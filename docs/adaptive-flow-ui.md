# Adaptive Flow and UI Design

This document defines how Underlayer's UI adapts to each learner's needs, knowledge state, and emotional condition.

---

## Core Principle

**The UI should feel like a patient tutor, not a relentless test.**

For learners with anxiety, depression, and overthinking:
- Show ONE thing at a time
- Never overwhelm with choices
- Always show a clear next step
- Make progress visible but not gamified
- Allow pausing anywhere
- Never punish returning after absence

---

## Flow Architecture

```
First Launch
  ↓
Onboarding (5 questions)
  ↓
IRT Diagnostic (5-8 questions)
  ↓
Course Home
  ↓
┌─────────────────────────────────────┐
│  Daily Flow                         │
│                                     │
│  1. Energy Check-in                 │
│  2. Review Due Items (if any)       │
│  3. Learn New Concept (if energy ok)│
│  4. Session Summary                 │
│  5. Preview Next Session            │
└─────────────────────────────────────┘
```

---

## Screen-by-Screen Flow

### Screen 1: Welcome Back

```
┌─────────────────────────────────────────────┐
│                                             │
│            Welcome back.                    │
│                                             │
│     You have 3 reviews due today.           │
│     Should take about 5 minutes.            │
│                                             │
│     ┌─────────────┐  ┌─────────────┐        │
│     │  Start      │  │  Learn      │        │
│     │  Review     │  │  Something  │        │
│     │             │  │  New        │        │
│     └─────────────┘  └─────────────┘        │
│                                             │
│     Last session: Yesterday                 │
│     Concepts learned: 8 of 20               │
│                                             │
└─────────────────────────────────────────────┘
```

**Rules:**
- Never show "You've been away 3 days" (causes guilt)
- Always show estimated time for reviews
- Always show progress (concepts learned, not percentage)
- Two clear options, no more

### Screen 2: Energy Check-in

```
┌─────────────────────────────────────────────┐
│                                             │
│         Before you start,                   │
│         how are you feeling?                │
│                                             │
│    ┌─────────┐ ┌─────────┐ ┌─────────┐     │
│    │  😊     │ │  😐     │ │  😔     │     │
│    │  Good   │ │  Okay   │ │  Low    │     │
│    │         │ │         │ │         │     │
│    └─────────┘ └─────────┘ └─────────┘     │
│                                             │
└─────────────────────────────────────────────┘
```

**Behavior based on selection:**

| Feeling | Session Type | Content | Pacing |
|---|---|---|---|
| Good | Full | New concepts + review | Standard |
| Okay | Balanced | Light review + easy new concept | Slightly slower |
| Low | Gentle | Easy reviews only, no new concepts | Slow, 10 min max |

### Screen 3: Review Session

```
┌─────────────────────────────────────────────┐
│  Review 1 of 3                              │
│  ─────────────────────                      │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                             │
│  What field in the ELF header               │
│  specifies the virtual address              │
│  where execution begins?                    │
│                                             │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │          Show Answer                │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  No time pressure. Take your time.          │
│                                             │
└─────────────────────────────────────────────┘
```

**After clicking "Show Answer":**

```
┌─────────────────────────────────────────────┐
│  Review 1 of 3                              │
│  ─────────────────────                      │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                             │
│  The answer is: e_entry                     │
│                                             │
│  e_entry contains the virtual address       │
│  of the program's entry point. This is      │
│  where the loader transfers control to      │
│  start execution.                           │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│  How well did you remember?                 │
│                                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│  │ Again   │ │ Hard    │ │ Good    │ │ Easy    │
│  │         │ │         │ │         │ │         │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘
│                                             │
└─────────────────────────────────────────────┘
```

**Rules:**
- No time pressure (ever, unless user opts in)
- "Show Answer" button is large and clear
- Rating buttons are equally sized (no "wrong" button is smaller)
- Show explanation regardless of rating
- Progress bar advances even on "Again"

### Screen 4: New Concept Introduction

