Yes. And I think music fits **Underlayer unusually well**, because composition has the same problem as low-level CS: there is a huge amount of *information*, but relatively little material that systematically trains the learner to **see, hear, analyze, and construct** increasingly complex things.

The important distinction is that I would **not** make an "AI music course generator." I would make a **composition-training system** inside Underlayer.

The end state you described is excellent:

> **A musician who has trained composition like an athlete trains a sport.**

That means the learner shouldn't merely know music theory. They should have thousands of small acts of composition, analysis, imitation, transformation, correction, and reconstruction behind them.

And yes, I would absolutely make **notation/sheet music a hard requirement**. If the AI says "try a descending chromatic line" but doesn't provide the actual musical example, the course is incomplete.

---

# What the music branch of Underlayer should produce

I'd define **two major capabilities**.

### 1. Composition athlete

The learner can:

* generate melodies
* develop motifs
* write bass lines
* write chord progressions
* harmonize melodies
* write counterpoint
* create rhythmic ideas
* develop themes
* vary motifs
* write transitions
* create tension and release
* control pacing
* write introductions
* write endings
* orchestrate
* arrange
* voice chords
* write for different instruments
* write pop songs
* write classical music
* write cinematic music
* imitate styles
* deliberately break conventions
* revise weak compositions
* diagnose why something sounds weak
* finish compositions instead of endlessly starting them

### 2. Musical analyst

The learner can take actual music and ask:

> **"Why does this work?"**

Then inspect the score and identify:

* form
* phrases
* motifs
* harmony
* melody
* rhythm
* voice leading
* cadences
* modulation
* tension
* repetition
* variation
* development
* instrumentation
* texture
* register
* dynamics
* orchestration
* arrangement

And importantly:

> **hear something → locate it in the score → explain it → reproduce it.**

That last part is extremely important.

---

# And I would add a third capability

## 3. Musical reconstruction

Give the learner a finished piece and ask them to **reverse engineer it**.

For example:

```text
Song
 ↓
Identify form
 ↓
Mark phrases
 ↓
Extract melody
 ↓
Identify chords
 ↓
Identify bass
 ↓
Identify rhythmic patterns
 ↓
Identify motifs
 ↓
Identify development techniques
 ↓
Reconstruct the arrangement
 ↓
Write something using the same technique
```

This is how you turn analysis into composition ability.

---

# The AI must be forced to generate actual music

This should be one of the strongest rules in the music specification.

**Text-only music education is insufficient for Underlayer's composition curriculum.**

Whenever a musical concept can be demonstrated through notation, the course should provide actual notation.

For example, if teaching:

> melodic sequence

the course should not merely say:

> "A sequence repeats a melodic idea at another pitch."

It should show something like:

```text
Original motif:
♪ C D E G | E D C

Sequence:
♪ D E F A | F E D

Sequence:
♪ E F G B | G F E
```

And then let the learner:

* see it
* hear it
* modify it
* write their own version
* answer questions about it.

---

# AI-generated notation is therefore a hard requirement

I would make the course generator capable of producing a **machine-readable musical representation**, not merely an image of sheet music.

That distinction matters enormously.

The AI should ideally generate:

```text
musical structure
        ↓
notation representation
        ↓
rendered sheet music
        ↓
audio rendering
        ↓
interactive score
```

So the learner can:

**read → hear → modify → replay → analyze.**

This is far more powerful than static sheet-music images.

---

# The AI doesn't have to "be able to compose sheet music" in one shot

You can constrain the system so that **a course lesson is not complete until its musical examples are validated**.

For example:

```text
AI proposes musical example
        ↓
notation generated
        ↓
notation rendered
        ↓
music played/rendered
        ↓
AI checks result
        ↓
musical theory check
        ↓
notation check
        ↓
example accepted
```

And for important exercises:

```text
Question
   ↓
Expected musical result
   ↓
Validation rules
   ↓
Learner composition
   ↓
Feedback
```

That's where this could become much more than an AI-written textbook.

---

# The curriculum I would build

I wouldn't make "Music Theory 101."

I'd create a **large progression of composition and analysis courses**.

Something like this:

**Restructured 2026-10-01. The 309 items below are unchanged.** No item was
added, removed, merged into another bullet, reworded, or re-ticked. What
changed is that the 309 un-started items, which sat flat under 15 topic
sections, are now grouped into **8 planned courses** instead, and every one
of them names the course that will teach it. The check is
`python3 tools/music_todo_check.py`: it proves the multiset of item titles
is identical to the pre-restructure file and exits non-zero if it is not.
This is the same move already applied to the systems roadmap in
`docs/courses-todo.md`, for the same reason: *"courses in there are also
too many, we should reduce courses before we start there."*

No music course is built, so nothing shipped was touched. There is no music
directory, `manifest.json`, verifier or harness; the slug is the course id a
build is expected to use and the concept id on each line is the concept that
build is expected to create. Both are proposals. The roadmap items are not.

## Summary — the 8 planned courses

| # | Planned course | Slug | Items | Curriculum sections it absorbs |
|---|---|---|---|---|
| 1 | Music Foundations and Notation | `music-foundations` | 34 | Foundation (14); MuseScore / Notation (20) |
| 2 | Harmony and Counterpoint | `music-harmony` | 37 | Harmony (25); Counterpoint (12) |
| 3 | Form and Analysis | `music-form` | 38 | Form (20); Analysis (18) |
| 4 | Composition | `music-composition` | 47 | Composition Training (19); Composition Techniques (28) |
| 5 | Genre Composition | `music-genres` | 43 | Pop Composition (25); Classical Composition (18) |
| 6 | Orchestration and Arrangement | `music-orchestration` | 22 | Orchestration & Arrangement (22) |
| 7 | Composition Drills and Style | `music-drills` | 46 | Composition Drills (25); Style Analysis (21) |
| 8 | Integrated and Advanced Composition | `music-integrated` | 42 | Integrated Composition Courses (14); Advanced "Composition Athlete" Training (28) |
| | **Total** | | **309** | 15 sections, all of them |

Each section moved whole. None of the 15 was cut, and no section was split
across two courses.

### Why 8 courses and not 15 sections

A course is not a folder of pages. Each one costs a `chemical.mod`, a
`manifest.json`, a build entry point, a `tools/verify_<course>.py`, a
`crosscheck.py` harness with its recorded output, a landing page, a route, a
verifier pass, and a commit that has to stay green. That overhead is paid
**per course**, and it is the part an AI agent pays over and over while
trying to finish a roadmap. For music it is worse than the list suggests,
because this document's own hard requirement — *never let a music lesson
remain purely verbal* — means a music course also carries the notation and
playback pipeline described above, and that is per-concept work.

Read as one course per section, the 309 items ask for 15 builds. Read as 8,
they ask for 8. The item count is identical; only the number of times the
fixed cost is paid changes.

### Grouping rules applied

Grouped by **what the learner is being trained to do**, not by where the
section happened to sit. The reasoning for the four non-obvious moves:

