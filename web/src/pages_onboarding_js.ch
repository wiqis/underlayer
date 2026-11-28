// underlayer_web — G1 onboarding client script + completion API.
//
// The script uses the DOM API (createElement/textContent) for diagnostic items,
// never innerHTML: server-supplied question text is untrusted markup and every
// attribute and text node is set as data. The completion handler re-validates
// the start concept against the course manifest before storing it.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func render_onboarding_js(page : &mut HtmlPage) {
        #js {
            var obStep = 0;
            var obGoal = 'curiosity';
            var obPrior = 'none';
            var obMinutes = 10;
            var obAnswers = {};
            var obItems = [];
            var obStarted = false;

            function obGuestId() {
                var id = null;
                try { id = localStorage.getItem('ul_guest_id'); } catch(e) { id = null; }
                if (!id) {
                    id = 'g' + Date.now().toString(36) + Math.floor(Math.random() * 1000000000).toString(36);
                    try { localStorage.setItem('ul_guest_id', id); } catch(e) {}
                }
                return id;
            }

            function obHeaders() {
                var h = { 'Content-Type': 'application/json' };
                var token = null;
                try { token = localStorage.getItem('session_token'); } catch(e) { token = null; }
                if (token) { h['Authorization'] = 'Bearer ' + token; }
                return h;
            }

            function obGo(n) {
                var steps = document.querySelectorAll('.step');
                var dots = document.querySelectorAll('.step-dot');
                var i = 0;
                while (i < steps.length) { steps[i].classList.add('hidden'); i = i + 1; }
                i = 0;
                while (i < dots.length) { dots[i].classList.remove('active'); i = i + 1; }
                var target = document.getElementById('step' + n);
                if (target) { target.classList.remove('hidden'); }
                if (dots[n]) { dots[n].classList.add('active'); }
                obStep = n;
                if (n === 4 && !obStarted) { obStarted = true; obLoadDiagnostic(); }
            }

            function obPick(btn, kind) {
                var group = btn.parentNode;
                var kids = group.querySelectorAll('.goal-btn');
                var i = 0;
                while (i < kids.length) { kids[i].classList.remove('selected'); i = i + 1; }
                btn.classList.add('selected');
                if (kind === 'goal') { obGoal = btn.getAttribute('data-goal'); }
                if (kind === 'prior') { obPrior = btn.getAttribute('data-prior'); }
                if (kind === 'minutes') { obMinutes = parseInt(btn.getAttribute('data-minutes'), 10); }
            }

            function obLoadDiagnostic() {
                var box = document.getElementById('ob-diagnostic');
                fetch('/api/onboarding/diagnostic?course_id=elf&count=6', { credentials: 'same-origin' })
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        obItems = data.items || [];
                        box.textContent = '';
                        if (obItems.length === 0) {
                            var none = document.createElement('p');
                            none.className = 'ob-quiet';
                            none.textContent = 'No check is available yet. You can start from the beginning.';
                            box.appendChild(none);
                            document.getElementById('ob-diagnostic-next').disabled = false;
                            return;
                        }
                        var i = 0;
                        while (i < obItems.length) {
                            var item = obItems[i];
                            var q = document.createElement('div');
                            q.className = 'ob-q';
                            q.setAttribute('data-exercise-id', item.exercise_id);
                            var label = document.createElement('p');
                            label.textContent = (i + 1) + '. ' + item.question;
                            q.appendChild(label);
                            var oi = 0;
                            while (oi < item.options.length) {
                                var b = document.createElement('button');
                                b.type = 'button';
                                b.textContent = item.options[oi];
                                b.setAttribute('data-index', String(oi));
                                b.onclick = (function(exid, idx, node) {
                                    return function() {
                                        obAnswers[exid] = idx;
                                        var sibs = node.parentNode.querySelectorAll('button');
                                        var k = 0;
                                        while (k < sibs.length) { sibs[k].classList.remove('selected'); k = k + 1; }
                                        node.classList.add('selected');
                                        var answered = Object.keys(obAnswers).length;
                                        document.getElementById('ob-diagnostic-next').disabled = (answered < obItems.length);
                                    };
                                })(item.exercise_id, oi, b);
                                q.appendChild(b);
                                oi = oi + 1;
                            }
                            box.appendChild(q);
                            i = i + 1;
                        }
                    })
                    .catch(function() {
                        box.textContent = 'The quick check could not load. You can still continue or skip.';
                        document.getElementById('ob-diagnostic-next').disabled = false;
                    });
            }

            function obSkipDiagnostic() { obSubmit(true, -1, 'bytes'); }

            function obFinishDiagnostic() {
                var answers = [];
                var keys = Object.keys(obAnswers);
                var i = 0;
                while (i < keys.length) {
                    answers.push({ exercise_id: keys[i], answer: obAnswers[keys[i]] });
                    i = i + 1;
                }
                fetch('/api/onboarding/score', {
                    method: 'POST', credentials: 'same-origin', headers: obHeaders(),
                    body: JSON.stringify({ course_id: 'elf', answers: answers })
                })
                .then(function(r) { return r.json(); })
                .then(function(d) { obSubmit(false, d.placement_score, d.recommended_start); })
                .catch(function() { obSubmit(true, -1, 'bytes'); });
            }

            function obSubmit(skipped, score, startConcept) {
                obGo(5);
                var bar = document.getElementById('ob-route-bar');
                if (bar) { bar.style.width = '70%'; }
                var payload = {
                    course_id: 'elf', goal: obGoal, prior_knowledge: obPrior,
                    session_minutes: obMinutes, placement_score: score,
                    starting_concept: startConcept, diagnostic_skipped: skipped,
                    guest_id: obGuestId()
                };
                fetch('/api/onboarding/complete', {
                    method: 'POST', credentials: 'same-origin', headers: obHeaders(),
                    body: JSON.stringify(payload)
                })
                .then(function(r) { return r.json(); })
                .then(function(d) {
                    if (bar) { bar.style.width = '100%'; }
                    var concept = d.starting_concept || startConcept || 'bytes';
                    var link = document.getElementById('ob-first-link');
                    if (link) { link.setAttribute('href', '/courses/elf/lessons/' + concept); }
                    var heading = document.getElementById('ob-first-title');
                    if (heading) { heading.textContent = d.starting_title || 'Bytes and Binary'; }
                    window.setTimeout(function() { obGo(6); }, 450);
                })
                .catch(function() {
                    window.setTimeout(function() { obGo(6); }, 450);
                });
            }
        }
    }

    // POST /api/onboarding/complete — G1 fields + pre-existing goal preferences.
    public func handle_onboarding_complete(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var body_str = read_body(req)
            var guest = string()
            if(body_str.size() > 0) {
                var pr = json::parse(body_str.to_view())
                if(pr is std::Result.Ok) {
                    var Ok(pj) = pr else unsafe { unreachable }
                    guest = clean_guest_id(&json_get_str(&pj, "guest_id"))
                }
            }
            if(guest.size() == 0) {
                var unauth = string("unauthorized")
                return send_error(401u, &unauth)
            }
            learner_id = string("guest_")
            learner_id.append_string(&guest)
        }
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            return send_error(400u, &err)
        }
        var pr = json::parse(body_str.to_view())
        if(pr is std::Result.Err) {
            var bad = string("invalid JSON")
            return send_error(400u, &bad)
        }
        var Ok(parsed) = pr else unsafe { unreachable }
        var goal = json_get_str(&parsed, "goal")
        var prior = json_get_str(&parsed, "prior_knowledge")
        var minutes = json_get_int(&parsed, "session_minutes") as i64
        var score = json_get_int(&parsed, "placement_score") as i64
        var start = json_get_str(&parsed, "starting_concept")
        var course_id = json_get_str(&parsed, "course_id")
        if(course_id.size() == 0) { course_id = string("elf") }
        if(goal.size() == 0) { goal = string("curiosity") }
        if(prior.size() == 0) { prior = string("none") }
        if(minutes < 5 || minutes > 120) { minutes = 10 }
        if(score < -1 || score > 3) { score = -1 }
        // Whitelist: an enum value never reaches SQL unchecked.
        var goals = string("curiosity career student builder")
        var priors = string("none aware used_tools written_parsers")
        if(!goals.contains(&goal.to_view())) { goal = string("curiosity") }
        if(!priors.contains(&prior.to_view())) { prior = string("none") }

        var courses_dir = request_courses_dir()
        var course = underlayer_repository::load_course(&courses_dir, &course_id)
        var start_valid = false
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            if(course.concepts.at_ref(ci).id.equals(&start)) { start_valid = true }
            ci = ci + 1
        }
        if(!start_valid) {
            score = -1
            if(course.concepts.size() > 0) { start = course.concepts.at_ref(0).id.copy() }
            else { start = string("bytes") }
        }
        var now = underlayer_core::current_timestamp()
        save_onboarding_state(db, &learner_id, &goal, &prior, minutes, score, &start, true)
        var guest_prefix = string("guest_")
        if(!learner_id.starts_with(&guest_prefix.to_view())) {
            underlayer_repository::mark_onboarding_complete(db, &learner_id, now)
        }
        var title = string("Bytes and Binary")
        ci = 0
        while(ci < course.concepts.size()) {
            var c = course.concepts.at_ref(ci)
            if(c.id.equals(&start)) { title = c.title.copy() }
            ci = ci + 1
        }
        var resp = string("{\"ok\":true,\"starting_concept\":\"")
        var e = underlayer_core::json_escape(&start.to_view())
        resp.append_string(&e)
        resp.append_view("\",\"starting_title\":\"")
        var et = underlayer_core::json_escape(&title.to_view())
        resp.append_string(&et)
        resp.append_view("\"}")
        return send_json_str(&resp)
    }

    public func handle_check_onboarding(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var unauth = string("{\"completed\":false,\"authenticated\":false}")
            return send_json_str(&unauth)
        }
        var completed = underlayer_repository::is_onboarding_complete(db, &learner_id)
        var resp = string("{\"completed\":")
        if(completed) { resp.append_view("true") } else { resp.append_view("false") }
        resp.append_view(",\"authenticated\":true}")
        return send_json_str(&resp)
    }

}
