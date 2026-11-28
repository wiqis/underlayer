// underlayer_web — G2 "Today": compose a day from FSRS due items + next step.
//
// POST /api/study-plans used to require the learner to hand-enter course_id,
// date, hour, duration and focus_concepts, and GET /api/goals had no readable
// daily-minute value in production. These routes compose the same day for the
// learner through the EXISTING plan repository functions, then record exactly
// one activity day when the learner marks the plan done.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::ReviewItem
using underlayer_models::Concept

public namespace underlayer_web {

    // First concept with no recorded attempt, starting at the learner's chosen
    // route when one exists. Every id comes from the manifest.
    private func next_lesson_concept(db : *DbClient, learner_id : &string, course : &underlayer_models::Course) : string {
        var states = underlayer_repository::get_all_concept_states(db, learner_id, &course.id)
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var concept = course.concepts.at_ref(ci)
            var attempted = false
            var si : size_t = 0
            while(si < states.size()) {
                if(states.at_ref(si).concept_id.equals(&concept.id)) {
                    if(states.at_ref(si).attempts > 0) { attempted = true }
                }
                si = si + 1
            }
            if(!attempted) { return concept.id.copy() }
            ci = ci + 1
        }
        if(course.concepts.size() > 0) { return course.concepts.at_ref(course.concepts.size() - 1).id.copy() }
        return string("bytes")
    }

    // POST /api/today/plan
    public func handle_today_plan(db : *DbClient, req : &http::Request) : http::Response {
        var body = read_body(req)
        var learner_id = resolve_learner(db, req, &body)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var course_id = string("elf")
        var goal = daily_goal_minutes(db, &learner_id)
        if(body.size() > 0) {
            var pr = json::parse(body.to_view())
            if(pr is std::Result.Ok) {
                var Ok(pj) = pr else unsafe { unreachable }
                var c = json_get_str(&pj, "course_id")
                if(c.size() > 0) { course_id = c }
                var m = json_get_int(&pj, "daily_minutes") as i64
                if(m >= 5 && m <= 180) { goal = m }
            }
        }
        var courses_dir = request_courses_dir()
        var course = underlayer_repository::load_course(&courses_dir, &course_id)
        if(course.id.size() == 0) {
            var nf = string("course not found")
            return send_error(404u, &nf)
        }
        var due = underlayer_repository::get_due_review_items(db, &learner_id, &course_id, 50)
        var per_review : i64 = 3
        // Five minutes of headroom per review keeps the day finishable: a
        // 15-minute goal with six due items becomes three reviews (9 min) and
        // one 6-minute next lesson, not five reviews and a rushed last step.
        var review_count : i64 = goal / 5
        if(review_count > 6) { review_count = 6 }
        if(review_count > due.size() as i64) { review_count = due.size() as i64 }
        var lesson_minutes : i64 = goal - review_count * per_review
        if(lesson_minutes < 1) { lesson_minutes = 1 }
        if(lesson_minutes > 20) { lesson_minutes = 20 }
        var next = next_lesson_concept(db, &learner_id, &course)

        var focus = string("[")
        var ri : i64 = 0
        while(ri < review_count) {
            if(ri > 0) { focus.append_view(",") }
            focus.append_view("{\"kind\":\"review\",\"concept_id\":\"")
            var rv = due.at_ref(ri as size_t).concept_id.to_view()
            var e = underlayer_core::json_escape(&rv)
            focus.append_string(&e)
            focus.append_view("\"}")
            ri = ri + 1
        }
        if(review_count > 0) { focus.append_view(",") }
        focus.append_view("{\"kind\":\"lesson\",\"concept_id\":\"")
        var le = underlayer_core::json_escape(&next.to_view())
        focus.append_string(&le)
        focus.append_view("\",\"minutes\":")
        var lm = underlayer_core::int_to_string(lesson_minutes)
        focus.append_view(lm.to_view())
        focus.append_view("}]")

        var now = underlayer_core::current_timestamp()
        var date = underlayer_core::date_string(now)
        var plan_id = underlayer_repository::create_plan(db, &learner_id, &course_id, &date, 0, goal, &focus)

        var out = string("{\"plan_id\":\"")
        var pe = underlayer_core::json_escape(&plan_id.to_view())
        out.append_string(&pe)
        out.append_view("\",\"course_id\":\"")
        var ce = underlayer_core::json_escape(&course_id.to_view())
        out.append_string(&ce)
        out.append_view("\",\"goal_minutes\":")
        var gs = underlayer_core::int_to_string(goal)
        out.append_string(&gs)
        out.append_view(",\"total_minutes\":")
        var total = underlayer_core::int_to_string(review_count * per_review + lesson_minutes)
        out.append_string(&total)
        out.append_view(",\"due_available\":")
        var ds = underlayer_core::int_to_string(due.size() as i64)
        out.append_string(&ds)
        out.append_view(",\"items\":")
        out.append_view(focus.to_view())
        out.append_view("}")
        return send_json_str(&out)
    }

    // POST /api/today/complete — one activity day, no streak UI of any kind.
    public func handle_today_complete(db : *DbClient, req : &http::Request) : http::Response {
        var body = read_body(req)
        var learner_id = resolve_learner(db, req, &body)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var plan_id = string()
        if(body.size() > 0) {
            var pr = json::parse(body.to_view())
            if(pr is std::Result.Ok) {
                var Ok(pj) = pr else unsafe { unreachable }
                plan_id = json_get_str(&pj, "plan_id")
            }
        }
        if(plan_id.size() == 0) {
            var err = string("plan_id is required")
            return send_error(400u, &err)
        }
        var plan = underlayer_repository::get_plan(db, &plan_id)
        if(plan.id.size() == 0) {
            var nf = string("plan not found")
            return send_error(404u, &nf)
        }
        if(!plan.learner_id.equals(&learner_id)) {
            var f = string("forbidden")
            return send_error(403u, &f)
        }
        underlayer_repository::update_plan_status(db, &plan_id, string("completed"))
        underlayer_repository::record_activity(db, &learner_id)
        var now = underlayer_core::current_timestamp()
        var out = string("{\"ok\":true,\"activity_date\":\"")
        var activity_date = underlayer_core::date_string(now)
        var d = underlayer_core::json_escape(&activity_date.to_view())
        out.append_string(&d)
        out.append_view("\"}")
        return send_json_str(&out)
    }

    // GET /api/today — a missed day says "Welcome back" and nothing else.
    public func handle_today_status(db : *DbClient, req : &http::Request) : http::Response {
        var guest_key = string("guest_id")
        var guest_v = sv_or_empty(req.query.get(std::str.make_view(guest_key.to_view())))
        var guest_body = string()
        if(guest_v.size() > 0) {
            guest_body = string("{\"guest_id\":\"")
            var guest_s = sv_to_string(&guest_v)
            var ge = underlayer_core::json_escape(&guest_s.to_view())
            guest_body.append_string(&ge)
            guest_body.append_view("\"}")
        }
        var learner_id = resolve_learner(db, req, &guest_body)
        if(learner_id.size() == 0) {
            var unauth = string("{\"authenticated\":false}")
            return send_json_str(&unauth)
        }
        var now = underlayer_core::current_timestamp()
        var today = underlayer_core::date_string(now)
        var today_view = today.to_view()
        var yesterday = underlayer_core::date_string_subtract_days(&today_view, 1)
        var streak = underlayer_repository::get_streak(db, &learner_id)
        var welcome = streak.last_active_date.size() > 0 && !streak.last_active_date.equals(&today) && !streak.last_active_date.equals(&yesterday)
        var out = string("{\"authenticated\":true,\"welcome_back\":")
        if(welcome) { out.append_view("true") } else { out.append_view("false") }
        out.append_view(",\"message\":\"")
        if(welcome) { out.append_view("Welcome back") } else if(streak.last_active_date.size() == 0) { out.append_view("Ready when you are") } else { out.append_view("Today's plan is ready") }
        out.append_view("\",\"goal_minutes\":")
        var g = underlayer_core::int_to_string(daily_goal_minutes(db, &learner_id))
        out.append_string(&g)
        out.append_view(",\"date\":\"")
        var today_v = today.to_view()
        var de = underlayer_core::json_escape(&today_v)
        out.append_string(&de)
        out.append_view("\"}")
        return send_json_str(&out)
    }

}
