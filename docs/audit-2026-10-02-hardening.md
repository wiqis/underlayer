# Underlayer hardening audit — what shipped, what was broken

**Scope.** Fix what exists. No new page, no new endpoint, no new setting.
**Date.** 2026-10-02
**Method.** Every claim below is a machine check against the running server or a
row count in `underlayer.db`, not an inspection. Where something could not be
fixed, the reason is given.

---

## 1. Account management: it works

The founder's 15 lifecycle checks were re-run at the end of this work, after
every change, and all 15 still pass:

| check | result |
|---|---|
| register | 200 |
| login | 200, 64-char token |
| `GET /api/auth/me` with token | 200 |
| with a garbage token | 401 |
| with no token | 401 |
| logout | 200 |
| `me` after logout | 401 |
| login with a wrong password | 401 |
| duplicate register | 409 |
| register with password `1` | 400 |
| forgot-password | 200 |
| reset-password with a bogus token | 400 |
| verify-email with a bogus token | 400 |
| `DELETE /api/user/account` | 200 |
| `me` after account deletion | 401 |

**Verdict: the authentication lifecycle is correct.** Session tokens are 64 hex
characters from `osrand::random_fill` (a CSPRNG), stored as SHA-256 of the
token rather than in the clear, expire after 30 days, are revoked on logout, and
are revoked wholesale on password reset. `security_check.py` CHECK 9 asserts the
stored form.

**The verdict did not extend to the rest of the account surface.** Two of the
endpoints around it — account deletion and per-category data deletion — took no
authentication at all and did not delete what they claimed to. See §4 F5.

---

## 2. The confirmed hole: passwords were unsalted single-pass SHA-256

### What it was

`web/src/handlers_auth.ch:45` was `sha256_hex(password)`. Proven empirically
before the fix:

```
s1@t.com  54c571aae6a1f21767a11961f25315e3bd22877c6db9758ef2f2e462c98a47e8
s2@t.com  54c571aae6a1f21767a11961f25315e3bd22877c6db9758ef2f2e462c98a47e8
IDENTICAL (UNSALTED): True
```

Unrelated to any rainbow table, that alone leaks which learners share a
password. And a single-pass SHA-256 is a fast hash on purpose — a GPU does
billions per second, so a six-character password falls in seconds. A password KDF
has to be deliberately slow; this one was deliberately fast.

### What is used now, and why that choice

The Chemical tree already ships **`lang/libs/bcrypt`**, a pure-Chemical
crypt_blowfish. So this is not a hand-rolled KDF. Before trusting it, it was
checked against a *different* implementation of the same standard — a fixed
salt, so the answer is deterministic:

```
Chemical  bcrypt::bf_crypt("abcdefghijklmnopqrstuvwxyz",
                           "$2b$06$If6bvum7DFjUnE9p2uDeDu0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i")
        -> $2b$06$If6bvum7DFjUnE9p2uDeDugSm/r4ClComu5mWRI4RIK8QxNtrr8pm

python3 -c "import bcrypt; bcrypt.hashpw(b'abcdefghijklmnopqrstuvwxyz',
                                        b'$2b$06$If6bvum7DFjUnE9p2uDeDu').decode()"
        -> $2b$06$If6bvum7DFjUnE9p2uDeDugSm/r4ClComu5mWRI4RIK8QxNtrr8pm
```

Byte-identical. `security_check.py` CHECK 8 re-derives that comparison on every
run against Python's `bcrypt`, so if the library ever stops agreeing with a
reference, the gate fails instead of the passwords quietly meaning something
else.

**Cost 12** — 2^12 rounds of the expensive key schedule. It is carried *inside*
the stored string (`$2b$12$…`), so raising it later is a rehash-on-login of old
rows, not a migration.

**Self-describing storage.** bcrypt's own format is `$2b$` version, `12` cost,
22 base64 salt chars, 31 base64 digest chars. So there is **no schema change and
no migration**: the algorithm and work factor can be read off the row. That is
the difference between a fix and a debt, and it is why this was safe to do now
rather than never. The founder's note that a bare hex digest "is what made this
unfixable without a migration" is correct, and the new format is chosen so that
it never applies again.

**Constant-time comparison.** `bcrypt::check_password` compares with
`.equals()`, which returns at the first differing byte — that leaks, over a
network, how many leading characters matched. The new code walks all 60 bytes
with `crypto::constant_time_equal` and accumulates the difference.

### Legacy rows: verified, then upgraded in place

