# User Flows Skill

Load this skill when designing screens, writing routes, or implementing user interactions. Documents every screen, action, and data flow.

> **Also load `engineering_patterns`** for API contract details (request/response schemas, error codes, rate limiting, pagination). This skill covers *what the user sees*; `engineering_patterns` covers *how the API works*.

## Quick Reference: All Screens

| Flow | Screen | Purpose |
|------|--------|---------|
| Onboarding | Welcome | First impression, no signup wall |
| Onboarding | Why Are You Here? | Commitment device |
| Onboarding | Prior Knowledge | Starting point selection |
| Onboarding | Session Preference | Duration default |
| Onboarding | Placement Quiz | Optional skip-ahead |
| Onboarding | Building Your Course | Manufactured anticipation |
| Onboarding | First Lesson | Value delivery |
| Course | Catalog | Browse courses, see progress |
| Course | Detail | Module breakdown, prerequisites |
| Session | Setup | Energy check, session type |
| Session | Lesson | 8-unit content delivery |
| Session | Exercise | Interactive practice |
| Session | Summary | What was learned |
| Review | Session | Spaced repetition items |
| Review | Complete | Session summary |
| Dashboard | Main | Progress, streak, next action |
| Settings | Preferences | User controls |

## Flow 1: Onboarding (7 screens, 2-3 minutes)

### Design Rules

1. **No signup wall** — deliver first lesson before asking for account
2. **Default to middle** — pre-select 10 min/day (users rarely change defaults)
3. **Commitment device** — answering "why are you here?" primes the user
4. **Skip placement** — power users feel efficient, beginners feel safe
5. **Manufactured anticipation** — "Building your course..." is theater
6. **Quick wins** — first lesson questions are trivially easy

### Data Collected

| Screen | Data | Type | Used For |
|--------|------|------|----------|
| Why Are You Here? | `goal` | enum: curiosity, career, student, builder | Commitment device |
| Prior Knowledge | `prior_knowledge` | enum: none, aware, used_tools, written_parsers | Starting point |
| Session Preference | `session_minutes` | int: 5, 10, 20, 45 | Session length default |
| Placement Quiz | `placement_score` | int: 0-3 (optional) | Skip ahead |

### Starting Point Logic

```
prior_knowledge == "none"           → Start at "Bytes" (concept 1)
prior_knowledge == "aware"          → Start at "ELF Identification" (concept 4)
prior_knowledge == "used_tools"     → Start at "ELF Header Fields" (concept 5)
prior_knowledge == "written_parsers" → Start at "Program Headers" (concept 8)
placement_score >= 2                → Skip to placement result
```

### Deferred Signup

Ask for account AFTER first lesson:
- Frame as "Save what you earned" not "Give us your data"
- Show what they'll lose if they don't save (progress, streak)
- One-click signup (email only, no password yet)

## Flow 2: Course Browsing

### Catalog Screen

Show for each course:
- Title and description
- Module count and concept count
- Progress bar (0% if not started)
- "Continue" button (if started) or "Start" button (if new)
- "Review Due (N)" badge (if reviews pending)

### Course Detail Screen

Show:
- Course title, description, version
- Module list with concept checkmarks (✓ completed, ○ not started, 🔒 locked)
- "Start from Beginning" button
- "Continue Where You Left Off" button
- "Test Out" button (for expert bypass)

### Navigation Rules

1. **Default path**: Linear sequence with clear next-step guidance
2. **Expert bypass**: "Test Out" allows skipping ahead
3. **Prerequisite enforcement**: Locked concepts show lock icon
4. **Free navigation**: Click any unlocked concept to jump there
5. **Progress always visible**: Progress bar on every screen

## Flow 3: Learning Session

### Session Setup

Three choices:
1. **Energy check**: "I'm ready" / "I'm okay" / "I'm low energy"
2. **Session type**: "Learn New" / "Review" / "Mixed"
3. **Duration**: User's default (from settings)

### Session Flow (8-12 minutes)

