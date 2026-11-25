// underlayer_web — GET /learning-path: the ONE ordered view of the collection.
//
// /learning-path is not a second directory and it does not repeat the route
// essays that used to sit on /courses.  It is a single ordered list: three
// collapsible routes, each step reduced to position, title, one sentence of
// "why here" and time, with the full argument and prerequisites on demand.
//
// Every count is read from the manifests on this render -- the same source
// /api/courses, /courses and the home card use -- so no page can quote a stale
// "398 concepts" after the catalogue changes.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func render_learning_path_page_index(page : &mut HtmlPage, courses_dir : &string) {
        var courses = underlayer_repository::list_courses(courses_dir)
        var routes = build_routes()
        var chk = verify_route_order(&courses, &routes)
        var lesson_total = 0
        var ci : size_t = 0
        while(ci < courses.size()) {
            lesson_total = lesson_total + courses.at_ref(ci).concepts.size() as int
            ci = ci + 1
        }
        var tally = string()
        var course_count_text = underlayer_core::int_to_string(courses.size() as i64)
        tally.append_view(course_count_text.to_view())
        tally.append_view(string_view(" courses  |  "))
        var lesson_count_text = underlayer_core::int_to_string(lesson_total as i64)
        tally.append_view(lesson_count_text.to_view())
        tally.append_view(string_view(" lessons  |  one ordered route"))
        var start = start_here_href()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Learning Path — Underlayer"))

        #html {
            {render_nav_bar(page)}
        }

        #html {
            <main class="container" id="main-content">
                <header class="page-head">
                    <h1>Your learning path</h1>
                    <p class="lede">Follow the route in order. Each step says why it sits where it does; open “Why is this here?” when you want the full reasoning.</p>
                    <p class="tally">{tally}</p>
                    <p class="path-start"><a class="btn btn-primary" href={start}>Start at step 1</a></p>
                </header>

                <section class="routes" aria-label="The three ordered routes">
                    <div class="route-grid">
                        {render_all_routes(&routes, &courses, page)}
                    </div>
                    {render_route_check(&chk, page)}
                </section>
            </main>
        }

        render_index_css(page)
        render_index_js(page)
    }

}
