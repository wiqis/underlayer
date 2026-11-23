// underlayer_web — response helpers.
//
// Every route in the platform answers through one of these four functions, and
// each one *returns* an `http::Response` the framework writes.  Before this the
// four were `ResponseWriter` writes: a handler that set a status and returned
// without writing a body produced no response at all, and every one of them had
// to remember the security headers separately.
//
// `apply_security_headers` still runs in exactly one place per response — here.
using std::string
using std::string_view

public namespace underlayer_web {

    // Called by every response helper below.  `insert_view` replaces an existing
    // header, so calling it twice is harmless.
    public func apply_security_headers(res : &mut http::Response) {
        var nosniff = string_view("nosniff")
        res.set_header_view(string_view("X-Content-Type-Options"), &nosniff)

        var deny = string_view("DENY")
        res.set_header_view(string_view("X-Frame-Options"), &deny)

        var referrer = string_view("strict-origin-when-cross-origin")
        res.set_header_view(string_view("Referrer-Policy"), &referrer)

        var hsts = string_view("max-age=31536000")
        res.set_header_view(string_view("Strict-Transport-Security"), &hsts)
    }

    // A rendered page, as `text/html`.
    public func send_page(page : &HtmlPage) : http::Response {
        var html = page.toString()
        return send_html(&html)
    }

    // HTML text, as `text/html`.
    public func send_html(html : &string) : http::Response {
        var res = http::Response()
        var ct = string_view("text/html; charset=utf-8")
        res.set_header_view(string_view("Content-Type"), &ct)
        apply_security_headers(&mut res)
        var hv = html.to_view()
        res.html(&hv)
        return res
    }

    // A JSON body, as `application/json`.
    public func send_json_str(body : &string) : http::Response {
        var res = http::Response()
        var ct = string_view("application/json")
        res.set_header_view(string_view("Content-Type"), &ct)
        apply_security_headers(&mut res)
        var bv = body.to_view()
        res.text(&bv)
        return res
    }

    // An error, as `{"error": "<msg>"}` with `status`.  The message is escaped
    // with `underlayer_core::json_escape`, so a message that contains a quote
    // cannot break the JSON — the previous version appended the raw text.
    public func send_error(status : u16, msg : &string) : http::Response {
        var escaped = underlayer_core::json_escape(&msg.to_view())
        var body = string("{\"error\":\"")
        body.append_string(&escaped)
        body.append_view("\"}")
        var res = send_json_str(&body)
        res.status = status
        return res
    }

    // A JSON body with a chosen status.
    public func send_json_status(status : u16, body : &string) : http::Response {
        var res = send_json_str(body)
        res.status = status
        return res
    }

    // An error with a status and a plain-text message (used where the client is a
    // browser rather than a JSON consumer).
    public func send_status_text(status : u16, msg : &string) : http::Response {
        var res = http::Response()
        var ct = string_view("text/plain; charset=utf-8")
        res.set_header_view(string_view("Content-Type"), &ct)
        apply_security_headers(&mut res)
        var mv = msg.to_view()
        res.text(&mv)
        res.status = status
        return res
    }

    // A 303 redirect to an arbitrary location.
    public func redirect_to(location : &string) : http::Response {
        var res = http::Response()
        res.status = 303u
        var lv = location.to_view()
        res.set_header_view(std::string_view("Location"), &lv)
        apply_security_headers(&mut res)
        var empty = string()
        var ev = empty.to_view()
        res.text(&ev)
        return res
    }

}
