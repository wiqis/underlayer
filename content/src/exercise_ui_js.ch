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
                        if (typeof __ul_report_attempt === 'function') { __ul_report_attempt(res.correct); }
                    })
                    .catch(function() {});
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
                            list.appendChild(__ul_ex_build(data.exercises[i]));
                            i = i + 1;
                        }
                    })
                    .catch(function() {});
            }
            document.addEventListener('DOMContentLoaded', function() { __ul_ex_load(); });
        }
    }

}
