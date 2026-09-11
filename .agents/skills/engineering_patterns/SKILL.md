# Engineering Patterns Skill — Underlayer

The "boring but critical" stuff. AIs tend to make blind decisions about error handling, logging, security, and testing. This skill documents every pattern so decisions are deliberate, not accidental.

---

## Quick Reference

| Category | Topics | Never Do This |
|----------|--------|---------------|
| Error Handling | Recovery, API errors, validation | Never silently swallow errors |
| Logging | What/when/how | Never log passwords, tokens, or PII |
| Configuration | Env vars, validation, defaults | Never hardcode values |
| API Contracts | Schemas, error codes, pagination | Never change response shape |
| Database | Migrations, pooling, transactions | Never run DDL in request handlers |
| Security | CORS, CSRF, rate limiting, XSS | Never trust user input |
| Caching | Strategy, invalidation, keys | Never cache PII |
| Testing | Unit, integration, E2E, content | Never skip error path tests |
| Monitoring | Health, metrics, alerts | Never ignore error rates |
| Privacy | GDPR, consent, retention | Never collect without consent |

---

## 1. Error Handling

### Error Response Format
Every API endpoint returns this structure:
```json
{
  "ok": false,
  "error": {
    "code": "CONCEPT_NOT_FOUND",
    "message": "Concept 'bytes' not found in course 'elf'",
    "details": {
      "course_id": "elf",
      "concept_id": "bytes"
    }
  },
  "request_id": "req_abc123"
}
```

### Error Codes
| Code | HTTP Status | Meaning |
|------|-------------|---------|
| `INVALID_REQUEST` | 400 | Malformed request body |
| `VALIDATION_ERROR` | 400 | Field validation failed |
| `UNAUTHORIZED` | 401 | Missing or invalid auth token |
| `FORBIDDEN` | 403 | Valid token but insufficient permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `CONFLICT` | 409 | Resource already exists (duplicate) |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected server error |
| `DATABASE_ERROR` | 500 | Database operation failed |
| `COURSE_COMPILE_ERROR` | 500 | Course file failed to compile |
| `SYNC_CONFLICT` | 409 | Offline sync conflict |

### Error Handling Rules
1. **Always return structured errors** — never raw strings
2. **Never expose internal details** — no stack traces, no SQL queries, no file paths
3. **Always log the full error** — including stack trace for debugging
4. **Always include request_id** — for tracing errors across logs
5. **Always return the right HTTP status** — 400 for bad input, 404 for missing, 500 for server errors

### Recovery Patterns
```chemical
// Pattern: Try with fallback
func load_course_with_fallback(course_id : string) : Result<Course, Error> {
    var course = load_course(course_id)
    if(course is Result.Err) {
        log_error("Failed to load course: " + course_id, course.error)
        return Result.Err(Error("Course not available"))
    }
    return course
}

// Pattern: Retry with backoff
func retry_database_operation<T>(fn : () => Result<T, Error>, max_retries : int) : Result<T, Error> {
    var attempt = 0
    while(attempt < max_retries) {
        var result = fn()
        if(result is Result.Ok) { return result }
        attempt = attempt + 1
        sleep_ms(attempt * 100)  // Exponential backoff
    }
    return Result.Err(Error("Max retries exceeded"))
}
```

### Never Do This
- ❌ `catch { }` — silently swallow errors
- ❌ `return ""` — return empty string on failure
- ❌ `return null` — return null without logging
- ❌ Print error to stdout — use structured logging
- ❌ Return raw error messages to client — sanitize

---

## 2. Logging

### Log Levels
| Level | When | Example |
|-------|------|---------|
| `DEBUG` | Development only | "Loading concept: bytes" |
| `INFO` | Normal operations | "Server started on port 9000" |
| `WARN` | Degraded but working | "Turso unreachable, falling back to SQLite" |
| `ERROR` | Failed operation | "Failed to compile course: syntax error in bytes.ch" |

### Log Format
```
[2026-09-11T10:30:45Z] INFO  server req_abc123 GET /api/courses/elf/concepts 200 45ms
[2026-09-11T10:30:45Z] ERROR db req_abc123 Failed to connect to Turso: timeout after 5000ms
```

