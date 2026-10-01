// underlayer_web — The site nav bar, as one component.
//
// WHY THIS IS A COMPONENT AND NOT COPIED INTO EACH PAGE.  The nav is the
// thing that let `/courses` stay broken for so long: every page rendered a
// nav that looked finished, and the href in it went nowhere.  It is now one
// function, so a link cannot be right in one page and wrong in another, and
// tools/link_check.py checks every href in it on every run.
//
// Every item here is a real route.  There is no href="#" and no item pointing
// at a course because a course happens to be the only one with lessons: that
// is what the home page used to do with its "Courses" item, and it is why the
// dead `/courses` link was invisible -- the nav looked plausible either way.
using std::string

public namespace underlayer_web {

    public func render_nav_bar(page : &mut HtmlPage) {
        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses" class="nav-link active">Courses</a>
                        <a href="/learning-path" class="nav-link">Path</a>
                        <a href="/search" class="nav-link">Search</a>
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
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">&#9728;</span>
                            <span class="theme-icon-dark">&#9790;</span>
                        </button>
                    </div>
                </div>
            </div>
        }
    }

    // Theme init, shared so every page that offers the toggle behaves the
    // same way: saved choice first, then the OS preference.
    public func render_theme_js(page : &mut HtmlPage) {
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
    }

}