// underlayer_web — Learning Path Visualization page.
// Shows course concepts as a visual path with status indicators.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Course
using underlayer_models::Module
using underlayer_models::ConceptRef
using underlayer_models::ConceptState

public namespace underlayer_web {

    // Build a status color class name from status string.
    private func status_color_class(status : &string) : string {
        if(status.equals(string("mastered"))) { return string("status-mastered") }
        if(status.equals(string("learning"))) { return string("status-learning") }
        if(status.equals(string("reviewing"))) { return string("status-reviewing") }
        return string("status-not-started")
    }

    // Build a status label from status string.
    private func status_label(status : &string) : string {
        if(status.equals(string("mastered"))) { return string("Mastered") }
        if(status.equals(string("learning"))) { return string("Learning") }
        if(status.equals(string("reviewing"))) { return string("Reviewing") }
        return string("Not Started")
    }

    // Compute accuracy percentage string from attempts/correct.
    private func accuracy_str(attempts : int, correct : int) : string {
        if(attempts <= 0) { return string("--") }
        var pct = (correct * 100) / attempts
        var pct_str = underlayer_core::int_to_string(pct as i64)
        var out = pct_str.copy()
        out.append_view("%")
        return out
    }

    // Render the learning path HTML page for a course.
    public func render_learning_path_page(db : *DbClient, course_id : &string, learner_id : &string) : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Learning Path — Underlayer"))

        // Load course
        var courses_dir = string("./courses")
        var course = underlayer_repository::load_course_from_disk(&courses_dir, course_id)
        var course_title = course.title.copy()
        if(course_title.size() == 0) { course_title = course_id.copy() }

        // Load concept states
        var states = underlayer_repository::get_all_concept_states(db, learner_id, course_id)

        // Build a map: concept_id -> ConceptState (as strings)
        // We'll iterate concepts and look up state by id.

        // Start HTML
        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <nav class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                    </div>
                    <div class="nav-right">
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">&#9728;</span>
                            <span class="theme-icon-dark">&#9790;</span>
                        </button>
                    </div>
                </div>
            </nav>

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Learning Path</h1>
                    <p class="subtitle">Visual overview of <strong>{course_title}</strong></p>
                    <a href="/courses/{course_id}" class="back-link">&larr; Back to course</a>
                </div>

