# Production hardening — 2026-11-26

Scope: `Web/underlayer` only. Every number below is a measurement against a
running server or a file on disk, not a claim from a document. Servers on ports
9000 and 9001 were left running and untouched; new builds were written to new
binaries and run on 9002/9003 with **copies** of the live database.

## 1. Theme checker reconciliation

**Before.** `py -3 tools/theme_check.py http://localhost:9001` → `theme_check:
11 of 17 CHECKS FAILED` (exit 1), with 12 distinct failure lines: eight pages
"reads the saved theme at all", "the pre-paint script is in <head>", "the nav
reads the same localStorage key", and "/login: declares color-scheme in <head>".

**Diagnosis — checker staleness, not a product flash.** Served HTML on 9001:

```
/courses head @643:  var KEY = "wiqis-theme"; ... apply(get());
/courses head @2115: (function(){var g=window.$wiqisThemeGet; ... getItem('wiqis-theme') ... })();
/courses head:       <meta name="color-scheme" content="light dark">
/courses body @63718: function getTheme(){ ... getItem('wiqis-theme') ... }
```

The checker hard-coded `localStorage.getItem('theme')`. That key does not exist
anywhere in the product. The brand shell (brandlib `WiqisTheme`) emits a
pre-paint script into `<head>` that resolves `wiqis-theme` against
`prefers-color-scheme`, calls `apply(get())` synchronously and publishes
`$wiqisThemeGet`/`$wiqisThemeSet`; underlayer's own small boot script delegates
to those globals or resolves the same key itself on a lesson page. The script is
in the head, before first paint. The reported flash was the checker reading an
old contract.

**Lesson exemption was also stale, in the opposite direction.** The old check
"a lesson page does NOT read the theme in `<head>`" passed only because the key
had changed. `content/src/theme_boot.ch` now emits the boot on **every** page,
lessons included (the source comment says so). What a lesson is genuinely exempt
from is the *brand shell*: it has no `WiqisTheme` IIFE and no nav `getTheme()`,
but it does carry the small boot, its navbar and the color-scheme meta. The new
checker asserts that real distinction instead of a false one.

**Auth pages.** `/login` and `/register` call `WiqisTheme(page, false)`: they
deliberately ignore a stored choice, so they have no boot script, no meta and no
nav getTheme. The brand head script sets `el.style.colorScheme` inline, which is
the equivalent frame guarantee. The checker asserts that rather than demanding
a meta those pages intentionally omit.

**After.**

```
py -3 tools/theme_check.py http://localhost:9001 --browser
  theme_check: ALL 61 CHECKS PASSED                     (exit 0)
py -3 tools/theme_check.py http://localhost:9002
  theme_check: ALL 56 CHECKS PASSED  (1 optional browser check skipped)   (exit 0)
```

Live browser proof (Playwright driving the system Chrome with an init-script
MutationObserver that samples `<html>` when `<body>` first appears):

```
localStorage['wiqis-theme']='dark'  -> at first body: dark=True, colorScheme='dark'
                                       data-theme='dark', html.dark still set
localStorage['wiqis-theme']='light' -> dark class cleared on load
```

**Non-vacuity proven directly** by calling the checker's own `split_head` +
`brand_script` helpers on synthetic HTML:

```
script in head -> detected        moved to body -> NOT detected (fails check)
missing        -> NOT detected    stale key 'theme' -> NOT detected
no apply(get()) -> NOT detected
```

No lesson, nav or theme source file was changed — the defect was entirely in
the checker.

## 2. CI workflow

**Before.** No `.github/workflows` directory. `docs/deployment.md` contained a
YAML *diagram* of a build-and-deploy pipeline that did not exist (audit §7.1).

**After.** `.github/workflows/ci.yml`, a verification-only job:

- triggers: push, pull_request, workflow_dispatch (with `compiler_root` input);
- compiler from `inputs.compiler_root || vars.CHEMICAL_ROOT`, explicit failure
  if neither is set;
