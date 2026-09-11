# Learner Profiling System

This document defines how Underlayer understands each learner and adapts to their needs.

---

## Why Profiling Exists

Every learner is different. A programmer with 10 years of experience needs different pacing than a student encountering ELF for the first time. Someone with anxiety needs different feedback than someone who thrives on challenge. Profiling lets us adapt without asking 50 questions.

**Critical insight from research:** Learning styles (VARK, Kolb) are neuromyths. Pashler et al. (2008) found virtually no evidence that matching instruction to learning styles improves outcomes. **Do NOT build profiling around "how you learn."** Build it around what actually matters: prior knowledge, goals, pacing needs, and emotional state.

---

## Profiling Architecture

```
Onboarding (5 questions)
  ↓
IRT Diagnostic (5-8 adaptive questions)
  ↓
Learner Profile Created
  ↓
Continuous Behavioral Profiling (no questions needed)
  ↓
Profile Updated Every Interaction
  ↓
Adaptation Rules Applied
```

---

## Phase 1: Onboarding Questionnaire

**5 questions. No more.** Spread across the first screen.

### Question 1: Topic Selection
```
What do you want to learn?

[ELF — Executable and Linkable Format]
[TLS — Transport Layer Security]
[Linkers and Loaders]
[...] (course list)
```

**Purpose:** Filter courses, set context for remaining questions.

### Question 2: Prior Experience
```
How much experience do you have with this topic?

[1] None — I've never touched this before
[2] Basic — I've read about it but never worked with it
[3] Some — I've used it but never dug into internals
[4] Experienced — I've worked with it regularly
[5] Expert — I could teach this to others
```

**Purpose:** Set initial difficulty level, determine prerequisite review needs.

### Question 3: Available Time
```
How much time can you spend per session?

[10 minutes — quick bursts]
[15 minutes — focused sessions]
[20 minutes — standard sessions]
[30 minutes — deep dives]
[As long as I want — no limits]
```

**Purpose:** Set default session length, prevent overactivity.

### Question 4: Learning Challenge
```
What's your biggest challenge when learning?

[Patience — I give up when things get hard]
[Focus — I get distracted easily]
[Overthinking — I get stuck on details]
[Memory — I forget what I've learned]
[Confidence — I doubt myself a lot]
```

**Purpose:** Activate specific support strategies.

### Question 5: Study Preference
```
When do you prefer to study?

[Morning]
[Afternoon]
[Evening]
[Night]
[No preference]
```

**Purpose:** Schedule reminders, optimize notification timing.

### After Onboarding

Show: "Great. Let's check what you already know. This takes 2-3 minutes."

Then proceed to IRT diagnostic.

---

## Phase 2: IRT Diagnostic

**Item Response Theory (IRT)** efficiently assesses knowledge with minimal questions.

### How It Works

1. Start with medium-difficulty question
2. Learner answers (or clicks "I don't know")
3. System updates ability estimate (θ)
4. Select next question that maximizes information at current θ
5. Stop when precision < 0.3 OR 8 questions max

### IRT Model (2PL)

```
P(correct) = 1 / (1 + e^(-a(θ - b)))

Where:
  θ = learner ability (ranges from -3 to +3)
  a = question discrimination (how well it separates abilities)
  b = question difficulty
```

### ELF Diagnostic Questions (Example)

| # | Question | b (difficulty) | a (discrimination) |
|---|----------|---------------|-------------------|
| 1 | What does ELF stand for? | -2.0 | 1.2 |
| 2 | What are the first 4 bytes of an ELF file? | -1.5 | 1.5 |
| 3 | What is the difference between a segment and a section? | -0.5 | 1.8 |
| 4 | What field in the ELF header specifies the entry point? | 0.0 | 1.6 |
| 5 | How does the loader use program headers? | 0.5 | 1.4 |
| 6 | What is the difference between ET_EXEC and ET_DYN? | 1.0 | 1.3 |
| 7 | How do relocations work in dynamic linking? | 1.5 | 1.1 |
| 8 | What is the difference between REL and RELA? | 2.0 | 1.0 |

### Diagnostic Flow

```
θ estimate starts at 0.0 (average)

Q: What does ELF stand for?
A: Correct → θ increases
A: "I don't know" → θ decreases
A: Wrong → θ decreases more

Select next question based on current θ:
  If θ < -1: ask easier questions
  If θ ≈ 0: ask medium questions
  If θ > 1: ask harder questions

Stop when:
  SE(θ) < 0.3 (confident in estimate)
  OR 8 questions answered
```

### Output

