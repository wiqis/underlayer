// tools/next_step_test.js -- RUN the "Where to go next" panel's JavaScript
// against the real server, and check it says the right thing in each state.
//
// WHY THIS RUNS THE CODE RATHER THAN GREPPING THE MARKUP
//
// The panel's entire content is a PRIORITY ORDER. There is nothing to assert
// about its markup: it ships `hidden`, it is three empty containers, and it is
// correct in all three states. What could be wrong -- and what would be invisible
// to any static check -- is that it renders the wrong ADVICE. A panel that says
// "read a new lesson" while three reviews are due is worse than no panel, because
// it is confidently wrong.
//
// So the JS is extracted from the Chemical source and executed against the real
// HTTP API with a minimal DOM, for four states a learner can actually be in:
//
//   1. new account       nothing opened, nothing due
//   2. started           two lessons read, nothing due, nothing failed
//   3. struggling        three concepts failed on purpose
//   4. reviews due       a due review, which must OUTRANK the failures
//
// State 4 is the one that matters most: it is the ordering claim, and it is the
// claim the file header argues for. A panel that gets it backwards is a panel
// that makes the learner's forgetting worse, which is the thing it exists to
// prevent.
//
// Usage:  node tools/next_step_test.js [base-url]
// Exit 0 if every state produced the expected advice.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const BASE = process.argv[2] || 'http://localhost:9000';
const ROOT = path.dirname(__dirname);
let failures = 0;
let checks = 0;

function ok(name, cond, detail) {
    checks++;
    if (cond) {
        console.log('  PASS  ' + name + (detail ? '  -- ' + detail : ''));
    } else {
        failures++;
        console.log('  FAIL  ' + name + (detail ? '  -- ' + detail : ''));
    }
}

// ── the source under test ──────────────────────────────────────────────
// Pulled straight out of web/src/next_step.ch. Extracting rather than keeping a
// copy is the point: a copy would drift, and a test that passes against a
// copy of the code rather than the code is a test of nothing.
const SRC = fs.readFileSync(path.join(ROOT, 'web/src/next_step.ch'), 'utf8');
const start = SRC.indexOf('#js {');
if (start < 0) { console.error('no #js block in next_step.ch'); process.exit(2); }
const bodyStart = SRC.indexOf('\n', start);
const end = SRC.indexOf('\n        }', bodyStart);
const JS = SRC.slice(bodyStart, end);

// ── a DOM small enough to be obviously correct ──────────────────────────
// A real DOM is not needed to check an ordering claim, and pulling one in would
// make this test fail for reasons that have nothing to do with the advice.
function makeEl(tag) {
    const e = {
        tagName: tag, className: '', textContent: '', hidden: false,
        href: '', children: [], attrs: {},
        appendChild(c) { this.children.push(c); return c; },
        setAttribute(k, v) { this.attrs[k] = v; },
    };
    return e;
}
// A REGISTRY, not a factory.
//
// Two versions of this harness got this wrong, and both failed in the same
// direction -- asserting nothing while looking like it was asserting something:
//
//   * the first returned a fresh element with `hidden` false, so "the panel
//     appears" passed unconditionally, and
//   * the second still returned a FRESH element per call, so the code appended
//     to one `#ns-list` and the test read an empty different one. Every
//     assertion then reported "0 items" against a panel that had in fact
//     rendered correctly.
//
// The lesson is that a DOM mock which does not persist is not a DOM mock. This
// one is a Map, and it starts from the attributes the SERVER actually sends.
const REG = new Map();
function byId(ids, wanted) {
    if (ids.indexOf(wanted) < 0) { return null; }
    if (REG.has(wanted)) { return REG.get(wanted); }
    const e = makeEl('div');
    // As served: the card ships `hidden`, so it must START hidden or the
    // panel's own discipline is not being tested.
    if (wanted === 'ul-nextstep' || wanted === 'ns-foot') { e.hidden = true; }
    REG.set(wanted, e);
    return e;
}
function resetDom() { REG.clear(); }

async function renderPanel() {
    // A fresh DOM per state: the four states are four different learners, and
    // reusing one registry would let state 2 inherit state 1's rendered items.
    resetDom();
    const ids = ['ul-nextstep', 'ns-list', 'ns-course', 'ns-foot'];
    const sandbox = {
        console,
        document: {
            readyState: 'complete',
            createElement: makeEl,
            getElementById: (id) => byId(ids, id),
            addEventListener: () => {},
        },
        window: { __ulToken: () => global.__TOKEN__ || '' },
        encodeURIComponent,
        Promise, Math, String, Number, JSON, Date,
    };
    // `fetch` is the real one, so this exercises the real endpoints.
    sandbox.fetch = (u, o) => fetch(BASE + u, o);
    sandbox.global = sandbox;
    vm.createContext(sandbox);
    vm.runInContext(JS, sandbox);
    // nsLoad() runs synchronously on readyState 'complete'; the chain is async,
    // so give it real time and then read the DOM the panel wrote into.
    await new Promise(r => setTimeout(r, 2500));
    const list = sandbox.document.getElementById('ns-list');
    return {
        hidden: sandbox.document.getElementById('ul-nextstep').hidden,
        items: list.children.map(li => ({
            cls: li.className,
            what: li.children[1].children[0].textContent,
            why: li.children[1].children[1].textContent,
            href: li.children[1].children[2].href || '',
        })),
    };
}

