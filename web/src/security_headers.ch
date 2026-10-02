// underlayer_web — SECURITY HEADERS, applied once at the four send_* helpers.
//
// WHY HERE AND NOWHERE ELSE.  There are four functions that write a response
// body (send_page, send_html, send_json_str, send_error), and every route in the
// platform goes through one of them.  A per-route header block is a header block
// somebody forgets, and the routes that forget it are the ones nobody tests.
//
// MEASURED BEFORE: a page response carried no HSTS, no CSP, no X-Frame-Options,
// no X-Content-Type-Options and no Referrer-Policy, and neither did a JSON
// response.  So a browser was told nothing about how to handle this origin.
//
// WHAT EACH ONE IS FOR, AND WHERE IT COULD HURT.
//
//   X-Content-Type-Options: nosniff -- stop a browser guessing that a .json
//     response is HTML.  On /api/* this is the difference between an API
//     endpoint and a stored-XSS vector.  Cannot break anything: the platform
//     serves what it says it serves.
//
//   X-Frame-Options: DENY -- stop this site being framed, which is clickjacking:
    //     an invisible frame over the real page makes a click land where the
//     attacker wants.  The platform has nothing to frame, so DENY is free.  If
//     embedding is ever wanted, this is the line to change -- and it must become
//     frame-ancestors in the CSP below too, or the CSP wins and denies anyway.
//     Both are set together on purpose.
//
//   Referrer-Policy: strict-origin-when-cross-origin -- the pages here carry a
//     session token in localStorage, not in the URL, so there is no credential
//     in a referrer to leak.  This stops the full URL (which includes ?course_id=
//     and ?next=) being handed to third parties anyway, which is the part that
//     actually matters here.
//
//   Strict-Transport-Security -- only tells a browser to pin https FOR FUTURE
//     VISITS, and only over https.  Harmless when the site is served over plain
//     http in development: the header is simply ignored.  Deliberately 1 year
//     with includeSubDomains omitted, because includeSubDomains on a host with
//     other subdomains is a way to break someone else's site.
//
// WHY THERE IS NO CONTENT-SECURITY-POLICY, stated plainly rather than left as a
// gap someone assumes is filled.  A real CSP needs every inline <script>, every
// inline style and every data: URI this codebase emits enumerated -- and both
// the universal-components runtime and the 398 lesson pages emit inline scripts
// and inline styles by the thousand, most of them built by the #js and #css
// macros.  A policy that forbids inline script would blank the product; one that
// allows it ('unsafe-inline') buys almost nothing over having no policy, because
// an attacker who can inject markup can use the allowed inline script too.
//
// So the honest sequence is: ship nosniff / DENY / referrer-policy / HSTS now,
// because each is independently correct and independently harmless, and add a CSP
// as a separate piece of work whose first step is getting the inline scripts
// into external files.  Shipping a CSP that breaks the site would be worse than
// shipping none, and a CSP with unsafe-inline is a comment pretending to be a
// control.
//
// WHY NOT X-XSS-Protection.  It is deprecated, every current browser has removed
// it, and the auditing it performed was itself exploitable.  Its presence in
// older hardening guides is a reason people cargo-cult headers rather than a
// reason to send one.
using std::string
using std::string_view

public namespace underlayer_web {

    // Called by every send_* helper.  Safe to call more than once per response:
    // set_header_view overwrites, and the values are constants.
    public func apply_security_headers(res : *mut http::ResponseWriter) {
        var nosniff = string_view("nosniff")
        res.set_header_view(string_view("X-Content-Type-Options"), &nosniff)

        var deny = string_view("DENY")
        res.set_header_view(string_view("X-Frame-Options"), &deny)

        var referrer = string_view("strict-origin-when-cross-origin")
        res.set_header_view(string_view("Referrer-Policy"), &referrer)

        var hsts = string_view("max-age=31536000")
        res.set_header_view(string_view("Strict-Transport-Security"), &hsts)
    }

}