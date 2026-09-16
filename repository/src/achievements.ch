// underlayer_repository — Achievements/Badges CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct Achievement {
        var id : string
        var learner_id : string
        var badge_type : string
        var badge_name : string
        var description : string
        var icon : string
        var earned_at : i64

        @make
        func make() : Achievement {
            return Achievement {
                id = string(),
                learner_id = string(),
                badge_type = string(),
                badge_name = string(),
                description = string(),
                icon = string(),
                earned_at = 0
            }
        }
    }

    private func generate_achievement_id() : string {
        var buf : [16]u8
        osrand::random_fill(&raw mut buf[0], 16)
        var hex_out : [33]char
        var i0 : size_t = 0
        while(i0 < 33) { hex_out[i0] = 0; i0 = i0 + 1 }
        encoding::hex_encode(&raw buf[0], 16, &raw mut hex_out[0], 33)
        var result = string()
        var i : size_t = 0
        while(i < 32 && hex_out[i] != 0) { result.append(hex_out[i]); i = i + 1 }
        return result
    }

    public func grant_achievement(db : *DbClient, learner_id : &string, badge_type : &string, badge_name : &string, description : &string, icon : &string) : string {
        var ach_id = generate_achievement_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO achievements (id, learner_id, badge_type, badge_name, description, icon, earned_at) VALUES ('")
        sql.append_string(&ach_id)
        sql.append_view("', '")
        sql.append_view(learner_id.to_view())
        sql.append_view("', '")
        sql.append_view(badge_type.to_view())
        sql.append_view("', '")
        sql.append_view(badge_name.to_view())
        sql.append_view("', '")
        sql.append_view(description.to_view())
        sql.append_view("', '")
        sql.append_view(icon.to_view())
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        var ntype = string("achievement")
        var ntitle = string("Achievement Unlocked")
        var nmsg = badge_name.copy()
        var ncourse = string("")
        var nconcept = string("")
        var nurl = string("/achievements")
        create_notification(db, learner_id, &ntype, &ntitle, &nmsg, &ncourse, &nconcept, &nurl)
        return ach_id
    }

    public func get_achievements(db : *DbClient, learner_id : &string) : vector<Achievement> {
        var achievements = vector<Achievement>()
        var sql = string("SELECT id, learner_id, badge_type, badge_name, description, icon, earned_at FROM achievements WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' ORDER BY earned_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 7) {
                var a = Achievement::make()
                a.id = row.vals.get_ptr(0).copy()
                a.learner_id = row.vals.get_ptr(1).copy()
                a.badge_type = row.vals.get_ptr(2).copy()
                a.badge_name = row.vals.get_ptr(3).copy()
                a.description = row.vals.get_ptr(4).copy()
                a.icon = row.vals.get_ptr(5).copy()
                a.earned_at = parse_i64(row.vals.get_ptr(6).to_view())
                achievements.push(a)
            }
            ri = ri + 1
        }
        return achievements
    }

    public func has_achievement(db : *DbClient, learner_id : &string, badge_type : &string) : bool {
        var sql = string("SELECT COUNT(*) FROM achievements WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND badge_type = '")
        sql.append_view(badge_type.to_view())
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                return parse_int(row.vals.get_ptr(0).to_view()) > 0
            }
        }
        return false
    }

    public func get_achievement_count(db : *DbClient, learner_id : &string) : int {
        var sql = string("SELECT COUNT(*) FROM achievements WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                return parse_int(row.vals.get_ptr(0).to_view())
            }
        }
        return 0
    }

    public func check_and_award_streak(db : *DbClient, learner_id : &string, streak_days : int) {
        if(streak_days >= 3) {
            var t3 = string("streak_3")
            if(!has_achievement(db, learner_id, &t3)) {
                var n = string("3-Day Streak")
                var d = string("Studied for 3 consecutive days")
                var ic = string("flame")
                grant_achievement(db, learner_id, &t3, &n, &d, &ic)
            }
        }
        if(streak_days >= 7) {
            var t7 = string("streak_7")
            if(!has_achievement(db, learner_id, &t7)) {
                var n = string("7-Day Streak")
                var d = string("Studied for 7 consecutive days")
                var ic = string("fire")
                grant_achievement(db, learner_id, &t7, &n, &d, &ic)
            }
        }
        if(streak_days >= 30) {
            var t30 = string("streak_30")
            if(!has_achievement(db, learner_id, &t30)) {
                var n = string("30-Day Streak")
                var d = string("Studied for 30 consecutive days")
                var ic = string("trophy")
                grant_achievement(db, learner_id, &t30, &n, &d, &ic)
            }
        }
        if(streak_days >= 100) {
            var t100 = string("streak_100")
            if(!has_achievement(db, learner_id, &t100)) {
                var n = string("100-Day Streak")
                var d = string("Studied for 100 consecutive days")
                var ic = string("diamond")
                grant_achievement(db, learner_id, &t100, &n, &d, &ic)
            }
        }
    }

    public func check_and_award_milestones(db : *DbClient, learner_id : &string, concepts_mastered : int, total_exercises : int) {
        if(total_exercises >= 1) {
            var t1 = string("first_lesson")
            if(!has_achievement(db, learner_id, &t1)) {
                var n = string("First Steps")
                var d = string("Completed your first exercise")
                var ic = string("seedling")
                grant_achievement(db, learner_id, &t1, &n, &d, &ic)
            }
        }
        if(total_exercises >= 10) {
            var t10 = string("exercise_10")
            if(!has_achievement(db, learner_id, &t10)) {
                var n = string("Getting Started")
                var d = string("Completed 10 exercises")
                var ic = string("book")
                grant_achievement(db, learner_id, &t10, &n, &d, &ic)
            }
        }
        if(total_exercises >= 100) {
            var t100 = string("exercise_100")
            if(!has_achievement(db, learner_id, &t100)) {
                var n = string("Century Club")
                var d = string("Completed 100 exercises")
                var ic = string("star")
                grant_achievement(db, learner_id, &t100, &n, &d, &ic)
            }
        }
        if(concepts_mastered >= 5) {
            var t5 = string("master_5")
            if(!has_achievement(db, learner_id, &t5)) {
                var n = string("Knowledge Seeker")
                var d = string("Mastered 5 concepts")
                var ic = string("compass")
                grant_achievement(db, learner_id, &t5, &n, &d, &ic)
            }
        }
        if(concepts_mastered >= 20) {
            var ta = string("master_all")
            if(!has_achievement(db, learner_id, &ta)) {
                var n = string("Master Scholar")
                var d = string("Mastered all available concepts")
                var ic = string("crown")
                grant_achievement(db, learner_id, &ta, &n, &d, &ic)
            }
        }
    }

    // Evaluate all achievement rules for a learner. Call after learning activity.
    public func run_achievement_checks(db : *DbClient, learner_id : &string) {
        var streak = get_streak(db, learner_id)
        check_and_award_streak(db, learner_id, streak.current_streak)
        var mastered = count_mastered_concepts(db, learner_id)
        var attempts = count_total_attempts(db, learner_id)
        check_and_award_milestones(db, learner_id, mastered, attempts)
    }

}
