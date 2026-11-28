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
| **elf** | **NONE — no harness file** | `courses/elf/assets/samples` (8 files; copied byte-for-byte from `obj`, `compback`, `dwarf` on 2026-11-27) | `courses/obj/research.md`; `courses/compback/research.md`; `courses/dwarf/research.md` | 2026-11-27 | `specimen_link_check.py` checksum plant | **BUNDLE VERIFIED** (33/33 assets); no byte verifier was authored in this batch |
| exe | `tools/verify_exe.py` | `courses/exe/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — `cycbench not built` (run `build_samples.sh`) |
| img | `tools/verify_img.py` | `courses/img/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — specimens missing |
| isa | `tools/verify_isa.py` | `courses/isa/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — specimens missing |
| jvm | `tools/verify_jvm.py` | `courses/jvm/assets/samples` (39 files) | `content/src/jvm_*.ch`; JVM Spec as cited | 2026-11-27 | yes (32→6) | PASS — 32 verified claims, crosscheck 25 files agree |
| link | `tools/verify_link.py` | `courses/link/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | PASS |
| macho | `tools/verify_macho.py` | `courses/macho/assets/samples` (7 files) | `content/src/macho_*.ch`; `loader.h`/`fat.h` as cited | 2026-11-27 | yes (125→122) | PASS — 125 verified claims (43/43 dump claims) |
| mem | `tools/verify_mem.py` | `courses/mem/assets/samples` | lesson text + `crosscheck.py` | 2026-11-27 | not in this batch | BLOCKED — `crosscheck.py` traceback |
| obj | `tools/verify_obj.py` | `courses/obj/assets/samples` (61 files) | `content/src/obj_*.ch`; ELF gABI / COFF / Mach-O | 2026-11-27 | yes (134→133) | PASS — 134 verified claims, crosscheck 87/0 |
| **pe** | **NONE — no harness file** | `courses/pe/assets/samples` (10 files; 3 real PE32+ images + 6 COFF objects/parsers copied from `coff`) | `courses/coff/research.md` (clang 21.1.8, LLVM 21.1.8 `llvm-readobj`) | 2026-11-27 | `specimen_link_check.py` checksum plant | **BUNDLE VERIFIED** (33/33 assets); no byte verifier was authored in this batch |
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

Full harness sweep (final rerun 2026-11-27 against the fresh `:9000` binary
`build/underlayer-i5c7d.exe`, throwaway `underlayer-i5c7-harness.db`):
**33 harness files executed, 27 PASS, 6 BLOCKED** by pre-existing missing
generated specimens or a `corrupt.py` traceback (exe, img, isa, mem, rvat,
sec). The 33 files are 31 per-course harnesses plus `verify_course_bytes.py`
and `verify_graded_banks.py`; **there is no `verify_elf.py` or `verify_pe.py`**,
so I5 did not "unblock" a harness — it supplied the bundles those harnesses
would read. No harness was deleted, weakened or relaxed, and the six BLOCKED
results are unchanged from the earlier report.

Specimen-asset coverage is now **33/33**: ELF and PE gained real bundles from
already-verified neighbours, so the "absent" rows above are closed. Byte-harness
coverage remains **31/33 files** because authoring the two missing verifiers
was outside this batch's file ownership. `tools/specimen_link_check.py` closes
the gap that can be closed without new byte claims: it verifies all 33 bundle
indexes, every per-file SHA-256, the archive SHA-256 and the named toolchain.

---

## 5. What remains (not claimed as done)

- **ELF and PE byte verifiers**: the specimen bundles now exist (I5), but no
  `tools/verify_elf.py` / `tools/verify_pe.py` was authored in this batch —
  `tools/` additions were limited to `specimen_link_check.py`. No byte claim
  was invented to fill that gap. The bundles are already consumable by H12.
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

---

## 6. I5 — learner specimen packs (2026-11-27)

