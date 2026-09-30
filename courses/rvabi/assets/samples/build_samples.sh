#!/usr/bin/env bash
# build_samples.sh -- produce every byte the rvabi course makes a claim about.
#
# Nothing in the course is a claim about a file that does not exist.  This
# script is the whole provenance of the corpus: it compiles four C files at
# four optimisation levels and at two -march settings, assembles the
# hand-written probe file, compiles the SAME C for AArch64 and x86-64 so the
# three-target table has three rows that came out of one file, then runs
# rvabi.py, which decodes the result.
#
#   ./build_samples.sh          build the corpus, then run the whole artifact
#   ./build_samples.sh --only   build the corpus, do not run the artifact
#
# AND THE TOOLCHAIN IS THINNER HERE THAN ANYWHERE ELSE IN THIS COLLECTION,
# which is why the script PRINTS what is missing instead of proceeding.  There
# is no RISC-V machine on this host, no emulator, and no RISC-V binutils:
# qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld} are all ABSENT.  So
# there are NO TIMINGS ANYWHERE IN THIS COURSE, and the artifact says so in its
# own header and again in its last section rather than quietly substituting an
# instruction count for a cycle count and calling it a measurement.  The
# x86-64 ABI course measured a 4.92x and a 27.65x; this course has no
# counterpart for either number and invents one for neither.

set -euo pipefail
cd "$(dirname "$0")"

CLANG=${CLANG:-clang}
OBJDUMP=${OBJDUMP:-llvm-objdump-21}
READELF=${READELF:-llvm-readelf-21}
TARGET=${TARGET:-riscv64-linux-gnu}
A64=${A64:-aarch64-linux-gnu}

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
say "NOTHING IN THIS COURSE IS EVER EXECUTED.  There is no RISC-V machine,"
say "no emulator and no RISC-V linker on this host.  Every figure below is a"
say "bit pattern, a count of bit patterns, an arithmetic identity, or a"
say "refusal from a real assembler.  There are NO TIMINGS and NO SPEEDUPS."
say "The three-target comparison in the artifact is a COMPILE-TIME"
say "instruction count and says so in its own caption."

printf '\n== 2. the hand-written probe corpus, one instruction per line ==\n'
"$CLANG" --target="$TARGET" -march=rv64gc -c probe.s -o probe.o
say "probe.s -> probe.o   (the assembler's own answers, not clang's choices)"
"$OBJDUMP" --triple=riscv64 -d probe.o > probe_objdump.txt
say "probe.o -> probe_objdump.txt   (the second reader's first opinion)"

printf '\n== 3. the four C corpora at four optimisation levels ==\n'
# -O0 through -Os, because the calling convention is the SPECIFICATION's and
# the instruction counts are the COMPILER's, and the only way to tell the two
# apart is to vary the level and see which numbers move.  A number that moves
# with -O is the compiler's; a number that does not is the ABI's.
for f in abi noflags regs cpc; do
  for o in O0 O1 O2 Os; do
    "$CLANG" --target="$TARGET" -march=rv64gc -c -"$o" "$f.c" -o "${f}_$o.o"
  done
  say "$f.c -> ${f}_O0.o ${f}_O1.o ${f}_O2.o ${f}_Os.o"
done

printf '\n== 4. the SAME C, at four -march settings, for the compression cost ==\n'
# TWO PAIRS, and the reason there are two is the most useful methodological
# result in this build script.
#
#   rv64i vs rv64gc          is CONFOUNDED.  rv64i has no F and no D, so
#                            every `double` in the source becomes a CALL to a
#                            soft-float helper and the instruction count
#                            changes because the ARITHMETIC changed rather
#                            than because the ENCODING did.  Comparing those
#                            two and reporting the difference as "what
#                            compression costs" is a category error, and the
#                            artifact prints the confound rather than hiding
#                            it.
#
#   rv64imafd vs rv64imafdc  is CLEAN.  Same base, same M, same A, same F,
#                            same D; the only difference is the trailing C.
#                            Any difference in instruction count here is
#                            either the C extension's own constraint on
#                            register selection or nothing at all.
for m in rv64i rv64gc rv64imafd rv64imafdc; do
  for f in cpc regs abi; do
    "$CLANG" --target="$TARGET" -march="$m" -c -O2 "$f.c" -o "${f}_$m.o"
  done
  say "cpc.c regs.c abi.c -march=$m -O2"
done

printf '\n== 5. the SAME C for AArch64 and x86-64, from the same file ==\n'
# This is the three-target comparison, and it is one source file compiled with
# three --target= flags.  If a target fails, the artifact's table says so in
# the row rather than omitting it: a comparison that silently drops a row
# reads as a smaller number.
for f in noflags abi regs cpc; do
  if "$CLANG" --target="$A64" -c -O2 "$f.c" -o "${f}_a64_O2.o" 2>/dev/null; then
    say "$f.c -> ${f}_a64_O2.o   (aarch64)"
  else
    say "$f.c -> NO aarch64 object; the three-target table loses this row"
  fi
  if "$CLANG" -c -O2 "$f.c" -o "${f}_x86_O2.o" 2>/dev/null; then
    say "$f.c -> ${f}_x86_O2.o   (x86-64)"
  else
    say "$f.c -> NO x86-64 object; the three-target table loses this row"
  fi
done
# And the SAME noflags.c at four optimisation levels for AArch64, because
# "AArch64 emits csel" is only interesting if it is asked at -O0 too: a
# claim that appears at -O2 and not at -O0 is a statement about the
# optimiser, not about the architecture, and the artifact needs to tell those
# apart.
for o in O0 O1 O2 Os; do
  "$CLANG" --target="$A64" -c -"$o" noflags.c -o "noflags_a64_$o.o" 2>/dev/null || true
done
say "noflags.c -> aarch64 at -O0 -O1 -O2 -Os"

if [ "${1:-}" = "--only" ]; then
  printf '\n== 6. --only: the corpus is built, the artifact was not run ==\n\n'
  exit 0
fi

printf '\n== 6. run the artifact ==\n'
# Sections 7, 8 and the cross-check need the files above to exist; anything
# else would run against an absent corpus and would be reporting a claim
# about nothing.
python3 rvabi.py --run | tee rvabi.out
say "rvabi.out  written"

printf '\n== 7. two runs of the same thing, to show the determinism ==\n'
python3 rvabi.py --run > run1.txt
python3 rvabi.py --run > run2.txt
if cmp -s run1.txt run2.txt; then
  say "run1.txt and run2.txt are BYTE-IDENTICAL"
else
  say "run1.txt and run2.txt DIFFER -- a measurement that moves between runs"
  say "is a measurement with a machine in it, and the difference is here:"
  diff run1.txt run2.txt | head -40
fi

printf '\n== 8. the harness, which reads the recorded output and re-asks ==\n'
python3 crosscheck.py rvabi.out