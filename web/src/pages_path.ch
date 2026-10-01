// underlayer_web — GET /learning-path: the three routes, in full.
//
// WHY THIS PAGE IS NOT THE PER-COURSE VISUALISATION.  There already is one:
// `/courses/:courseId/path`, wired to `handle_learning_path_page` in
// handlers_learning_path_viz.ch, showing one course's concepts against a
// learner's own progress.  That handler takes a course id, so it cannot serve
// a collection-level page, and the audit's "/learning-path is defined but
// never routed" was really that per-course handler being easy to mistake for a
// collection page.  This file is the collection page it was taken to be: the
// three orders, every step, every declared prerequisite, and the count that
// says the order is walkable.  The per-course pages are still reachable from
// each step as "dependency graph".
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func render_learning_path_page_index(courses_dir : &string) : string {
        var courses = underlayer_repository::list_courses(courses_dir)
        var routes = build_routes()
        var chk = verify_route_order(&courses, &routes)
        var claimed = route_orphans(&routes)
        var course_count = courses.size() as int

        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Learning Path — Underlayer"))

        #html {
            {render_nav_bar(&mut page)}
        }

        #html {
            <main class="container" id="main-content">
                <header class="page-head">
                    <h1>Learning path</h1>
                    <p class="lede">The collection in three orders. Each route is a sequence, not a tier: every step says why it sits where it does and which courses declare it a prerequisite. Walk them in order &mdash; the second assumes the first, the third assumes both.</p>
                    <p class="section-note">The orders come from two places, not from taste. The chain itself is the one <code>docs/course-mission.md</code> states the collection exists to serve. The order inside it is the order the <code>dependencies</code> field of each course's <code>manifest.json</code> admits &mdash; checked against the real manifests on every render, and the count is printed at the bottom of this page.</p>
                </header>

                <section class="routes">
                    <div class="route-grid">
                        {render_all_routes(&routes, &courses, &mut page)}
                    </div>
                    {render_route_check(&chk, &mut page)}
                    {render_orphan_note(&courses, &claimed, course_count, &mut page)}
                </section>

                <section class="catalogue">
                    <div class="catalogue-head">
                        <h2>Not sure where to start?</h2>
                        <a class="btn btn-primary" href="/courses">Browse all courses</a>
                    </div>
                    <p class="section-note">If you know which lesson you want rather than which course, search for it directly &mdash; 398 concepts is too many to browse but not to search.</p>
                    <p><a href="/search">Search all concepts &rarr;</a></p>
                </section>
            </main>
        }

        render_index_css(&mut page)
        render_index_js(&mut page)

        return page.toString()
    }

}