// underlayer_web — GET /courses: the course index.
//
// This page is the fix for the collection's worst dead link.  `/courses` was
// linked 42 times across 32 files -- every lesson's back-link and the course
// landing nav -- and it did not exist.  34 courses and 398 concepts with no
// index is not a fixed 404, though, so the page carries the three named
// routes from routes_*.ch above the full catalogue, and prints the count that
// says the ordering respects the manifests' declared prerequisites.
//
// Everything on the page is server-rendered.  Not because client-side
// rendering is wrong -- it is the pattern most of this codebase uses for
// dynamic lists -- but because the page you arrive at when you cannot find
// anything must not be blank without JavaScript.  See courses_index_render.ch
// for why the rows come from component functions rather than an `@{}` loop.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func total_minutes(cards : &vector<CatalogCard>) : int {
        var total = 0
        var i : size_t = 0
        while(i < cards.size()) {
            var card = cards.get_ptr(i)
            total = total + card.minutes
            i = i + 1
        }
        return total
    }

    public func total_concepts(cards : &vector<CatalogCard>) : int {
        var total = 0
        var i : size_t = 0
        while(i < cards.size()) {
            var card = cards.get_ptr(i)
            total = total + card.concepts
            i = i + 1
        }
        return total
    }

    public func render_courses_page(courses_dir : &string) : string {
        var courses = underlayer_repository::list_courses(courses_dir)
        var routes = build_routes()
        var chk = verify_route_order(&courses, &routes)
        var catalog = build_catalog(&courses, &routes)
        var claimed = route_orphans(&routes)
        var course_count = courses.size() as int

        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("All Courses — Underlayer"))

        var tally = string("The collection is ")
        var cc = underlayer_core::int_to_string(courses.size() as i64)
        tally.append_string(&cc)
        tally.append_view(string_view(" courses, "))
        var nc = underlayer_core::int_to_string(total_concepts(&catalog) as i64)
        tally.append_string(&nc)
        tally.append_view(string_view(" concepts, "))
        var tm = underlayer_core::int_to_string(total_minutes(&catalog) as i64)
        tally.append_string(&tm)
        tally.append_view(string_view(" minutes of material, every concept reachable from this page."))
        var tally_esc = underlayer_core::html_escape(&tally)

        #html {
            {render_nav_bar(&mut page)}
        }

        #html {
            <main class="container" id="main-content">
                <header class="page-head">
                    <h1>All courses</h1>
                    <p class="lede">Binary formats, linkers, instruction sets and compilers, taught from the bytes up. Read the routes below if you do not know where to start; the catalogue under them is every course, with its concepts one click away.</p>
                    <p class="tally">{tally_esc}</p>
                </header>

                <section class="routes" aria-labelledby="routes-head">
                    <h2 id="routes-head">Three ways through the collection</h2>
                    <p class="section-note">These are not difficulty tiers. Each one is an order, and each step says why it sits where it does. The three are meant to be walked in sequence: the second assumes the first, the third assumes both.</p>
                    <div class="route-grid">
                        {render_all_routes(&routes, &courses, &mut page)}
                    </div>
                    {render_route_check(&chk, &mut page)}
                    {render_orphan_note(&courses, &claimed, course_count, &mut page)}
                </section>

                <section class="catalogue" aria-labelledby="catalogue-head">
                    <div class="catalogue-head">
                        <h2 id="catalogue-head">Every course</h2>
                        <button class="expand-all" type="button" onclick="toggleAllConcepts()">Expand all concepts</button>
                    </div>
                    <p class="section-note">Every count on a card &mdash; modules, concepts, minutes, difficulty, importance &mdash; is read from that course's own manifest, not written down here. Expand a card for a direct link to each lesson in it.</p>
                    <div class="course-grid">
                        {render_all_cards(&catalog, &mut page)}
                    </div>
                </section>
            </main>
        }

        render_index_css(&mut page)
        render_index_js(&mut page)

        return page.toString()
    }

}