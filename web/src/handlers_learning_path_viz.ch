// underlayer_web — Learning Path Visualization handlers.
// GET /courses/:courseId/path — HTML learning path page
// GET /api/courses/:courseId/path — JSON data for the learning path
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /courses/:courseId/path — HTML learning path page
    public func handle_learning_path_page(db : *DbClient, courses_dir : &string, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            // Not logged in — redirect to login
            res.status = 302u
            res.set_header_view(std::string_view("Location"), &std::string_view("/login"))
            return
        }
        var html = render_learning_path_page(db, course_id, &learner_id)
        var bv = html.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    // GET /api/courses/:courseId/path — JSON data for the learning path
    public func handle_learning_path_api(db : *DbClient, courses_dir : &string, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }

        // Load course
        var course = underlayer_repository::load_course_from_disk(courses_dir, course_id)
        if(course.id.size() == 0) {
            var err = string("course not found")
            send_error(res, 404u, &err)
            return
        }

        // Load concept states
        var states = underlayer_repository::get_all_concept_states(db, &learner_id, course_id)

        // Build JSON response
        var resp = string("{\"course_id\":\"")
        resp.append_string(course_id)
        resp.append_view("\",\"title\":\"")
        var ct = course.title.copy()
        resp.append_string(&ct)
        resp.append_view("\",\"modules\":[")

        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            if(mi > 0) { resp.append_view(",") }
            resp.append_view("{\"id\":\"")
            var mid = mod.id.copy()
            resp.append_string(&mid)
            resp.append_view("\",\"title\":\"")
            var mtitle = mod.title.copy()
            resp.append_string(&mtitle)
            resp.append_view("\",\"order\":")
            var morder = underlayer_core::int_to_string(mod.order as i64)
            resp.append_view(morder.to_view())
            resp.append_view(",\"concepts\":[")

            var ci : size_t = 0
            while(ci < mod.concepts.size()) {
                var concept_id = mod.concepts.get_ptr(ci)
                if(ci > 0) { resp.append_view(",") }

                // Find concept title
                var concept_title = concept_id.copy()
                var concept_desc = string()
                var cii : size_t = 0
                while(cii < course.concepts.size()) {
                    var cref = course.concepts.get_ptr(cii)
                    if(cref.id.equals(concept_id)) {
                        concept_title = cref.title.copy()
                        concept_desc = cref.description.copy()
                        break
                    }
                    cii = cii + 1
                }

                // Find state
                var status = string("not_started")
                var attempts = 0
                var correct = 0
                var streak = 0
                var si : size_t = 0
                while(si < states.size()) {
                    var st = states.get_ptr(si)
                    if(st.concept_id.equals(concept_id)) {
                        status = st.status.copy()
                        attempts = st.attempts
                        correct = st.correct
                        streak = st.streak
                        break
                    }
                    si = si + 1
                }

                resp.append_view("{\"id\":\"")
                resp.append_string(concept_id)
                resp.append_view("\",\"title\":\"")
                resp.append_string(&concept_title)
                resp.append_view("\",\"description\":\"")
                resp.append_string(&concept_desc)
                resp.append_view("\",\"status\":\"")
                resp.append_string(&status)
                resp.append_view("\",\"attempts\":")
                var atk = underlayer_core::int_to_string(attempts as i64)
                resp.append_view(atk.to_view())
                resp.append_view(",\"correct\":")
                var crk = underlayer_core::int_to_string(correct as i64)
                resp.append_view(crk.to_view())
                resp.append_view(",\"streak\":")
                var stk = underlayer_core::int_to_string(streak as i64)
                resp.append_view(stk.to_view())
                resp.append_view("}")

                ci = ci + 1
            }

            resp.append_view("]}")
            mi = mi + 1
        }

        resp.append_view("]}")
        send_json_str(res, &raw resp)
    }

}
