#!/bin/sh
# build_samples.sh -- build privbench, run it, and cross-check the result.
#
#   ./build_samples.sh            build, run, cross-check
#   ./build_samples.sh --quick    skip the timing-heavy sections' extra reps
#
# The cross-check is run against a FRESH run, not against the committed
# privbench.out, so that "the claims still hold on this machine today" is a
# statement about the machine and not a tautology about a checked-in file.
set -e
cd "$(dirname "$0")"

CC=${CC:-cc}
CFLAGS=${CFLAGS:--O2 -Wall -Wextra}

echo "==> building privbench with: $CC $CFLAGS"
$CC $CFLAGS -o privbench privbench.c

if [ "$1" = "--quick" ]; then
    echo "==> quick run"
    ./privbench > /tmp/privbench.quick.$$ 2>&1 || true
    OUT=/tmp/privbench.quick.$$
else
    echo "==> running privbench (this takes about 20 s)"
    ./privbench > privbench.out
    OUT=privbench.out
fi

echo "==> cross-checking $OUT"
python3 crosscheck.py "$OUT"
rc=$?

if [ "$1" != "--quick" ]; then
    echo
    echo "==> artifact self-check"
    # The artifact prints its own tally of what it could and could not measure.
    # This is a second, weaker reader of the same file, and it exists because
    # the memory course's harness was once satisfied by a check that silently
    # had nothing to assert.
    n=$(grep -c '^   [0-9A-Z]' "$OUT" || true)
    echo "    $n numbered result lines in $OUT"
fi

exit $rc
