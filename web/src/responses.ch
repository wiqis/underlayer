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

        // ONE CSP FOR EVERY RESPONSE.  Built here rather than memoised in a
        // module global: a `string` global assigned at boot is a bitwise copy
        // that aliases a freed buffer, and an unconstructed global reads back
        // empty (both traps are documented in wiqis-chemical-language).  A
        // dozen append_views per response are nothing next to a request.
        //
        // `frame-src` names BOTH hosts on purpose.  The Google consent popup is
        // opened from inside the account iframe, but a navigation started in a
        // subframe is checked against the TOP-LEVEL document's frame-src — so
        // the entry has to be on OUR policy, not on the account service's.
        // There is deliberately no `frame-ancestors`: Underlayer is the parent
        // that frames the account service, not the page being framed.
        var account = underlayer_core::account_url()
        var policy = string("default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://storage.googleapis.com; connect-src 'self' ")
        policy.append_view(account.to_view())
        policy.append_view("; frame-src ")
        policy.append_view(account.to_view())
        policy.append_view(" https://accounts.google.com; form-action 'self'; base-uri 'self'; object-src 'none'")
        var policy_view = policy.to_view()
        res.set_header_view(string_view("Content-Security-Policy"), &policy_view)
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
    //   * Handler headers are PRESERVED.  `out` is a copy of `res`, never a
    //     fresh Response, so a `Set-Cookie` added by an auth handler reaches
    //     the wire; a response that sets one is also excluded from the 304
    //     path, because a conditional response cannot carry a new credential.
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

        // A response that sets a cookie is an EVENT, not a cacheable
        // representation.  Collapsing it to 304 used to drop the Set-Cookie
        // header entirely (the old branch built a fresh Response), so a login
        // answered from a validator would leave the browser with no session.
        // Never revalidate one, and keep every handler-set header on the 304
        // that is still legitimate for ordinary pages.
        var sets_cookie = out.headers.contains("Set-Cookie")

        // Revalidate: a matching If-None-Match means "you already have it".
        if(!sets_cookie && if_none_match_hits(req, &etag)) {
            // Copy the delivered response rather than constructing a new one:
            // any header a handler set must survive delivery.  Only the status
            // and the body change on a 304.  `res` itself was moved into `out`
            // above, so `out` is the value to move from here; nothing below
            // this branch uses it.
            var not_modified = out
            not_modified.status = 304u
            not_modified.set_body(http::ResponseBody.Empty())
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
        // Suffix BOTH constants: on Linux an unsuffixed 64-bit hex literal is
        // inferred as `long`, which the release type checker refuses for u64
        // (Windows' `long` is 32-bit, so a local debug build does not catch it).
        var hash : u64 = 0xcbf29ce484222325u64
        var i : size_t = 0
        while(i < text.size()) {
            hash = hash ^ (text.at(i) as u64)
            hash = hash * 0x100000001b3u64
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

    // ---- Process-wide: the course content directory ----
    //
    // Every page route needs to know where `courses/` is, and a route handler
    // cannot capture it (the router stores handlers as `Send + Sync + 'static`).
    // It is one value for the process, set once from `main` and read by the page
    // handlers, so it lives here.
    //
    // It is a fixed char buffer and not a `string`: a zero-initialised
    // `@never_destructed` global is not a constructed value, and a `string` global
    // assigned at boot read back EMPTY at request time (measured: every manifest
    // path came out as "/<course>/manifest.json").
    comptime const COURSES_DIR_MAX : size_t = 512
    @never_destructed
    var g_courses_buf : [COURSES_DIR_MAX]char
    @never_destructed
    var g_courses_len : size_t

    public func set_courses_dir(courses : &string) {
        unsafe {
            var n = courses.size()
            if(n >= COURSES_DIR_MAX) { n = COURSES_DIR_MAX - 1 }
            var i : size_t = 0
            while(i < n) {
                g_courses_buf[i] = courses.at(i)
                i = i + 1
            }
            g_courses_buf[n] = 0
            g_courses_len = n
        }
    }

    // The courses directory, as a value: callers take `&string` and must not hold
    // a view into the global.
    public func request_courses_dir() : string {
        var out = std::string()
        var n = unsafe(g_courses_len)
        var i : size_t = 0
        while(i < n) {
            out.append(unsafe(g_courses_buf[i]))
            i = i + 1
        }
        return out
    }

    // The 404 page, as the App's `not_found` slot.
    //
    // It is a live route: the address a reader mistyped is the one thing that
    // varies, so the page is rendered per request and carries `no-store`, like
    // every other per-request render.
    // The 404's own styles.  Kept in a `#css` block like every other stylesheet
    // in this codebase; the caller renders it on a scratch page (see below).
    func render_not_found_css(page : &mut HtmlPage) {
        #css {
            .not-found { max-width: 40rem; margin: 0 auto; padding: 4rem 1.5rem; }
            .not-found h1 { font-size: 1.75rem; margin: 0 0 0.75rem; color: hsl(var(--foreground)); }
            .not-found p { color: hsl(var(--muted-foreground)); margin: 0 0 1rem; line-height: 1.6; }
            .not-found code { font-family: ui-monospace, 'SFMono-Regular', 'Consolas', monospace; background: hsl(var(--muted)); color: hsl(var(--foreground)); padding: 0.1rem 0.35rem; border-radius: 4px; }
            .not-found-links { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; margin-top: 1.5rem; }
            .not-found a { color: hsl(var(--primary)); font-weight: 600; text-decoration: none; }
            .not-found a:hover { text-decoration: underline; text-underline-offset: 3px; }
            .not-found .btn-primary { display: inline-block; background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); padding: 0.6rem 1rem; border-radius: 8px; font-weight: 600; }
            .not-found .btn-primary:hover { filter: brightness(0.92); text-decoration: none; }
            @media (max-width: 560px) {
                .not-found { padding: 2.5rem 1rem; }
                .not-found-links { gap: 0.75rem; }
            }
        }
    }

    // THE LIVE-ROUTE CSS PROBLEM, AND WHY A SCRATCH PAGE IS USED.
    //
    // `app.not_found` is a live route. Its page is attached to the site's
    // already-frozen asset sink, and css_cbi wraps every declaration in
    // `if (page.require_css_hash(hash))`. The build-time warm pass records those
    // hashes in the shared sink, so the SAME declarations are skipped on every
    // real request — the page comes back with no `<style>` at all (measured:
    // Times New Roman, blue underlined links, zero nav styling).
    //
    // So the CSS is generated through the normal `#css` macros on a scratch
    // HtmlPage that has NO shared sink and a fresh hash set, and the resulting
    // bytes are placed in <head> as one inline `<style>`. This is the same raw
    // head escape hatch `render_theme_boot_js` uses for its pre-paint script;
    // only the `<style>` wrapper is a string, every declaration is macro output.
    // Calling WiqisTheme here instead would append `#globalcss` to the frozen
    // sink and make the bundle stale (503 on every 404).
    func attach_not_found_css(page : &mut HtmlPage) {
        var scratch = HtmlPage()
        underlayer_content::render_site_nav_css(&mut scratch)
        render_not_found_css(&mut scratch)
        var css = scratch.local_css()
        var style = string("<style>")
        style.append_view(&css.to_view())
        style.append_view("</style>")
        page.append_head_view(&style.to_view())
    }

    public func page_not_found(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        page.defaultPrepare()
        var wanted = ctx.path()
        var title = std::string_view("Page not found — Underlayer")
        page.appendTitle(&title)

        // One shared nav: same markup, scripts and theme bootstrap as a lesson
        // page. `render_nav_bar` would also call WiqisTheme, which cannot be used
        // on a live route (see attach_not_found_css above).
        underlayer_content::render_site_nav(page)
        attach_not_found_css(page)

        #html {
            <main class="container not-found" id="main-content">
                <h1>That page is not here</h1>
                <p>The address <code>{wanted}</code> does not match a course, a lesson or a page on this platform.</p>
                <p class="not-found-links">
                    <a class="btn btn-primary" href="/courses">Browse the courses</a>
                    <a href="/">Home</a>
                    <a href="/search">Search</a>
                </p>
            </main>
        }
    }

}