// underlayer_web — GET /search: faceted, paginated, server-rendered concept search.
//
// SERVER-RENDERED RESULTS, NOT A FETCH.  Search is the page you arrive at when
// you already know what you are looking for and want it now.  A plain GET form
// with server-rendered results works with JavaScript off, is shareable by URL,
// is the page the browser can back out of, and needs no API round trip.
//
// G7 adds facets and pagination without changing that contract: every facet
// is a named query parameter, every page is a stable URL, and the paginator
// rebuilds the whole query.  The 25-result slice is chosen on the server, so
// all `byte` hits are reachable in five links with no client-side state.
//
// The endpoint /api/search/concepts is a different shape and a different
// contract.  This page and that endpoint share `search_concepts()` so they
// cannot disagree about what a query means, but the page never calls it.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func render_search_page(page : &mut HtmlPage, courses_dir : &string,
                                   filters : &SearchFilters, completed : &vector<string>,
                                   due : &vector<string>, signed_in : bool) {
        var courses = underlayer_repository::list_courses(courses_dir)
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var seo_title = string("Search — Underlayer")
        var seo_desc = seo_desc_search()
        var seo_path = string("/search")
        var seo_ld = string()
        append_seo_head(page, &seo_title, &seo_desc, &seo_path, &seo_ld)

        var concept_total = 0
        var ci : size_t = 0
        while(ci < courses.size()) {
            concept_total = concept_total + courses.at_ref(ci).concepts.size() as int
            ci = ci + 1
        }
        var total_text = underlayer_core::int_to_string(concept_total as i64)
        var lede = string("Searches every concept title, description and module name in the collection. ")
        lede.append_string(&total_text)
        lede.append_view(string_view(" concepts is too many to browse and not too many to search."))
        var q = trim_start(&filters.q)
        q = trim_end(&q)
        var has_query = q.size() > 0
        var q_esc = underlayer_core::html_escape(&q)
        var course_esc = underlayer_core::html_escape(&filters.course)
        var module_esc = underlayer_core::html_escape(&filters.module)
        var status_esc = underlayer_core::html_escape(&filters.status)
        var minutes_esc = underlayer_core::html_escape(&filters.minutes)
        var diff_esc = underlayer_core::html_escape(&filters.difficulty)

        #html {
            {render_nav_bar(page)}
        }

        #html {
            <main class="container" id="main-content">
                <header class="page-head">
                    <h1>Search</h1>
                    <p class="lede">{lede}</p>
                </header>
                <form class="search-form" method="get" action="/search" role="search" data-difficulty={diff_esc} data-minutes={minutes_esc} data-status={status_esc}>
                    <label class="visually-hidden" for="q">Search concepts</label>
                    <input type="search" id="q" name="q" value={q_esc} placeholder="relro, cmpxchg, satp, chained fixups, LEB128..." autocomplete="off" autofocus />
                    <label for="course-filter">Course</label>
                    <input type="text" id="course-filter" name="course" value={course_esc} placeholder="elf" autocomplete="off" />
                    <label for="module-filter">Module</label>
                    <input type="text" id="module-filter" name="module" value={module_esc} placeholder="program headers" autocomplete="off" />
                    <label for="difficulty-filter">Difficulty</label>
                    <select id="difficulty-filter" name="difficulty">
                        <option value="">Any difficulty</option>
                        <option value="beginner">Beginner</option>
                        <option value="intermediate">Intermediate</option>
                        <option value="advanced">Advanced</option>
                    </select>
                    <label for="minutes-filter">At most minutes</label>
                    <select id="minutes-filter" name="minutes">
                        <option value="">Any length</option>
                        <option value="5">5 minutes or less</option>
                        <option value="10">10 minutes or less</option>
                        <option value="20">20 minutes or less</option>
                        <option value="30">30 minutes or less</option>
                    </select>
                    <label for="status-filter">My progress</label>
                    <select id="status-filter" name="status">
                        <option value="">Any progress</option>
                        <option value="completed">Completed by me</option>
                        <option value="review-due">Due for review</option>
                    </select>
                    <button type="submit" class="btn btn-primary">Search</button>
                </form>
                <section class="results" aria-live="polite">
                    {render_search_results(&courses, &q, has_query, page, filters, completed, due, signed_in)}
                </section>
                {render_search_pager(page, filters, filtered_total(&courses, filters, completed, due, signed_in))}
            </main>
        }

        render_search_css(page)
        render_index_js(page)
        render_search_filter_js(page, filters)
    }

    // The filtered count is used twice: in the "Found N" line inside the
    // results renderer and in the pager. One function, one answer.
    public func filtered_total(courses : &vector<Course>, filters : &SearchFilters,
                               completed : &vector<string>, due : &vector<string>, signed_in : bool) : int {
        var hits = search_concepts(courses, &filters.q)
        var filtered = apply_search_filters(&hits, courses, filters, completed, due, signed_in)
        return filtered.size() as int
    }

    // Selects are restored from data-* attributes on the form. This is the
    // only JS on the page; results, counts and paginator links are all in the
    // served HTML and work with JS off.
    public func render_search_filter_js(page : &mut HtmlPage, filters : &SearchFilters) {
        #js {
            (function() {
                var form = document.querySelector('form.search-form');
                if(!form) { return; }
                var ids = ['difficulty-filter', 'minutes-filter', 'status-filter'];
                var keys = ['difficulty', 'minutes', 'status'];
                for(var i = 0; i < ids.length; i++) {
                    var el = document.getElementById(ids[i]);
                    var want = form.getAttribute('data-' + keys[i]) || '';
                    if(el && want) { el.value = want; }
                }
            })();
        }
    }

    public func render_search_results(courses : &vector<Course>, query : &string, has_query : bool,
                                      page : &mut HtmlPage, filters : &SearchFilters,
                                      completed : &vector<string>, due : &vector<string>, signed_in : bool) {
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
        var total_all = hits.size() as int
        var filtered = apply_search_filters(&hits, courses, filters, completed, due, signed_in)
        var total = filtered.size() as int
        var searched : int = 0
        var ci : size_t = 0
        while(ci < courses.size()) {
            var c = courses.at_ref(ci)
            searched = searched + c.concepts.size() as int
            ci = ci + 1
        }
        var q_esc = underlayer_core::html_escape(query)
        // The count is emitted even for zero hits: a filtered page that drops
        // its count is a page a checker (or a reader) cannot distinguish from
        // a broken query.
        var zero_count = string("Found 0 of ")
        var zs = underlayer_core::int_to_string(searched as i64)
        zero_count.append_string(&zs)
        zero_count.append_view(string_view(" concepts with these filters for "))
        zero_count.append_string(query)
        zero_count.append('.')
        var zero_esc = underlayer_core::html_escape(&zero_count)
        if(filters.status.size() > 0 && !signed_in) {
            #html {
                <p class="result-note">Sign in to filter by your own completed concepts and review queue.</p>
            }
        }
        if(total == 0) {
            #html {
                <p class="result-count">{zero_esc}</p>
            }
            #html {
                <div class="empty-state">
                    <p class="no-hits">Nothing in {searched} concepts matches <strong>{q_esc}</strong> with these filters.</p>
                    <p class="empty-hint">Search is a case-insensitive substring match over concept titles, descriptions, module names and course titles. A shorter word is worth trying &mdash; and <a href="/search?q=byte">the byte search</a> shows every result, 25 at a time.</p>
                </div>
            }
            return
        }
        var count_line = string("Found ")
        var tn = underlayer_core::int_to_string(total as i64)
        count_line.append_string(&tn)
        if(total != total_all) {
            count_line.append_view(string_view(" of "))
            var ta = underlayer_core::int_to_string(total_all as i64)
            count_line.append_string(&ta)
        }
        count_line.append_view(string_view(" of "))
        var scn = underlayer_core::int_to_string(searched as i64)
        count_line.append_string(&scn)
        count_line.append_view(string_view(" concepts for "))
        count_line.append_string(query)
        count_line.append_view(string_view("."))
        var count_esc = underlayer_core::html_escape(&count_line)
        #html {
            <p class="result-count">{count_esc}</p>
        }
        if(filters.status.size() > 0 && !signed_in) {
            #html {
                <p class="result-note">Sign in to filter by your own completed concepts and review queue.</p>
            }
        }
        var start = (filters.page - 1) * SEARCH_PAGE_SIZE
        if(start < 0) { start = 0 }
        var stop = start + SEARCH_PAGE_SIZE
        if(stop > total) { stop = total }
        #html {
            <ul class="result-list">
                {render_hits(&filtered, start, stop, page)}
            </ul>
        }
    }

    // One `<li>` per hit, emitted by a loop OUTSIDE the #html macro (the
    // html_cbi @{} statement blocks are broken; see docs/implementation-gaps.md).
    public func render_hits(hits : &vector<SearchHit>, start : int, stop : int, page : &mut HtmlPage) {
        var i = start
        while(i < stop) {
            var hit = hits.at_ref(i as size_t)
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

    // Every page link is a complete GET URL. `?page=1` is omitted by
    // search_url(), so the first page and the bare query are the same URL.
    public func render_search_pager(page : &mut HtmlPage, filters : &SearchFilters, total : int) {
        if(filters.q.size() == 0 || total <= SEARCH_PAGE_SIZE) { return }
        var pages = total / SEARCH_PAGE_SIZE
        if(total % SEARCH_PAGE_SIZE > 0) { pages = pages + 1 }
        #html {
            <nav class="pager" aria-label="Search result pages">
                {render_pager_links(page, filters, pages)}
            </nav>
        }
    }

    func render_pager_links(page : &mut HtmlPage, filters : &SearchFilters, pages : int) {
        var i = 1
        while(i <= pages) {
            var href = search_url(filters, i)
            var href_esc = underlayer_core::html_escape(&href)
            var label = underlayer_core::int_to_string(i as i64)
            var rel = string("")
            if(i == filters.page) { rel = string(" page") }
            else if(i == filters.page + 1) { rel = string(" next") }
            else if(i == filters.page - 1) { rel = string(" prev") }
            var cls_esc = underlayer_core::html_escape(&rel)
            #html {
                <a class="pager-link" href={href_esc} data-page={label} data-rel={cls_esc}>{label}</a>
            }
            i = i + 1
        }
    }

}
