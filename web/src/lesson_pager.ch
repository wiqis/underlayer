// underlayer_web — prev/next lesson links, resolved on the SERVER.  (7.1.16)
//
// WHY THIS IS NOT DONE IN JAVASCRIPT ANY MORE.
//
// `GET /api/navigation/:courseId/:conceptId` shipped, and
// content/src/lesson_engagement_js.ch DOES consume it: it flattens the modules,
// finds the current concept, and fills in `#ul-prev`, `#ul-next` and the
// `<link rel="prev">` / `<link rel="next">` tags that the swipe handler reads.
// That works -- when there is a server.
//
// Two things it cannot do:
//
//   1. It breaks the backend-optional rule.  The 398 lesson pages are
//      pre-rendered to static HTML and served from GitHub Pages; a reader who
//      downloads a page and opens it from disk gets no fetch, no prev/next, and
//      a swipe gesture that RELOADS THE PAGE THEY ARE ALREADY ON, because an
//      empty `href=""` resolves to the current URL.  So the gesture is not
//      merely inert offline -- it is wrong, in the specific way that looks like
//      the app working.
//
//   2. It is invisible to everything that does not run script.  A text-mode
//      reader, a crawler, a print, and every accessibility tool that reads the
//      document rather than the DOM all see two hidden anchors and two empty
//      rel links -- i.e. a course that is a list with no way to walk it.
//
// The server already knows both halves: handle_lesson is given the course id
// and the concept id, and it has ALREADY loaded the course manifest to decide
// whether the lesson exists at all.  So the information needed to emit real
// links was in hand and was being fetched over HTTP afterwards.
//
// WHY SENTINEL REPLACEMENT RATHER THAN A NEW RENDER FUNCTION.  The markup
// lives in 431 page builders in content/src, and the empty
// `<link rel="prev" href="">` plus the hidden `#ul-prev` / `#ul-next` anchors
// are emitted by ONE shared component among them (content/src/
// lesson_engagement_js.ch).  Rewriting 431 files to thread a pager argument
// through render_concept would touch the entire course corpus -- which 24
// verify_*.py checkers assert byte-level facts about -- to move an argument the
// server already holds.
//
// So this replaces five exact, machine-generated, UNIQUE substrings, and only
// when they are present.  Each replacement is a no-op on a page that does not
// have the component, so nothing can be corrupted by a partial match, and
// tools/lesson_pager_check.py asserts that the real links are present in the
// SERVED html -- which is what stops this from quietly becoming a no-op.
//
// THE CLIENT SCRIPT IS LEFT ALONE, and is now redundant rather than
// load-bearing: it recomputes the same links and writes the same values.  That
// redundancy is deliberate -- it is the fallback for a statically generated
// page whose manifest moved after the file was written -- and it is safe
// because both computations read the same manifest.
//
// WHY THE FIRST AND LAST CONCEPT GET NO LINK.  A `rel="prev"` pointing at the
// page you are on is worse than no link: a crawler would treat the document as
// its own predecessor and stop walking, and a reader pressing "Previous" would
// get the same page.  So the anchor keeps its `hidden` attribute at the ends of
// the course, and only the interior pages carry both.
using std::string
using std::string_view
using underlayer_models::Course

public namespace underlayer_web {

    // Replace the first occurrence of `needle` in `src` with `value`.
    // Returns the input UNCHANGED when the needle is absent, so a caller can
    // tell "patched" from "this page does not carry the component" by
    // comparing lengths -- and, more importantly, cannot be corrupted by a
    // partial match.
    //
    // `src` and the destination MUST BE DIFFERENT VARIABLES.  Writing
    //
    //     out = patch_once(&out, needle, value)
    //
    // passes the same object as the thing being read and the thing being
    // assigned, and the compiler emits a move into storage that is still being
    // read from.  The observed result was not a wrong link -- it was a
    // RESPONSE TRUNCATED AT 24 KB, with the page cut off mid-attribute in the
    // accessibility controls, on every lesson, with the server still healthy.
    // That is the same aliasing family the audit recorded in
    // repository/src/notes.ch, and it is why each patch below is applied to a
    // NEWLY NAMED variable instead of back into itself.
    private func patch_once(src : &string, needle : &string_view, value : &string) : string {
        var at = src.find(needle)
        if(at == std::NPOS) { return src.copy() }
        var after = at + needle.size()
        var built = std::string()
        built.append_view(src.to_view().subview(0, at))
        built.append_string(value)
        // `subview(start, end)` TAKES AN END INDEX, NOT A LENGTH: it returns
        // string_view(_data + start, end - start).  Passing `size - after` as
        // the second argument therefore asks for the range
        // [after, size - after), whose length is `size - 2*after` -- and for a
        // needle found in the first tenth of a 65 KB page that is a NEGATIVE
        // length, i.e. the tail of the document silently disappears.
        //
        // The observed symptom was not a missing link.  It was every lesson
        // page served TRUNCATED -- bytes went from 65,866 bytes to 24,934,
        // cut off mid-attribute inside the accessibility controls -- with the
        // server healthy, every route answering 200, and nav_check and
        // link_check both reporting green because they check status codes and
        // link targets, not whether the document still has an end.
        //
        // tools/lesson_pager_check.py asserts the lesson body survives, which
        // is the only kind of assertion that catches this class.
        built.append_view(src.to_view().subview(after, src.size()))
        return built
    }

