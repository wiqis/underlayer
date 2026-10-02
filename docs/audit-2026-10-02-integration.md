# Underlayer integration & correctness pass — 2026-10-02

**Scope.** Start from the state the previous audit left the tree in, find what
still does not work, fix it, and close the P1 features that shipped as APIs with
no consumer. No new surface area beyond what the checklist already promised.

**Method.** Every claim below is a machine check against the running server or a
row count, not an inspection. Where a fix could not be verified it is not
claimed as fixed.

---

## 0. The headline

**The committed tree did not compile.** HEAD (`2db7501 updates`) failed at
symbol resolution, so `build/underlayer.exe` on disk was a stale binary from a
build nobody could reproduce, and every status report that said "the server
runs" was describing an artefact left over from before the last commit.

```
[SymRes:link] error: unresolved child 'ok' in parent 'result'
                        at repository/src/notes.ch:112
[SymRes:link] error: only integer / boolean / pointer types can be used as a condition
                        at repository/src/notes.ch:112
[lab] error: failure during symbol resolution in the module underlayer_repository
```

Two defects, both in the last commit: `note_owned_by` checked `result.ok` on a
`QueryResult`, which had no such field, and `update_note`/`delete_note` were
declared `&DbClient` while the database layer takes `*DbClient`.

Fixed. The build now succeeds and every gate below runs against a binary built
from this tree.

---

## 1. A refused query was indistinguishable from an empty one

The previous audit gave `ExecResult` an `ok` field and an `error_message`,
because a statement SQLite *refused* used to be readable as one that *ran* — and
that is how registering with an apostrophe in a display name returned 200 with a
token for a row that was never inserted.

`QueryResult` was left without it, on the same platform, with the same
reasoning broken in the other direction:

```
public struct QueryResult {
    var columns : vector<string>
    var rows : vector<QueryRow>
    var rows_affected : i64
}
```

So a statement that could not be parsed returned zero rows, and every caller
reads zero rows as "no such row". The symptom is quieter than the write path: a
404 is a *plausible* answer, so nothing looks broken, and the failing statement
never appears anywhere the caller can see. `notes.ch`'s ownership check hit
exactly this — it could not tell "not yours" from "could not be parsed".

Now `QueryResult` carries `ok` and `error_message`, the prepare failure logs
SQLite's own message (via `sqlite3_errmsg`, which returns a pointer SQLite owns
and which is therefore copied and **not** freed), and a step error is reported
instead of returning the rows gathered so far as though the query had completed.

One detail worth recording, because it is the kind of thing that produces a
false alarm on every single query: `sqlite3_errcode()` reports `SQLITE_DONE`
(101) for a query that ran perfectly, and 101 is not an error. Asking the handle
whether it is happy therefore reports **every successful query as a failure**.
The first version of this did exactly that and logged 414 phantom failures per
lesson page. The only honest answer is the code the loop actually stopped on,
which is why `last_step` is carried out of the loop.

**Verified:** a deliberately malformed statement is logged and reports `ok=false`;
every normal route is silent.

---

## 2. Four migrations failed on every single start

The previous audit recorded these as "benign" — the rows end up correct — and
deferred them, because the clean fix needs `PRAGMA table_info` introspection and
both schema files were near the 250-line ceiling.

They are not benign, they are **unreadable**. Four lines of log at every boot,
which nobody reads, are the only evidence that a migration is broken; they train
every reader to ignore that logger; and they are the residue of a `CREATE TABLE`
that declares the column and an `ALTER TABLE` that adds it again, which is a
defect in its own right rather than a redundant line.

`repository/src/schema_migrations.ch` asks SQLite whether the column is there
before adding it. On a fresh database: **0 failures**. On an existing one, on
the second start, which is where the old version failed: **0 failures**.

The same commit adds a fourth migration, `learning_preferences.onboarding_completed_at`,
which is the subject of §3.

---

## 3. The onboarding gate could not fire, because it always said `true`

This is the reason P1 7.1.20 was not merely unimplemented but *unimplementable*.

`GET /api/onboarding/check` decided "has this learner onboarded" by asking
whether a `learning_preferences` row existed. Registration itself inserts one —
`INSERT OR IGNORE INTO learning_preferences (learner_id, created_at, updated_at)`
at `web/src/handlers_auth.ch:233` — so **every account has a row from the second
it is created**.

Measured, before the fix:

```
POST /api/auth/register            -> {"learner_id":"be0036…","session_token":"…"}
GET  /api/onboarding/check         -> {"completed":true,"authenticated":true}
```

