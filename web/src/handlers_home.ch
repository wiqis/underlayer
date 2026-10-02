// underlayer_web — Health and home page handlers.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_health(req : &http::Request, res : *mut http::ResponseWriter) {
        var body = std::string("{\"status\": \"ok\", \"version\": \"0.1.0\"}")
        send_json_str(res, &raw body)
    }

    public func handle_home(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Underlayer - Learn Things Deeply")
        page.appendTitle(&title)
        // The shared session helper and the onboarding gate -- see pages_gate.ch.
        render_session_js(&mut page)

        #html {
            {render_nav_bar(&mut page)}
            {render_onboarding_gate(&mut page)}

            <div class="search-modal" id="search-modal">
                <div class="search-backdrop" onclick="closeSearch()"></div>
                <div class="search-dialog">
                    <input type="text" id="search-input" class="search-input" placeholder="Search all 398 concepts..." oninput="doSearch(this.value)" />
                    <div class="search-results" id="search-results"></div>
                    <div class="search-hint">Esc to close &middot; <a href="/search">full results page</a></div>
                </div>
            </div>

            <div class="hero">
                <div class="hero-inner">
                    <h1>Learn Things Deeply.</h1>
                    <p>Master complex technical subjects through structured learning, spaced repetition, and active recall. Every concept is taught from first principles, verified against authoritative sources, and tested until it sticks.</p>
                </div>
            </div>

            <div class="container" id="main-content">
                <div class="section">
                    <h2>Available Courses</h2>
                    <div class="course-grid" id="course-grid" aria-live="polite">
                        <div class="course-loading">Loading courses…</div>
                    </div>
                    <noscript>
                        <p class="course-loading">Enable JavaScript to list courses, or open <a href="/api/courses">/api/courses</a>.</p>
                    </noscript>
                </div>

                <div class="section">
                    <h2>How It Works</h2>
                    <div class="feature-grid">
                        <div class="feature-card">
                            <div class="feature-icon">1</div>
                            <h3>Learn</h3>
                            <p>Read structured lessons that build from simple models to real-world detail. Every concept has a Why, Model, Detail, Example, and Connect section.</p>
                        </div>
                        <div class="feature-card">
                            <div class="feature-icon">2</div>
                            <h3>Practice</h3>
                            <p>Test your understanding with targeted exercises. Multiple choice, recall, fill-in-the-blank, and apply questions with progressive hints.</p>
                        </div>
                        <div class="feature-card">
                            <div class="feature-icon">3</div>
                            <h3>Review</h3>
                            <p>Spaced repetition (FSRS v4) schedules reviews when you're about to forget. Never lose knowledge again. 10 review modes from quick to deep.</p>
                        </div>
                        <div class="feature-card">
                            <div class="feature-icon">4</div>
                            <h3>Track</h3>
                            <p>Monitor your progress, knowledge health, and weaknesses. See what you've mastered, what needs work, and where to focus next.</p>
                        </div>
                    </div>
                </div>

                <div class="section">
                    <h2>Quick Actions</h2>
                    <div class="action-grid">
                        <a href="/review" class="action-card">
                            <h3>Start Review</h3>
                            <p>Review concepts you're about to forget. Spaced repetition keeps knowledge fresh.</p>
                        </a>
                        <a href="/courses" class="action-card">
                            <h3>Browse Courses</h3>
                            <p>All 34 courses and every concept in them, with three orders if you do not know where to start.</p>
                        </a>
                        <a href="/learning-path" class="action-card">
                            <h3>Follow a Path</h3>
                            <p>Three orders through the collection, each step carrying the reason it sits there.</p>
                        </a>
                        <a href="/dashboard" class="action-card">
                            <h3>View Dashboard</h3>
                            <p>See your learning stats, health score, and due items at a glance.</p>
                        </a>
                        <a href="/progress" class="action-card">
                            <h3>Track Progress</h3>
                            <p>See how far you've come and what's left to master.</p>
                        </a>
                    </div>
                </div>
            </div>
        }

        render_home_css(&mut page)
        render_home_js(&mut page)
        render_home_search_js(&mut page)

        send_page(res, &raw page)
    }

}
