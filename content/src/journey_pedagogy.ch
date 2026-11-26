// underlayer_content — derive per-step pedagogy from the lesson itself.
//
// NOTHING HERE INVENTS A FACT.  Every attribute value is copied out of text that
// is already in the lesson (or its manifest): the strongest existing sentence,
// an existing question, an existing correct option / answer / explanation, and
// the finish unit's own wording.  When a unit has no such text the explicit
// "No new fact to memorise" sentence is emitted instead of a guess.
//
// This is the single choke point for all 469 lessons.  The backend calls it
// through web/src/journey_apply.ch and pre-rendered pages call it through
// scripts/journey_inject/src/main.ch, so no lesson file is hand-edited.  The
// string work below only INSERTS attributes into tags that the #html macro
// already emitted; no element is built by string concatenation.
using std::string
using std::string_view

public namespace underlayer_content {

    private func jpFindFrom(s : &string, needle : &string_view, from : size_t) : size_t {
        if(from >= s.size()) { return std::NPOS }
        var at = s.to_view().subview(from, s.size()).find_or_npos(needle)
        if(at == std::NPOS) { return std::NPOS }
        return from + at
    }

    private func jpIsSpace(c : char) : bool {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r'
    }

    private func jpReplace(s : &string, needle : &string_view, value : &string_view) : string {
        var out = string()
        var cursor : size_t = 0
        while(true) {
            var at = jpFindFrom(s, needle, cursor)
            if(at == std::NPOS) { break }
            out.append_view(s.to_view().subview(cursor, at))
            out.append_view(value)
            cursor = at + needle.size()
        }
        out.append_view(s.to_view().subview(cursor, s.size()))
        return out
    }

    private func jpDecode(s : &string) : string {
        var out = jpReplace(s, string_view("&amp;"), string_view("&"))
        var a = jpReplace(&out, string_view("&quot;"), string_view("\""))
        var b = jpReplace(&a, string_view("&#39;"), string_view("'"))
        var c = jpReplace(&b, string_view("&lt;"), string_view("<"))
        var d = jpReplace(&c, string_view("&gt;"), string_view(">"))
        // Numeric punctuation used by the lesson corpus. Rendered as ASCII so
        // an attribute never carries a double-encoded entity or a raw non-ASCII
        // byte into the #html output.
        var e = jpReplace(&d, string_view("&#8212;"), string_view(" - "))
        var f = jpReplace(&e, string_view("&#8211;"), string_view(" - "))
        var g = jpReplace(&f, string_view("&#8216;"), string_view("'"))
        var h = jpReplace(&g, string_view("&#8217;"), string_view("'"))
        var i = jpReplace(&h, string_view("&#8220;"), string_view("\""))
        return jpReplace(&i, string_view("&#8221;"), string_view("\""))
    }

