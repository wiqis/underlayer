# Learning Design Skill

Load this skill when designing how concepts are taught, tested, and retained.

## Core Principles

### 1. Learning Is Not Completion

Completion rates are irrelevant. Understanding is the metric.

### 2. Difficulty Is Evidence of Learning

When learning feels hard, durable memory is being built. Normalize struggle.

### 3. Forgetting Is Expected

Every session includes review. No punishment for forgetting.

### 4. Small Steps, Consistent Progress

10-25 minute sessions. Start with easy wins. 80% capacity rule.

## The FSRS Algorithm

### What Is FSRS

Free Spaced Repetition Scheduler. Models three variables per review item:

| Parameter | Meaning | Range |
|---|---|---|
| Difficulty (D) | How hard this item is for this learner | 1-10 |
| Stability (S) | Time until recall drops below target | days |
| Retrievability (R) | Current probability of recall | 0-1 |

### How It Schedules

1. Learner encounters a new review item
2. Rates recall: Again (1), Hard (2), Good (3), Easy (4)
3. FSRS updates D, S, R based on the rating
4. Computes next interval: `interval = S * (target_retrievability - 1)`
5. Item appears again when retrievability drops below target

### Target Retention

Default: 90%. Higher retention = more reviews per day.

| Target | Reviews/Day (approx) |
|---|---|
| 80% | 20 |
| 85% | 30 |
| 90% | 50 |
| 95% | 80 |

For anxiety-friendly design, default to 85% (fewer reviews, less pressure).

### Rating Guide

| Rating | When | Effect |
|---|---|---|
| Again | Complete blackout, no recall | Reset interval, increase difficulty |
| Hard | Recalled with significant effort, many errors | Short interval, increase difficulty |
| Good | Recalled with some effort, minor errors | Normal interval |
| Easy | Instant, effortless recall | Long interval, decrease difficulty |

## Retrieval Practice

### Why Testing Is Learning

The testing effect (Roediger & Karpicke, 2006): practicing retrieval produces stronger long-term memory than re-reading, even though re-reading feels more productive.

**The act of struggling to recall IS the learning.** Wrong answers that trigger retrieval still produce learning benefits.

### Retrieval Types

| Type | Prompt | Cognitive Demand |
|---|---|---|
| Free recall | "What is X?" (no hints) | Highest |
| Cued recall | "X is a field that..." (partial hint) | High |
| Recognition | "Which of these is X?" (multiple choice) | Medium |
| Application | "Use X to solve this" | High |
| Explanation | "Explain why X exists" | Highest |

### Design Rule

Every lesson ends with active recall, not a summary. Every session includes retrieval of previously learned material.

## Interleaving

### Why Mixing Helps

Interleaving forces the learner to identify WHAT TYPE of problem this is before solving it. Research shows 61% retention vs 38% for blocked practice.

### How to Interleave

1. **Daily reviews** pull from ALL learned concepts, not just the current module
2. **Cumulative quizzes** mix old and new material
3. **"Which concept applies here?"** challenges before "solve this"
4. **Exercise sessions** randomly interleave problem types

### Example

Bad (blocked):
```
Exercise 1: ELF header question
Exercise 2: ELF header question
Exercise 3: ELF header question
```

Good (interleaved):
```
Exercise 1: ELF header question
Exercise 2: Relocation question (from 2 weeks ago)
Exercise 3: Program header question
Exercise 4: Symbol question (from 1 week ago)
```

## Lesson Structure

### The 8-Unit Pattern

Every concept follows this structure:

```
1. WHY (1-2 min)
   Why does this exist? What problem does it solve?

2. MODEL (2-3 min)
   Simplified mental model. Explicitly marked as simplified.

3. REALITY (3-5 min)
   Actual technical detail. Specifications, byte layouts.

4. EXAMPLE (2-3 min)
   Concrete, verifiable example. Real bytes, real structures.

5. INTERACT (2-5 min)
   Interactive exercise or visualization.

6. RETRIEVE (1-2 min)
   Active recall question. No hints.

7. APPLY (2-5 min)
   Exercise that uses the knowledge.

8. CONNECT (1 min)
   How this relates to other concepts.
```

