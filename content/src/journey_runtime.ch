// underlayer_content - journey runtime: walk the existing .unit blocks.
//
// The runtime never authors technical text.  Every label, key point, question
// and answer is read from the lesson that is already on the page.  Nothing is
// fetched: the whole journey runs from file:// with no server.
//
// JS in this file is ASCII only.  The #js lexer cannot read non-ASCII bytes, and
// it drops grouping parentheses, so negations are written as explicit compares.
using std::string
using std::string_view

public namespace underlayer_content {

    public func render_journey_runtime_js(page : &mut HtmlPage) {
        #js {
            var jqSeq = 0;
            var jqState = { units: [], idx: 0, course: '', concept: '', gate: {}, started: false, deep: false, paused: false };

            function jqRoot() { return document.getElementById('ul-journey'); }
            function jqEl(id) { return document.getElementById(id); }

            function jqContext() {
                var root = jqRoot();
                var course = root ? root.getAttribute('data-course') : '';
                var concept = root ? root.getAttribute('data-concept') : '';
                var parts = window.location.pathname.split('/');
                var i = 0;
                while(i < parts.length) {
                    if(parts[i] === 'courses' && i + 1 < parts.length) {
                        if(!course) { course = parts[i + 1]; }
                    }
                    if(parts[i] === 'lessons' && i + 1 < parts.length) {
                        if(!concept) { concept = parts[i + 1]; }
                    }
                    i = i + 1;
                }
                if(!course) { course = parts.length > 1 ? parts[parts.length - 2] : 'course'; }
                if(!concept) { concept = document.title || 'lesson'; }
                return { course: course || 'course', concept: concept || 'lesson' };
            }

            function jqKey(part) {
                return 'ul-journey:' + jqState.course + ':' + jqState.concept + ':' + part;
            }
            function jqGet(key) {
                try { return window.localStorage.getItem(key) || ''; } catch(e) { return ''; }
            }
            function jqSet(key, value) {
                try { window.localStorage.setItem(key, value); } catch(e) { }
            }

            function jqHide(el, yes) {
                if(!el) { return; }
                if(yes) { el.setAttribute('hidden', ''); }
                else { el.removeAttribute('hidden'); }
            }

            function jqChrome() {
                jqHide(jqEl('ul-journey-arrival'), true);
                jqHide(jqEl('ul-journey-ribbon'), false);
                jqHide(jqEl('ul-journey-remember'), false);
                jqHide(jqEl('ul-journey-retrieve'), false);
                jqHide(jqEl('ul-journey-controls'), false);
                jqHide(jqEl('ul-journey-finish'), true);
                jqHide(jqEl('ul-journey-paused'), true);
                var all = jqAllUnits();
                var i = 0;
                while(i < all.length) {
                    all[i].setAttribute('hidden', '');
                    i = i + 1;
                }
                jqHideIntro(true);
                jqActionFeedback('');
            }

            function jqStep(i) {
                var s = jqState;
                if(i < 0) { i = 0; }
                if(i >= s.units.length) { jqFinish(); return; }
                s.idx = i;
                jqSet(jqKey('step'), String(i));
                jqChrome();
                var u = s.units[i];
                jqPrepareUnit(u);
                u.removeAttribute('hidden');
                var count = jqEl('ul-journey-count');
                if(count) { count.textContent = 'Step ' + (i + 1) + ' of ' + s.units.length; }
                var purpose = jqEl('ul-journey-purpose');
                if(purpose) {
                    var aim = jqTrim(u.getAttribute('data-aim') || '');
                    if(aim.length > 0) { purpose.textContent = aim; }
                    else { purpose.textContent = jqPurpose(u) + ' - ' + jqTitle(u); }
                }
                var next = jqEl('ul-journey-next');
                if(next) {
                    if(i + 1 < s.units.length) { next.textContent = 'Next: ' + jqTitle(s.units[i + 1]); }
                    else { next.textContent = 'Next: finish'; }
                }
                var key = jqEl('ul-journey-keypoint');
                if(key) {
                    var derived = jqTrim(u.getAttribute('data-remember') || '');
                    if(derived.length > 0) { key.textContent = derived; }
                    else if(jqNoFact(u)) { key.textContent = 'No new fact to memorise - this step is about seeing the link'; }
                    else { key.textContent = jqKeyPoint(u); }
                }
                var back = jqEl('ul-journey-back');
                if(back) { back.disabled = i === 0; }
                jqPrepareNote(i);
                jqPrepareGate(i);
                jqPrepareRetrieval(i);
                jqUpdateContinue();
                var stage = jqEl('ul-journey-stage');
                if(stage && stage.scrollIntoView && i > 0) { stage.scrollIntoView({ block: 'start' }); }
            }

            function jqBoot() {
                var root = jqRoot();
                if(!root) { return; }
                var units = jqUnits();
                if(units.length === 0) { return; }
                var ctx = jqContext();
                jqState.course = ctx.course;
                jqState.concept = ctx.concept;
                jqState.units = units;
                var first = units[0];
                if(first && first.parentNode) { first.parentNode.insertBefore(root, first); }
                var meta = jqEl('ul-journey-meta');
                var bits = [];
                var minutes = root.getAttribute('data-minutes');
                var diff = root.getAttribute('data-difficulty');
                var prereq = root.getAttribute('data-prereq');
                if(minutes && minutes !== '0') { bits.push(minutes + ' min'); }
                if(diff) { bits.push(diff); }
                if(prereq) { bits.push('Continues from ' + prereq); }
                if(meta && bits.length > 0) { meta.textContent = bits.join(' | '); meta.hidden = false; }
                var arrival = jqEl('ul-journey-aim');
                if(arrival && first) {
                    var aim0 = jqTrim(first.getAttribute('data-aim') || '');
                    if(aim0.length > 0) { arrival.textContent = aim0; }
                }
                jqHideIntro(true);
                root.hidden = false;
                var savedStep = parseInt(jqGet(jqKey('step')), 10);
                if(isNaN(savedStep)) { savedStep = 0; }
                if(savedStep < 0 || savedStep >= units.length) { savedStep = 0; }
                jqBind();
                if(jqGet(jqKey('deep')) === '1') { jqDeep(); return; }
                if(jqGet(jqKey('paused')) === '1') {
                    jqState.paused = true;
                    jqHide(jqEl('ul-journey-arrival'), true);
                    jqHide(jqEl('ul-journey-paused'), false);
                    return;
                }
                jqHide(jqEl('ul-journey-paused'), true);
                jqState.started = false;
                jqHide(jqEl('ul-journey-arrival'), false);
                jqHide(jqEl('ul-journey-ribbon'), true);
                jqHide(jqEl('ul-journey-remember'), true);
                jqHide(jqEl('ul-journey-retrieve'), true);
                jqHide(jqEl('ul-journey-controls'), true);
            }

            if(document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', jqBoot); }
            else { jqBoot(); }

        }
    }
}
