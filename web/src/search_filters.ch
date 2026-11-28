// underlayer_web — Facets, pagination and stable URLs for GET /search.
//
// WHY SERVER-SIDE.  A search result you can link to is the whole point of a
// GET page: a learner pastes the URL into a note, comes back a week later and
// sees the same slice of the collection.  A client-side filter that lives only
// in JS cannot do that, and it cannot work with JS off either.  Every facet
// below is therefore parsed from the query string and applied BEFORE the page
// slice is chosen, and every paginator href rebuilds the complete query.
//
// /api/search is not touched by any of this.  That endpoint's payload is
// frozen; this file serves only the page.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course
using underlayer_models::ConceptRef

public namespace underlayer_web {

    public const SEARCH_PAGE_SIZE : int = 25

    public struct SearchFilters {
        var q : string
        var course : string
        var module : string
        var difficulty : string
        var minutes : string
        var status : string
        var page : int

        @make
        func make() : SearchFilters {
            return SearchFilters {
                q = string(),
                course = string(),
                module = string(),
                difficulty = string(),
                minutes = string(),
                status = string(),
                page = 1
            }
        }
    }

    // Percent-encode a query value with uppercase hex. std::string has no
    // built-in URL encoder in this compiler; a hand-rolled one is fine because
    // it is a total byte function and never interprets its input.
    func hex_digit(n : u8) : char {
        if(n < 10u8) { return ('0' as char) + (n as char) }
        return ('A' as char) + ((n - 10u8) as char)
    }

