// underlayer_web — Lesson and course landing handlers.
using std::string
using std::string_view
using underlayer_db::DbClient
using underlayer_models::ConceptRef

public namespace underlayer_web {

    public func handle_lesson(courses_dir : &string, course_id : &string_view, concept_id : &string_view, req : &http::Request) : http::Response {
        // Validate the course exists — unknown courses get a 404 instead of
        // silently falling back to ELF content (multi-course correctness).
        var cidsv = sv_to_string(course_id)
        var course = underlayer_repository::load_course(courses_dir, &cidsv)
        if(course.id.size() == 0) {
            var err = std::string("course not found")
            return send_error(404u, &err)
        }
        var pid = sv_to_string(concept_id)
        var html = render_concept(&pid)
        if(html.size() == 0) {
            var err = std::string("lesson not found")
            return send_error(404u, &err)
        }
        // I1: one title, a 140-158 char description, canonical, og tags and
        // Course + BreadcrumbList JSON-LD. Applied BEFORE the pager/header
        // patches so their size-based sentinel logic still measures only
        // their own effect. No aggregateRating: no ratings are shipped.
        var seo_html = apply_lesson_seo(&html, &course, &pid)
        html = seo_html
        // Prev/next links, resolved HERE rather than in the lesson's own
        // script.  The course manifest is already loaded above -- it is what
        // decided whether this lesson exists -- so the information was in hand
        // and was previously fetched over HTTP by the page's JavaScript.  Doing
        // it server-side is what makes the links work with no server at all,
        // which the 398 statically pre-rendered lesson pages require; an empty
        // href="" also made the swipe gesture RELOAD THE CURRENT PAGE offline.
        // See web/src/lesson_pager.ch for the full argument and for why this is
        // sentinel replacement rather than an argument through 431 renderers.
        var paged = apply_lesson_pager(&html, &cidsv, &course, &pid)
        // HOW LONG, HOW HARD, AND WHAT TO KNOW FIRST.
        //
        // Applied after the pager because the pager rewrites the document and a
        // patcher that ran first could be looking for markers the pager has
        // already moved.  Both are sentinel replacements over the same string, so
        // the order is a correctness requirement rather than a preference.
        //
        // The manifest has said estimated_minutes for every concept of every
        // course since the day the loader was written, and a served lesson page
        // printed none of it: no time, no level, no prerequisites.  `course` has
        // been in hand since line 12 of this function, where it decides whether
        // the lesson exists at all.
        var headed = apply_lesson_header(&paged, &course, &pid)

        // THE GUIDED JOURNEY.  Most lesson renderers already emit the shell via
        // the shared lesson assets and this is a byte-for-byte no-op; the older
        // renderers (bytes and its neighbours) get the shell here.  The manifest
        // facts are attached in the same pass, so the arrival strip can state
        // the time, level and previous lesson without an API call.
        var journeyed = apply_lesson_journey(&headed, &course, &cidsv, &pid)

        // The header's own styles, emitted as a <style> block rather than a
        // <link>, for the two reasons in web/src/lesson_header_css.ch: one
        // request per lesson page, and a file:// lesson with no stylesheet.
        // Only emitted when the header was actually injected, so a lesson that
        // could not be patched does not carry rules for nothing.
        var css = lesson_header_css()
        if(journeyed.size() != paged.size()) {
            var tag = std::string("<style>")
            tag.append_string(&css)
            tag.append_view("</style>")
            var full = std::string("<!DOCTYPE html><html><head>")
            full.append_string(&tag)
            var rest = journeyed.to_view()
            var do_idx = rest.find_or_npos(string_view("<head>"))
            if(do_idx != std::NPOS) {
                var after = do_idx + 6
                full.append_view(journeyed.to_view().subview(after, journeyed.size()))
                return send_html(&full)
            }
        }
        return send_html(&journeyed)
    }

    public func handle_course_landing(db : *DbClient, courses_dir : &string, course_id : &string_view, req : &http::Request) : http::Response {
        // A local copy, giving the `*DbClient` the repository layer takes.
        //
        // The two course routes capture the database BY REFERENCE -- they already
        // captured courses_dir that way -- and a by-reference capture yields
        // `&DbClient`. `&raw db` reads as the pointer and is not one: in the
        // rate-limit gate on POST /api/exercises/submit that exact call compiled,
        // was present in the binary, and never ran -- 125 requests, no counter
        // written. `var dbp = db` then `&raw dbp` is the form that works, and
        // tools/security_check.py CHECK 14 fires every gate so it cannot return.
        var dbp = db
        // Data-driven: any course with a manifest.json gets a landing page.
        var cidsv = sv_to_string(course_id)
        var course = underlayer_repository::load_course(courses_dir, &cidsv)
        if(course.id.size() == 0) {
            var err = std::string("course not found")
            return send_error(404u, &err)
        }
        var html = underlayer_content::render_course_landing(&course)
        // I1: the same head contract as a lesson, with a three-crumb trail.
        var seo_html = apply_landing_seo(&html, &course)
        html = seo_html
        // ONE CLEAR STARTING PATH.  Every course still lists every lesson below;
        // the reader no longer has to choose among them before beginning.
        if(course.concepts.size() > 0) {
            var first = course.concepts.at_ref(0)
            var first_url = string("/courses/")
            first_url.append_view(cidsv.to_view())
            first_url.append_view("/lessons/")
            first_url.append_view(first.id.to_view())
            var safe_url = underlayer_core::html_escape(&first_url)
            var safe_title = underlayer_core::html_escape(&first.title)
            var count = underlayer_core::int_to_string(course.concepts.size() as i64)
            var paneled = underlayer_content::apply_start_panel(&html, &safe_url, &safe_title, &count)
            html = paneled
        }
        // THE ENROL CONTROL.  (P1 7.1.23)
        //
        // The checklist item said "enrollments API has no UI consumer" and that
        // was true of all of it: GET /api/enrollments, POST /api/courses/:id/enroll
        // and GET /api/courses/:id/can-enroll all answered 200 and no page on any
        // course named any of them.
        //
        // Server-rendered, not client-fetched, because the state has to be right
        // before any script runs -- a signed-out reader clicking a
        // client-rendered Enrol button gets a 401 with nothing around it to
        // explain. The session is right here; handle_course_landing is given the
        // request.
        var has_session = has_session_for(dbp, req)
        var enrolled_at = enrollment_state(dbp, req, &cidsv)
        html = apply_enroll_control(&html, &cidsv, enrolled_at, has_session)

        return send_html(&html)
    }

}
