// underlayer_web — Learning goal handlers (6.1.5).
//
// WHY THIS FILE EXISTS.  6.1.5 shipped POST /api/goals and DELETE /api/goals
// and no GET.  Measured: `GET /api/goals` answered 404 while POST answered 200,
// and tools/integration_holes.py listed POST and DELETE as routes no page could
// reach.  So a learner could set a target date and never read it back, which is
// the one thing a goal is for, and the write half of the feature was invisible
// as well as the read half.
//
// The three handlers moved here from handlers_progress.ch, which was 373 lines
// against a 250-line ceiling, and they now share one `goal_course_id` helper
// instead of each hardcoding "elf".  That hardcoding was not harmless: the
// platform ships 34 courses, and a goal was only ever readable or writable for
// ELF whatever course the learner was actually in.
using std::string
using std::string_view
using underlayer_db::DbClient
using underlayer_repository::parse_i64

public namespace underlayer_web {

    // Which course a goal request is about.
    //
    // `course_id` is honoured when present and falls back to "elf" when absent,
    // which is exactly the behaviour the hardcoded version had -- so an existing
    // caller that sends no course_id still lands on ELF, and the read side can
    // now see every course instead of only the one that was assumed.
    private func goal_course_id(req : &http::Request) : string {
        var key = string("course_id")
        var val = req.query.get(&key.to_view())
        if(val.size() == 0) { return string("elf") }
        var out = string()
        var i : size_t = 0
        while(i < val.size()) { out.append(val.get(i)); i = i + 1 }
        if(out.size() == 0) { return string("elf") }
        return out
    }

    // GET /api/goals -- every goal this learner has set, newest first.
    //
    // Returns an array rather than a single object because the old design could
    // only ever hold one goal per learner in practice (one hardcoded course),
    // and a read API that silently returns only the first of several rows is how
    // this bug started.
    public func handle_get_goals(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var goals = underlayer_repository::list_learning_goals(&raw db, &learner_id)
        var now = underlayer_core::current_timestamp()

        var body = string("{\"goals\":[")
        var i : size_t = 0
        while(i < goals.size()) {
            if(i > 0) { body.append_view(",") }
            var g = goals.get_ptr(i)
            body.append_view("{\"id\":\"")
            var gid = g.id.copy()
            body.append_string(&gid)
            body.append_view("\",\"course_id\":\"")
            var cid = g.course_id.copy()
            body.append_string(&cid)
            body.append_view("\",\"target_date\":")
            var td = underlayer_core::int_to_string(g.target_date)
            body.append_string(&td)
            body.append_view(",\"created_at\":")
            var ca = underlayer_core::int_to_string(g.created_at)
            body.append_string(&ca)
            // Days remaining is computed here rather than in the page so that a
            // client cannot disagree with the server about how far away a goal
            // is. It is clamped at 0: a passed target date is 0 days remaining,
            // not a negative number of days left.
            var days_left = (g.target_date - now) / 86400
            if(days_left < 0) { days_left = 0 }
            body.append_view(",\"days_remaining\":")
            var dl = underlayer_core::int_to_string(days_left)
            body.append_string(&dl)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("],\"count\":")
        var cnt = underlayer_core::int_to_string(goals.size() as i64)
        body.append_string(&cnt)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // 6.1.5: Set learning goal
    public func handle_set_goal(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_td = string("target_date")
        var td_v = req.query.get(&q_td.to_view())
        if(td_v.size() == 0) {
            var err_msg = string("missing query param: target_date")
            send_error(res, 400u, &err_msg)
            return
        }
        var target_date = parse_i64(td_v) as i64
        var learner_id = auth_get_learner_id(&raw db, &*req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = goal_course_id(&*req)
        underlayer_repository::set_learning_goal(&raw db, &learner_id, &course_id, target_date)
        var ok_body = string("{\"ok\":true,\"course_id\":\"")
        var cid = course_id.copy()
        ok_body.append_string(&cid)
        ok_body.append_view("\"}")
        send_json_str(res, &raw ok_body)
    }

    // 6.1.5: Delete learning goal
    public func handle_delete_goal(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = goal_course_id(req)
        underlayer_repository::delete_learning_goal(&raw db, &learner_id, &course_id)
        var ok_body = string("{\"ok\":true,\"course_id\":\"")
        var cid = course_id.copy()
        ok_body.append_string(&cid)
        ok_body.append_view("\"}")
        send_json_str(res, &raw ok_body)
    }

}