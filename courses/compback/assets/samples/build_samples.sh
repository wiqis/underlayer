#!/usr/bin/env bash
# build_samples.sh -- produce every byte the compback course makes a claim
# about, then run the whole artifact and both of its harnesses.
#
#   ./build_samples.sh          build the corpus, run the artifact, run both
#                                harnesses, and check determinism
#   ./build_samples.sh --only   build the corpus and stop
#
# THE TOOLCHAIN IS THINNER HERE THAN IN THE FOUR PER-ARCHITECTURE COURSES,
# and the asymmetry is the whole reason this course could be written at all:
#
#   * x86-64 COMPILES, LINKS AND RUNS.  There is a cc, there is an ld, and
#     the machine is an x86-64.  §KEEP§ THAT MEANS THE REGISTER-ALLOCATION
#     SECTION CAN PUT A RATIO ON THE COST OF A SPILL, WHICH NO COURSE IN THIS
#     COLLECTION HAS EVER DONE, §KEEP§ AND §KEEP§ IT IS THE ONLY SECTION THAT
#     §KEEP§ MAY USE A TIMING AT ALL.
#   * AArch64 and RISC-V COMPILE AND CANNOT RUN.  §KEEP§ NO
#     §KEEP§ aarch64-linux-gnu-ld, NO riscv64-linux-gnu-ld, NO qemu, NO
#     §KEEP§ spike.  §KEEP§ SO NOT ONE INSTRUCTION THIS COURSE EMITS FOR
#     §KEEP§ THOSE TWO TARGETS IS EVER EXECUTED, AND EVERY CLAIM ABOUT THEM
#     §KEEP§ IS MEASURED-ON-BYTES RATHER THAN MEASURED.
#
# §KEEP§ AND LLVM IS THE ORACLE, NEVER A DEPENDENCY: §KEEP§ THE ARTIFACT
# §KEEP§ PARSES ITS OWN COPY OF THE IR, RUNS ITS OWN SELECTOR, ITS OWN
# §KEEP§ ALLOCATORS, ITS OWN SCHEDULER AND ITS OWN ENCODER, AND USES
# §KEEP§ clang ONLY AS A THING THAT PRODUCES BYTES TO LOOK AT.

set -euo pipefail
cd "$(dirname "$0")"

CLANG=${CLANG:-clang}
OBJDUMP=${OBJDUMP:-llvm-objdump-21}
CC_BIN=${CC:-cc}
TARGETS="x86_64-linux-gnu aarch64-linux-gnu riscv64-linux-gnu"
LEVELS="O0 O1 O2 O3 Os"

say() { printf '  %s\n' "$*"; }

printf '\n== 1. the toolchain, printed because a claim about a decoder needs one ==\n'
say "compiler:    $("$CLANG" --version | head -1)"
say "disassembler: $($OBJDUMP --version | sed -n '2p')"
say "host cc:      $("$CC_BIN" --version | head -1)"
printf '\n'
for t in $TARGETS; do
  if command -v "$t-ld" >/dev/null 2>&1; then
    say "linker:       $("$t-ld" --version | head -1)"
  else
    say "linker:       $t-ld IS NOT INSTALLED"
  fi
done
for emu in qemu-x86_64 qemu-aarch64 qemu-riscv64 spike; do
  if command -v "$emu" >/dev/null 2>&1; then
    say "emulator:     $emu PRESENT"
  else
    say "emulator:     $emu ABSENT"
  fi
done
printf '\n'
say "x86-64 RUNS NATIVELY: sections 6, 7 and 11 may use a TIMING and do."
say "AArch64 and RISC-V CANNOT RUN: sections 4, 5, 9 and 11 for those"
say "two targets are MEASURED-ON-BYTES and MEASURED-ON-BYTES means the"
say "words were emitted and read back and NOTHING MORE HAPPENED TO THEM."

printf '\n== 2. the IR corpus, five levels x three targets ==\n'
# §KEEP§ THE CORPUS IS TEN SMALL FUNCTIONS, §KEEP§ CHOSEN SO THAT THE IR DIFFERS
# §KEEP§ AT EVERY LEVEL: A CALL SO THE BACKEND HAS TO KNOW THE ABI, A LOOP SO
# §KEEP§ THE IR HAS A CONTROL-FLOW EDGE, A REDUCTION SO THE VECTORISER HAS
# §KEEP§ SOMETHING TO VECTORISE, A SWITCH FOR MORE THAN TWO SUCCESSORS, AND A
# §KEEP§ MEMORY OPERAND SO INSTRUCTION SELECTION HAS A MEMORY FORM TO MATCH.
for t in $TARGETS; do
  a=${t%%-*}
  for o in $LEVELS; do
    "$CLANG" --target="$t" -"$o" -S -emit-llvm ir_corpus.c -o "corpus_${a}_${o}.ll"
    "$CLANG" --target="$t" -"$o" -c ir_corpus.c -o "corpus_${a}_${o}.o"
  done
  say "$t -> corpus_${a}_O{0,1,2,3,s}.ll and .o   (10 files)"
done

