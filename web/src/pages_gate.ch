// underlayer_web — THE ONBOARDING GATE MARKUP, in one component.
//
// WHAT THIS CLOSES.  (7.1.20, and 11.2.17's server half.)
//
// GET /api/onboarding/check shipped, answers
//   {"completed": false, "authenticated": true}
// correctly, and was called from NO page on the platform.  POST
// /api/onboarding/complete worked too.  So the entire onboarding flow existed
// and was reachable only by typing /onboarding -- and registration sent every
// new learner to `/` instead, which is a page that assumes a course has been
// chosen.  The result is the worst shape a signup can have: the account is
// created, the learner is told they are signed in, and they land on a dashboard
// full of zeroes belonging to a course they never picked.
//
// WHY A COMPONENT AND NOT A BLOCK IN EACH PAGE.  Two pages call it (/ and
// /dashboard) and a third kind of page -- any future authenticated landing page
// -- will too.  A gate copied per page is a gate that will be applied to /login
// by somebody eventually, and the guard against that is one definition with a
// short list of callers, not three copies each with its own idea of the
// exception list.
//
// THE `hidden` ATTRIBUTE IS NOT OPTIONAL.  The gate is a banner that appears
// for gated learners.  Rendering it visible and hiding it from JS after load
// means every signed-out visitor sees a flash of "finish setting up your
// account" before the script removes it -- and, on a static file:// page with
// no server at all, the script never runs and the banner stays visible
// permanently, telling an anonymous reader to sign in.  So it ships hidden and
// only ever becomes visible when the check has actually said yes.  The
// backend-optional rule is the reason: the page must be correct before any
// JavaScript runs.
//
// WHY THE ESCAPE BUTTON IS THERE.  A gate that cannot be dismissed is a trap.
// If the check is wrong -- a learner whose onboarding record was lost, or whose
// chosen course no longer exists -- they would be locked out of their own
// account with no way back.  "Skip for now" is one link to /courses, and it is
// the difference between a gate and a wall.
public namespace underlayer_web {

    public func render_onboarding_gate(page : &mut HtmlPage) {
        #html {
            <div class="ul-onboarding-gate" id="ul-onboarding-gate" hidden>
                <div class="ul-gate-inner">
                    <strong>Finish setting up your account</strong>
                    <span class="ul-gate-text">Pick a course and tell us how you learn best.</span>
                    <a class="ul-gate-cta" href="/onboarding">Set up now</a>
                    <a class="ul-gate-skip" href="/courses">Skip for now</a>
                </div>
            </div>
        }
        render_onboarding_gate_css(page)
        render_onboarding_gate_js(page)
    }

    public func render_onboarding_gate_css(page : &mut HtmlPage) {
        #css {
            .ul-onboarding-gate { background: hsl(217 91% 60% / 10%); border: 1px solid hsl(217 91% 60% / 35%); border-radius: 10px; margin: 1rem 0 1.5rem; }
            .ul-gate-inner { display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem 0.9rem; padding: 0.85rem 1.1rem; }
            .ul-gate-text { color: hsl(220 9% 46%); font-size: 0.9rem; }
            .ul-gate-cta { background: hsl(217 91% 60%); color: white; text-decoration: none; font-size: 0.85rem; font-weight: 600; padding: 0.4rem 0.9rem; border-radius: 6px; }
            .ul-gate-cta:hover { text-decoration: none; background: hsl(217 91% 50%); }
            .ul-gate-skip { color: hsl(220 9% 46%); font-size: 0.85rem; text-decoration: underline; }
        }
    }

    public func render_onboarding_gate_js(page : &mut HtmlPage) {
        #js {
            window.__ulPaintGate = function(blocked) {
                var gate = document.getElementById('ul-onboarding-gate');
                if (!gate) { return; }
                // ONLY ever unhide.  Never re-hide on a later answer: a second
                // check arriving late must not yank the banner away from a
                // learner who is already reading it.
                if (blocked) { gate.hidden = false; }
            };

            window.addEventListener('DOMContentLoaded', function() {
                // No token -> no request, no banner.  This is what keeps a
                // signed-out visitor and an offline file:// reader from ever
                // being told to finish setting up an account.
                if (typeof window.__ulToken !== 'function') { return; }
                if (window.__ulToken().length === 0) { return; }
                // __ulGate answers; the caller decides.  Here the decision is
                // "paint the banner, do not navigate" -- a learner who clicks
                // "Set up now" is the one who goes to /onboarding.  A forced
                // redirect would take the page away from someone who may have
                // arrived by clicking a bookmark.
                window.__ulGate().then(function(blocked) {
                    window.__ulPaintGate(blocked);
                });
            });
        }
    }

}