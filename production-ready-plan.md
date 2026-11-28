# Underlayer — Production-Ready Plan

**Status:** DRAFT — founder review required. Written 2026-11-26; revised after independent review.
**Location:** `Web/underlayer/production-ready-plan.md` (this repo). It is the single plan for
both Underlayer clients: the Chemical web platform in this repo, and the Kotlin/KMP client at
`Android/Apps/underlayer-kmp` (a separate repo, referenced by path throughout). Nothing in
this document authorises a push or a commit — see §0.2.

---

## 0. How to read this plan

### 0.1 The one-paragraph diagnosis

Underlayer has three layers, and only one of them is finished:

| Layer | State | Evidence |
|---|---|---|
| **Content + pedagogy** | Strong. 33 courses / 329 concepts, byte-verified, guided journey across every lesson, 364/364 served-HTML checks passing. | `docs/journey-quality-pass-2026-11-26.md`, `docs/journey-accessibility-2026-11-26.md`, live `/api/courses`. |
| **Platform + operations** | Beta. One SQLite file, one process, manual deploys, no request logging, checkers instead of the `@test` suite, CI never run on a runner. | `docs/deployment.md` §6, `docs/production-hardening-2026-11-26.md` §7. |
| **Business + product surface** | Absent. 0/60 payment items, 0/50 certificate items, 0/85 social items, 0/40 i18n items; 60 graded exercises for 329 concepts. | `docs/features-complete.md`, live `/api/exercises/*` sweep. |

The Android client is one layer further back: a genuinely good offline client with no usable
identity/sync path and no published release. So "P0 28/28 and P1 270/270 checked" is true but
misleading — the feature spec put almost everything a commercial learning product needs into
P3. **This plan is about closing the gap between the spec's MVP and a product that can be
trusted with users and money.**

**Explicitly out of scope for this plan** (do not treat the 1,497 unchecked P3 items as a
backlog to burn down): Social & Community (85), Admin & Management (65), Gamification (70),
AI/ML (50), Enterprise (60), CMS (50), Notification System (65), Data Pipeline/Warehouse (50),
Legal-P3 extras (55), **i18n (40) — pending §6.8, recommendation is deferral**, a "projects"
feature (CodeCrafters has one; we do not plan it — F6 must not claim it), and specialist input
modes (voice/switch/external-keyboard-Bluetooth/controller/stylus/multitouch) beyond the
explicit deferral in C8. They remain documented, unowned, and deliberately deferred.

**One narrow, explicitly ruled exception** (a carve-out written here, not only in a workstream):
- **Public proof-of-work only**: §8 items 8.1.10–8.1.17 (visibility, `/u/username` permalink, SEO,
  statistics, certificates, course list) are pulled into scope by G8, ruled positive 2026-11-26
  (§6.11). No social graph, following, feeds or messages.

**Learner email stays deferred**: §6.10 was ruled negative — I12 is killed and all §17 items
remain out of scope.

**GitHub Pages is also not a target of this plan.** No Pages URL exists, `courses/*/output` is
gitignored, and agents cannot push generated files. The backend-optional promise is verified
through a `file://` copy plus documented regeneration at publish time (EC8/E4).

### 0.2 Non-negotiables (company rules, binding on every work package)

1. **Never push to `origin`.** The founder pushes. No `--force-with-lease`, no "just verify CI".
2. **Commit only when told.** Standing permission for this body of work carries across it; each commit message is exactly two lines (subject + one detail line), no trailers, no AI attribution.
3. **Verify against the served artifact AND the running client**, not against source alone. Three local suites were green in the past while production was not; that cycle has already cost multiple days.
4. **Stack law:** web/backends stay Chemical; Android stays Kotlin/KMP. Do not propose a Chemical rewrite of the Android app.
5. **The frozen `applicationId` is `com.wakaztahir.learnpythonapp`**, hard-guarded in `app/build.gradle.kts`. Never rename it, including in credentials registration.
6. **All markup goes through `#html` / `#css` / `#js` macros.** No string-built HTML, ever.
7. **Never invent a byte, offset or spec claim.** Every course change goes through the verification corpus.
8. **Respect other people's work:** the Android repo has four pre-existing modified files (`CourseSummaryActivity.kt`, `LearningActivity.kt`, `CourseApi.kt`, `LogApi.kt`). Preserve them byte-for-byte unless their owner changes them.
9. **Emulator policy:** a visible window only; never headless. Explicit founder approval was given for the 2026-11-26 pass; ask again for a new device pass.
10. **Every task has a named owner** assigned at wave kickoff; record it in the wave-kickoff notes appended to this plan, and add an `- Owner:` line to any `Docs/decisions.md` entry that unblocks that work. Recording is a separate, checkable step — not an assumption.

### 0.3 Governing documents (read before executing a work package)

| Document | What it governs |
|---|---|
| `docs/course-mission.md` | The parsing→executable goal; course scope and verification standard. |
| `docs/learner-first-mandate.md` | ACTIVE. Overrides older teaching docs where they conflict. |
| `docs/features-complete.md` | Master checklist (P0–P3). Tick items in the same change that implements them. |
| `docs/implementation-gaps.md` | Known Chemical/component bugs; read before writing code. |
| `docs/deployment.md` | Current deployment reality; §6 lists what is *not* done. |
| `docs/native-lesson-contract.md` | Web↔Android typed lesson contract. |
| `docs/mobile-api.md` | `/units` + `/progress/sync` contract; note §"Blocked, not implemented" is stale (see §1.3). |
| `Android/Apps/underlayer-kmp/AGENTS.md` | Android build, guards, account bridge, telemetry. |
| Root `AGENTS.md` §7a | Git rules. |
| `Docs/profitability-plan.md` §Phase 2 | Course-pass decision (Paddle) and entitlement contract P2-01…P2-09. |
| `Docs/firebase-telemetry-plan.md` | W1-6 DONE (Android); W4-1 web GA4 streams TODO; Play Data Safety is a founder TODO. |

---

## 1. Evidence base — what was measured, and how fresh it is

Every number below was observed on **2026-11-26** against the running service, the file on
disk, or a direct competitor fetch. Nothing here is quoted from an old doc without saying so.

### 1.1 Live web service (measured with HTTP requests today)

| Probe | Result |
|---|---|
| `GET /api/health` | `200 {"status":"ok","version":"0.1.0"}` |
| `GET /api/courses` | `200`, 33 courses, 329 concepts; per-course concepts 4–24, mean 10.0 |
| `GET /courses/elf/lessons/bytes` | `200`, ~120 KiB (122,870 B); headers include CSP, HSTS (`max-age=31536000`), `nosniff`, `Referrer-Policy`, ETag, `no-cache` |
| `GET /api/courses/elf/lessons/bytes/native` | `200`, `schema_version:1`, 10 units / 20 typed blocks |
| `GET /api/courses/a64abi/lessons/a64-aapcs/native` | `200`, 6 units / 45 blocks — non-ELF lessons are dense, not thin |
| Graded exercise sweep (all 33 courses, every concept id in every module) | **60 total**: ELF 15, Mach-O 27, PE 18; **30 courses have zero**. `bytes` = 4; `elf-header`, `a64-aapcs`, `dwarf-intro`, `wasm-intro` = 0 |
| `POST /api/auth/from-account` with garbage token | **401**; `POST /api/no-such-endpoint` → **404** — the route **exists** in the deployed service |
| `GET /api/progress/sync` / `/api/auth/me` | 401 (route exists, protected) |
| `GET /privacy`, `GET /terms` | Both "Last updated: September 2026". `/privacy` has a cookies section but it is **stale** ("browser local storage to keep you signed in"; no HttpOnly cookie, no embedded account/Google auth); no Paddle/payment/refund text; generic export/delete text already exists |

### 1.2 Checklist and verification state (file measurements)

| Measure | Value |
|---|---|
| Feature checklist | P0 **28/28**, P1 **270/270**, P2 **214/234**, P3 **103/1600**; overall 615 checked / 1,517 unchecked |
| Sections entirely unstarted (P3) | Social 0/85, Admin 0/65, Notifications 0/65, Payment 0/60, Gamification 0/70, Certificates 0/50, i18n 0/40, CMS 0/50, Enterprise 0/60, AI/ML 0/50, Observability 0/60, Legal-P3 0/55, Performance 0/45, Data Pipeline/Warehouse 0/50, Accessibility 0/60, Security-P3 0/45 |
| Served-output checkers | journey 364/364 (329 lessons + 35 pages), theme 56/56, pager 35/35, helpful-dedupe 12/12 — all against a freshly built binary |
| Baseline caveat | The 9004 binary that produced 364/364 was compiled from a worktree containing another agent's uncommitted ELF quiz content edits (`docs/journey-accessibility-2026-11-26.md` §7). Re-run all four checkers against a **clean build of HEAD** and record the commit/digest before treating these numbers as baselines. |
| Known checker debt | the non-vacuity plant was repaired in commit `cb47c27` — re-verify it (A4), do not re-repair; CI workflow written but never run on a runner and with no compiler-provisioning step (A2); `@test` suite compiler-blocked since 2026-11-24 |
| Android | 109 unit tests / 0 failures; 329 lessons decoded from the real pack; 3-target compiles green; no WebView in 249 production Kotlin files; debug APK 44.31 MiB; version 1.0.3 / code 3; `keystore.jks` + `google-services.json` tracked |
| Lesson-count reconciliation | Governing docs say 469 lessons / ~3,000 units (`learner-first-mandate.md:35`, `journey-quality-pass` §"Deliberately not fixed"). The live API exposes **329 concepts**. Treat 329 as the execution baseline and have the owner confirm the 469 figure before C4/C5 targets are frozen. |

### 1.3 Document drift — treat these files as historical, not current

This is itself a work package (A1). The served build is ahead of several docs, and agents acting
on the docs will make wrong decisions. **Twelve rows, twelve distinct files: eleven drift rows
and one explicitly-not-drift row.** Row 3 is D1-owned (Wave 3); A1 owns all other doc rows.

| File | Says | Reality (measured) |
|---|---|---|
| `docs/deployment.md` §6 items 1 and 6 (2026-11-26) | "no Content-Security-Policy"; "non-vacuity plant is stale" | Live site sends a CSP (with `'unsafe-inline'`); the plant was repaired in commit `cb47c27` |
| `docs/plan.md` Status | "Phase 3 partial — 12 concepts; Phase 4 not started" | 33 courses / 329 concepts; journey shipped |
| `Android/.../core/.../WebCourseApi.kt:141-159` and `app/.../auth/AccountBridge.kt` | "`/api/auth/from-account` does not exist in the deployed service" | Route exists: POST → 401, unknown route → 404 |
| `Android/.../docs/underlayer-client-status.md` | "no emulator was launched" | `Docs/decisions.md` 2026-11-26 records a visible-emulator drive |
| `docs/competitors.md:150`, `:168` and `:28` | FSRS ✅ only for Underlayer (Gap Analysis and "Unique Position"); "8660 exercises across 83 languages" | Anki ships FSRS natively (docs.ankiweb.net/deck-options.html); Exercism now states 8,970 exercises / 85 languages |
| `Docs/profitability-plan.md:90` | "Freeze … Underlayer-Android client — no work until a paid path exists" | Superseded in practice by the 2026-11-24 and 2026-11-26 decisions; **needs a founder ruling** (§6.1) |
| `docs/features-complete.md` §12 | Accessibility section is 0/60 | Correct: §12 is a distinct set of 60 P3 items. The shipped a11y work lives in **P1 2.2.123–125 and is already ticked** — do not reclassify §12 as drift. |
| `docs/production-hardening-2026-11-26.md:211` and `:222-226` | "CSP — still deliberately absent"; "stale non-vacuity plant" | Live site sends a CSP; the plant was repaired in `cb47c27` |
| `Docs/profitability-plan.md:242` | "real paid content (ELF + HAT courses)" | HAT was removed 2026-11-24; update the premise of the course-pass phase |
| `Docs/action-plan.md:47` | LearnPythonBackend "is still the content source for `underlayer-kmp`" | Android `AGENTS.md`: the legacy Go backend is no longer the content source |
| `Web/underlayer/AGENTS.md:672` | "Sessions are bearer-token only, so the gated pages are unreachable from a browser" | Code now resolves an HttpOnly cookie (`web/src/handlers_auth.ch:89-94`, `set_session_cookie` at 194/257/354); correct the gotcha so agents do not stall on a false blocker |
| `docs/mobile-api.md:145-152` | "`POST /api/auth/exchange` needs a shared secret — explicitly deferred" | The deployed route is `POST /api/auth/from-account` and exists (POST → 401); rewrite §"Blocked, not implemented" to the measured state |

