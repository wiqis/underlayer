#!/usr/bin/env pwsh
# Build and run @test-annotated tests for Underlayer.
# Usage: pwsh lang/compiled/underlayer/scripts/test.ps1
#        pwsh lang/compiled/underlayer/scripts/test.ps1 -TestNames "test_health_returns_200"
#        pwsh lang/compiled/underlayer/scripts/test.ps1 -NoBuild

param(
    [string]$TestNames = "",
    [string]$TestIds = "",
    [switch]$NoBuild,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$buildDir = Join-Path $root "lang\compiled\underlayer\build"
$exe = Join-Path $buildDir "tests.exe"
$compiler = Join-Path $root "cmake-build-debug\TCCCompiler.exe"
$mod = Join-Path $root "lang\compiled\underlayer\chemical.mod"

Write-Host "=== Underlayer Test Runner ==="

# 1. Build (unless --NoBuild)
if (-not $NoBuild) {
    Write-Host "[1/2] Building tests.exe with --test..."
    if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }

    $flags = @($mod, "-o", $exe, "-frecompile-plugins", "--test", "--no-cache")
    if ($Verbose) { $flags += "-v" }

    & $compiler @flags
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[BUILD FAILED]"
        exit 1
    }
    Write-Host "  Build OK: $exe"
} else {
    Write-Host "[1/2] Skipping build (--NoBuild)"
}

if (-not (Test-Path $exe)) {
    Write-Host "[ERROR] Cannot find $exe"
    exit 1
}

# 2. Run tests
Write-Host "[2/2] Running tests..."
$runArgs = @()
if ($TestNames) { $runArgs += "--test-names"; $runArgs += $TestNames }
if ($TestIds) { $runArgs += "--test-ids"; $runArgs += $TestIds }

& $exe @runArgs
$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "[underlayer] All tests passed"
} else {
    Write-Host "[underlayer] Some tests failed (exit code $exitCode)"
}
exit $exitCode