```
INTRO (30 sec)
  → "In this lesson you'll learn X"
  → One concrete outcome stated

CONCEPT (2-3 min)
  → WHY → MODEL → REALITY → EXAMPLE
  → Short text, diagrams, hex dumps

INTERACT (2-5 min)
  → Interactive exercises
  → Immediate right/wrong feedback
  → Hint available at every step

RETRIEVE (1-2 min)
  → Active recall — no hints

APPLY (2-5 min)
  → Exercise using the knowledge

CONNECT (1 min)
  → "This relates to..."

SUMMARY (15 sec)
  → "You learned: X, Y, Z"
  → [Next Concept] [Take a Break]
```

### Feedback Rules

| Scenario | Feedback |
|----------|----------|
| Correct | Right/wrong + elaboration |
| Wrong (1st attempt) | Right/wrong + hint |
| Wrong (2nd attempt) | Right/wrong + correct answer |
| Stuck (3+ attempts) | Offer skip |

### Break Triggers

| Trigger | Action |
|---------|--------|
| Accuracy drops >15% from rolling average | "Taking a break helps memory" |
| Duration > 80% of chosen length | "Want to continue or save progress?" |
| 3 consecutive errors | "Let's try a different approach" |
| CLSI < 0.40 for 2+ sessions | Reduce difficulty automatically |

## Flow 4: Review Session (Spaced Repetition)

### Flow

1. Show due items count and estimated time
2. Present question (no timer)
3. Learner clicks "Show Answer" when ready
4. Show answer + rating buttons (equally sized)
5. Learner rates: Again / Hard / Good / Easy
6. Progress bar advances (even on "Again")
7. Repeat until all items reviewed
8. Show session summary

### Rating Effects

| Rating | When | FSRS Effect |
|--------|------|-------------|
| Again | Complete blackout | Reset interval, increase difficulty |
| Hard | Significant effort | Short interval, increase difficulty |
| Good | Some effort | Normal interval |
| Easy | Instant, effortless | Long interval, decrease difficulty |

### Design Rules

1. **No time pressure** — learner decides when to reveal answer
2. **Equally sized buttons** — no "wrong" button is smaller
3. **Progress bar advances on "Again"** — forgetting is not punished
4. **No failure language** — "3 needed second attempt" not "3 wrong"
5. **Preview next session** — "Tomorrow, 2 reviews due. ~5 minutes."

## Flow 5: Dashboard

### Sections

1. **Continue Learning** — top card, always first
   - Course name, current concept
   - Progress bar
   - "Resume" and "Review Due (N)" buttons

2. **This Week** — calendar visualization
   - Mon-Sun dots (filled = active, empty = inactive)
   - "3 concepts learned" summary

3. **Knowledge Health** — color-coded bars
   - Module name + progress bar
   - Green (>80%), Yellow (60-80%), Red (<60%)

4. **Upcoming** — what's next
   - "Tomorrow: 2 reviews due (~5 min)"
   - "This week: 1 new concept available"

### Design Rules

1. **Celebrate what was done** — "3 concepts learned" not "4 days missed"
2. **No shame-based leaderboards** — compare to self, not peers
3. **Streak freezes** — forgive one miss, sustain engagement
4. **Progress always visible** — never hide the progress bar
5. **Next action clear** — always show "what to do next"

## Flow 6: Adaptation

### Signals

| Signal | Measurement | Threshold | Action |
|--------|-------------|-----------|--------|
| Accuracy | Correct / Total | < 60% over 5+ attempts | Flag concept weak |
| CLSI | Weighted formula | < 0.40 for 2+ sessions | Reduce difficulty |
| Speed | Time per exercise | > 2x average | Offer hint |
| Hints | Hints used / Total | > 50% | Simplify content |
| Skips | Skips / Total | > 30% | Check prerequisites |
| Energy | Self-reported | "Low" for 2+ sessions | Shorter sessions |

### CLSI Formula

```
CLSI = (w1 * accuracy + w2 * (1 - error_rate) + w3 * (1 - retry_rate)) / (w1 + w2 + w3)

Initial weights: w1 = 1.0, w2 = 1.0, w3 = 1.0
Adapt from data: increase weights for signals that predict poor outcomes
```

### CLSI Interpretation

| CLSI | Zone | Action |
|------|------|--------|
| >= 0.60 | Optimal | Continue, gradually increase difficulty |
| 0.40 - 0.60 | Adequate | Continue, monitor |
| < 0.40 | Overloaded | Reduce difficulty, shorter sessions, check prerequisites |

