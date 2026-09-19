// underlayer_web — Streaks page.
// Client-side rendered activity streaks; data from GET /api/streaks and /api/streaks/weekly
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_streaks_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Streaks — Underlayer"))

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
                        <a href="/streaks" class="nav-link nav-link-active">Streaks</a>
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
                    <h1>Streaks</h1>
                    <p class="subtitle">Keep the habit alive &mdash; a little every day builds mastery.</p>
                </div>
                <div id="streak-zero" class="zero-state" hidden>
                    <div class="zero-icon">&#128293;</div>
                    <h2>No activity yet</h2>
                    <p>Complete a review session to start your streak. Day one is the hardest &mdash; and the most important.</p>
                    <a href="/review" class="btn btn-primary">Start a review</a>
                </div>
                <div id="streak-content" hidden>
                    <div class="stat-grid">
                        <div class="stat-card stat-highlight">
                            <div class="stat-label">Current streak</div>
                            <div class="stat-value"><span id="stat-current">0</span><span class="stat-unit">days</span></div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-label">Longest streak</div>
                            <div class="stat-value"><span id="stat-longest">0</span><span class="stat-unit">days</span></div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-label">Total active days</div>
                            <div class="stat-value"><span id="stat-total">0</span><span class="stat-unit">days</span></div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-label">Last active</div>
                            <div class="stat-value stat-value-date" id="stat-last">&mdash;</div>
                        </div>
                    </div>
                    <div class="week-panel">
                        <div class="week-head">
                            <h2>This week</h2>
                            <span class="week-note" id="week-note">Last 7 days</span>
                        </div>
                        <div class="week-row" id="week-row"></div>
                        <div class="week-legend">
                            <span class="legend-item"><span class="legend-swatch swatch-active"></span> Active</span>
                            <span class="legend-item"><span class="legend-swatch swatch-inactive"></span> Inactive</span>
                        </div>
                    </div>
                    <div class="tip-panel"><p id="streak-tip">Come back tomorrow to extend your streak.</p></div>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); }
            .nav-link-active { color: hsl(217 91% 60%); }
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
            .zero-state { text-align: center; padding: 3rem 1.5rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; }
            .zero-icon { font-size: 3rem; margin-bottom: 0.5rem; }
            .zero-state h2 { margin: 0 0 0.5rem 0; }
            .zero-state p { color: hsl(var(--muted-foreground)); max-width: 32rem; margin: 0 auto 1.5rem auto; }
            .stat-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; margin-bottom: 1.5rem; }
            .stat-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; }
            .stat-highlight { border-color: hsl(38 92% 50% / 60%); background: hsl(38 92% 50% / 6%); }
            .stat-label { font-size: 0.82rem; text-transform: uppercase; letter-spacing: 0.04em; color: hsl(var(--muted-foreground)); font-weight: 600; }
            .stat-value { font-size: 2rem; font-weight: 700; color: hsl(var(--foreground)); display: flex; align-items: baseline; gap: 0.4rem; }
            .stat-value-date { font-size: 1.35rem; }
            .stat-unit { font-size: 0.9rem; font-weight: 500; color: hsl(var(--muted-foreground)); }
            .week-panel { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; }
            .week-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; }
            .week-head h2 { font-size: 1.1rem; margin: 0; }
            .week-note { font-size: 0.82rem; color: hsl(var(--muted-foreground)); }
            .week-row { display: grid; grid-template-columns: repeat(7, 1fr); gap: 0.5rem; }
            .day-cell { display: flex; flex-direction: column; align-items: center; gap: 0.4rem; }
            .day-marker { width: 48px; height: 48px; border-radius: 10px; background: hsl(var(--secondary)); border: 1px solid hsl(var(--border)); display: flex; align-items: center; justify-content: center; font-weight: 700; color: hsl(var(--muted-foreground)); }
            .day-marker-active { background: hsl(38 92% 50%); border-color: hsl(38 92% 50%); color: white; }
            .day-marker-today { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .day-label { font-size: 0.72rem; color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.03em; }
            .week-legend { display: flex; gap: 1.25rem; margin-top: 1rem; }
            .legend-item { display: flex; align-items: center; gap: 0.4rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .legend-swatch { width: 14px; height: 14px; border-radius: 4px; display: inline-block; }
            .swatch-active { background: hsl(38 92% 50%); }
            .swatch-inactive { background: hsl(var(--secondary)); border: 1px solid hsl(var(--border)); }
            .tip-panel { margin-top: 1.5rem; padding: 1rem 1.25rem; background: hsl(217 91% 60% / 6%); border: 1px solid hsl(217 91% 60% / 30%); border-radius: 10px; }
            .tip-panel p { margin: 0; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.95rem; }
            .btn-primary { background: hsl(217 91% 60%); color: white; text-decoration: none; }
            .btn-primary:hover { background: hsl(217 91% 52%); }
            @media (max-width: 768px) { .nav-links { display: none; } .container { padding: 1rem; } .stat-grid { grid-template-columns: 1fr; } .day-marker { max-width: none; } }
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
            function authHeaders() {
                return { 'Authorization': 'Bearer ' + (localStorage.getItem('session_token') || '') };
            }
            function setText(id, value) {
                var el = document.getElementById(id);
                if (el) { el.textContent = String(value); }
            }
            function pad2(n) { return n < 10 ? '0' + n : '' + n; }
            function todayString() {
                var d = new Date();
                return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
            }
            function weekdayLabel(dateStr) {
                var names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                var parsed = new Date(dateStr + 'T00:00:00');
                if (isNaN(parsed.getTime())) { return '--'; }
                return names[parsed.getDay()];
            }
            function renderWeek(days) {
                var row = document.getElementById('week-row');
                while (row.firstChild) { row.removeChild(row.firstChild); }
                if (!days || days.length === 0) {
                    var empty = document.createElement('p');
                    empty.className = 'week-note';
                    empty.textContent = 'No activity recorded for this week.';
                    row.appendChild(empty);
                    return;
                }
                var today = todayString();
                var i = 0;
                while (i < days.length) {
                    var d = days[i];
                    var cell = document.createElement('div');
                    cell.className = 'day-cell';
                    var marker = document.createElement('div');
                    marker.className = 'day-marker';
                    if (d.active) { marker.className += ' day-marker-active'; }
                    if (d.date === today) { marker.className += ' day-marker-today'; }
                    marker.textContent = d.active ? String(d.sessions) : '';
                    marker.title = d.date + ' - ' + (d.active ? (d.sessions + ' session(s)') : 'no activity');
                    cell.appendChild(marker);
                    var label = document.createElement('div');
                    label.className = 'day-label';
                    label.textContent = weekdayLabel(d.date);
                    cell.appendChild(label);
                    row.appendChild(cell);
                    i = i + 1;
                }
            }
            function renderStreak(data) {
                var zero = document.getElementById('streak-zero');
                var content = document.getElementById('streak-content');
                var current = data.current_streak || 0;
                var longest = data.longest_streak || 0;
                var total = data.total_active_days || 0;
                if (current === 0 && total === 0) { zero.hidden = false; content.hidden = true; return; }
                zero.hidden = true;
                content.hidden = false;
                setText('stat-current', current);
                setText('stat-longest', longest);
                setText('stat-total', total);
                setText('stat-last', data.last_active_date ? data.last_active_date : '--');
                var tip = document.getElementById('streak-tip');
                if (tip) {
                    if (current === 1) { tip.textContent = 'You started today. Come back tomorrow to make it two.'; }
                    else if (current > 1) { tip.textContent = current + ' days in a row - one more tomorrow keeps it going.'; }
                    else { tip.textContent = 'Your streak has paused. A single session restarts it today.'; }
                }
                return;
            }
            fetch('/api/streaks', { headers: authHeaders() })
                .then(function(r) { return r.json(); })
                .then(function(data) { if (!data) { throw new Error('empty'); } renderStreak(data); })
                .catch(function() {
                    var zero = document.getElementById('streak-zero');
                    zero.hidden = false;
                    var h2 = zero.querySelector('h2');
                    if (h2) { h2.textContent = 'Could not load streaks'; }
                });
            fetch('/api/streaks/weekly', { headers: authHeaders() })
                .then(function(r) { return r.json(); })
                .then(function(data) { if (data && data.days) { renderWeek(data.days); } })
                .catch(function() {
                    var note = document.getElementById('week-note');
                    if (note) { note.textContent = 'Could not load weekly activity.'; }
                });
        }

        return page.toString()
    }

}
