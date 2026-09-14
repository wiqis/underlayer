#!/usr/bin/env bash
# Build and run the Underlayer server (not tests).
# Usage: ./lang/compiled/underlayer/scripts/serve.sh
#        ./lang/compiled/underlayer/scripts/serve.sh --no-build --port 9000

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BUILD_DIR="$ROOT_DIR/lang/compiled/underlayer/build"

NO_BUILD=false
PORT=9000
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-build) NO_BUILD=true; shift ;;
        --port) PORT="$2"; shift 2 ;;
        -v|--verbose) VERBOSE="-v -bm-modules"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Underlayer Server ==="

# 1. Build
if [ "$NO_BUILD" = false ]; then
    echo "[1/2] Building server..."
    mkdir -p "$BUILD_DIR"
    cd "$ROOT_DIR"
    cmake-build-debug/TCCCompiler "lang/compiled/underlayer/chemical.mod" $VERBOSE
    echo "  Build OK"
else
    echo "[1/2] Skipping build (--no-build)"
fi

# 2. Find exe
EXE="$ROOT_DIR/a.exe"
if [ ! -f "$EXE" ]; then
    EXE="$BUILD_DIR/underlayer.exe"
fi
if [ ! -f "$EXE" ]; then
    echo "[ERROR] Cannot find server executable."
    exit 1
fi
echo "  Using exe: $EXE"

# 3. Start server
echo "[2/2] Starting server on port $PORT..."
PORT=$PORT "$EXE"
