# Course Design Methodology

This document defines how courses are structured for deep learning, with special attention to learners with anxiety, depression, and overthinking.

## Core Principles

### 1. Learning Is Not Completion

Completion rates are irrelevant. A learner who watches 100% of a course and remembers 10% has failed. A learner who can explain, predict, and apply knowledge has succeeded.

### 2. Difficulty Is Evidence of Learning

When learning feels hard, that's when durable memory is being built. The platform must normalize struggle:

- "This is supposed to be hard. Difficulty means your brain is building durable memory."
- "You got it wrong. That's okay — the act of trying to recall is what strengthens your memory."
- "Confusion is the beginning of understanding, not the end of it."

### 3. Forgetting Is Expected

The platform never punishes forgetting. It expects it and plans for it.

- "Let's retrieve that again" not "You should already know this."
- Every session includes review of previously learned material
- Review intervals are calculated, not arbitrary

### 4. Small Steps, Consistent Progress

For learners with anxiety and depression:
- Micro-sessions: 10-25 minutes, not 2-hour marathons
- Start with easy wins to build self-efficacy
- Never start with the hardest concept
- Set activity limits at 80% of perceived capacity
- Consistent daily rhythm over occasional bursts

## Course Structure

### The Concept Dependency Graph

Every course has a knowledge graph. Concepts have prerequisites. The course walks the learner through the graph in dependency order, but allows review and revisiting at any time.

```
Module 1: Fundamentals
  Concept 1.1: Bytes and Binary
  Concept 1.2: Binary Representation
  Concept 1.3: File Layout

Module 2: ELF Header
  Concept 2.1: ELF Identification (Magic Bytes)
  Concept 2.2: ELF Header Fields
  Concept 2.3: Entry Point

Module 3: Program Headers
  Concept 3.1: Program Header Table
  Concept 3.2: Segment Types
  Concept 3.3: Memory Mapping

Module 4: Sections
  Concept 4.1: Section Header Table
  Concept 4.2: Common Sections
  Concept 4.3: Section vs Segment

... (more modules)
```

### Lesson Structure

> **Canonical source.** This is the authoritative definition of the 8-unit lesson structure. All other documents (skills, guides, handbooks) should reference this section, not repeat it.

Each concept follows this structure:

```
1. WHY (1-2 minutes)
   Why does this concept exist? What problem does it solve?
   Without this, what would go wrong?

2. MODEL (2-3 minutes)
   A simplified mental model. Explicitly marked as simplified.
   "For now, think of a segment as a memory region."
   "That model is useful but incomplete. Here's what actually happens."

3. REALITY (3-5 minutes)
   The actual technical detail. Specifications, byte layouts, field definitions.
   "The ELF specification defines program headers as follows..."

4. EXAMPLE (2-3 minutes)
   A concrete, verifiable example.
   Real bytes, real hex dumps, real structures.
   "Here is an actual ELF header. Let's walk through each field."

5. INTERACT (2-5 minutes)
   An interactive exercise or visualization.
   "Click on each field in this hex dump to see its meaning."
   "Find e_entry in this hex dump."

6. RETRIEVE (1-2 minutes)
   Active recall question. No hints. The learner must produce the answer.
   "Without looking back: what field in the ELF header specifies the entry point?"

7. APPLY (2-5 minutes)
   An exercise that uses the knowledge.
   "Given this malformed ELF, what's wrong with the header?"

8. CONNECT (1 minute)
   How this concept relates to others.
   "This connects to program headers because..."
   "We'll see this again when we study relocations."
```

Total: 15-25 minutes per concept.

### The Learning Loop

```
LOOP 1: Learn → Recall → Apply
  Understand a concept
  ↓
  Recall it without hints
  ↓
  Apply it to a concrete example

LOOP 2: Learn Related → Recall Previous → Connect
  Learn the next concept
  ↓
  Recall the previous concept
  ↓
  Connect the two concepts

LOOP 3: Solve Larger Problem → Expose Weaknesses → Repair
  Solve a problem spanning multiple concepts
  ↓
  Weaknesses become visible
  ↓
  Targeted review of weak concepts

LOOP 4: Review System → Apply to Real Artifact
  Review the entire module
  ↓
  Apply knowledge to a real ELF file

LOOP 5: Build → Debug → Explain
  Implement something (parser, inspector)
  ↓
  Debug it when it fails
  ↓
  Explain why it works
```

## Repetition Strategy

### The Five Exposures

Every important concept is encountered at least five times, each with a different cognitive activity:

1. **First exposure:** Learn the concept (lesson + example)
2. **Second exposure:** Recall it (free recall question)
3. **Third exposure:** Apply it (exercise)
4. **Fourth exposure:** Debug it (find an error involving this concept)
5. **Fifth exposure:** Explain it (teach it back)

### Spaced Intervals

Using FSRS, review items are scheduled at expanding intervals:
- Initial learning: Day 0
- First review: Day 1 (next day)
- Second review: Day 3
- Third review: Day 7
- Fourth review: Day 15
- Fifth review: Day 30
- ... and so on, adapting based on learner performance

