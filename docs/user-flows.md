# User Flows

Complete user interaction flows for Underlayer. Every screen, every action, every data point.

## Flow 1: First-Time User (Onboarding)

### Purpose
Convert visitors into learners. Deliver value before asking for commitment.

### Screens (7 max, 2-3 minutes)

```
Screen 1: Welcome
┌─────────────────────────────────────────┐
│                                         │
│           Underlayer                    │
│     Learn Things Deeply                 │
│                                         │
│   [Start Learning]                      │
│                                         │
│   No signup required.                   │
│                                         │
└─────────────────────────────────────────┘

Screen 2: Why Are You Here?
┌─────────────────────────────────────────┐
│                                         │
│   What brings you here?                 │
│                                         │
│   ○ I'm curious about how computers    │
│     work                                │
│   ○ I need this for my career          │
│   ○ I'm a student learning CS          │
│   ○ I want to build things             │
│                                         │
│   [Continue]                            │
│                                         │
└─────────────────────────────────────────┘

Screen 3: Prior Knowledge
┌─────────────────────────────────────────┐
│                                         │
│   How much do you know about binary     │
│   formats like ELF?                     │
│                                         │
│   ○ Never heard of them                │
│   ○ I know they exist                  │
│   ○ I've used readelf/objdump          │
│   ○ I've written parsers              │
│                                         │
│   [Continue]                            │
│                                         │
└─────────────────────────────────────────┘

Screen 4: Session Preference
┌─────────────────────────────────────────┐
│                                         │
│   How long do you want to study?        │
│                                         │
│   ○ 5 min   (Casual)                   │
│   ● 10 min  (Regular)  ← default      │
│   ○ 20 min  (Serious)                  │
│   ○ 45 min  (Deep dive)                │
│                                         │
│   You can change this anytime.          │
│                                         │
│   [Continue]                            │
│                                         │
└─────────────────────────────────────────┘

Screen 5: Placement Quiz (Optional)
┌─────────────────────────────────────────┐
│                                         │
│   Quick check to find your starting     │
│   point. Skip if you prefer to start    │
│   from the beginning.                   │
│                                         │
│   Question 1: What are the first 4      │
│   bytes of an ELF file?                 │
│                                         │
│   [0x7F ELF]  [MZ\x90]  [PE\x00]      │
│                                         │
│   Skip this step →                      │
│                                         │
└─────────────────────────────────────────┘

Screen 6: Building Your Course
┌─────────────────────────────────────────┐
│                                         │
│   ████████████░░░░░░  60%              │
│                                         │
│   Finding the best starting point       │
│   for you...                            │
│                                         │
└─────────────────────────────────────────┘

Screen 7: First Lesson
┌─────────────────────────────────────────┐
│                                         │
│   Bytes and Binary                      │
│   15 min · Core concept                 │
│                                         │
│   Every piece of data in a computer     │
│   is stored as bytes. Understanding     │
│   bytes is the foundation for           │
│   understanding ELF.                    │
│                                         │
│   [Start Learning]                      │
│                                         │
└─────────────────────────────────────────┘
```

### Data Collected

