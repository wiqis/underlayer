// underlayer_web — Search over concepts: snippets, collection walk, ordering.
//
// The snippet is a WINDOW ON THE DESCRIPTION, not the whole description.
// Several of these descriptions are 600 characters of measured findings, and a
// reader needs the sentence the match is in rather than all six.  The window
// opens at the match where there is one, snapped to a character boundary and
// then to a word boundary, and carries an ellipsis at whichever end was cut.
//
// The five score tiers are listed in search_core.ch's comment and each one is
// distinguishable in the rendered result, so a tier that stopped working would
// be visible rather than absorbed into a lower score.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    // At most this many hits are rendered.  Both the page and the API report
    // the true total beside the truncated list, because a result count that
    // silently disagrees with the number of results shown is a defect rather
    // than a performance measure.
    public const SEARCH_RESULT_LIMIT : int = 60

    // A window of this many characters, opening this many before the match.
    public const SNIPPET_WIDTH : int = 200
    public const SNIPPET_LEAD : int = 60

    public func snippet_of(desc : &string, query : &string, width : int, lead : int) : string {
        if(desc.size() == 0) { return string() }
        var at = find_bytes(desc, query)
        var start : size_t = 0
        if(at > lead) {
            start = snap_to_char_start(desc, at as size_t - lead as size_t)
            var j = start
            while(j < desc.size() && !is_space_byte(desc.at(j))) { j = j + 1 }
            while(j < desc.size() && is_space_byte(desc.at(j))) { j = j + 1 }
            start = j
        }
        var out = string()
        if(start > 0) { out.append_view(string_view("...")) }
        var end = start + width as size_t
        if(end >= desc.size()) {
            end = desc.size()
        } else {
            end = snap_to_char_start(desc, end)
            var k = end
            while(k > start && !is_space_byte(desc.at(k - 1))) { k = k - 1 }
            if(k > start) { end = k }
        }
        var i = start
        while(i < end) { out.append(desc.at(i)); i = i + 1 }
        if(end < desc.size()) { out.append_view(string_view("...")) }
        return out
    }

    // Byte-wise lexicographic compare, ASCII case-folded.  std::string has no
    // `<` in this build ("expected the value to have primitive type or have
    // operator overloaded"), and a hand-written compare that silently did
    // nothing would make the whole ordering fall back to input order -- which
    // is directory order, which is not an answer.
    func title_less(a : &string, b : &string) : bool {
        var i : size_t = 0
        var n = a.size()
        if(b.size() < n) { n = b.size() }
        while(i < n) {
            var ca = a.at(i)
            var cb = b.at(i)
            if(ca >= 'A' && ca <= 'Z') { ca = ca + 32 }
            if(cb >= 'A' && cb <= 'Z') { cb = cb + 32 }
            if(ca != cb) { return ca < cb }
            i = i + 1
        }
        return a.size() < b.size()
    }

    // Sort by score descending, then concept title ascending, then course id
    // ascending.  The last key makes the order TOTAL, which matters because
    // list_courses() reads a directory: without it two runs over the same
    // collection could order equal-scoring hits differently.
    public func sort_hits(hits : &mut vector<SearchHit>) {
        var n : size_t = hits.size()
        var i : size_t = 0
        while(i < n) {
            var best = i
            var j = i + 1
            while(j < n) {
                var a = hits.at_ref(j)
                var b = hits.at_ref(best)
                var take = false
                if(a.score > b.score) {
                    take = true
                } else if(a.score == b.score) {
                    var at = a.concept_title.copy()
                    var bt = b.concept_title.copy()
                    if(title_less(&at, &bt)) {
                        take = true
                    } else if(!title_less(&bt, &at)) {
                        var ac = a.course_id.copy()
                        var bc = b.course_id.copy()
                        if(title_less(&ac, &bc)) { take = true }
                    }
                }
                if(take) { best = j }
                j = j + 1
            }
            if(best != i) { swap_hits(hits, i, best) }
            i = i + 1
        }
    }

    // One hit, copied out.  `SearchHit` owns its strings, so a swap cannot move
    // through a borrow; it copies each side out and writes it back.
    public func copy_hit(src : &SearchHit) : SearchHit {
        var out = SearchHit::make()
        out.score = src.score
        out.concept_title = src.concept_title.copy()
        out.concept_id = src.concept_id.copy()
        out.course_id = src.course_id.copy()
        out.course_title = src.course_title.copy()
        out.concept_description = src.concept_description.copy()
        out.module_title = src.module_title.copy()
        out.href = src.href.copy()
        out.matched_field = src.matched_field.copy()
        return out
    }

    // Swap two hits.  Each side is copied out, then written back under its own
    // short mutable borrow, so the two borrows never overlap.
    func swap_hits(hits : &mut vector<SearchHit>, i : size_t, j : size_t) {
        var a_copy = copy_hit(hits.at_ref(i))
        var b_copy = copy_hit(hits.at_ref(j))
        {
            var a = hits.at_mut(i)
            a.score = b_copy.score
            a.concept_title = b_copy.concept_title.copy()
            a.concept_id = b_copy.concept_id.copy()
            a.course_id = b_copy.course_id.copy()
            a.course_title = b_copy.course_title.copy()
            a.concept_description = b_copy.concept_description.copy()
            a.module_title = b_copy.module_title.copy()
            a.href = b_copy.href.copy()
            a.matched_field = b_copy.matched_field.copy()
        }
        {
            var b = hits.at_mut(j)
            b.score = a_copy.score
            b.concept_title = a_copy.concept_title.copy()
            b.concept_id = a_copy.concept_id.copy()
            b.course_id = a_copy.course_id.copy()
            b.course_title = a_copy.course_title.copy()
            b.concept_description = a_copy.concept_description.copy()
            b.module_title = a_copy.module_title.copy()
            b.href = a_copy.href.copy()
            b.matched_field = a_copy.matched_field.copy()
        }
    }

}