```json
{
  "theta": 0.7,
  "standard_error": 0.25,
  "estimated_level": "intermediate",
  "prerequisite_gaps": ["segments", "dynamic-linking"],
  "recommended_start": "program-headers"
}
```

---

## Phase 3: Continuous Behavioral Profiling

After onboarding, the system profiles through behavior — no questions needed.

### Data Collected

| Signal | What It Tells Us | How to Measure |
|---|---|---|
| Response time | Confidence / cognitive load | Time between question display and answer |
| Accuracy | Knowledge level | Correct / incorrect per concept |
| Error patterns | Misconception type | Systematic vs random errors |
| Help usage | Struggling | Hints requested, explanations viewed |
| Session duration | Engagement / energy | Time from start to end |
| Session frequency | Motivation | Days between sessions |
| Review compliance | Retention commitment | % of due reviews completed |
| Skip behavior | Impatience / overwhelm | Content sections skipped |
| Revisit behavior | Uncertainty / thoroughness | Content sections re-read |

### Cognitive Load Stability Index (CLSI)

Composite score from behavioral signals, updated every interaction.

```
CLSI = (w1 × accuracy + w2 × (1 - error_rate) + w3 × (1 - retry_rate)) / (w1 + w2 + w3)

Where:
  accuracy = correct / total_recent
  error_rate = errors / total_recent
  retry_rate = retries / total_recent
  w1, w2, w3 = weights (start at 1.0, learn from data)
```

**Interpretation:**
| CLSI Range | State | Action |
|---|---|---|
| ≥ 0.80 | Underloaded | Increase difficulty, skip reviews |
| 0.40 - 0.80 | Optimal zone | Maintain current level |
| < 0.40 | Overloaded | Decrease difficulty, add hints, suggest break |

### Engagement Signals

| Signal | Healthy | Concerning |
|---|---|---|
| Session frequency | 3-7 days between sessions | > 14 days between sessions |
| Session duration | 10-30 minutes | < 5 minutes (rapid clicking) |
| Review completion | > 70% of due reviews | < 30% of due reviews |
| Exercise attempts | 1-2 per exercise | 4+ per exercise (frustration) |
| Content revisits | Occasional (20-30%) | Never or always (0% or 100%) |

---

## Phase 4: Learner Profile

The accumulated profile, updated every interaction.

```json
{
  "learner_id": "user_123",
  "created": "2026-09-11",
  
  "onboarding": {
    "topic": "elf",
    "prior_experience": 3,
    "session_length_pref": 20,
    "learning_challenge": "overthinking",
    "study_preference": "evening"
  },
  
  "knowledge": {
    "theta": 0.7,
    "standard_error": 0.25,
    "mastery": {
      "bytes": 0.95,
      "binary-representation": 0.92,
      "file-layout": 0.88,
      "elf-header": 0.75,
      "program-headers": 0.45,
      "sections": 0.30,
      "symbols": 0.0,
      "relocations": 0.0
    }
  },
  
  "behavioral": {
    "avg_session_minutes": 18,
    "avg_accuracy": 0.72,
    "avg_response_time_ms": 4500,
    "help_usage_rate": 0.15,
    "review_completion_rate": 0.65,
    "current_streak_days": 3,
    "total_sessions": 12,
    "total_exercises": 87,
    "total_correct": 63
  },
  
  "emotional": {
    "energy_trend": "stable",
    "frustration_events": 2,
    "confidence_level": "moderate",
    "anxiety_indicators": ["rapid_clicking", "skipping_hard_exercises"]
  },
  
  "adaptation": {
    "difficulty_level": "intermediate",
    "session_length_default": 20,
    "hint_frequency": "on_request",
    "error_feedback": "detailed",
    "new_concept_pacing": "standard"
  }
}
```

---

## Adaptation Rules

### Based on Knowledge State

| Condition | Action |
|---|---|
| Mastery > 0.8 for current concept | Skip to next concept |
| Mastery < 0.3 for current concept | Review prerequisites first |
| Mastery < 0.5 for prerequisite | Inject prerequisite review before continuing |
| All prerequisites mastered | Unlock next concept |
| 3+ concepts with mastery < 0.3 | Suggest course restart or prerequisite course |

### Based on CLSI (Cognitive Load)

| CLSI | Action |
|---|---|
| ≥ 0.80 | Offer harder exercises, skip review, present advanced content |
| 0.40 - 0.80 | Maintain current level |
| < 0.40 | Provide worked example, reduce exercise difficulty, suggest break |
| < 0.20 | Pause session, show encouragement, offer to continue tomorrow |

### Based on Emotional State

