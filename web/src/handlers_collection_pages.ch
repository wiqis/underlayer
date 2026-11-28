// underlayer_web — HTTP entry points for the three collection-level pages.
//
// Three handlers, one file, because they are three lines of glue each and the
// interesting part of all three is in pages_courses.ch, pages_path.ch and
// pages_search.ch.  Splitting them into three files would be three files whose
// entire content is a signature and a call.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // Three per-request pages, kept as endpoints rather than `app.live` routes.
    //
    // MEASURED: an `app.live` render attaches the page to the site's FROZEN asset
    // sink, so the page's `#css` blocks and the component theme are written to a
    // sink that is already closed — the served home page came back with no
    // <style> and no <link>, i.e. unstyled. These pages carry their own large
    // stylesheets, so the correct shape for them is a full response, cached
    // `no-cache` with an ETag and gzipped by `deliver`.
    public func handle_courses_page(courses_dir : &string, req : &http::Request) : http::Response {
        var budget = read_query_param(req, string("budget"))
        var page = HtmlPage()
        render_courses_page(&mut page, courses_dir, &budget)
        var html = page.toString()
        return send_html(&html)
    }

    public func handle_learning_path_index(courses_dir : &string, req : &http::Request) : http::Response {
        var page = HtmlPage()
        render_learning_path_page_index(&mut page, courses_dir)
        var html = page.toString()
        return send_html(&html)
    }

    // Kept for the shipped route signature. The teacher-facing coordinator
    // registration (see the final report) can switch /search to the db-aware
    // variant to enable the completed / review-due facets on a live session.
    public func handle_search_page(courses_dir : &string, req : &http::Request) : http::Response {
        return handle_search_page_db(null, courses_dir, req)
    }

    // G7: the only place a learner-specific facet is resolved. The two id
    // lists are built from this learner's own rows, never from the demo
    // learner, and are empty for a signed-out reader.
    public func handle_search_page_db(db : *DbClient, courses_dir : &string, req : &http::Request) : http::Response {
        var filters = parse_search_filters(req)
        var completed = vector<string>()
        var due = vector<string>()
        var signed_in = false
        if(db == null) {
            // No db handle on the legacy route: status facets are refused by
            // the renderer with an honest "sign in" note.
        } else {
            var learner_id = auth_get_learner_id(db, req)
            if(learner_id.size() > 0) {
                signed_in = true
                var courses = underlayer_repository::list_courses(courses_dir)
                var ci : size_t = 0
                while(ci < courses.size()) {
                    var course = courses.at_ref(ci)
                    var cid = course.id.copy()
                    var states = underlayer_repository::get_all_concept_states(db, &learner_id, &cid)
                    var si : size_t = 0
                    while(si < states.size()) {
                        var state = states.at_ref(si)
                        var mastered = string("mastered")
                        if(state.status.equals(&mastered)) {
                            var concept_id = state.concept_id.copy()
                            if(!id_in(&completed, &concept_id)) { completed.push(concept_id) }
                        }
                        si = si + 1
                    }
                    var items = underlayer_repository::get_due_review_items(db, &learner_id, &cid, 1000)
                    var ri : size_t = 0
                    while(ri < items.size()) {
                        var item = items.at_ref(ri)
                        var concept_id2 = item.concept_id.copy()
                        if(!id_in(&due, &concept_id2)) { due.push(concept_id2) }
                        ri = ri + 1
                    }
                    ci = ci + 1
                }
            }
        }
        var page = HtmlPage()
        render_search_page(&mut page, courses_dir, &filters, &completed, &due, signed_in)
        var html = page.toString()
        return send_html(&html)
    }

}