Total: 15-25 minutes per concept.

### The Five Exposures

Every important concept is encountered at least five times:

1. **First:** Learn the concept (lesson + example)
2. **Second:** Recall it (free recall question)
3. **Third:** Apply it (exercise)
4. **Fourth:** Debug it (find an error involving this concept)
5. **Fifth:** Explain it (teach it back)

## Exercise Design

### Exercise Types

| Type | Description | Example |
|---|---|---|
| `multiple_choice` | Select one correct answer | "Which field contains the entry point?" |
| `multiple_answer` | Select all that apply | "Which are program header types?" |
| `fill_blank` | Complete a statement | "The ELF magic bytes are ____" |
| `hex_inspect` | Read bytes from a hex dump | "Find e_entry in this hex" |
| `ordering` | Put items in correct order | "Order these by file offset" |
| `matching` | Connect related items | "Match section to purpose" |
| `labeling` | Label parts of a diagram | "Label ELF header fields" |
| `predict` | Predict system behavior | "What if e_phoff is invalid?" |
| `debug` | Find and fix an error | "This parser reads wrong offset" |
| `classify` | Categorize an item | "Segment or section?" |
| `construct` | Build something | "Write an ELF header parser" |
| `explain` | Explain in your own words | "Why do program headers exist?" |

### Feedback Rules

**Correct:**
> Correct. The ELF header field e_entry contains the virtual address of the program's entry point.

**Wrong (targeting misconception):**
> You selected "section offset" but the question asks about the entry point. The entry point is a virtual address, not a file offset.

**Never:**
> ❌ Wrong.
> ❌ Incorrect.
> ❌ Try again.

### Difficulty Progression

| Level | Type | Cognitive Demand |
|---|---|---|
| 1 | Recognition | "Which of these is X?" |
| 2 | Recall | "What is X?" |
| 3 | Application | "Use X to solve this" |
| 4 | Analysis | "Why does X work this way?" |
| 5 | Debugging | "Find the error in this X" |
| 6 | Construction | "Build something using X" |

## Anxiety-Friendly Design

### Before Each Session

1. Energy check-in: "How are you feeling?" (Low / Medium / High)
2. Session length: "How long?" (10 / 15 / 20 / 30 / 45 / 60 min)
3. Session type: "What would you like to do?" (Learn / Review / Mixed)

### During Sessions

- No time pressure (unless learner opts in)
- Pause anywhere — progress saved
- No streak display
- Subtle progress: "3 concepts this week" not "Day 47!"
- Fatigue detection: if accuracy drops >15% from rolling average over 5 exercises, suggest break
- Capacity limit: session ends at 80% of chosen duration OR after 3 consecutive errors (whichever comes first)

### After Sessions

- Summary: "Reviewed 5 concepts, practiced 12 exercises. 8 correct first try."
- No failure language: "3 needed second attempt" not "3 wrong"
- Preview: "Tomorrow, 2 reviews due. ~5 minutes."

### Overthinking Design

- Concrete tasks: "Parse this hex dump" not "Think about ELF"
- Time-boxing: fixed periods with hard stops
- One concept at a time: show next step, not full tree

### Depression Design

- Review-only mode: "Just 5 minutes"
- Easy wins: start with known concepts
- Welcome back: "Hello" not "You've been away 3 days"
- Micro-accomplishments: "Reviewed 3 items today"

## Weakness Detection

### Detection Rules

| Signal | Threshold | Action |
|---|---|---|
| Accuracy < 60% | Over 5+ attempts on a single concept | Flag as weak |
| Difficulty rating > 4 | Self-reported | Simplify exercises |
| 3+ consecutive "Again" | On any review item | Check prerequisites |
| No practice > 7 days | On any concept | Suggest review |
| CLSI < 0.40 | For 2+ consecutive sessions | Reduce difficulty |

### Repair Flow

1. Detect weakness (low accuracy, high difficulty)
2. Check prerequisites (is foundation solid?)
3. If prerequisite weak → review prerequisite first
4. If prerequisite solid → more practice on weak concept
5. If still weak → simplify, provide different examples
