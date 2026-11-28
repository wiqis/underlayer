// underlayer_web â€” F3/F4 course gating and the entitlement read contract.
//
// There is NO local boolean here. The account service owns entitlements (F1);
// this file asks it on every gated request, using the learner's stable account
// id from the local shadow learner. An unconfigured token, a missing learner,
// a network error or an unparseable answer all FAIL CLOSED.
//
// Progress is never touched by a gate: a 402 is a refusal to render, not a
// mutation. Refunds and expiry therefore leave every progress row intact.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    private func env_or(name : string_view, fallback : string_view) : string {
        var name_view = name
        var opt = std::get_env(&name_view)
        if(var Some(v) = opt) { if(v.size() > 0u) { return v.copy() } }
        return string(fallback)
    }

    private func err_resp(code : u32, msg : string_view) : http::Response {
        var m = string()
        m.append_view(&msg)
        return send_error(code, &m)
    }

    private func manifest_field(courses_dir : &string, course_id : &string, field : *char) : string {
        var manifest_path_s = courses_dir.copy()
        manifest_path_s.append_view(string_view("/"))
        manifest_path_s.append_string(course_id)
        manifest_path_s.append_view(string_view("/manifest.json"))
        var pv = std::str.make_view(manifest_path_s.to_view())
        var fp = path::Path.new(pv)
        var read = fs::read_to_string(&fp)
        if(read is std::Result.Err) { return string() }
        var Ok(text) = read else return string()
        var parsed = json::parse(text.to_view())
        if(parsed is std::Result.Err) { return string() }
        var Ok(root) = parsed else return string()
        return json_get_str(&root, field)
    }

    private func manifest_bool(courses_dir : &string, course_id : &string, field : *char) : bool {
        var manifest_path_s = courses_dir.copy()
        manifest_path_s.append_view(string_view("/"))
        manifest_path_s.append_string(course_id)
        manifest_path_s.append_view(string_view("/manifest.json"))
        var pv = std::str.make_view(manifest_path_s.to_view())
        var fp = path::Path.new(pv)
        var read = fs::read_to_string(&fp)
        if(read is std::Result.Err) { return false }
        var Ok(text) = read else return false
        var parsed = json::parse(text.to_view())
        if(parsed is std::Result.Err) { return false }
        var Ok(root) = parsed else return false
        return json_get_bool(&root, field)
    }

    public func is_paid_course(courses_dir : &string, course_id : &string) : bool {
        return manifest_bool(courses_dir, course_id, "paid")
    }

    public func course_product(courses_dir : &string, course_id : &string) : string {
        return manifest_field(courses_dir, course_id, "product")
    }

    // The stable id from the shared account, read from the local shadow learner.
    private func account_user_id(db : *DbClient, learner_id : &string) : string {
        if(learner_id.empty()) { return string() }
        var escaped = underlayer_repository::sql_escape(learner_id)
        var sql = string("SELECT account_user_id FROM learners WHERE id = '")
        sql.append_string(&escaped)
        sql.append_view(string_view("' LIMIT 1"))
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0u) {
            var row = result.rows.at_ref(0u)
            if(row.vals.size() > 0u) { return row.vals.at_ref(0u).copy() }
        }
        return string()
    }

    private func entitlement_call(body : &string) : string {
        var token = env_or(string_view("ACCOUNT_ENTITLEMENT_TOKEN"), string_view(""))
        if(token.empty()) { return string() }
        var url_s = string()
        var acct = underlayer_core::account_url()
        url_s.append_view(acct.to_view())
        url_s.append_view(string_view("/api/entitlements/check"))
        var parsed_url = http::URL::parse(url_s.to_view())
        if(parsed_url is std::Option.None) { return string() }
        var Some(u) = parsed_url else return string()
        var rb = http::RequestBuilder("POST", std::replace(&mut u, http::URL()))
        var hv = token.to_view()
        rb.header_view(string_view("X-Wiqis-Service-Token"), &hv)
        var bv = body.to_view()
        rb.set_body(&bv, "application/json")
        var client = http::Client()
        var result = client.request(&rb)
        if(result is std::Result.Err) { return string() }
        var Ok(resp) = result else return string()
        var body_opt = resp.body.text()
        if(body_opt is std::Option.None) { return string() }
        var Some(text) = body_opt else return string()
        return text.to_string()
    }

    public func entitlement_active_for(db : *DbClient, req : &http::Request, course_id : &string) : bool {
        if(!is_paid_course(request_courses_dir(), course_id)) { return true }
        var learner = auth_get_learner_id(db, req)
        var account_id = account_user_id(db, &learner)
        if(account_id.empty()) { return false }
        var product = course_product(request_courses_dir(), course_id)
        if(product.empty()) { return false }
        var body = string("{\"user_id\":\"")
        var aiv = account_id.to_view()
        var q1 = underlayer_core::json_escape(&aiv)
        body.append_view(q1.to_view())
        body.append_view("\",\"product\":\"")
        var pv = product.to_view()
        var q2 = underlayer_core::json_escape(&pv)
        body.append_view(q2.to_view())
        body.append_view("\"}")
        var answer = entitlement_call(&body)
        if(answer.empty()) {
            var diag = string("ENTITLEMENT: no answer for learner=")
            diag.append_view(learner.to_view())
            diag.append_view(" account=")
            diag.append_view(account_id.to_view())
            diag.append_view(" product=")
            diag.append_view(product.to_view())
            underlayer_core::log_line(&diag)
            return false
        }
        var parsed = json::parse(answer.to_view())
        if(parsed is std::Result.Err) { return false }
        var Ok(root) = parsed else return false
        return json_get_bool(&root, "active")
    }

    // A guard, not a handler: None means "serve normally", Some is the 402.
    public func require_paid_course(db : *DbClient, req : &http::Request, course_id : &string) : std::Option<http::Response> {
        if(!is_paid_course(request_courses_dir(), course_id)) { return std::Option.None<http::Response>() }
        if(entitlement_active_for(db, req, course_id)) { return std::Option.None<http::Response>() }
        var msg = string("This course needs a pass. Your progress is saved; sign in with the account that bought the pass, or visit account.wiqis.com/purchase.")
        return std::Option.Some<http::Response>(send_error(402u, &msg))
    }

    // GET /api/entitlements/me â€” forwarded with the caller's OWN account token.
    // Used by the Android client; no local entitlement flag is kept on device.
    public func handle_entitlements_me(req : &http::Request) : http::Response {
        var auth_opt = req.headers.get(string_view("Authorization"))
        if(auth_opt is std::Option.None) { return err_resp(401u, "account credentials required") }
        var Some(auth) = auth_opt else return err_resp(401u, "account credentials required")
        if(auth.size() < 8u) { return err_resp(401u, "account credentials required") }
        var token = substr_from(auth, 7u)
        if(token.empty()) { return err_resp(401u, "account credentials required") }

        var url_s = string()
        var acct = underlayer_core::account_url()
        url_s.append_view(acct.to_view())
        url_s.append_view(string_view("/api/entitlements/me"))
        var product_opt = req.query.get("product")
        if(var Some(p) = product_opt) {
            url_s.append_view(string_view("?product="))
            var enc = percent_encode(p)
            url_s.append_view(enc.to_view())
        } else { }
        var parsed_url = http::URL::parse(url_s.to_view())
        if(parsed_url is std::Option.None) { return err_resp(502u, "account URL invalid") }
        var Some(u) = parsed_url else return err_resp(502u, "account URL invalid")
        var rb = http::RequestBuilder("GET", std::replace(&mut u, http::URL()))
        var header = string("Bearer ")
        header.append_view(token.to_view())
        var hv = header.to_view()
        rb.header_view(string_view("Authorization"), &hv)
        var client = http::Client()
        var result = client.request(&rb)
        if(result is std::Result.Err) { return err_resp(502u, "account service unavailable") }
        var Ok(resp) = result else return err_resp(502u, "account service unavailable")
        var body_opt = resp.body.text()
        if(body_opt is std::Option.None) { return err_resp(502u, "account response empty") }
        var Some(text) = body_opt else return err_resp(502u, "account response empty")
        var body_out = text.to_string()
        return send_json_str(&body_out)
    }

    private func percent_encode(text : string_view) : string {
        var out = string()
        var hex = string("0123456789ABCDEF")
        var i : size_t = 0u
        while(i < text.size()) {
            var c = text.at(i)
            if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_') {
                out.append(c)
            } else {
                out.append('%')
                out.append(hex.at(((c as uint) >> 4u) as size_t))
                out.append(hex.at(((c as uint) & 15u) as size_t))
            }
            i = i + 1u
        }
        return out
    }

    private func substr_from(text : string_view, start : size_t) : string {
        var out = string()
        var i = start
        while(i < text.size()) { out.append(text.at(i)); i = i + 1u }
        return out
    }

    // GET /api/courses with an additive `paid` boolean on every course object.
    // Registers as a NEW route before the frozen listing handler; that handler
    // is left byte-for-byte untouched.
    public func handle_list_courses_with_paid(courses_dir : &string, req : &http::Request) : http::Response {
        var res = handle_list_courses(courses_dir, req)
        var body_opt = res.body.text()
        if(body_opt is std::Option.None) { return res }
        var Some(original) = body_opt else return res
        var body = original.to_string()
        var courses = underlayer_repository::list_courses(courses_dir)
        var i : size_t = 0u
        while(i < courses.size()) {
            var c = courses.at_ref(i)
            var needle = string("\"id\":\"")
            needle.append_view(c.id.to_view())
            needle.append('"')
            var at = body.find_or_npos(needle.to_view())
            if(at != std::NPOS) {
                var flag = string(",\"paid\":")
                if(is_paid_course(courses_dir, &c.id)) { flag.append_view("true") }
                else { flag.append_view("false") }
                var insert_at = at + needle.size()
                var patched = body.substring(0u, insert_at)
                patched.append_view(flag.to_view())
                patched.append_view(body.to_view().subview(insert_at, body.size()))
                body = patched
            }
            i = i + 1u
        }
        res.text(body.to_view())
        return res
    }

    // A paid lesson is served from the course's own generated output, then
    // passed through the SAME SEO/pager/header/journey patches as every other
    // lesson so the served-output checkers see the identical contract.
    public func handle_paid_lesson(db : *DbClient, courses_dir : &string, course_id : &string, concept_id : &string, req : &http::Request) : http::Response {
        var cid = course_id.copy()
        var pid = concept_id.copy()
        var gate = require_paid_course(db, req, &cid)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else return err_resp(500u, "gate failure")
            return refusal
        }
        var lesson_path_s = courses_dir.copy()
        lesson_path_s.append_view(string_view("/"))
        lesson_path_s.append_view(cid.to_view())
        lesson_path_s.append_view(string_view("/output/"))
        lesson_path_s.append_view(pid.to_view())
        lesson_path_s.append_view(string_view(".html"))
        var pv = std::str.make_view(lesson_path_s.to_view())
        var fp = path::Path.new(pv)
        var read = fs::read_to_string(&fp)
        if(read is std::Result.Err) { return err_resp(404u, "lesson not found") }
        var Ok(lesson_html) = read else return err_resp(404u, "lesson not found")
        var course = underlayer_repository::load_course(courses_dir, &cid)
        var seoed = apply_lesson_seo(&lesson_html, &course, &pid)
        var paged = apply_lesson_pager(&seoed, &cid, &course, &pid)
        var headed = apply_lesson_header(&paged, &course, &pid)
        var journeyed = apply_lesson_journey(&headed, &course, &cid, &pid)
        return send_html(&journeyed)
    }
}