- **MuseScore / Notation goes with Foundation, not beside it.** Notation is
  the *tool* the foundation is learned in, and the original section says so
  itself — *"this deserves its own learning track"*. A learner who cannot
  enter a note is not ready to be taught a chord, so a course that taught
  notation *after* tonality would have to teach notation twice: once as
  content and once as remediation for the concepts above it. Keeping the 20
  notation items with the 14 foundation items also puts the notation
  pipeline where it is first needed. This is the one move that changes a
  section's position rather than its neighbours'.
- **Harmony and Counterpoint are one course.** They are the same subject at
  two levels: harmony is the vertical arrangement of notes into chords and
  their motion, counterpoint is the horizontal arrangement of lines against
  each other, and neither is learnable without the other — a second species
  is defined by how it behaves over a bass, and a cadence is defined by the
  voices that reach it. Splitting them into a course each is defensible
  only if the pair turns out to be genuinely unfinishable at 37 items, and
  nothing in the plan suggests it is. If a build later finds counterpoint
  needs its own landing page, that is a **module** split inside
  `music-harmony`, not a ninth course.
- **Drills and Style Analysis are one course.** Neither introduces new
  knowledge. A drill is applied practice of something already taught; a style
  analysis is applied practice of the same analysis, run against a real
  repertoire. They are the *applied* half of the curriculum and they share a
  method — take it apart, put it back together, write your own — so together
  they are the largest applied block in the plan at 46 items. Splitting them
  would produce two courses of pure practice with no knowledge to practise
  on board.
- **Orchestration & Arrangement stays alone, deliberately.** It is 22 items
  and it is tempting to fold it into genre composition, where three of its
  titles already appear. It is not the same skill. Writing the line and
  choosing the line are one job; voicing that line for a cellist, a horn
  player and a percussion section, balancing their registers, and hearing
  the result is a different job with a different failure mode, and it is the
  one the original capability list names separately from *orchestrate* and
  *arrange*. A course that taught both would either teach orchestration
  badly or teach it twice. It is also the smallest planned course here, and
  that is the right answer for it rather than a symptom of leftovers.

Deliberately **not** merged:

- **Not merged by size.** `music-orchestration` (22) and
  `music-foundations` (34) are the two smallest and are the furthest apart in
  the curriculum. Proximity in the table is not a reason to merge; a reader
  who has finished orchestration does not want the foundations.
- **Not merged for tidiness.** `music-form` (38) sits between
  `music-harmony` (37) and `music-composition` (47), and stays separate:
  analysing a sonata and composing a melody are different acts, and the
  original plan says so by naming the analyst a separate capability from the
  composition athlete.
- **The 8 duplicate titles are kept as duplicates.** `Learn Musical Phrases`,
  `Learn Sonata Form`, `Learn Suspensions`, `Learn Theme and Variations`,
  `Learn Motif Development`, and `Learn Writing for Orchestra` / `for Piano` /
  `for String Quartet` each appear on two lines in the original. A set-based
  check would pass while a line had been deleted, so the check is a
  **multiset**, and each of the 8 pairs shares one concept id and carries a
  note saying which course the other line of the pair went to. The founder
  said teach everything, not miss anything: a duplicate is a genuine repeat
  of a real topic, not an error to collapse.

### The size target, and the arithmetic behind it

This is a real tension and it is stated rather than hidden.

The 32 built course directories run **4 to 24 concepts** — `elf`, `pe` and
`macho` at 24, `dwarf` at 23, `coff`, `obj` and `jvm` at 18, `rvabi`, `rvat`
and `rvpriv` at 4 — excluding `hat`, which is a 69-concept test-prep course
and not part of the comparison. Counted from the `manifest.json` of each
built course, not estimated.

These 8 courses average **38.6 items** (range 22–47). That is slightly
below the mean of 48.4 the systems roadmap settled on, and the arithmetic
that followed there follows here.

The systems roadmap could *measure* its item-to-concept ratio, because 39 of
its items are ticked and built: 1.3 concepts per item on x86-64, 1.9 on
RISC-V, 2.1 on AArch64. **No music course is built, so there is no measured
music ratio and this document does not claim one.** What can be reasoned is
its direction, and the direction is *up*, not down:

- A fair number of music items are single objects, exactly the size of a
  systems item: `Learn Seventh Chords`, `Learn Suspensions`, `Learn Canon`,
  `Learn Rondo Form`, `Learn MIDI in MuseScore`. These are one concept each,
  which is the floor.
- But 33 of the 309 items are not subjects at all. They are exercise
  families and whole pieces: the 20 `Write 10 ...` drills, the 5 `Compose
  10 ...` drills, the 14 `Compose a ... From Scratch` items, and the
  constraint items in the advanced block, where `Composition Under
  Constraints` or `Composition With Restricted Harmony` each need a rubric,
  several worked variants and a scoring rule. No systems roadmap item
  carries that much. Each of these is 2–5 concepts.
- So the reasoned range is **1.5 to 3.0 concepts per item**, and the two ends
  are not spread randomly across the eight courses. `music-foundations` and
  `music-harmony` sit at the bottom, where the items are objects — a chord
  type, a cadence, a scale. `music-drills` and `music-integrated` sit at the
  top, where the items are exercises and finished pieces.

At 1.5–3.0, a 38.6-item planned music course is **58 to 116 concepts**,
which is **2.4x to 4.8x** the largest course ever built. The systems case was
3–4x. Music is the same order of magnitude and slightly worse at the top
end. Four consequences, stated plainly:

1. **A planned music course is not one build.** It is a landing page, one
   manifest, one verifier and one harness covering 3–6 modules built and
   committed separately, each module landing as its own concept set with its
   own harness checks. The saving is that the per-course overhead is paid
   once; the per-concept work is still committed in reviewable pieces.
2. **The per-concept cost is higher here, not lower.** A systems concept
   needs its verifier to pass. A music concept needs its verifier to pass
   *and* its notation to survive the validation pipeline this document
   requires — generated, rendered, played, theory-checked, accepted. That is
   the rule *"a course lesson is not complete until its musical examples are
   validated"*, and it makes the module split more necessary for music, not
   less.
3. **`music-drills` should not be built as concepts at all.** 46 items of
   5-minute challenges and style recreations is a **drill bank** with a
   generator and a scoring rule, not 70–140 hand-written concept pages. This
   is a genuine divergence from how the systems roadmap should be built, and
   it is the one place where the right unit is smaller than a concept. If the
   drill bank is not built, the 116-concept figure is not a build plan.
4. **The alternative fails by arithmetic, not by taste.** To stay at or
   below 24 concepts, a course holds 8–16 items, so 309 items needs **20 to
   39 courses** — more courses than the 15 sections being consolidated, so it
   defeats the instruction instead of serving it. 8 is the number where the
   fixed cost is paid once per *subject* rather than once per *line of a
   checklist*.

A further split into modules, not courses, gets the size back down without
paying that cost again. That is the lever, and it costs nothing to hold in
reserve.

