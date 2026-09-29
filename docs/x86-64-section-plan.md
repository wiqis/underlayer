# The x86-64 section — plan

Authorised by `docs/course-mission.md`, which collapses the 18 `x86-64`
roadmap items into **one** course of ~22 concepts and warns that merging
produces "a course nobody finishes". The founder's ruling on 2026-09-29 was to
keep the no-duplication rule and the total coverage, but to **split the single
course into four sequential ones** so each is finishable. Course count for the
architecture half therefore becomes 9 + 3 = 12.

## The rule that shapes all four

Seven neutral courses already taught these topics *neutrally*, with x86-64 as
the running example: `isa`, `exe`, `mem`, `priv`, `smp`, `simd`, `sec`.

> *"The comparison lives in the neutral courses; the depth lives in the
> per-arch ones."* — `docs/course-mission.md`

So these four courses **never re-teach a principle**. Where an item shares its
subject with a neutral course, this section owes the **exhaustive x86-64
reference**: the complete table, the complete encoding, the complete bit
assignment — and a link back to the neutral concept for the why. A reader who
has done the neutral course and these four has the x86-64 reference manual
*and* the reasoning. A reader who has done only these four knows what x86-64
does and not why anyone would design it that way, which is the correct order.

## What is genuinely new (measured by word-boundary scan, 2026-09-29)

Zero coverage in any of the 21 existing courses:

| Term | Files |
|---|---|
| `SUB` `CMP` `MOVZX` `LEAQ` `SHR` `ROL` `SETcc` `CMOVcc` | **0** — the integer set is untaught as a set |
| `red zone` `callee-saved` `caller-saved` `GPR` | **0** |
| `AT&T` `Intel syntax` `disassembl` | **0** |
| `addps` `addpd` `movaps` `pxor` | **0** — the ISA course covers **14** `0F xx` opcodes total |

Partially covered, and this is where the seam is: `ModRM` `SIB` `REX` `EVEX`
are taught by the `isa` course as *encoding layers*, and `VEX`/`EVEX` are met
only as prefix bytes in the `0x62`-is-`BOUND`-in-32-bit collision story. The
instruction set behind those bytes is untouched.

## The four courses

### A. `x86asm` — "x86-64 Assembly and Encoding"
Roadmap items **1** (Assembly) and **2** (Instruction Encoding).

1. `x86-asm` — the assembly surface: AT&T vs Intel syntax and why the default
   flipped, the assembler, directives, and reading `objdump` output.
2. `x86-integers` — the integer instruction set, which nothing teaches today:
   the ALU group, the three-operand form and why it exists, `LEA` and what it
   really computes, the shift and rotate group and the two shift counts.
3. `x86-flags` — `EFLAGS` and condition codes, `SETcc`, `CMOVcc`, and the
   flags-to-boolean idiom. `exe` taught the flags' *role*; this is the
   exhaustive reference and the two branchless forms.
4. `x86-vex` — the two- and three-byte prefix encodings: `0F`, VEX 2-byte and
   3-byte, EVEX. The `isa` course met `0x62` as a byte; this is what is behind
   it and why the map structure changed shape.
5. `x86-map` — the reference decoder and the audit: a full 0F/0F38/0F3A
   coverage check against an independent source.

### B. `x86abi` — "The x86-64 ABI"
Roadmap items **3** (Calling Conventions), **4** (Stack Frames), **5** (ABI).

6. `x86-calling` — System V AMD64: the six argument registers, the return
   value, and why the fourth argument collided with the hardware's choice.
7. `x86-frame` — the stack frame: alignment, the **red zone**, leaf functions,
   and what a frame pointer is actually for.
8. `x86-saved` — callee-saved vs caller-saved, and the rule that follows from
   the red zone's existence.
9. `x86-varargs` — varargs: the register save area, `%al` as the vector count,
   and why it is the one place the ABI is self-describing.
10. `x86-unwind` — unwinding and CFI: `.cfi_*` directives, and why the ABI has
    to describe the frame in a second, independent language.
11. `x86-verify` — the artifact: compile C, read the ABI out of the
    disassembly, and check the compiler against the specification.

### C. `x86sys` — "The x86-64 Machine: Privilege, Memory and Time"
Roadmap items **6** (System Calls), **7** (Interrupts and Exceptions), **13**
(Virtual Memory), **14** (Paging), **15** (Protection Rings), **16** (Control
Registers), **17** (Debug Registers), **18** (Performance Monitoring).

Each of these has a neutral counterpart. Each is here as the **exhaustive
x86-64 table**, never as a re-derivation.

