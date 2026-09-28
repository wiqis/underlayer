#!/bin/sh
# build_samples.sh -- build and run the instrument for "The Memory
# Hierarchy", and keep only what belongs in the repository.
#
# The rule this follows, from the previous course: the instrument IS the
# artifact.  A benchmark you cannot rebuild with one command is a number you
# cannot check, and a number you cannot check is a number you should not
# publish.  So the samples directory holds four files -- this script, the
# program, the harness, and a .gitignore -- and everything else in it is a
# build product.
#
#   ./build_samples.sh            build, run, and cross-check
#   ./build_samples.sh --quick    the same with fewer repetitions
#
# The exit status is 0 only if the program ran, its own checks all passed, AND
# the harness agreed.  It is set explicitly at the end rather than left to
# `set -e`, because an earlier version of this script ended with a `git add
# --dry-run | sed` pipeline whose status had nothing to do with the
# measurement, and it reported failure on about a third of its runs while
# every check passed.  A build script whose own bookkeeping can fail it is
# the same mistake as a check that fails for the wrong reason.

cd "$(dirname "$0")" || exit 1

RUNARGS=""
if [ "$1" = "--quick" ]; then
    RUNARGS="--quick"
fi

RESULT=0

echo "== building membench"
# -O2, and deliberately no -march=native: the artifact must build and run on
# the reader's machine.  Every instruction used here (rdtsc, rdtscp, lfence,
# movdqu, movntdq) is baseline x86-64.
if ! cc -O2 -Wall -o membench membench.c -lpthread; then
    echo "   the build failed; nothing was measured"
    exit 1
fi

echo "== running membench"
./membench $RUNARGS > membench.out 2>&1
MEMRC=$?
if [ $MEMRC -ne 0 ]; then
    echo "   membench exited $MEMRC, so at least one of its own checks failed"
    sed -n '/--- group A/,$p' membench.out | grep -E '\[(PASS|FAIL)\]' || true
    RESULT=1
else
    echo "   membench ran clean"
fi

echo "== membench's own checks"
PASS=$(grep -c '\[PASS\]' membench.out || true)
FAIL=$(grep -c '\[FAIL\]' membench.out || true)
echo "   $PASS passed, $FAIL failed"

echo "== running crosscheck.py"
python3 crosscheck.py membench.out || RESULT=1

echo
echo "== done."
echo "   membench.out is $(wc -l < membench.out) lines."
echo "   tracked files in this directory (everything else is a build product):"
git add -An --dry-run . 2>/dev/null | sed 's/^/   /' || echo "   (not inside a git repository)"

exit $RESULT
