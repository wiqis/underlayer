// underlayer_web — GET /health, the Knowledge Health page.
//
// THE SIGN-IN GATE, and why this page needs it more than most. Every figure on
// the page is computed from the signed-in learner's own concept_states, goals and
// course progress. A signed-out visitor has none of those, so the page would
// render a health score of 0, a depth score of 0, a retention projection of 0%
// and a course covered figure of 0% -- four numbers, all zero, none of them the
// reader's. docs/course-design.md requires this collection to normalise
// struggle, and a page of zeroes tells a reader they are failing at something
// they have not started.
//
// The gate is server-side and runs before any query: the reader never receives
// the page and never receives its data, so there is no window on a slow
// connection where the numbers arrive and are then hidden. That is the property
// worth preserving, and it is why this is not a client-side check.
//
// See pages_auth_gate.ch for why this redirects rather than rendering a sign-in
// card in place.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_knowledge_health_page(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        if(!has_session(&raw db, req)) {
            var gate_path = string("/health")
            redirect_to_login(res, &gate_path)
            return
        }
        var learner_id = auth_get_learner_id(&raw db, req)

        // progress_course_id reads ?course_id= and falls back to elf. Reused
        // rather than reimplemented so /health, /progress and /dashboard cannot
        // drift on which course they are showing.
        var course_id = progress_course_id(req)

        var html_out = render_knowledge_health_page(&raw mut db, courses_dir, &learner_id, &course_id)
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        apply_security_headers(res)
        res.write_view(&bv)
    }

}