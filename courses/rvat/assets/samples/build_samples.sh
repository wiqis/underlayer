#!/usr/bin/env bash
# build_samples.sh -- produce every byte the rvat course makes a claim about.
#
# NOTHING IN THIS COURSE IS A CLAIM ABOUT A FILE THAT DOES NOT EXIST.  This
# script is the whole provenance of the corpus: it assembles three
# hand-written files covering the A extension, the ordering fence and the
# vector configuration instruction, compiles three C files at four
# optimisation levels AND with and without the extension letters, compiles the
# SAME C11 atomics file with and without `a` in -march (which is the course's
# central experiment), measures the x86-64 LOCK list for the contrast, runs
# the per-line REFUSALS, and then runs rvat.py, which reads the result.
#
#   ./build_samples.sh          build the corpus, then run the whole artifact
#   ./build_samples.sh --only   build the corpus, do not run the artifact
#
# AND THE TOOLCHAIN IS THINNER HERE THAN ANYWHERE ELSE IN THIS COLLECTION.
# There is no RISC-V machine on this host, no emulator, and no RISC-V
# binutils: qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld} are all
# ABSENT.  So:
#
#   * there are NO TIMINGS anywhere in this course, and
#   * no reservation is ever HELD, no fence is ever OBSERVED to order
#     anything, no AMO is ever observed to be atomic, and no vector
#     instruction is ever EXECUTED.
#
# THIS COURSE DELIBERATELY HAS NO TIMINGS where its two siblings DID, and the
# difference is worth stating rather than apologising for.  `simd` and `smp`
# taught vectors, atomics and ordering on hardware this collection could run,
# and they measured speedups; `x86simd` measured a lost-update count; and
# `a64simd` measured a 3.89x, a 4.92x and a 27.65x.  NONE of those has a
# counterpart here, because every one of them is a number about something a
# machine DID.  What replaces a ratio is an instruction count, a byte count, a
# bit position, and the sentence that a count does not know whether the
# instruction is fast.  `rvabi` and `rvpriv`, the two RISC-V courses before
# this one, lost the ability to TIME; this course loses it too, and it says so
# in its own header rather than in a paragraph at the end.

set -euo pipefail

# `set -e` IS DELIBERATELY KEPT.  §KEEP§THE STATUS OF THE ARTIFACT IS CAPTURED
# WITH `rc=0; python3 rvat.py --run > rvat.out || rc=$?` RATHER THAN WITH `set +e`,
# BECAUSE TURNING `set -e` OFF AROUND ONE COMMAND MEANS EVERY LATER COMMAND IN A
# 270-LINE SCRIPT IS RUNNING WITHOUT IT AND NOBODY WILL REMEMBER WHICH.
cd "$(dirname "$0")"

CLANG=${CLANG:-clang}
OBJDUMP=${OBJDUMP:-llvm-objdump-21}
READELF=${READELF:-llvm-readelf-21}
MC=${MC:-llvm-mc-21}
TARGET=${TARGET:-riscv64-linux-gnu}
LEVELS="O0 O1 O2 O3 Os"

say() { printf '  %s\n' "$*"; }

# THE -Wno-atomic-alignment FLAG, and it is a MEASUREMENT rather than a
# convenience.  Cross-compiling without a RISC-V sysroot, clang cannot ask the
# target what its atomic granularity is, so it reports `the max lock-free size
# (0 bytes)` for every 4-byte atomic -- and then, correctly, emits an inline
# `amoadd.w.aqrl` anyway once the `a` extension is present.  §KEEP§A COMPILER
# WARNING CAN BE ABOUT WHAT IT DOES NOT KNOW RATHER THAN ABOUT WHAT YOU ASKED
# FOR, AND THE WAY TO TELL IS TO READ WHAT IT EMITTED.  The warning text is
# captured in amo_warnings.txt so a reader can check it rather than take it on
# trust.
ATOMIC_WARN=(-Wno-atomic-alignment)

