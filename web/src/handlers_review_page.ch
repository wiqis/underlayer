// underlayer_web — Review session page (HTML UI).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_review_page(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Review — Underlayer"))

        #html {
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <button class="hamburger" onclick="document.querySelector('.nav-links').classList.toggle('open')" aria-label="Toggle menu">
                        <span class="hamburger-line"></span>
                        <span class="hamburger-line"></span>
                        <span class="hamburger-line"></span>
                    </button>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link active">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                    </div>
                    <div class="nav-right">
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">☀️</span>
                            <span class="theme-icon-dark">🌙</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="container">
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
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; gap: 1.5rem; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .hamburger { display: none; background: none; border: none; cursor: pointer; padding: 0.5rem; }
            .hamburger-line { display: block; width: 24px; height: 2px; background: hsl(var(--foreground)); margin: 4px 0; transition: all 0.3s; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
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
            .mode-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 1rem; }
            .mode-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; cursor: pointer; transition: all 0.15s; }
            .mode-card:hover { border-color: hsl(217 91% 60%); box-shadow: 0 2px 8px hsl(217 91% 60% / 20%); }
            .mode-card h3 { font-size: 1rem; margin-bottom: 0.35rem; color: hsl(var(--foreground)); }
            .mode-card p { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin: 0; }
            @media (max-width: 768px) {
                .nav-links { display: none; position: absolute; top: 100%; left: 0; right: 0; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); flex-direction: column; padding: 1rem; gap: 0.5rem; }
                .nav-links.open { display: flex; }
                .nav-link { padding: 0.75rem 1rem; }
                .hamburger { display: block; }
                .container { padding: 1rem; }
                .review-status-bar { flex-direction: column; gap: 1rem; }
                .review-card { padding: 2rem 1rem; min-height: 200px; }
                .card-prompt { font-size: 1.1rem; }
                .mode-grid { grid-template-columns: 1fr; }
            }
        }

        #js {
            function getTheme() {
                var saved = localStorage.getItem('theme');
                if (saved) return saved;
                return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            }
            function setTheme(theme) {
                document.documentElement.classList.toggle('dark', theme === 'dark');
                localStorage.setItem('theme', theme);
            }
            function toggleTheme() {
                var current = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
                setTheme(current === 'dark' ? 'light' : 'dark');
            }
            setTheme(getTheme());

            var currentIndex = 0;
            var totalDue = 0;
            var reviewed = 0;
            var currentConceptId = "";
            var sessionActive = false;
            var dueItems = [];

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

            window.addEventListener("DOMContentLoaded", function() {
                fetchDueItems();
            });

            function fetchDueItems() {
                fetch("/api/review/due?course_id=elf&limit=50")
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
                updateStats();
                loadNextCard();
            }

            function startMode(mode) {
                window.location.href = "/api/review/start?course_id=elf&mode=" + mode + "&count=10";
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
                currentConceptId = item.concept_id;
                document.getElementById("card-concept").textContent = displayName(currentConceptId);
                document.getElementById("card-prompt").textContent = "Think about what you know about this concept, then rate your recall.";
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
                fetch("/api/review/submit", {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({concept_id: currentConceptId, rating: rating, course_id: "elf", time_spent: 5})
                })
                .then(function(r) { return r.json(); })
                .then(function(data) {
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

            function showComplete() {
                document.getElementById("card-prompt").textContent = "Review session complete! You reviewed " + reviewed + " concepts. Great work!";
                document.getElementById("card-concept").textContent = "All Done";
                var actions = document.getElementById("review-actions");
                actions.innerHTML = '<a href="/dashboard" class="btn btn-primary btn-large">Back to Dashboard</a>';
            }

            function updateStats() {
                document.getElementById("reviewed-count").textContent = reviewed;
                var remaining = totalDue - currentIndex;
                if(remaining < 0) { remaining = 0; }
                document.getElementById("remaining-count").textContent = remaining;
            }
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
