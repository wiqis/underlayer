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

    // 8.1.13: GET /api/user/:username/stats — profile statistics
    public func handle_profile_stats(db : *DbClient, username : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        // Look up learner by username
        var profile = underlayer_repository::get_profile_by_username(db, username)
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

        // Get enrollments for this learner
        var enrollments = underlayer_repository::get_learner_enrollments(db, &profile.learner_id)

        // Aggregate overall stats
        var total_courses : int = enrollments.size() as int
        var courses_completed : int = 0
        var courses_active : int = 0
        var total_concepts_mastered : int = 0
        var total_concepts_started : int = 0
        var total_exercises_completed : i64 = 0
        var total_time_ms : i64 = 0

        // Per-course breakdown
        var course_json = string("[")
        var ei : size_t = 0
        while(ei < enrollments.size()) {
            var enrollment = enrollments.get_ptr(ei)

            if(enrollment.status.equals(string("completed"))) {
                courses_completed = courses_completed + 1
            } else {
                courses_active = courses_active + 1
            }

            // Get concept states for this course
            var states = underlayer_repository::get_all_concept_states(db, &profile.learner_id, &enrollment.course_id)
            var concepts_started : int = 0
            var concepts_mastered : int = 0
            var si : size_t = 0
            while(si < states.size()) {
                var state = states.get_ptr(si)
                if(state.attempts > 0) { concepts_started = concepts_started + 1 }
                if(state.status.equals(string("mastered"))) { concepts_mastered = concepts_mastered + 1 }
                si = si + 1
            }
            total_concepts_started = total_concepts_started + concepts_started
            total_concepts_mastered = total_concepts_mastered + concepts_mastered

            // Get session time for this course
            var sess_sql = string("SELECT COALESCE(SUM(si.time_spent_ms), 0) FROM session_items si JOIN sessions s ON si.session_id = s.id WHERE s.learner_id = '")
            sess_sql.append_string(&profile.learner_id)
            sess_sql.append_view("' AND si.concept_id IN (SELECT concept_id FROM concept_states WHERE learner_id = '")
            sess_sql.append_string(&profile.learner_id)
            sess_sql.append_view("' AND course_id = '")
            sess_sql.append_string(&enrollment.course_id)
            sess_sql.append_view("')")
            var sess_result = underlayer_db::query_sql(db, &raw sess_sql)
            var course_time_ms : i64 = 0
            if(sess_result.rows.size() > 0) {
                var srow = sess_result.rows.get_ptr(0)
                if(srow.vals.size() > 0) {
                    course_time_ms = underlayer_repository::parse_i64(srow.vals.get_ptr(0).to_view())
                }
            }
            total_time_ms = total_time_ms + course_time_ms

            // Count exercises for this course
            var ex_sql = string("SELECT COUNT(*) FROM session_items si JOIN sessions s ON si.session_id = s.id WHERE s.learner_id = '")
            ex_sql.append_string(&profile.learner_id)
            ex_sql.append_view("' AND si.concept_id IN (SELECT concept_id FROM concept_states WHERE learner_id = '")
            ex_sql.append_string(&profile.learner_id)
            ex_sql.append_view("' AND course_id = '")
            ex_sql.append_string(&enrollment.course_id)
            ex_sql.append_view("')")
            var ex_result = underlayer_db::query_sql(db, &raw ex_sql)
            var course_exercises : i64 = 0
            if(ex_result.rows.size() > 0) {
                var erow = ex_result.rows.get_ptr(0)
                if(erow.vals.size() > 0) {
                    course_exercises = underlayer_repository::parse_i64(erow.vals.get_ptr(0).to_view())
                }
            }
            total_exercises_completed = total_exercises_completed + course_exercises

            // Build per-course JSON
            if(ei > 0) { course_json.append_view(",") }
            course_json.append_view("{\"course_id\":\"")
            course_json.append_string(&enrollment.course_id)
            course_json.append_view("\",\"status\":\"")
            course_json.append_string(&enrollment.status)
            course_json.append_view("\",\"concepts_started\":")
            var cs_str = underlayer_core::int_to_string(concepts_started as i64)
            course_json.append_string(&cs_str)
            course_json.append_view(",\"concepts_mastered\":")
            var cm_str = underlayer_core::int_to_string(concepts_mastered as i64)
            course_json.append_string(&cm_str)
            course_json.append_view(",\"exercises_completed\":")
            var ec_str = underlayer_core::int_to_string(course_exercises)
            course_json.append_string(&ec_str)
            course_json.append_view(",\"time_spent_ms\":")
            var tm_str = underlayer_core::int_to_string(course_time_ms)
            course_json.append_string(&tm_str)
            course_json.append_view("}")

            ei = ei + 1
        }
        course_json.append_view("]")

        // Convert total_time_ms to seconds for the response
        var total_time_s = total_time_ms / 1000

        // Build overall stats JSON
        var body = std::string("{\"total_courses\":")
        var tc_str = underlayer_core::int_to_string(total_courses as i64)
        body.append_string(&tc_str)
        body.append_view(",\"courses_completed\":")
        var cc_str = underlayer_core::int_to_string(courses_completed as i64)
        body.append_string(&cc_str)
        body.append_view(",\"courses_active\":")
        var ca_str = underlayer_core::int_to_string(courses_active as i64)
        body.append_string(&ca_str)
        body.append_view(",\"total_concepts_mastered\":")
        var tcm_str = underlayer_core::int_to_string(total_concepts_mastered as i64)
        body.append_string(&tcm_str)
        body.append_view(",\"total_concepts_started\":")
        var tcs_str = underlayer_core::int_to_string(total_concepts_started as i64)
        body.append_string(&tcs_str)
        body.append_view(",\"total_exercises_completed\":")
        var tex_str = underlayer_core::int_to_string(total_exercises_completed)
        body.append_string(&tex_str)
        body.append_view(",\"total_time_seconds\":")
        var tts_str = underlayer_core::int_to_string(total_time_s)
        body.append_string(&tts_str)
        body.append_view(",\"courses\":")
        body.append_string(&course_json)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // 8.1.17: GET /api/user/:username/courses — courses in progress and completed
    public func handle_profile_courses(db : *DbClient, username : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var profile = underlayer_repository::get_profile_by_username(db, username)
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

        var enrollments = underlayer_repository::get_learner_enrollments(db, &profile.learner_id)
        var arr = string("[")
        var ei : size_t = 0
        while(ei < enrollments.size()) {
            var enrollment = enrollments.get_ptr(ei)

            // Get concept states for progress calculation
            var states = underlayer_repository::get_all_concept_states(db, &profile.learner_id, &enrollment.course_id)
            var concepts_started : int = 0
            var concepts_mastered : int = 0
            var total_concepts : int = states.size() as int
            var si : size_t = 0
            while(si < states.size()) {
                var state = states.get_ptr(si)
                if(state.attempts > 0) { concepts_started = concepts_started + 1 }
                if(state.status.equals(string("mastered"))) { concepts_mastered = concepts_mastered + 1 }
                si = si + 1
            }

            // Compute progress percentage
            var progress_pct : f64 = 0.0
            if(total_concepts > 0) {
                progress_pct = (concepts_mastered as f64) / (total_concepts as f64) * 100.0
            }

            // Format last_accessed timestamp
            var last_accessed_str = underlayer_core::int_to_string(enrollment.last_accessed)

            // Build JSON for this course
            if(ei > 0) { arr.append_view(",") }
            arr.append_view("{\"course_id\":\"")
            arr.append_string(&enrollment.course_id)
            arr.append_view("\",\"status\":\"")
            arr.append_string(&enrollment.status)
            arr.append_view("\",\"enrolled_at\":")
            var ea_str = underlayer_core::int_to_string(enrollment.enrolled_at)
            arr.append_string(&ea_str)
            arr.append_view(",\"last_accessed\":")
            arr.append_string(&last_accessed_str)
            arr.append_view(",\"completed_at\":")
            var ca_str = underlayer_core::int_to_string(enrollment.completed_at)
            arr.append_string(&ca_str)
            arr.append_view(",\"concepts_started\":")
            var cs_str = underlayer_core::int_to_string(concepts_started as i64)
            arr.append_string(&cs_str)
            arr.append_view(",\"concepts_mastered\":")
            var cm_str = underlayer_core::int_to_string(concepts_mastered as i64)
            arr.append_string(&cm_str)
            arr.append_view(",\"total_concepts\":")
            var tc_str = underlayer_core::int_to_string(total_concepts as i64)
            arr.append_string(&tc_str)
            arr.append_view(",\"progress_pct\":")
            var pp_str = underlayer_learning::f64_to_string(progress_pct)
            arr.append_string(&pp_str)
            arr.append_view("}")

            ei = ei + 1
        }
        arr.append_view("]")
        send_json_str(res, &raw arr)
    }

    // Routes:
    // GET /api/user/:username/stats → handle_profile_stats
    // GET /api/user/:username/courses → handle_profile_courses

}
