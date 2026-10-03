// underlayer_web — THE SIGN-IN GATE, for pages that only exist once you have
// an account.
//
// WHAT THIS IS FOR, and the measurement that prompted it.
//
// Asked "is it ready for production", with the observation: a visitor can open
// /dashboard. Stripped of its markup, a signed-out visit to /dashboard reads:
//
//     Dashboard  Where you are, and what to do next
//     Concepts in elf  24   Read 0   Learned 0   Review due 0
//     Course progress  0 of 24 concepts read
//     Mastery 0%   Depth 0.000% understanding   Breadth 0.000% coverage
//     Review Queue  New: 0  Due: 0  Mastered: 0
//
// Thirty-eight numbers, all of them zero, none of them the reader's. There is
// nothing to store about a signed-out visitor, so there is nothing to show --
// and a wall of zeroes reads as "you are failing at this" rather than "you are
// not signed in". The design rules in docs/course-design.md are explicit that
// this collection must normalise struggle; a page of zeroes does the opposite.
//
// The same applies to the ONBOARDING banner added on / and /dashboard: it
// appeared on the signed-out page too, telling a visitor with no account to
// "finish setting up your account".
//
// WHY SERVER-SIDE AND NOT A CLIENT-SIDE SWAP.
//
// Two reasons, and the first is the important one.
//
//   1. The page must be CORRECT BEFORE ANY SCRIPT RUNS.  A client-side gate
//      means the signed-out visitor receives a full dashboard of zeroes, waits
//      for the JS, and then has it replaced. On a slow connection they read the
//      zeroes first. A server-side gate means the HTML that arrives IS the
//      gate page. This is the same reasoning the onboarding banner uses for
//      shipping `hidden`, and the same rule the collection follows for the
//      pre-rendered static pages: they must work from file:// with no server.
//
//   2. `auth_get_learner_id` can only be called HERE.  The pages below decide
//      their own `demo` fallback by asking for a learner id they were never
//      given, which is precisely why a signed-out visitor lands in a shared
//      bucket at all. The gate removes the fallback for the pages that need an
//      account, instead of trying to hide the symptom downstream.
//
// WHAT IS *NOT* GATED, and why the line is drawn there.
//
//   * Course landing pages and lesson pages: these are the product. A person
//     who has never heard of Underlayer must be able to read a lesson and
//     decide whether to sign up. Gating those would be gating the shop window.
//     They get the SHORT advisory instead (pages_gate.ch) -- a sentence, a
//     button, and nothing else.
//   * /search and the course index: public by design.
//   * /home: public, with the advisory.
//
// WHY A GATE PAGE AND NOT A REDIRECT.
//
// A redirect to /login would be simpler and it is wrong here, for the same
// reason the 401 handler does not redirect off /login itself: it would throw
// away where the reader was, and it would make the browser's back button
// oscillate. Instead the gate renders in place, names what signing in gets, and
// carries the original path as `next` so that signing in returns them to it.
// The reader sees the same page chrome, the same nav and the same URL -- only
// the body differs.
//
// NO LEAK.  Nothing in this file reads or writes learner data. It asks exactly
// one question -- is there a valid session token -- and renders one of two
// bodies. tools/auth_gate_check.py asserts that the gate page contains no
// concept counts, no progress percentages and no learner identity, so this
// cannot quietly start showing someone's numbers.
using std::string
using underlayer_db::DbClient

public namespace underlayer_web {

    // True when `req` carries a session token that resolves to a real learner.
    // A token that is absent, malformed, expired or revoked all read as signed
    // out, which is the point: a stale token must not leave the reader on a page
    // that will 401 every request it makes.
    public func has_session(db : *DbClient, req : &http::Request) : bool {
        var learner_id = auth_get_learner_id(db, req)
        return learner_id.size() > 0
    }

