# Curriculum depth charter — 33 courses (I6)

**Date:** 2026-11-28. **Scope:** every shipped course in `courses/*/manifest.json`.
**Governing docs:** `docs/course-mission.md` (the parsing→executable chain),
`docs/courses-todo.md` (the roadmap this charter reconciles),
`docs/verification-coverage.md` (the 329-live-concept baseline).

This charter records **planned vs shipped concepts**, the reason for every
shortfall, and an owner/date line for each accepted shortfall. It authors **no
new course text** and changes no manifest. Its purpose is to stop "all 33
courses" being read as "every planned concept exists": two groups were cut
deliberately, and the numbers must be visible before E1/E2/E5/H12 set targets.

## 1. The two explicit deltas

### Linking half of the chain — planned 119, shipped 72

`docs/course-mission.md` §"The linking half of the chain: 7 courses, not 25"
plans these concept counts: obj 17, sym 16, reloc 18, link 16, dyn 20, img 18,
sec 14 = **119**. The shipped manifests hold 18 + 12 + 9 + 10 + 10 + 6 + 7 =
**72**. Shortfall: **47 concepts (-39.5%)**.

The cut was authorised on 2026-09-26 and is a *merge*, not a loss of topic:
PLT/GOT, lazy symbol binding, the three OS loaders, PIC/PIE, LTO and
per-format security were folded into comparative concepts inside the seven
courses. The mission's "why these cuts" table is the authoritative reason list.

### Neutral architecture half — planned 104, shipped 43

`docs/course-mission.md` §"The architecture half of the chain: 70 items -> 12
courses" plans isa 20, exe 18, mem 18, priv 16, smp 16, simd 16 = **104**.
Shipped: 7 + 6 + 8 + 8 + 7 + 7 = **43**. Shortfall: **61 concepts (-58.7%)**.

The mission's own rule is the reason: *"Neutral courses teach the principle and
then contrast all three ISAs. The per-architecture course teaches one in
depth."* The detailed material is in the 12 architecture courses (shipped
6+6+6+9+5+5+6+5+5+5+4+4 = **66** concepts), not deleted. Founder ruling §6.9
(2026-11-26) fixes the `ARM64`/`AArch64` naming now and defers restructuring
`Memory` and `Compilers` until after course #2 (E1).

### Owner / date for the two accepted shortfalls

- **Owner:** unassigned — must be named at Wave 4 kickoff per plan §0.2 rule 10.
  **Date:** 2026-11-28 (this charter). No `Docs/decisions.md` entry exists for
  these two deltas yet; recording one with an `- Owner:` line is a follow-up of
  I6, not something this charter pretends has happened.
- Decision owner for the structure: **Waqas Tahir**, ruling §6.9 on
  2026-11-26 (naming now, restructure after E1).

## 2. The baseline reconciliation: 469 legacy vs 329 live

`docs/learner-first-mandate.md:35` and `docs/journey-quality-pass-2026-11-26.md:128`
speak of **469 lessons / ~3,000 units**. The served API and all 33 manifests
expose **329 concepts**. The difference is an authoring-era figure from before
the roadmap collapsed 25 linking items into 7 courses and 70 architecture items
into 12; it is not a count of shipped lessons. `329` is the execution baseline
for C4/C5/E3/H12. Neither number is edited by this charter; see
`docs/verification-coverage.md` §1 for the measurement.

## 3. The 33-row matrix

"Place in chain" is where the course sits between *parse* and *working
executable*. "Assumptions" names what the course takes from a neighbour rather
than teaching again. Planned counts are the mission/roadmap numbers; where no
separate plan exists, planned = shipped and the reason column says so.