Each of the 33 courses now has
`courses/<id>/assets/samples/<id>-specimen.zip` and a sibling
`<id>-specimen.json` index. The index records the archive SHA-256, every
member's size and SHA-256, the producer toolchain (`gcc 15.2.0`,
`clang 21.1.8`, `readelf/binutils 2.46`), the verification date and an explicit
`not_checked` list. Zip timestamps are fixed at 1980-01-01 so the archive hash
is reproducible.

**ELF and PE were built from verified files, not invented bytes.**

| Bundle | Files | Provenance |
|---|---:|---|
| `elf` | 8 | `demo_elf.o`, `demo_elfgcc.o`, `demo_arm64elf.o`, `demo_i386_elf.o` and `emit_elf.py` copied from `courses/obj/assets/samples`; `cbbench` (ET_EXEC x86-64) from `courses/compback/assets/samples`; `types_O0` (ET_EXEC x86-64) from `courses/dwarf/assets/samples`; plus `SOURCES.md`. Magic and `e_type` asserted from the copied bytes; `readelf -h` on the local host (GNU readelf 2.39, MinGW gcc 13.2.0) confirmed `7f 45 4c 46`, ELF64, REL, x86-64 — not used to author a claim. |
| `pe` | 10 | Three real PE32+ images (`comdat_linked.exe`, `directive_used.exe`, `link_prog.exe`) and six COFF objects/parsers copied from `courses/coff/assets/samples`; `SOURCES.md`. `MZ` and `PE\0\0` at `e_lfanew = 0x80` asserted from the copied bytes. Producer: clang 21.1.8 / LLVM 21.1.8 `llvm-readobj`; gcc/readelf did NOT produce or read these images. |

`SOURCES.md` in each new bundle names the source course, the dated producer
toolchain and what was **not** checked (execution, platform ABI behaviour and
any new byte/field claim). The six courses whose generated specimens are
missing (exe, img, isa, mem, rvat, sec) ship their verified scripts only and
say so in the index — no specimen was fabricated for them.

### Verification

```
tools/specimen_link_check.py --selftest                      -> 3/3 plants rejected
tools/specimen_link_check.py --base http://localhost:9042 \
    --workers 8                                             -> 0 failures
  bundle manifests + checksums: 33/33
  downloadable bundles: SKIPPED (no --download-base — see blocker below)
tools/specimen_link_check.py --plant <fixture>              -> 2 failures (missing link + planted bad SHA)
```

The checker verifies each zip against BOTH the recorded SHA-256 and the hash
of each member read back from the archive, and compares the toolchain object
with the pinned `clang 21.1.8 / gcc 15.2.0 / readelf 2.46` label.

### BLOCKER: served bundle downloads (not claimed as done)

`app/main.ch` registers `GET /courses/*` before the `web::App` catch-all, but
the router does not match nested paths such as
`/courses/elf/assets/samples/elf-specimen.zip`; the request falls through to
the web app and gets its 404 page. For single-segment paths the route is
shadowed by `GET /courses/:courseId`, and `handle_static_file` also prepends
`COURSES_DIR` to the full request path (`./courses` + `/courses/...`). Measured
on the fresh `:9042` binary: the zip and index URLs both answer 404, and
`/courses/elf.zip` answers `{"error":"course not found"}`.

A served `<a href="/courses/.../...-specimen.zip">` was implemented first and
removed after measurement: `verify_*.py`'s internal-link check then reported
`link ... -> 404` in **24 harnesses**, turning 27 PASS / 6 BLOCKED into
9 PASS / 24 FAIL. `app/main.ch` is outside this batch's file ownership, so the
served link is deliberately NOT shipped. The six editable static landings
(`coff`, `dwarf`, `elf`, `macho`, `obj`, `pe`) carry a **relative** link
(`assets/samples/<id>-specimen.zip`) that works from `file://`; the other 27
static landings and all 329 static lesson pages are owned by other files and
were not touched. `tools/specimen_link_check.py --require-served` makes this
blocker a hard failure; the default run states that served links are not
asserted rather than pretending they work.

