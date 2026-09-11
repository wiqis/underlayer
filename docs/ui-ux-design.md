# UI/UX Design System

This document defines the visual design, interaction patterns, and user experience for Underlayer.

---

## Design Philosophy

Underlayer's UI should feel like:
> "I am sitting down and understanding something difficult."

NOT:
> "I am playing a mobile game about completing lessons."

### Core Principles

1. **Calm and focused** — no flashing animations, no excessive notifications
2. **Readable above all** — typography and spacing optimized for learning
3. **Progress is visible but not gamified** — show mastery, not streaks
4. **Errors are learning opportunities** — wrong answers get explanations, not X marks
5. **Accessible** — works for different learning needs, screen readers, keyboard navigation

---

## Color System

### Light Mode (Primary)

```
Background:        #ffffff  (pure white)
Surface:           #f8f9fa  (very light gray — cards, panels)
Surface Hover:     #f0f1f3  (slightly darker on hover)
Border:            #e5e7eb  (subtle borders)
Border Focus:      #3b82f6  (blue focus ring)

Text Primary:      #111827  (near-black — headings, body)
Text Secondary:    #6b7280  (gray — descriptions, metadata)
Text Tertiary:     #9ca3af  (light gray — placeholders, hints)

Primary:           #2563eb  (blue — CTAs, links, progress)
Primary Hover:     #1d4ed8  (darker blue on hover)
Primary Light:     #eff6ff  (very light blue — selection backgrounds)

Success:           #059669  (green — correct answers, completion)
Success Light:     #ecfdf5  (very light green — success backgrounds)

Warning:           #d97706  (amber — caution, review needed)
Warning Light:     #fffbeb  (very light amber — warning backgrounds)

Error:             #dc2626  (red — errors, but used gently)
Error Light:       #fef2f2  (very light red — error backgrounds)

Info:              #2563eb  (blue — informational messages)
Info Light:        #eff6ff  (very light blue — info backgrounds)
```

### Dark Mode

```
Background:        #0f172a  (dark navy — not pure black)
Surface:           #1e293b  (dark slate — cards, panels)
Surface Hover:     #334155  (lighter on hover)
Border:            #334155  (subtle borders)

Text Primary:      #f1f5f9  (near-white)
Text Secondary:    #94a3b8  (gray)
Text Tertiary:     #64748b  (lighter gray)

Primary:           #3b82f6  (brighter blue for dark bg)
Primary Hover:     #60a5fa  (lighter on hover)

Success:           #10b981  (brighter green)
Warning:           #f59e0b  (brighter amber)
Error:             #ef4444  (brighter red)
```

### Color Usage Rules

| Element | Color | Never |
|---|---|---|
| Correct answer | Success green | Never red |
| Wrong answer | Error red background + explanation | Never just "X Wrong" |
| Progress | Primary blue | Never as percentage (show concepts learned) |
| Focus ring | Primary blue | Never remove focus indicators |
| Links | Primary blue | Never underlined in body text |
| Headings | Text primary | Never colored |
| Metadata | Text secondary | Never primary color |

---

## Typography

### Font Stack

```css
--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
--font-mono: 'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace;
```

**Why Inter:** Excellent readability at small sizes, large x-height, open counters, wide language support. Used by Vercel, Linear, and many developer tools.

**Why JetBrains Mono:** Designed for code. Ligatures, clear character distinction, large x-height.

### Type Scale

```
Display:    36px / 40px line-height / 700 weight   (page titles)
H1:         30px / 36px / 700                       (section headings)
H2:         24px / 30px / 600                       (subsection headings)
H3:         20px / 28px / 600                       (concept titles)
H4:         16px / 24px / 600                       (sub-subsection)
Body:       16px / 24px / 400                       (main text)
Body Small: 14px / 20px / 400                       (metadata, hints)
Caption:    12px / 16px / 500                       (labels, timestamps)
Code:       14px / 20px / 400                       (inline code, code blocks)
```