| Course | Place in chain | Planned | Shipped | Deferred / reason | Owner / date for shortfall | Assumptions |
|---|---|---:|---:|---|---|---|
| `a64abi` | Architecture depth: AArch64 ABI and frames | 5 | 5 | None recorded | — | Neutral ABI principle from `isa`/`exe`; no re-teach of register encoding. |
| `a64asm` | Architecture depth: AArch64 encoding and assembly | 5 | 5 | None recorded | — | The byte/format model from `obj`; fixed-width encoding contrast in `isa`. |
| `a64simd` | Architecture depth: NEON, atomics, ordering | 5 | 5 | None recorded | — | `simd` states the principle; this course pays the AArch64 reference. |
| `a64sys` | Architecture depth: system calls, exceptions, page tables | 6 | 6 | None recorded | — | `priv`/`mem` own the mechanism; this course shows AArch64's form. |
| `coff` | Format: Windows object counterpart | 18 | 18 | None recorded | — | `bytes` and ELF's field-reading method are already known. |
| `compback` | Compiler backend: IR → machine code | 6 | 6 | None recorded; the *missing* front-end link is E1, not a concept shortfall here | — | Reads relocations from `reloc` and object layout from `obj`. |
| `dwarf` | Debugging data describing the produced executable | 23 | 23 | None recorded | — | Section/segment model from `elf`; no source-language semantics. |
| `dyn` | Linking 5: shared libraries, GOT/PLT, TLS | 20 | 10 | GOT/PLT, lazy binding and TLS merged into comparative concepts (mission cut table) | Unassigned, 2026-11-28 | Static symbol resolution from `sym`; relocation records from `reloc`. |
| `elf` | Format specimen: the reference object/executable | 24 | 24 | None recorded | — | `bytes` only; every later format compares against this one. |
| `exe` | Neutral architecture 2: how the CPU executes | 18 | 6 | Per-architecture courses own pipeline/speculation detail (mission rule, §258-259) | Unassigned, 2026-11-28 | Encoding/ISA vocabulary from `isa`. |
| `img` | Linking 6: OS loading | 18 | 6 | Three OS loaders merged into one comparative course; ASLR cross-referenced from `sec` | Unassigned, 2026-11-28 | Segment model from `elf`; relocation outcomes from `dyn`. |
| `isa` | Neutral architecture 1: instruction meaning, three ISAs | 20 | 7 | Encoding spectrum taught by contrast; exhaustive decode lives in the per-arch courses | Unassigned, 2026-11-28 | `obj-arch-table` asked the question this course answers. |
| `jvm` | Adjacent VM format (not on the native linker chain) | 18 | 18 | None recorded | — | Class-file bytes only; no native loader claim. |
| `link` | Linking 4: static linking and linker scripts | 16 | 10 | LTO and script detail folded into static-link stages | Unassigned, 2026-11-28 | `sym` and `reloc` are prerequisites. |
| `macho` | Format: Apple object counterpart | 24 | 24 | None recorded | — | ELF's field-reading method; dyld compared in `dyn`/`img`. |
| `mem` | Neutral architecture 3: caches, TLBs, ordering | 18 | 8 | Per-arch memory/ordering detail moved to the depth courses | Unassigned, 2026-11-28 | Virtual memory vocabulary from `priv`. |
| `obj` | Linking 1: emitter output / linker input | 17 | 18 | Exceeds plan by 1 (concept added during authoring); no shortfall | — | ELF/COFF/Mach-O section and symbol fields. |
| `pe` | Format: Windows loader view | 24 | 24 | None recorded | — | COFF object layout; loader comparison in `img`. |
| `priv` | Neutral architecture 4: exceptions, privilege, modes | 16 | 8 | Interrupt/context-switch depth moved to per-arch courses | Unassigned, 2026-11-28 | `isa` branch/flag model. |
| `reloc` | Linking 3: patch records, PIC and PIE | 18 | 9 | PIC/PIE folded into the choice of relocation set (mission §215) | Unassigned, 2026-11-28 | Symbol tables from `sym`; object sections from `obj`. |
| `rvabi` | Architecture depth: RISC-V calling convention | 4 | 4 | None recorded | — | Neutral ABI principle; no flags register (mission §308). |
| `rvasm` | Architecture depth: RISC-V encoding spectrum | 5 | 5 | None recorded | — | `isa` contrast; compressed extension is deliberately scoped. |
| `rvat` | Architecture depth: RISC-V atomics and vector | 4 | 4 | None recorded | — | `simd` principle; corpus labels unmodelled words honestly. |
| `rvpriv` | Architecture depth: RISC-V privileged architecture | 4 | 4 | None recorded | — | `priv` mechanism; `ecall` marked MEASURED-AS-EMITTED. |
| `sec` | Linking 7: hardening the produced executable | 14 | 7 | Per-format security taught comparatively, not per-platform | Unassigned, 2026-11-28 | Loader policy from `img`; format flags from `elf`/`pe`/`macho`. |
| `simd` | Neutral architecture 6: vectors and atomics | 16 | 7 | Per-arch vector/atomic detail lives in the depth courses | Unassigned, 2026-11-28 | `isa` register model. |
| `smp` | Neutral architecture 5: multiprocessor and counters | 16 | 7 | NUMA/virtualisation/counter depth moved to per-arch courses | Unassigned, 2026-11-28 | `mem` coherence and ordering. |
| `sym` | Linking 2: symbol tables and resolution | 16 | 12 | Weak symbols folded into resolution/binding | Unassigned, 2026-11-28 | Object symbol records from `obj`/`elf`/`coff`/`macho`. |
| `wasm` | Adjacent VM format (not on the native linker chain) | 13 | 13 | None recorded | — | Binary-format reading method; no native executable claim. |
| `x86abi` | Architecture depth: x86-64 ABI | 6 | 6 | None recorded | — | Neutral ABI principle; x86-64 register file from `x86asm`. |
| `x86asm` | Architecture depth: x86-64 encoding and assembly | 5 | 5 | None recorded | — | `isa` contrast; ModRM/SIB introduced here, not in `isa`. |
| `x86simd` | Architecture depth: atomics, ordering, vectors | 6 | 6 | None recorded | — | `simd` principle; AVX-512 refusal documented. |
| `x86sys` | Architecture depth: privilege, paging, time | 9 | 9 | None recorded | — | `priv`/`mem` mechanism; PMU counters are scoped. |