### The 15 original sections, and where their items went

Every section below kept its argument. What moved is the checklist under it.

| Original section | Items | Now in |
|---|---|---|
| Foundation | 14 | Planned course 1, `music-foundations` |
| MuseScore / Notation | 20 | Planned course 1, `music-foundations` |
| Harmony | 25 | Planned course 2, `music-harmony` |
| Counterpoint | 12 | Planned course 2, `music-harmony` |
| Form | 20 | Planned course 3, `music-form` |
| Analysis | 18 | Planned course 3, `music-form` |
| Composition Training | 19 | Planned course 4, `music-composition` |
| Composition Techniques | 28 | Planned course 4, `music-composition` |
| Pop Composition | 25 | Planned course 5, `music-genres` |
| Classical Composition | 18 | Planned course 5, `music-genres` |
| Orchestration & Arrangement | 22 | Planned course 6, `music-orchestration` |
| Composition Drills | 25 | Planned course 7, `music-drills` |
| Style Analysis | 21 | Planned course 7, `music-drills` |
| Integrated Composition Courses | 14 | Planned course 8, `music-integrated` |
| Advanced "Composition Athlete" Training | 28 | Planned course 8, `music-integrated` |

---

# The 15 original sections, prose kept

This is the argument for the curriculum above, in the order it was written,
with the checklists removed because they now live in the 8 courses. No
sentence was cut. Each pointer sits exactly where its checklist was.

## Foundation


> Its 14 items are now in **Planned course 1 of 8**, `music-foundations`, listed in full there.

But those are **prerequisites**, not the destination.

---

# Composition Training

Then:

> Its 19 items are now in **Planned course 4 of 8**, `music-composition`, listed in full there.

---

# Harmony

Then increasingly difficult:

> Its 25 items are now in **Planned course 2 of 8**, `music-harmony`, listed in full there.

---

# Counterpoint

This should be a **major Underlayer course family**, not a chapter.

> Its 12 items are now in **Planned course 2 of 8**, `music-harmony`, listed in full there.

And crucially:

> **Write hundreds of small counterpoint exercises.**

Not just read about counterpoint.

---

# Form

This is another huge area.

> Its 20 items are now in **Planned course 3 of 8**, `music-form`, listed in full there.

---

# Pop Composition

This should be a complete discipline rather than an afterthought.

> Its 25 items are now in **Planned course 5 of 8**, `music-genres`, listed in full there.

---

# Classical Composition


> Its 18 items are now in **Planned course 5 of 8**, `music-genres`, listed in full there.

---

# Orchestration & Arrangement


> Its 22 items are now in **Planned course 6 of 8**, `music-orchestration`, listed in full there.

---

# Analysis

This should be one of the **most important Underlayer families**.

> Its 18 items are now in **Planned course 3 of 8**, `music-form`, listed in full there.

The final one is particularly important.

---

# Composition Techniques

This is where your "composition athlete" idea really becomes powerful.

> Its 28 items are now in **Planned course 4 of 8**, `music-composition`, listed in full there.

---

# Composition Drills

This is the part I would make **radically different from normal music education**.

Instead of:

> "Here's a lesson about motif development."

The learner repeatedly gets:

> **5-minute composition challenge**

For example:

> Its 25 items are now in **Planned course 7 of 8**, `music-drills`, listed in full there.

Eventually:

This is how you get the **athlete**.

---

# Style Analysis

Instead of teaching "styles" as facts, make the learner reverse-engineer them.

> Its 21 items are now in **Planned course 7 of 8**, `music-drills`, listed in full there.

Then:

---

# MuseScore / Notation

Since you specifically want the learner to **compose using notation**, this deserves its own learning track.

> Its 20 items are now in **Planned course 1 of 8**, `music-foundations`, listed in full there.

---

# Integrated Composition Courses

Eventually I would have courses that deliberately combine everything.

> Its 14 items are now in **Planned course 8 of 8**, `music-integrated`, listed in full there.

---

# Advanced "Composition Athlete" Training

This should eventually become the culmination of the entire music branch.

> Its 28 items are now in **Planned course 8 of 8**, `music-integrated`, listed in full there.

---


# The 8 planned courses (309 items)

Nothing below is built. The slug is the course id a build is expected to use;
the concept id on each line is the concept that build is expected to create.
Both are proposals; the roadmap items themselves are not.

**The concept id rule.** The title lowercased and hyphenated, ASCII, with a
leading `learn-` dropped because the verb labels the item rather than naming
the subject — the same rule `docs/courses-todo.md` uses, extended to the
verbs this document starts its titles with. So `Learn MuseScore From First
Principles` is `musescore-from-first-principles` and `Recreate a Baroque
Composition Technique` is `recreate-a-baroque-composition-technique`. Eight
titles sit on two lines each; each pair shares one concept id and says so.

## Planned course 1 of 8 — Music Foundations and Notation

Slug `music-foundations`. **34 items.**

Absorbs **Foundation** (14 items), **MuseScore / Notation** (20 items).

* [ ] Learn Musical Notation  — `music-foundations`, from Foundation, concept `musical-notation`
* [ ] Learn Rhythm and Meter  — `music-foundations`, from Foundation, concept `rhythm-and-meter`
* [ ] Learn Intervals  — `music-foundations`, from Foundation, concept `intervals`
* [ ] Learn Scales  — `music-foundations`, from Foundation, concept `scales`
* [ ] Learn Major and Minor Tonality  — `music-foundations`, from Foundation, concept `major-and-minor-tonality`
* [ ] Learn Chords  — `music-foundations`, from Foundation, concept `chords`
* [ ] Learn Diatonic Harmony  — `music-foundations`, from Foundation, concept `diatonic-harmony`
* [ ] Learn Cadences  — `music-foundations`, from Foundation, concept `cadences`
* [ ] Learn Melody  — `music-foundations`, from Foundation, concept `melody`
* [ ] Learn Musical Phrases  — `music-foundations`, from Foundation, concept `musical-phrases`. The phrase as a unit of form is taught in `music-form`; this line is the phrase itself
* [ ] Learn Musical Form  — `music-foundations`, from Foundation, concept `musical-form`
* [ ] Learn Dynamics and Articulation  — `music-foundations`, from Foundation, concept `dynamics-and-articulation`
* [ ] Learn Musical Texture  — `music-foundations`, from Foundation, concept `musical-texture`
* [ ] Learn Register and Range  — `music-foundations`, from Foundation, concept `register-and-range`
* [ ] Learn MuseScore From First Principles  — `music-foundations`, from MuseScore / Notation, concept `musescore-from-first-principles`
* [ ] Learn Entering Notes in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `entering-notes-in-musescore`
* [ ] Learn Rhythm Entry in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `rhythm-entry-in-musescore`
* [ ] Learn Chords in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `chords-in-musescore`
* [ ] Learn Multiple Voices in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `multiple-voices-in-musescore`
* [ ] Learn Ties and Slurs in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `ties-and-slurs-in-musescore`
* [ ] Learn Articulations in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `articulations-in-musescore`
* [ ] Learn Dynamics in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `dynamics-in-musescore`
* [ ] Learn Tempo and Expression in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `tempo-and-expression-in-musescore`
* [ ] Learn Lyrics in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `lyrics-in-musescore`
* [ ] Learn Drum Notation in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `drum-notation-in-musescore`
* [ ] Learn Guitar Notation in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `guitar-notation-in-musescore`
* [ ] Learn Piano Notation in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `piano-notation-in-musescore`
* [ ] Learn Score Layout in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `score-layout-in-musescore`
* [ ] Learn Parts in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `parts-in-musescore`
* [ ] Learn Playback in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `playback-in-musescore`
* [ ] Learn MIDI in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `midi-in-musescore`
* [ ] Learn MusicXML in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `musicxml-in-musescore`
* [ ] Learn Exporting Scores in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `exporting-scores-in-musescore`
* [ ] Learn Producing Professional Sheet Music in MuseScore  — `music-foundations`, from MuseScore / Notation, concept `producing-professional-sheet-music-in-musescore`

