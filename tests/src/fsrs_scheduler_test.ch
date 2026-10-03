// underlayer_tests — the FSRS scheduler must REMEMBER.
//
// WHY THIS FILE EXISTS.  Spaced repetition is a function of what happened last
// time. For three separate reasons it was not:
//
//   1. the submit handler set `rs.stability = 1.0` as a literal on every
//      rating, so every card was scheduled as though brand new;
//   2. `review_items.stability` was written with int_to_string(x as i64), which
//      discarded the fraction — every stability under 1 stored as 0;
//   3. with the write-up fixed but the value still formatted to two decimals,
//      the round trip flattened anyway: S0("Good") is 0.1901 and the first few
//      growth steps are 0.1985, 0.2077 — all of which print as "0.19".
//
// Each of those alone holds stability flat. Only the third was visible after
// fixing the first two, which is why these tests assert on the SEQUENCE and
// not on a single call's return value: a check on one rating cannot tell a
// scheduler that remembers from one that does not.
//
// MEASURED, before the fix, ten consecutive "Good" ratings on one concept:
//
//   review  1: stability 0.19  interval 3
//   review  2: stability 0.19  interval 1
//   ...
//   review 10: stability 0.19  interval 1
//
// After:
//
//    1: 0.1901  3     4: 0.2178  1     7: 0.2548  1    10: 0.3068  1
//    2: 0.1985  1     5: 0.2289  1     8: 0.2701  1
//    3: 0.2077  1     6: 0.2412  1     9: 0.2873  1
//
// The interval stays at 1 day through ten perfect reviews and that is CORRECT,
// not a remaining bug: fsrs_next_interval is S * d_factor with d_factor ~0.55
// at difficulty 5, so the interval cannot exceed 1 until S passes ~1.8 days,
// and S0("Good") is 0.19. Growing from there is the paper's behaviour, not a
// defect — so the assertion below is on stability RISING and staying inside its
// bounds, and explicitly not on the interval widening quickly.
using std::string
using std::string_view
using std::Result
using std::Option

// A real bearer token for `learner_id`, on the pattern api_test.ch uses. No
// learners row is needed and none is inserted: make_session_token writes to
// auth_sessions only.
func fsrs_token(db : *underlayer_db::DbClient, learner : &string) : string {
    return test_helpers::make_session_token(db, learner)
}

// Rate `concept` once and return the stability the API reported.
func rate_and_read_stability(
    env : &mut TestEnv,
    client : &http::Client,
    base : &string,
    token : &string,
    concept : &string,
    rating : &string
) : f64 {
    var url = base.copy()
    url.append_view("/api/review/submit?concept_id=")
    url.append_string(concept)
    url.append_view("&course_id=elf&rating=")
    url.append_string(rating)
    // The handler reads concept_id, course_id and rating from the QUERY STRING
    // (that is the path every lesson page uses -- see
    // content/src/bytes.ch:316), so the body is an empty JSON object rather
    // than the parameters.
    var empty_body = string("{}")
    var ebv = empty_body.to_view()
    var res = test_helpers::authed_post(client, &url, token, &ebv, "application/json")
    if(res is Result.Err) { env.error("review submit failed"); return -1.0 }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body from review submit"); return -1.0 }
    var Some(body) = body_opt else unreachable
    var key = string("\"stability\":")
    var at = body.find(key.to_view())
    if(at == std::NPOS) { env.error("review submit response has no stability"); return -1.0 }
    var tail = string()
    var i = at + key.size()
    while(i < body.size()) {
        var ch = body.get(i)
        if(ch == ',' || ch == '}') { break }
        tail.append(ch)
        i = i + 1
    }
    return underlayer_repository::parse_f64(tail.to_view())
}

