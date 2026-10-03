# Integration holes and course legibility — 2026-10-03 (night pass)

**Asked for, in this order:** finish rate limiting; analyse the whole codebase for
features that exist with no way to reach them; analyse the UI of the courses and of
the platform; make the courses easier to learn. Do it without stopping and without
asking.

**Method.** Every claim is a measurement against the running server, a row count, or
a served document before and after. Nothing here was concluded by reading code
alone, and where a checker was wrong that is recorded rather than quietly corrected.

**Not committed.** Per the company git rules, committing is the founder's call and
this body of work was not authorised for it. Everything is in the working tree.

---

## 1. Rate limiting, finished

The four auth endpoints were limited yesterday. The other 38 POST routes were not.
Measured before changing anything:

| endpoint | before | now | ceiling |
|---|---|---|---|
| `POST /api/exercises/submit` | **10 requests, 10 × 200** | 429 past 120 | 120 / 5 min |
| `POST /api/feedback` | writes a human-triaged queue, unlimited | 429 past 120 | 120 / 5 min |
| `POST /api/feedback/report-exercise` | same queue, unlimited | 429 past 120 | 120 / 5 min |
| `POST /api/learners` | **200 to an anonymous caller, forever** | 401 → 429 past 8 | 8 / 5 min |

**Two ceilings rather than one configurable limit**, because the surfaces have
opposite shapes. Auth is 8 per 5 minutes: a person types a password, anything above
~10 is a script, and bcrypt cost 12 costs this server 0.44 s of CPU per attempt. A
learner answering exercises is 120: a reviewer working through a course in one
sitting produces about 12, so 120 is ten times the worst real reader.

**`POST /api/learning/view` is deliberately not limited.** Every lesson page load
posts it, for every reader, forever. It also has nothing to gain from — it only
advances a timestamp on the caller's own row. "Rate limit everything" is the
instinct and it is wrong here.

`POST /api/learners` was the worst of the four. It inserts into `learners`, which is
the **accounts** table, unauthenticated, with a hardcoded identity — name `learner`,
email `learner@underlayer.dev`, no password — and it reads no request body at all.
It exists for `tests/src/additional_api_test.ch` and nothing else.

### The limiter that did not run

This is the part worth reading. The gate on `/api/exercises/submit` **compiled, its
group string was present in the binary, and never ran.** 125 consecutive submissions
answered 200 and no bucket row was ever written.

The cause is the closure capture shape:

```chemical
srv.router.add("POST", "/api/exercises/submit", (|&db|(req, res) => {
    // `&raw db` here compiles, is emitted, and does nothing.
```

The identical call in a by-value closure — every other gated route — works. The
call site now uses a local copy (`var dbp = db; … &raw dbp`), and
`tools/security_check.py` **CHECK 14 now fires every gate and requires each to
refuse**, so "the gate is in the source" is no longer something anyone takes on
faith.

A limiter that silently never fires is worse than no limiter, because it reads as
coverage.

### `rate_limits` grew without bound

It gains a row per distinct IP per endpoint group and nothing removed one —
written by anonymous requests, unbounded. `purge_expired_rate_limits` now runs at
startup. A bucket whose window has passed can never affect a decision, because the
limiter resets a count whenever `window_start` differs from the current window, so
deleting one cannot change a single future answer. That is what makes it safe on
startup rather than needing a timer. The cutoff is **two** windows, so a row is
never deleted in the instant before its own window rolls over.

---

## 2. The integration audit

`tools/integration_holes.py` answers the question by measurement. Baseline:

```
180 routes (145 API), 995 page-building sources scanned
API routes reachable from a page : 110 of 146   (75%)
no UI caller at all             : 36
```

### The tool was wrong twice, and both are documented

**First version: 87 holes.** Five spot-checks found the caller in the first one —
`__ulFetch('/api/review/start')` in the review page, whose own test asserts on it.
The scanner missed `__ulFetch(` because `web/src/session_js.ch` replaced 17
duplicated fetch sites with one helper, and it matched caller paths only at equal
segment counts, so the 30 paths built by concatenation were dropped.

**Second version: 0 holes.** `app/main.ch` is the route table and names all 145 API
paths by definition, so including it made every route match itself. Zero is the one
number this tool must never print, because it reads as "everything is wired up".

Both failures are the same kind: **a scanner that over-reports gets ignored, and
then it protects nothing.** The exclusions are now stated where they are made.

### The highest-value invisible feature

```json
GET /api/weaknesses  ->  200
{"weaknesses":[{"concept_id":"bytes","accuracy":0.0,"severity":100,"status":"struggling"},
               {"concept_id":"binary-representation",…},
               {"concept_id":"file-layout",…}],
 "clusters":[…]}
```

