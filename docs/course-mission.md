# The Mission: parsing → executable, from scratch

> **This is the goal the entire course collection exists to serve.** Every course
> decision — scope, depth, what gets verified, what gets deferred — is judged
> against this file. When a course brief is ambiguous, this file resolves it.
>
> Written from the founder's direction, Sept 2026. Load
> `.agents/skills/course_mission/SKILL.md` before starting any course work.

## The goal, in the founder's terms

Teach a learner the **complete path from parsing to a working executable**, so
that they can then build a compiler of their own that supports **any
architecture** and **any operating system**, and emits **executables and dynamic
libraries** — **without relying on LLVM or any other backend**. LLVM is taught
too, but as a *thing to understand and eventually replace*, never as a
dependency the learner cannot do without.

Concretely, a learner who finishes the chain should be able to:

- write a lexer and a parser for a real language
- build an IR
- emit machine code for x86-64, AArch64, RISC-V and others
- emit assembly, and assemble it themselves
- **write a linker** — symbol resolution, relocation application, static and
  dynamic
- produce a working executable, and a shared library
- write a loader's worth of runtime support: relocations at load, PLT/GOT,
  initialisers, TLS
- debug all of it with nothing but their own understanding and `xxd`

## The five rules that follow from it

These are the operational consequences. They are what actually change when
writing a concept.

### 1. From scratch, not by delegation

Anything the learner would otherwise get from a library is **taught, and then
rebuilt**. If a course says "call `libbfd`" or "use `LLVMOrcJIT`", it has skipped
the thing the learner came for.

This does **not** mean "never mention the real tool". It means: show what the tool
does, show its output, then show the bytes it is reading and have the learner
read them too. The tool is the oracle; the format is the subject.

> The exception is *bootstrap convenience*, and it must be labelled as such.
> A course may use `gcc` to *produce* a sample file, provided the learner is then
> shown how to read that file without it — and provided the course says plainly
> that the tool was used to make the specimen.

### 2. Every instruction, every architecture

Not "here is how a function call works". **Every instruction the architecture
defines**, with its encoding, its flags, its cost, and the trap that bites
people.

Architectures nobody in the team personally likes are taught anyway — AArch64 is
the standing example. Someone is always going to need it, and "we didn't feel
like it" is not a reason to leave a hole in a curriculum that claims to be
complete.

Where an architecture's instruction set is large, the course teaches it as a
**complete reference with depth on the instructions that matter**, and says
plainly which parts are deferred. Silence about coverage is the failure mode; not
covering ARM in full is not.

### 3. Practical, not textbook

Not the treatment a CS curriculum gives a format: define the grammar, state the
rules, move on. The treatment a practitioner needs: **here is the file, here is
what is wrong with it, here is what the toolchain does that is surprising, here
is what it costs, and here is what you must emit to make it work.**

Concretely, this means:

- work backwards from a real problem ("this relocation does not resolve")
- use files the toolchain actually emits, not idealised ones
- name the trap, the workaround, and the historical accident
- show the disassembly, and explain why that instruction and not another
- end with something the learner could build

### 4. Every single thing explained in detail

The default is **thorough**. A learner who does not know why a 2-byte field is
little-endian in one place and big-endian in another cannot be trusted with
either.

This cuts both ways and must be stated honestly: detail is the goal, and
conciseness is the thing to sacrifice. The real risk is *shallowness disguised as
clarity* — a paragraph that sounds explanatory and skips the actual mechanism.
The test is whether a learner who implements from the text alone would get it
right.

### 5. Learn by doing, then improve forever

The current phase is explicit and temporary:

1. **Now:** get *something deployed for every course*. Breadth and a working
   artefact per course beat a perfected one.
2. **Then:** revise each course again and again until it is genuinely good.

Nothing in the collection is considered finished because it exists. A course that
has never been revised is a course that has not been worked on.

## How a course must fit the chain

A course is a link in one path, and it inherits its job from its neighbours. The
chain, in teaching order:

```
  lexing ──▶ parsing ──▶ semantic analysis ──▶ IR
                                                    │
                          ┌─────────────────────────┤
                          ▼                         ▼
                   target instruction sets     optimization
                          │                         │
                          └────────────┬────────────┘
                                       ▼
                              code generation
                                       │
                                       ▼
                          assembly text / machine code
                                       │
                                       ▼
                          OBJECT FILES          ◀── relocatable, still unresolved
                                       │
                                       ▼
                          LINKING                ◀── resolve, relocate, lay out
                             │            │
                    static .o/.a     dynamic .so/.dll
                             │            │
                             └─────┬──────┘
                                   ▼
                          EXECUTABLE / SHARED LIBRARY
                                   │
                                   ▼
                          LOADING               ◀── map, relocate, run init
                                   │
                                   ▼
                          the process is alive
```

