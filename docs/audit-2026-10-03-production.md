# Underlayer production-readiness pass — 2026-10-03

**Scope.** The five blockers named on 2026-10-02, plus three things a person
noticed about the site in the first second of using it.

**Method.** Every claim is a measurement against a running server, a row count, or
a served response before and after. Where something could not be fixed it is named
in §7 rather than left implied.

---

## 1. The headline from 02 Oct, re-measured

| | before | after |
|---|---|---|
| build | did not compile | exit 0 |
| startup SQL failures | 4 per start | 0, fresh DB and second start |
| `route_check` crashes | 4 | 0 |
| tests | would not build | 136 / 136 |
| integration checks | 5 failing | 105 / 105 |
| security checks | 44 | 50 |
| checkers proven non-vacuous | 13 | 14 |
| static pages | 0 in a clean clone | 432 across 34 courses |

---

## 2. The five production blockers

### 2.1 The documented production database does not exist

Pointed the shipped binary at the URL the Dockerfile names as the production
setting:

```
DATABASE_URL="libsql://example.invalid" ./underlayer.exe
  -> /api/health                      200
  -> POST /api/auth/register   {"error":"could not create the account"}
```

The remote (Turso/libSQL) backend is not implemented — the two branches in
`exec_sql`/`query_sql` return "no" with a comment nobody reads. The server booted,
reported healthy, accepted traffic, and lost every write. Anyone following
`docs/deployment.md` got a site that looked up and lost registrations.

Now exits before the schema init, the seeding and the accept loop, and prints what
to use instead. The same check catches a local SQLite path that could not be
opened, which has the identical shape: everything answers, nothing is stored.

```
[underlayer_db] FATAL: cannot use this database.
  DATABASE_URL = libsql://x.invalid
  The remote (Turso/libSQL) backend is NOT IMPLEMENTED in this build.
  Every query and every write would fail while the server reported itself healthy.
```

### 2.2 Anyone could write the course's answer key

Not inherited from the previous audit — confirmed:

```
POST /api/exercises/import            (no Authorization header)
  {"exercises":[{"concept_id":"bytes","question":"INJECTED BY UNAUTHENTICATED CALLER",
                "answer":"a","options":"alpha|beta","correct_index":0}]}
  -> {"inserted":1,"errors":0}
  -> the row is in `exercises`
```

`exercises` is not per-learner. It is the global bank every learner is graded
against. Refused now, and **refused rather than merely authenticated**: a token
check makes this "any registered learner", which is the same defect with a login
in front of it, and an account is free. There is no content-author role to give it
to — the `learners` table has no role column — so the routes stay registered and
say why. `401` anonymous, `403` authenticated.

`POST /api/exercises/seed` was the same hole. `POST /api/reviews/:id/helpful` was
an unauthenticated vote with no dedupe; it now needs a session. **The dedupe is
not fixed** and needs a per-learner column — a schema change, not a gate (§7).

### 2.3 No rate limiting anywhere

Twelve wrong passwords answered twelve `401`s, no delay, no counter. bcrypt cost
12 costs this server **0.44s of CPU per attempt**, so an unthrottled login
endpoint is a denial-of-service from one HTTP client, free to the attacker.

Now 8 attempts per 5 minutes per IP per endpoint group, on login, register,
forgot and reset:

```
401 401 401 401 401 401 401 401 429        <- 429 on the 9th
HTTP/1.1 429 + Retry-After: 176
```

**The counters live in a `rate_limits` table, not in memory.** The in-memory
version was written and thrown out, for two reasons: this codebase has no
module-level mutable state anywhere, so inventing one inside a request path is how
you get a data race in a language whose threading model is young; and a counter
that dies with the process resets on every restart and fails open the moment there
is a second process. A `SELECT` and an `UPSERT` on an endpoint that already
spends 0.44s hashing are invisible next to the work they guard.

`X-Forwarded-For` is **not trusted**. It is set by whoever sends the request, so
honouring it means the limiter can be sidestepped by changing the header — exactly
what an attacker would do. Behind a proxy this limits by the proxy's address,
which is stricter, not weaker.

### 2.4 No security headers

Verified present on **all 447 baseline URLs**, applied in the four `send_*`
helpers so every route inherits them rather than 17 files remembering.

`X-Content-Type-Options: nosniff` · `X-Frame-Options: DENY` ·
`Referrer-Policy: strict-origin-when-cross-origin` · `Strict-Transport-Security`.

