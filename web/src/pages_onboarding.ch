// underlayer_web — G1 onboarding v2: seven steps, no signup wall.
//
// The old flow asked for a course, a time budget and a "how it works" tour,
// then redirected anonymous visitors to /login. It never asked why the learner
// was here or what they already knew, and it had no placement. This page
// implements the seven screens in docs/user-flows.md and finishes on a real
// lesson link derived from the course manifest, not a hardcoded URL.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_onboarding_page(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        underlayer_content::render_theme_boot_js(&mut page, false)
        underlayer_content::render_color_scheme_meta(&mut page)
        var title = std::string_view("Welcome to Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="onboarding-page" id="onboarding-page">
                <div class="onboarding-card" data-onboarding="v2">
                    <div class="onboarding-brand">
                        <a href="/" class="brand-link">Underlayer</a>
                    </div>

                    <div class="step-indicator" id="stepIndicator" aria-label="Onboarding progress">
                        <div class="step-dot active" data-step="0"></div>
                        <div class="step-dot" data-step="1"></div>
                        <div class="step-dot" data-step="2"></div>
                        <div class="step-dot" data-step="3"></div>
                        <div class="step-dot" data-step="4"></div>
                        <div class="step-dot" data-step="5"></div>
                        <div class="step-dot" data-step="6"></div>
                    </div>

                    <div class="step" id="step0" data-onboarding-step="1">
                        <h1>Learn things deeply.</h1>
                        <p class="step-subtitle">One idea at a time, with a clear next step. No signup required.</p>
                        <button class="btn btn-primary" id="ob-start" onclick="obGo(1)">Start learning</button>
                        <p class="ob-quiet">About two minutes to set up.</p>
                    </div>

                    <div class="step hidden" id="step1" data-onboarding-step="2">
                        <h1>Why are you here?</h1>
                        <p class="step-subtitle">This changes how we frame your first lesson, not what you can access.</p>
                        <div class="ob-options" id="ob-goals" role="group" aria-label="Your reason for learning">
                            <button class="goal-btn" data-goal="curiosity" onclick="obPick(this, 'goal')">I'm curious how computers work</button>
                            <button class="goal-btn" data-goal="career" onclick="obPick(this, 'goal')">I need this for my career</button>
                            <button class="goal-btn" data-goal="student" onclick="obPick(this, 'goal')">I'm a student learning CS</button>
                            <button class="goal-btn" data-goal="builder" onclick="obPick(this, 'goal')">I want to build things</button>
                        </div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="obGo(0)">Back</button>
                            <button class="btn btn-primary" onclick="obGo(2)">Continue</button>
                        </div>
                    </div>

                    <div class="step hidden" id="step2" data-onboarding-step="3">
                        <h1>What do you already know?</h1>
                        <p class="step-subtitle">There is no wrong answer. You can change your route any time.</p>
                        <div class="ob-options" id="ob-prior" role="group" aria-label="Prior knowledge">
                            <button class="goal-btn" data-prior="none" onclick="obPick(this, 'prior')">Never heard of binary formats</button>
                            <button class="goal-btn" data-prior="aware" onclick="obPick(this, 'prior')">I know they exist</button>
                            <button class="goal-btn" data-prior="used_tools" onclick="obPick(this, 'prior')">I've used readelf or objdump</button>
                            <button class="goal-btn" data-prior="written_parsers" onclick="obPick(this, 'prior')">I've written parsers</button>
                        </div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="obGo(1)">Back</button>
                            <button class="btn btn-primary" onclick="obGo(3)">Continue</button>
                        </div>
                    </div>

                    <div class="step hidden" id="step3" data-onboarding-step="4">
                        <h1>How long is a session?</h1>
                        <p class="step-subtitle">A shorter session you finish beats a longer one you don't start.</p>
                        <div class="goal-options" id="ob-minutes" role="group" aria-label="Session minutes">
                            <button class="goal-btn" data-minutes="5" onclick="obPick(this, 'minutes')"><span class="goal-value">5</span><span class="goal-label">minutes</span></button>
                            <button class="goal-btn selected" data-minutes="10" onclick="obPick(this, 'minutes')"><span class="goal-value">10</span><span class="goal-label">minutes</span></button>
                            <button class="goal-btn" data-minutes="20" onclick="obPick(this, 'minutes')"><span class="goal-value">20</span><span class="goal-label">minutes</span></button>
                            <button class="goal-btn" data-minutes="45" onclick="obPick(this, 'minutes')"><span class="goal-value">45</span><span class="goal-label">minutes</span></button>
                        </div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="obGo(2)">Back</button>
                            <button class="btn btn-primary" onclick="obGo(4)">Continue</button>
                        </div>
                    </div>

                    <div class="step hidden" id="step4" data-onboarding-step="5">
                        <h1>A quick check</h1>
                        <p class="step-subtitle">Five questions from the course's verified bank. Skip if you'd rather start at the beginning.</p>
                        <div id="ob-diagnostic" class="ob-diagnostic" aria-live="polite"><p class="ob-quiet">Loading questions...</p></div>
                        <div class="step-actions">
                            <button class="btn btn-ghost" onclick="obGo(3)">Back</button>
                            <button class="btn btn-link" id="ob-skip" onclick="obSkipDiagnostic()">Skip this step</button>
                            <button class="btn btn-primary" id="ob-diagnostic-next" onclick="obFinishDiagnostic()" disabled>Continue</button>
                        </div>
                    </div>

                    <div class="step hidden" id="step5" data-onboarding-step="6">
                        <h1>Building your route</h1>
                        <p class="step-subtitle">Finding the best starting point for you.</p>
                        <div class="ob-route" id="ob-route"><div class="ob-route-bar" id="ob-route-bar"></div></div>
                        <p class="ob-quiet" id="ob-route-text">Reading your answers...</p>
                    </div>

                    <div class="step hidden" id="step6" data-onboarding-step="7">
                        <h1>Your first lesson</h1>
                        <p class="step-subtitle" id="ob-first-subtitle">Bytes and Binary · a good place to begin.</p>
                        <div class="ob-first" id="ob-first-card">
                            <h2 id="ob-first-title">Bytes and Binary</h2>
                            <p id="ob-first-note">Every piece of data in a computer is stored as bytes. This is the foundation for everything that follows.</p>
                        </div>
                        <a class="btn btn-primary" id="ob-first-link" href="/courses/elf/lessons/bytes">Start learning</a>
                    </div>
                </div>
            </div>
        }

        #css {
            .onboarding-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, -apple-system, sans-serif; padding: 1rem; }
            .onboarding-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 560px; box-shadow: 0 4px 20px hsl(var(--shadow)); text-align: center; }
            .onboarding-brand { margin-bottom: 1.25rem; }
            .brand-link { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); text-decoration: none; }
            .step-indicator { display: flex; justify-content: center; gap: 0.4rem; margin-bottom: 1.75rem; }
            .step-dot { width: 8px; height: 8px; border-radius: 50%; background: hsl(var(--border)); }
            .step-dot.active { background: hsl(217 91% 60%); width: 22px; border-radius: 4px; }
            .step { animation: obFade 0.25s ease; }
            .step.hidden { display: none; }
            @keyframes obFade { from { opacity: 0; } to { opacity: 1; } }
            .step h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .step-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.95rem; margin-bottom: 1.5rem; line-height: 1.5; }
            .ob-quiet { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin-top: 1rem; }
            .btn { display: inline-block; padding: 0.7rem 1.35rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: 1px solid transparent; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
            .btn-ghost { background: transparent; color: hsl(var(--muted-foreground)); border-color: hsl(var(--border)); }
            .btn-link { background: transparent; color: hsl(217 91% 60%); text-decoration: underline; }
            .step-actions { display: flex; justify-content: space-between; align-items: center; gap: 0.75rem; margin-top: 1.5rem; }
            .ob-options, .goal-options { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.6rem; margin-bottom: 0.5rem; }
            .goal-btn { display: flex; flex-direction: column; align-items: center; gap: 0.15rem; padding: 0.85rem 0.6rem; border: 1px solid hsl(var(--border)); border-radius: 8px; cursor: pointer; background: hsl(var(--background)); color: hsl(var(--foreground)); font-size: 0.85rem; }
            .goal-btn:hover { border-color: hsl(217 91% 60%); }
            .goal-btn.selected { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 8%); }
            .goal-value { font-size: 1.5rem; font-weight: 700; }
            .goal-label { font-size: 0.75rem; color: hsl(var(--muted-foreground)); }
            .ob-diagnostic { text-align: left; max-height: 340px; overflow-y: auto; }
            .ob-q { border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.75rem; margin-bottom: 0.75rem; }
            .ob-q p { margin: 0 0 0.5rem; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .ob-q button { display: block; width: 100%; text-align: left; border: 1px solid hsl(var(--border)); background: hsl(var(--background)); color: hsl(var(--foreground)); border-radius: 6px; padding: 0.5rem 0.65rem; margin-top: 0.35rem; cursor: pointer; font-size: 0.85rem; }
            .ob-q button.selected { border-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 8%); }
            .ob-route { height: 8px; border-radius: 4px; background: hsl(var(--muted)); overflow: hidden; }
            .ob-route-bar { height: 100%; width: 35%; background: hsl(217 91% 60%); transition: width 0.5s ease; }
            .ob-first { border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 1rem; margin-bottom: 1.25rem; text-align: left; }
            .ob-first h2 { font-size: 1.1rem; margin: 0 0 0.5rem; }
            .ob-first p { color: hsl(var(--muted-foreground)); font-size: 0.9rem; line-height: 1.5; margin: 0; }
            @media (max-width: 480px) { .onboarding-card { padding: 1.5rem; } .step-actions { flex-wrap: wrap; } }
        }

        render_onboarding_js(&mut page)
        var html_out = page.toString()
        return underlayer_web::send_html(&html_out)
    }

}
