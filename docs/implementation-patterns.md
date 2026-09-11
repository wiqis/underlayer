# Implementation Patterns — Blind Spots & Critical Details

The "boring but critical" stuff that AIs tend to make blind decisions about. Every pattern here is a decision that must be deliberate, not accidental.

---

## The Blind Spots Checklist

Before implementing ANY feature, verify these 14 categories:

| # | Category | Question | Skill |
|---|----------|----------|-------|
| 1 | Error Handling | What happens when this fails? | `engineering_patterns` §1 |
| 2 | Logging | What gets logged at what level? | `engineering_patterns` §2 |
| 3 | Configuration | Is this configurable or hardcoded? | `engineering_patterns` §3 |
| 4 | API Contract | What's the request/response format? | `engineering_patterns` §4 |
| 5 | Database | Does this need a migration? | `engineering_patterns` §5 |
| 6 | Security | Is input sanitized? Is auth required? | `engineering_patterns` §6 |
| 7 | Caching | Should this be cached? For how long? | `engineering_patterns` §7 |
| 8 | Testing | Are error paths tested? | `engineering_patterns` §8 |
| 9 | Monitoring | Will we know if this breaks? | `engineering_patterns` §9 |
| 10 | Privacy | Are we collecting data we shouldn't? | `engineering_patterns` §10 |
| 11 | Offline | Does this work offline? | `engineering_patterns` §11 |
| 12 | Shutdown | Does this handle graceful shutdown? | `engineering_patterns` §12 |
| 13 | Performance | Does this meet performance budgets? | `engineering_patterns` §13 |
| 14 | Content | Is this validated before deployment? | `engineering_patterns` §14 |

---

## 1. Error Handling

### Every API Endpoint Must Return This
```json
{
  "ok": false,
  "error": {
    "code": "CONCEPT_NOT_FOUND",
    "message": "Human-readable error",
    "details": { "course_id": "elf" }
  },
  "request_id": "req_abc123"
}
```

### Error Code Catalog
| Code | HTTP | When |
|------|------|------|
| `INVALID_REQUEST` | 400 | Malformed body |
| `VALIDATION_ERROR` | 400 | Field validation failed |
| `UNAUTHORIZED` | 401 | Missing/invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource missing |
| `CONFLICT` | 409 | Duplicate resource |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected failure |
| `DATABASE_ERROR` | 500 | DB operation failed |
| `COURSE_COMPILE_ERROR` | 500 | Course file failed |
| `SYNC_CONFLICT` | 409 | Offline sync conflict |

### Never Do This
- ❌ `catch { }` — silently swallow errors
- ❌ `return ""` — return empty string on failure
- ❌ `return null` — return null without logging
- ❌ Print error to stdout — use structured logging
- ❌ Return raw error messages to client

---

## 2. Logging

### Log Format
```
[ISO8601] LEVEL request_id message
```

### What to Log
| Event | Level | Fields |
|-------|-------|--------|
| Server start/stop | INFO | port, mode |
| Request completed | INFO | method, path, status, duration |
| Database error | ERROR | query_name, error, duration |
| Course compile error | ERROR | course_id, file, line, error |
| Auth failure | WARN | token_hint, reason |

### What NOT to Log
- ❌ Passwords or tokens (log last 4 chars)
- ❌ Full SQL queries (log query name + duration)
- ❌ Full request/response bodies
- ❌ Personal notes content

---

## 3. Configuration

### Required Env Vars
| Variable | Type | Default | Required |
|----------|------|---------|----------|
| `PORT` | int | `9000` | No |
| `DATABASE_URL` | string | `./underlayer.db` | No |
| `DATABASE_TOKEN` | string | (empty) | No (Turso needs it) |
| `COURSES_DIR` | string | `./courses` | No |
| `LOG_LEVEL` | string | `info` | No |
| `SESSION_SECRET` | string | (random) | Yes for prod |

### Rules
1. **Fail fast on invalid config** — don't start with bad config
2. **Validate types and ranges** — PORT must be 1-65535
3. **Log all config on startup** — redact secrets
4. **Never hardcode values** — always use config

---

## 4. API Contracts

### Response Shape (Always)
```json
{
  "ok": true/false,
  "data": { ... },
  "error": { ... },
  "request_id": "req_..."
}
```

### Pagination
```json
{
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total_items": 42,
    "total_pages": 3
  }
}
```

### Rate Limits
| Endpoint | Limit |
|----------|-------|
| `GET /api/*` | 60/min |
| `POST /api/*` | 30/min |
| `POST /api/auth/*` | 5/min |

---

## 5. Database

### Migration Rules
1. **Forward-only** — no rollback migrations
2. **Additive only** — never delete columns
3. **Backward compatible** — old code works with new schema
4. **Test against production copy**

### Transaction Pattern
```chemical
conn.begin_transaction()?
// ... multiple operations ...
conn.commit()?
```

### Never Do This
- ❌ Run DDL in request handlers
- ❌ Use string concatenation for SQL
- ❌ Skip transaction for multi-table writes
- ❌ Leave connections open

---

## 6. Security

### Headers (Every Response)
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

### Input Sanitization
- Escape `<`, `>`, `&`, `"`, `'`
- Validate email format
- Limit string lengths
- Reject null bytes

### Never Do This
- ❌ Trust user input
- ❌ Store passwords in plaintext
- ❌ Use GET for state-changing operations
- ❌ Skip CORS for API endpoints
- ❌ Log sensitive data

---

## 7. Caching

