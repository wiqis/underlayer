// underlayer_web — Lesson and course landing handlers.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_lesson(courses_dir : &string, course_id : *string_view, concept_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var pid = sv_to_string(concept_id)
        var html = render_concept(&raw pid)
        if(html.size() == 0) {
            var err = std::string("lesson not found")
            send_error(res, 404u, &err)
            return
        }
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

    public func handle_course_landing(courses_dir : &string, course_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var html = underlayer_content::render_elf_landing()
        if(html.size() == 0) {
            var err = std::string("course not found")
            send_error(res, 404u, &err)
            return
        }
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

}