    // Fill in the position line, the two step links and the two rel links.
    // Returns the patched HTML.  On a page that does not carry the engagement
    // component the input comes back byte-identical.
    public func apply_lesson_pager(html : &string, course_id : &string, course : &Course, concept_id : &string) : string {
        var idx : i64 = -1
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            if(course.concepts.get_ptr(ci).id.equals(concept_id)) { idx = ci as i64 }
            ci = ci + 1
        }
        // An unknown concept is not an error here: handle_lesson has already
        // decided this lesson renders.  Leave the sentinels untouched so the
        // client script still gets its turn, and return the input unchanged.
        if(idx < 0) { return html.copy() }
        if(idx == -999) { return html.copy() }

        var src0 = html.copy()
        var c_esc = underlayer_core::html_escape(course_id)

        // --- 1. the position line -------------------------------------------
        // "Concept 3 of 24 in Fundamentals".  The module name comes from the
        // manifest, so it is the module the learner sees in the sidebar.
        var module_title = std::string()
        var mid = course.concepts.get_ptr(idx as size_t).module_id.copy()
        if(mid.size() > 0) {
            var mi : size_t = 0
            while(mi < course.modules.size()) {
                var m = course.modules.get_ptr(mi)
                if(m.id.equals(&mid)) { module_title = m.title.copy() }
                mi = mi + 1
            }
        }
        // The replacement INCLUDES the span wrapper.  The sentinel is the whole
        // empty element, so replacing it with bare text would strip the element
        // and leave "Concept 3 of 24 in Fundamentals" sitting unstyled between
        // two divs -- which is exactly what the first version did, and it is
        // invisible in a status code and obvious on the page.
        var where_text = string("<span class=\"ul-progress-where\" id=\"ul-progress-where\">Concept ")
        where_text.append_string(&underlayer_core::int_to_string(idx + 1))
        where_text.append_view(" of ")
        where_text.append_string(&underlayer_core::int_to_string(course.concepts.size() as i64))
        if(module_title.size() > 0) {
            where_text.append_view(" in ")
            var mt_esc = underlayer_core::html_escape(&module_title)
            where_text.append_view(mt_esc.to_view())
        }
        where_text.append_view("</span>")
        var carried = patch_once(&src0, string_view("<span class=\"ul-progress-where\" id=\"ul-progress-where\"></span>"), &where_text)

        // --- 2. previous ----------------------------------------------------
        //
        // The FIRST concept of a course gets no previous link at all: the
        // anchor keeps its `hidden` attribute rather than pointing at the page
        // the reader is already on, which would make "Previous" reload the
        // current lesson.
        if(idx > 0) {
            var prev_concept = course.concepts.get_ptr((idx - 1) as size_t).id.copy()
            var prev_url = string("/courses/")
            prev_url.append_view(c_esc.to_view())
            prev_url.append_view("/lessons/")
            var p_esc = underlayer_core::html_escape(&prev_concept)
            prev_url.append_view(p_esc.to_view())

            var prev_title = course.concepts.get_ptr((idx - 1) as size_t).title.copy()
            var pt_esc = underlayer_core::html_escape(&prev_title)
            var prev_anchor = string("<a class=\"ul-step\" id=\"ul-prev\" rel=\"prev\" href=\"")
            prev_anchor.append_view(prev_url.to_view())
            prev_anchor.append_view("\">Previous: ")
            prev_anchor.append_view(pt_esc.to_view())
            prev_anchor.append_view("</a>")
            var with_prev_anchor = patch_once(&carried, string_view("<a class=\"ul-step\" id=\"ul-prev\" rel=\"prev\" hidden>Previous</a>"), &prev_anchor)

            var prev_link = string("<link rel=\"prev\" href=\"")
            prev_link.append_view(prev_url.to_view())
            prev_link.append_view("\">")
            var with_prev_link = patch_once(&with_prev_anchor, string_view("<link rel=\"prev\" href=\"\">"), &prev_link)
            carried = with_prev_link
        }

        // --- 3. next --------------------------------------------------------
        // The LAST concept gets no next link, for the same reason.
        if((idx as size_t) + 1 < course.concepts.size()) {
            var next_concept = course.concepts.get_ptr((idx + 1) as size_t).id.copy()
            var next_url = string("/courses/")
            next_url.append_view(c_esc.to_view())
            next_url.append_view("/lessons/")
            var n_esc = underlayer_core::html_escape(&next_concept)
            next_url.append_view(n_esc.to_view())

            var next_title = course.concepts.get_ptr((idx + 1) as size_t).title.copy()
            var nt_esc = underlayer_core::html_escape(&next_title)
            var next_anchor = string("<a class=\"ul-step\" id=\"ul-next\" rel=\"next\" href=\"")
            next_anchor.append_view(next_url.to_view())
            next_anchor.append_view("\">Next: ")
            next_anchor.append_view(nt_esc.to_view())
            next_anchor.append_view("</a>")
            var with_next_anchor = patch_once(&carried, string_view("<a class=\"ul-step\" id=\"ul-next\" rel=\"next\" hidden>Next</a>"), &next_anchor)

            var next_link = string("<link rel=\"next\" href=\"")
            next_link.append_view(next_url.to_view())
            next_link.append_view("\">")
            var final_out = patch_once(&with_next_anchor, string_view("<link rel=\"next\" href=\"\">"), &next_link)
            return final_out
        }

        return carried
    }

}