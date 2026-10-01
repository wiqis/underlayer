# Underlayer Course Roadmap

**Restructured 2026-10-01. The 738 items below are unchanged.** No item was
added, removed, merged into another bullet, reworded, or re-ticked. What
changed is that the 678 un-started items are now grouped into **14 planned
courses** instead of 35 flat topic sections, and every one of them names the
course that will teach it. `python3 tools/todo_check.py` proves the set of item
titles is identical to the pre-restructure file and exits non-zero if it is not.

## What is in this document

| Part | What | Items |
|---|---|---|
| 1 — Completed | Built courses. Unchanged headings, annotations and provenance. | 60 |
| 2 — Planned | 14 planned courses, each named, sized and traceable. | 678 |

---

## The shape of the remaining work

### The 14 planned courses

| # | Planned course | Slug | Items | Roadmap sections it absorbs |
|---|---|---|---|---|
| 1 | Operating Systems, Processes and Virtualization | `os` | 64 | Operating Systems (27); Runtime & Process Internals (14); Virtualization (20); Boot & Startup (3 of 13) |
| 2 | Hardware, Firmware and the Boot Path | `hwboot` | 39 | Firmware & Embedded Systems (17 of 18); Boot & Startup (10 of 13); Hardware Interfaces (12) |
| 3 | Memory Systems, Concurrency and Machine Arithmetic | `memconc` | 60 | Memory (27); Concurrency (20); Mathematics for Systems (11 of 13); Firmware & Embedded Systems (1 of 18); System Design at the Lowest Level (1 of 16) |
| 4 | Filesystems, Version Control and Replication | `storage` | 44 | Filesystems (21); Source Control Internals (10); Distributed & Networked Storage (12); Binary Formats & File Formats — Git object database (1 of 41) |
| 5 | Networking and Network Protocols | `network` | 52 | Networking (28); Network Protocols (23); Binary Formats & File Formats — PCAP packet captures (1 of 41) |
| 6 | Cryptography and Security Internals | `crypto` | 53 | Cryptography (31); Security Internals (21); Binary Formats & File Formats — X.509 certificates (1 of 41) |
| 7 | Text, Compression, Archives and Serialization | `encodings` | 59 | Unicode & Text (10); Compression & Encoding (16); Binary Formats & File Formats — archives (5 of 41); Binary Formats & File Formats — text and serialization formats (12 of 41); Protocol & Serialization Design (14); Mathematics for Systems (2 of 13) |
| 8 | Compilers, Languages and Build Systems | `compiler` | 67 | Compilers (31); Compilers & Languages — Advanced (21); Build Systems & Toolchains (15) |
| 9 | Virtual Machines, Runtimes and Language Internals | `vm` | 63 | Language Runtimes (19); JVM (17); WebAssembly (12); Programming Language Internals (15) |
| 10 | Data Structure and Database Internals | `data` | 41 | Databases & Storage Engines (21); Data Structures & Algorithms — Deep Internals (18); Binary Formats & File Formats — SQLite and Berkeley DB (2 of 41) |
| 11 | Graphics, Images and Page Description | `graphics` | 29 | Graphics (20); Binary Formats & File Formats — image and page formats (9 of 41) |
| 12 | Audio, Video and Media Containers | `media` | 31 | Audio & Video (22); Binary Formats & File Formats — audio and video containers (9 of 41) |
| 13 | Debugging, Observability and Systems I/O | `debugio` | 46 | Debugging & Observability (19); Binary Formats & File Formats — PDB (1 of 41); System Design at the Lowest Level (15 of 16); Terminals & Shells (11) |
| 14 | Distributed Systems, Clocks and Consistency | `distsys` | 30 | Distributed Systems (21); Time & Clocks (9) |
| | **Total** | | **678** | 35 sections, all of them |

### Why 14 courses and not 35

A course is not a folder of pages. Each one costs a `chemical.mod`, a
`manifest.json`, a build entry point, a `tools/verify_<course>.py`, a
`crosscheck.py` harness with its recorded output, a landing page, a route,
a verifier pass and a commit that has to stay green. That overhead is paid
**per course**, and it is the part an AI agent pays over and over while
trying to finish a roadmap.

Read as one-course-per-item, the 678 un-started items ask for 678 builds,
678 verifiers and 678 harnesses. Read as 14 courses, they ask for 14. The
item count is identical; only the number of times the fixed cost is paid
changes. That is the whole argument, and it is the founder's: *"we want to
teach less courses, but teach everything still, NOT miss anything, this way
AIs would be able to complete the courses faster."*

35 sections became 14 courses. Nothing was dropped to get there.

### The size target, and the arithmetic behind it

The 33 built course directories run **4 to 24 concepts** (`elf`, `pe` and
`macho` at 24; `coff`, `obj` and `jvm` at 18; `rvpriv` at 4), excluding `hat`,
which is a 69-concept test-prep course and not part of this comparison. The
target set here was
**roughly 48 roadmap items per course: mean 48.4, range 29–67.**

The honest consequence has to be stated. Converting roadmap items into
concepts using the ratio measured on the built courses:

| Built course group | `[x]` items | concepts | concepts/item |
|---|---|---|---|
| x86-64 (`x86asm`+`x86abi`+`x86sys`+`x86simd`) | 20 | 26 | 1.3 |
| AArch64 (`a64asm`+`a64abi`+`a64sys`+`a64simd`) | 10 | 21 | 2.1 |
| RISC-V (`rvasm`+`rvabi`+`rvpriv`+`rvat`) | 9 | 17 | 1.9 |

At 1.3–2.1 concepts per item, a 48-item planned course is **60–100
concepts**, which is 3–4x the largest course ever built. So a planned course
here is explicitly **not one build**. It is a landing page, one manifest, one
verifier and one harness covering 3–5 modules built and committed separately,
each module landing as its own concept set with its own harness checks. That
is where the saving comes from: the per-course overhead is paid once, and the
per-concept work is still committed in reviewable pieces.

The alternative was rejected by arithmetic, not by taste. To stay at or
below 24 concepts a course can hold at most 16 roadmap items, which over 678
items is **at least 43 courses** — more courses than the 35 sections being
merged away, so it defeats the instruction instead of serving it. 14 is the
number where the per-course cost is paid once per *subject* instead of once
per *line of a checklist*. A further split into modules, not courses, gets the
size back down without paying that cost again.

### Grouping rules applied

Grouped by **subject coherence**, not by section boundary. The 35 sections
were written as topics; a course has to be finishable on its own.

Merged without hesitation, because the concepts correspond:

- **Image and page formats with graphics.** PNG, JPEG, GIF, WebP, AVIF, TIFF,
  SVG, PDF and PostScript are all encoders and decoders over a pixel or a
  page; a learner who has rasterised a triangle and sampled a texture meets
  a scanline filter as the next step of the same problem, not a new subject.
- **Audio/video formats and containers together.** WAV, AIFF, FLAC, Ogg,
  Matroska, MP3, MP4, MPEG-TS and MPEG-PS each sit next to their codec in the
  same course: a container is taught as the box the codec's output is put in.
- **Archive formats with compression.** ZIP, GZIP, TAR, 7z and RAR are
  DEFLATE, LZ77, Huffman and a directory table — containers over the
  compression course, not separate subjects.
- **Cryptography with security internals.** An AEAD tag, a stack canary and
  an ASLR base are the same threat model. Splitting them teaches a
  primitive and its use-apart.
- **The compilers sections with each other, and with build systems.** Lexing
  through codegen, then type systems and metaprogramming, then Make/Ninja/
  CMake/cross-compilation is one chain: the parts of a toolchain, in the order
  a toolchain runs them.
- **The OS sections with each other.** Kernel, processes, `fork`/`exec`,
  handles, loaders and virtualisation are one subject seen at three layers.
- **Runtimes, the JVM, WebAssembly and language internals.** All four are a
  language's runtime and object layout in four vocabularies — and `wasm`+
  `jvm` are already merged on the built side by `docs/course-merge-plan.md`.
- **Distributed systems with clocks.** Logical clocks, vector clocks and NTP
  are the same first chapter of a distributed-systems course.

Deliberately **not** merged, as traps:

- **Not merged by size.** `graphics` (29) and `media` (31) are neighbours in
  the table and stayed apart; a reader finishing one does not want the other.
  `compiler` is 67 because the chain is long, not because nothing else was
  left.
- **Not merged for tidiness.** Databases keep their own course even at 41
  items; `sqlite`/`berkeleydb` were pulled out of the flat format list into it
  rather than scattered across a formats course that no longer exists.
- **`data` holds hash tables, B-trees, B+ trees, Bloom filters, LSM trees and
  query planners together** because those are the *same* structures in their
  engine role and in their own right. Four titles in this roadmap are literal
  duplicates across the two lists it absorbs, so a course that taught them
  twice would be worse than one that teaches them once and shows both uses.

### Sections that were split, and why

Four of the 35 sections were cut. Every other section moved whole.

