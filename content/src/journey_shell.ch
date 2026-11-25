// underlayer_content — the guided lesson journey shell (markup + styles).
//
// WHY THIS IS A SHELL AND NOT 469 REWRITTEN LESSONS.  Every lesson already emits
// its teaching as semantic `.unit` blocks (unit-why, unit-model, unit-reality,
// unit-example, unit-connect, unit-interact, unit-apply, unit-retrieve,
// unit-exercises).  The journey runtime in journey_runtime.ch / journey_actions.ch
// walks those blocks in place: it never clones them, never rewrites a byte of
// technical content, and Deep dive simply removes the chrome so the original
// document is exactly what it was before the journey was switched on.
//
// WHY THE MARKUP IS SERVER-RENDERED (AND INLINED).  A learner with scripting off
// still receives the whole lesson: the shell ships with `hidden` on it and the
// units stay visible until the runtime takes over.  Static pages built from
// content/src get this markup from render_lesson_css/render_lesson_js;
// backend-rendered pages get it from web/src/journey_apply.ch.  Both paths emit
// the SAME function, so there is one shell, not two.
//
// THE VISUAL RULES FOLLOW docs/learner-first-mandate.md: calm spacing, one focal
// element per screen, explicit labels on every control, no percentages, no
// animation for its own sake.  High-contrast and reduced-motion preferences are
// honoured through the lesson's own `.high-contrast` / `.reduced-motion` classes.
using std::string
using std::string_view

public namespace underlayer_content {

