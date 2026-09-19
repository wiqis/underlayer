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
                        <div class="course-card">
                            <div class="course-badge">5 Modules</div>
                            <h3>HAT — Higher Education Aptitude Test</h3>
                            <p>Preparation for the HEC Higher Education Aptitude Test, written for HAT-1 candidates in engineering, computing and the physical sciences: format and weightage, quantitative and verbal technique, analytical reasoning, and the technical foundations.</p>
                            <div class="course-stats">
                                <span>21 Lessons</span>
                                <span>Beginner</span>
                            </div>
                            <a href="/courses/hat" class="btn btn-primary">Start Learning</a>
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
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
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
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
            .hamburger { display: none; background: none; border: none; cursor: pointer; padding: 0.5rem; }
            .hamburger-line { display: block; width: 24px; height: 2px; background: hsl(var(--foreground)); margin: 4px 0; transition: all 0.3s; }
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
            .search-trigger { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; color: hsl(var(--muted-foreground)); display: flex; align-items: center; justify-content: center; }
            .search-trigger:hover { background: hsl(var(--accent)); color: hsl(var(--foreground)); }
            .search-modal { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1000; }
            .search-modal.open { display: flex; align-items: flex-start; justify-content: center; padding-top: 20vh; }
            .search-backdrop { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.5); }
            .search-dialog { position: relative; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; width: 90%; max-width: 500px; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3); overflow: hidden; }
            .search-input { width: 100%; padding: 1rem 1.25rem; border: none; background: transparent; font-size: 1rem; color: hsl(var(--foreground)); outline: none; }
            .search-input::placeholder { color: hsl(var(--muted-foreground)); }
            .search-results { max-height: 300px; overflow-y: auto; }
            .search-result-item { display: block; padding: 0.75rem 1.25rem; color: hsl(var(--foreground)); text-decoration: none; border-top: 1px solid hsl(var(--border)); }
            .search-result-item:hover { background: hsl(var(--accent)); }
            .search-hint { padding: 0.5rem 1.25rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); border-top: 1px solid hsl(var(--border)); }
            @media (max-width: 768px) {
                .nav-links { display: none; position: absolute; top: 100%; left: 0; right: 0; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); flex-direction: column; padding: 1rem; gap: 0.5rem; }
                .nav-links.open { display: flex; }
                .nav-link { padding: 0.75rem 1rem; }
                .hamburger { display: block; }
                .hero { padding: 2rem 1rem; }
                .hero h1 { font-size: 1.75rem; }
                .hero p { font-size: 1rem; }
                .container { padding: 1rem; }
                .course-grid { grid-template-columns: 1fr; }
                .feature-grid { grid-template-columns: 1fr; }
                .action-grid { grid-template-columns: 1fr; }
            }
            @media (min-width: 769px) and (max-width: 1024px) {
                .course-grid { grid-template-columns: repeat(2, 1fr); }
                .feature-grid { grid-template-columns: repeat(2, 1fr); }
                .action-grid { grid-template-columns: repeat(2, 1fr); }
            }
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

            var allConcepts = [
                {name: "Bytes and Binary", url: "/courses/elf/lessons/bytes"},
                {name: "Binary Representation", url: "/courses/elf/lessons/binary-representation"},
                {name: "File Layout", url: "/courses/elf/lessons/file-layout"},
                {name: "ELF Identification", url: "/courses/elf/lessons/elf-identification"},
                {name: "ELF Header Fields", url: "/courses/elf/lessons/elf-header-fields"},
                {name: "Entry Point", url: "/courses/elf/lessons/entry-point"},
                {name: "Program Header Table", url: "/courses/elf/lessons/program-header-table"},
                {name: "Segment Types", url: "/courses/elf/lessons/segment-types"},
                {name: "Memory Mapping", url: "/courses/elf/lessons/memory-mapping"},
                {name: "Section Header Table", url: "/courses/elf/lessons/section-header-table"},
                {name: "Common Sections", url: "/courses/elf/lessons/common-sections"},
                {name: "Section vs Segment", url: "/courses/elf/lessons/section-vs-segment"},
                {name: "Symbol Table", url: "/courses/elf/lessons/symbol-table"},
                {name: "Symbol Binding", url: "/courses/elf/lessons/binding"},
                {name: "Symbol Visibility", url: "/courses/elf/lessons/visibility"},
                {name: "Relocation Entries", url: "/courses/elf/lessons/relocation-entries"},
                {name: "Relocation Types", url: "/courses/elf/lessons/relocation-types"},
                {name: "Dynamic Relocations", url: "/courses/elf/lessons/dynamic-relocations"},
                {name: "Dynamic Section", url: "/courses/elf/lessons/dynamic-section"},
                {name: "Shared Libraries", url: "/courses/elf/lessons/shared-libraries"},
                {name: "The Dynamic Linker", url: "/courses/elf/lessons/ld-so"},
                {name: "The Kernel Loader", url: "/courses/elf/lessons/loader"},
                {name: "Process Memory Layout", url: "/courses/elf/lessons/memory-layout"},
                {name: "The Startup Sequence", url: "/courses/elf/lessons/execution"}
            ];

            function openSearch() {
                document.getElementById("search-modal").classList.add("open");
                document.getElementById("search-input").focus();
            }
            function closeSearch() {
                document.getElementById("search-modal").classList.remove("open");
                document.getElementById("search-input").value = "";
                document.getElementById("search-results").innerHTML = "";
            }
            function doSearch(q) {
                var results = document.getElementById("search-results");
                results.innerHTML = "";
                if(q.length < 2) return;
                var lower = q.toLowerCase();
                for(var i = 0; i < allConcepts.length; i++) {
                    if(allConcepts[i].name.toLowerCase().indexOf(lower) !== -1) {
                        var a = document.createElement("a");
                        a.className = "search-result-item";
                        a.href = allConcepts[i].url;
                        a.textContent = allConcepts[i].name;
                        results.appendChild(a);
                    }
                }
            }
            document.addEventListener("keydown", function(e) {
                if((e.ctrlKey || e.metaKey) && e.key === "k") { e.preventDefault(); openSearch(); }
                if(e.key === "Escape") { closeSearch(); }
            });
        }

        send_page(res, &raw page)
    }

}
