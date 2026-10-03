// Home page CSS + JS, extracted from handlers_home.ch (250-line rule).
// Includes the dynamic Available Courses loader: #html cannot loop, so cards
// render client-side from GET /api/courses (same pattern as onboarding).
public namespace underlayer_web {

    func render_home_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }

            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            a { color: hsl(217 91% 60%); text-decoration: none; }
            a:hover { text-decoration: underline; }

            .hero { background: linear-gradient(135deg, hsl(213 60% 24%) 0%, hsl(217 91% 60%) 100%); color: white; padding: 4rem 2rem; }
            .hero-inner { max-width: 800px; margin: 0 auto; text-align: center; }
            .hero h1 { font-size: 2.5rem; margin-bottom: 1rem; font-weight: 700; }
            .hero p { font-size: 1.1rem; opacity: 0.9; line-height: 1.7; max-width: 600px; margin: 0 auto; }
            .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
            .section { margin-bottom: 3rem; }
            .section h2 { font-size: 1.5rem; margin-bottom: 1.5rem; color: hsl(var(--foreground)); }
            .course-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 1.5rem; }
            .course-loading { grid-column: 1 / -1; color: hsl(var(--muted-foreground)); font-size: 0.95rem; padding: 0.5rem 0; }
            .course-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; transition: box-shadow 0.2s; }
            .course-card:hover { box-shadow: 0 4px 12px hsl(var(--shadow)); }
            .course-badge { display: inline-block; padding: 0.25rem 0.75rem; background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); border-radius: 9999px; font-size: 0.8rem; font-weight: 500; margin-bottom: 1rem; }
            .course-card h3 { font-size: 1.25rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .course-card p { color: hsl(var(--muted-foreground)); margin-bottom: 1rem; font-size: 0.95rem; }
            .course-stats { display: flex; gap: 1rem; margin-bottom: 1rem; font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border-radius: 8px; font-weight: 500; font-size: 0.9rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            .feature-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1.5rem; }
            .feature-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .feature-icon { width: 40px; height: 40px; background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 1.1rem; margin-bottom: 1rem; }
            .feature-card h3 { font-size: 1.1rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .feature-card p { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .action-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1rem; }
            .action-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; text-decoration: none; transition: all 0.15s; }
            .action-card:hover { border-color: hsl(217 91% 60%); box-shadow: 0 2px 8px hsl(217 91% 60% / 20%); text-decoration: none; }
            .action-card h3 { font-size: 1rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .action-card p { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin: 0; }
            .search-trigger { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; color: hsl(var(--muted-foreground)); display: flex; align-items: center; justify-content: center; }
            .search-trigger:hover { background: hsl(var(--accent)); color: hsl(var(--foreground)); }
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
            .search-result-more { color: hsl(217 91% 60%); font-weight: 600; }

            @media (max-width: 768px) {
                .hero { padding: 2rem 1rem; }
                .hero h1 { font-size: 1.75rem; }
                .hero p { font-size: 1rem; }
                .container { padding: 1rem; }
                .course-grid { grid-template-columns: 1fr; }
                .feature-grid { grid-template-columns: 1fr; }
                .action-grid { grid-template-columns: 1fr; }
            }
            @media (min-width: 769px) and (max-width: 1024px) {
                .course-grid { grid-template-columns: repeat(2, 1fr); }
                .feature-grid { grid-template-columns: repeat(2, 1fr); }
                .action-grid { grid-template-columns: repeat(2, 1fr); }
            }
        }
    }

    func render_home_js(page : &mut HtmlPage) {
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

            document.addEventListener("keydown", function(e) {
                if((e.ctrlKey || e.metaKey) && e.key === "k") { e.preventDefault(); openSearch(); }
                if(e.key === "Escape") { closeSearch(); }
            });

            function escapeHtml(s) {
                var str = String(s);
                var out = '';
                var i = 0;
                while(i < str.length) {
                    var ch = str.charAt(i);
                    if(ch === '&') { out += '&amp;'; }
                    else if(ch === '<') { out += '&lt;'; }
                    else if(ch === '>') { out += '&gt;'; }
                    else if(ch === '"') { out += '&quot;'; }
                    else if(ch === "'") { out += '&#39;'; }
                    else { out += ch; }
                    i = i + 1;
                }
                return out;
            }

            function loadHomeCourses() {
                var grid = document.getElementById('course-grid');
                if(!grid) { return; }
                fetch('/api/courses').then(function(r) { return r.json(); }).then(function(courses) {
                    if(!courses || courses.length === 0) {
                        grid.innerHTML = '<div class="course-loading">No courses available yet.</div>';
                        return;
                    }
                    var html = '';
                    var ci = 0;
                    while(ci < courses.length) {
                        var c = courses[ci];
                        var modules = c.modules || 0;
                        var lessons = c.concepts || 0;
                        var diff = '';
                        if(c.difficulty) { diff = c.difficulty.charAt(0).toUpperCase() + c.difficulty.substring(1); }
                        var cid = encodeURIComponent(c.id);
                        var ctitle = escapeHtml(c.title || c.id);
                        var cdesc = escapeHtml(c.description || '');
                        html += '<div class="course-card">';
                        html += '<div class="course-badge">' + modules + ' Modules</div>';
                        html += '<h3>' + ctitle + '</h3>';
                        html += '<p>' + cdesc + '</p>';
                        html += '<div class="course-stats"><span>' + lessons + ' Lessons</span><span>' + diff + '</span></div>';
                        html += '<a href="/courses/' + cid + '" class="btn btn-primary">Start Learning</a>';
                        html += '</div>';
                        ci = ci + 1;
                    }
                    grid.innerHTML = html;
                }).catch(function() {
                    grid.innerHTML = '<div class="course-loading">Could not load courses. Refresh to retry.</div>';
                });
            }
            loadHomeCourses();
        }
    }

}
