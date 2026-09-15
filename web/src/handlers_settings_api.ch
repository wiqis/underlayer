// underlayer_web — Settings API handlers (16.6-16.7).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    private func settings_get_learner_id(db : *DbClient, req : &http::Request) : string {
        var auth_opt = req.headers.get("Authorization")
        if(auth_opt is std::Option.None) { return string() }
        var Some(auth_header) = auth_opt else return string()
        if(auth_header.size() < 8) { return string() }
        var ok = auth_header.get(0) == 'B' && auth_header.get(1) == 'e' && auth_header.get(2) == 'a' && auth_header.get(3) == 'r' && auth_header.get(4) == 'e' && auth_header.get(5) == 'r' && auth_header.get(6) == ' '
        if(!ok) { return string() }
        var token = string()
        var ti : size_t = 7
        while(ti < auth_header.size()) { token.append(auth_header.get(ti)); ti = ti + 1 }
        var data = token.data() as *u8
        var digest : [32]u8
        var di : size_t = 0
        while(di < 32) { digest[di] = 0; di = di + 1 }
        crypto::sha256_hash(data, token.size(), &raw mut digest[0])
        var hex_out : [65]char
        var hi : size_t = 0
        while(hi < 65) { hex_out[hi] = 0; hi = hi + 1 }
        encoding::hex_encode(&raw digest[0], 32, &raw mut hex_out[0], 65)
        var token_hash = string()
        hi = 0
        while(hi < 64 && hex_out[hi] != 0) { token_hash.append(hex_out[hi]); hi = hi + 1 }
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

    public func handle_get_settings(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = settings_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var settings = underlayer_repository::get_settings(db, &learner_id)
        var body = std::string("{\"learner_id\":\"")
        body.append_string(&settings.learner_id)
        body.append_view("\",\"theme\":\"")
        body.append_string(&settings.theme)
        body.append_view("\",\"font_size\":\"")
        body.append_string(&settings.font_size)
        body.append_view("\",\"language\":\"")
        body.append_string(&settings.language)
        body.append_view("\",\"timezone\":\"")
        body.append_string(&settings.timezone)
        body.append_view("\",\"date_format\":\"")
        body.append_string(&settings.date_format)
        body.append_view("\",\"email_notifications\":")
        if(settings.email_notifications) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"push_notifications\":")
        if(settings.push_notifications) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"in_app_notifications\":")
        if(settings.in_app_notifications) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"compact_mode\":")
        if(settings.compact_mode) { body.append_view("true") } else { body.append_view("false") }
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    public func handle_update_settings(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = settings_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var settings = underlayer_repository::get_settings(db, &learner_id)
        settings.learner_id = learner_id.copy()
        var body_str = read_body(&raw mut req)
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
        var theme = json_get_str(&raw parsed, "theme")
        if(theme.size() > 0) { settings.theme = theme }
        var fs = json_get_str(&raw parsed, "font_size")
        if(fs.size() > 0) { settings.font_size = fs }
        var lang = json_get_str(&raw parsed, "language")
        if(lang.size() > 0) { settings.language = lang }
        var tz = json_get_str(&raw parsed, "timezone")
        if(tz.size() > 0) { settings.timezone = tz }
        var df = json_get_str(&raw parsed, "date_format")
        if(df.size() > 0) { settings.date_format = df }
        settings.email_notifications = json_get_bool(&raw parsed, "email_notifications")
        settings.push_notifications = json_get_bool(&raw parsed, "push_notifications")
        settings.in_app_notifications = json_get_bool(&raw parsed, "in_app_notifications")
        settings.compact_mode = json_get_bool(&raw parsed, "compact_mode")
        underlayer_repository::upsert_settings(db, &raw settings)
        var body = std::string("{\"ok\":true}")
        send_json_str(res, &raw body)
    }

    public func handle_get_learning_preferences(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = settings_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var prefs = underlayer_repository::get_learning_preferences(db, &learner_id)
        var body = std::string("{\"learner_id\":\"")
        body.append_string(&prefs.learner_id)
        body.append_view("\",\"daily_goal_minutes\":")
        var dgm = underlayer_core::int_to_string(prefs.daily_goal_minutes as i64)
        body.append_view(dgm.to_view())
        body.append_view(",\"daily_review_items\":")
        var dri = underlayer_core::int_to_string(prefs.daily_review_items as i64)
        body.append_view(dri.to_view())
        body.append_view(",\"session_length_minutes\":")
        var slm = underlayer_core::int_to_string(prefs.session_length_minutes as i64)
        body.append_view(slm.to_view())
        body.append_view(",\"break_reminder_minutes\":")
        var brm = underlayer_core::int_to_string(prefs.break_reminder_minutes as i64)
        body.append_view(brm.to_view())
        body.append_view(",\"preferred_session_time\":\"")
        body.append_string(&prefs.preferred_session_time)
        body.append_view("\",\"energy_checkin\":")
        if(prefs.energy_checkin) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"difficulty_preference\":\"")
        body.append_string(&prefs.difficulty_preference)
        body.append_view("\",\"interleaving_preference\":\"")
        body.append_string(&prefs.interleaving_preference)
        body.append_view("\",\"review_scheduling\":\"")
        body.append_string(&prefs.review_scheduling)
        body.append_view("\",\"show_streaks\":")
        if(prefs.show_streaks) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"show_leaderboards\":")
        if(prefs.show_leaderboards) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"show_achievements\":")
        if(prefs.show_achievements) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"auto_play_audio\":")
        if(prefs.auto_play_audio) { body.append_view("true") } else { body.append_view("false") }
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    public func handle_update_learning_preferences(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = settings_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var prefs = underlayer_repository::get_learning_preferences(db, &learner_id)
        prefs.learner_id = learner_id.copy()
        var body_str = read_body(&raw mut req)
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
        var dgm = json_get_int(&raw parsed, "daily_goal_minutes")
        if(dgm > 0) { prefs.daily_goal_minutes = dgm }
        var dri = json_get_int(&raw parsed, "daily_review_items")
        if(dri > 0) { prefs.daily_review_items = dri }
        var slm = json_get_int(&raw parsed, "session_length_minutes")
        if(slm > 0) { prefs.session_length_minutes = slm }
        var brm = json_get_int(&raw parsed, "break_reminder_minutes")
        if(brm > 0) { prefs.break_reminder_minutes = brm }
        var pst = json_get_str(&raw parsed, "preferred_session_time")
        if(pst.size() > 0) { prefs.preferred_session_time = pst }
        prefs.energy_checkin = json_get_bool(&raw parsed, "energy_checkin")
        var dp = json_get_str(&raw parsed, "difficulty_preference")
        if(dp.size() > 0) { prefs.difficulty_preference = dp }
        var ip = json_get_str(&raw parsed, "interleaving_preference")
        if(ip.size() > 0) { prefs.interleaving_preference = ip }
        var rs = json_get_str(&raw parsed, "review_scheduling")
        if(rs.size() > 0) { prefs.review_scheduling = rs }
        prefs.show_streaks = json_get_bool(&raw parsed, "show_streaks")
        prefs.show_leaderboards = json_get_bool(&raw parsed, "show_leaderboards")
        prefs.show_achievements = json_get_bool(&raw parsed, "show_achievements")
        prefs.auto_play_audio = json_get_bool(&raw parsed, "auto_play_audio")
        underlayer_repository::upsert_learning_preferences(db, &raw prefs)
        var body = std::string("{\"ok\":true}")
        send_json_str(res, &raw body)
    }

}