```
┌─────────────────────────────────────────────┐
│  Module 2: ELF Header                       │
│  ─────────────────────                      │
│  Concept 2 of 3: Header Fields              │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                             │
│  ┌─ WHY ─────────────────────────────────┐  │
│  │                                       │  │
│  │  The ELF header is the first thing    │  │
│  │  the system reads. Without it, the    │  │
│  │  file cannot be processed at all.     │  │
│  │                                       │  │
│  │  Think about what happens when you    │  │
│  │  try to open a file: the system needs │  │
│  │  to know what kind of file it is,     │  │
│  │  how to read it, and where to start.  │  │
│  │  The ELF header provides all of this. │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │           Continue →                │    │
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

**Rules:**
- Show ONE learning unit at a time (WHY, then MODEL, then REALITY, etc.)
- "Continue" button is the only action
- No back button needed (can scroll up if needed)
- Each unit is 1-3 paragraphs maximum

### Screen 5: Interactive Exercise (Embedded in Lesson)

```
┌─────────────────────────────────────────────┐
│  Let's check your understanding.            │
│  ─────────────────────                      │
│                                             │
│  In this hex dump, find the e_entry field:  │
│                                             │
│  00000000  7f 45 4c 46 02 01 01 00         │
│  00000008  00 00 00 00 00 00 00 00         │
│  00000010  03 00 3e 00 01 00 00 00         │
│  00000018  40 10 40 00 00 00 00 00         │
│                                             │
│  Click on the bytes that represent e_entry: │
│                                             │
│  ┌─────┐┌─────┐┌─────┐┌─────┐              │
│  │00-07││08-0F││10-17││18-1F│              │
│  └─────┘└─────┘└─────┘└─────┘              │
│                                             │
│  Hint available: [Show a hint]              │
│                                             │
└─────────────────────────────────────────────┘
```

**Rules:**
- Interactive exercises are embedded in lessons (not separated)
- Hint is available but not forced
- No wrong-answer惩罚 — wrong clicks just try again
- Visual feedback on correct selection

### Screen 6: Session Complete

```
┌─────────────────────────────────────────────┐
│                                             │
│              Nice work.                     │
│                                             │
│     You reviewed 3 concepts and             │
│     learned 1 new concept.                  │
│                                             │
│     ┌───────────────────────────────┐       │
│     │  Concepts learned: 9 of 20    │       │
│     │  ████████░░░░░░░░░░░░          │       │
│     └───────────────────────────────┘       │
│                                             │
│     Next session: Tomorrow                  │
│     2 reviews due. ~5 minutes.              │
│                                             │
│     ┌─────────────────────────────────────┐  │
│     │         Done for Today              │  │
│     └─────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

**Rules:**
- Never show percentages (shows "9 of 20 concepts")
- Never show "You're 45% done!" (causes anxiety about being "almost done")
- Always preview next session
- "Done for Today" is the primary action
- No confetti, no celebrations (except rare milestones)

---

## Knowledge Display Patterns

### The "i" Button

Every factual claim can have an info button (ⓘ) that shows on hover:

```
The ELF header starts with bytes 0x7f 0x45 0x4c 0x46 ⓘ
```

**On hover/click:**

```
┌─────────────────────────────────────────┐
│  Source                                  │
│  gABI specification, ELF Identification  │
│  section, p. 4-5                        │
│                                         │
│  Verified                               │
│  ✓ Checked with readelf on Linux 6.1    │
│  ✓ Correct per ELF64 and ELF32          │
│                                         │
│  Scope                                   │
│  Portable — applies to all ELF systems  │
│                                         │
│  [Open specification section]            │
└─────────────────────────────────────────┘
```

### Simplification Markers

When a simplified model is presented:

```
┌─ Simplified Model ─────────────────────┐
│                                       │
│  Think of a segment as a memory       │
│  region that the loader maps into     │
│  process memory.                      │
│                                       │
│  ⚠️ This is simplified. The actual    │
│  behavior involves additional flags   │
│  and edge cases.                      │
│                                       │
│  [Show full details]                  │
│                                       │
└───────────────────────────────────────┘
```

