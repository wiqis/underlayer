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


## 5f. Known test-suite flakiness (observed 2026-11-26,Wave 1)
During the I1/I2 verification batch, two of five `tests.exe` runs reported
136–137/138 with `RUNTIME ERROR: invalid memory access` in the upstream
`http::Server::release_connection` / `std::Arc::get`. A fresh rebuild passed
3/3 consecutive runs with 138/138 and no runtime errors. The cause is not
established; do not treat a single green run as proof. The CI summary-line gate
(A2) refuses a partial run, but this flakiness is recorded here so an intermittent
red run is investigated rather than rerun until green. Owner: unassigned —
assign at the next wave kickoff. Upstream `lang/libs/http` is read-only here.

## 6. Still open (do not mistake these for done)

1. **CSP externalisation is still open — the "no CSP" claim is historical
   (corrected 2026-11-26).** At the time this list was written the site sent no
   CSP; a live probe on 2026-11-26 returns
   `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://storage.googleapis.com; connect-src 'self' https://account.wiqis.com; frame-src https://account.wiqis.com https://accounts.google.com; form-action 'self'; base-uri 'self'; object-src 'none'`
   (plus HSTS `max-age=31536000`) on `/courses/elf/lessons/bytes`. It still
   allows `'unsafe-inline'` because the macros emit inline scripts and styles
   by the thousand; tightening it via externalisation remains the open work,
   which is why this item is not deleted.
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
