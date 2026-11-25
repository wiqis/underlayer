#!/usr/bin/env pwsh
# Build, start server, test endpoints, stop server.
# Usage: pwsh scripts/underlayer-build-test.ps1 [-Port 9000]
# This script ALWAYS exits cleanly - never blocks.

param([int]$Port = 9000)

$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $root "build"
$url = "http://localhost:$Port"

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

Write-Host "=== Underlayer Build + Test ==="

Write-Host "[1/3] Building..."
$compiler = Find-Compiler
if(-not $compiler) {
    Write-Host "[ERROR] Could not find TCCCompiler. Set CHEMICAL_ROOT or write scripts/.chemical-path."
    exit 1
}
$buildLog = Join-Path $buildDir "build_test.log"
if(-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }
$flags = @("chemical.mod", "-o", (Join-Path $buildDir "underlayer.exe"), "-bm-modules", "--no-cache")
Push-Location $root
try { & $compiler @flags 2>&1 > $buildLog }
finally { Pop-Location }
if($LASTEXITCODE -ne 0) {
    Write-Host "[BUILD FAILED] See $buildLog"
    Get-Content $buildLog | Select-String "error" | Select-Object -First 10
    exit 1
}
Write-Host "  Build OK"

$exe = Join-Path $buildDir "underlayer.exe"
if(-not (Test-Path $exe)) {
    Write-Host "[ERROR] Cannot find underlayer executable at $exe"
    exit 1
}
Write-Host "  Using exe: $exe"

$existing = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if($existing) {
    foreach($processId in $existing) { Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    Write-Host "  Killed old server on port $Port"
}

$env:PORT = "$Port"
if(-not $env:DATABASE_URL) { $env:DATABASE_URL = "./underlayer.db" }
if(-not $env:COURSES_DIR) { $env:COURSES_DIR = "./courses" }
$proc = Start-Process -FilePath $exe -WorkingDirectory $root -PassThru -NoNewWindow
Write-Host "[2/3] Server started (PID $($proc.Id)), waiting 4s..."
Start-Sleep -Seconds 4

Write-Host "[3/3] Testing endpoints..."
$passed = 0
$failed = 0

function Test-Url($label, $path) {
    try {
        $r = Invoke-WebRequest -Uri "$url$path" -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -eq 200) {
            Write-Host "  [OK]   $label  $path"
            $script:passed++
        } else {
            Write-Host "  [FAIL] $label  $path  (status $($r.StatusCode))"
            $script:failed++
        }
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Write-Host "  [FAIL] $label  $path  ($code)"
        $script:failed++
    }
}

Test-Url "health"          "/api/health"
Test-Url "home"            "/"
Test-Url "courses api"     "/api/courses"
Test-Url "elf course"      "/courses/elf"
Test-Url "elf lesson"      "/courses/elf/lessons/bytes"
Test-Url "lesson units"    "/api/courses/elf/lessons/bytes/units"

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

Write-Host ""
$total = $passed + $failed
if ($failed -eq 0) {
    Write-Host "[underlayer] All $total endpoints OK"
    exit 0
} else {
    Write-Host "[underlayer] $failed of $total endpoints FAILED"
    exit 1
}
