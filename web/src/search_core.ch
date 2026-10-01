// underlayer_web — Search matching, scoring and snippets over the manifests.
//
// WHY CONCEPTS AND NOT COURSES.  `/api/search` (handlers_search.ch) matches
// course TITLES only, which finds `elf` and finds nothing else: 398 concepts
// live under 34 course titles, and most of them are named after a register, a
// flag or a struct.  A search over titles cannot find "relro", "cmpxchg",
// "satp" or "LC_DYLD_CHAINED_FIXUPS", which are four of the things a learner
// arrives with a word for.  So this searches concept titles AND descriptions,
// and reports which field matched.
//
// SCORING IS NOT A FUZZY MATCH.  It is four ordered cases -- title starts
// with the query, title contains it, description starts with it, description
// contains it -- because a case a reader cannot distinguish is a case that
// cannot be tested, and this file is the thing that gets tested.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public struct SearchHit {
        var course_id : string
        var course_title : string
        var concept_id : string
        var concept_title : string
        var concept_description : string
        var module_title : string
        var href : string
        var matched_field : string
        var score : int

        @make
        func make() : SearchHit {
            return SearchHit {
                course_id = string(),
                course_title = string(),
                concept_id = string(),
                concept_title = string(),
                concept_description = string(),
                module_title = string(),
                href = string(),
                matched_field = string(),
                score = 0
            }
        }
    }

    // Byte-wise case-insensitive index of `needle` in `hay`.  -1 when absent.
    // Both sides are lowercased by the caller, because ASCII-lowering 398
    // descriptions once per keystroke would be wasted work.
    public func find_bytes(hay : &string, needle : &string) : int {
        if(needle.size() == 0) { return -1 }
        if(hay.size() < needle.size()) { return -1 }
        var last = hay.size() - needle.size()
        var i : size_t = 0
        while(i <= last) {
            var j : size_t = 0
            var ok = true
            while(j < needle.size()) {
                if(hay.get(i + j) != needle.get(j)) { ok = false; break }
                j = j + 1
            }
            if(ok) { return i as int }
            i = i + 1
        }
        return -1
    }

    // Score a (query, title, description) triple.  Higher is better; 0 means
    // no match at all.
    public func hit_score(query : &string, title : &string, description : &string) : int {
        var at = find_bytes(title, query)
        if(at == 0) { return 100 }
        if(at > 0) { return 80 }
        at = find_bytes(description, query)
        if(at == 0) { return 60 }
        if(at > 0) { return 40 }
        return 0
    }

    // Roll a UTF-8 cut point back to a character boundary.  Descriptions in
    // this collection contain em-dashes and curly quotes, so cutting at an
    // arbitrary byte produces a replacement character in the middle of a
    // snippet -- which reads as a mojibake bug on a page whose whole job is
    // to be trusted about bytes.
    func snap_to_char_start(s : &string, at : size_t) : size_t {
        var i = at
        while(i > 0) {
            var b = s.get(i) as u8
            if((b & 0xC0) != 0x80) { break }
            i = i - 1
        }
        return i
    }

    func is_space_byte(c : char) : bool {
        return c == ' ' || c == '\n' || c == '\t' || c == '\r'
    }

    public func trim_start(s : &string) : string {
        var i : size_t = 0
        while(i < s.size() && is_space_byte(s.get(i))) { i = i + 1 }
        var out = string()
        var j = i
        while(j < s.size()) { out.append(s.get(j)); j = j + 1 }
        return out
    }

    public func trim_end(s : &string) : string {
        var end = s.size()
        while(end > 0 && is_space_byte(s.get(end - 1))) { end = end - 1 }
        var out = string()
        var i : size_t = 0
        while(i < end) { out.append(s.get(i)); i = i + 1 }
        return out
    }

}