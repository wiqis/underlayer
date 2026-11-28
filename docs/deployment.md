# Deployment Architecture — current reality (2026-11-26)

This document replaces the old "auto-deploy on every push" description, which
was never true of this repository. Where the earlier file described a pipeline,
it described an intention. This one describes what exists and runs today, and
says plainly what does not.

## 1. What is actually deployed

One native server binary (`underlayer.exe`), built from this checkout with the
Chemical compiler, serving:

- the pre-rendered course pages and the server-rendered account pages, and
- the JSON API under `/api/*`.

State lives in a **single local SQLite file** (`DATABASE_URL`, default
`./underlayer.db`). Course manifests are discovered at startup from
`COURSES_DIR` (default `./courses`). The binary is self-contained; the only
runtime inputs are the port, the database path, the courses directory and the
optional Turso token.

**The founder deploys manually.** There is no CD. A commit does not change the
live site. Do not describe the CI workflow below as a deployment pipeline.

### What is NOT deployed from this repository

- **The Android client** is a separate repo (`Android/Apps/underlayer-kmp`),
  with a frozen `applicationId` (`com.wakaztahir.learnpythonapp`). This
  repository's workflow does not build an APK, upload one, or update a CDN.
- **Static course output** (`courses/*/output/`) is generated and gitignored.
  GitHub Pages needs it regenerated (`bash scripts/build_static.sh …`) before a
  pages deploy; committing generated files is not the mechanism.
- **A remote database backend.** `DATABASE_URL` pointing at `libsql://` or
  `https://` is **refused at startup** with a FATAL log. The remote branch of
  `exec_sql`/`query_sql` is not implemented; a build that accepted such a URL
  would report healthy and lose every write. The Dockerfile still mentions a
  remote URL as an option — that comment is aspirational. Use a local file on a
  mounted volume (the Dockerfile defaults to `/data/underlayer.db`).

## 2. CI — verification only

`.github/workflows/ci.yml` runs on `push`, `pull_request` and
`workflow_dispatch`. As of **2026-11-26** (commits `e627de0` for the suite and
`63b33eb` for the workflow) it:

1. checks out the repository with read-only permissions (`contents: read`);
2. **provisions the compiler** — either a pre-provisioned `CHEMICAL_ROOT`/
   `compiler_root` directory, or a checkout of the public Chemical source at the
   pinned `CHEMICAL_REF` (`7a2da417…`), cached by ref and built from
   `scripts/setup.sh` + CMake/Ninja if no cached binary exists. It records the
   compiler SHA-256 in `build/compiler.sha256` and fails with an actionable
   message if neither path yields `TCCCompiler`;
3. builds the server with `-bm-modules --no-cache`;
4. builds the ELF static pages with `bash scripts/build_static.sh elf --quiet`;
5. **builds the `@test` application** with
   `"$UL_COMPILER" tests/chemical.mod -o build/tests-verify.exe --no-cache`
   (deliberately **without** `--test`, which would propagate into dependencies);
6. starts the server on a free OS-assigned port with a **disposable**
   `ci-underlayer.db`;
7. runs the endpoint matrix, then the Chemical suite (parsing the `Summary: N
   tests – P passed, F failed` line, because the runner exits 0 even when tests
   fail, and refusing a zero-test run);
8. runs **five** served-artifact checkers:
   `tools/journey_quality_check.py`, `tools/theme_check.py`,
   `tools/lesson_pager_check.py`, `tools/helpful_dedupe_check.py` and
   `tools/bridge_probe.py` (three read-only POSTs proving the account-bridge
   route exists; no registration, votes or progress writes);
9. stops the server in an `always()` step.

Any non-zero exit fails the job. There is **no deploy step, no publish step, no
`git push`, and no secret of any kind** in the workflow.

### Honest limits of the workflow

- **Single platform.** The job uses `windows-latest` because that is the only
  platform where TCCCompiler is verified here. The compiler is a native binary
  this repository does not build; a Linux runner would need a Linux compiler
  checkout and its own verification.
- **No browser in CI.** `theme_check.py` runs all 56 static contract checks. The
  extra Playwright proof that a stored `dark` choice is applied before the first
  body paint runs locally with `python tools/theme_check.py BASE --browser`
  (or `THEME_CHECK_BROWSER=1`).
- **The write probe needs a disposable DB.** `helpful_dedupe_check.py` registers
  two throwaway learners and casts votes. It is safe in CI because the database
  is created fresh for the job. Never point it at production.
- **The `@test` suite is in CI now (updated 2026-11-26).** The old statement —
  that the suite was compiler-blocked and CI verified only the served artifact —
  was true until A3 (`e627de0`) unblocked it and A2 (`63b33eb`) wired it in. It
  builds as a separate application without `--test` and runs **138/138 green**
  (`build/a2verify-tests.stripped.log`, 2026-11-26; `Summary: 138 tests - 138
  passed, 0 failed`). The suite and the five served-artifact checkers are
  complementary, not substitutes: the checkers probe a running server, the
  suite exercises the modules directly. A GitHub-hosted runner execution of
  this workflow has **not** been observed on this machine; the steps above were
  verified locally against the same command sequence (A2 logs in `build/`).

## 3. Build and run

From the repository root, with `CHEMICAL` pointing at the compiler checkout:

```bash
"$CHEMICAL/cmake-build-debug/TCCCompiler.exe" chemical.mod \
    -o build/underlayer.exe -bm-modules --no-cache
PORT=9000 DATABASE_URL=./underlayer.db COURSES_DIR=./courses ./build/underlayer.exe
```

Windows PowerShell:

```powershell
& 'D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe' chemical.mod -o build\underlayer.exe -bm-modules --no-cache
$env:PORT='9000'; $env:DATABASE_URL='./underlayer.db'; $env:COURSES_DIR='./courses'
.\build\underlayer.exe
```

Smoke test (all three must answer 200):

```
GET /api/health
GET /courses/elf/lessons/bytes
GET /api/courses/elf/lessons/bytes/units
```

`AGENTS.md` requires the server to build and serve the ELF course after every
change. Build to a new binary name when another server holds the current one
open on Windows.

### Static pages

```bash
bash scripts/build_static.sh elf        # one course
bash scripts/build_static.sh            # every course
```

The script compiles each course, runs its generator and then the guided-journey
injector. Generated output is intentionally untracked; regenerate it wherever a
static site is served from.

### Environment variables (actually read)

| Variable | Purpose | Default |
|---|---|---|
| `PORT` | HTTP port | `9000` |
| `DATABASE_URL` | SQLite file path; remote URLs are refused | `./underlayer.db` |
| `DATABASE_TOKEN` | Turso auth token (unused for local SQLite) | empty |
| `COURSES_DIR` | Course content directory | `./courses` |
| `PUBLIC_BASE_URL` (I1) | Public origin used by canonicals, og:url, sitemap locs and robots' `Sitemap:` line | `https://underlayer.wiqis.com` |

`PUBLIC_BASE_URL` is read on demand (like `ACCOUNT_URL`), so a local run sets
it to `http://localhost:<port>` and nothing about the served markup or the
sitemap depends on a compile-time production host. There is no Tigris/S3
storage client, no `STORAGE_BUCKET`, and no CDN upload in this build, whatever
older docs said.

## 4. Backup and restore

`tools/backup_db.py` uses the standard-library `sqlite3.Connection.backup()`
API, so it takes a **consistent snapshot even while the server has the DB
open**. A plain file copy of a live WAL database can lose committed pages. The
source is opened read-only; `PRAGMA integrity_check` runs on the source and on
the copy; a failed check aborts and leaves no output file. Existing destinations
are never overwritten without `--force`.

