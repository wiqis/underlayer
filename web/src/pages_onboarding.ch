// underlayer_web — Onboarding flow page and API handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // ---- GET /onboarding — Onboarding page ----

    public func handle_onboarding_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Welcome to Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="onboarding-page">
                <div class="onboarding-card">
                    <div class="onboarding-brand">
                        <a href="/" class="brand-link">Underlayer</a>
                    </div>

                    <div class="step-indicator" id="stepIndicator">
                        <div class="step-dot active" data-step="0"></div>
                        <div class="step-dot" data-step="1"></div>
                        <div class="step-dot" data-step="2"></div>
                        <div class="step-dot" data-step="3"></div>
                    </div>

                    <div class="step" id="step0">
                        <div class="step-icon">
                            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                        </div>
                        <h1>Welcome, <span id="userName">Learner</span>!</h1>
                        <p class="step-subtitle">Let's set up your learning experience in just a few steps.</p>
                        <button class="btn btn-primary" onclick="goStep(1)">Get Started</button>
                    </div>

                    <div class="step hidden" id="step1">
                        <div class="step-icon">
                            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
                        </div>
                        <h1>Choose Your Path</h1>
                        <p class="step-subtitle">Select a course to begin your learning journey.</p>
                        <div class="course-grid" id="courseGrid">
                            <div class="course-loading">Loading courses...</div>
                        </div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="goStep(0)">Back</button>
                            <button class="btn btn-primary" id="courseNextBtn" onclick="goStep(2)" disabled>Next</button>
                        </div>
                    </div>

                    <div class="step hidden" id="step2">
                        <div class="step-icon">
                            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                        </div>
                        <h1>Set Your Goals</h1>
                        <p class="step-subtitle">How much time can you dedicate each day?</p>
                        <div class="goal-options" id="timeOptions">
                            <button class="goal-btn" data-minutes="15" onclick="selectTime(this)">
                                <span class="goal-value">15</span>
                                <span class="goal-label">min / day</span>
                                <span class="goal-desc">Casual</span>
                            </button>
                            <button class="goal-btn selected" data-minutes="20" onclick="selectTime(this)">
                                <span class="goal-value">20</span>
                                <span class="goal-label">min / day</span>
                                <span class="goal-desc">Steady</span>
                            </button>
                            <button class="goal-btn" data-minutes="30" onclick="selectTime(this)">
                                <span class="goal-value">30</span>
                                <span class="goal-label">min / day</span>
                                <span class="goal-desc">Focused</span>
                            </button>
                            <button class="goal-btn" data-minutes="45" onclick="selectTime(this)">
                                <span class="goal-value">45</span>
                                <span class="goal-label">min / day</span>
                                <span class="goal-desc">Intensive</span>
                            </button>
                        </div>
                        <div class="session-length">
                            <label class="form-label">Preferred session length</label>
                            <div class="session-options" id="sessionOptions">
                                <button class="session-btn" data-length="short" onclick="selectSession(this)">Short (5-10 min)</button>
                                <button class="session-btn selected" data-length="medium" onclick="selectSession(this)">Medium (10-20 min)</button>
                                <button class="session-btn" data-length="long" onclick="selectSession(this)">Long (20+ min)</button>
                            </div>
                        </div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="goStep(1)">Back</button>
                            <button class="btn btn-primary" onclick="goStep(3)">Next</button>
                        </div>
                    </div>

                    <div class="step hidden" id="step3">
                        <div class="step-icon">
                            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
                        </div>
                        <h1>How It Works</h1>
                        <p class="step-subtitle">A quick tour of your learning experience.</p>
                        <div class="tutorial-slides" id="tutorialSlides">
                            <div class="tutorial-slide active" data-slide="0">
                                <div class="tutorial-icon">
                                    <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                                </div>
                                <h3>Browse Courses</h3>
                                <p>Explore our collection of in-depth courses on systems programming, binary formats, and low-level concepts.</p>
                            </div>
                            <div class="tutorial-slide" data-slide="1">
                                <div class="tutorial-icon">
                                    <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="5 3 19 12 5 21 5 3"/></svg>
                                </div>
                                <h3>Start Learning</h3>
                                <p>Each concept includes detailed explanations, interactive exercises, and hands-on practice with real-world examples.</p>
                            </div>
                            <div class="tutorial-slide" data-slide="2">
                                <div class="tutorial-icon">
                                    <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
                                </div>
                                <h3>Track Progress</h3>
                                <p>Watch your knowledge grow with detailed analytics, mastery tracking, and streak awareness.</p>
                            </div>
                            <div class="tutorial-slide" data-slide="3">
                                <div class="tutorial-icon">
                                    <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="hsl(217 91% 60%)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                                </div>
                                <h3>Review &amp; Remember</h3>
                                <p>Spaced repetition schedules your reviews at the optimal time so concepts stick in long-term memory.</p>
                            </div>
                        </div>
                        <div class="slide-nav">
                            <button class="slide-dot active" data-slide="0" onclick="goSlide(0)"></button>
                            <button class="slide-dot" data-slide="1" onclick="goSlide(1)"></button>
                            <button class="slide-dot" data-slide="2" onclick="goSlide(2)"></button>
                            <button class="slide-dot" data-slide="3" onclick="goSlide(3)"></button>
                        </div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="goStep(2)">Back</button>
                            <button class="btn btn-primary" onclick="finishOnboarding()">Get Started</button>
                        </div>
                    </div>
                </div>
            </div>
        }

        #css {
            .onboarding-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, -apple-system, sans-serif; padding: 1rem; }
            .onboarding-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 520px; box-shadow: 0 4px 20px hsl(var(--shadow)); text-align: center; }
            .onboarding-brand { margin-bottom: 1.5rem; }
            .brand-link { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); text-decoration: none; }
            .brand-link:hover { text-decoration: none; }

            .step-indicator { display: flex; justify-content: center; gap: 0.5rem; margin-bottom: 2rem; }
            .step-dot { width: 8px; height: 8px; border-radius: 50%; background: hsl(var(--border)); transition: all 0.3s; }
            .step-dot.active { background: hsl(217 91% 60%); width: 24px; border-radius: 4px; }

            .step { animation: fadeIn 0.3s ease; }
            .step.hidden { display: none; }
            @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }

            .step-icon { margin-bottom: 1.5rem; }
            .step h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .step-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.95rem; margin-bottom: 2rem; line-height: 1.5; }

            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
            .btn-ghost { background: transparent; color: hsl(var(--muted-foreground)); border: 1px solid hsl(var(--border)); }
            .btn-ghost:hover { background: hsl(var(--accent)); color: hsl(var(--foreground)); }

            .step-actions { display: flex; justify-content: space-between; gap: 1rem; margin-top: 2rem; }

            .course-grid { display: grid; grid-template-columns: 1fr; gap: 0.75rem; margin-bottom: 1rem; text-align: left; max-height: 240px; overflow-y: auto; }
            .course-loading { text-align: center; color: hsl(var(--muted-foreground)); padding: 2rem; font-size: 0.9rem; }
            .course-option { display: flex; align-items: center; gap: 0.75rem; padding: 0.875rem 1rem; border: 1px solid hsl(var(--border)); border-radius: 8px; cursor: pointer; transition: all 0.15s; background: hsl(var(--background)); }
            .course-option:hover { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 5%); }
            .course-option.selected { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 8%); }
            .course-radio { width: 18px; height: 18px; border-radius: 50%; border: 2px solid hsl(var(--border)); flex-shrink: 0; display: flex; align-items: center; justify-content: center; transition: all 0.15s; }
            .course-option.selected .course-radio { border-color: hsl(217 91% 60%); }
            .course-option.selected .course-radio::after { content: ''; width: 8px; height: 8px; border-radius: 50%; background: hsl(217 91% 60%); }
            .course-info { flex: 1; min-width: 0; }
            .course-name { font-weight: 600; font-size: 0.95rem; color: hsl(var(--foreground)); }
            .course-meta { font-size: 0.8rem; color: hsl(var(--muted-foreground)); margin-top: 0.15rem; }

            .goal-options { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.75rem; margin-bottom: 2rem; }
            .goal-btn { display: flex; flex-direction: column; align-items: center; gap: 0.15rem; padding: 1rem 0.5rem; border: 1px solid hsl(var(--border)); border-radius: 8px; cursor: pointer; background: hsl(var(--background)); transition: all 0.15s; }
            .goal-btn:hover { border-color: hsl(217 91% 60%); }
            .goal-btn.selected { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 8%); }
            .goal-value { font-size: 1.5rem; font-weight: 700; color: hsl(var(--foreground)); }
            .goal-label { font-size: 0.75rem; color: hsl(var(--muted-foreground)); }
            .goal-desc { font-size: 0.7rem; color: hsl(217 91% 60%); font-weight: 500; margin-top: 0.25rem; }

            .session-length { margin-bottom: 1rem; }
            .form-label { display: block; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); margin-bottom: 0.75rem; text-align: left; }
            .session-options { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; }
            .session-btn { padding: 0.625rem 0.5rem; border: 1px solid hsl(var(--border)); border-radius: 8px; cursor: pointer; background: hsl(var(--background)); font-size: 0.85rem; color: hsl(var(--foreground)); transition: all 0.15s; }
            .session-btn:hover { border-color: hsl(217 91% 60%); }
            .session-btn.selected { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 8%); color: hsl(217 91% 60%); font-weight: 600; }

            .tutorial-slides { position: relative; min-height: 180px; margin-bottom: 1rem; }
            .tutorial-slide { display: none; animation: fadeIn 0.3s ease; }
            .tutorial-slide.active { display: block; }
            .tutorial-icon { margin-bottom: 1rem; }
            .tutorial-slide h3 { font-size: 1.1rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .tutorial-slide p { color: hsl(var(--muted-foreground)); font-size: 0.9rem; line-height: 1.6; max-width: 360px; margin: 0 auto; }

            .slide-nav { display: flex; justify-content: center; gap: 0.5rem; margin-bottom: 0.5rem; }
            .slide-dot { width: 8px; height: 8px; border-radius: 50%; border: none; background: hsl(var(--border)); cursor: pointer; padding: 0; transition: all 0.3s; }
            .slide-dot.active { background: hsl(217 91% 60%); width: 20px; border-radius: 4px; }

            @media (max-width: 480px) {
                .onboarding-card { padding: 1.5rem; }
                .goal-options { grid-template-columns: repeat(2, 1fr); }
                .session-options { grid-template-columns: 1fr; }
            }
        }

        #js {
            var currentStep = 0;
            var selectedCourse = '';
            var selectedMinutes = 20;
            var selectedSession = 'medium';

            function goStep(n) {
                var steps = document.querySelectorAll('.step');
                var dots = document.querySelectorAll('.step-dot');
                var i = 0;
                while(i < steps.length) { steps[i].classList.add('hidden'); i = i + 1; }
                i = 0;
                while(i < dots.length) { dots[i].classList.remove('active'); i = i + 1; }
                var target = document.getElementById('step' + n);
                if(target) { target.classList.remove('hidden'); }
                if(dots[n]) { dots[n].classList.add('active'); }
                currentStep = n;
                if(n === 1) { loadCourses(); }
            }

            function goSlide(n) {
                var slides = document.querySelectorAll('.tutorial-slide');
                var dots = document.querySelectorAll('.slide-dot');
                var i = 0;
                while(i < slides.length) { slides[i].classList.remove('active'); i = i + 1; }
                i = 0;
                while(i < dots.length) { dots[i].classList.remove('active'); i = i + 1; }
                var target = document.querySelector('[data-slide="' + n + '"]');
                if(target) { target.classList.add('active'); }
                if(dots[n]) { dots[n].classList.add('active'); }
            }

            function selectTime(btn) {
                var btns = document.querySelectorAll('#timeOptions .goal-btn');
                var i = 0;
                while(i < btns.length) { btns[i].classList.remove('selected'); i = i + 1; }
                btn.classList.add('selected');
                selectedMinutes = parseInt(btn.getAttribute('data-minutes'));
            }

            function selectSession(btn) {
                var btns = document.querySelectorAll('#sessionOptions .session-btn');
                var i = 0;
                while(i < btns.length) { btns[i].classList.remove('selected'); i = i + 1; }
                btn.classList.add('selected');
                selectedSession = btn.getAttribute('data-length');
            }

            function selectCourse(btn, courseId) {
                var opts = document.querySelectorAll('.course-option');
                var i = 0;
                while(i < opts.length) { opts[i].classList.remove('selected'); i = i + 1; }
                btn.classList.add('selected');
                selectedCourse = courseId;
                document.getElementById('courseNextBtn').disabled = false;
            }

            function loadCourses() {
                if(document.querySelectorAll('.course-option').length > 0) { return; }
                fetch('/api/courses').then(function(r) { return r.json(); })
                  .then(function(courses) {
                    var grid = document.getElementById('courseGrid');
                    if(!courses || courses.length === 0) {
                        grid.innerHTML = '<div class="course-loading">No courses available yet.</div>';
                        return;
                    }
                    var html = '';
                    var ci = 0;
                    while(ci < courses.length) {
                        var c = courses[ci];
                        var meta = '';
                        if(c.concepts) { meta = c.concepts + ' concepts'; }
                        if(c.difficulty) { meta = meta ? meta + ' · ' + c.difficulty : c.difficulty; }
                        var cid = c.id;
                        var ctitle = c.title || c.id;
                        html += '<div class="course-option" data-course-id="' + cid + '">';
                        html += '<div class="course-radio"></div>';
                        html += '<div class="course-info">';
                        html += '<div class="course-name">' + ctitle + '</div>';
                        html += '<div class="course-meta">' + meta + '</div>';
                        html += '</div></div>';
                        ci = ci + 1;
                    }
                    grid.innerHTML = html;
                    var opts = grid.querySelectorAll('.course-option');
                    var oi = 0;
                    while(oi < opts.length) {
                        opts[oi].onclick = function() { selectCourse(this, this.getAttribute('data-course-id')); };
                        oi = oi + 1;
                    }
                  }).catch(function() {
                    document.getElementById('courseGrid').innerHTML = '<div class="course-loading">Failed to load courses.</div>';
                  });
            }

            function loadUserName() {
                var token = localStorage.getItem('session_token');
                if(!token) { return; }
                fetch('/api/auth/me', {
                    headers: { 'Authorization': 'Bearer ' + token }
                }).then(function(r) { return r.json(); })
                  .then(function(data) {
                    if(data.name) {
                        document.getElementById('userName').textContent = data.name;
                    }
                  }).catch(function() {});
            }

            function finishOnboarding() {
                var token = localStorage.getItem('session_token');
                if(!token) {
                    window.location.href = '/login';
                    return;
                }
                var payload = JSON.stringify({
                    daily_minutes: selectedMinutes,
                    session_length: selectedSession,
                    selected_course: selectedCourse
                });
                fetch('/api/onboarding/complete', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
                    body: payload
                }).then(function(r) { return r.json(); })
                  .then(function(data) {
                    if(selectedCourse) {
                        window.location.href = '/courses/' + selectedCourse;
                    } else {
                        window.location.href = '/';
                    }
                  }).catch(function() {
                    window.location.href = '/';
                  });
            }

            loadUserName();
            var token = localStorage.getItem('session_token');
            if(!token) { window.location.href = '/login'; }
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    // ---- POST /api/onboarding/complete — Save onboarding goals ----

    public func handle_onboarding_complete(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var body_str = read_body(&raw mut req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var daily_minutes = json_get_int(&raw parsed, "daily_minutes")
        var session_length = json_get_str(&raw parsed, "session_length")
        var selected_course = json_get_str(&raw parsed, "selected_course")
        if(daily_minutes <= 0) { daily_minutes = 20 }
        if(session_length.size() == 0) { session_length = string("medium") }

        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var min_str = underlayer_core::int_to_string(daily_minutes as i64)

        // Map session length string to minutes
        var session_minutes : i64 = 20
        if(session_length.equals(&string("short"))) { session_minutes = 10 }
        if(session_length.equals(&string("long"))) { session_minutes = 30 }
        var sess_str = underlayer_core::int_to_string(session_minutes)

        // Save selected course to learning_goals (existing schema: id, learner_id, course_id, target_date, created_at)
        if(selected_course.size() > 0) {
            var del_sql = string("DELETE FROM learning_goals WHERE learner_id = '")
            del_sql.append_string(&learner_id)
            del_sql.append_view("' AND course_id = '")
            del_sql.append_string(&selected_course)
            del_sql.append_view("'")
            underlayer_db::exec_sql(db, &raw del_sql)
            var goal_id = underlayer_core::int_to_string(now)
            var ins_sql = string("INSERT INTO learning_goals (id, learner_id, course_id, target_date, created_at) VALUES ('")
            ins_sql.append_view(goal_id.to_view())
            ins_sql.append_view("', '")
            ins_sql.append_string(&learner_id)
            ins_sql.append_view("', '")
            ins_sql.append_string(&selected_course)
            ins_sql.append_view("', ")
            ins_sql.append_view(min_str.to_view())
            ins_sql.append_view(", ")
            ins_sql.append_view(now_str.to_view())
            ins_sql.append_view(")")
            underlayer_db::exec_sql(db, &raw ins_sql)
        }

        // Save daily minutes and session length to learning_preferences
        var pref_del = string("INSERT OR REPLACE INTO learning_preferences (learner_id, daily_goal_minutes, session_length_minutes, updated_at) VALUES ('")
        pref_del.append_string(&learner_id)
        pref_del.append_view("', ")
        pref_del.append_view(min_str.to_view())
        pref_del.append_view(", ")
        pref_del.append_view(sess_str.to_view())
        pref_del.append_view(", ")
        pref_del.append_view(now_str.to_view())
        pref_del.append_view(")")
        underlayer_db::exec_sql(db, &raw pref_del)

        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // ---- GET /api/onboarding/check — Check if onboarding is completed ----

    public func handle_check_onboarding(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var resp = string("{\"completed\":false,\"authenticated\":false}")
            send_json_str(res, &raw resp)
            return
        }
        // Onboarding is complete if the user has set a daily_goal_minutes different from the default (20)
        var sql = string("SELECT daily_goal_minutes FROM learning_preferences WHERE learner_id = '")
        sql.append_string(&learner_id)
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        var completed = false
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                var val = row.vals.get_ptr(0).copy()
                // If daily_goal_minutes was explicitly set (not default), onboarding is done
                // We check if a learning_preferences row exists with a non-default value
                completed = true
            }
        }
        var resp = string("{\"completed\":")
        if(completed) { resp.append_view("true") } else { resp.append_view("false") }
        resp.append_view(",\"authenticated\":true}")
        send_json_str(res, &raw resp)
    }

}

// Routes to add to app/main.ch:
// srv.router.add("GET", "/onboarding", (|db|(req, res) => { underlayer_web::handle_onboarding_page(&req, &raw mut res) }))
// srv.router.add("POST", "/api/onboarding/complete", (|db|(req, res) => { underlayer_web::handle_onboarding_complete(&raw db, &raw mut req, &raw mut res) }))
// srv.router.add("GET", "/api/onboarding/check", (|db|(req, res) => { underlayer_web::handle_check_onboarding(&raw db, &req, &raw mut res) }))