printf '\n== 1. the toolchain, printed because a claim about a decoder needs one ==\n'
say "assembler:    $("$CLANG" --version | head -1)"
say "disassembler: $($OBJDUMP --version 2>/dev/null | sed -n '2p')"
say "readelf:      $($READELF --version 2>/dev/null | sed -n '2p')"
say "x86 asm:      $($MC --version 2>/dev/null | sed -n '2p')"
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
say "NOTHING IN THIS COURSE IS EVER EXECUTED.  No reservation is ever HELD,"
say "no AMO is ever observed to be atomic, no fence is ever OBSERVED to order"
say "anything, and no vector instruction is ever RUN.  Every figure below is a"
say "bit pattern, a count of bit patterns, an arithmetic identity, or a"
say "refusal from a real assembler.  There are NO TIMINGS and NO SPEEDUPS."
say "The sibling x86-64 courses' ratios have NO COUNTERPART HERE."

printf '\n== 2. the hand-written ENCODING corpus ==\n'
# Three files, one concern each, and the split is the reason the artifact can
# say "the eleven operations" and "the four fields of fence" without either
# number depending on the other file.  All THREE are disassembled by the
# SECOND READER and all three listings are committed, so a reader with no
# cross-compiler can still check every byte claim in the course.
"$CLANG" --target="$TARGET" -march=rv64gcv -c amo.s   -o amo.o
say "amo.s   -> amo.o   (18 operations x 2 widths, 4 reservation-pair forms,"
say "                       20 aq/rl forms, 6 discard forms -- 52 instructions)"
"$OBJDUMP" --triple=riscv64 -d amo.o > amo_objdump.txt
say "amo.o   -> amo_objdump.txt   (the second reader's first opinion)"

"$CLANG" --target="$TARGET" -march=rv64gcv -c fence.s -o fence.o
say "fence.s -> fence.o (34 fences: the four fields swept, every accepted"
say "                       SPELLING of pred and succ, and fence.tso/fence.i)"
"$OBJDUMP" --triple=riscv64 -d fence.o > fence_objdump.txt
say "fence.o -> fence_objdump.txt"

"$CLANG" --target="$TARGET" -march=rv64gcv -c vec.s   -o vec.o
say "vec.s   -> vec.o   (112 vsetvli variants, 10 vsetivli/vsetvl, 5 AVL"
say "                       forms, 22 mask pairs, 9 group forms, 8 mask forms)"
"$OBJDUMP" --triple=riscv64 -d vec.o > vec_objdump.txt
say "vec.o   -> vec_objdump.txt"

printf '\n== 3. the CENTRAL EXPERIMENT: the same C11 file, with and without `a` ==\n'
# THE EXPERIMENT.  One source file, two builds, and the ONLY difference is
# whether the `a` letter is in -march.  The claim is that the compiler turns
# four of its functions into a LIBRARY CALL without the extension and into
# inline lr/sc and amo* instructions with it.  Both numbers are printed by the
# artifact and neither is asserted here.
#
# rv64im is the BASE for this experiment and not rv64i, for a reason worth
# recording: `amo.c` is pure integer code, so M costs it nothing, and using
# rv64im rather than rv64i removes a confound (whether the absent extension is
# A or something else) from a comparison whose whole point is that ONE letter
# is what changed.
"$CLANG" --target="$TARGET" -march=rv64im    "${ATOMIC_WARN[@]}" -c -O2 amo.c -o amo_noa_O2.o
say "amo.c -march=rv64im  -> amo_noa_O2.o"
"$CLANG" --target="$TARGET" -march=rv64ima   "${ATOMIC_WARN[@]}" -c -O2 amo.c -o amo_a_O2.o
say "amo.c -march=rv64ima -> amo_a_O2.o     (ONE letter different)"
"$OBJDUMP" --triple=riscv64 -d amo_noa_O2.o > amo_noa_O2_objdump.txt
"$OBJDUMP" --triple=riscv64 -d amo_a_O2.o   > amo_a_O2_objdump.txt
say "both disassembled; lr/sc/amo* counts printed by the artifact"
# AND THE WARNING TEXT, captured rather than suppressed and forgotten:
"$CLANG" --target="$TARGET" -march=rv64ima -c -O2 amo.c -o /dev/null 2> amo_warnings.txt || true
say "the assembler's own warning about atomic granularity is in amo_warnings.txt"