// Clear the login limiter's counters.
//
// web/src/rate_limit.ch caps /api/auth/register at 8 per 5 minutes per IP, and
// this harness registers four learners. When the cap was hit, `register` answered
// 429, `session_token` came back undefined, every later request went out as
// "Bearer undefined", and the whole file reported PASS/FAIL against an anonymous
// panel -- which is why three assertions were failing for reasons that had
// nothing to do with the panel.
//
// So the counters are cleared, by shelling out to python3 exactly the way
// tools/security_check.py and tools/progress_check.py do. It is not elegant and
// it is in keeping with the rest of this repository's harnesses.
function clearRateLimits() {
    const { execFileSync } = require('child_process');
    const db = process.env.UL_DB || './underlayer.db';
    try {
        execFileSync('python3', ['-c',
            'import sqlite3,sys;c=sqlite3.connect(sys.argv[1],timeout=20);' +
            'c.execute("DELETE FROM rate_limits");c.commit()', db],
            { stdio: 'ignore' });
    } catch (e) {
        console.log('      (could not clear rate_limits: ' + e.message + ')');
    }
}

async function makeLearner(tag) {
    clearRateLimits();
    const r = await fetch(BASE + '/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            email: 'nextstep-' + tag + '-' + Date.now() + '@underlayer.dev',
            password: 'password123', name: 'NextStep ' + tag,
        }),
    });
    if (r.status !== 200) {
        // A harness that proceeds without a session tests nothing at all, and
        // the failure it produces looks like a product bug. Refuse instead.
        console.error('  FAIL  could not register a learner for state "' + tag +
                      '" -- HTTP ' + r.status + ' ' + (await r.text()).slice(0, 120));
        console.error('        Every later request would go out as "Bearer ' +
                      'undefined" and the file would report results for an');
        console.error('        anonymous panel. Stopping rather than lying.');
        process.exit(1);
    }
    const d = await r.json();
    if (!d.session_token) {
        console.error('  FAIL  register returned no session_token for "' + tag +
                      '": ' + JSON.stringify(d).slice(0, 160));
        process.exit(1);
    }
    return d.session_token;
}

const H = (t) => ({ 'Content-Type': 'application/json', Authorization: 'Bearer ' + t });

// Run nsBuild directly with a queue that is not going to arrive on its own.
// Uses the REAL /api/weaknesses payload so the second and third items are the
// genuine failing concepts rather than invented ones.
async function runWithDue(items, total) {
    const tok = global.__TOKEN__;
    const weak = await (await fetch(BASE + '/api/weaknesses', { headers: H(tok) })).json();
    const nav = await (await fetch(BASE + '/api/navigation/elf')).json();
    const due = { items: items, total: total };

    resetDom();
    const ids = ['ul-nextstep', 'ns-list', 'ns-course', 'ns-foot'];
    const sandbox = {
        console, document: {
            // 'loading', NOT 'complete': the panel auto-runs on DOMContentLoaded
            // and this sandbox must not fetch, because nsBuild is being driven by
            // hand with a queue that is not going to arrive on its own. With
            // 'complete' the auto-run fired and the stubbed-fetch assertion below
            // caught it -- which is the assertion doing its job.
            readyState: 'loading', createElement: makeEl,
            getElementById: (id) => byId(ids, id), addEventListener: () => {},
        },
        window: { __ulToken: () => tok },
        encodeURIComponent, Promise, Math, String, Number, JSON, Date,
        fetch: () => { throw new Error('nsBuild must not fetch'); },
    };
    vm.createContext(sandbox);
    vm.runInContext(JS, sandbox);
    const titles = {};
    for (const m of nav.modules) {
        for (const c of m.concepts) { titles[c.id] = c.title; }
    }
    sandbox.nsBuild(due, weak, { concepts: [] }, nav, 'elf', titles);
    const list = sandbox.document.getElementById('ns-list');
    return {
        items: list.children.map(li => ({
            what: li.children[1].children[0].textContent,
            href: li.children[1].children[2].href || '',
        })),
    };
}

