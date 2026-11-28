// underlayer_web — Settings/FSRS settings handlers and the shared specimen route.
//
// G3: the four FSRS endpoints used to compute defaults and return them. The
// weights, desired retention and daily cap now live in repository/fsrs_params,
// keyed by learner id, so a change survives re-login and reaches every
// scheduling consumer. See load_effective_fsrs() below — it is the ONE read
// path (handlers_review.ch uses it too).
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_repository::parse_f64

public namespace underlayer_web {

    // GET /settings — render settings page
    public func handle_settings_page(req : &http::Request) : http::Response {
        var html_out = render_settings_page()
        var bv = html_out.to_view()
        return underlayer_web::send_html(&html_out)
    }

    // GET /support — public support and contact channel (I11)
    public func handle_support_page(req : &http::Request) : http::Response {
        var html_out = render_support_page()
        return underlayer_web::send_html(&html_out)
    }

    // GET /u/:username — render public profile page
    public func handle_profile_page(req : &http::Request) : http::Response {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 2) {
            var body = std::string("Not found")
            return underlayer_web::send_status_text(404u, &body)
        }
        var username_sv = segments.at_ref(1)
        var username = username_sv.to_string()
        var html_out = render_profile_page(&username)
        var bv = html_out.to_view()
        return underlayer_web::send_html(&html_out)
    }

    // ---- FSRS settings: the shared read/write path ------------------------

    // The additive settings document. `ok` distinguishes a parsed document
    // from a malformed one; `stored` says whether the learner has a row yet.
    public struct FsrsSettings {
        var params : underlayer_learning::FSRSParams
        var daily_review_cap : int
        var ok : bool
        var stored : bool

        @make
        func make() : FsrsSettings {
            return FsrsSettings {
                params = underlayer_learning::FSRSParams::make(),
                daily_review_cap = 20,
                ok = true,
                stored = false
            }
        }
    }

    private func find_char(v : &std::string_view, needle : char, from : size_t) : size_t {
        var i = from
        while(i < v.size()) {
            if(v.at(i) == needle) { return i }
            i = i + 1
        }
        return v.size()
    }

    private func find_literal(v : &std::string_view, needle : &std::string_view, from : size_t) : size_t {
        var i = from
        while(i + needle.size() <= v.size()) {
            var j : size_t = 0
            var matched = true
            while(j < needle.size()) {
                if(v.at(i + j) != needle.at(j)) { matched = false; j = needle.size() }
                else { j = j + 1 }
            }
            if(matched) { return i }
            i = i + 1
        }
        return v.size()
    }

    // parse_f64 consumes every later digit in a view, so a view that starts at
    // a value and runs to end-of-document would absorb the next field. This
    // stops at the first non-numeric byte and returns only that token.
    private func number_token(v : &std::string_view, from : size_t) : string {
        var buf = string()
        var i = from
        while(i < v.size()) {
            var c = v.at(i)
            if((c >= '0' && c <= '9') || c == '.' || c == '-' || c == '+') { buf.append(c) }
            else { i = v.size() }
            i = i + 1
        }
        return buf
    }

    private func f64_literal(v : f64) : string {
        var out = string()
        var x = v
        if(x < 0.0) { out.append('-'); x = -x }
        var ip = x as i64
        // Round, do not truncate: 0.2603 * 10000 is 2602.9999... in binary,
        // and truncating would silently rewrite a weight on every save.
        var frac = (((x - (ip as f64)) * 10000.0) + 0.5) as i64
        if(frac < 0) { frac = 0 }
        var ip_s = underlayer_core::int_to_string(ip)
        var fr_s = underlayer_core::int_to_string(frac)
        out.append_view(ip_s.to_view())
        out.append('.')
        if(frac < 1000) { out.append('0') }
        if(frac < 100) { out.append('0') }
        if(frac < 10) { out.append('0') }
        out.append_view(fr_s.to_view())
        return out
    }

    // Accepts the additive export shape {"w":[...],"target_retention":x,
    // "daily_review_cap":n} AND a bare Anki weights array [...]. Nothing here
    // evaluates attacker-controlled text: only digits, '.', '-' and '+' are
    // copied into the number buffer, and parse_f64 ignores the rest.
    public func parse_fsrs_settings_json(json_str : &string) : FsrsSettings {
        var out = FsrsSettings::make()
        var weights = underlayer_learning::FSRSParams::make()
        var view = std::string_view.make_view(json_str)
        var lb = find_char(&view, '[', 0)
        var rb = find_char(&view, ']', lb)
        if(lb >= view.size() || rb >= view.size() || rb <= lb) {
            out.ok = false
            return out
        }
        var seg_start = lb + 1
        var k = seg_start
        while(k <= rb) {
            var delim = false
            if(k == rb) { delim = true }
            else { if(view.at(k) == ',') { delim = true } }
            if(delim) {
                var buf = string()
                var m = seg_start
                while(m < k) {
                    var c = view.at(m)
                    if(c != ' ' && c != '\n' && c != '\r' && c != '\t') { buf.append(c) }
                    m = m + 1
                }
                if(buf.size() > 0) { weights.w.push(parse_f64(buf.to_view())) }
                seg_start = k + 1
            }
            k = k + 1
        }
        if(weights.w.size() < 3) {
            out.ok = false
            return out
        }
        out.params = weights
        var ret_key = std::string_view("target_retention")
        var cap_key = std::string_view("daily_review_cap")
        var rp = find_literal(&view, &ret_key, 0)
        if(rp < view.size()) {
            var colon = find_char(&view, ':', rp + ret_key.size())
            if(colon < view.size()) {
                var token = number_token(&view, colon + 1)
                out.params.target_retention = parse_f64(token.to_view())
            }
        }
        var cp = find_literal(&view, &cap_key, 0)
        if(cp < view.size()) {
            var colon = find_char(&view, ':', cp + cap_key.size())
            if(colon < view.size()) {
                var token = number_token(&view, colon + 1)
                out.daily_review_cap = underlayer_repository::parse_int(token.to_view())
            }
        }
        if(out.params.target_retention < 0.5 || out.params.target_retention > 1.0) {
            out.ok = false
            return out
        }
        if(out.daily_review_cap < 1 || out.daily_review_cap > 500) { out.daily_review_cap = 20 }
        return out
    }

    // The only way the scheduler reads settings. No row -> defaults, unchanged.
    public func load_effective_fsrs(db : *DbClient, learner_id : &string) : FsrsSettings {
        var out = FsrsSettings::make()
        var rec = underlayer_repository::load_fsrs_params(db, learner_id)
        if(!rec.found) {
            out.params = underlayer_learning::init_fsrs_params()
            return out
        }
        out.stored = true
        var parsed = parse_fsrs_settings_json(&rec.params_json)
        if(parsed.ok) {
            // Copy the scalar BEFORE the vector-bearing field is moved out.
            var parsed_cap = parsed.daily_review_cap
            out.params = parsed.params
            out.daily_review_cap = parsed_cap
        } else {
            out.params = underlayer_learning::init_fsrs_params()
        }
        // The columns are authoritative: they are what was saved last, even if
        // an older params_json document did not carry the additive cap field.
        out.params.target_retention = rec.target_retention
        out.daily_review_cap = rec.daily_review_cap
        if(out.daily_review_cap < 1 || out.daily_review_cap > 500) { out.daily_review_cap = 20 }
        if(out.params.w.size() < 3) { out.params = underlayer_learning::init_fsrs_params() }
        return out
    }

    public func fsrs_settings_to_json(settings : &FsrsSettings) : string {
        var json = string("{\"w\":[")
        var i : size_t = 0
        while(i < settings.params.w.size()) {
            if(i > 0) { json.append(',') }
            var val = f64_literal(settings.params.w.at(i))
            json.append_view(val.to_view())
            i = i + 1
        }
        json.append_view("],\"target_retention\":")
        var tr = f64_literal(settings.params.target_retention)
        json.append_view(tr.to_view())
        json.append_view(",\"daily_review_cap\":")
        var cap = underlayer_core::int_to_string(settings.daily_review_cap as i64)
        json.append_view(cap.to_view())
        json.append_view("}")
        return json
    }

    public func save_effective_fsrs(db : *DbClient, learner_id : &string, settings : &FsrsSettings) {
        var doc = fsrs_settings_to_json(settings)
        underlayer_repository::save_fsrs_params(db, learner_id, &doc, settings.params.target_retention, settings.daily_review_cap)
    }

    private func fsrs_learner_id(db : *DbClient, req : &http::Request) : string {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        return learner_id
    }

    // POST /api/fsrs/optimize — optimise from the learner's own history and WRITE it.
    public func handle_fsrs_optimize(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = fsrs_learner_id(db, req)
        var before = load_effective_fsrs(db, &learner_id)
        var history = underlayer_repository::get_all_review_history(db, &learner_id)
        if(history.size() < 10) {
            var err_msg = string("need at least 10 reviews for optimization")
            return send_error(400u, &err_msg)
        }
        var ratings = vector<int>()
        var intervals = vector<i64>()
        var hi : size_t = 0
        while(hi < history.size()) {
            var item = history.at_ref(hi)
            ratings.push(item.rating)
            var interval : i64 = 1
            if(hi > 0) {
                var prev = history.at_ref(hi - 1)
                interval = item.reviewed_at - prev.reviewed_at
                if(interval < 1) { interval = 1 }
            }
            intervals.push(interval)
            hi = hi + 1
        }
        var after = FsrsSettings::make()
        after.params = underlayer_learning::optimize_fsrs_params(&before.params, &ratings, &intervals)
        after.daily_review_cap = before.daily_review_cap
        save_effective_fsrs(db, &learner_id, &after)
        var optimize_reason = string("optimize_from_history")
        var log_entry = underlayer_learning::log_param_change(&before.params, &after.params, &optimize_reason)
        var before_json = fsrs_settings_to_json(&before)
        var after_json = fsrs_settings_to_json(&after)
        var body = std::string("{\"ok\":true,\"log\":")
        body.append_view(&log_entry.to_view())
        body.append_view(",\"before\":")
        body.append_view(&before_json.to_view())
        body.append_view(",\"after\":")
        body.append_view(&after_json.to_view())
        body.append_view("}")
        return send_json_str(&body)
    }

    // POST /api/fsrs/reset — restore defaults AND persist them.
    public func handle_fsrs_reset(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = fsrs_learner_id(db, req)
        var before = load_effective_fsrs(db, &learner_id)
        var after = FsrsSettings::make()
        after.params = underlayer_learning::reset_fsrs_params()
        after.stored = true
        save_effective_fsrs(db, &learner_id, &after)
        var before_json = fsrs_settings_to_json(&before)
        var after_json = fsrs_settings_to_json(&after)
        var body = std::string("{\"ok\":true,\"before\":")
        body.append_view(&before_json.to_view())
        body.append_view(",\"after\":")
        body.append_view(&after_json.to_view())
        body.append_view("}")
        return send_json_str(&body)
    }

    // GET /api/fsrs/export — export the learner's stored parameters, not defaults.
    public func handle_fsrs_export(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = fsrs_learner_id(db, req)
        var settings = load_effective_fsrs(db, &learner_id)
        var exported = fsrs_settings_to_json(&settings)
        return send_json_str(&exported)
    }

    // POST /api/fsrs/import — accept an additive document or a bare Anki array,
    // validate it, then WRITE it. A malformed import answers 400 with a short
    // visible message rather than silently pretending it worked.
    // POST /api/fsrs/params — set desired retention (0.80-0.95) and daily cap.
    public func handle_fsrs_params(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = fsrs_learner_id(db, req)
        var settings = load_effective_fsrs(db, &learner_id)
        var ret_key = std::string_view("target_retention")
        var cap_key = std::string_view("daily_review_cap")
        var rv = sv_or_empty(req.query.get(std::str.make_view(ret_key)))
        var cv = sv_or_empty(req.query.get(std::str.make_view(cap_key)))
        if(rv.size() > 0) {
            var retention = parse_f64(rv)
            if(retention < 0.80 || retention > 0.95) {
                var err_msg = string("target_retention must be between 0.80 and 0.95")
                return send_error(400u, &err_msg)
            }
            settings.params.target_retention = retention
        }
        if(cv.size() > 0) {
            var cap = underlayer_repository::parse_int(cv)
            if(cap < 1 || cap > 200) {
                var err_msg = string("daily_review_cap must be between 1 and 200")
                return send_error(400u, &err_msg)
            }
            settings.daily_review_cap = cap
        }
        settings.stored = true
        save_effective_fsrs(db, &learner_id, &settings)
        var body = fsrs_settings_to_json(&settings)
        return send_json_str(&body)
    }

    public func handle_fsrs_import(db : *DbClient, req : &mut http::Request) : http::Response {
        var q_weights = string("weights")
        var weights_v = sv_or_empty(req.query.get(std::str.make_view(q_weights.to_view())))
        if(weights_v.size() == 0) {
            var err_msg = string("missing query param: weights (JSON array of floats)")
            return send_error(400u, &err_msg)
        }
        var weights_str = sv_to_string(&weights_v)
        var parsed = parse_fsrs_settings_json(&weights_str)
        if(!parsed.ok) {
            var err_msg = string("invalid FSRS parameters: expected a JSON array of at least 3 numbers")
            return send_error(400u, &err_msg)
        }
        var learner_id = fsrs_learner_id(db, &*req)
        parsed.stored = true
        save_effective_fsrs(db, &learner_id, &parsed)
        var exported = fsrs_settings_to_json(&parsed)
        var body = std::string("{\"ok\":true,\"params\":")
        body.append_view(&exported.to_view())
        body.append_view("}")
        return send_json_str(&body)
    }

    // ---- I5: the two served specimen files per course ---------------------
    //
    // The /courses/* catch-all prepends the WHOLE request path to COURSES_DIR,
    // so a nested asset URL resolves to ./courses/courses/... and 404s. This
    // route is registered BEFORE that catch-all and serves exactly two fixed
    // filenames. The raw path segments are validated against [a-z0-9-]+ BEFORE
    // any filesystem call, and the filename is rebuilt from the validated id:
    // no caller-controlled text ever reaches path::Path.
    private func specimen_id_valid(id : &std::string_view) : bool {
        if(id.size() < 1 || id.size() > 64) { return false }
        var i : size_t = 0
        while(i < id.size()) {
            var c = id.at(i)
            if(!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')) { return false }
            i = i + 1
        }
        if(id.at(0) == '-') { return false }
        if(id.at(id.size() - 1) == '-') { return false }
        return true
    }

    private func specimen_not_found() : http::Response {
        var msg = string("not found")
        return send_error(404u, &msg)
    }

    public func handle_specimen_download(courses_dir : &string, req : &http::Request) : http::Response {
        var req_path = req.path.to_view()
        var segments = underlayer_core::path_segments(&req_path)
        // path_segments() omits the leading empty component: the five parts are
        // courses / <id> / assets / samples / <id>-specimen.<ext>.
        if(segments.size() != 5) { return specimen_not_found() }
        var course_sv = segments.at_ref(1)
        var file_sv = segments.at_ref(4)
        if(!specimen_id_valid(course_sv)) { return specimen_not_found() }
        var course = course_sv.to_string()
        var zip_name = course.copy()
        zip_name.append_view("-specimen.zip")
        var json_name = course.copy()
        json_name.append_view("-specimen.json")
        var zip_view = std::string_view.make_view(&zip_name)
        var json_view = std::string_view.make_view(&json_name)
        var is_zip = file_sv.equals(&zip_view)
        var is_json = file_sv.equals(&json_view)
        if(!is_zip && !is_json) { return specimen_not_found() }
        // Canonical path from the allow-listed id only. No '..', no separator,
        // no absolute path can survive specimen_id_valid/equals above.
        var name = zip_name
        if(is_json) { name = json_name }
        var fs_path = courses_dir.copy()
        fs_path.append_view("/")
        fs_path.append_string(&course)
        fs_path.append_view("/assets/samples/")
        fs_path.append_string(&name)
        // Belt and braces: refuse anything that could escape COURSES_DIR even
        // if the two validators are changed later.
        var root_view = std::string_view.make_view(courses_dir)
        if(!fs_path.starts_with(&root_view)) { return specimen_not_found() }
        var k : size_t = 0
        while(k + 1 < fs_path.size()) {
            if(fs_path.at(k) == '.' && fs_path.at(k + 1) == '.') { return specimen_not_found() }
            if(fs_path.at(k) == '\\') { return specimen_not_found() }
            k = k + 1
        }
        var path_view = std::str.make_view(fs_path.to_view())
        var file_path = path::Path.new(path_view)
        var content_res = fs::read(&file_path)
        if(content_res is std::Result.Err) { return specimen_not_found() }
        var Ok(bytes) = content_res else unsafe { unreachable }
        var res = http::Response()
        var ct = string("application/octet-stream")
        if(is_zip) { ct = string("application/zip") }
        else { ct = string("application/json") }
        var ct_view = ct.to_view()
        var cc = string_view("public, max-age=3600")
        res.set_header_view(std::string_view("Content-Type"), &ct_view)
        res.set_header_view(std::string_view("Cache-Control"), &cc)
        res.bytes(bytes.as_span())
        return res
    }

}
