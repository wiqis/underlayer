// Health endpoint tests
using std::string
using std::string_view
using std::vector
using std::Result
using std::Option
using underlayer_models::ConceptState

// 1.5.14 regression: reading a lesson must count as coverage.
//
// compute_breadth_score used to require `attempts > 0` on the concept's state
// row. Answering an exercise increments attempts; opening a lesson does not --
// record_concept_read (handlers_learning.ch) sets last_studied and leaves
// attempts alone. So a learner who had read five lessons and answered nothing
// was told they had covered 0% of the course.
//
// This is a unit test on the function because the bug is in the function: it
// fires for /health, for /dashboard and for /api/progress equally, and a test
// against one page would have passed while the other two stayed wrong. It also
// asserts the empty-status case, because a row with status "" has not been
// classified as started and must not be counted as covered.
@test
public func test_breadth_score_counts_read_lessons_not_only_answered_ones(env : &mut TestEnv) {
    var states = vector<ConceptState>()

    // A lesson that was opened and read: status set, attempts still 0. This is
    // the exact shape record_concept_read leaves behind.
    var read_only = ConceptState::make()
    read_only.concept_id = string("bytes")
    read_only.status = string("learning")
    read_only.attempts = 0
    states.push_back(read_only)

    var also_read_only = ConceptState::make()
    also_read_only.concept_id = string("elf-header")
    also_read_only.status = string("learning")
    also_read_only.attempts = 0
    states.push_back(also_read_only)

    // One that was actually answered.
    var answered = ConceptState::make()
    answered.concept_id = string("sections")
    answered.status = string("reviewing")
    answered.attempts = 3
    states.push_back(answered)

    // 3 of 10 concepts covered == 30%. Before the fix this returned 10%, because
    // only `answered` had attempts > 0.
    var breadth = underlayer_learning::compute_breadth_score(&raw states, 10)
    var breadth_int = breadth as i64
    if(breadth_int != 30) { env.error("breadth: expected 30 for 3 read concepts of 10, got a different number") }

    // A row with no status has not been classified as started, so it must not
    // inflate coverage.
    var unclassified = ConceptState::make()
    unclassified.concept_id = string("ghost")
    unclassified.status = string("")
    var read_again = ConceptState::make()
    read_again.concept_id = string("bytes")
    read_again.status = string("learning")
    read_again.attempts = 0
    var states2 = vector<ConceptState>()
    // A fresh one, not `read_only`: push_back moves the value and the original
    // cannot be reused afterwards.
    states2.push_back(read_again)
    states2.push_back(unclassified)
    var breadth2 = underlayer_learning::compute_breadth_score(&raw states2, 10)
    var breadth2_int = breadth2 as i64
    if(breadth2_int != 10) { env.error("breadth: an unclassified row must not count as covered") }

    // No states at all is 0, not a division by zero.
    var empty = vector<ConceptState>()
    var breadth3 = underlayer_learning::compute_breadth_score(&raw empty, 10)
    if(breadth3 != 0.0) { env.error("breadth: expected 0 for a learner with no states") }
}

// 2.2.122 regression: a retention projection with nothing measured behind it
// must say so.
//
// compute_retention_projection averages over concepts with `attempts > 0`,
// because stability comes from `streak` and only answering exercises moves it.
// That gating is correct. What was wrong was that the result was reported as
// three bare numbers: for a learner who had read five lessons and answered
// none, the loop skipped every row and the response was
//
//   {"days_30":0.0,"days_60":0.0,"days_90":0.0}
//
// which the /health page rendered as "0.0% in 30 days" under the heading "What
// you will remember" -- a confident prediction that a learner who had read five
// lessons would retain nothing, produced by arithmetic over no data. `measured`
// is what tells the two cases apart.
//
// The second half of the test is the part that keeps it honest: `measured` must
// count concepts that have an ATTEMPT, not concepts that have a row. A learner
// who read is not a learner who has been measured, and counting rows would
// reproduce the original bug with an extra field attached.
@test
public func test_retention_projection_reports_how_much_it_measured(env : &mut TestEnv) {
    var states = vector<ConceptState>()

    // Read but never answered: a row exists, attempts is 0. This is the shape
    // that produced "0.0% in 30 days".
    var read_only = ConceptState::make()
    read_only.concept_id = string("bytes")
    read_only.status = string("learning")
    read_only.attempts = 0
    read_only.streak = 0
    states.push_back(read_only)

    var also_read = ConceptState::make()
    also_read.concept_id = string("sections")
    also_read.status = string("learning")
    also_read.attempts = 0
    states.push_back(also_read)

    // Nothing answered, so nothing was measured and all three figures are 0.
    var empty_proj = underlayer_learning::compute_retention_projection(&raw states)
    if(empty_proj.measured != 0) {
        env.error("projection: measured must be 0 when no concept has an attempt, even though rows exist")
    }
    if(empty_proj.days_30 != 0.0) { env.error("projection: days_30 should be 0 when nothing is measured") }

    // One answered concept: measured becomes 1 and the figures become real.
    var answered = vector<ConceptState>()
    var ok_state = ConceptState::make()
    ok_state.concept_id = string("bytes")
    ok_state.status = string("learning")
    ok_state.attempts = 1
    ok_state.correct = 1
    ok_state.streak = 1
    answered.push_back(ok_state)

    var real_proj = underlayer_learning::compute_retention_projection(&raw answered)
    if(real_proj.measured != 1) {
        env.error("projection: measured must be 1 for one answered concept")
    }
    if(real_proj.days_30 <= 0.0) {
        env.error("projection: days_30 must be a real figure once something is measured")
    }
    // The decay must be monotone: remembering less further out is the whole
    // claim of a forgetting curve, so a projection where day 90 exceeds day 30
    // is a broken model rather than an unusual learner.
    if(real_proj.days_90 > real_proj.days_30) {
        env.error("projection: retention must fall with time; day 90 exceeded day 30")
    }
}

@test
public func test_health_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19876")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })
    srv.serve_async(19876u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19876/api/health")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_health_returns_json_content_type(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19877")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })
    srv.serve_async(19877u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19877/api/health")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_health_body_contains_status(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19878")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })
    srv.serve_async(19878u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19878/api/health")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    var has_ok = body.find(string_view("ok")) != std::NPOS
    var has_status = body.find(string_view("status")) != std::NPOS
    if(!has_ok && !has_status) { env.error("health body missing expected content") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
