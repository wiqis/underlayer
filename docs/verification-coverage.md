# Verification coverage — C1 / E3 / H12 (2026-11-27)

This document records the measured state of the graded-bank authoring pipeline
(C1), the poison rule for verifier counts (E3), and the per-course
byte-verification matrix (H12). It is a factual ledger: numbers that could not
be demonstrated are marked as such rather than filled in.

Nothing in this batch was committed or pushed. Servers used for verification
were local only (`:9036` for the endpoint probe, `:9000` for the legacy
harnesses), with disposable databases.

---

## 1. Baseline reconciliation: 329 live concepts vs the legacy 469 figure

| Measure | Value | Source |
|---|---|---|
| Live courses | 33 | `GET /api/courses` on `:9036`, 2026-11-27 |
| Live concepts (sum of the 33 course `concepts` fields) | **329** | same probe |
| Concepts in the 33 on-disk manifests | **329** | `python tools/concept_sources.py` |
| Legacy authoring figure | **469 lessons** | `docs/learner-first-mandate.md:35-36` and `docs/journey-quality-pass-2026-11-26.md:128` |

The two numbers count different objects in different authoring models. The
legacy docs count "lessons" (the nine semantic units are described as
~3,000 units across 469 lessons); the served API counts concepts in manifests.
Plan §1.2 says to treat **329 as the execution baseline** and have the owner
confirm 469 before C4/C5 targets are frozen. **Neither number is changed by
this package and the reconciliation is not claimed as resolved** — it stays an
owner decision (A8/C4/C5).

---

## 2. C1 — graded banks: exact counts before and after

| Measure | Before | After |
|---|---:|---:|
| Graded items (`exercise_decls` across all manifests) | 60 | **346** |
| Courses with ≥1 graded item | 3 | **33** |
| Concepts with ≥1 graded item | 43 | **329** |
| Courses with zero graded items | 30 | **0** |
| ELF / Mach-O / PE items | 15 / 27 / 18 | 15 / 27 / 18 (unchanged except one correction) |

286 items were generated. Each new item carries `source_ref`
(`content/src/<file>.ch:<line>`) and `source_quote` (verbatim cited text) in
addition to the shipped bank fields, so the answer key can be audited without
re-deriving it.

| Derivation method | Items | What the key is |
|---|---:|---|
| Lesson's own in-page graded quiz | 119 | The option marked correct in the lesson, with its own `data-explain` |
| Cloze from the lesson's own sentence | 155 | A verbatim `<code>` term in that sentence; distractors are other `<code>` terms from the same lesson |
| Lesson's own worked dump | 2 | The documented bytes at the documented offset |
| Verbatim statement recognition (last resort) | 10 | A sentence from the lesson; distractors are verbatim sentences from sibling lessons |

No byte, offset or spec value was authored by the generator. The concept →
lesson map is recovered from each course's build entry (a `render_*()` call
immediately followed by `write_page("output/<concept>.html")`), which is why
all 329 concepts map to a real verified source file.

Determinism was tested **after** the banks were written: two runs of
`python tools/generate_graded_banks.py --ignore-existing-generated --out <dir>`
produced 32 bank files each with zero diff (`git diff --no-index --stat`
exit 0) and identical SHA-256 for `elf.bank.json`
(`E7DB4869…B97A`). Without that flag a second run correctly emits nothing,
which would make the comparison vacuous; the flag only affects `--out`.

### Re-validation of the existing 60 items

- **60/60 keys re-validated** for structural contract (type, options,
  `correct_index`, answer consistency, non-empty explanation, difficulty),
  solvability (≥2 distinct options, answer equals the keyed option), and
  evidence (the answer string is present in that concept's verified lesson
  text).
- **1 corrected**, 59 left byte-for-byte unchanged:
  - `courses/macho/manifest.json`, `macho-intro` item 0. The answer key was
    `CF FA ED FE (0xFEEDFACF read little-endian)` but the keyed option read
    `CF FA ED FE (MH_MAGIC_64)` — the key did not equal the option it selected.
    Corrected the option to the keyed value; evidence
    `content/src/macho_intro.ch:35,71,99` and `content/src/macho_magic.ch:50`
    (`CF FA ED FE` = `0xFEEDFACF`, `MH_MAGIC_64`). The misleading hint
    "spells 'feed face'" was replaced with the lesson's own distinction
    `0xFEEDFACF` vs `0xFEEDFACE` (`macho_intro.ch:58`).
- The two non-MC types in the ELF bank (`hex_inspect`, `ordering`) were
  confirmed as real shipped types in `models/src/exercise_types_extra.ch` and
  `repository/src/exercise_type_map.ch`; they were not "fixed" to look like MC.

`tools/verify_graded_banks.py` is an independent second reader: it does not
reuse the generator's extraction logic. Current result: 346 total items,
346 valid, 33 courses, 329 concepts, 0 uncovered, 0 problems.

### Endpoint contract (fresh build on 9036)