### Adaptation Actions

| Action | Trigger | Implementation |
|--------|---------|---------------|
| Difficulty reduction | Accuracy < 60% | Show easier variant, more scaffolding |
| Prerequisite remediation | Weak prerequisite | "Let's review X before continuing" |
| Test-out | Prior knowledge > 60% | Skip to intermediate content |
| Hint escalation | 2+ attempts | Partial hint, then full solution |
| Session length adjustment | CLSI < 0.40 | Reduce duration by 25% |
| Content simplification | Energy "Low" 2+ sessions | Switch to Essential mode |

## Flow 7: Settings

### Preferences

| Preference | Default | Options |
|------------|---------|---------|
| `session_minutes` | 10 | 5, 10, 15, 20, 30, 45, 60 |
| `session_type` | mixed | learn, review, mixed |
| `target_retention` | 0.85 | 0.80, 0.85, 0.90, 0.95 |
| `max_reviews_per_day` | 50 | 20, 30, 50, 100 |
| `content_depth` | detailed | essential, detailed, full_reference |
| `show_progress_bar` | true | true, false |
| `show_info_button` | true | true, false |
| `daily_reminder` | true | true, false |
| `review_reminder` | true | true, false |

## Data Model

### LearnerState

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique learner ID |
| `goal` | enum | Why they're here |
| `prior_knowledge` | enum | Starting point |
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

## API Endpoints

> **Implemented vs. planned (verified 2026-09-17).** The routes below marked ✅ exist in `app/main.ch` (~175 routes total). The onboarding/session-flow endpoints marked ⬜ are the design target from the flows above — the onboarding page + `/api/onboarding/complete` + `/api/onboarding/check` now exist, but the structured `start/next/complete` learning-session flow is not implemented. Full list of implemented routes: see the `api_reference` skill.

### Implemented ✅

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Server status |
| `/api/auth/register\|login\|logout`, `/api/auth/me` | POST/GET | **Auth (bearer sessions)** |
| `/api/auth/forgot-password\|reset-password\|verify-email` | POST | Account recovery |
| `/api/user/profile\|settings\|learning-preferences` | GET/PUT | Per-learner settings |
| `/api/user/export`, `/api/user/account` (DELETE) | GET/DELETE | Data export + deletion |
| `/api/learners` + `/:learnerId` | POST/GET | Learner CRUD |
| `/api/courses`, `/api/courses/all`, `/api/courses/:courseId` | GET | Course listing/detail/filter |
| `/api/courses/:courseId/lessons/:conceptId` | GET | Lesson content |
| `/api/courses/:courseId/enroll`, `/api/enrollments` | POST/GET | Enrollments |
| `/api/courses/:courseId/reviews(+rating)`, `/api/reviews/:id` | POST/GET/PUT/DELETE | Course reviews |
| `/api/review/start?course_id=&mode=&count=` | GET | Start review (10 modes) |
| `/api/review/submit` | POST | Submit rating |
| `/api/review/end` | POST | End session |
| `/api/review/due` | GET | Due items |
| `/api/sessions`, `/api/sessions/:id`, `/api/session/detail` | GET | History/detail |
| `/api/session/pause\|resume\|abort\|undo\|skip` | POST | Session controls |
| `/api/exercises/:conceptId`, `/api/exercises/submit`, `/api/exercises/hint` | GET/POST | Exercise engine |
| `/api/exercises/import\|seed\|stats` | POST/GET | Bulk exercise management |
| `/api/progress`, `/api/progress/:courseId`, `/api/progress/export` | GET | Progress |
| `/api/progress/share`, `/api/progress/shared/:token`, `/api/progress/import` | POST/GET | Share + import |
| `/api/analytics/sessions`, `/api/analytics/concept/:conceptId` | GET | Analytics |
| `/api/analytics/difficulty\|errors\|engagement\|velocity\|temporal\|retention\|dropoff\|funnel\|comparative\|platform\|cohorts\|devices` | GET | Extended analytics |
| `/api/weaknesses` (+export/compare/alerts) | GET | Weakness dashboard |
| `/api/health/knowledge(/per-module)(/projection)` | GET | Knowledge health API |
| `/api/goals` | POST/DELETE | Learning goals |
| `/api/fsrs/optimize\|reset\|export\|import` | GET/POST | FSRS settings |
| `/api/search`, `/api/navigation/:courseId/:conceptId`, `/api/recent` | GET | Discovery |
| `/api/onboarding/complete`, `/api/onboarding/check` | POST/GET | Onboarding state |
| `/api/notifications` (+read/unread-count/delete) | GET/POST/DELETE | Notifications |
| `/api/bookmarks`, `/api/notes`, `/api/streaks`, `/api/achievements`, `/api/study-plans`, `/api/certificates` | CRUD | Feature endpoints |
| `/api/feedback` (+admin/report-exercise/stats) | POST/GET/PUT | Content feedback |
| `/api/courses/:courseId/prerequisites`, `/can-enroll`, `/assess(ment)` | CRUD | Learning paths |