**There is deliberately no Content-Security-Policy**, and the reason is written
down rather than left as a gap that reads like it is covered: this codebase emits
inline script and inline style by the thousand through the `#js`/`#css` macros, so
a policy forbidding inline breaks the product, and one with `unsafe-inline` buys
almost nothing. A real CSP starts with moving the inline scripts into external
files — separate work with a stated first step.

### 2.5 There was no static pipeline at all

`courses/*/output` is gitignored, which is right. It has a consequence nobody had
written down: **a clean clone contains no static pages.** GitHub Pages serves from
the repository, so with the output directory ignored and nothing regenerating it,
the Pages site is empty.

`scripts/build_static.sh` is the generator, as a checked-in script rather than a
YAML block, so it runs in CI, by a person, or on a laptop before pushing. A course
that fails is reported and the rest continue: a partial static site is still
usable, and a CI job that stops at the first course tells you nothing about the
other thirty-three.

Result: **34 courses, 432 pages, 0 truncated.**

---

## 3. The dark-mode flash

Reported as: *it loads light, then becomes dark, and the shift is not something I
like.*

Measured on the served HTML rather than guessed at:

```
/dashboard   </head> at 19555   theme detection at 134902
/courses     </head> at 14658   theme detection at 228801
/search      </head> at 11919   theme detection at 112403
```

The code reading `prefers-color-scheme` ran ~100 KB into the `<body>`, inside the
one giant `<script>` the components runtime emits at the end. A script at the end
of `<body>` is too late by definition — the browser has already painted everything
above it. So the page painted light and repainted. Not a slow page: a **correct
page arriving in the wrong colours**.

`content/src/theme_boot.ch` emits a small **blocking** script into `<head>`. Now at
byte ~220 of the head, on every themed page.

One detail cost a wrong version: the first attempt used a `#js` block, and `#js`
appends to `pageJs`, which `toString` emits in one `<script>` at the end of
`<body>`. The flash was unchanged, and there was now also a `<meta>` that looked
like it had fixed something. `append_head_view` writes into `pageHead`, which lands
between `<head>` and `</head>` — that is the slot.

Plus `<meta name="color-scheme" content="light dark">`, so scrollbars, form
controls and the frame behind the document follow the theme instead of staying
light behind a dark page.

The logic is duplicated from `getTheme()` because the head script must run before
`getTheme` is *defined*. That duplication is held honest by
`tools/theme_check.py`, which asserts the two agree on the two questions that can
disagree: where the choice comes from, and what class is applied.

**Forty pages were still flashing**, found by measuring rather than by assuming the
one fix covered everything:

| group | why it missed the fix |
|---|---|
| 6 course landing pages | hand-roll their navbar, never call `render_site_nav` |
| 28 course landing pages | call `render_lesson_nav`, which passes `lesson=true` |
| 6 pages (`/login`, `/settings`, `/help`, `/faq`, `/about`, `/register`) | draw no navbar at all, but do inject the components theme, whose `.dark` rules key on the `<html>` class — so with nothing setting the class they rendered light unconditionally |

All 40 now carry it. **Lesson pages still deliberately do not**, and
`theme_check.py` asserts that too, so a future "fix" that adds `.dark` to 398
hardcoded-light pages is caught rather than shipped.

---

## 4. Pages that need an account now say so

Reported as: *a visitor can open the dashboard — what are we storing that we can
show? hardly anything.*

Stripped of markup, a signed-out visit read:

```
Concepts in elf 24   Read 0   Learned 0   Review due 0
Course progress 0 of 24 concepts read   Mastery 0% learned
Depth Score 0.000% understanding        Breadth Score 0.000% coverage
Review Queue  New: 0  Due: 0  Mastered: 0
```

Thirty-eight zeroes, none of them the reader's. A wall of zeroes reads as "you are
failing at this". The onboarding banner fired there too, telling a visitor with no
account to finish setting up their account.

**Eleven pages are now behind a server-side gate**: dashboard, progress, review,
analytics, bookmarks, notes, study-plans, achievements, streaks, notifications,
certificates.

Server-side because the page must be **correct before any script runs**. A
client-side gate ships the zeroes and swaps them, so a reader on a slow connection
reads the zeroes first. The seven shell pages were the clearest case: HTTP 200,
correct headings, an empty list — the failure mode that looks most like success.

