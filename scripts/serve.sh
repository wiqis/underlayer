#!/usr/bin/env bash
# Build and run the Underlayer server (not tests).
# Usage: scripts/serve.sh
#        scripts/serve.sh --no-build --port 9000
#        CHEMICAL_ROOT=/path/to/Chemical/chemical scripts/serve.sh
#
# The compiler is discovered by scripts/_common.sh; set CHEMICAL_ROOT or write
# scripts/.chemical-path if it is not found automatically.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

NO_BUILD=false
PORT="${PORT:-9000}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-build) NO_BUILD=true; shift ;;
        --port) PORT="$2"; shift 2 ;;
        -v|--verbose) UL_VERBOSE=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Underlayer Server ==="

# 1. Build
EXE="$UL_BUILD_DIR/underlayer.exe"
if [ "$NO_BUILD" = false ]; then
    echo "[1/2] Building server..."
    ul_build_server
    echo "  Build OK"
else
    echo "[1/2] Skipping build (--no-build)"
    if [ ! -f "$EXE" ]; then
        echo "[ERROR] $EXE does not exist yet — run without --no-build first."
        exit 1
    fi
fi

if [ ! -f "$EXE" ]; then
    echo "[ERROR] Cannot find server executable at $EXE"
    exit 1
fi
echo "  Using exe: $EXE"

# 2. Start server
echo "[2/2] Starting server on port $PORT (Ctrl+C to stop)..."
ul_kill_port "$PORT"
cd "$UL_PROJECT_ROOT"
PORT="$PORT" "$EXE"
