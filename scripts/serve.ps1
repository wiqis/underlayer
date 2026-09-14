#!/usr/bin/env pwsh
# Build and run the Underlayer server (not tests).
# Usage: pwsh lang/compiled/underlayer/scripts/serve.ps1
#        pwsh lang/compiled/underlayer/scripts/serve.ps1 -NoBuild -Port 9000

param(
    [int]$Port = 9000,
    [switch]$NoBuild,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$buildDir = Join-Path $root "lang\compiled\underlayer\build"

Write-Host "=== Underlayer Server ==="

# 1. Build (unless --NoBuild)
if (-not $NoBuild) {
    Write-Host "[1/2] Building server..."
    $buildLog = Join-Path $buildDir "build_serve.log"
    if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }

    $flags = @("lang/compiled/underlayer/chemical.mod")
    if ($Verbose) { $flags += "-v"; $flags += "-bm-modules" }

    & cmake-build-debug/TCCCompiler @flags 2>&1 | Tee-Object -FilePath $buildLog
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[BUILD FAILED] See $buildLog"
        exit 1
    }
    Write-Host "  Build OK"
} else {
    Write-Host "[1/2] Skipping build (--NoBuild)"
}

# 2. Find exe
$exe = Join-Path $root "a.exe"
if (-not (Test-Path $exe)) {
    $exe = Join-Path $buildDir "underlayer.exe"
}
if (-not (Test-Path $exe)) {
    Write-Host "[ERROR] Cannot find server executable."
    exit 1
}
Write-Host "  Using exe: $exe"

# 3. Kill old server on port
$existing = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if ($existing) {
    foreach ($pid in $existing) { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    Write-Host "  Killed old server on port $Port"
}

# 4. Start server
Write-Host "[2/2] Starting server on port $Port..."
$env:PORT = $Port
$proc = Start-Process -FilePath $exe -PassThru -NoNewWindow
Write-Host "  Server started (PID $($proc.Id))"
Write-Host "  Press Ctrl+C to stop"

# Wait for Ctrl+C
try {
    Wait-Process -Id $proc.Id
} finally {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}