### Typography Rules

1. **Maximum line width: 68 characters** (optimal reading speed)
2. **Body text: 16px minimum** (accessibility)
3. **Line height: 1.5 for body, 1.2 for headings**
4. **Paragraph spacing: 1em between paragraphs**
5. **No justified text** — always left-aligned
6. **No ALL CAPS except labels** — use font-weight: 600 for emphasis

---

## Spacing System

Base unit: 4px

```
--space-1:  4px     (tight spacing)
--space-2:  8px     (default spacing)
--space-3:  12px    (card padding)
--space-4:  16px    (section padding)
--space-5:  20px    (between elements)
--space-6:  24px    (between sections)
--space-8:  32px    (large gaps)
--space-10: 40px    (page margins)
--space-12: 48px    (between major sections)
--space-16: 64px    (page-level spacing)
```

### Spacing Rules

1. **Consistent padding** — all cards use `--space-4` (16px) padding
2. **Section spacing** — `--space-12` (48px) between major sections
3. **Element spacing** — `--space-4` (16px) between related elements
4. **Tight spacing** — `--space-2` (8px) between tightly related items (exercise options)
5. **Page margins** — `--space-10` (40px) on desktop, `--space-4` (16px) on mobile

---

## Layout

### Page Structure

```
┌─────────────────────────────────────────────┐
│  Header (logo, nav, progress)               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  Content Area (max-width: 720px)    │    │
│  │                                     │    │
│  │  Lesson content                     │    │
│  │  Exercises                          │    │
│  │  Visualizations                     │    │
│  │                                     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  Sidebar (240px) — optional         │    │
│  │  Concept list, progress             │    │
│  └─────────────────────────────────────┘    │
│                                             │
├─────────────────────────────────────────────┤
│  Footer (minimal)                           │
└─────────────────────────────────────────────┘
```

### Content Width

- **Lesson content:** max-width 720px (optimal reading)
- **Exercise area:** max-width 720px
- **Visualization:** max-width 960px (wider for diagrams)
- **Full-width elements:** progress bars, navigation

### Responsive Breakpoints

```
Mobile:   < 640px    (single column, stacked layout)
Tablet:   640-1024px (sidebar collapses, content adjusts)
Desktop:  > 1024px   (sidebar visible, full layout)
```

---

## Components

### 1. Concept Card

A card displaying a single concept in the course outline.

```
┌─────────────────────────────────────┐
│  Module 2: ELF Header               │
│                                     │
│  ○ ELF Identification               │
│    ✓ ELF Header Fields              │
│    ○ Entry Point                    │
│                                     │
│  Progress: 1/3 concepts             │
│  ████████░░░░░░░░ 33%              │
└─────────────────────────────────────┘
```

**States:**
- ○ Not started (gray)
- ◐ In progress (blue)
- ✓ Completed (green)

### 2. Lesson View

The main learning interface.

```
┌─────────────────────────────────────┐
│  ← Back to Module                   │
│                                     │
│  ELF Header Fields                  │
│  ─────────────────                  │
│                                     │
│  WHY                                │
│  The ELF header is the first...     │
│                                     │
│  MODEL                              │
│  ┌─────────────────────────────┐    │
│  │ Simplified model here       │    │
│  │ ⚠️ This is simplified       │    │
│  └─────────────────────────────┘    │
│                                     │
│  REALITY                            │
│  The specification defines...       │
│                                     │
│  EXAMPLE                            │
│  ┌─────────────────────────────┐    │
│  │ 00000000  7f 45 4c 46 ...   │    │
│  │ ──────────────────────────  │    │
│  │ ↑ Magic bytes (0x7f ELF)    │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Next: Entry Point →]              │
└─────────────────────────────────────┘
```

### 3. Exercise Component