`repository/src/exercise_attempts.ch` records every wrong answer,
`learning/src/weakness.ch` ranks concepts by accuracy and severity, and
`GET /api/weaknesses/alerts` turns it into "this needs attention". All of it works.
All of it is computed on every answer. **No page on the platform named any of them.**

A learner who got five of six questions wrong on three separate concepts was told
nothing. That is the worst kind of shipped feature: it costs CPU on every answer and
returns nothing a person can use.

---

## 3. "Where to go next" — the dashboard's missing conclusion

`web/src/next_step.ch`. The dashboard's subtitle has always said *"where you are,
and what to do next"* and then answered only the first half: four counters, three
knowledge-health bars, a review-queue card. Those are the evidence. There was no
conclusion anywhere on the page.

The content of the panel **is** its priority order:

1. **Reviews first.** A due review is something already read once and about to be
   forgotten; learning something new instead makes the forgetting worse. This is the
   most common way a learner damages their own retention without knowing it.
2. **Then what they are getting wrong.** Accuracy is lowest there, so the return on
   the same number of minutes is highest.
3. **Then the next unread concept.** Only when nothing is due and nothing is failing
   is "carry on" the right answer.

It shows at most three, and says why it shows three — an unexplained short list
reads as "that is all there is". It ships `hidden` and stays hidden when there is
nothing to say. It never shows a percentage: "42% accuracy" invites a conclusion
about the reader, "you have got this wrong twice" invites them to open the lesson.

Verified by **running** its JavaScript against the real server in four states
(`tools/next_step_test.js`, 14 checks), including one the platform's own schedule
would not produce on demand — so the ordering claim is driven directly with a
stubbed queue plus the **real** weakness list, which is the only arrangement where
the ordering can be wrong.

Three of that harness's own assertions were wrong before the panel was:

* a `getElementById` mock returning a **fresh element per call**, so the code
  appended to one `#ns-list` and the test read an empty different one;
* a mock ignoring the `hidden` attribute, so "the panel appears" passed
  unconditionally;
* and the worst: it **proceeded after a rate-limited `register`**, sending every
  later request as `Bearer undefined` and reporting results for an anonymous panel.
  It now refuses to run without a session.

---

## 4. The lesson header — 431 pages

Measured on a served lesson page, before:

```
Bytes and Binary
Concept 1 of 24 in Fundamentals
Previous   Next: Binary Representation
```

That was all of it. **No time. No difficulty. No statement of what the reader is
assumed to know.** All three were in memory: every one of the 398 concepts in every
manifest carries `estimated_minutes` (12–40 min) and a per-concept `difficulty`,
`repository/src/courses.ch` parses both into `ConceptRef`, and `handle_lesson` has
the whole `Course` from line 12, where it decides whether the lesson exists.

Now, under the title on all 431 served lesson pages:

```
⏱ 18 min   ▲ advanced   ☰ Module 3: Program Headers
Continues from entry-point
```

Why each of the three earns its place:

* **Time**, because a reader who cannot tell whether a lesson is a three-minute read
  or a forty-minute grind cannot plan a session, and the natural response to an
  unknown commitment is not to open the thing.
* **Difficulty, per concept rather than per course.** All 398 concepts carry their
  own. A course-level label would tell a reader in the x86 course that everything is
  advanced, including the lesson that counts bytes.
* **The predecessor line**, derived from **course order**, not from the
  `prerequisites` field — because **0 of 398 concepts declare one**. The field
  exists in the model and the loader parses it; no manifest fills it. These courses
  are `navigation: "linear"` and every landing page says the lessons read in order,
  so "continues from" is the true and useful statement. An explicit `prerequisites`
  list still wins when a manifest supplies one.

`tools/lesson_header_check.py` reads the manifest and **compares**, for all 398
lessons. Comparing rather than checking presence is the only version that can catch a
wrong value — and it did:

> the predecessor href was built from `concept_id` instead of `course.id`, producing
> `/courses/binary-representation/lessons/bytes` on **every lesson page** — a 404 for
> every reader, from code that compiled cleanly.

**Static pages do not get the header**, and that is a real limitation rather than a
decision: the 432 pre-rendered pages are written by the course binaries, which never
run `handle_lesson`. The honest fix is for `scripts/build_static.sh` to apply the
same substitution from the manifest it already reads. It does not yet.

---

## 5. The Enrol button, and a feature that always said yes

**P1 7.1.23** said "enrollments API has no UI consumer". It was right about all of
it: `GET /api/enrollments`, `POST /api/courses/:id/enroll` and
`GET /api/courses/:id/can-enroll` all answered 200 and no page on any course named
any of them.

Two measurements shaped it:

**Enrolling already happens implicitly.** `repository/src/enrollments.ch` calls
`enroll_learner` from `touch_enrollment`, on the read path — opening a lesson enrols
you. So a button that always said "Enroll" would answer `already_enrolled` for most
people who clicked it. The control is therefore a **state** control:

| reader | sees |
|---|---|
| signed out | nothing — the sign-in advisory above the fold already says why, and saying it twice teaches the reader to skip both |
| signed in, not enrolled | the button, which asks `can-enroll` before enabling itself |
| signed in, enrolled | "Enrolled since 2026-10-02", and **no script**, because there is nothing to press |

**Then the feedback could never fire.**

```sql
SELECT COUNT(*) FROM course_prerequisites;   ->   0
```

…while **32 of 34 manifests declare `dependencies`**. `check_prerequisites`,
`get_missing_prerequisites` and `can-enroll` all existed and all read an empty
table, so `can-enroll` answered `{"can_enroll": true}` for **every course on the
platform**. A shipped feature that always says yes is worse than an absent one,
because the checklist says it exists.

`repository/src/prerequisites_seed.ch` now seeds it beside the exercise seeding, from
the same manifests: **107 rows**. Idempotent, and it **prunes** — a dependency
removed from a manifest stops being enforced, because the table is derived state and
derived state has to be allowed to shrink.

### The threshold, which the manifests do not supply

`dependencies` is a list of ids. There is no per-dependency mastery figure in any
of the 34 manifests. So the number had to be chosen, and the choice is written down:

**70%.** `check_prerequisites` computes mastery as `correct*100/attempts` and then
requires that share of concepts to clear the *same* threshold, so it is applied
twice:

* **100%** would make the collection unusable — one wrong answer on one concept locks
  the next course forever, with no recovery except deleting the account.
* **50%** would admit someone on half-understood material, which is exactly the
  failure the collection exists to prevent.

`a64abi` now correctly refuses and says so:

```json
{"can_enroll":false,"missing":[{"required_course_id":"a64asm","min_mastery_pct":70}]}
```

### Two more bugs this surfaced

* `render_enroll_js` **wrote to the `ResponseWriter`**, which commits the response —
  so the course page that followed came out as a 2,071-byte document containing a
  `<style>` and a `<script>` and no course at all, on all 34 courses. `/courses/elf`
  answered 200 throughout.
* The served script **did not parse.** Chemical's escaping collapsed the quotes
  inside a nested HTML string, producing `w.outerHTML='<span class='enroll-state'…'`
  — a syntax error on every course page, so the button did nothing. `enroll_check.py`
  now **parse-checks** the served script and reports a parse failure as a distinct
  fault from a disabled button, because they are different bugs.

---

## 6. Gates

| gate | result |
|---|---|
| build | exit 0 |
| `scripts/test.sh` | **136/136** |
| `integration_check` | 105/105 |
| `security_check` | **62/62** (was 50; CHECK 14 now fires every gate) |
| `progress_check` | 44/44 |
| `theme_check` | 29/29 |
| `lesson_pager_check` | 35/35 |
| `lesson_header_check` | **11/11 across all 398 lessons** |
| `enroll_check` | **22/22**, four states |
| `next_step_test` | **14/14**, four learner states |
| `session_js_check` | all |
| `nav_check` · `link_check` | 447 pages · 462 links |
| `route_check` | 181 routes |
| `verify_*.py` | 24/24 |
| static pages | **432 across 34 courses**, 0 truncated |
| integration holes | 110/146 reachable, **36** with no UI caller |

P0: **0 open.** P1: **1 open** (`2.2.37`, ELF per-option feedback — course content,
not platform).

---

## 7. Still open

1. **36 integration holes remain.** The largest cluster is `/api/analytics/*`
   (17 routes) — platform analytics with no UI. The rest are `/api/health/*` (4),
   `/api/fsrs/*` (4), `/api/weaknesses/*` (3 more), `/api/goals` (2, and
   **`GET /api/goals` does not exist at all**, so a learner cannot see their goal),
   and single routes for reviews, notifications, sessions and profiles.
   `tools/integration_holes.py` reports them rather than letting them be forgotten.
2. **The static pages carry neither the lesson header nor the Enrol control.** Both
   are injected at serve time by handlers the course binaries never run. The fix is
   to apply the same substitutions in `scripts/build_static.sh`.
3. **The lesson header still trusts `course.concepts` order.** That is the reading
   order because the manifests list concepts in it — the same assumption the prev/next
   pager already makes — but it is an assumption, not a guarantee.
4. **The Enrol control's prerequisite copy is generated in JavaScript**, so it cannot
   be seen by a text-mode reader or a crawler. `can-enroll` could be answered
   server-side instead; that would need the session at patch time, which is available.
5. **No Content-Security-Policy, no CI/CD, one SQLite handle behind 12 threads, no
   backup tooling** — unchanged from the previous audit.
6. **`2.2.37`** — 126 ELF quiz options still lack per-option feedback. Course content
   rather than platform, and the remaining P1 item.