## Planned course 2 of 8 — Harmony and Counterpoint

Slug `music-harmony`. **37 items.**

Absorbs **Harmony** (25 items), **Counterpoint** (12 items).

* [ ] Learn Functional Harmony  — `music-harmony`, from Harmony, concept `functional-harmony`
* [ ] Learn Voice Leading  — `music-harmony`, from Harmony, concept `voice-leading`
* [ ] Learn Chord Inversions  — `music-harmony`, from Harmony, concept `chord-inversions`
* [ ] Learn Non-Chord Tones  — `music-harmony`, from Harmony, concept `non-chord-tones`
* [ ] Learn Secondary Dominants  — `music-harmony`, from Harmony, concept `secondary-dominants`
* [ ] Learn Secondary Leading-Tone Chords  — `music-harmony`, from Harmony, concept `secondary-leading-tone-chords`
* [ ] Learn Applied Chords  — `music-harmony`, from Harmony, concept `applied-chords`
* [ ] Learn Modal Mixture  — `music-harmony`, from Harmony, concept `modal-mixture`
* [ ] Learn Borrowed Chords  — `music-harmony`, from Harmony, concept `borrowed-chords`
* [ ] Learn Chromatic Harmony  — `music-harmony`, from Harmony, concept `chromatic-harmony`
* [ ] Learn Diminished Chords  — `music-harmony`, from Harmony, concept `diminished-chords`
* [ ] Learn Augmented Chords  — `music-harmony`, from Harmony, concept `augmented-chords`
* [ ] Learn Extended Chords  — `music-harmony`, from Harmony, concept `extended-chords`
* [ ] Learn Seventh Chords  — `music-harmony`, from Harmony, concept `seventh-chords`
* [ ] Learn Ninth Chords  — `music-harmony`, from Harmony, concept `ninth-chords`
* [ ] Learn Eleventh Chords  — `music-harmony`, from Harmony, concept `eleventh-chords`
* [ ] Learn Thirteenth Chords  — `music-harmony`, from Harmony, concept `thirteenth-chords`
* [ ] Learn Suspensions  — `music-harmony`, from Harmony, concept `suspensions`. Its use as a delaying technique is taught in `music-composition`; this line is the chord
* [ ] Learn Pedal Points  — `music-harmony`, from Harmony, concept `pedal-points`
* [ ] Learn Passing Chords  — `music-harmony`, from Harmony, concept `passing-chords`
* [ ] Learn Neighbor Chords  — `music-harmony`, from Harmony, concept `neighbor-chords`
* [ ] Learn Tritone Substitution  — `music-harmony`, from Harmony, concept `tritone-substitution`
* [ ] Learn Harmonic Rhythm  — `music-harmony`, from Harmony, concept `harmonic-rhythm`
* [ ] Learn Harmonic Tension  — `music-harmony`, from Harmony, concept `harmonic-tension`
* [ ] Learn Harmonic Color  — `music-harmony`, from Harmony, concept `harmonic-color`
* [ ] Learn Species Counterpoint  — `music-harmony`, from Counterpoint, concept `species-counterpoint`
* [ ] Learn Two-Part Counterpoint  — `music-harmony`, from Counterpoint, concept `two-part-counterpoint`
* [ ] Learn Three-Part Counterpoint  — `music-harmony`, from Counterpoint, concept `three-part-counterpoint`
* [ ] Learn Contrapuntal Motion  — `music-harmony`, from Counterpoint, concept `contrapuntal-motion`
* [ ] Learn Imitative Counterpoint  — `music-harmony`, from Counterpoint, concept `imitative-counterpoint`
* [ ] Learn Canon  — `music-harmony`, from Counterpoint, concept `canon`
* [ ] Learn Inversion in Counterpoint  — `music-harmony`, from Counterpoint, concept `inversion-in-counterpoint`
* [ ] Learn Fugue Subject Construction  — `music-harmony`, from Counterpoint, concept `fugue-subject-construction`
* [ ] Learn Fugue Countersubjects  — `music-harmony`, from Counterpoint, concept `fugue-countersubjects`
* [ ] Learn Fugue Episodes  — `music-harmony`, from Counterpoint, concept `fugue-episodes`
* [ ] Learn Fugue Development  — `music-harmony`, from Counterpoint, concept `fugue-development`
* [ ] Learn Contrapuntal Texture  — `music-harmony`, from Counterpoint, concept `contrapuntal-texture`

## Planned course 3 of 8 — Form and Analysis

Slug `music-form`. **38 items.**

Absorbs **Form** (20 items), **Analysis** (18 items).