### What to Log
| Event | Level | Fields |
|-------|-------|--------|
| Server start/stop | INFO | port, mode |
| Request received | DEBUG | method, path, request_id |
| Request completed | INFO | method, path, status, duration |
| Database query | DEBUG | query, duration, rows |
| Database error | ERROR | query, error, duration |
| Course compile | INFO | course_id, success, duration |
| Course compile error | ERROR | course_id, file, line, error |
| FSRS calculation | DEBUG | concept_id, old_stability, new_stability, interval |
| Learner progress | DEBUG | learner_id, concept_id, action |
| Auth failure | WARN | token_hint, reason |
| System error | ERROR | error, stack_trace, request_id |

### What NOT to Log
- ❌ Passwords or tokens (log last 4 chars only)
- ❌ Full credit card numbers
- ❌ Personal notes content (log metadata only)
- ❌ Full SQL queries (log query name + duration)
- ❌ Full request/response bodies (log size + schema validation)

### Logging Implementation
```chemical
public enum LogLevel { Debug, Info, Warn, Error }

public struct Logger {
    var level : LogLevel
    var output : *mut FILE

    public func log(level : LogLevel, request_id : string, message : string) {
        if(level < self.level) { return }
        var timestamp = get_timestamp()
        var level_str = level_to_string(level)
        fprintf(self.output, "[%s] %5s %s %s\n", timestamp, level_str, request_id, message)
        fflush(self.output)
    }
}
```

---

## 3. Configuration

### Environment Variables
| Variable | Type | Default | Required | Validation |
|----------|------|---------|----------|------------|
| `PORT` | int | `9000` | No | 1-65535 |
| `DATABASE_URL` | string | `./underlayer.db` | No | Valid path or URL |
| `DATABASE_TOKEN` | string | (empty) | No | Non-empty for Turso |
| `COURSES_DIR` | string | `./courses` | No | Existing directory |
| `LOG_LEVEL` | string | `info` | No | debug/info/warn/error |
| `CORS_ORIGIN` | string | `*` | No | Comma-separated origins |
| `SESSION_SECRET` | string | (random) | Yes for prod | Min 32 chars |
| `MAX_CONCURRENT_SESSIONS` | int | `100` | No | 1-10000 |
| `REQUEST_TIMEOUT_MS` | int | `30000` | No | 1000-300000 |
| `RATE_LIMIT_PER_MINUTE` | int | `60` | No | 1-10000 |

### Config Loading Pattern
```chemical
public struct Config {
    var port : int
    var database_url : string
    var database_token : string
    var courses_dir : string
    var log_level : LogLevel

    public func load() : Result<Config, Error> {
        var config = Config()

        config.port = get_env_int("PORT", 9000)
        if(config.port < 1 || config.port > 65535) {
            return Result.Err(Error("PORT must be 1-65535"))
        }

        config.database_url = get_env_string("DATABASE_URL", "./underlayer.db")
        config.database_token = get_env_string("DATABASE_TOKEN", "")
        config.courses_dir = get_env_string("COURSES_DIR", "./courses")

        var log_level_str = get_env_string("LOG_LEVEL", "info")
        config.log_level = parse_log_level(log_level_str)
        if(config.log_level is null) {
            return Result.Err(Error("Invalid LOG_LEVEL: " + log_level_str))
        }

        return Result.Ok(config)
    }
}
```

### Config Validation Rules
1. **Fail fast on invalid config** — don't start server with bad config
2. **Validate types** — PORT must be int, not string
3. **Validate ranges** — PORT must be 1-65535
4. **Validate existence** — COURSES_DIR must exist
5. **Log all config on startup** — for debugging (redact secrets)

### Never Do This
- ❌ Hardcode `localhost:9000` — always use config
- ❌ Skip validation — bad config causes cryptic errors
- ❌ Log full `DATABASE_TOKEN` — log last 4 chars only
- ❌ Use production config in tests — always use test config

---

## 4. API Contracts

