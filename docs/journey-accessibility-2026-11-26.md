# Journey accessibility pass — 2026-11-26

Scope: **web only**, `Web/underlayer`. Guiding spec: `docs/learner-first-mandate.md`
(keyboard reachable, focus visible, screen-reader labels, reduced motion, high
contrast). This pass completes the item deliberately deferred by
`docs/journey-quality-pass-2026-11-26.md` ("Focus is not moved into the new
step"). No lesson text, quiz content, or technical fact was changed.

## 1. Before — measured on the old build (port 9000)

Served HTML, `GET /courses/elf/lessons/bytes`:

```
function jqFocusEl              => 0 occurrences
function jqFocusStep            => 0
setAttribute('tabindex', '-1')  => 0
jqDeep()                        => 2   (one is the boot call: jqDeep();return;)
id="ul-journey-answer" aria-live="polite"         => 0
id="ul-journey-answer-earlier" aria-live="polite" => 0
id="ul-journey-finish-head"     => 0
```

Served landmark counts (regex `<main(?:\s|>)`, `role="main"`):

```
/                              main=1 rolemain=0
/courses                       main=1 rolemain=0
/courses/elf                   main=0 rolemain=0   <-- no landmark
/courses/elf/lessons/bytes     main=1 rolemain=1   <-- lesson page, out of scope
```

Consequence: after Start/Continue/Deep dive/Return focus stayed on the button
that was clicked (and became hidden), so a keyboard or screen-reader user was
never told the step changed and had to tab through the chrome to find the new
content. Retrieval answers were revealed visually only.

## 2. Changes (files owned by this pass)

| File | Change |
|---|---|
| `content/src/journey_units.ch` | Added `jqFocusEl(el)` — adds `tabindex="-1"` **at runtime** if absent, then calls `.focus()`. Added `jqFocusStep(u)` — focuses the staged unit's `<h2>`, falling back to the unit itself when a step has no heading. No authored markup and no string-built HTML. |
| `content/src/journey_runtime.ch` | `jqStep(i)` ends with `jqFocusStep(u)`. Every caller (Start, Continue, Back, Resume, Return, arrow keys) is an explicit user action; boot never calls `jqStep`. Boot's saved-deep restore is now `jqDeep(false)`. |
| `content/src/journey_pacing.ch` | `jqDeep(focus)` focuses the full-reference heading (`.lesson h1`) only when called with `true` from the two click bindings; boot passes `false` so load never steals focus. `jqPause()` focuses the single obvious action (`#ul-journey-resume`). `jqFinish()` focuses `#ul-journey-finish-head`. |
| `content/src/journey_shell.ch` | `#ul-journey-finish-head` id added to the recap `<h2>`; `aria-live="polite"` added to both retrieval answer paragraphs. The ribbon keeps `aria-live="polite"`, the stage keeps `aria-live="off"` (the whole lesson is not read out), and feedback keeps `aria-live="polite"`. |
| `content/src/course_landing.ch` | The generic course landing wrapper is now `<main class="course-landing" id="main-content">` … `</main>` (was a `<div>`). One native landmark, no duplicate `role="main"`. `/courses` already had one and was left unchanged. |
| `tools/journey_quality_check.py` | New assertions: focus helpers and runtime `tabindex`, focus call site in `jqStep`, Pause/Finish/Deep-dive focus targets, boot focus guard (`jqDeep(false)`, no `.focus(`/`jqStep(` in the boot body), the three announcement regions, and exactly one `<main>` with no `role="main"` on `/`, `/courses` and every `/courses/<id>`. |

All JS edits are inside `#js { }` blocks, ASCII only, no regex literals, no
string-built markup. The scripting-off fallback and the DOM order fixed by the
previous pass (ribbon → staged unit → Remember → retrieval → feedback →
controls) are unchanged: only the *position of focus* changed.

## 3. Build and verify — exact commands

```powershell
cd D:\Programming\Wiqis\Web\underlayer
& 'D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe' `
  chemical.mod -o build/underlayer-a11y.exe -bm-modules --no-cache
# compile_exit=0 (warnings from shared libraries only; log: build/a11y-build.log)

$env:PORT='9004'; $env:DATABASE_URL='./underlayer.db'; $env:COURSES_DIR='./courses'
$p = Start-Process -FilePath 'D:\Programming\Wiqis\Web\underlayer\build\underlayer-a11y.exe' `
  -WorkingDirectory 'D:\Programming\Wiqis\Web\underlayer' -PassThru -WindowStyle Hidden
# pid=36728; servers on 9000/9001/9002/9003 were left running
```

Endpoint matrix on 9004:

```
GET /api/health                                -> 200 (36 bytes)
GET /courses/elf/lessons/bytes                 -> 200 (122544 bytes)
GET /api/courses/elf/lessons/bytes/units       -> 200 (786 bytes)
```

Checker, non-vacuity (old build, new assertions must fail):

```
python tools/journey_quality_check.py http://localhost:9000 --lessons elf:bytes --workers 8
  RESULT: 2 passed, 34 failed, 36 total  (exit 1)
```

The new failures on 9000 included: `focus management marker missing:
function jqFocusEl`, `… jqFocusStep`, `… setAttribute('tabindex', '-1')`,
`… jqFocusStep(u);`, `… jqFocusEl(jqEl('ul-journey-resume'))`,
`… jqFocusEl(jqEl('ul-journey-finish-head'))`, `… jqDeep(true)`,
`boot restores a saved deep view without the no-focus guard`,
`retrieval answer reveal is not announced`, `earlier retrieval answer reveal
is not announced`, and `expected exactly one <main> landmark, found 0` on all
33 course landing pages. `/` and `/courses` passed, as expected.

Checker, new build:

```
python tools/journey_quality_check.py http://localhost:9004 --lessons elf:bytes --workers 8
  RESULT: 36 passed, 0 failed, 36 total  (exit 0)
python tools/journey_quality_check.py http://localhost:9004 --all --workers 8
  RESULT: 364 passed, 0 failed, 364 total  (exit 0)  # 329 lessons + 35 pages
python tools/lesson_pager_check.py http://localhost:9004
  lesson_pager_check: ALL 35 CHECKS PASSED  (exit 0)
python tools/theme_check.py http://localhost:9004
  theme_check: ALL 56 CHECKS PASSED  (exit 0; 1 optional live-browser check skipped)
```

## 4. After — served DOM evidence (port 9004)

Landmarks:

```
/                              main=1 rolemain=0
/courses                       main=1 rolemain=0
/courses/elf                   main=1 rolemain=0   <-- fixed
/courses/elf/lessons/bytes     main=1 rolemain=1   <-- unchanged, out of scope
```

Focus/announcement markers in the served lesson (`/courses/elf/lessons/bytes`):

```
function jqFocusEl => 1
function jqFocusStep => 1
setAttribute('tabindex', '-1') => 1
jqFocusStep(u); => 1
jqDeep(false) => 1
jqDeep(true) => 2
jqFocusEl(jqEl('ul-journey-resume')) => 1
jqFocusEl(jqEl('ul-journey-finish-head')) => 1
id="ul-journey-answer" aria-live="polite" => 1
id="ul-journey-answer-earlier" aria-live="polite" => 1
id="ul-journey-finish-head" => 1
id="ul-journey-stage" aria-live="off" => 1
```

## 5. Browser proof — real keyboard input via Chrome CDP

`browser-use` CLI, one new tab at `http://localhost:9004/courses/elf/lessons/bytes`
(created for this pass and closed afterwards; the four pre-existing Timeline
tabs were not touched). `localStorage` was empty at the start of the run.

**On load (no explicit action) — focus not stolen:**

```json
{"active":"BODY#","arrivalHidden":false,"ls":[],"tabneg":0}
```

**Click Start (`click_at_xy` at 519, 274.55) — focus moves to staged heading:**

```json
{"tag":"H2","id":"section-0","text":"Why This Matters",
 "isStagedH2":true,"tabindex":"-1","count":"Step 1 of 9"}
```

**Type into the note (`type_text`), then Tab to Continue and press Enter
(`press_key`) — focus moves to the next staged heading:**

```
focused before Enter: ul-journey-continue
{"tag":"H2","id":"section-1","text":"A Simple Model",
 "isStagedH2":true,"tabindex":"-1","count":"Step 2 of 9",
 "units":1,"stagedClass":"unit unit-model"}
```

**Click Deep dive (556.3, 697.2) — focus moves to the full-reference heading;
all 10 units restored:**

```json
{"tag":"H1","id":"","text":"Bytes and Binary","tabindex":"-1",
 "deepClass":"journey-shell journey-deep","activeClass":"dark",
 "returnVisible":true,"visibleUnits":10}
```

**Click Return (323.5, 588.9) — step re-staged and its heading focused again:**

```json
{"tag":"H2","id":"section-1","text":"A Simple Model",
 "isStagedH2":true,"tabindex":"-1","count":"Step 2 of 9",
 "stagedClass":"unit unit-model","deepClass":"journey-shell"}
```

**Pause / Resume — focus stays on the single obvious action, then returns to
the step:**

```
after Pause:  {"tag":"BUTTON","id":"ul-journey-resume",
               "text":"Resume where I left off","pausedHidden":false}
after Resume: {"tag":"H2","id":"section-1","text":"A Simple Model",
               "isStagedH2":true,"count":"Step 2 of 9"}
```

**Focus ring under keyboard input** (ArrowLeft → staged heading):

```json
{"tag":"H2","id":"section-0","text":"Why This Matters",
 "focusVisible":true,"outline":"solid","outlineWidth":"2.8px","count":"Step 1 of 9"}
```

Screenshot captured at
`C:\Users\ACER\.config\browser-harness\tmp\shot.png` (harness temp path).

**Retrieval reveal is a live region** (step 2, click reveal):

```json
{"ariaLive":"polite","hidden":false,
 "text":"Every file on your computer - including executables, images, and documents - is ",
 "revealLabel":"Answer shown - continue when ready","contDisabled":false}
```

## 6. Checklist items I would tick (NOT edited here)

`docs/features-complete.md` is owned by another agent in this wave, so I did
not touch it. The owner should add/tick, with priority P1:

- **2.2.124** — Guided lesson journey focus management: staged unit's `<h2>`
  receives a runtime `tabindex="-1"` and focus after Start / Continue / Back /
  Resume / Return / arrow keys; Deep dive focuses the full-reference `<h1>`;
  Pause focuses Resume; the recap focuses its heading; boot never steals focus.
  Chrome CDP evidence above.
- **2.2.125** — Course landing and course index semantics: exactly one native
  `<main>` per page and no duplicate `role="main"`; retrieval answers are
  polite live regions while the stage stays `aria-live="off"`. Measured on
  `/`, `/courses` and all 33 `/courses/<id>` pages.
- Amend **2.2.123** (already ticked) to record the new checker assertions and
  the 364/364 result; the checker file itself changed in this pass.

## 7. Deferred / not verified

- No real screen-reader (NVDA / JAWS / VoiceOver) mannequin pass. Browser
  evidence is Chrome CDP: `document.activeElement`, `matches(':focus-visible')`
  and computed outline only.
- Browser focus was exercised on `elf/bytes` only; the served-HTML checker
  covers all 329 lessons for the presence of the contract, not a live focus
  move on every lesson. Steps whose units have no `<h2>` fall back to focusing
  the unit container itself.
- The lesson page still carries both `<main>` and `role="main"`; it is a
  different renderer and was out of scope for this pass.
- Generated `courses/*/output/*.html` are gitignored. The backend repairs them
  on serve (all 33 verified), but `file://` / GitHub Pages copies need
  `bash scripts/build_static.sh <course>` to pick up the new focus runtime.
- The arrival screen deliberately does not focus Start on load; that is the
  "do not steal focus on initial page load" rule, not an omission.
- I did not edit ELF quiz content, `docs/features-complete.md`, or any Android
  file. Servers on 9000/9001/9002/9003 were not stopped; the 9003 health probe
  timed out during measurement but that server was not touched.
