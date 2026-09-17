// Generic data-driven course landing page.
//
// Works for ANY course id — content is derived from the parsed Course model:
//   - Title / description / meta chips: interpolated server-side via {string}
//     interpolation and {int} (verified working constructs in html_cbi).
//   - Module list: rendered client-side by JS from /api/courses/:id
//     (the same pattern production pages use for dynamic lists — #html blocks
//      cannot contain loops: html_cbi's @{} statement blocks are broken, see
//      docs/implementation-gaps.md).
//
// Macro constraints honored: every #html block is internally balanced, all
// markup lives inside #html/#css/#js macro blocks (golden rule 7). Course
// strings are HTML-escaped server-side before interpolation (interpolation
// is raw — no auto-escaping).
public namespace underlayer_content {

using std::string
using std::string_view
using underlayer_models::Course

    public func render_course_landing(course : &Course) : string {
        var page = HtmlPage()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()

        var title_full = course.title.copy()
        title_full.append_view(string_view(" — Underlayer"))
        var tsv = title_full.to_view()
        page.appendTitle(&tsv)

        // Copy fields out first (move checker treats repeated member access on
        // a &Course param as moves); then escape the copies server-side.
        var f_title = course.title.copy()
        var f_desc = course.description.copy()
        var f_id = course.id.copy()
        var f_diff = course.difficulty.copy()
        var esc_title = underlayer_core::html_escape(&f_title)
        var esc_desc = underlayer_core::html_escape(&f_desc)
        var esc_course_id = underlayer_core::html_escape(&f_id)
        var esc_difficulty = underlayer_core::html_escape(&f_diff)

        var module_count = course.modules.size() as int
        var concept_count = course.concepts.size() as int

        // The module list container is filled by JS (fetch /api/courses/:id).
        // Concept links follow /courses/<id>/lessons/<concept>.
        render_landing_css(&mut page)

        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses" class="nav-link active">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                    </div>
                    <div class="nav-progress" id="nav-progress" hidden>
                        <div class="nav-progress-track" id="nav-progress-bar" role="progressbar" aria-label="Course progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
                            <div class="nav-progress-fill" id="nav-progress-fill"></div>
                        </div>
                        <a href="/review" class="nav-due-badge" id="nav-due-badge" hidden></a>
                    </div>
                    <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                        <span class="theme-icon-light">☀️</span>
                        <span class="theme-icon-dark">🌙</span>
                    </button>
                </div>
            </div>

            <div class="course-landing" id="main-content">
                <div class="cmdk-overlay" id="cmdk" hidden role="dialog" aria-modal="true" aria-label="Quick jump">
                    <div class="cmdk-panel">
                        <input type="text" class="cmdk-input" id="cmdk-input" placeholder="Jump to a concept… (Esc to close)" autocomplete="off" />
                        <div class="cmdk-results" id="cmdk-results" role="listbox"></div>
                    </div>
                </div>

                <div class="course-header">
                    <h1>{esc_title}</h1>
                    <p class="course-description">{esc_desc}</p>
                    <div class="course-meta">
                        <span class="meta-item" id="meta-modules">{module_count} modules</span>
                        <span class="meta-item" id="meta-concepts">{concept_count} concepts</span>
                        <span class="meta-item">{esc_difficulty}</span>
                    </div>
                    <div class="course-actions">
                        <a class="btn-start" id="start-btn" href="#module-list">Start learning</a>
                    </div>
                </div>

                <div class="module-list" id="module-list" aria-live="polite">
                    <div class="module-loading" id="module-loading">Loading course structure…</div>
                    <noscript>
                        <p class="cmdk-empty">Enable JavaScript to see the course structure, or fetch
                        the course JSON at <code>/api/courses/{esc_course_id}</code>.</p>
                    </noscript>
                </div>
            </div>
        }

        render_landing_js(&mut page)

        // Course-structure loader — client-side rendering of modules/concepts
        // from the course JSON API. This is the one dynamic part of the page;
        // everything else is server-rendered above.
        #js {
            (function() {
                var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
                var courseId = (parts.length >= 2 && parts[0] === 'courses') ? parts[1] : null;
                var list = document.getElementById('module-list');
                if (!list || !courseId) return;
                fetch('/api/courses/' + encodeURIComponent(courseId)).then(function(r) {
                    if (!r.ok) throw new Error('http ' + r.status);
                    return r.json();
                }).then(function(course) {
                    // Title/description/meta are server-rendered; modules are not
                    // (they are dynamic per-course data).
                    var modules = course.modules || [];
                    var concepts = course.concepts || [];
                    var byModule = {};
                    concepts.forEach(function(c) {
                        var key = c.module_id || '';
                        if (!byModule[key]) byModule[key] = [];
                        byModule[key].push(c);
                    });
                    var html = '';
                    modules.forEach(function(m, mi) {
                        var items = byModule[m.id] || [];
                        // NOTE: compute arithmetic BEFORE string concat. The #js
                        // macro drops parentheses in plain-JS mode (upstream bug:
                        // JsParen only preserved when jsx_enabled), so
                        // 'Module ' + (mi + 1) would emit as 'Module ' + mi + 1
                        // and render "Module 01".
                        var module_num = mi + 1;
                        html += '<div class="module">';
                        html += '<h2>Module ' + module_num + ': ' + escapeHtml(m.title) + '</h2>';
                        if (m.description) html += '<p>' + escapeHtml(m.description) + '</p>';
                        html += '<ul class="concept-list">';
                        items.forEach(function(c) {
                            html += '<li><a href="/courses/' + encodeURIComponent(courseId) +
                                '/lessons/' + encodeURIComponent(c.id) + '">' + escapeHtml(c.title || c.id) + '</a></li>';
                        });
                        // Concepts listed in the module but missing a ConceptRef
                        // still get a link (id is the fallback title).
                        if (items.length === 0 && m.concept_count > 0) {
                            html += '<li class="cmdk-empty">' + m.concept_count + ' concepts</li>';
                        }
                        html += '</ul></div>';
                    });
                    if (html === '') html = '<div class="cmdk-empty">This course has no modules yet.</div>';
                    list.innerHTML = html;
                }).catch(function() {
                    list.innerHTML = '<div class="cmdk-empty">Could not load the course structure. ' +
                        'Try reloading, or check that the backend is running.</div>';
                });
                function escapeHtml(s) {
                    s = String(s);
                    var out = '';
                    var i = 0;
                    while (i < s.length) {
                        var ch = s.charAt(i);
                        if (ch === '&') { out += '&amp;'; }
                        else if (ch === '<') { out += '&lt;'; }
                        else if (ch === '>') { out += '&gt;'; }
                        else if (ch === '"') { out += '&quot;'; }
                        else if (ch === "'") { out += '&#39;'; }
                        else { out += ch; }
                        i = i + 1;
                    }
                    return out;
                }
            })();
        }

        return page.toString()
    }

}