### Scope Badges

When content is implementation-specific:

```
This behavior is [Linux-specific] ⓘ
This is [implementation-specific] per the C standard ⓘ
This changed in [ELF gABI 1.1] ⓘ
```

### Verification Badges

On code examples:

```
┌─ Code Example ────────────────────────┐
│  #include <elf.h>                     │
│  // ... code here                    │
└──────────────────────────────────────┘
  ✓ Verified with GCC 13.2 on 2024-01-15
  ✓ Correct per gABI specification
```

---

## Progressive Disclosure

### Three Layers

```
Layer 1: Essential (always visible)
  Core concept explanation
  One example
  One exercise

Layer 2: Detailed (click "Show more")
  Additional examples
  Edge cases
  Multiple exercises

Layer 3: Full Reference (click "Show specification")
  Specification quotes
  Version differences
  Implementation comparisons
```

### Implementation

```
┌─────────────────────────────────────────┐
│  The ELF header is 52 bytes in ELF32   │
│  and 64 bytes in ELF64.                │
│                                         │
│  ┌─ Show more ─────────────────────┐   │
│  │                                 │   │
│  │  The header size is determined   │   │
│  │  by the e_ehsize field. In      │   │
│  │  ELF32, this is 52 (0x34). In   │   │
│  │  ELF64, this is 64 (0x40).      │   │
│  │                                 │   │
│  │  ┌─ Show specification ─────┐   │   │
│  │  │                          │   │   │
│  │  │  "e_ehsize: This member   │   │   │
│  │  │  holds the length, in     │   │   │
│  │  │  bytes, of this header."  │   │   │
│  │  │                          │   │   │
│  │  │  — gABI § ELF Header     │   │   │
│  │  └──────────────────────────┘   │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

**Rules:**
- Layer 1 is always visible (no click needed)
- Layer 2 is one click away
- Layer 3 is two clicks away
- Never hide essential information behind disclosure
- Persist disclosure state per user

---

## Adaptive Density

### Mode Toggle

```
[Overview] [Complete] [Full Reference]
```

**Persisted per user.** Default based on onboarding experience level.

| Mode | What's Shown | What's Hidden |
|---|---|---|
| **Overview** | Core concepts, one example, essential exercises | Edge cases, multiple exercises, spec quotes |
| **Complete** | Full explanations, examples, all exercises, edge cases | Spec quotes, version diffs |
| **Full Reference** | Everything including spec quotes, version diffs, implementation comparisons | Nothing hidden |

### Rules

- Never label as "Beginner/Expert" (hierarchy)
- Use neutral labels
- Allow per-concept override
- Default to "Complete" for most learners

---

## Navigation Patterns

### Breadcrumb

```
Courses > ELF > Module 2 > Header Fields
```

### Progress Sidebar (Desktop)

```
Module 1: Fundamentals ✓
  Bytes and Binary ✓
  Binary Representation ✓
  File Layout ✓

Module 2: ELF Header ◐
  ELF Identification ✓
  Header Fields ← (current)
  Entry Point ○

Module 3: Program Headers ○
  ...
```

### Mobile Navigation

Bottom bar with three buttons:
- [← Previous] (if applicable)
- [Menu] (course outline)
- [Next →] (primary action)

---

## Error and Empty States

### Wrong Answer

```
┌─────────────────────────────────────────┐
│  Not quite.                             │
│                                         │
│  You selected "e_phoff" but the         │
│  question asks about the entry point.   │
│  The entry point is e_entry — it's a    │
│  virtual address, not a file offset.    │
│                                         │
│  e_phoff is the offset to the program   │
│  header table, which is a different     │
│  field entirely.                        │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │        Try Next Exercise        │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

**Rules:**
- Never just "X Wrong"
- Explain WHY the wrong answer is wrong
- Explain WHY the correct answer is correct
- "Try Next Exercise" not "Try Again" (reduces anxiety)

### No Reviews Due

