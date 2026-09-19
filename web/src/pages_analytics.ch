// underlayer_web — Analytics dashboard page renders.
// Shows course learning analytics with charts and stats.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // Render overall analytics dashboard page
    public func render_analytics_page(db : *DbClient, learner_id : &string) : string {
        var course_id = string("elf")
        var states = underlayer_repository::get_all_concept_states(db, learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var sessions = underlayer_repository::get_learner_sessions(db, learner_id, 100)

        // Compute accuracy across all sessions
        var total_items : int = 0
        var total_correct : int = 0
        var total_duration : i64 = 0
        var si : size_t = 0
        while(si < sessions.size()) {
            var s = sessions.get_ptr(si)
            total_items = total_items + s.exercises_attempted
            total_correct = total_correct + s.exercises_correct
            total_duration = total_duration + (s.end_time - s.start_time)
            si = si + 1
        }
        var accuracy : f64 = 0.0
        if(total_items > 0) { accuracy = (total_correct as f64) / (total_items as f64) }
        var accuracy_pct = (accuracy * 100.0) as i64

        // Count easy/medium/hard from states
        var easy_count : i64 = 0
        var medium_count : i64 = 0
        var hard_count : i64 = 0
        var ci : size_t = 0
        while(ci < states.size()) {
            var s = states.get_ptr(ci)
            if(s.difficulty_rating < 3.0) { easy_count = easy_count + 1 }
            else if(s.difficulty_rating < 6.0) { medium_count = medium_count + 1 }
            else { hard_count = hard_count + 1 }
            ci = ci + 1
        }

        // Locals for HTML interpolation (dots are not allowed in {..})
        var total_concepts = health.total_concepts
        var mastered_count = health.mastered
        var learning_count = health.learning
        var reviewing_count = health.reviewing
        var unlearned_count = health.unlearned
        var session_count = sessions.size() as i64

        // Build page
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Analytics — Underlayer"))

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
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                        <a href="/analytics" class="nav-link active">Analytics</a>
                    </div>
                    <div class="nav-right">
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">☀️</span>
                            <span class="theme-icon-dark">🌙</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Learning Analytics</h1>
                    <p class="subtitle">Insights into your learning progress and patterns</p>
                </div>

                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-number" id="total-concepts">{total_concepts}</div>
                        <div class="stat-label">Total Concepts</div>
                    </div>
                    <div class="stat-card stat-mastered">
                        <div class="stat-number" id="mastered-count">{mastered_count}</div>
                        <div class="stat-label">Mastered</div>
                    </div>
                    <div class="stat-card stat-learning">
                        <div class="stat-number" id="learning-count">{learning_count}</div>
                        <div class="stat-label">Learning</div>
                    </div>
                    <div class="stat-card stat-accuracy">
                        <div class="stat-number" id="accuracy-val">{accuracy_pct}%</div>
                        <div class="stat-label">Accuracy</div>
                    </div>
                    <div class="stat-card stat-sessions">
                        <div class="stat-number" id="session-count">{session_count}</div>
                        <div class="stat-label">Total Sessions</div>
                    </div>
                </div>

                <div class="section-card">
                    <h2>Concept Mastery</h2>
                    <div class="chart-container" id="mastery-chart">
                        <div class="bar-chart">
                            <div class="bar-row">
                                <span class="bar-label">Mastered</span>
                                <div class="bar-track"><div class="bar-fill bar-mastered" id="bar-mastered"></div></div>
                                <span class="bar-value" id="bar-mastered-val">{mastered_count}</span>
                            </div>
                            <div class="bar-row">
                                <span class="bar-label">Learning</span>
                                <div class="bar-track"><div class="bar-fill bar-learning" id="bar-learning"></div></div>
                                <span class="bar-value" id="bar-learning-val">{learning_count}</span>
                            </div>
                            <div class="bar-row">
                                <span class="bar-label">Reviewing</span>
                                <div class="bar-track"><div class="bar-fill bar-reviewing" id="bar-reviewing"></div></div>
                                <span class="bar-value" id="bar-reviewing-val">{reviewing_count}</span>
                            </div>
                            <div class="bar-row">
                                <span class="bar-label">Unlearned</span>
                                <div class="bar-track"><div class="bar-fill bar-unlearned" id="bar-unlearned"></div></div>
                                <span class="bar-value" id="bar-unlearned-val">{unlearned_count}</span>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="section-card">
                    <h2>Difficulty Distribution</h2>
                    <div class="difficulty-chart">
                        <div class="diff-bar">
                            <div class="diff-segment diff-easy" id="diff-easy"></div>
                            <div class="diff-segment diff-medium" id="diff-medium"></div>
                            <div class="diff-segment diff-hard" id="diff-hard"></div>
                        </div>
                        <div class="diff-legend">
                            <span class="diff-legend-item"><span class="diff-dot diff-easy-dot"></span> Easy ({easy_count})</span>
                            <span class="diff-legend-item"><span class="diff-dot diff-medium-dot"></span> Medium ({medium_count})</span>
                            <span class="diff-legend-item"><span class="diff-dot diff-hard-dot"></span> Hard ({hard_count})</span>
                        </div>
                    </div>
                </div>

                <div class="section-card">
                    <h2>Learning Velocity</h2>
                    <p class="section-desc">Concepts mastered per week over the last 8 weeks</p>
                    <div class="velocity-chart" id="velocity-chart">
                        <p class="muted" id="velocity-loading">Loading velocity data...</p>
                    </div>
                </div>

                <div class="section-card">
                    <h2>Recent Sessions</h2>
                    <div class="table-container">
                        <table class="data-table" id="sessions-table">
                            <thead>
                                <tr>
                                    <th>Type</th>
                                    <th>Date</th>
                                    <th>Duration</th>
                                    <th>Items</th>
                                    <th>Accuracy</th>
                                </tr>
                            </thead>
                            <tbody id="sessions-body">
                            </tbody>
                        </table>
                        <p class="muted" id="no-sessions" style="display:none">No sessions recorded yet.</p>
                    </div>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
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
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .hamburger { display: none; background: none; border: none; cursor: pointer; padding: 0.5rem; }
            .hamburger-line { display: block; width: 24px; height: 2px; background: hsl(var(--foreground)); margin: 4px 0; transition: all 0.3s; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
            .container { max-width: 1000px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 2rem; }
            .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); }
            .stats-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 1rem; margin-bottom: 2rem; }
            .stat-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; text-align: center; }
            .stat-number { font-size: 1.75rem; font-weight: 700; color: hsl(var(--foreground)); }
            .stat-label { font-size: 0.8rem; color: hsl(var(--muted-foreground)); margin-top: 0.25rem; text-transform: uppercase; letter-spacing: 0.03em; }
            .stat-mastered .stat-number { color: hsl(142 76% 36%); }
            .stat-learning .stat-number { color: hsl(38 92% 50%); }
            .stat-accuracy .stat-number { color: hsl(217 91% 60%); }
            .stat-sessions .stat-number { color: hsl(258 90% 66%); }
            .section-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; }
            .section-card h2 { font-size: 1.1rem; margin-bottom: 0.5rem; }
            .section-desc { font-size: 0.85rem; color: hsl(var(--muted-foreground)); margin-bottom: 1rem; }
            .chart-container { padding: 0.5rem 0; }
            .bar-chart { display: flex; flex-direction: column; gap: 0.75rem; }
            .bar-row { display: flex; align-items: center; gap: 0.75rem; }
            .bar-label { width: 90px; font-size: 0.85rem; color: hsl(var(--muted-foreground)); text-align: right; flex-shrink: 0; }
            .bar-track { flex: 1; height: 24px; background: hsl(var(--secondary)); border-radius: 6px; overflow: hidden; }
            .bar-fill { height: 100%; border-radius: 6px; transition: width 0.5s ease; }
            .bar-mastered { background: hsl(142 76% 36%); }
            .bar-learning { background: hsl(38 92% 50%); }
            .bar-reviewing { background: hsl(0 84% 60%); }
            .bar-unlearned { background: hsl(var(--muted)); }
            .bar-value { width: 40px; font-size: 0.85rem; font-weight: 600; color: hsl(var(--foreground)); }
            .difficulty-chart { padding: 0.5rem 0; }
            .diff-bar { display: flex; height: 16px; border-radius: 8px; overflow: hidden; margin-bottom: 1rem; }
            .diff-segment { transition: width 0.5s ease; }
            .diff-easy { background: hsl(142 76% 36%); }
            .diff-medium { background: hsl(38 92% 50%); }
            .diff-hard { background: hsl(0 84% 60%); }
            .diff-legend { display: flex; gap: 1.5rem; justify-content: center; }
            .diff-legend-item { display: flex; align-items: center; gap: 0.4rem; font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .diff-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }
            .diff-easy-dot { background: hsl(142 76% 36%); }
            .diff-medium-dot { background: hsl(38 92% 50%); }
            .diff-hard-dot { background: hsl(0 84% 60%); }
            .velocity-chart { padding: 0.5rem 0; }
            .velocity-bars { display: flex; align-items: flex-end; gap: 0.5rem; height: 120px; }
            .velocity-bar-col { display: flex; flex-direction: column; align-items: center; gap: 0.25rem; flex: 1; }
            .velocity-bar { width: 100%; background: hsl(217 91% 60%); border-radius: 4px 4px 0 0; transition: height 0.5s ease; min-height: 2px; }
            .velocity-bar-label { font-size: 0.7rem; color: hsl(var(--muted-foreground)); }
            .velocity-bar-value { font-size: 0.7rem; font-weight: 600; color: hsl(var(--foreground)); }
            .table-container { overflow-x: auto; }
            .data-table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
            .data-table th { text-align: left; padding: 0.75rem; border-bottom: 2px solid hsl(var(--border)); color: hsl(var(--muted-foreground)); font-weight: 600; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.03em; }
            .data-table td { padding: 0.75rem; border-bottom: 1px solid hsl(var(--border)); color: hsl(var(--foreground)); }
            .data-table tr:last-child td { border-bottom: none; }
            .data-table tr:hover td { background: hsl(var(--accent) / 50%); }
            .muted { color: hsl(var(--muted-foreground)); text-align: center; padding: 1.5rem; font-size: 0.9rem; }
            @media (max-width: 1300px) {
                .nav-links { display: none; position: absolute; top: 100%; left: 0; right: 0; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); flex-direction: column; padding: 1rem; gap: 0.5rem; }
                .nav-links.open { display: flex; }
                .nav-link { padding: 0.75rem 1rem; }
                .hamburger { display: block; }
            }
            @media (max-width: 768px) {
                .container { padding: 1rem; }
                .stats-grid { grid-template-columns: repeat(2, 1fr); }
                .bar-label { width: 70px; font-size: 0.75rem; }
                .diff-legend { flex-direction: column; gap: 0.5rem; }
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

            function setText(id, val) {
                var el = document.getElementById(id);
                if(el) { el.textContent = val; }
            }

            function setWidth(id, pct) {
                var el = document.getElementById(id);
                if(el) { el.style.width = pct + '%'; }
            }

            function fmtDuration(seconds) {
                var h = Math.floor(seconds / 3600);
                var m = Math.floor((seconds % 3600) / 60);
                if(h > 0) { return h + 'h ' + m + 'm'; }
                return m + 'm';
            }

            function fmtDate(ts) {
                var d = new Date(ts * 1000);
                return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});
            }

            window.addEventListener("DOMContentLoaded", function() {
                renderBars();
                renderDifficulty();
                loadVelocity();
                loadSessions();
            });

            function renderBars() {
                var total = {total_concepts};
                if(total <= 0) { total = 1; }
                setWidth('bar-mastered', ({mastered_count} * 100) / total);
                setWidth('bar-learning', ({learning_count} * 100) / total);
                setWidth('bar-reviewing', ({reviewing_count} * 100) / total);
                setWidth('bar-unlearned', ({unlearned_count} * 100) / total);
            }

            function renderDifficulty() {
                var easy = {easy_count};
                var med = {medium_count};
                var hard = {hard_count};
                var total = easy + med + hard;
                if(total <= 0) { total = 1; }
                setWidth('diff-easy', (easy * 100) / total);
                setWidth('diff-medium', (med * 100) / total);
                setWidth('diff-hard', (hard * 100) / total);
            }

            function loadVelocity() {
                fetch('/api/analytics/velocity')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var weeks = data.weeks || [];
                        var container = document.getElementById('velocity-chart');
                        if(weeks.length === 0) {
                            container.innerHTML = '<p class="muted">No velocity data available yet.</p>';
                            return;
                        }
                        // Take last 8 weeks
                        var last8 = weeks.slice(-8);
                        var maxVal = 1;
                        for(var i = 0; i < last8.length; i++) {
                            if(last8[i].concepts_completed > maxVal) { maxVal = last8[i].concepts_completed; }
                        }
                        var html = '<div class="velocity-bars">';
                        for(var i = 0; i < last8.length; i++) {
                            var w = last8[i];
                            var height = maxVal > 0 ? Math.max(4, (w.concepts_completed * 100) / maxVal) : 4;
                            var d = new Date(w.week_start * 1000);
                            var label = (d.getMonth()+1) + '/' + d.getDate();
                            html += '<div class="velocity-bar-col">';
                            html += '<span class="velocity-bar-value">' + w.concepts_completed + '</span>';
                            html += '<div class="velocity-bar" style="height:' + height + '%"></div>';
                            html += '<span class="velocity-bar-label">' + label + '</span>';
                            html += '</div>';
                        }
                        html += '</div>';
                        container.innerHTML = html;
                    })
                    .catch(function() {
                        document.getElementById('velocity-chart').innerHTML = '<p class="muted">Failed to load velocity data.</p>';
                    });
            }

            function loadSessions() {
                fetch('/api/sessions')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var sessions = Array.isArray(data) ? data : (data.sessions || []);
                        var tbody = document.getElementById('sessions-body');
                        if(sessions.length === 0) {
                            document.getElementById('no-sessions').style.display = 'block';
                            return;
                        }
                        var html = '';
                        var shown = 0;
                        for(var i = sessions.length - 1; i >= 0 && shown < 10; i--) {
                            var s = sessions[i];
                            var dur = (s.end_time || 0) - (s.start_time || 0);
                            if(dur < 0) { dur = 0; }
                            var acc = s.exercises_attempted > 0 ? Math.round((s.exercises_correct / s.exercises_attempted) * 100) : 0;
                            html += '<tr>';
                            html += '<td><span class="session-type-badge">' + (s.session_type || 'review') + '</span></td>';
                            html += '<td>' + fmtDate(s.start_time || 0) + '</td>';
                            html += '<td>' + fmtDuration(dur) + '</td>';
                            html += '<td>' + (s.exercises_attempted || 0) + '</td>';
                            html += '<td>' + acc + '%</td>';
                            html += '</tr>';
                            shown++;
                        }
                        tbody.innerHTML = html;
                    })
                    .catch(function() {
                        document.getElementById('no-sessions').style.display = 'block';
                    });
            }

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
        return html_out
    }

    // Render course-specific analytics page
    public func render_course_analytics_page(db : *DbClient, course_id : &string, learner_id : &string) : string {
        var states = underlayer_repository::get_all_concept_states(db, learner_id, course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var sessions = underlayer_repository::get_learner_sessions(db, learner_id, 50)

        // Compute accuracy
        var total_items : int = 0
        var total_correct : int = 0
        var si : size_t = 0
        while(si < sessions.size()) {
            var s = sessions.get_ptr(si)
            total_items = total_items + s.exercises_attempted
            total_correct = total_correct + s.exercises_correct
            si = si + 1
        }
        var accuracy : f64 = 0.0
        if(total_items > 0) { accuracy = (total_correct as f64) / (total_items as f64) }
        var accuracy_pct = (accuracy * 100.0) as i64

        var total_concepts = health.total_concepts
        var mastered_count = health.mastered
        var learning_count = health.learning

        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Course Analytics — Underlayer"))

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
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                        <a href="/analytics" class="nav-link active">Analytics</a>
                    </div>
                    <div class="nav-right">
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">☀️</span>
                            <span class="theme-icon-dark">🌙</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Course Analytics</h1>
                    <p class="subtitle">Detailed analytics for course: <span id="course-title-label">elf</span></p>
                </div>

                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-number">{total_concepts}</div>
                        <div class="stat-label">Total Concepts</div>
                    </div>
                    <div class="stat-card stat-mastered">
                        <div class="stat-number">{mastered_count}</div>
                        <div class="stat-label">Mastered</div>
                    </div>
                    <div class="stat-card stat-learning">
                        <div class="stat-number">{learning_count}</div>
                        <div class="stat-label">Learning</div>
                    </div>
                    <div class="stat-card stat-accuracy">
                        <div class="stat-number">{accuracy_pct}%</div>
                        <div class="stat-label">Accuracy</div>
                    </div>
                </div>

                <div class="section-card">
                    <h2>Concept Progress</h2>
                    <div class="concept-list" id="concept-list">
                    </div>
                </div>

                <div class="section-card">
                    <h2>Recent Sessions</h2>
                    <div class="table-container">
                        <table class="data-table" id="course-sessions-table">
                            <thead>
                                <tr>
                                    <th>Type</th>
                                    <th>Date</th>
                                    <th>Duration</th>
                                    <th>Items</th>
                                    <th>Accuracy</th>
                                </tr>
                            </thead>
                            <tbody id="course-sessions-body">
                            </tbody>
                        </table>
                        <p class="muted" id="no-course-sessions" style="display:none">No sessions recorded for this course.</p>
                    </div>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
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
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .hamburger { display: none; background: none; border: none; cursor: pointer; padding: 0.5rem; }
            .hamburger-line { display: block; width: 24px; height: 2px; background: hsl(var(--foreground)); margin: 4px 0; transition: all 0.3s; }
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
            .stat-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; text-align: center; }
            .stat-number { font-size: 1.75rem; font-weight: 700; color: hsl(var(--foreground)); }
            .stat-label { font-size: 0.8rem; color: hsl(var(--muted-foreground)); margin-top: 0.25rem; text-transform: uppercase; letter-spacing: 0.03em; }
            .stat-mastered .stat-number { color: hsl(142 76% 36%); }
            .stat-learning .stat-number { color: hsl(38 92% 50%); }
            .stat-accuracy .stat-number { color: hsl(217 91% 60%); }
            .section-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; }
            .section-card h2 { font-size: 1.1rem; margin-bottom: 1rem; }
            .concept-list { display: flex; flex-direction: column; gap: 0.5rem; }
            .concept-row { display: flex; align-items: center; padding: 0.75rem 1rem; background: hsl(var(--secondary)); border-radius: 8px; }
            .concept-name { flex: 1; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .concept-status { font-size: 0.75rem; font-weight: 600; text-transform: uppercase; padding: 0.2rem 0.5rem; border-radius: 4px; }
            .status-mastered { background: hsl(142 76% 36% / 10%); color: hsl(142 76% 36%); }
            .status-learning { background: hsl(38 92% 50% / 10%); color: hsl(38 92% 50%); }
            .status-reviewing { background: hsl(0 84% 60% / 10%); color: hsl(0 84% 60%); }
            .status-not-started { background: hsl(var(--muted)); color: hsl(var(--muted-foreground)); }
            .table-container { overflow-x: auto; }
            .data-table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
            .data-table th { text-align: left; padding: 0.75rem; border-bottom: 2px solid hsl(var(--border)); color: hsl(var(--muted-foreground)); font-weight: 600; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.03em; }
            .data-table td { padding: 0.75rem; border-bottom: 1px solid hsl(var(--border)); color: hsl(var(--foreground)); }
            .data-table tr:last-child td { border-bottom: none; }
            .muted { color: hsl(var(--muted-foreground)); text-align: center; padding: 1.5rem; font-size: 0.9rem; }
            @media (max-width: 1300px) {
                .nav-links { display: none; position: absolute; top: 100%; left: 0; right: 0; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); flex-direction: column; padding: 1rem; gap: 0.5rem; }
                .nav-links.open { display: flex; }
                .nav-link { padding: 0.75rem 1rem; }
                .hamburger { display: block; }
            }
            @media (max-width: 768px) {
                .container { padding: 1rem; }
                .stats-grid { grid-template-columns: repeat(2, 1fr); }
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

            function fmtDuration(seconds) {
                var h = Math.floor(seconds / 3600);
                var m = Math.floor((seconds % 3600) / 60);
                if(h > 0) { return h + 'h ' + m + 'm'; }
                return m + 'm';
            }

            function fmtDate(ts) {
                var d = new Date(ts * 1000);
                return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});
            }

            function displayName(id) {
                var result = "";
                for(var i = 0; i < id.length; i++) {
                    var ch = id.charAt(i);
                    if(ch === "-") { result = result + " "; }
                    else if(i === 0) { result = result + ch.toUpperCase(); }
                    else if(id.charAt(i - 1) === "-") { result = result + ch.toUpperCase(); }
                    else { result = result + ch; }
                }
                return result;
            }

            window.addEventListener("DOMContentLoaded", function() {
                loadConceptList();
                loadSessions();
            });

            function loadConceptList() {
                fetch('/api/progress/:courseId?course_id=elf')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var concepts = data.concepts || [];
                        var list = document.getElementById('concept-list');
                        if(concepts.length === 0) {
                            list.innerHTML = '<p class="muted">No concept data available.</p>';
                            return;
                        }
                        var html = '';
                        for(var i = 0; i < concepts.length; i++) {
                            var c = concepts[i];
                            var statusClass = 'status-not-started';
                            var statusLabel = 'Not Started';
                            if(c.status === 'mastered') { statusClass = 'status-mastered'; statusLabel = 'Mastered'; }
                            else if(c.status === 'learning') { statusClass = 'status-learning'; statusLabel = 'Learning'; }
                            else if(c.status === 'reviewing') { statusClass = 'status-reviewing'; statusLabel = 'Reviewing'; }
                            html += '<div class="concept-row">';
                            html += '<span class="concept-name">' + (i + 1) + '. ' + displayName(c.concept_id) + '</span>';
                            html += '<span class="concept-status ' + statusClass + '">' + statusLabel + '</span>';
                            html += '</div>';
                        }
                        list.innerHTML = html;
                    })
                    .catch(function() {
                        document.getElementById('concept-list').innerHTML = '<p class="muted">Failed to load concepts.</p>';
                    });
            }

            function loadSessions() {
                fetch('/api/sessions')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var sessions = Array.isArray(data) ? data : (data.sessions || []);
                        var tbody = document.getElementById('course-sessions-body');
                        if(sessions.length === 0) {
                            document.getElementById('no-course-sessions').style.display = 'block';
                            return;
                        }
                        var html = '';
                        var shown = 0;
                        for(var i = sessions.length - 1; i >= 0 && shown < 10; i--) {
                            var s = sessions[i];
                            var dur = (s.end_time || 0) - (s.start_time || 0);
                            if(dur < 0) { dur = 0; }
                            var acc = s.exercises_attempted > 0 ? Math.round((s.exercises_correct / s.exercises_attempted) * 100) : 0;
                            html += '<tr>';
                            html += '<td>' + (s.session_type || 'review') + '</td>';
                            html += '<td>' + fmtDate(s.start_time || 0) + '</td>';
                            html += '<td>' + fmtDuration(dur) + '</td>';
                            html += '<td>' + (s.exercises_attempted || 0) + '</td>';
                            html += '<td>' + acc + '%</td>';
                            html += '</tr>';
                            shown++;
                        }
                        tbody.innerHTML = html;
                    })
                    .catch(function() {
                        document.getElementById('no-course-sessions').style.display = 'block';
                    });
            }

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
        return html_out
    }

}
