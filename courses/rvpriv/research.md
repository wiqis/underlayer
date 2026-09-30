# RISC-V Privileged Architecture — research notes

Working notes for the course whose id is `rvpriv` and whose title is **The
RISC-V Privileged Architecture**. Roadmap items 5, 6 and 7 — the third of the
four `docs/riscv-section-plan.md` splits.

These are the sources, the decisions, and the things that were measured
before a page was written. Everything here that is a number is also in
`assets/samples/rvpriv.out`, and the harness `assets/samples/crosscheck.py`
re-asks every one of them in **398 checks**.

---

## 1. The premise, and why this one is different in kind

`qemu-riscv64`, `spike` and `riscv64-linux-gnu-{gcc,as,ld}` are all **ABSENT**
on this host. That is checked and printed by `build_samples.sh` before it
compiles anything, and again in section 1 of the artifact.

The two RISC-V courses before this one also had no machine, and their absence
was **the ability to TIME** — a compiler's choice is visible in bytes, so
instruction counts and byte counts carried the weight a ratio would have.

This course's absence is **the ability to OBSERVE THE SUBJECT.** A privileged
architecture is largely a *document*: `csr[9:8]` is a privilege, `stvec`'s low
two bits are a mode, and the enforcement of both is a property of silicon this
host does not have. So:

* `NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN`
* `NO EXCEPTION IS EVER TAKEN, NO INTERRUPT IS EVER TAKEN, NO PAGE FAULT IS
  EVER RAISED, NO TLB IS EVER CONSULTED AND NO ACCESS FAULT IS EVER RAISED` —
  six absences, listed as six, because each is a separate thing the course
  would otherwise be able to say
* no RISC-V linker either, so **no relocation in the course is ever resolved**

What survives is the part a compiler author and a page-table writer both need,
and all of it is a bit pattern, a count of bit patterns, an arithmetic identity,
or a refusal from a real assembler:

* the **twelve CSR instruction encodings** and the single `funct3` bit between
  the two families
* the **CSR address arithmetic** and its decomposition into accessibility and
  privilege
* the **relocation records** a page-table walk emits
* the **size arithmetic** of Sv39/48/57 and of the pairing rule

`ecall` is the one place where overstating is tempting, so it is labelled
**MEASURED-AS-EMITTED** wherever it appears. What is measured: clang emits
`0x00000073` and the ABI's registers are `a7`/`a0`. What is **not**: the trap is
taken, supervisor mode is entered, `a7` is read, a kernel exists, anything
comes back.

The x86-64 section's **4.92x** and **27.65x** have **no counterpart here and
are not invented to fill the gap.**

---

## 2. Sources

| Short name | Document | Used for |
|---|---|---|
| `priv-spec` | *RISC-V Privileged Architecture*, Volume II, v20260120 | the three modes and the hole at encoding 2; the CSR address decomposition (§1); MPP/SPP and the trap-entry stack (§2.1.6.1); `medeleg`/`mideleg` (§2.1.1.8); the interrupt cause-number rule (§11.1.1.3); the two A/D schemes and Svade (§11.1.3.1); Sv39/48/57 (§11.1.4/5/6); the `satp` field layout (§11.1.1.11) |
| `riscv-elf` | *RISC-V ABIs Specification* v1.0 | Table 3, the relocation codes (16, 17, 20, 23, 24, 25, 26, 27, 28, 51); chapter 3, the syscall convention (`a7` = syscall number, `a0` = return); chapter 8, the `PCREL_HI20`/`PCREL_LO12` pairing rule and the "the addend must be 0" sentence |
| `rv32-unpriv` | *RISC-V Unprivileged ISA*, Volume I | the Zicsr split — "the base integer set no longer contains the six CSR instructions"; the `auipc` immediate that the previous course measured |

Three documents, and **every QUOTED row in the 44-row provenance table names one
of them with a section.**

---

## 3. The concept-id collision, decided before the pages were written

The section plan gives the id **`rv-verify`** to this course's artifact page.
`rvasm` already has it. A concept id is resolved **globally** by
`render_concept()` in `web/src/helpers.ch` with **no course in the key**, so a
collision does not 404 — it silently serves another course's page under this
course's URL.

`rv-modes`, `rv-paging` and `rv-traps` were checked against
`web/src/helpers.ch` by grep and are free. The fourth is therefore
**`rv-boundary`**, named for what the page is: forty-four provenance rows with
the count printed, sixteen limits, the two scope lists, and the retractions. It
is also the last concept, so "boundary" is literally where the course ends.

---

## 4. Decisions taken during the build

### 4.1 Borrow the decoder, do not fork it

The instruction reader is `courses/rvasm/assets/samples/rvdec.py`, located by
walking **up** the tree so a moved directory does not break it. This course
**prepends two models** and edits no sibling:

* `m_csr_address` — decomposes a CSR address into accessibility and privilege.
  The inherited `s_system` reads `inst[31:20]` and prints three hex digits,
  which is the *address* and not the *privilege*.
* `m_sfence_vma` — names `SFENCE.VMA` (funct12 = 0x120), which the inherited
  decoder **cannot name at all**: it declines any SYSTEM word whose `rd` or
  `rs1` is non-zero, because `ecall` and `ebreak` were the only funct3 = 0
  words it knew.

The first run of the cross-check reported **twelve** `SFENCE.VMA` words as
disagreements, and a reader would have had to work out that a decoder printing
`(undefined)` is claiming the architecture defines no meaning for a word the
architecture defines precisely.

The cost is retraction **R14**, which admits the defect is in the sibling's
code. That is published rather than patched across course boundaries, because a
course that edits its neighbour to make its own numbers work is a course whose
numbers are not measurements any more.

