# The AArch64 section — plan

Authorised by `docs/course-mission.md`, which collapses the 13 `ARM64`
roadmap items into **one** course of ~20 concepts. The founder's ruling on
2026-09-29 for the x86-64 section — keep the no-duplication rule and the total
coverage, but split the single course into sequential ones — is applied here
for the same reason: *"merging would produce a course nobody finishes."* Four
courses, ~20 concepts.

Naming: the section is `ARM64`; the items and the architecture are `AArch64`.
The course ids and every concept id use **`a64`**, not `arm64`, because the
architecture name is what a reader will look for. The mission doc's note that
naming is unsettled is the reason this is stated here rather than left to
whoever writes the next file.

## THE METHOD, and it is forced

**There is no AArch64 machine.** This is the defining constraint of the
section, and it inverts the x86-64 section's method completely.

What IS available, verified 2026-09-29:

| tool | result |
|---|---|
| `clang --target=aarch64-linux-gnu -S` | C → AArch64 assembly, real, with real `.cfi_*` |
| `clang --target=aarch64-linux-gnu -c` | → a real `ELF64 LSB relocatable, aarch64` object |
| `llvm-objdump-21 --triple=aarch64 -d` | disassembly — **an independent reader** |
| `aarch64-linux-gnu-ld`, `qemu-aarch64` | **absent. Nothing can be EXECUTED.** |

So every claim in this section is one of exactly three kinds, and every
concept page must label which:

1. **MEASURED** — something about the machine, the compiler, or the bytes,
   established by an experiment. These are the only measurements available, and
   they are rich: the compiler's own choices, the encoding's real structure, the
   unwind table's real contents, what a linker would have to relocate.
2. **MEASURED-ON-BYTES** — a property of the emitted bytes, cross-checked
   against `llvm-objdump` as a second reader. A check that reads the same byte
   twice agrees with a wrong answer, so every one of these has two readers.
3. **QUOTED** — a manual claim, with a document and section. The architectural
   reference material: the encoding tables, the exception classes, `VBAR_ELx`,
   the page-table descriptors, NEON's register file.

**What cannot be done here, and must be said on every affected page:**

- **No timing.** Nothing AArch64 can be timed. The x86-64 section's 4.92× and
  27.65× have no counterpart and must not be faked. There is no performance
  model to compare against either.
- **No exception delivery.** You cannot take an exception on AArch64 from here.
  The vector table, the syndrome register and the `ELR` are quoted, and the
  *encoding* of the instructions that read them is measured.
- **No memory behaviour.** No page walk, no TLB, no cache. The page-table
  formats are quoted; the **ELF-side** consequences are measured, and that is
  where the genuinely new material lives.
- **No `qemu`, no `ld`, no sysroot.** So no linked executable, no runtime, no
  syscall numbers confirmed by execution. The `SVC #imm16` convention and the
  `x8` syscall register are measured **as the compiler emits them**, which is
  weaker and must be labelled weaker.

The honest framing, and it is a good one: **this is a course about a machine
you cannot run, built the way a compiler author would build it** — from the
encoding outward, with the specification as the oracle and the compiler as the
witness. That is precisely the situation a learner writing a backend is in, so
the constraint is the subject rather than a limitation of the teaching.

## The four courses

### A. `a64asm` — "AArch64: Encoding From The Ground Up"
Roadmap items **1** (Assembly) and **2** (Instruction Encoding). ~5 concepts.

1. `a64-asm` — the assembly surface, and what a fixed 32-bit encoding changes
   about writing assembly. Measured: what the compiler emits, and how much of
   it is different from what a human would write.
2. `a64-encoding` — the encoding itself: every field of the 32-bit instruction,
   the three major opcode groups, and why AArch64 being fixed-width is not the
   simplicity it looks like. This is the course's centre and its artifact's
   first job.
3. `a64-immediate` — the two immediate encodings, which are where fixed-width
   costs you: logical immediates (`N:immr:imms`, the 64-bit pattern with the
   rotate built in) and the `MOVZ`/`MOVK`/`MOVN` wide-immediate family, and
   `adrp`/`add :lo12:` as a *pair*. All measured from real bytes.