                <div class="legend">
                    <span class="legend-item"><span class="legend-dot status-not-started"></span> Not Started</span>
                    <span class="legend-item"><span class="legend-dot status-learning"></span> Learning</span>
                    <span class="legend-item"><span class="legend-dot status-reviewing"></span> Reviewing</span>
                    <span class="legend-item"><span class="legend-dot status-mastered"></span> Mastered</span>
                </div>
        }

        // Render each module and its concepts
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            var mod_title = mod.title.copy()
            var mod_order_str = underlayer_core::int_to_string(mod.order as i64)

            #html {
                <div class="module-group">
                    <div class="module-header">
                        <span class="module-number">{mod_order_str}</span>
                        <span class="module-title">{mod_title}</span>
                    </div>
                    <div class="concept-list">
            }

            // Render concepts in this module
            var ci : size_t = 0
            while(ci < mod.concepts.size()) {
                var concept_id = mod.concepts.get_ptr(ci)

                // Find concept title from course.concepts
                var concept_title = concept_id.copy()
                var concept_desc = string()
                var cii : size_t = 0
                while(cii < course.concepts.size()) {
                    var cref = course.concepts.get_ptr(cii)
                    if(cref.id.equals(concept_id)) {
                        concept_title = cref.title.copy()
                        concept_desc = cref.description.copy()
                        break
                    }
                    cii = cii + 1
                }

                // Find state for this concept
                var status = string("not_started")
                var attempts = 0
                var correct = 0
                var si : size_t = 0
                while(si < states.size()) {
                    var st = states.get_ptr(si)
                    if(st.concept_id.equals(concept_id)) {
                        status = st.status.copy()
                        attempts = st.attempts
                        correct = st.correct
                        break
                    }
                    si = si + 1
                }

                var color_class = status_color_class(&status)
                var label = status_label(&status)
                var acc = accuracy_str(attempts, correct)
                var attempts_str = underlayer_core::int_to_string(attempts as i64)

                #html {
                    <a href="/courses/{course_id}/lessons/{concept_id}" class="concept-node {color_class}" title="{concept_desc}">
                        <div class="node-header">
                            <span class="node-status-dot"></span>
                            <span class="node-title">{concept_title}</span>
                        </div>
                        <div class="node-meta">
                            <span class="node-status">{label}</span>
                            <span class="node-stat">{attempts_str} attempts</span>
                            <span class="node-stat">Accuracy: {acc}</span>
                        </div>
                    </a>
                }

                // Draw connector arrow between concepts (not after the last in module)
                if(ci < mod.concepts.size() - 1) {
                    #html {
                        <div class="connector"></div>
                    }
                }

                ci = ci + 1
            }

            #html {
                    </div>
                </div>
            }

            // Draw connector between modules (not after the last)
            if(mi < course.modules.size() - 1) {
                #html {
                    <div class="module-connector"></div>
                }
            }

            mi = mi + 1
        }

        // Close HTML
        #html {
                <div class="stats-bar">
                    <div class="stats-bar-inner" id="path-stats"></div>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">&uarr; Top</button>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; gap: 1.5rem; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
            .container { max-width: 800px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 1.5rem; }
            .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); }
            .back-link { color: hsl(217 91% 60%); text-decoration: none; font-size: 0.85rem; display: inline-block; margin-top: 0.5rem; }
            .back-link:hover { text-decoration: underline; }
            .legend { display: flex; gap: 1.5rem; margin-bottom: 2rem; flex-wrap: wrap; }
            .legend-item { display: flex; align-items: center; gap: 0.4rem; font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .legend-dot { width: 12px; height: 12px; border-radius: 50%; display: inline-block; }
            .legend-dot.status-not-started { background: hsl(var(--muted)); border: 2px solid hsl(var(--border)); }
            .legend-dot.status-learning { background: hsl(38 92% 50%); }
            .legend-dot.status-reviewing { background: hsl(217 91% 60%); }
            .legend-dot.status-mastered { background: hsl(142 76% 36%); }
            .module-group { margin-bottom: 0.5rem; }
            .module-header { display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px 10px 0 0; }
            .module-number { background: hsl(217 91% 60%); color: white; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.8rem; font-weight: 700; flex-shrink: 0; }
            .module-title { font-size: 1rem; font-weight: 600; color: hsl(var(--foreground)); }
            .concept-list { display: flex; flex-direction: column; padding: 0.5rem 1rem 1rem 1rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-top: none; border-radius: 0 0 10px 10px; gap: 0.25rem; }
            .concept-node { display: block; padding: 0.75rem 1rem; border-radius: 8px; text-decoration: none; transition: all 0.15s; border: 1px solid hsl(var(--border)); background: hsl(var(--secondary)); }
            .concept-node:hover { border-color: hsl(217 91% 60%); text-decoration: none; transform: translateX(4px); }
            .concept-node.status-not-started { border-left: 4px solid hsl(var(--muted)); }
            .concept-node.status-learning { border-left: 4px solid hsl(38 92% 50%); background: hsl(38 92% 50% / 5%); }
            .concept-node.status-reviewing { border-left: 4px solid hsl(217 91% 60%); background: hsl(217 91% 60% / 5%); }
            .concept-node.status-mastered { border-left: 4px solid hsl(142 76% 36%); background: hsl(142 76% 36% / 5%); }
            .node-header { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.25rem; }
            .node-status-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
            .status-not-started .node-status-dot { background: hsl(var(--muted)); }
            .status-learning .node-status-dot { background: hsl(38 92% 50%); }
            .status-reviewing .node-status-dot { background: hsl(217 91% 60%); }
            .status-mastered .node-status-dot { background: hsl(142 76% 36%); }
            .node-title { font-size: 0.9rem; font-weight: 500; color: hsl(var(--foreground)); }
            .node-meta { display: flex; gap: 1rem; font-size: 0.78rem; color: hsl(var(--muted-foreground)); padding-left: 1.25rem; }
            .node-status { font-weight: 500; }
            .connector { width: 2px; height: 12px; background: hsl(var(--border)); margin: 0 auto; }
            .module-connector { width: 2px; height: 20px; background: hsl(217 91% 60% / 40%); margin: 0 auto; }
            .stats-bar { margin-top: 2rem; padding: 1rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; }
            .stats-bar-inner { font-size: 0.85rem; color: hsl(var(--muted-foreground)); text-align: center; }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; }
            .back-to-top:hover { background: #111827; }
            @media (max-width: 768px) {
                .nav-links { display: none; }
                .container { padding: 1rem; }
                .legend { gap: 0.75rem; }
                .node-meta { flex-wrap: wrap; gap: 0.5rem; }
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

            window.addEventListener('DOMContentLoaded', function() {
                computeStats();
                (function() {
                    var btn = document.getElementById('back-to-top');
                    if(btn) {
                        window.addEventListener('scroll', function() {
                            if(window.scrollY > 300) { btn.classList.add('visible'); }
                            else { btn.classList.remove('visible'); }
                        });
                    }
                })();
            });

            function computeStats() {
                var nodes = document.querySelectorAll('.concept-node');
                var total = nodes.length;
                var mastered = 0;
                var learning = 0;
                var reviewing = 0;
                for(var i = 0; i < total; i++) {
                    if(nodes[i].classList.contains('status-mastered')) { mastered++; }
                    else if(nodes[i].classList.contains('status-learning')) { learning++; }
                    else if(nodes[i].classList.contains('status-reviewing')) { reviewing++; }
                }
                var pct = total > 0 ? Math.round(mastered * 100 / total) : 0;
                var el = document.getElementById('path-stats');
                if(el) {
                    el.textContent = total + ' concepts — ' + mastered + ' mastered (' + pct + '%), ' + learning + ' learning, ' + reviewing + ' reviewing, ' + (total - mastered - learning - reviewing) + ' not started';
                }
            }
        }

        return page.toString()
    }

}
