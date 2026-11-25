// underlayer_content — the step list of a native lesson.
//
// Walks `class="unit unit-*"` in document order.  The remember / aim values
// are read from the journey-patched opening tag (data-remember / data-aim), so
// they are the platform's own derived takeaways, never a new guess here.
// `order` is the unique key: id duplicates are preserved by design.
using std::string
using std::string_view
using std::vector

public namespace underlayer_content {

    public struct NativeUnit {
        var id : string
        var kind : string
        var title : string
        var remember : string
        var aim : string
        var order : i64
        var blocks : string

        @make
        func make() : NativeUnit {
            return NativeUnit {
                id = string(),
                kind = string(),
                title = string(),
                remember = string(),
                aim = string(),
                order = 0,
                blocks = string()
            }
        }
    }

    public func native_unit_json(u : &NativeUnit) : string {
        var i = jquote(&u.id)
        var k = jquote(&u.kind)
        var t = jquote(&u.title)
        var r = jquote(&u.remember)
        var o = jint(u.order)
        var out = string("{\"id\":")
        out.append_string(&i)
        out.append_view(",\"kind\":")
        out.append_string(&k)
        out.append_view(",\"title\":")
        out.append_string(&t)
        out.append_view(",\"order\":")
        out.append_string(&o)
        out.append_view(",\"remember\":")
        out.append_string(&r)
        out.append_view(",\"blocks\":")
        out.append_string(&u.blocks)
        out.append('}')
        return out
    }

    public func native_units(html : &string) : vector<NativeUnit> {
        var out = vector<NativeUnit>()
        var marker = string_view("class=\"unit unit-")
        var quote = string_view("\"")
        var h2 = string_view("<h2")
        var h2_close = string_view("</h2>")
        var div = string("div")
        var remember_name = string("data-remember")
        var aim_name = string("data-aim")
        var no_fact = string("No new fact to memorise - this step is about seeing the link")
        var pos : size_t = 0
        var order : i64 = 0
        while(true) {
            var at = nfind(html, &marker, pos)
            if(at == std::NPOS) { break }
            var kind_start = at + marker.size()
            var kind_end = nfind(html, &quote, kind_start)
            if(kind_end == std::NPOS || kind_end > html.size()) { break }
            var kind_raw = html.substring(kind_start, kind_end)
            var kind = ntrim(&kind_raw)
            if(kind.size() > 0) {
                // The marker sits inside the opening tag; walk back to its '<'.
                var lt = at
                while(lt > 0 && html.at(lt - 1) != '<') { lt = lt - 1 }
                var gt = tag_end(html, lt)
                if(gt == std::NPOS) { break }
                var open = html.substring(lt, gt + 1)
                var remember_raw = tag_attr(&open, 0, gt - lt, &remember_name)
                var aim_raw = tag_attr(&open, 0, gt - lt, &aim_name)
                var remember = decode_entities(&remember_raw)
                var aim = decode_entities(&aim_raw)
                if(remember.size() == 0) { remember = no_fact.copy() }
                order = order + 1

                var close = matching_close(html, lt, &div)
                var close_end : size_t = gt + 1
                var body_end : size_t = gt + 1
                if(close != std::NPOS) {
                    body_end = close
                    var ce = tag_end(html, close)
                    if(ce != std::NPOS) { close_end = ce + 1 }
                }
                if(body_end <= gt + 1) { break }
                var body = html.substring(gt + 1, body_end)

                var title = string()
                var h2_at = nfind(&body, &h2, 0)
                if(h2_at != std::NPOS) {
                    var hgt = tag_end(&body, h2_at)
                    var hend = nfind(&body, &h2_close, hgt + 1)
                    if(hgt != std::NPOS && hend != std::NPOS && hend > hgt) {
                        var title_raw = body.substring(hgt + 1, hend)
                        title = inline_text(&title_raw)
                    }
                }

                var unit = NativeUnit::make()
                unit.kind = kind.copy()
                var uid = string("unit-")
                uid.append_string(&kind)
                unit.id = uid
                unit.title = title
                unit.remember = remember
                unit.aim = aim
                unit.order = order
                unit.blocks = native_blocks(&body)
                out.push(unit)
                pos = close_end
                continue
            }
            pos = kind_end + 1
        }
        return out
    }
}
