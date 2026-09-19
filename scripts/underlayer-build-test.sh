#!/usr/bin/env bash
# Build, start the server, smoke-test the endpoints, stop the server.
# Usage: scripts/underlayer-build-test.sh
#        PORT=9100 scripts/underlayer-build-test.sh
# This script ALWAYS exits cleanly — never blocks.
#
# The compiler is discovered by scripts/_common.sh; set CHEMICAL_ROOT or write
# scripts/.chemical-path if it is not found automatically.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

PORT="${PORT:-9000}"
URL="http://localhost:$PORT"

pass=0
fail=0

test_url() {
    local label="$1" path="$2"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$URL$path" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        echo "  [OK]   $label  $path"
        pass=$((pass + 1))
    else
        echo "  [FAIL] $label  $path  ($status)"
        fail=$((fail + 1))
    fi
}

echo "=== Underlayer Build + Test ==="

# 1. Build
echo "[1/3] Building..."
mkdir -p "$UL_BUILD_DIR"
BUILD_LOG="$UL_BUILD_DIR/build_test.txt"
if ! ul_build_server >"$BUILD_LOG" 2>&1; then
    echo "[BUILD FAILED] See $BUILD_LOG"
    grep -i "error" "$BUILD_LOG" | head -10
    exit 1
fi
echo "  Build OK"

# 2. Find the exe
EXE="$UL_BUILD_DIR/underlayer.exe"
if [ ! -f "$EXE" ]; then
    echo "[ERROR] Cannot find underlayer executable at $EXE"
    exit 1
fi
echo "  Using exe: $EXE"

# 3. Kill old server on port
ul_kill_port "$PORT"

# 4. Start server (from the project root so COURSES_DIR=./courses resolves)
SERVER_PID="$(ul_start_server "$EXE" "$PORT")"
echo "[2/3] Server started (PID $SERVER_PID), waiting 4s..."
sleep 4

# 5. Test endpoints
echo "[3/3] Testing endpoints..."
test_url "health"         "/api/health"
test_url "home"           "/"
test_url "dashboard"      "/dashboard"
test_url "review page"    "/review"
test_url "progress page"  "/progress"
test_url "courses api"    "/api/courses"
test_url "elf course"     "/courses/elf"
test_url "elf lesson"     "/courses/elf/lessons/bytes"
test_url "hat course"     "/courses/hat"
test_url "hat lesson"     "/courses/hat/lessons/hat-exam-overview"
test_url "hat lesson 2"   "/courses/hat/lessons/hat-digital-logic"
test_url "hat course api" "/api/courses/hat"

# 6. Kill server
kill "$SERVER_PID" 2>/dev/null || true
if command -v taskkill >/dev/null 2>&1; then
    taskkill //F //PID "$SERVER_PID" >/dev/null 2>&1 || true
fi
wait "$SERVER_PID" 2>/dev/null || true

# Summary
total=$((pass + fail))
echo ""
if [ $fail -eq 0 ]; then
    echo "[underlayer] All $total endpoints OK"
    exit 0
else
    echo "[underlayer] $fail of $total endpoints FAILED"
    exit 1
fi
