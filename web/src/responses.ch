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

    // ---- Delivery: cache policy, ETag/304 and gzip in one place ----
    //
    // Every route returns `deliver(&req, response)`.  Before this the app wrote
    // bodies straight out: no validator, no cache policy and no compression, so
    // a 143 KB home page was re-sent in full on every navigation and a 76 KB
    // lesson page could not be revalidated at all.
    //
    // What it does, and why each part:
    //
    //   * ETag + 304.  The validator is a 64-bit FNV-1a over the exact bytes we
    //     are about to send, so two renders of the same page agree and any change
    //     to the markup changes the tag.  A client that sends `If-None-Match`
    //     with the same tag gets 304 with no body: that is the whole win for a
    //     reader moving back and forth through a course.
    //   * `Cache-Control: no-cache` for pages — revalidate every time, which is
    //     correct for content that is rendered per request but almost always
    //     identical, and `no-store` for `/api/*`, whose answers are per-learner
    //     and must not sit in a shared cache.
    //   * Gzip when the client offers it and the body is worth it.  The 143 KB
    //     home page and the 76 KB lesson page both compress to a fraction of
    //     that; below 1 KiB the framing costs more than it saves.
    public func deliver(req : &http::Request, res : http::Response) : http::Response {
        var body : string
        var is_text = false
        switch(res.body) {
            Text(text) => {
                body = text.copy()
                is_text = true
            }
            default => {
                // Bytes / File / Empty: already encoded, or streamed. Leave it.
                return res
            }
        }
        if(!is_text) { return res }

        var out = res
        var etag = etag_of(&body)
        var etag_view = etag.to_view()
        out.set_header_view(std::string_view("ETag"), &etag_view)

        var no_store = string_view("no-store")
        var revalidate = string_view("no-cache")
        if(path_starts_with(req, "/api/")) {
            out.set_header_view(std::string_view("Cache-Control"), &no_store)
        } else {
            out.set_header_view(std::string_view("Cache-Control"), &revalidate)
        }

        // Revalidate: a matching If-None-Match means "you already have it".
        if(if_none_match_hits(req, &etag)) {
            var not_modified = http::Response()
            not_modified.status = 304u
            not_modified.set_header_view(std::string_view("ETag"), &etag_view)
            if(path_starts_with(req, "/api/")) {
                not_modified.set_header_view(std::string_view("Cache-Control"), &no_store)
            } else {
                not_modified.set_header_view(std::string_view("Cache-Control"), &revalidate)
            }
            apply_security_headers(&mut not_modified)
            return not_modified
        }

        // Gzip for clients that asked for it.
        if(body.size() >= 1024 && accepts_gzip(req)) {
            var body_view = body.to_view()
            var packed = compression::gzip(body_view.as_bytes())
            if(packed is std::Result.Ok) {
                var Ok(gz) = packed else unsafe { unreachable }
                out.set_header_view(std::string_view("Content-Encoding"), &string_view("gzip"))
                out.set_header_view(std::string_view("Vary"), &string_view("Accept-Encoding"))
                out.bytes(gz.as_span())
            }
        }
        return out
    }

    // 64-bit FNV-1a, hex.  Cheap, deterministic, and good enough to tell two
    // renders apart — this is a cache validator, not a signature.
    func etag_of(text : &string) : string {
        var hash : u64 = 0xcbf29ce484222325
        var i : size_t = 0
        while(i < text.size()) {
            hash = hash ^ (text.at(i) as u64)
            hash = hash * 0x100000001b3
            i = i + 1
        }
        var buf = std::vector<u8>()
        buf.reserve(8)
        var k : int = 7
        while(k >= 0) {
            var shift = (k as u64) * 8u64
            buf.push(((hash >> shift) & 0xffu64) as u8)
            k = k - 1
        }
        var encoded = encoding::hex_encode(buf.as_span())
        if(encoded is std::Result.Err) { return string("\"0\"") }
        var Ok(hex) = encoded else unsafe { unreachable }
        var quoted = string("\"")
        var hv = hex.to_view()
        quoted.append_view(&hv)
        quoted.append_view("\"")
        return quoted
    }

    func header_contains(req : &http::Request, name : std::string_view, needle : &string_view) : bool {
        var got = req.headers.get(std::str.make_view(name))
        if(got is std::Option.None) { return false }
        var Some(value) = got else unsafe { unreachable }
        return value.find_or_npos(needle) != std::NPOS
    }

    func accepts_gzip(req : &http::Request) : bool {
        var gzip = string_view("gzip")
        return header_contains(req, string_view("Accept-Encoding"), &gzip)
    }

    // `"abc"` -> `abc`, `W/"abc"` -> `abc`.
    func trim_quotes(value : &std::string_view) : std::string_view {
        var start : size_t = 0
        var end = value.size()
        if(end > 2 && value.at(0) == 'W' && value.at(1) == '/') { start = 2 }
        if(start < end && value.at(start) == '"') { start = start + 1 }
        if(end > start && value.at(end - 1) == '"') { end = end - 1 }
        if(end < start) { return std::string_view("") }
        return value.subview(start, end)
    }

    func if_none_match_hits(req : &http::Request, etag : &string) : bool {
        var inm = string_view("If-None-Match")
        var got = req.headers.get(std::str.make_view(inm))
        if(got is std::Option.None) { return false }
        var Some(value) = got else unsafe { unreachable }
        // Compare without the surrounding quotes: a validator may be sent
        // weakly (`W/"..."`) and some clients drop the quotes entirely.
        var want_a = trim_quotes(&value)
        var etag_view2 = etag.to_view()
        var want_b = trim_quotes(&etag_view2)
        if(want_a.size() != want_b.size()) { return false }
        var i : size_t = 0
        while(i < want_b.size()) {
            if(want_a.at(i) != want_b.at(i)) { return false }
            i = i + 1
        }
        return true
    }

    func path_starts_with(req : &http::Request, prefix : &string_view) : bool {
        var path = req.path.to_view()
        if(path.size() < prefix.size()) { return false }
        var head = path.subview(0, prefix.size())
        var i : size_t = 0
        while(i < prefix.size()) {
            if(head.at(i) != prefix.at(i)) { return false }
            i = i + 1
        }
        return true
    }

}
