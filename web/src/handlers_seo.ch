// underlayer_web — robots.txt, sitemap.xml and favicon.ico (I1).
//
// All three are registered as explicit routes BEFORE the web::App catch-all and
// answer through deliver_with_learner, so H3's uniform security headers, the
// access line, ETag/304 and gzip apply to them exactly as to every other route.
// Nothing here reads the filesystem directly: the sitemap walks the same
// repository loader the course pages use, so a new course appears in both.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func send_xml(body : &string) : http::Response {
        var res = http::Response()
        var ct = string_view("application/xml; charset=utf-8")
        res.set_header_view(string_view("Content-Type"), &ct)
        apply_security_headers(&mut res)
        var bv = body.to_view()
        res.text(&bv)
        return res
    }

    // The content snapshot date in production-ready-plan.md §1 (measured
    // 2026-11-26). No course ships a changelog.json yet (G9), so "from the
    // course version/changelog" means: this verified baseline, advanced by one
    // day per version bump. When changelogs land they replace this derivation.
    private func days_in_month(year : int, month : int) : int {
        if(month == 2) {
            var leap = false
            if(year % 400 == 0) { leap = true }
            else if(year % 4 == 0 && year % 100 != 0) { leap = true }
            if(leap) { return 29 }
            return 28
        }
        if(month == 4 || month == 6 || month == 9 || month == 11) { return 30 }
        return 31
    }

    private func two_digits(value : int) : string {
        var out = string()
        if(value < 10) { out.append('0') }
        var s = underlayer_core::int_to_string(value as i64)
        out.append_view(s.to_view())
        return out
    }

    public func lastmod_for_version(version : int) : string {
        var year = 2026
        var month = 11
        var day = 26
        var extra = version - 1
        if(extra < 0) { extra = 0 }
        while(extra > 0) {
            day = day + 1
            if(day > days_in_month(year, month)) {
                day = 1
                month = month + 1
                if(month > 12) { month = 1; year = year + 1 }
            }
            extra = extra - 1
        }
        var out = underlayer_core::int_to_string(year as i64)
        out.append_view("-")
        var mm = two_digits(month)
        out.append_view(mm.to_view())
        out.append_view("-")
        var dd = two_digits(day)
        out.append_view(dd.to_view())
        return out
    }

    public func handle_robots_txt(req : &http::Request) : http::Response {
        var body = string("User-agent: *\nAllow: /\nDisallow: /api/\n\nSitemap: ")
        var sitemap = absolute_url(string("/sitemap.xml"))
        body.append_view(sitemap.to_view())
        body.append_view("\n")
        return send_status_text(200u, &body)
    }

    private func append_url_entry(out : &mut string, path : &string, lastmod : &string) {
        var loc = absolute_url(path)
        var escaped = underlayer_core::html_escape(&loc)
        out.append_view("  <url><loc>")
        out.append_view(escaped.to_view())
        out.append_view("</loc><lastmod>")
        out.append_view(lastmod.to_view())
        out.append_view("</lastmod></url>\n")
    }

    public func handle_sitemap_xml(courses_dir : &string, req : &http::Request) : http::Response {
        var out = string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        out.append_view("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n")
        var baseline = lastmod_for_version(1)
        // Stable, human-readable order: the entry points, the guide/legal
        // pages, then every course landing and every concept URL.
        var fixed = vector<string>()
        fixed.push(string("/"))
        fixed.push(string("/courses"))
        fixed.push(string("/search"))
        fixed.push(string("/learning-path"))
        fixed.push(string("/help"))
        fixed.push(string("/shortcuts"))
        fixed.push(string("/faq"))
        fixed.push(string("/about"))
        fixed.push(string("/terms"))
        fixed.push(string("/privacy"))
        var fi : size_t = 0
        while(fi < fixed.size()) {
            append_url_entry(&mut out, fixed.at_ref(fi), &baseline)
            fi = fi + 1
        }
        var courses = underlayer_repository::list_courses(courses_dir)
        var ci : size_t = 0
        while(ci < courses.size()) {
            var course = courses.at_ref(ci)
            var modified = lastmod_for_version(course.version)
            var landing = string("/courses/")
            landing.append_view(course.id.to_view())
            append_url_entry(&mut out, &landing, &modified)
            // A paid lesson answers 402 to an anonymous crawler. The landing is
            // public store-front; its lesson URLs must not be in the sitemap.
            if(underlayer_web::is_paid_course(courses_dir, &course.id)) {
                ci = ci + 1
                continue
            }
            var ki : size_t = 0
            while(ki < course.concepts.size()) {
                var concept = course.concepts.at_ref(ki)
                var lesson = string("/courses/")
                lesson.append_view(course.id.to_view())
                lesson.append_view("/lessons/")
                lesson.append_view(concept.id.to_view())
                append_url_entry(&mut out, &lesson, &modified)
                ki = ki + 1
            }
            ci = ci + 1
        }
        out.append_view("</urlset>\n")
        return send_xml(&out)
    }

    // No favicon asset existed in this repo. Build a minimal, valid 16x16
    // 32-bpp ICO in memory rather than committing an opaque binary. The AND
    // mask stays zero; the pixels are Underlayer's dark brand colour.
    public func handle_favicon_ico(req : &http::Request) : http::Response {
        var icon = std::vector<u8>()
        var total : size_t = 1118
        var i : size_t = 0
        while(i < total) { icon.push(0u8); i = i + 1 }
        icon.set(0, 0u8)
        icon.set(2, 1u8)
        icon.set(4, 1u8)
        icon.set(6, 16u8)
        icon.set(7, 16u8)
        icon.set(10, 1u8)
        icon.set(12, 32u8)
        icon.set(14, 72u8)      // 1096 bytes of image data, little endian
        icon.set(15, 4u8)
        icon.set(18, 22u8)      // header offset
        icon.set(22, 40u8)      // BITMAPINFOHEADER size
        icon.set(26, 16u8)      // width
        icon.set(30, 32u8)      // height is doubled for an XOR+AND DIB
        icon.set(34, 1u8)
        icon.set(36, 32u8)
        icon.set(42, 0u8)       // sizeImage low byte = 1024
        icon.set(43, 4u8)
        var p : size_t = 0
        while(p < 256) {
            var base : size_t = 58 + p * 4
            icon.set(base, 59u8)
            icon.set(base + 1, 42u8)
            icon.set(base + 2, 26u8)
            icon.set(base + 3, 255u8)
            p = p + 1
        }
        var res = http::Response()
        var ct = string_view("image/x-icon")
        res.set_header_view(string_view("Content-Type"), &ct)
        apply_security_headers(&mut res)
        res.bytes(icon.as_span())
        return res
    }

}
