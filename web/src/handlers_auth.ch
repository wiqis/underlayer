// underlayer_web — the session lifecycle: register, login, logout, whoami.
//
// WHY THIS FILE IS ONLY PART OF WHAT USED TO BE HERE.  It was one 606-line file
// holding the lifecycle, the password-reset endpoints and the login history.  It
// is now three, split by concern, because the file grew every time a security
// fix landed in it -- which is exactly the condition the 250-line rule in
// AGENTS.md exists to stop: a file nobody wants to touch, holding the code that
// most needs it.
//
//   handlers_auth.ch            (here)  register, login, logout, /api/auth/me
//   handlers_auth_password.ch            forgot / reset / verify-email
//   handlers_auth_history.ch             /api/user/login-history
//   password_hash.ch                    bcrypt hashing + legacy-SHA256 upgrade
//   session_guard.ch                     session-ownership gate
//
// The four helpers above (random hex, SHA-256, bearer-token extraction, session
// creation, auth_get_learner_id) are shared by all three and live here because
// this is the layer that owns authentication.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {
    // ---- Helpers ----

    // public, not private: handlers_auth_password.ch mints reset and
    // verification tokens with it.  That is the rule in AGENTS.md -- a
    // private helper shared across files becomes public -- and leaving it
    // private is a link error, not a style note.
    public func generate_random_hex(len : size_t) : string {
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

    // public for the same reason as generate_random_hex above.
    public func sha256_hex(data : *u8, data_len : size_t) : string {
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

    // Session and reset tokens are stored as SHA-256 of the token.  That is
    // correct and unchanged: a token is 64 hex characters of CSPRNG output, so
    // there is nothing to guess and nothing to brute-force -- the database copy
    // is useless to an attacker without the token itself.  What is NOT correct
    // is to use the same primitive for PASSWORDS, which is why that lives in
    // password_hash.ch and comes back here through these two functions.
    // public for the same reason as generate_random_hex above.
    public func hash_token(token : *string) : string {
        return sha256_hex(token.data() as *u8, token.size())
    }

    // Password hashing lives in password_hash.ch, not here.  `hash_password`
    // and `verify_password` in the underlayer_web namespace are bcrypt with a
    // per-user random salt and a 2^12 work factor, stored self-describing so
    // the cost can be raised later without a schema change; `verify_password`
    // also accepts the old unsalted SHA-256 rows so no existing learner is
    // locked out, and `password_is_legacy_sha256` says when a row has earned an
    // upgrade.  Do not reintroduce a local wrapper of either name -- that is
    // exactly the collision the compiler rejected when this file first called
    // the new scheme.

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
        // email and name are request text concatenated into SQL literals.  Escaping
        // here is what stops a name like "O'Brien" from turning the INSERT into
        // a syntax error: because exec_sql discards SQLite's error, that used to
        // register an account that did not exist -- 200 with a session token,
        // then 404 on /api/auth/me and 401 on every later login.
        var email_safe = underlayer_repository::sql_escape(&email)
        var name_safe = underlayer_repository::sql_escape(&name)
        var check_sql = string("SELECT id FROM learners WHERE email = '")
        check_sql.append_string(&email_safe)
        check_sql.append_view("'")
        var existing = underlayer_db::query_sql(db, &raw check_sql)
        if(existing.rows.size() > 0) {
            var err = string("email already registered")
            send_error(res, 409u, &err)
            return
        }
        var pw_hash = hash_password(&raw password)
        var learner_id = generate_random_hex(32)
        var learner_safe = underlayer_repository::sql_escape(&learner_id)
        var hash_safe = underlayer_repository::sql_escape(&pw_hash)
        // One statement, and its effect is CHECKED.  create_learner() left the
        // password_hash column NULL and needed a second UPDATE to fill it, so
        // a failure anywhere between the two left a row that could never log
        // in.  rows_affected is now asserted below rather than assumed.
        var insert_rows = underlayer_repository::create_learner_with_hash(db, &learner_id, &name, &email, &pw_hash)
        if(insert_rows == 0) {
            var err = string("could not create the account")
            send_error(res, 500u, &err)
            return
        }
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var prof_sql = string("INSERT OR IGNORE INTO learner_profiles (learner_id, display_name, username, created_at, updated_at) VALUES ('")
        prof_sql.append_string(&learner_safe)
        prof_sql.append_view("', '")
        prof_sql.append_string(&name_safe)
        prof_sql.append_view("', '', ")
        prof_sql.append_view(now_str.to_view())
        prof_sql.append_view(", ")
        prof_sql.append_view(now_str.to_view())
        prof_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw prof_sql)
        var set_sql = string("INSERT OR IGNORE INTO learner_settings (learner_id, created_at, updated_at) VALUES ('")
        set_sql.append_string(&learner_safe)
        set_sql.append_view("', ")
        set_sql.append_view(now_str.to_view())
        set_sql.append_view(", ")
        set_sql.append_view(now_str.to_view())
        set_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw set_sql)
        var pref_sql = string("INSERT OR IGNORE INTO learning_preferences (learner_id, created_at, updated_at) VALUES ('")
        pref_sql.append_string(&learner_safe)
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
        // The email arrives in a JSON body and is concatenated straight into a
        // SQL literal.  Escaped here, in the handler, because this is the one
        // place in the file where a crafted email used to authenticate anybody:
        // "x' OR password_hash='<sha256 of a known password>" was returned 200
        // with a live session token.  tools/sqli_scan.py finds this pattern
        // anywhere it reappears.
        var email_safe = underlayer_repository::sql_escape(&email)
        var sel_sql = string("SELECT id, name, password_hash FROM learners WHERE email = '")
        sel_sql.append_string(&email_safe)
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
        var stored_hash = row.vals.get_ptr(2).copy()
        // Verify, do not re-hash-and-compare.  verify_password understands both
        // the current bcrypt form and the legacy unsalted SHA-256 rows, so a
        // learner created before the fix can still sign in.
        if(!verify_password(&raw password, &raw stored_hash)) {
            var now = underlayer_core::current_timestamp()
            var now_str = underlayer_core::int_to_string(now)
            var learner_safe = underlayer_repository::sql_escape(&learner_id)
            var fail_sql = string("INSERT INTO login_history (learner_id, success, failure_reason, created_at) VALUES ('")
            fail_sql.append_string(&learner_safe)
            fail_sql.append_view("', 0, 'wrong password', ")
            fail_sql.append_view(now_str.to_view())
            fail_sql.append_view(")")
            underlayer_db::exec_sql(db, &raw fail_sql)
            var err = string("invalid email or password")
            send_error(res, 401u, &err)
            return
        }
        // Self-upgrading migration.  A row that still verified against the old
        // scheme is rewritten in bcrypt here, on the one request where we have
        // just proved we know the plaintext.  Nothing is migrated in bulk, so
        // no account is locked out by a bad migration script, and the fleet
        // converges one real login at a time.
        if(underlayer_web::password_is_legacy_sha256(&raw stored_hash)) {
            var upgraded = hash_password(&raw password)
            if(upgraded.size() > 0u) {
                var up_learner = underlayer_repository::sql_escape(&learner_id)
                var up_hash = underlayer_repository::sql_escape(&upgraded)
                var up_sql = string("UPDATE learners SET password_hash = '")
                up_sql.append_string(&up_hash)
                up_sql.append_view("' WHERE id = '")
                up_sql.append_string(&up_learner)
                up_sql.append_view("'")
                underlayer_db::exec_sql(db, &raw up_sql)
            }
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

}
