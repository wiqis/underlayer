# H13 — Stable concept identity and forward-only migration (2026-11-28)

## What shipped in this repo

- `repository/src/schema.ch`: new `concept_aliases(old_id PRIMARY KEY, new_id,
  course_id, reason, created_at)` plus an index on `new_id`.
- `repository/src/concept_aliases.ch`: `register_concept_alias`,
  `resolve_concept_alias` (chain-following, max 16 hops),
  `concept_has_live_state`, `concept_deletion_allowed`, `migrate_concept_rows`
  and `apply_manifest_concept_aliases`. The migration touches exactly
  `concept_states`, `review_items`, `concept_unit_progress` and
  `exercise_attempts`; it never writes FSRS columns.
- `repository/src/review_seed.ch`: a manifest is read at startup and its
  `concept_aliases` are registered/migrated BEFORE exercise seeding. With
  today's manifests (no aliases) this is a measured no-op.
- `tools/concept_migration_check.py`: spec mirror + checker. Verified green:

```
PASS rename: zero orphan rows / FSRS params unchanged
PASS rename: deletion refused before alias+migration
PASS rename: deletion allowed after alias+migration
PASS split: zero orphan rows / FSRS params unchanged / both successors carry state
PASS selftest: 2 negative plants (unaliased id, planted FSRS drift)
```

## Exact manifest edits still needed (courses/* is out of my ownership)

For each of the 33 `courses/<id>/manifest.json`:

1. Add a top-level semver version if it is not already one. ELF currently has
   `"version": "1.0.0"` (a string); the loader's `json_get_int` reads 0 and
   falls back to 1. Add `"content_version": "1.0.0"` as the authoritative
   semver until the loader is changed to read a string version.
2. Give every entry in `concepts[]` a stable, content-independent id:

```json
"concepts": [
  {"id": "bytes", "concept_uid": "elf:concept:bytes:v1", "title": "Bytes and Binary", ...}
]
```

   `concept_uid` must NOT change on a slug rename. Use it as the learner-state
   key in a follow-up change; until then the slug is still the key and the
   alias table bridges renames.
3. When a slug is retired, add a top-level array. This is the only manifest
   field the server acts on today:

```json
"concept_aliases": [
  {"from": "bytes-old", "to": "bytes", "reason": "slug normalised 2026-11-28"}
]
```

   A 1→2 split needs two entries, e.g. `{"from":"split-src","to":"split-a"}`
   and `{"from":"split-src:part2","to":"split-b"}`. The tool's split scenario
   uses exactly this shape.
4. Do not delete a `concepts[]` entry that still has live learner state until
   an alias exists and `concept_deletion_allowed` returns true; the repository
   guard is the enforcement point.

No course file was edited in this change. Owner for the 33 manifest edits:
**founder / course-content owner** (courses/* is outside this package's file
ownership).