Compiled `build/underlayer-c1.exe` from HEAD plus the new banks; started on
`:9036` with a **fresh, empty** SQLite file (important: manifest seeding uses
`INSERT OR IGNORE`, so a copied DB keeps stale rows). Probed nine banks.
Shape is unchanged:

```json
{"concept_id":"a64-aapcs","exercises":[{"id":"a64abi_a64-aapcs_0",
"type":"recognize","question":"Complete this sentence from the lesson: ...",
"options":["ARM-software/abi-aa","NSRN","NGRN"],"difficulty":0.5}],"total":1}
```

`bytes` → 4 items (`elf_bytes_13` is the existing `hex_inspect`),
`macho-intro` → 2 (with the corrected option visible), `pe-intro` → 2,
`cb-ir`/`jvm-intro`/`wasm-intro`/`coff-arm64`/`wasm-header` → 1 each. The
handler caps a response at 5 items per concept, so `total` is the number
served, not the number in the bank.

---

## 3. E3 — every reported count has a poison

Shared helper: `tools/verifier_poison.py` — `poison_workspace` (temp dirs only
under `tools/`), `copy_file`, `copy_dir`, `flip_byte`, `replace_in_file`,
`assert_count_moves`. Stdlib only, no `shell=True`, explicit subprocess
timeouts, no secrets, temp trees removed in `finally`.

| Verifier | Reported count | Poison plant | Result |
|---|---:|---|---|
| `verify_graded_banks.py` | 5 valid keys (`a64abi`) | flip `correct_index` in an isolated manifest | 5 → 4 **MOVES** |
| `verify_coff.py` | 67 | corrupt every matching specimen byte | 67 → 66 **MOVES** |
| `verify_dwarf.py` | 75 | corrupt every matching specimen byte | 75 → 74 **MOVES** |
| `verify_jvm.py` | 32 | corrupt every occurrence of a claimed sequence | 32 → 6 **MOVES** |
| `verify_macho.py` | 125 | corrupt every matching specimen byte | 125 → 122 **MOVES** |
| `verify_obj.py` | 134 | corrupt every matching specimen byte | 134 → 133 **MOVES** |
| `verify_sym.py` | 6 (`symtables.py` reader count) | truncate `ord_map` in the temp copy | 6 → 0 **MOVES** |
| `verify_wasm.py` | 36 | corrupt every matching specimen byte | 36 → 35 **MOVES** |
| `verify_a64abi.py --poison` | 5 concepts | drop one concept in a temp manifest | 5 → 4 **MOVES** |
| `verify_x86abi.py --poison` | 6 concepts | drop one concept in a temp manifest | 6 → 5 **MOVES** |
| `verifier_poison.py` self-test | byte value 35 | flip byte 0 of an isolated copy | 35 → 220 **MOVES** |

Two failure modes were found and fixed while building this: corrupting only
the *first* matching specimen left a second specimen satisfying the claim
(dwarf count stayed put), and a sequence occurring more than once in a class
file survived a single-byte plant (jvm count stayed put). Both now corrupt
**all** matches. No verifier was weakened to make a gate green.

---

## 4. H12 — 33-course byte-verification coverage matrix

"Last verified" means this harness was executed against the local build on
2026-11-27. `PYTHONUTF8=1`/`PYTHONIOENCODING=utf-8` were set for the legacy
harnesses so curl output decoded as UTF-8; the new byte verifiers pin their
children's encoding explicitly (the shipped JVM crosscheck disagrees 2/25
under `PYTHONUTF8=1` but agrees 0/25 with the pinned env — a pre-existing
environment quirk, recorded rather than papered over).

