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
                var all = jqAllUnits();
                var i = 0;
                while(i < all.length) {
                    all[i].setAttribute('hidden', '');
                    all[i].removeAttribute('data-jq-current');
                    i = i + 1;
                }
                jqHide(jqEl('ul-journey-arrival'), true);
                jqHide(jqEl('ul-journey-ribbon'), true);
                jqHide(jqEl('ul-journey-remember'), true);
                jqHide(jqEl('ul-journey-retrieve'), true);
                jqHide(jqEl('ul-journey-controls'), true);
                jqHide(jqEl('ul-journey-finish'), true);
                jqHide(jqEl('ul-journey-paused'), false);
                // Pausing collapses the lesson to one obvious action. Focus
                // that action rather than leaving focus on a now-hidden button.
                jqFocusEl(jqEl('ul-journey-resume'));
            }

            function jqResume() {
                jqState.paused = false;
                jqSet(jqKey('paused'), '0');
                jqHide(jqEl('ul-journey-paused'), true);
                var saved = parseInt(jqGet(jqKey('step')), 10);
                if(isNaN(saved)) { saved = jqState.idx; }
                jqStep(saved);
            }

            function jqDeep(focus) {
                // Put the active unit back in the lesson's authored order so
                // the full reference reads top to bottom, not with one unit
                // stranded inside the journey shell.
                jqUnstage();
                jqState.deep = true;
                jqSet(jqKey('deep'), '1');
                var root = jqRoot();
                if(root) { root.classList.add('journey-deep'); }
                // Deep dive restores the original document: the mode class
                // goes away, so the shared hiding rule stops applying, and the
                // display controls go back to their original positions.
                document.documentElement.classList.remove('journey-active');
                if(typeof window.__ulJourneyDisplay === 'function') {
                    window.__ulJourneyDisplay(true);
                }
                var all = jqAllUnits();
                var i = 0;
                while(i < all.length) {
                    var u = all[i];
                    jqRestoreUnit(u);
                    u.removeAttribute('hidden');
                    if(u.classList.contains('unit-exercises') && u.style) { u.style.display = ''; }
                    i = i + 1;
                }
                jqHideIntro(false);
                jqActionFeedback('');
                jqHide(jqEl('ul-journey-paused'), true);
                jqHide(jqEl('ul-journey-finish'), true);
                // jqFinish() hides the whole control bar.  A learner who opens
                // the deep dive from the finish screen still needs a visible
                // way back, so restore the bar here; .journey-deep CSS hides
                // every control except the return button.
                jqHide(jqEl('ul-journey-controls'), false);
                jqHide(jqEl('ul-journey-return'), false);
                // An explicit Deep dive moves focus to the full-reference
                // heading. Boot restores a saved deep view with jqDeep(false)
                // so focus is not stolen on page load.
                if(focus === true) {
                    var lesson = jqLesson();
                    jqFocusEl(lesson ? lesson.querySelector('h1') : null);
                }
            }

            function jqReturn() {
                jqState.deep = false;
                jqSet(jqKey('deep'), '0');
                var root = jqRoot();
                if(root) { root.classList.remove('journey-deep'); }
                document.documentElement.classList.add('journey-active');
                if(typeof window.__ulJourneyDisplay === 'function') {
                    window.__ulJourneyDisplay(false);
                }
                jqHide(jqEl('ul-journey-return'), true);
                // Coming back from the finish screen must restore the recap,
                // not restart a step the learner already completed.
                if(jqGet(jqKey('finished')) === '1') { jqFinish(); }
                else { jqStep(jqState.idx); }
            }

            function jqFinish() {
                jqHide(jqEl('ul-journey-arrival'), true);
                jqHide(jqEl('ul-journey-ribbon'), true);
                jqHide(jqEl('ul-journey-remember'), true);
                jqHide(jqEl('ul-journey-retrieve'), true);
                jqHide(jqEl('ul-journey-controls'), true);
                var all = jqAllUnits();
                var i = 0;
                while(i < all.length) {
                    all[i].setAttribute('hidden', '');
                    all[i].removeAttribute('data-jq-current');
                    i = i + 1;
                }
                var h = document.querySelector('.lesson h1');
                var title = jqTrim(jqText(h)) || 'this lesson';
                var line = jqEl('ul-journey-can');
                if(line) {
                    var last = jqState.units.length > 0 ? jqState.units[jqState.units.length - 1] : null;
                    var can = last ? jqTrim(last.getAttribute('data-can-do') || '') : '';
                    if(can.length > 0) { line.textContent = can; }
                    else { line.textContent = 'You can now explain the ideas in ' + title + ' and carry them into the next lesson.'; }
                }
                var link = jqEl('ul-journey-nextlesson');
                var next = jqEl('ul-next');
                if(link && next && next.getAttribute('href')) {
                    link.setAttribute('href', next.getAttribute('href'));
                    link.textContent = next.textContent || 'Next lesson';
                    jqHide(link, false);
                } else if(link) { jqHide(link, true); }
                jqHide(jqEl('ul-journey-finish'), false);
                jqSet(jqKey('finished'), '1');
                // Reaching the recap is an explicit action (Continue on the
                // last step or Return from the deep dive); name the recap for
                // the screen reader instead of leaving focus on a hidden step.
                jqFocusEl(jqEl('ul-journey-finish-head'));
            }

            function jqClickedAction(ev) {
                var el = ev.target;
                while(el && el !== document) {
                    var c = el.className || '';
                    if(typeof c === 'string' && (c.indexOf('quiz-option') >= 0 || c.indexOf('hex-byte') >= 0 || c.indexOf('exercise-option') >= 0 || c.indexOf('tf-option') >= 0 || c.indexOf('recognize-option') >= 0)) {
                        var explain = jqTrim(el.getAttribute('data-explain') || '');
                        var correct = el.getAttribute('data-correct') === 'true';
                        if(c.indexOf('quiz-option') >= 0 && explain.length > 0 && !correct) {
                            jqActionFeedback('Good try. Here is why: ' + explain);
                        } else { jqActionFeedback(''); }
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
                jqBindClick('ul-journey-deep', function() { jqDeep(true); });
                jqBindClick('ul-journey-deep-finish', function() { jqDeep(true); });
                jqBindClick('ul-journey-return', jqReturn);
                jqBindClick('ul-journey-reveal', jqReveal);
                jqBindClick('ul-journey-reveal-earlier', jqRevealEarlier);
                var note = jqEl('ul-journey-note');
                if(note) { note.addEventListener('input', jqOnNote); }
                document.addEventListener('click', jqClickedAction, true);
                document.addEventListener('change', function(ev) {
                    var el = ev.target;
                    if(el && el.classList && el.classList.contains('fill-blank')) {
                        var answer = el.getAttribute('data-answer') || '';
                        var typed = jqTrim(el.value);
                        if(answer.length > 0 && typed.length > 0 && typed !== answer) {
                            jqActionFeedback('Have another look - this step says the value is ' + answer + '.');
                        } else { jqActionFeedback(''); }
                        jqMarkAction();
                    }
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

