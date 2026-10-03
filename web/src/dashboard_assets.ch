// underlayer_web — the dashboard's styles and script.
//
// SPLIT OUT OF handlers_dashboard.ch, and the reason is in the number: that
// file was 225 lines and the "what am I doing" work needed about forty more,
// which is over the 250-line rule.  home_assets.ch already does exactly this
// for the home page, so the shape is the collection's own rather than a new
// convention invented for one file.
//
// The navbar styles here are duplicated from lesson_nav.ch on purpose and were
// already duplicated before this split: /dashboard draws its own navbar
// instead of calling render_nav_bar, which is a separate defect and is not
// what this file is for.  What changed is that the two new blocks below --
// `.my-courses` and `.my-failures` -- are defined next to the JS that fills
// them, so a page and its own styles cannot drift.
using std::string

public namespace underlayer_web {

    public func render_dashboard_css(page : &mut HtmlPage) {
        #css {
            [data-chx-i] { display: contents; }

            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .container { font-family: system-ui, sans-serif; background: hsl(var(--background)); color: hsl(var(--foreground)); min-height: 100vh; }

            @media (max-width: 768px) {
                .container { padding: 1rem; }
            }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; }
            .back-to-top:hover { background: #111827; }
            .wd-head { margin-bottom: 2rem; }
            .wd-note { font-size: 0.85rem; color: hsl(var(--muted-foreground)); margin-top: 0.35rem; }
            .my-row { display: flex; align-items: center; gap: 0.75rem; padding: 0.7rem 0; border-bottom: 1px solid hsl(var(--border)); }
            .my-row:last-child { border-bottom: none; }
            .my-title { font-weight: 600; font-size: 0.95rem; }
            .my-sub { font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .my-nums { margin-left: auto; text-align: right; }
            .my-pct { font-weight: 700; font-size: 0.95rem; }
            .my-track { width: 90px; height: 6px; background: hsl(var(--secondary)); border-radius: 9999px; overflow: hidden; margin-top: 0.25rem; }
            .my-fill { height: 100%; width: 0%; background: hsl(217 91% 60%); border-radius: 9999px; }
            .my-empty { font-size: 0.9rem; color: hsl(var(--muted-foreground)); padding: 0.75rem 0; }
            .my-link { color: hsl(217 91% 60%); font-size: 0.8rem; text-decoration: none; white-space: nowrap; }
            .my-link:hover { text-decoration: underline; }
            .my-fail { padding: 0.6rem 0; border-bottom: 1px solid hsl(var(--border)); }
            .my-fail:last-child { border-bottom: none; }
            .my-fail-q { font-size: 0.9rem; }
            .my-fail-meta { font-size: 0.78rem; color: hsl(var(--muted-foreground)); margin-top: 0.2rem; }
            .my-bad { color: hsl(0 84% 60%); font-weight: 600; }
        }
    }

    public func render_dashboard_js(page : &mut HtmlPage) {
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

            // ---- what am I doing ----
            //
            // ONE endpoint, /api/me/overview, because the three answers are
            // drawn at once and three fetches would make the page flash between
            // states.  Every number is computed into a name before it is
            // printed: the js_cbi macro drops parentheses in operand position,
            // so `a + (b - c)` arrives as `a + b - c` and arithmetic inside a
            // string concatenation is arithmetically wrong, not just ugly.
            function wdToken() {
                var t = '';
                try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
                return t;
            }
            function wdText(id, text) {
                var el = document.getElementById(id);
                if (el) { el.textContent = text; }
            }
            function wdEl(tag, cls, text) {
                var el = document.createElement(tag);
                if (cls) { el.className = cls; }
                if (text !== undefined && text !== null) { el.textContent = text; }
                return el;
            }
            function wdCourseRow(c) {
                var row = wdEl('div', 'my-row');
                var left = wdEl('div');
                var a = wdEl('a', 'my-link', c.title);
                a.href = '/courses/' + encodeURIComponent(c.course_id);
                left.appendChild(a);
                var started = c.concepts_started;
                var total = c.concepts_total;
                left.appendChild(wdEl('div', 'my-sub', started + ' of ' + total + ' concepts read, ' + c.concepts_mastered + ' learned'));
                row.appendChild(left);
                var nums = wdEl('div', 'my-nums');
                nums.appendChild(wdEl('div', 'my-pct', c.progress_percentage + '%'));
                var track = wdEl('div', 'my-track');
                var fill = wdEl('div', 'my-fill');
                fill.style.width = c.progress_percentage + '%';
                track.appendChild(fill);
                nums.appendChild(track);
                row.appendChild(nums);
                return row;
            }
            function wdFailRow(f) {
                var box = wdEl('div', 'my-fail');
                box.appendChild(wdEl('div', 'my-fail-q', f.question));
                var meta = wdEl('div', 'my-fail-meta');
                var times = f.misses;
                meta.appendChild(wdEl('span', 'my-bad', 'missed ' + times + (times === 1 ? ' time' : ' times')));
                meta.appendChild(document.createTextNode(' in '));
                var a = wdEl('a', 'my-link', f.concept_id);
                a.href = f.lesson_url;
                meta.appendChild(a);
                box.appendChild(meta);
                return box;
            }
            function wdLoad() {
                var coursesEl = document.getElementById('wd-courses');
                var failsEl = document.getElementById('wd-failures');
                if (!coursesEl || !failsEl) { return; }
                var t = wdToken();
                var headers = {};
                if (t) { headers['Authorization'] = 'Bearer ' + t; }
                fetch('/api/me/overview', { headers: headers }).then(function(r) { return r.json(); }).then(function(d) {
                    wdText('wd-courses-count', d.courses_total);
                    wdText('wd-failures-count', d.failed_exercises_count);
                    var cs = d.courses || [];
                    if (cs.length === 0) {
                        coursesEl.appendChild(wdEl('div', 'my-empty', t ? 'Open a lesson and this fills in with the courses you are taking.' : 'Sign in, then open a lesson, and this fills in with the courses you are taking.'));
                    }
                    for (var i = 0; i < cs.length; i++) {
                        coursesEl.appendChild(wdCourseRow(cs[i]));
                    }
                    var fs = d.failed_exercises || [];
                    if (fs.length === 0) {
                        failsEl.appendChild(wdEl('div', 'my-empty', t ? 'Nothing missed yet.' : 'Sign in to see the questions you have got wrong.'));
                    }
                    for (var j = 0; j < fs.length; j++) {
                        failsEl.appendChild(wdFailRow(fs[j]));
                    }
                }).catch(function() {
                    coursesEl.appendChild(wdEl('div', 'my-empty', 'Could not load your courses. Is the backend running?'));
                });
            }
            document.addEventListener('DOMContentLoaded', function() { wdLoad(); });
        }
    }

}