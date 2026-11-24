// underlayer_web — THE BROWSER SESSION COOKIE.
//
// WHY THIS FILE EXISTS.  Auth used to be bearer-token only: `/api/auth/login`
// returned a `session_token` which the browser kept in localStorage, and
// `auth_get_learner_id` only read `Authorization: Bearer ...`.  A page load
// carries no Authorization header, so every server-side page gate answered
// "signed out" and bounced a genuinely signed-in reader to /login?next=...
// (see the gotcha at the bottom of AGENTS.md).  A page gate needs a credential
// the BROWSER sends on navigation; that is a cookie.
//
// THE CONTRACT IS HERE, AND ONLY HERE.  One name, one lifetime, one attribute
// set, computed once for setting and for clearing so the two cannot drift.
// `docs/browser-session.md` is the human-facing version.
//
// WHAT IS NOT HERE: any weakening of the gate.  A cookie is just a carrier for
// the same 64-hex-char token; it is still looked up by SHA-256 in `auth_sessions`
// with `expires_at > now`.  An unknown, revoked or expired cookie therefore
// reads as signed out exactly like a bad bearer token.  There is no demo-user
// fallback and there is no path from "cookie present" to "authorised" that
// skips the database.

using std::string
using std::string_view

public namespace underlayer_web {

    // The one name.  Prefixed so it cannot collide with a cookie from another
    // Wiqis product on a shared parent domain.  Built in the function, not held
    // in a `comptime const`: a comptime string_view constant translates back to
    // a bare `char[]` when returned across a function boundary.
    public func session_cookie_name() : string_view {
        return string_view("ul_session")
    }

    // 30 days, matching `create_session()` in handlers_auth.ch, which inserts
    // `expires_at = now + 2592000`.  A cookie outliving the row is harmless
    // (the lookup fails); a row outliving the cookie would strand a reader who
    // closed the tab near expiry, so the two are deliberately the same number.
    comptime const SESSION_MAX_AGE : i64 = 2592000

    // Case-insensitive equality against a short literal.  `string_view.equals`
    // is case-sensitive and a proxy is free to write "HTTPS" or "https, http".
    private func equals_ignore_case(a : &string_view, b : &string_view) : bool {
        if(a.size() != b.size()) { return false }
        var i : size_t = 0
        while(i < a.size()) {
            var x = a.at(i)
            var y = b.at(i)
            if(x >= 'A' && x <= 'Z') { x = (x + 32) as char }
            if(y >= 'A' && y <= 'Z') { y = (y + 32) as char }
            if(x != y) { return false }
            i = i + 1
        }
        return true
    }

    // Secure ONLY on HTTPS.  The container serves plain HTTP and TLS is
    // terminated by the proxy in front of it, so the request that reaches the
    // handler is HTTP even in production; the proxy supplies
    // `X-Forwarded-Proto: https`.  Marking a localhost `http://` cookie Secure
    // makes the browser refuse to store it, which is the classic "works in
    // production, impossible to debug locally" failure.  Checking both the
    // wire proto and the forwarded header covers direct TLS and proxied TLS.
    public func request_is_https(req : &http::Request) : bool {
        var https = string_view("https")
        var proto = req.proto.to_view()
        if(equals_ignore_case(&proto, &https)) { return true }
        var got = req.headers.get("X-Forwarded-Proto")
        if(got is std::Option.None) { return false }
        var Some(value) = got else unsafe { unreachable }
        // A proxy chain can append: take the first token only.
        var comma = value.find_or_npos(string_view(","))
        var first = value
        if(comma != std::NPOS) { first = value.subview(0, comma) }
        while(first.size() > 0 && first.at(0) == ' ') {
            first = first.subview(1, first.size())
        }
        while(first.size() > 0 && first.at(first.size() - 1) == ' ') {
            first = first.subview(0, first.size() - 1)
        }
        return equals_ignore_case(&first, &https)
    }

    // The exact attributes, in one place: HttpOnly, SameSite=Lax, Path=/,
    // Max-Age=2592000, Secure iff HTTPS.  No Domain, so the cookie is host-only
    // and cannot be planted by — or read by — a sibling Wiqis host.
    public func session_cookie_options(req : &http::Request) : http::CookieOptions {
        return http::CookieOptions.make("/", "Lax", true, request_is_https(req), SESSION_MAX_AGE, "")
    }

    // Attach the cookie to a response that already carries a JSON body.  The
    // token is the SAME value returned as `session_token`; the JSON stays for
    // the mobile API clients, which cannot use a browser cookie jar.
    public func set_session_cookie(res : &mut http::Response, req : &http::Request, token : &string) {
        var tv = token.to_view()
        res.cookie(session_cookie_name(), tv, session_cookie_options(req))
    }

    // Expire it with the same attributes.  We do NOT use `Response.delete_cookie`
    // here: it passes -1 to `CookieOptions.with`, whose setter only applies a
    // non-negative max_age, so a cookie created with Max-Age=2592000 came back
    // on logout as `ul_session=; Max-Age=2592000` — an empty cookie that the
    // browser would keep for a month.  A negative max_age fed straight to
    // `set_cookie_value` is the documented "delete now" form and emits
    // `Max-Age=0`, which is what actually clears it.
    public func clear_session_cookie(res : &mut http::Response, req : &http::Request) {
        var expired = http::CookieOptions.make("/", "Lax", true, request_is_https(req), -1, "")
        res.cookie(session_cookie_name(), string_view(""), expired)
    }

    // The cookie's token, or "" when absent.  Validation is NOT done here: the
    // caller hashes whatever comes back and asks the database, so a bogus
    // cookie is indistinguishable from no cookie at the gate.
    public func extract_cookie_token(req : &http::Request) : string {
        var jar = http::CookieJar.of(req)
        var got = jar.get(session_cookie_name())
        if(got is std::Option.None) { return string() }
        var Some(value) = got else unsafe { unreachable }
        var out = string()
        out.append_view(&value)
        return out
    }

}
