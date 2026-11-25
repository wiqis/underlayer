// underlayer_content — scanning primitives for the native lesson JSON.
//
// content cannot import web, so `find_from` is reimplemented here.  Every
// `subview(start,end)` uses ABSOLUTE indices and panics past the end, so each
// NPOS is checked before a slice.  These helpers read the already-rendered,
// journey-patched HTML; nothing here builds markup.
using std::string
using std::string_view

public namespace underlayer_content {

    // find_or_npos has no offset form: search a subview, translate back.
    public func nfind(s : &string, needle : &string_view, from : size_t) : size_t {
        if(from >= s.size()) { return std::NPOS }
        var rest = s.to_view().subview(from, s.size())
        var rel = rest.find_or_npos(needle)
        if(rel == std::NPOS) { return std::NPOS }
        return from + rel
    }

    public func nis_space(c : char) : bool {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r'
    }

    public func ntrim(s : &string) : string {
        var start : size_t = 0
        var end = s.size()
        while(start < end && nis_space(s.at(start))) { start = start + 1 }
        while(end > start && nis_space(s.at(end - 1))) { end = end - 1 }
        if(start >= end) { return string() }
        return s.substring(start, end)
    }

    public func nstarts(s : &string, prefix : std::string_view) : bool {
        if(prefix.size() > s.size()) { return false }
        var head = s.to_view().subview(0, prefix.size())
        var i : size_t = 0
        while(i < prefix.size()) {
            if(head.at(i) != prefix.at(i)) { return false }
            i = i + 1
        }
        return true
    }

    private func nreplace(s : &string, needle : &string_view, value : &string_view) : string {
        var out = string()
        var cursor : size_t = 0
        while(true) {
            var at = nfind(s, needle, cursor)
            if(at == std::NPOS) { break }
            out.append_view(s.to_view().subview(cursor, at))
            out.append_view(value)
            cursor = at + needle.size()
        }
        out.append_view(s.to_view().subview(cursor, s.size()))
        return out
    }

    // One entity, for the inline-text scanner.  A decoded entity is plain text
    // (or a space), never a tag.
    private func decode_one(entity : &string) : string {
        if(entity.size() == 5 && nstarts(entity, string_view("&amp;"))) { return string("&") }
        if(entity.size() == 6 && nstarts(entity, string_view("&quot;"))) { return string("\"") }
        if(entity.size() == 6 && nstarts(entity, string_view("&apos;"))) { return string("'") }
        if(entity.size() == 5 && nstarts(entity, string_view("&#39;"))) { return string("'") }
        if(entity.size() == 4 && nstarts(entity, string_view("&lt;"))) { return string("<") }
        if(entity.size() == 5 && nstarts(entity, string_view("&#60;"))) { return string("<") }
        if(entity.size() == 4 && nstarts(entity, string_view("&gt;"))) { return string(">") }
        if(entity.size() == 5 && nstarts(entity, string_view("&#62;"))) { return string(">") }
        if(entity.size() == 6 && nstarts(entity, string_view("&nbsp;"))) { return string(" ") }
        if(entity.size() == 7 && nstarts(entity, string_view("&mdash;"))) { return string(" - ") }
        if(entity.size() == 7 && nstarts(entity, string_view("&ndash;"))) { return string(" - ") }
        if(entity.size() == 7 && nstarts(entity, string_view("&#8212;"))) { return string(" - ") }
        if(entity.size() == 7 && nstarts(entity, string_view("&#8211;"))) { return string(" - ") }
        if(entity.size() == 7 && nstarts(entity, string_view("&#8216;"))) { return string("'") }
        if(entity.size() == 7 && nstarts(entity, string_view("&#8217;"))) { return string("'") }
        if(entity.size() == 7 && nstarts(entity, string_view("&#8220;"))) { return string("\"") }
        if(entity.size() == 7 && nstarts(entity, string_view("&#8221;"))) { return string("\"") }
        if(entity.size() == 6 && nstarts(entity, string_view("&#123;"))) { return string("{") }
        if(entity.size() == 6 && nstarts(entity, string_view("&#125;"))) { return string("}") }
        return entity.copy()
    }

    // Decode a run of entities anywhere in a string.  Used on attribute
    // values (data-remember / data-aim) and on code text.
    public func decode_entities(s : &string) : string {
        var a = nreplace(s, string_view("&amp;"), string_view("&"))
        var b = nreplace(&a, string_view("&quot;"), string_view("\""))
        var c = nreplace(&b, string_view("&apos;"), string_view("'"))
        var d = nreplace(&c, string_view("&#39;"), string_view("'"))
        var e = nreplace(&d, string_view("&lt;"), string_view("<"))
        var f = nreplace(&e, string_view("&#60;"), string_view("<"))
        var g = nreplace(&f, string_view("&gt;"), string_view(">"))
        var h = nreplace(&g, string_view("&#62;"), string_view(">"))
        var i = nreplace(&h, string_view("&nbsp;"), string_view(" "))
        var j = nreplace(&i, string_view("&mdash;"), string_view(" - "))
        var k = nreplace(&j, string_view("&ndash;"), string_view(" - "))
        var l = nreplace(&k, string_view("&#8212;"), string_view(" - "))
        var m = nreplace(&l, string_view("&#8211;"), string_view(" - "))
        var n = nreplace(&m, string_view("&#8216;"), string_view("'"))
        var o = nreplace(&n, string_view("&#8217;"), string_view("'"))
        var p = nreplace(&o, string_view("&#8220;"), string_view("\""))
        var q = nreplace(&p, string_view("&#8221;"), string_view("\""))
        var r = nreplace(&q, string_view("&#123;"), string_view("{"))
        return nreplace(&r, string_view("&#125;"), string_view("}"))
    }

