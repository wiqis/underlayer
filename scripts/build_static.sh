#!/usr/bin/env bash
# build_static.sh -- pre-render every course to courses/<id>/output/.
#
# WHY THIS EXISTS AS A SCRIPT RATHER THAN A CI STEP ALONE.
#
# courses/*/output is gitignored. That is correct -- generated HTML does not
# belong in git -- and it has a consequence nobody had written down: A CLEAN
# CLONE HAS NO STATIC PAGES AT ALL. GitHub Pages serves from the repository, so
# with the output directory ignored and no pipeline that regenerates it, the
# Pages site is empty. Measured on a fresh checkout of this repository: zero of
# the 398 lesson pages exist until somebody runs the generator.
#
# So the pipeline has to call something. This is that something, and it is a
# checked-in script rather than a YAML block so it can be run by hand, by CI, or
# on a laptop before pushing -- which is also how the course-content checks run
# against real pages.
#
# WHAT IT DOES, PER COURSE:
#   1. compiles courses/<id>/chemical.mod
#   2. runs the produced binary, which writes output/*.html
#
# The 34 courses share one compiler invocation each. A course that fails to
# build or render is reported and the rest continue, because a partial static
# site is still a usable static site and a CI job that stops at the first course
# tells you nothing about the other thirty-three.
#
# Usage:
#   scripts/build_static.sh              # every course
#   scripts/build_static.sh elf pe        # named courses only
#   scripts/build_static.sh --quiet      # summary lines only

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/_common.sh"

QUIET=false
COURSES=()
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        -*) echo "unknown option: $arg" >&2; exit 1 ;;
        *) COURSES+=("$arg") ;;
    esac
done

if ! ul_require_compiler 2>/dev/null; then
    echo "ERROR: no Chemical compiler found." >&2
    echo "  Set CHEMICAL_ROOT, or write the path to scripts/.chemical-path:" >&2
    echo "    echo /path/to/chemical > scripts/.chemical-path" >&2
    exit 1
fi

if [ ${#COURSES[@]} -eq 0 ]; then
    while IFS= read -r d; do
        [ -n "$d" ] && COURSES+=("$d")
    done < <(cd "$PROJECT_ROOT/courses" && ls -d */ 2>/dev/null | sed 's#/$##')
fi

echo "build_static: ${#COURSES[@]} course(s), compiler $UL_COMPILER"
echo

OK=0
FAILED=()
PAGES=0

for cid in "${COURSES[@]}"; do
    dir="$PROJECT_ROOT/courses/$cid"
    if [ ! -f "$dir/chemical.mod" ]; then
        FAILED+=("$cid (no chemical.mod)")
        continue
    fi
    mkdir -p "$dir/build"

    build_log="$dir/build/static-build.log"
    if ! (cd "$dir" && "$UL_COMPILER" chemical.mod \
            -o "build/$cid-course.exe" -bm-modules --no-cache \
            >"$build_log" 2>&1); then
        FAILED+=("$cid (compile failed -- $build_log)")
        continue
    fi

    # The course binary writes ./output relative to its CWD.
    if ! (cd "$dir" && "./build/$cid-course.exe" >"$dir/build/static-render.log" 2>&1); then
        FAILED+=("$cid (render failed -- $dir/build/static-render.log)")
        continue
    fi

    n=$(find "$dir/output" -maxdepth 1 -name '*.html' 2>/dev/null | wc -l)
    PAGES=$((PAGES + n))
    OK=$((OK + 1))
    [ "$QUIET" = true ] || printf '  %-12s %3d page(s)\n' "$cid" "$n"
done

echo
echo "build_static: $OK course(s) rendered, $PAGES page(s) total"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "build_static: ${#FAILED[@]} course(s) FAILED"
    for f in "${FAILED[@]}"; do
        echo "  - $f"
    done
    exit 1
fi
echo "build_static: every requested course rendered"