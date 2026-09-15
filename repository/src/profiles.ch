// underlayer_repository — Profile CRUD (16.5).
using std::string
using underlayer_db::DbClient
using underlayer_models::LearnerProfile

public namespace underlayer_repository {

    public func get_profile(db : *DbClient, learner_id : &string) : LearnerProfile {
        var profile = LearnerProfile::make()
        var sql = string("SELECT display_name, username, avatar_url, bio, learning_goals, location, website, social_twitter, social_github, social_linkedin, visibility, username_changed_at FROM learner_profiles WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 12) {
                profile.learner_id = learner_id.copy()
                profile.display_name = row.vals.get_ptr(0).copy()
                profile.username = row.vals.get_ptr(1).copy()
                profile.avatar_url = row.vals.get_ptr(2).copy()
                profile.bio = row.vals.get_ptr(3).copy()
                profile.learning_goals = row.vals.get_ptr(4).copy()
                profile.location = row.vals.get_ptr(5).copy()
                profile.website = row.vals.get_ptr(6).copy()
                profile.social_twitter = row.vals.get_ptr(7).copy()
                profile.social_github = row.vals.get_ptr(8).copy()
                profile.social_linkedin = row.vals.get_ptr(9).copy()
                profile.visibility = row.vals.get_ptr(10).copy()
                profile.username_changed_at = parse_i64(row.vals.get_ptr(11).to_view())
            }
        }
        return profile
    }

    public func upsert_profile(db : *DbClient, profile : *LearnerProfile) {
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var sql = string("INSERT OR REPLACE INTO learner_profiles (learner_id, display_name, username, avatar_url, bio, learning_goals, location, website, social_twitter, social_github, social_linkedin, visibility, username_changed_at, updated_at) VALUES ('")
        sql.append_string(&profile.learner_id)
        sql.append_view("', '")
        sql.append_string(&profile.display_name)
        sql.append_view("', '")
        sql.append_string(&profile.username)
        sql.append_view("', '")
        sql.append_string(&profile.avatar_url)
        sql.append_view("', '")
        sql.append_string(&profile.bio)
        sql.append_view("', '")
        sql.append_string(&profile.learning_goals)
        sql.append_view("', '")
        sql.append_string(&profile.location)
        sql.append_view("', '")
        sql.append_string(&profile.website)
        sql.append_view("', '")
        sql.append_string(&profile.social_twitter)
        sql.append_view("', '")
        sql.append_string(&profile.social_github)
        sql.append_view("', '")
        sql.append_string(&profile.social_linkedin)
        sql.append_view("', '")
        sql.append_string(&profile.visibility)
        sql.append_view("', ")
        var uca_str = underlayer_core::int_to_string(profile.username_changed_at)
        sql.append_view(uca_str.to_view())
        sql.append_view(", ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func is_username_available(db : *DbClient, username : &string, exclude_learner_id : &string) : bool {
        var sql = string("SELECT COUNT(*) FROM learner_profiles WHERE username = '")
        sql.append_string(username)
        sql.append_view("' AND learner_id != '")
        sql.append_string(exclude_learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                var count = parse_i64(row.vals.get_ptr(0).to_view())
                return count == 0
            }
        }
        return true
    }

    public func get_profile_by_username(db : *DbClient, username : &string) : LearnerProfile {
        var profile = LearnerProfile::make()
        var sql = string("SELECT learner_id, display_name, avatar_url, bio, learning_goals, location, website, social_twitter, social_github, social_linkedin, visibility, username_changed_at FROM learner_profiles WHERE username = '")
        sql.append_string(username)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 12) {
                profile.learner_id = row.vals.get_ptr(0).copy()
                profile.display_name = row.vals.get_ptr(1).copy()
                profile.username = username.copy()
                profile.avatar_url = row.vals.get_ptr(2).copy()
                profile.bio = row.vals.get_ptr(3).copy()
                profile.learning_goals = row.vals.get_ptr(4).copy()
                profile.location = row.vals.get_ptr(5).copy()
                profile.website = row.vals.get_ptr(6).copy()
                profile.social_twitter = row.vals.get_ptr(7).copy()
                profile.social_github = row.vals.get_ptr(8).copy()
                profile.social_linkedin = row.vals.get_ptr(9).copy()
                profile.visibility = row.vals.get_ptr(10).copy()
                profile.username_changed_at = parse_i64(row.vals.get_ptr(11).to_view())
            }
        }
        return profile
    }

}
