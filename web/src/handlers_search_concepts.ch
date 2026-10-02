// underlayer_web — GET /api/search/concepts
//
// Separate from `/api/search` on purpose.  `/api/search` is checklist item
// 7.1.6 and its contract is "match a course title"; changing its response
// shape would break whatever is already calling it, and this collection does
// not break shipped contracts to serve a new page.  The new endpoint is
// additive and is the one `/search` uses.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    public func handle_search_concepts(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_key = string("q")
        var q_v = req.query.get(&q_key.to_view())
        if(q_v.size() == 0) {
            var err_msg = string("missing query param: q")
            send_error(res, 400u, &err_msg)
            return
        }
        var query = sv_to_string(&raw q_v)
        var courses = underlayer_repository::list_courses(courses_dir)
        var hits = search_concepts(&courses, &query)
        var total = hits.size() as int
        var shown = total
        if(shown > SEARCH_RESULT_LIMIT) { shown = SEARCH_RESULT_LIMIT }

        var body = string("{\"query\":\"")
        var q_esc = underlayer_core::json_escape(&query.to_view())
        body.append_view(q_esc.to_view())
        body.append_view("\",\"total\":")
        var ts = underlayer_core::int_to_string(total as i64)
        body.append_string(&ts)
        body.append_view(",\"shown\":")
        var ss = underlayer_core::int_to_string(shown as i64)
        body.append_string(&ss)
        body.append_view(",\"searched\":")
        var searched : int = 0
        var ci : size_t = 0
        while(ci < courses.size()) {
            var c = courses.get_ptr(ci)
            searched = searched + c.concepts.size() as int
            ci = ci + 1
        }
        var scs = underlayer_core::int_to_string(searched as i64)
        body.append_string(&scs)
        body.append_view(",\"results\":[")

        var i : size_t = 0
        while(i < hits.size()) {
            var hit = hits.get_ptr(i)
            if(i >= shown as size_t) { break }
            if(i > 0) { body.append_view(",") }
            body.append_view("{\"course_id\":\"")
            var course_id = hit.course_id.copy()
            body.append_string(&course_id)
            body.append_view("\",\"course_title\":\"")
            var course_title = hit.course_title.copy()
            body.append_string(&course_title)
            body.append_view("\",\"concept_id\":\"")
            var concept_id = hit.concept_id.copy()
            body.append_string(&concept_id)
            body.append_view("\",\"title\":\"")
            var title = hit.concept_title.copy()
            body.append_string(&title)
            body.append_view("\",\"module\":\"")
            var module = hit.module_title.copy()
            body.append_string(&module)
            body.append_view("\",\"snippet\":\"")
            var snip = hit.concept_description.copy()
            body.append_string(&snip)
            body.append_view("\",\"matched_field\":\"")
            var field = hit.matched_field.copy()
            body.append_string(&field)
            body.append_view("\",\"score\":")
            var sc = underlayer_core::int_to_string(hit.score as i64)
            body.append_string(&sc)
            body.append_view(",\"url\":\"/courses/")
            var course_id2 = hit.course_id.copy()
            body.append_string(&course_id2)
            body.append_view("/lessons/")
            var concept_id2 = hit.concept_id.copy()
            body.append_string(&concept_id2)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

}