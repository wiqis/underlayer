// underlayer_web — S-1: structured unit index for the Android stepper.
//
// GET /api/courses/:courseId/lessons/:conceptId/units
//
// The lesson body is the real HTML produced by render_concept; this endpoint
// derives its step list from that exact document rather than from a second
// hand-maintained index, so the ids a client steps through are the ids present
// in the page.  Only the semantic `class="unit unit-*"` blocks and their
// `<h2>` titles are read.
//
// Response shape (exact):
// {
//   "course_id": "elf",
//   "concept_id": "bytes",
//   "units": [
//     {"id":"unit-why","kind":"why","title":"Why This Matters","order":1},
//     {"id":"unit-model","kind":"model","title":"A Simple Model","order":2}
//   ]
// }
//
// `id` is "unit-" + `kind`; `order` is 1-based document order.  An empty
// `units` array means the rendered lesson has no semantic units.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    public func handle_lesson_units(
        courses_dir : &string,
        course_id : &string_view,
        concept_id : &string_view,
        req : &http::Request
    ) : http::Response {
        var cid = sv_to_string(course_id)
        var pid = sv_to_string(concept_id)
        // Shared with /native: render_concept dispatches GLOBALLY by concept
        // id, so a mismatched pair must be refused in one place only.
        var check = validate_lesson_pair(courses_dir, course_id, concept_id)
        if(!check.ok) { return send_error(check.error_status, &check.error_message) }
        var html = render_concept(&pid)
        if(html.size() == 0) {
            var err3 = string("lesson not found")
            return send_error(404u, &err3)
        }

        var fragments = unit_fragments(&html)
        var body = string("{\"course_id\":\"")
        var ce = underlayer_core::json_escape(&cid.to_view())
        body.append_string(&ce)
        body.append_view("\",\"concept_id\":\"")
        var pe = underlayer_core::json_escape(&pid.to_view())
        body.append_string(&pe)
        body.append_view("\",\"units\":[")
        var i : size_t = 0
        while(i < fragments.size()) {
            if(i > 0) { body.append_view(",") }
            body.append_string(fragments.at_ref(i))
            i = i + 1
        }
        body.append_view("]}")
        return send_json_str(&body)
    }

    // Walk the rendered document once, emitting one JSON object per
    // `class="unit unit-<kind>"` block.  The `<h2>` title is bounded by the
    // next unit block so a unit without a heading cannot borrow its
    // neighbour's.
    private func unit_fragments(html : &string) : vector<string> {
        var out = vector<string>()
        var marker = std::string_view("class=\"unit unit-")
        var quote = std::string_view("\"")
        var h2_open = std::string_view("<h2>")
        var h2_close = std::string_view("</h2>")
        var pos : size_t = 0
        var order : i64 = 0
        while(true) {
            var at = find_from(html, &marker, pos)
            if(at == std::NPOS) { break }
            var kind_start = at + marker.size()
            var kind_end = find_from(html, &quote, kind_start)
            if(kind_end == std::NPOS) { break }
            var kind_view = html.to_view().subview(kind_start, kind_end)
            var kind = sv_to_string(&kind_view)
            if(kind.size() > 0) {
                order = order + 1
                var title = string()
                var h2_at = find_from(html, &h2_open, kind_end)
                var next_unit = find_from(html, &marker, kind_end + 1)
                if(h2_at != std::NPOS) {
                    var title_start = h2_at + h2_open.size()
                    var title_end = find_from(html, &h2_close, title_start)
                    if(title_end != std::NPOS && (next_unit == std::NPOS || title_end < next_unit)) {
                        var title_view = html.to_view().subview(title_start, title_end)
                        title = sv_to_string(&title_view)
                    }
                }
                var frag = string("{\"id\":\"unit-")
                frag.append_string(&kind)
                frag.append_view("\",\"kind\":\"")
                frag.append_string(&kind)
                frag.append_view("\",\"title\":\"")
                var te = underlayer_core::json_escape(&title.to_view())
                frag.append_string(&te)
                frag.append_view("\",\"order\":")
                var order_str = underlayer_core::int_to_string(order)
                frag.append_string(&order_str)
                frag.append_view("}")
                out.push(frag)
            }
            pos = kind_end + 1
        }
        return out
    }

}
