# Feature Specifications

## Core Features

### 1. Course Delivery

**What:** Render course content as structured, interactive lessons.

**Components:**
- Lesson renderer — converts concept content to interactive pages
- Exercise engine — presents exercises, validates answers, provides feedback
- Visualization renderer — displays interactive diagrams, hex viewers, state machines
- Progress tracker — records what the learner has seen and done

**Design:**
- Short learning units (5-15 minutes per concept)
- Every lesson ends with active recall, not a summary
- Exercises embedded in lessons, not separated
- Visualizations are first-class, not decorations

### 2. Spaced Repetition (FSRS)

**What:** Schedule reviews at optimal intervals to maximize long-term retention.

**Algorithm:** Free Spaced Repetition Scheduler (FSRS) — the same algorithm used in modern Anki.

**How it works:**
1. Learner encounters a concept for the first time
2. System generates 3-8 review items from the concept
3. Learner reviews items, rates recall (Again/Hard/Good/Easy)
4. FSRS computes next review interval based on difficulty, stability, and retrievability
5. Items due for review appear in the daily review session

**Parameters per review item:**
- `difficulty` (D) — inherent difficulty of this item for this learner (1-10)
- `stability` (S) — time until recall drops below target retention (days)
- `retrievability` (R) — current probability of successful recall (0-1)

**Target retention:** 90% (configurable). Higher retention = more reviews per day.

**Why FSRS over SM-2:**
- 20-30% fewer reviews for same retention
- Better handles difficult items
- Models memory more accurately
- Parameters derived from actual forgetting curves

### 3. Interleaved Practice

**What:** Mix concepts from different modules in review sessions and exercises.

**Why:** Interleaving forces the learner to identify *what type of problem is this* before solving it. Research shows 61% retention vs 38% for blocked practice.

**Implementation:**
- Daily reviews pull from all mastered concepts, not just the current module
- Cumulative quizzes mix old and new material
- "Which concept applies here?" challenges before "solve this"
- Exercise sessions randomly interleave problem types

### 4. Retrieval Practice

**What:** Every session includes active recall — the learner must produce answers, not recognize them.

**Types of retrieval:**
1. **Free recall** — "What do you remember about ELF headers?" (no hints)
2. **Cued recall** — "The ELF header contains a field called e_____ that specifies..." (partial hint)
3. **Recognition** — "Which of these is the ELF header magic number?" (multiple choice)
4. **Application** — "Parse this hex dump and extract the entry point" (use the knowledge)

**Design principle:** The struggle of retrieval IS the learning. Wrong answers that trigger retrieval still produce learning benefits.

### 5. Adaptive Pacing

**What:** Adjust session length and difficulty based on the learner's energy and state.

**For anxiety/depression/overthinking:**
- Pacing controls: learner sets preferred session length (10-60 minutes)
- Energy check-in: "How are you feeling?" before each session
- Fatigue detection: if performance drops, suggest a break
- No streak shaming: missing a day is normal, not a failure
- 80% rule: set activity limits at 80% of perceived capacity
- Prevent overactivity-underactivity cycling

**Session types:**
- `learn` — new concepts only
- `review` — spaced repetition reviews only
- `mixed` — learn new + review old (recommended)

**Adaptive behavior:**
- High energy → longer session, harder exercises, new concepts
- Low energy → shorter session, easier reviews, no new concepts
- Anxiety detected → reduce time pressure, simplify feedback
- Fatigue detected → suggest stopping, save progress

### 6. Weakness Detection

**What:** Identify concepts the learner is weak in and provide targeted repair.

**How:**
- Track per-concept accuracy, streak, and difficulty rating
- When accuracy drops below 60% on a concept, flag it as weak
- When a concept depends on a weak prerequisite, suggest reviewing the prerequisite first
- Show the learner a "knowledge health" view: strong concepts, weak concepts, not-yet-learned concepts

