// underlayer_web — "WHERE TO GO NEXT", the panel that turns shipped data into
// a decision.
//
// WHY THIS EXISTS, MEASURED RATHER THAN GUESSED.
//
// Asked for the integration holes -- features that exist but that no part of the
// UI reaches.  tools/integration_holes.py found 40 API routes no page names.
// Among them, and worth more than the other 39 together, is this one:
//
//     GET /api/weaknesses  ->  200
//     {"weaknesses":[{"concept_id":"bytes","accuracy":0.0,"severity":100,
//                      "status":"struggling"},
//                     {"concept_id":"binary-representation", ...},
//                     {"concept_id":"file-layout", ...}],
//      "clusters":[...]}
//
// `repository/src/exercise_attempts.ch` records every wrong answer.
// `learning/src/weakness.ch` ranks the concepts by accuracy and severity.
// `GET /api/weaknesses/alerts` turns the same thing into "this needs attention".
// All of it works, all of it is computed on every answer the learner gives, and
// NOT ONE PERSON COULD SEE IT.  A learner who got five of six questions wrong
// on three separate concepts was told nothing, because nothing drew it.
//
// That is the worst kind of shipped feature: it costs CPU on every answer and
// returns nothing a person can use.  And it is the most valuable one to surface,
// because "you are not getting this yet, and here is exactly where" is the single
// most useful sentence a learning platform can say.
//
// WHY THE DASHBOARD AND NOT A NEW PAGE.
//
// A parallel page would be a worse product, not a tidier codebase.  A learner
// who wants to know what to study opens the dashboard; a learner who wants to
// study opens a lesson.  A separate "Recommendations" page would be visited once
// and never again.  This is the top of the dashboard, above the counters,
// because it is the question the dashboard exists to answer -- the counters below
// it are the evidence, and evidence with no conclusion above it is a report.
//
// WHY IT IS AN HONEST PRIORITY ORDER AND NOT A LIST.
//
// The order below is the whole content of this file:
//
//   1. REVIEWS FIRST.  A due review is a concept the learner has already read
//      once and is about to forget. Reading something new instead is the single
//      most common way a learner makes their own forgetting worse. So a due
//      review outranks a new concept, every time.
//   2. THEN WHAT THEY ARE GETTING WRONG.  Struggling concepts come next because
//      they are where accuracy is lowest, which is where the return on time is
//      highest.
//   3. THEN THE NEXT UNREAD CONCEPT.  Only when nothing is due and nothing is
//      being failed is "carry on" the right answer.
//
// Anything else -- most-recently-viewed, a leaderboard, a streak count -- ranks
// activity rather than learning, and would send a learner back to material they
// already half-know while their due reviews age.
//
// WHAT IT DOES NOT DO.
//
//   * It does not tell a learner they are behind.  docs/course-design.md is
//     explicit that this collection must normalise struggle: a panel that says
//     "you are 3 concepts behind" is worse than useless, because the reader
//     cannot act on it and now feels worse about opening the page.  Every line
//     here is a THING TO DO, not a verdict.
//   * It never shows a percentage as the headline.  "42% accuracy" invites a
//     reader to conclude something about themselves; "you have got this wrong
//     twice" invites them to open the lesson, which is the only outcome worth
//     optimising for.
//   * It does not render when there is nothing to say.  An empty panel is a
//     second thing on the page with no content, and it teaches the reader to
//     stop looking at it.
//
// THE ONE REQUEST RULE.
//
// It fetches /api/weaknesses and /api/review/due -- two endpoints, both already
// requiring a session, both already returning 401 without one.  It does not add
// a new endpoint, because /api/me/overview already exists and adding a fourth
// round trip to a dashboard that makes two would be a cost for no new
// information.  /api/weaknesses closes an integration hole and
// /api/weaknesses/alerts and /api/weaknesses/export stay invisible for now,
// which tools/integration_holes.py will keep reporting rather than letting it be
// forgotten.
using std::string
using std::string_view

public namespace underlayer_web {