## 4. What this charter drives

- **E1** (mission-completing parsing→executable course) inherits the 47+61
  concept shortfalls as *context*, not as a mandate to fill every one.
- **E2** resolves `Memory` vs `The Memory Hierarchy` and the compiler section
  after E1 under ruling §6.9; it does not silently close the neutral-architecture
  delta.
- **E5** uses this matrix as the per-course revision baseline.
- **H12** verifies what is shipped (329 concepts), not the 223 planned
  concepts of the two cut groups (119 + 104).
- **I7** publishes the manifest metadata beside these numbers; no manifest is
  edited here.

## 5. E1/E2 addendum (2026-11-28)

This section is additive. It does not rewrite the 33-row matrix above, which
records the state at the date at the top of this charter.

### 5.1 The first link is now shipped

`courses/front` (3 concepts: `fe-lexer`, `fe-recursive-descent`, `fe-ast`; 72
minutes) is the first link in the mission chain. It teaches lexing → recursive-
descent parsing → AST for a real language (Python integer expressions) and
checks every number against CPython 3.12.2's `tokenize`/`ast` and a specimen on
disk. It deliberately does **not** teach IR, code generation, object files,
linking or loading; those remain with `compback` and the format courses. It
also does not tick parser-design, Pratt/LR/GLR, type checking, inference or
semantic analysis — those roadmap items stay open and are linked from
`docs/courses-todo.md`.

| Course | Place in chain | Planned | Shipped | Deferred / reason | Owner / date | Assumptions |
|---|---|---:|---:|---|---|---|
| `front` | First link: characters → tokens → AST | 3 | 3 | IR/codegen/linking/loading belong to `compback` and the format courses; no re-teach | Underlayer, 2026-11-28 | Basic Python syntax; no compiler course |

### 5.2 E2 — naming settled, restructure recorded as deferred

Founder ruling **§6.9** (2026-11-26) chose "(a) naming now, (b) restructure
after course #2". The two outcomes are recorded separately so the cheap fix is
not mistaken for the expensive one:

| Item | State on 2026-11-28 | Decision owner / date | Execution owner / date |
|---|---|---|---|
| `ARM64` (section label) vs `AArch64` (concept text) | **Settled now.** Canonical name is `AArch64`; the historical label stays as history. `docs/course-mission.md` gained the ruling as an additive note | Waqas Tahir, ruling §6.9, 2026-11-26 | E2 recorded it 2026-11-28; unassigned for any later copy sweep pending Wave 4 kickoff (plan §0.2 rule 10) |
| Fold `## Memory` into *The Memory Hierarchy* | **Deferred** until after E1 proves the finishable-course shape | Waqas Tahir, ruling §6.9, 2026-11-26 | Unassigned — must be named at Wave 4 kickoff; recorded 2026-11-28 |
| Restructure `## Compilers` into finishable courses | **Deferred** for the same reason; `front` is the first module, not the whole section | Waqas Tahir, ruling §6.9, 2026-11-26 | Unassigned — must be named at Wave 4 kickoff; recorded 2026-11-28 |

No `Docs/decisions.md` entry is appended by this addendum: §6.9 is already
covered by the consolidated 2026-11-26 entry (plan §3 A7). The owner column
above is the checkable record required by plan §0.2 rule 10; where it says
"unassigned", that is a real gap, not an assumption that somebody owns it.