* [ ] Learn Musical Phrases  — `music-form`, from Form, concept `musical-phrases`. The phrase itself is taught in `music-foundations`; this line is the phrase as a unit of form
* [ ] Learn Binary Form  — `music-form`, from Form, concept `binary-form`
* [ ] Learn Ternary Form  — `music-form`, from Form, concept `ternary-form`
* [ ] Learn Rounded Binary Form  — `music-form`, from Form, concept `rounded-binary-form`
* [ ] Learn Rondo Form  — `music-form`, from Form, concept `rondo-form`
* [ ] Learn Theme and Variations  — `music-form`, from Form, concept `theme-and-variations`. The classical use of the form is listed in `music-genres`; this line is the form itself
* [ ] Learn Sonata Form  — `music-form`, from Form, concept `sonata-form`. The classical use of the form is listed in `music-genres`; this line is the form itself
* [ ] Learn Sonata-Rondo Form  — `music-form`, from Form, concept `sonata-rondo-form`
* [ ] Learn Through-Composed Form  — `music-form`, from Form, concept `through-composed-form`
* [ ] Learn Strophic Form  — `music-form`, from Form, concept `strophic-form`
* [ ] Learn Verse-Chorus Form  — `music-form`, from Form, concept `verse-chorus-form`
* [ ] Learn AABA Song Form  — `music-form`, from Form, concept `aaba-song-form`
* [ ] Learn Bridge Sections  — `music-form`, from Form, concept `bridge-sections`
* [ ] Learn Pre-Choruses  — `music-form`, from Form, concept `pre-choruses`
* [ ] Learn Introductions  — `music-form`, from Form, concept `introductions`
* [ ] Learn Transitions  — `music-form`, from Form, concept `transitions`
* [ ] Learn Breakdowns  — `music-form`, from Form, concept `breakdowns`
* [ ] Learn Instrumental Solos  — `music-form`, from Form, concept `instrumental-solos`
* [ ] Learn Outros  — `music-form`, from Form, concept `outros`
* [ ] Learn Large-Scale Musical Architecture  — `music-form`, from Form, concept `large-scale-musical-architecture`
* [ ] Learn How to Analyze a Melody  — `music-form`, from Analysis, concept `how-to-analyze-a-melody`
* [ ] Learn How to Analyze Harmony  — `music-form`, from Analysis, concept `how-to-analyze-harmony`
* [ ] Learn How to Analyze Rhythm  — `music-form`, from Analysis, concept `how-to-analyze-rhythm`
* [ ] Learn How to Analyze Phrases  — `music-form`, from Analysis, concept `how-to-analyze-phrases`
* [ ] Learn How to Analyze Form  — `music-form`, from Analysis, concept `how-to-analyze-form`
* [ ] Learn How to Analyze Counterpoint  — `music-form`, from Analysis, concept `how-to-analyze-counterpoint`
* [ ] Learn How to Analyze Texture  — `music-form`, from Analysis, concept `how-to-analyze-texture`
* [ ] Learn How to Analyze Orchestration  — `music-form`, from Analysis, concept `how-to-analyze-orchestration`
* [ ] Learn How to Analyze a Pop Song  — `music-form`, from Analysis, concept `how-to-analyze-a-pop-song`
* [ ] Learn How to Analyze a Classical Piece  — `music-form`, from Analysis, concept `how-to-analyze-a-classical-piece`
* [ ] Learn How to Analyze a Piano Piece  — `music-form`, from Analysis, concept `how-to-analyze-a-piano-piece`
* [ ] Learn How to Analyze a String Quartet  — `music-form`, from Analysis, concept `how-to-analyze-a-string-quartet`
* [ ] Learn How to Analyze an Orchestral Score  — `music-form`, from Analysis, concept `how-to-analyze-an-orchestral-score`
* [ ] Learn How to Analyze a Film Score  — `music-form`, from Analysis, concept `how-to-analyze-a-film-score`
* [ ] Learn How to Analyze a Jazz Standard  — `music-form`, from Analysis, concept `how-to-analyze-a-jazz-standard`
* [ ] Learn How to Analyze a Song From Sheet Music  — `music-form`, from Analysis, concept `how-to-analyze-a-song-from-sheet-music`
* [ ] Learn How to Analyze Music by Ear and Score  — `music-form`, from Analysis, concept `how-to-analyze-music-by-ear-and-score`
* [ ] Learn How to Reverse Engineer a Composition  — `music-form`, from Analysis, concept `how-to-reverse-engineer-a-composition`

## Planned course 4 of 8 — Composition

Slug `music-composition`. **47 items.**

Absorbs **Composition Training** (19 items), **Composition Techniques** (28 items).

* [ ] Learn to Write Melodies  — `music-composition`, from Composition Training, concept `to-write-melodies`
* [ ] Learn Motif Construction  — `music-composition`, from Composition Training, concept `motif-construction`
* [ ] Learn Motif Development  — `music-composition`, from Composition Training, concept `motif-development`
* [ ] Learn Melodic Variation  — `music-composition`, from Composition Training, concept `melodic-variation`
* [ ] Learn Melodic Sequences  — `music-composition`, from Composition Training, concept `melodic-sequences`
* [ ] Learn Repetition and Contrast  — `music-composition`, from Composition Training, concept `repetition-and-contrast`
* [ ] Learn Musical Tension and Release  — `music-composition`, from Composition Training, concept `musical-tension-and-release`
* [ ] Learn Phrase Construction  — `music-composition`, from Composition Training, concept `phrase-construction`
* [ ] Learn Antecedent and Consequent Phrases  — `music-composition`, from Composition Training, concept `antecedent-and-consequent-phrases`
* [ ] Learn Periods and Sentences  — `music-composition`, from Composition Training, concept `periods-and-sentences`
* [ ] Learn Rhythmic Motifs  — `music-composition`, from Composition Training, concept `rhythmic-motifs`
* [ ] Learn Rhythmic Development  — `music-composition`, from Composition Training, concept `rhythmic-development`
* [ ] Learn Melodic Contour  — `music-composition`, from Composition Training, concept `melodic-contour`
* [ ] Learn Melodic Direction  — `music-composition`, from Composition Training, concept `melodic-direction`
* [ ] Learn Melodic Range  — `music-composition`, from Composition Training, concept `melodic-range`
* [ ] Learn Melodic Pacing  — `music-composition`, from Composition Training, concept `melodic-pacing`
* [ ] Learn Writing Singable Melodies  — `music-composition`, from Composition Training, concept `writing-singable-melodies`
* [ ] Learn Writing Instrumental Melodies  — `music-composition`, from Composition Training, concept `writing-instrumental-melodies`
* [ ] Learn Writing Memorable Hooks  — `music-composition`, from Composition Training, concept `writing-memorable-hooks`
* [ ] Learn Motif Development  — `music-composition`, from Composition Techniques, concept `motif-development`. Same concept; the other line of the pair is from Composition Training
* [ ] Learn Sequence  — `music-composition`, from Composition Techniques, concept `sequence`
* [ ] Learn Repetition  — `music-composition`, from Composition Techniques, concept `repetition`
* [ ] Learn Variation  — `music-composition`, from Composition Techniques, concept `variation`
* [ ] Learn Inversion  — `music-composition`, from Composition Techniques, concept `inversion`
* [ ] Learn Retrograde  — `music-composition`, from Composition Techniques, concept `retrograde`
* [ ] Learn Augmentation  — `music-composition`, from Composition Techniques, concept `augmentation`
* [ ] Learn Diminution  — `music-composition`, from Composition Techniques, concept `diminution`
* [ ] Learn Fragmentation  — `music-composition`, from Composition Techniques, concept `fragmentation`
* [ ] Learn Extension  — `music-composition`, from Composition Techniques, concept `extension`
* [ ] Learn Compression  — `music-composition`, from Composition Techniques, concept `compression`
* [ ] Learn Rhythmic Displacement  — `music-composition`, from Composition Techniques, concept `rhythmic-displacement`
* [ ] Learn Register Displacement  — `music-composition`, from Composition Techniques, concept `register-displacement`
* [ ] Learn Reharmonization  — `music-composition`, from Composition Techniques, concept `reharmonization`
* [ ] Learn Modulation  — `music-composition`, from Composition Techniques, concept `modulation`
* [ ] Learn Contrast  — `music-composition`, from Composition Techniques, concept `contrast`
* [ ] Learn Call and Response  — `music-composition`, from Composition Techniques, concept `call-and-response`
* [ ] Learn Ostinatos  — `music-composition`, from Composition Techniques, concept `ostinatos`
* [ ] Learn Pedal Tones  — `music-composition`, from Composition Techniques, concept `pedal-tones`
* [ ] Learn Suspensions  — `music-composition`, from Composition Techniques, concept `suspensions`. The chord is taught in `music-harmony`; this line is suspensions as a delaying technique
* [ ] Learn Anticipations  — `music-composition`, from Composition Techniques, concept `anticipations`
* [ ] Learn Delayed Resolution  — `music-composition`, from Composition Techniques, concept `delayed-resolution`
* [ ] Learn Tension Through Register  — `music-composition`, from Composition Techniques, concept `tension-through-register`
* [ ] Learn Tension Through Rhythm  — `music-composition`, from Composition Techniques, concept `tension-through-rhythm`
* [ ] Learn Tension Through Harmony  — `music-composition`, from Composition Techniques, concept `tension-through-harmony`
* [ ] Learn Tension Through Texture  — `music-composition`, from Composition Techniques, concept `tension-through-texture`
* [ ] Learn Tension Through Dynamics  — `music-composition`, from Composition Techniques, concept `tension-through-dynamics`
* [ ] Learn Tension Through Silence  — `music-composition`, from Composition Techniques, concept `tension-through-silence`

