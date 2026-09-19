#!/usr/bin/env bash
# Shared helpers for the Underlayer build/test scripts.
# Sourced by serve.sh, test.sh and underlayer-build-test.sh — never run directly.
#
# Why this exists: Underlayer used to be built from inside the Chemical repo at
# lang/compiled/underlayer, so every script climbed four directories up to reach
# the compiler and hardcoded that layout. The project now builds from its own
# checkout (database/chemical.mod imports the sqlite3 bindings by URL), so the
# project root is resolved from this file's location and the compiler is
# discovered separately.

# ---------------------------------------------------------------------------
# Project layout
# ---------------------------------------------------------------------------

# scripts/_common.sh -> project root is the parent of scripts/.
UL_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UL_BUILD_DIR="$UL_PROJECT_ROOT/build"
UL_MOD="$UL_PROJECT_ROOT/chemical.mod"
UL_COURSES_DIR="$UL_PROJECT_ROOT/courses"
UL_PORT="${PORT:-9000}"

# ---------------------------------------------------------------------------
# Compiler discovery
# ---------------------------------------------------------------------------

# Search order:
#   1. $CHEMICAL_ROOT / $CHEMICAL                      (explicit override)
#   2. scripts/.chemical-path                          (one-line local override)
#   3. $UL_PROJECT_ROOT/../../../*/chemical            (sibling of the workspace)
#   4. common install locations
#   5. TCCCompiler on PATH
# The compiler is looked for in cmake-build-debug/ first, since that is where
# the Chemical build puts it.
ul_find_compiler() {
    local candidate roots=() dirs=()

    if [ -n "${CHEMICAL_ROOT:-}" ]; then roots+=("$CHEMICAL_ROOT"); fi
    if [ -n "${CHEMICAL:-}" ]; then roots+=("$CHEMICAL"); fi

    local override_file="$UL_PROJECT_ROOT/scripts/.chemical-path"
    if [ -f "$override_file" ]; then
        local line
        line="$(head -n 1 "$override_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [ -n "$line" ]; then roots+=("$line"); fi
    fi

    local sibling
    for sibling in "$UL_PROJECT_ROOT"/../../../*/chemical; do
        if [ -d "$sibling" ]; then roots+=("$sibling"); fi
    done

    roots+=(
        "/d/Programming/Chemical/chemical"
        "/c/Programming/Chemical/chemical"
        "$HOME/Programming/Chemical/chemical"
        "$HOME/Chemical/chemical"
    )

    # A root may hold the compiler in cmake-build-debug/ or at its top level.
    dirs=("cmake-build-debug" "build" ".")
    local root dir
    for root in "${roots[@]}"; do
        for dir in "${dirs[@]}"; do
            for candidate in "$root/$dir/TCCCompiler" "$root/$dir/TCCCompiler.exe"; do
                if [ -f "$candidate" ]; then
                    echo "$candidate"
                    return 0
                fi
            done
        done
    done

    candidate="$(command -v TCCCompiler 2>/dev/null || true)"
    if [ -z "$candidate" ]; then
        candidate="$(command -v TCCCompiler.exe 2>/dev/null || true)"
    fi
    if [ -n "$candidate" ]; then
        echo "$candidate"
        return 0
    fi

    return 1
}

UL_COMPILER="$(ul_find_compiler || true)"

# Print an actionable error and stop when no compiler was found.
ul_require_compiler() {
    if [ -n "$UL_COMPILER" ]; then
        return 0
    fi
    cat >&2 <<'EOF'
[ERROR] Could not find the Chemical compiler (TCCCompiler).

Looked in $CHEMICAL_ROOT, scripts/.chemical-path, sibling directories of the
workspace, common install paths, and on PATH — checking cmake-build-debug/
first in each case.

Fix it with either:

    export CHEMICAL_ROOT=/path/to/Chemical/chemical
    # or record it once for this checkout:
    echo /path/to/Chemical/chemical > scripts/.chemical-path

The compiler path can also be given directly:

    export CHEMICAL_ROOT=/path/to/dir/containing/cmake-build-debug
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Shared commands
# ---------------------------------------------------------------------------

# Build the web server into build/underlayer.exe.
# Pass --no-cache for a trustworthy build: an incremental build can miss edits
# to a module that already compiled, which looks like "my change did nothing".
ul_build_server() {
    ul_require_compiler
    mkdir -p "$UL_BUILD_DIR"
    local extra=()
    if [ -n "${UL_VERBOSE:-}" ]; then extra+=("-v"); fi
    echo "[build] server -> $UL_BUILD_DIR/underlayer.exe"
    (cd "$UL_PROJECT_ROOT" && "$UL_COMPILER" chemical.mod \
        -o "$UL_BUILD_DIR/underlayer.exe" -bm-modules --no-cache "${extra[@]}")
}

# Build one course's pre-rendered static pages into courses/<id>/output/.
ul_build_course() {
    local course_id="$1"
    ul_require_compiler
    local course_dir="$UL_COURSES_DIR/$course_id"
    if [ ! -f "$course_dir/chemical.mod" ]; then
        echo "[ERROR] No such course: $course_id (looked for $course_dir/chemical.mod)" >&2
        return 1
    fi
    mkdir -p "$course_dir/build"
    echo "[build] course '$course_id' -> $course_dir/output/"
    (cd "$course_dir" && "$UL_COMPILER" chemical.mod \
        -o "build/$course_id-course.exe" -bm-modules --no-cache) || return 1
    (cd "$course_dir" && "./build/$course_id-course.exe")
}

# Kill whatever is listening on a port (Lsof on Unix, netstat+taskkill on Windows).
ul_kill_port() {
    local port="$1"
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
        pids="$(lsof -ti :"$port" 2>/dev/null || true)"
    elif command -v netstat >/dev/null 2>&1; then
        pids="$(netstat -ano 2>/dev/null | grep ":$port " | grep LISTENING | awk '{print $NF}' | sort -u || true)"
    fi
    if [ -z "$pids" ]; then
        return 0
    fi
    local pid
    for pid in $pids; do
        if command -v taskkill >/dev/null 2>&1; then
            taskkill //F //PID "$pid" >/dev/null 2>&1 || true
        else
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 2
    echo "  Killed old server on port $port"
}

# Run the server binary in the background, in the project root so that
# COURSES_DIR=./courses resolves. Echoes the PID.
ul_start_server() {
    local exe="$1" port="$2"
    (cd "$UL_PROJECT_ROOT" && PORT="$port" "$exe") &
    echo "$!"
}