4. `a64-cond` — `NZCV` and conditional execution: the flag-setting suffix, the
   sixteen condition codes, `csel`/`csinc`/`csinv`/`csneg`, and the `tbz`/`tbnz`
   range-load trick. Measured: the compiler's branch-vs-csel choices, and the
   fact that RISC-V has nothing to compare against.
5. `a64-verify` — the decoder, the two-reader cross-check, and the map audit.

### B. `a64abi` — "The AArch64 Procedure Call Standard"
Roadmap items **3** (Calling Conventions), **4** (ABI), **5** (Stack Frames).
~5 concepts.

6. `a64-aapcs` — the procedure call standard: `x0`–`x7`, the return in `x0`,
   and the **128-byte stack alignment rule**, which exists because of NEON's
   `LDP q0, q1` — a real reason, measured from the encoding.
7. `a64-registers` — the register file as a partitioned namespace: `x0`–`x30`
   and `w0`–`w30` as *the same registers*, `xzr`/`wzr` and `sp` as two
   special register numbers, and that a write to `w0` zeroes the top half.
   Measured, because it is a correctness trap and not a curiosity.
8. `a64-frame` — the frame: prologue/epilogue, the `stp`/`ldp` pair, leaf
   functions, and the fact that AArch64 has **no red zone** — measured by
   finding a leaf that does not allocate and asking what would break.
9. `a64-save` — callee-saved: `x19`–`x28`, `v8`–`v15`, the lower 64 bits of
   `v0`–`v7`, and the platform register. Read out of the compiler's output
   across optimisation levels, with the compiler as the test subject.
10. `a64-unwind` — `.cfi_*` and the `.eh_frame` that carries it. AArch64's
    frame description is a *second language* for the same frame, exactly as
    the x86-64 course found, and here the pair is `CFA` offsets and register
    rules. Measured from the emitted bytes.

### C. `a64sys` — "The AArch64 Machine: Modes, Memory and Faults"
Roadmap items **6** (System Calls), **7** (Exceptions), **8** (Interrupts),
**12** (Virtual Memory), **13** (Page Tables). ~6 concepts.

11. `a64-syscall` — `SVC #imm16` and the `x8` convention. **Measured as the
    compiler emits it**, and labelled weaker than an execution would be. The
    interesting part is why the immediate is a 16-bit *constant* in the
    instruction rather than a register — a real design difference from `SYSCALL`
    — plus the `x8`-is-the-only-convention fact, which is ABI and not
    architecture.
12. `a64-exceptions` — the exception classes and `ESR_ELx`'s packed syndrome:
    the EC, the IL, and the ISS whose meaning *depends on the class*. Quoted
    with a document, and the encoding of the instructions that read the
    registers is measured.
13. `a64-interrupts` — `VBAR_ELx`, `VBAR_V32_ELx`, the vector table's eight
    bytes per vector, the separate EL/IRQ/FIQ/SError entries, and why EL0
    cannot install one. Quoted, with the *address arithmetic* measured.
14. `a64-virtual` — TTBR0/TTBR1, TCR, the 48/52-bit `T0SZ`/`T1SZ` split, and
    the top half of the VA space. Quoted, and the **ELF-side** consequence
    measured — which is where the new material is.
15. `a64-pagetables` — the four descriptor levels, the block/table/page sizes
    and the `TXL`/`SL`/`AttrIndx` fields, and the overlap of the three
    translation regimes. Quoted with a document; the **relocation** side —
    which symbols need `R_AARCH64_ADR_PREL_PG_HI21` and why a pair of them per
    page — measured, because the object-file courses already teach ELF and
    this is the hinge.
