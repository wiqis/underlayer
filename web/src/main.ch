// underlayer_web — HTTP routes and handlers.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Course
using underlayer_models::Module
using underlayer_models::ConceptRef

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

    public func handle_health(req : &http::Request, res : *mut http::ResponseWriter) {
        var body = std::string("{\"status\": \"ok\", \"version\": \"0.1.0\"}")
        send_json_str(res, &raw body)
    }

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
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    public func handle_lesson(courses_dir : &string, course_id : *string_view, concept_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var pid = sv_to_string(concept_id)
        var html = render_concept(&raw pid)
        if(html.size() == 0) {
            res.status = 404u
            var ct = std::string_view("text/plain")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var msg = std::string("Lesson not found")
            var mv = msg.to_view()
            res.write_view(&mv)
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
            res.status = 404u
            var ct = std::string_view("text/plain")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var msg = std::string("Course not found")
            var mv = msg.to_view()
            res.write_view(&mv)
            return
        }
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var hv = html.to_view()
        res.write_view(&hv)
    }

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
}
