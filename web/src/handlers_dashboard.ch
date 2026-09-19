// underlayer_web — Dashboard handler with universal components.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // 7.2.4, 7.2.5, 1.5.20: Dashboard with progress, knowledge health, and stats
    public func handle_dashboard(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) {
            learner_id = string("demo")
        }
        var course_id = string("elf")

        // Get knowledge health
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var depth = underlayer_learning::compute_depth_score(&raw states)
        var breadth = underlayer_learning::compute_breadth_score(&raw states, health.total_concepts)

        // Get due items count
        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 1000)
        var new_count = 0
        var due_count = 0
        var i : size_t = 0
        while(i < due_items.size()) {
            var item = due_items.get_ptr(i)
            if(item.last_review == 0) { new_count = new_count + 1 }
            else { due_count = due_count + 1 }
            i = i + 1
        }

        // Build page with components
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Dashboard — Underlayer"))

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
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link active">Dashboard</a>
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
                            <span class="theme-icon-light">☀️</span>
                            <span class="theme-icon-dark">🌙</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="container" id="main-content" style="max-width: 1200px; margin: 0 auto; padding: 2rem;">
                <div style="margin-bottom: 2rem;">
                    <H1>Dashboard</H1>
                    <Text variant="muted">Welcome back to your learning journey</Text>
                </div>

                <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem;">
                    <Card>
                        <CardBody>
                            <Text variant="muted">Total Concepts</Text>
                            <Text style="font-size: 2rem; font-weight: bold;">{health.total_concepts}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Mastered</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--primary);">{health.mastered}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Learning</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--accent);">{health.learning}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Reviewing</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--destructive);">{health.reviewing}</Text>
                        </CardBody>
                    </Card>
                </div>

                <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;">
                    <Card>
                        <CardHeader>
                            <CardTitle>Knowledge Health</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <div style="margin-bottom: 1rem;">
                                <Text>Health Score</Text>
                                <Progress value={health.health_score * 100.0} max={100.0} variant="success" />
                                <Caption>{health.health_score * 100.0}% mastered</Caption>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Text>Depth Score</Text>
                                <Progress value={depth} max={100.0} variant="info" />
                                <Caption>{depth}% understanding</Caption>
                            </div>
                            <div>
                                <Text>Breadth Score</Text>
                                <Progress value={breadth} max={100.0} variant="accent" />
                                <Caption>{breadth}% coverage</Caption>
                            </div>
                        </CardBody>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Review Queue</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <div style="margin-bottom: 1rem;">
                                <Badge variant="info">New: {new_count}</Badge>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Badge variant="warning">Due: {due_count}</Badge>
                            </div>
                            <div>
                                <Badge variant="success">Mastered: {health.mastered}</Badge>
                            </div>
                            <div style="margin-top: 1rem;">
                                <Button variant="primary">Start Review</Button>
                            </div>
                        </CardBody>
                    </Card>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
        }

        #css {
            [data-chx-i] { display: contents; }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .container { font-family: system-ui, sans-serif; background: hsl(var(--background)); color: hsl(var(--foreground)); min-height: 100vh; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); }
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .hamburger { display: none; background: none; border: none; cursor: pointer; padding: 0.5rem; }
            .hamburger-line { display: block; width: 24px; height: 2px; background: hsl(var(--foreground)); margin: 4px 0; transition: all 0.3s; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
            @media (max-width: 1300px) {
                .nav-links { display: none; position: absolute; top: 100%; left: 0; right: 0; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); flex-direction: column; padding: 1rem; gap: 0.5rem; }
                .nav-links.open { display: flex; }
                .nav-link { padding: 0.75rem 1rem; }
                .hamburger { display: block; }
            }
            @media (max-width: 768px) {
                .container { padding: 1rem; }
            }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; }
            .back-to-top:hover { background: #111827; }
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

            (function() {
                var btn = document.getElementById('back-to-top');
                if(btn) {
                    window.addEventListener('scroll', function() {
                        if(window.scrollY > 300) { btn.classList.add('visible'); }
                        else { btn.classList.remove('visible'); }
                    });
                }
            })();
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