An existing row is 64 lowercase hex characters. `verify_password` decides by
content, not by guesswork: a bcrypt string always begins `$2`, the legacy form
never can, and the 64-hex form is additionally checked character by character.

On a successful login where the stored row still verified against the old
scheme, `handle_login` rewrites the row with bcrypt. So:

* a learner created before the fix can still sign in — no account is locked out;
* the fleet migrates itself one real login at a time;
* a **wrong** password never triggers the rewrite (CHECK 7 proves this).

Verified on real rows: before `dbf543f36b30ed38…` → login 200 → after
`$2b$12$1kB.S9HpfgnrGpBfvC2SvuLE.xLJ3qSky8iJzwF0IINjiUUDzg4.e`.

### Proved non-vacuous by reverting the fix

`password_hash.ch` was reverted to the literal pre-fix line (one unsalted
SHA-256, no bcrypt path in `verify_password`), rebuilt, and the check re-run:

```
security_check: 10 of 22 CHECKS FAILED
  FAILED: the two hashes DIFFER (the original defect) -- identical = True
  FAILED: neither hash is a bare 64-char hex digest -- lengths: [64, 64]
  FAILED: stored hash is a bcrypt modular-crypt string
  FAILED: sha256(password) does not appear in either stored value
  ... (6 more)
EXIT=1
```

It reproduces the founder's exact observation (`identical = True`). Restored,
rebuilt: **44/44 PASSED, exit 0**.

---

## 3. What else was broken

### F1 — CRITICAL — SQL injection: full authentication bypass on login

`handle_login` concatenated the `email` field of the POST body straight into a
SQL literal. Proven against the running server, before the fix:

```
POST /api/auth/login  {"email":"x' OR password_hash='ef92b778…","password":"password123"}
  -> 200 {"learner_id":"80fad02d…","session_token":"18332fa28a85fd72…"}

POST /api/auth/login  {"email":"zzz' UNION SELECT id,name,password_hash
                                 FROM learners WHERE email='ctl1@t.com' --", …}
  -> 200 {"learner_id":"80fad02d…","session_token":"0656e6ae…"}
```

A valid session token for another account, with no knowledge of the password.
Same defect, unexploitable-but-real, in `handle_register` (email, name),
`handle_forgot_password` (email), `handle_import_progress`
(`concept_id`/`course_id`/`status`/`type`) and `pages_onboarding.ch`
(`selected_course`).

**Fixed** with `sql_escape` at each interpolation, and covered twice over:
`tools/sqli_scan.py` (static — traces every request-derived value to every SQL
literal) and `security_check.py` CHECK 10 (live — four payload shapes must all
answer 401 with no token). All four now 401.

`tools/sqli_scan.py` reports the one class it treats as safe **by construction**
— anything built by `int_to_string()`, which formats an integer and cannot emit
a character that would end a SQL literal — and says so in its output, because a
scanner that quietly excluded lines would be indistinguishable from one that
could not see them.

### F2 — CRITICAL — a second SQL injection silently destroyed accounts

`exec_sql` frees SQLite's error message and discards it; `query_sql` returns 0
rows on a prepare failure. So a syntax error is indistinguishable from "no rows".

Registering with an apostrophe in a display name made the `INSERT` a syntax
error, and register answered **200 with a live session token**:

```
POST /api/auth/register {"email":"apos@t.com","password":"password123","name":"D'Arcy"}
  -> 200 {"learner_id":"b64c8455…","session_token":"f6fb4f46…"}
GET  /api/auth/me  (that token) -> 404 {"error":"learner not found"}
POST /api/auth/login            -> 401, forever
```

The account existed in the learner's hands and nowhere else. Two more defects sat
underneath: `create_learner` wrote the row **without** `password_hash` and left
the caller to fill it with a second `UPDATE`, so a failure anywhere between the
two left a permanently unloginable row; and the function never checked
`rows_affected`.

**Fixed**: `create_learner_with_hash` writes the hash with the row, escapes every
value, and returns `rows_affected`, which `handle_register` now asserts. Verified:
`D'Arcy O'Neill` registers, `/api/auth/me` returns
`"name":"D'Arcy O'Neill"`, and the learner can log in (CHECK 11).

### F3 — CRITICAL — session IDOR: an anonymous request could drive anyone's review session

Session ids are Unix timestamps (`handlers_review.ch:247`,
`underlayer_core::int_to_string(now)`), so a day's id space is enumerable by
addition. Seven endpoints took that id from the query string and acted on it with
**no auth and no ownership check**. Proven, with no `Authorization` header at all:

