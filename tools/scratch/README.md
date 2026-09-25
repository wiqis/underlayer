# Course authoring scratch space

**Everything in this directory is git-ignored and must never be committed.**
The only tracked file here is this README.

## What belongs here

Working files that exist to *produce* a course and have no value to anyone who
reads the course afterwards:

- throwaway corpora and scratch binaries, while you are still deciding which
  sample to ship
- one-off analysis scripts, before you know whether they earned a permanent
  home
- intermediate dumps, half-decoded tables, notes to yourself
- anything generated rather than authored

The test is simple: **would a learner of the course ever want this?** If the
answer is no, it goes here rather than into git.

## What does NOT belong here

Some things look like scratch and are actually load-bearing course content.
Keep those committed:

| Thing | Why it stays |
|---|---|
| `courses/<name>/assets/samples/*` | The sample files are the *subject* of the lessons. Every hex dump in a lesson is decoded from one of them, so a reader who cannot re-decode them cannot check a single claim. |
| Verification harnesses (`coff_parse.py`, `dwarf_decode.py`, `crosscheck.py`, …) | These courses' whole thesis is that one tool agreeing with another proves nothing. Shipping the second implementation is the proof, and lesson text tells the reader to run it. |
| `courses/<name>/research.md` | The Phase A record of what was verified and what was not. Lessons and the roadmap point at it. |

## Concretely, from the DWARF and COFF courses

- `tools/scratch/check_html_quirks.py` lives here. It was written once to catch
  two `html_cbi` parse failures during authoring, and nothing references it. If
  it ever earns a permanent place, promote it to `tools/` or wire it into
  `scripts/lint-concepts.sh` as a rule — do not leave it here indefinitely.
- Python bytecode caches (`__pycache__/`) are ignored globally rather than
  parked here, because they regenerate wherever the `.py` files happen to live.

## Housekeeping

Empty the directory whenever you like; nothing in it is referenced by a build,
a lesson, or a test. If you are unsure whether something is scratch, leave it
out of git until you are sure — an untracked file costs nothing, and a committed
one is forever.
