# The RISC-V section — plan

Authorised by `docs/course-mission.md`, which collapses the 9 `RISC-V`
roadmap items into **one** course of ~18 concepts. The founder's ruling on
2026-09-29 (x86-64) and its immediate application (AArch64) — keep the
no-duplication rule and the total coverage, but split the single course
into sequential ones so each is finishable — is applied here. Four courses,
~19 concepts.

Naming: the section is `RISC-V`; every course id and concept id uses `rv`.

## THE METHOD, and it is forced — verified 2026-09-30

**There is no RISC-V machine, no emulator and no RISC-V binutils on this
host.** Nothing can be executed. The method is therefore the AArch64
section's (see `docs/aarch64-section-plan.md`), and it is not a workaround:

| tool | result |
|---|---|
| `clang --target=riscv64-linux-gnu -march=rv64gcv -S` | C → RISC-V assembly, **and it auto-vectorises**: 7 `vadd` + 1 `vsetvli` out of scalar C |
| `clang --target=riscv64-linux-gnu -c` | → a real `ELF64 LSB relocatable, riscv` object |
| `llvm-objdump-21 --triple=riscv64 -d` | disassembly — **an independent reader** |
| `qemu-riscv64`, `spike`, `riscv64-linux-gnu-{gcc,as,ld}` | **absent. Nothing can be EXECUTED.** |

Every claim is one of three kinds and every concept page labels which:

1. **MEASURED** — about the compiler or the bytes, by experiment.
2. **MEASURED-ON-BYTES** — a property of emitted bytes, cross-checked
   against `llvm-objdump-21` as a second reader. Two readers always: a
   check that reads the same bytes the same way agrees with a wrong answer.
3. **QUOTED** — a manual claim, with a document and section.

What cannot be done here, and must be said on every affected page: **no
timing, no exception delivery, no page walk, no cache, no syscall confirmed
by execution.** The `ecall` convention is measured as the compiler emits it,
which is weaker and is labelled weaker.

## What makes RISC-V the most interesting of the three architectures

**The encoding is a spectrum, and the corpus shows it on the first page.**
Already measured while scoping, 2026-09-30:

```
  0: 952e          add  a0, a0, a1     2 bytes   (compressed, C)
  6: 0d85f2d7      vsetvli t0, a1,... 4 bytes   (V, always 32-bit)
 20: 00000073      ecall              4 bytes
```

x86-64 is 1–15 bytes, AArch64 is fixed 32, RISC-V is 16/32 **plus** a
compressed extension. That is the design axis behind the fact that an
object file's relocation record is architecture-specific — the hinge to
the `obj`, `reloc` and `link` courses. And RISC-V is **modular**: the base
is RV32I/RV64I and everything else is an extension letter, so the
instruction set is a *set of independent documents* rather than one list.

**RISC-V has no flags register and no condition codes.** x86-64 has
`EFLAGS`, AArch64 has `NZCV`, RISC-V has **nothing**. So a branch is the
only conditional thing, and that single absence is the section's spine:
it explains why AArch64 needs `csel`/`cset` at all, why x86-64 grew
`CMOVcc` and `SETcc`, and what a compiler has to do instead. It is
measurable statically: compile the same C and count what the compiler
emits.

**Memory ordering differs in kind.** x86-64's `DIR` flag makes ordering
implicit and historically buggy; AArch64 and RISC-V require **explicit
barriers**. So does the object-file side: an AArch64 or RISC-V object may
carry ordering metadata where an x86-64 object carries none.

**The vector extension is a different design, not a wider register.** `vsetvli`
programmes the element width, the register group count, and the tail and
mask policies at *runtime* — which is how one fixed 32-bit encoding
describes a vector of a length the instruction does not encode. Measured
already: clang emits it from plain C.

## The four courses

### A. `rvasm` — "RISC-V: The Encoding Spectrum"
Roadmap items **1** (ISA), **2** (Assembly), **3** (Instruction Encoding).
~5 concepts.

1. `rv-isa` — the modular ISA as a *set of documents*: I, M, A, F, D, C,
   Zicsr, and what each letter buys. Measured: compile the same C under
   different `-march` and diff what appears. The base is deliberately
   tiny, and that is the point.
2. `rv-encoding` — the encoding, and the spectrum. The 7-bit opcode, the
   three RISC-V instruction formats (`R`, `I`, `S`, `B`, `U`, `J` — six,
   not three), funct3/funct7, and the **register indices being in
   different bit positions in different formats**, which is why the
   assembler is not a lookup table. Measured from real bytes.
3. `rv-compressed` — the C extension: 16-bit encodings, what they
   compress, the reserved encodings, and the real cost (a compressed
   instruction can be *undecodable* where the 32-bit form was fine).
   Measured: the fraction of the corpus that is 2 bytes, and whether the
   compiler chooses it.
4. `rv-immediate` — the immediates, and **why they do not fit**. I-type's
   12-bit, S-type's asymmetric `imm[11:5]|imm[4:0]`, B and J-type's
   bit-permuted immediates. Measured: the ±2 KiB branch range from the
   encoding, and what the assembler does at the edge.