---

## 7. C7 — one navigation shell on course landings

Six static landing files hand-rolled a five/six-link navbar
(`coff`, `dwarf`, `elf`, `macho`, `obj`, `pe`). Each now calls the shared
`render_site_nav(&mut page)` — the same component every lesson, served course
landing and collection page uses — and the duplicate skip-link, theme script,
theme toggle, identity slot, nav CSS and nav JS were removed. Course-scoped
progress stays as the strip below the shell on the ELF landing; the Ctrl+K
palette on that landing is intact.

Measured after `bash scripts/build_static.sh coff dwarf elf macho obj pe --quiet`
(137 pages regenerated locally, `courses/*/output` still gitignored):

| Course | Static `class="navbar"` | Served `class="navbar"` | Shared shell marker (static / served) | Ctrl+K in static | Relative bundle link |
|---|---:|---:|---|---|---|
| coff | 1 | 1 | yes / yes | no (never existed) | yes |
| dwarf | 1 | 1 | yes / yes | no (never existed) | yes |
| elf | 1 | 1 | yes / yes | **yes** | yes |
| macho | 1 | 1 | yes / yes | no (never existed) | yes |
| obj | 1 | 1 | yes / yes | no (never existed) | yes |
| pe | 1 | 1 | yes / yes | no (never existed) | yes |

`tools/nav_check.py --base http://localhost:9000 --quiet`:
**377 pages, 366 with HTTP 200 and exactly one nav carrying
`/courses`, `/search`, `/dashboard`, `/progress`; 11 gated pages 303 to
/login.** `tools/bracecheck.py` reports ALL CLEAR after the landing edits.
No verifier expectation was changed for C7: the byte harnesses check served
lessons and landing links, not the landing navbar markup.

---

## 8. I14 — PE minutes are no longer a uniform template

All 24 PE concepts had `estimated_minutes: 15`. The manifest now records
`minutes_method` and per-concept values derived by the documented ELF-style
rule (`docs/features-complete.md` 2.1.27): eight-module teaching-order bases
(12/15/18/18/18/18/20/20) adjusted by `clamp(round((visible_words - 1318.5) /
150), -3, +3)`. Every PE lesson has eight teaching units, so length is the
per-concept differentiator. `visible_words` was counted from each concept's
own `content/src/pe_<concept>.ch` with markup stripped (date 2026-11-27). This
is an estimate derived from text length, **not** a timing measurement.

Result: `{10,11,12,15,17,18,19,20}` minutes, total 413 across 24 concepts.
No byte, offset or timing claim was invented.

```
tools/course_landing_contract.py --base http://localhost:9042
  API<->landing parity: 33/33
  uniform minute distributions: 0
  COURSE LANDING CONTRACT 0 failure(s)
tools/course_landing_contract.py --selftest
  SELFTEST 4/4 — both negative plants rejected, controls accepted
```

The `--allow-uniform pe` exception is not needed and was not used.

---

## 9. Final served-artifact gate (fresh binary, throwaway DBs)

Built `build/underlayer-i5c7d.exe` with the pinned compiler; served on `:9042`
(`underlayer-i5c7-test.db`) and `:9000` (`underlayer-i5c7-harness.db`).

| Gate | Result |
|---|---|
| `GET /api/health` on :9042 | 200 |
| `course_landing_contract.py --base :9042` | 33/33 parity, 0 uniform, 0 failures |
| `specimen_link_check.py --base :9042 --workers 8` | 33/33 bundles, 0 failures (served-link assertion documented as blocked) |
| `specimen_link_check.py --selftest` / `--plant` | 3/3 and 2 failures respectively |
| 33 `verify_*.py` harnesses on :9000 | 27 PASS, 6 BLOCKED (pre-existing exe/img/isa/mem/rvat/sec) |
| `journey_quality_check.py :9000 --all --workers 4` | 364 passed, 0 failed |
| `theme_check.py :9042` | 56/56 (1 optional live-browser check skipped) |
| `lesson_pager_check.py :9042` | 35/35 |
| `verify_graded_banks.py` | 346 valid, 0 uncovered, 0 problems |
| `seo_surface_check.py :9000` | 372 URLs, 0 inconsistencies |
| `../build/tests.exe` | 138 passed, 0 failed (no Arc flake on this run) |
| `nav_check.py :9000 --quiet` | 377 pages, 0 nav failures |