### Pages ✅

| Path | Purpose |
|------|---------|
| `/` | Home (course grid, quick actions) |
| `/dashboard` | Dashboard |
| `/review` | Review UI (6 mode cards, rating buttons) |
| `/progress` | Progress UI |
| `/courses/:courseId` | Course landing |
| `/courses/:courseId/lessons/:conceptId` | Lesson viewer |
| `/login`, `/register`, `/forgot-password`, `/reset-password` | Auth pages |
| `/settings`, `/onboarding` | Settings UI, onboarding flow |
| `/u/:username` | Public profile page |
| `/analytics(/:courseId)` | Analytics pages |
| `/bookmarks`, `/notes`, `/study-plans`, `/achievements`, `/streaks`, `/notifications`, `/certificates` | Feature pages |
| `/courses/:courseId/path` | Learning-path visualization |
| `/help`, `/shortcuts`, `/faq`, `/about`, `/terms`, `/privacy` | Help + legal |

### Planned ⬜

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/sessions/start` / `next` / `complete` | POST | Structured learning-session flow |
| `/api/dashboard` | GET | Dashboard data (page exists; data comes from other endpoints) |

## Implementation Patterns (Chemical)

### Route Registration (as implemented in app/main.ch)

```chemical
srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
    underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
}))

srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
    underlayer_web::handle_review_submit(db, &raw mut req, &raw mut res)
}))
```

Handlers build JSON with string appends and send via `send_json_str` / `send_error` (from `web/src/helpers.ch`).

### Page Rendering

```chemical
public func render_dashboard(db : *database::DbClient, learner_id : *std::string) : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()

    var learner = repository::get_learner(db, learner_id)
    var progress = repository::get_progress(db, learner_id)
    var reviews_due = learning::get_due_count(db, learner_id)

    #html {
        <div class="dashboard">
            <Card>
                <CardBody>
                    <CardTitle>Continue Learning</CardTitle>
                    <Text>{progress.current_concept}</Text>
                    <div class="progress-bar">
                        <div style={`width: ${progress.percent}%`}></div>
                    </div>
                    <Button variant="default">Resume</Button>
                    @{if(reviews_due > 0) {
                        #html {
                            <Button variant="outline">Review Due ({reviews_due})</Button>
                        }
                    }}
                </CardBody>
            </Card>
        </div>
    }

    return page.toString()
}
```

### Form Handling

```chemical
#html {
    <form onSubmit={handleSubmit}>
        <Field label="How are you feeling?">
            <Radio name="energy" value="ready" onChange={setEnergy}>I'm ready to learn</Radio>
            <Radio name="energy" value="okay" onChange={setEnergy}>I'm okay</Radio>
            <Radio name="energy" value="low" onChange={setEnergy}>I'm low energy</Radio>
        </Field>
        <Button type="submit">Start Session</Button>
    </form>
}
```

## Gotchas

1. **No signup wall** — deliver value before asking for commitment
2. **Default to middle** — users rarely change defaults
3. **No time pressure** — learner decides pace
4. **No shame** — celebrate progress, don't punish forgetting
5. **Progress always visible** — never hide the progress bar
6. **Next action clear** — always show "what to do next"
7. **Adapt from data** — not from assumptions
