// underlayer_web — RATE LIMITING, on the endpoints where it is worth having.
//
// WHY ONLY /api/auth/*.  A rate limiter is a cost, and a cost spent on the wrong
// endpoints buys nothing: throttling GET /courses/elf/lessons/byte would just
// make the product worse for the readers it is for.  The endpoints below are the
// ones where an unbounded caller gets something they should not:
//
//   * login -- bcrypt cost 12 costs the SERVER about 0.44s of CPU per attempt
//     (measured 2026-10-02).  A loop of wrong passwords is therefore a
//     denial-of-service from one HTTP client, and it costs the attacker nothing.
//     Twelve attempts in a row answered 401 with no delay and no lockout.
//   * register -- the same CPU shape, plus unbounded account creation.
//   * forgot/reset-password -- an email-sending endpoint, so it is the one that
//     can be pointed at somebody else's inbox.
//
// WHY THE COUNTERS LIVE IN THE DATABASE, and this is the interesting decision.
//
// The obvious implementation is a map in memory, and it was written and thrown
// out.  Two reasons, and the second is the one that matters:
//
//   1. This codebase has NO module-level mutable state anywhere -- there is no
//      established pattern for it, no proven memory semantics, and inventing
//      one inside a request path is how you get a data race in a language whose
//      threading model is still young.
//
//   2. A counter that dies with the process resets on every restart and on every
//      deploy, so a patient attacker simply waits.  It also fails open the moment
//      there is a second process, which is where this platform is going.
//
// A `rate_limits` row is a handful of bytes, costs one indexed SELECT and one
// UPSERT on an endpoint that already spends 0.44s of CPU hashing a password, and
// it survives a restart.  The overhead is invisible next to the work it guards,
// and it is inspectable from outside, which an in-memory counter is not.
//
// THE LIMIT, AND WHY IT IS THIS NUMBER.  8 attempts per 5 minutes per IP per
// endpoint group.  8 is a person typing a password twice and getting it wrong
// once; 8 * 0.44s = 3.5s of CPU for the worst realistic case.  A script sending
// one request per second needs 300 attempts to get through, and by then it has
// burned two minutes of server CPU to buy nothing.
//
// A FIXED WINDOW, and the consequence is written down rather than left to be
// discovered: a caller can burst up to 2x the limit across a window boundary,
// because both halves of a straddle are individually under the cap.  A sliding
// window fixes that at the cost of per-request timestamps or a ring buffer per
// key.  At this ceiling the trade is not worth it, and pretending otherwise
// would be worse than the boundary burst.
//
// WHY X-FORWARDED-FOR IS NOT TRUSTED.  That header is set by whoever sends the
// request, so trusting it means the limiter can be sidestepped by sending a
// different value each time -- which is precisely what an attacker would do.  The
// peer address the socket gives is the only value an attacker does not control.
// Behind a reverse proxy this rate-limits by the proxy's address, which is a
// STRICTER limit, not a weaker one, and the fix belongs in lang/libs/server.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // 8 attempts / 5 minutes for AUTH.  See the header for the arithmetic.
    private func rate_limit_max() : i64 { return 8 }
    private func rate_limit_window() : i64 { return 300 }

    // A DIFFERENT CEILING FOR LEARNING WRITES, and the reason there are two
    // numbers rather than one configurable limit is that the two surfaces have
    // opposite shapes.
    //
    //   auth       8 / 5 min.  A person types a password.  Anything above ~10
    //              is a script, and a script here is a DoS because bcrypt costs
    //              0.44s of CPU per attempt.
    //
    //   learning   120 / 5 min.  A person answering exercises does not hit 120;
    //              a reviewer working through a course deliberately might, and
    //              this platform's own reviewers are the people most likely to.
    //              Measured on the lesson page: a reader doing the exercises in
    //              one sitting produces about 12 submissions.  120 is ten times
    //              that, so a real reader never sees this ceiling.
    //
    // And one endpoint deliberately has NO limit, which is worth stating because
    // "rate limit everything" is the instinct and it is wrong here:
    //
    //   /api/learning/view  POSTed by every lesson page load, for every reader,
    //                       forever.  Limiting it would break the product.  It
    //                       also has nothing to gain from: it only advances a
    //                       timestamp on the caller's OWN row.
    private func rate_limit_write_max() : i64 { return 120 }

    // Create the table.  Idempotent, and called from init_schema's migration
    // path so a fresh database has it.
    public func ensure_rate_limit_table(db : *DbClient) {
        var sql = string("CREATE TABLE IF NOT EXISTS rate_limits (bucket TEXT PRIMARY KEY, window_start INTEGER, count INTEGER)")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // "group|ip" -- the IP is enough to keep the two concerns apart, and the
    // group keeps one noisy learner on /api/auth/login from being refused on
    // /api/auth/register.
    private func rate_limit_bucket(group : &string, ip : &string) : string {
        var b = group.copy()
        b.append_view("|")
        b.append_string(ip)
        return b
    }

    // The caller's peer address, which is the one value the caller does not get
    // to choose.  See the header for why the forwarded header is ignored.
    public func client_ip(req : &http::Request) : string {
        if(req.remote.size() > 0) { return req.remote.copy() }
        return string("unknown")
    }

    // Count one attempt and report whether the caller is still under the limit.
    //
    // Read-then-write rather than one atomic UPSERT, and that is a deliberate
    // simplification with a stated consequence: two simultaneous requests from
    // the same IP can both read count=7 and both write 8, so a burst can reach
    // roughly 2x the cap.  Making it exact needs a conditional UPDATE with a
    // WHERE count < max and a retry, which is more machinery than a login
    // limiter earns -- the purpose is to make a sustained attack expensive, not
    // to make it exactly metered.
    //
    // The window is derived from the timestamp, so no scheduled reset job is
    // needed: a bucket whose window_start is behind the current window starts
    // again at 1.
    // ONE SIGNATURE, `*DbClient`, because that is what a by-value route closure
    // can produce (`&raw db`), and eight of the nine gates sit in by-value
    // closures.  See web/src/rate_limit.ch's header for the by-reference case,
    // which is handled at the call site with a local copy rather than by adding a
    // second signature here: two overloads would leave the broken one available
    // and the bug below would come straight back.
    public func rate_limit_ok_with(db : *DbClient, req : &http::Request, group : &string, res : *mut http::ResponseWriter, max : i64) : bool {
        var ip = client_ip(req)
        var bucket = rate_limit_bucket(group, &ip)
        var now = underlayer_core::current_timestamp()
        var window = rate_limit_window()
        var window_start = now - (now % window)

        var bucket_esc = underlayer_repository::sql_escape(&bucket)
        var select_sql = string("SELECT window_start, count FROM rate_limits WHERE bucket = '")
        select_sql.append_string(&bucket_esc)
        select_sql.append_view("' LIMIT 1")
        var existing = underlayer_db::query_sql(db, &raw select_sql)

        var count : i64 = 0
        if(existing.ok && existing.rows.size() > 0) {
            var row = existing.rows.get_ptr(0)
            if(row.vals.size() >= 2) {
                var prior_window = underlayer_repository::parse_int(row.vals.get_ptr(0).to_view()) as i64
                // Only carry the count forward inside the SAME window.  A bucket
                // from a previous window resets, which is what stops a reader
                // who waits out five minutes from being locked out forever.
                if(prior_window == window_start) {
                    count = underlayer_repository::parse_int(row.vals.get_ptr(1).to_view()) as i64
                }
            }
        }

        if(count >= max) {
            var retry = window - (now % window)
            var retry_s = underlayer_core::int_to_string(retry)
            // The header NAME goes to set_header_view; putting it in the value
            // as well produced "Retry-After: Retry-After: 229" on the wire.
            var hdr_v = retry_s.to_view()
            res.set_header_view(string_view("Retry-After"), &hdr_v)
            res.status = 429u
            var msg = string("{\"error\":\"too many attempts; try again in ")
            msg.append_string(&retry_s)
            msg.append_view(" seconds\"}")
            send_json_str(res, &raw msg)
            return false
        }

        var next = count + 1
        var ws_s = underlayer_core::int_to_string(window_start)
        var ct_s = underlayer_core::int_to_string(next)
        var upsert = string("INSERT INTO rate_limits (bucket, window_start, count) VALUES ('")
        upsert.append_string(&bucket_esc)
        upsert.append_view("', ")
        upsert.append_view(ws_s.to_view())
        upsert.append_view(", ")
        upsert.append_view(ct_s.to_view())
        upsert.append_view(") ON CONFLICT(bucket) DO UPDATE SET window_start = ")
        upsert.append_view(ws_s.to_view())
        upsert.append_view(", count = ")
        upsert.append_view(ct_s.to_view())
        underlayer_db::exec_sql(db, &raw upsert)
        return true
    }

    // One named gate per guarded endpoint, so app/main.ch passes a literal and
    // the closure captures nothing.  Closures in this codebase can only see
    // their own captures -- a plain local declared in main() is "outside of
    // lambda scope" -- so passing a string literal in is the only shape that
    // compiles from a route registration.  The four names are also the four
    // places to look when asking "what is throttled", which is the question a
    // reader of the routes will actually have.
    public func rate_limit_login(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("login")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_max())
    }

    public func rate_limit_register(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("register")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_max())
    }

    public func rate_limit_forgot(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("forgot")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_max())
    }

    public func rate_limit_reset(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("reset")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_max())
    }

    // ---- the learning-write surface ------------------------------------
    //
    // /api/exercises/submit accepted ten submissions in ten consecutive
    // requests with no objection, measured before this.  Each one inserts into
    // `exercise_attempts` and re-grades, so the endpoint is both a write
    // amplifier against the database and a way to manufacture a flattering
    // history: a learner (or anyone holding a token) could inflate their own
    // accuracy and manufacture weaknesses to dodge a review they did not do.
    //
    // 120 per 5 minutes is the ceiling argued above -- ten times what a
    // reviewer doing a course in one sitting produces.
    public func rate_limit_exercise_submit(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("exercise_submit")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_write_max())
    }

    // POST /api/feedback and POST /api/feedback/report-exercise.  Both are
    // unauthenticated-adjacent (they answer 401 without a session) but they
    // write into a table a human has to READ -- the corrections queue -- so an
    // unbounded writer fills it with noise and makes the queue unworkable.
    public func rate_limit_feedback(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("feedback")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_write_max())
    }

    public func rate_limit_report_exercise(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("report_exercise")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_write_max())
    }

    // POST /api/learners.  This one is NOT a learning write and does not get the
    // learning ceiling: it inserts into `learners`, which is the ACCOUNTS table,
    // and it does so with a hardcoded identity (name "learner", email
    // learner@underlayer.dev, no password) -- there is no request body it reads
    // at all.  It exists for tests/src/additional_api_test.ch and nothing else.
    //
    // So it is limited at the AUTH ceiling, not because it is authentication
    // but because it creates rows in an accounts table and that is the same
    // shape of abuse.  Unauthenticated and unbounded, it answered 200 forever
    // and every call attempted an INSERT with a UNIQUE-violating email.
    public func rate_limit_create_learner(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) : bool {
        var g = string("create_learner")
        return rate_limit_ok_with(db, req, &g, res, rate_limit_max())
    }

}
