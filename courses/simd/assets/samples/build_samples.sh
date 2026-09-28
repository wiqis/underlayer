#!/bin/sh
# build_samples.sh -- build simdbench, run it, and cross-check the result.
#
#   ./build_samples.sh            build, run, cross-check
#   ./build_samples.sh --quick    fewer repetitions
#
# The cross-check runs against a FRESH run, not against the committed
# simdbench.out, so that "the claims still hold on this machine today" is a
# statement about the machine and not a tautology about a checked-in file.
#
# The flags matter and are not decorative:
#
#   -O2         what the "auto-vectorised" arm is measured at.  gcc 12 and later
#               enable -ftree-vectorize at -O2 under the "very-cheap" cost model,
#               which is why section 3's variable-trip-count arm is NOT
#               vectorised.  Changing this changes what arm A measures.
#   -mavx2 -mfma   sections 2, 4, 5 and 6 need _mm256_* and _mm256_fmadd_pd.
#               Without them the intrinsic headers refuse to compile.
#   NOT -march=native  on purpose.  A native build would silently pick a
#               different ISA level on a different machine, and a recorded run
#               that cannot be reproduced on the machine that reads it is a
#               remembered number.
set -e
cd "$(dirname "$0")"

CC=${CC:-cc}
CFLAGS=${CFLAGS:--O2 -Wall -mavx2 -mfma}

echo "==> building simdbench with: $CC $CFLAGS"
$CC $CFLAGS -o simdbench simdbench.c

OUT=simdbench.out
if [ "$1" = "--quick" ]; then
    echo "==> quick run"
    OUT=/tmp/simdbench.quick.$$
else
    echo "==> running simdbench (this takes a few minutes: six arms in section 2,"
    echo "    five working-set sizes up to 24 MiB in section 3, four arithmetic"
    echo "    bodies and two independence bodies in section 4, five reduction arms"
    echo "    in section 5, seven arms in section 6, all minimum-of-N and"
    echo "    INTERLEAVED so every arm sees the same machine state)"
    ./simdbench > "$OUT"

    # ---------------------------------------------------------------------
    # THE VERIFY BLOCK.  Section 3 makes three claims about what the compiler
    # did, and all three are claims about BYTES.  Quoting a speedup as
    # evidence for them is the mistake this collection keeps making, so the
    # four forms of the loop are disassembled and their mnemonics appended.
    # It lives in verify_codegen.sh because the recorded runs run1.txt and
    # run2.txt need the identical block produced by the identical code.
    # ---------------------------------------------------------------------
    echo "==> disassembling four forms of the same loop"
    ./verify_codegen.sh "$OUT"
fi

echo "==> cross-checking $OUT"
python3 crosscheck.py "$OUT"
rc=$?

if [ "$1" != "--quick" ]; then
    echo
    echo "==> the two results that are the course, on their own"
    # The claim this course exists to make is a SHAPE, not a number: the same
    # 4-wide arm's speedup collapses when the working set grows past the cache.
    # Print it in isolation, because a harness that can only be read inside a
    # transcript is a harness nobody reads.
    echo "    the 4-wide arm's speedup against the working set:"
    grep -E "^   (L1|beyond)" "$OUT" | sed 's/^/      /'
    echo "    and the gather, which is where the width costs:"
    grep -E "vpgatherdd, against" "$OUT" | sed 's/^ */      /'
fi

exit $rc
