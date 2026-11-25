// underlayer_content — media blocks for the native lesson contract.
//
// quiz / hex / fill_blank are derived from the same rendered HTML the browser
// sees: the correct option is the one the lesson marked `true`, the hex bytes
// are the spans or the dump text, and a fill blank is an input's own answer.
// No fact is invented and no markup is authored here — this is JSON output.
using std::string
using std::string_view
using std::vector

public namespace underlayer_content {

    // A quiz div.  `question_text` is the nearest preceding paragraph in the
    // unit (the lesson does not put the question inside the quiz div).
    public func block_quiz(fragment : &string, question_text : &string) : string {
        var gt = tag_end(fragment, 0)
        if(gt == std::NPOS) { return string() }
        var id_raw = tag_attr(fragment, 0, gt, string("id"))
        var id = decode_entities(&id_raw)
        var options = vector<string>()
        var correct : i64 = -1
        var explanation = string()
        var cursor = gt + 1
        while(true) {
            var open_pat = string_view("<button")
            var bt = nfind(fragment, &open_pat, cursor)
            if(bt == std::NPOS) { break }
            var bgt = tag_end(fragment, bt)
            if(bgt == std::NPOS) { break }
            var tag = fragment.substring(bt, bgt + 1)
            var explain_raw = tag_attr(fragment, bt, bgt, string("data-explain"))
            var explain = decode_entities(&explain_raw)
            var true_pat = string_view(", true)")
            var marked = nfind(&tag, &true_pat, 0) != std::NPOS
            if(!marked) {
                var corr_raw = tag_attr(fragment, bt, bgt, string("data-correct"))
                var tr = string("true")
                if(corr_raw.equals(&tr)) { marked = true }
            }
            var close_pat = string_view("</button>")
            var close = nfind(fragment, &close_pat, bgt + 1)
            if(close == std::NPOS) { break }
            var raw_option = fragment.substring(bgt + 1, close)
            var text = inline_text(&raw_option)
            var t = jquote(&text)
            var e = jquote(&explain)
            var option = string("{\"text\":")
            option.append_string(&t)
            option.append_view(",\"explanation\":")
            option.append_string(&e)
            option.append('}')
            options.push(option)
            if(marked && correct < 0) {
                correct = (options.size() as i64) - 1
                explanation = explain.copy()
            }
            cursor = close + close_pat.size()
        }
        var q = jquote(question_text)
        var i = jquote(&id)
        var x = jquote(&explanation)
        var arr = jarray(&options)
        var ci = jint(correct)
        var out = string("{\"type\":\"quiz\",\"id\":")
        out.append_string(&i)
        out.append_view(",\"question\":")
        out.append_string(&q)
        out.append_view(",\"options\":")
        out.append_string(&arr)
        out.append_view(",\"correct_index\":")
        out.append_string(&ci)
        out.append_view(",\"explanation\":")
        out.append_string(&x)
        out.append('}')
        return out
    }

    private func push_word(out : &mut vector<string>, s : &string, from : size_t, to : size_t) {
        if(to <= from) { return }
        var piece = s.substring(from, to)
        out.push(ntrim(&piece))
    }

    private func split_dump(inner : &string) : vector<string> {
        var words = vector<string>()
        var start : size_t = 0
        var i : size_t = 0
        while(i < inner.size()) {
            if(nis_space(inner.at(i))) {
                if(i > start) { push_word(&mut words, inner, start, i) }
                start = i + 1
            }
            i = i + 1
        }
        if(inner.size() > start) { push_word(&mut words, inner, start, inner.size()) }
        return words
    }

