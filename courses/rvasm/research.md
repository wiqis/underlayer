# RISC-V: The Encoding Spectrum — research notes

Authorised by `docs/course-mission.md`. Plan: `docs/riscv-section-plan.md`.
Roadmap items **1** (ISA), **2** (Assembly), **3** (Instruction Encoding).

This file records **where every claim in the course came from and what was
checked**, so that a later reader can re-derive it rather than trust it. It
is not a summary of the course. It is the provenance.

---

## 1. THE TOOLCHAIN, AND WHAT IT CANNOT DO

Verified 2026-09-30 on the build host.

| tool | result |
|---|---|
| `clang --version` | 21.1.8 |
| `clang --target=riscv64-linux-gnu -march=rv64gcv -S` | C → RISC-V assembly, **and it auto-vectorises** |
| `clang --target=riscv64-linux-gnu -march=rv64gcv -c` | → a real `ELF64 LSB relocatable, riscv` object |
| `llvm-objdump-21 --triple=riscv64 -d` | disassembly — **the second, independent reader** |
| `llvm-readelf-21 -r` | the relocations section 8 quotes |
| `qemu-riscv64` | **ABSENT** |
| `spike` | **ABSENT** |
| `riscv64-linux-gnu-{gcc,as,ld}` | **ABSENT** |

**Consequence, and it is the most important fact in this file: there are no
timings anywhere in this course.** Nothing is executed. Every figure is a bit
pattern, a count of bit patterns, an arithmetic identity, or a refusal from a
real assembler.

The x86-64 section has speedup ratios and code-density ratios at four
optimisation levels. **They have no counterpart here and are not invented to
fill the gap.** Where a page would carry a ratio it carries a byte count, an
instruction count, or a refusal, and says which. The artifact states this in
its own header, in section 1, and again in section 11; `build_samples.sh`
prints the missing tools and says the sentence out loud.

### The second reader is not fully independent

`clang` assembled the corpus and `llvm-objdump-21` disassembled it, so both
readers ultimately depend on **one LLVM tree**. An independent second
*assembler* does not exist on this host: GNU binutils has no RISC-V target
installed. This is stated in the artifact (section 10's preamble and section
11) and on the course landing page rather than being glossed, because what
section 10 establishes is "this decoder and one other piece of software agree
on what the bytes mean" — not "either agrees with silicon", and there is no
silicon here to agree with.

### And the decoder decodes nothing with a tool

Part one of `rvdec.py` imports `os`, `re`, `struct` and `sys` and nothing
else. ELF64 section headers are read by hand with `struct.unpack_from`
(`e_shoff` at 0x28, `e_shentsize`/`e_shnum`/`e_shstrndx` at 0x3a, 64 bytes per
entry) and `.text` is found by NAME. `llvm-objdump-21` is called to produce
words *about*, never to produce their meaning.

A decoder that shells out to a disassembler is a disassembler with a
hardcoded path in it.

---

## 2. THE THREE CLAIM KINDS, AND WHY THE LABEL IS NOT DECORATIVE

Plan rule 13. Every claim on every page carries exactly one of:

- **MEASURED** — about the compiler or the bytes, by experiment.
- **MEASURED-ON-BYTES** — a property of emitted bytes, cross-checked against
  `llvm-objdump-21` as a second reader.
- **QUOTED** — a manual claim, with a document and a section.

A label rendered two ways is not a label, and a reader cannot check a
category he cannot find. `tools/check_quotes.py` exists partly to make the
MEASURED numbers checkable against the recorded artifact output.

**QUOTED sources, all from the RISC-V unprivileged ISA manual (rv32-unprivileged)
and the calling convention document (riscv-cc):**