**Not drift:** `Android/.../docs/offline-pack.md` correctly says the **on-device pack** has an
exercise bank only for ELF. On disk, 32 of 33 `exercises.json` files are `[]`; only ELF's is
non-empty. The web has three banks. Both statements are true about different artefacts. The
offline-pack doc must be updated **in the same change as D4** when banks are regenerated.

### 1.4 Competitor facts (direct fetches 2026-11-26)

Web search was unavailable (HTTP 402 from the search integration), so these come from the
competitors' own sites, not a broad market scan. Record the date with any reuse.

| Competitor | Current capability | Implication for this plan |
|---|---|---|
| **Brilliant** | Rebuilt around **Koji**, a visual AI tutor: guiding questions, hints, mastery assessments, adaptive plan, homework help, personalised review. 100k+ five-star app reviews, 5,000+ schools, WASC accreditation. Breadth: math → CS → Python → AI. | "Adaptive review" and "AI tutor" are no longer white space. Underlayer must compete on **verified systems depth + a guided journey**, not on having AI or SRS. |
| **CodeCrafters** | 14 build-your-own challenges (Git, Grep, Redis, Shell, Kafka, SQLite, Firewall, Tokenizer, BitTorrent, DNS, HTTP Server, Interpreter, Claude Code, Inference Engine), git-based workflow, instant automated tests, membership/teams/lifetime plans. | Closest rival to "from scratch". `compback` already runs **machine-generated** code (`features-complete.md:2699`), but Underlayer has **no interactive learner-authored runner and no projects** — E1 must add the runner or F6 must concede the claim. |
| **Exercism** | 85 languages, **8,970 exercises**, free forever, human mentoring, CLI + browser editor, GitHub sync, ~20 localised UI languages. | Practice volume is two orders of magnitude larger. Our 60 exercises are the weak point. |
| **nand2tetris** | Free/open-source, taught at 400+ universities, complete hardware→software arc, Coursera certificate path. | Mission-shaped competitor with institutional trust and a certificate. Underlayer has more architectures and SRS, but no projects, no certificate, no adoption. |
| **Anki + FSRS** | FSRS is built in (optimiser, desired retention, workload simulator, presets, sync across desktop/web/Android). | Remove FSRS from the "unique" column; position it as **embedded** scheduling inside a guided curriculum. |

### 1.5 Verification limits of this plan

I did not rebuild either product, run the full test suites, or drive a browser/emulator myself.
The Android "no emulator" and "endpoint not deployed" claims come from docs that are now known
to be stale. Any work package that begins with "verify X" must actually do so before building
on it. Competitor facts are a dated snapshot; re-check before publishing a comparison (F6).

---

## 2. Definition of done — exit criteria for "production ready"

A product is production ready in this plan only when **all** rows are true. Targets are
deliberately measurable; "looks fine" is not an exit criterion. These are **EC1–EC16**; the
letters **D1–D9** are reserved for Android work packages in §3.