**Lessons and course pages are not gated.** A stranger has to read one before
deciding whether to register; gating the lesson would be gating the only thing
there is to see. They get one line instead — a sentence and a button — hidden in
the markup and revealed by the `/api/auth/me` call the nav already makes, so no
page gains a request and a page opened from disk never shows it.

---

## 5. Three checkers and one test were measuring the new features

Each failed for a reason that looked like a broken product:

| | what it reported | what was true |
|---|---|---|
| `progress_check` | `the dashboard has a place to draw the answer (#wd-courses)` | it fetched `/dashboard` anonymously and got the **gate** |
| `pages_test.ch` | `missing pauseSession()`, `missing /api/session/abort` | same — it asserted on the gate page it was handed |
| `security_check` | `HTTP 429` on login | the **rate limiter** working |
| `integration_check` | `register a fresh learner` → 429 | same |

All now sign in, and each also asserts the gate, so the security property is
covered rather than lost. The limiter is asserted from a known-empty counter in
`security_check` CHECK 14, **in both directions**: it refuses a flood, it starts
refusing *at the limit* rather than on the first try, a correct password is
**also** refused while throttled (so it is not an account-existence oracle), and a
legitimate login recovers once the window passes.

---

## 6. Gates

| gate | result |
|---|---|
| build | exit 0 |
| startup SQL failures, fresh DB + second start | **0** |
| remote `DATABASE_URL` | **refuses to start**, FATAL logged |
| content writes, anon / authed | **401 / 403**, 0 rows injected |
| rate limit | 401 ×8 then **429** with `Retry-After` |
| security headers | **447/447** URLs |
| static pages | **432** across 34 courses, 0 truncated |
| `theme_check` (new) | 29/29 |
| `lesson_pager_check` | 35/35 |
| `session_js_check` | 48/48 |
| `security_check` | **50/50** (was 44) |
| `integration_check` | 105/105 |
| `progress_check` | 44/44 |
| `nav_check` · `link_check` | 447 pages · 462 links |
| `route_check` | 180 routes, **0 crashes**, 0 5xx, 0 leaks, 0 bleeds |
| `verify_*.py` | 24/24 |
| `scripts/test.sh` | **136/136** |
| `checker_nonvacuity` | **14/14** proven live |

---

## 7. Still open, stated plainly

1. **No CI/CD.** `.github/workflows` does not exist. `docs/deployment.md` contains
   a pipeline as a YAML block inside markdown. `scripts/build_static.sh` is now the
   thing such a pipeline would call, so the missing piece is the workflow itself.
2. **No Content-Security-Policy.** Deliberate; first step is externalising the
   inline scripts (§2.4).
3. **`helpful` vote has no dedupe.** A free account can still vote repeatedly; the
   limiter bounds the rate, not the count. Needs a per-learner column.
4. **One SQLite handle behind a 12-thread pool.** 40 concurrent writes stored
   40/40 with no loss, so it survives what was tested — but a single handle cannot
   be *documented* safe without `SQLITE_OPEN_FULLMUTEX` or a connection per thread,
   and it caps the platform at one process. Scaling out needs the remote backend,
   which does not exist.
5. **No backup tooling.** No script copies or verifies `underlayer.db`.
6. **`rate_limits` grows without bound.** One row per distinct IP per endpoint
   group. A login-endpoint purge is missing.
7. **`/api/exercises/*` are now unreachable**, so course exercises cannot be pushed
   over HTTP. They still seed from the course manifests at startup, which is how
   the shipped content actually arrives, so nothing that works today stopped
   working — but a content authoring workflow needs a role first.
8. **128 files over the 250-line ceiling**, and 455 lesson files with no `<main>`
   for the skip-link to target. Unchanged; the second is an accessibility gap that
   `lesson_pager_check` deliberately does *not* assert on, because 92% of the
   corpus lacks it and a checker that fails on correct pages gets ignored.
9. **P1 2.2.37** (126 ELF quiz options still lacking per-option feedback) and
   **P1 7.1.23** (the Enroll button) remain. Course settings, at the founder's
   request, is deferred to a later pass.
10. **Four checkers hardcode port 9000** (`nav_check`, `link_check`,
    `progress_check`, `description_check`). They correctly refuse to run against
    a server they cannot reach, so the cost is that every gate run needs the
    server on exactly that port.