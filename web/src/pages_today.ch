// underlayer_web — G2 "Today" page: one click builds the day's plan.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_today_page(db : *DbClient, req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        underlayer_content::render_theme_boot_js(&mut page, false)
        underlayer_content::render_color_scheme_meta(&mut page)
        var title = std::string_view("Today — Underlayer")
        page.appendTitle(&title)
        render_session_js(&mut page)

        #html {
            {render_nav_bar(&mut page)}
            <main class="container today-page" id="main-content">
                <h1>Today</h1>
                <p class="today-subtitle" id="today-message" aria-live="polite">Your plan for today.</p>
                <div class="today-card">
                    <div class="today-head">
                        <span id="today-goal">A short, finishable session</span>
                        <button class="btn btn-primary" id="today-generate" type="button">Build my day</button>
                    </div>
                    <ol class="today-list" id="today-list" aria-live="polite">
                        <li class="today-empty">Nothing planned yet. Build your day to see what's due.</li>
                    </ol>
                    <div class="today-actions">
                        <button class="btn btn-ghost" id="today-complete" type="button" disabled>Done for today</button>
                        <a class="btn btn-link" href="/review">Go to reviews</a>
                    </div>
                    <p class="today-note">Missed a day? That's fine. Pick up where you are — nothing is lost.</p>
                </div>
            </main>
        }

        #css {
            .today-page { max-width: 46rem; padding: 2rem 1rem; color: hsl(var(--foreground)); }
            .today-page h1 { font-size: 2rem; margin: 0 0 0.5rem; }
            .today-subtitle { color: hsl(var(--muted-foreground)); margin: 0 0 1.5rem; }
            .today-card { border: 1px solid hsl(var(--border)); border-radius: 12px; background: hsl(var(--card)); padding: 1.5rem; }
            .today-head { display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap; }
            .today-list { list-style: none; padding: 0; margin: 1.25rem 0; }
            .today-list li { display: flex; justify-content: space-between; gap: 1rem; padding: 0.75rem 0; border-bottom: 1px solid hsl(var(--border)); }
            .today-list .today-empty { color: hsl(var(--muted-foreground)); border-bottom: none; }
            .today-list .today-kind { color: hsl(var(--muted-foreground)); font-size: 0.85rem; text-transform: capitalize; }
            .today-list a { color: hsl(217 91% 60%); }
            .today-actions { display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap; }
            .today-note { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin-top: 1.25rem; }
            .btn { padding: 0.65rem 1.2rem; border-radius: 8px; font-weight: 600; cursor: pointer; border: 1px solid transparent; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-ghost { background: transparent; color: hsl(var(--foreground)); border-color: hsl(var(--border)); }
            .btn-ghost:disabled { opacity: 0.5; cursor: not-allowed; }
            .btn-link { background: transparent; color: hsl(217 91% 60%); text-decoration: underline; }
        }

        #js {
            var todayPlanId = '';
            function todayHeaders() {
                var h = { 'Content-Type': 'application/json' };
                if (typeof window.__ulHeaders === 'function') {
                    var s = window.__ulHeaders();
                    for (var k in s) { if (Object.prototype.hasOwnProperty.call(s, k)) { h[k] = s[k]; } }
                }
                return h;
            }
            function todayGuest() {
                var id = null;
                try { id = localStorage.getItem('ul_guest_id'); } catch(e) { id = null; }
                return id || '';
            }
            function todayLoadStatus() {
                fetch('/api/today?guest_id=' + encodeURIComponent(todayGuest()), { credentials: 'same-origin' })
                    .then(function(r) { return r.json(); })
                    .then(function(d) {
                        var msg = document.getElementById('today-message');
                        if (msg && d.message) { msg.textContent = d.message + '. Your plan for today.'; }
                        if (d.goal_minutes) {
                            var goal = document.getElementById('today-goal');
                            if (goal) { goal.textContent = 'About ' + d.goal_minutes + ' minutes'; }
                        }
                    })
                    .catch(function() {});
            }
            function todayBuild() {
                var list = document.getElementById('today-list');
                fetch('/api/today/plan', {
                    method: 'POST', credentials: 'same-origin', headers: todayHeaders(),
                    body: JSON.stringify({ guest_id: todayGuest() })
                })
                .then(function(r) { return r.json(); })
                .then(function(d) {
                    if (!d.items) { return; }
                    todayPlanId = d.plan_id || '';
                    list.textContent = '';
                    var i = 0;
                    while (i < d.items.length) {
                        var item = d.items[i];
                        var li = document.createElement('li');
                        var left = document.createElement('span');
                        left.textContent = item.kind === 'review' ? 'Review ' + item.concept_id : 'Learn ' + item.concept_id;
                        var right = document.createElement('span');
                        right.className = 'today-kind';
                        right.textContent = item.kind === 'review' ? '3 min' : (item.minutes || 6) + ' min';
                        li.appendChild(left);
                        li.appendChild(right);
                        list.appendChild(li);
                        i = i + 1;
                    }
                    var done = document.getElementById('today-complete');
                    if (done) { done.disabled = false; }
                })
                .catch(function() {});
            }
            function todayDone() {
                if (!todayPlanId) { return; }
                fetch('/api/today/complete', {
                    method: 'POST', credentials: 'same-origin', headers: todayHeaders(),
                    body: JSON.stringify({ plan_id: todayPlanId, guest_id: todayGuest() })
                })
                .then(function(r) { return r.json(); })
                .then(function() {
                    var done = document.getElementById('today-complete');
                    if (done) { done.textContent = 'Saved for today'; done.disabled = true; }
                })
                .catch(function() {});
            }
            document.addEventListener('DOMContentLoaded', function() {
                var b = document.getElementById('today-generate');
                var d = document.getElementById('today-complete');
                if (b) { b.onclick = todayBuild; }
                if (d) { d.onclick = todayDone; }
                todayLoadStatus();
            });
        }
        return underlayer_web::send_page(&page)
    }

}
