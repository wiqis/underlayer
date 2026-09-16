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
            if(!has_achievement(db, learner_id, &string("streak_3"))) {
                grant_achievement(db, learner_id, &string("streak_3"), &string("3-Day Streak"), &string("Studied for 3 consecutive days"), &string("flame"))
            }
        }
        if(streak_days >= 7) {
            if(!has_achievement(db, learner_id, &string("streak_7"))) {
                grant_achievement(db, learner_id, &string("streak_7"), &string("7-Day Streak"), &string("Studied for 7 consecutive days"), &string("fire"))
            }
        }
        if(streak_days >= 30) {
            if(!has_achievement(db, learner_id, &string("streak_30"))) {
                grant_achievement(db, learner_id, &string("streak_30"), &string("30-Day Streak"), &string("Studied for 30 consecutive days"), &string("trophy"))
            }
        }
        if(streak_days >= 100) {
            if(!has_achievement(db, learner_id, &string("streak_100"))) {
                grant_achievement(db, learner_id, &string("streak_100"), &string("100-Day Streak"), &string("Studied for 100 consecutive days"), &string("diamond"))
            }
        }
    }

    public func check_and_award_milestones(db : *DbClient, learner_id : &string, concepts_mastered : int, total_exercises : int) {
        if(total_exercises >= 1) {
            if(!has_achievement(db, learner_id, &string("first_lesson"))) {
                grant_achievement(db, learner_id, &string("first_lesson"), &string("First Steps"), &string("Completed your first exercise"), &string("seedling"))
            }
        }
        if(total_exercises >= 10) {
            if(!has_achievement(db, learner_id, &string("exercise_10"))) {
                grant_achievement(db, learner_id, &string("exercise_10"), &string("Getting Started"), &string("Completed 10 exercises"), &string("book"))
            }
        }
        if(total_exercises >= 100) {
            if(!has_achievement(db, learner_id, &string("exercise_100"))) {
                grant_achievement(db, learner_id, &string("exercise_100"), &string("Century Club"), &string("Completed 100 exercises"), &string("star"))
            }
        }
        if(concepts_mastered >= 5) {
            if(!has_achievement(db, learner_id, &string("master_5"))) {
                grant_achievement(db, learner_id, &string("master_5"), &string("Knowledge Seeker"), &string("Mastered 5 concepts"), &string("compass"))
            }
        }
        if(concepts_mastered >= 20) {
            if(!has_achievement(db, learner_id, &string("master_all"))) {
                grant_achievement(db, learner_id, &string("master_all"), &string("Master Scholar"), &string("Mastered all available concepts"), &string("crown"))
            }
        }
    }

}
