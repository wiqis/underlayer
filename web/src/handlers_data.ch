// underlayer_web — Data management handlers (16.8: Data Management, 6.1.8, 6.1.12-6.1.13).
using std::string
using std::string_view
using underlayer_db::DbClient
using underlayer_repository::parse_i64

public namespace underlayer_web {

    // 16.8.1-16.8.5: GET /api/user/export — export all user data as JSON
    public func handle_export_data(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var learner = underlayer_repository::get_learner(db, &learner_id)
        var states = underlayer_repository::get_all_concept_states(db, &learner_id, &string("elf"))
        var sessions = underlayer_repository::get_learner_sessions(db, &learner_id, 1000)
        var body = string("{\"learner\":{\"id\":\"")
        body.append_string(&learner.id)
        body.append_view("\",\"name\":\"")
        var name_esc = underlayer_core::json_escape(&learner.name.to_view())
        body.append_string(&name_esc)
        body.append_view("\",\"email\":\"")
        var email_esc = underlayer_core::json_escape(&learner.email.to_view())
        body.append_string(&email_esc)
        body.append_view("\",\"created_at\":")
        var cat_str = underlayer_core::int_to_string(learner.created_at)
        body.append_string(&cat_str)
        body.append_view("},\"concept_states\":[")
        var ci : size_t = 0
        while(ci < states.size()) {
            if(ci > 0) { body.append_view(",") }
            var s = states.get_ptr(ci)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"course_id\":\"")
            body.append_string(&s.course_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var a_str = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&a_str)
            body.append_view(",\"correct\":")
            var c_str = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&c_str)
            body.append_view(",\"streak\":")
            var st_str = underlayer_core::int_to_string(s.streak as i64)
            body.append_string(&st_str)
            body.append_view("}")
            ci = ci + 1
        }
        body.append_view("],\"sessions\":[")
        var si : size_t = 0
        while(si < sessions.size()) {
            if(si > 0) { body.append_view(",") }
            var sess = sessions.get_ptr(si)
            body.append_view("{\"id\":\"")
            body.append_string(&sess.id)
            body.append_view("\",\"start_time\":")
            var st_str2 = underlayer_core::int_to_string(sess.start_time)
            body.append_string(&st_str2)
            body.append_view(",\"end_time\":")
            var et_str = underlayer_core::int_to_string(sess.end_time)
            body.append_string(&et_str)
            body.append_view(",\"type\":\"")
            body.append_string(&sess.session_type)
            body.append_view("\",\"exercises_attempted\":")
            var ea_str = underlayer_core::int_to_string(sess.exercises_attempted as i64)
            body.append_string(&ea_str)
            body.append_view(",\"exercises_correct\":")
            var ec_str = underlayer_core::int_to_string(sess.exercises_correct as i64)
            body.append_string(&ec_str)
            body.append_view("}")
            si = si + 1
        }
        body.append_view("],\"exported_at\":")
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        body.append_string(&now_str)
        body.append_view("}")
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
        res.set_header_view(std::string_view("Content-Disposition"), &std::string_view("attachment; filename=\"underlayer_export.json\""))
        var bv = body.to_view()
        res.write_view(&bv)
    }

    // 16.8.6-16.8.7: DELETE /api/user/data/:type — delete specific data type
    public func handle_delete_data(db : *DbClient, data_type : *string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var dt = data_type.copy()
        if(dt.equals(&string("reviews"))) {
            var sql = string("DELETE FROM review_items WHERE learner_id = '")
            sql.append_string(&learner_id)
            sql.append_view("'")
            underlayer_db::exec_sql(db, &raw sql)
        } else if(dt.equals(&string("progress"))) {
            var sql = string("DELETE FROM concept_states WHERE learner_id = '")
            sql.append_string(&learner_id)
            sql.append_view("'")
            underlayer_db::exec_sql(db, &raw sql)
        } else if(dt.equals(&string("analytics"))) {
            var sql = string("DELETE FROM sessions WHERE learner_id = '")
            sql.append_string(&learner_id)
            sql.append_view("'")
            underlayer_db::exec_sql(db, &raw sql)
            var sql2 = string("DELETE FROM session_items WHERE session_id IN (SELECT id FROM sessions WHERE learner_id = '")
            sql2.append_string(&learner_id)
            sql2.append_view("')")
            underlayer_db::exec_sql(db, &raw sql2)
        } else if(dt.equals(&string("all"))) {
            var sql = string("DELETE FROM concept_states WHERE learner_id = '")
            sql.append_string(&learner_id)
            sql.append_view("'")
            underlayer_db::exec_sql(db, &raw sql)
            var sql2 = string("DELETE FROM review_items WHERE learner_id = '")
            sql2.append_string(&learner_id)
            sql2.append_view("'")
            underlayer_db::exec_sql(db, &raw sql2)
            var sql3 = string("DELETE FROM sessions WHERE learner_id = '")
            sql3.append_string(&learner_id)
            sql3.append_view("'")
            underlayer_db::exec_sql(db, &raw sql3)
            var sql4 = string("DELETE FROM session_items WHERE session_id IN (SELECT id FROM sessions WHERE learner_id = '")
            sql4.append_string(&learner_id)
            sql4.append_view("')")
            underlayer_db::exec_sql(db, &raw sql4)
            var sql5 = string("DELETE FROM learning_goals WHERE learner_id = '")
            sql5.append_string(&learner_id)
            sql5.append_view("'")
            underlayer_db::exec_sql(db, &raw sql5)
        } else {
            send_error(res, 400u, &string("invalid data_type: use reviews, progress, analytics, or all"))
            return
        }
        var ok_body = string("{\"ok\":true,\"data_type\":\"")
        ok_body.append_string(&dt)
        ok_body.append_view("\"}")
        send_json_str(res, &raw ok_body)
    }

    // 16.8.8-16.8.10: DELETE /api/user/account — delete entire account
    public func handle_delete_account(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var del_sql = string("DELETE FROM concept_states WHERE learner_id = '")
        del_sql.append_string(&learner_id)
        del_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql)
        var del_sql2 = string("DELETE FROM review_items WHERE learner_id = '")
        del_sql2.append_string(&learner_id)
        del_sql2.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql2)
        var del_sql3 = string("DELETE FROM sessions WHERE learner_id = '")
        del_sql3.append_string(&learner_id)
        del_sql3.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql3)
        var del_sql4 = string("DELETE FROM session_items WHERE session_id IN (SELECT id FROM sessions WHERE learner_id = '")
        del_sql4.append_string(&learner_id)
        del_sql4.append_view("')")
        underlayer_db::exec_sql(db, &raw del_sql4)
        var del_sql5 = string("DELETE FROM learning_goals WHERE learner_id = '")
        del_sql5.append_string(&learner_id)
        del_sql5.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql5)
        var del_sql6 = string("DELETE FROM learner_profiles WHERE learner_id = '")
        del_sql6.append_string(&learner_id)
        del_sql6.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql6)
        var del_sql7 = string("DELETE FROM learner_settings WHERE learner_id = '")
        del_sql7.append_string(&learner_id)
        del_sql7.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql7)
        var del_sql8 = string("DELETE FROM learning_preferences WHERE learner_id = '")
        del_sql8.append_string(&learner_id)
        del_sql8.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql8)
        var del_sql9 = string("DELETE FROM login_history WHERE learner_id = '")
        del_sql9.append_string(&learner_id)
        del_sql9.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql9)
        var del_sql10 = string("DELETE FROM auth_sessions WHERE learner_id = '")
        del_sql10.append_string(&learner_id)
        del_sql10.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql10)
        var del_sql11 = string("DELETE FROM password_reset_tokens WHERE learner_id = '")
        del_sql11.append_string(&learner_id)
        del_sql11.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql11)
        var del_sql12 = string("DELETE FROM email_verification_tokens WHERE learner_id = '")
        del_sql12.append_string(&learner_id)
        del_sql12.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql12)
        var del_sql13 = string("DELETE FROM api_keys WHERE learner_id = '")
        del_sql13.append_string(&learner_id)
        del_sql13.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql13)
        var del_sql14 = string("DELETE FROM audit_log WHERE learner_id = '")
        del_sql14.append_string(&learner_id)
        del_sql14.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql14)
        var del_sql15 = string("DELETE FROM learners WHERE id = '")
        del_sql15.append_string(&learner_id)
        del_sql15.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql15)
        var ok_body = string("{\"ok\":true,\"message\":\"account deleted\"}")
        send_json_str(res, &raw ok_body)
    }

    // 16.8.12: POST /api/user/deactivate — deactivate account (temporary)
    public func handle_deactivate_account(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT OR REPLACE INTO learner_settings (learner_id, theme, font_size, language, timezone, date_format, email_notifications, push_notifications, in_app_notifications, compact_mode, created_at, updated_at) VALUES ('")
        sql.append_string(&learner_id)
        sql.append_view("', 'system', 'medium', 'en', 'UTC', 'YYYY-MM-DD', 0, 0, 0, 0, ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        var del_sql = string("DELETE FROM auth_sessions WHERE learner_id = '")
        del_sql.append_string(&learner_id)
        del_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql)
        var ok_body = string("{\"ok\":true,\"message\":\"account deactivated\"}")
        send_json_str(res, &raw ok_body)
    }

    // 16.8.13: POST /api/user/reactivate — reactivate account
    public func handle_reactivate_account(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT OR REPLACE INTO learner_settings (learner_id, theme, font_size, language, timezone, date_format, email_notifications, push_notifications, in_app_notifications, compact_mode, created_at, updated_at) VALUES ('")
        sql.append_string(&learner_id)
        sql.append_view("', 'system', 'medium', 'en', 'UTC', 'YYYY-MM-DD', 1, 1, 1, 0, ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        var ok_body = string("{\"ok\":true,\"message\":\"account reactivated\"}")
        send_json_str(res, &raw ok_body)
    }

    // 6.1.8: POST /api/progress/import — import progress from another account
    public func handle_import_progress(db : *DbClient, req : &mut http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var body_str = read_body(&raw mut req)
        if(body_str.size() == 0) {
            send_error(res, 400u, &string("missing request body"))
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            send_error(res, 400u, &string("invalid JSON"))
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var imported : int = 0
        var states_val = json_get(&raw parsed, "concept_states")
        if(states_val != null && states_val is JsonValue.Array) {
            var Array(states_arr) = *states_val else unreachable
            var i : size_t = 0
            while(i < states_arr.size()) {
                var item = states_arr.get_ptr(i)
                var concept_id = json_get_str(item, "concept_id")
                var course_id = json_get_str(item, "course_id")
                var status = json_get_str(item, "status")
                if(concept_id.size() > 0) {
                    var sql = string("INSERT OR REPLACE INTO concept_states (learner_id, concept_id, course_id, status, attempts, correct, streak, last_studied, next_review, difficulty_rating) VALUES ('")
                    sql.append_string(&learner_id)
                    sql.append_view("', '")
                    sql.append_string(&concept_id)
                    sql.append_view("', '")
                    sql.append_string(&course_id)
                    sql.append_view("', '")
                    sql.append_string(&status)
                    sql.append_view("', ")
                    var attempts_str = underlayer_core::int_to_string(json_get_int(item, "attempts") as i64)
                    sql.append_view(attempts_str.to_view())
                    sql.append_view(", ")
                    var correct_str = underlayer_core::int_to_string(json_get_int(item, "correct") as i64)
                    sql.append_view(correct_str.to_view())
                    sql.append_view(", ")
                    var streak_str = underlayer_core::int_to_string(json_get_int(item, "streak") as i64)
                    sql.append_view(streak_str.to_view())
                    sql.append_view(", 0, 0, 0.0)")
                    underlayer_db::exec_sql(db, &raw sql)
                    imported = imported + 1
                }
                i = i + 1
            }
        }
        var reviews_val = json_get(&raw parsed, "review_items")
        if(reviews_val != null && reviews_val is JsonValue.Array) {
            var Array(reviews_arr) = *reviews_val else unreachable
            var j : size_t = 0
            while(j < reviews_arr.size()) {
                var item = reviews_arr.get_ptr(j)
                var concept_id = json_get_str(item, "concept_id")
                var course_id = json_get_str(item, "course_id")
                var item_type = json_get_str(item, "type")
                if(concept_id.size() > 0) {
                    var id_str = underlayer_core::int_to_string(underlayer_core::current_timestamp())
                    var sql = string("INSERT OR IGNORE INTO review_items (id, learner_id, concept_id, course_id, type, front, back, difficulty, stability, retrievability, next_review, last_review, reps, lapses, ease_factor) VALUES ('")
                    sql.append_string(&id_str)
                    sql.append_view("', '")
                    sql.append_string(&learner_id)
                    sql.append_view("', '")
                    sql.append_string(&concept_id)
                    sql.append_view("', '")
                    sql.append_string(&course_id)
                    sql.append_view("', '")
                    sql.append_string(&item_type)
                    sql.append_view("', '', '', 5.0, 1.0, 1.0, 0, 0, 0, 0, 2.5)")
                    underlayer_db::exec_sql(db, &raw sql)
                    imported = imported + 1
                }
                j = j + 1
            }
        }
        var ok_body = string("{\"ok\":true,\"imported\":")
        var imp_str = underlayer_core::int_to_string(imported as i64)
        ok_body.append_string(&imp_str)
        ok_body.append_view("}")
        send_json_str(res, &raw ok_body)
    }

    // 6.1.6: POST /api/progress/share — create public sharing token
    public func handle_share_progress(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var token = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var body = string("{\"share_url\":\"/u/demo/progress/")
        body.append_view(token.to_view())
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    // GET /api/progress/shared/:token — get shared progress
    public func handle_get_shared_progress(db : *DbClient, token : *string_view, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var states = underlayer_repository::get_all_concept_states(db, &learner_id, &string("elf"))
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var body = string("{\"health_score\":")
        var hs_str = underlayer_learning::f64_to_string(health.health_score)
        body.append_string(&hs_str)
        body.append_view(",\"mastered\":")
        var m_str = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&m_str)
        body.append_view(",\"total_concepts\":")
        var tc_str = underlayer_core::int_to_string(health.total_concepts as i64)
        body.append_string(&tc_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
