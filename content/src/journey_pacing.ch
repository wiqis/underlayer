// underlayer_content - pacing, deep dive and finish for the guided journey.
//
// Pausing saves the exact step locally; Deep dive removes the chrome so the
// original lesson is byte-for-byte the document it was before the journey.
using std::string
using std::string_view

public namespace underlayer_content {

    public func render_journey_pacing_js(page : &mut HtmlPage) {
        #js {
            function jqPause() {
                jqState.paused = true;
                jqSet(jqKey('paused'), '1');
                jqSet(jqKey('step'), String(jqState.idx));
                var i = 0;
                while(i < jqState.units.length) {
                    jqState.units[i].setAttribute('hidden', '');
                    i = i + 1;
                }
                jqHide(jqEl('ul-journey-arrival'), true);
                jqHide(jqEl('ul-journey-ribbon'), true);
                jqHide(jqEl('ul-journey-remember'), true);
                jqHide(jqEl('ul-journey-retrieve'), true);
                jqHide(jqEl('ul-journey-controls'), true);
                jqHide(jqEl('ul-journey-finish'), true);
                jqHide(jqEl('ul-journey-paused'), false);
            }

            function jqResume() {
                jqState.paused = false;
                jqSet(jqKey('paused'), '0');
                jqHide(jqEl('ul-journey-paused'), true);
                var saved = parseInt(jqGet(jqKey('step')), 10);
                if(isNaN(saved)) { saved = jqState.idx; }
                jqStep(saved);
            }

            function jqDeep() {
                jqState.deep = true;
                jqSet(jqKey('deep'), '1');
                var root = jqRoot();
                if(root) { root.classList.add('journey-deep'); }
                var i = 0;
                while(i < jqState.units.length) {
                    var u = jqState.units[i];
                    jqRestoreUnit(u);
                    u.removeAttribute('hidden');
                    i = i + 1;
                }
                jqHide(jqEl('ul-journey-paused'), true);
                jqHide(jqEl('ul-journey-finish'), true);
                jqHide(jqEl('ul-journey-return'), false);
            }

            function jqReturn() {
                jqState.deep = false;
                jqSet(jqKey('deep'), '0');
                var root = jqRoot();
                if(root) { root.classList.remove('journey-deep'); }
                jqHide(jqEl('ul-journey-return'), true);
                jqStep(jqState.idx);
            }

            function jqFinish() {
                jqHide(jqEl('ul-journey-arrival'), true);
                jqHide(jqEl('ul-journey-ribbon'), true);
                jqHide(jqEl('ul-journey-remember'), true);
                jqHide(jqEl('ul-journey-retrieve'), true);
                jqHide(jqEl('ul-journey-controls'), true);
                var i = 0;
                while(i < jqState.units.length) {
                    jqState.units[i].setAttribute('hidden', '');
                    i = i + 1;
                }
                var h = document.querySelector('.lesson h1');
                var title = jqTrim(jqText(h)) || 'this lesson';
                var line = jqEl('ul-journey-can');
                if(line) { line.textContent = 'You can now explain the ideas in ' + title + ' and carry them into the next lesson.'; }
                var link = jqEl('ul-journey-nextlesson');
                var next = jqEl('ul-next');
                if(link && next && next.getAttribute('href')) {
                    link.setAttribute('href', next.getAttribute('href'));
                    link.textContent = next.textContent || 'Next lesson';
                    jqHide(link, false);
                } else if(link) { jqHide(link, true); }
                jqHide(jqEl('ul-journey-finish'), false);
                jqSet(jqKey('finished'), '1');
            }

            function jqClickedAction(ev) {
                var el = ev.target;
                while(el && el !== document) {
                    var c = el.className || '';
                    if(typeof c === 'string' && (c.indexOf('quiz-option') >= 0 || c.indexOf('hex-byte') >= 0 || c.indexOf('exercise-option') >= 0 || c.indexOf('tf-option') >= 0 || c.indexOf('recognize-option') >= 0)) {
                        jqMarkAction();
                        return;
                    }
                    el = el.parentNode;
                }
            }

            function jqBindClick(id, fn) {
                var el = jqEl(id);
                if(el) { el.addEventListener('click', fn); }
            }

            function jqBind() {
                jqBindClick('ul-journey-start', function() { jqState.started = true; jqHide(jqEl('ul-journey-arrival'), true); jqStep(jqState.idx); });
                jqBindClick('ul-journey-continue', function() { jqStep(jqState.idx + 1); });
                jqBindClick('ul-journey-back', function() { jqStep(jqState.idx - 1); });
                jqBindClick('ul-journey-pause', jqPause);
                jqBindClick('ul-journey-resume', jqResume);
                jqBindClick('ul-journey-deep', jqDeep);
                jqBindClick('ul-journey-deep-finish', jqDeep);
                jqBindClick('ul-journey-return', jqReturn);
                jqBindClick('ul-journey-reveal', jqReveal);
                var note = jqEl('ul-journey-note');
                if(note) { note.addEventListener('input', jqOnNote); }
                document.addEventListener('click', jqClickedAction, true);
                document.addEventListener('change', function(ev) {
                    var el = ev.target;
                    if(el && el.classList && el.classList.contains('fill-blank')) { jqMarkAction(); }
                }, true);
                document.addEventListener('keydown', function(ev) {
                    var tag = ev.target ? ev.target.tagName : '';
                    if(tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') { return; }
                    if(ev.key === 'ArrowRight') {
                        var c = jqEl('ul-journey-continue');
                        if(c && !c.disabled) { jqStep(jqState.idx + 1); }
                    }
                    if(ev.key === 'ArrowLeft') { jqStep(jqState.idx - 1); }
                });
            }
        }
    }
}

