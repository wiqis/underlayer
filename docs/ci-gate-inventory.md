# CI gate inventory — 2026-11-28

**Scope.** This is the inventory of every checker gate wired into
`.github/workflows/ci.yml` by the 2026-11-28 pass, plus the gates that were
reported green but are **deliberately not wired** because their own negative or
live case is red. No tool, product source, test or other repo file was changed.
Nothing was committed or pushed.

**How the local numbers were produced.** Fresh server build from this checkout
(`build/underlayer-cigates.exe`, `-bm-modules --no-cache`, exit 0), all course
static pages rendered (`scripts/build_static.sh --quiet`, 35 courses / 370
pages, exit 0), server restarted on a fresh port **9069** with a throwaway
SQLite file. Two DB names were used to match the two jobs:
`ci-underlayer.db` (per-push simulation) and `ci-underlayer-test.db` (nightly
simulation; the `test` marker is required by `takeover_check.py`'s guard).
`anonymous_write_check.py` was additionally run against a second release-mode
boot of the same binary on 9069 with provenance env vars set and
`test-release-9069.db`. Exit codes are from those runs, not from reading code.

**Hard-gate rule.** There is no `|| true`, no `continue-on-error`, and no step
that turns a red checker green. The inverted plants are the one deliberate
exception in shape: they require the tool to exit **1** *and* print its named
defect, so a silent or vacuous plant fails CI. No secret, deploy, publish or
push step was added; `permissions: contents: read` is unchanged.

---

## 1. Wired in `verify` (every push) — live commands

All commands run while the job's disposable server is up. `BASE` is the
OS-assigned `http://localhost:$PORT`; `PORT` is exported by the server step.

| Gate | Command | Owner | Negative case (why it can fail) | Local exit |
|---|---|---|---|---:|
| H3 headers | `python tools/security_header_coverage.py "$BASE"` | `tools/security_header_coverage.py` (H3) | A frozen page, asset or 404 missing any of CSP/HSTS/nosniff/frame/referrer/request-id fails; `--selftest` serves a headerless page and must fail. | 0 |
| I9 anonymous surface | `python tools/anonymous_surface_check.py --base "$BASE"` | `tools/anonymous_surface_check.py` (I9) | An anonymous 200 with learner-shaped keys and no `"demo": true`, or a page not showing "Sign in to see your data". **Must run before any write probe** — see §4. | 0 |
| I2 / I1 / I14 / C1 | existing gates (`literal_route_shadow_check`, `seo_surface_check`, `course_landing_contract`, `verify_graded_banks`) | respective tool files | each has its own `--selftest` / bank contract. | 0 |
| I4 quiz parity | `python tools/quiz_parity_check.py "$BASE" --workers 8` | Course-content tooling, `tools/quiz_parity_check.py` | A lesson with an ungraded choice or an option without `data-explain` fails; inverted `--plant explain` is a hard gate (§2). | 0 (332/332 lessons, 1789/1789 options explained) |
| I3 explanations | `python tools/explanation_check.py "$BASE"` | Course-content tooling, `tools/explanation_check.py` | An explanation not traceable to its own lesson, or a submit response lacking `why_wrong`, fails; two inverted plants in §2. | 0 (366/366 items) |
| I7 metadata | `python tools/metadata_check.py --base "$BASE" --require-migrated` | Course manifests owned by the coordinator; contract in `tools/metadata_check.py` | Disk manifest, API field or served landing drift from the migrated contract; 5 planted drifts in `--selftest`. | 0 (35/35 on disk, API and landing) |
| G5 graded types | `python tools/g5_types_check.py --base "$BASE"` | `tools/g5_types_check.py` (G5) | A missing served type, wrong grading of a perturbed key, or a missing specimen bundle fails (4 plants in `--selftest`). | 0 |
| G10 data panel | `python tools/data_panel_check.py --base "$BASE"` | `tools/data_panel_check.py` (G10) | Missing fifth Settings tab / control, or a script calling any endpoint other than the shipped five, fails. | 0 |
| I10 search freeze | `python tools/search_contract_check.py --base "$BASE"` | `tools/search_contract_check.py` (I10) | Changed `/api/search` shape, missing `Link: rel="alternate"`, or a shipped concept consumer of `/api/search`. | 0 |
| I11 support link | `python tools/support_link_check.py --base "$BASE"` | `tools/support_link_check.py` (I11); `/privacy` text is F0/`pages_legal.ch` owned | Missing/duplicate footer `href="/support"`, missing channel/mailto/target, missing `/support`. The `/privacy` warning is deliberately not asserted: add `--require-privacy-channel` only when F0 fixes that page. | 0 (warning: `/privacy` still says "Help page") |
| B5 theme boot hash | `python tools/theme_boot_hash_check.py "$BASE"` | `tools/theme_boot_hash_check.py` (B5) | Source hash, SRI constant, inline fallback or served asset/CSP drift; planted source drift in `--selftest`. | 0 |
| I5 specimen bundles (disk + downloads) | `python tools/specimen_link_check.py --base "$BASE" --download-base "$BASE"` | `tools/specimen_link_check.py` (I5) | Missing bundle, checksum mismatch, or a 404/wrong-bytes download. `--selftest` rejects wrong checksum, missing link and missing toolchain label. `--require-served` is **not** wired — see §4. | 0 (35/35 bundles and downloads) |
| B7 empty bucket | `python tools/rate_limit_deployed_probe.py --local --port "$PORT" --reset-db ./ci-underlayer.db` | `tools/rate_limit_deployed_probe.py` (B7) | A learner bucket surviving the reset fails; the deployed two-network half is a founder action, not CI. | 0 (pre-existing gate) |

## 2. Wired in `verify` (every push) — nonvacuity and source verifiers

These run after the served gates, with the same server still up. Every tool
that exposes `--selftest` gets it; tools whose only negative input is a plant
are asserted by an inverted command that **must** exit 1 and print the named
defect.

| Gate | Command | Owner | Negative case | Local exit |
|---|---|---|---|---:|
| H3 control | `python tools/security_header_coverage.py --selftest` | H3 tool | Headerless frozen page must fail. | 0 |
| I7 control | `python tools/metadata_check.py --selftest` | I7 tool | 5 planted manifest/landing drifts rejected. | 0 |
| G5 control | `python tools/g5_types_check.py --selftest` | G5 tool | 4 planted contract breaks rejected. | 0 |
| G10 control | `python tools/data_panel_check.py --selftest` | G10 tool | Missing panel / missing typed confirm / new endpoint rejected. | 0 |
| I10 control | `python tools/search_contract_check.py --selftest` | I10 tool | Missing Link, wrong rel, changed payload, concept consumer rejected. | 0 |
| I9 control | `python tools/anonymous_surface_check.py --selftest` | I9 tool | Unmarked planted payload must fail. | 0 |
| I11 control | `python tools/support_link_check.py --selftest` | I11 tool | Missing/duplicate link and missing mailto rejected. | 0 |
| B5 control | `python tools/theme_boot_hash_check.py --selftest` | B5 tool | Planted source drift detected. | 0 |
| I5 control | `python tools/specimen_link_check.py --selftest` | I5 tool | 8/8 plants rejected. | 0 |
| G12 author lint | `python tools/author_lint.py --selftest` **and** `python tools/author_lint.py` | Content authoring, `tools/author_lint.py` | 6 planted wording/byte-claim/key failures rejected. | 0 / 0 |
| E3 front verifier | `python tools/verify_front.py --poison` | `tools/verify_front.py` (E1/E3) | Each of the six reported counts has its own plant and must move. | 0 (6/6 poisons moved) |
| binread verifier | `python tools/verify_binread.py` | `tools/verify_binread.py` | 60 specimen/claim/manifest checks; inverted `--self-poison` below. | 0 (60/60) |
| I4 inverted plant | `python tools/quiz_parity_check.py "$BASE" --plant explain --workers 8` → must exit 1, log must contain `options have data-explain` | I4 tool | One in-memory `data-explain` removed; a green or transport-error run fails CI. | 1 (expected) |
| I3 inverted plants | `python tools/explanation_check.py "$BASE" --plant` → exit 1 + `explanation not traceable`; `--plant-response` → exit 1 + `why_wrong is empty` | I3 tool | Two independent in-memory plants. | 1 / 1 (expected) |
| binread inverted poison | `python tools/verify_binread.py --self-poison` → exit 1 + `POISON (expected failure)` | binread tool | Deliberately false expectation must fail the same verifier. | 1 (expected) |
| H4 static negatives | `python tools/static_gate_negative_cases.py` (existing step) | `tools/static_gate_negative_cases.py` | Six source gates pass on the real tree and fail on planted copies. | 0 (pre-existing gate) |

## 3. Wired in `nightly-live-gates` (schedule / dispatch) — write gates

The nightly job gets its own checkout and its own **`ci-underlayer-test.db`**
(server, `DATABASE_URL`, `UL_DB` and every `--db` argument all renamed to
match). Nothing here points at a developer DB or at a deployed host.

| Gate | Command | Owner | Negative case | Local exit |
|---|---|---|---|---:|
| G1/G2/G4/G6 | `python tools/g_features_check.py "$BASE" --db ./ci-underlayer-test.db` | `tools/g_features_check.py` | 46 served/DB assertions plus **4 internal negative plants**; a plant accepted fails the run. | 0 (46/46, plants 4/4) |
| G10 browser | `python tools/data_panel_check.py --base "$BASE" --browser --seed` | `tools/data_panel_check.py` | Real Chrome must download JSON, confirm typed category delete, and reject a new endpoint; requires the explicit Playwright install step. | 0 |
| G8 proof | `python tools/proof_check.py --selftest` **and** `python tools/proof_check.py --base "$BASE" --seed --db ./ci-underlayer-test.db` | `tools/proof_check.py` (G8) | Client shell, unlinked certificate, no statistics, social graph all rejected in selftest; live seeds a shadow learner. | 0 / 0 |
| enrolment | `python tools/enroll_check.py --selftest` **and** `python tools/enroll_check.py --port "$PORT"` | `tools/enroll_check.py`; seed data in `repository/src/prerequisites_seed.ch` | 4 planted page failures in selftest; live checks 22 assertions incl. served enrol script behaviour. | 0 / 0 (22/22) |
| G13 takeover | `python tools/takeover_check.py --selftest` **and** `python tools/takeover_check.py --base "$BASE" --db ./ci-underlayer-test.db` | `tools/takeover_check.py` (G13) | 3 planted outcome failures; live proves replay 409 and FSRS columns untouched. | 0 / 0 |
| H1 consistency (local half) | `python tools/instance_consistency_probe.py --selftest` **and** `python tools/instance_consistency_probe.py "$BASE" --disposable` | `tools/instance_consistency_probe.py` (H1) | Drift at round 5 must be caught; live uses two tokens and 10 rounds on the local server. | 0 / 0 |
| E1 runner | `python tools/front_runner_check.py` **plus** hard assertion `grep -q 'runner checks: 13/13 pass'` | `tools/front_runner_check.py` (E1) | Wrong tree, file/network/dunder escape, timeout and bounded input are refused; Chrome half must report 13/13 — the tool exits 0 when the browser is skipped, so the grep is mandatory. | 0 (13/13) |

Existing nightly gates (`security_check.py`, `route_check.py`,
`integration_check.py`, `checker_nonvacuity.py`, `feedback_triage.py`,
`auth_shape_check.py`, `concept_migration_check.py`, `retention_check.py`,
`perf_budget_check.py`) are unchanged. The H15 perf budget comment ("KNOWN RED
… owner: founder / brandlib") is left intact; this pass did not relax it. The
two new nightly steps are placed **before** the H9/H15 step so a known-red H15
cannot prevent the new gates from running at all.

---

## 4. Deliberately NOT wired — exact failures

These tools were reported green by other agents but are **red locally** (or
red in the half that would make them meaningful). Per the task rule they were
left out rather than edited or relaxed.

| Gate | Exact local failure | Why it is out / owner fix |
|---|---|---|
| G7 `discovery_check.py` | `python tools/discovery_check.py --base http://localhost:9069` → **exit 1**: `FAIL expected 110 unique byte hits, found 114` (`DISCOVERY CHECK 1 failure(s)`). `--selftest` is green (exit 0). | The live evaluator hardcodes `110` at `tools/discovery_check.py:137`; the current tree has 35 courses / 114 `byte` hit URLs. Owner fix: derive the expected count from the manifests/search index or update the dated baseline in the tool. Not a product defect. |
| I8 `account_surface_check.py` | `python tools/account_surface_check.py --selftest` → **exit 1**: `FAIL SELFTEST VACUOUS: raw token accepted`, `FAIL SELFTEST VACUOUS: raw JSON error accepted`, `ACCOUNT SURFACE SELFTEST incomplete`. | The checker's own evaluator accepts a raw session token and a raw JSON error as clean page content. Wiring it without the selftest would green-light a vacuous checker, and wiring the selftest would make every push red. Owner fix in the tool's evaluator (and its dated exception JSON) first. |
| H14 `anonymous_write_check.py` | Selftest green (`SELFTEST 5/5`, exit 0), but the live release-mode probe → **exit 1**: `FAIL /api/progress/takeover/token: anonymous request (HTTP 200) changed persistent rows: progress_takeover_tokens 0->1` and `FAIL /api/fsrs/reset: anonymous request (HTTP 200) changed persistent rows: fsrs_params 0->1` (`ANONYMOUS WRITE SURFACE 2 failure(s)`). | Measured against a freshly built release-mode binary on 9069 with `UL_BUILD_MODE=release` plus all three provenance variables and a throwaway `test-release-9069.db`. Two write routes still bypass `require_session_in_release()`. Owner fix: gate those two routes in release builds, then wire the gate into nightly with a release server. A debug server cannot substitute: it deliberately keeps anonymous writes for the 138-test suite. |
| I5 `--require-served` half of `specimen_link_check.py` | `python tools/specimen_link_check.py --base http://localhost:9069 --download-base http://localhost:9069 --require-served` → **exit 1**, e.g. `FAIL dwarf /courses/dwarf/lessons/dwarf-intro: no specimen link for this course` (`SPECIMEN LINK CHECK 371 failure(s)`). | The route/download half is green (35/35) and is wired. The served-link half needs `data-specimen-link` in the content-owned course landings and shared lesson renderer (`content/src/*`); see `docs/deployment.md` §5j. The checker's help text still calls the route defect open, but the route itself was fixed. |
| H1 deployed half of `instance_consistency_probe.py` | Not run against `*.wiqis.com`. | The tool refuses a production base without `--founder-approved` and creates sessions; the deployed probe is a founder action, not a CI step. Only the local `--disposable` half is wired. |
| H12 `verify_course_bytes` | Not wired (pre-existing). | Six pre-existing specimen-blocked harnesses; unchanged by this pass. |

### Ordering constraint found while wiring

`helpful_dedupe_check.py` (an existing write gate) inserts a real review row.
After that, `GET /api/courses/elf/reviews` legitimately carries `learner_id`,
and `anonymous_surface_check.py` reports it as an unmarked anonymous payload:
`FAIL /api/courses/elf/reviews: anonymous 200 with learner keys [learner_id]
but no "demo": true` (exit 1). On a write-free DB the same command is green
(94 routes probed, 0 unmarked). The I9 live probe is therefore the **first**
command in the served-checker step; its selftest stays in the nonvacuity step.

---

## 5. Verification of the workflow file itself

- `yaml.safe_load` on `.github/workflows/ci.yml`: **OK**.
  Jobs: `verify`, `nightly-live-gates`. Step counts: **17** in `verify`,
  **15** in `nightly-live-gates`.
  `permissions` parses as `{'contents': 'read'}`.
- `git diff --check`: exit **0** (no whitespace errors).
- The new step bodies were extracted from the parsed YAML with PyYAML and run
  verbatim through Git Bash against the 9069 server: nonvacuity step exit **0**;
  nightly write-gates step exit **0**; nightly E1 runner step exit **0**.
- No commit, no push, no `git checkout`/`restore`/`stash`. Working tree changes
  are limited to `.github/workflows/ci.yml` and this document (plus the
  `docs/deployment.md` §2 update where needed).