## Planned course 5 of 8 — Genre Composition

Slug `music-genres`. **43 items.**

Absorbs **Pop Composition** (25 items), **Classical Composition** (18 items).

* [ ] Learn Pop Melody Writing  — `music-genres`, from Pop Composition, concept `pop-melody-writing`
* [ ] Learn Pop Chord Progressions  — `music-genres`, from Pop Composition, concept `pop-chord-progressions`
* [ ] Learn Pop Bass Lines  — `music-genres`, from Pop Composition, concept `pop-bass-lines`
* [ ] Learn Pop Rhythmic Patterns  — `music-genres`, from Pop Composition, concept `pop-rhythmic-patterns`
* [ ] Learn Pop Song Structure  — `music-genres`, from Pop Composition, concept `pop-song-structure`
* [ ] Learn Writing Verses  — `music-genres`, from Pop Composition, concept `writing-verses`
* [ ] Learn Writing Choruses  — `music-genres`, from Pop Composition, concept `writing-choruses`
* [ ] Learn Writing Pre-Choruses  — `music-genres`, from Pop Composition, concept `writing-pre-choruses`
* [ ] Learn Writing Bridges  — `music-genres`, from Pop Composition, concept `writing-bridges`
* [ ] Learn Writing Hooks  — `music-genres`, from Pop Composition, concept `writing-hooks`
* [ ] Learn Writing Vocal Melodies  — `music-genres`, from Pop Composition, concept `writing-vocal-melodies`
* [ ] Learn Lyric-Melody Relationships  — `music-genres`, from Pop Composition, concept `lyric-melody-relationships`
* [ ] Learn Repetition in Pop Music  — `music-genres`, from Pop Composition, concept `repetition-in-pop-music`
* [ ] Learn Contrast in Pop Music  — `music-genres`, from Pop Composition, concept `contrast-in-pop-music`
* [ ] Learn Building a Chorus  — `music-genres`, from Pop Composition, concept `building-a-chorus`
* [ ] Learn Building a Drop  — `music-genres`, from Pop Composition, concept `building-a-drop`
* [ ] Learn Building a Breakdown  — `music-genres`, from Pop Composition, concept `building-a-breakdown`
* [ ] Learn Pop Arrangement  — `music-genres`, from Pop Composition, concept `pop-arrangement`
* [ ] Learn Pop Vocal Arrangement  — `music-genres`, from Pop Composition, concept `pop-vocal-arrangement`
* [ ] Learn Modern Pop Harmony  — `music-genres`, from Pop Composition, concept `modern-pop-harmony`
* [ ] Learn Writing Catchy Melodies  — `music-genres`, from Pop Composition, concept `writing-catchy-melodies`
* [ ] Learn Writing Emotional Pop  — `music-genres`, from Pop Composition, concept `writing-emotional-pop`
* [ ] Learn Writing Melancholic Pop  — `music-genres`, from Pop Composition, concept `writing-melancholic-pop`
* [ ] Learn Writing Dark Pop  — `music-genres`, from Pop Composition, concept `writing-dark-pop`
* [ ] Learn Writing Upbeat Pop  — `music-genres`, from Pop Composition, concept `writing-upbeat-pop`
* [ ] Learn Classical Melody Writing  — `music-genres`, from Classical Composition, concept `classical-melody-writing`
* [ ] Learn Classical Phrase Construction  — `music-genres`, from Classical Composition, concept `classical-phrase-construction`
* [ ] Learn Classical Harmony  — `music-genres`, from Classical Composition, concept `classical-harmony`
* [ ] Learn Classical Voice Leading  — `music-genres`, from Classical Composition, concept `classical-voice-leading`
* [ ] Learn Classical Counterpoint  — `music-genres`, from Classical Composition, concept `classical-counterpoint`
* [ ] Learn Classical Periods  — `music-genres`, from Classical Composition, concept `classical-periods`
* [ ] Learn Classical Forms  — `music-genres`, from Classical Composition, concept `classical-forms`
* [ ] Learn Theme and Variations  — `music-genres`, from Classical Composition, concept `theme-and-variations`. The form itself is taught in `music-form`; this line is the classical repertoire's use of it
* [ ] Learn Minuet and Trio  — `music-genres`, from Classical Composition, concept `minuet-and-trio`
* [ ] Learn Scherzo Form  — `music-genres`, from Classical Composition, concept `scherzo-form`
* [ ] Learn Sonata Form  — `music-genres`, from Classical Composition, concept `sonata-form`. The form itself is taught in `music-form`; this line is writing a classical piece in it
* [ ] Learn Classical Development Sections  — `music-genres`, from Classical Composition, concept `classical-development-sections`
* [ ] Learn Classical Transitions  — `music-genres`, from Classical Composition, concept `classical-transitions`
* [ ] Learn Classical Cadences  — `music-genres`, from Classical Composition, concept `classical-cadences`
* [ ] Learn Classical Modulation  — `music-genres`, from Classical Composition, concept `classical-modulation`
* [ ] Learn Writing for String Quartet  — `music-genres`, from Classical Composition, concept `writing-for-string-quartet`. The ensemble writing is taught in `music-orchestration`; this line is the classical genre's use of it
* [ ] Learn Writing for Piano  — `music-genres`, from Classical Composition, concept `writing-for-piano`. The arrangement for it is taught in `music-orchestration`; this line is writing a classical piece for it
* [ ] Learn Writing for Orchestra  — `music-genres`, from Classical Composition, concept `writing-for-orchestra`. The orchestration is taught in `music-orchestration`; this line is writing a classical piece for it