```
learner A: GET /api/review/start -> session_id 1790930967, status 'active'
anonymous: POST /api/session/abort?session_id=1790930967
          -> 200 {"status":"ok","state":"aborted"}
learner A's session row afterwards: gone
```

pause, resume, undo, skip and session-detail had the same hole.

**Fixed** with one gate, `web/src/session_guard.ch`, called by all seven. It
resolves the caller the way the rest of the platform does — token, else the
shared `demo` learner — and then requires the session to belong to that learner.
That is deliberately *ownership*, not *authentication*: requiring a token would
have fixed the hole and broken the signed-out review flow, which is a behaviour
change this fix had no business making. Verified: anonymous abort/pause/resume
→ 403, another learner's token → 403, and the owner still gets 200 (CHECK 12).

### F4 — HIGH — account deletion deleted almost nothing, and ran unauthenticated

`handle_delete_account` answered 200 and `/api/auth/me` then answered 401, so
from the outside the lifecycle looked correct. Row counts said otherwise. Three
defects:

1. **`session_items` was never deleted.** The order was
   `DELETE FROM sessions` and *then*
   `DELETE FROM session_items WHERE session_id IN (SELECT id FROM sessions …)`.
   The subquery runs against sessions that are already gone, so it matched
   nothing. Every per-item study record — which concept, what rating, how long —
   survived the account.
2. **Thirteen tables were missing from the list** entirely: notifications,
   learning_streaks, daily_activity, achievements, bookmarks, learner_notes,
   study_plans, certificates, email_verification_tokens, and others. After full
   deletions the database held **53 notification rows, 8 streak rows, 8 activity
   rows and 12 settings rows** belonging to learners that no longer existed.
3. **It required no authentication.** An absent token resolved to the shared
   `demo` learner, so `DELETE /api/user/account` with no header deleted the demo
   account, and `DELETE /api/user/data/all` wiped its progress. Both answered
   **200**.

The code carried a comment admitting defect 2 — *"the list above is hand-written,
which is the actual defect: a new table is invisible to this function until
somebody remembers"* — and had grown to 17 tables by hand and was still missing
half of them.

**Fixed**: one repository function, `repository/src/learner_deletion.ch`, walking
a table **list**, children before parents, returning how many tables it cleared.
The handler reports the number instead of assuming. Verified (CHECK 13, 14):
both endpoints 401 with no token; a throwaway learner with rows in 8 tables
deletes and **no table holds a row for that learner id afterwards** — 25 tables
cleared.

### F5 — CRITICAL — the server aborts on a request sequence

Auditing all 180 routes killed the process:

```
double free or corruption (out)
0x00000000: at ???: RUNTIME ERROR: abort() called
```

and every subsequent route answered "connection refused" — so one abort hides
the answers to the other 175 routes. Under gdb, the abort backtrace:

```
malloc_printerr ("corrupted double-linked list")  -> unlink_chunk -> _int_malloc
  -> _int_realloc -> realloc
  -> std::vector::reserve -> ensure_capacity_for_one_more -> push
  -> underlayer_db::query_sql
  -> underlayer_repository::get_due_review_items
  -> underlayer_web::handle_session_recommendations
  -> http_server::Server::handle_conn
```

Reproducer delivered as `tools/crash_repro.py`, which walks the route list,
checks `/api/health` after **every single request**, and prints the dying step:

```
*** THE PROCESS DIED at step 66 of 700
*** request: POST /api/review/end
*** build/server.log says: free(): double free detected in tcache 2
```

It happens roughly **4 times per full 180-route pass**, and the detection site
moves between `corrupted double-linked list`, `double free or corruption (!prev)`
and `free(): double free detected in tcache 2` — different runs, same failure.

**NOT FIXED.** Reason: this is heap corruption, not a logic error, and the
backtrace names where glibc *noticed*, not where the byte was *written*. Three
things were tried and did not localise it: prefix-bisecting the request sequence
(no single step is responsible — skipping any one of 30 candidates still
reproduces it), hammering each route 30× in isolation (nothing corrupts alone),
and running under gdb with `MALLOC_CHECK_=3` (survives some identical runs, dies
on others — the signature of an overrun). The tool that would settle it is a
memory checker, and `valgrind` needs root on this machine. **This is a remote,
unauthenticated denial of service and should be the next thing worked on.**

