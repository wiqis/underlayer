// underlayer_content — inject one journey shell into any rendered lesson page.
//
// The CSS, JS and markup are produced by #css / #js / #html macros in this
// module and only MOVED into the target document here.  No markup is authored
// with string appends: the string work in this file is sentinel replacement of
// the same kind used by web/src/lesson_pager.ch and web/src/lesson_header.ch.
//
// The same entry point is used by the backend (web/src/journey_apply.ch) and by
// the static-page injector, so a lesson served by the server and a lesson opened
// from file:// receive byte-identical journey assets.
using std::string
using std::string_view

public namespace underlayer_content {

    public func journey_css_fragment() : string {
        var p = HtmlPage()
        render_journey_css(&mut p)
        return p.toStringCssOnly()
    }

    public func journey_js_fragment() : string {
        var p = HtmlPage()
        render_journey_js(&mut p)
        return p.toStringJsOnly()
    }

    public func journey_markup_fragment() : string {
        var p = HtmlPage()
        render_journey_markup(&mut p)
        return p.toStringHtmlOnly()
    }

    // Replace an empty data-* attribute on the injected shell.  A no-op when the
    // page already carries a journey (idempotent) or the attribute is absent.
    public func patch_journey_attr(src : &string, name : &string, value : &string) : string {
        if(src.find_or_npos(string_view("journey-shell")) == std::NPOS) { return src.copy() }
        var needle = string("data-")
        needle.append_string(name)
        needle.append_view("=\"\"")
        var at = src.find_or_npos(needle.to_view())
        if(at == std::NPOS) { return src.copy() }
        var escaped = underlayer_core::html_escape(value)
        var replacement = string("data-")
        replacement.append_string(name)
        replacement.append_view("=\"")
        replacement.append_view(escaped.to_view())
        replacement.append_view("\"")
        var built = std::string()
        built.append_view(src.to_view().subview(0, at))
        built.append_string(&replacement)
        built.append_view(src.to_view().subview(at + needle.size(), src.size()))
        return built
    }

    // The one clear starting path on a course landing page.  The lesson list is
    // still on the page; this is the single action above it.
    public func render_start_panel_component(href : &string, title : &string, lesson_count : &string, page : &mut HtmlPage) {
        #html {
            <div class="journey-start-panel">
                <p class="journey-start-eyebrow">Start here</p>
                <p class="journey-start-line">One guided path through this course, one idea at a time.</p>
                <a class="journey-btn journey-start" href={href}>Begin with {title}</a>
                <p class="journey-start-note">{lesson_count} lessons in this course. The full list stays below.</p>
            </div>
        }
    }

    public func start_panel_html(href : &string, title : &string, lesson_count : &string) : string {
        var p = HtmlPage()
        render_start_panel_component(href, title, lesson_count, &mut p)
        return p.toStringHtmlOnly()
    }

    public func apply_start_panel(src : &string, href : &string, title : &string, lesson_count : &string) : string {
        var panel = start_panel_html(href, title, lesson_count)
        if(panel.size() == 0) { return src.copy() }
        var style = string("<style>")
        var css = journey_css_fragment()
        style.append_string(&css)
        style.append_view("</style>")
        var payload = std::string()
        payload.append_string(&style)
        payload.append_string(&panel)
        var at = src.find_or_npos(string_view("</h1>"))
        if(at == std::NPOS) { return src.copy() }
        var built = std::string()
        built.append_view(src.to_view().subview(0, at + 5))
        built.append_string(&payload)
        built.append_view(src.to_view().subview(at + 5, src.size()))
        return built
    }

    public func apply_journey_to_document(src : &string) : string {
        // A lesson that already emits the shell from shared lesson assets is left
        // untouched.  This is what stops double IDs when both paths are active.
        if(src.find_or_npos(string_view("journey-shell")) != std::NPOS) { return src.copy() }
        var css = journey_css_fragment()
        var js = journey_js_fragment()
        var markup = journey_markup_fragment()
        if(css.size() == 0 || js.size() == 0 || markup.size() == 0) { return src.copy() }

        var style = string("<style>")
        style.append_string(&css)
        style.append_view("</style>")
        var script = string("<script>")
        script.append_string(&js)
        script.append_view("</script>")

        var with_css = std::string()
        var head_at = src.find_or_npos(string_view("</head>"))
        if(head_at == std::NPOS) {
            with_css = src.copy()
        } else {
            with_css.append_view(src.to_view().subview(0, head_at))
            with_css.append_string(&style)
            with_css.append_view(src.to_view().subview(head_at, src.size()))
        }

        var body_at = with_css.find_or_npos(string_view("</body>"))
        if(body_at == std::NPOS) { return with_css }
        var final = std::string()
        final.append_view(with_css.to_view().subview(0, body_at))
        final.append_string(&markup)
        final.append_string(&script)
        final.append_view(with_css.to_view().subview(body_at, with_css.size()))
        return final
    }
}
