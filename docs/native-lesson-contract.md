# Native lesson contract (binding, 2026-11-25)

The Android client must not use WebView. Lessons are delivered as structured JSON and
rendered with native Compose views. This document is the single contract for both repos.
Any mismatch is a bug in the producer or consumer, not a reason to add HTML back.

Endpoint: `GET /api/courses/:courseId/lessons/:conceptId/native` (public, read-only).
Static companion: `courses/<course>/output/<concept>.native.json`.
Android pack path: `underlayer/offline-pack/<course>/concepts/<concept>.native.json`,
referenced by `manifest.json` as `concepts[].native_file`.

## Top level

| Field | Type | Notes |
|---|---|---|
| `schema_version` | int | literally `1` |
| `course_id` | string | path segment |
| `concept_id` | string | path segment |
| `title` | string | manifest concept title |
| `minutes` | int | `estimated_minutes` |
| `difficulty` | string | manifest difficulty |
| `prerequisite` | string or `null` | previous concept title in course order; `null` for the first |
| `objective` | string | derived aim (one sentence) |
| `units` | array | document order; `[]` is valid |

## Unit

| Field | Type | Notes |
|---|---|---|
| `id` | string | `unit-<kind>`; duplicates preserved |
| `kind` | string | suffix of `unit-*` |
| `title` | string | `<h2>` text |
| `order` | int | 1-based document order — the UNIQUE step key |
| `remember` | string | derived takeaway, never fabricated; explicit "No new fact to memorise - this step is about seeing the link" when there is none |
| `blocks` | array | document order |

All text is PLAIN TEXT. Entities decoded. Inline emphasis convention: backticks for code,
`**bold**`, `*italic*`. No HTML tags or attributes in any string. Clients render strings as
literal text and ignore unknown `type` values.

## Block types (discriminated by `type`)

- `paragraph` — `text: string`
- `heading` — `level: int` (3 or 4), `text: string`
- `code` — `text: string`, `language: string|null` (never guessed)
- `list` — `ordered: bool`, `items: string[]`
- `table` — `headers: string[]`, `rows: string[][]`
- `quiz` — `id: string`, `question: string`, `options: [{text: string, explanation: string}]`, `correct_index: int` (-1 if none), `explanation: string`
- `hex` — `bytes: string[]`, `labels: string[]`, `mode: "dump"|"interactive"`
- `fill_blank` — `text: string` (with `{{0}}`, `{{1}}` placeholders), `blanks: [{id: string, answer: string, position: int}]`
- `callout` — `variant: string`, `text: string`

Every value is derived from the already-rendered, journey-patched lesson HTML. No lesson
source file is hand-edited and no technical fact is invented.

## Errors

Unknown course → 404 `{"error":"course not found"}`.
Concept not in that course → 404 `{"error":"concept not found in course"}`.
No renderer → 404 `{"error":"lesson not found"}`.
Malformed path → 400 `{"error":"missing course or concept id"}`.
Success → 200 JSON through `deliver` (no-store, ETag, gzip).

## Client rules

- Preserve duplicate unit ids as progress keys `id#order` (existing
  `JourneyHtml.unitProgressKeys` algorithm) or local progress rows become orphaned.
- FSRS fields stay server-authoritative; the client never writes them.
- Local pack emission wins; a failed remote refresh is logged and swallowed.
- No WebView, no `android.webkit.WebView`, no `addJavascriptInterface`, no injected CSS/JS
  anywhere in the app. Deep dive is a native all-blocks view.