| quote | section |
|---|---|
| "RV32I contains 40 unique instructions… reducing base instruction count to 38 total" | 2.1 |
| "In the base RV32I ISA, there are four core instruction formats (R/I/S/U)" | 2.2 |
| "There are a further two variants of the instruction formats (B/J) based on the handling of immediates" | 2.3 |
| "The RISC-V ISA keeps the source (rs1 and rs2) and destination (rd) registers at the same position in all formats to simplify decoding" | 2.2 |
| "the instruction format was chosen to keep all register specifiers at the same position in all formats at the expense of having to move immediate bits across formats" | 2.2 note |
| "the 12-bit immediate field is used to encode branch offsets in multiples of 2 in the B format… the lowest bit in S format (inst[7]) encodes a high-order bit in B format" | 2.3 |
| "By rotating bits in the instruction encoding of B and J immediates instead of using dynamic hardware multiplexers to multiply the immediate by 2, we reduce instruction signal fanout and immediate multiplexer costs by around a factor of 2" | 2.3 |
| "the sign bit for all immediates is always in bit 31 of the instruction" | 2.3 |
| "In practice, most immediates are either small or require all XLEN bits. We chose an asymmetric immediate split (12 bits in regular instructions plus a special load-upper-immediate instruction with 20 bits)" | 2.2 note |
| "The formats were designed to keep bits for the two register source specifiers in the same position in all instructions… When the full 5-bit destination register specifier is present, it is in the same place as in the 32-bit RISC-V encoding. Where immediates are sign-extended, the sign extension is always from bit 12" | zca, Compressed Instruction Formats |
| "The immediate fields are scrambled in the instruction formats instead of in sequential order so that as many bits as possible are in the same position in every instruction" | zca |
| "The RISC-V ABI was changed to make the frequently used registers map to registers x8-x15. This simplifies the decompression decoder by having a contiguous naturally aligned set of register numbers" | riscv-cc |
| "A portion of the Zca encoding space is reserved for microarchitectural HINTs… these instructions do not modify any architectural state" | zca |
| "a hardware implementation including the machine-mode privileged architecture will also require the 6 CSR instructions in the Zicsr extension" | 2.1 |

---

## 3. WHAT WAS MEASURED, AND HOW

All of it reproducible with `./build_samples.sh`, which is the whole
provenance: it compiles the corpus at eight `-march` settings, assembles the
hand-written probes, runs the artifact, runs it twice more to show the runs
are byte-identical, and then runs the harness.

### Section 2 of the artifact — the length rule

Applied to 9 code sections of 9 objects. **1,082 instructions; every walk ends
EXACTLY on its section end.** Length distribution per object is a table;
the same C compiled with and without C gives **95 instructions both ways**
and 380 vs 246 bytes.

### Section 3 — the `-march` sweep

Eight settings, eleven functions of ordinary C. The findings that changed the
course:

- **`rv64i` → `rv64im` GAINS 3 and LOSES 4.** `divuw`, `mul`, `rem` appear;
  `j`, `jr`, `sext.w`, `srli` disappear. A shift-multiply is a *sequence* and
  sequences branch.
- **`rv64if` and `rv64i` are identical** — 146 instructions, 584 bytes, both.
  F buys this corpus nothing, because its only float function accumulates a
  `double` and a `double` needs D. **Kept as a warning about the method.**
- **`rv64imf` → `rv64imafd` GAINS 4 FP instructions and LOSES `jalr`(3) and
  `sd`(4).** Software floating-point calls become register operations.
  The first draft claimed three `auipc` also disappear; **they do not**, and
  that correction is in the page.
- **`rv64gc` → `rv64gcv` GAINS 20 mnemonics and the count nearly doubles**
  (95 → 178). Auto-vectorisation makes the code longer.
- `Tag_RISCV_arch` for `rv64imafdc` is `rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zmmul1p0_zaamo1p0_zalrsc1p0_zca1p0_zcd1p0`:
  **six letters in, twelve names out.**

### Section 4 — the field map

Method: assemble, change **one** operand, OR the XOR over a **sweep**.
- `rd` = `0x00000f80` (bits[11:7]), `rs1` = `0x000f8000` (bits[19:15]),
  `rs2` = `0x01f00000` (bits[24:20]) — **in every format**. This is the
  plan's prediction **inverted**, and it is retraction R1.
- I immediate `0xfff00000`; S immediate `0xfe000e00`; B immediate
  `0xfe000f80` — **differ by exactly bit 7**, which is the S format's imm[0]
  and the B format's imm[11].
- U and J are **both** `0xfffff000` and the two fields are nothing alike.
- Compressed: `rd'` is `0x00000380` (bits[9:7], three bits) and
  `rs2'` is `0x0000001c` (bits[4:2], three bits) — **a different register
  encoding whose value 0 means x8**.

