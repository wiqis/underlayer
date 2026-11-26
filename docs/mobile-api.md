# Underlayer mobile API

Two endpoints close the gaps that block the Android client (gaps S-1/S-2 in
`Android/Apps/underlayer-kmp/docs/underlayer-client-plan.md`, §2.8). They are
additive: every existing route keeps its shape. All paths are on
`https://underlayer.wiqis.com` (`localhost:9000` locally).

**Governing spec:** `docs/learner-first-mandate.md` (ACTIVE, 2026-11-24).

## `GET /api/courses/:courseId/lessons/:conceptId/units`

Public JSON. No authentication.

Derives the step index from the **exact HTML** `underlayer_content::render_concept`
produces: every `class="unit unit-<kind>"` block becomes one unit, with the
text of its `<h2>` as the title. There is no second, hand-maintained index to
drift. Units are in document order.

### Example

`GET /api/courses/elf/lessons/bytes/units`

```json
{
  "course_id": "elf",
  "concept_id": "bytes",
  "units": [
    {"id":"unit-why","kind":"why","title":"Why This Matters","order":1},
    {"id":"unit-model","kind":"model","title":"A Simple Model","order":2},
    {"id":"unit-reality","kind":"reality","title":"The Actual Detail","order":3},
    {"id":"unit-example","kind":"example","title":"A Real Example","order":4},
    {"id":"unit-interact","kind":"interact","title":"Try It","order":5},
    {"id":"unit-retrieve","kind":"retrieve","title":"Check Your Understanding","order":6},
    {"id":"unit-apply","kind":"apply","title":"Apply It","order":7}
  ]
}
```

Shape: a top-level object with `course_id` (string), `concept_id` (string) and
`units` (array). Each unit object has exactly four fields: `id` (string,
`"unit-" + kind`), `kind` (string, the suffix of `unit-*`), `title` (string,
the `<h2>` text), `order` (integer, 1-based). An empty `units` array is valid.

The ids are whatever the content contains, including duplicates: the shipped
`bytes` lesson has two `unit-retrieve` blocks (orders 6 and 9). A client that
needs a unique step key must use `order`, not `id`. The endpoint deliberately
does not rename or de-duplicate them — it reports the document as rendered.

**404** `{"error":"course not found"}` when the course id is unknown;
**404** `{"error":"concept not found in course"}` when the concept exists
globally but does not belong to that course. This check is required because
`render_concept` dispatches globally by concept id and will otherwise render a
mismatched pair; **404** `{"error":"lesson not found"}` when the id resolves to
no renderer.

## `POST /api/progress/sync`

Bearer authentication required (an Underlayer `session_token` from
`POST /api/auth/register` / `/api/auth/login`). No token → **401**
`{"error":"unauthorized"}`.

### Request

```json
{
  "client_now": 1763966400,
  "changes": [
    {
      "course_id": "elf",
      "concept_id": "bytes",
      "unit_id": "unit-why",
      "status": "seen",
      "step_index": 1,
      "updated_at": 1763966399
    }
  ]
}
```

All six fields of every change are required. `step_index` and `updated_at`
must be JSON numbers; the four text fields must be non-empty strings. Missing,
wrong-typed or non-object/non-array payloads → **400** with an `error` message.
`client_now` is required and must be a number; the server returns its own
`server_now` and does not trust the client clock.

### Response

```json
{
  "server_now": 1763966402,
  "changes": [
    {
      "course_id": "elf",
      "concept_id": "bytes",
      "unit_id": "unit-why",
      "status": "seen",
      "step_index": 1,
      "updated_at": 1763966399
    }
  ],
  "fsrs": [
    {
      "concept_id": "bytes",
      "stability": 0.0,
      "reps": 0,
      "interval": 0,
      "next_review": 0
    }
  ]
}
```

`changes` echoes what the **server holds after applying the batch** — a
rejected older write therefore comes back with the newer stored values, which
is what lets a client converge in one round trip. `fsrs` has one entry per
distinct `(course_id, concept_id)` touched by the response, read from
`review_items`; it is **read-only**. A concept with no review item reports
zeros rather than the model defaults. `stability` has four decimals; `interval`
is the stored spacing in whole days (0 when there is no last review).

### Conflict rule (last-write-wins, per key)

- Key: `(learner_id, course_id, concept_id, unit_id)` — never whole-course.
- A change is stored only when its `updated_at` is **strictly newer** than the
  stored one. Equal timestamps are a no-op (so replaying a batch is
  idempotent); older timestamps never overwrite newer state.
- Writes go to the new `concept_unit_progress` table only. The endpoint never
  writes `concept_states` or `review_items`: `stability`, `reps`, `interval`,
  `next_review`, `attempts`, `correct` and `streak` remain
  server-authoritative, written by `/api/review/submit`. This is the exact
  defect in `/api/progress/import` (which `INSERT OR REPLACE`s and zeroes
  `last_studied`, `next_review` and `difficulty_rating`) — **do not use that
  endpoint for sync**.

## `GET /api/progress/sync?since=<unix seconds>`

Bearer authentication required. Returns every stored key for the learner with
`updated_at >= since`, in ascending timestamp order, plus the same `fsrs`
block and `server_now` as the push response. `since=0` is the full initial
pull; store the last `server_now` for an incremental pull.

**400** `{"error":"since must be a unix timestamp"}` when `since` is absent,
empty or contains anything but decimal digits.

## S-3 account-bridge route: deployed, but not proven end to end

**Corrected 2026-11-26 (A1).** The text that used to live here said that
`POST /api/auth/exchange` needed a shared secret / token introspection endpoint
and was "explicitly deferred", and that `auth_get_learner_id` resolved only
Underlayer's own 64-hex session token. That was true of the earlier design; it
is **not** the deployed reality. The deployed route is
`POST /api/auth/from-account` (`web/src/handlers_account_bridge.ch:98-169`):
a browser forwards the account `refresh_token` cookie and is validated with
`GET /api/me`; an Android client sends `Authorization: Bearer <account access
token>` and is validated with `POST /v1/token/check` plus
`POST /v1/account/info`. Identity only — no learning data is written to the
account service. `auth_get_learner_id` now resolves a bearer **or** an HttpOnly
cookie (`web/src/handlers_auth.ch:82-98`).

Measured 2026-11-26 against `https://underlayer.wiqis.com` (read-only POSTs;
`tools/bridge_probe.py --deployed`):

| Request | Status | Meaning |
|---|---|---|
| `POST /api/auth/from-account` with no bearer and no cookie | **401** `{"error":"account credentials required"}` | route exists and guards credentials |
| `POST /api/auth/from-account` with `Authorization: Bearer <garbage>` | **502** `{"error":"invalid account token check response"}` on the deployed service today | route exists; the account backend was unreachable so the token check returned no usable body. When the account backend is reachable and rejects the token it answers **401** (`handlers_account_bridge.ch:111-125`) — the local case. Both are non-404, which is the route-existence proof. |
| `POST /api/no-such-endpoint` (and `/api/no-such-route-bridge-probe`) | **404** | unknown POST routes still 404 |

**Limit, not a claim of success:** no real `account.wiqis.com` token was
exchanged, no `/api/auth/me` was resolved with a bridged session, and no
progress batch was pushed in this measurement. End-to-end identity/progress
remains the D1 work package in `production-ready-plan.md` (EC9); the Android
client still treats sign-in as plumbing only. A garbage-token POST never
registers a learner or creates a session.