**Repair flow:**
1. Detect weakness (low accuracy, high difficulty rating)
2. Check prerequisites (is the foundation solid?)
3. If prerequisite is weak → review prerequisite first
4. If prerequisite is solid → more practice on the weak concept
5. If still weak after practice → simplify the concept, provide different examples

### 7. Course Structure

**What:** Courses are self-contained, portable directories.

**Structure:**
```
courses/
  elf/
    manifest.json
    concepts/
    exercises/
    visualizations/
    assets/
    reviews/
```

**Manifest:**
```json
{
  "id": "elf",
  "title": "ELF — Executable and Linkable Format",
  "version": 1,
  "description": "Understand the ELF binary format from first principles",
  "prerequisites": [],
  "concepts": [
    {
      "id": "bytes",
      "title": "Bytes and Binary",
      "module": "fundamentals",
      "prerequisites": [],
      "estimated_minutes": 15
    }
  ],
  "assets": [
    "assets/samples/hello.elf",
    "assets/samples/libcrypto.so"
  ]
}
```

**Portability rules:**
- No platform-specific dependencies in course content
- No database queries in course files
- All assets are relative paths
- Course can be opened by any compatible player

### 8. Visualization Engine

**What:** Interactive representations of technical concepts.

**Types:**

| Type | Use Case | Interaction |
|---|---|---|
| `hex_viewer` | ELF file inspection | Click bytes to highlight fields, show decoded values |
| `diagram` | File layout, memory map | Click sections to see details, drag to rearrange |
| `state_machine` | TLS handshake, linker states | Click transitions to see messages, step forward/back |
| `timeline` | Loading process, compilation | Scroll through stages, click for details |
| `tree` | Symbol table, include deps | Expand/collapse nodes, search |
| `code_viewer` | Source code + assembly | Highlight correspondence between lines |

**Design rules:**
- Every visualization must answer: "What does this help the learner understand?"
- No decorative animations
- Visualizations explain the actual system, not simplified metaphors
- Each visualization has a clear learning objective

### 9. Offline Support (Android App)

**What:** Download courses to the device and learn without internet.

**Capabilities:**
- Download entire course as a zip
- Store learner state locally (SQLite)
- Sync state to server when online
- Resume exactly where you left off

**Download flow:**
1. Browse available courses in the app
2. Tap "Download" — course zip downloads to device
3. Course is extracted to local storage
4. Learner state is initialized
5. All content is available offline

**Sync:**
- Learner state syncs when connected
- Conflict resolution: server state wins (single-device primary)
- Course updates trigger re-download of changed content

### 10. Auto-Deployment

**What:** On commit to main, the platform builds, tests, and deploys automatically.

**Pipeline:**
1. Commit pushed to main
2. CI builds the Chemical project
3. Runs integration tests (build verification, smoke tests)
4. Builds Android APK (if app changes)
5. Deploys web platform to hosting
6. Updates course content on CDN

**Design constraints:**
- Code must be correct before merge — no "fix it later"
- All tests pass before deploy
- Rollback on any failure
- Course content deploys independently of platform code

## Advanced Features (Phase 2+)

### 11. Knowledge Graph Visualization

Show the learner their position in the concept dependency graph. Visualize strong/weak/unlearned concepts as a node graph.

### 12. Incremental Reading

SuperMemo-style: import technical documentation, extract key passages, create review items automatically. Learn from specs and papers, not just prepared courses.

### 13. Cross-Course Concepts

Shared concepts across courses (e.g., "binary representation" appears in ELF, PE, Mach-O courses). Learn once, review in context.

### 14. Course Updates

When a course version bumps, the learner sees:
- What changed
- What they need to re-learn
- New exercises to try

### 15. Community Feedback

Learners can flag incorrect exercises, suggest improvements, and rate explanations. This feeds back into course improvement.

### 16. Energy Dashboard

Track learning patterns over time:
- Session lengths
- Accuracy trends
- Concept mastery progression
- Energy levels
- Rest patterns

Not for gamification — for helping the learner understand their own learning patterns.