### By Content Type
| Content | CDN | Browser | In-Memory |
|---------|-----|---------|-----------|
| Course HTML/CSS/JS | 1yr | 1yr | No |
| API: courses list | 1hr | 5min | 5min |
| API: learner state | No | No | No |
| Static assets | 1yr | 1yr | No |

### Never Do This
- ❌ Cache PII — ever
- ❌ Cache learner-specific data in CDN
- ❌ Use `no-cache` when you mean `no-store`

---

## 8. Testing

### Test Categories
| Category | What | Why |
|----------|------|-----|
| Happy path | Normal operations | Basic functionality |
| Error path | Invalid input, missing resources | Graceful failures |
| Edge cases | Empty data, max/min values | Robustness |
| Concurrency | Simultaneous requests | Thread safety |
| Performance | Response time under load | Scalability |

### Never Do This
- ❌ Skip error path tests
- ❌ Use production database in tests
- ❌ Test against live API
- ❌ Skip cleanup between tests

---

## 9. Monitoring

### Health Check
```json
GET /api/health
{
  "ok": true,
  "data": {
    "status": "healthy",
    "database": "connected",
    "courses_loaded": 1
  }
}
```

### Alert Thresholds
| Alert | Condition |
|-------|-----------|
| High error rate | >1% for 5min |
| Slow responses | p95 > 1s for 5min |
| Database down | Health fails for 1min |
| Memory leak | Growing >10MB/hour |

---

## 10. Privacy

### Data Rules
| Rule | Requirement |
|------|-------------|
| Consent | Explicit opt-in |
| Access | Export all data as JSON |
| Deletion | One-click permanent delete |
| Portability | Standard format export |
| Minimization | Collect only what's needed |
| Retention | Delete after 2 years |

### Never Do This
- ❌ Collect without consent
- ❌ Share with third parties
- ❌ Keep longer than necessary
- ❌ Make deletion difficult

---

## 11. Offline Sync

### Conflict Resolution
| Conflict | Resolution |
|----------|------------|
| Same concept, different progress | Server wins |
| Same note, different content | Server wins |
| Concurrent edits | Last-write-wins |

### Sync Status Indicators
```
✓ Synced          ← Green
● Syncing...      ← Yellow spinner
⚠ Sync failed     ← Yellow warning
✗ Offline         ← Red
```

---

## 12. Graceful Shutdown

### Sequence
```
1. Receive SIGTERM
2. Stop accepting new connections
3. Wait for active requests (max 30s)
4. Close database connections
5. Close file handles
6. Log shutdown complete
7. Exit
```

---

## 13. Performance Budgets

### Per-Request
| Metric | Limit |
|--------|-------|
| Response time | < 100ms (p95) |
| Memory | < 10MB |
| DB queries | < 10 |
| Response body | < 1MB |

### Course Pages
| Metric | Target |
|--------|--------|
| TTFB | < 100ms |
| TTI | < 500ms |
| FCP | < 300ms |
| LCP | < 500ms |
| CLS | < 0.1 |
| Total weight | < 500KB |

---

## 14. Content Validation

### Before Deploying a Course
- [ ] Manifest is valid JSON
- [ ] All concept files compile
- [ ] All exercises have correct answers
- [ ] All source links are valid
- [ ] All images/assets exist
- [ ] No invented byte sequences
- [ ] All hex dumps verified with `readelf`

---

## Additional Blind Spots

### Graceful Degradation
- What happens when Turso is unreachable? → Fall back to local SQLite
- What happens when a course file has a syntax error? → Log error, skip course
- What happens when FSRS calculation fails? → Use default interval

### State Machine
- Session states: `idle → setup → in_progress → paused → completed`
- Learner states: `not_started → learning → reviewing → mastered`
- Review states: `due → in_progress → completed`

### Versioning
- Course version: `semver` (major.minor.patch)
- API version: `/v1/`, `/v2/`
- Schema version: migration number

### Backup & Recovery
- Database: daily backups, 30-day retention
- Course files: git versioned
- Learner data: export available

### Feature Flags
```json
{
  "features": {
    "irt_diagnostic": true,
    "clsi_adaptation": true,
    "offline_sync": false
  }
}
```

### A/B Testing
```json
{
  "experiment": "exercise_order",
  "variants": ["sequential", "random", "adaptive"],
  "traffic_split": [0.33, 0.33, 0.34]
}
```

### Internationalization
- Default language: English
- Character encoding: UTF-8
- Date format: ISO 8601
- Number format: locale-aware

### Code Style
- Functions: `snake_case`
- Types: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Files: `snake_case.ch`

### Git Workflow
```
main ← production
  └── develop ← integration
      ├── feature/xyz
      ├── fix/xyz
      └── course/elf
```

### Dependency Management
1. Check ecosystem first
2. Verify license compatibility
3. Test integration
4. Document in plan.md

---

## Summary

The 14 critical blind spots are:

1. **Error handling** — every failure mode must be handled
2. **Logging** — every important event must be logged
3. **Configuration** — nothing should be hardcoded
4. **API contracts** — every endpoint must have a schema
5. **Database** — every change needs a migration
6. **Security** — every input must be sanitized
7. **Caching** — every cache must have invalidation
8. **Testing** — every error path must be tested
9. **Monitoring** — every failure must be detected
10. **Privacy** — every data collection needs consent
11. **Offline** — every feature must degrade gracefully
12. **Shutdown** — every resource must be cleaned up
13. **Performance** — every operation has a budget
14. **Content** — every course must be validated
