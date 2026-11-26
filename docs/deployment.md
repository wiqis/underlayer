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

There is no Tigris/S3 storage client, no `STORAGE_BUCKET`, and no CDN upload in
this build, whatever older docs said.

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

## 5. Rate-limit storage and retention

Login, register, forgot/reset, the account bridge and the learning-write
endpoints are limited by rows in the `rate_limits` table, not by in-memory
counters: a counter that dies with the process resets on every restart and fails
open with a second process. The limit is 8/5 minutes for auth and 120/5 minutes
for learning writes, keyed by the socket peer address (never `X-Forwarded-For`,
which the caller controls).

Stale buckets are removed at startup: the authoritative purge is
`repository/src/schema_migrations.ch::purge_expired_rate_limits` (two windows),
called from `repository/src/schema.ch`. `web/src/rate_limit.ch` adds a wider,
idempotent 24-hour sweep from `ensure_rate_limit_table`. Both conditions delete
only buckets the limiter already treats as expired, so neither can change a
future decision. Verified on a restart of a copy: a stale row was removed and a
fresh row kept; nine wrong logins from one IP answered `401 ×8` then `429` with
`Retry-After: 120`.

## 6. Still open (do not mistake these for done)

1. **CSP externalisation is still open — the "no CSP" claim is historical
   (corrected 2026-11-26).** At the time this list was written the site sent no
   CSP; a live probe on 2026-11-26 returns
   `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://storage.googleapis.com; connect-src 'self' https://account.wiqis.com; frame-src https://account.wiqis.com https://accounts.google.com; form-action 'self'; base-uri 'self'; object-src 'none'`
   (plus HSTS `max-age=31536000`) on `/courses/elf/lessons/bytes`. It still
   allows `'unsafe-inline'` because the macros emit inline scripts and styles
   by the thousand; tightening it via externalisation remains the open work,
   which is why this item is not deleted.
2. **SQLite concurrency.** One handle behind a 12-thread pool. 40 concurrent
   writes stored 40/40 with no loss in the test performed, but a single handle
   cannot be *documented* safe without `SQLITE_OPEN_FULLMUTEX` or a connection
   per thread, and it caps the platform at one process.
3. **No remote database backend.** See §1. Scaling out needs it, and it does not
   exist.
4. **No deployment automation, rollback automation or post-deploy monitoring**
   (checklist 15.4.3–15.4.7). The founder deploys by hand.
5. **CI limits — updated 2026-11-26; see §2.** One platform (`windows-latest`),
   no browser in CI, and the `helpful_dedupe_check.py` write probe needs a
   disposable database. These remain true. The old "no `@test` suite" limit is
   **fixed**: the suite runs in CI (138/138) alongside five served-artifact
   checkers (`e627de0`, `63b33eb`), and the compiler is provisioned in the job.
   What is still unverified here is a *GitHub-hosted runner* execution, not the
   command sequence.
6. **Non-vacuity plants — theme repaired, pager still open (2026-11-26).** The
   old `theme_check` plant (`if(lesson) { return }` in
   `content/src/theme_boot.ch`, grep for "inside <head>") was genuinely stale;
   it was repaired in commit `cb47c27` to no-op `render_theme_boot_js`, and
   verified on a seeded copy: `build/a4-plant-verify.log` shows the control
   `theme_check: ALL 56 CHECKS PASSED` and the planted build failing 7/56 with
   the named pre-paint boot checks. Do **not** re-repair it. The CI agent also
   reported a remaining `check_lesson_pager` plant-marker issue: the planted
   run in `build/a5-pager-plant.log` exited 1 but did not emit the expected
   `'truncated'` marker (`named_truncated=False caught=False`), and
   `build/a5-pager-plant3.log` ends in a connection-reset traceback instead of a
   named failure. That negative case is therefore **not certified**; it is left
   open rather than silently marked green.
7. **Two owners for the rate-limit purge** (§5). Consolidating them belongs to
   the schema layer; until then the wider sweep is harmless dead weight at
   startup.
