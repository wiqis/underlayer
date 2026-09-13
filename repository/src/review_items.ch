// underlayer_repository — Review item CRUD.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::ReviewItem

public namespace underlayer_repository {

    public func get_due_review_items(db : *DbClient, learner_id : &string, course_id : &string, limit : int) : vector<ReviewItem> {
        var items = vector<ReviewItem>()
        var now = underlayer_core::current_timestamp()
        var sql = string("SELECT id, concept_id, type, front, back, difficulty, stability, retrievability, next_review, reps, lapses, ease_factor FROM review_items WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' AND next_review <= ")
        var now_str = underlayer_core::int_to_string(now)
        sql.append_view(now_str.to_view())
        sql.append_view(" ORDER BY next_review ASC LIMIT ")
        var lim_str = underlayer_core::int_to_string(limit as i64)
        sql.append_view(lim_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 11) {
                var item = ReviewItem::make()
                item.id = row.vals.get_ptr(0).copy()
                item.learner_id = learner_id.copy()
                item.concept_id = row.vals.get_ptr(1).copy()
                item.course_id = course_id.copy()
                item.item_type = row.vals.get_ptr(2).copy()
                item.front = row.vals.get_ptr(3).copy()
                item.back = row.vals.get_ptr(4).copy()
                item.difficulty = parse_i64(row.vals.get_ptr(5).to_view()) as f64
                item.stability = parse_i64(row.vals.get_ptr(6).to_view()) as f64
                item.retrievability = parse_i64(row.vals.get_ptr(7).to_view()) as f64
                item.next_review = parse_i64(row.vals.get_ptr(8).to_view())
                item.reps = parse_i64(row.vals.get_ptr(9).to_view()) as int
                item.lapses = parse_i64(row.vals.get_ptr(10).to_view()) as int
                // 1.1.15: read ease_factor (column 11, may not exist in old DBs)
                if(row.vals.size() >= 12) {
                    item.ease_factor = parse_i64(row.vals.get_ptr(11).to_view()) as f64
                }
                items.push(item)
            }
            ri = ri + 1
        }
        return items
    }

    // 5.1.3: Get all review items (for cramming mode, ignore next_review)
    public func get_all_review_items(db : *DbClient, learner_id : &string, course_id : &string, limit : int) : vector<ReviewItem> {
        var items = vector<ReviewItem>()
        var sql = string("SELECT id, concept_id, type, front, back, difficulty, stability, retrievability, next_review, reps, lapses, ease_factor FROM review_items WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' ORDER BY next_review ASC LIMIT ")
        var lim_str = underlayer_core::int_to_string(limit as i64)
        sql.append_view(lim_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 11) {
                var item = ReviewItem::make()
                item.id = row.vals.get_ptr(0).copy()
                item.learner_id = learner_id.copy()
                item.concept_id = row.vals.get_ptr(1).copy()
                item.course_id = course_id.copy()
                item.item_type = row.vals.get_ptr(2).copy()
                item.front = row.vals.get_ptr(3).copy()
                item.back = row.vals.get_ptr(4).copy()
                item.difficulty = parse_i64(row.vals.get_ptr(5).to_view()) as f64
                item.stability = parse_i64(row.vals.get_ptr(6).to_view()) as f64
                item.retrievability = parse_i64(row.vals.get_ptr(7).to_view()) as f64
                item.next_review = parse_i64(row.vals.get_ptr(8).to_view())
                item.reps = parse_i64(row.vals.get_ptr(9).to_view()) as int
                item.lapses = parse_i64(row.vals.get_ptr(10).to_view()) as int
                if(row.vals.size() >= 12) {
                    item.ease_factor = parse_i64(row.vals.get_ptr(11).to_view()) as f64
                }
                items.push(item)
            }
            ri = ri + 1
        }
        return items
    }

    public func update_review_item(db : *DbClient, item : *ReviewItem) {
        var sql = string("UPDATE review_items SET difficulty = ")
        var diff_str = underlayer_core::int_to_string(item.difficulty as i64)
        sql.append_view(diff_str.to_view())
        sql.append_view(", stability = ")
        var stab_str = underlayer_core::int_to_string(item.stability as i64)
        sql.append_view(stab_str.to_view())
        sql.append_view(", retrievability = ")
        var ret_str = underlayer_core::int_to_string(item.retrievability as i64)
        sql.append_view(ret_str.to_view())
        sql.append_view(", next_review = ")
        var nr_str = underlayer_core::int_to_string(item.next_review)
        sql.append_view(nr_str.to_view())
        sql.append_view(", last_review = ")
        var lr_str = underlayer_core::int_to_string(item.last_review)
        sql.append_view(lr_str.to_view())
        sql.append_view(", reps = ")
        var reps_str = underlayer_core::int_to_string(item.reps as i64)
        sql.append_view(reps_str.to_view())
        sql.append_view(", lapses = ")
        var lapses_str = underlayer_core::int_to_string(item.lapses as i64)
        sql.append_view(lapses_str.to_view())
        // 1.1.15: persist ease_factor
        sql.append_view(", ease_factor = ")
        var ef_str = underlayer_core::int_to_string(item.ease_factor as i64)
        sql.append_view(ef_str.to_view())
        sql.append_view(".0")
        sql.append_view(" WHERE id = '")
        sql.append_string(&item.id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func insert_review_item(db : *DbClient, item : *ReviewItem) {
        var sql = string("INSERT OR IGNORE INTO review_items (id, learner_id, concept_id, course_id, type, front, back, difficulty, stability, retrievability, next_review, last_review, reps, lapses, ease_factor) VALUES ('")
        sql.append_string(&item.id)
        sql.append_view("', '")
        sql.append_string(&item.learner_id)
        sql.append_view("', '")
        sql.append_string(&item.concept_id)
        sql.append_view("', '")
        sql.append_string(&item.course_id)
        sql.append_view("', '")
        sql.append_string(&item.item_type)
        sql.append_view("', '")
        var front_esc = underlayer_core::json_escape(&item.front.to_view())
        sql.append_view(front_esc.to_view())
        sql.append_view("', '")
        var back_esc = underlayer_core::json_escape(&item.back.to_view())
        sql.append_view(back_esc.to_view())
        sql.append_view("', ")
        var diff_str = underlayer_core::int_to_string(item.difficulty as i64)
        sql.append_view(diff_str.to_view())
        sql.append_view(", ")
        var stab_str = underlayer_core::int_to_string(item.stability as i64)
        sql.append_view(stab_str.to_view())
        sql.append_view(", ")
        var ret_str = underlayer_core::int_to_string(item.retrievability as i64)
        sql.append_view(ret_str.to_view())
        sql.append_view(", ")
        var nr_str = underlayer_core::int_to_string(item.next_review)
        sql.append_view(nr_str.to_view())
        sql.append_view(", ")
        var lr_str = underlayer_core::int_to_string(item.last_review)
        sql.append_view(lr_str.to_view())
        sql.append_view(", ")
        var reps_str = underlayer_core::int_to_string(item.reps as i64)
        sql.append_view(reps_str.to_view())
        sql.append_view(", ")
        var lapses_str = underlayer_core::int_to_string(item.lapses as i64)
        sql.append_view(lapses_str.to_view())
        sql.append_view(", ")
        var ef_str = underlayer_core::int_to_string(item.ease_factor as i64)
        sql.append_view(ef_str.to_view())
        sql.append_view(".0)")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