    // The `>` ending the opening tag that starts at `at`.
    public func tag_end(s : &string, at : size_t) : size_t {
        var gt = string_view(">")
        return nfind(s, &gt, at)
    }

    // An attribute value from one opening tag, or "" when absent.
    public func tag_attr(s : &string, open : size_t, close : size_t, name : &string) : string {
        var pat = string()
        pat.append_string(name)
        pat.append_view("=\"")
        var pv = pat.to_view()
        var at = nfind(s, &pv, open)
        if(at == std::NPOS || at >= close) { return string() }
        var start = at + pat.size()
        if(start > close) { return string() }
        var quote = string_view("\"")
        var end = nfind(s, &quote, start)
        if(end == std::NPOS || end > close) { return string() }
        return s.substring(start, end)
    }

    // Depth-aware matching close tag.  A unit div can contain quiz / hex /
    // callout divs; a plain find of the first `</div>` would end it early.
    public func matching_close(s : &string, open_at : size_t, tag : &string) : size_t {
        var op = string("<")
        op.append_string(tag)
        var cl = string("</")
        cl.append_string(tag)
        var opv = op.to_view()
        var clv = cl.to_view()
        // Start AFTER the opening tag: counting it would make every nested
        // close look like the outer one and swallow the following units.
        var cursor = open_at
        var start_gt = tag_end(s, open_at)
        if(start_gt != std::NPOS) { cursor = start_gt + 1 }
        var depth : i64 = 0
        while(true) {
            var no = nfind(s, &opv, cursor)
            var nc = nfind(s, &clv, cursor)
            if(nc == std::NPOS) { return std::NPOS }
            if(no != std::NPOS && no < nc) {
                var after = no + op.size()
                if(after < s.size()) {
                    var c = s.at(after)
                    if(c == ' ' || c == '>' || c == '\t' || c == '\n' || c == '\r' || c == '/') {
                        depth = depth + 1
                    }
                }
                cursor = after
            } else {
                if(depth == 0) { return nc }
                depth = depth - 1
                cursor = nc + cl.size()
            }
        }
        return std::NPOS
    }

    // The earliest of several candidate positions.
    public func earliest(a : size_t, b : size_t) : size_t {
        if(a == std::NPOS) { return b }
        if(b == std::NPOS) { return a }
        if(a < b) { return a }
        return b
    }

    private func emit_plain(out : &mut string, text : &string, pending : &mut bool) {
        var i : size_t = 0
        while(i < text.size()) {
            var c = text.at(i)
            if(nis_space(c)) { *pending = true }
            else {
                if(*pending && out.size() > 0) { out.append(' ') }
                *pending = false
                out.append(c)
            }
            i = i + 1
        }
    }

    // Inline emphasis convention from the contract: backticks for code,
    // **bold**, *italic*.  Everything else is dropped, whitespace collapsed.
    private func emphasis_marker(tag : &string) : string {
        if(nstarts(tag, string_view("</code"))) { return string("`") }
        if(nstarts(tag, string_view("</kbd"))) { return string("`") }
        if(nstarts(tag, string_view("<code"))) { return string("`") }
        if(nstarts(tag, string_view("<kbd"))) { return string("`") }
        if(nstarts(tag, string_view("</strong"))) { return string("**") }
        if(nstarts(tag, string_view("</b>"))) { return string("**") }
        if(nstarts(tag, string_view("<strong"))) { return string("**") }
        if(nstarts(tag, string_view("<b>"))) { return string("**") }
        if(nstarts(tag, string_view("</em"))) { return string("*") }
        if(nstarts(tag, string_view("</i>"))) { return string("*") }
        if(nstarts(tag, string_view("<em"))) { return string("*") }
        if(nstarts(tag, string_view("<i>"))) { return string("*") }
        return string()
    }

    // Plain text: strip every tag, decode entities, collapse whitespace.
    public func inline_text(s : &string) : string {
        var out = string()
        var pending = false
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '<') {
                var gt = tag_end(s, i)
                if(gt == std::NPOS) { break }
                var tag = s.substring(i, gt + 1)
                var mark = emphasis_marker(&tag)
                if(mark.size() > 0) {
                    if(pending && out.size() > 0) { out.append(' ') }
                    pending = false
                    out.append_string(&mark)
                } else {
                    pending = true
                }
                i = gt + 1
            } else if(c == '&') {
                var semi = nfind(s, string_view(";"), i)
                if(semi == std::NPOS || semi - i > 12) {
                    emit_plain(&mut out, string("&"), &mut pending)
                    i = i + 1
                } else {
                    var ent = s.substring(i, semi + 1)
                    emit_plain(&mut out, decode_one(&ent), &mut pending)
                    i = semi + 1
                }
            } else {
                emit_plain(&mut out, s.substring(i, i + 1), &mut pending)
                i = i + 1
            }
        }
        return out
    }

}