```
┌─────────────────────────────────────┐
│  Exercise 3 of 5                    │
│                                     │
│  What field in the ELF header       │
│  specifies the virtual address      │
│  where execution begins?            │
│                                     │
│  ○ e_phoff                          │
│  ● e_entry                          │
│  ○ e_shoff                          │
│  ○ e_ehsize                         │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ ✓ Correct!                  │    │
│  │                             │    │
│  │ e_entry contains the virtual│    │
│  │ address of the program's    │    │
│  │ entry point. This is where  │    │
│  │ the loader transfers control│    │
│  │ to start execution.         │    │
│  │                             │    │
│  │ e_phoff is the offset to the│    │
│  │ program header table, not   │    │
│  │ the entry point address.    │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Next Exercise →]                  │
└─────────────────────────────────────┘
```

**States:**
- Unanswered: options have no color
- Answered correctly: green background, explanation
- Answered incorrectly: red background, explanation with correct answer highlighted

### 4. Review Card (Spaced Repetition)

```
┌─────────────────────────────────────┐
│  Review 1 of 8                      │
│                                     │
│  What is the purpose of the ELF     │
│  header?                            │
│                                     │
│  [Show Answer]                      │
│                                     │
│  ─────────────────────────────      │
│                                     │
│  Rate your recall:                  │
│                                     │
│  [Again]  [Hard]  [Good]  [Easy]    │
│                                     │
│  Again = "I couldn't remember"      │
│  Hard = "I remembered with effort"  │
│  Good = "I remembered, some effort" │
│  Easy = "Instant, effortless"       │
│                                     │
│  Next review: [calculated date]     │
└─────────────────────────────────────┘
```

### 5. Progress Bar

```
Module Progress
████████████░░░░░░░░ 4/6 concepts

Course Progress
██████░░░░░░░░░░░░░░ 12/20 concepts
```

**Rules:**
- Show concepts learned, not percentage
- Never show "You're 60% done!" — show "12 of 20 concepts learned"
- Green fill for completed, blue for in-progress, gray for not started

### 6. Knowledge Health View

```
Knowledge Health

Strong ( mastered )
  ELF Header
  Binary Representation

Learning ( reviewing )
  Program Headers — next review: tomorrow
  Sections — next review: in 3 days

Weak ( needs attention )
  Relocations — accuracy: 45%
  Dynamic Linking — accuracy: 52%

Not Yet Learned
  DWARF Debugging
  Thread-Local Storage
```

### 7. Energy Check-in

```
Before you start, how are you feeling?

┌─────────┐  ┌─────────┐  ┌─────────┐
│  😊     │  │  😐     │  │  😔     │
│  Good   │  │  Okay   │  │  Low    │
│         │  │         │  │         │
└─────────┘  └─────────┘  └─────────┘

How long would you like to study?

[10 min]  [15 min]  [20 min]  [30 min]

What would you like to do?

[Learn new]  [Review]  [Mixed]
```

**Behavior based on selection:**
- **Good + 30 min + Learn new:** Full session with new concepts
- **Okay + 15 min + Review:** Review session with easy items
- **Low + 10 min + Mixed:** Short session, mostly review, no hard exercises

### 8. Session Summary

```
Session Complete

You reviewed 5 concepts and practiced 12 exercises.
8 were correct on the first try.
4 needed a second attempt.

Next session: Tomorrow, 3 reviews due. ~5 minutes.

[Continue Learning]  [Done for Today]
```

**Rules:**
- Never say "3 wrong" — say "3 needed a second attempt"
- Never show percentages — show counts
- Always preview next session

---

## Interaction Patterns

### Exercise Flow

1. Present question (no time pressure unless opted in)
2. Learner selects answer
3. Immediate feedback:
   - Correct: green background + explanation
   - Incorrect: red background + explanation + correct answer highlighted
4. "Next Exercise" button appears
5. Progress bar advances

### Review Flow

1. Show front of card (question)
2. Learner clicks "Show Answer"
3. Show back of card (answer)
4. Learner rates: Again / Hard / Good / Easy
5. FSRS computes next interval
6. Next card appears
7. When queue empty: session summary

