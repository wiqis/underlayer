// underlayer_web — Progress page (HTML UI).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_progress_page(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Progress — Underlayer"))

        #html {
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link active">Progress</a>
                    </div>
                    <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                        <span class="theme-icon-light">☀️</span>
                        <span class="theme-icon-dark">🌙</span>
                    </button>
                </div>
            </div>

            <div class="container">
                <div class="page-header">
                    <h1>Your Progress</h1>
                    <p class="subtitle">Track your learning journey through the ELF course</p>
                </div>

                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-number" id="total-concepts">-</div>
                        <div class="stat-label">Total Concepts</div>
                    </div>
                    <div class="stat-card stat-mastered">
                        <div class="stat-number" id="mastered-count">-</div>
                        <div class="stat-label">Mastered</div>
                    </div>
                    <div class="stat-card stat-learning">
                        <div class="stat-number" id="learning-count">-</div>
                        <div class="stat-label">Learning</div>
                    </div>
                    <div class="stat-card stat-reviewing">
                        <div class="stat-number" id="reviewing-count">-</div>
                        <div class="stat-label">Reviewing</div>
                    </div>
                </div>

                <div class="progress-section">
                    <h2>Overall Mastery</h2>
                    <div class="progress-bar-large">
                        <div class="progress-fill" id="mastery-fill" style="width: 0%"></div>
                    </div>
                    <div class="progress-label" id="mastery-label">Loading...</div>
                </div>

                <div class="dual-grid">
                    <div class="section-card">
                        <h2>Knowledge Health</h2>
                        <div class="metric-row">
                            <span class="metric-label">Health Score</span>
                            <span class="metric-value" id="health-score">-</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill progress-health" id="health-fill" style="width: 0%"></div>
                        </div>
                        <div class="metric-row">
                            <span class="metric-label">Depth Score</span>
                            <span class="metric-value" id="depth-score">-</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill progress-depth" id="depth-fill" style="width: 0%"></div>
                        </div>
                        <div class="metric-row">
                            <span class="metric-label">Breadth Score</span>
                            <span class="metric-value" id="breadth-score">-</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill progress-breadth" id="breadth-fill" style="width: 0%"></div>
                        </div>
                    </div>

                    <div class="section-card">
                        <h2>Review Queue</h2>
                        <div class="queue-stats">
                            <div class="queue-stat">
                                <div class="queue-count queue-new" id="new-count">-</div>
                                <div class="queue-label">New</div>
                            </div>
                            <div class="queue-stat">
                                <div class="queue-count queue-due" id="due-count">-</div>
                                <div class="queue-label">Due</div>
                            </div>
                            <div class="queue-stat">
                                <div class="queue-count queue-mastered" id="mastered-queue">-</div>
                                <div class="queue-label">Mastered</div>
                            </div>
                        </div>
                        <a href="/review" class="btn btn-primary" style="width: 100%; text-align: center; margin-top: 1rem;">Start Review Session</a>
                    </div>
                </div>

                <div class="section-card" style="margin-top: 2rem;">
                    <h2>Concept Progress</h2>
                    <div class="concept-progress-list" id="concept-list">
                        <p class="muted">Loading concepts...</p>
                    </div>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
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
            .container { max-width: 1000px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 2rem; }
            .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); }
            .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem; }
            .stat-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; text-align: center; }
            .stat-number { font-size: 2rem; font-weight: 700; color: hsl(var(--foreground)); }
            .stat-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); margin-top: 0.25rem; }
            .stat-mastered .stat-number { color: hsl(142 76% 36%); }
            .stat-learning .stat-number { color: hsl(38 92% 50%); }
            .stat-reviewing .stat-number { color: hsl(0 84% 60%); }
            .progress-section { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; margin-bottom: 2rem; }
            .progress-section h2 { font-size: 1.1rem; margin-bottom: 1rem; }
            .progress-bar-large { height: 12px; background: hsl(var(--secondary)); border-radius: 6px; overflow: hidden; margin-bottom: 0.5rem; }
            .progress-fill { height: 100%; background: hsl(217 91% 60%); border-radius: 6px; transition: width 0.5s ease; }
            .progress-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .dual-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
            .section-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .section-card h2 { font-size: 1.1rem; margin-bottom: 1rem; }
            .metric-row { display: flex; justify-content: space-between; margin-bottom: 0.25rem; }
            .metric-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .metric-value { font-size: 0.85rem; font-weight: 600; color: hsl(var(--foreground)); }
            .progress-bar { height: 6px; background: hsl(var(--secondary)); border-radius: 3px; overflow: hidden; margin-bottom: 1rem; }
            .progress-health { background: hsl(142 76% 36%); }
            .progress-depth { background: hsl(217 91% 60%); }
            .progress-breadth { background: hsl(258 90% 66%); }
            .queue-stats { display: flex; justify-content: space-around; margin-bottom: 1rem; }
            .queue-stat { text-align: center; }
            .queue-count { font-size: 1.5rem; font-weight: 700; }
            .queue-new { color: hsl(217 91% 60%); }
            .queue-due { color: hsl(38 92% 50%); }
            .queue-mastered { color: hsl(142 76% 36%); }
            .queue-label { font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border-radius: 8px; font-weight: 500; font-size: 0.9rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            .concept-progress-list { display: flex; flex-direction: column; gap: 0.5rem; }
            .concept-row { display: flex; align-items: center; padding: 0.75rem 1rem; background: hsl(var(--secondary)); border-radius: 8px; }
            .concept-name { flex: 1; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .concept-link { color: hsl(217 91% 60%); font-size: 0.8rem; text-decoration: none; margin-left: 1rem; }
            .concept-link:hover { text-decoration: underline; }
            .muted { color: hsl(var(--muted-foreground)); text-align: center; padding: 2rem; }
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

            function setText(id, val) {
                document.getElementById(id).textContent = val;
            }

            function setWidth(id, pct) {
                document.getElementById(id).style.width = pct;
            }

            function fmtPct(n) {
                return Math.round(n) + "%%";
            }

            window.addEventListener("DOMContentLoaded", function() {
                loadProgress();
                loadConceptList();
            });

            function loadProgress() {
                fetch("/api/progress?course_id=elf")
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        setText("total-concepts", data.total_concepts || 24);
                        setText("mastered-count", data.mastered || 0);
                        setText("learning-count", data.learning || 0);
                        setText("reviewing-count", data.reviewing || 0);
                        var total = data.total_concepts || 24;
                        var mastered = data.mastered || 0;
                        var pct = total > 0 ? Math.round(mastered * 100 / total) : 0;
                        setWidth("mastery-fill", pct + "%%");
                        setText("mastery-label", pct + "%% mastered (" + mastered + " of " + total + " concepts)");
                        var health = data.health_score || 0;
                        var healthPct = Math.round(health * 100);
                        setText("health-score", fmtPct(healthPct));
                        setWidth("health-fill", healthPct + "%%");
                        var depth = data.depth || 0;
                        setText("depth-score", fmtPct(depth));
                        setWidth("depth-fill", Math.round(depth) + "%%");
                        var breadth = data.breadth || 0;
                        setText("breadth-score", fmtPct(breadth));
                        setWidth("breadth-fill", Math.round(breadth) + "%%");
                    })
                    .catch(function() {
                        setText("total-concepts", "24");
                        setText("mastered-count", "0");
                        setText("learning-count", "0");
                        setText("reviewing-count", "0");
                    });

                fetch("/api/review/due?course_id=elf&limit=1000")
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var items = data || [];
                        var newC = 0;
                        var dueC = 0;
                        for(var i = 0; i < items.length; i++) {
                            if(items[i].last_review === 0) { newC++; }
                            else { dueC++; }
                        }
                        setText("new-count", newC);
                        setText("due-count", dueC);
                    })
                    .catch(function() {
                        setText("new-count", "0");
                        setText("due-count", "0");
                    });
            }

            function loadConceptList() {
                var list = document.getElementById("concept-list");
                list.innerHTML = "";
                var names = ["Bytes and Binary", "Binary Representation", "File Layout", "ELF Identification", "ELF Header Fields", "Entry Point", "Program Header Table", "Segment Types", "Memory Mapping", "Section Header Table", "Common Sections", "Section vs Segment", "Symbol Table", "Symbol Binding", "Symbol Visibility", "Relocation Entries", "Relocation Types", "Dynamic Relocations", "Dynamic Section", "Shared Libraries", "The Dynamic Linker", "The Kernel Loader", "Process Memory Layout", "The Startup Sequence"];
                var ids = ["bytes", "binary-representation", "file-layout", "elf-identification", "elf-header-fields", "entry-point", "program-header-table", "segment-types", "memory-mapping", "section-header-table", "common-sections", "section-vs-segment", "symbol-table", "binding", "visibility", "relocation-entries", "relocation-types", "dynamic-relocations", "dynamic-section", "shared-libraries", "dynamic-linker", "loader", "memory-layout", "execution"];
                for(var i = 0; i < names.length; i++) {
                    var row = document.createElement("div");
                    row.className = "concept-row";
                    var nameEl = document.createElement("span");
                    nameEl.className = "concept-name";
                    nameEl.textContent = (i + 1) + ". " + names[i];
                    var link = document.createElement("a");
                    link.href = "/courses/elf/lessons/" + ids[i];
                    link.textContent = "Learn";
                    link.className = "concept-link";
                    row.appendChild(nameEl);
                    row.appendChild(link);
                    list.appendChild(row);
                }
                setText("mastered-queue", "0");
            }
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
