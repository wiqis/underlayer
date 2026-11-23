// underlayer_repository — Notification CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct Notification {
        var id : string
        var learner_id : string
        var type : string
        var title : string
        var message : string
        var course_id : string
        var concept_id : string
        var is_read : bool
        var action_url : string
        var created_at : i64

        @make
        func make() : Notification {
            return Notification {
                id = string(),
                learner_id = string(),
                type = string(),
                title = string(),
                message = string(),
                course_id = string(),
                concept_id = string(),
                is_read = false,
                action_url = string(),
                created_at = 0
            }
        }
    }

    private func generate_notification_id() : string {
        return random_hex_id()
    }

    public func create_notification(db : *DbClient, learner_id : &string, notif_type : &string, title : &string, message : &string, course_id : &string, concept_id : &string, action_url : &string) : string {
        var notif_id = generate_notification_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO notifications (id, learner_id, type, title, message, course_id, concept_id, is_read, action_url, created_at) VALUES ('")
        sql.append_string(&notif_id)
        sql.append_view("', '")
        sql.append_view(learner_id.to_view())
        sql.append_view("', '")
        sql.append_view(notif_type.to_view())
        sql.append_view("', '")
        sql.append_view(title.to_view())
        sql.append_view("', '")
        sql.append_view(message.to_view())
        sql.append_view("', '")
        sql.append_view(course_id.to_view())
        sql.append_view("', '")
        sql.append_view(concept_id.to_view())
        sql.append_view("', 0, '")
        sql.append_view(action_url.to_view())
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return notif_id
    }

    public func get_notifications(db : *DbClient, learner_id : &string, limit : int) : vector<Notification> {
        var notifications = vector<Notification>()
        var sql = string("SELECT id, learner_id, type, title, message, course_id, concept_id, is_read, action_url, created_at FROM notifications WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' ORDER BY created_at DESC LIMIT ")
        var limit_str = underlayer_core::int_to_string(limit)
        sql.append_view(limit_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.at_ref(ri)
            if(row.vals.size() >= 10) {
                var n = Notification::make()
                n.id = row.vals.at_ref(0).copy()
                n.learner_id = row.vals.at_ref(1).copy()
                n.type = row.vals.at_ref(2).copy()
                n.title = row.vals.at_ref(3).copy()
                n.message = row.vals.at_ref(4).copy()
                n.course_id = row.vals.at_ref(5).copy()
                n.concept_id = row.vals.at_ref(6).copy()
                n.is_read = parse_i64(row.vals.at_ref(7).to_view()) != 0
                n.action_url = row.vals.at_ref(8).copy()
                n.created_at = parse_i64(row.vals.at_ref(9).to_view())
                notifications.push(n)
            }
            ri = ri + 1
        }
        return notifications
    }

    public func get_unread_count(db : *DbClient, learner_id : &string) : int {
        var sql = string("SELECT COUNT(*) FROM notifications WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND is_read = 0")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.at_ref(0)
            if(row.vals.size() > 0) {
                return parse_int(row.vals.at_ref(0).to_view())
            }
        }
        return 0
    }

    public func mark_read(db : *DbClient, notification_id : &string) {
        var sql = string("UPDATE notifications SET is_read = 1 WHERE id = '")
        sql.append_view(notification_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func mark_all_read(db : *DbClient, learner_id : &string) {
        var sql = string("UPDATE notifications SET is_read = 1 WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND is_read = 0")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func delete_notification(db : *DbClient, notification_id : &string) {
        var sql = string("DELETE FROM notifications WHERE id = '")
        sql.append_view(notification_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func delete_old_notifications(db : *DbClient, learner_id : &string, older_than_days : int) {
        var now = underlayer_core::current_timestamp()
        var days_sec : i64 = (older_than_days as i64) * 86400
        var cutoff = now - days_sec
        var cutoff_str = underlayer_core::int_to_string(cutoff)
        var sql = string("DELETE FROM notifications WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND created_at < ")
        sql.append_view(cutoff_str.to_view())
        underlayer_db::exec_sql(db, &raw sql)
    }

}