16. `a64-evidence` — the artifact, and the measured/quoted boundary made
    explicit. **Renamed from `a64-verify` as planned**, because
    `render_concept()` resolves concept ids GLOBALLY with no course in the
    key and `a64-verify` was already claimed by `a64asm`; a second course
    asking for it silently receives the first one's page. The id is the only
    thing that changed, the file is `content/src/a64_evidence.ch`, and the
    reason is recorded where the fall-through lives in `web/src/helpers.ch`.
    Note also that this concept is written LAST and is therefore placed at the
    end of module `memory` in the manifest, not at the front of module `mode`
    as this list orders it, because the prev/next chain is generated from
    manifest module order.

### D. `a64simd` — "The AArch64 Data Path: NEON, Atomics and Ordering"
Roadmap items **9** (SIMD and NEON), **10** (Atomics), **11** (Memory
Ordering). ~5 concepts.

17. `a64-neon` — the NEON register file: 32 × 128-bit `v` registers, the
    *same bytes* viewable as 8/16/32/64-bit lanes, and the `Q`/`D`/`S`/`H`/`B`
    size suffix that reinterprets rather than converts. Quoted for the view
    rules; **measured** from emitted bytes, because a NEON instruction's
    encoding depends on the view and the decoder has to get it right.
18. `a64-crypto-simd` — the shared-memory-space complication: NEON, SVE, SVE2
    and the crypto extensions share an instruction encoding space, and the
    shared-resource rule is what makes SVE's vector-length-agnostic encoding
    possible. Quoted, and the *encodings* measured — the `0b0`/`0b1`/`0b10`
    space discipline is visible in the bytes.
19. `a64-ldst` — `ld1`/`st1`/`ld2`/`ldp` and the structure load/store that has
    no x86 equivalent, plus NEON's alignment requirement and what it costs in
    *code* rather than cycles. Measured from the compiler's output.
20. `a64-atomic` — `LDAXR`/`STLXR`, `CAS`/`CASP`, `LDAR`/`STLR`, the
    exclusive-monitor model and why the retry is a **loop by construction**
    rather than by accident, and the `FEAT_LSE` instructions. Quoted for the
    rules; the **encoded bytes** measured for every one.
21. `a64-order` — the weak model: acquire and release as *access modes* rather
    than a barrier you sprinkle, the `DMB`/`DSB`/`ISB` trio, and
    `PSTATE.PAN` as the supervisor-to-user control. This is the item where
    AArch64 differs from x86-64 **in kind** rather than in detail, and the
    neutral courses taught the principle; this is the reference.

## The no-duplication seam

Seven neutral courses already taught these topics neutrally, plus the four
x86-64 courses which are the *same architecture family* for five of them. So
for every item in this section:

- the **principle** belongs to `exe`, `mem`, `smp`, `simd`, `priv` and the
  x86-64 section's four courses — link out, do not re-teach;
- this section owes the **exhaustive AArch64 reference**, and where the two
  architectures differ *in kind* rather than in detail, that difference IS the
  concept.

The differences worth building on, all flagged by the mission doc as the
section's payoff:

- AArch64 has **`NZCV` and four flag-setting suffixes** where x86-64 has one
  `EFLAGS` register and a fixed meaning per instruction.
- AArch64's encoding is **fixed 32-bit** and RISC-V's is 16/32 plus compressed;
  x86-64's is 1–15 bytes. That single fact is why an object file's relocation
  record is architecture-specific — the hinge to `obj`, `reloc` and `link`.
- AArch64's ordering is **weak and explicit** where x86-64's is strong and
  implicit, so the same correct-looking C needs different fences.
- AArch64 has **no red zone** and no flags register to save separately.
- AArch64's `x0`/`w0` are the same register, so a 32-bit write is a
  *zero-extension* with a cost, not a separate bank.

## Rules (inherited from `docs/x86-64-section-plan.md`, all twelve apply)

The x86-64 section's discipline carried over unchanged, plus one new one:

**13. Label every claim MEASURED / MEASURED-ON-BYTES / QUOTED, in the artifact
output and in the page.** The method section of this plan is the reason. A
course built without hardware has exactly one honest advantage — it can be
scrupulous about provenance — and it must take it.