### Request/Response Patterns
```json
// GET /api/courses
// Response:
{
  "ok": true,
  "data": {
    "courses": [
      {
        "id": "elf",
        "title": "Mastering the ELF Format",
        "version": "1.0.0",
        "concepts_count": 42,
        "estimated_minutes": 180
      }
    ]
  },
  "request_id": "req_abc123"
}

// POST /api/learner/progress
// Request:
{
  "concept_id": "bytes",
  "action": "complete",
  "accuracy": 0.85,
  "duration_seconds": 120
}
// Response:
{
  "ok": true,
  "data": {
    "concept_state": {
      "concept_id": "bytes",
      "status": "reviewing",
      "next_review": "2026-09-12T10:00:00Z",
      "stability": 2.5,
      "retrievability": 0.85
    }
  },
  "request_id": "req_def456"
}
```

### Pagination Format
```json
{
  "ok": true,
  "data": {
    "items": [...],
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total_items": 42,
      "total_pages": 3
    }
  }
}
```

### Rate Limiting
| Endpoint | Limit | Window |
|----------|-------|--------|
| `GET /api/*` | 60/min | Sliding window |
| `POST /api/*` | 30/min | Sliding window |
| `POST /api/auth/*` | 5/min | Sliding window |
| `GET /static/*` | 600/min | CDN cached |

### API Versioning
```
/api/v1/courses        → v1 API
/api/v1/courses/elf    → v1 API
/api/v2/courses        → v2 API (breaking changes)
```

### Never Do This
- ❌ Change response shape without version bump
- ❌ Return different types for same field
- ❌ Omit `request_id` from responses
- ❌ Use 200 for errors — always use correct status code

---

## 5. Database

### Migration Strategy
```sql
-- migrations/001_initial.sql
CREATE TABLE learners (
    id TEXT PRIMARY KEY,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- migrations/002_add_email.sql
ALTER TABLE learners ADD COLUMN email TEXT;
-- Never delete columns in production
-- Never rename columns (add new, migrate data, deprecate old)
```

### Migration Rules
1. **Forward-only** — no rollback migrations
2. **Additive only** — never delete columns, only add
3. **Backward compatible** — old code must work with new schema
4. **Test migrations** — run against copy of production data
5. **Version migrations** — `001_`, `002_`, `003_` format

### Connection Pooling
```chemical
public struct ConnectionPool {
    var connections : vector<DbClient>
    var max_size : int
    var current_size : int

    public func acquire() : Result<*mut DbClient, Error> {
        if(self.current_size < self.max_size) {
            var conn = create_connection()
            self.current_size = self.current_size + 1
            return Result.Ok(&raw mut conn)
        }
        // Wait for available connection
        return wait_for_connection()
    }

    public func release(conn : *mut DbClient) {
        // Return to pool, don't close
        self.current_size = self.current_size - 1
    }
}
```

### Transaction Pattern
```chemical
func update_learner_progress(learner_id : string, concept_id : string, score : float) : Result<(), Error> {
    var conn = pool.acquire()?
    defer { pool.release(conn) }

    conn.begin_transaction()?

    // Update concept state
    conn.execute("UPDATE concept_states SET attempts = attempts + 1 WHERE learner_id = ? AND concept_id = ?", learner_id, concept_id)?

    // Update review schedule
    conn.execute("UPDATE review_items SET next_review = ? WHERE learner_id = ? AND concept_id = ?", next_review_time, learner_id, concept_id)?

    conn.commit()?
    return Result.Ok(())
}
```

### Never Do This
- ❌ Run DDL in request handlers — use migrations
- ❌ Use string concatenation for SQL — use parameterized queries
- ❌ Skip transaction for multi-table writes
- ❌ Leave connections open — always release to pool
- ❌ Log full SQL queries — log query name + duration

---

## 6. Security

### CORS Configuration
```chemical
func handle_cors(request : *Request, response : *Response) {
    var origin = request.get_header("Origin")
    var allowed = config.cors_origin

    if(allowed == "*") {
        response.set_header("Access-Control-Allow-Origin", "*")
    } else if(is_origin_allowed(origin, allowed)) {
        response.set_header("Access-Control-Allow-Origin", origin)
    }

    response.set_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
    response.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    response.set_header("Access-Control-Max-Age", "86400")
}
```

