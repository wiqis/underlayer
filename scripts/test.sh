#!/usr/bin/env bash
# Build and run @test-annotated tests for Underlayer.
# Usage: ./lang/compiled/underlayer/scripts/test.sh
#        ./lang/compiled/underlayer/scripts/test.sh --test-names "test_health_returns_200"
#        ./lang/compiled/underlayer/scripts/test.sh --no-build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BUILD_DIR="$ROOT_DIR/lang/compiled/underlayer/build"
EXE="$BUILD_DIR/tests.exe"
COMPILER="$ROOT_DIR/cmake-build-debug/TCCCompiler.exe"
MOD="$ROOT_DIR/lang/compiled/underlayer/chemical.mod"

NO_BUILD=false
TEST_NAMES=""
TEST_IDS=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-build) NO_BUILD=true; shift ;;
        --test-names) TEST_NAMES="$2"; shift 2 ;;
        --test-ids) TEST_IDS="$2"; shift 2 ;;
        -v|--verbose) VERBOSE="-v"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Underlayer Test Runner ==="

# 1. Build
if [ "$NO_BUILD" = false ]; then
    echo "[1/2] Building tests.exe with --test..."
    mkdir -p "$BUILD_DIR"
    "$COMPILER" "$MOD" -o "$EXE" -frecompile-plugins --test --no-cache $VERBOSE
    if [ $? -ne 0 ]; then
        echo "[BUILD FAILED]"
        exit 1
    fi
    echo "  Build OK: $EXE"
else
    echo "[1/2] Skipping build (--no-build)"
fi

if [ ! -f "$EXE" ]; then
    echo "[ERROR] Cannot find $EXE"
    exit 1
fi

# 2. Run tests
echo "[2/2] Running tests..."
RUN_ARGS=()
if [ -n "$TEST_NAMES" ]; then RUN_ARGS+=(--test-names "$TEST_NAMES"); fi
if [ -n "$TEST_IDS" ]; then RUN_ARGS+=(--test-ids "$TEST_IDS"); fi

"$EXE" "${RUN_ARGS[@]}"
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "[underlayer] All tests passed"
else
    echo "[underlayer] Some tests failed (exit code $EXIT_CODE)"
fi
exit $EXIT_CODE