    // A hex dump or the interactive byte viewer.  Interactive mode reads the
    // visible byte text from each span and its data-val as the label; dump
    // mode splits the <pre> text on whitespace.
    public func block_hex(fragment : &string) : string {
        var gt = tag_end(fragment, 0)
        if(gt == std::NPOS) { return string() }
        var tag = fragment.substring(0, gt + 1)
        var hex_pat = string_view("hex-interactive")
        var interactive = nfind(&tag, &hex_pat, 0) != std::NPOS
        var bytes = vector<string>()
        var labels = vector<string>()
        if(interactive) {
            var cursor = gt + 1
            while(true) {
                var span_pat = string_view("<span")
                var st = nfind(fragment, &span_pat, cursor)
                if(st == std::NPOS) { break }
                var sgt = tag_end(fragment, st)
                if(sgt == std::NPOS) { break }
                var close_pat = string_view("</span>")
                var close = nfind(fragment, &close_pat, sgt + 1)
                if(close == std::NPOS) { break }
                var label_raw = tag_attr(fragment, st, sgt, string("data-val"))
                var label = decode_entities(&label_raw)
                if(label.size() > 0) { labels.push(label) }
                var byte_raw = fragment.substring(sgt + 1, close)
                bytes.push(ntrim(&byte_raw))
                cursor = close + close_pat.size()
            }
        } else {
            var pre_pat = string_view("<pre")
            var pt = nfind(fragment, &pre_pat, gt + 1)
            if(pt != std::NPOS) {
                var pgt = tag_end(fragment, pt)
                var end_pat = string_view("</pre>")
                var pend = nfind(fragment, &end_pat, pgt + 1)
                if(pgt != std::NPOS && pend != std::NPOS) {
                    var dump_raw = fragment.substring(pgt + 1, pend)
                    var inner = decode_entities(&dump_raw)
                    bytes = split_dump(&inner)
                }
            }
        }
        var b = jstring_array(&bytes)
        var l = jstring_array(&labels)
        var mode = string("dump")
        if(interactive) { mode = string("interactive") }
        var m = jquote(&mode)
        var out = string("{\"type\":\"hex\",\"bytes\":")
        out.append_string(&b)
        out.append_view(",\"labels\":")
        out.append_string(&l)
        out.append_view(",\"mode\":")
        out.append_string(&m)
        out.append('}')
        return out
    }

    // A paragraph containing one or more `<input data-answer="...">`.
    // The text keeps `{{0}}`, `{{1}}` placeholders where the inputs were.
    public func block_fill_blank(paragraph : &string) : string {
        var text_raw = string()
        var blanks = vector<string>()
        var cursor : size_t = 0
        var ordinal : size_t = 0
        while(true) {
            var pat = string_view("<input")
            var at = nfind(paragraph, &pat, cursor)
            if(at == std::NPOS) { break }
            var gt = tag_end(paragraph, at)
            if(gt == std::NPOS) { break }
            var before = paragraph.substring(cursor, at)
            text_raw.append_view(before.to_view())
            var ord = jint(ordinal as i64)
            var ph = string("{{")
            ph.append_string(&ord)
            ph.append_view("}}")
            text_raw.append_string(&ph)
            var id_raw = tag_attr(paragraph, at, gt, string("id"))
            var answer_raw = tag_attr(paragraph, at, gt, string("data-answer"))
            var id = decode_entities(&id_raw)
            var answer = decode_entities(&answer_raw)
            var i = jquote(&id)
            var a = jquote(&answer)
            var blank = string("{\"id\":")
            blank.append_string(&i)
            blank.append_view(",\"answer\":")
            blank.append_string(&a)
            blank.append_view(",\"position\":")
            blank.append_string(&ord)
            blank.append('}')
            blanks.push(blank)
            ordinal = ordinal + 1
            cursor = gt + 1
        }
        var tail = paragraph.substring(cursor, paragraph.size())
        text_raw.append_view(tail.to_view())
        var text = inline_text(&text_raw)
        var t = jquote(&text)
        var arr = jarray(&blanks)
        var out = string("{\"type\":\"fill_blank\",\"text\":")
        out.append_string(&t)
        out.append_view(",\"blanks\":")
        out.append_string(&arr)
        out.append('}')
        return out
    }
}

