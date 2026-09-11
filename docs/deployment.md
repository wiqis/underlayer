# Deployment Architecture

## Overview

Underlayer has two deployment targets:
1. **Web platform** — hosted service for browsing courses and managing account
2. **Android app** — offline-first course player with download and local learning

Both are built from the same Chemical codebase. The web platform serves the API and web UI. The Android app downloads courses and provides the offline learning experience.

## Auto-Deployment Pipeline

```
git push main
  ↓
CI: Build Chemical project
  ↓
CI: Run integration tests
  ↓
CI: Build web platform
  ↓
CI: Build Android APK (if app changes)
  ↓
CD: Deploy web to hosting
  ↓
CD: Upload APK to distribution
  ↓
CD: Update course CDN (if course content changed)
```

### Design Principle

**Code must be correct before merge.** There is no "fix it later" — the auto-deploy pipeline means every commit goes live. This enforces:

- All tests pass before merge
- Code review before merge
- No broken builds in production

### Rollback

If any deployment step fails:
1. Previous version stays live
2. Failure is reported immediately
3. Fix is committed and pipeline re-runs

## Web Platform

### Stack

- **Server:** Chemical `http::server::Server` with thread pool
- **Database:** SQLite via Turso HTTP v2 (local dev + cloud)
- **Storage:** Tigris S3 (course assets, APK downloads)
- **Hosting:** Fly.io or similar (single binary deployment)

### Modules

```
src/main.ch              (wiring only)
   ↓
web/                     (public pages, SSR)
   ↓
admin/                   (course management)
   ↓
api/                     (JSON REST endpoints)
   ↓
content/                 (course rendering, exercise engine)
   ↓
learning/                (FSRS, progress, review scheduling)
   ↓
repository/              (ALL data access)
   ↓
models/                  (domain structs)
database/                (Turso HTTP client)
storage/                 (S3 client)
   ↓
core/                    (config, logging, utils)
```

### API Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/health` | GET | Health check |
| `/api/courses` | GET | List available courses |
| `/api/courses/:id` | GET | Course metadata |
| `/api/courses/:id/download` | GET | Download course zip |
| `/api/learner/state` | GET | Get learner state |
| `/api/learner/state` | POST | Update learner state |
| `/api/learner/review` | GET | Get due review items |
| `/api/learner/review` | POST | Submit review results |
| `/api/learner/session` | POST | Log a learning session |

### Authentication

- Simple token-based auth for Android app
- Web: optional account (courses can be used without account)
- Learner state is tied to device ID or account

## Android App

### Stack

- **Language:** Chemical (compiled to native via TCC or LLVM)
- **UI:** Native Android (JNI bridge to Chemical)
- **Storage:** SQLite (local database for learner state)
- **Course Storage:** File system (downloaded course directories)

### Architecture

```
Android UI (Kotlin/Java)
   ↓ JNI
Chemical Runtime
   ↓
Course Player (renders course content)
   ↓
FSRS Engine (spaced repetition scheduling)
   ↓
Local SQLite (learner state, review history)
   ↓
File System (downloaded courses)
```

### Offline-First Design

The app works entirely offline after course download:

1. **First launch:** Download courses from server
2. **Learning:** All content is local, no network needed
3. **Review:** Spaced repetition runs locally
4. **Sync:** When online, sync learner state to server
5. **Updates:** When online, check for course updates

### Download Flow

```
User taps "Download" on a course
  ↓
App requests course zip from server
  ↓
Zip downloaded to temp directory
  ↓
Zip extracted to courses/<id>/
  ↓
Course manifest loaded
  ↓
Review items generated (if first download)
  ↓
Learner state initialized
  ↓
Course available offline
```

### Course Player

The course player renders course content locally:

1. **Read manifest.json** — get concept list, metadata
2. **Render lesson** — convert concept content to native UI
3. **Present exercises** — interactive exercise engine
4. **Show visualizations** — render interactive diagrams
5. **Track progress** — record attempts, accuracy, timing
6. **Schedule reviews** — FSRS engine computes next review times

### Sync Protocol

When the app comes online:

```
App sends:
  - Device ID
  - Last sync timestamp
  - Learner state (concept states, review items, session history)

Server responds:
  - Updated learner state (merged from other devices if multi-device)
  - Course updates (new versions available)
  - New courses (if any)
```

Conflict resolution: server state wins. Single-device primary.

## Course Distribution

### Course as Zip

Courses are distributed as zip files:

```
elf-v1.zip
  manifest.json
  concepts/
  exercises/
  visualizations/
  assets/
  reviews/
```

### CDN Hosting

Course zips are hosted on CDN (Tigris S3). When a course version bumps:
1. New zip is uploaded to CDN
2. Old zip remains available (for version pinning)
3. App checks for updates on sync

### Course Updates

When a course updates:
1. App detects new version on sync
2. Downloads only changed content (delta update)
3. Merges with existing local copy
4. Re-generates review items for changed concepts
5. Notifies learner: "Course X has been updated. 3 concepts changed."

## Build System

### Chemical Build

```bash
# Build web platform
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# Build Android (cross-compilation target)
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/libunderlayer.so --target android -bm-modules
```

### CI Pipeline

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    steps:
      - checkout
      - setup-chemical
      - build-web
      - test-web
      - deploy-web
      - build-android (if app changes)
      - upload-apk
      - update-cdn (if courses change)
```

## Environment Variables

| Variable | Purpose | Default |
|---|---|---|
| `UNDERLAYER_PORT` | Server port | 9000 |
| `DATABASE_URL` | Turso HTTP URL | local |
| `DATABASE_TOKEN` | Turso auth token | - |
| `STORAGE_BUCKET` | Tigris S3 bucket | - |
| `STORAGE_ENDPOINT` | Tigris S3 endpoint | - |
| `STORAGE_KEY` | Tigris access key | - |
| `STORAGE_SECRET` | Tigris secret key | - |
| `COURSE_CDN_URL` | CDN URL for course downloads | - |

## Monitoring

- Health check endpoint: `/api/health`
- Deployment status: CI/CD pipeline notifications
- Course download counts: tracked in repository
- Error logging: to file, no external service dependency
