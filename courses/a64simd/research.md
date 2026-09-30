# The AArch64 Data Path: NEON, Atomics and Ordering — research log

Every number in this course was measured on this machine, with these tools,
**before** it was written. Claims that did not survive measurement were
**retracted rather than softened**, and all twenty-seven retractions are
printed by the artifact in section 13 and asserted as text by `crosscheck.py`
group O, so that they can be neither quietly dropped nor edited into being
right.

**Seven of the twenty-seven are about the artifact's own comparison rather than
about the architecture, and they are the best material in the course.** All
seven were found by ONE change: fixing a normaliser so that it stopped deleting
operands. Eighty-five real decoder defects were sitting behind a comparison
that had silently stopped comparing, and the printed disagreement count was
`0` the entire time. Not one of the seven printed a wrong word. That is the
argument for the whole collection in one sentence: **the interesting failures
here were not in the architecture, they were in what a number means.**

## The machine

| | |
|---|---|
| Host CPU | x86-64 (the exact model is irrelevant to this course and was not recorded) |
| **AArch64 machine** | **NONE.** No board, no emulator, no hypervisor, no cross-run |
| `aarch64-linux-gnu-ld` | **ABSENT** — no AArch64 linker |
| `qemu-aarch64` | **ABSENT** — no AArch64 emulator |
| `aarch64-linux-gnu-as` | **ABSENT** — **no second AArch64 assembler** |
| `aarch64-linux-gnu-gcc` | **ABSENT** — no AArch64 GCC |
| Assembler | clang 21.1.8 (6ubuntu1) integrated assembler, `--target=aarch64-linux-gnu` |
| Second reader | `llvm-objdump-21`, same LLVM tree — see below |
| Third reader | `struct.unpack_from` for the ELF section headers; **no library** |
| Kernel | the host's; irrelevant, because nothing here is executed |

Four absences decide what this course may claim at all, and they are printed in
the artifact's own section 1 **before** the first measurement.

1. **NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN.** Every figure is a bit
   pattern, a count of bit patterns, an arithmetic identity over a field
   width, or a **refusal from a real assembler**. No duration, no fault, no
   throughput, no portability claim.
2. **THERE ARE NO TIMINGS, AND THE x86-64 FIGURES ARE REFUSED BY NAME.** The
   sibling course measured 3.89×, 4.92× and 27.65×; the two neutral courses
   measured 3.89× at 2 KiB against 1.14× at 24 MiB (`simd`) and an uncontended
   `lock xadd` at 2.54× a plain store (`smp`). **Not one of those has a
   counterpart here**, because a ratio cannot be manufactured from a corpus of
   bit patterns and the honest alternative to a number is not a smaller number.
   Where a page of this course would naturally carry a ratio it carries an
   instruction count and says so — and section 5 measures one that points in
   the **opposite** direction to the one a reader expects.
3. **THE TWO READERS COME FROM ONE LLVM TREE.** `llvm-objdump-21` and
   clang 21.1.8 are one program. So the two-reader cross-check establishes
   **AGREEMENT and not correctness**, and every "refusal" in the file is a
   refusal by *one assembler at one version* rather than by the architecture.
   A reader who reads that as a property of the architecture has made the
   mistake the file exists to prevent.
4. **THE FEATURE BITS ARE UNREADABLE.** The ID registers that say whether an
   implementation has LSE, SVE, FP16 or AES are **EL1 registers**, and there
   is no EL1 here. So "is this word valid on the machine in front of me" is not
   a question this host can answer, and the five refusals that name a feature
   are the *assembler's* answer rather than the architecture's.

## What the eleven courses before it left open

The rule is in `docs/aarch64-section-plan.md`: *"the comparison lives in the
neutral courses; the depth lives in the per-arch ones."* Two neutral courses own
the principles and are **linked, not repeated**:

- **`simd`** owns the principle that a wider vector is not automatically
  faster, and measured 3.89× at 2 KiB against 1.14× at 24 MiB. This course
  does not re-measure it and says so in section 5's own words.
- **`smp`** owns contended atomics, and measured an uncontended `lock xadd` at
  2.54× a plain store and the contended one at 21.20× the floor. Section 6
  links rather than restating, because the numbers are durations and this
  course has no counterpart of either.

