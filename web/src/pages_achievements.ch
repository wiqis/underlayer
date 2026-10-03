// underlayer_web — Achievements page.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_achievements_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Achievements — Underlayer"))

        #html {
            {render_nav_bar(&mut page)}

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Achievements</h1>
                    <p class="subtitle">Badges you have earned on your learning journey.</p>
                </div>

                <div class="summary-card">
                    <div class="summary-icon" aria-hidden="true">&#127942;</div>
                    <div class="summary-text">
                        <div class="summary-number" id="ach-count">&mdash;</div>
                        <div class="summary-label" id="ach-count-label">achievements earned</div>
                    </div>
                </div>

                <div id="ach-list" class="ach-grid">
                    <p class="muted">Loading achievements&hellip;</p>
                </div>

                <div class="page-footer">
                    <a href="/dashboard" class="back-link">&larr; Back to dashboard</a>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">&uarr; Top</button>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }

            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }

            .container { max-width: 900px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 1.5rem; } .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; } .subtitle { color: hsl(var(--muted-foreground)); margin: 0; }
            .summary-card { display: flex; align-items: center; gap: 1rem; padding: 1.25rem 1.5rem; margin-bottom: 2rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; }
            .summary-icon { font-size: 2.25rem; line-height: 1; } .summary-number { font-size: 2rem; font-weight: 700; color: hsl(217 91% 60%); line-height: 1.1; } .summary-label { font-size: 0.9rem; color: hsl(var(--muted-foreground)); }
            .ach-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; }
            .ach-card { display: flex; gap: 1rem; padding: 1.25rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; transition: transform 0.15s, border-color 0.15s; }
            .ach-card:hover { transform: translateY(-2px); border-color: hsl(217 91% 60%); } .ach-icon { font-size: 2rem; line-height: 1; flex-shrink: 0; }
            .ach-title { font-size: 1rem; font-weight: 600; color: hsl(var(--foreground)); margin: 0 0 0.25rem 0; } .ach-desc { font-size: 0.85rem; color: hsl(var(--muted-foreground)); margin: 0 0 0.5rem 0; } .ach-date { font-size: 0.78rem; color: hsl(var(--muted-foreground)); font-weight: 500; }
            .ach-badge { display: inline-block; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.04em; color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); padding: 0.15rem 0.5rem; border-radius: 999px; margin-bottom: 0.4rem; }
            .empty-state { grid-column: 1 / -1; text-align: center; padding: 3rem 1rem; background: hsl(var(--card)); border: 1px dashed hsl(var(--border)); border-radius: 12px; }
            .empty-icon { font-size: 2.5rem; } .empty-title { font-size: 1.1rem; font-weight: 600; margin: 0.75rem 0 0.25rem 0; }
            .muted { color: hsl(var(--muted-foreground)); } .page-footer { margin-top: 2rem; } .back-link { color: hsl(217 91% 60%); text-decoration: none; font-size: 0.9rem; } .back-link:hover { text-decoration: underline; }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; } .back-to-top:hover { background: #111827; }
            @media (max-width: 768px) {
                .container { padding: 1rem; } .ach-grid { grid-template-columns: 1fr; }
            }
        }

        #js {
            var ICONS = {
                flame: '\uD83D\uDD25',
                fire: '\uD83D\uDD25',
                trophy: '\uD83C\uDFC6',
                diamond: '\uD83D\uDC8E',
                seedling: '\uD83C\uDF31',
                book: '\uD83D\uDCD6',
                star: '\u2B50',
                compass: '\uD83E\uDDED',
                crown: '\uD83D\uDC51',
                medal: '\uD83C\uDFC5'
            };
            function iconFor(name) {
                if (name && ICONS[name]) return ICONS[name];
                return ICONS.medal;
            }
            function formatDate(ts) {
                var n = Number(ts);
                if (!n || n <= 0) return 'Date unknown';
                var d = new Date(n * 1000);
                if (isNaN(d.getTime())) return 'Date unknown';
                return d.toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });
            }
            function buildCard(a) {
                var card = document.createElement('div');
                card.className = 'ach-card';
                var iconEl = document.createElement('div');
                iconEl.className = 'ach-icon';
                iconEl.setAttribute('aria-hidden', 'true');
                iconEl.textContent = iconFor(a.icon);
                card.appendChild(iconEl);
                var body = document.createElement('div');
                body.className = 'ach-body';
                var badge = document.createElement('div');
                badge.className = 'ach-badge';
                if (a.badge_type) { badge.textContent = String(a.badge_type).split('_').join(' '); } else { badge.textContent = 'achievement'; }
                body.appendChild(badge);
                var title = document.createElement('h2');
                title.className = 'ach-title';
                title.textContent = a.badge_name || 'Achievement';
                body.appendChild(title);
                var desc = document.createElement('p');
                desc.className = 'ach-desc';
                desc.textContent = a.description || '';
                body.appendChild(desc);
                var date = document.createElement('div');
                date.className = 'ach-date';
                date.textContent = 'Earned ' + formatDate(a.earned_at);
                body.appendChild(date);
                card.appendChild(body);
                return card;
            }
            function renderEmpty(list) {
                var box = document.createElement('div');
                box.className = 'empty-state';
                var icon = document.createElement('div');
                icon.className = 'empty-icon';
                icon.setAttribute('aria-hidden', 'true');
                icon.textContent = '\uD83C\uDF1F';
                box.appendChild(icon);
                var title = document.createElement('div');
                title.className = 'empty-title';
                title.textContent = 'No achievements yet - keep learning!';
                box.appendChild(title);
                var hint = document.createElement('p');
                hint.className = 'muted';
                hint.textContent = 'Complete exercises, build study streaks, and master concepts to earn badges.';
                box.appendChild(hint);
                list.appendChild(box);
            }
            function renderAchievements(items) {
                var list = document.getElementById('ach-list');
                while (list.firstChild) { list.removeChild(list.firstChild); }
                if (!items || items.length === 0) { renderEmpty(list); return; }
                var i = 0;
                while (i < items.length) { list.appendChild(buildCard(items[i])); i = i + 1; }
            }
            function setCount(n) {
                document.getElementById('ach-count').textContent = String(n);
                document.getElementById('ach-count-label').textContent = (n === 1) ? 'achievement earned' : 'achievements earned';
            }
            function showError() {
                var list = document.getElementById('ach-list');
                while (list.firstChild) { list.removeChild(list.firstChild); }
                var p = document.createElement('p');
                p.className = 'muted';
                p.textContent = 'Could not load achievements. Please try again later.';
                list.appendChild(p);
            }
            var authHeader = { 'Authorization': 'Bearer ' + (localStorage.getItem('session_token') || '') };
            Promise.all([
                fetch('/api/achievements', { headers: authHeader }).then(function(r) { return r.json(); }),
                fetch('/api/achievements/count', { headers: authHeader }).then(function(r) { return r.json(); })
            ]).then(function(results) {
                var items = results[0];
                var countData = results[1];
                if (!items || !items.length) { renderAchievements([]); }
                else { renderAchievements(items); }
                var count = (countData && typeof countData.count === 'number') ? countData.count : (items ? items.length : 0);
                setCount(count);
            }).catch(function() { showError(); });
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