| Signal | Action |
|---|---|
| Rapid clicking (anxiety) | Slow down, show "Take your time" message |
| Long gaps between sessions (depression) | Welcome back warmly, start with easy reviews |
| 3+ consecutive errors (frustration) | Offer hint, simplify next exercise |
| Skipping hard exercises (avoidance) | Don't force, note pattern, offer easier path |
| High accuracy + fast responses (boredom) | Increase difficulty, offer challenge mode |

### Based on Learning Challenge

| Challenge | Specific Adaptations |
|---|---|
| **Patience** | Shorter sessions, more micro-wins, visible progress bar |
| **Focus** | Minimal UI, no distractions, session timers |
| **Overthinking** | One concept at a time, concrete tasks, time-boxing |
| **Memory** | More frequent reviews, spaced repetition emphasis |
| **Confidence** | Celebrate small wins, "You're doing great" messages |

---

## Adaptive Content Depth

### Three Modes

| Mode | Label | Shows | For Whom |
|---|---|---|---|
| **Essential** | "Overview" | Core concepts only, no edge cases | Beginners, anxious learners |
| **Detailed** | "Complete" | Full explanations, examples, edge cases | Intermediate learners |
| **Full Reference** | "Specification" | Everything including spec quotes, version diffs | Experts, maintainers |

### Mode Selection

- **Default:** Based on prior experience from onboarding
- **Override:** User can toggle at any time
- **Adaptive:** System suggests switching based on behavior

### Rules

- Never label modes as "Beginner/Expert" (implies hierarchy)
- Use neutral labels: "Overview / Complete / Full Reference"
- Persist preference per user
- Allow per-concept override (some concepts warrant more detail)

---

## The "i" Button System

Every factual claim in the course can have an information button.

### What It Shows

On hover/click:
1. **Source:** "Per gABI specification, ELF Identification section"
2. **Verification:** "Verified with readelf on Linux 6.1"
3. **Scope:** "This is portable (not Linux-specific)"
4. **Version:** "ELF gABI 1.1"
5. **Confidence:** "High — directly from specification"

### Visibility Settings

| Setting | Who Sees "i" Buttons |
|---|---|
| **Off** (default for beginners) | No one — clean reading experience |
| **Learners** | Anyone who enables it in settings |
| **Contributors** | Course maintainers and reviewers |
| **Public** | Anyone who toggles it on |

### Why This Matters

- Beginners don't need to see verification status — it clutters the experience
- Advanced learners and maintainers need to verify claims
- Contributors need to check sources during review
- Building trust: "This course is verified against the actual specification"

---

## Questionnaire Design Principles

### Do

1. **Keep it short** — 5 questions maximum at onboarding
2. **Make questions feel relevant** — ask about goals, not abstract preferences
3. **Use behavioral data to fill gaps** — don't ask what you can observe
4. **Allow "I don't know"** — reduces guessing noise in IRT
5. **Spread remaining questions** — 1-2 per session for the first 3 sessions
6. **Show progress** — "Question 3 of 5"

### Don't

1. **Don't ask about learning styles** — they don't improve outcomes
2. **Don't ask more than 5 questions upfront** — causes abandonment
3. **Don't ask about emotions directly** — infer from behavior
4. **Don't force completion** — allow skip, adapt with less data
5. **Don't re-ask answered questions** — persist profile

### Fallback

If the user skips onboarding:
- Default to "intermediate" difficulty
- Default to 20-minute sessions
- Adjust based on first 5 interactions
- Never block progress because profile is incomplete

---

## Privacy and Data

### What We Collect

- Response history (correct/incorrect per exercise)
- Timing data (response time, session duration)
- Navigation data (what they clicked, what they skipped)
- Profile data (from onboarding questionnaire)

### What We Don't Collect

- Personal information (name, email, IP)
- Emotional state (inferred, not asked)
- Browsing history outside the platform
- Device fingerprinting

### Storage

- Learner state stored locally on device (SQLite)
- Optional sync to server (when online)
- No third-party analytics
- Course data is portable (can be exported and deleted)

---

## Implementation Priority

### Phase 1 (MVP)
- 5-question onboarding
- IRT diagnostic (simplified: fixed question set, not adaptive)
- Basic behavioral tracking (accuracy, session duration)
- Simple adaptation (difficulty adjustment based on accuracy)

### Phase 2
- Full IRT adaptive questioning
- CLSI composite score
- Emotional state inference
- Advanced adaptation rules

### Phase 3
- Bayesian Knowledge Tracing
- Predictive modeling
- Cross-course knowledge transfer
- Community-derived profiles (anonymized)
