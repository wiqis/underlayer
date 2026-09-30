#!/usr/bin/env bash
# build_samples.sh -- produce every byte the rvpriv course makes a claim about.
#
# Nothing in the course is a claim about a file that does not exist.  This
# script is the whole provenance of the corpus: it assembles the hand-written
# CSR and page-table files, compiles four C files at four optimisation levels,
# compiles ONE C file twice with the page tables in two different places, and
# assembles the SAME two-instruction file six times with the two LO12
# relocations at six different distances, then runs rvpriv.py, which reads
# the result.
#
#   ./build_samples.sh          build the corpus, then run the whole artifact
#   ./build_samples.sh --only   build the corpus, do not run the artifact
#
# AND THE TOOLCHAIN IS THINNER HERE THAN ANYWHERE ELSE IN THIS COLLECTION,
# and for THIS course the absence is not a limitation of the measurements --
# it is the subject.  There is no RISC-V machine on this host, no emulator,
# and no RISC-V binutils: qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld}
# are all ABSENT.  So:
#
#   * there are NO TIMINGS anywhere in this course, and
#   * no exception is ever DELIVERED, no page is ever WALKED, no TLB is ever
#     consulted, and no ecall is ever OBSERVED doing anything.
#
# The ecall convention is measured as the compiler emits it, which is weaker
# than an execution would have been, and every page that carries it says so.
# What CAN be measured is exactly what this course measures: the ENCODING,
# the CSR ADDRESS arithmetic, the relocation RECORDS, and the size arithmetic
# of Sv39/Sv48/Sv57.  The x86-64 section measured a 4.92x and a 27.65x on
# hardware; this course has no counterpart for either number and invents one
# for neither.

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
say "readelf:      $($READELF --version 2>/dev/null | sed -n '2p')"
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
if command -v "$TARGET-as" >/dev/null 2>&1; then
  say "second as:    $TARGET-as present"
else
  say "second as:    $TARGET-as IS NOT INSTALLED  (so both readers are ONE LLVM tree)"
fi
say ""
say "NOTHING IN THIS COURSE IS EVER EXECUTED.  No exception is ever taken,"
say "no page is ever walked, no TLB is ever consulted, no ecall is ever"
say "OBSERVED doing anything.  Every figure below is a bit pattern, a count"
say "of bit patterns, an arithmetic identity, or a refusal from a real"
say "assembler.  There are NO TIMINGS and NO SPEEDUPS."

printf '\n== 2. the hand-written CSR corpus, the assembler''s own answers ==\n'
"$CLANG" --target="$TARGET" -march=rv64gc -c csr.s -o csr.o
say "csr.s -> csr.o   (6 Zicsr instructions x 2 source forms, 30 CSR names,"
say "                     6 numeric U-mode addresses, 5 counter addresses)"
"$OBJDUMP" --triple=riscv64 -d csr.o > csr_objdump.txt
say "csr.o -> csr_objdump.txt   (the second reader's first opinion)"

printf '\n== 3. Zicsr, OUT OF THE BASE ISA, and whether anybody notices ==\n'
# The split is a fact about the DOCUMENTS.  What is measured here is whether
# the toolchain agrees, and the answer is that it does not check: the
# assembler emits a Zicsr instruction under -march=rv64i with no diagnostic,
# and the Tag_RISCV_arch string then records only rv64i2p1.  Three
# attributes, three objects, and the one that was asked for is not the one
# that is in the file.
#
# ALL THREE are disassembled and ALL THREE recordings are committed, not just
# the first.  The section's finding is that the same word 0xc00022f3 appears in
# all three objects -- a Zicsr instruction under `-march=rv64i`, which is the
# base -- and a reader with no cross-compiler can only check that claim if all
# three listings are in the directory.  Recording one of three would have made
# the claim checkable for two thirds of the cases, which is worse than not
# recording any: it looks like evidence.
for m in rv64i rv64i_zicsr rv64i_zicsr_zifencei; do
  "$CLANG" --target="$TARGET" -march="$m" -c only_zicsr.s -o "zicsr_$m.o"
  say "-march=$m -> zicsr_$m.o   $(llvm-readelf-21 -A "zicsr_$m.o" | grep -o 'Value: rv[^ ]*' | sed 's/Value: //')"
  "$OBJDUMP" --triple=riscv64 -d "zicsr_$m.o" > "zicsr_${m}_objdump.txt"
done
say "all three zicsr objects disassembled, and all three listings committed"

printf '\n== 4. the C corpora at four optimisation levels ==\n'
# -O0 through -Os, because the trap convention and the bit tables are the
# SPECIFICATION's and the instruction sequences are the COMPILER's, and the
# only way to tell the two apart is to vary the level and see which numbers
# move.  A number that moves with -O is the compiler's; a number that does
# not is the architecture's.
for f in wrap bits walk; do
  for o in O0 O1 O2 Os; do
    "$CLANG" --target="$TARGET" -march=rv64gc -c -"$o" "$f.c" -o "${f}_$o.o"
  done
  say "$f.c -> ${f}_O0.o ${f}_O1.o ${f}_O2.o ${f}_Os.o"
done

