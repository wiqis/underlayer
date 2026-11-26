# Journey quality pass — 2026-11-26

Scope: **web only**, `Web/underlayer`. Guiding spec: `docs/learner-first-mandate.md`
(ACTIVE). The guided journey already shipped; this pass measured the served
journey and fixed defects, without rewriting any lesson or technical fact.

## What was measured (before)

Baseline: live server on `http://localhost:9000` (PID 34468, left running), plus
`GET /api/courses` and the served HTML of at least eight lessons spanning ELF,
AArch64 ABI, DWARF, COFF, PE, Mach-O, JVM and WASM (`elf/bytes`,
`a64abi/a64-aapcs`, `dwarf/dwarf-intro`, `coff/coff-intro`, `pe/pe-intro`,
`macho/macho-intro`, `jvm/jvm-intro`, `wasm/wasm-intro`).

| Finding | Concrete evidence |
|---|---|
| **Shell without a runtime — dead journey.** | 11 of the 33 first lessons (`a64abi/a64-aapcs`, `a64asm/a64-asm`, `a64simd/a64-neon`, `a64sys/a64-syscall`, `priv/priv-table`, `simd/simd-width`, `smp/smp-topology`, `x86abi/x86-calling`, `x86asm/x86-asm`, `x86simd/x86-sse`, `x86sys/x86-syscall`) served `class="journey-shell"` and the pre-paint script but **no `function jqBoot`**. `html.journey-active .lesson .unit:not([data-jq-current]) { display: none }` then hid every unit and Start had no listener. Cause: `apply_journey_to_document` returned early whenever a shell was present, but stale `courses/*/output` pages were generated before the runtime landed. |
| **Teaching text rendered after all the chrome.** | Chrome/CDP on `http://localhost:9000/courses/elf/lessons/bytes`: `#ul-journey-stage` top **208**, height **64**, empty; the only visible `unit unit-why` top **762**, height **229** — below Remember this and below the Back/Continue/Deep dive/Pause controls. The shell was inserted before the first unit, but the unit was never moved into the stage. |
| **"Remember this" from an arbitrary `<strong>`.** | Served `data-remember` values: `a64abi/a64-aapcs` → `calling convention`, `it cannot tell you the answer`, `at every branch`; `coff/coff-intro` → `not`, `The compiler`; `dwarf/dwarf-intro` → `file format`; `jvm/jvm-intro` → `a file`; `pe/pe-intro` → `A 1980s MS-DOS program`; `elf/bytes` → `Click on each byte to see its decimal, hex, and ASCII values:` (an instruction ending in a colon). `jpRemember` took the first `<strong>`/`<b>` in the unit, whatever it was. |
| **Retrieval gate asked a stale question.** | `jqRetrieveUnit(i)` walked backwards to the nearest `unit-retrieve`. In `elf/bytes` the retrieve units are at steps 6 and 9 (with `unit-exercises` excluded); steps 7 and 8 therefore repeated the step-5 question instead of asking about the step just finished. `data-recall-q` was derived for every unit but never used by the runtime. |
| Checker baseline | `python tools/journey_quality_check.py http://localhost:9000` → **0 passed, 33 failed, 33 total** (exit 1). |

The rest of the contract was present and verified in the served HTML: arrival card
with aim/meta/one Start action, ribbon `Step N of M`, labelled "Show the full
detail", `disabled` Continue with "I'm stuck - show me" escape hatch, `ul-journey-*`
finish recap with next-lesson link and Deep dive, `ul-journey:` localStorage keys for
step/pause, `:focus-visible` CSS, `keydown` handler, and mobile flex-column rules.

## Fixes (files owned by this pass)

1. **`content/src/journey_inject.ch`** — `apply_journey_to_document` now checks
   shell and runtime separately. A shell without `jqBoot` gets the runtime script
   injected before `</body>` and is otherwise untouched; a complete page is still
   byte-identical. No duplicate shell or duplicate ids.
2. **`content/src/journey_runtime.ch`** + **`content/src/journey_pacing.ch`** —
   `jqStage(u)` moves exactly one unit into `#ul-journey-stage`; `jqUnstage()`
   returns it to the parent and next sibling recorded at boot before the next
   step is staged. `jqDeep()` unstages first, so the full reference reads in
   authored order; `jqReturn()` stages the current step again. Lesson text is
   never cloned or re-authored, and the scripting-off fallback is unchanged.