# And the whole -march sweep, so "the extension is one letter" is a TABLE and
# not a sentence.  This is the measurement rvasm's `rv-isa` already made for
# the ISA STRING; here it is made for the INSTRUCTIONS, and the finding is the
# opposite of that course's -- the string does not notice and the instructions
# change completely.
for m in rv64i rv64im rv64ima rv64imac rv64imafd rv64gc; do
  "$CLANG" --target="$TARGET" -march="$m" "${ATOMIC_WARN[@]}" -c -O2 amo.c -o "amo_march_$m.o" 2>/dev/null \
    && say "  -march=$m -> amo_march_$m.o   ISA string: $(llvm-readelf-21 -A "amo_march_$m.o" 2>/dev/null | grep -o 'Value: rv[^ ]*' | sed 's/Value: //')"
done

printf '\n== 4. the C11 ORDERS, and what the compiler chose for each ==\n'
"$CLANG" --target="$TARGET" -march=rv64gc "${ATOMIC_WARN[@]}" -c -O2 fence.c -o fence_c_O2.o
"$OBJDUMP" --triple=riscv64 -d fence_c_O2.o > fence_c_O2_objdump.txt
say "fence.c -> fence_c_O2.o -> fence_c_O2_objdump.txt"
say "  six C11 fence strengths, four load strengths, three store strengths,"
say "  and four RMW strengths -- 17 functions, and the artifact prints the"
say "  fence each one became"
for o in O0 O1 O2 O3; do
  "$CLANG" --target="$TARGET" -march=rv64gc "${ATOMIC_WARN[@]}" -c "-$o" fence.c -o "fence_c_$o.o"
done
say "fence.c at -O0 -O1 -O2 -O3"

printf '\n== 5. the VECTOR loops at four levels, with and without `v` ==\n'
# The comparison is CLEAN and the reason it is clean is worth stating: both
# builds are at -march=rv64gc, which already contains the C extension, so
# nothing about compression changes between them and the ONLY difference is
# the `v`.  An earlier draft compared rv64g against rv64gcv and had to retract
# the number, because dropping `c` as well as adding `v` confounds the two.
for f in vec; do
  for o in $LEVELS; do
    "$CLANG" --target="$TARGET" -march=rv64gc  -c "-$o" "$f.c" -o "${f}_noV_$o.o"
    "$CLANG" --target="$TARGET" -march=rv64gcv -c "-$o" "$f.c" -o "${f}_V_$o.o"
    "$OBJDUMP" --triple=riscv64 -d "${f}_V_$o.o" > "${f}_V_${o}_objdump.txt"
    "$OBJDUMP" --triple=riscv64 -d "${f}_noV_$o.o" > "${f}_noV_${o}_objdump.txt"
  done
  say "$f.c -> ${f}_noV_*.o ${f}_V_*.o at $LEVELS   (BOTH keep the C extension)"
done
# And the ISA strings, which is the point: the vector build's string grows by
# the `v1p0` and the zvl/zve entries and the scalar one does not, so the
# attribute DOES record the vector extension even though it did not record
# Zicsr in the previous course's finding.  Both halves of that are printed.
say "  ISA string with v : $(llvm-readelf-21 -A vec_V_O2.o | grep -o 'Value: rv[^ ]*' | sed 's/Value: //')"
say "  ISA string without: $(llvm-readelf-21 -A vec_noV_O2.o | grep -o 'Value: rv[^ ]*' | sed 's/Value: //')"

