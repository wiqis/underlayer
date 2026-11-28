// Home page CSS + JS, extracted from handlers_home.ch (250-line rule).
// The single course card is filled from GET /api/courses -- the same source
// /courses and /learning-path read -- so the lesson count and the first-lesson
// link cannot drift from the rest of the site.
public namespace underlayer_web {

    func render_home_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            a { color: hsl(var(--primary)); text-decoration: none; }
            a:hover { text-decoration: underline; }
            :focus-visible { outline: 2px solid hsl(var(--primary)); outline-offset: 2px; }

            .home-hero { border-bottom: 1px solid hsl(var(--border)); background: hsl(var(--accent)); padding: 4rem 1.5rem; }
            .home-hero-inner { max-width: 720px; margin: 0 auto; text-align: center; }
            .home-eyebrow { margin: 0 0 0.75rem; font-size: 0.78rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em; color: hsl(var(--primary)); }
            .home-hero h1 { font-size: 2.6rem; line-height: 1.15; margin: 0 0 1rem; letter-spacing: -0.03em; }
            .home-lede { font-size: 1.1rem; color: hsl(var(--muted-foreground)); max-width: 60ch; margin: 0 auto; }
            .home-actions { margin: 2rem 0 0.5rem; }
            .btn { display: inline-block; padding: 0.75rem 1.4rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); }
            .btn-primary:hover { filter: brightness(1.06); text-decoration: none; }
            .home-secondary { margin: 0; font-size: 0.9rem; }
            .container { max-width: 900px; margin: 0 auto; padding: 2.5rem 1.5rem; }
            .home-next h2 { font-size: 1rem; text-transform: uppercase; letter-spacing: 0.06em; color: hsl(var(--muted-foreground)); margin: 0 0 0.85rem; }
            .home-course-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--primary)); border-radius: 12px; padding: 1.5rem; }
            .home-course-card h3 { font-size: 1.35rem; margin: 0 0 0.4rem; }
            .home-course-meta { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0 0 0.9rem; }
            .home-course-link { font-weight: 600; font-size: 0.95rem; }

            .takeover-prompt { max-width: 720px; margin: 1.5rem auto 0; padding: 1rem 1.25rem; border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--primary)); border-radius: 12px; background: hsl(var(--card)); }
            .takeover-prompt h2 { font-size: 1.1rem; margin: 0 0 0.5rem; }
            .takeover-prompt p { margin: 0 0 0.75rem; color: hsl(var(--muted-foreground)); }
            .takeover-prompt button { margin-right: 0.5rem; }
            .takeover-status { margin-top: 0.5rem; min-height: 1.25rem; font-size: 0.9rem; }

            .search-modal { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1000; }
            .search-modal.open { display: flex; align-items: flex-start; justify-content: center; padding-top: 20vh; }
            .search-backdrop { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.5); }
            .search-dialog { position: relative; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; width: 90%; max-width: 500px; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3); overflow: hidden; }
            .search-input { width: 100%; padding: 1rem 1.25rem; border: none; background: transparent; font-size: 1rem; color: hsl(var(--foreground)); outline: none; }
            .search-input::placeholder { color: hsl(var(--muted-foreground)); }
            .search-results { max-height: 300px; overflow-y: auto; }
            .search-result-item { display: flex; flex-direction: column; gap: 0.1rem; padding: 0.75rem 1.25rem; color: hsl(var(--foreground)); text-decoration: none; border-top: 1px solid hsl(var(--border)); }
            .search-result-item:hover { background: hsl(var(--accent)); }
            .search-hint { padding: 0.5rem 1.25rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); border-top: 1px solid hsl(var(--border)); }
            .search-result-title { font-weight: 600; }
            .search-result-course { font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .search-result-more { color: hsl(var(--primary)); font-weight: 600; }

            @media (max-width: 700px) {
                .home-hero { padding: 2.5rem 1rem; }
                .home-hero h1 { font-size: 1.9rem; }
                .home-lede { font-size: 1rem; }
                .container { padding: 1.5rem 1rem; }
            }
        }
    }

    func render_home_js(page : &mut HtmlPage) {
        #js {
            function homeStart() {
                var cfg = document.getElementById('ul-home-config');
                if(cfg) { return cfg.getAttribute('data-start-here') || '/courses/elf/lessons/bytes'; }
                return '/courses/elf/lessons/bytes';
            }

            // A learner has progress when the journey runtime has stored a step.
            // This is local-first: no account and no API call needed.
            function homeSavedLesson() {
                var found = null;
                try {
                    var i = 0;
                    while(i < localStorage.length) {
                        var k = localStorage.key(i);
                        if(k && k.indexOf('ul-journey:') === 0) {
                            var parts = k.split(':');
                            if(parts.length >= 3 && parts[1].length > 0 && parts[2].length > 0) {
                                found = { course: parts[1], concept: parts[2] };
                                break;
                            }
                        }
                        i = i + 1;
                    }
                } catch(e) { found = null; }
                return found;
            }

            function homePaintCta() {
                var start = homeStart();
                var saved = homeSavedLesson();
                var label = 'Start the first lesson';
                var href = start;
                if(saved) {
                    label = 'Continue where you left off';
                    href = '/courses/' + encodeURIComponent(saved.course) + '/lessons/' + encodeURIComponent(saved.concept);
                }
                var cta = document.getElementById('home-primary-cta');
                if(cta) { cta.textContent = label; cta.href = href; }
                var card = document.getElementById('home-course-cta');
                if(card) {
                    card.textContent = saved ? 'Continue this course' : 'Open the first lesson';
                    card.href = href;
                }
            }

            function loadHomeCourses() {
                homePaintCta();
                fetch('/api/courses').then(function(r) { return r.json(); }).then(function(courses) {
                    if(!courses || courses.length === 0) { return; }
                    var featured = courses[0];
                    var i = 0;
                    while(i < courses.length) {
                        if(courses[i].id === 'elf') { featured = courses[i]; break; }
                        i = i + 1;
                    }
                    var title = document.getElementById('home-course-title');
                    if(title) { title.textContent = featured.title || featured.id; }
                    var meta = document.getElementById('home-course-meta');
                    if(meta) {
                        var minutes = featured.first_minutes || 0;
                        var level = featured.first_difficulty || featured.difficulty || '';
                        meta.textContent = (featured.concepts || 0) + ' lessons  |  ' + minutes + ' min first lesson  |  ' + level;
                    }
                }).catch(function() {
                    var meta = document.getElementById('home-course-meta');
                    if(meta) { meta.textContent = 'The guided path is ready when you are.'; }
                });
            }

            // G13 — one dismissible prompt. The guest changes were recorded
            // offline in localStorage; the server token is one-shot and the
            // replay uses the same per-key updated_at rule as sync. On success
            // (and only then) the local queue is cleared.
            function takeoverInit() {
                var prompt = document.getElementById('takeover-prompt');
                if(!prompt) { return; }
                var changes = null;
                try { changes = JSON.parse(localStorage.getItem('ul_guest_changes') || 'null'); } catch(e) { changes = null; }
                var token = localStorage.getItem('session_token') || '';
                if(!changes || changes.length === 0 || !token) { return; }
                if(localStorage.getItem('ul_takeover_dismissed') === '1') { return; }
                prompt.hidden = false;
                var status = document.getElementById('takeover-status');
                document.getElementById('takeover-dismiss').onclick = function() {
                    localStorage.setItem('ul_takeover_dismissed', '1');
                    prompt.hidden = true;
                };
                document.getElementById('takeover-keep').onclick = function() {
                    fetch('/api/progress/takeover/token', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' } })
                    .then(function(r) { return r.json(); })
                    .then(function(d) {
                        return fetch('/api/progress/takeover', {
                            method: 'POST', credentials: 'same-origin',
                            headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
                            body: JSON.stringify({ token: d.token, changes: changes })
                        });
                    })
                    .then(function(r) { return r.json().then(function(j) { return { ok: r.ok, j: j }; }); })
                    .then(function(out) {
                        if(out.ok && out.j && out.j.applied) {
                            localStorage.removeItem('ul_guest_changes');
                            prompt.hidden = true;
                            if(status) { status.textContent = 'Progress kept. Your review schedule was not changed.'; }
                        } else {
                            if(status) { status.textContent = (out.j && out.j.error) ? out.j.error : 'Could not bring the progress over. Try again.'; }
                        }
                    })
                    .catch(function() { if(status) { status.textContent = 'Could not bring the progress over. Try again.'; } });
                };
            }

            document.addEventListener("keydown", function(e) {
                if((e.ctrlKey || e.metaKey) && e.key === "k") { e.preventDefault(); openSearch(); }
                if(e.key === "Escape") { closeSearch(); }
            });

            loadHomeCourses();
            takeoverInit();
        }
    }

}