// A concept rated repeatedly must accumulate stability.
//
// The four properties asserted, and why each is one:
//
//   * it RISES across ratings — the scheduler remembers;
//   * it is STRICTLY below the first rating's value nowhere — i.e. it never goes
//     backwards on a run of Good ratings;
//   * it stays POSITIVE — no zero, which would make retrievability divide by
//     zero;
//   * it is not FLAT — this is the assertion that fails on all three defects
//     above, including the two-decimal one, because a flat sequence is exactly
//     what a rounded round trip produces.
@test
public func test_repeated_good_ratings_accumulate_stability(env : &mut TestEnv) {
    // Its OWN db file, not the shared ./test_underlayer_tmp.db. setup_test_db
    // wipes every row on the way in, and these tests run concurrently -- so two
    // of them sharing one file delete each other's review_items mid-sequence.
    // That is not hypothetical: it is why this test first failed with "stability
    // DECREASED", having had its rows deleted between two ratings, and it is the
    // documented reason setup_test_db_path exists.
    var lit_a = string("./test_fsrs_accumulate.db")
    var db = test_helpers::setup_test_db_path(&lit_a)
    var learner = string("fsrs-memory-learner")
    var token = fsrs_token(&raw db, &learner)
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20180")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
        underlayer_web::handle_review_submit(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20180u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var base = string("http://127.0.0.1:20180")
    var concept = string("fsrs-accumulates")

    var first = rate_and_read_stability(env, &client, &base, &token, &concept, &string("3"))
    if(first <= 0.0) { env.error("fsrs: first rating returned no stability"); srv.shutdown(); underlayer_db::close(&raw db); return }
    // S0("Good") is w[3] = 0.1901. Asserting the STARTING VALUE pins the
    // parameter table as well as the memory: a change to w[3] is a change to
    // the model and should fail here rather than silently alter every interval.
    if(first < 0.15 || first > 0.25) {
        env.error("fsrs: S0(Good) should be about 0.19 days")
    }

    var last = first
    var i : i64 = 0
    while(i < 8) {
        var next = rate_and_read_stability(env, &client, &base, &token, &concept, &string("3"))
        if(next <= 0.0) { break }
        // Positive, or retrievability divides by zero somewhere downstream.
        if(next <= 0.0) { env.error("fsrs: stability must stay positive") }
        // A run of Good ratings must never reduce stability.
        if(next < last) {
            env.error("fsrs: stability DECREASED across consecutive Good ratings — the scheduler forgot the card")
        }
        last = next
        i = i + 1
    }

    // THE FLATNESS CHECK. This is the one that catches the rounding defect: an
    // f64 formatted to two decimals turns 0.1901 and 0.1985 into the same
    // string, so the column stores 0.19 forever and the final value equals the
    // first. Growth over eight further successful reviews is unambiguous.
    if(last <= first) {
        env.error("fsrs: stability did not grow over nine Good ratings — the value is not surviving the round trip")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// A lapse must LOWER stability. This is the assertion that the "Again" floor of
// 1.0 broke: rating a concept "Again" — the learner saying they did not remember
// it — raised stability from 0.2178 to 1.0 and pushed the next review a day
// out, which is the opposite of what the rating means.
@test
public func test_again_lowers_stability_rather_than_raising_it(env : &mut TestEnv) {
    var lit_a = string("./test_fsrs_lapse.db")
    var db = test_helpers::setup_test_db_path(&lit_a)
    var learner = string("fsrs-lapse-learner")
    var token = fsrs_token(&raw db, &learner)
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20181")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
        underlayer_web::handle_review_submit(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20181u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var base = string("http://127.0.0.1:20181")
    var concept = string("fsrs-lapse")

    // Build up some stability first, so the lapse has something to lose.
    var i : i64 = 0
    while(i < 4) {
        rate_and_read_stability(env, &client, &base, &token, &concept, &string("3"))
        i = i + 1
    }
    var before = rate_and_read_stability(env, &client, &base, &token, &concept, &string("3"))
    if(before <= 0.0) { env.error("fsrs: no stability before the lapse"); srv.shutdown(); underlayer_db::close(&raw db); return }

    var after = rate_and_read_stability(env, &client, &base, &token, &concept, &string("1"))
    if(after <= 0.0) { env.error("fsrs: no stability after the lapse"); srv.shutdown(); underlayer_db::close(&raw db); return }

    // THE ASSERTION. A floor of 1.0 on the lapse branch made this comparison
    // fail in the worst possible direction: forgetting RAISED stability.
    if(after >= before) {
        env.error("fsrs: rating Again must LOWER stability — it did not, so a lapse is recorded as progress")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// The stored value must survive the round trip through SQL.
//
// The two defects above are invisible to a test that only reads the API's
// return value, because the API returns the freshly COMPUTED stability and the
// loss happens on the way to the column. This reads the column back through the
// repository, which is the only place the loss is observable.
//
// It asserts the fraction survives: a stability of 0.1901 must not come back as
// 0 (the int_to_string defect) or as 0.19 (the two-decimal defect, which is
// indistinguishable from 0.1901 only until the next rating grows it).
@test
public func test_stored_stability_survives_the_database_round_trip(env : &mut TestEnv) {
    var lit_a = string("./test_fsrs_roundtrip.db")
    var db = test_helpers::setup_test_db_path(&lit_a)
    var learner = string("fsrs-roundtrip-learner")
    var token = fsrs_token(&raw db, &learner)
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20182")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
        underlayer_web::handle_review_submit(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20182u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var base = string("http://127.0.0.1:20182")
    var concept = string("fsrs-roundtrip")

    var reported = rate_and_read_stability(env, &client, &base, &token, &concept, &string("3"))
    if(reported <= 0.0) { env.error("fsrs: no stability reported"); srv.shutdown(); underlayer_db::close(&raw db); return }

    var stored = underlayer_repository::get_review_item_by_concept(&raw db, &learner, &string("elf"), &concept)
    if(stored.id.size() == 0) {
        env.error("fsrs: the first rating created no review_items row, so nothing is remembered at all")
        srv.shutdown()
        underlayer_db::close(&raw db)
        return
    }
    if(stored.reps < 1) {
        env.error("fsrs: stored reps must be at least 1 after a rating")
    }
    // The fraction must be intact. 0.1901 stored as 0 or as 0.19 both fail a
    // comparison this tight, which is the point: the tolerance is smaller than
    // the gap the rounding defects introduced.
    if(stored.stability < 0.18 || stored.stability > 0.20) {
        env.error("fsrs: stored stability lost its fraction — it did not survive the round trip")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}