// underlayer_web — Authentication API handlers (16.1-16.4).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // ---- Helpers ----

    private func generate_random_hex(len : size_t) : string {
        var buf : [64]u8
        var fill_len = len / 2
        if(fill_len > 64) { fill_len = 64 }
        osrand::random_fill(&raw mut buf[0], fill_len)
        var hex_out : [129]char
        var i0 : size_t = 0
        while(i0 < 129) { hex_out[i0] = 0; i0 = i0 + 1 }
        encoding::hex_encode(&raw buf[0], fill_len, &raw mut hex_out[0], 129)
        var result = string()
        var i : size_t = 0
        while(i < len && hex_out[i] != 0) { result.append(hex_out[i]); i = i + 1 }
        return result
    }

    private func sha256_hex(data : *u8, data_len : size_t) : string {
        var digest : [32]u8
        var di : size_t = 0
        while(di < 32) { digest[di] = 0; di = di + 1 }
        crypto::sha256_hash(data, data_len, &raw mut digest[0])
        var hex_out : [65]char
        var hi : size_t = 0
        while(hi < 65) { hex_out[hi] = 0; hi = hi + 1 }
        encoding::hex_encode(&raw digest[0], 32, &raw mut hex_out[0], 65)
        var result = string()
        var ri : size_t = 0
        while(ri < 64 && hex_out[ri] != 0) { result.append(hex_out[ri]); ri = ri + 1 }
        return result
    }

    private func hash_token(token : *string) : string {
        return sha256_hex(token.data() as *u8, token.size())
    }

    private func hash_password(password : *string) : string {
        return sha256_hex(password.data() as *u8, password.size())
    }

    private func extract_bearer_token(req : &http::Request) : string {
        var auth_opt = req.headers.get("Authorization")
        if(auth_opt is std::Option.None) { return string() }
        var Some(auth_header) = auth_opt else return string()
        if(auth_header.size() < 8) { return string() }
        var ok = auth_header.get(0) == 'B' && auth_header.get(1) == 'e' && auth_header.get(2) == 'a' && auth_header.get(3) == 'r' && auth_header.get(4) == 'e' && auth_header.get(5) == 'r' && auth_header.get(6) == ' '
        if(!ok) { return string() }
        var token = string()
        var ti : size_t = 7
        while(ti < auth_header.size()) { token.append(auth_header.get(ti)); ti = ti + 1 }
        return token
    }

    public func auth_get_learner_id(db : *DbClient, req : &http::Request) : string {
        var token = extract_bearer_token(req)
        if(token.size() == 0) { return string() }
        var token_hash = hash_token(&raw token)
        var sql = string("SELECT learner_id FROM auth_sessions WHERE token_hash = '")
        sql.append_string(&token_hash)
        sql.append_view("' AND expires_at > ")
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        sql.append_view(now.to_view())
        sql.append_view(" LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                return row.vals.get_ptr(0).copy()
            }
        }
        return string()
    }

    private func create_session(db : *DbClient, learner_id : *string) : string {
        var token = generate_random_hex(64)
        var token_hash = hash_token(&raw token)
        var session_id = generate_random_hex(32)
        var now = underlayer_core::current_timestamp()
        var expires_at = now + 2592000
        var expires_str = underlayer_core::int_to_string(expires_at)
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO auth_sessions (id, learner_id, token_hash, expires_at, last_active, created_at) VALUES ('")
        sql.append_string(&session_id)
        sql.append_view("', '")
        sql.append_string(&(*learner_id))
        sql.append_view("', '")
        sql.append_string(&token_hash)
        sql.append_view("', ")
        sql.append_view(expires_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return token
    }

    // ---- 16.1.1: POST /api/auth/register ----

    public func handle_register(db : *DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var email = json_get_str(&raw parsed, "email")
        var password = json_get_str(&raw parsed, "password")
        var name = json_get_str(&raw parsed, "name")
        if(email.size() == 0) {
            var err = string("email is required")
            send_error(res, 400u, &err)
            return
        }
        if(password.size() < 8) {
            var err = string("password must be at least 8 characters")
            send_error(res, 400u, &err)
            return
        }
        var has_at = false
        var has_dot = false
        var ei : size_t = 0
        while(ei < email.size()) {
            var c = email.get(ei)
            if(c == '@') { has_at = true }
            if(c == '.') { has_dot = true }
            ei = ei + 1
        }
        if(!has_at || !has_dot) {
            var err = string("invalid email format")
            send_error(res, 400u, &err)
            return
        }
        var check_sql = string("SELECT id FROM learners WHERE email = '")
        check_sql.append_string(&email)
        check_sql.append_view("'")
        var existing = underlayer_db::query_sql(db, &raw check_sql)
        if(existing.rows.size() > 0) {
            var err = string("email already registered")
            send_error(res, 409u, &err)
            return
        }
        var pw_hash = hash_password(&raw password)
        var learner_id = generate_random_hex(32)
        underlayer_repository::create_learner(db, &learner_id, &name, &email)
        var ph_sql = string("UPDATE learners SET password_hash = '")
        ph_sql.append_string(&pw_hash)
        ph_sql.append_view("' WHERE id = '")
        ph_sql.append_string(&learner_id)
        ph_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw ph_sql)
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var prof_sql = string("INSERT OR IGNORE INTO learner_profiles (learner_id, display_name, username, created_at, updated_at) VALUES ('")
        prof_sql.append_string(&learner_id)
        prof_sql.append_view("', '")
        prof_sql.append_string(&name)
        prof_sql.append_view("', '', ")
        prof_sql.append_view(now_str.to_view())
        prof_sql.append_view(", ")
        prof_sql.append_view(now_str.to_view())
        prof_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw prof_sql)
        var set_sql = string("INSERT OR IGNORE INTO learner_settings (learner_id, created_at, updated_at) VALUES ('")
        set_sql.append_string(&learner_id)
        set_sql.append_view("', ")
        set_sql.append_view(now_str.to_view())
        set_sql.append_view(", ")
        set_sql.append_view(now_str.to_view())
        set_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw set_sql)
        var pref_sql = string("INSERT OR IGNORE INTO learning_preferences (learner_id, created_at, updated_at) VALUES ('")
        pref_sql.append_string(&learner_id)
        pref_sql.append_view("', ")
        pref_sql.append_view(now_str.to_view())
        pref_sql.append_view(", ")
        pref_sql.append_view(now_str.to_view())
        pref_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw pref_sql)
        var wtype = string("system")
        var wtitle = string("Welcome to Underlayer")
        var wmsg = string("Start with the ELF course to begin learning.")
        var wcourse = string("elf")
        var wconcept = string("")
        var wurl = string("/courses/elf")
        underlayer_repository::create_notification(db, &learner_id, &wtype, &wtitle, &wmsg, &wcourse, &wconcept, &wurl)
        var token = create_session(db, &raw learner_id)
        var resp = string("{\"learner_id\":\"")
        resp.append_string(&learner_id)
        resp.append_view("\",\"session_token\":\"")
        resp.append_string(&token)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.2.1: POST /api/auth/login ----

    public func handle_login(db : *DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var email = json_get_str(&raw parsed, "email")
        var password = json_get_str(&raw parsed, "password")
        if(email.size() == 0 || password.size() == 0) {
            var err = string("email and password are required")
            send_error(res, 400u, &err)
            return
        }
        var sel_sql = string("SELECT id, name, password_hash FROM learners WHERE email = '")
        sel_sql.append_string(&email)
        sel_sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sel_sql)
        if(result.rows.size() == 0) {
            var now = underlayer_core::current_timestamp()
            var now_str = underlayer_core::int_to_string(now)
            var fail_sql = string("INSERT INTO login_history (learner_id, success, failure_reason, created_at) VALUES ('', 0, 'user not found', ")
            fail_sql.append_view(now_str.to_view())
            fail_sql.append_view(")")
            underlayer_db::exec_sql(db, &raw fail_sql)
            var err = string("invalid email or password")
            send_error(res, 401u, &err)
            return
        }
        var row = result.rows.get_ptr(0)
        var learner_id = row.vals.get_ptr(0).copy()
        var pw_hash = hash_password(&raw password)
        var stored_hash = row.vals.get_ptr(2).copy()
        if(!pw_hash.equals(&stored_hash)) {
            var now = underlayer_core::current_timestamp()
            var now_str = underlayer_core::int_to_string(now)
            var fail_sql = string("INSERT INTO login_history (learner_id, success, failure_reason, created_at) VALUES ('")
            fail_sql.append_string(&learner_id)
            fail_sql.append_view("', 0, 'wrong password', ")
            fail_sql.append_view(now_str.to_view())
            fail_sql.append_view(")")
            underlayer_db::exec_sql(db, &raw fail_sql)
            var err = string("invalid email or password")
            send_error(res, 401u, &err)
            return
        }
        var token = create_session(db, &raw learner_id)
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var hist_sql = string("INSERT INTO login_history (learner_id, success, created_at) VALUES ('")
        hist_sql.append_string(&learner_id)
        hist_sql.append_view("', 1, ")
        hist_sql.append_view(now_str.to_view())
        hist_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw hist_sql)
        var resp = string("{\"learner_id\":\"")
        resp.append_string(&learner_id)
        resp.append_view("\",\"session_token\":\"")
        resp.append_string(&token)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.2.17: POST /api/auth/logout ----

    public func handle_logout(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var token = extract_bearer_token(req)
        if(token.size() == 0) {
            var err = string("missing token")
            send_error(res, 401u, &err)
            return
        }
        var token_hash = hash_token(&raw token)
        var sql = string("DELETE FROM auth_sessions WHERE token_hash = '")
        sql.append_string(&token_hash)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.2.14: GET /api/auth/me ----

    public func handle_get_me(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var learner = underlayer_repository::get_learner(db, &learner_id)
        if(learner.id.size() == 0) {
            var err = string("learner not found")
            send_error(res, 404u, &err)
            return
        }
        var profile = underlayer_repository::get_profile(db, &learner_id)
        var resp = string("{\"learner_id\":\"")
        resp.append_string(&learner.id)
        resp.append_view("\",\"name\":\"")
        resp.append_string(&learner.name)
        resp.append_view("\",\"email\":\"")
        resp.append_string(&learner.email)
        resp.append_view("\",\"username\":\"")
        resp.append_string(&profile.username)
        resp.append_view("\",\"display_name\":\"")
        resp.append_string(&profile.display_name)
        resp.append_view("\",\"avatar_url\":\"")
        resp.append_string(&profile.avatar_url)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.3.3: POST /api/auth/forgot-password ----

    public func handle_forgot_password(db : *DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var email = json_get_str(&raw parsed, "email")
        if(email.size() == 0) {
            var err = string("email is required")
            send_error(res, 400u, &err)
            return
        }
        var sel_sql = string("SELECT id FROM learners WHERE email = '")
        sel_sql.append_string(&email)
        sel_sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sel_sql)
        if(result.rows.size() == 0) {
            var resp = string("{\"ok\":true,\"message\":\"Check your email\"}")
            send_json_str(res, &raw resp)
            return
        }
        var row = result.rows.get_ptr(0)
        var learner_id = row.vals.get_ptr(0).copy()
        var reset_token = generate_random_hex(64)
        var token_hash = hash_token(&raw reset_token)
        var token_id = generate_random_hex(32)
        var now = underlayer_core::current_timestamp()
        var expires_at = now + 3600
        var now_str = underlayer_core::int_to_string(now)
        var expires_str = underlayer_core::int_to_string(expires_at)
        var ins_sql = string("INSERT INTO password_reset_tokens (id, learner_id, token_hash, expires_at, created_at) VALUES ('")
        ins_sql.append_string(&token_id)
        ins_sql.append_view("', '")
        ins_sql.append_string(&learner_id)
        ins_sql.append_view("', '")
        ins_sql.append_string(&token_hash)
        ins_sql.append_view("', ")
        ins_sql.append_view(expires_str.to_view())
        ins_sql.append_view(", ")
        ins_sql.append_view(now_str.to_view())
        ins_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw ins_sql)
        var resp = string("{\"ok\":true,\"message\":\"Check your email\"}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.3.6: POST /api/auth/reset-password ----

    public func handle_reset_password(db : *DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var token = json_get_str(&raw parsed, "token")
        var new_password = json_get_str(&raw parsed, "password")
        if(token.size() == 0 || new_password.size() == 0) {
            var err = string("token and password are required")
            send_error(res, 400u, &err)
            return
        }
        if(new_password.size() < 8) {
            var err = string("password must be at least 8 characters")
            send_error(res, 400u, &err)
            return
        }
        var token_hash = hash_token(&raw token)
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sel_sql = string("SELECT id, learner_id FROM password_reset_tokens WHERE token_hash = '")
        sel_sql.append_string(&token_hash)
        sel_sql.append_view("' AND used = 0 AND expires_at > ")
        sel_sql.append_view(now_str.to_view())
        sel_sql.append_view(" LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sel_sql)
        if(result.rows.size() == 0) {
            var err = string("invalid or expired token")
            send_error(res, 400u, &err)
            return
        }
        var row = result.rows.get_ptr(0)
        var reset_id = row.vals.get_ptr(0).copy()
        var learner_id = row.vals.get_ptr(1).copy()
        var new_hash = hash_password(&raw new_password)
        var upd_sql = string("UPDATE learners SET password_hash = '")
        upd_sql.append_string(&new_hash)
        upd_sql.append_view("' WHERE id = '")
        upd_sql.append_string(&learner_id)
        upd_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw upd_sql)
        var mark_sql = string("UPDATE password_reset_tokens SET used = 1 WHERE id = '")
        mark_sql.append_string(&reset_id)
        mark_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw mark_sql)
        var del_sql = string("DELETE FROM auth_sessions WHERE learner_id = '")
        del_sql.append_string(&learner_id)
        del_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.4.4: POST /api/auth/verify-email ----

    public func handle_verify_email(db : *DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var token = json_get_str(&raw parsed, "token")
        if(token.size() == 0) {
            var err = string("token is required")
            send_error(res, 400u, &err)
            return
        }
        var token_hash = hash_token(&raw token)
        var sel_sql = string("SELECT id FROM email_verification_tokens WHERE token_hash = '")
        sel_sql.append_string(&token_hash)
        sel_sql.append_view("' AND used = 0 LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sel_sql)
        if(result.rows.size() == 0) {
            var err = string("invalid or already used token")
            send_error(res, 400u, &err)
            return
        }
        var row = result.rows.get_ptr(0)
        var token_id = row.vals.get_ptr(0).copy()
        var mark_sql = string("UPDATE email_verification_tokens SET used = 1 WHERE id = '")
        mark_sql.append_string(&token_id)
        mark_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw mark_sql)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // ---- 16.10.1: GET /api/user/login-history ----

    public func handle_login_history(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var sel_sql = string("SELECT id, learner_id, ip_address, user_agent, success, failure_reason, created_at FROM login_history WHERE learner_id = '")
        sel_sql.append_string(&learner_id)
        sel_sql.append_view("' ORDER BY created_at DESC LIMIT 20")
        var result = underlayer_db::query_sql(db, &raw sel_sql)
        var resp = string("[")
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            if(ri > 0) { resp.append_view(",") }
            var row = result.rows.get_ptr(ri)
            var val0 = row.vals.get_ptr(0).copy()
            var val1 = row.vals.get_ptr(1).copy()
            var val2 = row.vals.get_ptr(2).copy()
            var val3 = row.vals.get_ptr(3).copy()
            var val4 = row.vals.get_ptr(4).copy()
            var val5 = row.vals.get_ptr(5).copy()
            var val6 = row.vals.get_ptr(6).copy()
            resp.append_view("{\"id\":")
            resp.append_string(&val0)
            resp.append_view(",\"learner_id\":\"")
            resp.append_string(&val1)
            resp.append_view("\",\"ip_address\":\"")
            resp.append_string(&val2)
            resp.append_view("\",\"user_agent\":\"")
            resp.append_string(&val3)
            resp.append_view("\",\"success\":")
            if(val4.equals(&string("1"))) { resp.append_view("true") } else { resp.append_view("false") }
            resp.append_view(",\"failure_reason\":\"")
            resp.append_string(&val5)
            resp.append_view("\",\"created_at\":")
            resp.append_string(&val6)
            resp.append_view("}")
            ri = ri + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

}
