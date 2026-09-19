// underlayer_web — Study Planner page.
// Client-side rendered study plan list; data from /api/study-plans.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_study_plans_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Study Planner — Underlayer"))

        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                        <a href="/study-plans" class="nav-link">Planner</a>
                    </div>
                    <div class="nav-right">
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">&#9728;</span>
                            <span class="theme-icon-dark">&#9790;</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Study Planner</h1>
                    <p class="subtitle">Schedule focused study sessions and keep your momentum.</p>
                </div>

                <form class="plan-form" id="plan-form">
                    <h2 class="form-title">Plan a session</h2>
                    <div class="form-grid">
                        <div class="field"><label for="plan-date">Date</label><input type="date" id="plan-date" required></div>
                        <div class="field"><label for="plan-course">Course</label><select id="plan-course"><option value="elf">ELF Fundamentals</option></select></div>
                        <div class="field"><label for="plan-hour">Start hour (0-23)</label><input type="number" id="plan-hour" min="0" max="23" value="18"></div>
                        <div class="field"><label for="plan-duration">Duration (minutes)</label><input type="number" id="plan-duration" min="5" max="240" step="5" value="30"></div>
                        <div class="field field-wide"><label for="plan-focus">Focus concepts (optional)</label><input type="text" id="plan-focus" placeholder="e.g. elf-header, sections"></div>
                    </div>
                    <div class="form-actions">
                        <button type="submit" class="btn btn-primary" id="plan-submit">Add to planner</button>
                        <span class="form-status" id="plan-status" role="status"></span>
                    </div>
                </form>

                <div class="list-header">
                    <h2 class="list-title">Your planned sessions</h2>
                    <button type="button" class="btn btn-ghost" onclick="loadPlans()">Refresh</button>
                </div>

                <div id="plans-body" class="plans-body">
                    <p class="muted">Loading study plans...</p>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; } :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; } .nav-brand:hover { color: hsl(217 91% 60%); }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); } .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; } .dark .theme-icon-dark { display: inline; }
            .container { max-width: 800px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 1.5rem; } .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); margin: 0; }
            .plan-form { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem; margin-bottom: 2rem; }
            .form-title { font-size: 1.1rem; margin: 0 0 1rem 0; }
            .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
            .field { display: flex; flex-direction: column; gap: 0.35rem; } .field-wide { grid-column: 1 / -1; }
            .field label { font-size: 0.8rem; font-weight: 600; color: hsl(var(--muted-foreground)); }
            .field input, .field select { padding: 0.55rem 0.65rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--background)); color: hsl(var(--foreground)); font-size: 0.9rem; font-family: inherit; }
            .field input:focus, .field select:focus { outline: 2px solid hsl(217 91% 60%); outline-offset: 1px; }
            .form-actions { display: flex; align-items: center; gap: 1rem; margin-top: 1.25rem; flex-wrap: wrap; }
            .form-status { font-size: 0.85rem; color: hsl(142 76% 36%); } .form-status.error { color: hsl(0 72% 51%); }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.9rem; font-family: inherit; }
            .btn:disabled { opacity: 0.6; cursor: default; } .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover:enabled { background: hsl(217 91% 52%); } .btn-ghost { background: none; border: 1px solid hsl(var(--border)); color: hsl(var(--muted-foreground)); }
            .btn-ghost:hover { background: hsl(var(--accent)); color: hsl(var(--foreground)); }
            .btn-danger { background: hsl(0 72% 51%); color: white; padding: 0.45rem 0.9rem; font-size: 0.8rem; } .btn-danger:hover:enabled { background: hsl(0 72% 44%); }
            .list-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.75rem; } .list-title { font-size: 1.1rem; margin: 0; }
            .plans-body { display: flex; flex-direction: column; gap: 0.75rem; }
            .plan-row { display: flex; align-items: center; gap: 1rem; padding: 1rem 1.25rem; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(217 91% 60%); border-radius: 10px; }
            .plan-row.status-completed { border-left-color: hsl(142 76% 36%); } .plan-row.status-skipped { border-left-color: hsl(var(--muted)); opacity: 0.75; }
            .plan-info { flex: 1; min-width: 0; } .plan-date { font-weight: 600; font-size: 0.95rem; }
            .plan-meta { display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); margin-top: 0.2rem; }
            .badge { font-size: 0.72rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; padding: 0.2rem 0.6rem; border-radius: 999px; background: hsl(217 91% 60% / 12%); color: hsl(217 91% 45%); }
            .badge-completed { background: hsl(142 76% 36% / 14%); color: hsl(142 76% 30%); } .badge-skipped { background: hsl(var(--muted)); color: hsl(var(--muted-foreground)); }
            .empty-state { text-align: center; padding: 2.5rem 1rem; border: 1px dashed hsl(var(--border)); border-radius: 10px; color: hsl(var(--muted-foreground)); }
            .empty-state h3 { margin: 0 0 0.5rem 0; color: hsl(var(--foreground)); } .empty-state p { margin: 0; font-size: 0.9rem; }
            .muted { color: hsl(var(--muted-foreground)); }
            @media (max-width: 768px) { .nav-links { display: none; } .container { padding: 1rem; } .form-grid { grid-template-columns: 1fr; } .plan-row { flex-wrap: wrap; } }
        }

        #js {
            function getTheme() {
                var saved = localStorage.getItem("theme");
                if (saved) return saved;
                return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
            }
            function setTheme(theme) {
                document.documentElement.classList.toggle("dark", theme === "dark");
                localStorage.setItem("theme", theme);
            }
            function toggleTheme() {
                var current = document.documentElement.classList.contains("dark") ? "dark" : "light";
                setTheme(current === "dark" ? "light" : "dark");
            }
            setTheme(getTheme());
            var plansBody = document.getElementById("plans-body");
            function authHeaders(extra) {
                var headers = { "Authorization": "Bearer " + (localStorage.getItem("session_token") || "") };
                if (extra) { var keys = Object.keys(extra); var i = 0; while (i < keys.length) { headers[keys[i]] = extra[keys[i]]; i = i + 1; } }
                return headers;
            }
            function setStatus(msg, isError) {
                var el = document.getElementById("plan-status");
                if (!el) return;
                el.textContent = msg;
                el.className = isError ? "form-status error" : "form-status";
            }
            function formatDate(iso) {
                if (!iso) return "No date set";
                var parts = iso.split("-");
                if (parts.length !== 3) return iso;
                var date = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                if (isNaN(date.getTime())) return iso;
                return days[date.getDay()] + ", " + months[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear();
            }
            function formatTime(hour) {
                if (hour === null || hour === undefined || isNaN(hour)) return "--:--";
                if (hour === 0) return "12:00 AM";
                if (hour < 12) return hour + ":00 AM";
                if (hour === 12) return "12:00 PM";
                return (hour - 12) + ":00 PM";
            }
            function sortPlans(plans) {
                plans.sort(function(a, b) {
                    if (a.plan_date < b.plan_date) return -1;
                    if (a.plan_date > b.plan_date) return 1;
                    return a.start_hour - b.start_hour;
                });
                return plans;
            }
            function clearPlans() { while (plansBody.firstChild) { plansBody.removeChild(plansBody.firstChild); } }
            function buildRow(plan) {
                var row = document.createElement("div"); row.className = "plan-row status-" + (plan.status || "planned");
                var info = document.createElement("div"); info.className = "plan-info";
                var dateEl = document.createElement("div"); dateEl.className = "plan-date"; dateEl.textContent = formatDate(plan.plan_date);
                info.appendChild(dateEl);
                var meta = document.createElement("div"); meta.className = "plan-meta";
                var timeEl = document.createElement("span"); timeEl.textContent = formatTime(plan.start_hour) + " \u00b7 " + plan.duration_minutes + " min";
                var courseEl = document.createElement("span"); courseEl.textContent = "Course: " + plan.course_id;
                meta.appendChild(timeEl); meta.appendChild(courseEl);
                if (plan.focus_concepts) { var focusEl = document.createElement("span"); focusEl.textContent = "Focus: " + plan.focus_concepts; meta.appendChild(focusEl); }
                info.appendChild(meta);
                var badge = document.createElement("span"); badge.className = "badge badge-" + (plan.status || "planned"); badge.textContent = plan.status || "planned";
                var del = document.createElement("button"); del.type = "button"; del.className = "btn btn-danger"; del.textContent = "Delete";
                del.addEventListener("click", function() { deletePlan(plan.id, del); });
                row.appendChild(info); row.appendChild(badge); row.appendChild(del);
                return row;
            }
            function renderPlans(plans) {
                clearPlans();
                if (!plans || plans.length === 0) {
                    var empty = document.createElement("div"); empty.className = "empty-state";
                    var h = document.createElement("h3"); h.textContent = "No sessions planned yet";
                    var p = document.createElement("p"); p.textContent = "Use the form above to schedule your first focused study session.";
                    empty.appendChild(h); empty.appendChild(p); plansBody.appendChild(empty);
                    return;
                }
                var i = 0; while (i < plans.length) { plansBody.appendChild(buildRow(plans[i])); i = i + 1; }
            }
            function showMessage(text) {
                clearPlans();
                var p = document.createElement("p"); p.className = "muted"; p.textContent = text;
                plansBody.appendChild(p);
            }
            function loadPlans() {
                showMessage("Loading study plans...");
                fetch("/api/study-plans", { headers: authHeaders(null) })
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if (!Array.isArray(data)) { showMessage("Could not load your study plans."); return; }
                        renderPlans(sortPlans(data));
                    })
                    .catch(function() { showMessage("Failed to load your study plans."); });
            }
            function deletePlan(id, button) {
                button.disabled = true; button.textContent = "Deleting...";
                fetch("/api/study-plans/" + encodeURIComponent(id), { method: "DELETE", headers: authHeaders(null) })
                    .then(function(r) { if (!r.ok) throw new Error("delete failed"); return r.json(); })
                    .then(function() { setStatus("Plan deleted.", false); loadPlans(); })
                    .catch(function() { button.disabled = false; button.textContent = "Delete"; setStatus("Could not delete the plan. Please try again.", true); });
            }
            var planForm = document.getElementById("plan-form");
            if (planForm) {
                planForm.addEventListener("submit", function(ev) {
                    ev.preventDefault();
                    var planDate = document.getElementById("plan-date").value;
                    if (!planDate) { setStatus("Please choose a date.", true); return; }
                    var payload = {
                        course_id: document.getElementById("plan-course").value,
                        plan_date: planDate,
                        start_hour: parseInt(document.getElementById("plan-hour").value, 10) || 0,
                        duration_minutes: parseInt(document.getElementById("plan-duration").value, 10) || 30,
                        focus_concepts: document.getElementById("plan-focus").value
                    };
                    var submitBtn = document.getElementById("plan-submit");
                    submitBtn.disabled = true; setStatus("Saving...", false);
                    fetch("/api/study-plans", { method: "POST", headers: authHeaders({ "Content-Type": "application/json" }), body: JSON.stringify(payload) })
                        .then(function(r) { if (!r.ok) throw new Error("save failed"); return r.json(); })
                        .then(function() { submitBtn.disabled = false; setStatus("Study session planned.", false); planForm.reset(); loadPlans(); })
                        .catch(function() { submitBtn.disabled = false; setStatus("Could not save your plan. Please try again.", true); });
                });
            }
            loadPlans();
        }

        return page.toString()
    }

}
