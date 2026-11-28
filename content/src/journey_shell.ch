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
    // Pre-paint mode flag. This is a RAW head script (like theme_boot.ch),
    // because the CSS that hides the non-current units must apply on the FIRST
    // paint, not after the end-of-body runtime has run. With scripting off the
    // class is never added and the whole lesson stays visible -- the required
    // backend-optional fallback.
    public func render_journey_boot_head(page : &mut HtmlPage) {
        var boot = string("<script>document.documentElement.classList.add('journey-active');</script>")
        var bv = boot.to_view()
        page.append_head_view(&bv)
    }

    public func render_journey_markup(page : &mut HtmlPage) {
        render_journey_boot_head(page)
        #html {
            <div class="journey-shell" id="ul-journey" data-course="" data-concept="" data-minutes="" data-difficulty="" data-prereq="" hidden>
                <div class="journey-arrival" id="ul-journey-arrival">
                    <p class="journey-aim" id="ul-journey-aim">In this step you will be able to work through this lesson one idea at a time.</p>
                    <p class="journey-arrival-meta" id="ul-journey-meta" hidden></p>
                    <div class="journey-energy" id="ul-journey-energy" role="group" aria-label="How are you feeling?">
                        <span class="journey-energy-label">How are you feeling?</span>
                        <button type="button" class="journey-energy-btn" data-energy="ready" aria-pressed="false">Ready</button>
                        <button type="button" class="journey-energy-btn" data-energy="okay" aria-pressed="true">Okay</button>
                        <button type="button" class="journey-energy-btn" data-energy="low-energy" aria-pressed="false">Low energy</button>
                    </div>
                    <div class="journey-energy" id="ul-journey-duration" role="group" aria-label="Session length">
                        <span class="journey-energy-label">Session length</span>
                        <button type="button" class="journey-energy-btn" data-minutes="5" aria-pressed="false">5 min</button>
                        <button type="button" class="journey-energy-btn" data-minutes="10" aria-pressed="true">10 min</button>
                        <button type="button" class="journey-energy-btn" data-minutes="20" aria-pressed="false">20 min</button>
                    </div>
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
                    <p class="journey-retrieve-answer" id="ul-journey-answer" aria-live="polite" hidden></p>
                    <p class="journey-retrieve-ask journey-ask-earlier" id="ul-journey-ask-earlier" hidden></p>
                    <button type="button" class="journey-btn journey-reveal" id="ul-journey-reveal-earlier" aria-label="Reveal the answer to the earlier recall question" hidden>I'm stuck - show me</button>
                    <p class="journey-retrieve-answer" id="ul-journey-answer-earlier" aria-live="polite" hidden></p>
                </div>
                <p class="journey-action-feedback" id="ul-journey-feedback" hidden aria-live="polite"></p>
                <div class="journey-controls" id="ul-journey-controls" hidden>
                    <button type="button" class="journey-btn journey-back" id="ul-journey-back" aria-label="Go back one step">Back</button>
                    <button type="button" class="journey-btn journey-continue" id="ul-journey-continue" aria-label="Continue to the next step" disabled>Continue</button>
                    <button type="button" class="journey-btn journey-deep" id="ul-journey-deep" aria-label="Expand the full technical reference">Deep dive - the full technical reference</button>
                    <button type="button" class="journey-btn journey-pause" id="ul-journey-pause" aria-label="Pause and save this step">Pause / take a break</button>
                    <button type="button" class="journey-btn journey-return" id="ul-journey-return" aria-label="Return to the guided journey" hidden>Return to guided journey</button>
                    <details class="journey-display" id="ul-journey-display">
                        <summary>Display &amp; accessibility</summary>
                        <div class="journey-display-slot" id="ul-journey-display-slot"></div>
                    </details>
                </div>
                <div class="journey-paused" id="ul-journey-paused" hidden>
                    <p class="journey-paused-line">Paused. Your place is saved on this device.</p>
                    <button type="button" class="journey-btn journey-resume" id="ul-journey-resume" aria-label="Resume the guided journey from the saved step">Resume where I left off</button>
                </div>
                <div class="journey-break" id="ul-journey-break" hidden role="status">
                    <h3>Take a break — progress saved</h3>
                    <p>You can stop here. Coming back will restore this exact step.</p>
                    <button type="button" class="journey-btn journey-break-resume" id="ul-journey-break-resume">Continue anyway</button>
                </div>
                <div class="journey-finish" id="ul-journey-finish" hidden>
                    <h2 class="journey-finish-head" id="ul-journey-finish-head">What you can now do</h2>
                    <p class="journey-finish-line" id="ul-journey-can"></p>
                    <a class="journey-btn journey-nextlesson" id="ul-journey-nextlesson" hidden>Next lesson</a>
                    <button type="button" class="journey-btn journey-deep-finish" id="ul-journey-deep-finish" aria-label="Expand the full technical reference">Deep dive - the full technical reference</button>
                </div>
            </div>
        }
    }

    // THE JOURNEY'S PALETTE IS THE FLEET'S PALETTE.
    // Every colour below is a brand token defined by the shared nav stylesheet
    // on every page, with `.dark` overrides there. The old hardcoded light
    // values made a lesson a white card sitting on a dark body; a learner who
    // toggled dark mode met unreadable panels. There are no lesson-only
    // tokens: --primary is 11 100% 60% in both themes, and --card / --foreground
    // / --muted-foreground flip together.
    public func render_journey_css(page : &mut HtmlPage) {
        #css {
            .journey-shell { max-width: 68ch; margin: 1.5rem auto 2.5rem; font-family: var(--font-sans); font-size: 1rem; line-height: 1.6; color: hsl(var(--foreground)); }
            .journey-shell [hidden] { display: none !important; }
            html .lesson:not(.high-contrast) .unit, html .lesson:not(.high-contrast) .quiz-option, html .lesson:not(.high-contrast) .fill-blank, html .lesson:not(.high-contrast) .fill-check-btn, html .lesson:not(.high-contrast) .exercise-option, html .lesson:not(.high-contrast) .tf-option, html .lesson:not(.high-contrast) .recognize-option, html .lesson:not(.high-contrast) th, html .lesson:not(.high-contrast) code, html .lesson:not(.high-contrast) .toc, html .lesson:not(.high-contrast) .shortcuts-dialog { background: hsl(var(--card)); color: hsl(var(--foreground)); border-color: hsl(var(--border)); }
            html .lesson:not(.high-contrast) .unit { border-left-color: hsl(var(--primary)); }
            .journey-arrival { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; text-align: center; color: hsl(var(--foreground)); }
            .journey-aim { font-size: 1.15rem; margin: 0 0 0.75rem; max-width: 68ch; margin-left: auto; margin-right: auto; line-height: 1.6; }
            .journey-arrival-meta { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0 0 1.25rem; }
            .journey-energy { display: flex; flex-wrap: wrap; gap: 0.4rem; justify-content: center; align-items: center; margin: 0 0 0.75rem; }
            .journey-energy-label { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin-right: 0.25rem; }
            .journey-energy-btn { border: 1px solid hsl(var(--border)); border-radius: 999px; background: hsl(var(--card)); color: hsl(var(--foreground)); padding: 0.35rem 0.7rem; font-size: 0.8rem; cursor: pointer; }
            .journey-energy-btn[aria-pressed="true"] { border-color: hsl(var(--primary)); color: hsl(var(--primary)); background: hsl(var(--primary) / 8%); }
            .journey-break { border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--primary)); border-radius: 10px; background: hsl(var(--card)); color: hsl(var(--foreground)); padding: 1.25rem; margin-top: 1rem; text-align: center; }
            .journey-break h3 { margin: 0 0 0.5rem; font-size: 1.1rem; }
            .journey-break p { color: hsl(var(--muted-foreground)); margin: 0 0 1rem; }
            .journey-ribbon { display: flex; flex-wrap: wrap; gap: 0.4rem 1.25rem; align-items: baseline; padding: 0.75rem 1rem; margin-bottom: 1.25rem; border-bottom: 1px solid hsl(var(--border)); font-size: 0.9rem; color: hsl(var(--muted-foreground)); }
            .journey-count { font-weight: 700; color: hsl(var(--foreground)); }
            .journey-purpose { color: hsl(var(--primary)); font-weight: 600; }
            .journey-next { margin-left: auto; }
            .journey-stage { min-height: 4rem; }
            .journey-stage .unit { margin-bottom: 1.25rem; }
            .journey-detail-btn { display: block; margin: 0.75rem 0; }
            .journey-remember { margin-top: 1.5rem; padding: 1.25rem; border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--primary)); border-radius: 10px; background: hsl(var(--card)); color: hsl(var(--foreground)); }
            .journey-remember-label { display: block; font-weight: 700; font-size: 0.95rem; margin-bottom: 0.5rem; }
            .journey-keypoint { margin: 0 0 0.75rem; font-size: 1rem; color: hsl(var(--muted-foreground)); max-width: 68ch; line-height: 1.6; }
            .journey-note { width: 100%; box-sizing: border-box; padding: 0.6rem 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 6px; font: inherit; font-size: 1rem; background: hsl(var(--card)); color: hsl(var(--foreground)); }
            .journey-words { display: block; margin-top: 0.35rem; font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .journey-retrieve { margin-top: 1rem; padding: 1rem 1.25rem; border: 1px solid hsl(var(--border)); border-radius: 10px; background: hsl(var(--card)); color: hsl(var(--foreground)); }
            .journey-retrieve-ask { margin: 0 0 0.75rem; font-size: 1rem; }
            .journey-ask-earlier { margin-top: 1rem; padding-top: 0.75rem; border-top: 1px solid hsl(var(--border)); }
            .journey-retrieve-answer { margin: 0.75rem 0 0; font-size: 1rem; color: hsl(var(--muted-foreground)); }
            .journey-action-feedback { margin: 1rem 0 0; padding: 0.75rem 1rem; border-left: 3px solid hsl(var(--primary)); background: hsl(var(--accent)); color: hsl(var(--foreground)); font-size: 1rem; }
            .journey-deep .journey-action-feedback { display: none !important; }
            .journey-controls { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: center; margin-top: 1.5rem; padding-top: 1.25rem; border-top: 1px solid hsl(var(--border)); }
            .journey-btn { min-height: 2.75rem; padding: 0.6rem 1rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--card)); color: hsl(var(--foreground)); font: inherit; font-size: 1rem; cursor: pointer; text-decoration: none; }
            .journey-btn:hover:not(:disabled) { border-color: hsl(var(--primary)); background: hsl(var(--accent)); text-decoration: none; }
            .journey-btn:disabled { opacity: 0.55; cursor: not-allowed; }
            .journey-start, .journey-continue { background: hsl(var(--primary)); border-color: hsl(var(--primary)); color: hsl(var(--primary-foreground)); font-weight: 600; }
            .journey-start:hover, .journey-continue:hover:not(:disabled) { background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); }
            .journey-reveal { border-color: hsl(var(--border)); color: hsl(var(--muted-foreground)); }
            .journey-paused { padding: 1.5rem; text-align: center; border: 1px dashed hsl(var(--border)); border-radius: 10px; background: hsl(var(--card)); color: hsl(var(--foreground)); }
            .journey-paused-line { margin: 0 0 1rem; color: hsl(var(--muted-foreground)); }
            .journey-finish { padding: 1.5rem; border: 1px solid hsl(var(--border)); border-radius: 12px; background: hsl(var(--card)); color: hsl(var(--foreground)); text-align: center; }
            .journey-finish-head { font-size: 1.2rem; margin: 0 0 0.5rem; }
            .journey-finish-line { font-size: 1rem; max-width: 68ch; margin: 0 auto 1.25rem; }
            .journey-start-panel { max-width: 68ch; margin: 1.25rem auto 2rem; padding: 1.5rem; border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--primary)); border-radius: 12px; background: hsl(var(--card)); color: hsl(var(--foreground)); font-family: var(--font-sans); }
            .journey-start-eyebrow { margin: 0 0 0.35rem; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; color: hsl(var(--primary)); font-weight: 700; }
            .journey-start-line { margin: 0 0 1rem; font-size: 1.05rem; max-width: 68ch; }
            .journey-start-note { margin: 0.75rem 0 0; font-size: 0.9rem; color: hsl(var(--muted-foreground)); }
            .journey-display { flex-basis: 100%; margin-top: 0.75rem; }
            .journey-display > summary { cursor: pointer; font-weight: 600; min-height: 2.75rem; display: flex; align-items: center; color: hsl(var(--foreground)); }
            .journey-display-slot { display: flex; flex-direction: column; gap: 0.75rem; padding: 0.75rem 0; }
            .journey-display:not([open]) .journey-display-slot { display: none !important; }
            .journey-deep .journey-arrival, .journey-deep .journey-ribbon, .journey-deep .journey-remember, .journey-deep .journey-retrieve, .journey-deep .journey-paused, .journey-deep .journey-finish { display: none !important; }
            .journey-deep .journey-back, .journey-deep .journey-continue, .journey-deep .journey-pause, .journey-deep .journey-deep { display: none !important; }
            .journey-deep .journey-return { display: inline-block !important; }
            .journey-shell :focus-visible { outline: 3px solid hsl(var(--primary)); outline-offset: 2px; }
            html.journey-active .journey-shell[hidden] { display: block !important; }
            html.journey-active .lesson .unit:not([data-jq-current]) { display: none !important; }
            html.journey-active .lesson > h1, html.journey-active .lesson > .lesson-meta, html.journey-active .lesson > .skip-link, html.journey-active .lesson > .lesson-head, html.journey-active .lesson > .shortcuts-modal, html.journey-active .lesson > .lesson-footer { display: none !important; }
            html.journey-active .a11y-controls, html.journey-active .cb-controls, html.journey-active .reading-controls, html.journey-active .ul-signin-advisory, html.journey-active .ul-progress, html.journey-active .ul-tools, html.journey-active header[role="banner"]:empty { display: none !important; }
            html.journey-active .lesson .unit-exercises h2:not(:first-child), html.journey-active .lesson #api-exercises > h2 { display: none !important; }
            html.journey-active .journey-display-slot .a11y-controls, html.journey-active .journey-display-slot .cb-controls, html.journey-active .journey-display-slot .reading-controls { display: flex !important; }
            .lesson.high-contrast .journey-shell { color: hsl(var(--foreground)); }
            .lesson.high-contrast .journey-shell .journey-arrival, .lesson.high-contrast .journey-shell .journey-remember, .lesson.high-contrast .journey-shell .journey-finish { background: hsl(var(--card)); border-color: hsl(var(--foreground)); }
            .lesson.high-contrast .journey-shell .journey-btn { background: hsl(var(--card)); color: hsl(var(--foreground)); border-color: hsl(var(--foreground)); }
            .lesson.high-contrast .journey-shell .journey-note { background: hsl(var(--card)); color: hsl(var(--foreground)); border-color: hsl(var(--foreground)); }
            .lesson.reduced-motion .journey-shell { transition: none; animation: none; }
            @media (prefers-reduced-motion: reduce) { .journey-shell { transition: none; animation: none; } }
            @media (prefers-contrast: more) { .journey-arrival { border-color: hsl(var(--foreground)); } .journey-btn { border-color: hsl(var(--foreground)); } }
            @media (max-width: 640px) { .journey-shell { margin: 1rem; } .journey-arrival { padding: 1.5rem; } .journey-next { margin-left: 0; } .journey-controls { flex-direction: column; align-items: stretch; } }
        }
    }

    // One entry point so every consumer gets the same four script blocks.  The
    // boot call lives in the runtime block, which comes last: function
    // declarations hoist inside the one <script> the page library emits.
    public func render_journey_js(page : &mut HtmlPage) {
        render_journey_units_js(page)
        render_journey_actions_js(page)
        render_journey_pacing_js(page)
        render_journey_display_js(page)
        render_journey_runtime_js(page)
    }
}