    // The scaffold.  It is deliberately empty of technical content: every fact
    // comes from the learner's own lesson, at runtime, from that lesson's units.
    public func render_journey_markup(page : &mut HtmlPage) {
        #html {
            <div class="journey-shell" id="ul-journey" data-course="" data-concept="" data-minutes="" data-difficulty="" data-prereq="" hidden>
                <div class="journey-arrival" id="ul-journey-arrival">
                    <p class="journey-aim" id="ul-journey-aim">In this step you will be able to work through this lesson one idea at a time.</p>
                    <p class="journey-arrival-meta" id="ul-journey-meta" hidden></p>
                    <button type="button" class="journey-btn journey-start" id="ul-journey-start" aria-label="Start the guided lesson journey">Start the journey</button>
                </div>
                <div class="journey-ribbon" id="ul-journey-ribbon" hidden aria-live="polite">
                    <span class="journey-count" id="ul-journey-count">Step 1 of 1</span>
                    <span class="journey-purpose" id="ul-journey-purpose"></span>
                    <span class="journey-next" id="ul-journey-next"></span>
                </div>
                <div class="journey-stage" id="ul-journey-stage" aria-live="off"></div>
                <div class="journey-remember" id="ul-journey-remember" hidden>
                    <label class="journey-remember-label" for="ul-journey-note">Remember this</label>
                    <p class="journey-keypoint" id="ul-journey-keypoint"></p>
                    <input type="text" class="journey-note" id="ul-journey-note" maxlength="180" aria-describedby="ul-journey-words" placeholder="The one thing I will keep..." />
                    <span class="journey-words" id="ul-journey-words">0 / 25 words</span>
                </div>
                <div class="journey-retrieve" id="ul-journey-retrieve" hidden>
                    <p class="journey-retrieve-ask" id="ul-journey-ask"></p>
                    <button type="button" class="journey-btn journey-reveal" id="ul-journey-reveal" aria-label="Reveal the answer to this recall question">I'm stuck - show me</button>
                    <p class="journey-retrieve-answer" id="ul-journey-answer" hidden></p>
                </div>
                <p class="journey-action-feedback" id="ul-journey-feedback" hidden aria-live="polite"></p>
                <div class="journey-controls" id="ul-journey-controls" hidden>
                    <button type="button" class="journey-btn journey-back" id="ul-journey-back" aria-label="Go back one step">Back</button>
                    <button type="button" class="journey-btn journey-continue" id="ul-journey-continue" aria-label="Continue to the next step" disabled>Continue</button>
                    <button type="button" class="journey-btn journey-deep" id="ul-journey-deep" aria-label="Expand the full technical reference">Deep dive - the full technical reference</button>
                    <button type="button" class="journey-btn journey-pause" id="ul-journey-pause" aria-label="Pause and save this step">Pause / take a break</button>
                    <button type="button" class="journey-btn journey-return" id="ul-journey-return" aria-label="Return to the guided journey" hidden>Return to guided journey</button>
                </div>
                <div class="journey-paused" id="ul-journey-paused" hidden>
                    <p class="journey-paused-line">Paused. Your place is saved on this device.</p>
                    <button type="button" class="journey-btn journey-resume" id="ul-journey-resume" aria-label="Resume the guided journey from the saved step">Resume where I left off</button>
                </div>
                <div class="journey-finish" id="ul-journey-finish" hidden>
                    <h2 class="journey-finish-head">What you can now do</h2>
                    <p class="journey-finish-line" id="ul-journey-can"></p>
                    <a class="journey-btn journey-nextlesson" id="ul-journey-nextlesson" hidden>Next lesson</a>
                    <button type="button" class="journey-btn journey-deep-finish" id="ul-journey-deep-finish" aria-label="Expand the full technical reference">Deep dive - the full technical reference</button>
                </div>
            </div>
        }
    }

    public func render_journey_css(page : &mut HtmlPage) {
        #css {
            .journey-shell { max-width: 760px; margin: 1.5rem auto 2.5rem; font-family: system-ui, -apple-system, sans-serif; line-height: 1.65; color: #111827; }
            .journey-shell [hidden] { display: none !important; }
            .journey-arrival { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 2rem; text-align: center; }
            .journey-aim { font-size: 1.15rem; margin: 0 0 0.75rem; max-width: 54ch; margin-left: auto; margin-right: auto; }
            .journey-arrival-meta { color: #475569; font-size: 0.9rem; margin: 0 0 1.25rem; }
            .journey-ribbon { display: flex; flex-wrap: wrap; gap: 0.4rem 1.25rem; align-items: baseline; padding: 0.75rem 1rem; margin-bottom: 1.25rem; border-bottom: 1px solid #e2e8f0; font-size: 0.86rem; color: #475569; }
            .journey-count { font-weight: 700; color: #1e293b; }
            .journey-purpose { color: #2563eb; font-weight: 600; }
            .journey-next { margin-left: auto; }
            .journey-stage { min-height: 4rem; }
            .journey-stage .unit { margin-bottom: 1.25rem; }
            .journey-detail-btn { display: block; margin: 0.75rem 0; }
            .journey-remember { margin-top: 1.5rem; padding: 1.25rem; border: 1px solid #cbd5e1; border-left: 4px solid #2563eb; border-radius: 10px; background: #f8fafc; }
            .journey-remember-label { display: block; font-weight: 700; font-size: 0.95rem; margin-bottom: 0.5rem; }
            .journey-keypoint { margin: 0 0 0.75rem; font-size: 0.92rem; color: #334155; max-width: 68ch; }
            .journey-note { width: 100%; box-sizing: border-box; padding: 0.6rem 0.75rem; border: 1px solid #94a3b8; border-radius: 6px; font: inherit; font-size: 0.95rem; background: #ffffff; color: #111827; }
            .journey-words { display: block; margin-top: 0.35rem; font-size: 0.8rem; color: #64748b; }
            .journey-retrieve { margin-top: 1rem; padding: 1rem 1.25rem; border: 1px solid #e2e8f0; border-radius: 10px; }
            .journey-retrieve-ask { margin: 0 0 0.75rem; font-size: 0.95rem; }
            .journey-retrieve-answer { margin: 0.75rem 0 0; font-size: 0.92rem; color: #334155; }
            .journey-action-feedback { margin: 1rem 0 0; padding: 0.75rem 1rem; border-left: 3px solid #64748b; background: #f8fafc; color: #334155; font-size: 0.92rem; }
            .journey-deep .journey-action-feedback { display: none !important; }
            .journey-controls { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: center; margin-top: 1.5rem; padding-top: 1.25rem; border-top: 1px solid #e2e8f0; }
            .journey-btn { padding: 0.55rem 1rem; border: 1px solid #94a3b8; border-radius: 8px; background: #ffffff; color: #1e293b; font: inherit; font-size: 0.9rem; cursor: pointer; text-decoration: none; }
            .journey-btn:hover:not(:disabled) { border-color: #2563eb; background: #eff6ff; text-decoration: none; }
            .journey-btn:disabled { opacity: 0.55; cursor: not-allowed; }
            .journey-start, .journey-continue { background: #2563eb; border-color: #2563eb; color: #ffffff; font-weight: 600; }
            .journey-start:hover, .journey-continue:hover:not(:disabled) { background: #1d4ed8; color: #ffffff; }
            .journey-reveal { border-color: #cbd5e1; color: #475569; }
            .journey-paused { padding: 1.5rem; text-align: center; border: 1px dashed #94a3b8; border-radius: 10px; }
            .journey-paused-line { margin: 0 0 1rem; color: #475569; }
            .journey-finish { padding: 1.5rem; border: 1px solid #cbd5e1; border-radius: 12px; background: #f8fafc; text-align: center; }
            .journey-finish-head { font-size: 1.2rem; margin: 0 0 0.5rem; }
            .journey-finish-line { font-size: 1rem; max-width: 60ch; margin: 0 auto 1.25rem; }
            .journey-start-panel { max-width: 760px; margin: 1.25rem auto 2rem; padding: 1.5rem; border: 1px solid #cbd5e1; border-left: 4px solid #2563eb; border-radius: 12px; background: #f8fafc; font-family: system-ui, sans-serif; }
            .journey-start-eyebrow { margin: 0 0 0.35rem; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; color: #2563eb; font-weight: 700; }
            .journey-start-line { margin: 0 0 1rem; font-size: 1.05rem; max-width: 60ch; }
            .journey-start-note { margin: 0.75rem 0 0; font-size: 0.85rem; color: #475569; }
            .journey-deep .journey-arrival, .journey-deep .journey-ribbon, .journey-deep .journey-remember, .journey-deep .journey-retrieve, .journey-deep .journey-paused, .journey-deep .journey-finish { display: none !important; }
            .journey-deep .journey-back, .journey-deep .journey-continue, .journey-deep .journey-pause, .journey-deep .journey-deep { display: none !important; }
            .journey-deep .journey-return { display: inline-block !important; }
            .journey-shell :focus-visible { outline: 3px solid #1d4ed8; outline-offset: 2px; }
            .lesson.high-contrast .journey-shell { color: #ffffff; }
            .lesson.high-contrast .journey-shell .journey-arrival, .lesson.high-contrast .journey-shell .journey-remember, .lesson.high-contrast .journey-shell .journey-finish { background: #000000; border-color: #ffffff; }
            .lesson.high-contrast .journey-shell .journey-btn { background: #000000; color: #ffffff; border-color: #ffffff; }
            .lesson.high-contrast .journey-shell .journey-note { background: #000000; color: #ffffff; border-color: #ffffff; }
            .lesson.reduced-motion .journey-shell { transition: none; animation: none; }
            @media (prefers-reduced-motion: reduce) { .journey-shell { transition: none; animation: none; } }
            @media (prefers-contrast: more) { .journey-arrival { border-color: #000000; } .journey-btn { border-color: #000000; } }
            @media (max-width: 640px) { .journey-shell { margin: 1rem; } .journey-arrival { padding: 1.25rem; } .journey-next { margin-left: 0; } .journey-controls { flex-direction: column; align-items: stretch; } }
        }
    }

    // One entry point so every consumer gets the same four script blocks.  The
    // boot call lives in the runtime block, which comes last: function
    // declarations hoist inside the one <script> the page library emits.
    public func render_journey_js(page : &mut HtmlPage) {
        render_journey_units_js(page)
        render_journey_actions_js(page)
        render_journey_pacing_js(page)
        render_journey_runtime_js(page)
    }
}