### 4.2 Ship both wrong `satp` masks

`bits.c` contains `satp_ppn54_wrong` and `satp_ppn44_wrong` **on purpose.** The
correct PPN is 36 bits (64 − 4 MODE − 16 ASID − 8 granule shift). 44 is what
falls out of the subtraction if you stop one step early, and 54 is the width of
a PTE's PPN applied to the wrong register. Both compile with no diagnostic, so
the only way to make the mistake *visible* rather than *describable* is to put
it in the corpus and read the widths out of the compiler's own shifts.

The widths are **recovered**, not assumed: a `slli by L ; srli by R` pair on a
64-bit value returns input bits `[R−L : 63−L]`, so the width is `64 − R` and
the low bit is `R − L`. A pair with no `slli` is `L = 0` and the formula still
holds, which is why the MODE row is in the table at all.

### 4.3 Build FOUR objects for the layout experiment, not two

The claim is that the number of relocations a walk emits is a property of the
**data layout**, not of the walk. The first draft built two objects, both at the
target default, and wrote "the same number of instructions in both" over a table
whose own column read **58 against 13**.

Building `-fno-pic` as well separates the confound: the **clean pair** is 59 vs
60 instructions with the HI20 count going 2 → 4, and the **confounded PIC pair**
is 58 vs 13 because the merged-globals pass unrolled the three fill paths when
the tables were adjacent and had nothing to merge when they were not. The
section prints the confounding number in its own column and says it does not
pick the flattering pair. That is retraction **R13**.

### 4.4 Two wrong masks in the record table, and one that is neither

`r_info`'s high half is deliberately corrupted in a **copy** of the relocation
data for poison 2, which loses 104 names and **silently misnames 5 of 125** —
because a poison that is loud is easy to catch and one that is quiet is not.

### 4.5 `sp.s`'s filler is `0x01`, not `0x0f`

The `.space` fill byte for the six padding distances is **`c.nop` (`0x01`)**.
With `0x0f` the filler accounted for **4,623 of 4,645** disagreements in an
earlier run, which made the padding experiment a measurement of the filler
rather than of the distance.

---

## 5. The retractions, by what kind of failure they are

Seventeen, each with a `SOURCE` line saying where the bad claim was written down
*before* it was measured.

| Kind | R's | What went wrong |
|---|---|---|
| Wrong field, right number | R16, R17 | `inst[31:20]` out of an S-type word is not an immediate; and the first fix named that register `rd`, which a store does not have |
| The wrong register for the job | R3 | `csrw` paired with `csrrs` on the reasonable-sounding assumption that `w` means "write the value in" |
| A number about the sweep, not the field | R2 | the raw mask sweep moved 20 bits; the isolated one moved 12; the *first* isolated one moved 11 |
| A compiler property reported as a convention | R4, R13 | dead-code elimination at `-O1` reported as the wrapper's shape; a confounded layout pair |
| A wrong field width that compiles | R5, R6 | 54 and 44 bits of `satp` PPN |
| An unenforced rule called a bug | R7, R8 | the pairing distance and the LO12 addend — quoted, not measured, because there is no linker |
| Reading a disagreement as correctness | R12 | ten `c.li a2, -1` against `li a2, -0x1` spelling differences counted as misreads |
| The subject, not the reader | R10, R11 | what a trap *does*; and that `stvec`'s mode is a property of the value |
| Someone else's code | R14 | the sibling decoder cannot name `SFENCE.VMA` |
| Both readers wrong the same way | R15 | `sfence.vma %0` assembles to `0x12050073`, which is neither of the two defined forms |
| The course's own reader | R1 | the inherited decoder prints the CSR number and stops |

**None of the seventeen is a mistake about how a computer works** — seventeen
courses in a row. Every one is a discovery about the machinery built to read
the hardware.

---

## 6. The scope lists, and why they are pinned

Eight things a reader therefore **cannot** conclude, beside ten that they
**can**, and the second list being longer is the finding: there is more that can
be read off bytes than there is that can be said about behaviour.

All eighteen claim sentences are pinned **whole** in `crosscheck.py`, because a
substring check passes over "That a page is ever walked" edited to "That a page
is walked, always" — the sentence keeps its subject and its verb and reverses
its meaning. That was confirmed by mutation, not by argument: twenty-plus
deliberate corruptions of the recorded output, every one caught.

---

## 7. What is committed, and why

Unlike `rvabi`'s sample directory, this one **commits its object files**, the
`llvm-objdump-21` and `llvm-readelf-21` listings, and the raw `*.relocs`
tables. Every byte claim in the course is a claim about a file, and a reader
with a hex editor and no cross-compiler should be able to check it. The
relocation codes (23, 24, 25, 26, 27, 51) are in the committed `.relocs` files,
so a reader who wants to know what `R_RISCV_PCREL_HI20`'s number is does not
need clang.

`rvpriv.out`, `run1.txt` and `run2.txt` are byte-identical from a fresh
`build_samples.sh`, so the 398-check harness runs on a machine that never ran
the cross-compiler.

---

## 8. The toolchain, as recorded

```
assembler:     clang version 21.1.8   (--target=riscv64-linux-gnu)
disassembler:  Ubuntu LLVM version 21.1.8  (llvm-objdump-21)
linker:        riscv64-linux-gnu-ld   IS NOT INSTALLED
emulator:      qemu-riscv64  ABSENT
emulator:      spike        ABSENT
```

Both readers of the two-reader check come from **one LLVM tree**, because GNU
binutils has no RISC-V target on this host. So what section 13 establishes is
*"this decoder and one other piece of software agree on what the bytes mean"* —
and **not** "either agrees with silicon". That is limit 9.