| # | Dimension | Exit criterion | Current state |
|---|---|---|---|
| EC1 | Deployable | A clean checkout builds; the pinned compiler image is recorded; a documented deploy + rollback drill was executed this month. | 🟡 manual deploy, no rollback drill |
| EC2 | Operable | Every request emits one structured log line + request id; 5xx and DB errors alert to a named owner with a runbook; `/api/health` is monitored. | ❌ 0/60 observability items |
| EC3 | Secure | Live CSP with no violations on ordinary flows; auth rate limits verified from an empty bucket; no signing material in the working tree or local HEAD after the founder's commit (the compromised historical key is recorded as such; purging shared refs is a founder-owned action, never an agent push); Play Data Safety filed. | 🟡 CSP live; signing key tracked in current tree |
| EC4 | Testable | CI job actually runs on a runner; a real suite (not only checkers) is green, or the checker-only position is a written, founder-accepted decision. | ❌ CI never run; `@test` compiler-blocked |
| EC5 | Scalable | SQLite concurrency documented as safe (FULLMUTEX or connection-per-thread) and load-tested; single-process ceiling explicitly accepted or remote backend exists. | ❌ one handle / 12 threads; remote backend refused |
| EC6 | Learning loop | All 329 lessons pass the journey checker; a live browser pass covers keyboard, theme, quiz feedback and one retrieval gate in each of the six course families (formats, linking, architecture-x86, architecture-ARM, architecture-RISC, compiler/VM). An exception requires an ad-hoc dated `Docs/decisions.md` entry with an `- Owner:` line (§0.2 rule 10) — a note alone is not coverage. | 🟡 364/364 served checks (mixed worktree); browser proof on one lesson |
| EC7 | Practice | Every concept has at least one graded action with a verified answer key, or an explicit, visible "reflection only" state. | ❌ 60 exercises / 329 concepts |
| EC8 | Backend-optional | Static output regenerated and journey-complete; a `file://` copy verified; regeneration at publish time documented. **GitHub Pages is not a target of this plan** — no Pages URL exists and generated output is gitignored; record as an accepted limitation (§6/§0.1), not as a gate. | ❌ output gitignored and stale |
| EC9 | Android identity | A real shared-account token exchanges into an Underlayer session end-to-end against deployed `account.wiqis.com`; progress marked synced only after a confirmed push. | 🟡 verified against a local account stub only (`Docs/decisions.md:4871`); not against the deployed service |
| EC10 | Android release | Signed release build from clean secrets; store listing refreshed; version 1.0.4 / code 4; device-tested on a visible emulator; legal pages and Data Safety current. | ❌ v1.0.3, no release, signing key in git |
| EC11 | Business | A named paid course exists (§6.3 ruling); course pass purchasable, entitlement enforced on web + Android; one certificate/shareable artifact shipped. | ❌ 0/60 payment, 0/50 certificate; no manifest marks any course paid; HAT removed |
| EC12 | Truth | The eleven drift rows in §1.3 are corrected (A1's doc rows in Wave 0, the D1-owned Kotlin row in Wave 3) and the one not-drift row is left intact; decisions recorded in `Docs/decisions.md` per §6/A7. | ❌ eleven known drift rows |
| EC13 | Competitive learner surface | Onboarding v2 with placement (G1), Today/daily plan (G2), FSRS controls (G3), energy/pacing/retry ladder (G4), four new graded types (G5), web PWA (G6), faceted discovery (G7) and Android Today/review (G11) are live and browser/device-verified. | ❌ none of G1–G7/G11 exists today |
| EC14 | Trust and maintainability surface | Public proof-of-work (G8), change log + feedback closure (G9), data-control panel (G10), structured authoring pipeline (G12) and safe local→account takeover (G13) are live and verified. | 🟡 profile shell + visibility toggle and the five data endpoints already exist; server-rendered proof, unified panel, changelog/feedback closure, authoring pipeline and takeover do not |
| EC15 | Production integrity | Single-instance deployment (H1), proxy-safe rate limiting (H2), uniform headers/CSP (H3), full CI gate corpus (H4), build provenance (H5), deployed-DB restore drill (H6), graceful shutdown (H7), secrets inventory (H8), embedded sign-in proof (H11) and byte-verification coverage (H12) are green with linked logs; **H9–H17 each have a linked green log or a dated, owner-signed exception**. | ❌ none of H1–H17 exists today |
| EC16 | Discovery, depth and support | Robots/sitemap/meta/canonical live and indexed (I1), hint route repaired (I2), explanations on every graded and in-page item (I3/I4), 33 learner specimen packs (I5), curriculum depth charter (I6), metadata contract (I7), signed-in page proof (I8), support channel (I11) and honest landing prerequisites/time (I14); **I9/I10/I11/I13/I14 are at least measured and dispositioned**; I12 is killed by ruling (§6.10). | ❌ none of I1–I14 exists today |

---

## 3. Work breakdown

Each package lists **goal → tasks → acceptance → dependencies**. IDs are stable; use them in
commit subjects and decision-log entries. Every task gets a named owner at wave kickoff (§0.2 rule 10).

### Workstream A — Truth, verification and CI

**Goal:** make the repo a trustworthy source of truth before any large feature work.

| ID | Task | Files / commands | Acceptance |
|---|---|---|---|
| A1 | Reconcile drifted docs with served behaviour (docs only — **not** the two Kotlin comment blocks, which D1 owns) | `docs/deployment.md` §6 items 1 and 6; `docs/plan.md` Status; `docs/mobile-api.md` §"Blocked"; `Android/.../docs/underlayer-client-status.md`; `docs/competitors.md:150`, `:168` **and** `:28`; `Web/underlayer/AGENTS.md:672`; `Docs/profitability-plan.md:90` **and** `:242`; `Docs/action-plan.md:47`; `docs/production-hardening-2026-11-26.md:211` **and** `:222-226`; **do not edit** `offline-pack.md`, `WebCourseApi.kt:141-159`, `AccountBridge.kt`, or `features-complete.md` §12 (all correct or owned by D1); live `/privacy`, `/terms` | Every doc row A1 owns states the measured fact and date; no claim contradicted by §1.1. The D1-owned Kotlin row stays marked "corrected in Wave 3". §1.3 accounting updated to eleven drift rows (ten corrected here) plus one not-drift row. |
| A2 | Make the CI job real | `.github/workflows/ci.yml`, `docs/deployment.md` | **Provision the compiler** (checkout/build/cache `TCCCompiler` from the Chemical source, or use a documented self-hosted runner that has it) — a stock `windows-latest` has no `CHEMICAL_ROOT` compiler. Build from a **clean checkout**, record compiler version/digest/pin location in `docs/deployment.md`; run the job on a runner, keep the green log, link it from `docs/deployment.md`. No deploy/publish step added. |
| A3 | **Hard gate:** unblock the `@test` suite | `tests/chemical.mod`, `AGENTS.md:674-676`, sibling repos read-only: `Web/timeline/tests/` + `scripts/test.sh`, `Web/123Mind` test setup, `Web/easytodo/tests/` + `scripts/test.sh` | `TCCCompiler tests/chemical.mod -o ../build/tests.exe --no-cache` builds and `tests.exe` runs green. First **analyse how Timeline and 123Mind (and easyToDo) wire their working Chemical test suites — read only, do not modify their code** — then apply the manifest/source-set pattern to Underlayer. Do not patch library test sources in those repos. Checker-only verification is explicitly rejected by the founder (§6.4, 2026-11-26). |
| A4 | Verify the repaired non-vacuity harness | `tools/checker_nonvacuity.py::check_theme` | The plant was already repaired (commit `cb47c27`, plants a no-op in `render_theme_boot_js`); re-run it against a seeded copy and confirm it fails `theme_check.py`. Re-scope from "repair" to "verify"; do not lease a new repair. |
| A5 | Make checkers first-class | `tools/journey_quality_check.py`, `theme_check.py`, `lesson_pager_check.py`, `helpful_dedupe_check.py` | Re-run all four against a **clean build of HEAD**, record commit/digest; then wire them into CI against a disposable DB; each has a documented negative case. Prior baselines: 364/364, 56/56, 35/35, 12/12 (see §1.2 caveat). |
| A6 | Add a served-behaviour contract probe for the account bridge | new `tools/bridge_probe.py` | Asserts `POST /api/auth/from-account` returns a non-404 for a bad token and 401 with no token; run against local and deployed URLs. Prevents the stale "endpoint does not exist" claim recurring. |
| A7 | Decision log housekeeping | `Docs/decisions.md` | **Satisfied for §6.1–§6.11** by the consolidated 2026-11-26 entry already appended ("Founder rulings for executing the Underlayer production-ready plan"), which includes the written paid-path proposal required by §6.1. Any later ruling gets its own entry with an `- Owner:` line. Never rewrite history. |
| A8 | Final truth sweep | this plan (§1.1, §1.3, §2 current-state column) | Re-run every §1.1 live probe and refresh §1.1, the §1.3 drift table and the "Current state" column of §2 after F0/E1/E2 ship; record the date and commit/digest. Assign an owner at Wave 5 kickoff. |

**Dependencies:** A3 blocked by the §6.4 ruling; A7 entries blocked by their respective §6 rulings.

### Workstream B — Platform and operations (web)

**Goal:** turn a running server into an operable service.

| ID | Task | Files / commands | Acceptance |
|---|---|---|---|
| B1 | Request logging + request id | `web/src/` response helpers, `app/main.ch` | One line per request: `method path status duration_ms learner_id request_id`; `X-Request-Id` echoed; 5xx and DB failures logged at error level; verified in Cloud Logging on a deployed revision; **named on-call owner recorded**. |
| B2 | Health alerting + web analytics | deploy config + `Docs/firebase-telemetry-plan.md` W4-1 | `/api/health` monitored with an alert to a named owner and an incident runbook at a recorded path; GA4 web streams for `underlayer.wiqis.com` added per W4-1 if the founder approves. |
| B3 | SQLite concurrency decision | `database/src/`, `repository/src/` | Either `SQLITE_OPEN_FULLMUTEX` documented + a 40-writer test recorded, or connection-per-thread implemented; load test repeated and result written into `docs/deployment.md` §6. |
| B4 | Remote-backend path (deferred by default) | `database/src/` | If chosen: `libsql://`/`https://` implemented with a conformance test; if not: FATAL refusal retained and documented as the single-process ceiling. Do not accept a URL that boots healthy and loses writes. |
| B5 | CSP externalisation plan | macro output + `docs/deployment.md` §6 item 1 | Inventory every inline script/style source; first externalised script (theme boot) shipped with a nonce or hash; CSP tightened one step with zero console violations in the browser drive. Full tightening is explicitly a follow-up. |
| B6 | Backup, retention and rollback drill | `docs/deployment.md` §4, `tools/backup_db.py` | Automated backup schedule + retention + named owner; a drill on a **copy**: deploy a revision, roll back to the previous binary + DB snapshot, verify `/api/health` + one account action; record date/digest/env in `Docs/decisions.md`. |
| B7 | Rate-limit/owner consolidation | `repository/src/schema_migrations.ch`, `web/src/rate_limit.ch` | One purge owner; both windows preserved; restart probe from `docs/production-hardening-2026-11-26.md` §4 repeated; **empty-bucket probe repeated**: 8 wrong logins → `401 ×8` then `429` with `Retry-After: 120` on the 9th (`docs/deployment.md` §5). |

**Dependencies:** A1, A2. **Blocked by:** founder decisions §6.2 (storage) for B3/B4 and §6.5 (CSP scope) for B5.

### Workstream C — Learning product (web)

**Goal:** close the gap between "document viewer with a quiz" and the mandated guided journey.

| ID | Task | Files / commands | Acceptance |
|---|---|---|---|
| C1 | Graded-bank authoring pipeline | `courses/<id>/`, `repository/src/exercises*`, `tools/` | A generator + verifier that produces ≥1 graded item per concept from that concept's own verified text, with answer keys checked by a second reader/checker. **Also re-validate the existing 60 graded items** (correctness, ambiguity, solvability, consistency per `AGENTS.md` AI constraints) and record corrections. Start with the 30 zero-bank courses; target the **329 live concepts** (reconcile against the 469 legacy figure first — §1.2). Same rule as the 126 ELF explanations (`docs/quiz-feedback-2026-11-26.md`). |
| C2 | Wire existing feedback APIs into UI | checklist 4.1.30, 4.2.19, 5.1.20 | Hints reachable from a quiz step; streak no longer hardcoded `0` (or removed as misleading); `/api/review/recommendations` and `/api/review/time-recommendation` have a visible consumer. |
| C3 | Wire analytics/adaptation into UI | checklist 6.2.16, 6.2.17 | Progress and analytics pages send the auth token; at least temporal, retention, dropoff and funnel endpoints are consumed; identity is unambiguous server-side. |
| C4 | Journey objective wording | `content/src/journey_shell.ch`, manifests, `tools/journey_quality_check.py` | "In this step you will be able to ___" for all **329 live concepts** (derive from `objective` text per unit, or author a short objective per concept). Current `elf/bytes` objective is `"Understanding bytes."` — fails the mandate. Extend `journey_quality_check.py` to assert the wording; the current checker only asserts an aim exists. |
| C5 | Takeaway/recall quality sweep | `content/src/journey_pedagogy.ch`, `journey_runtime.ch` | Zero takeaways ending in `?`, zero repeats of a recall question, zero whitespace artefacts before punctuation across the 329 concepts (reconcile legacy 469 first — §1.2); checker asserts all three. |
| C6 | Real browser + accessibility pass | Chrome CDP / browser-use, visible emulator | **All six** course families named in EC6 are driven with keyboard focus, theme persistence, quiz feedback and one retrieval gate. A note is not coverage; any exception requires an ad-hoc dated `Docs/decisions.md` entry with an `- Owner:` line (§0.2 rule 10, EC6). One real screen-reader session recorded or the gap explicitly accepted under the same rule; `:focus-visible` ring consistent (checklist 7.1.39). |
| C7 | Navigation and home polish | checklist 7.1.14, 7.1.24, 7.1.25, 7.1.40, 7.1.41 | One shared nav shell (seven hand-rolled landing navs merged); home shows "Continue learning" + due-review badge and an unread indicator for signed-in learners; signed-out dashboard shows a login prompt rather than demo data (verify against the current server-side gate); the 11 "Your space" pages share one collection shell. |
| C8 | Responsive/visualisation follow-ups | checklist 7.4.13, 7.5.4–7.5.11 | Responsive visualisations verified at 1280/420 px; custom shortcuts shipped or deferred with a written reason; specialist input (voice/switch/controller/stylus/multitouch) moved to "not planned" per §0.1. |
| C9 | Tick only newly shipped checklist items | `docs/features-complete.md` | Verify P1 a11y ticks 2.2.123–125 are present (they are); tick only items newly shipped in C1–C8 **plus the narrowly ruled §8 proof-of-work items from G8 (§6.11 positive)**; §17 items stay deferred (§6.10 negative). Refresh totals at the top of this plan. Do not reclassify §12. |

**Dependencies:** A1 (truth), A4/A5 (checkers), **I2 (hint route must be repaired before C2's hint proof)**. **No dependency on the course-#2 decision** — that blocks E1 only.

### Workstream D — Android client

**Goal:** make the client a real, released member of the workspace rather than an offline demo.

| ID | Task | Files / commands | Acceptance |
|---|---|---|---|
| D1 | Confirm bridge end-to-end | `app/.../auth/AccountBridge.kt`, `core/.../WebCourseApi.kt`, live `POST /api/auth/from-account` | A real shared-account token from deployed `account.wiqis.com` exchanges into an Underlayer session, `/api/auth/me` resolves, and one progress batch pushes via `/api/progress/sync`. Only then update the stale comments; never mark progress "synced" before a confirmed push. |
| D2 | Confirm account credentials for the frozen id | Google Cloud / account service config, `app/build.gradle.kts:18-24` | The OAuth client id and reCAPTCHA site key are **public identifiers** shipped as defaults in `app/build.gradle.kts`; env/Gradle properties still win. Confirm the release pair is correct for `com.wakaztahir.learnpythonapp`. Register a `.debug` pair **only if** the founder approves the separate Enterprise registration; otherwise record the documented KEY_MISMATCH rationale (debug defaults intentionally empty) and accept that emulator sign-in is unavailable. Never describe these identifiers as embedded secrets. |
| D3 | On-device lesson cache | `core/.../repository/CourseRepository.kt`, `database/` | A lesson fetched while online is written to disk with an explicit "cached copy" label and invalidation; cold open works offline; test covers a course published after pack generation. |
| D4 | Graded bank parity | offline pack generator + `docs/offline-pack.md` | Regenerate banks for the 33 bundled courses once C1 lands; preserve verified answer keys; deterministic test updated; update `offline-pack.md` in the **same change** (it was accurate before). |
| D5 | Journey parity with web | `core-ui/.../underlayer/`, `JourneyExercises.kt` | Verify the two issues flagged by `docs/journey-quality-pass-2026-11-26.md` §Android: takeaway derived from a fact sentence (not a question), recall from the just-finished unit's `remember`; add tests. |
| D6 | Release hygiene and signing | `app/build.gradle.kts`, `gradle.properties`, `keystore.jks`, `app/google-services.json`, store assets, legal pages | Generate a **new** release signing key — assume the committed key is compromised; store key + password in founder-controlled secret storage; **wire a `signingConfig` (or a documented external signing step) that reads keystore path, alias and both passwords from env/Gradle properties**; verify the release APK with `apksigner verify --verbose`; rehearse from a clean checkout. Run `git rm --cached keystore.jks`, delete the working copy, add `*.jks` to `.gitignore`, and append a decision that the old key remains in git history and must never sign a release. `google-services.json` **stays tracked** as public Firebase config — verify its `package_name` matches `com.wakaztahir.learnpythonapp`. Version 1.0.4 / code 4; store listing refreshed under the frozen id; changelog written; `/privacy` and `/terms` re-dated (F0). |
| D7 | Debt reduction (bounded) | inherited Sketchable modules | Inventory what is actually wired; remove only provably dead modules with a build-green check; do not do a drive-by rewrite. APK size target recorded before/after. |
| D8 | Device verification | `wiqis-verify` AVD, `adb input`, `uiautomator dump` | Visible-window run of: sign-in (if D1/D2 unblocked), journey start→retrieval→finish, airplane-mode bundled lesson, sync push/pull; screenshots + logcat retained. Ask for fresh founder approval. |
| D9 | Android telemetry verification | `Docs/firebase-telemetry-plan.md` W1-6 (Android) | Android funnel, perf and FCM are DONE in code — verify consent off stops automatic events and debug never collects, per `Android/AGENTS.md`. **Web GA4 streams (W4-1) belong to B2 only — D9 does not own them.** |

**Dependencies:** D1 needs a founder/owner action (D2). D3/D4 depend on web C1 and a regenerated pack. D6 depends on §6.1 ruling and F0.

### Workstream E — Content and mission

**Goal:** make the course collection actually deliver "parsing → executable", and make every course finishable.

| ID | Task | Files / commands | Acceptance |
|---|---|---|---|
| E1 | Course #2 that completes the chain | `courses/<new>/`, `docs/courses-todo.md` §Compilers | Ship a course that teaches lexing/parsing → small IR → emitter → object → linker (or an explicitly scoped first link), following the 7-phase handbook and the mission's verification standard. **Include an interactive, learner-authored runner: learner-produced source → compile → run → output verified against a real specimen.** Machine-generated code already runs in `compback` (`features-complete.md:2699`), so that alone does not satisfy this; otherwise §5's "build from scratch" claim must be formally conceded in F6. `courses-todo.md:878-887` has lexers, parser design, recursive descent, Pratt, LR, GLR, AST, type checking, type inference, semantic analysis all unchecked. |
| E2 | Restructure the outstanding sections | `docs/course-mission.md` §"Still outstanding", `docs/courses-todo.md` | `## Memory` folded into *The Memory Hierarchy*; `## Compilers` restructured into finishable courses; naming settled (`ARM64` vs `AArch64`). Founder ruling **§6.9** recorded by A7 in Wave 4. |
| E3 | Per-course exercise bank from verified text | `courses/*/`, `tools/` | Every concept has a bank; every answer key traceable to the lesson's own verified text; `tools/verify_*` harnesses extended with a "number has its own poison" check (mission §"A cross-check that has silently stopped"): each reported count gets a poison that must move it. |
| E4 | Static output pipeline | `scripts/build_static.sh`, `courses/*/output` | Regenerate all courses after journey changes; verify a **`file://` copy** shows the complete journey; document that output is gitignored and must be regenerated at publish time. GitHub Pages has no target and is out of scope (§0.1); do not claim it as verified. |
| E5 | Course quality revision cadence | `docs/course-development-handbook.md`, `Docs/decisions.md` | A per-course revision schedule ("improve forever" rule 5) with an owner and measurable review interval; first revision completed for ELF. |
| E6 | Author the §6.3-named paid course | `courses/<paid>/`, `docs/courses-todo.md` | The course named by the §6.3 ruling exists before F3/F4/F6: manifest marks it paid, its lessons pass the same verification and journey checkers as every other course, and a graded bank is generated via C1/E3. This is the owner of option (b)/(c); E1 alone only builds the mission course (a). |

**Dependencies:** C1 (shared bank tooling), founder ruling §6.3 for E1 and **E6**; E6 → F3/F4/F6.

### Workstream F — Business, legal and distribution

**Goal:** one paid path and one shareable artifact, without touching learning data semantics.

| ID | Task | Files / commands | Acceptance |
|---|---|---|---|
| F0 | Legal and store compliance | live `/privacy`, `/terms`, Play Console Data Safety | `/privacy` and `/terms` re-dated: **correct the stale cookie section** (local-storage-only → HttpOnly cookie), disclose embedded `account.wiqis.com`/Google auth, Paddle as merchant of record, what payment data is/isn't stored and the refund path; verify the existing generic export/delete text is accurate (do not merely "add" it); `/terms` covers purchases. Play Data Safety declaration filed for `com.wakaztahir.learnpythonapp`; named owner recorded. Must complete before D6 and F3. |
| F1 | Entitlement source of truth | `Web/account` `entitlements` collection | Fields `user_id`, `product`, `source`, `status`, `expires_at`, `receipt_ref` per `Docs/profitability-plan.md` P2-02; Underlayer reads only, never owns entitlements. |
| F2 | Paddle webhook + purchase page + pass management | `Web/account` + this repo | Paddle is the resolved provider (Pakistan payouts); signature verified, idempotent, retried; P2-T1…T5 tests pass (purchase, replay, forged signature, refund, expiry); **P2-07 course-pass management page** (active pass, expiry, restore) shipped in `account.wiqis.com`. |
| F3 | Course gating | `web/src/`, `app/main.ch` | **The paid course is named by the §6.3 ruling and exists before gating is enabled** (no manifest is currently marked paid; HAT was removed). Free course stays free; paid course returns 402 without entitlement; progress preserved when a course flips to paid (P2-06/P2-09). |
| F4 | Android entitlement read | `app/.../auth/` | A web purchase unlocks the **§6.3-named paid course** on Android under the frozen id; entitlement checked server-side, never a local boolean. |
| F5 | Certificate / shareable proof | new pages + `docs/features-complete.md` §20 | First certificate issued on course completion, verified against server-side progress, shareable URL; checklist 0/50 → first items ticked. |
| F6 | Acquisition surface | `wiqis.com` docs + `docs/` | One truthful public page per flagship course (free ELF + the §6.3-named paid course), with real screenshots; follow `wiqis-seo-content` rules; no claim of FSRS uniqueness; no claim of a learner-authored runner or projects unless E1/F6 actually shipped them; competitor facts re-checked before publishing (§1.5). |
| F7 | Public-status honesty | README + this plan | A short "current state" section on the repo README links this plan and the exit-criteria table, so an agent or visitor sees the real state in one click. |

**Dependencies:** F0 → F3 and D6; F1 → F2 → F3 → F4; **E6 (the §6.3-named paid course) plus the §6.3 ruling** gate F3/F4/F6; D1/D6 for F4; E1 for F5/F6; §6.1 ruling for the whole Android portion of F4.

### Workstream G — Competitive learner-experience gaps

**Goal:** close the product gaps that currently stop Underlayer competing with Brilliant,
CodeCrafters, Exercism, Anki and nand2tetris — features the app lacks and A–F do not build.
Nothing here ticks §8 Social/Admin/Gamification/CMS/i18n items; those stay in §0.1.

| ID | Task | Files / commands | Acceptance | Wave / priority |
|---|---|---|---|---|
| G1 | Onboarding v2: motive → prior knowledge → optional placement → start point | `web/src/pages_onboarding.ch`, new `web/src/handlers_onboarding_diagnostic.ch`, `repository/src/*`, `database/src/schema.ch`, `app/main.ch`, `docs/user-flows.md` | `/onboarding` has 7 steps: welcome, "Why are you here?", prior knowledge, session minutes, **skippable** 5–8 item diagnostic, "building your route", first lesson. Diagnostic items come from C1's verified banks; `POST /api/courses/:courseId/assess` scores; results stored as `goal`, `prior_knowledge`, `session_minutes`, `placement_score`, `onboarding_complete`. Skipping starts at ELF `bytes`. No signup wall. Served-HTML check of all 7 steps + fresh-account live probe. | 2 (steps) / 3 (scorer) — **P0** |
| G2 | Daily study plan generator ("Today") | new `web/src/handlers_today.ch`, `pages_today.ch`, extend `pages_study_plans.ch`, `handlers_goals.ch`, reuse `POST /api/study-plans` | Seeded DB with 6 due reviews + 15-minute goal → one click creates 3 reviews + 1 next lesson ≤15 minutes via the existing plan API. Completion records one activity day in `/api/streaks`; missing a day says "Welcome back" — never loss, badge or leaderboard. Live probe + 420 px keyboard drive. | 2 — P1 |
| G3 | FSRS params: make them persistent, then ship Settings controls (Anki parity) | `web/src/pages_settings.ch`, `web/src/handlers_settings.ch:78-144`, **new `repository/src/fsrs_params.ch`, `database/src/schema.ch`, `web/src/handlers_review.ch:379`, `learning/src/session.ch:17`** | The four endpoints currently **return/statelessly compute defaults** — optimize logs but never stores (`:104-111`), export returns `init_fsrs_params()` (`:125-128`), import parses and returns JSON without writing (`:144`), reset returns defaults (`:115-121`); scheduling consumers also use defaults (`handlers_review.ch:379`, `handlers_exercises.ch:177`, `session.ch:17`). First add a per-learner `fsrs_params` table + repository load/save, and make optimize/import/reset **write** it and all scheduling consumers **read** it. Then: "Expert · spaced repetition" section with desired retention 0.80–0.95, daily review cap, "Optimise from my history" (before/after params), Export JSON, Import Anki parameters. Changing 0.90→0.85 changes `/api/review/due` after re-login; bad import shows a visible error; export→import round-trips; optimise with too few reviews refuses honestly. UI alone does **not** satisfy EC13. | 2/3 — P1 (highest ROI) |
| G4 | Energy check-in, adaptive pacing and honest retry ladder | `content/src/journey_pacing.ch`, `web/src/handlers_review.ch`, `pages_review.ch`, `content/src/exercise_ui_js.ch`, `docs/features.md` §5 | Learner picks ready/okay/low-energy + duration; sent to `/api/review/start`, stored as `energy_before`/`energy_after`. At 80% of duration or 3 consecutive errors → "Take a break — progress saved"; resume restores the exact step. Retry ladder: conceptual hint → directional hint → reveal + "continue anyway" via `GET /api/exercises/hint`. No timer pressure, red verdicts or percentage scores. 420/1280 px browser drive with focus assertions. | 2 — P1 |
| G5 | Exercise-type expansion + specimen mini-labs | `learning/src/exercise_types/`, `repository/src/exercises*`, `content/src/exercise_ui_build.ch`, `exercise_ui_css.ch`, `exercise_ui_js.ch`, `courses/*/assets/samples/`, `tools/` | Add graded types `order_steps`, `byte_range`, `decode_field`, `output_match` plus one `specimen_lab` per six course families using existing sample files. Keys derived from verified text with a poison check; API reports new types; browser drive solves one of each. Not the compiler runner (E1). | 2 (types) / 4 (labs) — P1 |
| G6 | Installable web PWA: offline lesson/quiz + queued writes | new `app/manifest.webmanifest`, `content/src/service_worker.ch` or generated asset, `content/src/lesson_identity.ch`, nav offline state, `tools/` | After one online visit, Chrome CDP offline mode opens a visited lesson, completes its quiz and records progress locally; reconnect replays via `POST /api/progress/sync` with last-write-wins and no FSRS overwrite. Manifest validates; cache version/invalidation and "Download this course" documented. No Pages URL introduced. | 3, verify 5 — P1 |
| G7 | Faceted, paginated discovery + time-budget routing | `web/src/pages_search.ch`, `search_core.ch`, `search_scan.ch`, `courses_index_data.ch`, `handlers_learning_path.ch` | `/search?q=&course=&module=&difficulty=&minutes=&status=&page=` server-side, 25/page, no JS; all 110 `byte` hits reachable in ≤5 stable URLs; signed-in learners filter completed/review-due. "10 minutes / this week / deep dive" control on `/courses` and `/learning-path` maps to the existing 33-course route. | 3 — P2 |
| G8 | Server-rendered public proof-of-work (**subject to §6.11**; pulls §8 items 8.1.10–8.1.17 into scope) | `web/src/handlers_settings.ch:17-18` (existing `handle_profile_page`), `handlers_profiles.ch`, `pages_certificates.ch`, `pages_settings.ch` | The shell and visibility toggle already exist (`app/main.ch:784`, `features-complete.md:1689-1690`); the gap is data. `/u/<username>` renders server-side, no JS: courses completed, concepts mastered, minutes, issued certificates linking to `/certificates/:id`, honouring the existing visibility setting. All numbers server-side. The progress-share token already exists (`app/main.ch:945`, `handlers_data.ch:317`) — reuse it, do not build it. No social graph, following, feeds or messages. If §6.11 is negative, kill this package. | 4/5 — P2 |
| G9 | Course change log + closed feedback loop | new `tools/changelog_gen.py`, `courses/*/changelog.json`, `web/src/handlers_whats_new.ch`, `pages_whats_new.ch`, `content/src/course_landing.ch`, `lesson_feedback_js.ch` | On a disposable copy, a manifest version bump produces 3 changed-concept entries visible at `/whats-new` and in the course landing expander. A `fixed` feedback item appears to its own author with date + concept link; admin endpoints stay owner-scoped. | 5 — P2 |
| G10 | "Your data" panel in Settings | `web/src/pages_settings.ch`, existing endpoints `app/main.ch:911-939`, `/privacy` text from F0 | Signed-in learner downloads JSON (progress, FSRS, notes, profile), deletes a typed data category with confirmation, and deletes/deactivates the account with typed confirmation; last export date shown; post-delete login shows empty state. F0's `/privacy` describes the same steps in the same change. | 3/4 — P2 |
| G11 | Android Today + review session screens | new `core-ui/.../main/TodayScreen.kt`, `core-ui/.../review/ReviewSessionScreen.kt`, extend `MainScreenState.kt`, `MainDrawerContent.kt`, consume `/api/progress/sync` FSRS block + `/api/review/start\|submit\|end` | Visible-emulator drive: Today shows due count + next bundled lesson; due card → Again/Hard/Good/Easy → next → summary; airplane mode still opens a bundled lesson; "synced" only after confirmed push (D1 rule). Desktop target + no-WebView guard stay green. No streak/badge UI. | 3 under §6.1(b), else 4 — P1 |
| G12 | Structured authoring pipeline + preview/lint (not the CMS) | new `content/authoring/*.json`, `tools/author_generate.py`, `author_preview.py`, `author_lint.py`, `docs/course-development-handbook.md`, pilot in one course | A non-agent author edits one structured concept file and runs one generator to produce the existing `content/src/*.ch` shape; `author_lint.py` checks objective wording, takeaway length, no invented byte claims, answer-key traceability; `author_preview.py` serves the pilot lesson locally. Generated files pass `journey_quality_check.py` and the byte corpus. No admin UI or §24 CMS ticks. | 4, validate 5 — P2 |
| G13 | Safe local → account progress takeover | new `web/src/handlers_progress_takeover.ch`, `repository/src/progress_takeover.ch`, `content/src/lesson_identity.ch`, `pages_home.ch`, `docs/mobile-api.md` | `POST /api/progress/takeover` replays guest changes through the same per-key `updated_at` rule as `/api/progress/sync`, never writing FSRS-authoritative fields; one-shot token prevents replay. Guest completes 2 lessons offline then signs in → both appear in `/api/progress` with FSRS untouched; replay is a no-op; newer server state wins. One dismissible "keep this progress" prompt. `mobile-api.md` names takeover as the only supported import path. | 3/4 — P1 |

**Dependencies:** G1 ← A1, C1, C2, C7 (route ordering verified in A1; no E2 dependency); G2 ← C2, C3, C7, G1; G3 ← C2, C3 (plus its own repository/schema persistence work); G4 ← C1, C2, C3, G2, **I2**; G5 ← C1, E3, A5; G6 ← E4, C7, B5, A6, D1; G7 ← C7, C3; G8 ← F5, C3, F0; G9 ← E5, B7, C1; G10 ← F0, B7; G11 ← D1, D5, D9, C2, G2; G12 ← C1, C4, C5, E3, E5; G13 ← D1, A6, C7, G6.

### Workstream H — Production integrity, security and operations

**Goal:** make the deployed artifact, its data and its gates trustworthy — not merely the code.
Fences: no §10 Admin/CMS UI, no new auth system (§6.6), no CD/push, no remote DB (§6.2/B4).

| ID | Task | Files / commands | Acceptance | Wave / priority |
|---|---|---|---|---|
| H1 | Enforce single-instance deployment and prove data consistency | `docs/deployment.md`, Dockerfile, Cloud Run service config (founder console action recorded as a command) | Production set `max-instances=1` (and `min-instances>=1` if cold-start data loss is unacceptable), or a durable shared DB exists. Record setting + who applied it. Two-client probe (register/login on A, read `/api/auth/me` + `/api/progress` on B ×10) always sees the same row. Scaling to 2 instances is a documented FATAL config. EC5 true only with this log linked. | 1 — **P0** |
| H2 | Rate-limit key and trust boundary behind the deployed proxy | `web/src/rate_limit.ch`, `web/src/responses.ch`, `docs/deployment.md`, new `tools/rate_limit_deployed_probe.py` | Log `remote`; key by authenticated learner id plus a proxy-derived address from a guaranteed hop, or use an edge limiter. Deployed probe from 2 networks: 8 wrong logins from A → 429 for A while B still gets `401 ×8` and a correct login succeeds. Document XFF decision + bypass analysis; add probe to CI/nightly. | 1 — **P0** |
| H3 | Uniform security headers + violation-free CSP source list | `app/main.ch:1612-1648`, `web/src/responses.ch:17-49`, `web/src/security_headers.ch`, new `tools/security_header_coverage.py` | (a) Apply `apply_security_headers` to `web::serve_request` incl. 404 — live re-probe of `/help`, `/faq`, `/about`, `/shortcuts`, `/privacy`, `/terms`, a 404: header set identical to `/api/health`. (b) Add exactly the origins served HTML needs (Google Fonts if retained) or remove the external font link — record which; CDP drive of 5 pages with zero CSP violations and the intended font loaded. (c) Checker with a negative plant, wired into CI. Does not externalise inline scripts (B5). | 1 — **P0** |
| H4 | Full regression corpus in CI | `.github/workflows/ci.yml`, `tools/{security_check,route_check,integration_check,checker_nonvacuity,check_inline_string_temporaries,sqli_scan,bracecheck,html_balance,check_quotes,js_escape_check}.py`, `docs/deployment.md` | Static/semantic gates run per push with negative cases; live gates on disposable DB: `security_check` 44/44, `route_check` re-run with the **route count recorded from the current binary** (the old "180 routes" is a 2026-10 baseline; source now has ~187 `srv.router.add` calls), 0 5xx / 0 leaks / 0 bleeds / 0 aborts, `integration_check` 105/105, all non-vacuity plants detected. Heavy gates may be nightly with linked logs. Inventory table in `docs/deployment.md` with owner per exclusion. A planted inline string temporary and unescaped SQL interpolation each fail CI. | 1 — **P0** |
| H5 | Deployed build provenance | generated `core/src/build_info.ch`, `app/main.ch` health route, new `tools/release_probe.py`, `docs/deployment.md` | `/api/health` returns `commit`, `compiler_version`, `build_mode`, `built_at`. Probe fails when mode != release or compiler differs from pin. Record current deployed values as rollback baseline. EC1's rollback drill references a digest from the wire. | 1/2 — P1 |
| H6 | Durability + point-in-time recovery of the deployed DB | `docs/deployment.md`, `tools/backup_db.py`, H5 probe, Cloud Run volume/snapshot config recorded | Record where the production DB physically lives and that it persists across a revision swap (throwaway learner before/after redeploy). Snapshot cadence + 30-day retention + named owner. Restore into **staging**, verify health/account/progress row, log date/digest/RPO/RTO. | 1/2 — P1 (P0 if H1 finds no durable volume) |
| H7 | Graceful shutdown + request timeout contract | `app/main.ch:125-130,1649-1659`, upstream server library (record as dependency, do not patch), `docs/deployment.md` | Determine SIGTERM/drain support; if absent add stop-accept → wait ≤30 s → close DB → log "shutdown complete". Configure read/write/idle timeouts + worker count. Kill test during in-flight login and sync POST: no DB-locked errors, clean 503 or completion, shutdown line logged. | 1/2 — P1 |
| H8 | Secrets inventory, environment separation + rotation | new `docs/secrets.md`, `Dockerfile:17-20`, `.gitignore`, deploy notes | Table: secret, purpose, dev/staging/prod source, owner, rotation interval, last rotation. Replace plain build `ARG` with BuildKit secret mount (or document why it cannot leak); `docker history`/image scan clean. Staging service with separate DB/account config; rotate one staging secret end-to-end. No secret literal tracked. | 1/3 — P1 |
| H9 | Operator identity for feedback triage + content publication | `web/src/handlers_feedback_admin.ch`, `handlers_content_authoring.ch`, `session_guard.ch`, new `tools/feedback_triage.py`, `docs/deployment.md` | Env-configured operator allow-list checked server-side on the four feedback routes + `exercises/import`; never a `role` column on learners. Every operator action writes `audit_log` with request id/actor. Triage one real report on disposable DB; it appears to its author through G9. Normal learner still 403; no cross-learner reads. No Admin/CMS checklist ticks. | 4/5 — P1 |
| H10 | Web error reporting + consent-aware event contract | new `web/src/client_telemetry.ch`, `handlers_telemetry.ch`, `repository/src/client_errors.ch`, `pages_settings.ch`, `Docs/firebase-telemetry-plan.md` W4-1 | `window.onerror` + `unhandledrejection` → `POST /api/telemetry/client` (rate-limited, no PII, stores type/file/line/request id). Consent-gated GA4 events with Android's names; opt-out stops both. Injected client error appears with request id; 7-day funnel query returns counts or honest empty state. Privacy copy updated with F0. | 2/3 — P1 |
| H11 | Embedded sign-in end-to-end proof on `underlayer.wiqis.com` | `content/src/embedded_auth.ch`, `web/src/pages_auth_embedded.ch`, new `tools/auth_shape_check.py`, browser evidence file | Link-shape check (local `/sign-in` opener, zero `href="https://account.`); password, **passkey ceremony**, Google popup + MFA all complete inside the dialog; Safari human check recorded or gap accepted with owner. Screenshots/console log; link-shape assertion in CI. | 3/5 — P1 |
| H12 | Verification coverage map + gate for all 33 courses | new `docs/verification-coverage.md`, `tools/verify_<course>.py` for uncovered courses, `.github/workflows/ci.yml` | Matrix 33 courses × (byte verifier, specimen asset, spec source, last verified, poison). Add verifiers for `coff`, `dwarf`, `elf`, `jvm`, `macho`, `obj`, `pe`, `sym`, `wasm` from existing samples **except `elf` and `pe`, whose specimen bundles I5 supplies** (`courses/elf/assets` and `courses/pe/assets` do not exist today) — no new byte claim without the existing corpus. Wave 2 covers the 31 courses with samples; Wave 4 reaches 33/33 after I5. All run in CI (nightly OK); each count has a poison that moves it. Content files change only if a real defect is found. | 2/4 — P1 |
| H13 | Stable concept identity + forward-only content migration | `courses/*/manifest.json`, `repository/src/schema.ch`, new `repository/src/concept_aliases.ch`, `courses.ch`, new `tools/concept_migration_check.py` | Manifests carry stable `concept_uid` + semver; alias table maps retired ids. On load, migrate `concept_states`, `review_items`, `concept_unit_progress`, `exercise_attempts` forward-only preserving FSRS; refuse deletion while live state references it until aliased. Checker simulates rename and 1→2 split: zero orphan rows, unchanged FSRS params. | 4 — P1 |
| H14 | Remove test-only + anonymous-write surfaces from production | `app/main.ch:138-148`, `tools/security_check.py`, `route_check.py`, `web/src/*` demo fallbacks | Gate/remove `POST /api/learners` outside debug (404/403 in release); CI asserts unreachable. Classify the 86 anonymous-200 routes; every persistent write either requires a session or has a documented approved behaviour + owner. 0 cross-learner bleeds. G13's guest takeover untouched. | 1/2 — P1 |
| H15 | Web performance budget gate | new `tools/perf_budget_check.py`, `.github/workflows/ci.yml`, `docs/deployment.md` | CDP drive 6 page archetypes at 1280/420 px throttled: transferred bytes, TTFB, LCP, INP, CLS. CWV-aligned budgets (p95 LCP <2.5 s, INP <200 ms, CLS <0.1, transfer <500 KB); record why older <500 ms LCP is revised. No render-blocking third-party stylesheet. Results in CI + docs. | 3/5 — P2 |
| H16 | Retention sweep + orphan cleanup | new `repository/src/retention.ch`, `schema.ch`, `tools/retention_check.py`, `docs/deployment.md` | Bounded startup/nightly sweep of orphans, expired reset/verification tokens and sessions, aged login/audit rows; dry-run + counts. Checker asserts zero orphans on disposable DB and refuses production. Founder rules on the 152 historical orphan rows before any production cleanup. | 4/5 — P2 |
| H17 | Staged rollout + kill switches | `docs/deployment.md`, `core/src/config.ch`, `app/main.ch`, Android Play internal-track steps (founder-owned) | Rollback target from H5; **Android internal-track → production steps apply under §6.1(b) only — under (a)/(c) they are documented but not executed** (freeze rule: no launch, no growth work); 24 h crash-free/ANR gate. Two env flags (`paid_gating_enabled`, `learner_surface_v2`) default off at route/UI entry points. Rehearsed flag flip on staging changes behaviour with no rebuild; owner + date recorded. | 4/5 — P2 |

**Dependencies:** H1 ← A2, B6; H2 ← B1, B7, H1; H3 ← A2, A5; H4 ← A2, A5, A3; H5 ← A2, B1; H6 ← B6, H1, H5; H7 ← B1, B3, H1; H8 ← A2, D6 (Paddle secret is inventoried as planned with an owner; F2 need not have shipped); H9 ← G9, G12, B1; H10 ← B1, B2, C3, D9, F0; H11 ← B5, D1, G1; H12 ← A5, E3, H4, **I5 for ELF/PE samples** (Wave 2 verifies 31 courses; Wave 4 reaches 33/33 after I5); H13 ← E5, G9, C1; H14 ← A2/A3, H4; H15 ← H3, H4, A5; H16 ← B7, G10, H6; H17 ← H5, D6, F3, G1–G4, H10.

### Workstream I — Shallow shipped features, course depth, distribution and support

**Goal:** make what is already shipped genuinely good, make "all courses" an honest statement,
and give a zero-budget product a discovery and support surface. Fences: no Social/Gamification/
i18n/CMS/in-app notifications/AI/Enterprise/projects (§0.1); **I12 is killed by the §6.10 ruling — no email work**; I13 creates navigation links only, never moves learning data (§6.6).

| ID | Task | Files / commands | Acceptance | Wave / priority |
|---|---|---|---|---|
| I1 | Organic discovery infrastructure on `underlayer.wiqis.com` | new `web/src/handlers_seo.ch`, head injection in pages via `HtmlPage`, `app/main.ch`, `docs/deployment.md`, new `tools/seo_surface_check.py` | `GET /robots.txt` 200 with `Sitemap:`; `/sitemap.xml` 200 generated from 33 course landings + 329 concept URLs + 6 guide/legal pages with `<lastmod>` from version/changelog; `/favicon.ico` 200. Every served lesson, course landing, `/courses`, `/search`, `/learning-path`, guide page has one non-empty title, 140–158-char description, canonical with public host, og tags, `Course`+`BreadcrumbList` JSON-LD; no `aggregateRating`. Checker crawls the generator's own URL list — 33 course landings + 329 concept URLs + 6 guide/legal pages + `/` = **369**, plus `/courses`, `/search`, `/learning-path` = 372 — rather than a hardcoded number, with a negative plant. Search Console baseline + named owner in `Docs/seo-content-status.md`. | 1 build / 2 verify — **P0** |
| I2 | Repair the shadowed `/api/exercises/hint` route + route-order gate | `app/main.ch:613,665`, `web/src/handlers_exercises.ch:283-315`, `tools/route_check.py`, new `tools/literal_route_shadow_check.py` | Literal routes precede parameterised ones on the same method (or router prefers exact matches). Live `GET /api/exercises/hint?exercise_id=elf_bytes_0&level=1..3` returns lesson-sourced hints, unknown id → clear 404, never `{"concept_id":"hint"}`. New checker enumerates literal routes and fails a planted shadow; wired into H4's CI corpus. C2/G4 browser drives re-run after the fix. | 2 — **P0** |
| I3 | Explanation-bearing graded feedback | `models/`, `repository/src/exercises*`, `web/src/handlers_exercises.ch:123-136`, `content/src/exercise_ui_js.ch`, `tools/` | `/api/exercises/submit` returns `explanation` + `why_wrong`, each derived from that concept's verified text with the C1/E3 poison check; zero untraceable byte/offset/spec claims. UI shows explanations for right and wrong in the mandate's calm tone. Checker asserts 100% of graded items across all six families have non-empty traceable explanations with a negative plant. | 3 — P1 |
| I4 | In-lesson quiz/explanation parity across six course families | `courses/*/src/*.ch`, `content/src/journey_actions.ch`, `web/src/lesson_header.ch`, new `tools/quiz_parity_check.py` | Every one of the 329 served lessons has ≥1 in-page graded choice with non-empty per-option `data-explain` written from that lesson's own text; families with zero today (`architecture-x86/ARM/RISC`, `compiler/VM`, linking/neutral) are fixed. Checker has a negative plant; EC6's browser drive adds one wrong + one right explanation per family. No prose/byte rewrite. | 3 — P1 |
| I5 | Learner-accessible specimen packs + named toolchain | `courses/*/assets/samples/`, `courses/*/manifest.json`, `web/src/handlers_lessons.ch`, `content/src/course_landing.ch`, `scripts/build_static.sh`, new `tools/specimen_link_check.py` | 33 downloadable specimen bundles (create missing `elf/` and `pe/` sets from verified real files) with SHA-256, exact gcc/clang/readelf versions, verification date and "what was not checked". Every course landing and all 329 lessons link to their bundle; `file://` links stay relative. Checker asserts 33/33, checksum match, served link + toolchain label. H12's verifiers consume the same bundles. | 4 — P1 |
| I6 | Curriculum depth charter for all 33 courses | new `docs/curriculum-coverage.md`, `courses/*/manifest.json`, `docs/courses-todo.md`, `Docs/decisions.md` | 33-row matrix: planned vs shipped concepts vs deferred topics with reason and owner/date — explicitly the 119→72 linking and 104→43 neutral-architecture deltas. Every course states its place in the chain and assumptions; zero blank cells. Charter drives E1/E2/E5/H12; each accepted shortfall gets a dated decision entry with `- Owner:`. No new course text authored here. | 4 — P1 |
| I7 | Single course metadata contract, served and displayed | `courses/*/manifest.json`, `repository/src/courses.ch`, `web/src/handlers_courses.ch`, `course_landing.ch`, new `tools/manifest_schema_check.py`, `Docs/decisions.md` | All 33 manifests migrate to one schema: `author`, `license`, semver `version`, `toolchain`, `spec_source`, `last_verified`, `limitations`. Apply the §6.7 ruling uniformly (normalise the two CC BY-SA rows and the `Waqas Tahir` row — no silent relicensing). API exposes the same fields; landings display licence/date/limits. Checker fails schema drift, licence/author mismatch, non-semver, missing toolchain, with a negative plant. | 4 — P1 |
| I8 | Signed-in "Your space" end-to-end proof | `web/src/pages_gate.ch`, 11 account handlers, new `tools/account_surface_check.py`, browser evidence | Using a disposable shadow learner via the deployed bridge, drive all 11 gated pages (dashboard, review, progress, notes, bookmarks, study-plans, streaks, achievements, notifications, certificates, analytics) with seeded data: real data, no demo zeros, no raw token errors, keyboard focus reaches every control, no 420 px overflow, one create/edit/delete round trip per mutating page. Screenshots + request log retained; undrivable pages get a dated `- Owner:` exception. | 3 — P1 |
| I9 | Anonymous demo-data honesty + dev-showcase gating | `web/src/handlers_analytics*.ch`, `handlers_streaks.ch`, `handlers_progress*.ch`, `app/main.ch` (`/components`), new `tools/anonymous_surface_check.py` | Every anonymous endpoint returning learner-shaped values either 401 or carries `"demo": true` plus an explicit "Sign in to see your data" UI; no page presents demo numbers as the learner's own. `/components` gated behind a debug flag (404/302 in release). Checker enumerates anonymous-200 endpoints with a planted unmarked payload. F0's `/privacy` matches final behaviour. | 2/3 — P2 |
| I10 | Search API contract clarity (non-breaking) | `.agents/skills/api_reference/SKILL.md`, `docs/mobile-api.md`, `web/src/handlers_search.ch`, `app/main.ch` (header only), new `tools/search_consumer_check.py` | Keep the frozen `/api/search` payload unchanged; add `Link: </api/search/concepts?q=…>; rel="alternate"`, document both endpoints with live examples, mark `/api/search` course-title-only/deprecated-without-removal. Checker fails if any shipped concept-search consumer calls `/api/search`; asserts the measured totals differ. | 3 — P2 |
| I11 | Public support and contact channel | new `web/src/pages_support.ch`, `app/main.ch`, nav + all page footers, `web/src/pages_legal.ch`, `docs/deployment.md` | `/support` 200, server-rendered: supported channels, named owner, published response-time target, `mailto:support@wiqis.com`; every public page footer and the Android Help & Support dialog link to it; F0's `/privacy` names the same channel. Operator rota from H9's allow-list when available; a named owner is recorded regardless. Checker asserts exactly one support link per served page and no 420 px overflow. | 3 — P1 |
| I12 | **KILLED by founder ruling §6.10 (2026-11-26)** — consent-based learner email loop | — | No work. All §17 items stay deferred. The change log (G9) is reachable only by visiting the site. Do not implement, do not tick §17 checklist items. | — |
| I13 | Workspace cross-links (links only, no data migration) | lesson footer + `content/src/journey_shell.ch`, Timeline share target, `Web/timeline`, 123Mind node action, attribution log | "Save to Timeline" from a lesson takeaway and open a linked concept from a Timeline note / 123Mind node; every link carries UTM/install-referrer and states origin product. No learning-data copy, entitlement coupling or new login. Two round trips verified on deployed hosts with attribution; each cross-repo change has its own owner under the two-subagent batch limit. | 5 — P2 |
| I14 | Course-landing prerequisite and time transparency | `content/src/course_landing.ch`, `web/src/handlers_courses.ch`, `pages_courses.ch`, `journey_shell.ch`, new `tools/course_landing_contract.py` | Every landing renders declared dependencies with `min_mastery_pct`, a "read these first" path, total minutes computed from concept estimates, and an honest state when enrolment is gated but UI cannot show it. Replace template time values (PE's uniform 15 min etc.) with per-concept estimates from unit count or measurement; `last_verified` shown (I7). Checker asserts API↔landing parity for 33/33 and flags uniform minute distributions, with a negative plant. | 3 — P2 |

**Dependencies:** I1 ← A1, B2, H3; I2 ← A5, H4 (blocks C2/G4 — **sequence I2 before the C2/G4 browser proof in Wave 2**); I3 ← C1, C2, G4, E3, A5; I4 ← A5, C1, E3, C6, E5; I5 ← H12, E3, E4, E5, E2; I6 ← A1, E1, E2, E5, H12, §6.9; I7 ← A1, §6.7, H12, E5, I6; I8 ← H11, D1, C7, G10, B1 (no H9 dependency — page proof does not require operator triage); I9 ← H14, C7, F0; I10 ← G7, A1, C7; I11 ← F0, G9, C7 (operator rota from H9 when available; a named owner is recorded regardless); I12 ← G9, F0, H11/D1, G10, `manage` owner; I13 ← F6, G8, D1, §6.6; I14 ← C7, G7, A1 (no E2/I7 dependency — show whatever prerequisite and time metadata the manifest already carries; I7 improves it later).

---

## 4. Sequenced roadmap

Effort is in founder-days (one agent, not calendar time). Work packages can run in parallel up
to the documented batch limit of two subagents with disjoint file ownership.

| Wave | Timing | Packages | Exit gate |
|---|---|---|---|
| **Wave 0 — Truth reset** | Days 1–5 | A1–A7 | Every doc drift row A1 owns matches the served build; the D1-owned Kotlin row is explicitly deferred to D1 (Wave 3); CI green on a runner; **§6.1 (freeze) and §6.4 (verification policy) rulings in the decision log**. **Do not start feature work before this gate.** |
| **Wave 1 — Operable web** | Weeks 1–3 | B1–B7, **H1–H4, H5/H6/H7 start, I1 build** | EC1, EC2, EC4, EC5 true; CSP step shipped after §6.5; storage decision documented. H1 (single instance), H2 (proxy rate-limit key), H3 (header/CSP coverage), H4 (full CI corpus) are P0 and must be green. I1's sitemap/metadata infrastructure is built here and verified in Wave 2. EC3 still deferred (F0 Wave 2, signing Wave 3, H3 partially covers headers). |
| **Wave 2 — Learning loop** | Weeks 3–7 | C1–C9, E3, **E4, E5**, F0, **G1 (steps 1–4/6), G2, G4, G5 (types), G9**, **H5–H7 finish, H10, H12 start (31 courses), H14**, **I1 verify, I2, I9** | EC6–EC8 true; 329 concepts have a graded action or honest reflection state; static output verified; legal surface updated; browser drive passes; checklist refreshed. E3 sequenced **after** C1 with one shared owner. Onboarding shell, Today and pacing ship here; G1's diagnostic scorer follows in Wave 3. Build provenance, DB durability, shutdown, web telemetry, verification coverage, anonymous-write audit, SEO verification, the shadowed hint fix and demo-data honesty land here. |
| **Wave 3 — Client + release** | Weeks 6–10 | D1–D9 (under option (b)), **G1 (scorer), G3, G6, G7, G10, G11, G13**, **H8, H11, H12 finish, H15 start**, **I3, I4, I8, I10, I11, I14** | EC9, EC10 **and EC3** true; a signed release installed and driven on a visible emulator; sync demonstrated end to end; Data Safety filed. Plus: FSRS controls, PWA, faceted search, data panel, Android Today/review, safe takeover, secrets inventory, embedded sign-in proof, 33/33 verification coverage, explained graded/in-page feedback, signed-in page proof, support channel and honest landing pages. Under options (a)/(c) this gate becomes EC9 only and D6/D8/D9 move to Wave 4 (§6.1). |
| **Wave 4 — Mission course + money** | Weeks 8–14 | **E6**, E1, E2, F1–**F5** (+ D6/D8/D9 only under options (a)/(c)), **G5 (labs), G8, G12, G11/G13 if deferred**, **H9, H12 finish (33/33 after I5), H13, H16, H17 start**, **I5, I6, I7** | EC11 true; the §6.3-named paid course exists (E6); course-pass purchase end to end on web and Android; certificate shipped; public proof-of-work and authoring pilot in place. Operator identity, content migration, retention, rollout flags, specimen packs, curriculum depth charter and the metadata contract land here. |
| **Wave 5 — Surface** | Weeks 14–18 | F6, F7, **A8, G12 validation**, **H15 finish, H16/H17 finish**, **I13** | Public pages live; revision cadence adopted with a visible change log; workspace cross-links live; **EC12–EC16 true** after A8's final drift sweep and the competitive/integrity/discovery verification. I12 is killed — no email work. |

**Illustrative dependency graph (not a blocking schedule — §3 dependency lines are
authoritative):** `A1 → A2 → A4/A5 → C1 → E3`; `A1 → A6 → D2 → D1 → D6`; `F0 → D6/F3`;
`§6.3 + paid course → F3/F4/F6`; `F1 → F2 → F3 → F4`; `E1 → F5/F6`. The §6.1 Android-freeze
gate precedes D1. The last cross-client dependency is F4. **F5 runs inside Wave 4 in parallel;
F6–F7 run after Wave 4.** Within Wave 2, C1 and E3 share a single owner and are sequenced
C1 → E3 (both edit `courses/*/` and `tools/`, so they cannot be split across two subagents under
the batch rule above). **Intra-wave ordering is also binding:** in Wave 2, I2 precedes the C2/G4
browser proof; E5 and G9 ship early in Wave 2 because H9/H13/I3–I7/I11 depend on them. Same-wave
dependencies (I12←G9, I13←F6, G8←F5, H13←E5/G9) are checkable within their wave.

---

## 5. Competitor-driven requirements map

| Competitor capability | Why it matters | Underlayer response | Package | Priority |
|---|---|---|---|---|
| Brilliant Koji / adaptive review | AI tutoring and personalised review are now table stakes in "interactive learning" | Do **not** build a chatbot. Ship the existing FSRS/recommendation endpoints into the UI and keep the journey calm; compete on verified depth, not on AI. | C2, C3 | P1 |
| CodeCrafters build-your-own + instant tests | Owns "build real systems from scratch"; our mission promises exactly that | Add graded, verifiable actions per concept now; add an **interactive learner-authored runner** in course #2 (`compback` already runs machine-generated code). Without it, F6 must concede the claim. | C1, E1, F6 | P1 (strategic; E1 is Wave 4 because it needs a founder ruling and a new course pipeline, not because it is unimportant) |
| Exercism 8,970 exercises / mentoring | Practice volume and human feedback | Generative bank from verified lesson text; no mentoring (out of scope); be honest about scale. | C1, E3 | P1 |
| nand2tetris free + certificate + universities | Free, complete arc, institutional trust | Course #2 completes the chain; certificate (F5) is the first trust artifact; no university channel planned. | E1, F5 | P1 |
| Anki FSRS built in | FSRS is not a differentiator | Reposition as "FSRS embedded in a guided curriculum"; remove the false row from `competitors.md`; keep cross-device sync as the real advantage. | A1, D1 | P1 |
| Paddle / membership pricing (CodeCrafters, Brilliant) | A product needs a checkout | Course pass per resolved Paddle decision; 26 passes/month ≈ $1,000/month target from `profitability-plan`. | F0–F4 | P1 |
| Brilliant adaptive plan / personal tutor; roadmap.sh "what next" | A newcomer must be put on the right first step or the 33-course catalogue is unnavigable | Onboarding v2 with placement (G1), Today/daily plan (G2), energy-aware pacing (G4), faceted discovery (G7). | G1, G2, G4, G7 | P0/P1 |
| Anki FSRS controls + offline + mobile review | The retention product category's baseline is optimiser, retention, simulator, cross-device review | Wire the four existing FSRS endpoints (G3), web PWA (G6), Android Today/review (G11), safe progress takeover (G13). | G3, G6, G11, G13 | P1 |
| Exercism practice volume / nand2tetris public proof | Practice *kind* and a visible body of work, not just one certificate | Four new graded types + specimen labs (G5), public proof-of-work (G8), change log + feedback closure (G9), structured authoring (G12). | G5, G8, G9, G12 | P1/P2 |
| Localisation (Exercism ~20 languages) | Low-cost reach when zero marketing budget exists | **Pending founder ruling §6.8 (recommended: defer until a paid path exists).** | §6.8 | P3 |

---

## 6. Decisions required from the founder

These are recorded in `Docs/decisions.md` only after the founder rules. Do not pre-empt them.

### 6.1 Android freeze conflict — blocks Wave 3
`Docs/profitability-plan.md:90` says freeze the Underlayer Android client until a paid path
exists; the 2026-11-24 and 2026-11-26 decisions made it a real client and authorised device
verification. **Choose:** (a) keep the freeze and limit Android to crash/policy fixes until F1–F4
ship; (b) lift the freeze and fund D1–D9 now; (c) lift it only for D1/D2 (identity) and defer
release work. Recommendation: **(b)** — the client is already built; the marginal cost is a
release, and the frozen listing has 5+ installs with effectively no revenue
    (`Docs/profitability-plan.md:243`), so it cannot cannibalise revenue. The *historical*
    LearnPython app reached zero users (`Android/.../AGENTS.md:45`) — that is a different
    baseline from today's 5+ installs. **However, `Docs/profitability-plan.md:99` requires exit
    from freeze to include a written paid-path proposal in `Docs/decisions.md`.** A **written
    proposal** (course pass, F1–F5) satisfies that condition; the code need not ship first, so
    option **(b)** proceeds on the ruling. If the founder instead picks (a) or (c), move
    D6/D8/D9 into Wave 4 after F1–F4, change the Wave 3 gate to EC9 only, and move EC3/EC10 to
    the Wave 4 gate. D6 depends only on the §6.1 ruling plus F0 — never on F1–F4 shipping; F4
    depends on D6, not the reverse, so there is no circular block.

### 6.2 Storage strategy — blocks B3/B4
Single SQLite file with one handle behind 12 threads survived 40/40 writes but cannot be
documented safe without FULLMUTEX or a connection per thread; remote DB is unimplemented and
FATAL-refused. **Choose:** (a) FULLMUTEX + connection-per-thread now, accept single process;
(b) implement the Turso/libSQL backend; (c) accept the ceiling as a written risk. Recommendation:
**(a)** now, revisit (b) when the course-pass launch makes scale real.

### 6.3 Course #2 — blocks E1
HAT was removed 2026-11-24; no manifest currently marks any course `paid` or `price`, so
**F3/F4/F6 have no course to gate until this ruling names one**. The mission chain has no
lexing/parsing course (`courses-todo.md:878-887` unchecked) and no *interactive learner-authored
code runner* (the `compback` course already runs machine-generated code — see §1.4). **Choose:**
(a) a mission-completing compiler-front-end course with a learner-authored runner; (b) an
externally-marketable paid course like HAT; (c) both, sequential. Recommendation: **(a) first**
for the mission, **(b) or (c) as the paid course**; the §6.3 entry must name the paid course
explicitly, and F3/F4/F6 depend on that course existing (§3).

### 6.4 Verification policy — RULED 2026-11-26: hard gate, blocks A3
The founder rejected checkers-as-tests. **A3 must make `tests.exe` build and run green.**
First analyse (read-only, never modify) how `Web/timeline`, `Web/123Mind` and `Web/easytodo`
wire their working Chemical test suites — their `tests/chemical.mod`, `scripts/test.sh`, manifest
`source "..."/import ... if test` rules and module import graphs — then apply the pattern to
Underlayer. Do not patch sibling repos and do not patch library test sources. If the stall
persists, report it with the exact compiler evidence; do not silently downgrade the gate.

### 6.5 CSP scope — blocks B5 depth
Full tightening needs externalising thousands of inline scripts/styles. **Choose:** (a) stepwise
externalisation (theme boot first) with nonces; (b) keep `'unsafe-inline'` and accept the risk.
Recommendation: **(a)**, one script per wave, zero console violations as the gate.

### 6.6 Account-data boundary — confirmation, not a new decision
The 2026-11-25 ruling (`Docs/decisions.md:4867-4869`) binds: all Underlayer learning data
(progress, FSRS, notes) stays in Underlayer's own database; the shared account is identity only.
The older Sept 2026 MongoDB/WiqisSync preference was a general sync-stack choice and does **not**
override it. Confirm: keep the bridge + own DB through the course-pass launch; do **not** plan a
MongoDB migration here. If the founder wants to reverse the ruling, that creates a new data
migration work package and a fresh decision — it is not part of this plan.

### 6.7 Open-source claim
`competitors.md` claims "free + open source" while product repos are private and the store id
is frozen. **Choose:** publish course content only under an explicit licence, or remove the row.

### 6.8 i18n deferral
Exercism localises into ~20 languages; Underlayer has 0/40 i18n items. **Defer i18n until a paid
path exists.** This is the plan's default and needs no new work package. If the founder wants
to reverse it, that reversal must create a new i18n work package with its own wave, budget and
exit criterion — this plan has none, so the reversal cannot be executed by simply editing §6.8.
Recorded here so §5's localisation row has a decision owner.

### 6.9 Course-structure and naming ruling — blocks E2
`docs/course-mission.md` §"Still outstanding" names two unresolved structures (`## Memory`
overlaps *The Memory Hierarchy*; `## Compilers` needs the same finishable-course treatment) and
one naming conflict (section `ARM64` vs concept text `AArch64`). **Choose:** (a) fold and
rename as proposed before any new course work; (b) defer until after E1. Recommendation:
**(a) for naming, (b) for the restructure** — fix the naming now (cheap, prevents new drift),
restructure after course #2 proves the shape. A7 logs this entry in Wave 4.

### 6.10 Opt-in learner email — RULED 2026-11-26: negative, I12 killed
Learner email stays deferred; all §17 items remain out of scope. I12 is not executed and no §17
checklist item is ticked. The change log (G9) is reachable only on the site.

### 6.11 Public proof-of-work scope — blocks G8
G8 pulls §8 items 8.1.10–8.1.17 into scope; the page shell and visibility toggle already exist
(`app/main.ch:784`, `features-complete.md:1689-1690`), so the remaining gap is server-rendered
proof data. **Choose:** (a) allow the narrow §8 proof-of-work items and ship G8; (b) keep all §8
items deferred, kill G8, and fold the metadata work into I1/C7. Recommendation: **(a)** —
certificates without a persistent public record are weak trust artifacts. A7 logs this entry in
Wave 4. No social graph, following, feeds or messages are authorised.

---

## 7. Verification playbook

**Two different working directories — do not mix them.** Build to a **new binary name** when
another server holds the current one open on Windows. Servers on 9000/9001/9002/9003/9004 were
left running during the November passes and hold DB locks, so use a fresh port (9010 below).

### Web — cwd `D:\Programming\Wiqis\Web\underlayer`

```powershell
$cc='D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe'
& $cc chemical.mod -o build/underlayer-plan.exe -bm-modules --no-cache
$env:PORT='9010'; $env:DATABASE_URL='./underlayer-plan-test.db'; $env:COURSES_DIR='./courses'
# start the binary in a VISIBLE window, then:
curl localhost:9010/api/health
curl localhost:9010/courses/elf/lessons/bytes
curl localhost:9010/api/courses/elf/lessons/bytes/units

# Served-output gates (use a disposable DB for the write probe; clean HEAD per §1.2)
py -3 tools/journey_quality_check.py http://localhost:9010 --all --workers 8   # expect 364/364
py -3 tools/theme_check.py http://localhost:9010                               # 56/56
py -3 tools/lesson_pager_check.py http://localhost:9010                        # 35/35
py -3 tools/helpful_dedupe_check.py http://localhost:9010                      # 12/12
py -3 tools/backup_db.py <copy-of-db> <temp-backup-dir>

# Static mode (must be redone after any journey change)
bash scripts/build_static.sh elf
```

### Android — cwd `D:\Programming\Wiqis\Android\Apps\underlayer-kmp`

```bash
# Git Bash; 'sh gradlew', NEVER './gradlew' — the wrapper has no exec bit on this checkout
sh gradlew :core:desktopTest :core-ui:desktopTest :database:desktopTest :app:testDebugUnitTest
sh gradlew :app:compileDebugKotlin :core-ui:compileKotlinDesktop :core-ui:compileKotlinJs \
           :core:compileKotlinJs :web:compileKotlinJs
sh gradlew :app:assembleDebug
sh scripts/check_no_webview.sh
# Device: VISIBLE wiqis-verify window only; adb input / uiautomator dump; retain screenshots + logcat
```

**Never** verify only against source. For every work package, re-run the live probes in §1.1
after the change and record the result in the package's acceptance notes. Write probes must use
a throwaway database — `helpful_dedupe_check.py` is rate-limit-sensitive after ~4 local runs.

---

## 8. Decision-log entry templates to append after each ruling

```
## YYYY-MM-DD — <title>
- Context: <which work package is blocked and what was measured>
- Decision: <the chosen option>
- Alternatives considered: <the rejected options and why>
- Consequences / follow-ups: <work packages unblocked, dates, owners>
- Owner: <name responsible for the work packages this unblocks>
```

Expected entries: Android freeze (§6.1 — **must include the written paid-path proposal** per
`profitability-plan.md:99`), storage (§6.2), course #2 **and the named paid course** (§6.3),
verification policy (§6.4), CSP scope (§6.5), open-source claim (§6.7), i18n deferral (§6.8),
course-structure/naming ruling (§6.9), public proof-of-work scope (§6.11). **All eleven were ruled
on 2026-11-26 in one consolidated `Docs/decisions.md` entry — no further entries are needed for
§6.1–§6.11.** §6.10 was negative (I12 killed). §6.6 is a confirmation of an existing ruling.

---

## Appendix A — all 20 unchecked P2 items and their disposition

From `docs/features-complete.md` (measured 2026-11-26). Each is assigned above or explicitly
deferred with a reason; after Wave 2 every item must have a recorded disposition — an owner or
an explicit, dated deferral.

| Item | Disposition |
|---|---|
| 2.4.22 Seed review_item_decls from manifest | C1/E3 — bank pipeline |
| 4.1.30 Progressive hints UI | C2 |
| 4.2.19 Real exercise streak counter | C2 (or remove as misleading) |
| 5.1.20 Review recommendations in UI | C2 |
| 6.2.16 Analytics endpoints consumed by UI | C3 |
| 6.2.17 Auth bearer on progress/analytics fetches | C3 |
| 7.1.14 Unread indicator | C7 |
| 7.1.24 Home "Continue learning" + due badge | C7 |
| 7.1.25 Dashboard login prompt instead of demo data | C7 (verify against current gate; may be stale) |
| 7.1.39 Nav focus ring consistency | C6 |
| 7.1.40 Shared shell for the 11 account pages | C7 |
| 7.1.41 Merge seven hand-rolled navbars | C7 |
| 7.4.13 Responsive visualisations | C8 |
| 7.5.4 Custom keyboard shortcuts | C8 (ship or defer with reason) |
| 7.5.6 Voice input | C8 → defer explicitly |
| 7.5.7 Switch access | C8 → defer explicitly |
| 7.5.8 External keyboard | C8 → defer explicitly |
| 7.5.9 Game controller | C8 → defer explicitly |
| 7.5.10 Stylus/pen | C8 → defer explicitly |
| 7.5.11 Multi-touch | C8 → defer explicitly |

## Appendix B — section-level checklist totals (measured)

| Section | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| 1 Learning Engine | 28/28 | 19/19 | 71/71 | 0/35 |
| 2 Course Authoring | — | 116/116 | 20/21 | 10/79 |
| 3 Course Content & Visualizations | — | — | 3/3 | 0/90 |
| 4 Exercise System | — | 14/14 | 23/25 | 1/45 |
| 5 Review & Spaced Repetition | — | 9/9 | 5/6 | 0/50 |
| 6 Progress & Analytics | — | 5/5 | 20/22 | 0/35 |
| 7 User Experience | — | 21/21 | 72/86 | — |
| 8 Social & Community | — | — | — | 0/85 |
| 9 Content Delivery | — | — | — | 2/60 |
| 10 Admin & Management | — | — | — | 0/65 |
| 11 API & Integrations | — | 2/2 | — | 12/76 |
| 12 Accessibility | — | — | — | 0/60 |
| 13 Security & Privacy | — | — | — | 0/45 |
| 14 Performance & Scalability | — | — | — | 0/45 |
| 15 Developer Experience | — | — | — | 3/50 |
| 16 Account Management | — | — | — | 75/170 |
| 17 Notification System | — | — | — | 0/65 |
| 18 Payment & Monetization | — | — | — | 0/60 |
| 19 Gamification & Motivation | — | — | — | 0/70 |
| 20 Certification & Credentials | — | — | — | 0/50 |
| 21 Internationalization | — | — | — | 0/40 |
| 22 AI & Machine Learning | — | — | — | 0/50 |
| 23 Enterprise Features | — | — | — | 0/60 |
| 24 Content Management System | — | — | — | 0/50 |
| 25 Data Pipeline & Warehouse | — | — | — | 0/50 |
| 26 Observability & Monitoring | — | — | — | 0/60 |
| 27 Legal & Compliance | — | 84/84 | — | 0/55 |

## Appendix C — open risks not covered by a work package

1. **Single-process ceiling** remains even after B3 unless B4 ships; record it as a known limit in the README (F7).
2. **No real screen-reader mannequin pass** is scheduled; C6 either does one or records acceptance of the gap.
3. **Servers on 9000/9001/9002/9003/9004** were left running during the November passes and hold DB locks; build to new binary names and use disposable DBs as the playbook says.
4. **Exercise-bank counts** were verified against the deployed `/api/exercises/{concept}` endpoint on 2026-11-26, but C1 must re-run the sweep before using them as an authoring baseline.
5. **Competitor facts are a snapshot dated 2026-11-26** from direct site fetches; re-check before publishing any comparison page (F6).
6. **This plan is a draft.** Its effort estimates are founder-days for one agent, not a commitment; the founder sets the schedule.

## Appendix D — execution status (A8 sweep, 2026-11-28)

This section is the live status record; §1.1/§1.3/§2 preserve the ORIGINAL 2026-11-26 baseline
so the measurements remain auditable. Counts below were measured on a fresh build of HEAD.

### Implemented and verified in the local tree

| Area | Result |
|---|---|
| Courses / concepts | **35 / 336** — original 33 + E6 `binread` (paid first module) + E1 `front` (mission lexer/parser course with a learner-authored runner) |
| Practice | **366 graded items**, every concept covered; explained in-page quiz on all 332 served free lessons (1,789 explained options); four new graded types + six specimen labs |
| Learning journey | 7-step onboarding with skippable placement, Today/daily plan, energy pacing + break panel, hints/retry ladder, compliant aims and clean takeaways |
| Platform | Per-learner FSRS persistence + Settings controls, PWA with offline lesson/quiz and queued sync replay, guest→account takeover, faceted search, public proof, "Your data" panel, support page |
| Security/ops | One access log per request, uniform headers on frozen pages, proxy-safe rate-limit keys, 33 specimen bundles with checksums, operator allow-list + audit log, concept alias migration, retention sweep, rollout flags |
| Android | Today/review screens, disk lesson cache, refreshed 346-item pack, telemetry policy, entitlement read; 130 unit tests, three-target compiles, no-WebView guard green |
| CI | Compiler provisioning, 138 unit tests with summary-line gate, served-output checkers, static/semantic corpus, nightly live gates + performance budget |
| Gates | journey 369/369 · theme 56/56 · pager 35/35 · dedupe 12/12 · bridge 3/3 · security 73/73 · SEO 377/377 · banks 366 · quiz 332 · explanation 366 · landing 35/35 · specimen 35/35 · metadata 35/35 · proof 0 failures · enroll 22/22 · perf PASS with one dated font exception |

### Still open — founder/external actions, not agent work

1. **Real Paddle account, webhook secret, checkout URL and payout profile**; the shipped webhook is proven with a documented test-mode stub only. No real purchase has occurred.
2. **Play Store release** for the Android app: generate a NEW signing key (the committed `keystore.jks` is compromised), wire `signingConfig` from secrets, refresh the listing, file Play Data Safety. Frozen applicationId unchanged.
3. **Deployed environment**: Cloud Run `max-instances=1`, durable DB volume, deployed build provenance via `tools/release_probe.py`, alerting owner, staging restore drill, staging flag rehearsal. None is verifiable from this machine.
4. **Real sign-in ceremonies**: passkey/WebAuthn and Google OAuth+MFA on the deployed host, plus a Safari human check. Local stub payload shapes were captured; they are not proof of a real ceremony.
5. **On-device emulator pass** (visible window, fresh approval) for the Android client.
6. **Upstream Chemical HTTP server teardown race** (`std::Arc::get` in `release_connection`), founder-owned in the compiler/libs repo; see `Docs/decisions.md` 2026-11-27 and `docs/deployment.md` §5f. Six in-repo mitigations were measured and rejected.
7. **`WebLibs/brandlib` render-blocking Google Fonts stylesheet** — owner founder/brandlib, exception dated 2026-11-28, review 2026-12-12 (`docs/h15-performance-budget.md`).
8. **G12 authoring pilot is not swapped into the served course**; it is validated by its own lint/preview only. Six pre-existing byte-harness BLOCKED results (`exe`, `img`, `isa`, `mem`, `rvat`, `sec`) remain.
9. **Production-DB cleanup** of 152 historical orphan rows needs a founder ruling; the retention tool refuses production paths.
10. **G13 takeover is web-only** in this execution; the Android outbox still queues until a session token exists (D1 bridge proof is pending a real account token).
