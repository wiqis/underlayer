// underlayer_content — text blocks for the native lesson contract.
//
// The walker reads one unit body in document order.  Only block-level tags
// become blocks; unknown tags are stepped over so nested markup inside a quiz,
// table or callout is never emitted twice.  Code text keeps its newlines;
// every other string is plain text with entities decoded.
using std::string
using std::string_view
using std::vector

public namespace underlayer_content {

    // Code text keeps newlines and indentation; only tags and entities change.
    private func code_text(s : &string) : string {
        var stripped = string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '<') {
                var gt = tag_end(s, i)
                if(gt == std::NPOS) { break }
                i = gt + 1
            } else {
                stripped.append(c)
                i = i + 1
            }
        }
        return decode_entities(&stripped)
    }

    private func element_end(s : &string, lt : size_t, gt : size_t, tag : &string) : size_t {
        var close = matching_close(s, lt, tag)
        if(close == std::NPOS) { return gt + 1 }
        var ce = tag_end(s, close)
        if(ce == std::NPOS) { return gt + 1 }
        return ce + 1
    }

    // `end` is the index just past the closing tag's '>'.  Subtract the close
    // tag so the inner slice never includes part of `</tag>`.
    private func inner_of(s : &string, gt : size_t, end : size_t, tag : &string) : string {
        if(end <= gt + 1) { return string() }
        var close_len = tag.size() + 3
        if(end < close_len) { return string() }
        var inner_end = end - close_len
        if(inner_end < gt + 1) { return string() }
        return s.substring(gt + 1, inner_end)
    }

    private func block_heading(level : i64, inner : &string) : string {
        var text = inline_text(inner)
        var q = jquote(&text)
        var l = jint(level)
        var out = string("{\"type\":\"heading\",\"level\":")
        out.append_string(&l)
        out.append_view(",\"text\":")
        out.append_string(&q)
        out.append('}')
        return out
    }

    private func block_code(inner : &string) : string {
        var text = code_text(inner)
        var q = jquote(&text)
        var out = string("{\"type\":\"code\",\"text\":")
        out.append_string(&q)
        out.append_view(",\"language\":null}")
        return out
    }

    private func block_paragraph(inner : &string) : string {
        var text = inline_text(inner)
        var q = jquote(&text)
        var out = string("{\"type\":\"paragraph\",\"text\":")
        out.append_string(&q)
        out.append('}')
        return out
    }

    private func block_list(fragment : &string, ordered : bool) : string {
        var items = vector<string>()
        var cursor : size_t = 0
        while(true) {
            var pat = string_view("<li")
            var at = nfind(fragment, &pat, cursor)
            if(at == std::NPOS) { break }
            var gt = tag_end(fragment, at)
            if(gt == std::NPOS) { break }
            var tag = string("li")
            var end = element_end(fragment, at, gt, &tag)
            if(end <= gt + 1) { break }
            var inner = inner_of(fragment, gt, end, &tag)
            var text = inline_text(&inner)
            items.push(jquote(&text))
            cursor = end
        }
        var arr = jarray(&items)
        var o = jbool(ordered)
        var out = string("{\"type\":\"list\",\"ordered\":")
        out.append_string(&o)
        out.append_view(",\"items\":")
        out.append_string(&arr)
        out.append('}')
        return out
    }

    private func block_callout(fragment : &string, class_attr : &string) : string {
        var variant = string("note")
        var warn = string_view("callout-warn")
        var tip = string_view("callout-tip")
        if(nfind(class_attr, &warn, 0) != std::NPOS) { variant = string("warn") }
        else if(nfind(class_attr, &tip, 0) != std::NPOS) { variant = string("tip") }
        var gt = tag_end(fragment, 0)
        if(gt == std::NPOS) { return string() }
        var tag = string("div")
        var end = element_end(fragment, 0, gt, &tag)
        if(end <= gt + 1) { return string() }
        var inner = inner_of(fragment, gt, end, &tag)
        var text = inline_text(&inner)
        var t = jquote(&text)
        var v = jquote(&variant)
        var out = string("{\"type\":\"callout\",\"variant\":")
        out.append_string(&v)
        out.append_view(",\"text\":")
        out.append_string(&t)
        out.append('}')
        return out
    }

    // Walk a unit body once, emitting one JSON block per recognized element.
    public func native_blocks(body : &string) : string {
        var blocks = vector<string>()
        var last_paragraph = string()
        var cursor : size_t = 0
        while(cursor < body.size()) {
            var lt_pat = string_view("<")
            var lt = nfind(body, &lt_pat, cursor)
            if(lt == std::NPOS) { break }
            var gt = tag_end(body, lt)
            if(gt == std::NPOS) { break }
            var tag = body.substring(lt, gt + 1)
            if(nstarts(&tag, string_view("</"))) { cursor = gt + 1; continue }
            var tag_p = string("p")
            var tag_table = string("table")
            var tag_div = string("div")
            if(nstarts(&tag, string_view("<h3")) || nstarts(&tag, string_view("<h4"))) {
                var tag_h = string("h3")
                var end = element_end(body, lt, gt, &tag_h)
                if(end <= gt + 1) { break }
                var inner = inner_of(body, gt, end, &tag_h)
                var level : i64 = 3
                if(nstarts(&tag, string_view("<h4"))) { level = 4 }
                blocks.push(block_heading(level, &inner))
                cursor = end
                continue
            }
            if(nstarts(&tag, string_view("<p>")) || nstarts(&tag, string_view("<p "))) {
                var end = element_end(body, lt, gt, &tag_p)
                if(end <= gt + 1) { break }
                var fragment = body.substring(lt, end)
                var inner = inner_of(body, gt, end, &tag_p)
                var blank_pat = string_view("class=\"fill-blank")
                var input_pat = string_view("<input")
                if(nfind(&inner, &blank_pat, 0) != std::NPOS || nfind(&inner, &input_pat, 0) != std::NPOS) {
                    blocks.push(block_fill_blank(&fragment))
                } else {
                    blocks.push(block_paragraph(&inner))
                    last_paragraph = inline_text(&inner)
                }
                cursor = end
                continue
            }
            if(nstarts(&tag, string_view("<pre"))) {
                var tag_pre = string("pre")
                var end = element_end(body, lt, gt, &tag_pre)
                if(end <= gt + 1) { break }
                var inner = inner_of(body, gt, end, &tag_pre)
                blocks.push(block_code(&inner))
                cursor = end
                continue
            }
            if(nstarts(&tag, string_view("<ul")) || nstarts(&tag, string_view("<ol"))) {
                var ordered = nstarts(&tag, string_view("<ol"))
                var tag_ul = string("ul")
                var end = element_end(body, lt, gt, &tag_ul)
                if(end <= gt + 1) { break }
                var fragment = body.substring(lt, end)
                blocks.push(block_list(&fragment, ordered))
                cursor = end
                continue
            }
            if(nstarts(&tag, string_view("<table"))) {
                var end = element_end(body, lt, gt, &tag_table)
                if(end <= gt + 1) { break }
                var fragment = body.substring(lt, end)
                blocks.push(block_table(&fragment))
                cursor = end
                continue
            }
            if(nstarts(&tag, string_view("<div"))) {
                var class_attr = tag_attr(body, lt, gt, string("class"))
                var quiz = string_view("class=\"quiz")
                var hex = string_view("hex-")
                var callout = string_view("callout")
                var end = element_end(body, lt, gt, &tag_div)
                if(end <= gt + 1) { break }
                var fragment = body.substring(lt, end)
                if(nfind(&tag, &quiz, 0) != std::NPOS) {
                    blocks.push(block_quiz(&fragment, &last_paragraph))
                } else if(nfind(&tag, &hex, 0) != std::NPOS) {
                    blocks.push(block_hex(&fragment))
                } else if(nfind(&class_attr, &callout, 0) != std::NPOS) {
                    blocks.push(block_callout(&fragment, &class_attr))
                }
                cursor = end
                continue
            }
            cursor = gt + 1
        }
        var arr = jarray(&blocks)
        return arr
    }
}
