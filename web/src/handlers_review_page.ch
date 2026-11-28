// underlayer_web — Review session page (HTML UI).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_review_page(db : *DbClient, courses_dir : &string, req : &http::Request) : http::Response {
        // THE SIGN-IN GATE.  Every number on this page is read from
        // the signed-in learner's own rows, so with no account there
        // is nothing to show and the page rendered zeros -- which reads
        // as failure rather than as "you are not signed in".  Checked
        // before any query; see pages_auth_gate.ch for why this is a
        // page rather than a redirect.
        if(!has_session(db, req)) {
            // Redirect, not an in-place card: see pages_auth_gate.ch for why this

            // changed, and for why it cannot loop.

            var gate_path = string("/review")
            return redirect_to_login(&gate_path)
        }
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Review — Underlayer"))
        // The shared session helper: __ulFetch (one 401 policy), __ulCourseId
        // (which course this review is about), __ulHeaders.  This page's own
        // script used to carry three private copies of the bearer-header logic.
        render_session_js(&mut page)

        #html {
            {render_nav_bar(&mut page)}

            <div class="container" id="main-content">
                <div class="review-header">
                    <h1>Review Session</h1>
                    <p class="subtitle">Spaced repetition keeps your knowledge fresh</p>
                </div>

                <div class="review-status-bar">
                    <div class="stat">
                        <span class="stat-label">Due</span>
                        <span class="stat-value" id="due-count">-</span>
                    </div>
                    <div class="stat">
                        <span class="stat-label">Reviewed</span>
                        <span class="stat-value" id="reviewed-count">0</span>
                    </div>
                    <div class="stat">
                        <span class="stat-label">Remaining</span>
                        <span class="stat-value" id="remaining-count">-</span>
                    </div>
                </div>

                <div id="review-card-container" class="review-card-container">
                    <div id="review-card" class="review-card">
                        <div class="card-front" id="card-front">
                            <div class="card-concept-label" id="card-concept">Select a concept to review</div>
                            <div class="card-prompt" id="card-prompt">Click "Start Review" to begin reviewing your due concepts.</div>
                        </div>
                    </div>
                </div>

                <div class="review-actions" id="review-actions">
                    <button class="btn btn-primary btn-large" id="btn-start" onclick="startReview()">Start Review</button>
                </div>

                <div class="session-controls hidden" id="session-controls" aria-label="Session controls">
                    <button class="btn btn-control" id="btn-pause" onclick="pauseSession()">Pause</button>
                    <button class="btn btn-control hidden" id="btn-resume" onclick="resumeSession()">Resume</button>
                    <button class="btn btn-control" id="btn-undo" onclick="undoItem()">Undo</button>
                    <button class="btn btn-control" id="btn-skip" onclick="skipItem()">Skip</button>
                    <button class="btn btn-control btn-control-danger" id="btn-abort" onclick="abortSession()">Abort</button>
                    <span class="session-state" id="session-state">Active</span>
                </div>

                <div class="energy-checkin" id="energy-checkin" aria-label="Session check-in">
                    <h2>Before you start</h2>
                    <p class="energy-subtitle">How are you feeling? This only changes the pace we suggest.</p>
                    <div class="energy-options" role="group" aria-label="Energy level">
                        <button class="energy-btn selected" data-energy="ready" onclick="rvPickEnergy(this)" type="button">Ready to learn</button>
                        <button class="energy-btn" data-energy="okay" onclick="rvPickEnergy(this)" type="button">Okay, let's go</button>
                        <button class="energy-btn" data-energy="low-energy" onclick="rvPickEnergy(this)" type="button">Low energy, keep it light</button>
                    </div>
                    <div class="energy-options" role="group" aria-label="Session duration">
                        <button class="energy-btn" data-minutes="5" onclick="rvPickMinutes(this)" type="button">5 min</button>
                        <button class="energy-btn selected" data-minutes="10" onclick="rvPickMinutes(this)" type="button">10 min</button>
                        <button class="energy-btn" data-minutes="20" onclick="rvPickMinutes(this)" type="button">20 min</button>
                    </div>
                </div>

                <div class="review-mode-grid">
                    <h2>Review Modes</h2>
                    <div class="mode-grid">
                        <div class="mode-card" onclick="startMode('due')">
                            <h3>Due Review</h3>
                            <p>Review concepts scheduled for today. The standard spaced repetition loop.</p>
                        </div>
                        <div class="mode-card" onclick="startMode('new')">
                            <h3>Learn New</h3>
                            <p>Study concepts you haven't seen yet. Build your initial knowledge.</p>
                        </div>
                        <div class="mode-card" onclick="startMode('cram')">
                            <h3>Cram Mode</h3>
                            <p>Review all concepts regardless of schedule. Good before an exam.</p>
                        </div>
                        <div class="mode-card" onclick="startMode('lightning')">
                            <h3>Lightning Round</h3>
                            <p>Quick-fire 5-minute sessions. Perfect for a coffee break.</p>
                        </div>
                        <div class="mode-card" onclick="startMode('weakness')">
                            <h3>Weakness Focus</h3>
                            <p>Target your weakest concepts. Build strength where you need it most.</p>
                        </div>
                        <div class="mode-card" onclick="startMode('deep')">
                            <h3>Deep Dive</h3>
                            <p>Extended session with detailed feedback and explanations.</p>
                        </div>
                    </div>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }

            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }

            .container { max-width: 900px; margin: 0 auto; padding: 2rem; }
            .review-header { text-align: center; margin-bottom: 2rem; }
            .review-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); }
            .review-status-bar { display: flex; justify-content: center; gap: 3rem; margin-bottom: 2rem; padding: 1rem; background: hsl(var(--card)); border-radius: 12px; border: 1px solid hsl(var(--border)); }
            .stat { text-align: center; }
            .stat-label { display: block; font-size: 0.8rem; color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.05em; }
            .stat-value { display: block; font-size: 1.5rem; font-weight: 700; color: hsl(var(--foreground)); }
            .review-card-container { perspective: 1000px; margin-bottom: 2rem; }
            .review-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 16px; padding: 3rem 2rem; min-height: 250px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; box-shadow: 0 2px 8px hsl(var(--shadow)); }
            .card-concept-label { font-size: 0.85rem; color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 1rem; }
            .card-prompt { font-size: 1.25rem; color: hsl(var(--foreground)); line-height: 1.6; max-width: 500px; }
            .review-actions { display: flex; justify-content: center; gap: 1rem; margin-bottom: 3rem; flex-wrap: wrap; }
            .session-controls { display: flex; justify-content: center; align-items: center; gap: 0.5rem; margin: -1.5rem 0 2.5rem; flex-wrap: wrap; }
            .btn-control { background: hsl(var(--card)); color: hsl(var(--foreground)); border: 1px solid hsl(var(--border)); font-size: 0.85rem; padding: 0.5rem 1rem; }
            .btn-control:hover { background: hsl(var(--accent)); }
            .btn-control-danger { color: hsl(0 84% 45%); border-color: hsl(0 84% 60% / 40%); }
            .btn-control-danger:hover { background: hsl(0 84% 60% / 10%); }
            .session-state { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; color: hsl(var(--muted-foreground)); margin-left: 0.5rem; }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 10px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-large { padding: 1rem 2rem; font-size: 1.1rem; }
            .btn-again { background: hsl(0 84% 60%); color: white; }
            .btn-again:hover { background: hsl(0 84% 50%); }
            .btn-hard { background: hsl(38 92% 50%); color: white; }
            .btn-hard:hover { background: hsl(38 92% 40%); }
            .btn-good { background: hsl(142 76% 36%); color: white; }
            .btn-good:hover { background: hsl(142 76% 30%); }
            .btn-easy { background: hsl(245 58% 51%); color: white; }
            .btn-easy:hover { background: hsl(245 58% 45%); }
            .hidden { display: none !important; }
            .review-mode-grid h2 { font-size: 1.25rem; margin-bottom: 1rem; color: hsl(var(--foreground)); }
            .energy-checkin { border: 1px solid hsl(var(--border)); border-radius: 12px; background: hsl(var(--card)); padding: 1.25rem; margin-bottom: 2rem; }
            .energy-checkin h2 { font-size: 1.25rem; margin: 0 0 0.35rem; color: hsl(var(--foreground)); }
            .energy-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0 0 1rem; }
            .energy-options { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.6rem; }
            .energy-btn { padding: 0.55rem 0.9rem; border-radius: 8px; border: 1px solid hsl(var(--border)); background: hsl(var(--background)); color: hsl(var(--foreground)); cursor: pointer; font-size: 0.85rem; }
            .energy-btn.selected { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 8%); }
            .energy-break { border: 1px solid hsl(var(--border)); border-radius: 12px; background: hsl(var(--card)); padding: 1.25rem; margin-bottom: 1.5rem; text-align: center; }
            .energy-break p { color: hsl(var(--muted-foreground)); }
            .mode-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1rem; }
            .mode-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; cursor: pointer; transition: all 0.15s; }
            .mode-card:hover { border-color: hsl(217 91% 60%); box-shadow: 0 2px 8px hsl(217 91% 60% / 20%); }
            .mode-card h3 { font-size: 1rem; margin-bottom: 0.35rem; color: hsl(var(--foreground)); }
            .mode-card p { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin: 0; }
            @media (max-width: 768px) {
                .container { padding: 1rem; }
                .review-status-bar { flex-direction: column; gap: 1rem; }
                .review-card { padding: 2rem 1rem; min-height: 200px; }
                .card-prompt { font-size: 1.1rem; }
                .mode-grid { grid-template-columns: 1fr; }
            }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
            .back-to-top.visible { opacity: 1; pointer-events: auto; }
            .back-to-top:hover { background: #111827; }
        }

        #js {

            var currentIndex = 0;
            var totalDue = 0;
            var reviewed = 0;
            var currentConceptId = "";
            var sessionActive = false;
            var dueItems = [];
            var sessionId = "";
            var currentMode = "due";
            var sessionStartTime = 0;
            var sessionPaused = false;

            function setSessionState(state) {
                var el = document.getElementById("session-state");
                if(el) { el.textContent = state; }
            }

            function showSessionControls(show) {
                var el = document.getElementById("session-controls");
                if(!el) { return; }
                if(show) { el.classList.remove("hidden"); } else { el.classList.add("hidden"); }
            }

            function displayName(id) {
                var result = "";
                for(var i = 0; i < id.length; i++) {
                    var ch = id.charAt(i);
                    if(ch === "-") {
                        result = result + " ";
                    } else if(i === 0) {
                        result = result + ch.toUpperCase();
                    } else if(id.charAt(i - 1) === "-") {
                        result = result + ch.toUpperCase();
                    } else {
                        result = result + ch;
                    }
                }
                return result;
            }

            // G4: the check-in is a choice, not a timer. These two values are
            // sent with /api/review/start and drive the break threshold.
            var rvEnergy = 'ready';
            var rvMinutes = 10;
            var rvStartedAt = 0;
            var rvBreakShown = false;
            function rvPickEnergy(btn) {
                var kids = btn.parentNode.querySelectorAll('.energy-btn');
                var i = 0;
                while (i < kids.length) { kids[i].classList.remove('selected'); i = i + 1; }
                btn.classList.add('selected');
                rvEnergy = btn.getAttribute('data-energy');
            }
            function rvPickMinutes(btn) {
                var kids = btn.parentNode.querySelectorAll('.energy-btn');
                var i = 0;
                while (i < kids.length) { kids[i].classList.remove('selected'); i = i + 1; }
                btn.classList.add('selected');
                rvMinutes = parseInt(btn.getAttribute('data-minutes'), 10);
            }
            function rvCheckBreak() {
                if (rvBreakShown || !rvStartedAt) { return; }
                var threshold = rvMinutes * 48 * 1000;
                if (Date.now() - rvStartedAt < threshold) { return; }
                rvBreakShown = true;
                var box = document.createElement('div');
                box.className = 'energy-break';
                box.setAttribute('role', 'status');
                var h = document.createElement('h3');
                h.textContent = 'Take a break — progress saved';
                var p = document.createElement('p');
                p.textContent = 'You can stop here. What you have done is saved, and you can pick up the same step later.';
                var b = document.createElement('button');
                b.type = 'button';
                b.className = 'btn btn-ghost';
                b.textContent = 'Continue anyway';
                b.onclick = function() { box.remove(); };
                box.appendChild(h); box.appendChild(p); box.appendChild(b);
                var card = document.getElementById('review-card-container');
                if (card && card.parentNode) { card.parentNode.insertBefore(box, card); }
            }
            function rvEnergyAfter() {
                if (!sessionId) { return; }
                __ulFetch('/api/review/energy', {
                    method: 'POST', silent401: true,
                    json: { session_id: sessionId, energy_after: rvEnergy }
                }).catch(function() {});
            }
            window.addEventListener('DOMContentLoaded', function() {
                fetchDueItems();
                window.setInterval(rvCheckBreak, 5000);
            });

            // THE BEARER HEADER IS NOT BUILT HERE ANY MORE.  This page had three
            // helpers of its own -- bearerValue(), authHeaders() and
            // jsonAuthHeaders() -- each reading localStorage separately, and
            // the first of them sent the literal string "Bearer " with an empty
            // token when signed out.  All three now live once in session_js.ch
            // as __ulFetch, which also does the one thing none of the three
            // did: on a 401 it drops the dead token and sends the learner to
            // /login with a `next` back to this page.
            //
            // The reason that mattered HERE specifically is already written
            // below -- showAuthRequired() was the manual 401 answer for four
            // call sites, and the two fetches below that used fetch() directly
            // had no 401 branch at all.  One wrapper, one 401 policy, and the
            // policy is visible at the call site.
            //
            // showAuthRequired() is kept, and is still called: __ulFetch
            // navigates away on a 401, but this page also renders its own
            // message for the case where navigation is not wanted.
            function showAuthRequired() {
                var concept = document.getElementById("card-concept");
                var prompt = document.getElementById("card-prompt");
                if(concept) { concept.textContent = "Sign in required"; }
                if(prompt) { prompt.textContent = "Please log in to start a review session. Your progress is saved to your account."; }
                var actions = document.getElementById("review-actions");
                if(actions) {
                    actions.innerHTML = '<a href="/login?next=' + encodeURIComponent(window.location.pathname) + '" class="btn btn-primary btn-large">Log in</a>';
                }
            }

            function fetchDueItems() {
                // course_id=elf WAS HARDCODED HERE, and this is the page where it
                // cost the most.  A learner enrolled in RISC-V who opened /review
                // was shown RISC-V's due count on the left and could only start
                // an ELF session -- the Start button called startMode() with a
                // hardcoded course too, so every rating they submitted was
                // recorded against ELF.  __ulCourseId() reads the real one.
                __ulFetch('/api/review/due?course_id=' + encodeURIComponent(__ulCourseId()) + '&limit=50', { silent401: true })
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        dueItems = data || [];
                        totalDue = dueItems.length;
                        document.getElementById("due-count").textContent = totalDue;
                        document.getElementById("remaining-count").textContent = totalDue;
                    })
                    .catch(function() {
                        dueItems = [];
                        totalDue = 0;
                    });
            }

            function startReview() {
                if(dueItems.length === 0) {
                    document.getElementById("card-prompt").textContent = "No concepts due for review. Come back later or try a different review mode.";
                    return;
                }
                sessionActive = true;
                currentIndex = 0;
                reviewed = 0;
                showSessionControls(true);
                setSessionState("Active");
                updateStats();
                loadNextCard();
            }

            function startMode(mode) {
                currentMode = mode;
                var prompt = document.getElementById("card-prompt");
                var concept = document.getElementById("card-concept");
                concept.textContent = "Starting session";
                prompt.textContent = "Loading your " + mode + " review session...";
                __ulFetch('/api/review/start?course_id=' + encodeURIComponent(__ulCourseId()) + '&mode=' + encodeURIComponent(mode) + '&count=10', {
                    method: 'POST',
                    silent401: true,
                    json: { course_id: __ulCourseId(), mode: mode, energy_before: rvEnergy, duration_minutes: rvMinutes }
                })
                    .then(function(r) {
                        return r.json();
                    })
                    .then(function(data) {
                        if(!data) { return; }
                        if(!data.items || data.items.length === 0) {
                            concept.textContent = "Nothing to review";
                            prompt.textContent = "No items available for the " + mode + " mode right now. Try another mode.";
                            return;
                        }
                        sessionId = data.session_id || "";
                        sessionStartTime = Date.now();
                        rvStartedAt = Date.now();
                        rvBreakShown = false;
                        dueItems = data.items;
                        totalDue = dueItems.length;
                        reviewed = 0;
                        currentIndex = 0;
                        sessionActive = true;
                        document.getElementById("due-count").textContent = totalDue;
                        showSessionControls(true);
                        setSessionState("Active");
                        updateStats();
                        loadNextCard();
                    })
                    .catch(function() {
                        concept.textContent = "Could not start";
                        prompt.textContent = "We could not start the session. Please refresh and try again.";
                    });
            }

            function loadNextCard() {
                if(currentIndex >= dueItems.length) {
                    showComplete();
                    return;
                }
                var item = dueItems[currentIndex];
                if(!item) {
                    showComplete();
                    return;
                }
                // /api/review/due uses "concept_id"; /api/review/start uses "concept".
                currentConceptId = item.concept_id || item.concept || "";
                document.getElementById("card-concept").textContent = displayName(currentConceptId);
                if(item.front) {
                    document.getElementById("card-prompt").textContent = item.front;
                } else {
                    document.getElementById("card-prompt").textContent = "Think about what you know about this concept, then rate your recall.";
                }
                document.getElementById("card-front").classList.remove("hidden");
                showRatingButtons();
            }

            function showRatingButtons() {
                var actions = document.getElementById("review-actions");
                actions.innerHTML = "";
                var btnAgain = document.createElement("button");
                btnAgain.className = "btn btn-again btn-large";
                btnAgain.textContent = "Again";
                btnAgain.onclick = function() { rateItem(1); };
                var btnHard = document.createElement("button");
                btnHard.className = "btn btn-hard btn-large";
                btnHard.textContent = "Hard";
                btnHard.onclick = function() { rateItem(2); };
                var btnGood = document.createElement("button");
                btnGood.className = "btn btn-good btn-large";
                btnGood.textContent = "Good";
                btnGood.onclick = function() { rateItem(3); };
                var btnEasy = document.createElement("button");
                btnEasy.className = "btn btn-easy btn-large";
                btnEasy.textContent = "Easy";
                btnEasy.onclick = function() { rateItem(4); };
                actions.appendChild(btnAgain);
                actions.appendChild(btnHard);
                actions.appendChild(btnGood);
                actions.appendChild(btnEasy);
            }

            function rateItem(rating) {
                var elapsed = 5;
                if(sessionStartTime > 0) {
                    elapsed = Math.round((Date.now() - sessionStartTime) / 1000);
                    if(elapsed < 0) { elapsed = 0; }
                }
                // course_id: "elf" WAS HARDCODED IN THIS BODY, so every rating a learner
                // gave on any course was recorded against ELF's schedule.  A
                // rating is the one input FSRS consumes; writing it under the
                // wrong concept id makes the whole spaced-repetition model train
                // on the wrong material, silently, forever.
                __ulFetch("/api/review/submit", {
                    method: "POST",
                    json: {concept_id: currentConceptId, rating: rating, course_id: __ulCourseId(), session_id: sessionId, time_spent: elapsed}
                })
                .then(function(r) {
                    return r.json();
                })
                .then(function(data) {
                    if(!data) { return; }
                    sessionStartTime = Date.now();
                    reviewed++;
                    currentIndex++;
                    updateStats();
                    var prompt = document.getElementById("card-prompt");
                    if(rating >= 3) {
                        prompt.textContent = "Nice! You remembered that correctly.";
                    } else {
                        prompt.textContent = "No worries - we will come back to this one soon.";
                    }
                    setTimeout(function() { loadNextCard(); }, 1200);
                })
                .catch(function(err) {
                    reviewed++;
                    currentIndex++;
                    updateStats();
                    loadNextCard();
                });
            }

            function endSession() {
                if(!sessionId) { return; }
                rvEnergyAfter();
                __ulFetch("/api/review/end?session_id=" + encodeURIComponent(sessionId), {
                    method: "POST",
                    noRedirect: true
                })
                .then(function(r) { return r.json(); })
                .catch(function() { /* best effort — the session is finished locally */ });
                sessionId = "";
                sessionActive = false;
            }

            function showComplete() {
                endSession();
                showSessionControls(false);
                document.getElementById("card-prompt").textContent = "Review session complete! You reviewed " + reviewed + " concepts. Great work!";
                document.getElementById("card-concept").textContent = "All Done";
                var actions = document.getElementById("review-actions");
                actions.innerHTML = '<a href="/dashboard" class="btn btn-primary btn-large">Back to Dashboard</a>';
            }

            // 5.1.18: session controls wired to /api/session/*.
            function sessionPost(path, extra) {
                if(!sessionId) { return Promise.resolve(null); }
                var url = path + "?session_id=" + encodeURIComponent(sessionId);
                if(extra) { url = url + extra; }
                // noRedirect BECAUSE ENDING A SESSION IS NOT AN AUTHORISATION PROBLEM.  If the
                // token has expired, the review already happened in this tab and
                // there is nothing to navigate to -- bouncing to /login mid-way
                // through ending a session loses the reader's place.  The 401 is
                // recorded and the local session is still closed.
                return __ulFetch(url, { method: "POST", noRedirect: true })
                    .then(function(r) { return r.json(); }).catch(function() { return null; });
            }

            function pauseSession() {
                sessionPost("/api/session/pause", "").then(function() {
                    sessionPaused = true;
                    var pauseBtn = document.getElementById("btn-pause");
                    var resumeBtn = document.getElementById("btn-resume");
                    if(pauseBtn) { pauseBtn.classList.add("hidden"); }
                    if(resumeBtn) { resumeBtn.classList.remove("hidden"); }
                    setSessionState("Paused");
                    document.getElementById("card-prompt").textContent = "Session paused. Resume when you are ready.";
                });
            }

            function resumeSession() {
                sessionPost("/api/session/resume", "").then(function() {
                    sessionPaused = false;
                    var pauseBtn = document.getElementById("btn-pause");
                    var resumeBtn = document.getElementById("btn-resume");
                    if(pauseBtn) { pauseBtn.classList.remove("hidden"); }
                    if(resumeBtn) { resumeBtn.classList.add("hidden"); }
                    setSessionState("Active");
                    loadNextCard();
                });
            }

            function undoItem() {
                if(reviewed <= 0 || currentIndex <= 0) { return; }
                sessionPost("/api/session/undo", "").then(function() {
                    reviewed--;
                    currentIndex--;
                    updateStats();
                    loadNextCard();
                });
            }

            function skipItem() {
                var item = dueItems[currentIndex];
                var concept = item ? (item.concept_id || item.concept || "") : "";
                var extra = concept ? "&concept_id=" + encodeURIComponent(concept) : "";
                sessionPost("/api/session/skip", extra).then(function() {
                    currentIndex++;
                    updateStats();
                    loadNextCard();
                });
            }

            function abortSession() {
                if(!sessionId) {
                    showComplete();
                    return;
                }
                sessionPost("/api/session/abort", "").then(function() {
                    sessionId = "";
                    sessionActive = false;
                    showSessionControls(false);
                    document.getElementById("card-concept").textContent = "Session aborted";
                    document.getElementById("card-prompt").textContent = "This session was aborted. No further items will be recorded.";
                    var actions = document.getElementById("review-actions");
                    actions.innerHTML = '<a href="/dashboard" class="btn btn-primary btn-large">Back to Dashboard</a>';
                });
            }

            function updateStats() {
                document.getElementById("reviewed-count").textContent = reviewed;
                var remaining = totalDue - currentIndex;
                if(remaining < 0) { remaining = 0; }
                document.getElementById("remaining-count").textContent = remaining;
            }

            (function() {
                var btn = document.getElementById('back-to-top');
                if(btn) {
                    window.addEventListener('scroll', function() {
                        if(window.scrollY > 300) { btn.classList.add('visible'); }
                        else { btn.classList.remove('visible'); }
                    });
                }
            })();
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        return underlayer_web::send_html(&html_out)
    }

}