The x86-64 sibling owns the same subject **with** hardware, which is the
contrast this course is built to make legible: identical question, two
architectures, and the one with a clock can say 3.89× while the one without can
only count. Neither is the better course. The one with hardware is more useful
to a reader who wants a number; the one without is the only one that can show
where the number came from.

## The measurements, and how each was obtained

Every one of these is reproduced by a command in the artifact, and every one is
in `a64data.out`, `run1.txt` and `run2.txt` — which are **byte-identical**, so
the run is deterministic and a reader can check any of it with `diff`.

| what | how | the finding |
|---|---|---|
| The Q bit | assemble `ldr b0,q0,s0,d0` and XOR | `ldr b0` and `ldr q0` differ in **bit 23** and no other bit; `ldr b0` and `str b0` in bit 22 |
| The float type | assemble `fadd s0,s1,s2` and `fadd d0,d1,d2` | differ in **bit 22** alone, so the type is `bits[23:22]` |
| The third type | `fadd h0,h1,h2` at baseline, then `+fp16` | REFUSED with "instruction requires: fullfp16", then `0x1ee22820` — **two** bits from the `s` form |
| 128-bit arithmetic | `fadd q0,q1,q2` | does not exist; `fadd v0.4s` is `0x4e22d420`, **six** bits from the scalar form |
| The field map | 45 positions over 47 cases, 2 refusals | the same four element sizes at `bits[31:30]`+bit 23, `bits[23:22]`+bit 30, `bits[11:10]`+bit 30, and `bits[23:22]` with **no Q bit** |
| SVE's missing field | five compiles, `-msve-vector-bits` 128…2048 | **five identical words**, `0x04c00020` — ×16 in vector length, not one bit |
| The SVE operation | twelve assembles | a **six-bit** field at `bits[21:16]`, twelve names, class byte `0b00000100` for all twelve |
| The acquire bit | five XORs of the exclusive family | **bit 15**, one bit, the same bit in a load and a store |
| Bit 21 | read across thirteen words | 0 in every single-register word, 1 in every pair word — the **pair discriminator** |
| The LSE ordering bits | four suffixes swept in **each** half | CAS: 22 and 15. LDADD: **23 and 22**. Bit 21 constant in both. **R21** |
| CASP's width | `cas` vs `casp` | 128-bit-ness is **bit 23** — the bit that means acquire in the other half |
| The barrier fields | 12 options × 3 barriers | option is `bits[11:8]`, four bits, **twelve** names; identity is `bits[7:5]`, three bits |
| `clrex` | read `op2` | `0b010`, in the barrier group, used by **no** barrier |
| The barrier census | 12 C11 atomic functions, 4 optimisation levels, 13 `.s` files | **3 barriers**, all in fence functions; acquire load and seq_cst load are the same `ldar` |
| The 16-byte case | `pair.c` at two `-march` levels | 7 instructions per attempt at baseline; 2 `ldaddal` for a fetch-add at `+lse` |
| PSTATE.PAN | `msr PSTATE.PAN, x1` | REFUSED by **name**; `msr S3_3_C4_C0_2, x1` accepted, and the two are the same 32 bits |
| The instruction counts | 6 functions × {vectorised, scalar} | the vectorised `sum_loop` is **34 against 12** — the count points the wrong way |
| The round trip | 41 entries × three parties | the spec, the transcribed table and the assembler agree **41 of 41** |
| The corpus pass | 1038 words, two readers | 1031 named, **0 disagreements** — and three poisons that each move their own number |

## The seven that a comparison found

The most important table in the log, and the one that is not about AArch64.

| | the normaliser bug | what it hid | the general form |
|---|---|---|---|
| R22 | comma split ignored brackets, then the operand list was truncated after its first element | **85** disagreements | both readers lost the same operand, so they agreed |
| R23 | scaled `imm12` was multiplied by the access size in **bits** | `[sp, #96]` where the offset is 12 | a unit mistake produces a plausible number, not an error |
| R24 | CCMP printed `bits[4:0]` as a register and Rm as the immediate | swapped NZCV and condition | two adjacent fields, both printed by every disassembler |
| R25 | `imm5 >> 1` for a field that is not a shift of the index | `v1.s[6]` where the lane is 1 | a wrong **number** in the legal range is invisible from the inside |
| R26 | the 64-bit MOVI form was **declined** with a true reason about the wrong field | the form was not modelled at all | a decoder that declines is the safest kind of wrong, and it hides |
| R27 | one poison, which moved the named count and not the disagreement count | the control could not fail | a control that cannot move its number is a comment saying POISONED |
| R21 | the LSE ordering bits were read at the wrong positions | `ldadd` printed as `ldaddl` | a wrong constant and a constant **field** look identical |

