// underlayer_web — GET /courses: a compact, searchable course index.
//
// This page answers one question: "which course do I want?"  The ordered
// "where do I start?" question belongs to /learning-path, so the three route
// essays that used to sit above this grid were removed rather than repeated.
// Everything here is server-rendered -- a page you reach because you are lost
// must not be blank without JavaScript -- and the local search only hides rows
// that are already in the served HTML.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func total_minutes(cards : &vector<CatalogCard>) : int {
        var total = 0
        var i : size_t = 0
        while(i < cards.size()) {
            var card = cards.at_ref(i)
            total = total + card.minutes
            i = i + 1
        }
        return total
    }

    public func total_concepts(cards : &vector<CatalogCard>) : int {
        var total = 0
        var i : size_t = 0
        while(i < cards.size()) {
            var card = cards.at_ref(i)
            total = total + card.concepts
            i = i + 1
        }
        return total
    }

    // G7: the time-budget control is a GET to this SAME route, not a new page
    // and not a client-side filter. The three buckets partition all 33 courses.
    // We filter at render time rather than copy the card structs: CatalogCard
    // owns nested vectors and this compiler has no struct-wide `.copy()`.
    public func card_in_budget(card : &CatalogCard, budget : &string) : bool {
        if(budget.size() == 0) { return true }
        return budget_bucket(card.minutes).equals(budget)
    }

    func tally_of(cards : &vector<CatalogCard>, budget : &string, want_concepts : bool) : int {
        var sum = 0
        var i : size_t = 0
        while(i < cards.size()) {
            var card = cards.at_ref(i)
            if(card_in_budget(card, budget)) {
                if(want_concepts) { sum = sum + card.concepts }
                else { sum = sum + card.minutes }
            }
            i = i + 1
        }
        return sum
    }

    public func render_courses_page(page : &mut HtmlPage, courses_dir : &string, budget : &string) {
        var courses = underlayer_repository::list_courses(courses_dir)
        var routes = build_routes()
        var catalog = build_catalog(&courses, &routes)
        var shown_courses = 0
        var ci0 : size_t = 0
        while(ci0 < catalog.size()) {
            if(card_in_budget(catalog.at_ref(ci0), budget)) { shown_courses = shown_courses + 1 }
            ci0 = ci0 + 1
        }
        var tally = string()
        var shown = underlayer_core::int_to_string(shown_courses as i64)
        tally.append_string(&shown)
        tally.append_view(string_view(" of "))
        var cc = underlayer_core::int_to_string(courses.size() as i64)
        tally.append_string(&cc)
        tally.append_view(string_view(" courses, "))
        var nc = underlayer_core::int_to_string(tally_of(&catalog, budget, true) as i64)
        tally.append_string(&nc)
        tally.append_view(string_view(" lessons, "))
        var tm = underlayer_core::int_to_string(tally_of(&catalog, budget, false) as i64)
        tally.append_string(&tm)
        tally.append_view(string_view(" minutes in this view. Every course is one click from here."))
        var start = start_here_href()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var seo_title = string("All Courses — Underlayer")
        var seo_desc = seo_desc_courses()
        var seo_path = string("/courses")
        var seo_ld = string()
        append_seo_head(page, &seo_title, &seo_desc, &seo_path, &seo_ld)

        #html {
            {render_nav_bar(page)}
        }

        #html {
            <main class="container" id="main-content">
                <header class="page-head">
                    <h1>All courses</h1>
                    <p class="lede">Find the course you need, or follow one ordered route from the first lesson. Every count on this page comes from the manifests.</p>
                    <p class="tally">{tally}</p>
                    <p class="courses-actions"><a class="btn btn-primary" href={start}>Start at step 1</a> <a class="text-link" href="/learning-path">See the ordered path</a></p>
                    <div class="budget-control" role="group" aria-label="Choose a time budget">
                        <span>How much time have you got?</span>
                        <a href="/courses?budget=10">10 minutes</a>
                        <a href="/courses?budget=week">This week</a>
                        <a href="/courses?budget=deep">Deep dive</a>
                    </div>
                </header>

                <section class="catalogue" aria-labelledby="catalogue-head">
                    <h2 id="catalogue-head" class="visually-hidden">Course catalogue</h2>
                    <div class="catalogue-tools">
                        <label class="course-search-label" for="course-search">Find a course</label>
                        <input id="course-search" class="course-search" type="search" placeholder="Search by name or topic" autocomplete="off" />
                        <div class="course-filters" role="group" aria-label="Filter by level">
                            <button type="button" class="filter-chip is-active" data-filter="all" aria-pressed="true">All</button>
                            <button type="button" class="filter-chip" data-filter="beginner" aria-pressed="false">Beginner</button>
                            <button type="button" class="filter-chip" data-filter="intermediate" aria-pressed="false">Intermediate</button>
                            <button type="button" class="filter-chip" data-filter="advanced" aria-pressed="false">Advanced</button>
                        </div>
                        <p class="course-count" id="course-count" aria-live="polite"></p>
                    </div>
                    <div class="course-grid" id="course-grid">
                        {render_all_cards(&catalog, page, budget)}
                    </div>
                </section>
            </main>
        }

        render_index_css(page)
        render_index_js(page)
    }

}
