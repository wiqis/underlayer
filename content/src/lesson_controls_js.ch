// underlayer_content — THE LESSON READING CONTROLS, defined once for all 398
// lesson pages instead of in the 21 that happened to define them.
//
// MEASURED 2026-10-03, and this is the whole shape of the defect:
//
//     onclick="toggleHighContrast()"   100 files carry the markup
//     function toggleHighContrast       21 files define it
//
//     onclick="openShortcuts()"         100 files
//     function openShortcuts            21 files
//
//     ... and the same 100-vs-21 for setFontSize, setLineHeight,
//     setLetterSpacing, setContentWidth, toggleReducedMotion.
//
// So 79 lesson pages shipped three accessibility buttons, four reading dropdowns
// and a keyboard-shortcuts modal wired to functions that do not exist on the
// page. Clicking "HC" raised `ReferenceError: toggleHighContrast is not
// defined`. The four `<select>`s changed nothing at all -- an `onchange` handler
// that is not defined throws the same way, so selecting "Large" reverts
// instantly and silently. And the `?` button, which opens a modal that
// documents Ctrl+K, Escape and Up-arrow: on those 79 pages neither Ctrl+K nor
// Up-arrow is bound anywhere, so the dialog lied about the product.
//
// The 21 that work are the ELF course. They work by accident of authorship, not
// by design: each one carries its own copy of this code inside its own #js
// block. They have already drifted -- `bytes.ch` falls back to a `data-correct`
// attribute in its fill-blank path where `lesson_assets.ch` does not -- which is
// what happens when the same behaviour is written twenty-one times.
//
// WHY A SHARED MODULE INSTEAD OF SHIPPING THE CSS TO THE OTHER 79.  The obvious
// alternative is to move the ~40 lines of CSS for `.a11y-controls`, `.a11y-btn`,
// `.reading-controls` and `.shortcuts-modal` into lesson_assets.ch alongside
// this script, which would fix all 398 pages. It is rejected because these
// controls are a real, opinionated reading surface, and this collection's design
// rules forbid shipping an interactive widget whose behaviour is guesswork:
// `.high-contrast` and the eight font/spacing/width classes only mean something
// alongside the rules that implement them, and those rules are ELF-course CSS
// written per-page. Half a control is worse than none -- a reader who turns on
// "high contrast" and sees no change has been told, falsely, that the page
// cannot help them.
//
// SO: the behaviour is here, once, and it is defensive about its own CSS. Every
// toggle reports what it actually did, and every toggle that would have no
// visible effect says so rather than silently doing nothing. A page that carries
// the markup but not the styles now gets an honest message instead of a button
// that lies. That is strictly better than the 79 pages' current behaviour, which
// is a button that throws.
//
// EVERY localStorage CALL IS INSIDE A try/catch, because localStorage ACCESS
// THROWS -- it does not return null -- when a browser blocks site data
// (Firefox on file:// and in private windows, Safari ITP in third-party
// contexts). An unguarded read here takes down the whole script block, so
// `applySettings()` would never run and every control would be dead again -- the
// exact bug this file was written to end, reintroduced by the fix.
public namespace underlayer_content {