| Section | Split into | Why |
|---|---|---|
| Binary Formats & File Formats — 41 un-started items across 8 courses; its 7 `[x]` items stay in Part 1 | `graphics` (9), `media` (9), `encodings` (17), `data` (2), `storage`, `network`, `crypto`, `debugio` (1 each) | This is not one subject, it is a list. 41 items with images, audio, archives, serialization, certificates, packet captures and a Git object database in it is a table of contents, not a course outline. Each format went to the course that already teaches the machinery it is a format of. |
| Mathematics for Systems (13) | `memconc` (11), `encodings` (2) | Two different audiences. Representation and arithmetic (two's complement, fixed point, IEEE 754, bit manipulation, modular arithmetic, probability of a race) belong with memory and concurrency; information theory and Shannon entropy are the *definition* of a compression course and read as an unexplained prerequisite anywhere else. |
| Boot & Startup (13) | `hwboot` (10), `os` (3) | The section has a hinge in it. UEFI → `EFI_STUB` → kernel entry is firmware; kernel initialisation, PID 1 and system startup are the first three things `os` teaches. Putting PID 1 in a firmware course would be wrong in both directions. |
| Firmware & Embedded Systems (18) | `hwboot` (17), `memconc` (1) | `Memory-Mapped I/O` is memory access, and the memory course already owns `Memory-Mapped Files`. Splitting it keeps both courses internally consistent; the firmware course still teaches UART, SPI, I²C, timers and DMA, which are all memory-mapped registers. |

### Titles that appear on two roadmap lines

Sixteen titles in this roadmap sit on two roadmap lines each, and one more is
a near-duplicate. All of them are kept — both lines, `- [ ]` or `- [x]`, as
they were. What changed is that each duplicate now names where it is taught
instead of looking like an accident. The sixteen exact duplicates are in the
first thirteen rows; the last row is the near-duplicate.

| Title | Lines | Handling |
|---|---|---|
| Learn B-Trees / Learn B+ Trees / Learn Bloom Filters / Learn Lock-Free Data Structures | Databases & Storage Engines; Data Structures & Algorithms | One concept each, annotated on both lines. Same concept, two roadmap lines. |
| Learn Rasterization | Graphics — two consecutive lines | One concept `rasterization`. Same concept, two roadmap lines. |
| Learn Bootloaders | Firmware & Embedded Systems; Boot & Startup | One concept `bootloaders` in `hwboot`. |
| Learn DMA | Firmware & Embedded Systems; Hardware Interfaces | One concept `dma` in `hwboot`. |
| Learn Memory-Mapped I/O | Firmware & Embedded Systems; System Design at the Lowest Level | One concept `mmio` in `memconc`. |
| Learn Secure Boot | Security Internals; Boot & Startup | Taught in `hwboot` (it is a firmware measurement chain); `crypto` keeps the line for the attack surface. |
| Learn Consistent Hashing | Distributed Systems; Distributed & Networked Storage | Taught in `distsys`; `storage` keeps the line for its use in object storage. |
| Learn Stack Unwinding | Debugging & Observability; Language Runtimes | Taught in `debugio`; `vm` keeps the line for its use in exception handling. |
| Learn Deadlocks | Operating Systems; Concurrency | Taught in `os`; `memconc` keeps the line for user-space deadlock. |
| Learn Coroutines | Language Runtimes; Concurrency | Taught in `vm`; `memconc` keeps the line for user-space use. |
| Learn NTP | Network Protocols; Time & Clocks | Wire protocol in `network`; clock synchronisation in `distsys`. |
| Learn Entropy | Cryptography; Mathematics for Systems | Cryptographic entropy in `crypto`; Shannon entropy in `encodings`. |
| Learn WebAssembly Binary Format | `[x]` under Binary Formats; `[ ]` under WebAssembly | The `[ ]` line is already satisfied by the built `wasm` course (`wasm-header`, `wasm-sections`, `wasm-leb128`). Both lines stay. |
| Learn JVM Class File Format / Learn JVM Class Files | `[x]` under Binary Formats; `[ ]` under JVM | The `[ ]` line is already satisfied by the built `jvm` course (`jvm-header`, `jvm-constant-pool`, `jvm-code`). Both lines stay. |

### How to read an annotation

Shown here without the leading checkbox so the example is not itself parsed
as a roadmap item:

```
Learn jemalloc  — `memconc`, from Memory, concept `jemalloc`
Learn PNG — Portable Network Graphics  — `graphics`, from Binary Formats & File Formats, concept `png`
Learn DMA  — `hwboot`, from Hardware Interfaces, concept `dma`. same concept; this line duplicates the Firmware & Embedded Systems one
```

`— \`<slug>\`` is the planned course. `from <section>` is where the line came
from, so a reader can still find the section it used to live under. `concept
\`<id>\`` is the **proposed** concept id. Concept ids are *proposed, not
registered* — a concept gets a real id when its course is built, and the
proposal here is the id that build is expected to take. They are generated
from the item title by one rule, so they are reproducible and comparable
rather than hand-picked:

> strip a leading `Learn `, lowercase, replace every run of non-alphanumeric
> characters with a single `-`, trim leading and trailing `-`.

Two short override tables handle the cases the rule mangles. The first is
keyed by the item title, for the six where the rule cannot tell C from C++
(`C++ ABI` → `cpp-abi`; `C ABI` stays `c-abi`). The second is keyed by the
slug the rule produced, for spelling (`H.265 / HEVC` → `hevc`, `ext4` →
`ext4` not `ext-4`, `Memory-Mapped I/O` → `mmio`). No id is assigned by
guessing what the concept will contain.

### The machine check

```bash
python3 tools/todo_check.py            # exits 0 only if nothing moved
python3 tools/todo_check.py --against docs/courses-todo.md.before  # diff two revisions
```

It verifies, and exits non-zero on any failure:

1. total items 738, checked 60, unchecked 678
2. every `- [ ]`/`- [x]` line is well formed
3. the **multiset** of item titles, sorted, hashes to the value recorded
   when the restructure was made — so no item added, dropped, reworded,
   re-ticked, or merged into another bullet
4. the 60 `[x]` titles are still exactly the same 60
5. every unchecked line carries an annotation naming one of the 14 slugs
6. the per-slug counts on the lines are 64/39/60/44/52/53/59/67/63/41/29/
   31/46/30 and sum to 678, matching the summary table above

The multiset, not the set: sixteen titles appear on two lines each, so a
check that deduplicated would pass while a line had been silently deleted.

---

# Part 1 — completed work (60 items, unchanged)

Every line below is what it was before the restructure, under the heading it
already had. The 60 `[x]` items and the courses that teach them were
deliberately left alone — `docs/course-merge-plan.md` records that decision
separately and this restructure does not touch it. The only text added under a
heading is one sentence, under the first, pointing at where its un-started
siblings went.
## Binary Formats & File Formats

Its 41 un-started items moved into the planned courses in Part 2, each
to the course that already teaches the machinery it is a format of. The
seven `[x]` lines below did not move.

- [x] Learn ELF — Executable and Linkable Format
- [x] Learn PE — Portable Executable Format
- [x] Learn Mach-O — Mach Object File Format
- [x] Learn DWARF — Debugging Data Format
- [x] Learn COFF — Common Object File Format
- [x] Learn WebAssembly Binary Format
- [x] Learn JVM Class File Format

## Executables, Linking & Loading

- [x] Learn Object Files
- [x] Learn Symbol Resolution and Symbol Tables
- [x] Learn Relocations, PIC and PIE
- [x] Learn Static Linking and Linker Scripts
- [x] Learn Dynamic Linking and Shared Libraries
- [x] Learn Executable Images and OS Loading
- [x] Learn Executable Security and Hardening

## CPU Architecture

- [x] Learn The Instruction Set Architecture
- [x] Learn How a CPU Executes Instructions
- [x] Learn The Memory Hierarchy
- [x] Learn Exceptions, Privilege and Mode Changes
- [x] Learn Multiprocessor Architecture
- [x] Learn SIMD and Vector Processing

## x86-64

- [x] Learn x86-64 Assembly
- [x] Learn x86-64 Instruction Encoding
- [x] Learn x86-64 Calling Conventions
- [x] Learn x86-64 Stack Frames
- [x] Learn x86-64 ABI
- [x] Learn x86-64 System Calls
- [x] Learn x86-64 Interrupts and Exceptions
- [x] Learn x86-64 SIMD Instructions  — `x86simd`, concept `x86-sse`
- [x] Learn x86-64 AVX and AVX2  — `x86simd`, concept `x86-avx`
- [x] Learn x86-64 AVX-512  — `x86simd`, concept `x86-avx512`. Quoted, not
      measured: this machine reads all five CPUID feature bits and all three
      XCR0 state bits as zero, so the concept is reference plus a bytes-only
      decoder and says which is which on every claim.
- [x] Learn x86-64 Atomic Instructions  — `x86simd`, concept `x86-atomics`.
      42 arms, 3 instruments, 266 harness checks.
- [x] Learn x86-64 Memory Ordering  — `x86simd`, concept `x86-order`
- [x] Learn x86-64 Virtual Memory
- [x] Learn x86-64 Paging
- [x] Learn x86-64 Protection Rings
- [x] Learn x86-64 Control Registers
- [x] Learn x86-64 Debug Registers
- [x] Learn x86-64 Performance Monitoring

## ARM64

- [x] Learn AArch64 Assembly
- [x] Learn AArch64 Instruction Encoding
- [x] Learn AArch64 Calling Conventions
- [x] Learn AArch64 ABI
- [x] Learn AArch64 Stack Frames
- [x] Learn AArch64 System Calls  — `a64sys`, concept `a64-syscall`
- [x] Learn AArch64 Exceptions  — `a64sys`, concept `a64-exceptions`
- [x] Learn AArch64 Interrupts  — `a64sys`, concept `a64-interrupts`
- [x] Learn AArch64 SIMD and NEON  — `a64simd`, concept `a64-neon`. Five
      views of one vector register, and the Q bit of a single load/store is
      BIT 23 rather than bit 30 -- so a field's position is a property of an
      instruction group and not of an architecture. `fadd q0` does not exist;
      128-bit arithmetic is a different encoding six bits away.
- [x] Learn AArch64 Atomics  — `a64simd`, concept `a64-atomic`. The retry is
      a loop because the store-exclusive reports failure in a register and an
      instruction cannot act on its own output. Acquire is BIT 15 in the
      exclusive family; FEAT_LSE does NOT use one set of ordering bits for its
      group (CAS: 22 and 15; LDADD: 23 and 22; bit 21 is a constant of both),
      which the cross-check found and the course retracted as R21.
- [x] Learn AArch64 Memory Ordering  — `a64simd`, concept `a64-order`. Twelve
      functions performing C11 atomics emit THREE barriers, all three in
      functions whose source asks for a fence, and a C11 seq_cst load and a
      C11 acquire load are the SAME `ldar`. DMB/DSB/ISB differ in TWO fields,
      and the four-bit option field is the one everybody forgets. No timings.
- [x] Learn AArch64 Virtual Memory  — `a64sys`, concept `a64-virtual`
- [x] Learn AArch64 Page Tables  — `a64sys`, concept `a64-pagetables`. The
      hinge into the ELF courses: `sh_addralign` carries the 2 MiB
      requirement and the ADRP+LO12 pair is read from an object file, both by
      two parsers that agree. No timings anywhere in this course.

## RISC-V

- [x] Learn RISC-V ISA
- [x] Learn RISC-V Assembly
- [x] Learn RISC-V Instruction Encoding
- [x] Learn RISC-V Calling Conventions
- [x] Learn RISC-V Privilege Specification
       "The RISC-V Privileged Architecture", 4 concepts in 2 modules,
       101 minutes, and the THIRD of the four splits
       `docs/riscv-section-plan.md` makes of the RISC-V roadmap. It is the
       FIRST course in the collection whose SUBJECT cannot be observed at
       all: no RISC-V machine, no emulator, no RISC-V linker, so no exception
       is taken, no page is walked, no TLB is consulted, and no `ecall` is
       observed trapping. `ecall` is measured AS EMITTED and labelled so on
       every page that mentions it. What survives is the part a compiler
       author needs: the twelve CSR instruction encodings and the single
       funct3 bit between the register and immediate forms (1^5 = 2^6 = 3^7 =
       4), the 12-bit CSR address decomposed into accessibility and privilege
       with encoding 2 printed as a hole, the Zicsr split, the satp PPN width
       of 36 bits with two natural wrong widths BOTH COMPILING and measured on
       the compiler's own shifts, the PTE bit table as seven descending shift
       amounts, the relocation records a walk emits with the HI20/LO12
       asymmetry, and the pairing rule's arithmetic over six distances the
       assembler refuses to diagnose. 44 provenance rows with the count
       printed (8 MEASURED, 13 MEASURED-ON-BYTES, 23 QUOTED), 16 limits, 17
       retractions, 4 poisons.
- [x] Learn RISC-V Virtual Memory
       Same course, `rv-paging`: Sv39/Sv48/Sv57, `satp`, the PTE layout and
       the A/D bits, plus the object-file half that a walk produces.
- [x] Learn RISC-V Interrupts
       Same course, `rv-traps`: the five trap CSR addresses and their
       decomposition, `stvec`'s mode and base alignment, the cause-number-
       equals-bit rule measured on the compiler's `ori` immediates, and the
       read-modify-write race named and labelled a quoted consequence.
- [x] Learn RISC-V Atomics
       `rv-amo` and `rv-fence`, same course, `rvat` "RISC-V Atomics and the
       Vector Extension", 4 concepts in 2 modules, 101 minutes, and the FOURTH
       and last of the four `docs/riscv-section-plan.md` splits, so all nine
       RISC-V roadmap items are now ticked. No timings here either, but the
       comparison with the two architectures that CAN be timed is the
       concept, so the honest form of it is a COUNT and not a ratio: zero
       instructions in the corpus take a lock prefix, against nine operations
       plus a reservation pair that are atomic with no prefix at all. The
       x86-64 side is measured rather than quoted and the SDM's eighteen
       locked instructions are quoted **and disclaimed** against the 22
       spellings this host's assembler actually accepts, the trap being
       `lock bt` -- a form no vendor documents and every assembler takes.
       `amo`: one opcode 0101111, 11 funct5 values, 21 unnamed holes printed
       as holes; `.w`/`.d` is ONE BIT of funct3 (12 pairs, all XOR 0x1000);
       `aq` = inst[26], `rl` = inst[25], adjacent, and the three XORs are
       ADDITIVE, which is what makes them two fields and not one field with
       three values. The CENTRAL EXPERIMENT needs no clock at all: the same
       C11 file at `rv64ima` is 29 instructions, 2 lr, 2 sc, 5 amo*, **0
       calls**, and at `rv64im` it is 111 instructions, 0 lr, 0 sc, 0 amo*
       and **9 calls** to `__atomic_*_4` -- one letter apart. That call
       count was measured wrong first: it counted a `call` MNEMONIC that
       cannot exist in a relocatable object, so it printed zero against 111
       instructions without noticing its own method was vacuous, and it now
       counts `R_RISCV_CALL_PLT` relocations instead. `fence`: the ordering
       model is DEFINED as a relation between two four-bit sets inside one
       instruction, which is neither x86-64's TSO baseline nor AArch64's
       access modes; 35 fences at fm=0000, 2 `fence.tso`, 2 `fence.i`, 15
       named spellings of 16 codes with the 16th a hole, and CONSUME and
       ACQUIRE the same four bits -- plus ACQ_REL becoming `fence.tso`, a
       DIFFERENT INSTRUCTION.
- [x] Learn RISC-V Vector Extension
       Same course, `rv-vector` and `rv-dataflow`: ONE FIXED 32-BIT
       INSTRUCTION DESCRIBES A VECTOR AND THE LENGTH IS NOT IN THIS
       INSTRUCTION AT ALL -- `vsetvli` carries SEW, LMUL and the tail/mask
       policies, and the length arrives as an AVL in inst[19:15] and comes
       back out of a CSR the instruction does not contain, which the compiler
       proves by emitting `csrr a7, vlenb` (0xC22, read-only from U-mode).
       120 `vsetvli`, 112 distinct zimm, `zimm[10:8]` = 0b000 in all 120.
       The mask is ONE BIT at inst[25] across three instruction groups --
       11 pairs, every XOR exactly 0x02000000 -- and the mask REGISTER is
       not in the encoding, which the assembler says in its own diagnostic.
       Levels: -O1 vectorises nothing, -O2 and -O3 are BYTE-IDENTICAL, -Os
       emits MORE vector instructions than -O2 (21 against 19) while being
       SMALLER in code size (81 instructions against 191), because the vector
       body replaces a loop. Two readers on the same bytes: 2,197
       instructions, 2,147 named, **50 unmodelled** printed BESIDE the
       disagreement count, 0 disagreements, and 6 fire-table rules of which
       5 fire and **1 is dead by design** and labelled NEVER FIRED. Four
       poisons, each moving one column and claiming the other stays put.
       58 provenance rows with the count printed (20 MEASURED, 18
       MEASURED-ON-BYTES, 20 QUOTED), 19 limits, 18 retractions, and the
       two scope lists at 9 cannot-conclude against 11 can-conclude -- the
       second being the longer one IS the finding.

---

# Part 2 — the 14 planned courses (678 items)

Every course below is **planned**, not built: no directory, `manifest.json`,
verifier or harness exists for any of them. The slug is the course id a build
is expected to use, and the concept id on each line is the concept that build
is expected to create. Both are proposals; the roadmap items themselves are
not.

## Planned course 1 of 14 — Operating Systems, Processes and Virtualization

Slug `os`. **64 items.**

Absorbs **Operating Systems** (27 items), **Runtime & Process Internals** (14 items), **Virtualization** (20 items), **Boot & Startup** (3 of 13 items).

- [ ] Learn Operating Systems From First Principles  — `os`, from Operating Systems, concept `operating-systems-from-first-principles`
- [ ] Learn Processes  — `os`, from Operating Systems, concept `processes`
- [ ] Learn Threads  — `os`, from Operating Systems, concept `threads`
- [ ] Learn Scheduling  — `os`, from Operating Systems, concept `scheduling`
- [ ] Learn Context Switching  — `os`, from Operating Systems, concept `context-switching`
- [ ] Learn System Calls  — `os`, from Operating Systems, concept `system-calls`
- [ ] Learn User Mode and Kernel Mode  — `os`, from Operating Systems, concept `user-mode-and-kernel-mode`
- [ ] Learn Interrupts  — `os`, from Operating Systems, concept `interrupts`
- [ ] Learn Exceptions  — `os`, from Operating Systems, concept `exceptions`
- [ ] Learn Kernel Entry and Exit  — `os`, from Operating Systems, concept `kernel-entry-and-exit`
- [ ] Learn Inter-Process Communication  — `os`, from Operating Systems, concept `ipc`
- [ ] Learn Pipes  — `os`, from Operating Systems, concept `pipes`
- [ ] Learn Shared Memory  — `os`, from Operating Systems, concept `shared-memory`
- [ ] Learn Signals  — `os`, from Operating Systems, concept `signals`
- [ ] Learn Synchronization  — `os`, from Operating Systems, concept `synchronization`
- [ ] Learn Mutexes  — `os`, from Operating Systems, concept `mutexes`
- [ ] Learn Semaphores  — `os`, from Operating Systems, concept `semaphores`
- [ ] Learn Condition Variables  — `os`, from Operating Systems, concept `condition-variables`
- [ ] Learn Futexes  — `os`, from Operating Systems, concept `futexes`
- [ ] Learn Deadlocks  — `os`, from Operating Systems, concept `deadlocks`
- [ ] Learn Kernel Memory Management  — `os`, from Operating Systems, concept `kernel-memory-management`
- [ ] Learn Kernel Virtual Memory  — `os`, from Operating Systems, concept `kernel-virtual-memory`
- [ ] Learn Kernel Modules  — `os`, from Operating Systems, concept `kernel-modules`
- [ ] Learn Device Drivers  — `os`, from Operating Systems, concept `device-drivers`
- [ ] Learn Linux Kernel Architecture  — `os`, from Operating Systems, concept `linux-kernel-architecture`
- [ ] Learn Windows NT Architecture  — `os`, from Operating Systems, concept `windows-nt-architecture`
- [ ] Learn macOS and XNU Architecture  — `os`, from Operating Systems, concept `macos-and-xnu-architecture`
- [ ] Learn Process Creation  — `os`, from Runtime & Process Internals, concept `process-creation`
- [ ] Learn fork()  — `os`, from Runtime & Process Internals, concept `fork`
- [ ] Learn exec()  — `os`, from Runtime & Process Internals, concept `exec`
- [ ] Learn Windows Process Creation  — `os`, from Runtime & Process Internals, concept `windows-process-creation`
- [ ] Learn Unix File Descriptors  — `os`, from Runtime & Process Internals, concept `unix-file-descriptors`
- [ ] Learn Windows Handles  — `os`, from Runtime & Process Internals, concept `windows-handles`
- [ ] Learn Unix Signals  — `os`, from Runtime & Process Internals, concept `unix-signals`
- [ ] Learn Windows Structured Exception Handling  — `os`, from Runtime & Process Internals, concept `windows-structured-exception-handling`
- [ ] Learn Unix Dynamic Loading  — `os`, from Runtime & Process Internals, concept `unix-dynamic-loading`
- [ ] Learn Windows DLL Loading  — `os`, from Runtime & Process Internals, concept `windows-dll-loading`
- [ ] Learn macOS Dynamic Loading  — `os`, from Runtime & Process Internals, concept `macos-dynamic-loading`
- [ ] Learn Environment Variables Internals  — `os`, from Runtime & Process Internals, concept `environment-variables-internals`
- [ ] Learn Process Environment Blocks  — `os`, from Runtime & Process Internals, concept `process-environment-blocks`
- [ ] Learn Thread-Local Storage Internals  — `os`, from Runtime & Process Internals, concept `thread-local-storage-internals`
- [ ] Learn Virtual Machines From First Principles  — `os`, from Virtualization, concept `virtual-machines-from-first-principles`
- [ ] Learn Hardware Virtualization  — `os`, from Virtualization, concept `hardware-virtualization`
- [ ] Learn Intel VT-x  — `os`, from Virtualization, concept `intel-vt-x`
- [ ] Learn AMD-V  — `os`, from Virtualization, concept `amd-v`
- [ ] Learn ARM Virtualization  — `os`, from Virtualization, concept `arm-virtualization`
- [ ] Learn Hypervisors  — `os`, from Virtualization, concept `hypervisors`
- [ ] Learn Type-1 Hypervisors  — `os`, from Virtualization, concept `type-1-hypervisors`
- [ ] Learn Type-2 Hypervisors  — `os`, from Virtualization, concept `type-2-hypervisors`
- [ ] Learn Virtual CPUs  — `os`, from Virtualization, concept `virtual-cpus`
- [ ] Learn Virtual Memory in Hypervisors  — `os`, from Virtualization, concept `virtual-memory-in-hypervisors`. X86-64 and AArch64 page tables are already taught by `x86sys` and `a64sys`; this line is the second-level map a VMM maintains
- [ ] Learn Virtual I/O  — `os`, from Virtualization, concept `virtual-io`
- [ ] Learn Device Emulation  — `os`, from Virtualization, concept `device-emulation`
- [ ] Learn VirtIO  — `os`, from Virtualization, concept `virtio`
- [ ] Learn QEMU Internals  — `os`, from Virtualization, concept `qemu-internals`
- [ ] Learn KVM  — `os`, from Virtualization, concept `kvm`
- [ ] Learn Containers From First Principles  — `os`, from Virtualization, concept `containers-from-first-principles`
- [ ] Learn Linux Containers  — `os`, from Virtualization, concept `linux-containers`
- [ ] Learn Namespaces  — `os`, from Virtualization, concept `namespaces`. Linux namespaces as a security boundary are in `crypto`; this line is their use in a container
- [ ] Learn cgroups  — `os`, from Virtualization, concept `cgroups`
- [ ] Learn Overlay Filesystems  — `os`, from Virtualization, concept `overlay-filesystems`. Union-mount semantics are taught here; on-disk structures are in `storage`
- [ ] Learn Kernel Initialization  — `os`, from Boot & Startup, concept `kernel-initialization`
- [ ] Learn Process 1  — `os`, from Boot & Startup, concept `process-1`
- [ ] Learn System Initialization  — `os`, from Boot & Startup, concept `system-initialization`

## Planned course 2 of 14 — Hardware, Firmware and the Boot Path

Slug `hwboot`. **39 items.**

Absorbs **Firmware & Embedded Systems** (17 of 18 items), **Boot & Startup** (10 of 13 items), **Hardware Interfaces** (12 items).

- [ ] Learn Embedded Systems From First Principles  — `hwboot`, from Firmware & Embedded Systems, concept `embedded-systems-from-first-principles`
- [ ] Learn Microcontrollers  — `hwboot`, from Firmware & Embedded Systems, concept `microcontrollers`
- [ ] Learn Interrupt Controllers  — `hwboot`, from Firmware & Embedded Systems, concept `interrupt-controllers`
- [ ] Learn Timers  — `hwboot`, from Firmware & Embedded Systems, concept `timers`
- [ ] Learn UART  — `hwboot`, from Firmware & Embedded Systems, concept `uart`
- [ ] Learn SPI  — `hwboot`, from Firmware & Embedded Systems, concept `spi`
- [ ] Learn I2C  — `hwboot`, from Firmware & Embedded Systems, concept `i2c`
- [ ] Learn GPIO  — `hwboot`, from Firmware & Embedded Systems, concept `gpio`
- [ ] Learn DMA  — `hwboot`, from Firmware & Embedded Systems, concept `dma`
- [ ] Learn ADC and DAC  — `hwboot`, from Firmware & Embedded Systems, concept `adc-and-dac`
- [ ] Learn Bootloaders  — `hwboot`, from Firmware & Embedded Systems, concept `bootloaders`
- [ ] Learn Embedded Linker Scripts  — `hwboot`, from Firmware & Embedded Systems, concept `embedded-linker-scripts`
- [ ] Learn Firmware Images  — `hwboot`, from Firmware & Embedded Systems, concept `firmware-images`
- [ ] Learn ARM Cortex-M  — `hwboot`, from Firmware & Embedded Systems, concept `arm-cortex-m`
- [ ] Learn RTOS Architecture  — `hwboot`, from Firmware & Embedded Systems, concept `rtos-architecture`
- [ ] Learn Real-Time Scheduling  — `hwboot`, from Firmware & Embedded Systems, concept `real-time-scheduling`
- [ ] Learn Embedded Debugging  — `hwboot`, from Firmware & Embedded Systems, concept `embedded-debugging`
- [ ] Learn Computer Boot From Power-On  — `hwboot`, from Boot & Startup, concept `computer-boot-from-power-on`
- [ ] Learn BIOS  — `hwboot`, from Boot & Startup, concept `bios`
- [ ] Learn UEFI  — `hwboot`, from Boot & Startup, concept `uefi`
- [ ] Learn UEFI Boot Process  — `hwboot`, from Boot & Startup, concept `uefi-boot-process`
- [ ] Learn Bootloaders  — `hwboot`, from Boot & Startup, concept `bootloaders`. Same concept; the other line of the pair is from Firmware & Embedded Systems
- [ ] Learn Multiboot  — `hwboot`, from Boot & Startup, concept `multiboot`
- [ ] Learn Linux Boot Process  — `hwboot`, from Boot & Startup, concept `linux-boot-process`
- [ ] Learn Windows Boot Process  — `hwboot`, from Boot & Startup, concept `windows-boot-process`
- [ ] Learn macOS Boot Process  — `hwboot`, from Boot & Startup, concept `macos-boot-process`
- [ ] Learn Secure Boot  — `hwboot`, from Boot & Startup, concept `secure-boot`
- [ ] Learn PCI Express  — `hwboot`, from Hardware Interfaces, concept `pcie`
- [ ] Learn USB  — `hwboot`, from Hardware Interfaces, concept `usb`
- [ ] Learn USB Device Enumeration  — `hwboot`, from Hardware Interfaces, concept `usb-device-enumeration`
- [ ] Learn USB Descriptors  — `hwboot`, from Hardware Interfaces, concept `usb-descriptors`
- [ ] Learn NVMe  — `hwboot`, from Hardware Interfaces, concept `nvme`
- [ ] Learn SATA  — `hwboot`, from Hardware Interfaces, concept `sata`
- [ ] Learn AHCI  — `hwboot`, from Hardware Interfaces, concept `ahci`
- [ ] Learn Bluetooth  — `hwboot`, from Hardware Interfaces, concept `bluetooth`
- [ ] Learn Wi-Fi From First Principles  — `hwboot`, from Hardware Interfaces, concept `wi-fi-from-first-principles`
- [ ] Learn IOMMU  — `hwboot`, from Hardware Interfaces, concept `iommu`
- [ ] Learn DMA  — `hwboot`, from Hardware Interfaces, concept `dma`. Same concept; the other line of the pair is from Firmware & Embedded Systems
- [ ] Learn Interrupts and MSI-X  — `hwboot`, from Hardware Interfaces, concept `msix-interrupts`

## Planned course 3 of 14 — Memory Systems, Concurrency and Machine Arithmetic

Slug `memconc`. **60 items.**

Absorbs **Memory** (27 items), **Concurrency** (20 items), **Mathematics for Systems** (11 of 13 items), **Firmware & Embedded Systems** (1 of 18 items), **System Design at the Lowest Level** (1 of 16 items).

- [ ] Learn Virtual Memory  — `memconc`, from Memory, concept `virtual-memory`. X86-64 and AArch64 paging are already taught by `x86sys` and `a64sys`
- [ ] Learn Physical Memory  — `memconc`, from Memory, concept `physical-memory`
- [ ] Learn Page Tables  — `memconc`, from Memory, concept `page-tables`. X86-64 and AArch64 page tables are already taught by `x86sys` and `a64sys`
- [ ] Learn Multi-Level Page Tables  — `memconc`, from Memory, concept `multi-level-page-tables`
- [ ] Learn Memory Mapping  — `memconc`, from Memory, concept `memory-mapping`
- [ ] Learn Memory Protection  — `memconc`, from Memory, concept `memory-protection`. X86-64 and AArch64 protection are already taught by `x86sys` and `a64sys`
- [ ] Learn Memory-Mapped Files  — `memconc`, from Memory, concept `memory-mapped-files`
- [ ] Learn Copy-on-Write  — `memconc`, from Memory, concept `copy-on-write`
- [ ] Learn Demand Paging  — `memconc`, from Memory, concept `demand-paging`
- [ ] Learn Page Faults  — `memconc`, from Memory, concept `page-faults`
- [ ] Learn Huge Pages  — `memconc`, from Memory, concept `huge-pages`
- [ ] Learn Memory Allocators  — `memconc`, from Memory, concept `memory-allocators`
- [ ] Learn malloc  — `memconc`, from Memory, concept `malloc`
- [ ] Learn jemalloc  — `memconc`, from Memory, concept `jemalloc`
- [ ] Learn mimalloc  — `memconc`, from Memory, concept `mimalloc`
- [ ] Learn Garbage Collection  — `memconc`, from Memory, concept `garbage-collection`
- [ ] Learn Mark-and-Sweep Garbage Collection  — `memconc`, from Memory, concept `mark-and-sweep-garbage-collection`
- [ ] Learn Generational Garbage Collection  — `memconc`, from Memory, concept `generational-garbage-collection`
- [ ] Learn Concurrent Garbage Collection  — `memconc`, from Memory, concept `concurrent-garbage-collection`
- [ ] Learn Reference Counting  — `memconc`, from Memory, concept `reference-counting`
- [ ] Learn Region-Based Memory Management  — `memconc`, from Memory, concept `region-based-memory-management`
- [ ] Learn Stack Allocation  — `memconc`, from Memory, concept `stack-allocation`
- [ ] Learn Heap Allocation  — `memconc`, from Memory, concept `heap-allocation`
- [ ] Learn Memory Fragmentation  — `memconc`, from Memory, concept `memory-fragmentation`
- [ ] Learn Memory Arenas  — `memconc`, from Memory, concept `memory-arenas`
- [ ] Learn Slab Allocators  — `memconc`, from Memory, concept `slab-allocators`
- [ ] Learn Lock-Free Memory Reclamation  — `memconc`, from Memory, concept `lock-free-memory-reclamation`
- [ ] Learn Concurrency From First Principles  — `memconc`, from Concurrency, concept `concurrency-from-first-principles`
- [ ] Learn Threads and Processes  — `memconc`, from Concurrency, concept `threads-and-processes`
- [ ] Learn Race Conditions  — `memconc`, from Concurrency, concept `race-conditions`
- [ ] Learn Mutual Exclusion  — `memconc`, from Concurrency, concept `mutual-exclusion`
- [ ] Learn Lock-Free Programming  — `memconc`, from Concurrency, concept `lock-free-programming`
- [ ] Learn Atomic Operations  — `memconc`, from Concurrency, concept `atomic-operations`. The machine-level primitives are already taught by `x86simd`, `a64simd` and `rvat`
- [ ] Learn Compare-and-Swap  — `memconc`, from Concurrency, concept `compare-and-swap`
- [ ] Learn Memory Models  — `memconc`, from Concurrency, concept `memory-models`. The machine-level ordering is already taught by `x86simd`, `a64simd` and `rvat`
- [ ] Learn Sequential Consistency  — `memconc`, from Concurrency, concept `sequential-consistency`
- [ ] Learn Acquire and Release Semantics  — `memconc`, from Concurrency, concept `acquire-and-release-semantics`
- [ ] Learn Data Races  — `memconc`, from Concurrency, concept `data-races`
- [ ] Learn Deadlocks  — `memconc`, from Concurrency, concept `deadlocks`. Taught in `os`; this line is its use in user-space code
- [ ] Learn Lock-Free Data Structures  — `memconc`, from Concurrency, concept `lock-free-data-structures`
- [ ] Learn Wait-Free Algorithms  — `memconc`, from Concurrency, concept `wait-free-algorithms`
- [ ] Learn Work Stealing  — `memconc`, from Concurrency, concept `work-stealing`
- [ ] Learn Thread Pools  — `memconc`, from Concurrency, concept `thread-pools`
- [ ] Learn Event Loops  — `memconc`, from Concurrency, concept `event-loops`
- [ ] Learn Async I/O  — `memconc`, from Concurrency, concept `async-io`
- [ ] Learn Coroutines  — `memconc`, from Concurrency, concept `coroutines`. Taught in `vm`; this line is its use in user-space code
- [ ] Learn Fibers  — `memconc`, from Concurrency, concept `fibers`
- [ ] Learn Binary Arithmetic  — `memconc`, from Mathematics for Systems, concept `binary-arithmetic`
- [ ] Learn Two's Complement  — `memconc`, from Mathematics for Systems, concept `twos-complement`
- [ ] Learn Fixed-Point Arithmetic  — `memconc`, from Mathematics for Systems, concept `fixed-point-arithmetic`
- [ ] Learn Floating-Point Arithmetic  — `memconc`, from Mathematics for Systems, concept `floating-point-arithmetic`
- [ ] Learn IEEE 754  — `memconc`, from Mathematics for Systems, concept `ieee-754`
- [ ] Learn Floating-Point Errors  — `memconc`, from Mathematics for Systems, concept `floating-point-errors`
- [ ] Learn Numerical Stability  — `memconc`, from Mathematics for Systems, concept `numerical-stability`
- [ ] Learn Bit Manipulation  — `memconc`, from Mathematics for Systems, concept `bit-manipulation`
- [ ] Learn Boolean Algebra  — `memconc`, from Mathematics for Systems, concept `boolean-algebra`
- [ ] Learn Modular Arithmetic  — `memconc`, from Mathematics for Systems, concept `modular-arithmetic`
- [ ] Learn Probability for Computer Systems  — `memconc`, from Mathematics for Systems, concept `probability-for-computer-systems`
- [ ] Learn Memory-Mapped I/O  — `memconc`, from Firmware & Embedded Systems, concept `mmio`
- [ ] Learn Memory-Mapped I/O  — `memconc`, from System Design at the Lowest Level, concept `mmio`. Same concept; the other line of the pair is from Firmware & Embedded Systems

## Planned course 4 of 14 — Filesystems, Version Control and Replication

Slug `storage`. **44 items.**

Absorbs **Filesystems** (21 items), **Source Control Internals** (10 items), **Distributed & Networked Storage** (12 items), **Binary Formats & File Formats — Git object database** (1 of 41 items).

- [ ] Learn Filesystems From First Principles  — `storage`, from Filesystems, concept `filesystems-from-first-principles`
- [ ] Learn Inodes  — `storage`, from Filesystems, concept `inodes`
- [ ] Learn File Descriptors  — `storage`, from Filesystems, concept `file-descriptors`
- [ ] Learn Directory Structures  — `storage`, from Filesystems, concept `directory-structures`
- [ ] Learn File Permissions  — `storage`, from Filesystems, concept `file-permissions`
- [ ] Learn File Metadata  — `storage`, from Filesystems, concept `file-metadata`
- [ ] Learn Journaling Filesystems  — `storage`, from Filesystems, concept `journaling-filesystems`
- [ ] Learn Copy-on-Write Filesystems  — `storage`, from Filesystems, concept `copy-on-write-filesystems`
- [ ] Learn Virtual Filesystems  — `storage`, from Filesystems, concept `virtual-filesystems`
- [ ] Learn Linux VFS  — `storage`, from Filesystems, concept `linux-vfs`
- [ ] Learn ext4  — `storage`, from Filesystems, concept `ext4`
- [ ] Learn XFS  — `storage`, from Filesystems, concept `xfs`
- [ ] Learn Btrfs  — `storage`, from Filesystems, concept `btrfs`
- [ ] Learn ZFS  — `storage`, from Filesystems, concept `zfs`
- [ ] Learn NTFS  — `storage`, from Filesystems, concept `ntfs`
- [ ] Learn APFS  — `storage`, from Filesystems, concept `apfs`
- [ ] Learn FAT32  — `storage`, from Filesystems, concept `fat32`
- [ ] Learn exFAT  — `storage`, from Filesystems, concept `exfat`
- [ ] Learn FUSE  — `storage`, from Filesystems, concept `fuse`
- [ ] Learn Filesystem Caching  — `storage`, from Filesystems, concept `filesystem-caching`
- [ ] Learn Filesystem Crash Consistency  — `storage`, from Filesystems, concept `filesystem-crash-consistency`
- [ ] Learn Git Internals  — `storage`, from Source Control Internals, concept `git-internals`
- [ ] Learn Git Objects  — `storage`, from Source Control Internals, concept `git-objects`
- [ ] Learn Git Packfiles  — `storage`, from Source Control Internals, concept `git-packfiles`
- [ ] Learn Git Index  — `storage`, from Source Control Internals, concept `git-index`
- [ ] Learn Git References  — `storage`, from Source Control Internals, concept `git-references`
- [ ] Learn Git Reflogs  — `storage`, from Source Control Internals, concept `git-reflogs`
- [ ] Learn Git Merge  — `storage`, from Source Control Internals, concept `git-merge`
- [ ] Learn Git Rebase  — `storage`, from Source Control Internals, concept `git-rebase`
- [ ] Learn Git Garbage Collection  — `storage`, from Source Control Internals, concept `git-garbage-collection`
- [ ] Learn Git Transfer Protocol  — `storage`, from Source Control Internals, concept `git-transfer-protocol`
- [ ] Learn Object Storage  — `storage`, from Distributed & Networked Storage, concept `object-storage`
- [ ] Learn Distributed Filesystems  — `storage`, from Distributed & Networked Storage, concept `distributed-filesystems`
- [ ] Learn RAID  — `storage`, from Distributed & Networked Storage, concept `raid`
- [ ] Learn RAID 0  — `storage`, from Distributed & Networked Storage, concept `raid-0`
- [ ] Learn RAID 1  — `storage`, from Distributed & Networked Storage, concept `raid-1`
- [ ] Learn RAID 5  — `storage`, from Distributed & Networked Storage, concept `raid-5`
- [ ] Learn RAID 6  — `storage`, from Distributed & Networked Storage, concept `raid-6`
- [ ] Learn RAID 10  — `storage`, from Distributed & Networked Storage, concept `raid-10`
- [ ] Learn Erasure Coding  — `storage`, from Distributed & Networked Storage, concept `erasure-coding`
- [ ] Learn Replicated Storage  — `storage`, from Distributed & Networked Storage, concept `replicated-storage`
- [ ] Learn Consistent Hashing  — `storage`, from Distributed & Networked Storage, concept `consistent-hashing`. Taught in `distsys`; this line is its use in object storage
- [ ] Learn Content-Addressable Storage  — `storage`, from Distributed & Networked Storage, concept `content-addressable-storage`
- [ ] Learn Git Object Database  — `storage`, from Binary Formats & File Formats, concept `git-object-database`

## Planned course 5 of 14 — Networking and Network Protocols

Slug `network`. **52 items.**

Absorbs **Networking** (28 items), **Network Protocols** (23 items), **Binary Formats & File Formats — PCAP packet captures** (1 of 41 items).

- [ ] Learn Networking From First Principles  — `network`, from Networking, concept `networking-from-first-principles`
- [ ] Learn Ethernet  — `network`, from Networking, concept `ethernet`
- [ ] Learn ARP  — `network`, from Networking, concept `arp`
- [ ] Learn IPv4  — `network`, from Networking, concept `ipv4`
- [ ] Learn IPv6  — `network`, from Networking, concept `ipv6`
- [ ] Learn ICMP  — `network`, from Networking, concept `icmp`
- [ ] Learn UDP  — `network`, from Networking, concept `udp`
- [ ] Learn TCP  — `network`, from Networking, concept `tcp`
- [ ] Learn TCP Connection Establishment  — `network`, from Networking, concept `tcp-connection-establishment`
- [ ] Learn TCP Congestion Control  — `network`, from Networking, concept `tcp-congestion-control`
- [ ] Learn TCP Flow Control  — `network`, from Networking, concept `tcp-flow-control`
- [ ] Learn TCP Retransmission  — `network`, from Networking, concept `tcp-retransmission`
- [ ] Learn TCP Sockets  — `network`, from Networking, concept `tcp-sockets`
- [ ] Learn Network Byte Order  — `network`, from Networking, concept `network-byte-order`
- [ ] Learn DNS  — `network`, from Networking, concept `dns`
- [ ] Learn DHCP  — `network`, from Networking, concept `dhcp`
- [ ] Learn NAT  — `network`, from Networking, concept `nat`
- [ ] Learn Routing  — `network`, from Networking, concept `routing`
- [ ] Learn IP Fragmentation  — `network`, from Networking, concept `ip-fragmentation`
- [ ] Learn MTU and Path MTU Discovery  — `network`, from Networking, concept `mtu-and-path-mtu-discovery`
- [ ] Learn Ethernet Frames  — `network`, from Networking, concept `ethernet-frames`
- [ ] Learn IP Packets  — `network`, from Networking, concept `ip-packets`
- [ ] Learn TCP Segments  — `network`, from Networking, concept `tcp-segments`
- [ ] Learn UDP Datagrams  — `network`, from Networking, concept `udp-datagrams`
- [ ] Learn Network Packet Capture  — `network`, from Networking, concept `network-packet-capture`
- [ ] Learn BPF  — `network`, from Networking, concept `bpf`
- [ ] Learn eBPF  — `network`, from Networking, concept `ebpf`. Tracing with it is `eBPF Tracing` in `debugio`
- [ ] Learn Network Namespaces  — `network`, from Networking, concept `network-namespaces`
- [ ] Learn HTTP/1.1  — `network`, from Network Protocols, concept `http-1-1`
- [ ] Learn HTTP/2  — `network`, from Network Protocols, concept `http-2`
- [ ] Learn HTTP/3  — `network`, from Network Protocols, concept `http-3`
- [ ] Learn QUIC  — `network`, from Network Protocols, concept `quic`
- [ ] Learn WebSocket  — `network`, from Network Protocols, concept `websocket`
- [ ] Learn TLS 1.2  — `network`, from Network Protocols, concept `tls-1-2`
- [ ] Learn TLS 1.3  — `network`, from Network Protocols, concept `tls-1-3`
- [ ] Learn TLS From Cryptographic Primitives  — `network`, from Network Protocols, concept `tls-from-cryptographic-primitives`
- [ ] Learn How to Implement TLS  — `network`, from Network Protocols, concept `how-to-implement-tls`
- [ ] Learn SSH Protocol  — `network`, from Network Protocols, concept `ssh-protocol`
- [ ] Learn SMTP  — `network`, from Network Protocols, concept `smtp`
- [ ] Learn IMAP  — `network`, from Network Protocols, concept `imap`
- [ ] Learn POP3  — `network`, from Network Protocols, concept `pop3`
- [ ] Learn FTP  — `network`, from Network Protocols, concept `ftp`
- [ ] Learn SFTP  — `network`, from Network Protocols, concept `sftp`
- [ ] Learn NTP  — `network`, from Network Protocols, concept `ntp`. The NTP wire protocol is taught here; clock synchronisation is taught in `distsys`
- [ ] Learn SNMP  — `network`, from Network Protocols, concept `snmp`
- [ ] Learn LDAP  — `network`, from Network Protocols, concept `ldap`
- [ ] Learn MQTT  — `network`, from Network Protocols, concept `mqtt`
- [ ] Learn AMQP  — `network`, from Network Protocols, concept `amqp`
- [ ] Learn gRPC  — `network`, from Network Protocols, concept `grpc`
- [ ] Learn DNS over HTTPS  — `network`, from Network Protocols, concept `dns-over-https`
- [ ] Learn DNS over TLS  — `network`, from Network Protocols, concept `dns-over-tls`
- [ ] Learn PCAP Packet Capture Format  — `network`, from Binary Formats & File Formats, concept `pcap-packet-capture-format`

## Planned course 6 of 14 — Cryptography and Security Internals

Slug `crypto`. **53 items.**

Absorbs **Cryptography** (31 items), **Security Internals** (21 items), **Binary Formats & File Formats — X.509 certificates** (1 of 41 items).

- [ ] Learn Cryptography From First Principles  — `crypto`, from Cryptography, concept `cryptography-from-first-principles`
- [ ] Learn Cryptographic Randomness  — `crypto`, from Cryptography, concept `cryptographic-randomness`
- [ ] Learn Entropy  — `crypto`, from Cryptography, concept `entropy`. Shannon entropy for compression is taught in `encodings`
- [ ] Learn Hash Functions  — `crypto`, from Cryptography, concept `hash-functions`
- [ ] Learn HMAC  — `crypto`, from Cryptography, concept `hmac`
- [ ] Learn HKDF  — `crypto`, from Cryptography, concept `hkdf`
- [ ] Learn SHA-2  — `crypto`, from Cryptography, concept `sha-2`
- [ ] Learn SHA-3  — `crypto`, from Cryptography, concept `sha-3`
- [ ] Learn BLAKE2  — `crypto`, from Cryptography, concept `blake2`
- [ ] Learn BLAKE3  — `crypto`, from Cryptography, concept `blake3`
- [ ] Learn AES  — `crypto`, from Cryptography, concept `aes`
- [ ] Learn ChaCha20  — `crypto`, from Cryptography, concept `chacha20`
- [ ] Learn Poly1305  — `crypto`, from Cryptography, concept `poly1305`
- [ ] Learn Authenticated Encryption  — `crypto`, from Cryptography, concept `authenticated-encryption`
- [ ] Learn AES-GCM  — `crypto`, from Cryptography, concept `aes-gcm`
- [ ] Learn ChaCha20-Poly1305  — `crypto`, from Cryptography, concept `chacha20-poly1305`
- [ ] Learn Public-Key Cryptography  — `crypto`, from Cryptography, concept `public-key-cryptography`
- [ ] Learn RSA  — `crypto`, from Cryptography, concept `rsa`
- [ ] Learn Diffie-Hellman  — `crypto`, from Cryptography, concept `diffie-hellman`
- [ ] Learn Elliptic-Curve Cryptography  — `crypto`, from Cryptography, concept `elliptic-curve-cryptography`
- [ ] Learn X25519  — `crypto`, from Cryptography, concept `x25519`
- [ ] Learn Ed25519  — `crypto`, from Cryptography, concept `ed25519`
- [ ] Learn Digital Signatures  — `crypto`, from Cryptography, concept `digital-signatures`
- [ ] Learn Certificate Chains  — `crypto`, from Cryptography, concept `certificate-chains`. The DER structure itself is the next line, concept `x509-der`
- [ ] Learn X.509  — `crypto`, from Cryptography, concept `x509-certificates`
- [ ] Learn Certificate Transparency  — `crypto`, from Cryptography, concept `certificate-transparency`
- [ ] Learn Key Derivation  — `crypto`, from Cryptography, concept `key-derivation`
- [ ] Learn Password Hashing  — `crypto`, from Cryptography, concept `password-hashing`
- [ ] Learn Argon2  — `crypto`, from Cryptography, concept `argon2`
- [ ] Learn Secure Random Number Generation  — `crypto`, from Cryptography, concept `secure-random-number-generation`
- [ ] Learn Cryptographic Protocol Design  — `crypto`, from Cryptography, concept `cryptographic-protocol-design`
- [ ] Learn Memory Safety  — `crypto`, from Security Internals, concept `memory-safety`
- [ ] Learn Buffer Overflows  — `crypto`, from Security Internals, concept `buffer-overflows`
- [ ] Learn Stack Smashing  — `crypto`, from Security Internals, concept `stack-smashing`
- [ ] Learn Heap Exploitation  — `crypto`, from Security Internals, concept `heap-exploitation`
- [ ] Learn Use-After-Free  — `crypto`, from Security Internals, concept `use-after-free`
- [ ] Learn Double-Free Bugs  — `crypto`, from Security Internals, concept `double-free-bugs`
- [ ] Learn Integer Overflow  — `crypto`, from Security Internals, concept `integer-overflow`
- [ ] Learn Format String Vulnerabilities  — `crypto`, from Security Internals, concept `format-string-vulnerabilities`
- [ ] Learn Return-Oriented Programming  — `crypto`, from Security Internals, concept `return-oriented-programming`
- [ ] Learn Control-Flow Integrity  — `crypto`, from Security Internals, concept `control-flow-integrity`
- [ ] Learn ASLR  — `crypto`, from Security Internals, concept `aslr`
- [ ] Learn DEP and NX  — `crypto`, from Security Internals, concept `dep-and-nx`
- [ ] Learn Sandboxing  — `crypto`, from Security Internals, concept `sandboxing`
- [ ] Learn Process Isolation  — `crypto`, from Security Internals, concept `process-isolation`
- [ ] Learn Linux Namespaces  — `crypto`, from Security Internals, concept `linux-namespaces`
- [ ] Learn Linux Capabilities  — `crypto`, from Security Internals, concept `linux-capabilities`
- [ ] Learn Secure Boot  — `crypto`, from Security Internals, concept `secure-boot`. Measured boot is taught in `hwboot`; this line is the attack surface
- [ ] Learn Trusted Execution Environments  — `crypto`, from Security Internals, concept `trusted-execution-environments`
- [ ] Learn Memory Protection Keys  — `crypto`, from Security Internals, concept `memory-protection-keys`
- [ ] Learn Spectre  — `crypto`, from Security Internals, concept `spectre`
- [ ] Learn Meltdown  — `crypto`, from Security Internals, concept `meltdown`
- [ ] Learn X.509 Certificate Format  — `crypto`, from Binary Formats & File Formats, concept `x509-der`

## Planned course 7 of 14 — Text, Compression, Archives and Serialization

Slug `encodings`. **59 items.**

Absorbs **Unicode & Text** (10 items), **Compression & Encoding** (16 items), **Binary Formats & File Formats — archives** (5 of 41 items), **Binary Formats & File Formats — text and serialization formats** (12 of 41 items), **Protocol & Serialization Design** (14 items), **Mathematics for Systems** (2 of 13 items).

- [ ] Learn Unicode From First Principles  — `encodings`, from Unicode & Text, concept `unicode-from-first-principles`
- [ ] Learn UTF-8  — `encodings`, from Unicode & Text, concept `utf-8`
- [ ] Learn UTF-16  — `encodings`, from Unicode & Text, concept `utf-16`
- [ ] Learn UTF-32  — `encodings`, from Unicode & Text, concept `utf-32`
- [ ] Learn Unicode Normalization  — `encodings`, from Unicode & Text, concept `unicode-normalization`
- [ ] Learn Unicode Grapheme Clusters  — `encodings`, from Unicode & Text, concept `unicode-grapheme-clusters`
- [ ] Learn Unicode Collation  — `encodings`, from Unicode & Text, concept `unicode-collation`
- [ ] Learn Unicode Bidirectional Algorithm  — `encodings`, from Unicode & Text, concept `unicode-bidi`
- [ ] Learn Character Encoding  — `encodings`, from Unicode & Text, concept `character-encoding`
- [ ] Learn Text Segmentation  — `encodings`, from Unicode & Text, concept `text-segmentation`
- [ ] Learn Compression From First Principles  — `encodings`, from Compression & Encoding, concept `compression-from-first-principles`
- [ ] Learn Run-Length Encoding  — `encodings`, from Compression & Encoding, concept `rle`
- [ ] Learn Huffman Coding  — `encodings`, from Compression & Encoding, concept `huffman-coding`
- [ ] Learn Arithmetic Coding  — `encodings`, from Compression & Encoding, concept `arithmetic-coding`
- [ ] Learn LZ77  — `encodings`, from Compression & Encoding, concept `lz77`
- [ ] Learn LZ78  — `encodings`, from Compression & Encoding, concept `lz78`
- [ ] Learn LZW  — `encodings`, from Compression & Encoding, concept `lzw`
- [ ] Learn DEFLATE  — `encodings`, from Compression & Encoding, concept `deflate`
- [ ] Learn gzip  — `encodings`, from Compression & Encoding, concept `gzip`
- [ ] Learn Brotli  — `encodings`, from Compression & Encoding, concept `brotli`
- [ ] Learn Zstandard  — `encodings`, from Compression & Encoding, concept `zstandard`
- [ ] Learn Snappy  — `encodings`, from Compression & Encoding, concept `snappy`
- [ ] Learn LZ4  — `encodings`, from Compression & Encoding, concept `lz4`
- [ ] Learn Delta Encoding  — `encodings`, from Compression & Encoding, concept `delta-encoding`
- [ ] Learn Entropy Coding  — `encodings`, from Compression & Encoding, concept `entropy-coding`
- [ ] Learn Error-Correcting Codes  — `encodings`, from Compression & Encoding, concept `error-correcting-codes`
- [ ] Learn ZIP File Format  — `encodings`, from Binary Formats & File Formats, concept `zip-file-format`
- [ ] Learn GZIP File Format  — `encodings`, from Binary Formats & File Formats, concept `gzip-file-format`
- [ ] Learn TAR Archive Format  — `encodings`, from Binary Formats & File Formats, concept `tar-archive-format`
- [ ] Learn 7z Archive Format  — `encodings`, from Binary Formats & File Formats, concept `7z-archive-format`
- [ ] Learn RAR Archive Format  — `encodings`, from Binary Formats & File Formats, concept `rar-archive-format`
- [ ] Learn .NET Assembly Metadata and PE Format  — `encodings`, from Binary Formats & File Formats, concept `net-assembly-metadata`
- [ ] Learn DNS Zone File Format  — `encodings`, from Binary Formats & File Formats, concept `dns-zone-file-format`
- [ ] Learn MIME and Internet Media Types  — `encodings`, from Binary Formats & File Formats, concept `mime-and-internet-media-types`
- [ ] Learn ASN.1  — `encodings`, from Binary Formats & File Formats, concept `asn-1`
- [ ] Learn DER Encoding  — `encodings`, from Binary Formats & File Formats, concept `der-encoding`
- [ ] Learn BER Encoding  — `encodings`, from Binary Formats & File Formats, concept `ber-encoding`
- [ ] Learn CBOR  — `encodings`, from Binary Formats & File Formats, concept `cbor`
- [ ] Learn MessagePack  — `encodings`, from Binary Formats & File Formats, concept `messagepack`
- [ ] Learn Protocol Buffers Encoding  — `encodings`, from Binary Formats & File Formats, concept `protocol-buffers-encoding`
- [ ] Learn BSON  — `encodings`, from Binary Formats & File Formats, concept `bson`
- [ ] Learn FlatBuffers Binary Format  — `encodings`, from Binary Formats & File Formats, concept `flatbuffers-binary-format`
- [ ] Learn Cap'n Proto Encoding  — `encodings`, from Binary Formats & File Formats, concept `cap-n-proto-encoding`
- [ ] Learn Binary Protocol Design  — `encodings`, from Protocol & Serialization Design, concept `binary-protocol-design`
- [ ] Learn Text Protocol Design  — `encodings`, from Protocol & Serialization Design, concept `text-protocol-design`
- [ ] Learn Protocol Framing  — `encodings`, from Protocol & Serialization Design, concept `protocol-framing`
- [ ] Learn Length-Prefixed Protocols  — `encodings`, from Protocol & Serialization Design, concept `length-prefixed-protocols`
- [ ] Learn Varints  — `encodings`, from Protocol & Serialization Design, concept `varints`
- [ ] Learn Endianness  — `encodings`, from Protocol & Serialization Design, concept `endianness`
- [ ] Learn Versioning Protocols  — `encodings`, from Protocol & Serialization Design, concept `versioning-protocols`
- [ ] Learn Backward-Compatible Protocols  — `encodings`, from Protocol & Serialization Design, concept `backward-compatible-protocols`
- [ ] Learn Forward-Compatible Protocols  — `encodings`, from Protocol & Serialization Design, concept `forward-compatible-protocols`
- [ ] Learn Protocol Negotiation  — `encodings`, from Protocol & Serialization Design, concept `protocol-negotiation`
- [ ] Learn Capability Negotiation  — `encodings`, from Protocol & Serialization Design, concept `capability-negotiation`
- [ ] Learn State Machine Protocols  — `encodings`, from Protocol & Serialization Design, concept `state-machine-protocols`
- [ ] Learn Protocol Error Handling  — `encodings`, from Protocol & Serialization Design, concept `protocol-error-handling`
- [ ] Learn Protocol Security  — `encodings`, from Protocol & Serialization Design, concept `protocol-security`
- [ ] Learn Information Theory  — `encodings`, from Mathematics for Systems, concept `information-theory`
- [ ] Learn Entropy  — `encodings`, from Mathematics for Systems, concept `entropy`. This is Shannon entropy; cryptographic entropy is taught in `crypto`

## Planned course 8 of 14 — Compilers, Languages and Build Systems

Slug `compiler`. **67 items, 6 ticked.**

Absorbs **Compilers** (31 items), **Compilers & Languages — Advanced** (21 items), **Build Systems & Toolchains** (15 items).

The six ticked items are all ticked by the `compback` course, and the reason
all six landed in one course rather than six is the shape of the chain:
`docs/course-mission.md` puts the backend between the IR and the object file,
and this collection had taught both ends in depth with **nothing in the
middle**. So `compback` fills the hole and takes the six roadmap lines that
belong to it — with two boundaries stated rather than glossed:

* **The IR is straight-line.** No SSA construction, no PHI placement, no CFG,
  no dominators, no loop structure, no peepholes, no compressed encodings, no
  exception frames. That is why `ssa-static-single-assignment`,
  `control-flow-graphs`, `dominators` and `data-flow-analysis` are still open:
  every live range in the course is a straight interval, and the
  loops-through-a-phi case that makes real allocation hard is not present.
* **Compiler Debug Information is ticked by its second half only.** Nothing in
  the course emits DWARF — `dwarf` owns the format — and the item is ticked for
  reading a backend's decisions back out of bytes with no debug information at
  all. This is retraction **R16** in the artifact, published rather than left
  for a reader to discover.

Every concept id was renamed from the todo name to a `cb-` name, because a
concept id is resolved **GLOBALLY** by `render_concept()` in
`web/src/helpers.ch` with no course in the key, so a collision does not 404 — it
silently serves another course's page under this course's URL.
`tools/verify_compback.py` asserts all six todo names **ABSENT** as whole
segments, so the rename cannot be undone by accident and cannot be "tidied"
back by a later editor.

- [x] Learn Compiler Architecture  — `compiler`, from Compilers, concept `compiler-architecture`. Ticked by `compback`, whose `cb-ir` names the finding rather than the topic: what an IR is for, and what it must not hide. The ratio is read BOTH ways (-O0 1.106, -O2 0.818) and it is NOT MONOTONIC; and at -O2 all three targets agree on every opcode while emitting 253, 190 and 207 instructions. Concept id renamed `cb-ir` — see `tools/verify_compback.py`'s RETIRED list, which asserts `compiler-architecture` ABSENT so the rename cannot be undone by accident
- [ ] Learn Lexers  — `compiler`, from Compilers, concept `lexers`
- [ ] Learn Parser Design  — `compiler`, from Compilers, concept `parser-design`
- [ ] Learn Recursive-Descent Parsing  — `compiler`, from Compilers, concept `recursive-descent-parsing`
- [ ] Learn Pratt Parsing  — `compiler`, from Compilers, concept `pratt-parsing`
- [ ] Learn LR Parsing  — `compiler`, from Compilers, concept `lr-parsing`
- [ ] Learn GLR Parsing  — `compiler`, from Compilers, concept `glr-parsing`
- [ ] Learn Abstract Syntax Trees  — `compiler`, from Compilers, concept `abstract-syntax-trees`
- [ ] Learn Type Checking  — `compiler`, from Compilers, concept `type-checking`
- [ ] Learn Type Inference  — `compiler`, from Compilers, concept `type-inference`
- [ ] Learn Semantic Analysis  — `compiler`, from Compilers, concept `semantic-analysis`
- [ ] Learn Intermediate Representations  — `compiler`, from Compilers, concept `intermediate-representations`
- [ ] Learn SSA — Static Single Assignment  — `compiler`, from Compilers, concept `ssa-static-single-assignment`
- [ ] Learn Control-Flow Graphs  — `compiler`, from Compilers, concept `control-flow-graphs`
- [ ] Learn Data-Flow Analysis  — `compiler`, from Compilers, concept `data-flow-analysis`
- [ ] Learn Dominators  — `compiler`, from Compilers, concept `dominators`
- [x] Learn Register Allocation  — `compiler`, from Compilers, concept `register-allocation`. Ticked by `compback`'s `cb-regalloc`, 28 min, and it is the course's centrepiece because it holds the ONLY measurement in the collection whose machine runs the code it makes: four arms, 0/1/2/4 spilled values, one checksum 5925179420309322629 across all four, and bands rather than ticks because a clock reading and a byte-identical file cannot both be true. THE COST OF A SPILL IS NOT LINEAR and no page may say otherwise — the 1- and 2-spill arms are indistinguishable and only 4 separates. Three allocators give 58/166/45 spills and the 2.86 is a fact about the SPILL HEURISTIC, not the algorithms. Concept id renamed `cb-regalloc`
- [x] Learn Instruction Selection  — `compiler`, from Compilers, concept `instruction-selection`. Ticked by `compback`'s `cb-isel`, 27 min: a selector dispatching on operand KIND alone routes 49 of 61 instructions to the wrong machine form and NEVER FAILS ONCE, so the receipt is a checksum (193715795505516148 against 193715795509322676) and not the count. Fusion is MEASURED-ON-BYTES — seven AArch64 words re-encoded from register numbers, 7 of 7 agreeing with a real assembler — and the x86-64 half is a REFUSAL: `enc_x86` takes (op, dst, src) and cannot express a three-operand multiply. Concept id renamed `cb-isel`
- [x] Learn Instruction Scheduling  — `compiler`, from Compilers, concept `instruction-scheduling`. Ticked by `compback`'s `cb-sched`, 26 min: list scheduling with three priorities on a kernel chosen ON PURPOSE (kernel_d, not kernel_a, because a dependency chain gives the scheduler nothing to decide and prints three copies of the input). `height` against `height_hi` is the same algorithm with a different undocumented TIE-BREAK, and a backend reporting "my scheduler is better" without naming it has reported a different scheduler. Then the trap: without an alias analysis the schedule is FAST and WRONG. Concept id renamed `cb-sched`
- [ ] Learn Compiler Optimization  — `compiler`, from Compilers, concept `compiler-optimization`
- [ ] Learn Constant Folding  — `compiler`, from Compilers, concept `constant-folding`
- [ ] Learn Dead-Code Elimination  — `compiler`, from Compilers, concept `dead-code-elimination`
- [ ] Learn Common Subexpression Elimination  — `compiler`, from Compilers, concept `common-subexpression-elimination`
- [ ] Learn Loop Optimization  — `compiler`, from Compilers, concept `loop-optimization`
- [ ] Learn Inlining  — `compiler`, from Compilers, concept `inlining`
- [ ] Learn Escape Analysis  — `compiler`, from Compilers, concept `escape-analysis`
- [ ] Learn Link-Time Optimization  — `compiler`, from Compilers, concept `link-time-optimization`
- [ ] Learn JIT Compilation  — `compiler`, from Compilers, concept `jit-compilation`. The JVM's and the runtimes' JIT are in `vm`; this line is the compiler-internal one
- [ ] Learn Runtime Code Generation  — `compiler`, from Compilers, concept `runtime-code-generation`
- [x] Learn Compiler Debug Information  — `compiler`, from Compilers, concept `compiler-debug-information`. DWARF is already taught by the built `dwarf` course. Ticked by `compback`'s `cb-verify`, and it is ticked by its **SECOND HALF ONLY** — reading a backend's decisions back out of the bytes with NO debug information at all — and not by its first, because nothing in this course emits DWARF. That is retraction R16 in the artifact's own list, published rather than left implied. What is recovered is four things, of which THREE ARE COUNTS and the fourth is an INFERENCE and is labelled as one: 9 instructions, 7 distinct registers, peak 3 at instruction 3, so allocated without spilling — and a prologue is visible because it is a FRAME, not because it saves registers. Concept id `cb-verify`, deliberately NOT `cb-boundary`: `rv-boundary` and `x86-boundary` already exist and a concept id is resolved GLOBALLY
- [x] Learn Compiler ABIs  — `compiler`, from Compilers, concept `compiler-abis`. The x86-64 and AArch64 ABIs are already taught by `x86abi` and `a64abi`, and so is RISC-V's by `rvabi` — which is exactly why this page teaches the OBLIGATION and not the convention, and LINKS all three rather than re-teaching any. The subject is the ORDER: register allocation assigns names to values and the ABI assigns names to arguments, so a backend that learns the ABI second emits a prologue it did not plan for — on x86-64, a stack frame where the function looked like it needed none. 6 of 6 argument registers read on all three targets, and that count is a LOWER BOUND rather than an upper one. Concept id renamed `cb-abi`, asserted ABSENT as `compiler-abis` by the verifier
- [ ] Learn Borrow Checking  — `compiler`, from Compilers & Languages — Advanced, concept `borrow-checking`
- [ ] Learn Lifetime Analysis  — `compiler`, from Compilers & Languages — Advanced, concept `lifetime-analysis`
- [ ] Learn Region Inference  — `compiler`, from Compilers & Languages — Advanced, concept `region-inference`
- [ ] Learn Ownership Type Systems  — `compiler`, from Compilers & Languages — Advanced, concept `ownership-type-systems`
- [ ] Learn Algebraic Data Types  — `compiler`, from Compilers & Languages — Advanced, concept `algebraic-data-types`
- [ ] Learn Pattern Matching Compilation  — `compiler`, from Compilers & Languages — Advanced, concept `pattern-matching-compilation`
- [ ] Learn Effect Systems  — `compiler`, from Compilers & Languages — Advanced, concept `effect-systems`
- [ ] Learn Dependent Types  — `compiler`, from Compilers & Languages — Advanced, concept `dependent-types`
- [ ] Learn Type Erasure  — `compiler`, from Compilers & Languages — Advanced, concept `type-erasure`
- [ ] Learn Monomorphization  — `compiler`, from Compilers & Languages — Advanced, concept `monomorphization`
- [ ] Learn Trait Resolution  — `compiler`, from Compilers & Languages — Advanced, concept `trait-resolution`
- [ ] Learn Garbage Collector Integration  — `compiler`, from Compilers & Languages — Advanced, concept `garbage-collector-integration`
- [ ] Learn Closure Conversion  — `compiler`, from Compilers & Languages — Advanced, concept `closure-conversion`
- [ ] Learn Continuation-Passing Style  — `compiler`, from Compilers & Languages — Advanced, concept `continuation-passing-style`
- [ ] Learn Tail-Call Optimization  — `compiler`, from Compilers & Languages — Advanced, concept `tail-call-optimization`
- [ ] Learn Desugaring  — `compiler`, from Compilers & Languages — Advanced, concept `desugaring`
- [ ] Learn Macro Systems  — `compiler`, from Compilers & Languages — Advanced, concept `macro-systems`
- [ ] Learn Hygienic Macros  — `compiler`, from Compilers & Languages — Advanced, concept `hygienic-macros`
- [ ] Learn Module Systems  — `compiler`, from Compilers & Languages — Advanced, concept `module-systems`
- [ ] Learn Incremental Compilation  — `compiler`, from Compilers & Languages — Advanced, concept `incremental-compilation`
- [ ] Learn Compiler Caching  — `compiler`, from Compilers & Languages — Advanced, concept `compiler-caching`
- [ ] Learn Build Systems From First Principles  — `compiler`, from Build Systems & Toolchains, concept `build-systems-from-first-principles`
- [ ] Learn Make  — `compiler`, from Build Systems & Toolchains, concept `make`
- [ ] Learn Ninja  — `compiler`, from Build Systems & Toolchains, concept `ninja`
- [ ] Learn CMake Internals  — `compiler`, from Build Systems & Toolchains, concept `cmake-internals`
- [ ] Learn Dependency Resolution  — `compiler`, from Build Systems & Toolchains, concept `dependency-resolution`
- [ ] Learn Package Managers  — `compiler`, from Build Systems & Toolchains, concept `package-managers`
- [ ] Learn Reproducible Builds  — `compiler`, from Build Systems & Toolchains, concept `reproducible-builds`
- [ ] Learn Hermetic Builds  — `compiler`, from Build Systems & Toolchains, concept `hermetic-builds`
- [ ] Learn Cross Compilation  — `compiler`, from Build Systems & Toolchains, concept `cross-compilation`
- [ ] Learn Toolchains  — `compiler`, from Build Systems & Toolchains, concept `toolchains`
- [ ] Learn Sysroots  — `compiler`, from Build Systems & Toolchains, concept `sysroots`
- [ ] Learn Linker Toolchains  — `compiler`, from Build Systems & Toolchains, concept `linker-toolchains`
- [ ] Learn Compiler Drivers  — `compiler`, from Build Systems & Toolchains, concept `compiler-drivers`
- [ ] Learn Build Caching  — `compiler`, from Build Systems & Toolchains, concept `build-caching`
- [ ] Learn Distributed Build Systems  — `compiler`, from Build Systems & Toolchains, concept `distributed-build-systems`

## Planned course 9 of 14 — Virtual Machines, Runtimes and Language Internals

Slug `vm`. **63 items.**

Absorbs **Language Runtimes** (19 items), **JVM** (17 items), **WebAssembly** (12 items), **Programming Language Internals** (15 items).

- [ ] Learn Language Runtime Design  — `vm`, from Language Runtimes, concept `language-runtime-design`
- [ ] Learn Calling Conventions  — `vm`, from Language Runtimes, concept `calling-conventions`
- [ ] Learn Stack-Based Virtual Machines  — `vm`, from Language Runtimes, concept `stack-based-virtual-machines`
- [ ] Learn Register-Based Virtual Machines  — `vm`, from Language Runtimes, concept `register-based-virtual-machines`
- [ ] Learn Bytecode Interpreters  — `vm`, from Language Runtimes, concept `bytecode-interpreters`
- [ ] Learn Tree-Walking Interpreters  — `vm`, from Language Runtimes, concept `tree-walking-interpreters`
- [ ] Learn Virtual Machine Design  — `vm`, from Language Runtimes, concept `virtual-machine-design`
- [ ] Learn JIT Compilers  — `vm`, from Language Runtimes, concept `jit-compilers`
- [ ] Learn Inline Caches  — `vm`, from Language Runtimes, concept `inline-caches`
- [ ] Learn Runtime Type Information  — `vm`, from Language Runtimes, concept `runtime-type-information`
- [ ] Learn Exception Handling  — `vm`, from Language Runtimes, concept `exception-handling`
- [ ] Learn Stack Unwinding  — `vm`, from Language Runtimes, concept `stack-unwinding`. Taught in `debugio`; this line is its use in exception handling
- [ ] Learn Foreign Function Interfaces  — `vm`, from Language Runtimes, concept `foreign-function-interfaces`
- [ ] Learn ABI Compatibility  — `vm`, from Language Runtimes, concept `abi-compatibility`
- [ ] Learn Dynamic Dispatch  — `vm`, from Language Runtimes, concept `dynamic-dispatch`
- [ ] Learn Object Models  — `vm`, from Language Runtimes, concept `object-models`
- [ ] Learn Closures  — `vm`, from Language Runtimes, concept `closures`
- [ ] Learn Coroutines  — `vm`, from Language Runtimes, concept `coroutines`
- [ ] Learn Async Runtimes  — `vm`, from Language Runtimes, concept `async-runtimes`
- [ ] Learn JVM Architecture  — `vm`, from JVM, concept `jvm-architecture`
- [ ] Learn JVM Class Files  — `vm`, from JVM, concept `jvm-class-files`. The built `jvm` course already teaches this format (`jvm-header`, `jvm-constant-pool`, `jvm-code`); the line stays for the roadmap count
- [ ] Learn JVM Bytecode  — `vm`, from JVM, concept `jvm-bytecode`
- [ ] Learn JVM Verification  — `vm`, from JVM, concept `jvm-verification`
- [ ] Learn JVM Stack Frames  — `vm`, from JVM, concept `jvm-stack-frames`
- [ ] Learn JVM Operand Stacks  — `vm`, from JVM, concept `jvm-operand-stacks`
- [ ] Learn JVM Class Loading  — `vm`, from JVM, concept `jvm-class-loading`
- [ ] Learn JVM Linking  — `vm`, from JVM, concept `jvm-linking`
- [ ] Learn JVM Method Resolution  — `vm`, from JVM, concept `jvm-method-resolution`
- [ ] Learn JVM Garbage Collection  — `vm`, from JVM, concept `jvm-garbage-collection`
- [ ] Learn JVM JIT Compilation  — `vm`, from JVM, concept `jvm-jit-compilation`
- [ ] Learn JVM Safepoints  — `vm`, from JVM, concept `jvm-safepoints`
- [ ] Learn JVM Threads  — `vm`, from JVM, concept `jvm-threads`
- [ ] Learn JVM Synchronization  — `vm`, from JVM, concept `jvm-synchronization`
- [ ] Learn JVM Memory Model  — `vm`, from JVM, concept `jvm-memory-model`
- [ ] Learn JVM Native Interface  — `vm`, from JVM, concept `jvm-native-interface`
- [ ] Learn JVM Performance  — `vm`, from JVM, concept `jvm-performance`
- [ ] Learn WebAssembly  — `vm`, from WebAssembly, concept `webassembly`
- [ ] Learn WebAssembly Text Format  — `vm`, from WebAssembly, concept `webassembly-text-format`
- [ ] Learn WebAssembly Binary Format  — `vm`, from WebAssembly, concept `webassembly-binary-format`. The built `wasm` course already teaches this format (`wasm-header`, `wasm-sections`, `wasm-leb128`); the line stays for the roadmap count
- [ ] Learn WebAssembly Validation  — `vm`, from WebAssembly, concept `webassembly-validation`
- [ ] Learn WebAssembly Linear Memory  — `vm`, from WebAssembly, concept `webassembly-linear-memory`
- [ ] Learn WebAssembly Tables  — `vm`, from WebAssembly, concept `webassembly-tables`
- [ ] Learn WebAssembly Modules  — `vm`, from WebAssembly, concept `webassembly-modules`
- [ ] Learn WebAssembly Imports and Exports  — `vm`, from WebAssembly, concept `webassembly-imports-and-exports`
- [ ] Learn WebAssembly Runtime Design  — `vm`, from WebAssembly, concept `webassembly-runtime-design`
- [ ] Learn WebAssembly WASI  — `vm`, from WebAssembly, concept `webassembly-wasi`
- [ ] Learn WebAssembly Component Model  — `vm`, from WebAssembly, concept `webassembly-component-model`
- [ ] Learn WebAssembly Garbage Collection  — `vm`, from WebAssembly, concept `webassembly-garbage-collection`
- [ ] Learn C Object Representation  — `vm`, from Programming Language Internals, concept `c-object-representation`
- [ ] Learn C Undefined Behavior  — `vm`, from Programming Language Internals, concept `c-undefined-behavior`
- [ ] Learn C Memory Model  — `vm`, from Programming Language Internals, concept `c-memory-model`
- [ ] Learn C ABI  — `vm`, from Programming Language Internals, concept `c-abi`
- [ ] Learn C++ Object Model  — `vm`, from Programming Language Internals, concept `cpp-object-model`
- [ ] Learn C++ ABI  — `vm`, from Programming Language Internals, concept `cpp-abi`
- [ ] Learn C++ Name Mangling  — `vm`, from Programming Language Internals, concept `cpp-name-mangling`
- [ ] Learn C++ Virtual Functions  — `vm`, from Programming Language Internals, concept `cpp-virtual-functions`
- [ ] Learn C++ Exception Handling  — `vm`, from Programming Language Internals, concept `cpp-exceptions`
- [ ] Learn C++ RTTI  — `vm`, from Programming Language Internals, concept `cpp-rtti`
- [ ] Learn Rust Ownership Internals  — `vm`, from Programming Language Internals, concept `rust-ownership-internals`
- [ ] Learn Rust Borrow Checking Internals  — `vm`, from Programming Language Internals, concept `rust-borrow-checking-internals`
- [ ] Learn Rust Trait Objects  — `vm`, from Programming Language Internals, concept `rust-trait-objects`
- [ ] Learn Rust Async Runtime Internals  — `vm`, from Programming Language Internals, concept `rust-async-runtime-internals`
- [ ] Learn Rust ABI and FFI  — `vm`, from Programming Language Internals, concept `rust-abi-and-ffi`

## Planned course 10 of 14 — Data Structure and Database Internals

Slug `data`. **41 items.**

Absorbs **Databases & Storage Engines** (21 items), **Data Structures & Algorithms — Deep Internals** (18 items), **Binary Formats & File Formats — SQLite and Berkeley DB** (2 of 41 items).

- [ ] Learn Database Storage Engines  — `data`, from Databases & Storage Engines, concept `database-storage-engines`
- [ ] Learn B-Trees  — `data`, from Databases & Storage Engines, concept `b-trees`
- [ ] Learn B+ Trees  — `data`, from Databases & Storage Engines, concept `b-plus-trees`
- [ ] Learn LSM Trees  — `data`, from Databases & Storage Engines, concept `lsm-trees`
- [ ] Learn SSTables  — `data`, from Databases & Storage Engines, concept `sstables`
- [ ] Learn Write-Ahead Logging  — `data`, from Databases & Storage Engines, concept `write-ahead-logging`
- [ ] Learn Database Transactions  — `data`, from Databases & Storage Engines, concept `database-transactions`
- [ ] Learn MVCC  — `data`, from Databases & Storage Engines, concept `mvcc`
- [ ] Learn Database Isolation Levels  — `data`, from Databases & Storage Engines, concept `database-isolation-levels`
- [ ] Learn Database Recovery  — `data`, from Databases & Storage Engines, concept `database-recovery`
- [ ] Learn Database Buffer Pools  — `data`, from Databases & Storage Engines, concept `database-buffer-pools`
- [ ] Learn Database Indexes  — `data`, from Databases & Storage Engines, concept `database-indexes`
- [ ] Learn Query Execution  — `data`, from Databases & Storage Engines, concept `query-execution`
- [ ] Learn Query Planners  — `data`, from Databases & Storage Engines, concept `query-planners`
- [ ] Learn Cost-Based Query Optimization  — `data`, from Databases & Storage Engines, concept `cost-based-query-optimization`
- [ ] Learn Hash Tables in Databases  — `data`, from Databases & Storage Engines, concept `hash-tables-in-databases`
- [ ] Learn Bloom Filters  — `data`, from Databases & Storage Engines, concept `bloom-filters`
- [ ] Learn Compaction  — `data`, from Databases & Storage Engines, concept `compaction`
- [ ] Learn SQLite Internals  — `data`, from Databases & Storage Engines, concept `sqlite-internals`
- [ ] Learn SQLite Virtual Machine  — `data`, from Databases & Storage Engines, concept `sqlite-virtual-machine`
- [ ] Learn SQLite Query Planner  — `data`, from Databases & Storage Engines, concept `sqlite-query-planner`
- [ ] Learn Hash Tables  — `data`, from Data Structures & Algorithms — Deep Internals, concept `hash-tables`. The engine's use of it is the earlier line `Hash Tables in Databases`
- [ ] Learn Hash Table Collision Resolution  — `data`, from Data Structures & Algorithms — Deep Internals, concept `hash-table-collision-resolution`
- [ ] Learn Bloom Filters  — `data`, from Data Structures & Algorithms — Deep Internals, concept `bloom-filters`. Same concept; the other line of the pair is from Databases & Storage Engines
- [ ] Learn Cuckoo Hashing  — `data`, from Data Structures & Algorithms — Deep Internals, concept `cuckoo-hashing`
- [ ] Learn B-Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `b-trees`. Same concept; the other line of the pair is from Databases & Storage Engines
- [ ] Learn B+ Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `b-plus-trees`. Same concept; the other line of the pair is from Databases & Storage Engines
- [ ] Learn Red-Black Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `red-black-trees`
- [ ] Learn AVL Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `avl-trees`
- [ ] Learn Skip Lists  — `data`, from Data Structures & Algorithms — Deep Internals, concept `skip-lists`
- [ ] Learn Tries  — `data`, from Data Structures & Algorithms — Deep Internals, concept `tries`
- [ ] Learn Radix Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `radix-trees`
- [ ] Learn Interval Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `interval-trees`
- [ ] Learn Fenwick Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `fenwick-trees`
- [ ] Learn Segment Trees  — `data`, from Data Structures & Algorithms — Deep Internals, concept `segment-trees`
- [ ] Learn Union-Find  — `data`, from Data Structures & Algorithms — Deep Internals, concept `union-find`
- [ ] Learn Priority Queues  — `data`, from Data Structures & Algorithms — Deep Internals, concept `priority-queues`
- [ ] Learn Heaps  — `data`, from Data Structures & Algorithms — Deep Internals, concept `heaps`
- [ ] Learn Lock-Free Data Structures  — `data`, from Data Structures & Algorithms — Deep Internals, concept `lock-free-data-structures`
- [ ] Learn SQLite Database File Format  — `data`, from Binary Formats & File Formats, concept `sqlite-database-file-format`
- [ ] Learn Berkeley DB File Format  — `data`, from Binary Formats & File Formats, concept `berkeley-db-file-format`

## Planned course 11 of 14 — Graphics, Images and Page Description

Slug `graphics`. **29 items.**

Absorbs **Graphics** (20 items), **Binary Formats & File Formats — image and page formats** (9 of 41 items).

- [ ] Learn Rasterization  — `graphics`, from Graphics, concept `rasterization`
- [ ] Learn Computer Graphics From First Principles  — `graphics`, from Graphics, concept `computer-graphics-from-first-principles`
- [ ] Learn GPU Architecture  — `graphics`, from Graphics, concept `gpu-architecture`
- [ ] Learn GPU Memory  — `graphics`, from Graphics, concept `gpu-memory`
- [ ] Learn Graphics Pipelines  — `graphics`, from Graphics, concept `graphics-pipelines`
- [ ] Learn Vertex Processing  — `graphics`, from Graphics, concept `vertex-processing`
- [ ] Learn Rasterization  — `graphics`, from Graphics, concept `rasterization`. Same concept; the other line of the pair is from Graphics
- [ ] Learn Fragment Processing  — `graphics`, from Graphics, concept `fragment-processing`
- [ ] Learn Depth Buffers  — `graphics`, from Graphics, concept `depth-buffers`
- [ ] Learn Blending  — `graphics`, from Graphics, concept `blending`
- [ ] Learn Texture Sampling  — `graphics`, from Graphics, concept `texture-sampling`
- [ ] Learn GPU Command Buffers  — `graphics`, from Graphics, concept `gpu-command-buffers`
- [ ] Learn Shader Compilation  — `graphics`, from Graphics, concept `shader-compilation`
- [ ] Learn SPIR-V  — `graphics`, from Graphics, concept `spir-v`
- [ ] Learn Vulkan Architecture  — `graphics`, from Graphics, concept `vulkan-architecture`
- [ ] Learn Vulkan Synchronization  — `graphics`, from Graphics, concept `vulkan-synchronization`
- [ ] Learn Vulkan Memory Management  — `graphics`, from Graphics, concept `vulkan-memory-management`
- [ ] Learn OpenGL Internals  — `graphics`, from Graphics, concept `opengl-internals`
- [ ] Learn Direct3D Architecture  — `graphics`, from Graphics, concept `direct3d-architecture`
- [ ] Learn Metal Architecture  — `graphics`, from Graphics, concept `metal-architecture`
- [ ] Learn PDF — Portable Document Format  — `graphics`, from Binary Formats & File Formats, concept `pdf-portable-document-format`
- [ ] Learn PostScript  — `graphics`, from Binary Formats & File Formats, concept `postscript`
- [ ] Learn SVG — Scalable Vector Graphics  — `graphics`, from Binary Formats & File Formats, concept `svg-scalable-vector-graphics`
- [ ] Learn PNG — Portable Network Graphics  — `graphics`, from Binary Formats & File Formats, concept `png-portable-network-graphics`
- [ ] Learn JPEG — JPEG Image Format  — `graphics`, from Binary Formats & File Formats, concept `jpeg-jpeg-image-format`
- [ ] Learn GIF — Graphics Interchange Format  — `graphics`, from Binary Formats & File Formats, concept `gif-graphics-interchange-format`
- [ ] Learn WebP  — `graphics`, from Binary Formats & File Formats, concept `webp`
- [ ] Learn AVIF  — `graphics`, from Binary Formats & File Formats, concept `avif`
- [ ] Learn TIFF  — `graphics`, from Binary Formats & File Formats, concept `tiff`

## Planned course 12 of 14 — Audio, Video and Media Containers

Slug `media`. **31 items.**

Absorbs **Audio & Video** (22 items), **Binary Formats & File Formats — audio and video containers** (9 of 41 items).

- [ ] Learn Digital Audio From First Principles  — `media`, from Audio & Video, concept `digital-audio-from-first-principles`
- [ ] Learn PCM Audio  — `media`, from Audio & Video, concept `pcm-audio`
- [ ] Learn Sample Rates and Bit Depth  — `media`, from Audio & Video, concept `sample-rates-and-bit-depth`
- [ ] Learn Digital Audio Codecs  — `media`, from Audio & Video, concept `digital-audio-codecs`
- [ ] Learn MP3 Encoding  — `media`, from Audio & Video, concept `mp3-encoding`
- [ ] Learn AAC Encoding  — `media`, from Audio & Video, concept `aac-encoding`
- [ ] Learn Opus  — `media`, from Audio & Video, concept `opus`
- [ ] Learn FLAC Encoding  — `media`, from Audio & Video, concept `flac-encoding`
- [ ] Learn Digital Video From First Principles  — `media`, from Audio & Video, concept `digital-video-from-first-principles`
- [ ] Learn YUV and RGB Video  — `media`, from Audio & Video, concept `yuv-rgb`
- [ ] Learn Video Frames  — `media`, from Audio & Video, concept `video-frames`
- [ ] Learn I-Frames, P-Frames and B-Frames  — `media`, from Audio & Video, concept `video-frame-types`
- [ ] Learn Motion Estimation  — `media`, from Audio & Video, concept `motion-estimation`
- [ ] Learn H.264  — `media`, from Audio & Video, concept `h264-avc`
- [ ] Learn H.265 / HEVC  — `media`, from Audio & Video, concept `hevc`
- [ ] Learn AV1  — `media`, from Audio & Video, concept `av1`
- [ ] Learn VP9  — `media`, from Audio & Video, concept `vp9`
- [ ] Learn Video Encoding  — `media`, from Audio & Video, concept `video-encoding`
- [ ] Learn Video Decoding  — `media`, from Audio & Video, concept `video-decoding`
- [ ] Learn Audio/Video Synchronization  — `media`, from Audio & Video, concept `av-sync`
- [ ] Learn Media Containers  — `media`, from Audio & Video, concept `media-containers`
- [ ] Learn MP4 Internals  — `media`, from Audio & Video, concept `mp4-internals`
- [ ] Learn WAV — Waveform Audio File Format  — `media`, from Binary Formats & File Formats, concept `wav-waveform-audio-file-format`
- [ ] Learn AIFF — Audio Interchange File Format  — `media`, from Binary Formats & File Formats, concept `aiff-audio-interchange-file-format`
- [ ] Learn FLAC — Free Lossless Audio Codec Format  — `media`, from Binary Formats & File Formats, concept `flac-free-lossless-audio-codec-format`
- [ ] Learn Ogg and Ogg Containers  — `media`, from Binary Formats & File Formats, concept `ogg`
- [ ] Learn Matroska — MKV  — `media`, from Binary Formats & File Formats, concept `matroska`
- [ ] Learn MP3 File Format  — `media`, from Binary Formats & File Formats, concept `mp3-file-format`
- [ ] Learn MP4 — ISO Base Media File Format  — `media`, from Binary Formats & File Formats, concept `mp4`
- [ ] Learn MPEG Transport Stream  — `media`, from Binary Formats & File Formats, concept `mpeg-transport-stream`
- [ ] Learn MPEG Program Stream  — `media`, from Binary Formats & File Formats, concept `mpeg-program-stream`

## Planned course 13 of 14 — Debugging, Observability and Systems I/O

Slug `debugio`. **46 items.**

Absorbs **Debugging & Observability** (19 items), **Binary Formats & File Formats — PDB** (1 of 41 items), **System Design at the Lowest Level** (15 of 16 items), **Terminals & Shells** (11 items).

- [ ] Learn Debuggers From First Principles  — `debugio`, from Debugging & Observability, concept `debuggers-from-first-principles`
- [ ] Learn Breakpoints  — `debugio`, from Debugging & Observability, concept `breakpoints`
- [ ] Learn Watchpoints  — `debugio`, from Debugging & Observability, concept `watchpoints`
- [ ] Learn Hardware Breakpoints  — `debugio`, from Debugging & Observability, concept `hardware-breakpoints`
- [ ] Learn Stack Traces  — `debugio`, from Debugging & Observability, concept `stack-traces`
- [ ] Learn Stack Unwinding  — `debugio`, from Debugging & Observability, concept `stack-unwinding`
- [ ] Learn Core Dumps  — `debugio`, from Debugging & Observability, concept `core-dumps`
- [ ] Learn Crash Dumps  — `debugio`, from Debugging & Observability, concept `crash-dumps`
- [ ] Learn Minidumps  — `debugio`, from Debugging & Observability, concept `minidumps`
- [ ] Learn Debug Symbols  — `debugio`, from Debugging & Observability, concept `debug-symbols`
- [ ] Learn PDB Debug Information  — `debugio`, from Debugging & Observability, concept `pdb-debug-info`
- [ ] Learn Source-Level Debugging  — `debugio`, from Debugging & Observability, concept `source-level-debugging`
- [ ] Learn Remote Debugging  — `debugio`, from Debugging & Observability, concept `remote-debugging`
- [ ] Learn GDB Internals  — `debugio`, from Debugging & Observability, concept `gdb-internals`
- [ ] Learn LLDB Internals  — `debugio`, from Debugging & Observability, concept `lldb-internals`
- [ ] Learn System Call Tracing  — `debugio`, from Debugging & Observability, concept `system-call-tracing`
- [ ] Learn Linux perf  — `debugio`, from Debugging & Observability, concept `linux-perf`
- [ ] Learn eBPF Tracing  — `debugio`, from Debugging & Observability, concept `ebpf-tracing`
- [ ] Learn Hardware Performance Counters  — `debugio`, from Debugging & Observability, concept `hardware-performance-counters`
- [ ] Learn PDB — Program Database Format  — `debugio`, from Binary Formats & File Formats, concept `pdb-file-format`
- [ ] Learn IPC From First Principles  — `debugio`, from System Design at the Lowest Level, concept `ipc-from-first-principles`
- [ ] Learn RPC From First Principles  — `debugio`, from System Design at the Lowest Level, concept `rpc-from-first-principles`
- [ ] Learn Serialization From First Principles  — `debugio`, from System Design at the Lowest Level, concept `serialization-from-first-principles`
- [ ] Learn Event-Driven Architecture  — `debugio`, from System Design at the Lowest Level, concept `event-driven-architecture`
- [ ] Learn Message Queues  — `debugio`, from System Design at the Lowest Level, concept `message-queues`
- [ ] Learn Ring Buffers  — `debugio`, from System Design at the Lowest Level, concept `ring-buffers`
- [ ] Learn Memory Pools  — `debugio`, from System Design at the Lowest Level, concept `memory-pools`
- [ ] Learn Object Pools  — `debugio`, from System Design at the Lowest Level, concept `object-pools`
- [ ] Learn Zero-Copy I/O  — `debugio`, from System Design at the Lowest Level, concept `zero-copy-io`
- [ ] Learn Scatter-Gather I/O  — `debugio`, from System Design at the Lowest Level, concept `scatter-gather-io`
- [ ] Learn io_uring  — `debugio`, from System Design at the Lowest Level, concept `io-uring`
- [ ] Learn epoll  — `debugio`, from System Design at the Lowest Level, concept `epoll`
- [ ] Learn kqueue  — `debugio`, from System Design at the Lowest Level, concept `kqueue`
- [ ] Learn IOCP  — `debugio`, from System Design at the Lowest Level, concept `iocp`
- [ ] Learn Asynchronous File I/O  — `debugio`, from System Design at the Lowest Level, concept `async-file-io`
- [ ] Learn Terminal Emulators  — `debugio`, from Terminals & Shells, concept `terminal-emulators`
- [ ] Learn TTYs  — `debugio`, from Terminals & Shells, concept `ttys`
- [ ] Learn PTYs  — `debugio`, from Terminals & Shells, concept `ptys`
- [ ] Learn Terminal Line Discipline  — `debugio`, from Terminals & Shells, concept `terminal-line-discipline`
- [ ] Learn ANSI Escape Sequences  — `debugio`, from Terminals & Shells, concept `ansi-escape-sequences`
- [ ] Learn Shell Parsing  — `debugio`, from Terminals & Shells, concept `shell-parsing`
- [ ] Learn Shell Expansion  — `debugio`, from Terminals & Shells, concept `shell-expansion`
- [ ] Learn Shell Job Control  — `debugio`, from Terminals & Shells, concept `shell-job-control`
- [ ] Learn Unix Pipelines  — `debugio`, from Terminals & Shells, concept `unix-pipelines`
- [ ] Learn Process Groups  — `debugio`, from Terminals & Shells, concept `process-groups`
- [ ] Learn Session Management  — `debugio`, from Terminals & Shells, concept `session-management`

## Planned course 14 of 14 — Distributed Systems, Clocks and Consistency

Slug `distsys`. **30 items.**

Absorbs **Distributed Systems** (21 items), **Time & Clocks** (9 items).

- [ ] Learn Distributed Systems From First Principles  — `distsys`, from Distributed Systems, concept `distributed-systems-from-first-principles`
- [ ] Learn Clocks in Distributed Systems  — `distsys`, from Distributed Systems, concept `clocks-in-distributed-systems`
- [ ] Learn Logical Clocks  — `distsys`, from Distributed Systems, concept `logical-clocks`
- [ ] Learn Vector Clocks  — `distsys`, from Distributed Systems, concept `vector-clocks`
- [ ] Learn Leader Election  — `distsys`, from Distributed Systems, concept `leader-election`
- [ ] Learn Consensus  — `distsys`, from Distributed Systems, concept `consensus`
- [ ] Learn Raft  — `distsys`, from Distributed Systems, concept `raft`
- [ ] Learn Paxos  — `distsys`, from Distributed Systems, concept `paxos`
- [ ] Learn Distributed Transactions  — `distsys`, from Distributed Systems, concept `distributed-transactions`
- [ ] Learn Two-Phase Commit  — `distsys`, from Distributed Systems, concept `two-phase-commit`
- [ ] Learn Replication  — `distsys`, from Distributed Systems, concept `replication`
- [ ] Learn Quorum Systems  — `distsys`, from Distributed Systems, concept `quorum-systems`
- [ ] Learn Consistent Hashing  — `distsys`, from Distributed Systems, concept `consistent-hashing`
- [ ] Learn Distributed Hash Tables  — `distsys`, from Distributed Systems, concept `distributed-hash-tables`
- [ ] Learn CAP Theorem  — `distsys`, from Distributed Systems, concept `cap-theorem`
- [ ] Learn Eventual Consistency  — `distsys`, from Distributed Systems, concept `eventual-consistency`
- [ ] Learn Distributed Locks  — `distsys`, from Distributed Systems, concept `distributed-locks`
- [ ] Learn Distributed Logs  — `distsys`, from Distributed Systems, concept `distributed-logs`
- [ ] Learn Failure Detection  — `distsys`, from Distributed Systems, concept `failure-detection`
- [ ] Learn Idempotency  — `distsys`, from Distributed Systems, concept `idempotency`
- [ ] Learn Exactly-Once Processing  — `distsys`, from Distributed Systems, concept `exactly-once-processing`
- [ ] Learn Computer Timekeeping  — `distsys`, from Time & Clocks, concept `computer-timekeeping`
- [ ] Learn Unix Time  — `distsys`, from Time & Clocks, concept `unix-time`
- [ ] Learn Monotonic Clocks  — `distsys`, from Time & Clocks, concept `monotonic-clocks`
- [ ] Learn Wall Clocks  — `distsys`, from Time & Clocks, concept `wall-clocks`
- [ ] Learn Clock Synchronization  — `distsys`, from Time & Clocks, concept `clock-synchronization`
- [ ] Learn NTP  — `distsys`, from Time & Clocks, concept `ntp`. The NTP wire protocol is taught in `network`; this line is the clock model
- [ ] Learn Leap Seconds  — `distsys`, from Time & Clocks, concept `leap-seconds`
- [ ] Learn Time Zones  — `distsys`, from Time & Clocks, concept `time-zones`
- [ ] Learn Calendrical Computation  — `distsys`, from Time & Clocks, concept `calendrical-computation`

