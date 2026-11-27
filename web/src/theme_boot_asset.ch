// underlayer_web — the external pre-paint theme bootstrap (B5).
//
// `content/src/theme_boot.ch` owns the exact JS bytes and the pinned SHA-384.
// HTTP-served brand-shell pages emit a BLOCKING <script src=...> with that
// hash; this route is what answers it. Lesson pages still use the inline form
// because they are exported for file:// (see content/src/theme_boot.ch). The
// external script is blocking on purpose: the browser will not parse or paint
// the body until it has run, which is the same guarantee the inline script gave.
//
// No secret, no request-specific state, no caller-supplied header. The response
// goes through `deliver_with_learner` at the call site, so it gets the one CSP,
// ETag/304, X-Request-Id and access line every other response gets.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_theme_boot(req : &http::Request) : http::Response {
        var js = underlayer_content::theme_boot_js_source()
        var res = http::Response()
        var ct = string_view("application/javascript; charset=utf-8")
        res.set_header_view(string_view("Content-Type"), &ct)
        var jv = js.to_view()
        res.text(&jv)
        return res
    }

}