printf '\n== 5. the page-table walk, and the SAME walk with a different LAYOUT ==\n'
# THE EXPERIMENT.  One source file, two builds, and the only difference is
# whether 4 KiB of unrelated data sits between each pair of page tables.
# The relocation count is expected to change and the instruction count is
# expected not to; both numbers are printed by the artifact and neither is
# asserted here.
"$CLANG" --target="$TARGET" -march=rv64gc -c -O2 sp2.c -o sp2_dense.o
say "sp2.c -> sp2_dense.o     (three tables ADJACENT)"
"$CLANG" --target="$TARGET" -march=rv64gc -DSPARSE -DSPARSE_KB=4096 -c -O2 \
    sp2.c -o sp2_sparse.o
say "sp2.c -> sp2_sparse.o    (the same three tables, 4 KiB apart)"
# And the same pair built -fno-pic, because `la` means two different things
# under the two code models and the artifact has to say which it measured.
"$CLANG" --target="$TARGET" -march=rv64gc -fno-pic -c -O2 sp2.c -o sp2_dense_nopic.o
"$CLANG" --target="$TARGET" -march=rv64gc -fno-pic -DSPARSE -DSPARSE_KB=4096 \
    -c -O2 sp2.c -o sp2_sparse_nopic.o
say "sp2.c -> sp2_dense_nopic.o sp2_sparse_nopic.o   (-fno-pic, both layouts)"

printf '\n== 6. hand-written page-table references, and their RELOCATIONS ==\n'
for pf in "" "-fno-pic"; do
  tag=pic; [ -n "$pf" ] && tag=nopic
  "$CLANG" --target="$TARGET" -march=rv64gc $pf -c pt.s -o "pt_$tag.o"
  say "pt.s -> pt_$tag.o   $pf"
  "$OBJDUMP" --triple=riscv64 -d -r "pt_$tag.o" > "pt_${tag}_objdump.txt"
  "$READELF" -r "pt_$tag.o" > "pt_${tag}_relocs.txt"
done

printf '\n== 7. the PAIRING DISTANCE, one object per distance ==\n'
# The psABI pairs an R_RISCV_PCREL_LO12 with an R_RISCV_PCREL_HI20 in the
# same 4 KiB region.  The ASSEMBLER does not enforce it -- the artifact
# prints how many HI20 records each of these six objects has, and every one
# of them has one, including the two whose LO12s are 8 KiB apart.  Whether
# a LINKER would accept them is quoted, because there is no RISC-V linker on
# this host and no way to find out.
for d in 0x0 0x40 0x800 0xffc 0x1000 0x2000; do
  sed "s/^#PADLINE#\$/        .space  $d, 0x01/" sp.s > "sp_$d.s"
  "$CLANG" --target="$TARGET" -march=rv64gc -fno-pic -c "sp_$d.s" -o "sp_$d.o"
  "$READELF" -r "sp_$d.o" > "sp_$d.relocs"
  say "pad=$d sp_$d.o   sp_$d.relocs"
done
# the second pass, now that the .relocs files exist and the counts can be
# printed rather than guessed
for d in 0x0 0x40 0x800 0xffc 0x1000 0x2000; do
  say "  pad=$d  HI20=$(grep -c R_RISCV_PCREL_HI20 "sp_$d.relocs")  LO12_I=$(grep -c R_RISCV_PCREL_LO12_I "sp_$d.relocs")  span=$(awk '/PCREL_LO12_I/{print $1}' "sp_$d.relocs" | sort | tail -1)"
done
rm -f sp_0x*.s

printf '\n== 8. the per-line REFUSALS, which are measurements too ==\n'
# A refusal is the cheapest possible proof that a value is out of range, and
# it is a different kind of claim from "the manual says the field is twelve
# bits".  The artifact runs these one at a time and prints the result.
for src in 'csrr t0, 0x7ff' 'csrr t0, 0x800' 'csrr t0, 0xfff' 'csrr t0, 0x1000' \
           'csrr t0, utvec' 'csrr t0, sieh' 'csrw mstatus, t0' \
           'csrw cycle, t0' 'csrwi 0x1000, 5' 'csrrs t0, 0xfff, t1'; do
  printf '        %s\n        ret\n' "$src" > _one.s
  if "$CLANG" --target="$TARGET" -march=rv64gc -c _one.s -o _one.o 2>_one.err; then
    say "ACCEPTED  $src"
  else
    say "REFUSED   $src   -- $(head -1 _one.err | sed 's/.*error: //' | cut -c1-58)"
  fi
done
rm -f _one.s _one.o _one.err

if [ "${1:-}" = "--only" ]; then
  printf '\n== 9. --only: the corpus is built, the artifact was not run ==\n\n'
  exit 0
fi

printf '\n== 9. run the artifact ==\n'
python3 rvpriv.py --run | tee rvpriv.out
say "rvpriv.out  written"

printf '\n== 10. two runs of the same thing, to show the determinism ==\n'
python3 rvpriv.py --run > run1.txt
python3 rvpriv.py --run > run2.txt
if cmp -s run1.txt run2.txt; then
  say "run1.txt and run2.txt are BYTE-IDENTICAL"
else
  say "run1.txt and run2.txt DIFFER -- a measurement that moves between runs"
  say "is a measurement with a machine in it, and the difference is here:"
  diff run1.txt run2.txt | head -40
fi

printf '\n== 11. the harness, which reads the recorded output and re-asks ==\n'
python3 crosscheck.py rvpriv.out
