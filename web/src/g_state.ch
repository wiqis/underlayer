// underlayer_web — G1/G2/G4 learner state storage.
//
// WHY THIS FILE EXISTS.  G1 needs five new learner fields, G4 needs an energy
// check-in per review session, and the strict work-package boundary does not
// allow the repository/schema files to be edited.  These two tables are
// therefore created here, at startup, with `CREATE TABLE IF NOT EXISTS` --
// additive and idempotent, with no ALTER of an existing table (the migration
// pattern in repository/src/schema_migrations.ch is left alone).
//
// Every value that reaches SQL is escaped with the repository's own escaper;
// enum fields are additionally whitelisted by the handlers before they land
// here.  No markup is built in this file.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func init_g_tables(db : *DbClient) {
        var onboarding = string("CREATE TABLE IF NOT EXISTS onboarding_state (learner_id TEXT PRIMARY KEY, goal TEXT DEFAULT '', prior_knowledge TEXT DEFAULT '', session_minutes INTEGER DEFAULT 10, placement_score INTEGER DEFAULT -1, starting_concept TEXT DEFAULT 'bytes', onboarding_complete INTEGER DEFAULT 0, updated_at INTEGER)")
        underlayer_db::exec_sql(db, &raw onboarding)
        var energy = string("CREATE TABLE IF NOT EXISTS review_energy (session_id TEXT PRIMARY KEY, learner_id TEXT NOT NULL, energy_before TEXT DEFAULT 'okay', energy_after TEXT DEFAULT '', duration_minutes INTEGER DEFAULT 10, started_at INTEGER)")
        underlayer_db::exec_sql(db, &raw energy)
    }

    // A guest is a real, scoped identity: the browser sends a random id that is
    // checked here before use.  Without a session there is no signup wall, but
    // guests must not all write to one shared row (the old "demo" pattern).
    public func clean_guest_id(candidate : &string) : string {
        if(candidate.size() == 0 || candidate.size() > 64) { return string() }
        var i : size_t = 0
        while(i < candidate.size()) {
            var c = candidate.at(i)
            var ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_'
            if(!ok) { return string() }
            i = i + 1
        }
        return candidate.copy()
    }

    // Signed-in learners keep their identity; guests get a scoped, validated
    // id from localStorage. This is the "no signup wall" contract for G1/G2.
    public func resolve_learner(db : *DbClient, req : &http::Request, body_str : &string) : string {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() > 0) { return learner_id }
        var guest = string()
        if(body_str.size() > 0) {
            var pr = json::parse(body_str.to_view())
            if(pr is std::Result.Ok) {
                var Ok(pj) = pr else unsafe { unreachable }
                guest = clean_guest_id(&json_get_str(&pj, "guest_id"))
            }
        }
        if(guest.size() == 0) { return string() }
        var out = string("guest_")
        out.append_string(&guest)
        return out
    }

    public func save_onboarding_state(db : *DbClient, learner_id : &string, goal : &string, prior : &string, minutes : i64, score : i64, start_concept : &string, complete : bool) {
        var lid = underlayer_repository::sql_escape(learner_id)
        var g = underlayer_repository::sql_escape(goal)
        var p = underlayer_repository::sql_escape(prior)
        var sc = underlayer_repository::sql_escape(start_concept)
        var now = underlayer_core::current_timestamp()
        var now_s = underlayer_core::int_to_string(now)
        var min_s = underlayer_core::int_to_string(minutes)
        var score_s = underlayer_core::int_to_string(score)
        var done : i64 = 0
        if(complete) { done = 1 }
        var done_s = underlayer_core::int_to_string(done)
        var sql = string("INSERT OR REPLACE INTO onboarding_state (learner_id, goal, prior_knowledge, session_minutes, placement_score, starting_concept, onboarding_complete, updated_at) VALUES ('")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&g)
        sql.append_view("', '")
        sql.append_string(&p)
        sql.append_view("', ")
        sql.append_view(min_s.to_view())
        sql.append_view(", ")
        sql.append_view(score_s.to_view())
        sql.append_view(", '")
        sql.append_string(&sc)
        sql.append_view("', ")
        sql.append_view(done_s.to_view())
        sql.append_view(", ")
        sql.append_view(now_s.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        // /api/goals was empty in production: the daily goal is the one input
        // the day planner needs, so mirror it into learning_preferences too.
        // INSERT ... ON CONFLICT keeps a row registration already created.
        var pref = string("INSERT INTO learning_preferences (learner_id, daily_goal_minutes, session_length_minutes, created_at, updated_at) VALUES ('")
        pref.append_string(&lid)
        pref.append_view("', ")
        pref.append_view(min_s.to_view())
        pref.append_view(", ")
        pref.append_view(min_s.to_view())
        pref.append_view(", ")
        pref.append_view(now_s.to_view())
        pref.append_view(", ")
        pref.append_view(now_s.to_view())
        pref.append_view(") ON CONFLICT(learner_id) DO UPDATE SET daily_goal_minutes = excluded.daily_goal_minutes, session_length_minutes = excluded.session_length_minutes, updated_at = excluded.updated_at")
        underlayer_db::exec_sql(db, &raw pref)
    }

    // Safe JSON projection of the row; empty goal means "not onboarded".
    public func onboarding_state_json(db : *DbClient, learner_id : &string) : string {
        var lid = underlayer_repository::sql_escape(learner_id)
        var sql = string("SELECT goal, prior_knowledge, session_minutes, placement_score, starting_concept, onboarding_complete FROM onboarding_state WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        var out = string("{\"goal\":\"\",\"prior_knowledge\":\"\",\"session_minutes\":10,\"placement_score\":-1,\"starting_concept\":\"bytes\",\"onboarding_complete\":false}")
        if(result.rows.size() > 0) {
            var row = result.rows.at_ref(0)
            if(row.vals.size() >= 6) {
                var gv = row.vals.at_ref(0).to_view()
                var pv = row.vals.at_ref(1).to_view()
                var sv = row.vals.at_ref(4).to_view()
                var body = string("{\"goal\":\"")
                var g = underlayer_core::json_escape(&gv)
                body.append_string(&g)
                body.append_view("\",\"prior_knowledge\":\"")
                var p = underlayer_core::json_escape(&pv)
                body.append_string(&p)
                body.append_view("\",\"session_minutes\":")
                var mins_s = underlayer_core::int_to_string(underlayer_repository::parse_i64(row.vals.at_ref(2).to_view()))
                body.append_view(mins_s.to_view())
                body.append_view(",\"placement_score\":")
                var score_s = underlayer_core::int_to_string(underlayer_repository::parse_i64(row.vals.at_ref(3).to_view()))
                body.append_view(score_s.to_view())
                body.append_view(",\"starting_concept\":\"")
                var s = underlayer_core::json_escape(&sv)
                body.append_string(&s)
                body.append_view("\",\"onboarding_complete\":")
                if(underlayer_repository::parse_i64(row.vals.at_ref(5).to_view()) != 0) { body.append_view("true") } else { body.append_view("false") }
                body.append_view("}")
                out = body
            }
        }
        return out
    }

    public func daily_goal_minutes(db : *DbClient, learner_id : &string) : i64 {
        var lid = underlayer_repository::sql_escape(learner_id)
        var sql = string("SELECT session_minutes FROM onboarding_state WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0 && result.rows.at_ref(0).vals.size() > 0) {
            var mv = result.rows.at_ref(0).vals.at_ref(0).to_view()
            return underlayer_repository::parse_i64(mv)
        }
        return 15
    }

    // Account deletion must clear the G-work-package tables too. The repository
    // deletion function owns a fixed table list and cannot be edited under this
    // work package's file boundary, so the two handlers call this alongside it.
    public func delete_g_state_for_learner(db : *DbClient, learner_id : &string) {
        var lid = underlayer_repository::sql_escape(learner_id)
        var a = string("DELETE FROM onboarding_state WHERE learner_id = '")
        a.append_string(&lid)
        a.append_view("'")
        underlayer_db::exec_sql(db, &raw a)
        var b = string("DELETE FROM review_energy WHERE learner_id = '")
        b.append_string(&lid)
        b.append_view("'")
        underlayer_db::exec_sql(db, &raw b)
    }

    public func save_review_energy_start(db : *DbClient, session_id : &string, learner_id : &string, energy : &string, minutes : i64) {
        var sid = underlayer_repository::sql_escape(session_id)
        var lid = underlayer_repository::sql_escape(learner_id)
        var e = underlayer_repository::sql_escape(energy)
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var dur = underlayer_core::int_to_string(minutes)
        var sql = string("INSERT OR REPLACE INTO review_energy (session_id, learner_id, energy_before, energy_after, duration_minutes, started_at) VALUES ('")
        sql.append_string(&sid)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&e)
        sql.append_view("', '', ")
        sql.append_view(dur.to_view())
        sql.append_view(", ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func save_review_energy_after(db : *DbClient, session_id : &string, energy : &string) : bool {
        var sid = underlayer_repository::sql_escape(session_id)
        var e = underlayer_repository::sql_escape(energy)
        var sql = string("UPDATE review_energy SET energy_after = '")
        sql.append_string(&e)
        sql.append_view("' WHERE session_id = '")
        sql.append_string(&sid)
        sql.append_view("'")
        var result = underlayer_db::exec_sql(db, &raw sql)
        return result.ok
    }

}
