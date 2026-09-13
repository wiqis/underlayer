// underlayer_web — Navigation handlers (7.1.2, 7.1.3, 7.1.5).
using std::string
using std::string_view

public namespace underlayer_web {

    // GET /api/navigation/:courseId/:conceptId — returns sidebar, prev/next, breadcrumbs
    public func handle_navigation(courses_dir : &string, course_id : *string_view, concept_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var cid = sv_to_string(course_id)
        var concept = sv_to_string(concept_id)
        var course = underlayer_repository::load_course(courses_dir, &cid)
        if(course.id.size() == 0) {
            send_error(res, 404u, &string("course not found"))
            return
        }

        var body = std::string("{\"course_id\":\"")
        var cid_esc = underlayer_core::json_escape(&cid.to_view())
        body.append_view(cid_esc.to_view())
        body.append_view("\",\"course_title\":\"")
        var ct_esc = underlayer_core::json_escape(&course.title.to_view())
        body.append_view(ct_esc.to_view())

        // 7.1.2: Module sidebar — modules with their concepts
        body.append_view("\",\"modules\":[")
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            if(mi > 0) { body.append(',') }
            body.append_view("{\"id\":\"")
            var mid_esc = underlayer_core::json_escape(&mod.id.to_view())
            body.append_view(mid_esc.to_view())
            body.append_view("\",\"title\":\"")
            var mtitle_esc = underlayer_core::json_escape(&mod.title.to_view())
            body.append_view(mtitle_esc.to_view())
            body.append_view("\",\"order\":")
            var morder = underlayer_core::int_to_string(mod.order as i64)
            body.append_view(morder.to_view())
            body.append_view(",\"concepts\":[")
            // Find concepts in this module
            var first_concept = true
            var ci : size_t = 0
            while(ci < course.concepts.size()) {
                var cref = course.concepts.get_ptr(ci)
                if(cref.module_id.equals(&mod.id)) {
                    if(!first_concept) { body.append(',') }
                    first_concept = false
                    body.append_view("{\"id\":\"")
                    var cid2_esc = underlayer_core::json_escape(&cref.id.to_view())
                    body.append_view(cid2_esc.to_view())
                    body.append_view("\",\"title\":\"")
                    var ctitle_esc = underlayer_core::json_escape(&cref.title.to_view())
                    body.append_view(ctitle_esc.to_view())
                    body.append_view("\"}")
                }
                ci = ci + 1
            }
            body.append_view("]}")
            mi = mi + 1
        }
        body.append_view("]")

        // 7.1.5: Breadcrumbs — find module for current concept
        var current_module_id = string()
        var current_module_title = string()
        var current_concept_title = string()
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.get_ptr(ci)
            if(cref.id.equals(&concept)) {
                current_module_id = cref.module_id.copy()
                current_concept_title = cref.title.copy()
            }
            ci = ci + 1
        }
        var mi2 : size_t = 0
        while(mi2 < course.modules.size()) {
            var mod2 = course.modules.get_ptr(mi2)
            if(mod2.id.equals(&current_module_id)) {
                current_module_title = mod2.title.copy()
            }
            mi2 = mi2 + 1
        }
        body.append_view(",\"breadcrumbs\":[")
        body.append_view("{\"label\":\"Home\",\"url\":\"/\"}")
        body.append_view(",{\"label\":\"")
        var ct2_esc = underlayer_core::json_escape(&course.title.to_view())
        body.append_view(ct2_esc.to_view())
        body.append_view("\",\"url\":\"/courses/")
        body.append_view(cid_esc.to_view())
        body.append_view("\"}")
        if(current_module_title.size() > 0) {
            body.append_view(",{\"label\":\"")
            var mt_esc = underlayer_core::json_escape(&current_module_title.to_view())
            body.append_view(mt_esc.to_view())
            body.append_view("\"}")
        }
        if(current_concept_title.size() > 0) {
            body.append_view(",{\"label\":\"")
            var cct_esc = underlayer_core::json_escape(&current_concept_title.to_view())
            body.append_view(cct_esc.to_view())
            body.append_view("\"}")
        }
        body.append_view("]")

        // 7.1.3: Prev/Next concept
        var prev_id = string()
        var prev_title = string()
        var next_id = string()
        var next_title = string()
        var found_current = false
        var ci2 : size_t = 0
        while(ci2 < course.concepts.size()) {
            var cref = course.concepts.get_ptr(ci2)
            if(cref.id.equals(&concept)) {
                found_current = true
            } else if(!found_current) {
                prev_id = cref.id.copy()
                prev_title = cref.title.copy()
            } else if(next_id.size() == 0) {
                next_id = cref.id.copy()
                next_title = cref.title.copy()
            }
            ci2 = ci2 + 1
        }
        body.append_view(",\"prev\":")
        if(prev_id.size() > 0) {
            body.append_view("{\"id\":\"")
            var pid_esc = underlayer_core::json_escape(&prev_id.to_view())
            body.append_view(pid_esc.to_view())
            body.append_view("\",\"title\":\"")
            var pt_esc = underlayer_core::json_escape(&prev_title.to_view())
            body.append_view(pt_esc.to_view())
            body.append_view("\"}")
        } else {
            body.append_view("null")
        }
        body.append_view(",\"next\":")
        if(next_id.size() > 0) {
            body.append_view("{\"id\":\"")
            var nid_esc = underlayer_core::json_escape(&next_id.to_view())
            body.append_view(nid_esc.to_view())
            body.append_view("\",\"title\":\"")
            var nt_esc = underlayer_core::json_escape(&next_title.to_view())
            body.append_view(nt_esc.to_view())
            body.append_view("\"}")
        } else {
            body.append_view("null")
        }

        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
