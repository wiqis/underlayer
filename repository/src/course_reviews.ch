// underlayer_repository — Course reviews & ratings CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct CourseReview {
        var id : string
        var learner_id : string
        var course_id : string
        var rating : int
        var title : string
        var review_text : string
        var helpful_count : int
        var created_at : i64
        var updated_at : i64

        @make
        func make() : CourseReview {
            return CourseReview { id = string(), learner_id = string(), course_id = string(), rating = 0, title = string(), review_text = string(), helpful_count = 0, created_at = 0, updated_at = 0 }
        }
    }

    public struct CourseRatingSummary {
        var course_id : string
        var avg_rating : f64
        var total_reviews : int
        var rating_5 : int
        var rating_4 : int
        var rating_3 : int
        var rating_2 : int
        var rating_1 : int

        @make
        func make() : CourseRatingSummary {
            return CourseRatingSummary { course_id = string(), avg_rating = 0.0, total_reviews = 0, rating_5 = 0, rating_4 = 0, rating_3 = 0, rating_2 = 0, rating_1 = 0 }
        }
    }

    private func generate_review_id() : string {
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

    public func submit_review(db : *DbClient, learner_id : &string, course_id : &string, rating : int, title : &string, review_text : &string) : string {
        var review_id = generate_review_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var rating_str = underlayer_core::int_to_string(rating as i64)
        var sql = string("INSERT INTO course_reviews (id, learner_id, course_id, rating, title, review_text, helpful_count, created_at, updated_at) VALUES ('")
        sql.append_string(&review_id)
        sql.append_view("', '")
        sql.append_string(learner_id)
        sql.append_view("', '")
        sql.append_string(course_id)
        sql.append_view("', ")
        sql.append_view(rating_str.to_view())
        sql.append_view(", '")
        var title_esc = underlayer_core::json_escape(&title.to_view())
        sql.append_view(title_esc.to_view())
        sql.append_view("', '")
        var text_esc = underlayer_core::json_escape(&review_text.to_view())
        sql.append_view(text_esc.to_view())
        sql.append_view("', 0, ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return review_id
    }

    public func get_reviews_for_course(db : *DbClient, course_id : &string) : vector<CourseReview> {
        var reviews = vector<CourseReview>()
        var sql = string("SELECT id, learner_id, course_id, rating, title, review_text, helpful_count, created_at, updated_at FROM course_reviews WHERE course_id = '")
        sql.append_string(course_id)
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 9) {
                var rv = CourseReview::make()
                rv.id = row.vals.get_ptr(0).copy()
                rv.learner_id = row.vals.get_ptr(1).copy()
                rv.course_id = row.vals.get_ptr(2).copy()
                rv.rating = parse_int(row.vals.get_ptr(3).to_view())
                rv.title = row.vals.get_ptr(4).copy()
                rv.review_text = row.vals.get_ptr(5).copy()
                rv.helpful_count = parse_int(row.vals.get_ptr(6).to_view())
                rv.created_at = parse_i64(row.vals.get_ptr(7).to_view())
                rv.updated_at = parse_i64(row.vals.get_ptr(8).to_view())
                reviews.push(rv)
            }
            ri = ri + 1
        }
        return reviews
    }

    public func get_learner_review(db : *DbClient, learner_id : &string, course_id : &string) : CourseReview {
        var review = CourseReview::make()
        var sql = string("SELECT id, learner_id, course_id, rating, title, review_text, helpful_count, created_at, updated_at FROM course_reviews WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 9) {
                review.id = row.vals.get_ptr(0).copy()
                review.learner_id = row.vals.get_ptr(1).copy()
                review.course_id = row.vals.get_ptr(2).copy()
                review.rating = parse_int(row.vals.get_ptr(3).to_view())
                review.title = row.vals.get_ptr(4).copy()
                review.review_text = row.vals.get_ptr(5).copy()
                review.helpful_count = parse_int(row.vals.get_ptr(6).to_view())
                review.created_at = parse_i64(row.vals.get_ptr(7).to_view())
                review.updated_at = parse_i64(row.vals.get_ptr(8).to_view())
            }
        }
        return review
    }

    public func update_review(db : *DbClient, review_id : &string, rating : int, title : &string, review_text : &string) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var rating_str = underlayer_core::int_to_string(rating as i64)
        var sql = string("UPDATE course_reviews SET rating = ")
        sql.append_view(rating_str.to_view())
        sql.append_view(", title = '")
        var title_esc = underlayer_core::json_escape(&title.to_view())
        sql.append_view(title_esc.to_view())
        sql.append_view("', review_text = '")
        var text_esc = underlayer_core::json_escape(&review_text.to_view())
        sql.append_view(text_esc.to_view())
        sql.append_view("', updated_at = ")
        sql.append_view(now_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_string(review_id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func delete_review(db : *DbClient, review_id : &string) {
        var sql = string("DELETE FROM course_reviews WHERE id = '")
        sql.append_string(review_id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func mark_helpful(db : *DbClient, review_id : &string) {
        var sql = string("UPDATE course_reviews SET helpful_count = helpful_count + 1 WHERE id = '")
        sql.append_string(review_id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_course_rating_summary(db : *DbClient, course_id : &string) : CourseRatingSummary {
        var summary = CourseRatingSummary::make()
        summary.course_id = course_id.copy()
        var sql = string("SELECT COUNT(*) as total, COALESCE(AVG(rating), 0) as avg, SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as r5, SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as r4, SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as r3, SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as r2, SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as r1 FROM course_reviews WHERE course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 7) {
                summary.total_reviews = parse_int(row.vals.get_ptr(0).to_view())
                summary.avg_rating = parse_f64(row.vals.get_ptr(1).to_view())
                summary.rating_5 = parse_int(row.vals.get_ptr(2).to_view())
                summary.rating_4 = parse_int(row.vals.get_ptr(3).to_view())
                summary.rating_3 = parse_int(row.vals.get_ptr(4).to_view())
                summary.rating_2 = parse_int(row.vals.get_ptr(5).to_view())
                summary.rating_1 = parse_int(row.vals.get_ptr(6).to_view())
            }
        }
        return summary
    }

}