Three method rules, all the results of getting it wrong first: **sweep, do
not pair** (one pair marks the bits where two *values* differ); **a mask is a
LOWER BOUND**; **do not sweep at a `-march` that rewrites the format** (the
first version ran at `rv64gcv`, `lw a0, 8(a1)` became a 2-byte `c.lw`, and
the XOR mixed widths).

### Section 4B — funct7

Base sweep moves bits 25 and 30 of the seven. F/D sweep reaches all seven.
**Both are true and they measure different things**; printing only the first
would claim a two-bit funct7. The seven bits are **not one field**: under
opcode 0x53 they are a five-bit selector at inst[31:27] and a two-bit width
at inst[26:25].

### Section 4D — the permutations

Sweep every reachable value of each compressed displacement, read the word
back, and for each bit of the produced value find the instruction bit that is
1 in exactly the same offsets.

**11 families measured, 7 DISTINCT PERMUTATIONS.** `c.lw` and `c.ld` share
the identical five-bit *window* (`0x00001c60`) and assign it in different
*orders*: `c.lw` puts v[0] at inst[6], `c.ld` at inst[10].

### Section 6 — the compressed space

All 65,536 half-words, classified twice. **16,384 are not reachable at all**
(`bits[1:0] == 0b11` — a fact about the LENGTH RULE, and the number the
assembler's "instruction length does not match the encoding" diagnostic is
really reporting). Of the 49,152 reachable: **2,409 reserved (4.90%)**,
426 HINT, 46,317 neither. One cell (q0, funct3=100) is 2,048 of the 2,409.

Cross-check against the second reader over the exhaustive set: **2,408 agree,
1 disagrees** — and the 1 is `0x0000`, which the reader prints as `unimp`.
Both are right about their own subject and it is reported rather than
normalised away.

### Section 7 — the immediates

Reach computed from the encoding, then confirmed by asking the assembler:

| format | near end | far end | symmetric? | scaled |
|---|---|---|---|---|
| B | 4094 | 4096 | **NO** | ×2 |
| I | 2047 | 2048 | no | |
| J | 1048574 | 1048576 | **NO** | ×2 |
| S | 2047 | 2048 | no | |
| U | 16777200 | 16777216 | no | |

**The best measurement in the concept:** `beq a0, a1, .+4096` is **accepted**
and assembled into two instructions — an inverted branch over a jump. The
assembler does not refuse; it **relaxes**. The diagnostic appears only at
1 MiB and says **"fixup value out of range"** — the word *fixup*, not
displacement, and that is a relocation-shaped failure.

### Section 8 — the pair

`R_RISCV_HI20` + `R_RISCV_LO12_I` (+ `R_RISCV_RELAX` alongside each) against
AArch64's `R_AARCH64_ADR_PREL_PG_HI21` + `R_AARCH64_ADD_ABS_LO12_NC`. The
substantive difference is visible in the names: **no `_PREL_` in RISC-V's**,
because `lui` is absolute and `auipc` is PC-relative.

### Section 10 — the cross-check

**1,082 printed, 1,047 named, 1,047 agree, 0 disagree, 0 length
disagreements. 47 normalisation rules, 47 fired, 0 dead. Four poisons, four
verdicts.**

**And the number it started from**, which is the actual content of this
course's verification concept: the inherited first run reported **354 agree,
701 disagree, of 1,055**. Decomposed (retractions R17–R22):

| cause | words |
|---|---|
| `r_mul`/`r_mulw` with no funct7 guard | 116 |
| `i_alu_imm` raising Undefined for its neighbour's funct3 | 62 |
| `c.mv` unreachable (cell dispatched on `rs1 == 0`, not inst[12]) | 33 |
| branches missing both register operands | 91 |
| branch targets off by one (inst[8] → imm[0]) | 26 |
| `srai` shamt printed as 12 bits when the field is 6 | 35 |
| `fcvt` source/destination swapped | 8 |
| printing conventions (aliases, base names for compressed forms, hex vs decimal) | the rest |

---

## 4. THE CORRECTIONS TO THE PLAN

Three, and all three are in the pages in full.

