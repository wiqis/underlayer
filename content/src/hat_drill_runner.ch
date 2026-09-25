// HAT course - shared timed drill runner (CSS + client-side JS).
//
// Reused by all three timed drills (quant, verbal, analytical). The runner is
// generic: it reads a global HAT_DRILL_BANK and HAT_DRILL_CONFIG that each
// drill's config file sets immediately before it, so the question data and the
// timing rules live in the drill, not here.
//
// It turns a paper-and-pencil drill into something the platform can observe:
// timed, auto-marked, scored against a pass mark, and stored in localStorage so
// a retake a week later can be compared with the first attempt. It works from
// a file:// URL, so static mode is unaffected.
//
// Macro notes: DOM is built with createElement + textContent (never HTML
// strings), no grouping parentheses in expressions (the #js converter drops
// them), no regex literals, no bare % token, ASCII-only strings, and loop
// handlers go through a factory because `var` shares one binding.
public namespace underlayer_content {

using std::string

    public func render_hat_drill_css(page : &mut HtmlPage) {
        #css {
            .unit-drill { border-color: #be123c; background: #fff1f2; }
            .hat-drill { margin-top: 1rem; }
            .hat-drill-lead { font-size: 1rem; }
            .hat-drill-rules { margin: 0.5rem 0 1rem 0; padding-left: 1.2rem; }
            .hat-drill-actions { display: flex; gap: 0.75rem; flex-wrap: wrap; margin-top: 1rem; }
            .hat-drill-btn { padding: 0.6rem 1.1rem; border-radius: 6px; border: 1px solid #d1d5db; background: #ffffff; color: #111827; font-size: 0.95rem; cursor: pointer; }
            .hat-drill-btn:hover { border-color: #be123c; }
            .hat-drill-btn.primary { background: #be123c; border-color: #be123c; color: #ffffff; }
            .hat-drill-btn.primary:hover { background: #9f1239; }
            .hat-drill-btn.secondary { background: #f9fafb; }
            .hat-drill-previous { border-left: 3px solid #be123c; background: #ffffff; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem; font-size: 0.95rem; }
            .hat-drill-header { position: sticky; top: 0; z-index: 5; display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding: 0.6rem 0.9rem; background: #111827; color: #f9fafb; border-radius: 6px; font-size: 0.9rem; }
            .hat-drill-timer { font-family: ui-monospace, monospace; font-size: 1.05rem; font-weight: 600; letter-spacing: 0.03em; }
            .hat-drill-timer.low { color: #fca5a5; }
            .hat-drill-question { padding: 1rem 0.25rem; min-height: 11rem; }
            .hat-drill-qmeta { color: #6b7280; font-size: 0.85rem; margin-bottom: 0.5rem; }
            .hat-drill-qtext { font-size: 1.05rem; font-weight: 600; margin: 0.5rem 0 1rem 0; }
            .hat-drill-options { display: flex; flex-direction: column; gap: 0.5rem; }
            .hat-drill-option { display: flex; align-items: flex-start; gap: 0.6rem; width: 100%; text-align: left; padding: 0.7rem 0.9rem; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; color: #111827; font-size: 0.95rem; cursor: pointer; }
            .hat-drill-option:hover { border-color: #be123c; background: #fff1f2; }
            .hat-drill-option.selected { border-color: #be123c; background: #ffe4e6; }
            .hat-drill-optletter { flex: 0 0 auto; width: 1.5rem; height: 1.5rem; border-radius: 50%; background: #e5e7eb; color: #374151; display: flex; align-items: center; justify-content: center; font-size: 0.8rem; font-weight: 700; }
            .hat-drill-option.selected .hat-drill-optletter { background: #be123c; color: #ffffff; }
            .hat-drill-nav { display: flex; justify-content: space-between; gap: 0.75rem; margin-top: 1rem; }
            .hat-drill-palette { display: grid; grid-template-columns: repeat(10, minmax(0, 1fr)); gap: 0.3rem; margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid #e5e7eb; }
            .hat-drill-cell { padding: 0.35rem 0; border: 1px solid #d1d5db; border-radius: 4px; background: #ffffff; color: #6b7280; font-size: 0.75rem; cursor: pointer; }
            .hat-drill-cell.answered { background: #ffe4e6; border-color: #fda4af; color: #881337; }
            .hat-drill-cell.current { outline: 2px solid #be123c; outline-offset: 1px; color: #111827; font-weight: 700; }
            .hat-drill-total { font-size: 2.4rem; font-weight: 800; color: #111827; margin: 0.25rem 0 0.5rem 0; }
            .hat-drill-passed { color: #047857; font-weight: 700; }
            .hat-drill-failed { color: #b91c1c; font-weight: 700; }
            .hat-drill-review { border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.75rem 0.9rem; margin: 0.6rem 0; background: #ffffff; }
            .hat-drill-review.right { border-left: 4px solid #059669; }
            .hat-drill-review.wrong { border-left: 4px solid #dc2626; }
            .hat-drill-review-q { font-weight: 600; font-size: 0.95rem; }
            .hat-drill-review-e { font-size: 0.9rem; color: #374151; margin-top: 0.35rem; }
            .hat-drill-note { font-size: 0.85rem; color: #6b7280; margin-top: 0.75rem; }
            @media (max-width: 640px) {
                .hat-drill-palette { grid-template-columns: repeat(6, minmax(0, 1fr)); }
                .hat-drill-header { flex-direction: column; align-items: flex-start; }
            }
        }
    }

    public func render_hat_drill_js(page : &mut HtmlPage) {
        #js {
            // ---- state ----
            var hatDrillAnswers = {};
            var hatDrillIdx = 0;
            var hatDrillDeadline = 0;
            var hatDrillTimer = null;
            var hatDrillRunning = false;
            var hatDrillStartedAt = 0;

            // ---- storage (fails silently on file:// and private mode) ----
            function hatDrillStore(key, value) {
                try { localStorage.setItem(key, value); } catch (e) { var hatDrillIgnore = 0; }
            }
            function hatDrillLoad(key) {
                try { return localStorage.getItem(key); } catch (e) { return null; }
            }
            function hatDrillRemove(key) {
                try { localStorage.removeItem(key); } catch (e) { var hatDrillIgnore = 0; }
            }
            function hatDrillResultKey() { return "hat_drill_result_" + HAT_DRILL_CONFIG.slug; }
            function hatDrillProgressKey() { return "hat_drill_progress_" + HAT_DRILL_CONFIG.slug; }

            // ---- tiny DOM helpers (no HTML strings) ----
            function hatDrillRoot() { return document.getElementById("hat-drill-root"); }
            function hatDrillEl(tag, cls, text) {
                var e = document.createElement(tag);
                if (cls) { e.className = cls; }
                if (text !== undefined && text !== null) { e.textContent = text; }
                return e;
            }
            function hatDrillClear(node) {
                while (node.firstChild) { node.removeChild(node.firstChild); }
            }
            function hatDrillBtn(text, cls, handler) {
                var b = hatDrillEl("button", "hat-drill-btn " + cls, text);
                b.type = "button";
                b.onclick = handler;
                return b;
            }
            function hatDrillPad(n) {
                if (n < 10) { return "0" + n; }
                return "" + n;
            }
            function hatDrillClock(ms) {
                var total = Math.floor(ms / 1000);
                var m = Math.floor(total / 60);
                var s = total - m * 60;
                return hatDrillPad(m) + ":" + hatDrillPad(s);
            }
            function hatDrillLetter(i) { return String.fromCharCode(97 + i); }

            // ---- persistence ----
            function hatDrillSaveProgress() {
                var data = { answers: hatDrillAnswers, idx: hatDrillIdx, deadline: hatDrillDeadline, started: hatDrillStartedAt };
                hatDrillStore(hatDrillProgressKey(), JSON.stringify(data));
            }
            function hatDrillLoadProgress() {
                var raw = hatDrillLoad(hatDrillProgressKey());
                if (!raw) { return null; }
                try { return JSON.parse(raw); } catch (e) { return null; }
            }
            function hatDrillLoadResult() {
                var raw = hatDrillLoad(hatDrillResultKey());
                if (!raw) { return null; }
                try { return JSON.parse(raw); } catch (e) { return null; }
            }

            // ---- handler factories: `var` shares one binding in a loop ----
            function hatDrillOptionHandler(i) {
                return function() { hatDrillSelect(i); };
            }
            function hatDrillCellHandler(i) {
                return function() { hatDrillJump(i); };
            }
            function hatDrillNavHandler(delta) {
                return function() { hatDrillMove(delta); };
            }

            // ---- interaction ----
            function hatDrillSelect(i) {
                hatDrillAnswers[hatDrillIdx] = i;
                hatDrillSaveProgress();
                hatDrillRenderQuestion();
            }
            function hatDrillMove(delta) {
                var next = hatDrillIdx + delta;
                if (next < 0) { next = 0; }
                if (next > HAT_DRILL_BANK.length - 1) { next = HAT_DRILL_BANK.length - 1; }
                hatDrillIdx = next;
                hatDrillSaveProgress();
                hatDrillRenderQuestion();
            }
            function hatDrillJump(i) {
                hatDrillIdx = i;
                hatDrillSaveProgress();
                hatDrillRenderQuestion();
            }
            function hatDrillStart(resume) {
                var span = HAT_DRILL_CONFIG.minutes * 60000;
                if (resume) {
                    var p = hatDrillLoadProgress();
                    if (p) {
                        hatDrillAnswers = p.answers || {};
                        hatDrillIdx = p.idx || 0;
                        hatDrillDeadline = p.deadline || 0;
                        hatDrillStartedAt = p.started || 0;
                    } else {
                        hatDrillAnswers = {};
                        hatDrillIdx = 0;
                        hatDrillDeadline = 0;
                    }
                } else {
                    hatDrillAnswers = {};
                    hatDrillIdx = 0;
                    hatDrillStartedAt = Date.now();
                    hatDrillRemove(hatDrillResultKey());
                }
                if (hatDrillDeadline === 0) { hatDrillDeadline = Date.now() + span; }
                hatDrillRunning = true;
                hatDrillSaveProgress();
                hatDrillRenderQuestion();
                hatDrillStartTimer();
            }
            function hatDrillStartTimer() {
                if (hatDrillTimer) { clearInterval(hatDrillTimer); }
                hatDrillTick();
                hatDrillTimer = setInterval(hatDrillTick, 1000);
            }
            function hatDrillTick() {
                var left = hatDrillDeadline - Date.now();
                var el = document.getElementById("hat-drill-timer");
                if (el) {
                    if (left <= 0) {
                        el.textContent = "00:00";
                    } else {
                        el.textContent = hatDrillClock(left);
                        var low = left < 300000;
                        el.className = low ? "hat-drill-timer low" : "hat-drill-timer";
                    }
                }
                if (left <= 0 && hatDrillRunning) { hatDrillSubmit(true); }
            }

            // ---- rendering ----
            function hatDrillRenderIntro() {
                var root = hatDrillRoot();
                if (!root) { return; }
                hatDrillClear(root);

                var prev = hatDrillLoadResult();
                if (prev) {
                    var box = hatDrillEl("div", "hat-drill-previous");
                    var head = hatDrillEl("div", null, "");
                    head.appendChild(hatDrillEl("strong", null, "Your last attempt: "));
                    head.appendChild(document.createTextNode(prev.total + " / " + prev.max + "  (" + prev.accuracy + "%)"));
                    box.appendChild(head);
                    var when = prev.at ? " on " + prev.at : "";
                    box.appendChild(hatDrillEl("div", null, "Marked " + prev.marked + " of " + prev.max + when));
                    root.appendChild(box);
                }

                root.appendChild(hatDrillEl("p", "hat-drill-lead", HAT_DRILL_CONFIG.lead));

                var rules = hatDrillEl("ul", "hat-drill-rules");
                rules.appendChild(hatDrillEl("li", null, HAT_DRILL_CONFIG.count + " questions in " + HAT_DRILL_CONFIG.minutes + " minutes, about " + HAT_DRILL_CONFIG.budget + " seconds each."));
                rules.appendChild(hatDrillEl("li", null, "No negative marking, so answer every question. A blank is a zero you chose."));
                rules.appendChild(hatDrillEl("li", null, "The clock does not stop. It submits for you at zero."));
                rules.appendChild(hatDrillEl("li", null, "Pass mark for this drill is " + HAT_DRILL_CONFIG.pass + " of " + HAT_DRILL_CONFIG.count + "."));
                rules.appendChild(hatDrillEl("li", null, "Your result is stored in this browser only, so you can compare a retake with the first attempt."));
                root.appendChild(rules);

                var actions = hatDrillEl("div", "hat-drill-actions");
                var prog = hatDrillLoadProgress();
                if (prog) {
                    actions.appendChild(hatDrillBtn("Resume the drill", "primary", function() { hatDrillStart(true); }));
                    actions.appendChild(hatDrillBtn("Start over", "secondary", function() { hatDrillRemove(hatDrillProgressKey()); hatDrillStart(false); }));
                } else {
                    actions.appendChild(hatDrillBtn("Start the drill", "primary", function() { hatDrillStart(false); }));
                }
                root.appendChild(actions);
            }
            function hatDrillRenderQuestion() {
                var root = hatDrillRoot();
                if (!root) { return; }
                hatDrillClear(root);

                var header = hatDrillEl("div", "hat-drill-header");
                var left = hatDrillEl("div", null, "Question " + (hatDrillIdx + 1) + " of " + HAT_DRILL_BANK.length);
                var timer = hatDrillEl("div", "hat-drill-timer", "00:00");
                timer.id = "hat-drill-timer";
                header.appendChild(left);
                header.appendChild(timer);
                root.appendChild(header);

                var q = HAT_DRILL_BANK[hatDrillIdx];
                var wrap = hatDrillEl("div", "hat-drill-question");
                wrap.appendChild(hatDrillEl("div", "hat-drill-qmeta", HAT_DRILL_CONFIG.unit + " drill"));
                wrap.appendChild(hatDrillEl("div", "hat-drill-qtext", q.q));

                var opts = hatDrillEl("div", "hat-drill-options");
                var chosen = hatDrillAnswers[hatDrillIdx];
                for (var i = 0; i < q.o.length; i++) {
                    var cls = "hat-drill-option";
                    if (chosen === i) { cls = "hat-drill-option selected"; }
                    var b = hatDrillEl("button", cls, null);
                    b.type = "button";
                    b.appendChild(hatDrillEl("span", "hat-drill-optletter", hatDrillLetter(i)));
                    b.appendChild(document.createTextNode(q.o[i]));
                    b.onclick = hatDrillOptionHandler(i);
                    opts.appendChild(b);
                }
                wrap.appendChild(opts);
                root.appendChild(wrap);

                var nav = hatDrillEl("div", "hat-drill-nav");
                var prevB = hatDrillBtn("Previous", "secondary", hatDrillNavHandler(-1));
                if (hatDrillIdx === 0) { prevB.disabled = true; }
                nav.appendChild(prevB);
                if (hatDrillIdx < HAT_DRILL_BANK.length - 1) {
                    nav.appendChild(hatDrillBtn("Next", "primary", hatDrillNavHandler(1)));
                } else {
                    nav.appendChild(hatDrillBtn("Submit the drill", "primary", function() { hatDrillSubmit(false); }));
                }
                root.appendChild(nav);

                var palette = hatDrillEl("div", "hat-drill-palette");
                for (var j = 0; j < HAT_DRILL_BANK.length; j++) {
                    var cellCls = "hat-drill-cell";
                    var answered = hatDrillAnswers[j];
                    if (answered !== undefined) { cellCls = "hat-drill-cell answered"; }
                    if (j === hatDrillIdx) { cellCls = cellCls + " current"; }
                    var cell = hatDrillEl("button", cellCls, "" + (j + 1));
                    cell.type = "button";
                    cell.onclick = hatDrillCellHandler(j);
                    palette.appendChild(cell);
                }
                root.appendChild(palette);
            }

            // ---- scoring ----
            function hatDrillSubmit(auto) {
                if (!hatDrillRunning) { return; }
                hatDrillRunning = false;
                if (hatDrillTimer) { clearInterval(hatDrillTimer); }
                hatDrillRemove(hatDrillProgressKey());

                var max = HAT_DRILL_BANK.length;
                var correct = 0;
                var marked = 0;
                var wrongIdx = [];
                for (var i = 0; i < max; i++) {
                    var pick = hatDrillAnswers[i];
                    if (pick === undefined) { continue; }
                    marked = marked + 1;
                    if (pick === HAT_DRILL_BANK[i].a) {
                        correct = correct + 1;
                    } else {
                        wrongIdx.push(i);
                    }
                }
                var pct = 0;
                if (max > 0) { pct = Math.round(correct * 100 / max); }
                var elapsed = Date.now() - hatDrillStartedAt;
                if (elapsed < 0) { elapsed = 0; }
                var passed = correct >= HAT_DRILL_CONFIG.pass;

                var result = {
                    slug: HAT_DRILL_CONFIG.slug,
                    total: correct,
                    max: max,
                    marked: marked,
                    blank: max - marked,
                    accuracy: pct,
                    passed: passed,
                    auto: auto,
                    elapsed: elapsed,
                    at: new Date().toISOString().slice(0, 10),
                    wrong: wrongIdx
                };
                hatDrillStore(hatDrillResultKey(), JSON.stringify(result));
                hatDrillRenderResult(result);
            }
            function hatDrillRenderResult(result) {
                var root = hatDrillRoot();
                if (!root) { return; }
                hatDrillClear(root);

                var verdict = hatDrillEl("div", null, null);
                verdict.appendChild(hatDrillEl("div", "hat-drill-total", result.total + " / " + result.max));
                var line = hatDrillEl("div", null, "");
                line.appendChild(document.createTextNode(result.accuracy + "% correct, " + result.marked + " marked, " + result.blank + " left blank, in " + hatDrillClock(result.elapsed) + "."));
                verdict.appendChild(line);
                if (result.auto) {
                    verdict.appendChild(hatDrillEl("p", "hat-drill-note", "The clock reached zero and the drill submitted itself. Anything you had not answered is counted as a zero."));
                }
                var status = hatDrillEl("p", null, "");
                if (result.passed) {
                    status.className = "hat-drill-passed";
                    status.textContent = "Above the pass mark of " + HAT_DRILL_CONFIG.pass + ". Book the retake and try to beat this score.";
                } else {
                    status.className = "hat-drill-failed";
                    status.textContent = "Below the pass mark of " + HAT_DRILL_CONFIG.pass + ". The question-by-question review below names the technique behind every miss; go back to those lessons before the retake.";
                }
                verdict.appendChild(status);
                root.appendChild(verdict);

                if (result.wrong.length > 0) {
                    root.appendChild(hatDrillEl("h4", null, "Review every question you missed"));
                    for (var i = 0; i < result.wrong.length; i++) {
                        var qi = result.wrong[i];
                        var q = HAT_DRILL_BANK[qi];
                        var box = hatDrillEl("div", "hat-drill-review wrong");
                        box.appendChild(hatDrillEl("div", "hat-drill-review-q", "Q" + (qi + 1) + ". " + q.q));
                        var yours = hatDrillAnswers[qi];
                        var yoursText = "not answered";
                        if (yours !== undefined) { yoursText = "(" + hatDrillLetter(yours) + ") " + q.o[yours]; }
                        var rightText = "(" + hatDrillLetter(q.a) + ") " + q.o[q.a];
                        box.appendChild(hatDrillEl("div", "hat-drill-review-e", "You chose " + yoursText + ". The answer is " + rightText + "."));
                        if (q.e) { box.appendChild(hatDrillEl("div", "hat-drill-review-e", q.e)); }
                        root.appendChild(box);
                    }
                } else if (result.marked === 0) {
                    root.appendChild(hatDrillEl("p", "hat-drill-note", "Nothing was marked, so there is nothing to review. Start again and attempt every question."));
                } else {
                    root.appendChild(hatDrillEl("p", "hat-drill-note", "Full marks. Push the time down on the retake rather than trying to get more correct."));
                }

                var actions = hatDrillEl("div", "hat-drill-actions");
                actions.appendChild(hatDrillBtn("Take the drill again", "primary", function() { hatDrillStart(false); }));
                root.appendChild(actions);
                root.appendChild(hatDrillEl("p", "hat-drill-note", "The printed answer key earlier on this page is the same data this runner used, so the two can never disagree."));
            }

            document.addEventListener("DOMContentLoaded", function() { hatDrillRenderIntro(); });
        }
    }

    // Per-drill timing and pass marks. Each sets the two globals the runner
    // reads. Call order matters: bank, then config, then the runner.
    public func render_hat_quant_drill_config(page : &mut HtmlPage) {
        #js {
            var HAT_DRILL_BANK = HAT_QUANT_DRILL_BANK;
            var HAT_DRILL_CONFIG = {
                slug: "quant",
                unit: "Quantitative",
                count: 25,
                minutes: 30,
                budget: 72,
                pass: 22,
                lead: "Mixed quantitative practice under a clock: 25 questions in 30 minutes with no calculator. Read about percentages does not make you faster at percentages, and in this paper nothing tells you which technique to use, so recognising the type is the skill being trained."
            };
        }
    }

    public func render_hat_verbal_drill_config(page : &mut HtmlPage) {
        #js {
            var HAT_DRILL_BANK = HAT_VERBAL_DRILL_BANK;
            var HAT_DRILL_CONFIG = {
                slug: "verbal",
                unit: "Verbal",
                count: 30,
                minutes: 30,
                budget: 60,
                pass: 25,
                lead: "Mixed verbal practice under a clock: 30 questions in 30 minutes. Vocabulary, antonyms, analogies, sentence completion, grammar, prepositions and a short passage. These are the fastest marks on the paper because a rule learned once is right every time."
            };
        }
    }

    public func render_hat_analytical_drill_config(page : &mut HtmlPage) {
        #js {
            var HAT_DRILL_BANK = HAT_ANALYTICAL_DRILL_BANK;
            var HAT_DRILL_CONFIG = {
                slug: "analytical",
                unit: "Analytical",
                count: 20,
                minutes: 24,
                budget: 72,
                pass: 16,
                lead: "Mixed analytical reasoning under a clock: 20 questions in 24 minutes. Seating, scheduling, syllogisms, relations, directions, coding, series, data interpretation and data sufficiency. This section punishes careless reading more than weak reasoning."
            };
        }
    }

}