| Course | Byte verifier | Specimen asset | Spec source | Last verified | Poison | Result |
|---|---|---|---|---|---|---|
| a64abi | `tools/verify_a64abi.py` (+ `--poison`) | `courses/a64abi/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | yes (concept count) | PASS |
| a64asm | `tools/verify_a64asm.py` | `courses/a64asm/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| a64simd | `tools/verify_a64simd.py` | `courses/a64simd/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| a64sys | `tools/verify_a64sys.py` | `courses/a64sys/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| coff | `tools/verify_coff.py` | `courses/coff/assets/samples` (40 files) | `content/src/coff_*.ch`; COFF spec as cited | 2026-11-27 | yes (67→66) | PASS — 67 verified claims |
| compback | `tools/verify_compback.py` | `courses/compback/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS (served checks; crosscheck 169/1 pre-existing) |
| dwarf | `tools/verify_dwarf.py` | `courses/dwarf/assets/samples` (26 files) | `content/src/dwarf_*.ch`; DWARF 2-5 as cited | 2026-11-27 | yes (75→74) | PASS — 75 verified claims |
| dyn | `tools/verify_dyn.py` | `courses/dyn/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| **elf** | **NONE — pending I5** | **absent** (`courses/elf/assets` does not exist) | lesson text (not used until I5) | 2026-11-27 | n/a | **NOT VERIFIED BY BYTE** — I5 supplies the bundle |
| exe | `tools/verify_exe.py` | `courses/exe/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — `cycbench not built` (run `build_samples.sh`) |
| img | `tools/verify_img.py` | `courses/img/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — specimens missing |
| isa | `tools/verify_isa.py` | `courses/isa/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — specimens missing |
| jvm | `tools/verify_jvm.py` | `courses/jvm/assets/samples` (39 files) | `content/src/jvm_*.ch`; JVM Spec as cited | 2026-11-27 | yes (32→6) | PASS — 32 verified claims, crosscheck 25 files agree |
| link | `tools/verify_link.py` | `courses/link/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| macho | `tools/verify_macho.py` | `courses/macho/assets/samples` (7 files) | `content/src/macho_*.ch`; `loader.h`/`fat.h` as cited | 2026-11-27 | yes (125→122) | PASS — 125 verified claims (43/43 dump claims) |
| mem | `tools/verify_mem.py` | `courses/mem/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — `crosscheck.py` traceback |
| obj | `tools/verify_obj.py` | `courses/obj/assets/samples` (61 files) | `content/src/obj_*.ch`; ELF gABI / COFF / Mach-O | 2026-11-27 | yes (134→133) | PASS — 134 verified claims, crosscheck 87/0 |
| **pe** | **NONE — pending I5** | **absent** (`courses/pe/assets` does not exist) | lesson text (not used until I5) | 2026-11-27 | n/a | **NOT VERIFIED BY BYTE** — I5 supplies the bundle |
| priv | `tools/verify_priv.py` | `courses/priv/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS — crosscheck 88/0 |
| reloc | `tools/verify_reloc.py` | `courses/reloc/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| rvabi | `tools/verify_rvabi.py` | `courses/rvabi/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| rvasm | `tools/verify_rvasm.py` | `courses/rvasm/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| rvat | `tools/verify_rvat.py` | `courses/rvat/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — `corrupt.py` no tally; crosscheck 370/0 |
| rvpriv | `tools/verify_rvpriv.py` | `courses/rvpriv/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS — crosscheck 398/0 |
| sec | `tools/verify_sec.py` | `courses/sec/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — specimens missing |
| simd | `tools/verify_simd.py` | `courses/simd/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| smp | `tools/verify_smp.py` | `courses/smp/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| sym | `tools/verify_sym.py` | `courses/sym/assets/samples` (`ord_map`) | `content/src/sym_*.ch`; ELF gABI in `symtables.py` | 2026-11-27 | yes (6→0) | PASS — 6 independent-reader entries |
| wasm | `tools/verify_wasm.py` | `courses/wasm/assets/samples` (32 files) | `content/src/wasm_*.ch`; WebAssembly Spec as cited | 2026-11-27 | yes (36→35) | PASS — 36 verified claims |
| x86abi | `tools/verify_x86abi.py` (+ `--poison`) | `courses/x86abi/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | yes (concept count) | PASS |
| x86asm | `tools/verify_x86asm.py` | `courses/x86asm/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| x86simd | `tools/verify_x86simd.py` | `courses/x86simd/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| x86sys | `tools/verify_x86sys.py` | `courses/x86sys/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |

Full harness sweep: **33/33 executed, 27 PASS, 6 BLOCKED** by pre-existing
missing generated specimens or a `corrupt.py` traceback (exe, img, isa, mem,
rvat, sec). Those six failures are not caused by this batch: the only course
files changed are `manifest.json` `exercise_decls` arrays and one answer-key
correction. All 33 harness scripts were run; no harness was deleted or
relaxed. 31 courses have specimens; 2 (ELF, PE) do not and are honestly marked
pending I5 — coverage is **31/33**, not 33/33.

---

## 5. What remains (not claimed as done)

- **ELF and PE byte coverage**: `courses/elf/assets` and `courses/pe/assets`
  do not exist. No byte claim was invented to make the matrix 33/33. I5 must
  supply the bundles; then verifiers can be added.
- **Depth of practice**: 346 graded items against Exercism's 8,970 is a real
  gap. The generated items are retrieval/recognition (119 lesson quizzes, 155
  cloze, 2 dumps, 10 statement) — traceable and verifiable, but not
  substitute for authored problem sets, the four new graded types or specimen
  mini-labs (G5), or the learner-authored runner (E1).
- **The 10 `statement` items are the weakest of the generated set.** Every
  option is verbatim from verified lesson text, but they test recognition of
  prose. They are flagged for replacement when those concepts get their own
  in-page quiz, not silently presented as equivalent to the quiz-derived items.
- **Deployment seeding**: manifest changes are picked up by `INSERT OR IGNORE`
  only on a fresh DB. An already-seeded production DB will not receive the new
  items or the corrected Mach-O option without an explicit re-seed/migration;
  that is a follow-up outside this batch's file ownership.
- **Six legacy harnesses blocked** as listed above; they need `build_samples.sh`
  outputs (and a `corrupt.py` fix for rvat), owned by another package.
- **`docs/features-complete.md` ticks are NOT made in this batch** (another
  agent owns that file). Coordinator should tick only the items actually
  shipped here: C1 graded-bank coverage and E3/H12 verifier tooling.
- **No commit, no push.** All changes are left uncommitted for review.