- `TCCCompiler … chemical.mod -o build/underlayer-verify.exe -bm-modules --no-cache`;
- `bash scripts/build_static.sh elf --quiet`;
- server on a Python-socket-chosen free port with a disposable DB;
- endpoint matrix + four checkers; server stopped in an `always()` step;
- `permissions: contents: read`; no deploy, no publish, no push, no secrets.

`py -3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` → YAML
OK. The constituent commands were exercised locally (see §3–§5), but **the
GitHub Actions job itself was not executed on a runner** — that needs a repository
with a `CHEMICAL_ROOT` variable and a Windows runner, which only the founder can
provide. The workflow is honest about this in its header: single-platform, no
browser, no `@test` suite, and a write probe that must run on a disposable DB.

`docs/deployment.md` was rewritten: the auto-deploy claim, the Turso-as-default
claim, the Tigris/Fly.io stack and the aspirational CI YAML are gone; manual
deployment, local SQLite, the verification-only workflow and the backup/restore
procedure are now described as they are.

## 3. Backup tooling

**Before.** No script copied or verified the database (audit §7.5).

**After.** `tools/backup_db.py` — stdlib `sqlite3` `backup()` API, source opened
read-only, `PRAGMA integrity_check` on source and copy, timestamped output,
temp-file + rename, no overwrite without `--force`.

```
py -3 tools/backup_db.py <tmp>\source-copy.db <tmp>\backups
  source 647,168 bytes, integrity_check ok
  dest   <tmp>\backups\source-copy-20261126-143508.db
  backup integrity_check ok (158 pages), 647,168 bytes in 0.06s   -> exit 0
py -3 tools/backup_db.py <tmp>\source-copy.db <existing backup>
  FAIL -- destination exists (use --force)                        -> exit 1
… --force                                                         -> exit 0
corrupted copy (128 bytes of X at offset 8192)
  FAIL -- DatabaseError: database disk image is malformed          -> exit 1, no file
```

The live `underlayer.db` was never used as a source; a byte-for-byte copy in a
temp directory was. Restore procedure is documented in `docs/deployment.md` §4.

## 4. Rate-limit retention

**Before.** Audit §7.6 listed `rate_limits` as unbounded. The checklist already
records 2.2.64 as done: `repository/src/schema_migrations.ch::purge_expired_rate_limits`
deletes rows older than two 5-minute windows at startup, called from
`repository/src/schema.ch`. `ensure_rate_limit_table` in `web/src/rate_limit.ch`
had no caller.

**After.** `web/src/rate_limit.ch` gained `purge_stale_rate_limits`, a single
`DELETE … WHERE window_start < cutoff` with a generous 24-hour retention, called
from `ensure_rate_limit_table`. It is a second net, not a second policy: any row
it deletes is already dead by the limiter's own window reset and by the 10-minute
startup purge. No module-level state.

```
build to build/underlayer-hardening.exe, -bm-modules --no-cache -> exit 0
GET /api/health                                  -> 200
GET /courses/elf/lessons/bytes                   -> 200 (122,008 bytes)
GET /api/courses/elf/lessons/bytes/units         -> 200
9 wrong logins from one IP, empty bucket:
  401 401 401 401 401 401 401 401 429
  9th body {"error":"too many attempts; try again in 120 seconds"}, Retry-After: 120
  rate_limits: one row login|127.0.0.1 count=8
stale row (now-100000s) + fresh row (now), restart:
  before: [('stale|1.2.3.4', …), ('fresh|5.6.7.8', …)]
  after:  [('fresh|5.6.7.8', …)]      <- stale removed, fresh kept
journey_quality_check --workers 8 -> 33/33; theme_check -> 56/56;
lesson_pager_check -> 35/35        (all on the hardening build, port 9002)
```

## 5. Helpful-vote dedupe

**Before** (pre-dedupe binary on port 9002, fresh throwaway learner and review):

