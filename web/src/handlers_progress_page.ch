// underlayer_web — Progress page (HTML UI).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_progress_page(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        // THE SIGN-IN GATE.  Every number on this page is read from
        // the signed-in learner's own rows, so with no account there
        // is nothing to show and the page rendered zeros -- which reads
        // as failure rather than as "you are not signed in".  Checked
        // before any query; see pages_auth_gate.ch for why this is a
        // page rather than a redirect.
        if(!has_session(&raw db, req)) {
            // Redirect, not an in-place card: see pages_auth_gate.ch for why this

            // changed, and for why it cannot loop.

            var gate_path = string("/progress")
            redirect_to_login(res, &gate_path)
            return
        }
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Progress — Underlayer"))
        // THE SHARED SESSION HELPER.  This page's script calls __ulFetch,
        // __ulCourseId and __ulHeaders, all defined once in session_js.ch.
        // Emitted before the page's own script so the helpers exist by the
        // time its DOMContentLoaded handler calls them.
        render_session_js(&mut page)

        #html {
            {render_nav_bar(&mut page)}

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Your Progress</h1>
                    <p class="subtitle">Track your learning journey through this course</p>
                </div>

                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-number" id="total-concepts">-</div>
                        <div class="stat-label">Total Concepts</div>
                    </div>
                    <div class="stat-card stat-mastered">
                        <div class="stat-number" id="mastered-count">-</div>
                        <div class="stat-label">Mastered</div>
                    </div>
                    <div class="stat-card stat-learning">
                        <div class="stat-number" id="learning-count">-</div>
                        <div class="stat-label">Learning</div>
                    </div>
                    <div class="stat-card stat-reviewing">
                        <div class="stat-number" id="reviewing-count">-</div>
                        <div class="stat-label">Reviewing</div>
                    </div>
                </div>

                <div class="progress-section">
                    <h2>Overall Mastery</h2>
                    <div class="progress-bar-large">
                        <div class="progress-fill" id="mastery-fill" style="width: 0%"></div>
                    </div>
                    <div class="progress-label" id="mastery-label">Loading...</div>
                </div>

                <div class="dual-grid">
                    <div class="section-card">
                        <h2>Knowledge Health</h2>
                        <div class="metric-row">
                            <span class="metric-label">Health Score</span>
                            <span class="metric-value" id="health-score">-</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill progress-health" id="health-fill" style="width: 0%"></div>
                        </div>
                        <div class="metric-row">
                            <span class="metric-label">Depth Score</span>
                            <span class="metric-value" id="depth-score">-</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill progress-depth" id="depth-fill" style="width: 0%"></div>
                        </div>
                        <div class="metric-row">
                            <span class="metric-label">Breadth Score</span>
                            <span class="metric-value" id="breadth-score">-</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill progress-breadth" id="breadth-fill" style="width: 0%"></div>
                        </div>
                    </div>

                    <div class="section-card">
                        <h2>Review Queue</h2>
                        <div class="queue-stats">
                            <div class="queue-stat">
                                <div class="queue-count queue-new" id="new-count">-</div>
                                <div class="queue-label">New</div>
                            </div>
                            <div class="queue-stat">
                                <div class="queue-count queue-due" id="due-count">-</div>
                                <div class="queue-label">Due</div>
                            </div>
                            <div class="queue-stat">
                                <div class="queue-count queue-mastered" id="mastered-queue">-</div>
                                <div class="queue-label">Mastered</div>
                            </div>
                        </div>
                        <a href="/review" class="btn btn-primary" style="width: 100%; text-align: center; margin-top: 1rem;">Start Review Session</a>
                    </div>
                </div>

                <div class="section-card" style="margin-top: 2rem;">
                    <h2>Concept Progress</h2>
                    <div class="concept-progress-list" id="concept-list">
                        <p class="muted">Loading concepts...</p>
                    </div>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }

            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }

            .container { max-width: 1000px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 2rem; }
            .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); }
            .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem; }
            .stat-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; text-align: center; }
            .stat-number { font-size: 2rem; font-weight: 700; color: hsl(var(--foreground)); }
            .stat-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); margin-top: 0.25rem; }
            .stat-mastered .stat-number { color: hsl(142 76% 36%); }
            .stat-learning .stat-number { color: hsl(38 92% 50%); }
            .stat-reviewing .stat-number { color: hsl(0 84% 60%); }
            .progress-section { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; margin-bottom: 2rem; }
            .progress-section h2 { font-size: 1.1rem; margin-bottom: 1rem; }
            .progress-bar-large { height: 12px; background: hsl(var(--secondary)); border-radius: 6px; overflow: hidden; margin-bottom: 0.5rem; }
            .progress-fill { height: 100%; background: hsl(217 91% 60%); border-radius: 6px; transition: width 0.5s ease; }
            .progress-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .dual-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
            .section-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .section-card h2 { font-size: 1.1rem; margin-bottom: 1rem; }
            .metric-row { display: flex; justify-content: space-between; margin-bottom: 0.25rem; }
            .metric-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .metric-value { font-size: 0.85rem; font-weight: 600; color: hsl(var(--foreground)); }
            .progress-bar { height: 6px; background: hsl(var(--secondary)); border-radius: 3px; overflow: hidden; margin-bottom: 1rem; }
            .progress-health { background: hsl(142 76% 36%); }
            .progress-depth { background: hsl(217 91% 60%); }
            .progress-breadth { background: hsl(258 90% 66%); }
            .queue-stats { display: flex; justify-content: space-around; margin-bottom: 1rem; }
            .queue-stat { text-align: center; }
            .queue-count { font-size: 1.5rem; font-weight: 700; }
            .queue-new { color: hsl(217 91% 60%); }
            .queue-due { color: hsl(38 92% 50%); }
            .queue-mastered { color: hsl(142 76% 36%); }
            .queue-label { font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border-radius: 8px; font-weight: 500; font-size: 0.9rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            .concept-progress-list { display: flex; flex-direction: column; gap: 0.5rem; }
            .concept-row { display: flex; align-items: center; padding: 0.75rem 1rem; background: hsl(var(--secondary)); border-radius: 8px; }
            .concept-name { flex: 1; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .concept-link { color: hsl(217 91% 60%); font-size: 0.8rem; text-decoration: none; margin-left: 1rem; }
            .concept-link:hover { text-decoration: underline; }
            .muted { color: hsl(var(--muted-foreground)); text-align: center; padding: 2rem; }
            @media (max-width: 768px) {
                .container { padding: 1rem; }
                .stats-grid { grid-template-columns: repeat(2, 1fr); }
                .dual-grid { grid-template-columns: 1fr; }
            }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; }
            .back-to-top:hover { background: #111827; }
        }

        #js {

            function setText(id, val) {
                document.getElementById(id).textContent = val;
            }

            function setWidth(id, pct) {
                document.getElementById(id).style.width = pct;
            }

            function fmtPct(n) {
                return Math.round(n) + "%%";
            }

            window.addEventListener("DOMContentLoaded", function() {
                loadProgress();
                loadConceptList();
            });

            // THE AUTHORIZATION HEADER IS NOT HERE ANY MORE.  This page had its own
            // ppHeaders() that read localStorage in a try/catch and built the
            // bearer header -- the same helper now lives once in
            // session_js.ch as __ulHeaders(), which every page shares, and it
            // does this plus handles the 401 this page had no answer for.
            // Kept here as a note because the comment that explained why the
            // header was added is the reason the helper is shared rather than
            // copy-pasted: auth_get_learner_id() falls back to the shared
            // "demo" learner when no bearer token arrives, so a page that
            // forgets the header shows EVERY LEARNER THE SAME NUMBERS.
            function loadProgress() {
                __ulFetch('/api/progress?course_id=' + encodeURIComponent(__ulCourseId()))
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        // Every field below was read by this page and emitted by
                        // NOBODY: /api/progress did not send total_concepts,
                        // health_score, depth or breadth, so the `|| 24` fallback
                        // below painted a hardcoded 24 and the health bar sat at
                        // 0% for every learner on the platform.  The API emits all
                        // four now (handlers_progress_json.ch).  The `|| 0` guards
                        // stay -- an absent number should read 0, but an absent
                        // TOTAL should read "no data", not a plausible lie.
                        var total = data.concepts_total || 0;
                        var started = data.concepts_started || 0;
                        var mastered = data.concepts_mastered || 0;
                        setText("total-concepts", total);
                        setText("mastered-count", mastered);
                        setText("learning-count", started);
                        setText("reviewing-count", data.reviewing || 0);
                        var pct = data.progress_percentage || 0;
                        setWidth("mastery-fill", pct + "%%");
                        setText("mastery-label", pct + "%% read (" + started + " of " + total + " concepts)");
                        var health = data.health_score || 0;
                        var healthPct = Math.round(health * 100);
                        setText("health-score", fmtPct(healthPct));
                        setWidth("health-fill", healthPct + "%%");
                        var depth = data.depth || 0;
                        setText("depth-score", fmtPct(depth));
                        setWidth("depth-fill", Math.round(depth) + "%%");
                        var breadth = data.breadth || 0;
                        setText("breadth-score", fmtPct(breadth));
                        setWidth("breadth-fill", Math.round(breadth) + "%%");
                    })
                    .catch(function() {
                        setText("total-concepts", "-");
                        setText("mastered-count", "0");
                        setText("learning-count", "0");
                        setText("reviewing-count", "0");
                    });

                // silent401 HERE, DELIBERATELY.  This is the due-review COUNTER: a signed-out
                // visitor should see "0 due", not be thrown to a login page for
                // asking what is on their schedule.  The review page, where
                // nothing can happen without a session, does not pass this and
                // does redirect.  Same wrapper, one named flag, and the flag is
                // where the decision is visible.
                __ulFetch('/api/review/due?course_id=' + encodeURIComponent(__ulCourseId()) + '&limit=1000', { silent401: true })
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var items = data || [];
                        var newC = 0;
                        var dueC = 0;
                        for(var i = 0; i < items.length; i++) {
                            if(items[i].last_review === 0) { newC++; }
                            else { dueC++; }
                        }
                        setText("new-count", newC);
                        setText("due-count", dueC);
                    })
                    .catch(function() {
                        setText("new-count", "0");
                        setText("due-count", "0");
                    });
            }

            // The order and titles still come from a hardcoded ELF array -- this
            // page is the ELF course's progress page and reordering it by hand
            // would be a 24-entry table to keep in step with the manifest.  What
            // is NOT hardcoded is the STATUS, which used to be absent: every one
            // of the 24 rows read identically and said nothing about whether the
            // learner had been there.  It now comes from the same /api/progress
            // payload, keyed by concept id, so "which have I completed" is
            // answerable here rather than only on the lesson strip.
            function loadConceptList() {
                var list = document.getElementById("concept-list");
                list.innerHTML = "";
                var course = __ulCourseId();
                // THE ORDER AND TITLES COME FROM THE MANIFEST NOW.  They used to
                // be two hardcoded arrays pasted into this page, and the comment
                // above them admitted the cost: "reordering it by hand would be a
                // 24-entry table to keep in step with the manifest."  That is not
                // a maintenance note, it is the defect.  The arrays had already
                // drifted -- they were ELF's 24 concepts on a page whose URL
                // carries a course id, so on /progress?course_id=rvasm this drew
                // 24 rows titled "Bytes and Binary", "ELF Header Fields" and
                // "The Dynamic Linker" over RISC-V progress, and a learner
                // studying RISC-V saw a page about ELF.
                //
                // GET /api/courses/<id> already returns the manifest's own
                // concepts array -- the same source the lesson pages and the
                // course landing page are built from -- so there was never a
                // reason for a second copy to exist.
                __ulFetch('/api/courses/' + encodeURIComponent(course))
                    .then(function(r) { return r.json(); })
                    .then(function(manifest) {
                        var concepts = (manifest && manifest.concepts) || [];
                        if (concepts.length === 0) {
                            list.innerHTML = '<p class="muted">This course has no concepts yet.</p>';
                            return;
                        }
                        var ids = [];
                        var names = [];
                        for (var c = 0; c < concepts.length; c++) {
                            ids.push(concepts[c].id);
                            names.push(concepts[c].title);
                        }
                        return __ulFetch('/api/progress?course_id=' + encodeURIComponent(course))
                            .then(function(r) { return r.json(); })
                            .then(function(data) { renderConceptRows(list, ids, names, data.concepts || []); })
                            .catch(function() { renderConceptRows(list, ids, names, []); });
                    })
                    .catch(function() {
                        list.innerHTML = '<p class="muted">Could not load the concepts for this course.</p>';
                    });
            }
            function renderConceptRows(list, ids, names, states) {
                var byId = {};
                for (var k = 0; k < states.length; k++) { byId[states[k].concept_id] = states[k]; }
                var mastered = 0;
                for(var i = 0; i < names.length; i++) {
                    var row = document.createElement("div");
                    row.className = "concept-row";
                    var nameEl = document.createElement("span");
                    nameEl.className = "concept-name";
                    nameEl.textContent = (i + 1) + ". " + names[i];
                    var st = byId[ids[i]];
                    var label = "not started";
                    if (st) {
                        if (st.status === "mastered") { label = "learned"; mastered = mastered + 1; }
                        else if (st.attempts > 0) { label = "read, " + st.attempts + " answered"; }
                        else { label = "read"; }
                    }
                    var badge = document.createElement("span");
                    badge.className = "concept-link";
                    badge.textContent = label;
                    var link = document.createElement("a");
                    link.href = "/courses/elf/lessons/" + ids[i];
                    link.textContent = "Open";
                    link.className = "concept-link";
                    row.appendChild(nameEl);
                    row.appendChild(badge);
                    row.appendChild(link);
                    list.appendChild(row);
                }
                setText("mastered-queue", String(mastered));
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
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        apply_security_headers(res)
        res.write_view(&bv)
    }

}