The endpoint that gates the entire onboarding flow returned `completed: true`
for a learner who had done nothing at all. The flow was reachable only by typing
`/onboarding`.

The obvious next guess — compare `daily_goal_minutes` against its `DEFAULT` of
20 — is equally wrong, because the column *does* default to 20, so a learner who
genuinely picks "20 minutes a day" becomes indistinguishable from one who never
onboarded. The gate would then either never fire or fire forever, depending on a
coincidence. **A DEFAULT cannot be evidence that someone chose something.**

So the answer is an explicit `onboarding_completed_at` timestamp, added through
the conditional-migration path from §2 (NULL means "has not onboarded"; a value
means "onboarded at this time", which also answers "when", something the
inferred version could not). `repository/src/onboarding.ch` owns the query, and
the completion handler records it **unconditionally** — the onboarding page lets
a learner finish without picking a course, so gating on "a course was picked"
would return them to `/onboarding` on every page load and every login, with no
way out.

Measured, after: new account `completed:false` → complete without a course →
`completed:true` → complete with a course → `completed:true` → anonymous →
`{"completed":false,"authenticated":false}`.

---

## 4. `POST /api/certificates` had never worked

`tools/integration_check.py` reported 5 failures around certificates. The cause
is not a test problem:

```
POST /api/certificates   -H "Authorization: Bearer <valid 64-hex token>"
  -> 401 {"error":"unauthorized"}
GET  /api/certificates   -H "Authorization: Bearer <the same token>"
  -> 200 []
```

`auth_get_learner_id` uses the same code for both. So the token was arriving —
instrumenting the handler showed the `Authorization` header present, 71 bytes —
and the lookup still returned empty. Probing the query from inside the handler:

```
[PROBE] auth header: is_none=0 len=71
[PROBE] direct count query: ok=0 rows=0     <-- SELECT COUNT(*) FROM auth_sessions
[underlayer_db] SQL PREPARE FAILED rc=21: bad parameter or other API misuse
```

`SQLITE_MISUSE` from `sqlite3_prepare_v2`. The route was the only one in the
tree combining a **by-reference** `|&db|` capture with an `&raw db` argument:

```
srv.router.add("POST", "/api/certificates", (|&db, &courses_dir|(req, res) => {
    underlayer_web::handle_issue_certificate(&raw db, courses_dir, &req, &raw mut res)
}))
```