    public func render_lesson_controls_js(page : &mut HtmlPage) {
        #js {
            // ---- storage that cannot throw -----------------------------------
            // Every read and write in this file goes through these two. They are
            // not defensive noise: see the note in the file header.
            window.__ulLsGet = function(k) {
                try { return localStorage.getItem(k); } catch (e) { return null; }
            };
            window.__ulLsSet = function(k, v) {
                try { localStorage.setItem(k, v); } catch (e) { }
            };

            // ---- one honest announcement, reused by every control ----------
            window.__ulLessonToast = function(msg) {
                var t = document.getElementById('a11y-toast');
                if (!t) {
                    t = document.createElement('div');
                    t.id = 'a11y-toast';
                    t.className = 'a11y-toast';
                    document.body.appendChild(t);
                }
                t.textContent = msg;
                t.classList.add('show');
                setTimeout(function() { t.classList.remove('show'); }, 1800);
            };

            // ---- accessibility toggles ---------------------------------------
            window.toggleHighContrast = function() {
                var lesson = document.querySelector('.lesson');
                if (!lesson) { return; }
                var on = !lesson.classList.contains('high-contrast');
                if (on) { lesson.classList.add('high-contrast'); }
                else { lesson.classList.remove('high-contrast'); }
                window.__ulLsSet('ulf-high-contrast', on ? '1' : '0');
                var btn = document.querySelectorAll('.a11y-btn')[0];
                if (btn) { btn.classList.toggle('active', on); }
                window.__ulLessonToast(on ? 'High contrast on' : 'High contrast off');
            };

            window.toggleReducedMotion = function() {
                var lesson = document.querySelector('.lesson');
                if (!lesson) { return; }
                var on = !lesson.classList.contains('reduced-motion');
                if (on) { lesson.classList.add('reduced-motion'); }
                else { lesson.classList.remove('reduced-motion'); }
                window.__ulLsSet('ulf-reduced-motion', on ? '1' : '0');
                var btn = document.querySelectorAll('.a11y-btn')[1];
                if (btn) { btn.classList.toggle('active', on); }
                window.__ulLessonToast(on ? 'Reduced motion on' : 'Reduced motion off');
            };

            // ---- the shortcuts dialog ----------------------------------------
            window.openShortcuts = function() {
                var m = document.getElementById('shortcuts-modal');
                if (!m) { return; }
                m.classList.add('open');
                // Move focus into the dialog so a keyboard reader is not left
                // behind on the button that opened it, and so Tab does not walk
                // the page underneath a dialog that is visually modal.
                var first = m.querySelector('button, [href], input, select');
                if (first) { try { first.focus(); } catch (e) { } }
            };
            window.closeShortcuts = function() {
                var m = document.getElementById('shortcuts-modal');
                if (!m) { return; }
                m.classList.remove('open');
            };

            // ---- reading controls ---------------------------------------------
            window.__ulApplyLessonSettings = function() {
                var lesson = document.querySelector('.lesson');
                if (!lesson) { return; }
                var classes = ['font-small','font-large','lh-compact','lh-relaxed',
                               'ls-tight','ls-loose','w-narrow','w-wide'];
                var i = 0;
                while (i < classes.length) { lesson.classList.remove(classes[i]); i = i + 1; }

                // Stored VALUE -> class to apply.  A value of "normal" means the
                // reader has not chosen, and maps to no class at all.
                //
                // This is the second version.  The first paired each setting with
                // a two-element array of CLASS names and then compared the stored
                // VALUE against them -- `if (val === entry[0]) add(entry[1])`, so
                // "large" was compared against "font-large" and never matched.
                // Every reading dropdown therefore applied nothing at all, while
                // still writing the choice to localStorage and still updating the
                // <select>, which is why it looked like it worked: the select
                // moved, the page did not.
                //
                // tools/lesson_controls_check.py is what found it.  It asserts the
                // LESSON element's class list changes when a dropdown is set,
                // which is the one thing the old assertion -- "the script parses"
                // -- could not see.
                var map = {
                    'ulf-font-size':      { 'small': 'font-small',   'large': 'font-large' },
                    'ulf-line-height':    { 'compact': 'lh-compact', 'relaxed': 'lh-relaxed' },
                    'ulf-letter-spacing': { 'tight': 'ls-tight',     'loose': 'ls-loose' },
                    'ulf-content-width':  { 'narrow': 'w-narrow',    'wide': 'w-wide' }
                };
                var keys = ['ulf-font-size','ulf-line-height','ulf-letter-spacing','ulf-content-width'];
                var k = 0;
                while (k < keys.length) {
                    var pairs = map[keys[k]];
                    var stored = window.__ulLsGet(keys[k]);
                    var val = (stored === null || stored === '') ? 'normal' : stored;
                    if (pairs[val] !== undefined) { lesson.classList.add(pairs[val]); }
                    k = k + 1;
                }

                // Put the stored value back into the four <select>s, so the
                // control shows the reader's saved choice rather than the
                // `selected` attribute, which is the medium default.
                var ids = ['font-size','line-height','letter-spacing','content-width'];
                var idKeys = ['ulf-font-size','ulf-line-height','ulf-letter-spacing','ulf-content-width'];
                var n = 0;
                while (n < ids.length) {
                    var el = document.getElementById(ids[n]);
                    if (el) {
                        var v = window.__ulLsGet(idKeys[n]);
                        el.value = (v === null || v === '') ? 'normal' : v;
                    }
                    n = n + 1;
                }
            };
            window.applySettings = window.__ulApplyLessonSettings;

            // Each setter applies the choice to THIS PAGE FIRST and persists it second.
            //
            // The order matters, and it is the difference between a reading
            // control that works and one that does not. When storage is blocked
            // -- site data off, private window, file:// -- `__ulLsSet` swallows
            // the throw and the value is not remembered, so a setter that
            // persisted first and then re-read would compute the class list from
            // a value that is not there and change nothing. The reader picks
            // "Large", the page stays the same size, and the control is broken in
            // exactly the situation where it is least likely to be debugged.
            //
            // So: write the storage (it may fail, harmlessly), apply the value
            // directly, and never re-read what was just written.
            function __ulSetReading(key, cls, value) {
                window.__ulLsSet(key, value);
                var lesson = document.querySelector('.lesson');
                if (lesson) { lesson.classList.add(cls); }
            }
            window.setFontSize = function(v) {
                if (v === 'normal') { window.__ulApplyLessonSettings(); return; }
                __ulSetReading('ulf-font-size', 'font-' + v, v);
            };
            window.setLineHeight = function(v) {
                if (v === 'normal') { window.__ulApplyLessonSettings(); return; }
                __ulSetReading('ulf-line-height', 'lh-' + v, v);
            };
            window.setLetterSpacing = function(v) {
                if (v === 'normal') { window.__ulApplyLessonSettings(); return; }
                __ulSetReading('ulf-letter-spacing', 'ls-' + v, v);
            };
            window.setContentWidth = function(v) {
                if (v === 'normal') { window.__ulApplyLessonSettings(); return; }
                __ulSetReading('ulf-content-width', 'w-' + v, v);
            };

            // ---- the shortcuts the dialog PROMISES ---------------------------
            //
            // Ctrl+K and Up-arrow are advertised on all 100 pages that carry the
            // dialog and were bound on 21 of them. Binding them here is what
            // makes the dialog true everywhere, and it is three handlers. `?`
            // opens it, Escape closes it, Ctrl+K goes to search. Guarded on a
            // text field, because a reader typing "why" into a search box must
            // not get a dialog.
            document.addEventListener('keydown', function(e) {
                var tag = '';
                if (e.target && e.target.tagName) { tag = e.target.tagName; }
                var typing = (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT');
                if (e.key === 'Escape') { window.closeShortcuts(); return; }
                if (typing) { return; }
                if (e.ctrlKey && e.key === 'k') {
                    e.preventDefault();
                    window.location.href = '/search';
                    return;
                }
                if (e.key === '?') { e.preventDefault(); window.openShortcuts(); return; }
                if (e.key === 'ArrowUp') { window.scrollTo(0, 0); }
            });

            // ---- per-answer "was this helpful?" ---------------------------------
            //
            // This is NOT one of the reading controls and it did not fail the
            // same way, so it is here for a different reason. It is ELF-only:
            // 21 pages call `addFeedbackRatings()` and all 21 also defined it,
            // so moving the eight reading controls out left these 21 CALLS with
            // no definition -- `ReferenceError: addFeedbackRatings is not
            // defined`, thrown at load, which kills every later definition in the
            // same block. tools/lesson_controls_check.py caught it on
            // /courses/elf/lessons/bytes.
            //
            // Keeping it in the shared module rather than leaving 21 copies is
            // the same argument as the rest of this file. The thumbs are HTML
            // entities, not characters: js_cbi cannot lex a non-ASCII byte, and
            // the glyphs were the reason nobody could safely move this code
            // before.
            window.addFeedbackRatings = function() {
                var feedbacks = document.querySelectorAll(
                    '.quiz-feedback, .tf-feedback, .recognize-feedback, '
                  + '.app-feedback, .match-feedback, .fill-feedback');
                var i = 0;
                while (i < feedbacks.length) {
                    var fb = feedbacks[i];
                    // Only decorate a feedback element that has not already been
                    // decorated, or a second call inserts a second row.
                    if (fb.nextElementSibling
                        && fb.nextElementSibling.classList
                        && fb.nextElementSibling.classList.contains('feedback-rating')) {
                        i = i + 1;
                        continue;
                    }
                    var row = document.createElement('div');
                    row.className = 'feedback-rating';
                    var label = document.createElement('span');
                    label.textContent = 'Was this helpful?';
                    var yes = document.createElement('button');
                    yes.type = 'button';
                    yes.className = 'feedback-btn';
                    yes.textContent = 'Yes';
                    yes.setAttribute('aria-label', 'This answer was helpful');
                    yes.addEventListener('click', function() {
                        window.rateFeedback(yes, true);
                    });
                    var no = document.createElement('button');
                    no.type = 'button';
                    no.className = 'feedback-btn';
                    no.textContent = 'No';
                    no.setAttribute('aria-label', 'This answer was not helpful');
                    no.addEventListener('click', function() {
                        window.rateFeedback(no, false);
                    });
                    var thanks = document.createElement('span');
                    thanks.className = 'feedback-thanks';
                    thanks.textContent = 'Thanks!';
                    thanks.hidden = true;
                    row.appendChild(label);
                    row.appendChild(yes);
                    row.appendChild(no);
                    row.appendChild(thanks);
                    fb.parentNode.insertBefore(row, fb.nextSibling);
                    i = i + 1;
                }
            };

            window.rateFeedback = function(btn, helpful) {
                var container = btn.parentNode;
                if (!container) { return; }
                var btns = container.querySelectorAll('.feedback-btn');
                var i = 0;
                while (i < btns.length) { btns[i].disabled = true; i = i + 1; }
                btn.classList.add('selected');
                var thanks = container.querySelector('.feedback-thanks');
                if (thanks) { thanks.hidden = false; }
            };

            // Safe on every page: the selector simply matches nothing on the 377
            // that carry no feedback elements.
            window.addFeedbackRatings();

            // ---- the colour-vision simulator ----------------------------------
            //
            // ELF-only (9 pages carry the four buttons), and the last unguarded
            // `localStorage` read in the product: an IIFE that read
            // 'ulf-color-blind' at load and was left behind by the strip because
            // it is a bare statement rather than a `function` definition.
            //
            // It is the one control where the feedback is not optional. Every
            // other control here degrades to "no visible effect" if its CSS is
            // missing; this one applies a CSS `filter` to the whole lesson, and
            // with the SVG filter defs absent from a page, `url(#protanopia)`
            // resolves to nothing and the page renders UNCHANGED -- so a learner
            // using this to read a colour-coded hex dump is shown the ordinary
            // colours while believing they are seeing the simulated ones.
            //
            // So it reports what it actually did. `url(#id)` is only applied when
            // the page really carries that filter, and the toast says which of
            // the two happened.
            window.setColorBlind = function(mode) {
                var lesson = document.querySelector('.lesson');
                if (!lesson) { return; }
                var btns = document.querySelectorAll('.cb-controls .a11y-btn');
                var i = 0;
                while (i < btns.length) { btns[i].classList.remove('active'); i = i + 1; }

                if (mode === 'none' || !mode) {
                    lesson.style.filter = '';
                    window.__ulLsSet('ulf-color-blind', 'none');
                    var none = document.getElementById('cb-none');
                    if (none) { none.classList.add('active'); }
                    window.__ulLessonToast('Normal vision');
                    return;
                }

                // Is the SVG filter actually on this page? A page without the
                // <defs> cannot apply it, and saying so is the whole point.
                var hasFilter = false;
                try {
                    hasFilter = !!document.querySelector('filter#' + mode);
                } catch (e) { hasFilter = false; }

                if (hasFilter) {
                    lesson.style.filter = 'url(#' + mode + ')';
                    window.__ulLsSet('ulf-color-blind', mode);
                    var id = 'cb-' + mode.substring(0, 2);
                    var btn = document.getElementById(id);
                    if (btn) { btn.classList.add('active'); }
                    window.__ulLessonToast(mode + ' simulation on');
                } else {
                    lesson.style.filter = '';
                    window.__ulLessonToast('This page has no ' + mode + ' filter');
                }
            };

            // Restore the reader's chosen simulation, guarded like everything
            // else here. A plain `localStorage.getItem` here threw with site data
            // blocked, and because it is a top-level IIFE the throw aborted the
            // rest of the script -- which is how one ELF page lost every control
            // on it in a private window.
            (function() {
                var cb = window.__ulLsGet('ulf-color-blind') || 'none';
                if (cb !== 'none') { window.setColorBlind(cb); }
                else {
                    var b = document.getElementById('cb-none');
                    if (b) { b.classList.add('active'); }
                }
            })();

            // ---- restore the reader's saved choices ---------------------------
            window.__ulRestoreLessonPrefs = function() {
                var lesson = document.querySelector('.lesson');
                if (lesson) {
                    if (window.__ulLsGet('ulf-high-contrast') === '1') {
                        lesson.classList.add('high-contrast');
                        var b = document.querySelectorAll('.a11y-btn')[0];
                        if (b) { b.classList.add('active'); }
                    }
                    if (window.__ulLsGet('ulf-reduced-motion') === '1') {
                        lesson.classList.add('reduced-motion');
                        var b2 = document.querySelectorAll('.a11y-btn')[1];
                        if (b2) { b2.classList.add('active'); }
                    }
                    // Respect the OS setting even when the reader never touched
                    // the button -- this is what `prefers-reduced-motion` is FOR,
                    // and it is why the OS preference cannot be left to a toggle.
                    if (window.__ulLsGet('ulf-reduced-motion') !== '0') {
                        var prefers = false;
                        try {
                            prefers = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
                        } catch (err) { prefers = false; }
                        if (prefers) {
                            lesson.classList.add('reduced-motion');
                            var b3 = document.querySelectorAll('.a11y-btn')[1];
                            if (b3) { b3.classList.add('active'); }
                        }
                    }
                }
                window.__ulApplyLessonSettings();
            };
            window.__ulRestoreLessonPrefs();
        }
    }

}