    public func url_encode(s : &string) : string {
        var out = string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            var safe = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                       (c >= '0' && c <= '9') || c == '-' || c == '_' ||
                       c == '.' || c == '~'
            if(safe) {
                out.append(c)
            } else {
                var b = c as u8
                out.append('%')
                out.append(hex_digit(b >> 4u8))
                out.append(hex_digit(b & 15u8))
            }
            i = i + 1
        }
        return out
    }

    // Rebuild a complete, shareable URL for one page of the SAME query. The
    // empty facets are omitted, so two URLs that mean the same thing are byte-
    // identical and a paginator link can be used as a cache key.
    public func search_url(f : &SearchFilters, page : int) : string {
        var out = string("/search?q=")
        var q = url_encode(&f.q)
        out.append_view(q.to_view())
        if(f.course.size() > 0) {
            out.append_view("&course=")
            var v = url_encode(&f.course)
            out.append_view(v.to_view())
        }
        if(f.module.size() > 0) {
            out.append_view("&module=")
            var v2 = url_encode(&f.module)
            out.append_view(v2.to_view())
        }
        if(f.difficulty.size() > 0) {
            out.append_view("&difficulty=")
            var v3 = url_encode(&f.difficulty)
            out.append_view(v3.to_view())
        }
        if(f.minutes.size() > 0) {
            out.append_view("&minutes=")
            var v4 = url_encode(&f.minutes)
            out.append_view(v4.to_view())
        }
        if(f.status.size() > 0) {
            out.append_view("&status=")
            var v5 = url_encode(&f.status)
            out.append_view(v5.to_view())
        }
        if(page > 1) {
            out.append_view("&page=")
            var p = underlayer_core::int_to_string(page as i64)
            out.append_view(p.to_view())
        }
        return out
    }

    public func read_query_param(req : &http::Request, name : &string) : string {
        var key = std::str.make_view(name.to_view())
        var v = sv_or_empty(req.query.get(key))
        return sv_to_string(&v)
    }

    public func parse_search_filters(req : &http::Request) : SearchFilters {
        var f = SearchFilters::make()
        f.q = read_query_param(req, string("q"))
        f.course = read_query_param(req, string("course"))
        f.module = read_query_param(req, string("module"))
        f.difficulty = read_query_param(req, string("difficulty"))
        f.minutes = read_query_param(req, string("minutes"))
        f.status = read_query_param(req, string("status"))
        var raw_page = read_query_param(req, string("page"))
        var n : int = 0
        var i : size_t = 0
        while(i < raw_page.size()) {
            var c = raw_page.at(i)
            if(c < '0' || c > '9') { n = 0; i = raw_page.size() }
            else { n = n * 10 + (c - '0') as int; i = i + 1 }
        }
        if(n < 1) { n = 1 }
        f.page = n
        return f
    }

    func lower_of(s : &string) : string {
        var qsv = s.to_view()
        return ascii_lower(&qsv)
    }

    func matches_facet(want : &string, actual : &string) : bool {
        if(want.size() == 0) { return true }
        var a = lower_of(actual)
        var b = lower_of(want)
        return find_bytes(&a, &b) >= 0
    }

    // Owned projection: returning a borrow out of a vector of borrowed courses
    // has no inferable lifetime in this compiler, and a dangling reference on
    // a search page would be worse than an extra copy of two scalars.
    struct ConceptMeta {
        var difficulty : string
        var minutes : int
        var found : bool

        @make
        func make() : ConceptMeta {
            return ConceptMeta { difficulty = string(), minutes = 0, found = false }
        }
    }

    func concept_meta(courses : &vector<Course>, hit : &SearchHit) : ConceptMeta {
        var out = ConceptMeta::make()
        var ci : size_t = 0
        while(ci < courses.size()) {
            var course = courses.at_ref(ci)
            var cid = course.id.copy()
            var hid = hit.course_id.copy()
            if(cid.equals(&hid)) {
                var k : size_t = 0
                while(k < course.concepts.size()) {
                    var cref = course.concepts.at_ref(k)
                    var ccid = cref.id.copy()
                    var hcid = hit.concept_id.copy()
                    if(ccid.equals(&hcid)) {
                        out.difficulty = cref.difficulty.copy()
                        out.minutes = cref.estimated_minutes
                        out.found = true
                        return out
                    }
                    k = k + 1
                }
            }
            ci = ci + 1
        }
        return out
    }

    public func id_in(ids : &vector<string>, id : &string) : bool {
        var i : size_t = 0
        while(i < ids.size()) {
            var v = ids.at_ref(i)
            var a = v.copy()
            var b = id.copy()
            if(a.equals(&b)) { return true }
            i = i + 1
        }
        return false
    }

    // `completed` and `due` are empty when no session resolves. An empty
    // status filter is then refused by the renderer with a sign-in note, not
    // silently answered with somebody else's data or a demo zero.
    public func apply_search_filters(hits : &vector<SearchHit>, courses : &vector<Course>,
                                     f : &SearchFilters, completed : &vector<string>,
                                     due : &vector<string>, signed_in : bool) : vector<SearchHit> {
        var out = vector<SearchHit>()
        var max_minutes : int = 0
        if(f.minutes.size() > 0) {
            var i : size_t = 0
            while(i < f.minutes.size()) {
                var c = f.minutes.at(i)
                if(c >= '0' && c <= '9') { max_minutes = max_minutes * 10 + (c - '0') as int }
                else { max_minutes = 0; i = f.minutes.size() }
                i = i + 1
            }
        }
        var i : size_t = 0
        while(i < hits.size()) {
            var hit = hits.at_ref(i)
            var keep = true
            if(f.course.size() > 0 && !matches_facet(&f.course, &hit.course_id)) { keep = false }
            if(keep && f.module.size() > 0 && !matches_facet(&f.module, &hit.module_title)) { keep = false }
            if(keep && f.difficulty.size() > 0) {
                var meta = concept_meta(courses, hit)
                if(!meta.found) { keep = false }
                else if(!matches_facet(&f.difficulty, &meta.difficulty)) { keep = false }
            }
            if(keep && max_minutes > 0) {
                var meta2 = concept_meta(courses, hit)
                if(!meta2.found || meta2.minutes > max_minutes) { keep = false }
            }
            if(keep && f.status.size() > 0) {
                if(!signed_in) { keep = false }
                else {
                    var want_done = string("completed")
                    var want_due = string("review-due")
                    if(f.status.equals(&want_done)) {
                        keep = id_in(completed, &hit.concept_id)
                    } else if(f.status.equals(&want_due)) {
                        keep = id_in(due, &hit.concept_id)
                    }
                }
            }
            if(keep) { out.push(copy_hit(hit)) }
            i = i + 1
        }
        return out
    }

    // A course's reading minutes decide which of the three time budgets it
    // belongs to. The thresholds are written here, not on three cards, so the
    // /courses control and its checker cannot disagree.
    public func budget_bucket(total_minutes : int) : string {
        if(total_minutes <= 130) { return string("10") }
        if(total_minutes <= 250) { return string("week") }
        return string("deep")
    }

}