printf '\n== 3. the ABI leaf, two levels x three targets ==\n'
# §KEEP§ SIX ARGUMENTS AND NOT SEVEN, §KEEP§ BECAUSE THE SIXTH IS STILL IN A
# §KEEP§ REGISTER ON ALL THREE CONVENTIONS AND THE SEVENTH IS THE ONE THAT
# §KEEP§ MOVES TO THE STACK -- §KEEP§ AND HOW MANY ARGUMENTS SPILL IS A FACT
# §KEEP§ ABOUT THE ABI AND NOT ABOUT THE BACKEND, §KEEP§ SO IT IS IN THE
# §KEEP§ COURSE'S LIMITS RATHER THAN IN ITS MEASUREMENT.
for t in $TARGETS; do
  a=${t%%-*}
  for o in O0 O2; do
    "$CLANG" --target="$t" -"$o" -c leaf.c -o "leaf_${a}_${o}.o"
  done
  "$CLANG" --target="$t" -O2 -S leaf.c -o "leaf_${a}_O2.s"
  say "$t -> leaf_${a}_O0.o leaf_${a}_O2.o leaf_${a}_O2.s"
done

printf '\n== 4. the disassembler recordings, one per object ==\n'
# §KEEP§ AND THESE ARE COMMITTED, NOT ONLY GENERATED, §KEEP§ BECAUSE A
# §KEEP§ READER WITH NO CROSS-COMPILER MUST BE ABLE TO CHECK EVERY FIGURE IN
# §KEEP§ SECTIONS 4, 5, 9 AND 11, §KEEP§ AND A CLAIM THAT CAN ONLY BE CHECKED
# §KEEP§ ON THE MACHINE THAT MADE IT IS A CLAIM.
for t in $TARGETS; do
  a=${t%%-*}
  case "$a" in
    x86_64) TR=x86_64 ;;
    *) TR=$a ;;
  esac
  for o in $LEVELS; do
    "$OBJDUMP" --triple="$TR" -d "corpus_${a}_${o}.o" > "corpus_${a}_${o}_objdump.txt"
  done
  for o in O0 O2; do
    "$OBJDUMP" --triple="$TR" -d -r "leaf_${a}_${o}.o" > "leaf_${a}_${o}_objdump.txt"
  done
  say "$t -> 7 objdump recordings"
done

printf '\n== 5. the timing instrument ==\n'
"$CC_BIN" -O2 -o cbbench cbbench.c
./cbbench --out cbbench.out > /dev/null
say "cbbench built and run once into cbbench.out (the raw ticks, which the"
say "report replaces with bands so the report can be byte-identical)."
say "§KEEP§IT MEASURES THE CLOCK TWICE AND THE FLOOR BEFORE"
say "ANYTHING ELSE, AND §KEEP§ IT PRINTS BOTH FLOORS -- THE ESTIMATOR'S"
say "(A POINTER CHASE) AND THE COMPARISON'S (PASS-TO-PASS)."
if command -v taskset >/dev/null 2>&1; then
  say "taskset is present; the instrument pins itself to cpu2 and VERIFIES"
  say "the cpu that answered, so the pinning is a measurement and not a wish."
else
  say "taskset is ABSENT, so the instrument's OWN sched_setaffinity call is"
  say "the only pinning and it prints whether the cpu that answered was the"
  say "one it asked for."
fi

printf '\n== 6. the sibling decoders, which this course BORROWS ==\n'
# §KEEP§ BORROWED AND NOT FORKED.  §KEEP§ TWO HARNESSES THAT BOTH PASS WHILE
# §KEEP§ READING DIFFERENT CODE IS THE FAILURE MODE THIS COLLECTION KEEPS
# §KEEP§ PAYING FOR, SO THIS COURSE FINDS THE SIBLING BY WALKING UP THE TREE
# §KEEP§ AND PREPENDS NOTHING TO IT.
# §KEEP§ FOUND BY WALKING UP THE TREE AND NOT BY A RELATIVE PATH, §KEEP§
# §KEEP§ BECAUSE A HARDCODED `../../a64asm/assets/samples` BREAKS THE FIRST TIME
# §KEEP§ SOMEBODY MOVES A DIRECTORY, §KEEP§ AND A COURSE WHOSE ARTIFACT ONLY
# §KEEP§ RUNS IN THE LAYOUT IT WAS WRITTEN IN IS A COURSE NOBODY CAN RE-RUN.
# §KEEP§ THE SAME FUNCTION IS IN cbabi.py, AND §KEEP§ compback.py USES THAT ONE
# §KEEP§ RATHER THAN A SECOND COPY, §KEEP§ BECAUSE TWO COPIES OF A PATH FINDER
# §KEEP§ ARE TWO ANSWERS TO "WHERE IS THE SIBLING".
find_sibling() {
  local name=$1 sib=$2 d
  d=$(pwd)
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$(dirname "$d")/$sib/assets/samples/$name" ]; then
      printf '%s\n' "$(cd "$(dirname "$d")/$sib/assets/samples" && pwd)"
      return 0
    fi
    d=$(dirname "$d")
    [ "$d" = "/" ] && break
  done
  return 1
}