```
vote 1/2/3 -> {"ok":true} each
final helpful_count = 3; review_helpful_votes table did not exist
```

**After** (`review_helpful_votes(review_id, learner_id, created_at)` with a
UNIQUE composite key; `mark_helpful_once` uses `INSERT OR IGNORE` and
`ExecResult.rows_affected` as the atomic gate; `course_reviews.helpful_count`
remains the display value):

```
vote 1 -> {"ok":true,"duplicate":false,"helpful":true}    count 1, votes 1
vote 2 -> {"ok":true,"duplicate":true,"helpful":false,    count 1, votes 1
           "message":"already marked helpful"}
vote 3 -> same duplicate response                          count 1, votes 1
second learner's first vote -> duplicate:false             count 2, votes 2
anonymous vote -> 401 {"error":"unauthorized"}
```

Build to `build/underlayer-dedupe.exe` → exit 0. On that build,
`journey_quality_check` 33/33, `theme_check` 56/56, `lesson_pager_check` 35/35.
`tools/helpful_dedupe_check.py` encodes all twelve assertions and passes 12/12;
it is wired into CI against the disposable database. Anonymous 401 and the
existing authenticated routes are unchanged; `app/main.ch` was not edited.

## 6. Exact commands used

```powershell
cd D:\Programming\Wiqis\Web\underlayer
py -3 tools/theme_check.py http://localhost:9001 --browser
# tools/checker_nonvacuity.py was READ (not run) to inspect its stale theme plant

$cc='D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe'
& $cc chemical.mod -o build/underlayer-hardening.exe -bm-modules --no-cache
& $cc chemical.mod -o build/underlayer-dedupe.exe -bm-modules --no-cache

$env:PORT='9002'; $env:DATABASE_URL='./underlayer-test-9002.db'; $env:COURSES_DIR='./courses'
Start-Process -FilePath '...\build\underlayer-hardening.exe' -WorkingDirectory '...\underlayer' -PassThru -WindowStyle Hidden
# 9003 with build/underlayer-dedupe.exe and underlayer-test-9003.db

py -3 tools/journey_quality_check.py http://localhost:9002 --workers 8
py -3 tools/theme_check.py http://localhost:9002
py -3 tools/lesson_pager_check.py http://localhost:9002
py -3 tools/helpful_dedupe_check.py http://localhost:9003
py -3 tools/backup_db.py <copy> <temp-dir>
```

## 7. Remaining open

1. **CSP** — still deliberately absent; inline scripts/styles from the macros
   make a meaningful policy a separate externalisation project.
2. **SQLite concurrency** — one handle behind a 12-thread pool; 40/40 concurrent
   writes survived, but it cannot be *documented* safe without FULLMUTEX or a
   connection per thread, and it caps the platform at one process.
3. **Remote DB backend** — not implemented; the server refuses `libsql://` and
   `https://` URLs at startup. Scale-out depends on it.
4. **CI limits** — one Windows platform (compiler only verified there), no
   browser for the live theme proof, no `@test` suite (compiler-blocked), and a
   write probe that needs a disposable DB. The workflow itself was not run on a
   GitHub runner here.
5. **Stale non-vacuity plant** — `tools/checker_nonvacuity.py::check_theme`
   plants `if(lesson) { return }` in `content/src/theme_boot.ch` and greps for
   "inside <head>". Both were true of the old code; neither is true now. The
   checker was proven non-vacuous by direct helper probes in §1, but that harness
   needs a new plant before it certifies `theme_check.py` again.
6. **Two purge owners** — schema_migrations (2 windows) and rate_limit.ch (24h).
   Harmless today; consolidate into the schema layer when touching startup.
7. **`helpful_dedupe_check.py` is rate-limit-sensitive** — two registers per run
   against one IP means about four consecutive runs before the auth limiter
   refuses it. CI uses a fresh DB, so this only affects repeated local runs.