Each shape is fine alone and the combination is not: 55 routes capture `&db`
and pass `db` (auto-deref, works); 57 capture `db` by value and pass `&raw db`
(a pointer to the closure's own copy, works); exactly one did both. Changing
the capture to `|db|` makes it answer correctly.

Verified end to end: incomplete learner → 403 with the coverage numbers;
after reading all 24 concepts → a certificate; a second request → the existing
id; and the record itself is now right where it was wrong twice:

```
"course_title":   "Executable and Linkable Format"   (was "elf")
"completion_date": "2026-10-02"                     (was "2026-10-19")
```

The date was computed by hand with a 30-day month and a 365-day year.
`underlayer_core::date_string` has existed in `core/` all along and uses
`civil_from_days`; a second implementation of "epoch seconds to a calendar
date" is a second set of bugs.

---

## 5. Four checkers were asserting behaviour that had been fixed

This is the finding worth carrying forward. Each of these checkers had a
comment explaining what it measured, the comment was true when written, and the
product moved underneath it. All four then failed against a server that was
doing the right thing.

| checker | what it asserted | what is true now |
|---|---|---|
| `integration_check.py` | "the standing proof that the server **does not** check completion: the learner has read ONE concept" and a certificate must appear | the completion gate refuses an unfinished learner. The check failed **when the hole was closed** |
| `integration_check.py` | `GET /api/feedback/concept/:id` leaks every learner's feedback (documented, warn-only) | the endpoint answers 401 unauthenticated. The leak is closed |
| `additional_api_test.ch` ×5 | an anonymous caller gets "200 or 404" from pause/resume/abort/undo/skip | `require_own_session` refuses with **403**. The IDOR is closed |
| `api_test.ch` | anonymous `GET /api/review/start` is **200** | 5.1.19 resolves the learner from the bearer token only. **401** |

A checker documenting a known defect is indistinguishable from a checker that
has gone stale, and only the second one wastes anybody's time. Worse, the first
row is a gate that **fails when a vulnerability is fixed** — which means the
first person to see it red is tempted to make it green by reverting the fix.

All four now assert the secure behaviour, and each says in a comment which fix it
is protecting, so the next reader knows that turning it red means something broke
rather than that a hole reopened. The completion-gate assertion was proved
non-vacuous by disabling the gate: exactly 2 of 105 checks fail, and 0 with it
in place.

---

## 6. The test suite had never built

`scripts/test.sh` was reported as "does not build, and did not before this
work", with two link errors handed over as pre-existing rot. Both were two lines:

* `additional_api_test.ch` called `handle_nav_status` with 3 arguments for a
  4-parameter handler — it grew `courses_dir` when nav-status stopped being
  pinned to ELF, and the test was never updated.
* `pages_test.ch` passed `&raw mut req` to `handle_review_end`, which takes
  `&http::Request`. The asymmetry is real (`handle_review_submit` takes
  `*mut Request` because it calls `read_body`), and the compiler reported it as a
  *missing argument* rather than a type, because `&raw mut` on captured state is
  also the shape it rejects as a mutation in a safe context.

With the build fixed, 8 tests failed — all of them §5's stale assertions. So the
suite's value was not "3 pre-existing errors", it was **zero information**:
nothing in it had run in the time since the security fixes landed. It is now
**136 tests, 136 passed**.

Two things were needed to get there honestly. `tests/src/test_helpers.ch` gained
`make_session_token`, which mints a token through the *same*
`generate_random_hex` + `hash_token` path the login handler uses, plus
`authed_get`/`authed_post` because `http::Client::get` takes no headers. A test
that hand-rolled its own token hash would pass while the real login path broke.

---

## 7. The features that shipped with no consumer

P1 7.1.16, 7.1.19, 7.1.20, 7.1.21, 7.1.22, 11.2.16 and 11.2.17 are closed. The
substance:

**11.2.16 — seventeen implementations of "who is this request from?"**
`handlers_review_page.ch` alone had three (`bearerValue`, `authHeaders`,
`jsonAuthHeaders`), each reading localStorage separately, and `pages_settings.ch`
had four inline `'Bearer ' + getItem(...)`, two of which passed `null` straight
into a header value. Eleven of the seventeen read localStorage **unguarded**, and
localStorage *access throws* with site data blocked — which takes down the whole
script block, not one function. The nav's `getTheme()` was one of the eleven, so
a reader with site data blocked lost the theme toggle along with everything else
in that block. All of it is now `web/src/session_js.ch`: one `__ulFetch` with
one 401 policy, one `__ulCourseId`, and it is emitted per page so the statically
pre-rendered lesson pages still work from `file://`.

**7.1.22 — the literal-template bug.** `fetch('/api/progress/:courseId?course_id=elf')`
pasted a route *template* into a literal. `:courseId` was never substituted, the
router matched nothing, `r.json()` threw on the 404 page, and the concept list on
the course analytics page was permanently empty — on the page whose only job is
that list. The `course_id=elf` beside it was a second, separate lie.

**7.1.21 — `course_id=elf` in three fetches.** `/progress` drew 24 hardcoded ELF
concepts with their titles on any course, and `/review` submitted every **rating**
against ELF — so FSRS, the scheduler, streaks and achievements all trained on the
wrong material, silently. The progress page's two 24-entry arrays are now a
fetch of `/api/courses/:id`, the same manifest the lesson pages are built from.

**7.1.19 — 401 was rendered as an empty state.** An expired or revoked session
was indistinguishable from never having signed in, and the dead token stayed in
localStorage so every later page load re-sent it. `__ulFetch` clears the token,
redirects to `/login?next=…`, and refuses to redirect on the auth pages so it
cannot loop.

**11.2.17 — `next` was written and then discarded.** `__ulRedirectToLogin`
appends `?next=%2Freview`; the login handler used `window.location.href = '/'`.
So a reader bounced off an expired session signed in and was sent to the home
page instead of back to the review queue. `__ulAfterAuth` now decides in one
place: `next` first, then the gate, then home — in that order, because a learner
who followed a `next` link has already shown they can find things, and a new
account sent straight to a lesson has no course, no dashboard and no idea what
exists.

### 7.1.16 — and the one that was already "integrated"

The navigation API *did* have a consumer, so the checklist item was stale. The
lesson page's own script flattened the modules and filled `#ul-prev`, `#ul-next`
and the `<link rel>` tags. Two consequences:

* A statically pre-rendered lesson page has no server, so the fetch fails, so
  **the swipe gesture reloads the page the reader is already on** — because an
  empty `href=""` resolves to the current URL. The gesture was not inert
  offline, it was *wrong*, in the specific way that looks like an app working.
* Everything that reads the document rather than the DOM — a text-mode reader, a
  crawler, a print — saw two hidden anchors and a course with no way to walk it.

The server was already handed the course id, the concept id, and the loaded
manifest. So `web/src/lesson_pager.ch` resolves it there. Note the dead markup
it had to work around: the `<link rel="prev">`/`<link rel="next">` tags in 22
course sources **never reached a page in any build**, because the `html_cbi` macro
drops `<link>` inside `<body>`. They are not in the served HTML and were not
before this either.

---

## 8. A defect that shipped while this pass was being written

Recorded because the method is the point, not the individual bug.

The first version of `patch_once` sliced the tail of the document with
`subview(after, src.size() - after)`. `subview(start, end)` takes an **end
index**, not a length — it returns `string_view(_data + start, end - start)` —
so that asked for `[after, size - after)` and the tail of every lesson page
silently vanished:

```
bytes:  65,866 -> 24,934 bytes, cut off mid-attribute inside the a11y controls
```

and **every gate stayed green**: the server healthy, all 180 routes answering
200, `nav_check` reporting 447 pages with one navbar each, `link_check`
reporting 462 resolving links. A status code is valid in a truncated document
and a link target is valid in a truncated document, so nothing that asks "did the
server answer?" can see it. (`nav_check` passed because the navbar is in the
first 4 KB.)

