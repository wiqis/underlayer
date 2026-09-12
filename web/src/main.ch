// underlayer_web — HTTP routes and handlers.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Course
using underlayer_models::Module
using underlayer_models::ConceptRef
using underlayer_models::ReviewItem
using underlayer_models::Session

public namespace underlayer_web {

    public struct WebConfig {
        var db : *DbClient
        var courses_dir : string
    }

    private func send_page(res : *mut http::ResponseWriter, page : *HtmlPage) {
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var html = page.toString()
        var hv = html.to_view()
        res.write_view(&hv)
    }

    private func send_json_str(res : *mut http::ResponseWriter, body : *string) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var bv = body.to_view()
        res.write_view(&bv)
    }

    private func send_error(res : *mut http::ResponseWriter, status : uint, msg : &string) {
        res.status = status
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"error\":\"")
        body.append_string(msg)
        body.append_view("\"}")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    private func sv_to_string(sv : *string_view) : string {
        var out = std::string()
        var i : size_t = 0
        while(i < sv.size()) { out.append(sv.get(i)); i = i + 1 }
        return out
    }

    // Route a concept ID to the correct render function
    private func render_concept(concept_id : *string) : string {
        var cid = concept_id.copy()
        var bytes_id = std::string("bytes")
        var binrep_id = std::string("binary-representation")
        var filelayout_id = std::string("file-layout")
        var elfident_id = std::string("elf-identification")
        var elfheader_id = std::string("elf-header-fields")
        var entrypoint_id = std::string("entry-point")
        var progheader_id = std::string("program-header-table")
        var segtype_id = std::string("segment-types")
        var memmap_id = std::string("memory-mapping")
        var sectheader_id = std::string("section-header-table")
        var commonsec_id = std::string("common-sections")
        var secvsseg_id = std::string("section-vs-segment")

        if(cid.equals(&bytes_id)) { return underlayer_content::render_bytes() }
        if(cid.equals(&binrep_id)) { return underlayer_content::render_binary_representation() }
        if(cid.equals(&filelayout_id)) { return underlayer_content::render_file_layout() }
        if(cid.equals(&elfident_id)) { return underlayer_content::render_elf_identification() }
        if(cid.equals(&elfheader_id)) { return underlayer_content::render_elf_header_fields() }
        if(cid.equals(&entrypoint_id)) { return underlayer_content::render_entry_point() }
        if(cid.equals(&progheader_id)) { return underlayer_content::render_program_header_table() }
        if(cid.equals(&segtype_id)) { return underlayer_content::render_segment_types() }
        if(cid.equals(&memmap_id)) { return underlayer_content::render_memory_mapping() }
        if(cid.equals(&sectheader_id)) { return underlayer_content::render_section_header_table() }
        if(cid.equals(&commonsec_id)) { return underlayer_content::render_common_sections() }
        if(cid.equals(&secvsseg_id)) { return underlayer_content::render_section_vs_segment() }
        return string()
    }

    // ---- Health ----
    public func handle_health(req : &http::Request, res : *mut http::ResponseWriter) {
        var body = std::string("{\"status\": \"ok\", \"version\": \"0.1.0\"}")
        send_json_str(res, &raw body)
    }

    // ---- Course Listing ----
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

    // ---- Course Detail ----
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

    // ---- Lesson Viewer ----
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

    // ---- Course Landing ----
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

    // ---- Home Page ----
    public func handle_home(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultPrepare()
        var title = std::string_view("Underlayer - Learn Things Deeply")
        page.appendTitle(&title)

        #html {
            <div style="max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, sans-serif;">
                <h1 style="font-size: 2rem; margin-bottom: 0.5rem;">Underlayer</h1>
                <p style="font-size: 1.1rem; color: #4b5563; margin-bottom: 2rem;">Learn Things Deeply.</p>
                <div style="padding: 1.5rem; border: 1px solid #e5e7eb; border-radius: 8px;">
                    <h2>ELF — Executable and Linkable Format</h2>
                    <p style="color: #6b7280;">A deep dive into the ELF binary format.</p>
                    <a href="/courses/elf" style="color: #3b82f6;">Start Learning</a>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; }
            a { color: #3b82f6; text-decoration: none; }
            a:hover { text-decoration: underline; }
        }

        send_page(res, &raw page)
    }

    // ---- Learner Creation ----
    public func handle_create_learner(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        // Generate a simple learner ID from timestamp
        var learner_id = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var name = std::string("learner")
        var email = std::string("learner@underlayer.dev")
        underlayer_repository::create_learner(db, &learner_id, &name, &email)
        var body = std::string("{\"id\":\"")
        body.append_view(learner_id.to_view())
        body.append_view("\",\"name\":\"")
        body.append_view(name.to_view())
        body.append_view("\",\"email\":\"")
        body.append_view(email.to_view())
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    // ---- Get Learner ----
    public func handle_get_learner(db : *DbClient, learner_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var lid = sv_to_string(learner_id)
        var learner = underlayer_repository::get_learner(db, &lid)
        if(learner.id.size() == 0) {
            var err = std::string("learner not found")
            send_error(res, 404u, &err)
            return
        }
        var body = std::string("{\"id\":\"")
        body.append_string(&learner.id)
        body.append_view("\",\"name\":\"")
        body.append_string(&learner.name)
        body.append_view("\",\"email\":\"")
        body.append_string(&learner.email)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    // ---- Review Session ----
    public func handle_review_start(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        // Get learner_id and course_id from query params
        var learner_id = string("demo")
        var course_id = string("elf")

        // Fetch due review items from repository
        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 10)

        // Create review session using learning module
        var session = underlayer_learning::start_review_session(due_items)

        // Build JSON response with items
        var body = std::string("{\"items\":[")
        var i : size_t = 0
        while(i < session.items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = session.items.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&item.id)
            body.append_view("\",\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"type\":\"")
            body.append_string(&item.item_type)
            body.append_view("\",\"front\":\"")
            body.append_string(&item.front)
            body.append_view("\",\"back\":\"")
            body.append_string(&item.back)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(session.items.size() as i64)
        body.append_string(&total_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    public func handle_review_submit(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        // For now, acknowledge — full rating recording will use FSRS
        var body = std::string("{\"status\":\"ok\"}")
        send_json_str(res, &raw body)
    }

    // ---- Learner Progress ----
    public func handle_progress(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")

        // Get all concept states for this learner
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)

        // Compute knowledge health using learning module
        var health = underlayer_learning::compute_knowledge_health(&raw states)

        // Build progress JSON
        var body = std::string("{\"learner_id\":\"")
        body.append_string(&learner_id)
        body.append_view("\",\"course_id\":\"")
        body.append_string(&course_id)
        body.append_view("\",\"health\":")
        var health_str = underlayer_core::int_to_string((health.health_score * 100.0) as i64)
        body.append_string(&health_str)
        body.append_view(",\"mastered\":")
        var mastered_str = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&mastered_str)
        body.append_view(",\"learning\":")
        var learning_str = underlayer_core::int_to_string(health.learning as i64)
        body.append_string(&learning_str)
        body.append_view(",\"reviewing\":")
        var reviewing_str = underlayer_core::int_to_string(health.reviewing as i64)
        body.append_string(&reviewing_str)
        body.append_view(",\"unlearned\":")
        var unlearned_str = underlayer_core::int_to_string(health.unlearned as i64)
        body.append_string(&unlearned_str)
        body.append_view(",\"concepts\":[")

        var i : size_t = 0
        while(i < states.size()) {
            if(i > 0) { body.append_view(",") }
            var s = states.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var attempts_str = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&attempts_str)
            body.append_view(",\"correct\":")
            var correct_str = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&correct_str)
            body.append_view(",\"streak\":")
            var streak_str = underlayer_core::int_to_string(s.streak as i64)
            body.append_string(&streak_str)
            body.append_view("}")
            i = i + 1
        }

        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // ---- Static File Serving ----
    // Serves files from courses/<courseId>/output/ or courses/<courseId>/assets/
    private func content_type_for_ext(ext : *string) : string {
        if(ext.equals(string("html"))) { return string("text/html; charset=utf-8") }
        if(ext.equals(string("css"))) { return string("text/css; charset=utf-8") }
        if(ext.equals(string("js"))) { return string("application/javascript; charset=utf-8") }
        if(ext.equals(string("json"))) { return string("application/json") }
        if(ext.equals(string("png"))) { return string("image/png") }
        if(ext.equals(string("jpg"))) { return string("image/jpeg") }
        if(ext.equals(string("jpeg"))) { return string("image/jpeg") }
        if(ext.equals(string("gif"))) { return string("image/gif") }
        if(ext.equals(string("svg"))) { return string("image/svg+xml") }
        if(ext.equals(string("ico"))) { return string("image/x-icon") }
        if(ext.equals(string("woff"))) { return string("font/woff") }
        if(ext.equals(string("woff2"))) { return string("font/woff2") }
        if(ext.equals(string("ttf"))) { return string("font/ttf") }
        return string("application/octet-stream")
    }

    // Extract file extension from path (everything after last '.')
    private func file_extension(path : *string_view) : string {
        var last_dot : size_t = 0
        var i : size_t = 0
        while(i < path.size()) {
            if(path.get(i) == '.') { last_dot = i }
            i = i + 1
        }
        if(last_dot == 0 || last_dot >= path.size() - 1) { return string() }
        var ext = string()
        var j : size_t = last_dot + 1
        while(j < path.size()) {
            ext.append(path.get(j))
            j = j + 1
        }
        return ext
    }

    public func handle_static_file(courses_dir : &string, req_path : *string_view, res : *mut http::ResponseWriter) {
        // Build the full filesystem path: courses_dir + req_path
        // req_path is like "/courses/elf/bytes.css" or "/courses/elf/assets/image.png"
        var fs_path = courses_dir.copy()
        var req_str = req_path.to_string()
        fs_path.append_string(&req_str)

        // Read the file
        var content_res = fs::read_entire_file(fs_path.data())
        if(content_res is std::Result.Err) {
            var err_msg = std::string("file not found")
            send_error(res, 404u, &err_msg)
            return
        }
        var Ok(bytes) = content_res else unreachable

        // Determine content type from extension
        var ext = file_extension(req_path)
        var ct = content_type_for_ext(&raw ext)
        var ct_view = ct.to_view()
        res.set_header_view(std::string_view("Content-Type"), &ct_view)

        // Serve the bytes
        var body_view = std::string_view(bytes.data() as *char, bytes.size())
        res.write_view(&body_view)
    }

}
