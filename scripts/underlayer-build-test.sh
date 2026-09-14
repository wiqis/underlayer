#!/usr/bin/env bash
# Build, start server, test all endpoints, stop server.
# Usage: bash lang/compiled/underlayer/scripts/underlayer-build-test.sh
# This script ALWAYS exits cleanly — never blocks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
BUILD_DIR="$ROOT/lang/compiled/underlayer/build"
URL="http://localhost:9000"
PORT=9000

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
BUILD_LOG="$BUILD_DIR/build_test.txt"
(cd "$ROOT" && cmake-build-debug/TCCCompiler "lang/compiled/underlayer/chemical.mod" -v -bm-modules --no-cache >"$BUILD_LOG" 2>&1) || {
    echo "[BUILD FAILED] See $BUILD_LOG"
    grep -i "error" "$BUILD_LOG" | head -10
    exit 1
}
echo "  Build OK"

# 2. Find the exe — TCCCompiler outputs a.exe in CWD
EXE="$ROOT/a.exe"
if [ ! -f "$EXE" ]; then
    # Fallback: check build dir
    EXE="$BUILD_DIR/main.exe"
fi
if [ ! -f "$EXE" ]; then
    echo "[ERROR] Cannot find underlayer executable"
    exit 1
fi
echo "  Using exe: $EXE"

# 3. Kill old server on port
if command -v lsof >/dev/null 2>&1; then
    old_pids=$(lsof -ti :$PORT 2>/dev/null || true)
elif command -v netstat >/dev/null 2>&1; then
    old_pids=$(netstat -ano 2>/dev/null | grep ":$PORT " | grep LISTENING | awk '{print $NF}' | sort -u || true)
else
    old_pids=""
fi
if [ -n "$old_pids" ]; then
    for pid in $old_pids; do
        kill -9 $pid 2>/dev/null || true
    done
    sleep 2
    echo "  Killed old server"
fi

# 4. Start server
"$EXE" &
SERVER_PID=$!
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

# 6. Kill server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

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
