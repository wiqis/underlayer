// underlayer_repository — Review item CRUD.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::ReviewItem

public namespace underlayer_repository {

    // Fetch a single review item by id. Returns a default item (id == "") if missing.
    public func get_review_item(db : *DbClient, item_id : &string) : ReviewItem {
        var item = ReviewItem::make()
        var sql = string("SELECT id, concept_id, type, front, back, difficulty, stability, retrievability, next_review, last_review, reps, lapses, ease_factor FROM review_items WHERE id = '")
        sql.append_string(item_id)
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() == 0) { return item }
        var row = result.rows.get_ptr(0)
        if(row.vals.size() < 13) { return item }
        item.id = row.vals.get_ptr(0).copy()
        item.concept_id = row.vals.get_ptr(1).copy()
        item.item_type = row.vals.get_ptr(2).copy()
        item.front = row.vals.get_ptr(3).copy()
        item.back = row.vals.get_ptr(4).copy()
        item.difficulty = parse_f64(row.vals.get_ptr(5).to_view())
        item.stability = parse_f64(row.vals.get_ptr(6).to_view())
        item.retrievability = parse_f64(row.vals.get_ptr(7).to_view())
        item.next_review = parse_i64(row.vals.get_ptr(8).to_view())
        item.last_review = parse_i64(row.vals.get_ptr(9).to_view())
        item.reps = parse_i64(row.vals.get_ptr(10).to_view()) as int
        item.lapses = parse_i64(row.vals.get_ptr(11).to_view()) as int
        item.ease_factor = parse_f64(row.vals.get_ptr(12).to_view())
        return item
    }

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
                item.stability = parse_f64(row.vals.get_ptr(6).to_view())
                item.retrievability = parse_f64(row.vals.get_ptr(7).to_view())
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
                item.stability = parse_f64(row.vals.get_ptr(6).to_view())
                item.retrievability = parse_f64(row.vals.get_ptr(7).to_view())
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

    // The stored FSRS memory for one (learner, concept) pair, or an item with
    // id "" when there is none.
    //
    // WHY THIS EXISTS.  Spaced repetition is a function of what happened LAST
    // TIME, and `review_items` is where that memory lives -- it has carried a
    // `stability` column since the table was created, and get_review_item /
    // get_due_review_items / get_all_review_items all read it. Nothing read it
    // on the WRITE path.
    //
    // handlers_review.ch built its ReviewState out of `concept_states` instead,
    // which has attempts, correct, streak and two timestamps but no stability,
    // and then set `rs.stability = 1.0` as a literal. So every rating was
    // scheduled as though the learner had never seen the concept before, and
    // fsrs_next_stability -- which is S * exp(w16 * S^-w17), strictly increasing
    // in S -- could only ever return its S=1.0 answer.
    //
    // Measured on a learner rating one concept eight times "Good" in a row:
    //
    //   review 1: stability 0.19  interval 3 days
    //   review 2: stability 1.25  interval 1 day
    //   review 3: stability 1.25  interval 1 day     <- and 4, 5, 6, 7, 8
    //
    // Eight successful recalls, and the concept never left a 1-day interval. The
    // scheduler was working; it was being handed a fresh card every time.
    //
    // `get_review_item` takes an item id, and the submit handler knows a
    // concept_id rather than an item id, so this lookup is what makes the stored
    // state reachable at all. Returns reps/lapses/ease_factor/stability for the
    // concept's recall item; the id convention is the same one
    // seed_review_items writes (`<learner>_<course>_<concept>`).
    public func get_review_item_by_concept(db : *DbClient, learner_id : &string, course_id : &string, concept_id : &string) : ReviewItem {
        var sql = string("SELECT id, concept_id, type, front, back, difficulty, stability, retrievability, next_review, reps, lapses, ease_factor FROM review_items WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' AND concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("' ORDER BY last_review DESC LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        var item = ReviewItem::make()
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 12) {
                item.id = row.vals.get_ptr(0).copy()
                item.learner_id = learner_id.copy()
                item.concept_id = row.vals.get_ptr(1).copy()
                item.course_id = course_id.copy()
                item.item_type = row.vals.get_ptr(2).copy()
                item.front = row.vals.get_ptr(3).copy()
                item.back = row.vals.get_ptr(4).copy()
                item.difficulty = parse_f64(row.vals.get_ptr(5).to_view())
                item.stability = parse_f64(row.vals.get_ptr(6).to_view())
                item.retrievability = parse_f64(row.vals.get_ptr(7).to_view())
                item.next_review = parse_i64(row.vals.get_ptr(8).to_view())
                item.reps = parse_i64(row.vals.get_ptr(9).to_view()) as int
                item.lapses = parse_i64(row.vals.get_ptr(10).to_view()) as int
                item.ease_factor = parse_f64(row.vals.get_ptr(11).to_view())
            }
        }
        return item
    }

    public func update_review_item(db : *DbClient, item : *ReviewItem) {
        var sql = string("UPDATE review_items SET difficulty = ")
        var diff_str = underlayer_core::int_to_string(item.difficulty as i64)
        sql.append_view(diff_str.to_view())
        sql.append_view(", stability = ")
        // stability and retrievability are f64, written with FOUR decimals.
        //
        // They were int_to_string(x as i64), which discarded the fraction
        // entirely: every stability in (0,1) stored as 0, and 1.25 stored as 1.
        //
        // Two decimals was tried next and is ALSO wrong, which is the more
        // interesting half. FSRS initialises stability from w[rating] and
        // w[3] -- S0 for "Good" -- is 0.1901. The scheduler does raise it
        // (0.1901 -> 0.1985 -> 0.2080), but all of those sit below 0.20, so two
        // decimals cannot tell them apart: each computed stability was rounded
        // back to 0.19 on the way into the column and the next rating read 0.19
        // again. Ten successful reviews moved it from 0.19 to 0.19. A ROUND TRIP
        // HAS TO PRESERVE EVERY BIT THE NEXT STEP DEPENDS ON, and fixing the
        // write-up while rounding at the boundary leaves the loop intact.
        //
        // Four decimals covers the whole sub-1.0 range the scheduler spends its
        // early reviews in and is exact for f64 at these magnitudes.
        var stab_str = underlayer_repository::f64_to_string_prec(item.stability, 4)
        sql.append_view(stab_str.to_view())
        sql.append_view(", retrievability = ")
        var ret_str = underlayer_repository::f64_to_string_prec(item.retrievability, 4)
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
        // Four decimals, for the reason given on update_review_item. Truncating to an
        // integer discarded the scheduler's memory entirely, and two decimals
        // rounded away precisely the 0.19-0.20 band that S0("Good") sits in.
        var stab_str = underlayer_repository::f64_to_string_prec(item.stability, 4)
        sql.append_view(stab_str.to_view())
        sql.append_view(", ")
        var ret_str = underlayer_repository::f64_to_string_prec(item.retrievability, 4)
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
