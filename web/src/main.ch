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
    public func handle_review_start(db : *DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        // For now, return empty list — FSRS integration in Phase 2
        var body = std::string("{\"items\":[],\"message\":\"review engine coming in Phase 2\"}")
        send_json_str(res, &raw body)
    }

    public func handle_review_submit(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        // For now, acknowledge — FSRS integration in Phase 2
        var body = std::string("{\"status\":\"ok\",\"message\":\"review recording coming in Phase 2\"}")
        send_json_str(res, &raw body)
    }
}