Take a timestamped backup into a directory:

```powershell
py -3 tools\backup_db.py .\underlayer.db .\backups
# -> backups\underlayer-YYYYmmdd-HHMMSS.db
```

Or name the file explicitly:

```powershell
py -3 tools\backup_db.py .\underlayer.db .\backups\nightly.db --force
```

Verified 2026-11-26 against a **copy** of the live DB (the live DB was never
touched): source 647,168 bytes, `integrity_check ok`, backup 647,168 bytes /
158 pages, `integrity_check ok`. Refusing an existing destination returned
exit 1; `--force` succeeded; a deliberately corrupted source was rejected with
`database disk image is malformed` and wrote no file.

### Restore

1. Stop the server. This is the important step: restoring underneath a running
   process can mix old and new pages.
2. Keep the current file as a fallback (rename it; do not delete it).
3. Copy the chosen backup over the path in `DATABASE_URL`:

   ```powershell
   Copy-Item .\backups\underlayer-20261126-143508.db .\underlayer.db
   ```

4. Start the server. Startup migrations are forward-only and idempotent, so an
   older backup is brought up to the current schema automatically.
5. Verify `/api/health`, `/courses/elf/lessons/bytes` and one account action.
6. Confirm any data written between the backup and the stop is re-entered or
   intentionally discarded — a restore is a point-in-time rollback, not a merge.

### H5 — build provenance baseline (2026-11-27)

`/api/health` now returns four **additive** fields; `status` and `version` keep
their exact bytes because clients and the served-behaviour checkers parse them:

```
before (pre-change binary, 2026-11-27): {"status": "ok", "version": "0.1.0"}
after  (local binary, 2026-11-27):     {"status": "ok", "version": "0.1.0", "commit": "ea3261cc91ec774e17bdfe86e343d5777fdee97d", "compiler_version": "Chemical v0.6.0", "build_mode": "debug", "built_at": "2026-11-27T00:00:00Z"}
```

Values come from `UL_BUILD_COMMIT`, `UL_BUILD_COMPILER_VERSION`,
`UL_BUILD_MODE` and `UL_BUILD_AT` (see `core/src/build_info.ch`). A release
build with any of the three identifying values missing or `unknown` logs a
FATAL line and exits 1 **before** schema init; verified locally on 2026-11-27
(`build/h5-after.err.log`). The runtime inputs are set by the deploy step, not
baked as secrets into the image.

Provisional baseline recorded here (update this line when the founder commits
and deploys the release build — the deployed service on 2026-11-27 still
answers only `{"status":"ok","version":"0.1.0"}`, so its provenance is
**not measurable** and there is no deployed rollback digest yet):

- Build digest: ea3261cc91ec774e17bdfe86e343d5777fdee97d
- Compiler pin: Chemical v0.6.0
- Deployed provenance: **FOUNDER ACTION** — set the four `UL_BUILD_*` values in
  the release deploy, then run `py -3 tools/release_probe.py
  https://underlayer.wiqis.com` and replace the two lines above with the
  observed values. Until then `release_probe.py` fails against the deployed
  host by design; no deployed release is claimed.

`tools/release_probe.py --selftest` runs one positive and four negative cases
(wrong mode, wrong compiler, missing field, changed client contract) with no
network dependency. It never writes to a database or a deployed service.

### H6 — where production data lives, and the restore drill (2026-11-27)

**Known from this repo:** the Docker image sets `DATABASE_URL=/data/underlayer.db`
and creates `/data`; it does **not** declare a volume, and the container
filesystem is ephemeral. A revision swap discards anything written to a path
that is not mounted. **Not verifiable from this machine:** whether the Cloud Run
service actually attaches a volume/NFS mount at `/data` is founder-console
state. Do not assume the deployed DB persists across revisions.

- **FOUNDER ACTION (blocks H6 in production):** run
  `gcloud run services describe underlayer --region <region> --format='value(spec.template.spec.volumes,spec.template.spec.containers[].volumeMounts)'`
  and record the result here, with the setting applied and by whom. `gcloud` is
  **not installed on this machine**, so this could not be measured from an
  agent session. If no durable mount exists, production data is currently lost
  on every deploy and H1/H6 cannot be called green.
- **Snapshot policy (defined, not yet automated):** daily snapshot at 03:00 UTC
  of the live SQLite file via `tools/backup_db.py` (consistent even with the
  server open), retain **30 days**, verify `integrity_check ok` on every
  snapshot, alarm on a missed run. Scheduler/Cloud Run job creation is a
  founder action; no cron is wired in this change.
- **Named owner:** `TBD — founder to name` (placeholder; a named human is
  required before this is an operational control).

**Drill performed 2026-11-27, on copies only (production DB never opened):**

```
source: disposable build/h6/source.db, one throwaway account + one progress row
backup: tools/backup_db.py -> build/h6/snapshots/source-20261127-120900.db
        source 4096 B, backup 561152 B / 137 pages, integrity_check ok on both
sha256: 621c41f5122df7228750b17297d0f412b92e57422981b2ae88f4ca10e66d70b0
restore: copied the snapshot to a SEPARATE staging path build/h6/staging.db
verify: staging /api/health 200, login 200, /api/progress/sync 200,
        progress row h6-drill-unit present
RPO measured in drill: 1.3 s (snapshot age at restore)
RTO measured in drill: 1.3 s (restart to verified)
log: build/h6-restore-drill.log, scripts/restore_drill.py
```

Those RPO/RTO numbers describe the **local drill**, not the deployed service;
production targets are not claimed until the founder records the snapshot
schedule and mount.

### I1/I2 — discovery surface and its two new gates (2026-11-27)

Three new literal routes (`/robots.txt`, `/sitemap.xml`, `/favicon.ico`) are
registered before the `web::App` catch-all and answer through
`deliver_with_learner`. They therefore inherit the H3 header contract, request
id, ETag/304 and gzip rather than bypassing it. The sitemap is generated from
the repository's own course loader — 4 entry pages + 6 guide/legal pages + 33
course landings + 329 concept URLs = **372** — with `<lastmod>` derived from
the verified 2026-11-26 content snapshot and the manifest's `version` (no
course changelog exists yet). Head metadata on served pages is emitted by
`HtmlPage`; no markup is string-built. The full status ledger, including the
Search Console baseline ("baseline pending founder access") and the honest
list of what was **not** verified, is `docs/seo-content-status.md`.

Two local-only gates were added; **CI wiring is the coordinator's step (H4)**,
not part of this change. Add these commands to the served-artifact checker
stage:

```
python3 tools/literal_route_shadow_check.py
python3 tools/literal_route_shadow_check.py --selftest
python3 tools/seo_surface_check.py "$BASE_URL"
python3 tools/seo_surface_check.py --selftest
```

`literal_route_shadow_check.py` is the source-level guard for I2: the router is
first-match-wins in registration order, so `GET /api/exercises/hint` must stay
ahead of `GET /api/exercises/:conceptId`. `seo_surface_check.py` builds its
expected URL set from `/api/courses` + `/api/courses/<id>` (not a hardcoded
count), checks the sitemap set and every served page's head, and has both a
synthetic `--selftest` and a live `--plant` negative case.

The journey checker needs `--workers 8` locally; a sequential crawl of 329
lessons is correct but exceeds a 10-minute command timeout on this machine.

### I9/H14 — anonymous surface honesty and anonymous writes (2026-11-27)

**I9 — the 13 unmarked learner-shaped anonymous 200s were resolved by
classification, not by a blanket change.** The shipped JSON shape is unchanged
apart from the additive fields below; `/api/search` was not touched.

