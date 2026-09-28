#!/bin/sh
# build_samples.sh -- build smpbench, run it, and cross-check the result.
#
#   ./build_samples.sh            build, run, cross-check
#   ./build_samples.sh --quick    fewer repetitions
#
# The cross-check runs against a FRESH run, not against the committed
# smpbench.out, so that "the claims still hold on this machine today" is a
# statement about the machine and not a tautology about a checked-in file.
set -e
cd "$(dirname "$0")"

CC=${CC:-cc}
CFLAGS=${CFLAGS:--O2 -Wall -Wextra}
LDLIBS=${LDLIBS:--lpthread}

echo "==> building smpbench with: $CC $CFLAGS $LDLIBS"
$CC $CFLAGS -o smpbench smpbench.c $LDLIBS

OUT=smpbench.out
if [ "$1" = "--quick" ]; then
    echo "==> quick run"
    OUT=/tmp/smpbench.quick.$$
else
    echo "==> running smpbench (this takes about 2 minutes: 6 placement"
    echo "    configurations plus 6 in the atomic section, 5 repetitions each,"
    echo "    2,000,000 iterations, and every arm is pinned and VERIFIED)"
    ./smpbench > "$OUT"
fi

echo "==> cross-checking $OUT"
python3 crosscheck.py "$OUT"
rc=$?

if [ "$1" != "--quick" ]; then
    echo
    echo "==> a second, weaker reader of the same file"
    # The claim this course exists to make is a SHAPE, not a number: that B and
    # C are close to each other and both far above A.  Print it in isolation,
    # because a harness that can only be read inside a 73-line transcript is a
    # harness nobody reads.
    echo "    the result, on its own:"
    grep -E "^  [A-G] " "$OUT" | sed 's/^/      /'
    echo "    and the one comparison that matters:"
    grep "B / C" "$OUT" | sed 's/^ */      /'
fi

exit $rc