`tools/route_check.py` now records a process death as its own finding class and
restarts the server so the rest of the routes are still measured.

### F6 — HIGH — `GET /api/courses/:courseId/lessons/:conceptId` never worked

The route read `segments[1]` and `segments[3]`, but that path starts with
`/api`, so those are the literal words `"courses"` and `"lessons"`. Every lesson
in the product answered **404**. The page route
`/courses/:courseId/lessons/:conceptId` has no `/api` prefix and was correctly
1 and 3 — which is why it was never noticed, and why the fix must not be copied
across. Now `200`. A scan of all 46 parameterised routes found no other
mis-index.

### F7 — HIGH — `GET /api/courses/all` was registered twice

Byte-identical handler, registered at two points in `app/main.ch`. Dead
configuration that reads like a second, different endpoint. Second registration
removed; a duplicate-path scan now reports none.

### F8 — HIGH — 11 platform pages shipped a nav that could not reach search

`/analytics` was the one the founder spotted. Measuring the rest:

* **11 pages had a navbar with no `/search` link**: `/review`, `/progress`,
  `/dashboard`, `/analytics`, `/bookmarks`, `/notes`, `/study-plans`,
  `/achievements`, `/streaks`, `/notifications`, `/certificates` — each a
  hand-copied copy of the nav.
* **`/settings` had no navbar and zero links in its body.** A learner who
  navigated from the dashboard to settings had nothing to click.

`nav_check` caught none of it, because **`baseline_urls.txt` contained 432 URLs
and not one of them was a platform page** — it was 34 course pages plus 398
lesson pages. The checker was green over a corpus that excluded every page it was
most needed for.

**Fixed at the root, not patch by patch.** Thirteen hand-copied navs now call
`render_nav_bar`, which delegates to the one nav in `content/src/lesson_nav.ch`;
their duplicated nav CSS and their duplicate `getTheme`/`setTheme`/`toggleTheme`
were removed with them (two declarations of `function getTheme` on one page is a
JavaScript redeclaration error that would have killed the page's script). The 15
platform pages were added to `baseline_urls.txt`, so the gate now covers them.
**447 URLs, all 200, one nav each carrying `/courses`, `/search`, `/dashboard`,
`/progress`** — up from 432, with 15 more pages and 11 broken navs fixed.

### F9 — MEDIUM — two shipped checkers were measuring nothing

* **`html_balance.py` with no arguments was a silent no-op that always exited 0.**
  It took file paths as `argv` and iterated over an empty list. It was in the
  gate list printing nothing, and every status report that said "html_balance exit
  0" was reporting on an empty loop. It now has a default file set (576 files,
  the same one `bracecheck` uses) and says how many it checked.
* **`bracecheck.py` scanned only `content/src` + `courses/*/src`.** `web/src`
  has 25 files with `#html` blocks and the compiler breaks on a raw brace in a
  `#html` block identically regardless of layer, so "bracecheck exits 0" said
  nothing about the pages between lessons. `web/src` added; still clean.

### F10 — MEDIUM — a destructive POST endpoint with no authentication

`POST /api/exercises/import` inserts caller-supplied questions into the **global**
exercise bank — the content every learner is then graded against — with no auth
check. `POST /api/exercises/seed` and `POST /api/reviews/:id/helpful` are the same
shape. **NOT FIXED, reported:** adding auth to a content-authoring endpoint is a
product decision about who is allowed to write course content, not a mechanical
defect fix, and this brief adds no capability and changes no contract. It is the
highest-value item on the follow-up list.

### F11 — MEDIUM — 46 handlers fall back to a shared `demo` identity when signed out

`if(learner_id.size() == 0) { learner_id = string("demo") }` appears 46 times.
On read paths this is a deliberate design (signed-out pages must still render),
and `route_check` measured **0 cross-learner bleeds** across all 180 routes with
two accounts, so nothing leaks between real learners. But the *write* paths that
used it meant anonymous visitors could write to — and, in two cases, delete —
that shared bucket. The two destructive ones are now fixed (F4). The remaining
ones (`POST /api/goals`, `/api/fsrs/optimize`, `/api/streaks/activity`,
`/api/progress/share|import`) accumulate anonymous writes under one identity.
**NOT FIXED:** changing them alters what a signed-out visitor's progress does,
which is a behaviour change, not a fix.

### F12 — LOW — the 250-line rule is violated in 130 files, not ~20

