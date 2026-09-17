// Review item seeding tests (P1 2.4.21).
// Verifies that review queues are no longer permanently empty:
// seeding creates items for engaged concepts and /api/review/due returns them.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_review_seeding_creates_items(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()

    // Simulate a learner having engaged with the "bytes" concept
    var learner_id = string("seed-test-learner")
    var course_id = string("elf")
    var concept_id = string("bytes")
    var state = underlayer_models::ConceptState::make()
    state.learner_id = learner_id.copy()
    state.concept_id = concept_id.copy()
    state.course_id = course_id.copy()
    state.attempts = 1
    underlayer_repository::upsert_concept_state(&raw db, &raw state)

    // Seed and verify creation
    var created = underlayer_repository::seed_review_items(&raw db, &learner_id, &course_id)
    if(created == 0) { env.error("expected at least 1 review item to be created"); underlayer_db::close(&raw db); return }

    // Idempotent: re-seeding must not create more
    var created2 = underlayer_repository::seed_review_items(&raw db, &learner_id, &course_id)
    if(created2 != 0) { env.error("re-seeding should create 0 items (idempotency)"); underlayer_db::close(&raw db); return }

    // Item must now be due (next_review = now at creation)
    var due = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 10)
    if(due.size() == 0) { env.error("expected due items after seeding"); underlayer_db::close(&raw db); return }

    // Only engaged concepts get items — a learner with no state gets nothing
    var other_learner = string("seed-test-inactive")
    var created3 = underlayer_repository::seed_review_items(&raw db, &other_learner, &course_id)
    if(created3 != 0) { env.error("inactive learner should get 0 items"); underlayer_db::close(&raw db); return }

    underlayer_db::close(&raw db)
}

@test
public func test_review_due_seeds_automatically(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")

    // Give the "demo" learner (unauthenticated fallback) an engaged concept
    var learner_id = string("demo")
    var course_id = string("elf")
    var concept_id = string("bytes")
    var state = underlayer_models::ConceptState::make()
    state.learner_id = learner_id.copy()
    state.concept_id = concept_id.copy()
    state.course_id = course_id.copy()
    state.attempts = 2
    underlayer_repository::upsert_concept_state(&raw db, &raw state)

    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19979")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/review/due", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_due(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19979u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19979/api/review/due?course_id=elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    // The response must now contain a seeded item for the engaged concept
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("demo_elf_bytes")) == std::NPOS) { env.error("expected seeded item demo_elf_bytes in due response") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