## Planned course 6 of 8 — Orchestration and Arrangement

Slug `music-orchestration`. **22 items.**

Absorbs **Orchestration & Arrangement** (22 items).

* [ ] Learn Instrument Ranges  — `music-orchestration`, from Orchestration & Arrangement, concept `instrument-ranges`
* [ ] Learn Instrument Timbres  — `music-orchestration`, from Orchestration & Arrangement, concept `instrument-timbres`
* [ ] Learn Instrument Registers  — `music-orchestration`, from Orchestration & Arrangement, concept `instrument-registers`
* [ ] Learn Instrument Doubling  — `music-orchestration`, from Orchestration & Arrangement, concept `instrument-doubling`
* [ ] Learn Writing for Strings  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-strings`
* [ ] Learn Writing for Woodwinds  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-woodwinds`
* [ ] Learn Writing for Brass  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-brass`
* [ ] Learn Writing for Percussion  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-percussion`
* [ ] Learn Writing for Piano  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-piano`. The classical piece that uses it is listed in `music-genres`; this line is the orchestration
* [ ] Learn Writing for Guitar  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-guitar`
* [ ] Learn Writing for Small Ensembles  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-small-ensembles`
* [ ] Learn Writing for String Quartet  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-string-quartet`. The classical piece that uses it is listed in `music-genres`; this line is the ensemble writing
* [ ] Learn Writing for Chamber Ensembles  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-chamber-ensembles`
* [ ] Learn Writing for Orchestra  — `music-orchestration`, from Orchestration & Arrangement, concept `writing-for-orchestra`. The classical piece that uses it is listed in `music-genres`; this line is the orchestration
* [ ] Learn Orchestral Texture  — `music-orchestration`, from Orchestration & Arrangement, concept `orchestral-texture`
* [ ] Learn Orchestral Balance  — `music-orchestration`, from Orchestration & Arrangement, concept `orchestral-balance`
* [ ] Learn Orchestral Voicing  — `music-orchestration`, from Orchestration & Arrangement, concept `orchestral-voicing`
* [ ] Learn Musical Density  — `music-orchestration`, from Orchestration & Arrangement, concept `musical-density`
* [ ] Learn Register Distribution  — `music-orchestration`, from Orchestration & Arrangement, concept `register-distribution`
* [ ] Learn Doubling and Reinforcement  — `music-orchestration`, from Orchestration & Arrangement, concept `doubling-and-reinforcement`
* [ ] Learn Arrangement From Piano to Orchestra  — `music-orchestration`, from Orchestration & Arrangement, concept `arrangement-from-piano-to-orchestra`
* [ ] Learn Arrangement From Orchestra to Piano  — `music-orchestration`, from Orchestration & Arrangement, concept `arrangement-from-orchestra-to-piano`

## Planned course 7 of 8 — Composition Drills and Style

Slug `music-drills`. **46 items.**

Absorbs **Composition Drills** (25 items), **Style Analysis** (21 items).


**The 5-minute challenges.** The 20 items the original section lists after *"For example:"*.

* [ ] Write 10 Two-Bar Motifs  — `music-drills`, from Composition Drills, concept `write-10-two-bar-motifs`
* [ ] Write 10 Melodies Using Only Five Notes  — `music-drills`, from Composition Drills, concept `write-10-melodies-using-only-five-notes`
* [ ] Write 10 Melodies With One Rhythmic Motif  — `music-drills`, from Composition Drills, concept `write-10-melodies-with-one-rhythmic-motif`
* [ ] Write 10 Melodies Using Sequence  — `music-drills`, from Composition Drills, concept `write-10-melodies-using-sequence`
* [ ] Write 10 Melodies With Contrasting Phrases  — `music-drills`, from Composition Drills, concept `write-10-melodies-with-contrasting-phrases`
* [ ] Write 10 Four-Bar Phrases  — `music-drills`, from Composition Drills, concept `write-10-four-bar-phrases`
* [ ] Write 10 Eight-Bar Periods  — `music-drills`, from Composition Drills, concept `write-10-eight-bar-periods`
* [ ] Write 10 Bass Lines  — `music-drills`, from Composition Drills, concept `write-10-bass-lines`
* [ ] Write 10 Chord Progressions  — `music-drills`, from Composition Drills, concept `write-10-chord-progressions`
* [ ] Write 10 Melodies Over Existing Chords  — `music-drills`, from Composition Drills, concept `write-10-melodies-over-existing-chords`
* [ ] Write 10 Chord Progressions Under Existing Melodies  — `music-drills`, from Composition Drills, concept `write-10-chord-progressions-under-existing-melodies`
* [ ] Develop One Motif 10 Different Ways  — `music-drills`, from Composition Drills, concept `develop-one-motif-10-different-ways`
* [ ] Write 10 Modulations  — `music-drills`, from Composition Drills, concept `write-10-modulations`
* [ ] Write 10 Transitions  — `music-drills`, from Composition Drills, concept `write-10-transitions`
* [ ] Write 10 Introductions  — `music-drills`, from Composition Drills, concept `write-10-introductions`
* [ ] Write 10 Endings  — `music-drills`, from Composition Drills, concept `write-10-endings`
* [ ] Write 10 Choruses  — `music-drills`, from Composition Drills, concept `write-10-choruses`
* [ ] Write 10 Bridges  — `music-drills`, from Composition Drills, concept `write-10-bridges`
* [ ] Write 10 Instrumental Themes  — `music-drills`, from Composition Drills, concept `write-10-instrumental-themes`
* [ ] Write 10 Countermelodies  — `music-drills`, from Composition Drills, concept `write-10-countermelodies`

**Eventually.** The 5 items the original section lists after *"Eventually:"* — the point of the 20 above.

* [ ] Compose 10 Complete Short Pieces  — `music-drills`, from Composition Drills, concept `compose-10-complete-short-pieces`
* [ ] Compose 10 Complete Pop Songs  — `music-drills`, from Composition Drills, concept `compose-10-complete-pop-songs`
* [ ] Compose 10 Piano Pieces  — `music-drills`, from Composition Drills, concept `compose-10-piano-pieces`
* [ ] Compose 10 Chamber Pieces  — `music-drills`, from Composition Drills, concept `compose-10-chamber-pieces`
* [ ] Compose 10 Orchestral Pieces  — `music-drills`, from Composition Drills, concept `compose-10-orchestral-pieces`

**Reverse-engineer the style.** The 15 items the original section lists first.

* [ ] Analyze Baroque Music  — `music-drills`, from Style Analysis, concept `analyze-baroque-music`
* [ ] Analyze Classical Music  — `music-drills`, from Style Analysis, concept `analyze-classical-music`
* [ ] Analyze Romantic Music  — `music-drills`, from Style Analysis, concept `analyze-romantic-music`
* [ ] Analyze Impressionist Music  — `music-drills`, from Style Analysis, concept `analyze-impressionist-music`
* [ ] Analyze Modern Classical Music  — `music-drills`, from Style Analysis, concept `analyze-modern-classical-music`
* [ ] Analyze Film Music  — `music-drills`, from Style Analysis, concept `analyze-film-music`
* [ ] Analyze Jazz  — `music-drills`, from Style Analysis, concept `analyze-jazz`
* [ ] Analyze Blues  — `music-drills`, from Style Analysis, concept `analyze-blues`
* [ ] Analyze Rock  — `music-drills`, from Style Analysis, concept `analyze-rock`
* [ ] Analyze Pop  — `music-drills`, from Style Analysis, concept `analyze-pop`
* [ ] Analyze R&B  — `music-drills`, from Style Analysis, concept `analyze-r-and-b`
* [ ] Analyze Electronic Music  — `music-drills`, from Style Analysis, concept `analyze-electronic-music`
* [ ] Analyze Hip-Hop  — `music-drills`, from Style Analysis, concept `analyze-hip-hop`
* [ ] Analyze Folk Music  — `music-drills`, from Style Analysis, concept `analyze-folk-music`
* [ ] Analyze Game Music  — `music-drills`, from Style Analysis, concept `analyze-game-music`

**Then.** The 6 items the original section lists after *"Then:"* — having taken a style apart, put one of its techniques back.

* [ ] Recreate a Baroque Composition Technique  — `music-drills`, from Style Analysis, concept `recreate-a-baroque-composition-technique`
* [ ] Recreate a Classical Composition Technique  — `music-drills`, from Style Analysis, concept `recreate-a-classical-composition-technique`
* [ ] Recreate a Romantic Composition Technique  — `music-drills`, from Style Analysis, concept `recreate-a-romantic-composition-technique`
* [ ] Recreate an Impressionist Composition Technique  — `music-drills`, from Style Analysis, concept `recreate-an-impressionist-composition-technique`
* [ ] Recreate a Film-Scoring Technique  — `music-drills`, from Style Analysis, concept `recreate-a-film-scoring-technique`
* [ ] Recreate a Pop Composition Technique  — `music-drills`, from Style Analysis, concept `recreate-a-pop-composition-technique`

## Planned course 8 of 8 — Integrated and Advanced Composition

Slug `music-integrated`. **42 items.**

Absorbs **Integrated Composition Courses** (14 items), **Advanced "Composition Athlete" Training** (28 items).

* [ ] Compose a Melody From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-melody-from-scratch`
* [ ] Compose a Piano Piece From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-piano-piece-from-scratch`
* [ ] Compose a Pop Song From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-pop-song-from-scratch`
* [ ] Compose a Classical Piece From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-classical-piece-from-scratch`
* [ ] Compose a String Quartet From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-string-quartet-from-scratch`
* [ ] Compose a Film Cue From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-film-cue-from-scratch`
* [ ] Compose an Orchestral Piece From Scratch  — `music-integrated`, from Integrated Composition Courses, concept `compose-an-orchestral-piece-from-scratch`
* [ ] Compose a Theme and Variations  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-theme-and-variations`
* [ ] Compose a Fugue  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-fugue`
* [ ] Compose a Sonata Movement  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-sonata-movement`
* [ ] Compose a Complete Pop Song  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-complete-pop-song`
* [ ] Compose a Complete Instrumental Song  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-complete-instrumental-song`
* [ ] Compose a Complete Short Film Score  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-complete-short-film-score`
* [ ] Compose a Complete Piano Album Track  — `music-integrated`, from Integrated Composition Courses, concept `compose-a-complete-piano-album-track`
* [ ] Daily Melody Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-melody-training`
* [ ] Daily Rhythm Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-rhythm-training`
* [ ] Daily Harmony Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-harmony-training`
* [ ] Daily Counterpoint Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-counterpoint-training`
* [ ] Daily Motif Development Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-motif-development-training`
* [ ] Daily Musical Analysis Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-musical-analysis-training`
* [ ] Daily Composition Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `daily-composition-training`
* [ ] Rapid Melody Composition  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `rapid-melody-composition`
* [ ] Rapid Chord Progression Composition  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `rapid-chord-progression-composition`
* [ ] Rapid Harmonic Reharmonization  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `rapid-harmonic-reharmonization`
* [ ] Rapid Motif Development  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `rapid-motif-development`
* [ ] Composition Under Constraints  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-under-constraints`
* [ ] Composition From a Single Motif  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-from-a-single-motif`
* [ ] Composition From a Single Chord  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-from-a-single-chord`
* [ ] Composition Without Repetition  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-without-repetition`
* [ ] Composition Using Extreme Repetition  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-using-extreme-repetition`
* [ ] Composition With Restricted Harmony  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-with-restricted-harmony`
* [ ] Composition With Restricted Rhythm  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-with-restricted-rhythm`
* [ ] Composition From an Existing Melody  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-from-an-existing-melody`
* [ ] Composition From an Existing Chord Progression  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-from-an-existing-chord-progression`
* [ ] Composition From an Existing Rhythm  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-from-an-existing-rhythm`
* [ ] Composition Through Imitation  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-through-imitation`
* [ ] Composition Through Transformation  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-through-transformation`
* [ ] Composition Through Analysis  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-through-analysis`
* [ ] Composition Speed Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-speed-training`
* [ ] Composition Revision Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-revision-training`
* [ ] Composition Problem-Solving Training  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `composition-problem-solving-training`
* [ ] Complete Composition Mastery  — `music-integrated`, from Advanced "Composition Athlete" Training, concept `complete-composition-mastery`

