// underlayer_web — HTTP entry points for the three collection-level pages.
//
// Three handlers, one file, because they are three lines of glue each and the
// interesting part of all three is in pages_courses.ch, pages_path.ch and
// pages_search.ch.  Splitting them into three files would be three files whose
// entire content is a signature and a call.
using std::string

public namespace underlayer_web {

    // GET /courses — the index.  Every lesson's back-link points here, so it
    // is the most-requested page in the collection and was returning 404.
    public func handle_courses_page(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_courses_page(courses_dir)
        send_html(res, &raw html)
    }

    // GET /learning-path — the three routes in full.
    public func handle_learning_path_index(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_learning_path_page_index(courses_dir)
        send_html(res, &raw html)
    }

    // GET /search — concept search.  Results are server-rendered from the
    // `q` query parameter, so the page works with JavaScript disabled and the
    // URL is shareable.
    public func handle_search_page(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_key = string("q")
        var q_v = req.query.get(&q_key.to_view())
        var query = sv_to_string(&raw q_v)
        var html = render_search_page(courses_dir, &query)
        send_html(res, &raw html)
    }

}