### CSRF Protection
```chemical
func generate_csrf_token() : string {
    return random_bytes(32).to_hex()
}

func validate_csrf_token(request : *Request, token : string) : bool {
    var session_token = request.get_session_csrf_token()
    return session_token == token
}
```

### Input Sanitization
```chemical
func sanitize_input(input : string) : string {
    var output = string()
    for(var i = 0u; i < input.size(); i++) {
        var c = input.get(i)
        if(c == '<') { output.append_view("&lt;") }
        else if(c == '>') { output.append_view("&gt;") }
        else if(c == '&') { output.append_view("&amp;") }
        else if(c == '"') { output.append_view("&quot;") }
        else if(c == '\'') { output.append_view("&#x27;") }
        else { output.append(c) }
    }
    return output
}
```

### Rate Limiting Implementation
```chemical
struct RateLimiter {
    var requests : unordered_map<string, vector<timestamp>>
    var max_per_minute : int

    public func is_allowed(client_id : string) : bool {
        var now = current_timestamp()
        var window_start = now - 60

        // Remove old requests
        var requests = self.requests.get_ptr(client_id)
        if(requests != null) {
            requests.value().retain(|ts| ts > window_start)
        }

        // Check limit
        var current_count = requests.value().size()
        if(current_count >= self.max_per_minute) {
            return false
        }

        // Record request
        requests.value().push(now)
        return true
    }
}
```

### Security Headers
```chemical
func set_security_headers(response : *Response) {
    response.set_header("X-Content-Type-Options", "nosniff")
    response.set_header("X-Frame-Options", "DENY")
    response.set_header("X-XSS-Protection", "1; mode=block")
    response.set_header("Referrer-Policy", "strict-origin-when-cross-origin")
    response.set_header("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'")
}
```

### Never Do This
- ❌ Trust user input — always sanitize
- ❌ Store passwords in plaintext — use bcrypt
- ❌ Use GET for state-changing operations — use POST/PUT/DELETE
- ❌ Skip CORS for API endpoints
- ❌ Log sensitive data — redact tokens, passwords, PII

---

## 7. Caching

### Cache Strategy by Content Type
| Content | CDN TTL | Browser TTL | In-Memory | Invalidation |
|---------|---------|-------------|-----------|--------------|
| Course HTML | 1 year | 1 year | No | Version bump |
| Course CSS/JS | 1 year | 1 year | No | Version bump |
| Static assets | 1 year | 1 year | No | Filename hash |
| API: courses list | 1 hour | 5 min | 5 min | Course update |
| API: learner state | No cache | No cache | No cache | N/A |
| API: review items | No cache | No cache | No cache | N/A |

### Cache Key Format
```
course:{course_id}:v{version}:concept:{concept_id}
learner:{learner_id}:state
review:{learner_id}:due
```

### Cache Headers
```chemical
func set_cache_headers(response : *Response, content_type : string, max_age : int) {
    if(content_type == "static") {
        response.set_header("Cache-Control", "public, max-age=31536000, immutable")
    } else if(content_type == "course") {
        response.set_header("Cache-Control", "public, max-age=31536000")
        response.set_header("ETag", compute_etag(content))
    } else if(content_type == "api") {
        response.set_header("Cache-Control", "private, max-age=300")
    } else {
        response.set_header("Cache-Control", "no-store")
    }
}
```

### Never Do This
- ❌ Cache learner-specific data in CDN
- ❌ Cache without version key (stale content)
- ❌ Cache PII — ever
- ❌ Use `no-cache` when you mean `no-store`

---

## 8. Testing

### Test Structure
```
tests/
  unit/
    learning/
      fsrs_test.ch          # Test FSRS algorithm
      clustering_test.ch    # Test interleaving
    repository/
      course_loader_test.ch # Test course loading
    web/
      routes_test.ch        # Test API endpoints
  integration/
    database_test.ch        # Test DB operations end-to-end
    course_compile_test.ch  # Test course compilation
  e2e/
    onboarding_test.ch      # Test full onboarding flow
    learning_session_test.ch # Test learning session
  content/
    elf_bytes_test.ch       # Test ELF course content accuracy
```