### Lesson Flow

1. Present 8 learning units sequentially
2. Each unit has a "Continue" button
3. Visualizations are embedded inline
4. Retrieval questions pause the flow (must answer before continuing)
5. Exercises are embedded in the lesson
6. "Next Concept" at the end

### Navigation

```
Header: [Logo]  [Courses]  [Progress]  [Settings]

Breadcrumb:  Courses > ELF > Module 2 > ELF Header Fields

Sidebar (desktop):  Concept list with completion status

Footer:  [← Previous Concept]  [Next Concept →]
```

---

## Accessibility

### Requirements

1. **WCAG 2.1 AA** compliance minimum
2. **Color contrast:** 4.5:1 for normal text, 3:1 for large text
3. **Focus indicators:** Visible focus ring on all interactive elements
4. **Keyboard navigation:** All interactions work with keyboard only
5. **Screen reader:** All content accessible via ARIA labels
6. **Reduced motion:** Respect `prefers-reduced-motion`
7. **Text scaling:** Layout works at 200% zoom
8. **Alt text:** All images and visualizations have descriptive alt text

### Focus Management

- When a new exercise appears, focus moves to the question
- When feedback appears, focus moves to the feedback
- When a new card appears, focus moves to the card
- Tab order follows visual reading order

### Color Independence

- Never use color alone to convey information
- Always pair color with text labels or icons
- Example: ✓ Correct (green + checkmark) not just green

---

## Mobile Design

### Breakpoints

```
Mobile:   < 640px
Tablet:   640-1024px
Desktop:  > 1024px
```

### Mobile Adaptations

1. **Sidebar collapses** — becomes hamburger menu
2. **Content goes full-width** — no side-by-side layouts
3. **Visualizations scale** — touch-friendly, pinch-to-zoom
4. **Exercise options stack** — vertical instead of horizontal
5. **Bottom navigation** — thumb-friendly zone for primary actions
6. **Larger touch targets** — minimum 44x44px

### Touch Interactions

- **Tap:** Select answer, navigate
- **Swipe:** Next/previous card (optional)
- **Pinch:** Zoom visualizations
- **Long press:** Show hint (optional)

---

## Dark Mode

### Implementation

- Respect system preference (`prefers-color-scheme`)
- Allow manual toggle in settings
- Persist preference in local storage
- All components support both modes

### Dark Mode Adjustments

- Reduce brightness (not pure black background)
- Increase contrast slightly for readability
- Use brighter versions of primary colors
- Shadows become subtle glows

---

## Loading States

### Skeleton Loading

```
┌─────────────────────────────────────┐
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓              │
│                                     │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓          │
└─────────────────────────────────────┘
```

- Use skeleton screens, not spinners
- Match the shape of the content being loaded
- Animate with subtle pulse

### Progress Indicators

- **Course download:** Progress bar with bytes downloaded
- **Exercise evaluation:** Brief loading indicator (< 100ms, often not needed)
- **Sync:** Subtle sync icon in header

---

## Empty States

### No Courses Yet

```
┌─────────────────────────────────────┐
│                                     │
│  📚                                │
│                                     │
│  No courses yet                     │
│                                     │
│  Download a course to get started.  │
│                                     │
│  [Browse Courses]                   │
│                                     │
└─────────────────────────────────────┘
```

### No Reviews Due

```
┌─────────────────────────────────────┐
│                                     │
│  ✓                                 │
│                                     │
│  All caught up!                     │
│                                     │
│  No reviews due today.              │
│  Next review: tomorrow              │
│                                     │
│  [Learn Something New]              │
│                                     │
└─────────────────────────────────────┘
```

### Session Complete

