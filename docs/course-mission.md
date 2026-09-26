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

### Still outstanding

`## CPU Architecture` has the same disease — 15+ items (Instruction Sets,
Machine Instructions, Registers, Flags, Decoding, Encoding, Addressing Modes,
Pipelines, ILP, Out-of-Order, Speculative Execution, Branch Prediction, Caches).
By the mission's "every instruction, every architecture" rule that section
matters more than any other, and as written it would produce the same sprawl.
**Not yet restructured** — awaiting a ruling.

## Related documents

| Document | Purpose |
|---|---|
| `.agents/skills/course_mission/SKILL.md` | The loadable version of this file, plus the decision checklist |
| `docs/courses-todo.md` | The status checklist. Status only — `[ ]`↔`[x]` and nothing else |
| `docs/course-development-handbook.md` | The 7-phase process for building a course |
| `docs/technical-research` (skill) | How to verify a claim against an authoritative source |
| `AGENTS.md` | The platform's engineering rules |