### Interleaved Reviews

Daily reviews pull from ALL learned concepts, not just the current module. This prevents:
- Forgetting old material while learning new material
- Illusion of mastery (easy because it's fresh)
- Poor discrimination between concept types

## Exercise Design

### Every Exercise Must

1. Have a verifiable correct answer
2. Test understanding, not just recognition
3. Include an explanation of WHY the answer is correct
4. Target a specific misconception
5. Be checked for correctness, ambiguity, and solvability

### Exercise Progression

Within each concept, exercises progress through levels:

| Level | Type | Cognitive Demand |
|---|---|---|
| 1 | Recognition | "Which of these is X?" |
| 2 | Recall | "What is X?" |
| 3 | Application | "Use X to solve this" |
| 4 | Analysis | "Why does X work this way?" |
| 5 | Debugging | "Find the error in this X" |
| 6 | Construction | "Build something using X" |

### Feedback Design

**Correct answer:**
> Correct. The ELF header field e_entry contains the virtual address of the program's entry point. This is where execution begins when the loader transfers control to the program.

**Wrong answer (targeting specific misconception):**
> You selected "section offset" but the question asks about the entry point. The entry point is a virtual address, not a file offset. The ELF header has two address-related fields: e_entry (entry point address) and e_phoff (program header table offset). The entry point tells the loader where to start executing code.

**Never just say:**
> ❌ Wrong.
> ❌ Incorrect.
> ❌ Try again.

## Anxiety-Friendly Design

### Before Each Session

1. **Energy check-in:** "How are you feeling today?" (Low / Medium / High)
2. **Session length preference:** "How long would you like to study?" (10 / 15 / 20 / 30 / 45 / 60 min)
3. **Session type:** "What would you like to do?" (Learn new / Review / Mixed)

### During Sessions

- **No time pressure on exercises** (unless the learner opts in)
- **Pause anywhere** — progress is saved automatically
- **No streak display** — streaks cause anxiety when broken
- **Subtle progress indicators** — "3 concepts learned this week" not "Day 47 streak!"
- **Fatigue detection** — if accuracy drops significantly, suggest: "You're doing great. Want to take a break?"

### After Sessions

- **Session summary:** "You reviewed 5 concepts and practiced 12 exercises. 8 were correct on the first try."
- **No failure language:** "3 needed a second attempt" not "3 were wrong"
- **Next session preview:** "Tomorrow, you have 2 reviews due. Should take about 5 minutes."

### Dealing with Overthinking

- **Concrete tasks:** "Parse this hex dump" not "Think about ELF"
- **Time-boxing:** Fixed learning periods with hard stops
- **Progress over perfection:** Partial completion is fine
- **One concept at a time:** Don't show the full course tree — show the next step

## Depression-Friendly Design

### Low Motivation Days

- **Review-only mode:** "Just do 5 minutes of review" — lower the bar
- **Easy wins:** Start with concepts the learner already knows well
- **No guilt:** "Welcome back" not "You've been away for 3 days"
- **Micro-accomplishments:** "You reviewed 3 items today" — celebrate small wins

### Cognitive Fatigue

- **Shorter sessions:** Default to 10 minutes, let the learner extend if they want
- **Simpler exercises:** On low-energy days, skip hard exercises
- **Visual learning:** Visualizations require less cognitive effort than text
- **No multi-step exercises:** One question at a time

## Overthinking-Friendly Design

### Analysis Paralysis

- **Clear next step:** Always show exactly one thing to do next
- **No open-ended prompts:** "Which field is e_entry?" not "What do you notice about this hex dump?"
- **Decision limits:** "Choose one of these 4 options" not "Describe what you see"

### Perfectionism

- **Wrong answers are learning:** "The act of trying to recall strengthens your memory, even when you get it wrong."
- **No quality scores:** No "95% mastery" that makes 95% feel like the only acceptable number
- **Progress is cumulative:** Every attempt adds to knowledge, never subtracts
- **Skip option always available:** "Skip this for now" is always a valid choice

## Content Verification

### Source Hierarchy

1. **Primary:** Official specifications, RFCs, standards, authoritative source code
2. **Secondary:** Reputable books, high-quality technical articles
3. **Tertiary:** Forum posts, blogs, AI-generated material (leads only, not authority)

### Verification Checklist

For every technical claim in a course:
- [ ] Is this in the specification? Which section?
- [ ] Is this version-specific? Which version?
- [ ] Is this architecture-specific? Which architecture?
- [ ] Is this implementation-specific? Which implementation?
- [ ] Are the byte layouts, offsets, and sizes correct?
- [ ] Does the example actually work?
- [ ] Are there edge cases I'm hiding?
- [ ] Is the terminology correct per the specification?

### AI Generation Constraints

1. Never generate a course in one pass
2. Never claim a source says something without consulting it
3. Always distinguish specification facts from implementation details
4. Every example must be verifiable
5. Every exercise must be checked for correctness
6. Identify likely misconceptions and address them
7. Teach relationships, not isolated facts
8. Progress from simple models toward reality
