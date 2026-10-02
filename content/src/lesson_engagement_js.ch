// underlayer_content — the engagement script: one POST per page load, plus the
// strip's contents.
//
// WHAT IT DOES, IN ORDER, AND WHY THAT ORDER.
//
//   1. Works out whether this is a lesson URL at all.  The script is emitted
//      by the nav, which web/src also renders on collection pages, so the first
//      job is to decline to do anything when there is no
//      /courses/<course>/lessons/<concept> in the pathname.
//   2. Reveals the strip and shows the position, from /api/navigation.  That
//      endpoint already exists, is already manifest-driven, and already
//      returns the ordered module list, the breadcrumbs and prev/next for the
//      concept -- so "Concept N of M" and the module name need no new data
//      source, no build-time argument and no 431 edits.  The alternative --
//      passing (course, index, total) into render_lesson_nav -- would have
//      meant changing the signature of the call all 438 page builders make,
//      which is exactly the hand-edit storm this file exists to avoid.
//   3. POSTs /api/learning/view once, and only once (the guards are in
//      lesson_engagement.ch).  The response sets the pill, so the learner sees
//      whether this read was NEW to the platform or a re-read, instead of a
//      strip that says "logged" unconditionally.
//   4. Reads /api/progress/<course> for the course-wide bar and this
//      concept's own status.
//
// EVERY FAILURE IS SILENT BY DESIGN.  No token -> no POST, and the strip says
// so.  No network -> nothing.  A learner on a file:// URL with no backend sees
// a strip that says "sign in to record progress" over a lesson that works,
// which is the backend-optional rule.
//
// TWO RULES THIS FILE FOLLOWS, EACH ONE LEARNED FROM THE EMITTED OUTPUT
// AND NOT FROM THE SPECIFICATION.  The #js macro is a transpiler, not a
// printer, and the first build of this file emitted JavaScript that did not
// parse.  tools/progress_check.py asserts both on the served page.
//
//   (a) NO ARITHMETIC INSIDE A STRING CONCATENATION.  `Concept ` + (i + 1)
//       came out as `Concept ` + i + 1 and rendered "Concept 01 of 24".
//       course_landing.ch records the same trap and the same fix: compute the
//       number into its own `var` first.
//   (b) NO PARENTHESISED SUB-EXPRESSION IN AN OPERAND POSITION.
//       `mi < (d.modules || []).length` came out as `mi < d.modules || [].length`
//       -- which is not a comparison at all, so the loop never ran and the
//       position never rendered.  Bind the sub-expression to a `var`.
//   (c) NOT ASCII, ON PURPOSE, because a comment here used to claim otherwise
//       and was WRONG.  It said the #js macro turns an em-dash into "\u{2014}",
//       that this is "a Rust escape, not a JavaScript one", and that one such
//       sequence makes the whole script block a parse error.  All three were
//       checked against the served page on 2026-10-02 and all three are false:
//       `\u{2014}` is ES2015 code-point escape syntax and every browser since
//       2016 evaluates it, `node --check` parses the emitted block, and 325 of
//       the 398 lesson pages have shipped js_cbi-escaped emoji as `\u{1F44D}`
//       since long before this file existed.  The claim was presumably written
//       to justify ASCII-fying unrelated pages, which is a change nobody asked
//       for that quietly made the source worse to read.
//
//       So: this file stays ASCII in COMMENTS and string literals where a
//       plain hyphen reads just as well, and that is a readability choice, not
//       a correctness one.  Nothing here breaks if a non-ASCII character is
//       typed, and tools/progress_check.py does NOT assert an absence of
//       "\u{" -- it asserts the opposite and would fail if js_cbi ever
//       stopped escaping, because unescaped bytes are the thing that actually
//       breaks a script tag.
public namespace underlayer_content {