12. `x86-syscall` — the full instruction and the `STAR`/`LSTAR`/`SFMASK`/`EFER`
    model-specific registers, as a reference. `priv` measured the boundary.
13. `x86-exceptions` — all 32 vectors as an x86-64 reference with the class,
    the error code and the encoding. `priv` taught the numbers; this is every
    one of them, with sources, including the AMD divergences.
14. `x86-virtual` — the 48/57-bit split, `CR3` and the four address-size bits,
    `LA57`, `LAM`, and the canonical rules as a reference.
15. `x86-paging` — the four paging-structure entries, every CR3 and CR4 bit
    that selects a format, and the complete flag set per entry. `mem` measured
    the cost of a walk; this is the structure of the walk.
16. `x86-rings` — the descriptor tables in full: GDT, LDT, TSS, the segment
    selector layout, and every `MAX`/`DPL`/`RPL`/`CPL` check with the Intel and
    AMD wording side by side, including the task-gate inconsistency.
17. `x86-cr` — `CR0`–`CR4` exhaustively, every bit, what sets it, what clears
    it, and which TLB invalidations each write causes.
18. `x86-debug` — `DR0`–`DR7`: the four address registers, the four type
    registers, the control word, and the exact mask a debugger must program.
19. `x86-pmu` — the performance monitoring architecture: the counter list, the
    fixed counters, the events that exist on paper. **Stated up front: this
    machine has no PMU** (`perf_event_paranoid = 4`), so this concept is
    reference material and the artifact proves the absence rather than
    asserting it.
20. `x86-verify` — the artifact: read what is readable (`CPUID`, `SIDT`,
    `SGDT`), decode what is decodable, and state precisely what ring 3 cannot
    see.

### D. `x86simd` — "The x86-64 Data Path: Atomics, Ordering and Vectors"
Roadmap items **8** (SIMD), **9** (AVX and AVX2), **10** (AVX-512), **11**
(Atomic Instructions), **12** (Memory Ordering).

`simd` and `smp` taught the principles. These are the x86-64 reference.

21. `x86-sse` — SSE and SSE2 in full: the `XMM` register, the packed and
    scalar forms, the `movaps`/`movups` alignment split, and the 16-byte
    operand size prefix that means something different here.
22. `x86-avx` — AVX and AVX2: the 256-bit register, the **three-operand
    VEX encoding and what it fixed**, unaligned penalties, `vzeroupper`, and
    the AVX2 integer set.
23. `x86-avx512` — AVX-512: `ZMM`, the **mask registers**, the four-level
    hierarchy, embedded broadcast, and the EVEX encoding. **This machine has no
    AVX-512**, so the concept is reference plus a decoder that works on bytes
    rather than on the CPU, and it says which is which.
24. `x86-atomics` — the atomic instruction set exhaustively: which
    instructions imply `LOCK` and which do not, `XADD`, `CMPXCHG`, `XCHG`,
    and the atomicity of a compare-exchange against a wider compare-exchange.
25. `x86-order` — memory ordering as a reference: TSO, the `MFENCE`/`LFENCE`/
    `SFENCE` trio and what each one actually orders, the store-buffer flush,
    and the `DIR` flag's history.
26. `x86-verify` — the artifact: an encoder and a decoder for the vector maps,
    byte for byte, checked against an independent disassembler.

## Totals

26 concepts in 4 courses, ~26 + 4 landings, all 18 roadmap items covered with
nothing dropped and nothing re-taught.

## The section is complete (2026-09-29)

All four courses are shipped, all 26 concepts have live routes, and all 18
roadmap items are ticked in `docs/courses-todo.md`.

| # | Course | Concepts | Min | Artifact | Checks | Verifier |
|---|---|---|---|---|---|---|
| A | `x86asm` — Assembly and Encoding | 5 | 127 | `x86dec` | 155 | `verify_x86asm.py` |
| B | `x86abi` — The ABI | 6 | 150 | `abidump` | 143 | `verify_x86abi.py` |
| C | `x86sys` — Privilege, Memory and Time | 9 | 231 | `sysdump` | 214 | `verify_x86sys.py` |
| D | `x86simd` — The Data Path | 6 | 154 | `vecdump` | 266 | `verify_x86simd.py` |
| | **Total** | **26** | **662** | | **778** | |

Every course ships its recorded artifact output, so its harness runs on a
machine that never ran its benchmark. That is the property the section plan
asked for and the one the harness's `default_output()` exists to provide.

### The three concept-id collisions, and the rule they produced

