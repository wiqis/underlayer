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
// WHY A REDIRECT, AND WHY THAT CHANGED.   [2026-10-03]
//
// This file used to argue for rendering a sign-in card IN PLACE, and the
// argument was:
//
//   "A redirect to /login would be simpler and it is wrong here ... it would
//    throw away where the reader was, and it would make the browser's back
//    button oscillate."
//
// Neither half held up.
//
//   * The path was never at risk. The card already carried the original path as
//     `?next=`, so the destination was preserved by the version being replaced.
//   * There is no cycle to oscillate in, because `/login` does NOT bounce a
//     signed-in visitor -- checked in pages_auth.ch, which only navigates on a
//     successful submit. A reader who follows /review -> /login and signs in
//     lands back on /review via `next`, and the back button goes to /login,
//     which is where they came from.
//
// What the argument missed was the cost of the alternative. A reader who asked
// for their review queue got a page titled "Sign in to use review sessions",
// served AT `/review`, with the site nav above it. That page cannot be
// bookmarked, cannot be shared, and cannot be linked to: opening the link again
// lands on the same dead end. It reads as a broken feature rather than as a
// missing account -- which is precisely the failure this file was written to
// prevent when it replaced a dashboard full of zeroes. The card solved "don't
// show me someone else's numbers" and created "this page does not work".
//
// So it is a redirect, and the URL is honest: `/review` says you need an
// account, `/login` is where you sign in, and `next` brings you back.
//
// THE PROPERTY THAT SURVIVED THE CHANGE.  Server-side. The redirect happens
// before any query runs, so a signed-out reader never receives the page and
// never receives its data. That was the reason the gate was server-side in the
// first place -- a client-side swap would send the full page first and correct
// it afterwards, so on a slow connection the reader sees the content before the
// script hides it. Redirecting preserves that exactly.
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

    // Send the reader to /login, carrying where they were so signing in returns
    // them to it.
    //
    // 303 rather than 302: the destination is a page to be READ, not a resource
    // to be re-fetched, and 303 says that without depending on the original
    // method. Every caller today is a GET so the two behave identically, but 303
    // is what stays correct if a POST ever reaches this.
    //
    // THE PATH IS ESCAPED. `path` comes from a literal at every call site today,
    // but it lands in a header, and a raw CR or LF inside a Location header is a
    // response-splitting primitive. `html_escape` is what this layer already uses
    // for the same value.
    //
    // `next` is validated on the FAR side, not here: session_js.ch's
    // `__ulNextPath` rejects anything that is not a single leading `/`, so
    // `//evil.example` -- protocol-relative, and it would leave the site -- could
    // not be honoured even if it were somehow constructed here.
    public func redirect_to_login(res : *mut http::ResponseWriter, path : &string) {
        var esc = underlayer_core::html_escape(path)
        var loc = string("/login?next=")
        loc.append_string(&esc)

        res.status = 303u
        var loc_view = loc.to_view()
        res.set_header_view(std::string_view("Location"), &loc_view)
        apply_security_headers(res)

        // A body, because a 303 with none is legal and some clients render a
        // blank page instead of following. It repeats the link, so a reader whose
        // client does not follow still has somewhere to go -- and it is a
        // complete, self-contained document, which is why it sets its own body
        // margin rather than relying on a page stylesheet that a redirect target
        // will replace a moment later anyway.
        var page = HtmlPage()
        page.defaultPrepare()
        #html {
            <main class="container" id="main-content">
                <h1>Signing in first</h1>
                <p>This page keeps your progress, so it needs an account. Taking you to the sign-in page &mdash; you will come straight back here afterwards.</p>
                <p class="gate-go"><a href={loc_view}>Continue to sign in</a></p>
            </main>
        }
        #css {
            body { margin: 0; font-family: system-ui, sans-serif; line-height: 1.6; color: #111827; background: #ffffff; }
            .container { max-width: 34rem; margin: 0 auto; padding: 4rem 1.5rem; }
            h1 { font-size: 1.4rem; margin: 0 0 0.75rem; }
            p { margin: 0 0 1rem; color: #4b5563; }
            .gate-go { margin: 1.5rem 0 0; }
            a { color: #2563eb; }
        }
        var out = page.toString()
        var ov = out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&ov)
    }

}