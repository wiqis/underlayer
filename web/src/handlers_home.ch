// underlayer_web — Health and home page handlers.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_health(req : &http::Request) : http::Response {
        var body = std::string("{\"status\": \"ok\", \"version\": \"0.1.0\"}")
        return send_json_str(&body)
    }

    // GET / -- a per-request page. It stays an endpoint rather than an
    // `app.live` route: see the note in handlers_collection_pages.ch.
    //
    // The home page answers exactly one question: what do I do next?  One
    // headline, one sentence, ONE primary action, one secondary text link,
    // and the card for the course that action opens.  The old 12-choice
    // dashboard (How It Works + six Quick Actions) competed with /courses and
    // /learning-path and is gone; the ordered view lives on /learning-path.
    public func handle_home(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string("Underlayer - Learn Things Deeply")
        var description = seo_desc_home()
        var canonical_path = std::string("/")
        var empty_ld = std::string()
        append_seo_head(&mut page, &title, &description, &canonical_path, &empty_ld)
        // The shared session helper and the onboarding gate -- see pages_gate.ch.
        render_session_js(&mut page)
        var start = start_here_href()

        #html {
            {render_nav_bar(&mut page)}
            {render_onboarding_gate(&mut page)}
            <div id="ul-home-config" data-start-here={start} hidden></div>

            <div class="search-modal" id="search-modal">
                <div class="search-backdrop" onclick="closeSearch()"></div>
                <div class="search-dialog">
                    <input type="text" id="search-input" class="search-input" placeholder="Search courses and lessons..." oninput="doSearch(this.value)" />
                    <div class="search-results" id="search-results"></div>
                    <div class="search-hint">Esc to close &middot; <a href="/search">full results page</a></div>
                </div>
            </div>

            <section class="home-hero" aria-labelledby="home-heading">
                <div class="home-hero-inner">
                    <p class="home-eyebrow">Underlayer</p>
                    <h1 id="home-heading">Learn one hard thing at a time.</h1>
                    <p class="home-lede">Start at the first lesson and follow a clear path through the collection — one idea, one action, and a reason for every step.</p>
                    <p class="home-actions"><a id="home-primary-cta" class="btn btn-primary" href={start}>Start the first lesson</a></p>
                    <p class="home-secondary"><a href="/courses">Browse all courses</a></p>
                </div>
            </section>

            <main class="container home-main" id="main-content">
                <section class="home-next" aria-labelledby="home-next-heading">
                    <h2 id="home-next-heading">Your next lesson</h2>
                    <article class="home-course-card">
                        <h3 id="home-course-title">Loading the first course…</h3>
                        <p class="home-course-meta" id="home-course-meta"></p>
                        <a id="home-course-cta" class="home-course-link" href={start}>Open the first lesson</a>
                    </article>
                </section>
            </main>
        }

        render_home_css(&mut page)
        render_home_js(&mut page)
        render_home_search_js(&mut page)
        return send_page(&page)
    }

}