5. `rv-verify` — the decoder, the two-reader cross-check, and the map
   audit.

### B. `rvabi` — "The RISC-V ABI, and the Register That Isn't There"
Roadmap item **4** (Calling Conventions). ~4 concepts.

6. `rv-calling` — the calling convention: `a0`–`a7`, `s0`–`s11`,
   `t0`–`t6`, and why there is no red zone and no frame pointer
   requirement. The compiler as the test subject, as in `x86abi`.
7. `rv-noflags` — **the section's spine.** No flags register, no
   condition codes, therefore no `CMOV` and no `SETcc`. Measured: what
   the compiler emits instead, and the cost in instructions. This is
   where the x86-64 and AArch64 designs are compared and the absence
   explains both.
8. `rv-registers` — the register file as a partitioned namespace: the ABI
   names *roles* not registers, `x0` is hardwired zero, and
   `ra`/`sp` are not privileged. Measured from the compiler's output.
9. `rv-compressed-cost` — the ABI's interaction with compression, and
   what a disassembler has to do to find an instruction boundary.

### C. `rvpriv` — "RISC-V Privileged Architecture"
Roadmap items **5** (Privilege Specification), **6** (Virtual Memory),
**7** (Interrupts). ~5 concepts.

10. `rv-modes` — U/S/M, the CSR trap, and how a trap becomes a function
    call. Quoted with a document; the *encoding* of `csrr`/`csrw`/`csrrw`
    and the immediate forms is measured, and `Zicsr`'s recent split out
    of the base is a good, checkable fact.
11. `rv-paging` — Sv39/Sv48/Sv57, the three levels, the PTE bit
    assignments, and the **A/D bits and the implicit page-fault path**.
    Quoted for the formats; the *relocation side* measured, as the hinge
    to `obj`/`reloc`/`link`, exactly as `a64sys` did.
12. `rv-traps` — `stvec`/`sepc`/`scause`/`stval`/`sie`/`sip` and the trap
    model. Quoted; the encodings measured.
13. `rv-verify` — the artifact, and the measured/quoted boundary made
    explicit, as a table.

### D. `rvat` — "RISC-V Atomics and the Vector Extension"
Roadmap items **8** (Atomics), **9** (Vector Extension). ~5 concepts.

14. `rv-amo` — the A extension: `lr`/`sc` and the reservation as a
    *loop by construction*, the AMOs, and why there is no implicit lock
    anywhere. Contrast with x86-64's LOCK, which is the mission doc's
    "differs in kind" point. Measured: what the compiler emits for a
    C11 atomic compare-exchange with and without `-march=...a`.
15. `rv-fence` — `fence`, and the fact that RISC-V's ordering model is
    **defined in terms of the fence's predecessor/successor sets**, which
    is a genuinely different formulation from both x86-64's TSO and
    AArch64's access modes. Decode `fence`'s encoding and show the four
    fields.
16. `rv-vector` — `vsetvli`/`vsetivli`/`vsetvl`, the `v`/`vl`/`vt`/`vd`
    register groups, `vle64`/`vse64`, and **the four fields `vsetvli`
    carries**: SEW, LMUL, and the tail/mask policies. Measured from the
    bytes clang emits.
17. `rv-vector-mask` — the mask registers `v0` and the mask-agnostic
    encodings, plus the tail/mask policies as the thing that makes
    portability hard. And the honest caveat: **this machine cannot run
    them**, so it is reference plus a decoder that works on bytes.
18. `rv-dataflow` — the artifact, the encode/decode round trip, the
    two-reader cross-check, and the measured/quoted boundary.

## The no-duplication seam

Seven neutral courses taught these topics neutrally; the four x86-64 and
three AArch64 courses are the same subject for five of them. So for every
item in this section: the **principle** belongs to `exe`, `mem`, `smp`,
`simd`, `priv` and the earlier per-arch courses — link out; this section
owes the **exhaustive RISC-V reference**, and where the three architectures
differ **in kind** rather than in detail, that difference IS the concept.

## Rules (inherited from the two previous section plans, all twelve apply)

Plus the two the later sections added:

**13. Label every claim MEASURED / MEASURED-ON-BYTES / QUOTED**, in the
artifact output and in the page. A label rendered two different ways is not
a label, and a reader cannot check a category he cannot find.

**14. Every concept id is `rv-` prefixed and grepped before use.** A concept
id is resolved GLOBALLY by `render_concept()` in `web/src/helpers.ch` with
no course in the key; the x86-64 section lost three names to this.

**15. The two-reader check must be able to fail.** Each course runs a
**poison**: remove a model or flip a bit, and the reported number must
move, or the run prints `[POISON FAILED]`. A control that cannot move the
number it measures is a comment that says the word POISONED. This rule
exists because the AArch64 data-path course found its own cross-check
printing 0 disagreements over a corpus where 85 instructions genuinely
disagreed — not one of the four bugs printed a wrong word, they all made
the comparison vacuous.
