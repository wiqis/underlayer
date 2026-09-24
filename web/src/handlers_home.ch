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

        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <button class="hamburger" onclick="document.querySelector('.nav-links').classList.toggle('open')" aria-label="Toggle menu">
                        <span class="hamburger-line"></span>
                        <span class="hamburger-line"></span>
                        <span class="hamburger-line"></span>
                    </button>
                <div class="nav-links">
                    <a href="/" class="nav-link active">Home</a>
                    <a href="/courses/elf" class="nav-link">Courses</a>
                    <a href="/dashboard" class="nav-link">Dashboard</a>
                    <a href="/review" class="nav-link">Review</a>
                    <a href="/progress" class="nav-link">Progress</a>
                    <a href="/bookmarks" class="nav-link">Bookmarks</a>
                    <a href="/notes" class="nav-link">Notes</a>
                    <a href="/study-plans" class="nav-link">Planner</a>
                    <a href="/achievements" class="nav-link">Achievements</a>
                    <a href="/streaks" class="nav-link">Streaks</a>
                    <a href="/notifications" class="nav-link">Alerts</a>
                    <a href="/certificates" class="nav-link">Certificates</a>
                </div>
                    <div class="nav-right">
                        <button class="search-trigger" onclick="openSearch()" aria-label="Search (Ctrl+K)">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
                        </button>
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">☀️</span>
                            <span class="theme-icon-dark">🌙</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="search-modal" id="search-modal">
                <div class="search-backdrop" onclick="closeSearch()"></div>
                <div class="search-dialog">
                    <input type="text" id="search-input" class="search-input" placeholder="Search concepts..." oninput="doSearch(this.value)" />
                    <div class="search-results" id="search-results"></div>
                    <div class="search-hint">Press Escape to close</div>
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
                        <a href="/courses/elf" class="action-card">
                            <h3>Continue Learning</h3>
                            <p>Pick up where you left off in the ELF course.</p>
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

        send_page(res, &raw page)
    }

}