3. **`content/src/journey_pedagogy.ch`** — `jpRemember` now prefers a complete
   5–25 word sentence from the step's own paragraphs, then a longer existing
   sentence capped at 25 words, then the mandated "No new fact to memorise" text.
   Arbitrary `<strong>`/`<b>` fragments, colon-ended labels and hex-dump rows are
   no longer treated as the key idea. Every word still comes from the lesson.
4. **`content/src/journey_actions.ch`** + **`content/src/journey_shell.ch`** +
   **`content/src/journey_pacing.ch`** — retrieval now asks about `units[i-1]`
   (the step just finished); from step 3 it also asks one question about
   `units[i-2]` ("From earlier: …"). Two labelled "I'm stuck - show me" buttons
   are bound; either reveal marks the step done, so the gate can never deadlock.
   The old backwards `unit-retrieve` search is gone.

## Verification — exact commands and results

Build (the 9000 server holds a lock on `build/underlayer.exe`, so this pass built
to separate binaries):

```powershell
cd D:\Programming\Wiqis\Web\underlayer
& 'D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe' chemical.mod -o build/underlayer-quality4.exe -bm-modules --no-cache
# compile_exit=0 (warnings from shared libraries only)

$env:PORT='9001'; $env:DATABASE_URL='./underlayer.db'; $env:COURSES_DIR='./courses'
$p = Start-Process -FilePath 'D:\Programming\Wiqis\Web\underlayer\build\underlayer-quality4.exe' -WorkingDirectory 'D:\Programming\Wiqis\Web\underlayer' -PassThru -WindowStyle Hidden
# pid=43752
```

Endpoint matrix (all 200):

```
GET /api/health                                  -> 200
GET /courses/elf/lessons/bytes                   -> 200 (122006 bytes, contains journey-shell and jqBoot)
GET /api/courses/elf/lessons/bytes/units         -> 200
```

Checker:

```
python tools/journey_quality_check.py http://localhost:9000
  RESULT: 0 passed, 33 failed, 33 total     (before, exit 1)
python tools/journey_quality_check.py http://localhost:9001 --workers 8
  RESULT: 33 passed, 0 failed, 33 total     (final build, exit 0)
python tools/journey_quality_check.py http://localhost:9001 --lessons elf:bytes,a64abi:a64-aapcs,dwarf:dwarf-intro,coff:coff-intro,pe:pe-intro,macho:macho-intro,jvm:jvm-intro,wasm:wasm-intro --workers 8
  RESULT: 8 passed, 0 failed, 8 total       (exit 0)
python tools/journey_quality_check.py http://localhost:9001 --all --workers 8
  RESULT: 329 passed, 0 failed, 329 total   (final build, every concept of all 33 courses, exit 0)
python tools/lesson_pager_check.py http://localhost:9001
  lesson_pager_check: ALL 35 CHECKS PASSED  (exit 0)
python tools/theme_check.py http://localhost:9001
  theme_check: 11 of 17 CHECKS FAILED      (exit 1) -- identical 12 failure lines on the untouched 9000 server; pre-existing, unrelated to the journey
```

Browser measurement (Chrome via CDP, real click on Start on port 9001):

| Element | Before (9000) | After (9001) |
|---|---|---|
| ribbon | — | bottom **189** |
| `#ul-journey-stage` | top 208, height **64**, empty | top **209**, bottom **492**, height 283 |
| visible `unit unit-why` | top **762**, height 229 | top **209**, bottom **492**, height 283 |
| `ul-journey-remember` | above the unit | top **516** (after the unit) |
| `ul-journey-controls` | above the unit | top **753** |
| visible units / unit inside stage | 1 / no | **1 / yes** (`stageChild: 'unit unit-why'`) |