Two things follow that are easy to get wrong:

- **A course must not require a link the learner has not yet been given.** If a
  concept needs "the linker resolved this", and the linker has not been taught,
  the course has to teach the minimum needed, or say "this is taught in
  *Linking*, here is the shape of the answer".
- **A course must not re-teach its neighbour.** Three finished courses already
  cover object files *inside their own format*. A fourth course on ELF object
  files would be redundant. A course on **the object file as a concept**, compared
  across formats, is not — and it is the right shape for that slot.

## The standard for a course in this collection

| Must have | Why |
|---|---|
| Every byte claim traceable to a real file on disk | AI output is presumed wrong until checked |
| Two independent readers, or one reader plus a hand-check | Self-consistency proves nothing |
| A specimen set that ships with the course | So a learner can re-verify, and so the claim is falsifiable |
| Named, dated toolchain | "Verified with gcc 15.2 / clang 21" is a fact; "verified" is not |
| Documented limits | What was *not* checked is part of the course's honesty |
| Exercises the learner can run | Learn by doing, not by reading |
| A stated place in the chain | So it knows what it may assume and what it must teach |

## What is deliberately not the goal

- **Not** a replacement for the official specifications. The specs are cited, and
  the learner is pointed at them; the course's job is to make them *readable*.
- **Not** a survey of history. History is taught where it explains a decision —
  why this field is a 2-byte index, why this flag exists — and skipped otherwise.
- **Not** coverage for its own sake. A course that mentions RISC-V once and calls
  the architecture covered is worse than one that says "not yet, here is the
  link". `docs/courses-todo.md` tracks what is genuinely outstanding.
- **Not** one architecture's view of the world. The x86-64-first bias is a real
  bias and every course must state where it is speaking from one target and
  where the concept is portable.

## The linking half of the chain: 7 courses, not 25

`docs/courses-todo.md` originally listed **25** items under *Executables, Linking
& Loading*. On 2026-09-26 the founder authorised collapsing them to **7**. The
rule that the checklist permits only `[ ]`↔`[x]` was relaxed **once, for this
one edit**; it stands for every future edit.

The organising principle is **the linker's own pipeline**, because the mission's
outcome is a learner who can build one. The three platforms became an axis
*inside* each course rather than separate courses.

| # | Course | Absorbed checklist items | ~Concepts |
|---|---|---|---|
| 1 | **Object Files** | Object Files | 17 |
| 2 | **Symbol Resolution and Symbol Tables** | Symbol Tables, Symbol Resolution, Weak Symbols | 16 |
| 3 | **Relocations, PIC and PIE** | Relocations, Binary Relocation Processing, Position-Independent Code, Position-Independent Executables | 18 |
| 4 | **Static Linking and Linker Scripts** | Static Linking, Linkers, Linker Scripts, Link-Time Optimization | 16 |
| 5 | **Dynamic Linking and Shared Libraries** | Dynamic Linking, Shared Libraries, Procedure Linkage Tables, Global Offset Tables, Lazy Symbol Binding, Runtime Linking, Thread-Local Storage | 20 |
| 6 | **Executable Images and OS Loading** | Executable Loaders, Dynamic Loaders, How Linux Loads an ELF, How Windows Loads a PE, How macOS Loads a Mach-O, Address Space Layout Randomization | 18 |
| 7 | **Executable Security and Hardening** | Executable Format Security | 14 |

### Why these cuts, and what must not be re-taught

- **PLT and GOT are concepts, not courses.** Two data structures implementing
  one mechanism — an indirect call through a writable slot. One module in #5.
- **Lazy Symbol Binding is one paragraph.** Whether the first call goes through
  the resolver or the slot arrives pre-filled. It only looked large because of
  the name.
- **The three OS loaders merge into #6.** The comparison *is* the teaching
  device; three courses would teach one mechanism three times.