| Decision | Endpoints | Why |
|---|---|---|
| **401** `{"error":"Sign in to see your data"}` | `/api/streaks`, `/api/streaks/weekly`, `/api/progress`, `/api/progress/:courseId`, `/api/progress/export`, `/api/me/overview`, `/api/exercises/failures`, `/api/nav-status`, `/api/review/recommendations` | Each is one learner's own state (streak, export, "me", failures, due queue). With no session the old handler answered for the shared `demo` row, which reads as the visitor's own data. Pure personal data has no honest anonymous form. |
| **200 + additive `"demo":true,"message":"Sign in to see your data"`** | `/api/analytics/overview`, `/api/analytics/concept/:conceptId`, `/api/analytics/retention`, `/api/analytics/funnel` | Aggregate/curiosity views stay public, but the marker says on the wire that the numbers belong to the demo learner. The four pages that paint learner numbers (`/dashboard`, `/progress`, `/analytics`, `/streaks`) remain 303-gated, so no page can present them as the visitor's own. |

The marker is emitted only when `has_session()` is false; a signed-in caller
gets byte-identical JSON to before the change. `/components` remains gated by
the same `UL_BUILD_MODE` provenance (404 in release), as recorded above.

**H14 — release builds must not create or delete persistent rows anonymously.**
Measured against a release-like binary on a disposable SQLite file, five routes
wrote rows with no credentials; with a richer probe payload six write/del
operations fired, and a seventh route (`reactivate`) was an upsert masked by an
earlier probe. Debug/test binaries keep the old behaviour byte-for-byte so
`tests.exe` still drives `POST /api/learners` (138/138). In release:

- the **test-only** route (`POST /api/learners`) answers **404 "Not found"** —
  it inserts into `learners` with a hardcoded identity and no password, and its
  rate limiter still fires first so `security_check`'s existing bucket assertion
  keeps proving that gate runs;
- the **six real feature routes** answer **401** when no session resolves, via
  `require_session_in_release()`. This is deliberately narrower than a
  build-mode 404: a gate that disabled these routes for signed-in learners
  would silently break shipped features (measured: `security_check`'s account
  deletion check calls `POST /api/streaks/activity` with a valid token).

| Route | Persistent effect when anonymous | Release |
|---|---|---|
| `POST /api/learners` | inserts `learners` with a hardcoded identity | 404 (test-only) |
| `POST /api/goals` | inserts `learning_goals` for `demo` | 401 without session |
| `DELETE /api/goals` | deletes `learning_goals` for `demo` | 401 without session |
| `POST /api/user/deactivate` | upserts `learner_settings`, deletes `auth_sessions` | 401 without session |
| `POST /api/user/reactivate` | upserts `learner_settings` on a fresh DB | 401 without session |
| `POST /api/progress/import` | inserts `concept_states` / `review_items` | 401 without session |
| `POST /api/streaks/activity` | inserts `daily_activity` / `learning_streaks` | 401 without session |

Authenticated calls to all six are unchanged in release: the gate passes as
soon as `has_session()` is true, so no product feature is lost.

**Deliberately left unauthenticated — documented behaviours, not oversights:**

- The auth lifecycle (`register`, `login`, `logout`, `from-account`,
  `forgot-password`, `reset-password`, `verify-email`). Requiring a session to
  obtain the first session is impossible; these writes are the shipped account
  contract (see `docs/mobile-api.md`), not a discretionary anonymous write.
  `tools/anonymous_write_check.py` exempts exactly these seven and prints the
  reason for each exemption.
- `POST /api/progress/share` returns a share URL only; it inserts no row.
- `POST /api/fsrs/optimize|reset|import` are stateless today — they compute and
  return parameters and write nothing. This is G3's known persistence gap, not
  an anonymous-write surface; gating them would hide that gap rather than fix
  it.
- Public catalogue and navigation reads keep their existing `demo` fallbacks
  where the payload is not learner-shaped. I9's checker keys on learner-shaped
  fields specifically; it does not flag course metadata.
- G13's guest progress takeover is a separate feature and is untouched.

