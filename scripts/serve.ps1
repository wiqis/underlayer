#!/usr/bin/env pwsh
# Build and run the Underlayer server (not tests).
# Usage: pwsh scripts/serve.ps1
#        pwsh scripts/serve.ps1 -NoBuild -Port 9002
#
# Compiler discovery mirrors scripts/_common.sh: the project builds from its
# own checkout, so no path climbs to lang/compiled/underlayer any more.

param(
    [int]$Port = 9000,
    [switch]$NoBuild,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $root "build"

function Find-Compiler {
    $candidates = @()
    foreach($envVar in @("CHEMICAL_ROOT", "CHEMICAL")) {
        $value = [Environment]::GetEnvironmentVariable($envVar)
        if($value) { $candidates += $value }
    }
    $override = Join-Path $root "scripts\.chemical-path"
    if(Test-Path $override) {
        $line = (Get-Content $override -TotalCount 1).Trim()
        if($line) { $candidates += $line }
    }
    $workspaceParent = Split-Path (Split-Path (Split-Path $root -Parent) -Parent) -Parent
    if(Test-Path $workspaceParent) {
        Get-ChildItem -Path $workspaceParent -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $sibling = Join-Path $_.FullName "chemical"
            if(Test-Path $sibling) { $candidates += $sibling }
        }
    }
    $candidates += @(
        "D:\Programming\Chemical\chemical",
        "C:\Programming\Chemical\chemical",
        (Join-Path $HOME "Programming\Chemical\chemical"),
        (Join-Path $HOME "Chemical\chemical")
    )
    foreach($base in $candidates) {
        foreach($dir in @("cmake-build-debug", "build", ".")) {
            foreach($name in @("TCCCompiler.exe", "TCCCompiler")) {
                $exe = Join-Path (Join-Path $base $dir) $name
                if(Test-Path $exe) { return (Resolve-Path $exe).Path }
            }
        }
    }
    $onPath = Get-Command TCCCompiler.exe -ErrorAction SilentlyContinue
    if(-not $onPath) { $onPath = Get-Command TCCCompiler -ErrorAction SilentlyContinue }
    if($onPath) { return $onPath.Source }
    return $null
}

Write-Host "=== Underlayer Server ==="

if(-not $NoBuild) {
    $compiler = Find-Compiler
    if(-not $compiler) {
        Write-Host "[ERROR] Could not find TCCCompiler. Set CHEMICAL_ROOT or write scripts/.chemical-path."
        exit 1
    }
    Write-Host "[1/2] Building server with $compiler..."
    $buildLog = Join-Path $buildDir "build_serve.log"
    if(-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }
    $flags = @("chemical.mod", "-o", (Join-Path $buildDir "underlayer.exe"), "-bm-modules", "--no-cache")
    if($Verbose) { $flags += "-v" }
    Push-Location $root
    try { & $compiler @flags 2>&1 | Tee-Object -FilePath $buildLog }
    finally { Pop-Location }
    if($LASTEXITCODE -ne 0) {
        Write-Host "[BUILD FAILED] See $buildLog"
        exit 1
    }
    Write-Host "  Build OK"
} else {
    Write-Host "[1/2] Skipping build (--NoBuild)"
}

$exe = Join-Path $buildDir "underlayer.exe"
if(-not (Test-Path $exe)) {
    Write-Host "[ERROR] Cannot find server executable at $exe"
    exit 1
}
Write-Host "  Using exe: $exe"

$existing = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if($existing) {
    foreach($processId in $existing) { Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    Write-Host "  Killed old server on port $Port"
}

Write-Host "[2/2] Starting server on port $Port..."
$env:PORT = "$Port"
if(-not $env:DATABASE_URL) { $env:DATABASE_URL = "./underlayer.db" }
if(-not $env:COURSES_DIR) { $env:COURSES_DIR = "./courses" }
$proc = Start-Process -FilePath $exe -WorkingDirectory $root -PassThru -NoNewWindow
Write-Host "  Server started (PID $($proc.Id))"
Write-Host "  Press Ctrl+C to stop"

try { Wait-Process -Id $proc.Id }
finally { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