| Screen | Data | Type | Used For |
|--------|------|------|----------|
| 2 | `goal` | enum: curiosity, career, student, builder | Commitment device (changes user's mental state) |
| 3 | `prior_knowledge` | enum: none, aware, used_tools, written_parsers | Starting point selection |
| 4 | `session_minutes` | int: 5, 10, 20, 45 | Session length default |
| 5 | `placement_score` | int: 0-3 (optional) | Skip ahead if high |

### Data Flow

```
Onboarding Complete
  ↓
Save to LearnerState:
  - goal: string
  - prior_knowledge: enum
  - session_minutes: int
  - placement_score: int (if taken)
  - onboarding_complete: true
  ↓
Determine Starting Concept:
  - prior_knowledge == "none" → Start at "Bytes" (concept 1)
  - prior_knowledge == "aware" → Start at "ELF Identification" (concept 4)
  - prior_knowledge == "used_tools" → Start at "ELF Header Fields" (concept 5)
  - prior_knowledge == "written_parsers" → Start at "Program Headers" (concept 8)
  - placement_score >= 2 → Skip to placement result
  ↓
Deliver First Lesson
  ↓
THEN ask for account creation (deferred signup)
```

### Design Rules

1. **No signup wall** — deliver first lesson before asking for account
2. **Default to middle** — pre-select 10 min/day (users rarely change defaults)
3. **Commitment device** — answering "why are you here?" primes the user to take it seriously
4. **Skip placement** — power users feel efficient, beginners feel safe
5. **Manufactured anticipation** — "Building your course..." loading is theater (course is pre-built)
6. **Quick wins** — first lesson questions are trivially easy, 5 dopamine hits in 90 seconds

## Flow 2: Course Browsing

### Purpose
Help users find and start courses. Show progress for returning users.

### Screens

```
Screen 2a: Course Catalog
┌─────────────────────────────────────────┐
│   Courses                               │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │ ELF — Executable and Linkable   │   │
│   │ Format                          │   │
│   │ 15 concepts · 20 hours          │   │
│   │ ████████░░░░░░  40% complete    │   │
│   │ [Continue] [Review]             │   │
│   └─────────────────────────────────┘   │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │ TLS — Transport Layer Security  │   │
│   │ Coming soon                     │   │
│   │ [Notify me]                     │   │
│   └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘

Screen 2b: Course Detail
┌─────────────────────────────────────────┐
│   ELF — Executable and Linkable Format  │
│                                         │
│   Understand the ELF binary format      │
│   from first principles.                │
│                                         │
│   15 concepts · 20 hours · v1.2         │
│                                         │
│   Modules:                              │
│   ┌─────────────────────────────────┐   │
│   │ 1. Fundamentals                 │   │
│   │    ✓ Bytes and Binary           │   │
│   │    ✓ Binary Representation      │   │
│   │    ○ File Layout                │   │
│   ├─────────────────────────────────┤   │
│   │ 2. ELF Header                   │   │
│   │    ○ Identification             │   │
│   │    ○ Header Fields              │   │
│   │    ○ Entry Point                │   │
│   ├─────────────────────────────────┤   │
│   │ 3. Program Headers              │   │
│   │    ○ Table                      │   │
│   │    ○ Segment Types              │   │
│   │    ○ Memory Mapping             │   │
│   └─────────────────────────────────┘   │
│                                         │
│   [Start from Beginning]                │
│   [Continue Where You Left Off]         │
│   [Test Out]                            │
│                                         │
└─────────────────────────────────────────┘
```

### Data Points

| Data | Source | Used For |
|------|--------|----------|
| `course_progress` | Repository (learner_progress table) | Progress bar, completion % |
| `concept_status` | Repository (per-concept state) | Checkmarks, lock icons |
| `module_completion` | Computed from concepts | Module headers |
| `last_activity` | Repository (sessions table) | "Continue where you left off" |

### Navigation Rules

1. **Default path**: Linear sequence with clear next-step guidance
2. **Expert bypass**: "Test Out" allows skipping ahead
3. **Prerequisite enforcement**: Locked concepts show lock icon
4. **Free navigation**: Click any unlocked concept to jump there
5. **Progress always visible**: Progress bar on every screen

## Flow 3: Learning Session

### Purpose
Deliver content effectively. Maximize retention through active recall and interleaving.

### Session Setup Screen

```
Screen 3a: Session Setup
┌─────────────────────────────────────────┐
│                                         │
│   How are you feeling?                  │
│                                         │
│   ○ I'm ready to learn                 │
│   ○ I'm okay, let's go                 │
│   ○ I'm low energy, keep it light      │
│                                         │
│   Session type:                         │
│   [Learn New]  [Review]  [Mixed]        │
│                                         │
│   Duration: 10 min (your default)       │
│                                         │
│   [Start Session]                       │
│                                         │
└─────────────────────────────────────────┘
```

### Session Flow

```
┌─────────────────────────────────────────┐
│                                         │
│  INTRO (30 sec)                         │
│  "In this lesson you'll learn how       │
│   ELF identifies itself with magic      │
│   bytes."                               │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  CONCEPT (2-3 min)                      │
│  WHY → MODEL → REALITY → EXAMPLE        │
│  Short text, diagrams, hex dumps        │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  INTERACT (2-5 min)                     │
│  Interactive exercises with immediate   │
│  right/wrong feedback                   │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  RETRIEVE (1-2 min)                     │
│  Active recall — no hints               │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  APPLY (2-5 min)                        │
│  Exercise using the knowledge           │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  CONNECT (1 min)                        │
│  "This relates to program headers..."   │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  SUMMARY (15 sec)                       │
│  "You learned: ELF magic bytes,         │
│   identification fields."               │
│  [Next Concept]  [Take a Break]         │
│                                         │
└─────────────────────────────────────────┘
```

### Feedback Delivery

| Scenario | Feedback | Example |
|----------|----------|---------|
| Correct | Right/wrong + elaboration | "Correct! The magic bytes are 0x7F followed by 'E', 'L', 'F'." |
| Wrong (first attempt) | Right/wrong + hint | "Not quite. Think about what makes ELF files unique compared to other formats." |
| Wrong (second attempt) | Right/wrong + correct answer | "The answer is 0x7F ELF. This identifies the file as an ELF binary." |
| Stuck (3+ attempts) | Offer skip | "Would you like to see the explanation and move on?" |

### Data Collected During Session

| Data | Type | Used For |
|------|------|----------|
| `concept_id` | string | Track which concepts are learned |
| `exercise_results` | array of {exercise_id, correct, attempts, time_seconds} | Accuracy, difficulty |
| `session_duration` | int (seconds) | CLSI calculation |
| `hints_used` | int | Difficulty signal |
| `skip_count` | int | Frustration signal |
| `energy_before` | enum | CLSI input |
| `energy_after` | enum | Fatigue detection |

### Break Suggestions

| Trigger | Action |
|---------|--------|
| Accuracy drops >15% from rolling average | "Taking a break helps memory. Resume later?" |
| Session duration > 80% of chosen length | "You've been learning for 8 minutes. Want to continue or save progress?" |
| 3 consecutive errors | "This concept is tricky. Let's try a different approach." |
| CLSI < 0.40 for 2+ sessions | Reduce difficulty automatically |

## Flow 4: Review Session (Spaced Repetition)

### Purpose
Maintain long-term retention through spaced practice.

### Flow

```
┌─────────────────────────────────────────┐
│                                         │
│  REVIEW SESSION                         │
│  5 items due today · ~8 min             │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Question: What field in the ELF header │
│  contains the entry point address?      │
│                                         │
│  [Think about it...]                    │
│                                         │
│  [Show Answer]                          │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Answer: e_entry                        │
│                                         │
│  How well did you remember?             │
│                                         │
│  [Again]  [Hard]  [Good]  [Easy]        │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Next item: How many section headers    │
│  can an ELF file have?                  │
│                                         │
│  Progress: ████░░░░░░ 2/5               │
│                                         │
└─────────────────────────────────────────┘
```

### Rating Rules

| Rating | When | FSRS Effect | UI Behavior |
|--------|------|-------------|-------------|
| Again | Complete blackout | Reset interval, increase difficulty | Show answer again in 1 minute |
| Hard | Recalled with significant effort | Short interval, increase difficulty | Move to next item |
| Good | Recalled with some effort | Normal interval | Move to next item |
| Easy | Instant, effortless | Long interval, decrease difficulty | Move to next item |

### Design Rules

1. **No time pressure** — learner decides when to reveal answer
2. **Equally sized buttons** — no "wrong" button is smaller
3. **Progress bar advances on "Again"** — forgetting is not punished
4. **Session complete**: "Reviewed 5 concepts. 3 needed second attempt." (no failure language)
5. **Preview next session**: "Tomorrow, 2 reviews due. ~5 minutes."

## Flow 5: Dashboard

### Purpose
Show progress, motivate continued learning, surface next actions.

### Screen

```
┌─────────────────────────────────────────┐
│                                         │
│   Welcome back.                         │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │ Continue Learning                │   │
│   │ ELF — File Layout                │   │
│   │ ████████░░░░░░  40% complete     │   │
│   │ [Resume] [Review Due (3)]        │   │
│   └─────────────────────────────────┘   │
│                                         │
│   This Week                             │
│   Mon ● Tue ● Wed ● Thu ○ Fri ○ Sat ○  │
│   3 concepts learned                    │
│                                         │
│   Knowledge Health                      │
│   ┌─────────────────────────────────┐   │
│   │ Fundamentals     ████████████   │   │
│   │ ELF Header       ████████░░░░   │   │
│   │ Program Headers  ████░░░░░░░░   │   │
│   │ Sections         ░░░░░░░░░░░░   │   │
│   └─────────────────────────────────┘   │
│                                         │
│   Upcoming                              │
│   Tomorrow: 2 reviews due (~5 min)      │
│   This week: 1 new concept available    │
│                                         │
└─────────────────────────────────────────┘
```

### Data Points

| Data | Source | Display |
|------|--------|---------|
| `current_concept` | learner_progress | "Continue Learning" card |
| `course_progress` | computed | Progress bar |
| `reviews_due` | FSRS scheduler | "Review Due (N)" button |
| `weekly_activity` | sessions table | Calendar dots |
| `concepts_learned_this_week` | sessions table | "3 concepts learned" |
| `knowledge_health` | computed from FSRS | Color-coded bars |
| `upcoming_reviews` | FSRS scheduler | "Tomorrow: 2 reviews" |

### Design Rules

1. **Celebrate what was done** — "3 concepts learned" not "4 days missed"
2. **No shame-based leaderboards** — compare to self, not peers
3. **Streak freezes** — forgive one miss, sustain engagement
4. **Progress always visible** — never hide the progress bar
5. **Next action clear** — always show "what to do next"

## Flow 6: Adaptation

### Purpose
Personalize the learning path based on performance and preferences.

### Adaptation Signals

| Signal | Measurement | Threshold | Action |
|--------|-------------|-----------|--------|
| Accuracy | Correct / Total attempts | < 60% over 5+ attempts | Flag concept as weak, check prerequisites |
| CLSI | Weighted formula | < 0.40 for 2+ sessions | Reduce difficulty |
| Speed | Time per exercise | > 2x average | Offer hint, simplify |
| Hints | Hints used / Total exercises | > 50% | Simplify content |
| Skips | Skips / Total exercises | > 30% | Check prerequisites |
| Energy | Self-reported | "Low" for 2+ sessions | Shorter sessions, easier content |

### Adaptation Actions

| Action | Trigger | Implementation |
|--------|---------|---------------|
| Difficulty reduction | Accuracy < 60% | Show easier variant, more scaffolding |
| Prerequisite remediation | Weak prerequisite detected | "Let's review X before continuing" |
| Test-out | Prior knowledge > 60% on diagnostic | Skip to intermediate content |
| Hint escalation | 2+ attempts on same exercise | Show partial hint, then full solution |
| Session length adjustment | CLSI < 0.40 | Reduce session duration by 25% |
| Content simplification | Energy = "Low" for 2+ sessions | Switch to Essential mode |

### Adaptation Flow

```
Performance Data Collected
  ↓
CLSI Computed:
  CLSI = (w1 * accuracy + w2 * (1 - error_rate) + w3 * (1 - retry_rate)) / (w1 + w2 + w3)
  ↓
┌─────────────────────────────────────────┐
│ CLSI >= 0.60                            │
│   → Optimal zone                        │
│   → Continue standard path              │
│   → Gradually increase difficulty       │
├─────────────────────────────────────────┤
│ CLSI 0.40 - 0.60                        │
│   → Adequate zone                       │
│   → Continue, monitor                   │
├─────────────────────────────────────────┤
│ CLSI < 0.40                             │
│   → Overloaded zone                     │
│   → Reduce difficulty                   │
│   → Shorter sessions                    │
│   → More scaffolding                    │
│   → Check prerequisites                 │
└─────────────────────────────────────────┘
  ↓
Knowledge State Updated
  ↓
Next Session Adjusted
```

## Flow 7: Settings/Preferences

### Purpose
Let users control their experience.

### Screen

```
┌─────────────────────────────────────────┐
│   Settings                              │
│                                         │
│   Session Preferences                   │
│   Default duration: [10 min ▼]          │
│   Session type: [Mixed ▼]               │
│   Show progress bar: [✓]                │
│                                         │
│   Review Preferences                    │
│   Target retention: [85% ▼]             │
│   Max reviews per day: [50 ▼]           │
│                                         │
│   Display                               │
│   Content depth: [Detailed ▼]           │
│   Show "i" button: [✓]                  │
│                                         │
│   Notifications                         │
│   Daily reminder: [✓]                   │
│   Review reminder: [✓]                  │
│                                         │
│   [Save]  [Reset to Defaults]           │
│                                         │
└─────────────────────────────────────────┘
```

### Preferences Storage

| Preference | Default | Stored In |
|------------|---------|-----------|
| `session_minutes` | 10 | learner_preferences |
| `session_type` | mixed | learner_preferences |
| `target_retention` | 0.85 | learner_preferences |
| `max_reviews_per_day` | 50 | learner_preferences |
| `content_depth` | detailed | learner_preferences |
| `show_progress_bar` | true | learner_preferences |
| `show_info_button` | true | learner_preferences |
| `daily_reminder` | true | learner_preferences |
| `review_reminder` | true | learner_preferences |

## Data Model for User Flows

### LearnerState

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique learner ID |
| `goal` | enum | Why they're here (from onboarding) |
| `prior_knowledge` | enum | Starting point (from onboarding) |
| `session_minutes` | int | Default session length |
| `placement_score` | int | Placement quiz result |
| `onboarding_complete` | bool | Whether onboarding is done |
| `current_course` | string | Active course ID |
| `current_concept` | string | Active concept ID |
| `created_at` | datetime | First visit |
| `last_active` | datetime | Last session |

### ConceptState

| Field | Type | Description |
|-------|------|-------------|
| `learner_id` | string | FK to LearnerState |
| `concept_id` | string | FK to Concept |
| `status` | enum | not_started, in_progress, mastered |
| `difficulty` | float | FSRS difficulty (1-10) |
| `stability` | float | FSRS stability (days) |
| `retrievability` | float | FSRS retrievability (0-1) |
| `last_review` | datetime | When last reviewed |
| `next_review` | datetime | When next due |
| `accuracy` | float | Rolling accuracy |
| `attempts` | int | Total attempts |

### Session

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique session ID |
| `learner_id` | string | FK to LearnerState |
| `type` | enum | learn, review, mixed |
| `started_at` | datetime | Session start |
| `ended_at` | datetime | Session end |
| `energy_before` | enum | Self-reported energy |
| `energy_after` | enum | Self-reported energy |
| `concepts_hit` | string[] | Concepts encountered |
| `exercises_attempted` | int | Total exercises |
| `exercises_correct` | int | Correct exercises |
| `hints_used` | int | Total hints |
| `skips` | int | Total skips |

## API Endpoints for User Flows

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `/api/onboarding` | POST | Save onboarding data | `{goal, prior_knowledge, session_minutes, placement_score}` | `{learner_id, starting_concept}` |
| `/api/courses` | GET | List courses | — | `[{id, title, progress, concepts}]` |
| `/api/courses/:id` | GET | Course detail | — | `{id, title, modules, concepts}` |
| `/api/sessions/start` | POST | Start learning session | `{course_id, type, energy}` | `{session_id, first_item}` |
| `/api/sessions/:id/next` | POST | Get next item | `{concept_id, result}` | `{next_item, progress}` |
| `/api/sessions/:id/complete` | POST | End session | `{energy_after}` | `{summary, next_reviews}` |
| `/api/review/start` | POST | Start review session | `{course_id}` | `{session_id, items[]}` |
| `/api/review/submit` | POST | Submit review | `{item_id, rating}` | `{next_item}` |
| `/api/dashboard` | GET | Dashboard data | — | `{progress, streak, reviews_due, knowledge_health}` |
| `/api/settings` | GET/PUT | Preferences | `{preferences}` | `{preferences}` |

### Authentication

> **Auth is not implemented yet.** These endpoints are currently open (no session/token). When auth is added:
> - Use `cookie` or `Authorization` header for session identification
> - `/api/onboarding` returns `learner_id` — store in cookie, pass to subsequent requests
> - `/api/courses`, `/api/sessions/*`, `/api/review/*`, `/api/dashboard`, `/api/settings` all require `learner_id`
> - `/api/health` remains open (used by CI/smoke tests)
> - See `docs/implementation-patterns.md` for rate limiting patterns (per-IP for unauthenticated, per-learner for authenticated)
