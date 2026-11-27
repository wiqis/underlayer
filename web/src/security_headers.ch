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
// WHY THE CONTENT-SECURITY-POLICY LOOKS LIKE THIS.  The earlier version of this
// file argued that no CSP was better than one with 'unsafe-inline', because the
// lesson pages and the components runtime emit inline <script>/<style> by the
// thousand and a policy that forbade them would blank the product.  That is
// still true about forbidding them, but it is no longer a reason to ship no
// policy at all: the honest policy allows the inline blocks this codebase
// actually emits and still constrains everything else.  It is a real control on
// framing, destinations, forms and object/plugin loads, not a pretend one.
//
//   default-src 'self'               anything not named below stays on this host
//   script-src 'self' 'unsafe-inline'
//                                    B5 externalised the theme boot to a
//                                    same-origin SRI-hashed asset ('self'
//                                    already covers it). The hash is NOT in
//                                    this policy: CSP3 would then ignore
//                                    'unsafe-inline' and break the thousands
//                                    of macro-emitted inline blocks. Measured
//                                    with a CDP drive; see docs/deployment.md
//                                    §6 item 1. No tightened CSP is claimed.
//   style-src  'self' 'unsafe-inline'    the #js/#css macros emit inline blocks
//   img-src 'self' data: https://storage.googleapis.com
//                                    data: for lesson diagrams, GCS for avatars
//   connect-src 'self' <ACCOUNT_URL>  the browser calls account.wiqis.com
//   frame-src <ACCOUNT_URL> https://accounts.google.com
//                                    see the trap below -- Google belongs HERE
//   form-action 'self'; base-uri 'self'; object-src 'none'
//                                    no off-site form posts, no <base> hijack,
//                                    no plugins
//
// THE GOOGLE ENTRY IS THE SUBTLE PART, and getting it wrong is silent.  Google's
// consent screen cannot render in a third-party iframe, so the account page
// opens a top-level POPUP from inside the sign-in iframe.  A navigation started
// in a subframe is enforced against the TOP-LEVEL document's frame-src — what
// w3c/webappsec-csp#400 reports and all current browsers implement, contrary to
// the literal spec text.  Adding accounts.google.com to the ACCOUNT service's
// policy fixes nothing: the violation names OUR directive.  Scope it to
// frame-src only; Google must never appear in default-src, script-src or
// connect-src, because the credential page deliberately runs no third-party JS.
//
// NO frame-ancestors HERE, on purpose.  Underlayer is the parent that embeds the
// account service's sign-in frame; the account service sends the matching
// frame-ancestors wildcard.  Sending frame-ancestors from Underlayer would only
// say who may frame US, which is a different question and would risk breaking
// the reader's own use of the site for no benefit.
//
// WHY NOT X-XSS-Protection.  It is deprecated, every current browser has removed
// it, and the auditing it performed was itself exploitable.  Its presence in
// older hardening guides is a reason people cargo-cult headers rather than a
// reason to send one.
using std::string
using std::string_view

// The headers themselves are set by `apply_security_headers` in `responses.ch`,
// next to the four functions that build a response.  The rationale above is why
// they are what they are; the code that sends them lives beside the code that
// sends the body, so the two cannot drift apart.