Four of those seven are **about the comparison**, and that is the finding.
Every number in section 11 is a number about a *comparison* as well as about
the decoder, and the two can drift apart without anything failing. The course's
answer is structural: **three poisons, one per reported number, each required
to move the number it claims to test, and a `[POISON FAILED]` line the harness
requires to be absent.**

## The toolchain checks that were run before writing anything

- `clang --target=aarch64-linux-gnu -S -x c /dev/null` — works
- `clang --target=aarch64-linux-gnu -march=armv8.1-a` — works (FEAT_LSE)
- `clang --target=aarch64-linux-gnu -march=armv8.2-a+sve` — works (SVE)
- `clang --target=aarch64-linux-gnu -march=armv8.2-a+fp16` — works
- `llvm-objdump-21` — present, and the second reader
- `llvm-readelf-21` — present
- `aarch64-linux-gnu-ld`, `qemu-aarch64`, `aarch64-linux-gnu-as`,
  `aarch64-linux-gnu-gcc` — **all absent**, and the artifact checks and prints
  that rather than asserting it
- `.inst` — **works**, which is what made the 40-probe byte-mask sweep of the
  64-bit MOVI possible; a `.word` directive is *not* decoded by
  `llvm-objdump` and a first attempt used it and reported "the two readers
  never agree" on all 41 rows, which was a refusal to decode being read as a
  disagreement

## What this course cannot establish, in one list

1. That any instruction in it has ever run.
2. That a wider vector is faster, or slower, than a narrower one, or than
   anything on any other architecture.
3. That a `seq_cst` load is one instruction wide or four, or that a `seq_cst`
   store needs a barrier — only that clang emits no barrier and that `ldar`
   decodes with bit 15 set.
4. That an exclusive store ever fails, or that the loop is necessary — only
   that the compiler writes one and that the status register is where the
   decision comes from.
5. That DMB, DSB and ISB order anything, or that the four option bits mean what
   the manual says they mean.
6. That this machine has LSE, SVE, FP16, AES or RCPC, since the ID registers
   are EL1 registers.
7. That PSTATE.PAN does anything at all.
8. That `llvm-objdump` agrees with silicon. It is a second **reader** and both
   readers come from one LLVM tree.
9. That the coverage figures describe the architecture; they describe **five
   object files compiled from two C files by one compiler** — and one of them
   was missing for most of the artifact's life, which is why the corpus list is
   now a named constant with the omission recorded beside it.

## What a reader CAN check, with a hex editor

- Every bit pattern in this course, in an object file on this disk.
- Every field position, by re-running the sweep in section 3 — 45 positions
  over 47 cases, 2 refusals.
- Every instruction count, in a `.s` file on this disk.
- Every refusal, by running clang with the same flag.
- The arithmetic: five vector lengths and one identical 32-bit word, two bits
  for five access sizes, four bits for twelve barrier options, one bit for
  acquire, and `imm8 = (esz/8) · (2·index + 1)` over thirty lanes.
- The three labels on every claim, which is a claim about a sentence and so is
  checkable by reading — and which is now counted by the harness, because
  a label rendered two ways is not a label.

That is the shape of a course with no hardware: **a small set of claims you can
check with a hex editor, and a larger set you have to take on the word of a
document — and an exact statement of which is which.** A course with hardware
would have the second set too, labelled MEASURED, and would be worth more for
the parts that need it.

## Files

| | |
|---|---|
| `a64data.py` | the artifact, 14 sections, 4,100+ lines, 20 models of its own |
| `crosscheck.py` | 268 checks in 16 groups; reads the **shipped** output, needs no toolchain |
| `a64data.out`, `run1.txt`, `run2.txt` | three **byte-identical** recorded runs |
| `build_samples.sh` | 13 files from two C files, POSIX, `set -e` |
| `data.c`, `pair.c` | the corpus. `pair.c`'s `aligned(16)` is **load-bearing** and the comment says so |