printf '\n== 6. the x86-64 LOCK list, measured so the ZERO is a CONTRAST ==\n'
# The contrast has to be measured or it is a footnote.  `llvm-mc-21` is a
# SECOND reader for the x86-64 side and it is on this host, so every one of the
# twenty-two `lock` lines in lock86.s is assembled for real and the count is
# read out of its output.
"$MC" -triple=x86_64 -assemble -show-encoding lock86.s > lock86_listing.txt 2>&1 || true
say "lock86.s -> lock86_listing.txt   $(grep -c '^\s*lock' lock86_listing.txt) lock-prefixed instructions accepted, 1 implicit"
say "  and a LOCK BT is in the file because the SDM's eighteen does NOT list"
say "  it -- and the assembler ACCEPTS it, which is the trap the section is"
say "  about and the reason the eighteen are quoted rather than counted"

printf '\n== 7. the per-line REFUSALS, which are measurements too ==\n'
# A refusal is the cheapest possible proof that a value is out of range or
# that a mnemonic does not exist, and it is a different kind of claim from
# "the manual says the field is five bits".  The artifact runs these one at a
# time and prints each result.
for src in 'lr.w a0, a1, (a2)' 'sc.w a0, (a1)' 'amoadd.w a0, (a1)' \
           'amoadd.b a0, a1, (a2)' 'lr.w.t a0, (a1)' 'sc.w.t a0, a1, (a2)' \
           'fence r, r, 0' 'fence r, r, 0x7' 'fence.tso, rw, rw' 'fence.i, r, r' \
           'vsetvli t0, a1, e32, m1' 'vsetvli t0, a1, e1024, m1, ta, ma' \
           'vsetvli t0, a1, e32, m16, ta, ma' 'vsetvli t0, a1, e32, m1, xx, ma' \
           'vsetvl t0, a1, a2, a3' 'vl2r.v v1, (a0)' 'vs2r.v v1, (a0)' \
           'vadd.vv v1, v2, v3, v1.t' 'vmsne.vi v1, v2, 0' 'lock add a0, a1, a2' \
           'fence rrw, rw'; do
  printf '        %s\n        ret\n' "$src" > _one.s
  if "$CLANG" --target="$TARGET" -march=rv64gcv -c _one.s -o _one.o 2>_one.err; then
    say "ACCEPTED  $src"
  else
    say "REFUSED   $src   -- $(head -1 _one.err | sed 's/.*error: //' | cut -c1-52)"
  fi
done
rm -f _one.s _one.o _one.err

printf '\n== 8. the fence SPELLING sweep, one assembler call per candidate ==\n'
# Every non-empty subset of {i, o, r, w} is a spelling the assembler might
# accept, and there are fifteen of them.  The artifact sweeps all fifteen and
# prints the four-bit code each one gets, so "the sets are NAMED and not
# arbitrary" is a measurement of the assembler rather than a claim about a
# manual.
python3 - <<'PY'
import itertools, os, re, subprocess
letters = 'iorw'
rows = []
for n in range(1, 5):
    for combo in itertools.combinations(letters, n):
        sp = ''.join(combo)
        with open('_sp.s', 'w') as f:
            f.write('\tfence %s, rw\n\tret\n' % sp)
        r = subprocess.run(['clang', '--target=riscv64-linux-gnu', '-march=rv64gc',
                            '-c', '_sp.s', '-o', '_sp.o'], capture_output=True, text=True)
        if r.returncode == 0:
            o = subprocess.run(['llvm-objdump-21', '--triple=riscv64', '-d', '_sp.o'],
                               capture_output=True, text=True)
            m = re.search(r':\s+([0-9a-f]{8})\s', o.stdout)
            w = int(m.group(1), 16)
            rows.append((sp, '%08x' % w, '%d' % ((w >> 24) & 0xf)))
        else:
            err = [l for l in r.stderr.splitlines() if 'error:' in l]
            msg = err[0].split('error:', 1)[1].strip()[:44] if err else '?'
            rows.append((sp, 'REFUSED', msg))
os.remove('_sp.s')
if os.path.exists('_sp.o'):
    os.remove('_sp.o')
print('  %-6s %-10s %s' % ('letter', 'word', 'pred'))
for a, b, c in rows:
    print('  %-6s %-10s %s' % (a, b, c))