### Test Patterns
```chemical
// Unit test
@test func fsrs_next_interval_test() {
    var state = ConceptState {
        stability: 2.5,
        retrievability: 0.85,
        attempts: 5,
        correct: 4
    }

    var next = fsrs_next_interval(state, 0.9)  // 90% target retention

    // Verify interval is reasonable (1-365 days)
    assert(next.interval_days >= 1)
    assert(next.interval_days <= 365)

    // Verify stability increased after correct answer
    assert(next.stability > state.stability)
}

// Integration test
@test func course_loader_test() {
    var loader = CourseLoader("./courses")
    var result = loader.load_course("elf")

    assert(result is Result.Ok)
    var course = result.value()
    assert(course.concepts.size() > 0)
    assert(course.manifest.version == "1.0.0")
}

// API test
@test func api_courses_endpoint_test() {
    var server = create_test_server()
    var response = server.get("/api/courses")

    assert(response.status == 200)
    var body = parse_json(response.body)
    assert(body.get("ok") == true)
    assert(body.get("data").get("courses").is_array())
}
```

### What to Test
| Category | What | Why |
|----------|------|-----|
| Happy path | Normal operations | Ensure basic functionality |
| Error path | Invalid input, missing resources | Ensure graceful failures |
| Edge cases | Empty data, max values, min values | Ensure robustness |
| Concurrency | Multiple simultaneous requests | Ensure thread safety |
| Performance | Response time under load | Ensure scalability |

### Never Do This
- ❌ Skip error path tests — errors are the most common failures
- ❌ Use production database in tests — use test database
- ❌ Test against live API — use mocked responses
- ❌ Skip cleanup — reset state between tests

---

## 9. Monitoring

### Health Check Endpoint
```json
GET /api/health
{
  "ok": true,
  "data": {
    "status": "healthy",
    "version": "1.0.0",
    "uptime_seconds": 3600,
    "database": "connected",
    "courses_loaded": 1,
    "memory_mb": 45.2
  }
}
```

### Key Metrics to Track
| Metric | Type | Alert Threshold |
|--------|------|-----------------|
| `http_requests_total` | Counter | N/A |
| `http_request_duration_ms` | Histogram | p95 > 500ms |
| `http_errors_total` | Counter | Rate > 1% |
| `db_query_duration_ms` | Histogram | p95 > 100ms |
| `db_connections_active` | Gauge | > 80% pool |
| `courses_loaded` | Gauge | 0 (should be >0) |
| `learner_sessions_active` | Gauge | N/A |
| `fsrsCalculations_total` | Counter | N/A |
| `memory_usage_mb` | Gauge | > 500MB |

### Alerting Rules
| Alert | Condition | Action |
|-------|-----------|--------|
| High error rate | >1% errors for 5min | Page on-call |
| Slow responses | p95 > 1s for 5min | Investigate |
| Database down | Health check fails for 1min | Page on-call |
| Memory leak | Memory growing >10MB/hour | Investigate |
| Course compile failure | Any compilation error | Log + alert |

### Never Do This
- ❌ Skip health checks — they're your early warning
- ❌ Ignore slow responses — they become failures
- ❌ Alert on everything — causes alert fatigue
- ❌ Don't monitor learning outcomes — CLSI trends matter

---

## 10. Privacy & Compliance

### Data Collection Rules
| Data | Collected | Stored | Shared | Retention |
|------|-----------|--------|--------|-----------|
| Name | Optional | Local DB | Never | Until deleted |
| Email | Optional | Local DB | Never | Until deleted |
| Learning progress | Yes | Local DB + Turso | Never | 2 years |
| Session history | Yes | Local DB | Never | 6 months |
| Notes | Yes | Local DB | Never | Until deleted |
| Bookmarks | Yes | Local DB | Never | Until deleted |
| Analytics | Anonymized | Server | Aggregated only | 1 year |

