// underlayer_web — HTTP entry points for the three collection-level pages.
//
// Three handlers, one file, because they are three lines of glue each and the
// interesting part of all three is in pages_courses.ch, pages_path.ch and
// pages_search.ch.  Splitting them into three files would be three files whose
// entire content is a signature and a call.
using std::string

public namespace underlayer_web {

    // Three per-request pages, kept as endpoints rather than `app.live` routes.
    //
    // MEASURED: an `app.live` render attaches the page to the site's FROZEN asset
    // sink, so the page's `#css` blocks and the component theme are written to a
    // sink that is already closed â€” the served home page came back with no
    // <style> and no <link>, i.e. unstyled. These pages carry their own large
    // stylesheets, so the correct shape for them is a full response, cached
    // `no-cache` with an ETag and gzipped by `deliver`.
    public func handle_courses_page(courses_dir : &string, req : &http::Request) : http::Response {
        var page = HtmlPage()
        render_courses_page(&mut page, courses_dir)
        var html = page.toString()
        return send_html(&html)
    }

    public func handle_learning_path_index(courses_dir : &string, req : &http::Request) : http::Response {
        var page = HtmlPage()
        render_learning_path_page_index(&mut page, courses_dir)
        var html = page.toString()
        return send_html(&html)
    }

    public func handle_search_page(courses_dir : &string, req : &http::Request) : http::Response {
        var q_key = string("q")
        var q_v = sv_or_empty(req.query.get(std::str.make_view(q_key.to_view())))
        var query = sv_to_string(&q_v)
        var page = HtmlPage()
        render_search_page(&mut page, courses_dir, &query)
        var html = page.toString()
        return send_html(&html)
    }

}