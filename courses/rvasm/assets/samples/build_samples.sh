#!/usr/bin/env bash
# build_samples.sh -- produce every byte the rvasm course makes a claim about.
#
# Nothing in the course is a claim about a file that does not exist.  This
# script is the whole provenance of the corpus: it compiles the same C file at
# eight -march settings, assembles the hand-written probe corpus, and then
# runs rvdec.py, which decodes the result.  Given the three inputs --
# corpus.c, rv.s and far.c -- it is the only thing that has to be re-run when
# a number in the course needs re-measuring.
#
#   ./build_samples.sh          build the corpus, then run the whole artifact
#   ./build_samples.sh --only   build the corpus, do not run the artifact
#
# The compiler and the disassembler named below are the SECOND reader.
# rvdec.py never calls them to DECODE anything; it calls them to produce words
# to decode and to check its own names against, and the difference is the
# reason a two-reader cross-check is a check.  Part one of rvdec.py imports
# os, re, struct and sys and nothing else, and that is enforced by reading the
# import lines rather than by a promise in a comment.
#
# AND THE TOOLCHAIN IS THINNER HERE THAN ANYWHERE ELSE IN THIS COLLECTION,
# which is why the script PRINTS what is missing instead of proceeding.  There
# is no RISC-V machine on this host, no emulator, and no RISC-V binutils:
# qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld} are all ABSENT.  So
# there are no timings anywhere in this course, and the artifact says so in
# section 1 and section 11 rather than quietly substituting a byte count for
# a cycle count and calling it a measurement.

set -euo pipefail
cd "$(dirname "$0")"

CLANG=${CLANG:-clang}
OBJDUMP=${OBJDUMP:-llvm-objdump-21}
READELF=${READELF:-llvm-readelf-21}
TARGET=${TARGET:-riscv64-linux-gnu}

say() { printf '  %s\n' "$*"; }

printf '\n== 1. the toolchain, printed because a claim about a decoder needs one ==\n'
say "assembler:    $("$CLANG" --version | head -1)"
say "disassembler: $($OBJDUMP --version 2>/dev/null | sed -n '2p')"
if command -v "$TARGET-ld" >/dev/null 2>&1; then
  say "linker:       $("$TARGET-ld" --version | head -1)"
else
  say "linker:       $TARGET-ld IS NOT INSTALLED"
fi
for emu in qemu-riscv64 spike; do
  if command -v "$emu" >/dev/null 2>&1; then
    say "emulator:     $emu present"
  else
    say "emulator:     $emu ABSENT"
  fi
done
say ""
say "NOTHING IN THIS COURSE IS EVER EXECUTED.  Every figure is a bit"
say "pattern, a count of bit patterns, an arithmetic identity, or a refusal"
say "from a real assembler.  The x86-64 section's speedup ratios have NO"
say "counterpart here and are not invented to fill the gap."

printf '\n== 2. the hand-written corpus, one instruction per line ==\n'
"$CLANG" --target="$TARGET" -march=rv64gcv -c rv.s -o rv.o
say "rv.s   ->  rv.o"
"$OBJDUMP" --triple=riscv64 -d rv.o > rv_objdump.txt
say "rv.o   ->  rv_objdump.txt"

printf '\n== 3. ordinary C at eight -march settings ==\n'
# The sweep is the measurement behind concept 1: the same eleven functions
# compiled with and without each extension letter, and the diff of what
# appears and disappears.  It is also the one place where a number is a
# property of a COMPILER and not of an architecture, and the artifact says so
# in the paragraph under the table.
for m in rv64i rv64im rv64if rv64imf rv64imafd rv64imafdc rv64gc rv64gcv; do
  "$CLANG" --target="$TARGET" -march="$m" -c -O2 corpus.c -o "corpus_$m.o"
  say "corpus.c -march=$m -> corpus_$m.o"
done

printf '\n== 4. the far-reference probe, for the address-forming pair ==\n'
"$CLANG" --target="$TARGET" -march=rv64gcv -c -O2 far.c -o far_rv.o
say "far.c -> far_rv.o   (rv64)"
# The AArch64 build of the SAME C, for the one comparison the course makes
# against the sibling section.  If it fails, section 8 is one-sided and says
# so; it does not fail silently, which is the whole point of the `if`.
if "$CLANG" --target=aarch64-linux-gnu -c -O2 far.c -o far_a64.o 2>/dev/null; then
  say "far.c -> far_a64.o  (aarch64, for the comparison in section 8)"
else
  say "far.c -> NO aarch64 object; section 8's comparison is one-sided"
fi
"$READELF" -r far_rv.o > far_riscv_relocs.txt 2>/dev/null || true
"$READELF" -r far_a64.o > far_a64_relocs.txt 2>/dev/null || true
say "far_riscv_relocs.txt and far_a64_relocs.txt written"

if [ "${1:-}" = "--only" ]; then
  printf '\n== 5. --only: the corpus is built, the artifact was not run ==\n\n'
  exit 0
fi

printf '\n== 5. run the artifact ==\n'
# Section 6 is the two-reader cross-check and section 10 runs the corpus, so
# they need the files above to exist; everything else would run against an
# absent corpus and would be reporting a claim about nothing.
python3 rvdec.py --run | tee rvdec.out
say "rvdec.out  written"

printf '\n== 6. two runs of the same thing, to show the determinism ==\n'
python3 rvdec.py --run > run1.txt
python3 rvdec.py --run > run2.txt
if cmp -s run1.txt run2.txt; then
  say "run1.txt and run2.txt are BYTE-IDENTICAL"
else
  say "run1.txt and run2.txt DIFFER -- a measurement that moves between runs"
  say "is a measurement with a machine in it, and the difference is here:"
  diff run1.txt run2.txt | head -40
fi

printf '\n== 7. the harness, which reads the recorded output and re-asks ==\n'
python3 crosscheck.py rvdec.out