```
┌─────────────────────────────────────────┐
│                                         │
│           All caught up.                │
│                                         │
│     No reviews due today.               │
│     Next review: Tomorrow               │
│                                         │
│     ┌─────────────────────────────┐     │
│     │    Learn Something New      │     │
│     └─────────────────────────────┘     │
│                                         │
└─────────────────────────────────────────┘
```

### Returning After Long Absence

```
┌─────────────────────────────────────────┐
│                                         │
│           Welcome back.                 │
│                                         │
│     Let's start with some easy reviews  │
│     to refresh your memory.             │
│                                         │
│     ┌─────────────────────────────┐     │
│     │    Start Reviewing          │     │
│     └─────────────────────────────┘     │
│                                         │
└─────────────────────────────────────────┘
```

**Rules:**
- Never show how long they've been away
- Never show "You missed X reviews"
- Always start with easy reviews
- "Let's refresh" not "You forgot"

---

## Animation Rules

### Allowed

| Animation | Duration | Purpose |
|---|---|---|
| Card reveal | 200ms | New content appearing |
| Progress bar fill | 400ms | Show progress advance |
| Fade in | 200ms | Feedback appearing |
| Focus ring | 150ms | Keyboard navigation |

### Forbidden

- Bouncing, jumping, or pulsing elements
- Flashing or strobing
- Confetti (except rare course completion)
- Auto-playing animations
- Looping animations
- Any animation that draws attention away from content

### Reduced Motion

Always respect `prefers-reduced-motion`. All animations become instant.

---

## Anxiety-Specific Design

### Time Pressure

- **Never** show countdown timers (unless user opts in)
- **Never** auto-advance after timeout
- **Always** show "No time pressure. Take your time."
- **Allow** pausing anywhere

### Choice Overload

- **Maximum 3 choices** on any screen
- **One clear next step** always visible
- **No decision fatigue** — system recommends, user confirms

### Failure Framing

- Never "Wrong" — use "Not quite"
- Never "Failed" — use "Needs review"
- Never "X incorrect" — use "X needed a second attempt"
- Always explain WHY, not just WHAT

### Progress Anxiety

- Never "You're 45% done" — use "9 of 20 concepts"
- Never "3 questions left" — use "3 more to go"
- Always show "Done for Today" as an option
- Never force completion

### Social Pressure

- No leaderboards
- No comparison to other learners
- No public scores
- No social features (initially)

---

## Depression-Specific Design

### Low Energy Days

- Energy check-in at session start
- If "Low" → gentle review only, no new concepts
- If session is short → celebrate the time spent
- If no session → "Welcome back" not "You missed 3 days"

### Motivation

- Visible progress bar (concepts learned)
- Small wins: "You reviewed 3 concepts today"
- Preview next session: "Tomorrow, 2 reviews due. ~5 minutes."
- Never guilt-trip about missed sessions

### Cognitive Fatigue

- Shorter default sessions (10 minutes when energy is low)
- More worked examples, fewer independent exercises
- Visual content over text when possible
- One concept at a time

---

## Overthinking-Specific Design

### Analysis Paralysis

- One concept at a time (never show the full tree)
- Concrete tasks: "Find e_entry in this hex dump"
- Time-boxing: "This concept takes 15 minutes"
- Clear completion criteria

### Perfectionism

- "Show Answer" button (no penalty for looking)
- "Skip this for now" always available
- Wrong answers are learning: "The act of trying strengthens your memory"
- No quality scores (no "95% mastery")

### Detail Spiral

- Essential layer visible by default
- "Show more" for additional detail
- "Show specification" for full reference
- Never hide essential info behind disclosure

---

## Implementation Priority

### Phase 1 (MVP)
- Energy check-in
- Review session with FSRS
- Lesson viewer with 8-unit structure
- Session summary
- Basic progress tracking

### Phase 2
- "i" button system
- Three-layer progressive disclosure
- Scope badges and verification badges
- Adaptive density modes

### Phase 3
- Full adaptive flow
- Emotional state inference
- Advanced anxiety/depression support
- Cross-session persistence