1. **"the same register number sits in different bit positions in different
   formats."** **FALSE for the base ISA.** `rd` is bits[11:7] in every
   format; `rs1` and `rs2` likewise. The manual says so and says what pays
   for it. The compressed extension *does* introduce a second register
   encoding — three bits, at bits[9:7] and bits[4:2] — which is a real finding
   and is not the one predicted.

2. **"the number of reserved 16-bit patterns you can enumerate and verify
   against the assembler."** The assembler refuses 16,384 of 65,536 —
   **exactly a quarter, and exactly `bits[1:0] == 0b11`**, which is the length
   rule and not a reservation. The number the extension's cost is made of is
   **2,409 of 49,152 = 4.90%**.

3. **"a compressed instruction can be undecodable where the 32-bit form was
   legal."** Kept, but the cost is in the **register file**, not the encoding
   space: `c.lw t0, 0(a0)` is **refused by the assembler** and `lw t0, 0(a0)`
   is four bytes. Four refusals, each one an instruction the 32-bit form
   encodes without difficulty.

---

## 5. WHAT COULD NOT BE DONE, AND IS SAID ON THE PAGES

- **No timing, no execution, no cycle count.** Said on the landing page, in
  the artifact's header, in artifact section 11, and in a `unit-reality`
  block on each concept page.
- **The `ecall` convention.** Only that the compiler emits `0x00000073` and
  that 31 of its 32 bits are a fixed pattern. **Not** what it does, which
  register holds a syscall number, or whether the trap is taken. Labelled
  weaker than a measurement of the convention would be.
- **Nothing is linked.** No RISC-V `ld` on this host, so the `auipc`+`addi`
  pair is measured as *two instructions and two relocations* and **not** as
  a pair that lands on the right address. Stated on the immediate page and in
  artifact section 8.
- **No trap behaviour for any reserved encoding.** "Reserved" means the
  *specification* has not assigned the encoding; what an implementation does
  is a property of that implementation.
- **Nothing generalises from an empty row.** Every distribution is a
  distribution of what clang chose for eleven functions of C at one version.

---

## 6. LINKS OUT, AND WHY EACH IS NOT RE-TAUGHT

Verified present before linking:

| link | why it is a link and not a re-teach |
|---|---|
| `/courses/isa/lessons/isa-length` | the contrast case: a variable-length encoding where the length *is* the problem |
| `/courses/isa/lessons/isa-modrm` | why x86 needed a byte to name a register-from-memory operand, against RISC-V's fixed field |
| `/courses/a64asm/lessons/a64-encoding` | the same *goal* (register specifiers still) by a completely different mechanism |
| `/courses/a64asm/lessons/a64-immediate` | the same problem with a different answer: 1,302 of 2³² constants vs. every 12-bit value and nothing beyond |
| `/courses/exe/lessons/exe-verify` | the verification vocabulary this course shares, and the course that would check the address pair |
| `/courses/link` | the only course that could prove the `auipc`+`addi` pair lands correctly |
| `/courses/reloc` | what a *fixup* is; the section 7 refusal message is the first appearance of the word |
| `/courses/elf` | the container, and `.riscv.attributes` is the same exercise with a different name |

The no-duplication rule, from the plan: the *principle* belongs to `exe`,
`mem`, `smp`, `simd`, `priv` and the earlier per-arch courses. This course
owes the exhaustive RISC-V reference, and where the three architectures
differ **in kind** rather than in detail, that difference is the concept.

---

## 7. REPRODUCING EVERYTHING

```
cd courses/rvasm/assets/samples
./build_samples.sh                 # corpus + artifact + determinism + harness
python3 crosscheck.py rvdec.out    # 128 checks, 0 failures
python3 rvdec.py --run             # the whole report, 2,408 lines
```

Requires `clang` with a `riscv64` target and `llvm-objdump-21`. **Nothing
else**, and in particular **nothing that runs RISC-V code**.

The recorded outputs — `rvdec.out`, `run1.txt`, `run2.txt` — are committed,
so a reader can check every figure in the course without installing a
cross-compiler. The object files are not, and `build_samples.sh` reproduces
them from `corpus.c`, `rv.s` and `far.c` with one command.

**A course whose numbers can only be checked by first rebuilding its own
artifact is a course whose numbers are claims.**
