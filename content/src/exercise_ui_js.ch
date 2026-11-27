// Shared exercise loader + builders for all 8 lesson types (4.1.29).
// Self-contained: own context parser, injects #api-exercises when missing.
// Wired from render_lesson_js and from every ELF lesson page.
public namespace underlayer_content {

    public func render_exercise_js(page : &mut HtmlPage) {
        #js {
            function __ul_ex_ctx() {
                var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
                if (parts.length >= 4) {
                    if (parts[0] === 'courses') {
                        if (parts[2] === 'lessons') {
                            return { course: parts[1], concept: parts[3] };
                        }
                    }
                }
                return null;
            }
            function __ul_ex_ensure() {
                var box = document.getElementById('api-exercises');
                if (!box) {
                    box = document.createElement('div');
                    box.id = 'api-exercises';
                    box.className = 'unit unit-exercises';
                    box.style.display = 'none';
                    var h = document.createElement('h2');
                    h.textContent = 'Practice Exercises';
                    box.appendChild(h);
                    var list = document.createElement('div');
                    list.id = 'exercise-list';
                    box.appendChild(list);
                    var lesson = document.querySelector('.lesson');
                    if (lesson) { lesson.appendChild(box); } else { document.body.appendChild(box); }
                }
                var list = document.getElementById('exercise-list');
                if (!list) {
                    list = document.createElement('div');
                    list.id = 'exercise-list';
                    box.appendChild(list);
                }
                return list;
            }
            function __ul_ex_submit(ex, answer, controls, fb) {
                var i = 0;
                while (i < controls.length) { controls[i].disabled = true; i = i + 1; }
                var url = '/api/exercises/submit?exercise_id=' + encodeURIComponent(ex.id) +
                    '&answer=' + encodeURIComponent(answer) +
                    '&course_id=' + encodeURIComponent(__ul_ex_ctx() ? __ul_ex_ctx().course : '');
                fetch(url, { method: 'POST' })
                    .then(function(r) { return r.json(); })
                    .then(function(res) {
                        if (res.correct) {
                            fb.className = 'exercise-feedback ok';
                        } else {
                            fb.className = 'exercise-feedback err';
                        }
                        var text = (res.correct ? 'Correct! ' : 'Not quite. ') + (res.explanation || '');
                        if (res.correct_answer && res.correct === false) {
                            text = text + ' Answer: ' + res.correct_answer;
                        }
                        fb.textContent = text;
                        // 4.2.19: the real streak is shown only when the server
                        // resolved a learner. A signed-out answer returns 0,
                        // and printing "0 in a row" would be a misleading
                        // verdict on progress that does not exist.
                        if (res.authenticated === true && res.streak > 0) {
                            var st = document.createElement('span');
                            st.className = 'exercise-streak';
                            st.textContent = ' - ' + res.streak + ' correct in a row';
                            fb.appendChild(st);
                        }
                        if (typeof __ul_report_attempt === 'function') { __ul_report_attempt(res.correct); }
                    })
                    .catch(function() {});
            }
            // 4.1.30: progressive hints, wired to the repaired I2 route.
            // GET /api/exercises/hint takes exercise_id + a 1..3 level. Each
            // click asks for the next level; the server never invents a deeper
            // hint from the explanation, it falls back to its own authored text.
            // The endpoint is public but the fetch carries the cookie and the
            // legacy bearer exactly like the submit call, so behaviour matches
            // a signed-in session without leaking anything.
            function __ul_ex_add_hint(card, ex) {
                if (!card || !ex || !ex.id) { return; }
                var box = document.createElement('div');
                box.className = 'exercise-hint-box';
                var btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'exercise-check';
                btn.textContent = 'Need a hint?';
                var out = document.createElement('p');
                out.className = 'exercise-hint';
                out.setAttribute('aria-live', 'polite');
                var level = 0;
                btn.onclick = function() {
                    if (level >= 3) { return; }
                    level = level + 1;
                    var url = '/api/exercises/hint?exercise_id=' + encodeURIComponent(ex.id) + '&level=' + level;
                    var h = {};
                    if (typeof window.__ulHeaders === 'function') { h = window.__ulHeaders(); }
                    fetch(url, { credentials: 'same-origin', headers: h })
                        .then(function(r) { return r.json(); })
                        .then(function(d) {
                            var shown = level;
                            if (d.level) { shown = d.level; }
                            var text = d.hint ? d.hint : 'No hint is authored for this item yet.';
                            out.textContent = 'Hint ' + shown + ': ' + text;
                            if (shown >= 3) { btn.disabled = true; }
                        })
                        .catch(function() { out.textContent = 'Hint not available right now.'; });
                };
                box.appendChild(btn);
                box.appendChild(out);
                card.appendChild(box);
            }

            function __ul_ex_load() {
                var ctx = __ul_ex_ctx();
                if (!ctx) { return; }
                var list = __ul_ex_ensure();
                var box = document.getElementById('api-exercises');
                fetch('/api/exercises/' + encodeURIComponent(ctx.concept))
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if (!data.exercises || data.exercises.length === 0) { return; }
                        box.style.display = '';
                        var i = 0;
                        while (i < data.exercises.length) {
                            var card = __ul_ex_build(data.exercises[i]);
                            list.appendChild(card);
                            __ul_ex_add_hint(card, data.exercises[i]);
                            i = i + 1;
                        }
                    })
                    .catch(function() {});
            }
            document.addEventListener('DOMContentLoaded', function() { __ul_ex_load(); });
        }
    }

}