`git diff --check`, `git status --short` and the uncommitted state are reported
in the handover, not here. **Nothing was committed or pushed.**

---

## 10. E1/E2 — first mission-link course and naming (2026-11-28)

**Toolchain:** CPython 3.12.2 (tags/v3.12.2:6abddd9, Feb 6 2024, 21:26:36)
[MSC v.1937 64 bit (AMD64)]; Chemical compiler at
`D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe`.
Server: **fresh** `build/underlayer-e12.exe`, port **9052**, throwaway
`underlayer-e12-test.db`; static pages regenerated from `courses/front` and
passed through the shared journey injector. Nothing committed or pushed.

### 10.1 Course verifier with per-count poison

`python tools/verify_front.py --poison`:

| Reported count | Value | Poison plant | Result |
|---|---:|---|---|
| `token_agreement` | 11 | rename `a` → `aa` in the specimen (token TEXT, count unchanged) | 11 → 10 MOVES |
| `ast_agreement` | 9 | replace `(b - 3)` with `b` in the specimen | 9 → 0 MOVES |
| `claim_hits` | 10 | change the lesson's `9` nodes claim to `8` | 10 → 9 MOVES |
| `graded_valid` | 6 | flip one `correct_index` in the manifest | 6 → 5 MOVES |
| `retired_hits` | 0 | plant `lexers` in the manifest | 0 → 1 MOVES |
| `runner_markers` | 9 | rename `oracleParse` in the runner source | 9 → 8 MOVES |

Verdict PASS; no count is a self-consistency report. The token stream and tree
are re-derived from `tokenize`/`ast`, not trusted from the fixtures.

### 10.2 Graded bank

The six new items were authored in the generator's exact convention
(`source_ref` → this course's own verified `src/*.ch` line, `source_quote`
verbatim, answer/distractors verbatim from that lesson). They cannot be
generated by `tools/generate_graded_banks.py` without editing
`content/src/*`, which this package does not own: the generator maps concept →
`content/src/<fn>.ch`. `python tools/generate_graded_banks.py` runs clean
(**0 new items needed**); `--ignore-existing-generated --out` deliberately
ignores authored items and reports 7 unmapped sources (4 pre-existing
`binread` + 3 `front`), stated rather than papered over.

`python tools/verify_graded_banks.py`: **356 total items, 356 valid, 35
courses, 336 concepts, 0 uncovered, 0 problem items** (296 generated incl.
the 6 new, 60 pre-existing). `--poison`: 5 → 4 valid keys, MOVES.

### 10.3 Learner-authored runner — real browser + constrained envelope

`python tools/front_runner_check.py`: **13/13 pass**.

- Python envelope (7/7): correct learner code matches the verified AST by
  value; a wrong tree is refused calmly; `open()`, `import socket` and
  `__import__` are refused by AST allowlist; an infinite loop is killed at
  **2.02 s** by the parent timeout; a 5000-character input is refused by the
  4096-character bound. The child runs with `-I`, a scrubbed environment, a
  temporary cwd and pure-data builtins only. This is an exercise envelope,
  not a security-grade sandbox, and the manifest says so.
- Real Chrome / CDP via Playwright on the `file://` static lesson (6/6): the
  learner typed `a + 2 * (b - 3) / 4` and saw **11** tokens plus AGREE-by-value
  from two parsers; `a +` produced `expected more input, reached end of source`;
  `open('/etc/passwd')` as source produced `unexpected character ' at offset 5`
  (refused as data, no file access); `-a * 2` agreed on `USub`; zero uncaught
  page errors.

