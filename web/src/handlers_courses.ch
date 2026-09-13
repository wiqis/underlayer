// underlayer_web — Course listing and detail handlers.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    public func handle_list_courses(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var courses = underlayer_repository::list_courses(courses_dir)
        var body = std::string("[")
        var ci : size_t = 0
        while(ci < courses.size()) {
            var course = courses.get_ptr(ci)
            if(ci > 0) { body.append(',') }
            body.append_view("{\"id\":\"")
            var id_sv = course.id.to_view()
            var id_str = underlayer_core::json_escape(&id_sv)
            body.append_view(id_str.to_view())
            body.append_view("\",\"title\":\"")
            var title_sv = course.title.to_view()
            var title_str = underlayer_core::json_escape(&title_sv)
            body.append_view(title_str.to_view())
            body.append_view("\",\"version\":")
            var ver = underlayer_core::int_to_string(course.version as i64)
            body.append_view(ver.to_view())
            body.append_view(",\"modules\":")
            var mc = underlayer_core::int_to_string(course.modules.size() as i64)
            body.append_view(mc.to_view())
            body.append_view(",\"concepts\":")
            var cc = underlayer_core::int_to_string(course.concepts.size() as i64)
            body.append_view(cc.to_view())
            body.append('}')
            ci = ci + 1
        }
        body.append(']')
        send_json_str(res, &raw body)
    }

    public func handle_get_course(courses_dir : &string, course_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var cid = sv_to_string(course_id)
        var course = underlayer_repository::load_course(courses_dir, &cid)
        if(course.id.size() == 0) {
            var err = std::string("course not found")
            send_error(res, 404u, &err)
            return
        }
        var body = std::string("{\"id\":\"")
        var id_sv2 = course.id.to_view()
        var id_str = underlayer_core::json_escape(&id_sv2)
        body.append_view(id_str.to_view())
        body.append_view("\",\"title\":\"")
        var title_sv2 = course.title.to_view()
        var title_str = underlayer_core::json_escape(&title_sv2)
        body.append_view(title_str.to_view())
        body.append_view("\",\"version\":")
        var ver = underlayer_core::int_to_string(course.version as i64)
        body.append_view(ver.to_view())
        body.append_view(",\"modules\":[")
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            if(mi > 0) { body.append(',') }
            body.append_view("{\"id\":\"")
            var mid_sv = mod.id.to_view()
            var mid_str = underlayer_core::json_escape(&mid_sv)
            body.append_view(mid_str.to_view())
            body.append_view("\",\"title\":\"")
            var mtitle_sv = mod.title.to_view()
            var mtitle_str = underlayer_core::json_escape(&mtitle_sv)
            body.append_view(mtitle_str.to_view())
            body.append_view("\",\"order\":")
            var morder = underlayer_core::int_to_string(mod.order as i64)
            body.append_view(morder.to_view())
            body.append_view(",\"concept_count\":")
            var mcount = underlayer_core::int_to_string(mod.concepts.size() as i64)
            body.append_view(mcount.to_view())
            body.append('}')
            mi = mi + 1
        }
        body.append_view("],\"concepts\":[")
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.get_ptr(ci)
            if(ci > 0) { body.append(',') }
            body.append_view("{\"id\":\"")
            var cid2_sv = cref.id.to_view()
            var cid2_str = underlayer_core::json_escape(&cid2_sv)
            body.append_view(cid2_str.to_view())
            body.append_view("\",\"title\":\"")
            var ctitle_sv = cref.title.to_view()
            var ctitle_str = underlayer_core::json_escape(&ctitle_sv)
            body.append_view(ctitle_str.to_view())
            body.append_view("\",\"module_id\":\"")
            var cmid_sv = cref.module_id.to_view()
            var cmid_str = underlayer_core::json_escape(&cmid_sv)
            body.append_view(cmid_str.to_view())
            body.append_view("\"}")
            ci = ci + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

}