    private func jpStripTags(s : &string) : string {
        var out = string()
        var in_tag = false
        var pending = false
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '<') { in_tag = true; pending = true }
            else if(c == '>') { in_tag = false }
            else if(!in_tag) {
                if(jpIsSpace(c)) { pending = true }
                else {
                    if(pending && out.size() > 0) { out.append(' ') }
                    pending = false
                    out.append(c)
                }
            }
            i = i + 1
        }
        return out
    }

    private func jpClean(s : &string) : string {
        var stripped = jpStripTags(s)
        return jpDecode(&stripped)
    }

    private func jpWords(s : &string, limit : size_t) : string {
        var out = string()
        var count : size_t = 0
        var i : size_t = 0
        while(i < s.size()) {
            while(i < s.size() && jpIsSpace(s.at(i))) { i = i + 1 }
            if(i >= s.size()) { break }
            var start = i
            while(i < s.size() && !jpIsSpace(s.at(i))) { i = i + 1 }
            if(count >= limit) { out.append_view(string_view("...")); return out }
            if(count > 0) { out.append(' ') }
            out.append_view(s.to_view().subview(start, i))
            count = count + 1
        }
        return out
    }

    private func jpFirstSentence(s : &string) : string {
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '.' || c == '?' || c == '!') {
                if(i + 1 >= s.size() || jpIsSpace(s.at(i + 1))) { return s.substring(0, i + 1) }
            }
            i = i + 1
        }
        return s.copy()
    }

    private func jpInner(s : &string, open : &string_view, close : &string_view) : string {
        var a = jpFindFrom(s, open, 0)
        if(a == std::NPOS) { return string() }
        var gt = jpFindFrom(s, string_view(">"), a)
        if(gt == std::NPOS) { return string() }
        var b = jpFindFrom(s, close, gt + 1)
        if(b == std::NPOS) { return string() }
        return s.substring(gt + 1, b)
    }

    private func jpAttr(s : &string, open : &string_view) : string {
        var a = jpFindFrom(s, open, 0)
        if(a == std::NPOS) { return string() }
        var start = a + open.size()
        var end = jpFindFrom(s, string_view("\""), start)
        if(end == std::NPOS) { return string() }
        return s.substring(start, end)
    }

    private func jpFillAnswers(html : &string) : string {
        var out = string()
        var cursor : size_t = 0
        while(true) {
            var at = jpFindFrom(html, string_view("<input"), cursor)
            if(at == std::NPOS) { break }
            var gt = jpFindFrom(html, string_view(">"), at)
            if(gt == std::NPOS) { break }
            var tag_text = html.substring(at, gt + 1)
            var value = jpAttr(&tag_text, string_view("data-answer=\""))
            out.append_view(html.to_view().subview(cursor, at))
            out.append_view(value.to_view())
            cursor = gt + 1
        }
        out.append_view(html.to_view().subview(cursor, html.size()))
        return out
    }

    private func jpNoFact() : string {
        return string("No new fact to memorise - this step is about seeing the link")
    }

    private func jpTitle(slice : &string) : string {
        var heading_text = jpInner(slice, string_view("<h2"), string_view("</h2>"))
        var clean = jpClean(&heading_text)
        return jpWords(&clean, 12)
    }

    // A takeaway must be a fact the learner can carry into the next step.
    // The corpus uses <strong> for emphasis of a term as often as for the key
    // idea, so an emphasised word ("not", "calling convention", "file format")
    // is not a takeaway. Prefer a complete sentence from the step's own prose;
    // every word still comes from that lesson, nothing is invented here.
    private func jpTrimmed(s : &string) : string {
        var a : size_t = 0
        var b : size_t = s.size()
        while(a < b && jpIsSpace(s.at(a))) { a = a + 1 }
        while(b > a && jpIsSpace(s.at(b - 1))) { b = b - 1 }
        return s.substring(a, b)
    }

    private func jpCountWords(s : &string) : size_t {
        var count : size_t = 0
        var i : size_t = 0
        while(i < s.size()) {
            while(i < s.size() && jpIsSpace(s.at(i))) { i = i + 1 }
            if(i >= s.size()) { break }
            count = count + 1
            while(i < s.size() && !jpIsSpace(s.at(i))) { i = i + 1 }
        }
        return count
    }

    private func jpSentenceGood(s : &string) : bool {
        var t = jpTrimmed(s)
        var n = jpCountWords(&t)
        if(n < 5 || n > 25) { return false }
        if(t.size() == 0) { return false }
        var last = t.at(t.size() - 1)
        // A takeaway is a fact to carry forward, never a question. On a quiz
        // step the first <p> is the question itself; presenting that as
        // "Remember this" tells the learner nothing to keep in their head.
        if(last != '.' && last != '!') { return false }
        var lead = string_view("Here is ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("Here are ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("Now ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("So ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("Look ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("Try ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("Think ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("You saw ")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        lead = string_view("The payoff")
        if(jpFindFrom(&t, &lead, 0) == 0) { return false }
        // A hex-dump row is evidence, not a takeaway. It starts with eight
        // hex digits and a colon; leave it in the lesson and pick another
        // sentence instead of calling the dump the key idea.
        if(t.size() > 9) {
            var hexrun = true
            var h : size_t = 0
            while(h < 8) {
                var c = t.at(h)
                if(!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) { hexrun = false }
                h = h + 1
            }
            if(hexrun && t.at(8) == ':') { return false }
        }
        return true
    }

    private func jpLooseSentence(s : &string) : bool {
        var t = jpTrimmed(s)
        if(t.size() == 0) { return false }
        if(jpCountWords(&t) < 5) { return false }
        var last = t.at(t.size() - 1)
        return last == '.' || last == '!'
    }

    // Return the first sentence and leave the remainder in `rest`.
    private func jpNextSentence(s : &string, rest : &mut string) : string {
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '.' || c == '?' || c == '!') {
                if(i + 1 >= s.size() || jpIsSpace(s.at(i + 1))) {
                    var first = s.substring(0, i + 1)
                    *rest = s.substring(i + 1, s.size())
                    return jpTrimmed(&first)
                }
            }
            i = i + 1
        }
        *rest = s.substring(s.size(), s.size())
        return jpTrimmed(s)
    }

    private func jpKeySentence(slice : &string) : string {
        var cursor : size_t = 0
        var loose = string()
        var paras : size_t = 0
        while(paras < 12) {
            var next = jpFindFrom(slice, string_view("<p"), cursor)
            if(next == std::NPOS) { break }
            var gt = jpFindFrom(slice, string_view(">"), next)
            if(gt == std::NPOS) { break }
            var close = jpFindFrom(slice, string_view("</p>"), gt + 1)
            if(close == std::NPOS) { break }
            var para_raw = slice.substring(gt + 1, close)
            var filled = jpFillAnswers(&para_raw)
            var clean = jpClean(&filled)
            var rest = string()
            var sentence = jpNextSentence(&clean, &mut rest)
            var n = 0
            while(sentence.size() > 0 && n < 8) {
                if(jpSentenceGood(&sentence)) { return jpWords(&sentence, 25) }
                if(loose.size() == 0 && jpLooseSentence(&sentence)) { loose = jpWords(&sentence, 25) }
                var next_rest = string()
                var next_sentence = jpNextSentence(&rest, &mut next_rest)
                sentence = next_sentence
                rest = next_rest
                n = n + 1
            }
            cursor = close + 4
            paras = paras + 1
        }
        return loose
    }

    // A quiz step often has no prose fact: its only full sentence is the
    // question. The correct option's own explanation (now authored from the
    // lesson text in every ELF concept) is a fact and is safe to carry forward.
    private func jpQuizFact(slice : &string) : string {
        var cursor : size_t = 0
        while(true) {
            var open = jpFindFrom(slice, string_view("<button"), cursor)
            if(open == std::NPOS) { break }
            var gt = jpFindFrom(slice, string_view(">"), open)
            if(gt == std::NPOS) { break }
            var tag = slice.substring(open, gt + 1)
            var marked = tag.find_or_npos(string_view(", true)")) != std::NPOS
            if(!marked) { marked = tag.find_or_npos(string_view("data-correct=\"true\"")) != std::NPOS }
            if(marked) {
                var explain_raw = jpAttr(&tag, string_view("data-explain=\""))
                var explain = jpDecode(&explain_raw)
                var first = jpFirstSentence(&explain)
                if(jpSentenceGood(&first)) { return jpWords(&first, 25) }
                var lt = jpFindFrom(slice, string_view("<"), gt + 1)
                if(lt != std::NPOS) {
                    var text_raw = slice.substring(gt + 1, lt)
                    var text = jpClean(&text_raw)
                    if(jpSentenceGood(&text)) { return jpWords(&text, 25) }
                }
            }
            cursor = gt + 1
        }
        return string()
    }

    private func jpRemember(slice : &string) : string {
        var key = jpKeySentence(slice)
        if(key.size() > 0) { return key }
        var quiz = jpQuizFact(slice)
        if(quiz.size() > 0) { return quiz }
        var strong_raw = jpInner(slice, string_view("<strong"), string_view("</strong>"))
        var strong = jpClean(&strong_raw)
        if(jpSentenceGood(&strong)) { return jpWords(&strong, 25) }
        var bold_raw = jpInner(slice, string_view("<b>"), string_view("</b>"))
        var bold = jpClean(&bold_raw)
        if(jpSentenceGood(&bold)) { return jpWords(&bold, 25) }
        var para_raw = jpInner(slice, string_view("<p"), string_view("</p>"))
        var para_filled = jpFillAnswers(&para_raw)
        var para_clean = jpClean(&para_filled)
        var para = jpFirstSentence(&para_clean)
        // An instruction ending in ":" is not a fact to carry forward. Say so
        // plainly rather than turning a label into a fake takeaway.
        if(jpLooseSentence(&para)) { return jpWords(&para, 25) }
        return jpNoFact()
    }

    private func jpQuestion(slice : &string, previous : &string) : string {
        var para_raw = jpInner(slice, string_view("<p"), string_view("</p>"))
        var clean = jpClean(&para_raw)
        var mark = clean.find_or_npos(string_view("?"))
        if(mark != std::NPOS) {
            var start : size_t = 0
            var i : size_t = mark
            while(i > 0) {
                var c = clean.at(i - 1)
                if(c == '.' || c == '?' || c == '!') { start = i; break }
                i = i - 1
            }
            var asked = clean.substring(start, mark + 1)
            return jpWords(&asked, 30)
        }
        var none = jpNoFact()
        if(previous.size() > 0 && !previous.equals(&none)) {
            var q = string("You saw: ")
            q.append_view(previous.to_view())
            if(previous.size() > 0 && previous.at(previous.size() - 1) == '.') {
                q.append_view(string_view(" In your own words, what did it mean?"))
            } else {
                q.append_view(string_view(". In your own words, what did it mean?"))
            }
            return q
        }
        var title = jpTitle(slice)
        var q2 = string("What is the one idea in ")
        if(title.size() > 0) { q2.append_view(title.to_view()) }
        else { q2.append_view(string_view("this step")) }
        q2.append_view(string_view("?"))
        return q2
    }

    // The corpus marks the right option either with data-correct="true" or
    // with `, true)` in its click handler. Its own data-explain is the best
    // existing answer text; never take a wrong option's explanation instead.
    private func jpCorrectExplain(slice : &string) : string {
        var cursor : size_t = 0
        while(true) {
            var open = jpFindFrom(slice, string_view("<button"), cursor)
            if(open == std::NPOS) { break }
            var gt = jpFindFrom(slice, string_view(">"), open)
            if(gt == std::NPOS) { break }
            var tag = slice.substring(open, gt + 1)
            var marked = tag.find_or_npos(string_view(", true)")) != std::NPOS
            if(!marked) { marked = tag.find_or_npos(string_view("data-correct=\"true\"")) != std::NPOS }
            if(marked) {
                var explain = jpAttr(&tag, string_view("data-explain=\""))
                if(explain.size() > 0) { return explain }
            }
            cursor = gt + 1
        }
        return string()
    }

    private func jpAnswer(slice : &string, fallback : &string) : string {
        var best = jpDecode(jpCorrectExplain(slice))
        if(best.size() > 0) { return jpWords(&best, 25) }
        var at = jpFindFrom(slice, string_view("data-correct=\"true\""), 0)
        if(at != std::NPOS) {
            var gt = jpFindFrom(slice, string_view(">"), at)
            var lt = jpFindFrom(slice, string_view("<"), gt + 1)
            if(gt != std::NPOS && lt != std::NPOS) {
                var text_raw = slice.substring(gt + 1, lt)
                var text = jpClean(&text_raw)
                if(text.size() > 0) { return jpWords(&text, 12) }
            }
        }
        var answer_raw = jpAttr(slice, string_view("data-answer=\""))
        var answer = jpDecode(&answer_raw)
        if(answer.size() > 0) { return jpWords(&answer, 12) }
        var explain_raw = jpAttr(slice, string_view("data-explain=\""))
        var explain = jpDecode(&explain_raw)
        if(explain.size() > 0) { return jpWords(&explain, 25) }
        return fallback.copy()
    }

    // ONE source sentence, whole. The old arrival line stitched three strings
    // together ("In this step ... explore X - fragment. Starting here: ...")
    // and then ran jpWords(..., 30) over the result, which cut it off at an
    // arbitrary word mid-sentence. A reader cannot act on half a sentence.
    // Prefer the course's own description sentence; fall back to the unit's own
    // first sentence; if neither is a short, complete sentence, use one short
    // plain sentence rather than inventing a fact or truncating either source.
    private func jpAim(title : &string, description : &string, slice : &string, first : bool) : string {
        var desc_raw = jpDecode(description)
        var desc = jpFirstSentence(&desc_raw)
        if(desc.size() > 0 && desc.size() <= 400) { return desc.copy() }
        var purpose_raw = jpInner(slice, string_view("<p"), string_view("</p>"))
        var purpose_clean = jpClean(&purpose_raw)
        var purpose = jpFirstSentence(&purpose_clean)
        if(purpose.size() > 0 && purpose.size() <= 400) { return purpose.copy() }
        return string("In this step you will work through one idea at a time.")
    }

    private func jpCanDo(slice : &string) : string {
        var para_raw = jpInner(slice, string_view("<p"), string_view("</p>"))
        var para_filled = jpFillAnswers(&para_raw)
        var para_clean = jpClean(&para_filled)
        var line = jpFirstSentence(&para_clean)
        if(line.size() == 0) { line = jpTitle(slice) }
        if(line.size() == 0) { return jpNoFact() }
        return jpWords(&line, 25)
    }

    private func jpAttrTag(name : &string, value : &string) : string {
        var escaped = underlayer_core::html_escape(value)
        var tag = string(" ")
        tag.append_string(name)
        tag.append_view(string_view("=\""))
        tag.append_view(escaped.to_view())
        tag.append_view(string_view("\""))
        return tag
    }

    // Insert derived attributes into every existing unit tag.  Idempotent: a
    // page that already carries data-remember is left byte-identical.
    public func journey_inject_pedagogy(src : &string, title : &string, description : &string) : string {
        if(src.find_or_npos(string_view("data-remember=")) != std::NPOS) { return src.copy() }
        var out = string()
        var cursor : size_t = 0
        var previous = string()
        var index : size_t = 0
        var needle = string_view("<div class=\"unit")
        while(true) {
            var start = jpFindFrom(src, &needle, cursor)
            if(start == std::NPOS) { break }
            var gt = jpFindFrom(src, string_view(">"), start)
            if(gt == std::NPOS) { break }
            var next = jpFindFrom(src, &needle, gt + 1)
            var body_end = src.size()
            var last = false
            if(next != std::NPOS) { body_end = next }
            else {
                last = true
                var main_end = jpFindFrom(src, string_view("</main>"), gt + 1)
                if(main_end != std::NPOS) { body_end = main_end }
            }
            var body = src.substring(gt + 1, body_end)
            var remember = jpRemember(&body)
            var aim = jpAim(title, description, &body, index == 0)
            var question = jpQuestion(&body, &previous)
            var answer = jpAnswer(&body, &remember)
            var can = jpCanDo(&body)
            var attr = string()
            var n1 = string("data-aim")
            var n2 = string("data-remember")
            var n3 = string("data-recall-q")
            var n4 = string("data-recall-a")
            var n5 = string("data-can-do")
            var t1 = jpAttrTag(&n1, &aim)
            var t2 = jpAttrTag(&n2, &remember)
            var t3 = jpAttrTag(&n3, &question)
            var t4 = jpAttrTag(&n4, &answer)
            var t5 = jpAttrTag(&n5, &can)
            attr.append_view(t1.to_view())
            attr.append_view(t2.to_view())
            attr.append_view(t3.to_view())
            attr.append_view(t4.to_view())
            attr.append_view(t5.to_view())
            out.append_view(src.to_view().subview(cursor, gt))
            out.append_view(attr.to_view())
            previous = remember
            cursor = gt
            index = index + 1
            if(last) { break }
        }
        out.append_view(src.to_view().subview(cursor, src.size()))
        return out
    }

    // Fill the shell's five empty manifest attributes, then derive the unit
    // attributes.  One entry point for the backend and the static injector.
    public func journey_apply_metadata(src : &string, facts : &JourneyFacts, course_id : &string, concept_id : &string) : string {
        if(src.find_or_npos(string_view("journey-shell")) == std::NPOS) { return src.copy() }
        var out = src.copy()
        var name = string("course")
        var a = patch_journey_attr(&out, &name, course_id)
        name = string("concept")
        var b = patch_journey_attr(&a, &name, concept_id)
        name = string("minutes")
        var c = patch_journey_attr(&b, &name, &facts.minutes)
        name = string("difficulty")
        var d = patch_journey_attr(&c, &name, &facts.difficulty)
        name = string("prereq")
        var e = patch_journey_attr(&d, &name, &facts.prereq)
        return journey_inject_pedagogy(&e, &facts.title, &facts.description)
    }

    // The #html macro emits these tags self-closed (`/>`), so both spellings
    // are handled. Only the href value is replaced; the tag's own closing form
    // is left exactly as the macro wrote it.
    private func jpPatchRel(src : &string, rel : &string, target_id : &string) : string {
        var open = string("<link rel=\"")
        open.append_string(rel)
        open.append_view(string_view("\" href=\"\""))
        var out = src.copy()
        if(target_id.size() > 0) {
            var replacement = string("<link rel=\"")
            replacement.append_string(rel)
            replacement.append_view(string_view("\" href=\""))
            var escaped = underlayer_core::html_escape(target_id)
            replacement.append_view(escaped.to_view())
            replacement.append_view(string_view(".html\""))
            return jpReplace(&out, open.to_view(), replacement.to_view())
        }
        var self_closed = string("<link rel=\"")
        self_closed.append_string(rel)
        self_closed.append_view(string_view("\" href=\"\"/>"))
        var removed = jpReplace(&out, self_closed.to_view(), string_view(""))
        var paired = string("<link rel=\"")
        paired.append_string(rel)
        paired.append_view(string_view("\" href=\"\">"))
        return jpReplace(&removed, paired.to_view(), string_view(""))
    }

    // Static pages have no server to resolve /api/navigation.  Use relative
    // file names so the rel links also work from file://.
    public func journey_apply_static_pager(src : &string, prev_id : &string, next_id : &string) : string {
        var first = jpPatchRel(src, string("prev"), prev_id)
        return jpPatchRel(&first, string("next"), next_id)
    }
}