    // Emit the sign-in gate into `page`.  `path` is the page the reader was
    // trying to reach, and becomes `?next=` so signing in returns them to it.
    //
    // The copy is deliberately short. The design rules forbid a wall of text on
    // a page that is meant to be a page, and the reader who hit a gate has just
    // been told they cannot do the thing they came to do -- a paragraph about it
    // is not a kindness.
    public func render_auth_gate(page : &mut HtmlPage, path : &string, feature : &string) {
        var next = string("/login?next=")
        var path_esc = underlayer_core::html_escape(path)
        next.append_view(path_esc.to_view())
        var next_v = next.to_view()

        var feature_esc = underlayer_core::html_escape(feature)
        var feature_v = feature_esc.to_view()

        #html {
            <div class="ul-gate-page" id="ul-gate-page">
                <div class="ul-gate-card">
                    <div class="ul-gate-icon" aria-hidden="true">
                        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="3" y="11" width="18" height="10" rx="2"></rect>
                            <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
                        </svg>
                    </div>
                    <h1 class="ul-gate-title">Sign in to use {feature_v}</h1>
                    <p class="ul-gate-why">Your progress, notes and review schedule are kept with your account.</p>
                    <div class="ul-gate-actions">
                        <a class="ul-gate-primary" href={next_v}>Sign in</a>
                        <a class="ul-gate-secondary" href="/register?next={path_esc}">Create an account</a>
                    </div>
                    <p class="ul-gate-foot">Reading is always free &mdash; no account needed.</p>
                </div>
            </div>
        }
        render_auth_gate_css(page)
    }

    // Render the gate as a COMPLETE page and write it.
    //
    // A standalone function rather than a branch inside each page's builder,
    // for the reason the whole file header argues: a gate copied into eleven
    // page builders is a gate that will be applied to /login by somebody
    // eventually, and the only real defence against that is one definition with
    // a short list of callers.
    //
    // It carries the SAME nav as every other page, deliberately. The reader is
    // not on an error screen -- they are on the page they asked for, and can
    // navigate away without going through the gate. A gate with no nav is a
    // dead end, and a dead end on a learning site is the one thing worse than
    // the zeroes it replaced.
    public func send_auth_gate(res : *mut http::ResponseWriter, path : &string, feature : &string) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = string("Sign in — Underlayer")
        var tv = title.to_view()
        page.appendTitle(&tv)
        render_nav_bar(&mut page)

        #html {
            <main class="container" id="main-content">
                {render_auth_gate(&mut page, path, feature)}
            </main>
        }

        var out = page.toString()
        var ov = out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        apply_security_headers(res)
        res.write_view(&ov)
    }

    // WHY THIS BLOCK USES `--nav-*` AND NOT THE SHADCN TOKENS.
    //
    // The gate was written with `var(--border, hsl(var(--nav-border)))` and
    // friends, on the assumption that the fallback would carry it on a page
    // without the components theme.  css_cbi drops the second argument, so the
    // served rule was `border: 1px solid var(--border)` with `--border`
    // undefined -- and the gate is shown to exactly the readers least likely to
    // have a components theme loaded, because the gate only appears when there
    // is no session.
    //
    // `--nav-*` is defined on `:root` by the nav component on EVERY page in both
    // layers, so it is the one set of tokens this can rely on without a
    // conditional.  `render_auth_gate` calls `render_nav_bar`, so those tokens
    // are guaranteed present on the page that carries this stylesheet.
    public func render_auth_gate_css(page : &mut HtmlPage) {
        #css {
            .ul-gate-page { display: flex; justify-content: center; padding: 4rem 1.5rem 5rem; }
            .ul-gate-card { max-width: 26rem; width: 100%; text-align: center; border: 1px solid hsl(var(--nav-border)); border-radius: 12px; padding: 2.5rem 2rem; background: hsl(var(--nav-card)); }
            .ul-gate-icon { color: hsl(217 91% 60%); margin-bottom: 1rem; }
            .ul-gate-title { font-size: 1.35rem; font-weight: 700; margin: 0 0 0.5rem; color: hsl(var(--nav-fg)); }
            .ul-gate-why { margin: 0 0 1.75rem; color: hsl(var(--nav-muted)); font-size: 0.95rem; line-height: 1.5; }
            .ul-gate-actions { display: flex; gap: 0.6rem; justify-content: center; flex-wrap: wrap; }
            .ul-gate-primary { background: hsl(217 91% 60%); color: white; text-decoration: none; font-weight: 600; font-size: 0.95rem; padding: 0.6rem 1.3rem; border-radius: 8px; }
            .ul-gate-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            .ul-gate-secondary { border: 1px solid hsl(var(--nav-border)); color: hsl(var(--nav-fg)); text-decoration: none; font-weight: 600; font-size: 0.95rem; padding: 0.6rem 1.3rem; border-radius: 8px; }
            .ul-gate-secondary:hover { text-decoration: none; background: hsl(var(--nav-accent)); }
            .ul-gate-foot { margin: 1.75rem 0 0; font-size: 0.82rem; color: hsl(var(--nav-muted)); }
        }
    }

}