### GDPR Compliance
1. **Consent** — explicit opt-in for data collection
2. **Right to access** — export all user data as JSON
3. **Right to deletion** — delete all user data permanently
4. **Right to portability** — export in standard format
5. **Data minimization** — collect only what's needed
6. **Purpose limitation** — use data only for stated purpose

### Data Export
```json
GET /api/learner/export
{
  "learner_id": "...",
  "exported_at": "2026-09-11T10:30:00Z",
  "data": {
    "profile": { ... },
    "progress": [ ... ],
    "sessions": [ ... ],
    "notes": [ ... ],
    "bookmarks": [ ... ]
  }
}
```

### Data Deletion
```json
DELETE /api/learner/account
// Requires confirmation token
// Deletes all data permanently
// Returns 204 No Content
```

### Never Do This
- ❌ Collect data without consent
- ❌ Share data with third parties
- ❌ Keep data longer than necessary
- ❌ Make deletion difficult — one-click deletion
- ❌ Forget to delete backups — backup retention policy

---

## 11. Offline Sync

### Sync Protocol
```json
// Client -> Server: Sync request
{
  "client_version": 3,
  "last_sync": "2026-09-10T10:00:00Z",
  "changes": [
    {
      "type": "progress_update",
      "concept_id": "bytes",
      "data": { "attempts": 6, "correct": 5 },
      "timestamp": "2026-09-10T10:30:00Z"
    }
  ]
}

// Server -> Client: Sync response
{
  "ok": true,
  "server_version": 4,
  "changes": [
    {
      "type": "review_schedule",
      "concept_id": "bytes",
      "data": { "next_review": "2026-09-11T10:00:00Z" },
      "timestamp": "2026-09-10T10:30:05Z"
    }
  ]
}
```

### Conflict Resolution
| Conflict Type | Resolution |
|---------------|------------|
| Same concept, different progress | Server wins |
| Same note, different content | Server wins |
| Same bookmark, different time | Server wins |
| Concurrent edits | Last-write-wins (server timestamp) |

### Sync Status Indicators
```
┌─────────────────────────────────────────┐
│ ✓ Synced                    Last: 2m ago │  ← Green
│ ● Syncing...                             │  ← Yellow spinner
│ ⚠ Sync failed, will retry               │  ← Yellow warning
│ ✗ Offline, changes saved locally         │  ← Red
└─────────────────────────────────────────┘
```

### Never Do This
- ❌ Sync without conflict resolution
- ❌ Sync large payloads — delta sync only
- ❌ Sync immediately on every change — batch changes
- ❌ Show sync errors without retry logic

---

## 12. Graceful Shutdown

### Shutdown Sequence
```
1. Receive SIGTERM
2. Stop accepting new connections
3. Wait for active requests to complete (max 30s)
4. Close database connections
5. Close file handles
6. Log shutdown complete
7. Exit
```

### Implementation
```chemical
var shutdown_flag = false

func handle_shutdown_signal() {
    log_info("Shutdown signal received")
    shutdown_flag = true
}

func graceful_shutdown(server : *Server) {
    // Stop accepting new connections
    server.stop_accepting()

    // Wait for active requests (max 30s)
    var waited = 0
    while(server.active_requests() > 0 && waited < 30000) {
        sleep_ms(100)
        waited = waited + 100
    }

    if(server.active_requests() > 0) {
        log_warn("Forcing shutdown with active requests")
    }

    // Close database
    database.close()

    // Close server
    server.close()

    log_info("Shutdown complete")
}
```

### Never Do This
- ❌ Exit immediately on SIGTERM — drain connections
- ❌ Forget to close database connections — causes resource leaks
- ❌ Wait forever for active requests — set a timeout
- ❌ Skip logging shutdown — needed for debugging

---

## 13. Performance Budgets

### Per-Request Limits
| Metric | Limit | Action on Exceed |
|--------|-------|------------------|
| Response time | < 100ms (p95) | Log warning |
| Memory per request | < 10MB | Reject request |
| Database queries | < 10 per request | Log warning |
| Response body | < 1MB | Reject request |
| Concurrent connections | 100 per IP | Rate limit |

