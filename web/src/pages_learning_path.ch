// underlayer_web — Learning Path Visualization page.
// Client-side rendered visual path; data from GET /api/courses/:courseId/path
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func render_learning_path_page(db : *DbClient, course_id : &string, learner_id : &string) : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Learning Path — Underlayer"))

        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <div class="navbar">
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
            </div>

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Learning Path</h1>
                    <p class="subtitle" id="lp-subtitle">Visual overview of your course</p>
                    <a id="lp-back" href="/courses/elf" class="back-link">&larr; Back to course</a>
                </div>

                <div class="legend">
                    <span class="legend-item"><span class="legend-dot status-not-started"></span> Not Started</span>
                    <span class="legend-item"><span class="legend-dot status-learning"></span> Learning</span>
                    <span class="legend-item"><span class="legend-dot status-reviewing"></span> Reviewing</span>
                    <span class="legend-item"><span class="legend-dot status-mastered"></span> Mastered</span>
                </div>

                <div id="lp-body">
                    <p class="muted">Loading learning path...</p>
                </div>

                <div class="stats-bar">
                    <div class="stats-bar-inner" id="path-stats"></div>
                </div>

                <a href="/review" class="btn btn-primary">Start Review Session</a>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">&uarr; Top</button>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
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
            .muted { color: hsl(var(--muted-foreground)); }
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
            .stats-bar { margin: 2rem 0 1rem 0; padding: 1rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; }
            .stats-bar-inner { font-size: 0.85rem; color: hsl(var(--muted-foreground)); text-align: center; }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.95rem; }
            .btn-primary { background: hsl(217 91% 60%); color: white; text-decoration: none; }
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

            var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
            var courseId = parts.length >= 2 ? parts[1] : 'elf';

            function statusClass(status) {
                if (status === 'mastered') return 'status-mastered';
                if (status === 'learning') return 'status-learning';
                if (status === 'reviewing') return 'status-reviewing';
                return 'status-not-started';
            }
            function statusLabel(status) {
                if (status === 'mastered') return 'Mastered';
                if (status === 'learning') return 'Learning';
                if (status === 'reviewing') return 'Reviewing';
                return 'Not Started';
            }

            function renderPath(data) {
                var body = document.getElementById('lp-body');
                var sub = document.getElementById('lp-subtitle');
                var back = document.getElementById('lp-back');
                if (data.title) { sub.textContent = 'Visual overview of ' + data.title; }
                back.setAttribute('href', '/courses/' + courseId);

                var mastered = 0;
                var learning = 0;
                var reviewing = 0;
                var total = 0;
                var html = '';
                var mi = 0;
                while (mi < data.modules.length) {
                    var mod = data.modules[mi];
                    html += '<div class="module-group">';
                    html += '<div class="module-header">';
                    html += '<span class="module-number">' + (mi + 1) + '</span>';
                    html += '<span class="module-title">' + mod.title + '</span>';
                    html += '</div>';
                    html += '<div class="concept-list">';
                    var ci = 0;
                    while (ci < mod.concepts.length) {
                        var c = mod.concepts[ci];
                        total = total + 1;
                        if (c.status === 'mastered') { mastered = mastered + 1; }
                        else if (c.status === 'learning') { learning = learning + 1; }
                        else if (c.status === 'reviewing') { reviewing = reviewing + 1; }
                        var cls = statusClass(c.status);
                        var acc = c.attempts > 0 ? Math.round(c.correct * 100 / c.attempts) + '%' : '--';
                        html += '<a href="/courses/' + courseId + '/lessons/' + c.id + '" class="concept-node ' + cls + '">';
                        html += '<div class="node-header">';
                        html += '<span class="node-status-dot"></span>';
                        html += '<span class="node-title">' + c.title + '</span>';
                        html += '</div>';
                        html += '<div class="node-meta">';
                        html += '<span class="node-status">' + statusLabel(c.status) + '</span>';
                        html += '<span class="node-stat">' + c.attempts + ' attempts</span>';
                        html += '<span class="node-stat">Accuracy: ' + acc + '</span>';
                        html += '</div></a>';
                        html += '<div class="connector"></div>';
                        ci = ci + 1;
                    }
                    html += '</div></div>';
                    if (mi < data.modules.length - 1) { html += '<div class="module-connector"></div>'; }
                    mi = mi + 1;
                }
                body.innerHTML = html;

                var pct = total > 0 ? Math.round(mastered * 100 / total) : 0;
                var notStarted = total - mastered - learning - reviewing;
                document.getElementById('path-stats').textContent = total + ' concepts — ' + mastered + ' mastered (' + pct + '%), ' + learning + ' learning, ' + reviewing + ' reviewing, ' + notStarted + ' not started';
            }

            fetch('/api/courses/' + courseId + '/path', {
                headers: { 'Authorization': 'Bearer ' + (localStorage.getItem('session_token') || '') }
            }).then(function(r) { return r.json(); })
              .then(function(data) {
                if (!data || !data.modules) {
                    document.getElementById('lp-body').innerHTML = '<p class="muted">Could not load learning path.</p>';
                    return;
                }
                renderPath(data);
              }).catch(function() {
                document.getElementById('lp-body').innerHTML = '<p class="muted">Failed to load learning path.</p>';
              });

            window.addEventListener('DOMContentLoaded', function() {
                var btn = document.getElementById('back-to-top');
                if (btn) {
                    window.addEventListener('scroll', function() {
                        if (window.scrollY > 300) { btn.classList.add('visible'); }
                        else { btn.classList.remove('visible'); }
                    });
                }
            });
        }

        return page.toString()
    }

}
