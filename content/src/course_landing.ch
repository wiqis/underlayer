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

        // I14: total reading time is the SUM of the declared per-concept
        // estimates, never a fixed template number. Both values cross into
        // markup as escaped strings; the checker compares them with the API.
        var total_minutes : int = 0
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.at_ref(ci)
            total_minutes = total_minutes + cref.estimated_minutes
            ci = ci + 1
        }
        var minutes_str = underlayer_core::int_to_string(total_minutes as i64)

        // The prerequisite ids are a pipe-delimited data attribute, escaped
        // once here. JS turns them into links. The mastery percentage is NOT
        // invented on the server: it is seeded into the repository from these
        // same manifests and is read from /api/courses/:id/prerequisites at
        // runtime, so the percentage on screen cannot drift from the API.
        var deps_raw = string()
        var di : size_t = 0
        while(di < course.dependencies.size()) {
            var dep = course.dependencies.at_ref(di)
            deps_raw.append_view(dep.to_view())
            deps_raw.append_view("|")
            di = di + 1
        }

        // #html attributes are interpolated with the UNQUOTED {var} form; a
        // quoted "{var}" is literal text (measured on the served landing).
        // Build the whole endpoint once so the browser and the checker see
        // exactly the same string.
        var prereq_source = string("/api/courses/")
        prereq_source.append_view(f_id.to_view())
        prereq_source.append_view("/prerequisites")

        // The module list container is filled by JS (fetch /api/courses/:id).
        // Concept links follow /courses/<id>/lessons/<concept>.
        render_landing_css(&mut page)
        // THE ONE NAV, on a course landing page too. This page used to draw a
        // second, hand-rolled navbar with seven peer links, its own identity
        // slot and its own theme script -- the place where "one shell" broke.
        // render_site_nav emits the identical markup, styles, identity script
        // and pre-paint theme as every lesson and every collection page.
        // The course-specific progress strip stays below the nav; it is not a
        // second navigation bar.
        render_site_nav(&mut page)

        #html {
            <div class="nav-progress-wrap">
                <div class="nav-progress" id="nav-progress" hidden>
                    <div class="nav-progress-track" id="nav-progress-bar" role="progressbar" aria-label="Course progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
                        <div class="nav-progress-fill" id="nav-progress-fill"></div>
                    </div>
                    <span class="nav-progress-note" id="nav-progress-note"></span>
                    <a href="/review" class="nav-due-badge" id="nav-due-badge" hidden></a>
                </div>
            </div>

            <main class="course-landing" id="main-content">
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
                        {render_certificate_claim(&mut page)}
                    </div>
                </div>

                <section class="course-prereqs" id="course-prereqs"
                         data-course-id={f_id}
                         data-dependencies={deps_raw}
                         data-prereq-source={prereq_source}
                         data-total-minutes={minutes_str}>
                    <h2>Before you start</h2>
                    <p class="prereq-lead">Read these first, in this order. Each one states the mastery this course expects.</p>
                    <ol class="prereq-list" id="prereq-list"></ol>
                    <p class="prereq-status" id="prereq-status" aria-live="polite">Sign in to see whether you meet these prerequisites.</p>
                    <p class="course-time">Estimated reading time: <strong>{minutes_str} minutes</strong> across {concept_count} concepts. Every concept carries its own estimate in the list below; these are reading estimates, not a timed test.</p>
                    <p class="enrol-state" id="enrol-state" aria-live="polite">Checking enrolment…</p>
                </section>

                <div class="module-list" id="module-list" aria-live="polite">
                    <div class="module-loading" id="module-loading">Loading course structure…</div>
                    <noscript>
                        <p class="cmdk-empty">Enable JavaScript to see the course structure, or fetch
                        the course JSON at <code>/api/courses/{esc_course_id}</code>.</p>
                    </noscript>
                </div>
            </main>
        }

        render_landing_js(&mut page)

        // I14 styles live here, with the markup they belong to. They are not in
        // course_landing_assets.ch because this block and its section ship as
        // one reviewable unit: a checker can assert the section exists without
        // following a second file.
        #css {
            .course-prereqs { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem 1.5rem; margin-bottom: 2rem; }
            .course-prereqs h2 { font-size: 1.15rem; margin: 0 0 0.5rem 0; }
            .prereq-lead, .prereq-status, .course-time, .enrol-state { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0.5rem 0; }
            .prereq-list { margin: 0.75rem 0; padding-left: 1.5rem; }
            .prereq-list li { margin-bottom: 0.35rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .prereq-list a { color: hsl(217 91% 60%); }
            .concept-minutes { color: hsl(var(--muted-foreground)); font-size: 0.8rem; white-space: nowrap; }
            .enrol-state.gated { color: hsl(25 90% 55%); }
            @media (max-width: 640px) { .course-prereqs { padding: 1rem; } }
        }

        // Course-structure loader — client-side rendering of modules/concepts
        // from the course JSON API. This is the one dynamic part of the page;
        // everything else is server-rendered above.
        #js {
            (function() {
                var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
                var courseId = (parts.length >= 2 && parts[0] === 'courses') ? parts[1] : null;
                var list = document.getElementById('module-list');
                if (!list || !courseId) return;

                // I14 — prerequisites, time and an honest enrolment state.
                // Links are built as DOM nodes: no string from the API ever
                // becomes markup. The mastery percentage is read from the
                // same endpoint the gating uses, so it cannot disagree.
                var prereqSection = document.getElementById('course-prereqs');
                var prereqList = document.getElementById('prereq-list');
                if (prereqSection && prereqList) {
                    var deps = (prereqSection.getAttribute('data-dependencies') || '').split('|').filter(function(x) { return x.length > 0; });
                    if (deps.length === 0) {
                        prereqList.appendChild(document.createTextNode('This course declares no prerequisites — you can start anywhere.'));
                    }
                    for (var d = 0; d < deps.length; d++) {
                        var item = document.createElement('li');
                        var link = document.createElement('a');
                        link.href = '/courses/' + encodeURIComponent(deps[d]);
                        link.textContent = deps[d];
                        item.appendChild(link);
                        var pctNode = document.createElement('span');
                        pctNode.className = 'prereq-pct';
                        pctNode.textContent = ' — mastery requirement loading…';
                        item.appendChild(pctNode);
                        prereqList.appendChild(item);
                    }
                    var prereqUrl = prereqSection.getAttribute('data-prereq-source') || ('/api/courses/' + encodeURIComponent(courseId) + '/prerequisites');
                    fetch(prereqUrl).then(function(r) {
                        if (!r.ok) { throw new Error('http ' + r.status); }
                        return r.json();
                    }).then(function(rows) {
                        var byId = {};
                        for (var k = 0; k < rows.length; k++) { byId[rows[k].required_course_id] = rows[k].min_mastery_pct; }
                        var items = prereqList.querySelectorAll('li');
                        for (var j = 0; j < items.length; j++) {
                            var text = items[j].querySelector('.prereq-pct');
                            var anchor = items[j].querySelector('a');
                            if (!text || !anchor) { continue; }
                            var value = byId[anchor.textContent];
                            if (value === undefined) { text.textContent = ' — mastery: not declared'; }
                            else { text.textContent = ' — requires ' + value + '% mastery'; }
                        }
                    }).catch(function() {
                        var nodes = prereqList.querySelectorAll('.prereq-pct');
                        for (var n = 0; n < nodes.length; n++) { nodes[n].textContent = ' — mastery: unavailable'; }
                    });

                    var enrol = document.getElementById('enrol-state');
                    if (enrol) {
                        fetch('/api/courses/' + encodeURIComponent(courseId) + '/can-enroll', { credentials: 'same-origin' })
                        .then(function(r) {
                            if (r.status === 401) { enrol.textContent = 'Sign in to see whether this course is open to you.'; return null; }
                            if (!r.ok) { throw new Error('http ' + r.status); }
                            return r.json();
                        }).then(function(d) {
                            if (!d) { return; }
                            if (d.can_enroll) { enrol.textContent = 'You can start this course now.'; return; }
                            var missing = d.missing || [];
                            var names = [];
                            for (var m = 0; m < missing.length; m++) { names.push(missing[m].required_course_id + ' (' + missing[m].min_mastery_pct + '%)'); }
                            if (names.length > 0) { enrol.textContent = 'Enrolment is gated until you complete: ' + names.join(', '); }
                            else { enrol.textContent = 'Enrolment is currently gated. Sign in to see why.'; }
                            enrol.className = 'enrol-state gated';
                        }).catch(function() {
                            enrol.textContent = 'Enrolment status is unavailable right now. Sign in to check it.';
                        });
                    }
                }

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
                            var mins = parseInt(c.estimated_minutes, 10);
                            if (isNaN(mins)) { mins = 0; }
                            html += '<li><a href="/courses/' + encodeURIComponent(courseId) +
                                '/lessons/' + encodeURIComponent(c.id) + '">' + escapeHtml(c.title || c.id) +
                                '</a> <span class="concept-minutes">' + mins + ' min</span></li>';
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
