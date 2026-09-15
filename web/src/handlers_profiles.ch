// underlayer_web — Profile API handlers (16.5).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    private func get_learner_id_from_token(db : *DbClient, req : &http::Request) : string {
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

    public func handle_get_profile(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = get_learner_id_from_token(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var profile = underlayer_repository::get_profile(db, &learner_id)
        var body = std::string("{\"learner_id\":\"")
        body.append_string(&profile.learner_id)
        body.append_view("\",\"display_name\":\"")
        body.append_string(&profile.display_name)
        body.append_view("\",\"username\":\"")
        body.append_string(&profile.username)
        body.append_view("\",\"avatar_url\":\"")
        body.append_string(&profile.avatar_url)
        body.append_view("\",\"bio\":\"")
        body.append_string(&profile.bio)
        body.append_view("\",\"learning_goals\":\"")
        body.append_string(&profile.learning_goals)
        body.append_view("\",\"location\":\"")
        body.append_string(&profile.location)
        body.append_view("\",\"website\":\"")
        body.append_string(&profile.website)
        body.append_view("\",\"social_twitter\":\"")
        body.append_string(&profile.social_twitter)
        body.append_view("\",\"social_github\":\"")
        body.append_string(&profile.social_github)
        body.append_view("\",\"social_linkedin\":\"")
        body.append_string(&profile.social_linkedin)
        body.append_view("\",\"visibility\":\"")
        body.append_string(&profile.visibility)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    public func handle_update_profile(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = get_learner_id_from_token(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var profile = underlayer_repository::get_profile(db, &learner_id)
        profile.learner_id = learner_id.copy()
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
        var dn = json_get_str(&raw parsed, "display_name")
        if(dn.size() > 0) { profile.display_name = dn }
        var un = json_get_str(&raw parsed, "username")
        if(un.size() > 0) {
            if(un.size() < 3 || un.size() > 20) {
                var err = string("username must be 3-20 characters")
                send_error(res, 400u, &err)
                return
            }
            var valid = true
            var ci : size_t = 0
            while(ci < un.size()) {
                var c = un.get(ci)
                if(!(c >= 'a' && c <= 'z') && !(c >= 'A' && c <= 'Z') && !(c >= '0' && c <= '9') && c != '_') { valid = false; ci = un.size() }
                ci = ci + 1
            }
            if(!valid) {
                var err = string("username must be alphanumeric or underscore")
                send_error(res, 400u, &err)
                return
            }
            if(!underlayer_repository::is_username_available(db, &un, &learner_id)) {
                var err = string("username already taken")
                send_error(res, 409u, &err)
                return
            }
            profile.username = un
            profile.username_changed_at = underlayer_core::current_timestamp()
        }
        var bio = json_get_str(&raw parsed, "bio")
        if(bio.size() > 0) { profile.bio = bio }
        var loc = json_get_str(&raw parsed, "location")
        if(loc.size() > 0) { profile.location = loc }
        var web = json_get_str(&raw parsed, "website")
        if(web.size() > 0) { profile.website = web }
        var tw = json_get_str(&raw parsed, "social_twitter")
        if(tw.size() > 0) { profile.social_twitter = tw }
        var gh = json_get_str(&raw parsed, "social_github")
        if(gh.size() > 0) { profile.social_github = gh }
        var li = json_get_str(&raw parsed, "social_linkedin")
        if(li.size() > 0) { profile.social_linkedin = li }
        var vis = json_get_str(&raw parsed, "visibility")
        if(vis.size() > 0) { profile.visibility = vis }
        underlayer_repository::upsert_profile(db, &raw profile)
        var body = std::string("{\"ok\":true}")
        send_json_str(res, &raw body)
    }

    public func handle_get_public_profile(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 3) {
            var err = string("missing username")
            send_error(res, 400u, &err)
            return
        }
        var username_raw = segments.get_ptr(segments.size() - 1)
        var username = string()
        var ui : size_t = 0
        while(ui < username_raw.size()) { username.append(username_raw.get(ui)); ui = ui + 1 }
        var profile = underlayer_repository::get_profile_by_username(db, &username)
        if(profile.learner_id.size() == 0) {
            var err = string("profile not found")
            send_error(res, 404u, &err)
            return
        }
        var private_vis = string("private")
        if(profile.visibility.equals(&private_vis)) {
            var err = string("profile is private")
            send_error(res, 403u, &err)
            return
        }
        var body = std::string("{\"display_name\":\"")
        body.append_string(&profile.display_name)
        body.append_view("\",\"username\":\"")
        body.append_string(&profile.username)
        body.append_view("\",\"avatar_url\":\"")
        body.append_string(&profile.avatar_url)
        body.append_view("\",\"bio\":\"")
        body.append_string(&profile.bio)
        body.append_view("\",\"learning_goals\":\"")
        body.append_string(&profile.learning_goals)
        body.append_view("\",\"location\":\"")
        body.append_string(&profile.location)
        body.append_view("\",\"website\":\"")
        body.append_string(&profile.website)
        body.append_view("\",\"social_twitter\":\"")
        body.append_string(&profile.social_twitter)
        body.append_view("\",\"social_github\":\"")
        body.append_string(&profile.social_github)
        body.append_view("\",\"social_linkedin\":\"")
        body.append_string(&profile.social_linkedin)
        body.append_view("\",\"visibility\":\"")
        body.append_string(&profile.visibility)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

}