- **Symbol Resolution is pulled out of static linking (#2)** because it is the
  linker's central data structure, needed by both the static and the dynamic
  linker, and each format solved it differently.
- **PIC/PIE fold into relocations (#3).** Position-independence is not a topic,
  it is *the choice of which relocation set you emit*. Separating them guarantees
  re-explaining.
- **ASLR is treated canonically in #6** (it is a loader policy) and
  cross-referenced from #7 (that is its purpose).
- **LTO lives in #4** — it is an input-language question, and it only makes
  sense once the static linker's stages are known.
- **TLS lives in #5** — it is allocated and relocated by the dynamic-linking
  machinery, which is where a learner asking "where does TLS live" should land.

### The overlap that made this necessary

About 40% of the 25 items were already taught — per-format rather than
comparatively. The new courses must therefore **generalise, never repeat**:

| Already in a finished course | Item it pre-empts |
|---|---|
| `elf/relocation-types`, `coff/coff-relocations`, `macho/macho-relocations` | Relocations |
| `elf/symbol-table`, `coff/coff-symbol-table`, `macho/macho-symtab` | Symbol Tables |
| `elf/shared-libraries`, `macho/macho-dylibs` | Shared Libraries |
| `elf/ld-so`, `macho/macho-dyld`, `pe/pe-loader` | Dynamic/Executable Loaders |
| `elf/dynamic-relocations`, `pe/pe-base-relocations`, `macho/macho-chained-fixups` | Binary Relocation Processing |
| `pe/pe-security-flags`, `macho/macho-code-signing`, `macho/macho-hardening` | Executable Format Security |
| `elf/memory-layout`, `pe/pe-memory-layout`, `macho/macho-memory-layout` | ASLR |
| `coff/coff-weak-externals`, `coff/coff-tls`, `pe/pe-tls` | Weak Symbols, Thread-Local Storage |
| `elf/binding`, `elf/visibility` | Symbol Resolution |
| `coff/coff-archives` | archive concept (already delivered) |

**The gap this closes:** the finished courses teach each format's *answer*. These
7 teach **the question each answer was responding to** — which is what lets a
learner write a fourth format, or a linker. Today the collection can tell you
what the Mach-O loader does but not how to build one.

## The architecture half of the chain: 70 items -> 12 courses

Also authorised 2026-09-26. `## CPU Architecture` held **30** items and
duplicated the per-architecture sections three ways over. It collapsed to **6**,
giving **12 courses** across the four architecture sections
(`CPU Architecture` 30, `x86-64` 18, `ARM64` 13, `RISC-V` 9 = 70 items). The
count was 9 until 2026-09-29, when `x86-64` was split from one 22-concept
course into four sequential ones; see the note under the table.

The three per-architecture sections were already correctly shaped and are
**unchanged**. The split that makes "every architecture" teachable:

> **Neutral courses teach the principle and then contrast all three ISAs.
> The per-architecture course teaches one in depth.**

| # | Course | Absorbed from `CPU Architecture` | ~Concepts |
|---|---|---|---|
| 1 | **The Instruction Set Architecture** | CPU Architecture From First Principles, Instruction Sets, Machine Instructions, Registers, Flags and Condition Codes, CPU Addressing Modes, Instruction Decoding, Instruction Encoding | 20 |
| 2 | **How a CPU Executes Instructions** | CPU Pipelines, Instruction-Level Parallelism, Out-of-Order Execution, Speculative Execution, Branch Prediction, Microcode, Store Buffers | 18 |
| 3 | **The Memory Hierarchy** | CPU Caches, Cache Lines, Cache Coherence, TLBs, Memory Ordering | 18 |
| 4 | **Exceptions, Privilege and Mode Changes** | CPU Exceptions, Hardware Interrupts, CPU Privilege Levels, Context Switching | 16 |
| 5 | **Multiprocessor Architecture** | Multiprocessor Architecture, NUMA, CPU Virtualization, CPU Performance Counters | 16 |
| 6 | **SIMD and Vector Processing** | SIMD, Vector Processing | 16 |
| 7 | **x86-64 Assembly and Encoding** | 5 of the 18 `x86-64` items | 5 |
| 8 | **The x86-64 ABI** | 3 more | 6 |
| 9 | **The x86-64 Machine: Privilege, Memory and Time** | 5 more | 9 |
| 10 | **The x86-64 Data Path: Atomics, Ordering and Vectors** | the last 5 | 6 |
| 11 | **AArch64** | the existing 13 items, unchanged | 20 |
| 12 | **RISC-V** | the existing 9 items, unchanged | 18 |

8+7+5+4+4+2 = 30, and 18+13+9 = 40, so 70 items map onto **12** courses
with **nothing dropped** -- every item becomes a named concept or module.

> **Why `x86-64` is four rows and not one.** Rows 7-10 are the four courses
> `docs/x86-64-section-plan.md` splits the original 22-concept `x86-64` entry
> into, authorised by the founder on 2026-09-29. The no-duplication rule and
> the total coverage were both kept; only the shape changed, because a single
> 22-concept course is a course nobody finishes. Each of the four is finishable
> on its own, and none of them re-teaches a principle the neutral courses
> already own -- they pay the *exhaustive per-architecture reference* and link
> back for the *why*. **All four are shipped** (26 concepts, 662 minutes, 778
> harness checks), so the architecture half of the chain is complete up to
> AArch64 and RISC-V.

### Duplication that had to be resolved

| `CPU Architecture` item | Duplicated a per-arch item |
|---|---|
| Instruction Sets, Machine Instructions | all three "Assembly" |
| Instruction Decoding, Instruction Encoding | all three "Instruction Encoding" |
| Registers, Flags and Condition Codes | per-arch register and flag detail |
| CPU Addressing Modes | per-arch operand forms |
| CPU Exceptions, Hardware Interrupts | x86-64 "Interrupts and Exceptions", AArch64 "Exceptions" + "Interrupts", RISC-V "Interrupts" |
| CPU Privilege Levels | x86-64 "Protection Rings", RISC-V "Privilege Specification" |
| TLBs | all three "Paging" / "Page Tables" / "Virtual Memory" |
| Memory Ordering | x86-64 and AArch64 "Memory Ordering" |
| SIMD, Vector Processing | x86-64 SIMD/AVX/AVX-512, AArch64 NEON, RISC-V Vector |

### The comparison is the payoff, and only the collapse makes it possible

Three things a per-architecture course cannot teach and a neutral course can:

- **RISC-V has no flags register and no condition codes.** x86-64 has `EFLAGS`,
  AArch64 has `NZCV`, RISC-V has nothing -- so branches are the only conditional
  thing, and that single absence explains why AArch64 needs `csel`/`cset` at all
  and why a compiler emits a branch on one target and a `cmov` on another.
- **Encoding is a spectrum, not three facts.** x86-64 is variable-length
  (1-15 bytes), AArch64 is fixed 32-bit, RISC-V is 16/32-bit plus a 16-bit
  compressed extension. This is the design axis behind the fact that an object
  file's relocation record is architecture-specific -- which is the hinge
  between this section and the *Object Files* course.
- **Memory ordering differs in kind.** x86-64's `DIR` flag makes ordering
  implicit and historically buggy; AArch64 and RISC-V require explicit barriers.
  So does the object-file side: an x86-64 object needs no ordering metadata and
  an AArch64 object may.

### Why the three per-arch courses were NOT merged into one

Each is 18-22 concepts of genuinely different material, and a learner usually
needs one deeply rather than three shallowly. The comparison lives in the
neutral courses; the depth lives in the per-arch ones. Merging would produce a
course nobody finishes.

### Still outstanding

`## Memory` (27 items) overlaps *The Memory Hierarchy* almost entirely and the
two should be folded together rather than left as competing structures.
`## Compilers` (31) needs the same treatment. Neither restructured yet.
Naming unsettled: the section is `ARM64` but its items say `AArch64`.

### Previously outstanding



`## CPU Architecture` has the same disease — 15+ items (Instruction Sets,
Machine Instructions, Registers, Flags, Decoding, Encoding, Addressing Modes,
Pipelines, ILP, Out-of-Order, Speculative Execution, Branch Prediction, Caches).
By the mission's "every instruction, every architecture" rule that section
matters more than any other, and as written it would produce the same sprawl.
**Not yet restructured** — awaiting a ruling.

## The AArch64 section is FOUR courses, not one

Appended 2026-09-30, after the fourth and last course shipped. This is an
**addition to** the mission document and not a rewrite of it: the paragraphs
above are the ones the section was planned under and they stay as they are,
because a mission document that is quietly edited to match what was built is a
mission document that can no longer be used to judge what should be built next.

What changed is a fact about scope. The AArch64 material is not one course and
never plausibly was: `docs/courses-todo.md` has **thirteen** ARM64 items
(Assembly, Instruction Encoding, Calling Conventions, ABI, Stack Frames, System
Calls, Exceptions, Interrupts, SIMD/NEON, Atomics, Memory Ordering, Virtual
Memory, Page Tables), and the section resolved them into four courses:

| course | resolves | concepts | minutes |
|---|---|---|---|
| `a64asm` | Assembly, Instruction Encoding | 5 | 127 |
| `a64abi` | Calling Conventions, ABI, Stack Frames | 5 | 125 |
| `a64sys` | System Calls, Exceptions, Interrupts, Virtual Memory, Page Tables | 6 | 150 |
| `a64simd` | SIMD/NEON, Atomics, Memory Ordering | 5 | 127 |

All thirteen roadmap items are now ticked: 21 concepts, 529 minutes. The x86-64 section resolved its
eighteen items into four courses the same way, so the two sections are now
symmetric, and the practical consequence is the one worth stating: **a roadmap
item is not a course.** One ARM64 item -- "Memory Ordering" -- became a
twenty-six minute concept inside a five-concept course whose other four
concepts are about register files, encodings, atomics and cross-checks, and
splitting it into a course of its own would have produced a course about one
barrier field and no reason to read it.

### The RISC-V section is also four courses, and the third one changed what an absence is

Added 2026-10-01, in the same additive form as the AArch64 note above and for
the same reason: the paragraphs earlier in this document are the ones the
section was planned under, and they stay.

`docs/riscv-section-plan.md` collapsed the **nine** RISC-V roadmap items into
one course of ~18 concepts and then, on the founder's ruling that a course must
be finishable, split them into four:

| course | resolves | concepts | minutes |
|---|---|---|---|
| `rvasm` | ISA, Assembly, Instruction Encoding | 5 | 127 |
| `rvabi` | Calling Conventions | 4 | 101 |
| `rvpriv` | Privilege Specification, Virtual Memory, Interrupts | 4 | 101 |
| `rvat` | Atomics, Vector Extension | 4 | 101 |

All nine roadmap items are now ticked: 17 concepts, 430 minutes. **All three
architecture halves are now four courses each**, and the practical consequence
generalises past ARM64: **a roadmap item is not a course, and neither is an
architecture.** "RISC-V" was never one course's worth of material; it was 430
minutes of four.

What the section added that the other two did not is a progression in **what a
missing machine takes away**, and it is worth recording because the mission's
rule 1 ("does this help someone understand something deeply") is answered
differently by each course. `rvabi` lost the ability to **time**. `rvpriv` lost
the ability to **observe the subject at all** — a privileged architecture is
largely a document, so not one instruction in that course has been run, and
`ecall` is labelled MEASURED-AS-EMITTED on every page that mentions it.
`rvat` lost the ability to **compare rates**, and so its contrast with x86-64
and AArch64 is a COUNT against a COUNT and never a ratio: zero instructions in
its corpus take a lock prefix, against nine operations plus a reservation pair
that are atomic with no prefix at all, so the zero has a denominator instead of
being an absence.

The finding that generalises to the whole collection is the last one. Across
these four courses and their accumulated retractions, **not one
retraction is a mistake about how a computer works.** They are: a bit number
read out of a register instead of remembered, a call count taken by a method
that could not see a call, a section header counted as an instruction, and a
harness check that contradicted itself in two adjacent lines. A course that
retracts the specification it was built from — `rvat` retracts the brief's own
headline claim that the compiler emits `amoswap.w` in place of a hand-rolled
compare-exchange, because there is no `cmpxchg` in the base A extension to
trade against — and keeps the specification is doing the work this collection
exists to do.

Two things the mission's own rules gained from the section, both of which were
already required and are now checkable:

- **Rule 13 (label every claim MEASURED / MEASURED-ON-BYTES / QUOTED) caught a
  defect in itself.** The last course's artifact defined all three labels and
  then rendered only two of them in the same form, so a reader scanning for an
  unmeasured claim would have seen two labels one way and the third another.
  Fixed, and the fix is a count: the harness now asserts how many times each
  label appears *in its own form*, because a label rendered two ways is not a
  label. A rule nobody measures is a rule nobody has checked.
- **A cross-check that has silently stopped comparing reports the same number
  as one that is working.** The last course produced four normaliser bugs that
  each left a printed disagreement count at zero while eighty-five real decoder
  defects sat behind them, and not one of them printed a wrong word. The
  general form is now a check in the course's own harness: every reported
  number has its own poison, and a poison that does not move its number prints
  a failure. This belongs in the mission document rather than in one course's
  notes because it is true of the whole collection, and the collection's other
  seventeen course verifiers are the right place to apply it next.

## Related documents

| Document | Purpose |
|---|---|
| `.agents/skills/course_mission/SKILL.md` | The loadable version of this file, plus the decision checklist |
| `docs/courses-todo.md` | The status checklist. Status only — `[ ]`↔`[x]` and nothing else |
| `docs/course-development-handbook.md` | The 7-phase process for building a course |
| `docs/technical-research` (skill) | How to verify a claim against an authoritative source |
| `AGENTS.md` | The platform's engineering rules |