Step 2 after answering the step-1 action: ribbon bottom −20 < unit top 0 < unit
bottom 257 < Remember this top 281, one visible unit (`unit unit-model`), staged,
`Step 2 of 9`, ask = "You saw: Every file on your computer … made of bytes. In your
own words, what did it mean?" — i.e. the **just-finished** step. At step 3 the
earlier question becomes visible ("From earlier: …") alongside the current one.
Deep dive: 10 visible units in authored order `why, model, reality, example,
interact, retrieve, …`, stage empty, return control visible. Return: `Step 2 of
9`, one visible staged unit again. The CDP tab created for this measurement was
closed afterwards; the other tabs in the shared browser were not touched.

Representative takeaways after the fix (served `data-remember`):

```
elf/bytes        A byte is just a number. / A byte is 8 bits.
a64-aapcs        The rule is SP mod 16 = 0 at a public interface, and a bl is a public interface.
dwarf-intro      DWARF is produced by the compiler, stored in sections the linker keeps, and read by debuggers, profilers, crash reporters, and language runtimes.
coff-intro       You have written int add(int a, int b) and called it from another file, and it worked.
```

## Deliberately not fixed

- **Arrival objective wording.** The mandate asks for "In this step you will be
  able to ___"; the served aim is the manifest's first sentence (e.g.
  `Understanding bytes.`). Changing it platform-wide would mean authoring new
  objective text for 469 lessons, outside a pacing/presentation pass. The
  checker only asserts that the aim exists and is non-empty.
- **Focus is not moved into the new step.** `jqStep` scrolls the stage into view
  and the shell has `:focus-visible` plus a `keydown` handler, but no
  `stage.focus()` call. Keyboard users can still Tab to the controls; a proper
  fix needs an aria-live/focus policy agreed as its own feature. Flagged, not
  silently claimed as done.
- **Stale static output.** `courses/*/output/*.html` are generated and gitignored;
  the pre-rendered files on disk still lack the runtime. The backend patcher now
  repairs them on serve (all 33 lessons verified), but GitHub Pages / `file://`
  copies need `bash scripts/build_static.sh <course>` to be regenerated before
  the offline journey is complete. Generated files were not edited here.
- **Residual takeaway quality.** A few derived takeaways are still a sentence
  with a whitespace artefact before final punctuation (e.g. `Those notes are
  relocations .`) or an early-context sentence rather than the deepest idea.
  They are complete existing sentences and within 25 words; improving them
  further needs per-unit editorial review, not a rule change.
- **`theme_check.py` failures are pre-existing** on both ports; no theme code
  was touched.

## Android / native journey

I did not edit the Android repo. Based on the shared contract
(`docs/native-lesson-contract.md`), the native client renders `units[]` itself
with Compose and has no DOM stage, so the *stage ordering* bug cannot reproduce
there. Two things are worth the Android agent checking from the same data:
(1) the takeaway shown in the native UI comes from the same derived
`data-remember`/`remember` text, so the old "first `<strong>`" defect would have
appeared there too until the server/manifest is regenerated with this build;
(2) the native recall prompt must be derived from the just-finished unit's
`remember`, not from the nearest earlier `unit-retrieve`, or it inherits the
stale-question defect. The unit `order` field remains the unique progress key;
nothing in this pass changes it.

## 2026-11-26 follow-up — a question is not a takeaway

Final browser pass on `elf/elf-identification` found the last pedagogy defect:
the "Remember this" card on a quiz step showed the quiz *question* ("What are
the first 4 bytes of every ELF file?"), and the next step's retrieval prompt
quoted the mandated "No new fact to memorise" line back at the learner.

- `jpSentenceGood` / `jpLooseSentence` now require a fact sentence (`.`/`!`),
  never `?`; `jpQuizFact` uses the correct option's own lesson-sourced
  `data-explain` when a quiz step has no prose fact.
- `jqRecallQA` no longer quotes the no-new-fact line; it asks about the step
  itself and uses the unit's existing recall answer when one is present.
- `tools/journey_quality_check.py` now fails on a takeaway that ends in `?` or
  repeats the unit's recall question. Non-vacuity: `elf:elf-identification`
  scored **35 passed / 1 failed** on the previous build and **36/36** after the
  fix; the full first-lesson sweep scored **68/68** on the final build.

Browser evidence after the fix (step 6 of 8): takeaway = "Bytes 0-3 are the
magic number, 7f 45 4c 46, which spells .ELF."; retrieval ask = "Recall the idea
from Try It. In your own words, what did it mean?"