Local gates (CI wiring is the coordinator's H4 step):

```
python3 tools/anonymous_surface_check.py --base "$BASE_URL"
python3 tools/anonymous_surface_check.py --selftest
python3 tools/anonymous_write_check.py --base "$BASE_URL" --db "$DISPOSABLE_DB"
python3 tools/anonymous_write_check.py --selftest
python3 tools/security_check.py --port "$PORT"   # includes the H14 13b assertion
```

Neither write checker will accept a non-loopback URL or a production-looking
DB name, and `anonymous_write_check.py` refuses a server whose `/api/health`
does not report `build_mode=release`. Both have negative plants that must fail.

## 5. Rate-limit key, trust boundary and retention (H2/B7, 2026-11-26)

Login, register, forgot/reset, the account bridge and the learning-write
endpoints are limited by rows in the `rate_limits` table, not by in-memory
counters: a counter that dies with the process resets on every restart and
fails open with a second process. The limit is 8/5 minutes for auth and 120/5
minutes for learning writes. **Both windows are preserved** in one table; the
two "windows" in the original B7 wording meant the auth and learning
ceilings, not two schema windows, and neither was removed.

### The key, and what is trusted

`web/src/rate_limit.ch::rate_limit_key` uses:

* an **authenticated learner id** (`u:<32-hex-id>`) when the request resolves
  to a session -- so two signed-in learners behind the same frontend never
  share a learning bucket; and
* the **socket peer** (`ip:<remote>`) otherwise -- login/register have no
  learner id yet.

`X-Forwarded-For` is **never read**, including its last hop. It is set by the
caller; trusting it means a caller can sidestep any key by changing a header.
A peer value from the socket is the only value an attacker cannot choose.
`app/main.ch` logs `remote=` on every request, so Cloud Logging records what
the deployed peer actually resolves to without a client-side probe.

**Deployed trust analysis (not yet measured from two networks).** This service
runs behind Google Frontend. On Cloud Run the socket peer is the frontend's
address, so all *anonymous* callers may share one 8/5-minute bucket. That is
fail-closed -- no header deception can bypass it -- but it is a real shared
allowance: one person's failed logins can lock out strangers for parts of five
minutes. This is accepted deliberately until the founder chooses one of:

1. an edge limiter (Cloud Armor rate-based rule) keyed on the edge-observed
   client address; or
2. a trusted proxy hop that **overwrites** (not appends to) a client-ip header
   and a server-library change to read only that hop's value.

A client-supplied `X-Forwarded-For` is NOT option 2. There is no committed
third option that trusts a caller-controlled header.

### Deployed two-network probe -- FOUNDER ACTION, NOT RUN

`tools/rate_limit_deployed_probe.py --deployed ... --founder-approved` is the
documented probe. It must be run by the founder from **two distinct client
networks** (office wifi and a mobile hotspot, not two tabs on one machine):

* A: 8 wrong logins -> `401 x8`, 9th -> `429` with numeric `Retry-After`;
* B: 8 wrong logins -> `401 x8` (NOT 429), then a correct login -> `200`.

If B is throttled after A, the shared-frontend finding is confirmed and an
edge limiter is required. This machine cannot produce two networks, and an
agent may not throttle a deployed service, so the deployed probe was **not
run** for this work package. No deployed pass is claimed. Record the date,
both network labels, observed statuses, and the `remote=` values from Cloud
Logging here when the founder runs it.

### Empty-bucket probe (B7) -- local, run and passed

With a disposable DB (`build/verify-9014.db`), the tool cleared `rate_limits`
and fired nine wrong logins from localhost:

```
401 x8, then 429 on attempt 9; Retry-After: 160 (within the live 300s window)
```

The historical deployed observation was `Retry-After: 120`; the value is a
position in the live window, so the assertion is on numeric presence and
range, not a fixed number. A local empty-bucket probe also runs on every CI
push against `ci-underlayer.db`.

### One purge owner

`repository/src/schema_migrations.ch::purge_expired_rate_limits` is the single
startup purge (cutoff `now - 2*300s`, so every expired bucket is dead by the
limiter's own reset rule). It is called from `repository/src/schema.ch`. The
former web-layer 24-hour sweep (`ensure_rate_limit_table` /
`purge_stale_rate_limits`) has been **removed**, not kept as harmless dead
weight: two owners of one counter table is how a future change deletes a live
bucket in one layer while the other still counts it. A restart of a copy
still removes a stale row and keeps a fresh one.

## 5a. Request logging and request ids (B1, 2026-11-26)

Every request now emits exactly one structured line through
`web/src/request_log.ch`, reached from the one delivery funnel in
`web/src/responses.ch`:

```
[request] method=GET path=/api/health status=200 duration_ms=0 learner_id=- request_id=e939... remote=127.0.0.1
```

`X-Request-Id` is echoed. A caller-supplied value is used only when it is a
short plain token (64 chars, no spaces/quotes/CR/LF/separators); otherwise a
fresh 16-hex id is minted. That stops a forged header from injecting a second
log line. `learner_id` is resolved from the same bearer/cookie token the auth
guards use -- no new process-wide mutable state. A 5xx is logged at ERROR;
database failures (`exec_sql`, `prepare`, `step`) are logged at ERROR in
`database/src/main.ch`.

`duration_ms` is measured **from delivery entry to wire-ready response**: the
upstream router has no middleware hook, so the handler's own execution time is
not included. The server library's `http::AccessEntry` has whole-exchange
duration but no request id or learner id, so it cannot produce this line.
Both this limitation and the next are recorded rather than papered over:
an alert to a named on-call owner and Cloud Logging verification on a deployed
revision are still founder actions.

## 5b. Uniform security headers and CSP font origins (H3, 2026-11-26)

The header contract (`Content-Security-Policy`, HSTS `max-age=31536000`,
`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
`Referrer-Policy: strict-origin-when-cross-origin`, `X-Request-Id`) is now
applied to **two** paths:

1. `deliver_with_learner` for every handler route, including guard refusals
   (429) and redirects -- the 17-handler list was never 17 edits; it is one
   helper plus the existing `deliver` call sites;
2. `deliver_web_request` around `web::serve_request` for the frozen page/app
   assets and the 404. These used to have **no** security headers at all.

`apply_security_headers` uses `set_header_view` (replace), so the catch-all
cannot double-set a helper's header. Verified byte-for-byte on port 9014:
`/api/health`, `/`, `/courses`, a lesson, `/help`, `/faq`, `/about`,
`/shortcuts`, `/privacy`, `/terms` and a 404 all carry an identical CSP and
the same five fixed headers.
`tools/security_header_coverage.py` asserts this with a negative plant
(a deliberately headerless response must FAIL).

**Font decision (recorded choice): keep the external font, add exactly two
origins.** The brand layer (`WebLibs/brandlib/src/theme.ch`) links the Inter
stylesheet from `https://fonts.googleapis.com` and fetches woff2 from
`https://fonts.gstatic.com`. The CSP now allows those two origins in
`style-src` and `font-src` respectively; Google remains absent from
`default-src`, `script-src`, `img-src` and `connect-src`. The alternative --
removing the external link and using system fonts -- was rejected because it
changes the shipped visual design, which H3 explicitly does not do.

**Browser evidence (local port 9014, headless Chrome via Playwright).**
Drove `/`, `/courses`, a lesson, a quiz step ("Start the journey") and the
six frozen/legal pages: **zero `securitypolicyviolation` events on every
page**. On `/help` the Google stylesheet returned HTTP 200 and Inter moved
from `unloaded` to `loaded` when an element explicitly requesting it was
rendered (`document.fonts.check("16px Inter")` became true). On the lesson
page the served HTML has no Google Fonts link at all and uses the system
font stack, which is why it reports no Inter faces -- that is correct, not a
missing font. Note that the shipped CSS on the frozen pages still resolves
`body` to `system-ui`; the Inter faces are loaded on demand, so the visual
effect of the new origins is to permit those loads rather than to change the
default body font. Confirming the intended visual font on the deployed host
remains a founder/CSP-drive follow-up.

## 5c. CI gate corpus and inventory (H4, 2026-11-26)

Per push: the six source checkers and the quick non-vacuity harness. Nightly
(`schedule` + `workflow_dispatch`): the live gates on a fresh disposable DB,
with logs on the GitHub run page. No deploy, publish, push or secret is in the
workflow. **Route count is 187** from the current binary's `srv.router.add`
calls (the old "180" was a 2026-10 baseline); `tools/route_check.py` parses
the source itself (UTF-8 explicit) and reports the number it walked.

| Gate | Per push | Nightly | Negative case / owner for exclusion |
|---|---|---|---|
| `check_inline_string_temporaries.py` | yes | yes | plant `&string(...)` in production source; `tests/` excluded, owner: `@test` suite 138/138 |
| `sqli_scan.py` | yes | yes | `--selftest` plants one unescaped interpolation and requires +1 finding |
| `bracecheck.py` | yes | yes | planted raw `{` inside `#html` fails |
| `html_balance.py` | yes | yes | planted unclosed `<div>` fails |
| `check_quotes.py` | yes | yes | planted "412.500 ticks/op" in a quoted `<pre>` fails |
| `js_escape_check.py` | yes | yes | node round-trip of emitted `\u{...}`; a wrong escape fails |
| `static_gate_negative_cases.py` | yes | yes | plants all six source gates in disposable copies; certified 6/6 locally; no DB, no rebuild |
| `security_check.py` | -- | yes | `--selftest` plus live 44-check probes; H4 fixed it to read `DATABASE_URL` (it used to always open the default `underlayer.db`, so a disposable DB produced false "row not written" failures) |
| `route_check.py` | -- | yes | `--selftest` plants a cross-learner leak; walks 187 routes |
| `integration_check.py` | -- | yes | `--prove-non-vacuous` removes one rendered call and must fail |
| `checker_nonvacuity.py` (full) | -- | yes | theme + lesson-pager tree plants must fail with named markers; see exclusion notes below |
| `security_header_coverage.py` | yes | yes | `--selftest` plants a headerless frozen page; it must FAIL |
| `rate_limit_deployed_probe.py --local` | yes | yes | empty bucket: 401x8 then 429 with numeric Retry-After |
| Deployed two-network H2 probe | -- | -- | **Owner: founder.** Cannot run from one machine; needs two networks and approval to throttle |
| Browser / CDP CSP-drive | -- | -- | **Owner: founder / agent with browser tooling.** See final report for this pass's outcome |

## 5d. Deployed verification status (2026-11-26)

All B1/H2/H3/H4/B7 evidence in this document was gathered **locally** against
a freshly built binary on port 9014 with a throwaway DB. A live re-probe of
`underlayer.wiqis.com` on 2026-11-26 still shows the OLD behaviour: `/api/health`
has no `X-Request-Id`, its CSP has no `fonts.gstatic.com`, and `/help` still has
no security headers. That is expected -- the founder deploys manually and no
deploy or push is part of these work packages. The deployed re-probe is a
**founder action after deploy**: run `tools/security_header_coverage.py
https://underlayer.wiqis.com`, confirm the six frozen pages/404 now match
`/api/health`, and link the output here.


## 5e. Graceful shutdown and timeouts (H7, 2026-11-27)

**Upstream finding (read, not patched):** `lang/libs/http/src/server.ch`
provides `Server::handle()` → `ShutdownHandle::shutdown()` and a poll-based
accept loop, but registers **no** OS signal handler and does not drain on
SIGTERM by itself. On shutdown, `serve()` returns and the worker-pool
destructor joins workers after their queues drain; that is the drain, but it
has to be triggered by our code.

**Implemented in `app/main.ch`:** handlers for SIGTERM/SIGINT (plus SIGBREAK on
Windows) set one boolean latch; a watcher thread notices it, logs
`shutdown signal received`, calls `ShutdownHandle.shutdown()` (stop accepting),
lets the upstream pool drain in-flight work, then closes the DB and logs
`[underlayer] shutdown complete` before returning 0. Per-request work is
bounded by `header_timeout_secs=5`, `body_timeout_secs=30`, so the drain is
bounded by 30 s. The upstream `ServerConfig` has **no separate idle-timeout
field**; an idle keep-alive connection is bounded by the header-read timeout.
The worker pool size is **12**, `max_inflight=256`; both are logged at startup
(`server config: worker_count=12 …`). The only new global is
one boolean signal latch, written by the handler and read by the watcher; no
route, FFI string or DB access goes through it.

**Kill test (disposable server, 2026-11-27; `scripts/shutdown_probe.py`, log
`build/h7-shutdown-result.log`):** four wrong-password logins and one
`POST /api/progress/sync` were in flight when CTRL_BREAK_EVENT was sent.
In-flight outcomes: `sync=200`, `login×4=401` (clean completions, no 503 and no
connection reset); exit code 0. Log contains both shutdown lines and no
`database is locked` / `SQL FAILED`. Restart on the **same DB**: health 200,
login 200, `/api/progress/sync?since=0` 200 with the progress row intact.

**Cloud Run caveat:** Cloud Run sends SIGTERM to the container; on Linux our
SIGTERM handler is the path exercised above conceptually, but this machine is
Windows and the local drill used SIGBREAK. A deployed SIGTERM drill is a
founder action after the next release; no deployed shutdown proof is claimed.

### H4 exclusions (owner for every gap)

* `checker_nonvacuity.py::check_nesting` and `::check_link` -- their controls
  already fail on a clean tree in this checkout (red before any plant), so
  neither can certify anything right now. Owner: the content/link gate owner;
  re-certify in the nightly job once the controls are green. Documented, not
  silently marked green.
* `checker_nonvacuity.py::check_session_js` -- control fails against the local
  server on 9014; owner: web client gate owner.
* `checker_nonvacuity.py::check_lesson_pager` and `::check_theme` -- the plant
  is repaired/reversed as described in §6 item 6, but in this Windows checkout
  the planted tree did not build (compiler exits 1) so the negative case is
  **not certified here**. Nightly job must show a named `truncated` /
  `pre-paint boot` failure before these are claimed certified. Owner: H4
  nightly gate.
* The full `checker_nonvacuity.py` run exits non-zero locally because of the
  exclusions above; that is why per-push uses `static_gate_negative_cases.py`,
  whose six plants are all certified.


## 5f. Test-suite flake: upstream `http::Server` teardown (investigated 2026-11-27)

**Status: root cause located upstream; NOT fixed in this repo. A partial
mitigation is applied; the suite is still nondeterministic. Do not treat a
green run as proof.** CI's summary-line gate (A2) still refuses a partial run.

### Symptom (re-measured)
Baseline `tests-diag.exe` built from `tests/chemical.mod` (no `--test`),
12 consecutive runs: **3/12 failed** — 136, 136, 137 of 138 — each with
`RUNTIME ERROR: invalid memory access` at `std::Arc::get`. The failing test
name varies between runs; the faulting arc is always the `Arc<Mutex<uint>>`
`std_stdArc__cgs__a56329b9d998`, i.e. `Server.inflight`.

### Root cause — upstream, file:line
The error is a use-after-free of the `Server` object reached from a worker's
callback. The relevant upstream sites (all read-only here) are:

* `lang/libs/http/src/server.ch:463-466` — `serve_async(self)` consumes the
  `Server` **by value** and spawns `serve_thread(server : Server)`
  (`server.ch:626-629`), which takes it by value again. The spawned thread owns
  the `Server` value; its address is a raw `selfp : *Server` taken at
  `server.ch:517` and `server.ch:563` and copied into pool/IOCP closures.
* `lang/libs/http/src/server.ch:388-392` (`release_connection`) and
  `server.ch:378-384` (`try_reserve_connection`) dereference
  `self.inflight` — an `Arc<Mutex<uint>>` — through that raw pointer.
* `lang/libs/http/src/server.ch:513-604` — `serve_iocp` returns as soon as the
  accept loop observes `stopping`. It never unregisters sockets, drains the
  completion port, cancels pending `WSARecv`, or closes/frees the `cp`
  allocation; every `AsyncContext` callback still holds `selfp`
  (`server.ch:563-600`).
* `lang/libs/net/win/iocp.ch:90-108` — `CompletionPort::poll` invokes those
  callbacks inline on pool workers, including during the server's own teardown.
* `lang/libs/std/src/concurrency/threadpool.ch:363-377,435-448` —
  `ThreadPool::delete` joins workers, but it does not drain IOCP completions,
  so a callback can call `release_connection()` after the `Server` is destroyed.

`--emit-c` output confirms the faulting function has exactly two callers,
`try_reserve_connection` and `release_connection`, both loading
`server->inflight` and then `Arc::get` (`tests/build/Translated.c:103166-103208,
98664-98679`). The generated `is_running`/`shutdown` paths use a *different*
Arc instantiation (`Arc<Mutex<bool>>`, `...3ed23381dad8`), so those are not
the faulting path.

The proper fix must be upstream: make the serving `Server` heap-owned with a
lifetime that outlives every callback, and drain/cancel the completion port
before returning from `serve_iocp`. That is outside the permitted scope here.

### Workarounds measured (none gives a clean 15/15)
Each alternative was built with `--no-cache` and run repeatedly:

| Change | Result |
|---|---|
| Baseline | 3/12 runs failed (136/136/137) |
| `--serial` (runner flag passed to `tests.exe`) | 6/12 failed — not a fix |
| RAII guard joining the `Thread` from `serve_async` at test-scope exit | 3/15 failed; one run stalled 182 s waiting on a join — not a fix |
| `cfg.worker_count = 1u` in all 126 test configs | 13/15 failed (and a different fault address) — worse |
| Make all 379 `stop.shutdown()` calls no-ops | 1/12 failed — reduced but not eliminated |
| Make all `underlayer_db::close` calls no-ops | 3/12 failed — no effect |
| Run all 138 tests one-per-process via `--test-names` | 1/276 test invocations failed — still nonzero |
| `@test.retry(4)` on all 138 tests (runner retries crashed children) | 1/15 runs failed — hides, does not fix |

Because the residual failure survives every in-repo variation, this is recorded
as an upstream defect rather than claimed fixed. Final clean-machine gate on
the shipped tree (`tests-final-diag.exe`, 15 consecutive runs): **2/15 runs
still failed** — run 9 reported 138/138 but emitted the Arc runtime error from
a child exiting after it had reported success; run 10 reported 137/138 with
the same error. The other 13 runs were 138/138 with no runtime errors.

### In-repo change applied
`tests/src/page_html_test.ch` — `test_review_page_has_html` used port 19971,
which `account_bridge_test.ch` also uses. With parallel child processes that
makes this test's `bind()` fail independently of the page under test. It now
uses the previously unused port 19998. This is a separate, deterministic test
bug found during the investigation; it does not address the Arc lifetime race.

**Next action:** assign an owner upstream (`lang/libs/http`) to implement the
drain + heap-owned lifetime fix, then re-run the 15x gate above.

## 5g. Health alerting, on-call and web analytics (B2, 2026-11-27)

**Status: configuration and decision recorded; the alert and the named human are
founder actions. No alert is live and no GA4 stream was created by this work.**

- **Named on-call owner:** `TBD — founder to name`. This is a placeholder, not an
  operational control. The same placeholder is used for H6's snapshot owner in
  §4; both must be replaced with a human before EC2/EC15 can be called true.
- **Alert rule (to apply in Cloud Monitoring):**
  - Resource: the Cloud Run revision serving `underlayer.wiqis.com`.
  - Probe: `GET https://underlayer.wiqis.com/api/health` every **60 s**, from at
    least two regions. Expected: HTTP **200** *and* JSON `status == "ok"` *and*
    `version == "0.1.0"` (the unchanged client contract).
  - Trigger: **2 consecutive failed probes** (≥120 s of failure). Severity P1 →
    page the named owner. A single isolated failure is a signal, not an incident.
  - Second signal: 5xx ratio **> 1 % over 5 minutes**, or any `SQL FAILED` /
    `database is locked` line in Cloud Logging → same owner. `X-Request-Id` and
    the `[request]` line in §5a give the correlation key to quote in the page.
  - Recovery: 5 consecutive healthy probes → auto-resolve, but the incident
    still gets a written note in the decision log.
- **Incident runbook — exact path:** `docs/deployment.md#5g-health-alerting-on-call-and-web-analytics-b2-2026-11-27`.
  The runbook is this subsection until a dedicated `docs/incident-runbook.md` is
  created by the owner; steps, in order:
  1. Acknowledge the page; record the time, the failing region(s) and the
     `X-Request-Id` from the Cloud Logging `[request]` line.
  2. Re-probe `GET /api/health` by hand. If it answers, check whether the alert
     was a transient region failure before changing anything.
  3. Run `py -3 tools/release_probe.py https://underlayer.wiqis.com` — this is
     the **health identity check**, not a liveness replacement. It verifies the
     deployed payload still matches the recorded commit/compiler pin (§4 H5) and
     is expected to fail until the founder deploys a release build with the four
     `UL_BUILD_*` values. A 200 with a two-field payload means "healthy but
     unverified provenance", not "wrong service".
  4. Check the last deployment digest and whether `DATABASE_URL` still points at
     the durable mount (§4 H6). If `/data` is not mounted, a recent revision swap
     has lost writes — do not restart again before taking a snapshot.
  5. Verify single-instance state (§5h). A second instance on the same SQLite
     file is a FATAL config, not a scale path.
  6. Mitigation: roll back to the previous binary digest from H5 (§4), restore a
     snapshot into a **staging** path first, and re-run `/api/health` plus one
     account action. Never restore underneath a running process.
  7. Close out: write the date, root cause, digest, RPO/RTO and owner into
     `Docs/decisions.md`; link the log. Company rule: never push or deploy from
     an agent session.

**Decision awaiting the founder — W4-1 web GA4 streams.** The company
`Docs/firebase-telemetry-plan.md` W4-1 asks for GA4 web streams on
`underlayer.wiqis.com` (and `timeline.wiqis.com`) with consent-aware gtag and the
same event names as Android. This is **separate from §6.10**, which ruled learner
email/I12 negative; that ruling does not dispose of GA4. No stream, gtag snippet
or web event implementation was added here — that is a founder/owner decision on
whether web analytics is wanted at all, and, if yes, which property and consent
mechanism. The authoritative decision entry belongs in `Docs/decisions.md` and is
owned by the founder/coordinator, not by this agent. H10 (web error reporting)
depends on a W4-1 ruling; do not pre-empt it.

**H8** is inventoried in `docs/secrets.md`: the Dockerfile build token is now a
BuildKit secret mount, and no secret literal is tracked. Docker's daemon is
unavailable on this machine, so `docker history` / image-scan verification and
the staging rotation are founder actions, not claimed checks.

## 5h. Single-instance enforcement (H1, 2026-11-27)

**Status: documented and tooled; the Cloud Run setting itself is a
founder console action. No production change was made.**

B3 measured 40/40 concurrent writes through one `SQLITE_OPEN_FULLMUTEX` handle.
That is safe for **one process only**. A second instance gets a second SQLite
file and the fleet silently diverges; it must never be treated as a scale path.

Cloud Run settings to apply (owner: **TBD — founder to name**; a named human is
required before EC5 is true):

```bash
gcloud run services update underlayer --region <region> \
  --max-instances=1 \
  --min-instances=1
```

- `max-instances=1` is **mandatory**. Any deployment with `max-instances > 1`
  (or no cap that allows scale-out) is a FATAL config until a durable shared DB
  exists; B4's remote backend is unimplemented and FATAL-refused at startup.
- `min-instances>=1` is recommended: with `min-instances=0` a cold start creates
  a new container and a new empty `/data` file, which looks healthy while losing
  the previous instance's writes. It does not replace the H6 volume check.
- Record the applied values, the revision and who applied them here **after**
  the founder runs the command. `gcloud` is not installed on this machine, so no
  deployed value was measured.

**Two-client consistency probe recipe** (tool:
`tools/instance_consistency_probe.py`):

```bash
# Local / disposable base only. One throwaway registration + two logins, no
# progress writes; two independent session tokens for the SAME learner.
py -3 tools/instance_consistency_probe.py http://127.0.0.1:9032 --disposable

# Or supply two existing tokens (zero writes):
py -3 tools/instance_consistency_probe.py http://127.0.0.1:9032 \
    --token-a TOKEN_A --token-b TOKEN_B
```

Each round reads `GET /api/auth/me` and `GET /api/progress` with both tokens and
requires byte-equivalent normalised JSON across clients and across all 10 rounds.
A `*.wiqis.com` base is refused unless `--founder-approved` is passed; this
agent did **not** run the probe against the deployed service. Token values are
never printed (only an 8-hex fingerprint). `--selftest` proves a drifting stub
is caught. Local run on 2026-11-27 against the disposable `build/b5b-verify.db`:
10 rounds × 2 clients × 2 endpoints identical; production refusal exit 2.

## 5i. Play Data Safety (F0) — founder action, NOT filed

**Status: the legal pages are updated; the Play Console declaration is not.**
No agent can sign in to Play Console or attest to data handling on the
founder's behalf, so this section records the work rather than claiming it.

- **App:** `com.wakaztahir.learnpythonapp` (frozen application id — do not
  rename it, including in this declaration).
- **Owner:** `TBD — founder to name`. Placeholder, not an attestation.
- **What the declaration must match (measured from the served app, not invented):**
  - Sign-in is embedded from `account.wiqis.com`; Google sign-in may be used.
    The account service handles credentials; Underlayer receives an account
    identifier and keeps learning data in its own database.
  - An HttpOnly session cookie is set on sign-in; local storage keeps a legacy
    token mirror for API/offline callers and display preferences.
  - Learning data collected: lesson views, exercise attempts, review ratings,
    notes, bookmarks, study plans, streaks.
  - Payments: none are live today. If a course pass is introduced, Paddle is
    merchant of record (`Docs/profitability-plan.md` P2-01); Underlayer keeps
    only entitlement status and a receipt reference, not card data. Refund
    revokes entitlement on the next request (P2-04).
  - The live `/privacy` and `/terms` pages are re-dated 2026-11-27 and are the
    public wording the declaration should point at.
- **Founder steps:** sign in to Play Console → the app's **Data safety** form →
  declare the categories above accurately (including whether data is encrypted
  in transit and whether it is shared with the account service / Paddle) →
  save and submit with the next release. Record the submission date and the
  named owner in `Docs/decisions.md` when done.
- **Do not claim EC3/EC10 "Data Safety filed" until that log exists.**

## 5j. FSRS persistence, served specimen downloads and /support (2026-11-28)

Measured against a freshly built debug binary on a fresh port (9044) and a
throwaway SQLite file, not against source alone.

- **G3 — FSRS parameters are persistent.** New table `fsrs_params(learner_id
  PRIMARY KEY, params_json, target_retention, daily_review_cap, updated_at)` is
  created in `repository/src/schema.ch`; `repository/src/fsrs_params.ch` owns the
  load/save. `web/src/handlers_settings.ch::load_effective_fsrs()` is the ONE
  read path; `handle_fsrs_optimize`, `_reset`, `_import` and the new
  `POST /api/fsrs/params` all write the row, `handle_fsrs_export` reads it.
  `web/src/handlers_review.ch` (submit + due) and `learning/src/session.ch`
  consume it. `/api/review/due` now treats a card as due when its FSRS
  retrievability is below the learner's target, bounded by the daily cap;
  measured on a seeded throwaway DB: **21 due at 0.90 → 4 due at 0.85**, and the
  same count/retention after a fresh login. Export → import round-trips byte-for-byte;
  a malformed import answers `400 {"error": ...}`; optimise with <10 reviews
  answers `400 need at least 10 reviews for optimization`. Additive JSON only.
  **One-line change still needed in the parallel agent's
  `web/src/handlers_exercises.ch` (line ~214): replace
  `var params = underlayer_learning::init_fsrs_params()` with
  `var params = underlayer_web::load_effective_fsrs(db, &learner_id).params`
  (a local copy may be needed because Chemical rejects a field access on a
  temporary struct value).** That file was not touched here.
- **I5 (route half) — specimen downloads are served.** `app/main.ch` registers
  `GET /courses/:course/assets/samples/:file` BEFORE the `/courses/*` catch-all.
  The handler validates the raw segments against `[a-z0-9-]+` first, rebuilds
  the filename as `<id>-specimen.(zip|json)` from the validated id, and never
  passes a caller-controlled path to `path::Path`. Measured: ELF zip 200 with
  `application/zip`, `Cache-Control: public, max-age=3600`, SHA-256 equal to disk;
  `..`, `%2e%2e`, `%2f`, `%5c`, absolute and null-byte attempts all 404. The
  `specimen_link_check.py` disk + download half is 33/33 bundles and 33/33
  downloads. **`--require-served` is still NOT green**: 362 served landings and
  lessons contain no `data-specimen-link` attribute. Those links belong to
  `content/src/*` (course landings and the shared lesson renderer), which this
  package does not own; the six landing files that do carry the attribute are
  not the renderers the served pages use. The route defect is fixed; the link
  insertion is a separate, content-owned work item.
- **I11 — `/support` is live.** Server-rendered with supported channels, a named
  owner placeholder (Waqas Tahir; duty operator from the H9 allow-list when it
  exists), a published two-business-day response target and
  `mailto:support@wiqis.com`. One support link is emitted by the shared
  `render_support_footer()` called from `web/src/nav_bar.ch`, so pages that draw
  the shared web nav get exactly one. `tools/support_link_check.py` is green
  (5/5 public pages, 3/3 negative plants, non-local bases refused). Known gap:
  `/privacy` still says "Privacy questions can be raised through the Help page"
  rather than naming `support@wiqis.com`; `pages_legal.ch` is F0-owned and was
  not edited. The checker reports this as a visible warning and fails on it
  with `--require-privacy-channel`.

## 5k. Operator identity, retention, flags and the H9–H17 gates (2026-11-28)

Built to `build/h9-h17-underlayer-v2.exe`, served on fresh ports **9060**
(no allow-list), **9062** (operator allow-list) and **9064** (both rollout flags
on), each with a throwaway SQLite file. No deploy, push or commit.

- **H9 — operator identity.** `UL_OPERATOR_IDS` is a comma-separated allow-list
  of stable identities (local learner id, `account_user_id` or email), read
  from the environment by `core/src/config.ch` and compared with a
  length-independent, constant-time loop. `session_guard.ch::require_operator`
  resolves the caller from the session it already trusts — there is no
  `role` column and no client-supplied operator flag. All five previously
  refused routes now work for an allow-listed operator and still answer 401
  anonymous / 403 normal learner: `GET /api/feedback/admin`,
  `GET /api/feedback/admin/reports`, `PUT /api/feedback/:id/status`,
  `POST /api/exercises/import`, `POST /api/exercises/seed`. Every successful
  action writes `audit_log` with `actor`, `request_id`, action and peer ip;
  two additive columns were installed by a conditional migration. With the
  operator token, `tools/feedback_triage.py --list --mark-fixed … --db …`
  listed one pending item, marked it `fixed`, and verified 10 audit rows with
  actor+request_id and none incomplete. The two-account regression on 9060:
  normal learner 403 on all three admin routes, anonymous 401, B cannot read
  A's feedback message or id, A can. No admin UI and no Admin/CMS ticks.
  Limitation: when a caller omits `X-Request-Id`, the audit id is freshly
  minted and does not equal the access-line id; the triage tool always sends
  the header, so the rehearsed rows correlate exactly.
- **H16 — retention.** Startup is DRY-RUN and logs counts from
  `repository/src/retention.ch` (measured on 9060: all zero on a fresh DB).
  Applied sweeps are bounded to 200 rows/table and are only runnable by the
  explicit tool against a disposable DB. `tools/retention_check.py` verified
  5 orphan tables + expired tokens/sessions + aged login/audit rows are
  counted and removed while the valid learner and its FSRS params are intact.
  **The 152 historical orphan rows were not touched and are a founder
  decision before any production cleanup.**
- **H17 — flags.** `UL_PAID_GATING_ENABLED` and `UL_LEARNER_SURFACE_V2`
  default OFF, are checked at the `/api/health` route entry and emitted as
  data attributes on the sign-in UI entry point, and were rehearsed with no
  rebuild (9060 off/off vs 9064 on/on). Full evidence, the H5 rollback target
  and the founder-only Android track steps are in
  `docs/h17-rollout-rehearsal.md`.
- **H11 / H13 / H15** evidence and exceptions are recorded in
  `docs/h11-embedded-signin-proof.md`, `docs/h13-concept-identity-migration.md`
  and `docs/h15-performance-budget.md`. H15 is **RED** on two owner-signed
  defects (render-blocking font stylesheet, one 420 px CLS reading) and is
  wired into the nightly job only — do not mark it green.

New local-only gates (all refuse production URLs/DBs): `feedback_triage.py`,
`auth_shape_check.py`, `concept_migration_check.py`, `retention_check.py`,
`perf_budget_check.py`. Each has a negative plant. The nightly CI job runs
them against its own disposable DB; no checker, CSP directive, rate limit or
existing CI step was weakened, and no new `unsafe-*` was added to the CSP.

## 6. Still open (do not mistake these for done)

1. **CSP externalisation: step 1 shipped 2026-11-27; the policy is NOT
   tightened. The "no CSP" claim is historical (corrected 2026-11-26).** A live
   probe returns
   `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://storage.googleapis.com; connect-src 'self' https://account.wiqis.com; frame-src https://account.wiqis.com https://accounts.google.com; form-action 'self'; base-uri 'self'; object-src 'none'`
   (plus HSTS `max-age=31536000`). **Byte-for-byte unchanged by B5** — the
   `frame-src`/`connect-src` account+Google entries are load-bearing and were
   not touched.

   What changed: the pre-paint theme boot on HTTP-served brand-shell pages
   (`/courses`, `/help`, …) now loads from the same-origin blocking asset
   `/assets/theme-boot.js`, pinned with
   `integrity="sha384-+gwYSbETg+BseeAs0LJMGgeg+pDg1DdV59E7dJ0v+GH9CookguKFp6Nw5IFZ8dcH"`.
   The asset is served by one explicit route ahead of the `web::App` catch-all;
   its JS bytes and the hash live in `content/src/theme_boot.ch` and are checked
   against `web/src/responses.ch` by `tools/theme_boot_hash_check.py --selftest`
   (and, with a live base, by the same tool without the flag).

   **Why the hash is in the SRI attribute and not in `script-src`:** a CDP drive
   on 2026-11-27 first added the hash to `script-src` and measured **33 CSP
   violations** (`script-src-elem`/`script-src-attr`, "inline") across
   `/courses` (3), a lesson (28) and `/help` (2). Under CSP3 a hash or nonce
   source makes the browser IGNORE `'unsafe-inline'`, and the `#html`/`#css`/
   `#js` macros emit inline blocks by the thousand. So the hash in the policy
   would break the product, not tighten it. It was reverted in the same change.

   **What is still open:** (a) every inline script/style emitted by the macros
   must be externalised or individually hashed before `'unsafe-inline'` can be
   removed; (b) lesson pages are also pre-rendered for `file://`, where an
   absolute asset URL does not resolve — they keep the inline boot, and a
   portable asset-path strategy is needed before they can move. No full CSP is
   claimed. Browser evidence after the reverted policy: zero
   `securitypolicyviolation` events on `/courses`, a lesson and `/help`, with
   `wiqis-theme=dark` present at first `<body>` (`tools/theme_boot_csp_probe.py`);
   `theme_check.py` 56/56 static and 61/61 with `--browser`.
2. **SQLite concurrency — RESOLVED 2026-11-27 (B3, founder ruling §6.2).** The
   one handle is now opened with `SQLITE_OPEN_FULLMUTEX`
   (`database/src/main.ch`), so the C library serialises all 12 workers.
   Re-test on a disposable DB: **40/40 registrations returned a session token,
   40/40 distinct rows stored, `integrity_check ok`, zero `SQL FAILED` /
   `database is locked` lines** (`build/b3-concurrent-result.log`,
   `scripts/sqlite_concurrency_probe.py`). The **single-process ceiling is
   accepted explicitly**: H1 must keep `max-instances=1`; a second process on
   the same file is a FATAL config, not a scale path. No connection-per-thread
   pool was added — with a serialised handle it would create a second source
   of truth without buying concurrency.
3. **No remote database backend.** See §1. Scaling out needs it, and it does not
   exist.
4. **No deployment automation, rollback automation or post-deploy monitoring**
   (checklist 15.4.3–15.4.7). The founder deploys by hand.
5. **CI limits — updated 2026-11-26; see §2.** One platform (`windows-latest`),
   no browser in CI, and the `helpful_dedupe_check.py` write probe needs a
   disposable database. These remain true. The old "no `@test` suite" limit is
   **fixed**: the suite runs in CI (138/138) alongside six source gates and
   the nightly live corpus (see §5c), and the compiler is provisioned in the
   job. The browser CDP drive is still not in CI.
   What is still unverified here is a *GitHub-hosted runner* execution, not the
   command sequence.
6. **Non-vacuity plants (updated 2026-11-26; H4).** The theme plant was
   repaired in commit `cb47c27` (it no-ops `render_theme_boot_js`) and
   re-verified on a seeded copy: control `theme_check: ALL 56 CHECKS PASSED`,
   planted build failing 7/56 with the named pre-paint boot checks; see
   `build/a4-plant-verify.log`. The `check_lesson_pager` plant was **stale**:
   the replacement string was the buggy form, so it was a no-op and the
   "planted" checker still passed. It is now reversed to plant the real defect
   (`subview(after, src.size() - after)`, a LENGTH where subview takes an END
   INDEX), and the negative case must name `truncated` **and** print a
   `CHECKS FAILED` summary; a connection-reset traceback is not a named
   failure. Do not re-repair either plant.
7. **H5 release provenance — deployed values not yet measurable.** The code and
   local verification are in place (§4 H5), but the deployed service still
   answers the two-field health payload. Recording a real deployed rollback
   digest requires a release deploy with the four `UL_BUILD_*` inputs — **founder
   action**; see §4. `tools/release_probe.py` is expected to fail against the
   current deployment.
8. **H6 production durability — unverified.** The image uses an ephemeral
   filesystem and declares no volume; whether `/data` is mounted on Cloud Run
   is founder-console state (§4 H6). The local staging restore drill passed,
   but no production snapshot schedule or named owner exists yet, so no
   production RPO/RTO is claimed. If no durable mount exists this becomes P0.
9. **H7 deployed SIGTERM drill — not run.** Upstream has a stop handle but no
   signal path; our path is verified locally with SIGBREAK on Windows
   (§5e). A Linux/Cloud Run SIGTERM drill after deploy is a **founder action**.


## G1/G2/G4/G6 — local verification (2026-11-28)

Built to a new binary `build/g1g2g4g6-underlayer.exe` and served on a fresh
port **9045** with a throwaway SQLite file. No deploy, push or commit was
performed.

New same-origin routes (all registered before the `web::App` catch-all, so
`deliver_with_learner` applies CSP, nosniff, HSTS, request id, ETag and gzip to
them): `GET /onboarding`, `GET /api/onboarding/diagnostic`,
`POST /api/onboarding/score`, `GET /today`, `GET /api/today`,
`POST /api/today/plan`, `POST /api/today/complete`, `POST /api/review/start`,
`POST /api/review/energy`, `GET /manifest.webmanifest`, `GET /sw.js`,
`GET /icons/:name`. H3's header wrapper was not changed and the CSP was not
weakened; the manifest and worker contain no third-party or GitHub Pages URL.

The two additive tables (`onboarding_state`, `review_energy`) are created by
`underlayer_web::init_g_tables` at startup with `CREATE TABLE IF NOT EXISTS`.
Both are cleared by the existing account/category deletion handlers, so
`security_check.py` stays at 73/73.

**Verification performed:** `tools/g_features_check.py` 46/46 with 4/4 in-memory
negative plants; all served checkers green (journey 364/364, theme 56/56,
pager 35/35, dedupe 12/12, bridge 3/3, security 73/73, SEO 372/372, graded
banks 346/346, quiz parity 329/329, explanation 346/346, landing 33/33,
specimen bundles 33/33, support link); `tests.exe` 138/138.

**Browser/CDP drive (Chrome, localhost:9045):** all seven onboarding steps
were clicked through in both the diagnostic and skip paths; a correct-answer
run placed the learner at ELF `symbol-table`, while skip and an all-wrong run
placed them at `bytes`. `/today` with six due items and a 15-minute goal
rendered three reviews plus one six-minute lesson and recorded the day.
On `/review`, choosing low-energy + 5 minutes persisted those values and the
break panel appeared only after the 80% point. The service worker registered
and cached the visited lesson; with CDP offline the lesson and its in-page quiz
still worked, progress was queued in localStorage, and reconnecting replayed it
through `/api/progress/sync` (queue emptied, rows present in
`concept_unit_progress`). "Download this course" grew the worker cache from 16
to 40 entries.
