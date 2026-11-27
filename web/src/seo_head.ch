// underlayer_web — SEO head metadata (I1).
//
// WHY THIS IS A WEB-LAYER HELPER AND NOT 431 CONTENT EDITS.
// Lessons and course landings are rendered as complete documents by
// content/src/*.ch, then patched by the handler (pager, header, journey). The
// same sentinel-replacement pattern is used here: the head block produced by
// HtmlPage's typed head API replaces the existing <title> in the emitted
// document. Every tag is emitted by HtmlPage; every value is escaped either by
// set_head or by html_escape/json_ld_escape before it reaches an attribute.
// No markup is built by concatenating HTML in a handler.
//
// The public host is env-driven: PUBLIC_BASE_URL, defaulting to the production
// host. A local run sets PUBLIC_BASE_URL=http://localhost:9034 and every
// canonical, og:url, sitemap loc and robots Sitemap line agrees with it.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    public func public_base_url() : string {
        var configured = underlayer_core::get_env_str("PUBLIC_BASE_URL")
        if(!configured.empty()) {
            while(configured.size() > 1 && configured.at(configured.size() - 1) == '/') {
                configured.resize(configured.size() - 1)
            }
            return configured
        }
        return string("https://underlayer.wiqis.com")
    }

    public func absolute_url(path : &string) : string {
        var out = public_base_url()
        if(path.size() == 0 || path.at(0) != '/') { out.append_view("/") }
        out.append_view(path.to_view())
        return out
    }

    // ---- Descriptions --------------------------------------------------
    // Every served page gets ONE description of 140-158 plain-text characters.
    // The manifest descriptions are 18-30 characters, so they are a keyword
    // seed rather than a description: compose, collapse whitespace, then fit.
    private func collapse_ws(src : &string, out : &mut string) {
        var pending = false
        var i : size_t = 0
        while(i < src.size()) {
            var c = src.at(i)
            if(c == ' ' || c == '\n' || c == '\r' || c == '\t') {
                pending = true
            } else {
                if(pending && out.size() > 0) { out.append(' ') }
                out.append(c)
                pending = false
            }
            i = i + 1
        }
    }

    private func fit_description(src : &string) : string {
        var s = string()
        collapse_ws(src, &mut s)
        var guard = 0
        while(s.size() < 140 && guard < 8) {
            s.append_view(" Part of a verified course collection on Underlayer.")
            guard = guard + 1
        }
        if(s.size() > 158) {
            var cut : size_t = 150
            while(cut > 140 && s.at(cut) != ' ') { cut = cut - 1 }
            if(cut <= 140) { cut = 150 }
            s.resize(cut)
            if(s.at(s.size() - 1) != '.') { s.append('.') }
        }
        return s
    }

    public func lesson_description(title : &string, course_title : &string, seed : &string) : string {
        var s = string("Learn ")
        s.append_view(title.to_view())
        if(course_title.size() > 0) {
            s.append_view(" in ")
            s.append_view(course_title.to_view())
        }
        s.append_view(": ")
        s.append_view(seed.to_view())
        if(seed.size() > 0 && seed.at(seed.size() - 1) != '.') { s.append('.') }
        s.append_view(" Verified Underlayer lesson with real file examples, active recall and spaced repetition.")
        return fit_description(&s)
    }

    public func course_description(title : &string, seed : &string) : string {
        var s = string(seed.to_view())
        if(s.size() > 0 && s.at(s.size() - 1) != '.') { s.append('.') }
        s.append_view(" A verified course on Underlayer, taught from first principles with active recall and spaced repetition. ")
        s.append_view(title.to_view())
        return fit_description(&s)
    }

    // ---- JSON-LD -------------------------------------------------------
    // json_escape alone does not escape '<', and a title containing "</script>"
    // would close the script element. Escape <, > and & as JSON \uXXXX too.
    public func json_ld_string(value : &string) : string {
        var escaped = underlayer_core::json_escape(&value.to_view())
        var out = string("\"")
        var i : size_t = 0
        while(i < escaped.size()) {
            var c = escaped.at(i)
            if(c == '<') { out.append_view("\\u003c") }
            else if(c == '>') { out.append_view("\\u003e") }
            else if(c == '&') { out.append_view("\\u0026") }
            else { out.append(c) }
            i = i + 1
        }
        out.append_view("\"")
        return out
    }

    public func course_json_ld(name : &string, description : &string, url : &string) : string {
        var out = string("{\"@type\":\"Course\",\"name\":")
        var n = json_ld_string(name)
        out.append_view(n.to_view())
        out.append_view(",\"description\":")
        var d = json_ld_string(description)
        out.append_view(d.to_view())
        out.append_view(",\"url\":")
        var u = json_ld_string(url)
        out.append_view(u.to_view())
        out.append_view(",\"provider\":{\"@type\":\"Organization\",\"name\":\"Underlayer\"}}")
        return out
    }

    public func breadcrumb_json_ld(names : &vector<string>, urls : &vector<string>) : string {
        var out = string("{\"@type\":\"BreadcrumbList\",\"itemListElement\":[")
        var i : size_t = 0
        while(i < names.size() && i < urls.size()) {
            if(i > 0) { out.append_view(",") }
            out.append_view("{\"@type\":\"ListItem\",\"position\":")
            var pos = underlayer_core::int_to_string((i + 1) as i64)
            out.append_view(pos.to_view())
            out.append_view(",\"name\":")
            var n = json_ld_string(names.at_ref(i))
            out.append_view(n.to_view())
            out.append_view(",\"item\":")
            var u = json_ld_string(urls.at_ref(i))
            out.append_view(u.to_view())
            out.append_view("}")
            i = i + 1
        }
        out.append_view("]}")
        return out
    }

    public func wrap_json_ld(objects : &vector<string>) : string {
        var out = string("{\"@context\":\"https://schema.org\",\"@graph\":[")
        var i : size_t = 0
        while(i < objects.size()) {
            if(i > 0) { out.append_view(",") }
            out.append_view(objects.at_ref(i).to_view())
            i = i + 1
        }
        out.append_view("]}")
        return out
    }

    // ---- Head assembly -------------------------------------------------
    // set_head escapes title/description/canonical. og tags and JSON-LD use
    // append_head_view with values escaped above. The resulting fragment is a
    // HtmlPage head, never a hand-built HTML string.
    public func seo_head_fragment(title : &string, description : &string,
                                  canonical : &string, jsonld : &string) : string {
        var scratch = HtmlPage()
        var head = PageHead {
            title = title.to_view(),
            description = description.to_view(),
            canonical = canonical.to_view(),
            noindex = false
        }
        scratch.set_head(&head)
        var og_title = string("<meta property=\"og:title\" content=\"")
        var et = underlayer_core::html_escape(title)
        og_title.append_view(et.to_view())
        og_title.append_view("\">")
        scratch.append_head_view(&og_title.to_view())
        var og_desc = string("<meta property=\"og:description\" content=\"")
        var ed = underlayer_core::html_escape(description)
        og_desc.append_view(ed.to_view())
        og_desc.append_view("\">")
        scratch.append_head_view(&og_desc.to_view())
        var og_url = string("<meta property=\"og:url\" content=\"")
        var eu = underlayer_core::html_escape(canonical)
        og_url.append_view(eu.to_view())
        og_url.append_view("\">")
        scratch.append_head_view(&og_url.to_view())
        if(jsonld.size() > 0) {
            var script = string("<script type=\"application/ld+json\">")
            script.append_view(jsonld.to_view())
            script.append_view("</script>")
            scratch.append_head_view(&script.to_view())
        }
        var result = scratch.getHead()
        return result.to_string()
    }

    // Replace the document's existing <title> with the generated head block.
    // Returns an unchanged copy when no <title> is present, so a renderer that
    // changes shape cannot produce a second title or a half-patched document.
    public func inject_seo_head(html : &string, fragment : &string) : string {
        var start = html.find_or_npos(string_view("<title>"))
        var end = html.find_or_npos(string_view("</title>"))
        if(start == std::NPOS || end == std::NPOS || end < start) {
            return html.copy()
        }
        var out = string()
        var whole = html.to_view()
        out.append_view(whole.subview(0, start))
        out.append_view(fragment.to_view())
        out.append_view(whole.subview(end + 8, html.size()))
        return out
    }

    // For per-request pages built from an HtmlPage directly.
    public func append_seo_head(page : &mut HtmlPage, title : &string,
                                description : &string, canonical_path : &string,
                                jsonld : &string) {
        var canonical = absolute_url(canonical_path)
        var fragment = seo_head_fragment(title, description, &canonical, jsonld)
        page.append_head_view(&fragment.to_view())
    }

}
