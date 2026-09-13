// underlayer_web — Search, filter, and history handlers (7.1.6-7.1.9).
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // 7.1.6: Search functionality (full-text search)
    public func handle_search(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_query = string("q")
        var q_v = req.query.get(&q_query.to_view())
        if(q_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: q"))
            return
        }
        var query = sv_to_string(&raw q_v)
        var results = vector<string>()

        // Search through available courses
        var courses = underlayer_repository::list_courses(courses_dir)
        var i : size_t = 0
        while(i < courses.size()) {
            var course = courses.get_ptr(i)
            // Simple substring match on course title
            var title_copy = course.title.copy()
            var query_copy = query.copy()
            // Check if title contains query (manual implementation)
            var found = false
            if(title_copy.size() >= query_copy.size()) {
                var ti : size_t = 0
                while(ti <= title_copy.size() - query_copy.size()) {
                    var match = true
                    var qi : size_t = 0
                    while(qi < query_copy.size()) {
                        if(title_copy.get(ti + qi) != query_copy.get(qi)) { match = false }
                        qi = qi + 1
                    }
                    if(match) { found = true }
                    ti = ti + 1
                }
            }
            if(found) {
                results.push(course.id.copy())
            }
            i = i + 1
        }

        var body = string("{\"query\":\"")
        body.append_string(&query)
        body.append_view("\",\"results\":[")
        var j : size_t = 0
        while(j < results.size()) {
            if(j > 0) { body.append_view(",") }
            body.append_view("{\"id\":\"")
            var r = results.get_ptr(j)
            var r_copy = r.copy()
            body.append_string(&r_copy)
            body.append_view("\"}")
            j = j + 1
        }
        body.append_view("],\"total\":")
        var total_out = underlayer_core::int_to_string(results.size() as i64)
        body.append_string(&total_out)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // 7.1.7: Filter/sort courses (by topic, difficulty, rating)
    public func handle_filter_courses(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var courses = underlayer_repository::list_courses(courses_dir)
        var body = string("{\"courses\":[")
        var i : size_t = 0
        while(i < courses.size()) {
            if(i > 0) { body.append_view(",") }
            var c = courses.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&c.id)
            body.append_view("\",\"title\":\"")
            body.append_string(&c.title)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_out = underlayer_core::int_to_string(courses.size() as i64)
        body.append_string(&total_out)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // 7.1.9: Recent history (last 10 visited concepts)
    public func handle_recent_history(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 10)
        var recent = vector<string>()

        var i : size_t = 0
        while(i < sessions.size()) {
            var s = sessions.get_ptr(i)
            // Get session items to find concepts
            var items = underlayer_repository::get_session_items(&raw db, &s.id)
            var j : size_t = 0
            while(j < items.size()) {
                var item = items.get_ptr(j)
                // Add concept if not already in recent list
                var found = false
                var k : size_t = 0
                while(k < recent.size()) {
                    var existing = recent.get_ptr(k)
                    var existing_copy = existing.copy()
                    var item_copy = item.concept_id.copy()
                    if(existing_copy.equals(&item_copy)) { found = true }
                    k = k + 1
                }
                if(!found) {
                    recent.push(item.concept_id.copy())
                }
                j = j + 1
            }
            i = i + 1
        }

        var body = string("{\"recent\":[")
        var limit = recent.size()
        if(limit > 10) { limit = 10 }
        var i2 : size_t = 0
        while(i2 < limit) {
            if(i2 > 0) { body.append_view(",") }
            body.append_view("{\"concept_id\":\"")
            var r = recent.get_ptr(i2)
            var r_copy = r.copy()
            body.append_string(&r_copy)
            body.append_view("\"}")
            i2 = i2 + 1
        }
        body.append_view("],\"total\":")
        var total_out = underlayer_core::int_to_string(limit as i64)
        body.append_string(&total_out)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
