// underlayer_web — HTTP routes and handlers.
// All SQL lives in repository/. Web layer only handles HTTP.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Course

public namespace underlayer_web {

    // ---- Health endpoint ----
    public func handle_health(req : &http::Request, res : *mut http::ResponseWriter) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"status\": \"ok\"}")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    // ---- Course listing (hardcoded for now) ----
    public func handle_list_courses(req : &http::Request, res : *mut http::ResponseWriter) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("[{\"id\": \"elf\", \"title\": \"Executable and Linkable Format\", \"version\": 1}]")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    // ---- Course detail (hardcoded for now) ----
    public func handle_get_course(course_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"id\": \"elf\", \"title\": \"Executable and Linkable Format\", \"version\": 1}")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    // ---- Lesson viewer (serves pre-rendered HTML) ----
    public func handle_lesson(course_id : *string_view, concept_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var cid = *course_id
        var pid = *concept_id
        var path = std::string("lang/compiled/underlayer/courses/")
        path.append_view(&cid)
        path.append_view(std::string_view("/output/"))
        path.append_view(&pid)
        path.append_view(std::string_view(".html"))

        var f = fopen(path.data(), "rb")
        if(f == null) {
            res.status = 404u
            var ct = std::string_view("text/plain")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("Lesson not found")
            var bv = body.to_view()
            res.write_view(&bv)
            return
        }
        unsafe { fseek(f, 0, 2) }
        var fsize : long = 0
        unsafe { fsize = ftell(f) }
        unsafe { fseek(f, 0, 0) }
        var buf = string()
        unsafe { buf.resize(fsize as size_t) }
        unsafe { fread(buf.data() as *mut void, 1, fsize as size_t, f) }
        unsafe { fclose(f) }
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var bv = buf.to_view()
        res.write_view(&bv)
    }

    // ---- Home page ----
    public func handle_home(req : &http::Request, res : *mut http::ResponseWriter) {
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("<!DOCTYPE html><html><head><title>Underlayer</title></head><body>")
        body.append_view(std::string_view("<h1>Underlayer</h1>"))
        body.append_view(std::string_view("<p>AI-native learning platform for binary formats.</p>"))
        body.append_view(std::string_view("<ul>"))
        body.append_view(std::string_view("<li><a href=\"/api/courses\">Courses</a></li>"))
        body.append_view(std::string_view("<li><a href=\"/api/health\">Health</a></li>"))
        body.append_view(std::string_view("</ul></body></html>"))
        var bv = body.to_view()
        res.write_view(&bv)
    }
}
