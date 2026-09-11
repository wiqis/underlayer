# Implementation Plan

## Status

Current phase: **Planning** (no code written yet)

## Phases

### Phase 0: Planning ✅

- [x] Read and understand the constitution document
- [x] Research competitors (Brilliant, Exercism, CodeCrafters, roadmap.sh, nand2tetris, OST2, Coursera)
- [x] Research teaching methods for anxiety, depression, overthinking
- [x] Research spaced repetition (FSRS, SM-2, SuperMemo)
- [x] Research desirable difficulties (Bjork), retrieval practice, interleaving
- [x] Write AGENTS.md
- [x] Write conceptual model
- [x] Write feature specifications
- [x] Write competitor analysis
- [x] Write course design methodology
- [x] Write AI constraint system
- [x] Write deployment architecture
- [x] Write skills (7 skills)
- [x] Write implementation plan (this document)

### Phase 1: Foundation (Week 1-2)

**Goal:** Minimal working platform that can serve a static course.

#### 1.1 Project Skeleton
- [ ] Create `chemical.mod` with module structure
- [ ] Create `core/` module (config, env, logging)
- [ ] Create `models/` module (all domain structs)
- [ ] Create `database/` module (Turso HTTP client)
- [ ] Create `repository/` module (schema + basic CRUD)
- [ ] Create `storage/` module (S3 client)

#### 1.2 Course Content Model
- [ ] Implement course manifest parsing (`manifest.json`)
- [ ] Implement concept loading from `.ch` files
- [ ] Implement lesson rendering (concept → HTML)
- [ ] Implement exercise rendering (exercise → interactive HTML)

#### 1.3 Minimal Web Platform
- [ ] Create `web/` module with health endpoint
- [ ] Create course listing page (GET /api/courses)
- [ ] Create course detail page (GET /api/courses/:id)
- [ ] Create lesson viewer (GET /api/courses/:id/lessons/:concept_id)

#### 1.4 First Course Content
- [ ] Create ELF course manifest
- [ ] Write first 3 concepts: Bytes, Binary Representation, File Layout
- [ ] Write 2 exercises per concept
- [ ] Verify against ELF specification (gABI)

**Deliverable:** A deployed website showing the first 3 ELF lessons with exercises.

### Phase 2: Learning Engine (Week 3-4)

**Goal:** Spaced repetition, retrieval practice, and progress tracking.

#### 2.1 FSRS Engine
- [ ] Implement FSRS algorithm (difficulty, stability, retrievability)
- [ ] Implement review scheduling (next review calculation)
- [ ] Implement review session (present items, record ratings)

#### 2.2 Learner State
- [ ] Implement learner state storage (SQLite)
- [ ] Implement concept state tracking (not_started, learning, reviewing, mastered)
- [ ] Implement session history logging

#### 2.3 Retrieval Practice
- [ ] Implement review item generation from concepts
- [ ] Implement free recall questions
- [ ] Implement recognition questions (multiple choice)
- [ ] Implement application exercises

#### 2.4 Interleaved Reviews
- [ ] Implement daily review queue (pull from all learned concepts)
- [ ] Implement cumulative quizzes (mix old and new material)

**Deliverable:** Learner can create account, learn concepts, and get scheduled reviews.

### Phase 3: Course Content (Week 5-8)

**Goal:** Complete ELF course with all concept types.

#### 3.1 ELF Course Modules
- [ ] Module 1: Fundamentals (bytes, binary, file layout)
- [ ] Module 2: ELF Header (identification, fields, entry point)
- [ ] Module 3: Program Headers (table, segments, memory mapping)
- [ ] Module 4: Sections (section header, common sections, section vs segment)
- [ ] Module 5: Symbols (symbol table, binding, visibility)
- [ ] Module 6: Relocations (relocation types, dynamic sections)
- [ ] Module 7: Dynamic Linking (dynamic section, libraries, ld.so)
- [ ] Module 8: Loading (loader, memory layout, execution)

#### 3.2 Visualizations
- [ ] ELF file layout diagram (clickable)
- [ ] Hex viewer with field highlighting
- [ ] Segment-to-memory mapping visualization
- [ ] Symbol table tree
- [ ] Relocation processing visualization

#### 3.3 Exercises
- [ ] 5+ exercises per concept (recall, recognize, apply, debug, construct)
- [ ] Debug exercises (find errors in ELF parsers)
- [ ] Hex inspection exercises (read real ELF files)
- [ ] Construction exercises (write small ELF parsers)

#### 3.4 Review Items
- [ ] Generate 5-8 review items per concept
- [ ] Verify all review items against specification
- [ ] Test all exercises for correctness

**Deliverable:** Complete ELF course with 50+ concepts, 200+ exercises, 5 visualizations.

### Phase 4: Android App (Week 9-12)

**Goal:** Offline-first Android app for course learning.

#### 4.1 Chemical Runtime for Android
- [ ] Cross-compile Chemical to Android (JNI bridge)
- [ ] Implement local SQLite for learner state
- [ ] Implement file system access for course storage

#### 4.2 Course Player
- [ ] Implement course download and extraction
- [ ] Implement lesson rendering (concept → Android UI)
- [ ] Implement exercise engine (exercise → interactive UI)
- [ ] Implement visualization rendering

#### 4.3 Offline Learning
- [ ] Implement local FSRS engine
- [ ] Implement offline review sessions
- [ ] Implement progress sync when online

#### 4.4 Polish
- [ ] Implement energy check-in UI
- [ ] Implement session length preferences
- [ ] Implement fatigue detection
- [ ] Implement "welcome back" messaging (no streak shaming)

**Deliverable:** Android app that downloads ELF course and provides offline learning.

### Phase 5: Platform Polish (Week 13-16)

**Goal:** Production-ready platform with all features.

#### 5.1 Web Platform
- [ ] Course management admin (create, edit, version courses)
- [ ] Learner dashboard (progress, next reviews, knowledge health)
- [ ] Course download page
- [ ] Account management

#### 5.2 Learning Features
- [ ] Weakness detection and repair recommendations
- [ ] Knowledge graph visualization
- [ ] Energy dashboard (session history, accuracy trends)
- [ ] Course update notifications

#### 5.3 Quality
- [ ] Integration tests for all API endpoints
- [ ] Course content verification tests
- [ ] FSRS algorithm tests
- [ ] Android app tests

#### 5.4 Auto-Deployment
- [ ] CI pipeline (build, test, deploy)
- [ ] Course CDN setup
- [ ] Android APK distribution
- [ ] Rollback mechanism

**Deliverable:** Production platform with auto-deploy, offline Android app, complete ELF course.

## Future Phases (Post-MVP)

### Phase 6: Second Course
- PE format course (portable from ELF course structure)
- Mach-O format course

### Phase 7: Advanced Learning
- Incremental reading (import specs, create review items)
- Cross-course concepts (shared knowledge graph)
- Community feedback (flag errors, suggest improvements)

### Phase 8: More Courses
- TLS implementation
- Linkers and loaders
- Memory allocators
- Virtual memory
- Filesystems

## Chemical Gaps to Document

As we build, we'll encounter Chemical features that don't exist yet. Document them:

| Gap | Description | Workaround |
|---|---|---|
| JNI bridge | Chemical → Android Java interop | TBD — may need to write Android UI in Kotlin, bridge to Chemical |
| Delta updates | Download only changed course content | Full re-download for now |
| File watching | Hot reload during development | Manual restart |

These gaps will be documented in `docs/chemical-gaps.md` as we encounter them.
