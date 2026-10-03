// underlayer_tests — POST /api/learning/view must only record concepts that
// exist in the course it was told about.
//
// WHY THIS FILE EXISTS.  The endpoint upserted whatever `concept_id` it was
// handed, with no check against the course manifest. Because `concept_states` is
// where coverage, mastery, the health score and every module breakdown are
// counted from, any id at all became progress the learner never made.
//
// Measured on a learner who had read 5 ELF lessons (coverage 20%, 5 of 24):
//
//   POST {"course_id":"elf","concept_id":"this-concept-does-not-exist"}
//     -> {"ok":true,"recorded":true,"first_time":true,...}
//   GET  /api/progress?course_id=elf
//     -> concepts_started: 6, breadth: 25.0
//
// A concept that does not exist moved their coverage five points, and could
// have moved it again on the next call. Nothing rejected it, because there was
// nothing to reject it against.
//
// The fix validates against the manifest before writing. These three tests pin
// the three ways that can go, and the third is the one that matters most: a
// guard that rejects real lessons is worse than no guard, because it discards
// activity that actually happened.
using std::string
using std::string_view
using std::Result
using std::Option

// A real bearer token for `learner_id`.
//
// NO learners ROW IS INSERTED, and that is deliberate: make_session_token writes
// only to auth_sessions, and api_test.ch's authenticated review-start test works
// the same way. An earlier draft of this file also inserted a learners row and
// every one of its three tests failed with
//
//   [underlayer_db] SQL PREPARE FAILED rc=21 ... SELECT learner_id FROM auth_sessions
//
// which looked like an auth bug and was not. `db` here is the CLIENT that
// setup_test_db returned, and the route closure below captures the same handle
// by reference (`|&db|`); mixing `&raw db` at the call site with a by-value
// closure is the exact shape 2.2.46 documents -- the handler receives a
// DbClient whose sqlite_handle is not the live connection, and every statement
// prepared on it fails with SQLITE_MISUSE. The endpoint then saw no learner, took
// its anonymous no-op path, and answered {"recorded":false} for EVERY concept
// including real ones -- which is why "a nonexistent concept created a row"
// fired on a test whose only sin was a bad token.
//
// The fix is to pass the client the same way the closure is declared.
func view_token(db : *underlayer_db::DbClient) : string {
    var learner = string("view-test-learner")
    return test_helpers::make_session_token(db, &learner)
}

// The learner behind the token, so the test can count the rows it caused.
func view_learner_id() : string {
    return string("view-test-learner")
}

// A concept that is in no course at all must not create a state row.
@test
public func test_learning_view_rejects_a_concept_that_does_not_exist(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var token = view_token(&raw db)
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20170")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/learning/view", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_learning_view(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(20170u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var body = string("{\"course_id\":\"elf\",\"concept_id\":\"this-concept-does-not-exist\"}")
    var res = test_helpers::authed_post(&client, &string("http://127.0.0.1:20170/api/learning/view"), &token, &body.to_view(), "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable

    // The response must say it did not record, and why -- so a caller can tell
    // "I learned nothing" from "the server refused this".
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(rb) = body_opt else unreachable
    if(rb.find(string_view("\"recorded\":false")) == std::NPOS) {
        env.error("learning_view: expected recorded:false for a concept that does not exist")
    }
    if(rb.find(string_view("unknown_concept")) == std::NPOS) {
        env.error("learning_view: expected the reason to be named")
    }

    // The row is the assertion that matters. The response body can say anything;
    // what must not exist is the state row, because that row is what every
    // coverage and mastery figure on the platform is counted from.
    //
    // last_studied is the probe, NOT status. ConceptState::make() initialises
    // status to "not_started", so get_concept_state returns a non-empty status
    // for an ABSENT row -- asserting on status.size() would fail on correct
    // code, which is how this test first reported a phantom row.
    var learner = view_learner_id()
    var found = underlayer_repository::get_concept_state(&raw db, &learner, &string("this-concept-does-not-exist"), &string("elf"))
    if(found.last_studied != 0) {
        env.error("learning_view: a nonexistent concept created a concept_states row")
    }
    if(found.attempts != 0) {
        env.error("learning_view: a nonexistent concept recorded an attempt")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// A real concept from a real course must still be recorded. This is the test
// that stops the guard from being a regression: it passed before the fix and
// has to keep passing.
@test
public func test_learning_view_still_records_a_real_concept(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var token = view_token(&raw db)
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20171")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/learning/view", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_learning_view(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(20171u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var body = string("{\"course_id\":\"elf\",\"concept_id\":\"bytes\"}")
    var res = test_helpers::authed_post(&client, &string("http://127.0.0.1:20171/api/learning/view"), &token, &body.to_view(), "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(rb) = body_opt else unreachable
    if(rb.find(string_view("\"recorded\":true")) == std::NPOS) {
        env.error("learning_view: a real concept (elf/bytes) must still be recorded")
    }

    // last_studied is the probe here too, and for the same reason: status is
    // "not_started" on a default-constructed ConceptState, so status cannot
    // distinguish "row written and classified" from "no row at all".
    var learner = view_learner_id()
    var found = underlayer_repository::get_concept_state(&raw db, &learner, &string("bytes"), &string("elf"))
    if(found.last_studied == 0) {
        env.error("learning_view: elf/bytes is a real concept but no state row was written")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// The check is per COURSE, not global: a concept that belongs to another course
// is not a concept of this one. `elf-header` is a real id in the collection and
// `bytes` is a real id in elf -- asking for elf/entry-point (which lives in the
// elf-header MODULE) must work, while a concept that only exists in a different
// course must not.
//
// The pair matters because the previous test would also pass against a guard
// that rejected everything, and this one would fail against a guard that
// accepted everything. Together they pin the boundary.
@test
public func test_learning_view_checks_the_course_not_just_the_id(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var token = view_token(&raw db)
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20172")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/learning/view", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_learning_view(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(20172u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()

    // Listed only inside a module, not in the top-level concepts array. A guard
    // that read one source would have rejected this.
    var ok_body = string("{\"course_id\":\"elf\",\"concept_id\":\"entry-point\"}")
    var ok_res = test_helpers::authed_post(&client, &string("http://127.0.0.1:20172/api/learning/view"), &token, &ok_body.to_view(), "application/json")
    if(ok_res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(ok_resp) = ok_res else unreachable
    var ok_opt = ok_resp.body.read_to_string()
    if(ok_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ok_rb) = ok_opt else unreachable
    if(ok_rb.find(string_view("\"recorded\":true")) == std::NPOS) {
        env.error("learning_view: elf/entry-point is listed in a module and must be accepted")
    }

    // A concept belonging to a different course, sent with course_id=elf.
    var no_body = string("{\"course_id\":\"elf\",\"concept_id\":\"jvm-header\"}")
    var no_res = test_helpers::authed_post(&client, &string("http://127.0.0.1:20172/api/learning/view"), &token, &no_body.to_view(), "application/json")
    if(no_res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(no_resp) = no_res else unreachable
    var no_opt = no_resp.body.read_to_string()
    if(no_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(no_rb) = no_opt else unreachable
    if(no_rb.find(string_view("\"recorded\":false")) == std::NPOS) {
        env.error("learning_view: jvm-header is not an elf concept and must not be recorded against elf")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}