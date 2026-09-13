# Features Checklist — Underlayer

Master feature checklist for the Underlayer platform. 1884 features across 27 sections.

## Location

`lang/compiled/underlayer/docs/features-complete.md`

## Priority System (MANDATORY)

Every feature has a priority tag. **Always work on the lowest available priority number.**

| Tag | Priority | Description |
|-----|----------|-------------|
| **P0** | Critical | Must have for MVP |
| **P1** | Important | Should have for launch |
| **P2** | Nice to have | Enhances experience |
| **P3** | Future | Long-term vision |

### How to Use

1. **Before starting work:** Read the checklist. Find the lowest unchecked priority.
2. **Pick a feature:** Choose the next unchecked P0 (or P1 if all P0 done, etc.).
3. **Implement:** Write the code, build, verify.
4. **Check off:** Change `- [ ] P0 1.2.3...` to `- [x] P0 1.2.3...`.
5. **Verify:** Run the server, hit the endpoint, confirm it works.
6. **Repeat.**

### Rules

- Never implement P3 when P0 or P1 remain unchecked.
- Same priority → implement in numerical order.
- After each feature: build, start server, verify, check off.
- One feature per change. No batching.

### Quick Status

Check current progress:
```bash
$total = (Select-String -Path "lang/compiled/underlayer/docs/features-complete.md" -Pattern "^\- \[").Count
$checked = (Select-String -Path "lang/compiled/underlayer/docs/features-complete.md" -Pattern "^\- \[x\]").Count
"$checked / $total features checked"
```

---

## Section Overview

| Section | Description | Priority Range |
|---------|-------------|----------------|
| 1. Learning Engine | FSRS, sessions, weaknesses, health | P0-P3 |
| 2. Course Authoring | Manifest, structure, metadata | P2-P3 |
| 3. Course Content | Visualizations, exercises | P3 |
| 4. Exercise System | Types, feedback, hints | P1-P3 |
| 5. Review & Spaced Repetition | Scheduling, adaptive | P1-P3 |
| 6. Progress & Analytics | Tracking, dashboards | P1-P3 |
| 7. User Experience | Navigation, theming, keyboard | P1-P3 |
| 8-27. Everything Else | Social, enterprise, AI, etc. | P3 |

---

## Current State

- **P0**: Core FSRS ✅, basic sessions ✅, basic weakness ✅, basic health ✅
- **P1**: Session management ✅, FSRS graduation ✅, lapse recovery ✅
- **P2**: Not started
- **P3**: Not started

Last updated: After session management + FSRS improvements implementation.