    public func render_lesson_engagement_js(page : &mut HtmlPage) {
        #js {
            window.__ulPosition = function() {
                var parts = window.location.pathname.split('/');
                var out = [];
                for (var i = 0; i < parts.length; i++) {
                    if (parts[i].length > 0) { out.push(parts[i]); }
                }
                if (out.length < 4) { return null; }
                if (out[0] !== 'courses') { return null; }
                if (out[2] !== 'lessons') { return null; }
                return { course: out[1], concept: out[3] };
            };
            window.__ulToken = function() {
                var t = '';
                try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
                return t;
            };
            window.__ulHeaders = function() {
                var h = { 'Content-Type': 'application/json' };
                var t = window.__ulToken();
                if (t) { h['Authorization'] = 'Bearer ' + t; }
                return h;
            };
            window.__ulText = function(id, text) {
                var el = document.getElementById(id);
                if (el) { el.textContent = text; }
            };
            window.__ulPill = function(text, cls) {
                var el = document.getElementById('ul-progress-state');
                if (el) { el.textContent = text; el.className = 'ul-progress-state ' + cls; }
            };
            // Flatten {modules:[{title,concepts:[...]}]} into one ordered list.
            // Rule (b): `d.modules` is bound to a name before it is indexed and
            // before `|| []` is applied to it.
            window.__ulFlatConcepts = function(d) {
                var mods = d.modules || [];
                var flat = [];
                for (var mi = 0; mi < mods.length; mi++) {
                    var cs = mods[mi].concepts || [];
                    var moduleTitle = mods[mi].title || '';
                    for (var ci = 0; ci < cs.length; ci++) {
                        flat.push({ id: cs[ci].id, title: cs[ci].title, module: moduleTitle });
                    }
                }
                return flat;
            };

            // ---- position: N of M, module name, prev/next ----
            window.__ulLoadPosition = function(ctx) {
                var url = '/api/navigation/' + encodeURIComponent(ctx.course) + '/' + encodeURIComponent(ctx.concept);
                fetch(url).then(function(r) { return r.json(); }).then(function(d) {
                    var flat = window.__ulFlatConcepts(d);
                    var idx = -1;
                    for (var fi = 0; fi < flat.length; fi++) {
                        if (flat[fi].id === ctx.concept) { idx = fi; }
                    }
                    if (idx < 0) { return; }
                    // Rule (a): every number is computed before it is printed.
                    var shown = idx + 1;
                    var total = flat.length;
                    window.__ulText('ul-progress-where', 'Concept ' + shown + ' of ' + total + ' in ' + flat[idx].module);
                    var prev = document.getElementById('ul-prev');
                    var next = document.getElementById('ul-next');
                    if (idx > 0) {
                        var p = flat[idx - 1];
                        prev.href = '/courses/' + ctx.course + '/lessons/' + p.id;
                        prev.textContent = 'Previous: ' + p.title;
                        prev.hidden = false;
                        // The pages carry <link rel="prev" href=""> with an empty
                        // href, which the swipe handler reads.  Filling it here
                        // is what makes that gesture work at all.
                        var lp = document.querySelector('link[rel="prev"]');
                        if (lp) { lp.href = prev.href; }
                    }
                    if (idx + 1 < flat.length) {
                        var n = flat[idx + 1];
                        next.href = '/courses/' + ctx.course + '/lessons/' + n.id;
                        next.textContent = 'Next: ' + n.title;
                        next.hidden = false;
                        var ln = document.querySelector('link[rel="next"]');
                        if (ln) { ln.href = next.href; }
                    }
                }).catch(function() { });
            };

            // ---- course-wide bar and this concept's status ----
            window.__ulLoadProgress = function(ctx) {
                var url = '/api/progress/' + encodeURIComponent(ctx.course);
                fetch(url, { headers: window.__ulHeaders() }).then(function(r) { return r.json(); }).then(function(d) {
                    var pct = d.progress_percentage || 0;
                    var started = d.concepts_started || 0;
                    var total = d.concepts_total || 0;
                    var fill = document.getElementById('ul-progress-fill');
                    if (fill) { fill.style.width = pct + '%'; }
                    var bar = document.querySelector('.ul-progress-bar');
                    if (bar) { bar.setAttribute('title', started + ' of ' + total + ' concepts read'); }
                    var mine = null;
                    var cs = d.concepts || [];
                    for (var i = 0; i < cs.length; i++) {
                        if (cs[i].concept_id === ctx.concept) { mine = cs[i]; }
                    }
                    if (mine === null) {
                        window.__ulPill('Not started yet', '');
                        return;
                    }
                    if (mine.status === 'mastered') {
                        window.__ulPill('Learned', 'mastered');
                        return;
                    }
                    var attempts = mine.attempts || 0;
                    var correct = mine.correct || 0;
                    // Rule (a) again: the difference is computed first.  Written
                    // inline it emitted as a bare subtraction and the pill read
                    // "Read, 1 missed" as the NUMBER 1.
                    var missed = attempts - correct;
                    if (attempts > 0 && missed > 0) {
                        window.__ulPill('Read, ' + missed + ' missed', 'due');
                        return;
                    }
                    if (attempts > 0) {
                        window.__ulPill('Read, all answers right', 'logged');
                        return;
                    }
                    window.__ulPill('Read', 'logged');
                }).catch(function() { });
            };

            // ---- the one event ----
            window.__ulReportRead = function(ctx) {
                var t = window.__ulToken();
                if (t.length === 0) {
                    window.__ulPill('Sign in to record your progress', '');
                    return;
                }
                fetch('/api/learning/view', {
                    method: 'POST',
                    headers: window.__ulHeaders(),
                    body: JSON.stringify({ course_id: ctx.course, concept_id: ctx.concept })
                }).then(function(r) { return r.json(); }).then(function(d) {
                    if (d.recorded === false) {
                        window.__ulPill('Not recorded - sign in again', '');
                        return;
                    }
                    if (d.first_time) {
                        window.__ulPill('Logged - first read of this concept', 'logged');
                        window.__ulLoadProgress(ctx);
                        return;
                    }
                    window.__ulPill('Logged - read before', 'logged');
                }).catch(function() {
                    window.__ulPill('Offline - not recorded', '');
                });
            };
        }
    }

}