```
┌─────────────────────────────────────┐
│                                     │
│  🎉 (subtle, not loud)             │
│                                     │
│  Nice work!                         │
│                                     │
│  You reviewed 5 concepts and        │
│  practiced 12 exercises.            │
│                                     │
│  Next session: Tomorrow, ~5 min     │
│                                     │
│  [Done for Today]                   │
│                                     │
└─────────────────────────────────────┘
```

---

## Animation Guidelines

### Principles

1. **Purposeful** — every animation explains something or provides feedback
2. **Subtle** — 150-300ms duration, gentle easing
3. **Respectful** — honor `prefers-reduced-motion`
4. **Never decorative** — no bouncing mascots, no confetti (except rare milestones)

### Allowed Animations

| Animation | Duration | Purpose |
|---|---|---|
| Card flip (review) | 300ms | Reveal answer |
| Fade in | 200ms | New content appearing |
| Slide up | 200ms | Feedback appearing |
| Progress bar fill | 400ms | Show progress advance |
| Focus ring | 150ms | Keyboard navigation |
| Page transition | 200ms | Navigate between pages |

### Forbidden Animations

- Bouncing or jumping elements
- Flashing or strobing
- Auto-playing animations
- Looping animations (except loading skeleton pulse)
- Confetti (except rare milestones like course completion)
- Particle effects

---

## Typography in Practice

### Lesson Text

```
The ELF header is the first structure in an ELF file.
It provides the system with essential information about
how to process the file.

The header contains fields for:
  - File class (32-bit or 64-bit)
  - Data encoding (little-endian or big-endian)
  - ELF version
  - Target OS/ABI
  - Architecture type
  - Entry point address
```

### Code Blocks

```
┌─────────────────────────────────────┐
│  // ELF header structure            │
│  struct Elf64_Ehdr {                │
│      unsigned char e_ident[16];     │
│      Elf64_Half    e_type;          │
│      Elf64_Half    e_machine;       │
│      Elf64_Word    e_version;       │
│      Elf64_Addr    e_entry;         │
│  }                                  │
└─────────────────────────────────────┘
```

- Background: `--surface` color
- Border: 1px `--border`
- Font: monospace at 14px
- Numbers in gutter (optional)
- Syntax highlighting (if Chemical code)

### Hex Dumps

```
┌─────────────────────────────────────┐
│  00000000  7f 45 4c 46 02 01 01 00  │ .ELF.... │
│  00000008  00 00 00 00 00 00 00 00  │ ........ │
│  00000010  03 00 3e 00 01 00 00 00  │ ..>..... │
│  00000018  40 10 40 00 00 00 00 00  │ @.@..... │
│           ─────────────────────────  │          │
│           ↑ e_entry (0x401040)       │          │
└─────────────────────────────────────┘
```

- Clickable bytes highlight corresponding fields
- Annotations below with arrows
- Color-coded by field type

---

## Design Tokens (CSS Custom Properties)

```css
:root {
  /* Colors */
  --bg: #ffffff;
  --surface: #f8f9fa;
  --border: #e5e7eb;
  --text-primary: #111827;
  --text-secondary: #6b7280;
  --primary: #2563eb;
  --success: #059669;
  --warning: #d97706;
  --error: #dc2626;

  /* Typography */
  --font-sans: 'Inter', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --text-xs: 12px;
  --text-sm: 14px;
  --text-base: 16px;
  --text-lg: 18px;
  --text-xl: 20px;
  --text-2xl: 24px;
  --text-3xl: 30px;
  --text-4xl: 36px;

  /* Spacing */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;

  /* Borders */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px rgba(0,0,0,0.07);
  --shadow-lg: 0 10px 15px rgba(0,0,0,0.1);

  /* Transitions */
  --duration-fast: 150ms;
  --duration-normal: 200ms;
  --duration-slow: 300ms;
  --easing: cubic-bezier(0.4, 0, 0.2, 1);

  /* Layout */
  --max-width-content: 720px;
  --max-width-visualization: 960px;
  --sidebar-width: 240px;
  --header-height: 64px;
}
```