The plan gave the last concept of all three remaining courses the id
`x86-verify`. A concept id is resolved **globally** by `render_concept()` in
`web/src/helpers.ch` with no course in the key, so three courses cannot share
one and only the first to claim it keeps it. `x86abi` took it. `x86sys` took
`x86-boundary` and `x86simd` took `x86-bytes`.

The general rule, now written into the comment at the call site:

> **The only concept ids that survive are the ones nobody thought of first.**
> Name a concept for the *thing it measures* and check `grep -n '"<id>"'
> web/src/helpers.ch` before planning it, not after.

### What the fourth course added to the twelve rules

Rules 1–12 above were written after courses A–C. Course D did not add a
thirteenth, which is the result worth recording, but it **sharpened three of
them** in ways the earlier three could not have known:

- **Rule 1 gained a second half.** The artifact is not finished when it runs.
  Course D's cross-check reported *28 disagreements out of 30* for a full run
  and the file believed them, concluding the encoder was broken. The encoder
  was perfect; the **reader of the disassembly** was counting `objdump`'s
  section header as row 0, so every row was compared against its neighbour's
  text. The two rows that still "agreed" did so only because both happen to be
  `vaddps`. All 30 agree once the reader is aimed.
  **A second reader must itself be checked against what a correct run looks
  like**, not against whether its verdict felt right.
- **Rule 10 gained its sharpest illustration.** The store-buffer ping-pong took
  three attempts, and every version produced numbers that looked entirely
  reasonable. The tell was visible throughout — the store-only floor came out
  **above** the thing it was a floor for, in every run — and the file printed
  the ratio instead of objecting. A test that says *faster* passes when the
  instrument is broken; a test that says *slower* fails and hands you the
  instrument. **Every table needs a claim that says a number should have been
  smaller.**
- **Rule 3 gained a variant nobody had written down.** `aligned(64)` on a
  two-element array aligns the *array*, not each *element*, so two threads
  eight bytes apart still shared a cache line and the "two lines" arm was
  secretly the "one line" arm. The fix is a stride. **A layout is a claim, and
  it is printed above the table and asserted by the harness rather than
  described in a comment** — a comment is not a measurement, and two of the
  three attempts were bugs that read exactly like correct code.

Course D also produced **24 retractions**, the most of the four, and the same
shape as the others: six about what a *number* is, seven about what an
*instrument* is, three about what an *encoding* is, and not one about how a
computer works.

### The one place this section is deliberately incomplete

Course D's third concept covers AVX-512, and **this machine cannot execute one
instruction in it**: `CPUID.7.0:EBX` reads F, DQ, CD, BW and VL as five zeros,
and the three `XCR0` state bits are three more. Every claim in that concept is
marked `QUOTED` against `MEASURED` on the page itself, and the one thing the
artifact does with AVX-512 is decode its bytes, which needs no silicon. This
is the correct outcome rather than a gap, and it generalises:

> **A reference for a feature you cannot run is still worth writing, provided
> every sentence in it says whether it was measured.** The alternative — omit
> the feature — leaves the reader with no way to tell a quoted claim from a
> tested one, and that is the failure that actually costs people.

## Rules every one of these four must follow

The rules the last four courses learned, written down so they are not re-learned:

1. **The artifact and its harness come first.** No prose until every number
   exists and is checkable. A claim with no measurement does not get a concept.
2. **Every number in a concept comes out of the recorded artifact output.** If
   it is not in `*.out`, it does not go in the page.
3. **Inline `asm` for anything that must not be optimised away.** The compiler
   has deleted separate experiments in all four of the last courses. Every arm
   proves it did the work with a checksum.
4. **Reset state between arms.** An arm inheriting the previous one's arrays
   overflows and still looks plausible.
5. **Pin and verify any placement.** `sched_getcpu()` from inside the worker,
   discard and count.
6. **Min-of-N, interleaved, and print the noise floor before any claim.**
7. **The TSC is time, not cycles.** Every figure is a ratio.
8. **Never a raw `{` or `}` inside `#html` — use `&#123;`/`&#125;`.** Check with
   `python3 tools/bracecheck.py`.
9. **Every substring check in a harness runs against a whitespace-normalised
   copy.** The artifact wraps prose; a check for a wrapped sentence fails on
   text that is present.
10. **Assert structure exactly and timings only as orderings and shapes.**
    Central results move between runs; shapes do not.
11. **Every retraction is printed by the artifact and asserted as text**, so it
    can be neither quietly dropped nor deleted.
12. **`#html`/`#css`/`#js` macros only.** Never a string append.
