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
`workflow_dispatch`. It:

1. checks out the repository with read-only permissions;
2. locates `TCCCompiler` from the `compiler_root` dispatch input or the
   `CHEMICAL_ROOT` repository variable (it never guesses a path from a
   developer's laptop, and fails with an actionable message if neither is set);
3. builds the server with `-bm-modules --no-cache`;
4. builds the ELF static pages with `bash scripts/build_static.sh elf --quiet`;
5. starts the server on a free OS-assigned port with a **disposable**
   `ci-underlayer.db`;
6. runs the endpoint matrix, then
   `tools/journey_quality_check.py`, `tools/theme_check.py`,
   `tools/lesson_pager_check.py` and `tools/helpful_dedupe_check.py`;
7. stops the server in an `always()` step.

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
- **The `@test` suite is not in CI (yet).** `tests/chemical.mod` was unblocked on
  2026-11-26 (A3): it builds with `TCCCompiler tests/chemical.mod -o ../build/tests.exe --no-cache`
  (no `--test`) and runs 138/138 green. The workflow does not invoke it yet — wiring it
  into CI belongs to A2/A5, and until then the workflow verifies the served artifact
  only. That is not the same thing, and this document does not claim it is.

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

1. **No Content-Security-Policy.** Deliberate: the macros emit inline scripts
   and styles by the thousand, so a policy forbidding inline breaks the product
   and one with `unsafe-inline` buys almost nothing. First step is externalising
   the inline scripts.
2. **SQLite concurrency.** One handle behind a 12-thread pool. 40 concurrent
   writes stored 40/40 with no loss in the test performed, but a single handle
   cannot be *documented* safe without `SQLITE_OPEN_FULLMUTEX` or a connection
   per thread, and it caps the platform at one process.
3. **No remote database backend.** See §1. Scaling out needs it, and it does not
   exist.
4. **No deployment automation, rollback automation or post-deploy monitoring**
   (checklist 15.4.3–15.4.7). The founder deploys by hand.
5. **CI limits** — see §2: one platform, no browser, no `@test` suite, and a
   write probe that needs a disposable database.
6. **`tools/checker_nonvacuity.py`'s `theme_check` plant is stale.** It plants
   `if(lesson) { return }` in `content/src/theme_boot.ch`, but that guard was
   removed when the theme boot began covering lessons too, and it looks for the
   old phrase "inside <head>" in the checker output. The checker itself was
   proven non-vacuous directly (missing script, script moved to body, stale key
   and missing `apply(get())` all fail), but the non-vacuity harness needs a new
   plant before it can certify this checker again.
7. **Two owners for the rate-limit purge** (§5). Consolidating them belongs to
   the schema layer; until then the wider sweep is harmless dead weight at
   startup.
