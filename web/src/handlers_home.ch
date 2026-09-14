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
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link active">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                    </div>
                    <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                        <span class="theme-icon-light">☀️</span>
                        <span class="theme-icon-dark">🌙</span>
                    </button>
                </div>
            </div>

            <div class="hero">
                <div class="hero-inner">
                    <h1>Learn Things Deeply.</h1>
                    <p>Master complex technical subjects through structured learning, spaced repetition, and active recall. Every concept is taught from first principles, verified against authoritative sources, and tested until it sticks.</p>
                </div>
            </div>

            <div class="container">
                <div class="section">
                    <h2>Available Courses</h2>
                    <div class="course-grid">
                        <div class="course-card">
                            <div class="course-badge">8 Modules</div>
                            <h3>Executable and Linkable Format</h3>
                            <p>A deep dive into the ELF binary format - headers, sections, segments, symbols, relocations, and dynamic linking.</p>
                            <div class="course-stats">
                                <span>24 Lessons</span>
                                <span>Intermediate</span>
                            </div>
                            <a href="/courses/elf" class="btn btn-primary">Start Learning</a>
                        </div>
                    </div>
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

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            a { color: hsl(217 91% 60%); text-decoration: none; }
            a:hover { text-decoration: underline; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; gap: 1.5rem; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
            .hero { background: linear-gradient(135deg, hsl(213 60% 24%) 0%, hsl(217 91% 60%) 100%); color: white; padding: 4rem 2rem; }
            .hero-inner { max-width: 800px; margin: 0 auto; text-align: center; }
            .hero h1 { font-size: 2.5rem; margin-bottom: 1rem; font-weight: 700; }
            .hero p { font-size: 1.1rem; opacity: 0.9; line-height: 1.7; max-width: 600px; margin: 0 auto; }
            .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
            .section { margin-bottom: 3rem; }
            .section h2 { font-size: 1.5rem; margin-bottom: 1.5rem; color: hsl(var(--foreground)); }
            .course-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 1.5rem; }
            .course-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; transition: box-shadow 0.2s; }
            .course-card:hover { box-shadow: 0 4px 12px hsl(var(--shadow)); }
            .course-badge { display: inline-block; padding: 0.25rem 0.75rem; background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); border-radius: 9999px; font-size: 0.8rem; font-weight: 500; margin-bottom: 1rem; }
            .course-card h3 { font-size: 1.25rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .course-card p { color: hsl(var(--muted-foreground)); margin-bottom: 1rem; font-size: 0.95rem; }
            .course-stats { display: flex; gap: 1rem; margin-bottom: 1rem; font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border-radius: 8px; font-weight: 500; font-size: 0.9rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            .feature-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1.5rem; }
            .feature-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .feature-icon { width: 40px; height: 40px; background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 1.1rem; margin-bottom: 1rem; }
            .feature-card h3 { font-size: 1.1rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .feature-card p { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .action-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1rem; }
            .action-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; text-decoration: none; transition: all 0.15s; }
            .action-card:hover { border-color: hsl(217 91% 60%); box-shadow: 0 2px 8px hsl(217 91% 60% / 20%); text-decoration: none; }
            .action-card h3 { font-size: 1rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .action-card p { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin: 0; }
        }

        #js {
            function getTheme() {
                var saved = localStorage.getItem('theme');
                if (saved) return saved;
                return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            }
            function setTheme(theme) {
                document.documentElement.classList.toggle('dark', theme === 'dark');
                localStorage.setItem('theme', theme);
            }
            function toggleTheme() {
                var current = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
                setTheme(current === 'dark' ? 'light' : 'dark');
            }
            setTheme(getTheme());
        }

        send_page(res, &raw page)
    }

}