### 10.4 Served-artifact gates on the fresh binary

| Gate | Result |
|---|---|
| `GET /api/health` | 200 |
| `GET /api/courses` | **35 courses**, `front` present with all seven I7 fields and 3 concepts |
| journey `--all` | **366 passed, 7 failed, 373 total** — the 7 are 4 pre-existing `binread` 404/402 and the **3 `front` lessons (404)** |
| theme / pager / dedupe | **56/56** (1 optional browser check skipped), **35/35**, **12/12** |
| bridge / security / g_features | **3/3**, **73/73**, **46/46** (+4/4 negative plants) |
| account surface / unit suite | **11/11 gated pages**, **138/138 tests** |
| SEO surface | 381 URLs; **7 problems**: 4 `binread` 402 (pre-existing paid gating) and 3 `front` 404 |
| quiz parity | aborted on a pre-existing `binread` 402; the 3 `front` lessons are 404 until hook 1 below (their static pages do carry in-page quizzes with `data-explain`) |
| explanation | 346/356 — 4 `binread` and **6 `front`** items not traceable (tool reads only `content/src/<concept>.ch`) |
| metadata | 35/35 disk manifests pass; API 33/35 — 2 `binread`, **3 `front`** compared against a hardcoded 33-course migration map |
| enroll / proof | 8/23 and 1 failure respectively — both on pre-existing pages, unrelated to `front` |

### 10.5 Exact hooks needed elsewhere (coordinator-owned)

These are not skipped silently; they are the reason the three `front` served
gates are not green yet. All four files are outside this package's ownership.

1. **`web/src/helpers.ch` + root `chemical.mod`** (two lines): add
   `import "./courses/front"` to the root manifest (the course module compiles
   on its own, verified with the pinned compiler), and add to
   `underlayer_web::render_concept`, BEFORE the generic ELF table (next to the
   `cb-` fall-through at `helpers.ch:1340-1341`):

       var front_html = front_pages::render_front_concept(concept_id)
       if(front_html.size() > 0) { return front_html }

   The dispatcher `front_pages::render_front_concept` is already authored and
   compiling in `courses/front/src/dispatch.ch`; it claims only `fe-lexer`,
   `fe-recursive-descent` and `fe-ast` and returns empty for everything else.
   Without the hook, `/courses/front/lessons/*` returns 404 and journey/SEO/
   quiz-parity cannot see the lessons.
2. **`tools/concept_sources.py` + `tools/explanation_check.py`**: teach both
   the course-local source root (`courses/<id>/src/<file>.ch`) for concepts
   whose manifest `source_ref` starts with `courses/`. Otherwise the six new
   explanation keys remain "not traceable" even though the cited lines exist.
