// underlayer_content — the certificate claim, on the course landing page.
//
// WHY IT IS HERE AND NOT IN THE LESSON NAV.  A certificate is earned per
// COURSE.  There is no such thing as a certificate for one concept, so a claim
// button on every lesson page would be a control for something the page cannot
// know about -- and this repository's rule is that a control which does not do
// anything is a decoration.  The lesson nav's chip does the only thing a lesson
// can honestly do, which is offer the link once progress hits 100%; the claim
// itself belongs on the page that knows which course it is.
//
// WHY IT IS IN THIS FILE AND NOT IN elf_landing.ch.  /courses/<id> is served by
// the GENERIC render_course_landing in content/src/course_landing.ch --
// web/src/handlers_lessons.ch line 40 is the only caller -- so that is the one
// landing page a reader of any of the 34 courses actually sees.  Building it
// into a per-course file would have produced a certificate claim on exactly one
// course and thirty-three pages that silently do not have one, which is the
// dead-affordance shape this collection has been bitten by twice.  (The seven
// per-course landing renderers in this directory have no caller in web/; they
// are unreachable at runtime.  Reported separately, not fixed here.)
//
// THE SHAPES, VERIFIED WITH CURL BEFORE THIS WAS WRITTEN.
//   GET  /api/certificates -> [ {id, course_id, learner_name, course_title,
//                                completion_date, certificate_url, created_at} ]
//   POST /api/certificates {course_id} -> {"id":"...","learner_id":"...",
//                                 "course_id":"...","learner_name":"...",
//                                 "course_title":"...","certificate_url":"/certificates/<id>"}
//   401 when signed out; {"error":"certificate already issued","certificate_id":"..."} on a repeat.
//
// THE GATE ON THE CLAIM BUTTON IS CLIENT-SIDE, AND THAT IS A FINDING NOT A
// DESIGN.  handle_issue_certificate in web/src/handlers_certificates.ch checks
// has_certificate() and NOTHING ELSE -- it never asks whether the course is
// finished.  POST /api/certificates with any course id therefore returns a
// certificate, which was verified: a learner with zero concepts read in elf got
// one.  Until the server checks completion, the only thing standing between a
// learner and an unearned certificate is this button being shown at 100%, and
// that is a fact worth knowing before anyone builds a leaderboard on top of it.
//
// SIGNED OUT: NOTHING IS SHOWN AND NOTHING IS ASKED.  No token, no request, no
// empty box.  A course landing page must render and read well for a reader who
// never signs in; that is the backend-optional rule.
public namespace underlayer_content {

    public func render_certificate_claim(page : &mut HtmlPage) {
        #html {
            <div class="cert-claim" id="cert-claim" hidden>
                <span class="cert-claim-label" id="cert-claim-label"></span>
                <a class="cert-claim-link" id="cert-claim-link" href="/certificates" hidden>View it</a>
                <button type="button" class="cert-claim-btn" id="cert-claim-btn" hidden>Claim your certificate</button>
            </div>
        }
        render_certificate_claim_css(page)
        render_certificate_claim_js(page)
    }

    public func render_certificate_claim_css(page : &mut HtmlPage) {
        #css {
            .cert-claim { display: flex; flex-wrap: wrap; align-items: center; gap: 0.6rem; margin-top: 0.75rem; padding: 0.6rem 0.85rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--secondary)); }
            .cert-claim[hidden] { display: none; }
            .cert-claim-label { font-size: 0.9rem; color: hsl(var(--foreground)); }
            .cert-claim-link { font-size: 0.9rem; font-weight: 600; color: hsl(217 91% 60%); text-decoration: none; }
            .cert-claim-link:hover { text-decoration: underline; }
            .cert-claim-btn { font: inherit; font-size: 0.9rem; font-weight: 600; padding: 0.4rem 0.8rem; border: none; border-radius: 6px; background: hsl(217 91% 60%); color: hsl(0 0% 100%); cursor: pointer; }
            .cert-claim-btn:hover { background: hsl(217 91% 55%); }
            .cert-claim-btn[hidden] { display: none; }
        }
    }

}