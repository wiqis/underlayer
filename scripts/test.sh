#!/usr/bin/env bash
# Build and run @test-annotated tests for Underlayer.
# Usage: scripts/test.sh
#        scripts/test.sh --test-names "test_health_returns_200"
#        scripts/test.sh --no-build
#
# The compiler is discovered by scripts/_common.sh; set CHEMICAL_ROOT or write
# scripts/.chemical-path if it is not found automatically.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_common.sh"

EXE="$UL_BUILD_DIR/tests.exe"

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
    ul_require_compiler
    echo "[1/2] Building tests.exe with --test..."
    mkdir -p "$UL_BUILD_DIR"
    (cd "$UL_PROJECT_ROOT" && "$UL_COMPILER" chemical.mod \
        -o "$EXE" -frecompile-plugins --test --no-cache $VERBOSE)
    echo "  Build OK: $EXE"
else
    echo "[1/2] Skipping build (--no-build)"
fi

if [ ! -f "$EXE" ]; then
    echo "[ERROR] Cannot find $EXE"
    exit 1
fi

# 2. Run tests (from the project root so ./courses resolves)
echo "[2/2] Running tests..."
RUN_ARGS=()
if [ -n "$TEST_NAMES" ]; then RUN_ARGS+=(--test-names "$TEST_NAMES"); fi
if [ -n "$TEST_IDS" ]; then RUN_ARGS+=(--test-ids "$TEST_IDS"); fi

cd "$UL_PROJECT_ROOT"
"$EXE" "${RUN_ARGS[@]}"
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "[underlayer] All tests passed"
else
    echo "[underlayer] Some tests failed (exit code $EXIT_CODE)"
fi
exit $EXIT_CODE
