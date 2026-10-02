// underlayer_web — password reset and email verification.
//
// Split out of the 606-line handlers_auth.ch.  Split BY CONCERN rather than by
// size: these three endpoints are the ones that mint a credential, so they are
// the ones an audit has to read closely, and burying them under register/login
// made that harder.
//
// THE SHAPE OF ALL THREE IS THE SAME AND IS DELIBERATE.  The token arrives in
// the body, is hashed with SHA-256 before it touches SQL, and only the hash is
// ever stored -- so a leaked password_reset_tokens table is useless without the
// token, which the founder's original note already called out as the sound part
// of the auth code.  Password RESET, by contrast, is the one place that writes a
// new password_hash, so it goes through hash_password() like every other write;
// a learner who resets their password also leaves the legacy scheme behind.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {
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
        // Same escaping as login and register: the email is request text going into a
        // SQL literal, and an unescaped one here let an attacker ask "which
        // emails exist" by watching whether a reset row was created.
        var email_safe = underlayer_repository::sql_escape(&email)
        var sel_sql = string("SELECT id FROM learners WHERE email = '")
        sel_sql.append_string(&email_safe)
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
        // The new password is hashed with bcrypt here too, so a reset produces the
        // same row shape as a registration and a legacy learner is upgraded by
        // a reset even if they never sign in again.
        var new_hash = hash_password(&raw new_password)
        var new_hash_safe = underlayer_repository::sql_escape(&new_hash)
        var learner_safe = underlayer_repository::sql_escape(&learner_id)
        var upd_sql = string("UPDATE learners SET password_hash = '")
        upd_sql.append_string(&new_hash_safe)
        upd_sql.append_view("' WHERE id = '")
        upd_sql.append_string(&learner_safe)
        upd_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw upd_sql)
        var mark_sql = string("UPDATE password_reset_tokens SET used = 1 WHERE id = '")
        mark_sql.append_string(&reset_id)
        mark_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw mark_sql)
        // Resetting a password revokes every existing session for that learner.
        // This was already here and is correct: it is what stops a stolen token
        // from surviving the owner's password change.
        var del_sql = string("DELETE FROM auth_sessions WHERE learner_id = '")
        del_sql.append_string(&learner_safe)
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

}