A64DEC_DIR=$(find_sibling a64dec.py a64asm) || true
RVDEC_DIR=$(find_sibling rvdec.py rvasm) || true
say "a64dec.py found in: ${A64DEC_DIR:-NOT FOUND}"
say "rvdec.py  found in: ${RVDEC_DIR:-NOT FOUND}"
if [ -z "${A64DEC_DIR:-}" ] || [ -z "${RVDEC_DIR:-}" ]; then
  say "FATAL: a sibling decoder is missing, and section 16's two-reader check"
  say "would then compare ZERO words -- which is a check that did not run and"
  say "not a check that passed."
  exit 1
fi

if [ "${1:-}" = "--only" ]; then
  printf '\n== 7. --only: the corpus is built, the artifact was not run ==\n\n'
  exit 0
fi

printf '\n== 7. run the artifact ==\n'
# §KEEP§ AND IT IS NOT ALLOWED TO BE EMPTY.  §KEEP§ THE FIRST VERSION OF THIS
# §KEEP§ LINE WAS `python3 compback.py --run | tee compback.out` WITH NO CHECK,
# §KEEP§ AND ON A RUN WHERE THE DRIVER FAILED THE PIPE WROTE A ZERO-BYTE FILE
# §KEEP§ WHICH WOULD HIDE EVERY CHECK THE HARNESS HAS.
rc=0
python3 compback.py --run compback.out || rc=$?
BYTES=$(wc -c < compback.out)
LINES=$(wc -l < compback.out)
say "compback.out written: $LINES lines, $BYTES bytes"
if [ "$rc" -ne 0 ] || [ "$BYTES" -lt 20000 ]; then
  say "FATAL: compback.py exited $rc and wrote $BYTES bytes.  A report this"
  say "short is not a report, and shipping it would hide every check."
  exit 1
fi
if ! grep -q 'END OF REPORT' compback.out; then
  say "FATAL: compback.out has no END OF REPORT line, so the run did not finish."
  exit 1
fi
say "the run finished, and the file is not empty"

printf '\n== 8. two runs of the same thing, to show the determinism ==\n'
rc=0; python3 compback.py --run run1.txt || rc=$?
[ "$rc" -eq 0 ] || { say "FATAL: the first determinism run exited $rc"; exit 1; }
rc=0; python3 compback.py --run run2.txt || rc=$?
[ "$rc" -eq 0 ] || { say "FATAL: the second determinism run exited $rc"; exit 1; }
if cmp -s run1.txt run2.txt; then
  say "run1.txt and run2.txt are BYTE-IDENTICAL"
else
  say "run1.txt and run2.txt DIFFER -- a measurement that moves between"
  say "runs is a measurement with a machine in it, and the difference is:"
  diff run1.txt run2.txt | head -40
  exit 1
fi
# §KEEP§ AND ALL THREE ARE COMPARED, NOT ONLY THE TWO: §KEEP§ A DETERMINISM
# §KEEP§ CHECK THAT COMPARES TWO OF THREE FILES PASSES WHILE THE THIRD IS EMPTY,
# §KEEP§ WHICH IS EXACTLY THE FAILURE IT WAS ADDED TO CATCH.
if cmp -s compback.out run1.txt; then
  say "and compback.out is byte-identical to both"
else
  say "FATAL: compback.out differs from run1.txt, so the shipped report is"
  say "not one of the runs the determinism check compared."
  exit 1
fi

printf '\n== 9. the harness, which reads the recorded output and re-asks ==\n'
python3 crosscheck.py compback.out

printf '\n== 10. the corruption suite, which asks whether the harness can FAIL ==\n'
# §KEEP§A HARNESS WHOSE CHECKS HAVE NEVER BEEN SEEN TO FAIL IS A RUBRIC, §KEEP§
# §KEEP§AND THIS COLLECTION HAS RETRACTED FOUR OF THEM FOR EXACTLY THAT. §KEEP§
# §KEEP§THIS IS THE ONLY PART OF THIS SCRIPT THAT CAN FAIL WHEN THE HARNESS IS
# §KEEP§GREEN -- WHICH IS THE POINT.
python3 corrupt.py

printf '\n== 11. what was written ==\n'
ls -l compback.out run1.txt run2.txt | sed 's/^/  /'
printf '\n'
say "compback.out, run1.txt and run2.txt are all BYTE-IDENTICAL."
printf '\n'
say "WHAT WAS NOT MEASURED, in one place, so a reader does not have to"
say "assemble it from fifteen sections:"
say "  * no AArch64 or RISC-V instruction was executed"
say "  * the interference-graph COMPLEXITY claims are quoted, not measured"
say "  * the timing harness executes four HAND-WRITTEN bodies, not code this"
say "    course emitted -- it executes what the allocator's DECISIONS imply"
say "  * the schedule in section 8 is a CHECKSUM and a critical path and"
say "    never a TIME, because the only schedule that can be timed is one the"
say "    machine already reordered"
say ""
say "The last of those four is the one a reader is most likely to miss, and"
say "it is why section 10 exists at all."
printf '\n'