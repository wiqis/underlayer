// underlayer_repository — Settings CRUD (16.6-16.7).
using std::string
using underlayer_db::DbClient
using underlayer_models::LearnerSettings
using underlayer_models::LearningPreferences

public namespace underlayer_repository {

    public func get_settings(db : *DbClient, learner_id : &string) : LearnerSettings {
        var settings = LearnerSettings::make()
        var sql = string("SELECT theme, font_size, language, timezone, date_format, email_notifications, push_notifications, in_app_notifications, compact_mode FROM learner_settings WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 9) {
                settings.learner_id = learner_id.copy()
                settings.theme = row.vals.get_ptr(0).copy()
                settings.font_size = row.vals.get_ptr(1).copy()
                settings.language = row.vals.get_ptr(2).copy()
                settings.timezone = row.vals.get_ptr(3).copy()
                settings.date_format = row.vals.get_ptr(4).copy()
                settings.email_notifications = parse_i64(row.vals.get_ptr(5).to_view()) != 0
                settings.push_notifications = parse_i64(row.vals.get_ptr(6).to_view()) != 0
                settings.in_app_notifications = parse_i64(row.vals.get_ptr(7).to_view()) != 0
                settings.compact_mode = parse_i64(row.vals.get_ptr(8).to_view()) != 0
            }
        }
        return settings
    }

    private func bool_to_int(v : bool) : i64 {
        if(v) { return 1 } else { return 0 }
    }

    public func upsert_settings(db : *DbClient, settings : *LearnerSettings) {
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var sql = string("INSERT OR REPLACE INTO learner_settings (learner_id, theme, font_size, language, timezone, date_format, email_notifications, push_notifications, in_app_notifications, compact_mode, updated_at) VALUES ('")
        sql.append_string(&settings.learner_id)
        sql.append_view("', '")
        sql.append_string(&settings.theme)
        sql.append_view("', '")
        sql.append_string(&settings.font_size)
        sql.append_view("', '")
        sql.append_string(&settings.language)
        sql.append_view("', '")
        sql.append_string(&settings.timezone)
        sql.append_view("', '")
        sql.append_string(&settings.date_format)
        sql.append_view("', ")
        var en_i = bool_to_int(settings.email_notifications)
        var en_s = underlayer_core::int_to_string(en_i)
        sql.append_view(en_s.to_view())
        sql.append_view(", ")
        var pn_i = bool_to_int(settings.push_notifications)
        var pn_s = underlayer_core::int_to_string(pn_i)
        sql.append_view(pn_s.to_view())
        sql.append_view(", ")
        var ia_i = bool_to_int(settings.in_app_notifications)
        var ia_s = underlayer_core::int_to_string(ia_i)
        sql.append_view(ia_s.to_view())
        sql.append_view(", ")
        var cm_i = bool_to_int(settings.compact_mode)
        var cm_s = underlayer_core::int_to_string(cm_i)
        sql.append_view(cm_s.to_view())
        sql.append_view(", ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_learning_preferences(db : *DbClient, learner_id : &string) : LearningPreferences {
        var prefs = LearningPreferences::make()
        var sql = string("SELECT daily_goal_minutes, daily_review_items, session_length_minutes, break_reminder_minutes, preferred_session_time, energy_checkin, difficulty_preference, interleaving_preference, review_scheduling, show_streaks, show_leaderboards, show_achievements, auto_play_audio FROM learning_preferences WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 13) {
                prefs.learner_id = learner_id.copy()
                prefs.daily_goal_minutes = parse_i64(row.vals.get_ptr(0).to_view()) as int
                prefs.daily_review_items = parse_i64(row.vals.get_ptr(1).to_view()) as int
                prefs.session_length_minutes = parse_i64(row.vals.get_ptr(2).to_view()) as int
                prefs.break_reminder_minutes = parse_i64(row.vals.get_ptr(3).to_view()) as int
                prefs.preferred_session_time = row.vals.get_ptr(4).copy()
                prefs.energy_checkin = parse_i64(row.vals.get_ptr(5).to_view()) != 0
                prefs.difficulty_preference = row.vals.get_ptr(6).copy()
                prefs.interleaving_preference = row.vals.get_ptr(7).copy()
                prefs.review_scheduling = row.vals.get_ptr(8).copy()
                prefs.show_streaks = parse_i64(row.vals.get_ptr(9).to_view()) != 0
                prefs.show_leaderboards = parse_i64(row.vals.get_ptr(10).to_view()) != 0
                prefs.show_achievements = parse_i64(row.vals.get_ptr(11).to_view()) != 0
                prefs.auto_play_audio = parse_i64(row.vals.get_ptr(12).to_view()) != 0
            }
        }
        return prefs
    }

    public func upsert_learning_preferences(db : *DbClient, prefs : *LearningPreferences) {
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var sql = string("INSERT OR REPLACE INTO learning_preferences (learner_id, daily_goal_minutes, daily_review_items, session_length_minutes, break_reminder_minutes, preferred_session_time, energy_checkin, difficulty_preference, interleaving_preference, review_scheduling, show_streaks, show_leaderboards, show_achievements, auto_play_audio, updated_at) VALUES ('")
        sql.append_string(&prefs.learner_id)
        sql.append_view("', ")
        var dgm = underlayer_core::int_to_string(prefs.daily_goal_minutes as i64)
        sql.append_view(dgm.to_view())
        sql.append_view(", ")
        var dri = underlayer_core::int_to_string(prefs.daily_review_items as i64)
        sql.append_view(dri.to_view())
        sql.append_view(", ")
        var slm = underlayer_core::int_to_string(prefs.session_length_minutes as i64)
        sql.append_view(slm.to_view())
        sql.append_view(", ")
        var brm = underlayer_core::int_to_string(prefs.break_reminder_minutes as i64)
        sql.append_view(brm.to_view())
        sql.append_view(", '")
        sql.append_string(&prefs.preferred_session_time)
        sql.append_view("', ")
        var ec_i = bool_to_int(prefs.energy_checkin)
        var ec_s = underlayer_core::int_to_string(ec_i)
        sql.append_view(ec_s.to_view())
        sql.append_view(", '")
        sql.append_string(&prefs.difficulty_preference)
        sql.append_view("', '")
        sql.append_string(&prefs.interleaving_preference)
        sql.append_view("', '")
        sql.append_string(&prefs.review_scheduling)
        sql.append_view("', ")
        var ss_i = bool_to_int(prefs.show_streaks)
        var ss_s = underlayer_core::int_to_string(ss_i)
        sql.append_view(ss_s.to_view())
        sql.append_view(", ")
        var sl_i = bool_to_int(prefs.show_leaderboards)
        var sl_s = underlayer_core::int_to_string(sl_i)
        sql.append_view(sl_s.to_view())
        sql.append_view(", ")
        var sa_i = bool_to_int(prefs.show_achievements)
        var sa_s = underlayer_core::int_to_string(sa_i)
        sql.append_view(sa_s.to_view())
        sql.append_view(", ")
        var apa_i = bool_to_int(prefs.auto_play_audio)
        var apa_s = underlayer_core::int_to_string(apa_i)
        sql.append_view(apa_s.to_view())
        sql.append_view(", ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