3. **`tools/metadata_check.py::expected_for`**: let a course supply its own
   truthful `toolchain` / `spec_source` / `last_verified` (e.g. a `metadata`
   object in the course's specimen index) instead of deriving them only from
   gcc/clang/readelf fields with a fallback of `unrecorded` /
   `docs/course-mission.md` / `2026-11-27`. The `front` values are correct;
   the checker's 33-course migration map simply does not know new courses.
4. **`tools/front_runner_check.py` is NOT a server route** by design; no
   `app/main.ch` change is needed for the runner. The browser proof runs
   against the generated static page in backend-optional mode.

---

## 11. Final batch (2026-11-28) — red gates closed, new packages verified

Nothing in this batch was committed or pushed. Server: fresh
`build/underlayer-finalbatch3.exe`, port **9066**, throwaway
`verify-finalbatch3-9066.db`.

### Closed RED gates

| Gate | Before | After / evidence |
|---|---|---|
| `specimen_link_check.py` | 5 failures: `binread` reader 2.39 vs producer 2.46, date 2026-11-28 vs 2026-11-27, missing `front` bundle | **35/35 bundles, 0 failures.** `binread-specimen.json` now records inherited producers (gcc 15.2.0 / clang 21.1.8 / readelf 2.46) AND the local reader 2.39; the checker validates a declared, evidenced toolchain contract instead of one global version. `front` has a real 4-member bundle from its verified `specimen.src`/`.tokens`/`.ast`/`SOURCES.md` with the CPython 3.12.2 contract. 8/8 selftest cases (5 plants). |
| `proof_check.py` | 1 failure: expected "Proof Learner" not in served HTML | **0 failures.** The seed registered the name into `learners.name` but never set `learner_profiles.display_name`, which is what `/u/:username` renders. The checker now seeds the field it asserts on; 4/4 plants still rejected. |
| `enroll_check.py` | 8 failures on the fresh binary (2 stale "orphaned script" + 6 from a regex spanning neighbouring `<script>` tags) | **22/22 passed.** The assertion now targets the `#enroll-btn` handler specifically (the prerequisite `#enrol-state` script legitimately calls `can-enroll`), and the extractor isolates one `<script>` tag. 4/4 selftest plants. |
| H15 perf | CLS 0.1209 on the 420 px lesson; blocking Google Fonts CSS on 4 pages | **Gate passes with one DATED, OWNER-SIGNED exception.** `content/src/lesson_assets.ch` reserves space for hex dumps/tables/figures/controls and `content/src/lesson_nav_css.ch` reserves the post-font nav height. p95 CLS 0.03; LCP 2144 ms; INP 32 ms; transfer 57984 B. The font link is emitted by `WebLibs/brandlib/src/theme.ch` (outside this repo) and is excepted with owner, since/review dates and evidence path in `docs/h15-performance-budget.md`; `--no-exceptions` keeps the hard failure available. 12 selftest cases / 8 plants. |

### New packages

- **G5** — `order_steps`, `byte_range`, `decode_field`, `output_match` plus six
  `specimen_lab` items (one per course family) live in model/repository/grading
  code and in `content/authoring/g5_exercises.json`. `tools/generate_g5_banks.py`
  wrote 10 traceable items (5/5 selftest plants); graded banks are **366 valid /
  0 problems**; `tools/g5_types_check.py` passed with right/wrong grading for
  every new type (4/4 plants); the browser solved one of each.
- **G12** — `content/authoring/elf/bytes.json` → `tools/author_generate.py` →
  `content/authoring/generated/elf/bytes.ch` (macro-based, escaped). Lint 0
  failures (6/6 plants), preview served on 9067 (3/3 plants). The pilot is a
  draft: it is NOT swapped into the served course, so journey/byte-corpus
  coverage still applies to the shipped lesson (explicit gap, documented in
  `docs/course-development-handbook.md`).
- **G13** — `POST /api/progress/takeover/token` + `POST /api/progress/takeover`
  replay through `progress_sync_apply` under the same per-key `updated_at`
  rule, with an atomic one-shot token; FSRS columns are read-only here.
  `tools/takeover_check.py`: token replay 409 / no writes, two guest lessons
  imported, newer server row wins, FSRS unchanged (4/4 plants). Browser drive
  showed the dismissible prompt, the dismiss flag, and "Progress kept" with the
  local queue cleared. `/api/progress/import` was not touched.

### Gate results on the final binary

journey 369/369; theme 56/56; pager 35/35; dedupe 12/12; bridge 3/3;
security 73/73; SEO 377/377; graded banks 366 valid; quiz parity 332/332;
explanations 366/366; landing 35/35; specimen 35/35; metadata 35/35 disk;
proof 0 failures; enroll 22/22; g_features 46/46 (+4/4 plants); perf PASS with
the dated font exception; G5 0 failures; author lint 0; takeover 0 failures.
`build/tests-finalbatch.exe`: first run 137/138 (one transient failure in
`test_learning_view_still_records_a_real_concept` — "no state row was written",
not the known Arc flake), second diagnostic run 138/138. Both logs are in
`build/final-tests-run*.log`.