````

## But I would add one fundamental rule to the Underlayer music specification

**Never let a music lesson remain purely verbal when the idea can be demonstrated musically.**

For a normal technical course, an AI might get away with:

> "Here is an explanation."

For music:

> **Explanation + notation + playback + interaction + learner creation**

should be the default.

So a lesson on **sequence**, for example, should ideally contain:

```text
CONCEPT
   ↓
notation
   ↓
hear it
   ↓
identify it
   ↓
analyze it
   ↓
modify it
   ↓
write one
   ↓
hear your version
   ↓
receive feedback
   ↓
encounter sequence again later
````

And a lesson on **sonata form** shouldn't just show a diagram. It should give the learner an actual score and progressively ask them to **mark the exposition, themes, transition, development, recapitulation, etc.**

That is where Underlayer could become genuinely unusual.

### The end-state I'd put into the AI's music brief

> **Underlayer's music curriculum should produce musicians who can hear music, see music, analyze music, explain why music works, reconstruct compositional decisions from a score, and deliberately create music using the same underlying techniques.**
>
> **The learner should not merely know music theory. They should have practiced composition so extensively that compositional techniques become usable skills.**
>
> **Whenever a musical concept can be represented with notation, notation should be provided. Whenever it can be heard, it should be playable. Whenever it can be practiced, the learner should practice it. Whenever it can be analyzed, the learner should analyze an actual piece of music.**

That last distinction—**knowledge → analysis → imitation → transformation → original composition**—is probably the most important thing to bake into the music branch.