`tools/lesson_pager_check.py` is the answer to that, and it asks the question no
other gate in the repo asks: **did the server answer with the whole page?** It
asserts the unit-section count against the manifest, that the document ends with
`</html>`, and that the pager is correct at the first, an interior and the last
concept of a course. It also fetches all 24 ELF lessons for truncation alone.
35 checks, proved to fail by reintroducing the exact bug — 13 named failures.

One assertion in it was itself wrong and was corrected: it required `</main>`,
which 455 of the lesson files in `content/src` do not have at all. That is a
pre-existing gap in the course corpus, and a checker that fails on correct pages
is a checker people learn to ignore.

---

## 9. Gates

| gate | result |
|---|---|
| build | exit 0 (was: **did not compile**) |
| `/api/health` | 200 |
| startup SQL failures, fresh DB + second start | **0** (was: 4 per start) |
| `tools/baseline_urls.txt` | 447/447 HTTP 200 |
| `nav_check` | 447 pages, one nav each |
| `link_check` | 462 links, 3,868 occurrences |
| `progress_check` | 43/43 |
| `description_check` | 108/108 |
| `security_check` | 44/44 |
| `route_check` | **180 routes: 0 unreachable, 0 5xx, 0 leaks, 0 bleeds, 0 crashes** — the crash class the previous audit could only report is gone |
| `integration_check` | **105/105** (was: 5 failing) |
| `session_js_check` (new) | 48/48 |
| `lesson_pager_check` (new) | 35/35 |
| `bracecheck` · `nesting_check` · `html_balance` · `check_quotes` · `js_escape_check` · `sqli_scan` · `check_inline_string_temporaries` | all exit 0 |
| `verify_*.py` | 24/24 |
| `scripts/test.sh` | **136/136** (was: would not build) |
| `checker_nonvacuity` | **13/13** proven live — every checker passes on the real tree and fails when its claim is broken |
| `app/main.ch` line endings | CRLF preserved |

---

## 10. What is still open

1. **`POST /api/exercises/import` writes global course content with no auth.**
   Unchanged from the previous audit, and still the highest-value item on that
   list: it decides who may author course content, which is a product decision.
2. **The `demo` fallback on non-destructive writes.** 46 sites. Changing it
   alters what a signed-out visitor's progress does, which is a behaviour
   change, not a fix.
3. **`scripts/` — `nav_check`, `link_check`, `progress_check` and
   `description_check` hardcode port 9000.** They all refuse to run against a
   server they cannot reach, which is correct, but it means every gate run needs
   the server on exactly that port. A `--base-url` on the four would remove a
   foot-gun that has already cost a confusing "all pages broken" report.
4. **455 of 460 lesson files have no `<main>` element.** The nav emits a
   skip-link aimed at `#main-content`, which on a lesson page is either absent
   or points nowhere — so the skip-link is the same dead-link shape this
   collection had once, on 398 pages.
5. **128 files over the 250-line ceiling** (`web/src/helpers.ch` 1574,
   `app/main.ch` 1259, `handlers_review.ch` 898, plus ~100 lesson files that 24
   `verify_*.py` assert byte-level facts about). Unchanged, and correctly
   deferred: splitting the lesson corpus is a refactor with a different risk
   profile from correctness work.
6. **P1 2.2.37** (126 ELF quiz options still lacking per-option feedback) and
   **P1 7.1.23** (the course landing page's Enroll button) remain. 7.1.23 is the
   last API-with-no-UI-consumer in the P1 list.