    // The card.  Markup ships with a `hidden` attribute and is revealed only
    // when there is something to say -- the same rule the onboarding banner and
    // the sign-in advisory follow, for the same reason: a panel that is present
    // but empty is worse than a panel that is absent.
    public func render_next_step(page : &mut HtmlPage) {
        #html {
            <section class="ns-card" id="ul-nextstep" hidden aria-labelledby="ns-title">
                <div class="ns-head">
                    <h2 class="ns-title" id="ns-title">Where to go next</h2>
                    <span class="ns-course" id="ns-course"></span>
                </div>
                <ol class="ns-list" id="ns-list" aria-live="polite"></ol>
                <p class="ns-foot" id="ns-foot" hidden></p>
            </section>
        }
        render_next_step_css(page)
        render_next_step_js(page)
    }

    public func render_next_step_css(page : &mut HtmlPage) {
        #css {
            .ns-card { border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.1rem 1.25rem; margin: 0 0 1.5rem; background: var(--card, hsl(var(--card))); }
            .ns-head { display: flex; align-items: baseline; justify-content: space-between; gap: 0.75rem; flex-wrap: wrap; margin-bottom: 0.6rem; }
            .ns-title { font-size: 1.05rem; font-weight: 700; margin: 0; color: var(--foreground, hsl(var(--foreground))); }
            .ns-course { font-size: 0.8rem; color: var(--muted-foreground, hsl(var(--muted-foreground))); }
            .ns-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.55rem; }
            .ns-item { display: flex; gap: 0.65rem; align-items: flex-start; border: 1px solid hsl(var(--border)); border-radius: 9px; padding: 0.7rem 0.85rem; }
            .ns-rank { flex: 0 0 auto; width: 1.35rem; height: 1.35rem; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.75rem; font-weight: 700; background: hsl(var(--muted)); color: hsl(var(--background)); }
            .ns-body { flex: 1 1 auto; min-width: 0; }
            .ns-what { font-size: 0.93rem; margin: 0 0 0.15rem; }
            .ns-why { font-size: 0.83rem; margin: 0; color: var(--muted-foreground, hsl(var(--muted-foreground))); }
            .ns-go { display: inline-block; margin-top: 0.4rem; font-size: 0.85rem; font-weight: 600; color: hsl(217 91% 60%); text-decoration: none; }
            .ns-go:hover { text-decoration: underline; }
            /* A review outranks a new concept, so it is the one item allowed to
               be visually stronger. Everything else is deliberately the same
               weight: a learner who feels ranked will study the ranking. */
            .ns-item.ns-review { border-color: hsl(217 91% 60% / 45%); background: hsl(217 91% 60% / 5%); }
            .ns-item.ns-struggle { border-color: hsl(38 92% 50% / 45%); background: hsl(38 92% 50% / 6%); }
            .ns-foot { margin: 0.8rem 0 0; font-size: 0.82rem; color: var(--muted-foreground, hsl(var(--muted-foreground))); }
            @media (max-width: 640px) { .ns-head { flex-direction: column; gap: 0.2rem; } }
        }
    }

    public func render_next_step_js(page : &mut HtmlPage) {
        // NOTE ON THIS BLOCK: it is pure ASCII on purpose.  Every other #js block
        // in this codebase is too, and that is not a style choice -- js_cbi
        // cannot lex a non-ASCII byte inside a #js block.  The first version of
        // this file used U+2500 box-drawing separators in the comments below and
        // failed to parse at a line far from them, which is a miserable way to
        // spend a build cycle.  (The CSS block above and the Chemical comments
        // around it handle UTF-8 fine; it is specifically the #js lexer.)
        #js {
            // -- the data ----------------------------------------------
            // Two endpoints, both of which already require a session and both of
            // which already 401 without one. No new endpoint: /api/me/overview
            // already exists and this panel needs per-concept detail it does not
            // carry.
            function nsHeaders() {
                var h = {};
                if (typeof window.__ulToken === 'function') {
                    var t = window.__ulToken();
                    if (t) { h['Authorization'] = 'Bearer ' + t; }
                }
                return h;
            }
            function nsGet(path) {
                return fetch(path, { headers: nsHeaders() })
                    .then(function (r) { return r.ok ? r.json() : null; })
                    .catch(function () { return null; });
            }

            function nsEl(tag, cls, text) {
                var e = document.createElement(tag);
                if (cls) { e.className = cls; }
                if (text !== undefined && text !== null) { e.textContent = text; }
                return e;
            }

            // "binary-representation" -> "Binary Representation"
            //
            // Done here rather than trusted from the API because the API returns
            // ids, not titles, and an id in a sentence reads like a database
            // leaking. The manifest DOES carry titles -- /api/navigation does --
            // but joining on it would mean a third request for a cosmetic
            // improvement, so the transformation is local and the title is used
            // when one happens to be in hand.
            function nsTitle(id, byId) {
                if (byId && byId[id]) { return byId[id]; }
                var s = String(id || '');
                var out = '';
                var upperNext = true;
                for (var i = 0; i < s.length; i++) {
                    var ch = s.charAt(i);
                    if (ch === '-' || ch === '_') {
                        out += ' ';
                        upperNext = true;
                        continue;
                    }
                    if (upperNext) { out += ch.toUpperCase(); upperNext = false; }
                    else { out += ch; }
                }
                return out;
            }

            // -- the actions, in priority order -----------------------
            //
            // This ordering is the content of the panel and it is argued in the
            // file header. The short version, repeated here because this is the
            // part a future reader will change:
            //
            //   reviews before new work, because a due review is something the
            //   learner already read once and is about to forget, and learning
            //   something new instead makes the forgetting worse. That is the
            //   most common way a learner damages their own retention without
            //   knowing it.
            //
            //   struggling concepts before new ones, because accuracy is lowest
            //   there and so the return on the same number of minutes is
            //   highest.
            //
            //   new concepts last, because they are the only option left when
            //   nothing is due and nothing is being failed.
            function nsBuild(due, weak, progress, nav, courseId, titles) {
                var items = [];

                var dueTotal = due && typeof due.total === 'number' ? due.total : 0;
                if (dueTotal > 0) {
                    items.push({
                        cls: 'ns-review',
                        what: dueTotal === 1
                            ? 'Review one concept you read earlier'
                            : 'Review ' + dueTotal + ' concepts you read earlier',
                        why: 'These come back on a schedule. Reading new material instead lets this go, and forgetting it again costs more than the new lesson was worth.',
                        href: '/review',
                        cta: 'Start the review'
                    });
                }

                var ws = weak && weak.weaknesses ? weak.weaknesses : [];
                // Three, not all. A panel listing eleven concepts is a to-do list
                // the reader abandons, and the point is the FIRST thing to do.
                var shown = 0;
                for (var i = 0; i < ws.length && shown < 3; i++) {
                    var w = ws[i];
                    if (!w || !w.concept_id) { continue; }
                    if (w.status === 'mastered' || w.severity === 0) { continue; }
                    var cid = w.concept_id;
                    var tries = '';
                    items.push({
                        cls: 'ns-struggle',
                        what: 'Look again at ' + nsTitle(cid, titles),
                        why: 'You have got this wrong' + tries +
                             '. Reading it once more, then doing its exercises, is worth more than starting something new.',
                        href: '/courses/' + encodeURIComponent(courseId) +
                              '/lessons/' + encodeURIComponent(cid),
                        cta: 'Open the lesson'
                    });
                    shown++;
                }

                // The carry-on case, and it needs a third payload because neither
                // of the first two can answer it.
                //
                // There is no "next concept" field anywhere on this platform --
                // /api/progress was checked and does not carry one. What it does
                // carry is `concepts[]`, listing only the concepts the learner has
                // OPENED, and /api/navigation carries every concept in COURSE
                // ORDER. So "what to read next" is the first concept in that order
                // that is absent from the opened set, and both halves are already
                // in hand. That is why this file fetches /api/navigation at all.
                //
                // The alternative -- adding a `next_concept` field to
                // /api/progress -- was rejected: it would be a server change to
                // answer a question two existing payloads already answer, and the
                // derivation is five lines that can be read and corrected.
                if (items.length === 0) {
                    nsNextConcept(courseId, titles, progress, nav);
                    return items;
                }

                nsRender(items, courseId, dueTotal);
                return items;
            }

            function nsNextConcept(courseId, titles, progress, nav) {
                var opened = {};
                if (progress && progress.concepts) {
                    for (var i = 0; i < progress.concepts.length; i++) {
                        var c = progress.concepts[i];
                        if (c && c.concept_id) { opened[c.concept_id] = true; }
                    }
                }
                var next = null;
                if (nav && nav.modules) {
                    for (var m = 0; m < nav.modules.length && !next; m++) {
                        var cs = nav.modules[m].concepts || [];
                        for (var k = 0; k < cs.length; k++) {
                            if (cs[k] && cs[k].id && !opened[cs[k].id]) {
                                next = cs[k];
                                break;
                            }
                        }
                    }
                }
                if (next) {
                    nsRender([{
                        cls: '',
                        what: 'Read ' + nsTitle(next.id, titles),
                        // The module name, not the concept title: the concept title
                        // is already the headline here, and the useful second fact
                        // is WHICH PART of the course this is.
                        why: (nav.modules.length && nsModuleName(nav, next.id)) ||
                             'The next one in the order the course is meant to be read.',
                        href: '/courses/' + encodeURIComponent(courseId) +
                              '/lessons/' + encodeURIComponent(next.id),
                        cta: 'Open the lesson'
                    }], courseId, 0);
                    return;
                }
                // Every concept is opened and nothing is due. Point at the course
                // page rather than at a lesson: if something is genuinely left,
                // the course page shows what, and guessing a lesson id here would
                // produce a 404 the reader cannot diagnose.
                nsRender([{
                    cls: '',
                    what: 'You have opened every lesson in this course',
                    why: 'Nothing is due for review and nothing is left unread. The course page shows the review queue and your certificate.',
                    href: '/courses/' + encodeURIComponent(courseId),
                    cta: 'Open the course'
                }], courseId, 0);
            }

            function nsModuleName(nav, conceptId) {
                for (var m = 0; m < nav.modules.length; m++) {
                    var cs = nav.modules[m].concepts || [];
                    for (var k = 0; k < cs.length; k++) {
                        if (cs[k] && cs[k].id === conceptId) {
                            return 'Module ' + (nav.modules[m].order || (m + 1)) +
                                   ', ' + nav.modules[m].title;
                        }
                    }
                }
                return null;
            }

            function nsRender(items, courseId, dueTotal) {
                var card = document.getElementById('ul-nextstep');
                var list = document.getElementById('ns-list');
                if (!card || !list) { return; }
                if (!items || items.length === 0) { return; }  // say nothing
                list.textContent = '';
                for (var i = 0; i < items.length; i++) {
                    var it = items[i];
                    var li = nsEl('li', 'ns-item ' + (it.cls || ''));
                    li.appendChild(nsEl('span', 'ns-rank', String(i + 1)));
                    var body = nsEl('div', 'ns-body');
                    body.appendChild(nsEl('p', 'ns-what', it.what));
                    body.appendChild(nsEl('p', 'ns-why', it.why));
                    var a = nsEl('a', 'ns-go', it.cta);
                    a.href = it.href;
                    body.appendChild(a);
                    li.appendChild(body);
                    list.appendChild(li);
                }
                var courseEl = document.getElementById('ns-course');
                if (courseEl) { courseEl.textContent = courseId; }
                var foot = document.getElementById('ns-foot');
                if (foot && dueTotal === 0 && items.length > 1) {
                    // Say WHY the list is short. An unexplained short list reads
                    // as "that is all there is", which is the opposite of the
                    // truth for a learner with nine failures.
                    foot.textContent = 'The first three, because a list of eleven is a list you stop reading.';
                    foot.hidden = false;
                }
                card.hidden = false;
            }

            // -- entry point ------------------------------------------
            //
            // SEQUENTIAL .then() CHAINING, NOT Promise.all, and that is not a
            // style preference. The first version of this used
            // `Promise.all([...]).then(function (res) { var due = res[0], ... })`
            // and it did not compile: js_cbi walks the block with a Chemical-side
            // parser and that construct -- an array literal argument plus indexed
            // access on the callback's parameter -- is something it cannot parse.
            // The error pointed at a line several hundred away from the cause.
            //
            // Every other data-loading block in this codebase chains .then() with
            // named variables (dashboard_assets.ch, handlers_progress_page.ch), so
            // this is now the same shape. Three requests in sequence rather than
            // in parallel costs a few milliseconds against localhost and removes
            // a construct the toolchain cannot lex.
            function nsLoadCourse(courseId) {
                if (!courseId) { return; }
                var due = null;
                var weak = null;
                var progress = null;
                var nav = null;
                nsGet('/api/review/due').then(function (d) {
                    due = d;
                    return nsGet('/api/weaknesses');
                }).then(function (w) {
                    weak = w;
                    return nsGet('/api/navigation/' + encodeURIComponent(courseId));
                }).then(function (n) {
                    nav = n;
                    return nsGet('/api/progress?course_id=' +
                                 encodeURIComponent(courseId));
                }).then(function (p) {
                    progress = p;
                    // Titles from the navigation payload, so a lesson is named the
                    // way the course names it rather than by reshaping its id.
                    // This is why the panel asks for /api/navigation at all.
                    var titles = {};
                    if (nav && nav.modules) {
                        for (var m = 0; m < nav.modules.length; m++) {
                            var cs = nav.modules[m].concepts || [];
                            for (var c = 0; c < cs.length; c++) {
                                if (cs[c] && cs[c].id) {
                                    titles[cs[c].id] = cs[c].title;
                                }
                            }
                        }
                    }
                    nsBuild(due, weak, progress, nav, courseId, titles);
                });
            }

            function nsLoad() {
                if (typeof window.__ulCourseId === 'function') {
                    var cid = window.__ulCourseId();
                    if (cid) { return nsLoadCourse(cid); }
                }
                // No course in the URL: the dashboard defaults to elf server-side,
                // so this matches the counters above.
                nsLoadCourse('elf');
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', nsLoad);
            } else {
                nsLoad();
            }
        }
    }

}