### Course Page Performance
| Metric | Target |
|--------|--------|
| Time to First Byte (TTFB) | < 100ms |
| Time to Interactive (TTI) | < 500ms |
| First Contentful Paint (FCP) | < 300ms |
| Largest Contentful Paint (LCP) | < 500ms |
| Cumulative Layout Shift (CLS) | < 0.1 |
| Total page weight | < 500KB |

### Never Do This
- ❌ Skip performance budgets — they prevent slow creep
- ❌ Ignore p95 — average lies
- ❌ Load entire course into memory — lazy load
- ❌ Make synchronous database calls in request handlers

---

## 14. Content Validation

### Manifest Validation
```json
{
  "required": ["id", "title", "version", "modules"],
  "modules": {
    "required": ["id", "title", "concepts"],
    "concepts": {
      "required": ["id", "title", "file"],
      "optional": ["prerequisites", "estimated_minutes"]
    }
  }
}
```

### Concept File Validation
1. **Syntax check** — compiles without errors
2. **Render check** — produces valid HTML
3. **Exercise check** — all exercises have correct answers
4. **Source check** — all source links are valid
5. **Asset check** — all images/files exist

### Validation Commands
```bash
# Validate manifest
./underlayer validate courses/elf/chemical.mod

# Validate concept files
./underlayer validate courses/elf/src/*.ch

# Validate exercises
./underlayer validate-exercises courses/elf/

# Full validation (manifest + concepts + exercises + assets)
./underlayer validate-all courses/elf/
```

### Never Do This
- ❌ Deploy without validation — broken courses break trust
- ❌ Skip exercise validation — wrong answers destroy learning
- ❌ Ignore asset validation — missing images break lessons
- ❌ Validate only syntax — semantics matter

---

## 15. Git Workflow

### Branching Strategy
```
main          ← production, auto-deploy
  ├── develop ← integration branch
  │   ├── feature/xyz   ← new features
  │   ├── fix/xyz       ← bug fixes
  │   └── course/elf     ← course content
  └── release/x.y.z     ← release preparation
```

### Commit Message Format
```
type(scope): description

Examples:
feat(learning): implement FSRS algorithm
fix(database): handle Turso timeout gracefully
course(elf): add relocations module
docs(api): document review endpoint
test(fsrs): add edge case tests
```

### PR Requirements
1. **All tests pass** — no merge with failing tests
2. **Code review** — at least one approval
3. **No conflicts** — must be up to date with develop
4. **Documentation updated** — if changing API or behavior
5. **Performance budget** — no regression in benchmarks

---

## 16. Dependency Management

### Adding a New Library
```bash
# 1. Check if it exists in ecosystem
ls lang/compiled/*/chemical.mod

# 2. Check license compatibility
cat lang/compiled/<lib>/LICENSE

# 3. Add to chemical.mod
import <lib>

# 4. Test integration
./scripts/test.sh --tcc

# 5. Document in docs/plan.md
```

### Version Pinning
```
# In chemical.mod
import std                    # Latest compatible
import sqlite3 version 1.2.0  # Pinned version
```

### Never Do This
- ❌ Add dependencies without checking licenses
- ❌ Pin to exact version without testing
- ❌ Skip integration testing
- ❌ Forget to document new dependencies

---

## Summary: The AIs Blind Spots Checklist

Before implementing any feature, verify:

- [ ] **Error handling** — What happens when this fails?
- [ ] **Logging** — What gets logged at what level?
- [ ] **Configuration** — Is this configurable or hardcoded?
- [ ] **API contract** — What's the request/response format?
- [ ] **Database** — Does this need a migration?
- [ ] **Security** — Is input sanitized? Is auth required?
- [ ] **Caching** — Should this be cached? For how long?
- [ ] **Testing** — Are error paths tested?
- [ ] **Monitoring** — Will we know if this breaks?
- [ ] **Privacy** — Are we collecting data we shouldn't?
- [ ] **Offline** — Does this work offline?
- [ ] **Shutdown** — Does this handle graceful shutdown?
- [ ] **Performance** — Does this meet performance budgets?
- [ ] **Content** — Is this validated before deployment?