async function main() {
    console.log('next_step_test against ' + BASE + '\n');
    try {
        const h = await fetch(BASE + '/api/health');
        if (h.status !== 200) { console.error('no server'); process.exit(2); }
    } catch (e) { console.error('no server: ' + e.message); process.exit(2); }

    // ---- state 1: a brand new account --------------------------------
    console.log('[1] a new account: nothing opened, nothing due');
    let tok = await makeLearner('new');
    global.__TOKEN__ = tok;
    let p = await renderPanel();
    ok('the panel appears', p.hidden === false, 'hidden=' + p.hidden);
    ok('it offers exactly one thing to do', p.items.length === 1,
       p.items.length + ' item(s)');
    ok('and that thing is to start reading', /start the course|read /i.test(p.items[0].what),
       JSON.stringify(p.items[0] && p.items[0].what));

    // ---- state 2: started, nothing failing ---------------------------
    console.log('\n[2] two lessons read, nothing due, nothing failed');
    tok = await makeLearner('started');
    global.__TOKEN__ = tok;
    for (const c of ['bytes', 'binary-representation']) {
        await fetch(BASE + '/api/learning/view', {
            method: 'POST', headers: H(tok),
            body: JSON.stringify({ course_id: 'elf', concept_id: c }),
        });
    }
    p = await renderPanel();
    ok('the panel appears', p.hidden === false, 'hidden=' + p.hidden);
    ok('it names a lesson to read', /read /i.test(p.items[0] && p.items[0].what),
       JSON.stringify(p.items[0] && p.items[0].what));
    ok('the lesson is one they have NOT read', !/bytes|binary-representation/i.test(p.items[0].href),
       'href=' + p.items[0].href);

    // ---- state 3: struggling -----------------------------------------
    console.log('\n[3] three concepts failed on purpose');
    tok = await makeLearner('struggle');
    global.__TOKEN__ = tok;
    for (const e of ['elf_bytes_0', 'elf_bytes_1', 'elf_binary-representation_3',
                     'elf_file-layout_5']) {
        await fetch(BASE + '/api/exercises/submit?exercise_id=' + e + '&answer=WRONG',
                    { method: 'POST', headers: H(tok),
                      body: JSON.stringify({ course_id: 'elf' }) });
    }
    p = await renderPanel();
    ok('the panel appears', p.hidden === false, 'hidden=' + p.hidden);
    ok('it lists the concepts that are failing', p.items.length >= 1,
       p.items.length + ' item(s): ' + p.items.map(i => i.what).join(' | '));
    ok('each one is a LINK to its lesson',
       p.items.every(i => /^\/courses\/elf\/lessons\//.test(i.href)),
       p.items.map(i => i.href).join(' '));
    ok('it shows AT MOST three', p.items.length <= 3,
       p.items.length + ' (a list of eleven is a list you stop reading)');
    ok('the failing ones are named, not numbered',
       !/%|accuracy|behind/i.test(p.items[0].what + p.items[0].why),
       'no verdict, only an action: ' + JSON.stringify(p.items[0].what));

    // ---- state 4: due reviews OUTRANK the failures --------------------
    // The ordering claim. This is the assertion the whole file argues for.
    console.log('\n[4] a due review must OUTRANK the failing concepts');
    const due0 = await (await fetch(BASE + '/api/review/due', { headers: H(tok) })).json();
    console.log('      (this learner currently has ' + (due0.total || 0) + ' due)');
    // Reading a concept puts it in the review schedule; the platform's own
    // schedule is what decides when something is due, so the honest version of
    // this assertion is: IF something is due, the review is first.
    if ((due0.total || 0) > 0) {
        p = await renderPanel();
        ok('the review is the FIRST item', /review/i.test(p.items[0].what),
           JSON.stringify(p.items[0].what));
        ok('and it links to /review', p.items[0].href === '/review',
           'href=' + p.items[0].href);
    } else {
        // The platform's own schedule decides when something is due, so no
        // learner in this harness will have one on demand -- which means the
        // ORDERING claim, the thing the panel exists for, cannot be observed
        // from outside. So it is driven directly: nsBuild is called with a
        // stubbed queue AND the real weakness list, and the review has to come
        // first. A panel that gets this backwards sends the learner to new
        // material while a due concept decays, which is the failure the file
        // header argues against.
        console.log('      (no learner here has a due review, so the ordering is');
        console.log('       driven directly with a stubbed queue plus the REAL');
        console.log('       weakness list -- both together, which is the only');
        console.log('       arrangement where the ordering can be wrong)');
        const stubbed = await runWithDue([
            { concept_id: 'bytes', title: 'Bytes and Binary' },
            { concept_id: 'binary-representation',
              title: 'Binary Representation' },
        ], 2);
        ok('a due review OUTRANKS two failing concepts',
           stubbed.items.length >= 2 &&
           /review/i.test(stubbed.items[0].what) &&
           !/review/i.test(stubbed.items[1].what),
           'order was: ' + stubbed.items.map(i => i.what).join('  ->  '));
        ok('and the review links to /review', stubbed.items[0].href === '/review',
           'href=' + stubbed.items[0].href);
        // Four, not three: one review plus the three failures the panel is
        // allowed to show. The first version of this assertion expected three
        // and failed against a panel that was behaving correctly -- a check
        // written from a guess about the output rather than from the rule.
        ok('the failing concepts are still listed, just AFTER the review',
           stubbed.items.length === 4 &&
           /review/i.test(stubbed.items[0].what) &&
           stubbed.items.slice(1).every(i => /look again/i.test(i.what)),
           stubbed.items.length + ' items, in order: ' +
           stubbed.items.map(i => i.what).join('  ->  '));
    }

    console.log('\n' + (failures === 0
        ? 'next_step_test: ALL ' + checks + ' CHECKS PASSED'
        : 'next_step_test: ' + failures + ' of ' + checks + ' CHECKS FAILED'));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(2); });