Measured, not estimated. `web/src/helpers.ch` 1574, `app/main.ch` 1259,
`handlers_review.ch` 898, `pages_analytics.ch` 647, and 124 more including ~100
lesson files. `handlers_auth.ch` was 541 and I grew it, so **I split it** into
`handlers_auth.ch` (lifecycle, 407), `handlers_auth_password.ch` (reset/verify,
194) and `handlers_auth_history.ch` (login history, 59), promoting the three
shared helpers to `public` as AGENTS.md requires. `handlers_data.ch` went 389 →
335 as a side effect of moving its SQL into `repository/`. **The other 128 files
are not fixed** — splitting 128 files, ~100 of them lesson content that 24
`verify_*.py` checkers assert byte-level facts about, is a refactor with a very
different risk profile from hardening, and doing it here would put the course
content at risk for no security or correctness gain.

---

## 4. The full route audit — 180 routes, ~2,500 malformed requests

`tools/route_check.py` (new). For every registered route: does it answer; does it
5xx on 14 garbage bodies; does any error body leak a path, a SQL fragment or a
Chemical type name; and — probed with **two separate accounts**, which one
account cannot do — does it hand learner A's identity to learner B.

```
=== 0. PROCESS ABORTS ===        4    (F5)
=== 1. ROUTES THAT DO NOT ANSWER ===   none: all 180 routes answered
=== 2. 5xx ON BAD INPUT ===            none
=== 3. INTERNALS IN AN ERROR BODY ===  none
=== 4. CROSS-LEARNER BLEED ===          none
=== 5. ANONYMOUS 200s (INFO) ===        86 of 180
```

The 86 are course pages, the health check, search, static files and the demo
pages — public by design, reported as information rather than guessed at.

---

## 5. Course pages and the harnesses

**The 434 course pages are healthy.** `nav_check` covers all 398 lesson pages plus
34 course pages plus the 15 platform pages: **447/447 HTTP 200, one navbar each**.
`link_check` resolves **461 distinct internal links over 3,865 occurrences, all
200**. `progress_check` passes all 43 assertions including the learner journey.

**All eleven checkers are proven non-vacuous** by `tools/checker_nonvacuity.py`
(new), which breaks each claim in a *copy* of the tree and requires a failure,
after first requiring a pass on the real tree:

```
bracecheck       plant a raw { inside a #html block            -> exit 1
nesting_check    plant a .unit-exercises one level too deep    -> exit 1, named
html_balance     plant an unclosed <div>                       -> exit 1, named
link_check       plant an internal href that 404s              -> exit 1
sqli_scan        its own --selftest plants an unescaped append -> +1 finding
security_check   its own --selftest on identical-vs-different  -> ok
route_check      its own --selftest plants a cross-leak        -> detected
nav_check        --expect-nav 0 must pass AND /settings must fail -> 0 / 0 / 1
todo_check       check 2 items by hand                         -> exit 1
music_todo_check check 2 items by hand                         -> exit 1
check_quotes     plant "412.500 ticks/op" in a quoted <pre>   -> exit 1, named

checker_nonvacuity: ALL 11 checkers PASS on the real tree and FAIL when broken.
```

Worth recording: **five of those plants were wrong before they were right**, and
in every case the checker was correct and the test was not — `check_quotes`
legitimately ignores prose decimals, `nesting_check` correctly accepted unit divs
that really were direct children of `.lesson`, and `html_balance` needed its new
default file set before a bare invocation could mean anything. A checker that
fails when nothing is broken is how a checker stops being believed, so each of
those is now a *named* detection (`named=True`), not just a nonzero exit.

---

## 6. Gates

| gate | result |
|---|---|
| build | exit 0 |
| `/api/health` | 200 |
| all URLs in `tools/baseline_urls.txt` | **447/447** HTTP 200 (was 432; 15 platform pages added) |
| `nav_check` | exit 0 — 447 pages, one nav each carrying `/courses`, `/search`, `/dashboard`, `/progress` |
| `link_check` | exit 0 — 461 links, 3,865 occurrences |
| `progress_check` | exit 0 — 43/43 |
| `bracecheck` | exit 0 — now scans `web/src` too |
| `nesting_check` | exit 0 |
| `html_balance` | exit 0 — 576 files (previously a silent no-op) |
| `check_quotes` | exit 0 |
| `js_escape_check` | exit 0 |
| `sqli_scan` | exit 0 — 0 unescaped request text in SQL; `--selftest` proves it can fail |
| **`security_check`** | **exit 0 — 44/44**; exits 1 with 10 failures when the password fix is reverted |
| `checker_nonvacuity` | **exit 0 — 11/11** proven live |
| `route_check` | exit 1 — 4 process aborts (F5). 0 unreachable, 0 5xx, 0 leaks, 0 bleeds |
| `verify_*.py` | **24/24 ALL CONSISTENT** |
| `app/main.ch` line endings | CRLF preserved (1,265 CRLF, 0 bare LF) |

