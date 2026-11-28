// underlayer_web — G6 "Download this course" control.
//
// Offline content is the course's existing static pages; the button asks the
// service worker to cache those same-origin lesson URLs. No Pages URL, no new
// route and no hand-built markup: the button is a #html block, its script a
// #js block, both emitted on a scratch page and injected beside the enrol
// control. The course id is HTML-escaped before it reaches an attribute.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_download_control(course_id : &string) : string {
        var safe = underlayer_core::html_escape(course_id)
        var page = HtmlPage()
        #html {
            <button type="button" class="ul-download-btn" id="ul-download-course" data-course={safe}>Download this course</button>
            <span class="ul-download-note" id="ul-download-note" role="status" hidden>Caching lessons for offline use...</span>
        }
        return page.toStringHtmlOnly()
    }

    public func render_download_js() : string {
        var page = HtmlPage()
        #js {
            document.addEventListener('DOMContentLoaded', function() {
                var b = document.getElementById('ul-download-course');
                if (!b) { return; }
                b.onclick = function() {
                    var note = document.getElementById('ul-download-note');
                    if (note) { note.hidden = false; }
                    if (typeof window.__ulCacheCourse === 'function') {
                        window.__ulCacheCourse(b.getAttribute('data-course'));
                    }
                    if (note) { note.textContent = 'Lessons will be available offline after this visit.'; }
                };
            });
        }
        return page.toStringJsOnly()
    }

    public func apply_download_control(src : &string, course_id : &string) : string {
        var marker = src.find_or_npos(string_view("course-actions"))
        if(marker == std::NPOS) { return src.copy() }
        var gt = src.to_view().subview(marker, src.size()).find_or_npos(string_view(">"))
        if(gt == std::NPOS) { return src.copy() }
        var payload = render_download_control(course_id)
        payload.append_view("<style>.ul-download-btn{font:inherit;font-size:.92rem;font-weight:600;padding:.5rem 1rem;border-radius:8px;border:1px solid hsl(var(--border));background:hsl(var(--card));color:hsl(var(--foreground));cursor:pointer}.ul-download-note{font-size:.8rem;color:hsl(var(--muted-foreground));margin-left:.5rem}</style>")
        var js = render_download_js()
        if(js.size() > 0) {
            payload.append_view("<script>")
            payload.append_view(js.to_view())
            payload.append_view("</script>")
        }
        var at = marker + gt + 1
        var built = string()
        built.append_view(src.to_view().subview(0, at))
        built.append_string(&payload)
        built.append_view(src.to_view().subview(at, src.size()))
        return built
    }

}
