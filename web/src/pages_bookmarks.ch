// underlayer_web — Bookmarks page.
// Client-side rendered list of bookmarked concepts; data from GET /api/bookmarks
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_bookmarks_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Bookmarks — Underlayer"))

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
                        <a href="/bookmarks" class="nav-link active">Bookmarks</a>
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
                    <h1>Bookmarks</h1>
                    <p class="subtitle">Concepts you saved for later</p>
                    <a href="/courses/elf" class="back-link">&larr; Back to course</a>
                </div>

                <div id="bm-body">
                    <p class="muted">Loading bookmarks...</p>
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
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
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
            .muted { color: hsl(var(--muted-foreground)); }
            .bm-list { display: flex; flex-direction: column; gap: 0.75rem; }
            .bm-card { display: flex; align-items: flex-start; gap: 1rem; padding: 1rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; }
            .bm-main { flex: 1; min-width: 0; }
            .bm-link { font-size: 1rem; font-weight: 600; color: hsl(217 91% 60%); text-decoration: none; word-break: break-word; }
            .bm-link:hover { text-decoration: underline; }
            .bm-meta { font-size: 0.78rem; color: hsl(var(--muted-foreground)); margin-top: 0.25rem; }
            .bm-note { font-size: 0.85rem; color: hsl(var(--foreground)); margin-top: 0.5rem; padding: 0.5rem 0.75rem; background: hsl(var(--secondary)); border-radius: 6px; white-space: pre-wrap; }
            .bm-remove { background: hsl(var(--secondary)); color: hsl(var(--foreground)); border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem 0.9rem; cursor: pointer; font-size: 0.85rem; font-weight: 500; flex-shrink: 0; }
            .bm-remove:hover { background: hsl(0 84% 60%); color: white; border-color: hsl(0 84% 60%); }
            .empty-state { text-align: center; padding: 3rem 1rem; color: hsl(var(--muted-foreground)); }
            .empty-state .empty-title { font-size: 1.1rem; font-weight: 600; color: hsl(var(--foreground)); margin-bottom: 0.5rem; }
            .empty-state a { color: hsl(217 91% 60%); text-decoration: none; font-weight: 500; }
            .empty-state a:hover { text-decoration: underline; }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; }
            .back-to-top:hover { background: #111827; }
            @media (max-width: 768px) {
                .nav-links { display: none; }
                .container { padding: 1rem; }
                .bm-card { flex-direction: column; }
                .bm-remove { align-self: flex-start; }
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

            function authHeaders() {
                return { 'Authorization': 'Bearer ' + (localStorage.getItem('session_token') || '') };
            }

            function showEmpty(body, title, message) {
                body.innerHTML = '';
                var wrap = document.createElement('div');
                wrap.className = 'empty-state';
                var t = document.createElement('div');
                t.className = 'empty-title';
                t.textContent = title;
                var m = document.createElement('p');
                m.textContent = message;
                wrap.appendChild(t);
                wrap.appendChild(m);
                var a = document.createElement('a');
                a.setAttribute('href', '/courses/elf');
                a.textContent = 'Browse the ELF course';
                wrap.appendChild(a);
                body.appendChild(wrap);
            }

            function buildCard(bm, reload) {
                var card = document.createElement('div');
                card.className = 'bm-card';

                var main = document.createElement('div');
                main.className = 'bm-main';

                var course = bm.course_id || 'elf';
                var link = document.createElement('a');
                link.className = 'bm-link';
                link.setAttribute('href', '/courses/' + course + '/lessons/' + bm.concept_id);
                link.textContent = bm.concept_id;
                main.appendChild(link);

                var meta = document.createElement('div');
                meta.className = 'bm-meta';
                meta.textContent = course + ' / ' + bm.concept_id;
                main.appendChild(meta);

                if (bm.note && bm.note.length > 0) {
                    var note = document.createElement('div');
                    note.className = 'bm-note';
                    note.textContent = bm.note;
                    main.appendChild(note);
                }

                card.appendChild(main);

                var btn = document.createElement('button');
                btn.className = 'bm-remove';
                btn.textContent = 'Remove';
                btn.addEventListener('click', function() {
                    btn.disabled = true;
                    btn.textContent = 'Removing...';
                    fetch('/api/bookmarks/' + encodeURIComponent(bm.concept_id), {
                        method: 'DELETE',
                        headers: authHeaders()
                    }).then(function(r) {
                        if (r.ok) {
                            reload();
                        } else {
                            btn.disabled = false;
                            btn.textContent = 'Remove';
                        }
                    }).catch(function() {
                        btn.disabled = false;
                        btn.textContent = 'Remove';
                    });
                });
                card.appendChild(btn);

                return card;
            }

            function load() {
                var body = document.getElementById('bm-body');
                fetch('/api/bookmarks', { headers: authHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if (!data || !Array.isArray(data)) {
                            showEmpty(body, 'Could not load bookmarks', 'Please sign in and try again.');
                            return;
                        }
                        if (data.length === 0) {
                            showEmpty(body, 'No bookmarks yet', 'Save concepts while reading to find them here.');
                            return;
                        }
                        body.innerHTML = '';
                        var list = document.createElement('div');
                        list.className = 'bm-list';
                        var i = 0;
                        while (i < data.length) {
                            list.appendChild(buildCard(data[i], load));
                            i = i + 1;
                        }
                        body.appendChild(list);
                    }).catch(function() {
                        showEmpty(body, 'Could not load bookmarks', 'The request failed. Please try again.');
                    });
            }

            load();

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
