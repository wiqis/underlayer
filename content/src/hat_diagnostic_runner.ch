// HAT course — baseline diagnostic runner (CSS + client-side JS).
//
// The runner turns the question bank from hat_diagnostic_bank.ch into a
// self-contained, timed 100-question test. It renders with createElement /
// textContent (no HTML strings), scores the three sections, and stores the
// result in localStorage, so it works in both static and backend modes.
//
// Macro notes: no grouping parentheses in expressions (they are dropped by the
// #js converter — hoist sub-expressions into variables), no bare % token, no
// regex literals, no backticks.
public namespace underlayer_content {

using std::string

    public func render_hat_diagnostic_css(page : &mut HtmlPage) {
        #css {
            .unit-diagnostic { border-color: #0f766e; background: #f0fdfa; }
            .hat-diag { margin-top: 1rem; }
            .hat-diag-lead { font-size: 1rem; }
            .hat-diag-rules { margin: 0.5rem 0 1rem 0; padding-left: 1.2rem; }
            .hat-diag-actions { display: flex; gap: 0.75rem; flex-wrap: wrap; margin-top: 1rem; }
            .hat-diag-btn { padding: 0.6rem 1.1rem; border-radius: 6px; border: 1px solid #d1d5db; background: #ffffff; color: #111827; font-size: 0.95rem; cursor: pointer; }
            .hat-diag-btn:hover { border-color: #2563eb; }
            .hat-diag-btn.primary { background: #2563eb; border-color: #2563eb; color: #ffffff; }
            .hat-diag-btn.primary:hover { background: #1d4ed8; }
            .hat-diag-btn.secondary { background: #f9fafb; }
            .hat-diag-previous { border-left: 3px solid #2563eb; background: #eff6ff; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem; font-size: 0.95rem; }
            .hat-diag-header { position: sticky; top: 0; z-index: 5; display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding: 0.6rem 0.9rem; background: #111827; color: #f9fafb; border-radius: 6px; font-size: 0.9rem; }
            .hat-diag-timer { font-family: ui-monospace, monospace; font-size: 1.05rem; font-weight: 600; letter-spacing: 0.03em; }
            .hat-diag-timer.low { color: #fca5a5; }
            .hat-diag-question { padding: 1rem 0.25rem; min-height: 12rem; }
            .hat-diag-qmeta { color: #6b7280; font-size: 0.85rem; margin-bottom: 0.5rem; }
            .hat-diag-passage { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.75rem 1rem; margin-bottom: 0.75rem; font-size: 0.95rem; color: #374151; }
            .hat-diag-qtext { font-size: 1.05rem; font-weight: 600; margin: 0.5rem 0 1rem 0; }
            .hat-diag-options { display: flex; flex-direction: column; gap: 0.5rem; }
            .hat-diag-option { display: flex; align-items: flex-start; gap: 0.6rem; width: 100%; text-align: left; padding: 0.7rem 0.9rem; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; color: #111827; font-size: 0.95rem; cursor: pointer; }
            .hat-diag-option:hover { border-color: #2563eb; background: #eff6ff; }
            .hat-diag-option.selected { border-color: #2563eb; background: #dbeafe; }
            .hat-diag-optletter { flex: 0 0 auto; width: 1.5rem; height: 1.5rem; border-radius: 50%; background: #e5e7eb; color: #374151; display: flex; align-items: center; justify-content: center; font-size: 0.8rem; font-weight: 700; }
            .hat-diag-option.selected .hat-diag-optletter { background: #2563eb; color: #ffffff; }
            .hat-diag-nav { display: flex; justify-content: space-between; gap: 0.75rem; margin-top: 1rem; }
            .hat-diag-palette { display: grid; grid-template-columns: repeat(10, minmax(0, 1fr)); gap: 0.3rem; margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid #e5e7eb; }
            .hat-diag-cell { padding: 0.35rem 0; border: 1px solid #d1d5db; border-radius: 4px; background: #ffffff; color: #6b7280; font-size: 0.75rem; cursor: pointer; }
            .hat-diag-cell.answered { background: #dbeafe; border-color: #93c5fd; color: #1e3a8a; }
            .hat-diag-cell.current { outline: 2px solid #2563eb; outline-offset: 1px; color: #111827; font-weight: 700; }
            .hat-diag-total { font-size: 2.4rem; font-weight: 800; color: #111827; margin: 0.25rem 0 0.5rem 0; }
            .hat-diag-interp { font-size: 0.98rem; }
            .hat-diag-table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.95rem; }
            .hat-diag-table th, .hat-diag-table td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
            .hat-diag-table th { background: #f9fafb; font-weight: 600; }
            .hat-diag-next { margin-top: 1rem; }
            .hat-diag-next h4 { margin: 0 0 0.5rem 0; }
            .hat-diag-next ul { margin: 0; padding-left: 1.2rem; }
            .hat-diag-link { color: #2563eb; text-decoration: none; }
            .hat-diag-link:hover { text-decoration: underline; }
            .hat-diag-note { font-size: 0.85rem; color: #6b7280; margin-top: 0.75rem; }
            @media (max-width: 640px) {
                .hat-diag-palette { grid-template-columns: repeat(6, minmax(0, 1fr)); }
                .hat-diag-header { flex-direction: column; align-items: flex-start; }
            }
        }
    }

    public func render_hat_diagnostic_js(page : &mut HtmlPage) {
        #js {
            var HAT_DIAG_TOTAL_MINUTES = 120;
            var HAT_DIAG_RESULT_KEY = "hat_diag_result";
            var HAT_DIAG_PROGRESS_KEY = "hat_diag_progress";
            var hatDiagQs = [];
            var hatDiagAnswers = {};
            var hatDiagIdx = 0;
            var hatDiagDeadline = 0;
            var hatDiagTimer = null;
            var hatDiagRunning = false;

            function hatDiagStore(key, value) {
                try { localStorage.setItem(key, value); } catch (e) { var ignored_store = 0; }
            }
            function hatDiagLoad(key) {
                try { return localStorage.getItem(key); } catch (e) { return null; }
            }
            function hatDiagRemove(key) {
                try { localStorage.removeItem(key); } catch (e) { var ignored_remove = 0; }
            }
            function hatDiagRoot() {
                return document.getElementById("hat-diag-root");
            }
            function hatEl(tag, cls, text) {
                var e = document.createElement(tag);
                if (cls) { e.className = cls; }
                if (text !== undefined && text !== null) { e.textContent = text; }
                return e;
            }
            function hatClear(node) {
                while (node.firstChild) { node.removeChild(node.firstChild); }
            }
            function hatDiagBtn(text, cls, handler) {
                var b = hatEl("button", "hat-diag-btn " + cls, text);
                b.type = "button";
                b.onclick = handler;
                return b;
            }
            function hatDiagSectionName(code) {
                if (code === "quant") { return "Quantitative"; }
                if (code === "verbal") { return "Verbal"; }
                if (code === "analytical") { return "Analytical"; }
                return "";
            }
            function hatDiagSectionMax(code) {
                if (code === "quant") { return 40; }
                if (code === "verbal") { return 30; }
                if (code === "analytical") { return 30; }
                return 0;
            }
            function hatDiagBuild() {
                var all = [];
                var i;
                for (i = 0; i < HAT_DIAG_QUANT.length; i++) {
                    var q1 = HAT_DIAG_QUANT[i];
                    q1.s = "quant";
                    all.push(q1);
                }
                for (i = 0; i < HAT_DIAG_VERBAL.length; i++) {
                    var q2 = HAT_DIAG_VERBAL[i];
                    q2.s = "verbal";
                    all.push(q2);
                }
                for (i = 0; i < HAT_DIAG_ANALYTICAL.length; i++) {
                    var q3 = HAT_DIAG_ANALYTICAL[i];
                    q3.s = "analytical";
                    all.push(q3);
                }
                return all;
            }
            function hatDiagPad(n) {
                if (n < 10) { return "0" + n; }
                return "" + n;
            }
            function hatDiagFormat(ms) {
                var total = Math.floor(ms / 1000);
                var h = Math.floor(total / 3600);
                var rem = total - h * 3600;
                var m = Math.floor(rem / 60);
                var s = rem - m * 60;
                return hatDiagPad(h) + ":" + hatDiagPad(m) + ":" + hatDiagPad(s);
            }
            function hatDiagOptionHandler(idx) {
                return function() { hatDiagSelect(idx); };
            }
            function hatDiagJumpHandler(idx) {
                return function() { hatDiagJump(idx); };
            }
            function hatDiagSaveProgress() {
                var data = { answers: hatDiagAnswers, idx: hatDiagIdx, deadline: hatDiagDeadline };
                hatDiagStore(HAT_DIAG_PROGRESS_KEY, JSON.stringify(data));
            }
            function hatDiagLoadProgress() {
                var raw = hatDiagLoad(HAT_DIAG_PROGRESS_KEY);
                if (!raw) { return null; }
                try { return JSON.parse(raw); } catch (e) { return null; }
            }
            function hatDiagLoadResult() {
                var raw = hatDiagLoad(HAT_DIAG_RESULT_KEY);
                if (!raw) { return null; }
                try { return JSON.parse(raw); } catch (e) { return null; }
            }
            function hatDiagSectionSummary(result) {
                if (!result || !result.sections) { return ""; }
                var codes = ["quant", "verbal", "analytical"];
                var parts = [];
                var i;
                for (i = 0; i < codes.length; i++) {
                    var s = result.sections[codes[i]];
                    if (s) { parts.push(s.name + " " + s.correct + "/" + s.max); }
                }
                return parts.join("  |  ");
            }
            function hatDiagInterpret(total) {
                if (total < 50) {
                    return "Below the 50-mark qualifying line. A cold baseline is supposed to be humbling: the diagnostic has done its job and shown you where the marks currently are. Work the quantitative and analytical lessons first, then re-diagnose in two weeks.";
                }
                if (total < 70) {
                    return "Above the 50-mark qualifying line, but not yet competitive. Scholarships and oversubscribed programmes decide among candidates well above the line, so target the section where your accuracy is lowest.";
                }
                return "A strong baseline, at or above the competitive range of 70. Protect your strongest section and close the remaining gaps in your weakest one.";
            }
            function hatDiagRenderIntro() {
                var root = hatDiagRoot();
                if (!root) { return; }
                hatClear(root);

                var result = hatDiagLoadResult();
                if (result) {
                    var prev = hatEl("div", "hat-diag-previous");
                    var line = hatEl("div", null, "");
                    line.appendChild(hatEl("strong", null, "Your last diagnostic: "));
                    line.appendChild(document.createTextNode(result.total + " / 100"));
                    prev.appendChild(line);
                    prev.appendChild(hatEl("div", null, hatDiagSectionSummary(result)));
                    root.appendChild(prev);
                }

                root.appendChild(hatEl("p", "hat-diag-lead", "This is a full HAT-1 style paper: 100 multiple-choice questions in 120 minutes, split 40 quantitative, 30 verbal and 30 analytical, one mark each and no negative marking. Sit it cold, in one sitting, without a calculator. When you submit you get a sectional score and a next-step plan."));

                var rules = hatEl("ul", "hat-diag-rules");
                rules.appendChild(hatEl("li", null, "100 questions in 120 minutes, about 72 seconds each."));
                rules.appendChild(hatEl("li", null, "No negative marking, so answer every question."));
                rules.appendChild(hatEl("li", null, "Your score is stored in this browser only."));
                root.appendChild(rules);

                var actions = hatEl("div", "hat-diag-actions");
                var prog = hatDiagLoadProgress();
                if (prog) {
                    actions.appendChild(hatDiagBtn("Resume the diagnostic", "primary", function() { hatDiagStart(true); }));
                    actions.appendChild(hatDiagBtn("Start over", "secondary", function() { hatDiagRemove(HAT_DIAG_PROGRESS_KEY); hatDiagStart(false); }));
                } else {
                    actions.appendChild(hatDiagBtn("Start the diagnostic", "primary", function() { hatDiagStart(false); }));
                }
                root.appendChild(actions);
            }
            function hatDiagStart(resume) {
                hatDiagQs = hatDiagBuild();
                hatDiagRunning = true;
                var span = HAT_DIAG_TOTAL_MINUTES * 60000;
                if (resume) {
                    var p = hatDiagLoadProgress();
                    if (p) {
                        hatDiagAnswers = p.answers || {};
                        hatDiagIdx = p.idx || 0;
                        hatDiagDeadline = p.deadline || Date.now() + span;
                    } else {
                        hatDiagAnswers = {};
                        hatDiagIdx = 0;
                        hatDiagDeadline = Date.now() + span;
                    }
                } else {
                    hatDiagAnswers = {};
                    hatDiagIdx = 0;
                    hatDiagDeadline = Date.now() + span;
                    hatDiagSaveProgress();
                }
                if (hatDiagIdx >= hatDiagQs.length) { hatDiagIdx = 0; }
                hatDiagRenderTest();
                hatDiagStartTimer();
            }
            function hatDiagStartTimer() {
                if (hatDiagTimer) { clearInterval(hatDiagTimer); }
                hatDiagTick();
                hatDiagTimer = setInterval(hatDiagTick, 1000);
            }
            function hatDiagTick() {
                var left = hatDiagDeadline - Date.now();
                var el = document.getElementById("hat-diag-timer");
                if (el) {
                    if (left <= 0) {
                        el.textContent = "00:00:00";
                    } else {
                        el.textContent = hatDiagFormat(left);
                        if (left < 300000) { el.className = "hat-diag-timer low"; }
                    }
                }
                if (left <= 0 && hatDiagRunning) { hatDiagSubmit(true); }
            }
            function hatDiagRenderTest() {
                var root = hatDiagRoot();
                if (!root) { return; }
                hatClear(root);

                var header = hatEl("div", "hat-diag-header");
                var timer = hatEl("span", "hat-diag-timer", "00:00:00");
                timer.id = "hat-diag-timer";
                header.appendChild(timer);
                var progress = hatEl("span", "hat-diag-progress", "");
                progress.id = "hat-diag-progress";
                header.appendChild(progress);
                root.appendChild(header);

                var qbox = hatEl("div", "hat-diag-question");
                qbox.id = "hat-diag-question";
                root.appendChild(qbox);

                var nav = hatEl("div", "hat-diag-nav");
                nav.appendChild(hatDiagBtn("Previous", "secondary", function() { hatDiagGo(-1); }));
                nav.appendChild(hatDiagBtn("Submit diagnostic", "primary", function() { hatDiagSubmit(false); }));
                nav.appendChild(hatDiagBtn("Next", "secondary", function() { hatDiagGo(1); }));
                root.appendChild(nav);

                var palette = hatEl("div", "hat-diag-palette");
                palette.id = "hat-diag-palette";
                root.appendChild(palette);

                hatDiagRenderQuestion();
            }
            function hatDiagRenderQuestion() {
                var box = document.getElementById("hat-diag-question");
                if (!box) { return; }
                var q = hatDiagQs[hatDiagIdx];
                if (!q) { return; }
                hatClear(box);

                var num = hatDiagIdx + 1;
                var meta = hatEl("div", "hat-diag-qmeta", "Question " + num + " of " + hatDiagQs.length + "  |  " + hatDiagSectionName(q.s));
                box.appendChild(meta);
                if (q.p) { box.appendChild(hatEl("div", "hat-diag-passage", q.p)); }
                box.appendChild(hatEl("p", "hat-diag-qtext", q.q));

                var opts = hatEl("div", "hat-diag-options");
                var letters = ["A", "B", "C", "D"];
                var i;
                for (i = 0; i < q.o.length; i++) {
                    var cls = "hat-diag-option";
                    if (hatDiagAnswers[hatDiagIdx] === i) { cls = cls + " selected"; }
                    var btn = hatEl("button", cls);
                    btn.type = "button";
                    btn.appendChild(hatEl("span", "hat-diag-optletter", letters[i]));
                    btn.appendChild(hatEl("span", "hat-diag-opttext", q.o[i]));
                    btn.onclick = hatDiagOptionHandler(i);
                    opts.appendChild(btn);
                }
                box.appendChild(opts);
                hatDiagRenderPalette();
            }
            function hatDiagSelect(idx) {
                hatDiagAnswers[hatDiagIdx] = idx;
                hatDiagSaveProgress();
                hatDiagRenderQuestion();
            }
            function hatDiagGo(delta) {
                var next = hatDiagIdx + delta;
                if (next < 0) { next = 0; }
                if (next >= hatDiagQs.length) { next = hatDiagQs.length - 1; }
                hatDiagIdx = next;
                hatDiagSaveProgress();
                hatDiagRenderQuestion();
            }
            function hatDiagJump(idx) {
                hatDiagIdx = idx;
                hatDiagSaveProgress();
                hatDiagRenderQuestion();
            }
            function hatDiagRenderPalette() {
                var answered = 0;
                var i;
                for (i = 0; i < hatDiagQs.length; i++) {
                    if (hatDiagAnswers[i] !== undefined) { answered = answered + 1; }
                }
                var p = document.getElementById("hat-diag-progress");
                if (p) { p.textContent = answered + " of " + hatDiagQs.length + " answered"; }
                var pal = document.getElementById("hat-diag-palette");
                if (!pal) { return; }
                hatClear(pal);
                for (i = 0; i < hatDiagQs.length; i++) {
                    var cls = "hat-diag-cell";
                    if (hatDiagAnswers[i] !== undefined) { cls = cls + " answered"; }
                    if (i === hatDiagIdx) { cls = cls + " current"; }
                    var label = i + 1;
                    var cell = hatEl("button", cls, "" + label);
                    cell.type = "button";
                    cell.onclick = hatDiagJumpHandler(i);
                    pal.appendChild(cell);
                }
            }
            function hatDiagScore() {
                var result = { total: 0, answered: 0, correct: 0, wrong: 0, blank: 0, sections: {} };
                var codes = ["quant", "verbal", "analytical"];
                var c;
                for (c = 0; c < codes.length; c++) {
                    var code = codes[c];
                    result.sections[code] = { name: hatDiagSectionName(code), max: hatDiagSectionMax(code), correct: 0, wrong: 0, blank: 0 };
                }
                var i;
                for (i = 0; i < hatDiagQs.length; i++) {
                    var q = hatDiagQs[i];
                    var sec = result.sections[q.s];
                    var chosen = hatDiagAnswers[i];
                    if (chosen === undefined) {
                        sec.blank = sec.blank + 1;
                        result.blank = result.blank + 1;
                    } else {
                        result.answered = result.answered + 1;
                        if (chosen === q.a) {
                            sec.correct = sec.correct + 1;
                            result.correct = result.correct + 1;
                            result.total = result.total + 1;
                        } else {
                            sec.wrong = sec.wrong + 1;
                            result.wrong = result.wrong + 1;
                        }
                    }
                }
                return result;
            }
            function hatDiagSubmit(auto) {
                if (!hatDiagRunning) { return; }
                var unanswered = 0;
                var i;
                for (i = 0; i < hatDiagQs.length; i++) {
                    if (hatDiagAnswers[i] === undefined) { unanswered = unanswered + 1; }
                }
                if (!auto && unanswered > 0) {
                    var ok = window.confirm("You still have " + unanswered + " unanswered question(s). Submit the diagnostic now?");
                    if (!ok) { return; }
                }
                if (auto) {
                    window.alert("Time is up. Your diagnostic has been submitted.");
                }
                hatDiagRunning = false;
                if (hatDiagTimer) { clearInterval(hatDiagTimer); hatDiagTimer = null; }
                hatDiagRemove(HAT_DIAG_PROGRESS_KEY);
                var result = hatDiagScore();
                hatDiagStore(HAT_DIAG_RESULT_KEY, JSON.stringify(result));
                hatDiagRenderResult(result);
            }
            function hatDiagResultRow(cells, isHeader) {
                var tr = document.createElement("tr");
                var i;
                for (i = 0; i < cells.length; i++) {
                    var tag = "td";
                    if (isHeader) { tag = "th"; }
                    var cell = document.createElement(tag);
                    cell.textContent = "" + cells[i];
                    tr.appendChild(cell);
                }
                return tr;
            }
            function hatDiagNextItem(url, text) {
                var li = document.createElement("li");
                var a = document.createElement("a");
                a.href = url;
                a.textContent = text;
                a.className = "hat-diag-link";
                li.appendChild(a);
                return li;
            }
            function hatDiagRenderResult(result) {
                var root = hatDiagRoot();
                if (!root) { return; }
                hatClear(root);

                root.appendChild(hatEl("h3", null, "Your diagnostic score"));
                root.appendChild(hatEl("div", "hat-diag-total", result.total + " / 100"));
                root.appendChild(hatEl("p", "hat-diag-interp", hatDiagInterpret(result.total)));

                var table = document.createElement("table");
                table.className = "hat-diag-table";
                var thead = document.createElement("thead");
                thead.appendChild(hatDiagResultRow(["Section", "Score", "Correct", "Wrong", "Blank"], true));
                table.appendChild(thead);
                var tbody = document.createElement("tbody");
                var codes = ["quant", "verbal", "analytical"];
                var i;
                for (i = 0; i < codes.length; i++) {
                    var s = result.sections[codes[i]];
                    tbody.appendChild(hatDiagResultRow([s.name, s.correct + " / " + s.max, s.correct, s.wrong, s.blank], false));
                }
                tbody.appendChild(hatDiagResultRow(["Total", result.total + " / 100", result.correct, result.wrong, result.blank], false));
                table.appendChild(tbody);
                root.appendChild(table);

                var next = hatEl("div", "hat-diag-next");
                next.appendChild(hatEl("h4", null, "Where to go next"));
                var list = hatEl("ul", null);
                list.appendChild(hatDiagNextItem("/courses/hat/lessons/hat-weightage-strategy", "Weightage and Study Strategy: turn these numbers into a plan"));
                list.appendChild(hatDiagNextItem("/courses/hat/lessons/hat-study-plan", "The Eight-Week Program: schedule the work"));
                list.appendChild(hatDiagNextItem("/courses/hat/lessons/hat-error-log", "The Error Log: record the cause of every miss"));
                next.appendChild(list);
                root.appendChild(next);

                var actions = hatEl("div", "hat-diag-actions");
                actions.appendChild(hatDiagBtn("Retake the diagnostic", "primary", function() { hatDiagRemove(HAT_DIAG_RESULT_KEY); hatDiagRenderIntro(); }));
                root.appendChild(actions);
                root.appendChild(hatEl("p", "hat-diag-note", "Your result is saved in this browser. Retaking replaces it."));
            }
            function hatDiagInit() {
                var root = hatDiagRoot();
                if (!root) { return; }
                hatDiagQs = hatDiagBuild();
                hatDiagRenderIntro();
            }
            document.addEventListener("DOMContentLoaded", hatDiagInit);
        }
    }

}
