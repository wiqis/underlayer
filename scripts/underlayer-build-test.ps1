#!/usr/bin/env pwsh
# Build, start server, test all endpoints, stop server.
# Usage: pwsh lang/compiled/underlayer/scripts/underlayer-build-test.ps1
# This script ALWAYS exits cleanly — never blocks.

$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$buildDir = Join-Path $root "lang\compiled\underlayer\build"
$url = "http://localhost:9000"

Write-Host "=== Underlayer Build + Test ==="

# 1. Build
Write-Host "[1/3] Building..."
$buildLog = Join-Path $buildDir "build_test.txt"
& cmake-build-debug/TCCCompiler "lang/compiled/underlayer/chemical.mod" -v -bm-modules --no-cache 2>&1 > $buildLog
if ($LASTEXITCODE -ne 0) {
    Write-Host "[BUILD FAILED] See $buildLog"
    Get-Content $buildLog | Select-String "error" | Select-Object -First 10
    exit 1
}
Write-Host "  Build OK"

# 2. Find exe — TCCCompiler outputs a.exe in CWD
$exe = Join-Path $root "a.exe"
if (-not (Test-Path $exe)) {
    $exe = Join-Path $buildDir "main.exe"
}
if (-not (Test-Path $exe)) {
    Write-Host "[ERROR] Cannot find underlayer executable"
    exit 1
}
Write-Host "  Using exe: $exe"

# 3. Kill old server
$existing = Get-NetTCPConnection -LocalPort 9000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if ($existing) {
    foreach ($pid in $existing) { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    Write-Host "  Killed old server"
}

# 4. Start server
$proc = Start-Process -FilePath $exe -PassThru -NoNewWindow
Write-Host "[2/3] Server started (PID $($proc.Id)), waiting 4s..."
Start-Sleep -Seconds 4

# 5. Test endpoints
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

Test-Url "health"         "/api/health"
Test-Url "home"           "/"
Test-Url "dashboard"      "/dashboard"
Test-Url "review page"    "/review"
Test-Url "progress page"  "/progress"
Test-Url "courses api"    "/api/courses"
Test-Url "elf course"     "/courses/elf"
Test-Url "elf lesson"     "/courses/elf/lessons/bytes"

# 6. Kill server
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
