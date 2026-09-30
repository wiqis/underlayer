# The AArch64 Procedure Call Standard — research log

Every number on all five pages of this course was measured before it was written,
on this machine, with these tools, by `assets/samples/a64abi.py`. Claims that did
not survive either a quotation of the AAPCS64 or a measurement of a compiler
were **retracted rather than softened**, and all seven retractions are printed by
the artifact in section 11 and asserted *as text* by `crosscheck.py` group L, so
that they can be neither quietly dropped nor edited into being right.

## The machine — and what is missing from it

| | |
|---|---|
| Host CPU | x86-64. **No AArch64 silicon.** Nothing in this course was executed. |
| Compiler | `Ubuntu clang version 21.1.8 (6ubuntu1)`, `--target=aarch64-linux-gnu` |
| Disassembler | `Ubuntu LLVM version 21.1.8` (`llvm-objdump-21 --triple=aarch64 -d`) |
| Unwinder | `llvm-readelf-21 --unwind` |
| AArch64 linker | **`aarch64-linux-gnu-ld` is NOT INSTALLED** |
| AArch64 emulator | **`qemu-aarch64` is NOT PRESENT** |
| Python | 3.x, standard library only, plus one imported sibling file |
| Determinism | two runs of `a64abi.py --run` are **byte-identical** (1417 lines, 147 657-byte source) |

Two absences decide what this course may claim at all, and the artifact prints
them in **section 1, before the first measurement**, rather than in a limits block
at the end:

1. **No AArch64 machine, no emulator, no linker.** Not one instruction in this
   course has been run. Every number is a **bit pattern**, a **count of bit
   patterns**, an **arithmetic identity over the immediates a compiler emitted**,
   or a **refusal from a real assembler**. There is no duration, no fault, no
   throughput and no portability claim in the artifact or on any page.
2. **No second AArch64 assembler.** `clang` assembled the corpus and
   `llvm-objdump-21` disassembled it, so both readers come from one LLVM tree.
   The cross-check establishes that this decoder and one other piece of software
   agree on what the bytes mean — **not** that either agrees with the silicon.

The x86-64 ABI course in the previous section measured a 4.92x and a 27.65x. This
course has **no counterpart for either number and fakes none**. The one
cross-architecture comparison here is a **compile-time instruction count**, and
every table that contains it says so.

### Why the absences are the design, not a limitation

The four kinds of claim this course makes do not need a machine to verify, do not
go stale when a compiler changes, and can be checked by a reader with a hex
editor. That is the same reason the chain gets here: an object file that obeys a
contract is the step of
`lexing → parsing → IR → codegen → object files → linking → executable` where
the contract first becomes checkable, and this course is the AArch64 half of it.
The parts that need hardware — whether a `stp`/`ldp` pair is free, whether a
misaligned store traps, whether the branch predictor likes a link — are somebody
else's course, and section 12 names them in the artifact's own words.

## The oracle

| | |
|---|---|
| Document | **AAPCS64 — Procedure Call Standard for the Arm 64-bit Architecture** |
| Source | `ARM-software/abi-aa`, `aapcs64/aapcs64.rst` |
| Release | **2025Q4**, date of issue **23 January 2026** |
| SVE variant | `ARM_100986_0000_00` (legacy documents), §5.2.2.1 and §5.2.2.2 — the same alignment rule |
| Architectural manual | **not consulted** |

The specification is the **ORACLE**; the compiler is the **TEST SUBJECT**. The
two are printed in separate artifact sections (§2 quoted, §3–§10 measured) so a
reader can check one against the other with the compiler out of the way. Every
disagreement is a retraction, and there are seven.

The reason the alignment rule was checked against the SVE variant as well as
against AAPCS64 is that a rule stated in only one place is a rule a reader should
distrust, and this one is stated in **two** places in AAPCS64 (5.2.2.1 as a
universal constraint, 5.2.2.2 at a public interface) and in two more in the SVE
variant. A document that says a thing four times is a document telling you it
matters four times.

## Scope: what the collection had not said

The rule that shaped this course is the same one that shaped its two siblings:
*the comparison lives in the neutral courses; the depth lives in the per-arch
ones.* The sibling that precedes it — `courses/x86abi` — is the exhaustive
x86-64 reference to the same subject, and this course is **not** a rewrite of it.
The overlap is measured rather than asserted:

| Subject | x86abi owns | a64abi owns |
|---|---|---|
| Why a contract exists at all | the whole idea | one paragraph, linked |
| Argument registers | `%rdi %rsi %rdx %rcx %r8 %r9` | `x0`–`x7` and `d0`–`d7` and **the two independent counters** |
| Stack alignment | `stack=0x10`, measured as a **fault** | `SP mod 16 = 0`, measured as an **arithmetic identity** |
| Red zone | 128 bytes, measured by **clobbering it** | **there is none**, measured by a **census of who allocates** |
| Callee-saved | 6 GPRs + 16 XMM, 9,255 functions linted | `x19`–`x28` + `v8`–`v15` **bottom 64 bits only** |
| Unwind | `%rbp` walk and CFI | `x29`/`x30` and the CFI that quotes the ABI's own register |
| Flags across a call | `PUSHFQ`, **271 counted** | `NZCV`, **zero**, and no mnemonic exists |

What this course owes and does not re-teach: the ELF section-header table (the
artifact's own reader, `e_shoff` at `0x28`, `struct.unpack_from`, no library), the
**encoding** of every load/store form (a64asm, and this course imports its
decoder rather than rewriting it), the dynamic loader's view of the stack
(`dyn-order-runtime`), and the *why* a frame gets a canary in it
(`sec-canary`).

## What was measured, and what it changed

Every row is reproducible with `build_samples.sh`, and every number on the pages
comes from the recorded run in `a64abi.out`, which is committed so the claims are
checkable on a machine that never ran the assembler.

| # | Experiment | Recorded result | What it changed |
|---|---|---|---|
| A1 | Import a64asm's decoder and add models until the corpus is covered | 21 models in, **6 added**, 27 out; the six are the SIMD/FP load-store, literal, pair, 2-source, conversion and extended add/sub families | The base decoder could not **name** `stp q0, q1`, and a decoder that cannot name it cannot check the alignment rule — which is concept 1. **Coverage: 188 further instructions named at -O0, 115 at -O2** (736 of 741 and 462 of 468). |
| A2 | Ask the assembler 29 boundary cases | **17 accepted, 12 refused, 7 distinct diagnostics** | The row to read twice is `str q0, [sp, #8]`: **ACCEPTED, and it does not become an `str` — it becomes a `stur`**, `0x3c8083e0`, a different encoding in a different field, because the scaled form cannot express a non-multiple of 16 and the unscaled form can. Also: the q pair range is `[-1024, 1008]`, not `[-1024, 1024]`, because 1008 is 63×16 and 64×16 is one step past the end. |
| A3 | Give every argument its own `volatile` global and audit, by name, four optimisation levels | **36 of 36 argument placements agree** with C.9, C.13 and C.17; `x0`–`x7`, `d0`–`d7`; the 9th integer at `[sp+0]`, the 9th double at `[sp+8]` | The **first stacked argument is at offset ZERO**, because x30 holds the return address and there is nothing on the stack to skip. That is why every offset here is 8 lower than x86-64's, in **one sentence** instead of a diagram. |
| A4 | `m8` (4 int + 4 double) and `m18` (9 + 9) | `m8` cannot separate the two hypotheses; `m18` puts the 9th integer at `[sp+0]` and the 9th double at `[sp+8]` | The two counters are **independent** and the *specification* decides the outgoing order, by processing the parameter list left to right. `m8` alone would have agreed with both hypotheses, which is why the second function exists. |
| A5 | Result registers, and a struct too large for one | `x0` and `d0` — the **first argument register, not a dedicated one**; `x8` is the Indirect Result Location Register | One argument register has a job that is not passing an argument, and a reader who assumes results come back somewhere else will misread `use_big` at -O2, which is `mov x8, sp; bl rbig`. |
| A6 | Walk every SP delta and check the running sum at **every branch** | 0 misaligned out of **151 branches**; every function's sum is 0 mod 16 at every level | **STRICTLY STRONGER than the specification**, which constrains a *public interface* and a `bl` is one — a conditional branch inside a function is not. A check stronger than the spec cannot be defeated by a case the spec does not mention. A fixed-width stream has no length arithmetic to get wrong, so this is arithmetic, not simulation. |
| A7 | Six `w`/`x` instruction pairs, XOR the words | **6 pairs, 1 differing bit in every pair, and it is bit 31** — `0x80000000` each time, three of them arithmetic and three a move | **R2.** The widths are one register and one bit; a 32-bit write **ZEROES** the top half. `mov w0, #-1` and `mov x0, #-1` are the same immediate in the same field and mean different things. |
| A8 | Read register number 31 out of three different slots | `sp` in `Rd`, `xzr` in `Rn` of a logical, and **`str w0, [x31, #12]` is REFUSED** — the assembler will not let you name it in a base slot at all | A decoder that prints `x31` in a base slot is not making a naming choice, it is reading a field the encoding has already given a different meaning. The two rows worth reading twice are `mov x0, sp` and `mov x0, xzr`: they look like the same instruction and are in different encoding groups. |
| A9 | Frame census, 25 functions × 4 levels, counting pre-indexed allocation as an allocation | **-O0: 25 of 25 allocate. -O1/-O2/-Os: 14 of 25.** x86-64 the same C: 7 of 25, then 5, 5, 5 | The nine extra are exactly the functions whose C asks for memory that does not fit in a register. On x86-64 that memory is the red zone and costs nothing; here it costs a `sub` and an `add`. |
| A10 | The same function, hand-written, both architectures | AArch64 framed leaf: 11 instructions, **8 touch SP**. x86-64 framed leaf: 8 instructions, **6 touch the stack pointer, and `%rsp` never moves** | The whole cost of having no red zone is **two instructions** in every function with locals. The measurement is on hand-written code precisely so it cannot be blamed on the compiler. |
| A11 | The same C, both targets, compile-time instruction counts | whole corpus at -O2: **468 a64 against 423 x86, ratio 0.904**; a mean frame of 55 bytes against 56 | A compile-time count is a property of **clang 21.1.8**, not of an architecture, and the file says so where it is printed. The defensible claim is the **shape**: 14 of 25 versus 5 of 25 at every level above -O0. |
| A12 | Which of the five forms hides an allocation | 4 of 5 read *and* write SP in one instruction (`stp x29,x30,[sp,#-16]!` = `0xa9bf7bfd`, `ldr x0,[sp],#16` = `0xf84107e0`, …) | A frame counter that only counts `sub sp, sp, #N` misses all four. The first version of this table did, and reported 9 functions with no deallocation at -O2, which was wrong for 3 of them. |
| A13 | What the compiler saves, read out of the disassembly | `many` at -O2 saves **x19–x28 — all ten — in five `stp` pairs**; `fmany` saves **d8–d15, the 64-bit view, not q8–q15** | `many` needs ten callee-saved registers because there are **seven** caller-saved temporaries (x9–x15) and **twelve** live values: x19–x28 is what is left, not a set of ten chosen registers. And `fmany` obeyed the "bottom 64 bits" clause exactly — a reader who assumed 128-bit saves would conclude the compiler had made an error. |
| A14 | Count occurrences of the platform register | **w18/x18 in the whole corpus at all four levels: 0** | **R5.** There is nothing to save, because there is no rule to save it for. A conditional rule a compiler never implements is indistinguishable from a rule that does not exist, and the count is what tells them apart. |
| A15 | Count mrs/msr of a flag register | **0**, and there is no mnemonic for "save the flags" on this architecture | **R6.** The flags are a side effect of a bit in an instruction, and the sentence that makes them not your problem is a sentence rather than a store. x86-64's answer is `PUSHFQ` and x86abi counted 271 of them. |
| A16 | CFI for `nonleaf` at -O0, side by side | 4 instructions on the left, **10 directives on the right**, describing **one** frame | `.cfi_def_cfa_offset 48` is `sub sp, sp, #48` in English, and `.cfi_offset w30, -8` is the fact that the return address is in a register and was written to the stack. The two vocabularies share almost no symbols. |
| A17 | Read every FDE out of `.eh_frame` and count rows and rules per function | Row counts are **0, 2, 3 or 4** at every level and **no function ever gains a row**: 9 go 2→0, `cm8` 4→0, `va` 3→2. What gains is **rules**: `many` holds 4 rows and grows 40→64 bytes with 12 `DW_CFA_offset`; `fmany` holds 4 rows and grows 36→76 with 10 (2 exact + 8 extended) | **R7, the retraction that is also the finding.** The brief's "3 rows at -O0 and 9 at -O2" does not occur. The real shape is better: **rows and rules move in opposite directions in the same function**, so the information content is rows × rules and optimisation moves those two against each other. |
| A18 | Section sizes, four levels | `.eh_frame` is **27.0% of `.text` at -O0 and 42.3% at -O2** (800 of 2964 bytes → 792 of 1872) | Halving the code moved the table from 27.0% to 42.3% of it. The cost of the second language is a function of the **number of functions**, not of the amount of code in them: the per-function floor is a CIE reference, an FDE header and at least one row, and no amount of optimisation removes it. |
| A19 | The second reader's own account of the same table | `return_address_register: 30`, `data_alignment_factor: -4`, `DW_CFA_def_cfa: reg31 +0` | `reg31` is the stack pointer, and it is the **same number 31** that A8 showed being three different things in three instruction slots. That is the hinge between concept 2 and concept 5, and it is why the two pages are adjacent. |
| A20 | Two readers over four objects | **2102 instructions read, 2078 named, 0 disagreements**, and every distinct (before, after) normalisation pair printed with the number of instructions it touched — 14 shown, and **1,130 distinct pairs in the run, 4,059 instructions touched** | 100% is what a broken cross-check looks like. Hence A21. |
| A21 | **Poison** one guard by one bit and re-run the same loop | named **2078 → 1859** (moved by **219**), disagreements **0 → 304**, and the first few are printed **by name** | The control. And the reason the section exists: the first run reported **1232 disagreements out of 2086** and **every one was a real defect** — a guard that did not fix `bits[25:24]`, a pair model that read the width from `bits[29:28]` instead of `bits[31:30]`, a floating-point immediate whose fraction was five bits wide instead of four and printed 2.0 for 1.0, a MOVN that complemented without sign-extending, and a register-offset form that concatenated two register fields into the number 150. **A check that has never failed is a check.** |
| A22 | Ask whether a misaligned SP access faults | **It cannot be measured here, and the artifact says so where a reader would expect a measurement.** `mrs x0, sctlr_el1` = `0xd5381000` is measured; the fault is not | The AAPCS64 says "the hardware requires". Whether it *traps* is decided by `SCTLR_ELx.A`, and a Linux EL0 process runs with that bit **clear** — so on this platform the rule is a **software contract**, not a hardware trap. A reader who took "requires" as "will trap" would be wrong about the platform this compiles for. |

## The seven retractions

Printed in full by the artifact in section 11, in this order, with no gap, and
asserted as **text** by `crosscheck.py` group L.

| | Claim retracted | What was found instead |
|---|---|---|
| **R1** | the AAPCS64 stack alignment rule is 128 bytes | **16 bytes**, stated in both 5.2.2.1 and 5.2.2.2 and in both documents. The section plan's *reason* — NEON's `LDP q0, q1` — is **right and implies 16**, which is the largest scale in the whole load/store family. A stated reason that does not imply the stated number is a reason invented after the fact. |
| **R2** | a 32-bit write is a separate register bank, so the two widths cost nothing to keep apart | **One register and one bit**, and the 32-bit form **ZEROES** the top half. A decoder modelling two 32-register banks gets the numbers right and the **semantics wrong, silently**: every value it computes is a valid value, and the wrong one is exactly what a 32-bit programmer would have got on a machine with two banks. |
| **R3** | the 128 bytes is an AArch64 stack alignment rule | The 128 bytes is an **APPLE platform-ABI red zone**, and the AAPCS64 has no red zone at all: §5.2.2.1 defines the region below SP as the **inactive region** and says no thread is permitted to access it. Two quantities about two different regions of memory, conflated by the number 128. A course that used the red zone's number would also have concluded AArch64 *has* a red zone. |
| **R4** | the AAPCS64 preserves the lower 64 bits of **v0–v7** | it preserves the lower 64 bits of **v8–v15**. v0–v7 are the argument and result registers and are entirely caller-saved — so a course that got the range wrong would have had to explain a callee **saving the registers its arguments just arrived in**. |
| **R5** | the platform register `r18` is preserved across a call that uses the stack | **there is no such rule.** §5.1.1 says the role is platform specific and the platform ABI specification must document it; Linux does not reserve it. The plan's rule is an AArch32 and Windows x86-64 idea. Measurement: **0 occurrences in 25 functions × 4 levels.** |
| **R6** | AArch64 has a flags register that has to be saved like any other | `NZCV` is not a general register, **has no mnemonic**, and is explicitly **UNDEFINED** on entry to and return from a public interface. Undefined is not preserved and not destroyed: a callee may leave them in any state and the caller may not read them across a call. The measurable consequence is a **count of zero**. |
| **R7** | a function needing 3 CFI rows at -O0 and 9 at -O2 is the characteristic example | **no function in the corpus does that**, and no function ever gains a row. What rises is the rule count. A predicted shape that the measurement does not contain is a retraction and not a nuance — and it took a second experiment to find the real one, because the first counted rows and stopped. |

A course that reports **zero** retractions on a subject this size has either not
looked or has not been reading the documents it cites. All seven were asserted in
`docs/aarch64-section-plan.md` or in the brief for this course.

## The harness

`crosscheck.py` — **166 checks in 13 groups (A–M)** — reads the shipped
`a64abi.out` and re-asks the claims. It has no assembler, no object files and no
decoder of its own, and that is deliberate: a harness that can re-measure can
disagree with the artifact for reasons that have nothing to do with whether the
artifact's sentences are still true, and then it teaches its reader to ignore it.

Three kinds of assertion, and the split is the point:

* **EXACT** for anything the specification owns and the encoding confirms —
  register assignment, argument order, the alignment constant, frame sizes, CFI
  row and rule counts, the reach of every scaled field, every assembler
  diagnostic, every bit pattern, the two-reader agreement. These are not being
  clever; an exact quantity has one honest treatment.
* **SHAPES** for anything that is a property of a compiler version — the
  instruction-count ratios, the orderings. A check whose threshold is a bare
  number from one compiler is a check that fails on a busier machine and teaches
  its reader to ignore it.
* **TEXT** for the seven retractions, because a retraction *is* a claim about a
  number that is otherwise fine, and a course that quietly dropped one would pass
  every other check in the file.

## What the artifact deliberately does not do

* **It does not execute anything.** Section 1 prints the two absences before the
  first measurement; section 12 lists the consequences in its own words.
* **It does not quote a timing**, and it refuses the x86-64 course's 4.92x and
  27.65x by name rather than leaving them out silently, because a reader who has
  just read them in the previous course is looking for a counterpart.
* **It does not use a tool to DECODE.** It imports a64asm's decoder — a sibling
  artifact, found by walking up the tree, overridable with `A64DEC_DIR` — and
  adds six models of its own. A decoder that shells out to a disassembler is a
  disassembler with a hardcoded path in it.
* **It does not re-teach the encoding.** A64asm owns the 21 base models and
  measured the field map; this course adds the six families the *procedure call
  standard* needs, which is a list of the things a decoder cannot name.
* **It does not claim a fault.** The alignment section names the boundary at the
  point where a reader would expect a measurement, because a reader who took
  "the hardware requires" as "will trap" would be wrong on Linux.

## The toolchain notes worth keeping

Three of these cost a whole afternoon each and none is in any manual.

1. **`llvm-objdump-21` needs `--triple=aarch64` and has no `-b binary`** — the
   same trap a64asm recorded. It has **no** `--triple=x86-64` either; that one
   wants none at all. Every single-word probe here is therefore assembled into a
   real object file and asked about in a section the disassembler already reads.
2. **`build_samples.sh` is `#!/bin/sh` and this host's `awk` is mawk**, which has
   no `strtonum()`. The first version computed `.text` sizes with a python
   heredoc inside a `$( )` substitution; POSIX shells read a heredoc body from
   the line after the `<<`, so it swallowed the rest of the script and the line
   printed `.text= bytes` four times **with a zero exit status**. That is now
   `textsize.py`, and the reason is written in its docstring.
3. **Decoder guards, all six added models and every one that was got wrong at
   least once**: the FP pair is `fixed(29,27,0b101)` + `fixed(26,26,1)` +
   `fixed(25,25,0)` with `opc = bits[31:30]` (00 = s/×4, 01 = d/×8, 10 = q/×16);
   `LDR` literal for s/d/q is `bits[29:27]=0b011` with `V=1` and
   **`bits[25:24]=0b00`**; the FP immediate is `bits[28:24]=0b11110` with
   `bits[15:10]=0b000100`, `bits[11:5]=0`, and `imm8 = bits[20:13]` split
   `a=bit7, bc=bits[6:4], f=bits[3:0]` giving
   `(-1)^a · 2^(signed3(bc)+1) · (1 + f/16)`; extended add/sub is
   `bits[28:24]=0b01011` + `bits[23:21]=0b001` with `option = bits[15:13]`
   (`uxtx` is REFUSED). The measured reach of the FP immediate is
   **2⁻³ (0.125) to 2⁴ (16.0) in steps of 1/16**; 0.0625 and 32.0 are refused,
   and `fmov d0, #0.0` assembles as `fmov d0, xzr`, which is a different
   encoding with the same source text.