`route_check` is the one gate that exits non-zero, and it does so because the
platform aborts its process, not because of anything a change introduced.

---

## 7. Test-account cleanup

Every account created during this audit has been removed. Twelve accounts were
created by hand plus tooling; **the `learners` table now contains exactly one
row, `learner@underlayer.dev`, which is the platform's own seed.**

How: `security_check.py` deletes each account through the shipped
`DELETE /api/user/account` route and *verifies the row is gone*, on every exit
path including an exception. `route_check.py` and `crash_repro.py` now do the
same. The handful that predated the `security_check` cleanup were removed the
same way; the two whose passwords were created before the bcrypt migration and
so could not be recovered were removed by the same row walk the fixed repository
function performs.

**Left in place, deliberately:** 152 orphaned rows (53 notifications, 30 skill
assessments, 26 login-history, 9 daily-activity, 8 streaks, and others) belonging
to learners that no longer exist. These are residue from accounts deleted by the
*old buggy* handler before this audit fixed it — they are the evidence for F4. They
have no owner and are inert. They were not purged because deleting rows from the
founder's database is his call, not this audit's; the one-line query is in the
F4 discussion if he wants them gone.

---

## 8. What I could not fix, and why

1. **The heap-corruption abort (F5).** Needs a memory checker; `valgrind` needs
   root. Three localisation attempts documented above. Reproducer delivered.
2. **`POST /api/exercises/import` and neighbours write global course content with
   no auth (F10).** Fixing it means deciding who may author course content — a
   product decision, not a defect fix, and this brief adds no capability.
3. **The remaining 128 over-length files (F12).** Splitting ~100 lesson files
   that 24 `verify_*.py` checkers assert byte-level facts about is a refactor,
   not hardening, and it would put the course corpus at risk.
4. **11 pages still have no navbar** — `/login`, `/register`, `/forgot-password`,
   `/reset-password`, `/help`, `/faq`, `/about`, `/terms`, `/privacy`,
   `/shortcuts`, `/components`, `/onboarding`. Each already carries a link home,
   so none is the trap `/settings` was, and putting a full nav on an auth page or
   a legal page is a design decision rather than a defect fix. They are also
   deliberately **not** in `baseline_urls.txt`, because `nav_check` asserts every
   baseline URL has a nav and adding them would fail on a design choice.
5. **The `demo` fallback on non-destructive writes (F11).** Changing it changes
   what a signed-out visitor's progress does.

---

## 9. New tools

| tool | what it does |
|---|---|
| `tools/security_check.py` | 44 live assertions: salted bcrypt, self-describing cost, reference-bcrypt agreement, legacy-row authenticate-and-upgrade, 4 SQLi payloads, apostrophe-account-loss, session IDOR, destructive-endpoint auth, complete account deletion. `--selftest`. Cleans up after itself. |
| `tools/sqli_scan.py` | Static: traces every request-derived value to every SQL literal in the tree. `--selftest` plants one and asserts the count rises by exactly one. |
| `tools/route_check.py` | All 180 routes: answers, 5xx on 14 garbage bodies, error-body leaks, cross-learner bleed with two accounts, process aborts. `--selftest`. |
| `tools/crash_repro.py` | The F5 abort: minimal dying step, preceding requests, server-log evidence, optional gdb backtrace. |
| `tools/checker_nonvacuity.py` | Proves all 11 shipped checkers fail when their claim is broken. |
| `tools/nav_consolidate.py` | `--check` / `--apply` for the nav consolidation. Idempotent. |

## 10. Files changed

Modified: `app/main.ch` (CRLF preserved), `repository/src/learners.ch`,
`web/chemical.mod`, `tools/{baseline_urls,bracecheck,html_balance}`, and 18 files
in `web/src/`.

New: `web/src/{password_hash,session_guard,handlers_auth_password,handlers_auth_history}.ch`,
`repository/src/{session_ownership,learner_deletion}.ch`, and the six tools above.

**Nothing has been committed.** The tree is left for review.