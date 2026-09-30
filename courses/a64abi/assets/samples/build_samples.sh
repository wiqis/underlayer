#!/bin/sh
# build_samples.sh -- rebuild the corpus for "The AArch64 Procedure Call
# Standard", run the artifact, and run the harness.
#
#   ./build_samples.sh          build, run the artifact, run crosscheck.py
#   ./build_samples.sh --run    just run the artifact
#
# The recorded outputs (a64abi.out, run1.txt, run2.txt) are committed, so
# `python3 crosscheck.py` works with no toolchain at all.  The object files
# are not committed: they are reproducible from four source files with this
# one script, and a course whose numbers are only checkable on the machine
# that produced them is a course whose numbers are claims.
set -e
cd "$(dirname "$0")"

T=aarch64-linux-gnu
CC="clang --target=$T"

echo "== toolchain =="
clang --version | head -1
llvm-objdump-21 --version | head -3 | tail -1
for t in aarch64-linux-gnu-ld qemu-aarch64; do
    if command -v "$t" >/dev/null 2>&1; then echo "$t: PRESENT"; else echo "$t: ABSENT"; fi
done

echo "== C corpus, four optimisation levels =="
for O in O0 O1 O2 Os; do
    $CC -S -$O abi.c -o abi_$O.s
    $CC -c -$O abi.c -o abi_$O.o
    # the same C for the other architecture, for the compile-time
    # instruction-count comparison.  NOT a timing comparison.
    clang -S -$O -fomit-frame-pointer abi.c -o x86_$O.s
    clang -c -$O -fomit-frame-pointer abi.c -o x86_$O.o
    # mawk has no strtonum() and gawk is not installed here, so the .text
    # size is read with python rather than with awk.  See textsize.py for
    # why that is a file and not an inline heredoc.
    printf "  %-4s abi_%s.o  .text=%s bytes\n" "$O" "$O" \
        "$(python3 textsize.py abi_$O.o .text)"
done

echo "== hand-written assembly =="
$CC -c frame.s -o frame_a64.o
clang -c frame86.s -o frame_x86.o
$CC -c regs.s  -o regs.o
$CC -c align.s -o align.o
echo "  frame_a64.o frame_x86.o regs.o align.o"

echo "== the artifact =="
python3 a64abi.py --run > a64abi.out 2>&1 || { echo "ARTIFACT FAILED"; tail -30 a64abi.out; exit 1; }
wc -l a64abi.out

echo "== determinism: two runs must be byte-identical =="
python3 a64abi.py --run > run1.txt 2>&1
python3 a64abi.py --run > run2.txt 2>&1
if cmp -s run1.txt run2.txt; then echo "  run1.txt == run2.txt  OK"; else
    echo "  RUNS DIFFER:"; diff run1.txt run2.txt | head -20; exit 1; fi
if cmp -s run1.txt a64abi.out; then echo "  run1.txt == a64abi.out  OK"; else
    echo "  THE RECORDED OUTPUT IS STALE -- copy run1.txt over a64abi.out"; fi

echo "== the harness =="
python3 crosscheck.py
