// underlayer_web — Navigation handlers (7.1.2, 7.1.3, 7.1.5).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // P2 7.1.13/7.1.15: Nav status — course progress + due review count for the navbar
    public func handle_nav_status(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) {
            learner_id = string("demo")
        }
        var course_id = string("elf")

        // Count concepts the learner has actually attempted
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var started : int = 0
        var si : size_t = 0
        while(si < states.size()) {
            var state = states.get_ptr(si)
            var not_started = string("not_started")
            if(state.attempts > 0 && !state.status.equals(&not_started)) {
                started = started + 1
            }
            si = si + 1
        }

        // 24 concepts — matches render_concept mapping in helpers.ch
        var total : int = 24
        var pct : int = (started * 100) / total
        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 50)

        var body = string("{\"concepts_started\":")
        var s_str = underlayer_core::int_to_string(started as i64)
        body.append_string(&s_str)
        body.append_view(",\"concepts_total\":")
        var t_str = underlayer_core::int_to_string(total as i64)
        body.append_string(&t_str)
        body.append_view(",\"progress_pct\":")
        var p_str = underlayer_core::int_to_string(pct as i64)
        body.append_string(&p_str)
        body.append_view(",\"due_reviews\":")
        var d_str = underlayer_core::int_to_string(due_items.size() as i64)
        body.append_string(&d_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

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

    // P2 7.1.10: Quick jump — all concepts + nav pages for the command palette.
    // Concept IDs mirror render_concept() in helpers.ch (24 concepts).
    public func handle_nav_search(req : &http::Request, res : *mut http::ResponseWriter) {
        var body = string("{\"entries\":[")
        body.append_view("{\"label\":\"Home\",\"url\":\"/\",\"kind\":\"page\"}")
        body.append_view(",{\"label\":\"Dashboard\",\"url\":\"/dashboard\",\"kind\":\"page\"}")
        body.append_view(",{\"label\":\"Review\",\"url\":\"/review\",\"kind\":\"page\"}")
        body.append_view(",{\"label\":\"Progress\",\"url\":\"/progress\",\"kind\":\"page\"}")

        // 24 concepts in course order
        append_nav_entry(&raw body, string("Bytes and Binary"), string("bytes"), true)
        append_nav_entry(&raw body, string("Binary Representation"), string("binary-representation"), true)
        append_nav_entry(&raw body, string("File Layout"), string("file-layout"), true)
        append_nav_entry(&raw body, string("ELF Identification"), string("elf-identification"), true)
        append_nav_entry(&raw body, string("ELF Header Fields"), string("elf-header-fields"), true)
        append_nav_entry(&raw body, string("Entry Point"), string("entry-point"), true)
        append_nav_entry(&raw body, string("Program Header Table"), string("program-header-table"), true)
        append_nav_entry(&raw body, string("Segment Types"), string("segment-types"), true)
        append_nav_entry(&raw body, string("Memory Mapping"), string("memory-mapping"), true)
        append_nav_entry(&raw body, string("Section Header Table"), string("section-header-table"), true)
        append_nav_entry(&raw body, string("Common Sections"), string("common-sections"), true)
        append_nav_entry(&raw body, string("Section vs Segment"), string("section-vs-segment"), true)
        append_nav_entry(&raw body, string("Symbol Table"), string("symbol-table"), true)
        append_nav_entry(&raw body, string("Symbol Binding"), string("binding"), true)
        append_nav_entry(&raw body, string("Symbol Visibility"), string("visibility"), true)
        append_nav_entry(&raw body, string("Relocation Entries"), string("relocation-entries"), true)
        append_nav_entry(&raw body, string("Relocation Types"), string("relocation-types"), true)
        append_nav_entry(&raw body, string("Dynamic Relocations"), string("dynamic-relocations"), true)
        append_nav_entry(&raw body, string("Dynamic Section"), string("dynamic-section"), true)
        append_nav_entry(&raw body, string("Shared Libraries"), string("shared-libraries"), true)
        append_nav_entry(&raw body, string("The Dynamic Linker"), string("ld-so"), true)
        append_nav_entry(&raw body, string("The Kernel Loader"), string("loader"), true)
        append_nav_entry(&raw body, string("Process Memory Layout"), string("memory-layout"), true)
        append_nav_entry(&raw body, string("The Startup Sequence"), string("execution"), true)

        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // Append one concept entry (adds comma before every entry).
    func append_nav_entry(body : *string, label : string, concept_id : string, is_concept : bool) {
        body.append_view(",\"label\":\"")
        body.append_string(&label)
        body.append_view("\",\"url\":\"/courses/elf/lessons/")
        body.append_string(&concept_id)
        if(is_concept) {
            body.append_view("\",\"kind\":\"concept\"}")
        } else {
            body.append_view("\",\"kind\":\"page\"}")
        }
    }

}
