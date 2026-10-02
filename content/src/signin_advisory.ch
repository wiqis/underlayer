// underlayer_content — THE SIGN-IN ADVISORY, for a page a signed-out reader CAN
// use.
//
// WHY THIS LIVES IN content/ AND NOT IN web/src/pages_auth_gate.ch, where the
// GATE lives.  The gate is for platform pages, all of which are built in web/.
// The advisory is for the 398 lesson pages, which are built in content/ -- the
// layer BELOW web, which cannot import web.  Splitting the two is not tidiness:
// they are different decisions about different kinds of page, and the layer
// boundary is what stops the advisory ever being applied to /login.
//
// WHY IT IS AN ADVISORY AND NOT A GATE.  A reader who has never heard of this
// platform has to be able to open a lesson and decide whether it is worth an
// account. Gating the lesson would be gating the only thing there is to see, and
// the sign-up decision it is supposed to invite would never be made. So the
// lesson is intact, and this is one line under the nav that can be ignored.
//
// WHY IT IS HIDDEN IN THE MARKUP.  It is revealed by the /api/auth/me call the
// nav's identity loader already makes, so this adds NO REQUEST to any page. And
// shipping it hidden means a signed-in reader never sees a flash of a prompt
// aimed at somebody else, and a page opened from disk with no server never sees
// it at all -- which is the backend-optional rule, the same one the onboarding
// banner follows.
//
// WHY THE COPY IS THIS SHORT.  The instruction was "keep the advice short, take
// them to sign in/register when the user clicks". One sentence, one button, one
// quieter link. A paragraph explaining what an account is for would be a wall
// in the middle of a lesson, and the reader who is unsure can read a lesson
// first and decide afterwards -- which is why the advisory sits BELOW the nav
// rather than over the content.
//
// The `next` on both links points at "/" because a statically pre-rendered page
// has no way to know its own path at build time; on a served page the sign-in
// handler's own `next` handling takes over from the query string. That is a
// deliberate limit, not an oversight: guessing a path that is wrong on 398 pages
// would be worse than always returning to the course index.
using std::string

public namespace underlayer_content {

    public func render_signin_advisory(page : &mut HtmlPage) {
        #html {
            <div class="ul-signin-advisory" id="ul-signin-advisory" hidden>
                <span class="ul-advisory-text">Sign in to keep your progress across lessons.</span>
                <a class="ul-advisory-cta" href="/login?next=%2F">Sign in</a>
                <a class="ul-advisory-alt" href="/register">or create an account</a>
            </div>
        }
        render_signin_advisory_css(page)
    }

    public func render_signin_advisory_css(page : &mut HtmlPage) {
        #css {
            .ul-signin-advisory { display: flex; align-items: center; justify-content: center; gap: 0.6rem; flex-wrap: wrap; margin: 0.75rem auto; max-width: 52rem; padding: 0.6rem 1rem; border: 1px solid hsl(217 91% 60% / 30%); border-radius: 8px; background: hsl(217 91% 60% / 6%); font-size: 0.88rem; }
            .ul-advisory-text { color: var(--muted-foreground, hsl(var(--nav-muted))); }
            .ul-advisory-cta { color: hsl(217 91% 60%); font-weight: 600; text-decoration: none; }
            .ul-advisory-cta:hover { text-decoration: underline; }
            .ul-advisory-alt { color: var(--muted-foreground, hsl(var(--nav-muted))); text-decoration: underline; font-size: 0.82rem; }
        }
    }

}