print('  %d spellings probed, %d accepted' % (len(rows),
                                              sum(1 for _a, b, _c in rows if b != 'REFUSED')))
PY

if [ "${1:-}" = "--only" ]; then
  printf '\n== 9. --only: the corpus is built, the artifact was not run ==\n\n'
  exit 0
fi

printf '\n== 9. run the artifact ==\n'
# AND IT IS NOT ALLOWED TO BE EMPTY.  §KEEP§THE FIRST VERSION OF THIS LINE WAS
# `python3 rvat.py --run | tee rvat.out` WITH NO CHECK, AND ON A RUN WHERE THE
# DRIVER FAILED THE PIPE WROTE A ZERO-BYTE FILE -- WHICH HID 557 OF THE HARNESS'S
# CHECKS BEHIND A FILE THAT LOOKED LIKE A RESULT.  §KEEP§AN OUTPUT FILE WHOSE
# SIZE IS NOT ASSERTED IS A FILE WHOSE FAILURE IS INVISIBLE, AND THE
# ASSERTION IS TWO LINES AND COSTS NOTHING.
rc=0
python3 rvat.py --run > rvat.out || rc=$?
RC=$rc
BYTES=$(wc -c < rvat.out)
LINES=$(wc -l < rvat.out)
say "rvat.out written: $LINES lines, $BYTES bytes"
if [ "$RC" -ne 0 ] || [ "$BYTES" -lt 20000 ]; then
  say "FATAL: rvat.py exited $RC and wrote $BYTES bytes.  A report this short is"
  say "not a report, and shipping it would hide every check the harness has."
  exit 1
fi
if ! grep -q 'END OF REPORT' rvat.out; then
  say "FATAL: rvat.out has no END OF REPORT line, so the run did not finish."
  exit 1
fi
say "the run finished, and the file is not empty"

printf '\n== 10. two runs of the same thing, to show the determinism ==\n'
rc=0; python3 rvat.py --run > run1.txt || rc=$?
[ "$rc" -eq 0 ] || { say "FATAL: the first determinism run exited $rc"; exit 1; }
rc=0; python3 rvat.py --run > run2.txt || rc=$?
[ "$rc" -eq 0 ] || { say "FATAL: the second determinism run exited $rc"; exit 1; }
if cmp -s run1.txt run2.txt; then
  say "run1.txt and run2.txt are BYTE-IDENTICAL"
else
  say "run1.txt and run2.txt DIFFER -- a measurement that moves between runs"
  say "is a measurement with a machine in it, and the difference is here:"
  diff run1.txt run2.txt | head -40
  exit 1
fi
# AND ALL THREE ARE COMPARED AGAINST EACH OTHER, not only the two.  §KEEP§A
# DETERMINISM CHECK THAT COMPARES TWO OF THE THREE FILES IS A CHECK THAT PASSES
# WHILE THE THIRD IS EMPTY, WHICH IS EXACTLY THE FAILURE IT WAS ADDED TO CATCH.
if cmp -s rvat.out run1.txt; then
  say "and rvat.out is byte-identical to both"
else
  say "FATAL: rvat.out differs from run1.txt, so the shipped report is not one"
  say "of the runs the determinism check compared."
  exit 1
fi

printf '\n== 11. the harness, which reads the recorded output and re-asks ==\n'
python3 crosscheck.py rvat.out

printf '\n== 12. and the corruption suite, which asks whether the harness can FAIL ==\n'
# §KEEP§A HARNESS WHOSE CHECKS HAVE NEVER BEEN SEEN TO FAIL IS A RUBRIC, AND THIS
# COLLECTION HAS RETRACTED FOUR OF THEM FOR EXACTLY THAT.  §KEEP§THE SUITE
# CORRUPTS THE RECORDED REPORT THIRTY-FOUR WAYS AND ASSERTS THAT EVERY ONE IS
# CAUGHT, AND IT IS THE ONLY PART OF THIS SCRIPT THAT CAN FAIL WHEN THE HARNESS
# IS GREEN -- WHICH IS THE POINT.
python3 corrupt.py