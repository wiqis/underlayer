// underlayer_web — Exercise answer grading for all 8 lesson UI types (4.1.29).
// Shared by handle_exercise_submit. Kept separate so handlers_exercises.ch
// stays focused on HTTP concerns.
using std::string
using std::vector
using underlayer_models::Exercise

public namespace underlayer_web {

    private func trim_lower(s : &string) : string {
        var start : size_t = 0
        var end : size_t = s.size()
        while(start < end && (s.get(start) == ' ' || s.get(start) == '\t')) { start = start + 1 }
        while(end > start && (s.get(end - 1) == ' ' || s.get(end - 1) == '\t')) { end = end - 1 }
        var out = string()
        var i : size_t = start
        while(i < end) {
            var c = s.get(i)
            if(c >= 'A' && c <= 'Z') { c = c + 32 }
            out.append(c)
            i = i + 1
        }
        return out
    }

    // Hex answers: accept "40", "0x40", "0X40" as the same value.
    private func normalize_hex(s : &string) : string {
        var t = trim_lower(s)
        if(t.size() > 2 && t.get(0) == '0' && t.get(1) == 'x') {
            var out = string()
            var i : size_t = 2
            while(i < t.size()) { out.append(t.get(i)); i = i + 1 }
            return out
        }
        return t
    }

    private func split_pipe(s : &string) : vector<string> {
        var parts = vector<string>()
        var cur = string()
        var i : size_t = 0
        while(i < s.size()) {
            if(s.get(i) == '|') { parts.push(cur); cur = string() }
            else { cur.append(s.get(i)) }
            i = i + 1
        }
        parts.push(cur)
        return parts
    }

    private func vectors_equal(a : &vector<string>, b : &vector<string>) : bool {
        if(a.size() != b.size()) { return false }
        var i : size_t = 0
        while(i < a.size()) {
            var ap = a.get_ptr(i)
            var bp = b.get_ptr(i)
            var as = ap.copy()
            var bs = bp.copy()
            var la = trim_lower(&as)
            var lb = trim_lower(&bs)
            if(!la.equals(&lb)) { return false }
            i = i + 1
        }
        return true
    }

    private func grade_multi(ex : &Exercise, user_answer : &string) : bool {
        var user_indices = vector<int>()
        var ui_start : size_t = 0
        var ui : size_t = 0
        while(ui <= user_answer.size()) {
            if(ui == user_answer.size() || user_answer.get(ui) == ',') {
                var num_str = string()
                var uj : size_t = ui_start
                while(uj < ui) { num_str.append(user_answer.get(uj)); uj = uj + 1 }
                if(num_str.size() > 0) {
                    user_indices.push(underlayer_repository::parse_i64(num_str.to_view()) as int)
                }
                ui_start = ui + 1
            }
            ui = ui + 1
        }
        if(user_indices.size() != ex.correct_indices.size()) { return false }
        var uii : size_t = 0
        while(uii < user_indices.size()) {
            var user_idx = user_indices.get(uii)
            var found = false
            var cii : size_t = 0
            while(cii < ex.correct_indices.size()) {
                if(ex.correct_indices.get(cii) == user_idx) { found = true }
                cii = cii + 1
            }
            if(!found) { return false }
            uii = uii + 1
        }
        return true
    }

    private func grade_mc(ex : &Exercise, user_answer : &string) : bool {
        var ans_idx = -1
        var ai : size_t = 0
        while(ai < ex.options.size()) {
            var opt_ptr = ex.options.get_ptr(ai)
            if(opt_ptr.to_view().equals(&user_answer.to_view())) { ans_idx = ai as int }
            ai = ai + 1
        }
        if(ans_idx == ex.correct_index) { return true }
        return user_answer.to_view().equals(&ex.answer.to_view())
    }

    // Grade a submitted answer for any supported exercise type.
    public func grade_exercise(ex : &Exercise, user_answer : &string) : bool {
        if(ex.exercise_type.id.equals(string("multi_recognize"))) { return grade_multi(ex, user_answer) }

        // Ordering / matching / labeling: pipe-separated parts, exact after trim+lower.
        if(ex.exercise_type.id.equals(string("ordering")) ||
           ex.exercise_type.id.equals(string("matching")) ||
           ex.exercise_type.id.equals(string("labeling"))) {
            var want = split_pipe(&ex.answer)
            var got = split_pipe(user_answer)
            return vectors_equal(&want, &got)
        }

        // Hex inspect: normalize 0x prefix and case.
        if(ex.exercise_type.id.equals(string("hex_inspect"))) {
            var got_hex = normalize_hex(user_answer)
            var want_hex = normalize_hex(&ex.answer)
            return got_hex.equals(&want_hex)
        }

        // Free-text answers: fill_blank, recall/apply, explain, and anything
        // with no options (including predict without options).
        if(ex.exercise_type.id.equals(string("fill_blank")) ||
           ex.exercise_type.id.equals(string("recall")) ||
           ex.exercise_type.id.equals(string("apply")) ||
           ex.exercise_type.id.equals(string("explain")) ||
           ex.options.size() == 0) {
            var got_t = trim_lower(user_answer)
            var want_t = trim_lower(&ex.answer)
            return got_t.equals(&want_t)
        }

        // multiple_choice / recognize / true_false / predict-with-options
        return grade_mc(ex, user_answer)
    }

}
