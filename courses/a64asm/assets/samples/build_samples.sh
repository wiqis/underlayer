#!/usr/bin/env bash
# build_samples.sh -- produce every byte the a64asm course makes a claim about.
#
# Nothing in the course is a claim about a file that does not exist.  This
# script is the whole provenance of the corpus: it compiles ordinary C for
# AArch64 at four optimisation levels, assembles the hand-written corpus, and
# then runs a64dec.py, which decodes the result.  Given the two inputs --
# corpus.c and a64.s -- it is the only thing that has to be re-run when a
# number in the course needs re-measuring.
#
#   ./build_samples.sh          build the corpus, then run the whole artifact
#   ./build_samples.sh --only   build the corpus, do not run the artifact
#
# The two compilers and the one disassembler named below are the SECOND
# reader.  a64dec.py never calls them to DECODE anything; it calls them to
# produce words to decode and to check its own names against, and the
# difference is the reason a two-reader cross-check is a check.

set -euo pipefail
cd "$(dirname "$0")"

CLANG=${CLANG:-clang}
OBJDUMP=${OBJDUMP:-llvm-objdump-21}
TARGET=${TARGET:-aarch64-linux-gnu}

say() { printf '  %s\n' "$*"; }

printf '\n== 1. the toolchain, printed because a claim about a decoder needs one ==\n'
say "assembler:   $("$CLANG" --version | head -1)"
say "disassembler: $($OBJDUMP --version 2>/dev/null | sed -n '2p')"
if command -v "$TARGET-ld" >/dev/null 2>&1; then
  say "linker:      $("$TARGET-ld" --version | head -1)"
else
  say "linker:      $TARGET-ld IS NOT INSTALLED"
fi
if command -v qemu-aarch64 >/dev/null 2>&1; then
  say "emulator:    qemu-aarch64 present"
else
  say "emulator:    NONE.  Nothing in this corpus is ever EXECUTED, and the"
  say "             artifact says so in section 1 rather than implying that"
  say "             a disassembly is a measurement of a running program."
fi

printf '\n== 2. the hand-written corpus: 175 lines, one instruction per line ==\n'
"$CLANG" --target="$TARGET" -c a64.s -o a64.o
say "a64.s  ->  a64.o"
"$OBJDUMP" --triple=aarch64 -d a64.o > a64_objdump.txt
say "a64.o  ->  a64_objdump.txt"

printf '\n== 3. ordinary C, four optimisation levels ==\n'
for o in 0 1 2 s; do
  "$CLANG" --target="$TARGET" -c -O$o corpus.c -o "corpus_O$o.o"
  say "corpus.c -O$o -> corpus_O$o.o"
done

printf '\n== 4. the same C for x86-64, for the one comparison that needs it ==\n'
# The density comparison is a claim about a RATIO and a ratio needs both
# sides.  If either tool is missing the section prints a one-sided table and
# claims nothing, which is the correct behaviour and is why these lines have
# no `set -e` guard of their own beyond the whole script's.
for o in 0 1 2 s; do
  if "$CLANG" -c -O$o corpus.c -o "density_x86_O$o.o" 2>/dev/null; then
    say "corpus.c -O$o -> density_x86_O$o.o  (x86-64)"
  else
    say "corpus.c -O$o -> NO x86-64 object; the density section will be one-sided"
  fi
done

if [ "${1:-}" = "--only" ]; then
  printf '\n== 5. --only: the corpus is built, the artifact was not run ==\n\n'
  exit 0
fi

printf '\n== 5. run the artifact ==\n'
# Section 6 is the two-reader cross-check and section 7 runs the corpus, so
# they need the files above to exist; everything else would run against an
# absent corpus and would be reporting a claim about nothing.
python3 a64dec.py --run | tee a64dec.out
say "a64dec.out  written"

printf '\n== 6. two runs of the same thing, to show the determinism ==\n'
python3 a64dec.py --run > run1.txt
python3 a64dec.py --run > run2.txt
if cmp -s run1.txt run2.txt; then
  say "run1.txt and run2.txt are BYTE-IDENTICAL"
else
  say "run1.txt and run2.txt DIFFER -- a measurement that moves between runs"
  say "is a measurement with a machine in it, and the difference is here:"
  diff run1.txt run2.txt | head -40
fi

printf '\n== 7. the harness, which reads the recorded output and re-asks ==\n'
python3 crosscheck.py a64dec.out
