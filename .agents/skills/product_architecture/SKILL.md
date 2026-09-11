# Product Architecture Skill

Load this skill when understanding or modifying the overall Underlayer system design.

## System Overview

Underlayer is a learning platform for deep technical subjects. It consists of:
1. **Web platform** — course browsing, learner account, course management
2. **Android app** — offline-first course player with spaced repetition
3. **Course format** — self-contained, portable directories with content + exercises + visualizations

## Module Structure

```
underlayer/
├── chemical.mod              (project manifest)
├── src/main.ch               (wiring only — route registration, context building)
│
├── core/                     (config, env, logging, string+time utils)
│   └── src/main.ch
│
├── models/                   (plain domain structs — no business logic)
│   └── src/
│       ├── Course.ch
│       ├── Concept.ch
│       ├── Exercise.ch
│       ├── LearnerState.ch
│       ├── ReviewItem.ch
│       └── Session.ch
│
├── database/                 (Turso HTTP v2 client)
│   └── src/main.ch
│
├── repository/               (ALL SQL lives here — schema + CRUD)
│   └── src/
│       ├── schema.ch
│       ├── courses.ch
│       ├── learners.ch
│       └── reviews.ch
│
├── storage/                  (S3 client for course assets)
│   └── src/main.ch
│
├── content/                  (course loading, lesson rendering, exercise engine)
│   └── src/
│       ├── CourseLoader.ch
│       ├── LessonRenderer.ch
│       ├── ExerciseEngine.ch
│       └── ReviewGenerator.ch
│
├── learning/                 (FSRS engine, progress tracking, review scheduling)
│   └── src/
│       ├── FSRS.ch
│       ├── ProgressTracker.ch
│       ├── ReviewScheduler.ch
│       └── WeaknessDetector.ch
│
├── web/                      (public pages, SSR)
│   └── src/main.ch
│
├── admin/                    (course management, learner admin)
│   └── src/main.ch
│
├── api/                      (JSON REST endpoints)
│   └── src/main.ch
│
├── courses/                  (course content — self-contained directories)
│   └── elf/
│       ├── manifest.json
│       ├── concepts/
│       ├── exercises/
│       ├── visualizations/
│       ├── assets/
│       └── reviews/
│
└── .agents/skills/           (this documentation)
```

## Dependency Chain

```
src/main.ch
   ↓
web/  admin/  api/           (presentation + transport)
   ↓
content/                     (course rendering, exercise engine)
   ↓
learning/                    (FSRS, progress, scheduling)
   ↓
repository/                  (ALL SQL lives here)
   ↓
models/                      (plain domain structs)
database/                    (Turso HTTP client)
storage/                     (S3 client)
   ↓
core/                        (config, env, logging, utils)
```

**Rule:** A layer may only call layers below it. If you are tempted to run SQL inside `web/`, stop — add a repository function instead.

## Data Flow

### Course Loading

```
Request: GET /api/courses/elf
  ↓
api/ reads course ID from URL
  ↓
content/CourseLoader reads courses/elf/manifest.json
  ↓
Returns Course struct with concepts, metadata
```

### Learning Session

```
Request: POST /api/learner/review
  ↓
api/ reads review results (item ID, rating)
  ↓
learning/FSRS computes next interval
  ↓
repository/ updates review item in database
  ↓
learning/ProgressTracker updates concept state
  ↓
Returns next review item (or session complete)
```

### Course Download

```
Request: GET /api/courses/elf/download
  ↓
api/ zips courses/elf/ directory
  ↓
storage/ uploads zip to CDN (if not already there)
  ↓
Returns download URL
```

## Key Design Decisions

### 1. Course as File System

Courses are directories on disk, not database rows. This enables:
- Portable, self-contained artifacts
- Git version control
- Independent distribution
- Offline access (Android app downloads the directory)

### 2. Content Separation

Course content (what to teach) is separate from platform logic (how to present it). This means:
- Courses can be updated independently of platform code
- Courses can be distributed without the platform
- Multiple platforms can consume the same course format

### 3. FSRS Over SM-2

FSRS (Free Spaced Repetition Scheduler) is used instead of SM-2 because:
- 20-30% fewer reviews for same retention
- Better handles difficult items
- Parameters derived from actual forgetting curves
- Modern algorithm (2023) based on memory research

### 4. Chemical for Everything

All implementation is in Chemical, including the Android bridge. This means:
- We discover Chemical gaps early
- Single language for maintenance
- Native performance for course rendering
- Chemical's memory model suits the domain

## Technology Stack

| Component | Technology |
|---|---|
| Language | Chemical |
| Build | TCCCompiler / LLVM Compiler |
| Web Server | `http::server::Server` (thread pool) |
| Database | SQLite via Turso HTTP v2 |
| Storage | Tigris S3 (AWS SigV4) |
| Course Format | JSON manifest + Chemical source files |
| Android | JNI bridge to Chemical runtime |
| CI/CD | GitHub Actions |
| Hosting | Fly.io (web) + Tigris (CDN) |

## Gotchas

- **Universal components have known bugs.** Use carefully. Prefer simple HTML for course content.
- **Chemical is young.** Some features may not exist. Document gaps.
- **Courses must be portable.** No platform-specific dependencies in course files.
- **Auto-deploy on commit.** Code must be correct before merge.
