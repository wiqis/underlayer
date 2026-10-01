// underlayer_web — GET /search: concept search.
//
// SERVER-RENDERED RESULTS, NOT A FETCH.  The obvious implementation is the one
// this codebase uses everywhere else: render an empty shell, fetch
// /api/courses from JavaScript, fill a grid.  It was rejected here for a
// specific reason.  Every other page on the platform is a place you can GET to
// and read; search is the page you arrive at when you already know what you
// are looking for and want it now, and the collection's lesson pages carry
// ?q= nothing and cannot.  A plain GET form with server-rendered results
// works with JavaScript off, is shareable by URL, is the page the browser can
// back out of, and needs no API round trip to be correct.
//
// The endpoint still exists and is the same code path -- `search_concepts()`
// in search_walk.ch serves both the page and GET /api/search/concepts -- so
// the two cannot disagree about what a query means.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func render_search_page(courses_dir : &string, query : &string) : string {
        var courses = underlayer_repository::list_courses(courses_dir)
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Search — Underlayer"))

        // Trimmed FIRST, then tested.  The order was the other way round, so
        // /search?q=%20%20%20 reported "Nothing in 398 concepts matches " with
        // an empty bold query in it -- a page telling a reader their blank
        // search failed, which is both true and useless.
        var q = trim_start(query)
        q = trim_end(&q)
        var has_query = q.size() > 0
        var q_esc = underlayer_core::html_escape(&q)

        #html {
            {render_nav_bar(&mut page)}
        }

        #html {
            <main class="container" id="main-content">
                <header class="page-head">
                    <h1>Search</h1>
                    <p class="lede">Searches every concept title, description and module name in the collection. 398 concepts is too many to browse and not too many to search.</p>
                </header>
                <form class="search-form" method="get" action="/search" role="search">
                    <label class="visually-hidden" for="q">Search concepts</label>
                    <input type="search" id="q" name="q" value={q_esc} placeholder="relro, cmpxchg, satp, chained fixups, LEB128..." autocomplete="off" autofocus />
                    <button type="submit" class="btn btn-primary">Search</button>
                </form>
                <section class="results" aria-live="polite">
                    {render_search_results(&courses, &q, has_query, &mut page)}
                </section>
            </main>
        }

        render_search_css(&mut page)
        render_index_js(&mut page)

        return page.toString()
    }

    public func render_search_results(courses : &vector<Course>, query : &string, has_query : bool, page : &mut HtmlPage) {
        if(!has_query) {
            #html {
                <div class="empty-state">
                    <p>Type a word, a register name, a flag, a structure name or a number.</p>
                    <p class="empty-hint">The descriptions carry the findings, so words like <code>relro</code>, <code>cmpxchg</code>, <code>satp</code>, <code>auth</code> and <code>0x7f</code> all find something. Searching is case-insensitive.</p>
                    <p class="empty-hint">If you are looking for a course rather than a lesson, <a href="/courses">browse the course index</a>, or pick an order from <a href="/learning-path">the learning path</a>.</p>
                </div>
            }
            return
        }
        var hits = search_concepts(courses, query)
        var total = hits.size() as int
        var searched : int = 0
        var ci : size_t = 0
        while(ci < courses.size()) {
            var c = courses.get_ptr(ci)
            searched = searched + c.concepts.size() as int
            ci = ci + 1
        }
        var q_esc = underlayer_core::html_escape(query)
        if(total == 0) {
            #html {
                <div class="empty-state">
                    <p class="no-hits">Nothing in {searched} concepts matches <strong>{q_esc}</strong>.</p>
                    <p class="empty-hint">Search is a case-insensitive substring match over concept titles, descriptions, module names and course titles. A shorter word is worth trying &mdash; and <a href="/courses">the index lists every concept</a> if you would rather browse.</p>
                </div>
            }
            return
        }
        var shown = total
        var truncated = false
        if(shown > SEARCH_RESULT_LIMIT) {
            shown = SEARCH_RESULT_LIMIT
            truncated = true
        }
        var count_line = string("Found ")
        var tn = underlayer_core::int_to_string(total as i64)
        count_line.append_string(&tn)
        count_line.append_view(string_view(" of "))
        var sc = underlayer_core::int_to_string(searched as i64)
        count_line.append_string(&sc)
        count_line.append_view(string_view(" concepts for "))
        count_line.append_string(query)
        count_line.append_view(string_view("."))
        var count_esc = underlayer_core::html_escape(&count_line)
        #html {
            <p class="result-count">{count_esc}</p>
        }
        if(truncated) {
            var trunc = string("Showing the first ")
            var sn = underlayer_core::int_to_string(shown as i64)
            trunc.append_string(&sn)
            trunc.append_view(string_view(" of "))
            var tn2 = underlayer_core::int_to_string(total as i64)
            trunc.append_string(&tn2)
            trunc.append_view(string_view(", best matches first. Narrow the query to see the rest."))
            var trunc_esc = underlayer_core::html_escape(&trunc)
            #html {
                <p class="result-truncated">{trunc_esc}</p>
            }
        }
        #html {
            <ul class="result-list">
                {render_hits(&hits, shown, page)}
            </ul>
        }
    }

    public func render_hits(hits : &vector<SearchHit>, shown : int, page : &mut HtmlPage) {
        var i : size_t = 0
        while(i < hits.size()) {
            if(i >= shown as size_t) { break }
            var hit = hits.get_ptr(i)
            var href_esc = underlayer_core::html_escape(&hit.href)
            var title_esc = underlayer_core::html_escape(&hit.concept_title)
            var course_esc = underlayer_core::html_escape(&hit.course_title)
            var module_esc = underlayer_core::html_escape(&hit.module_title)
            var snip_esc = underlayer_core::html_escape(&hit.concept_description)
            var field_esc = underlayer_core::html_escape(&hit.matched_field)
            #html {
                <li class="result">
                    <div class="result-head">
                        <a class="result-title" href={href_esc}>{title_esc}</a>
                        <span class="result-course">{course_esc}</span>
                    </div>
                    <p class="result-snippet">{snip_esc}</p>
                    <div class="result-meta"><span class="matched">{field_esc}</span><span class="result-module">{module_esc}</span></div>
                </li>
            }
            i = i + 1
        }
    }

}