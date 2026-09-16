// underlayer_web — Course reviews & ratings handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/courses/:courseId/reviews — Submit a review
    public func handle_submit_review(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var body_str = read_body(&raw mut req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var rating = json_get_int(&raw parsed, "rating")
        var title = json_get_str(&raw parsed, "title")
        var review_text = json_get_str(&raw parsed, "review_text")
        if(rating < 1 || rating > 5) {
            var err = string("rating must be between 1 and 5")
            send_error(res, 400u, &err)
            return
        }
        var existing = underlayer_repository::get_learner_review(db, &learner_id, course_id)
        if(existing.id.size() > 0) {
            var err = string("you have already reviewed this course")
            send_error(res, 409u, &err)
            return
        }
        var review_id = underlayer_repository::submit_review(db, &learner_id, course_id, rating, &title, &review_text)
        var resp = string("{\"ok\":true,\"id\":\"")
        resp.append_view(review_id.to_view())
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // GET /api/courses/:courseId/reviews — Get all reviews for a course
    public func handle_get_course_reviews(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var reviews = underlayer_repository::get_reviews_for_course(db, course_id)
        var resp = string("[")
        var ri : size_t = 0
        while(ri < reviews.size()) {
            if(ri > 0) { resp.append_view(",") }
            var rv = reviews.get_ptr(ri)
            resp.append_view("{\"id\":\"")
            resp.append_string(&rv.id)
            resp.append_view("\",\"learner_id\":\"")
            resp.append_string(&rv.learner_id)
            resp.append_view("\",\"course_id\":\"")
            resp.append_string(&rv.course_id)
            resp.append_view("\",\"rating\":")
            var rating_str = underlayer_core::int_to_string(rv.rating as i64)
            resp.append_view(rating_str.to_view())
            resp.append_view(",\"title\":\"")
            resp.append_string(&rv.title)
            resp.append_view("\",\"review_text\":\"")
            resp.append_string(&rv.review_text)
            resp.append_view("\",\"helpful_count\":")
            var hc_str = underlayer_core::int_to_string(rv.helpful_count as i64)
            resp.append_view(hc_str.to_view())
            resp.append_view(",\"created_at\":")
            var created_str = underlayer_core::int_to_string(rv.created_at)
            resp.append_view(created_str.to_view())
            resp.append_view(",\"updated_at\":")
            var updated_str = underlayer_core::int_to_string(rv.updated_at)
            resp.append_view(updated_str.to_view())
            resp.append_view("}")
            ri = ri + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // PUT /api/reviews/:id — Update a review
    public func handle_update_review(db : *DbClient, review_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var body_str = read_body(&raw mut req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var rating = json_get_int(&raw parsed, "rating")
        var title = json_get_str(&raw parsed, "title")
        var review_text = json_get_str(&raw parsed, "review_text")
        if(rating < 1 || rating > 5) {
            var err = string("rating must be between 1 and 5")
            send_error(res, 400u, &err)
            return
        }
        underlayer_repository::update_review(db, review_id, rating, &title, &review_text)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // DELETE /api/reviews/:id — Delete a review
    public func handle_delete_review(db : *DbClient, review_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        underlayer_repository::delete_review(db, review_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // POST /api/reviews/:id/helpful — Mark a review as helpful
    public func handle_mark_review_helpful(db : *DbClient, review_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        underlayer_repository::mark_helpful(db, review_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // GET /api/courses/:courseId/rating — Get rating summary for a course
    public func handle_course_rating_summary(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var summary = underlayer_repository::get_course_rating_summary(db, course_id)
        var resp = string("{\"course_id\":\"")
        resp.append_string(&summary.course_id)
        resp.append_view("\",\"avg_rating\":")
        var avg_str = underlayer_learning::f64_to_string(summary.avg_rating)
        resp.append_view(avg_str.to_view())
        resp.append_view(",\"total_reviews\":")
        var total_str = underlayer_core::int_to_string(summary.total_reviews as i64)
        resp.append_view(total_str.to_view())
        resp.append_view(",\"rating_5\":")
        var r5_str = underlayer_core::int_to_string(summary.rating_5 as i64)
        resp.append_view(r5_str.to_view())
        resp.append_view(",\"rating_4\":")
        var r4_str = underlayer_core::int_to_string(summary.rating_4 as i64)
        resp.append_view(r4_str.to_view())
        resp.append_view(",\"rating_3\":")
        var r3_str = underlayer_core::int_to_string(summary.rating_3 as i64)
        resp.append_view(r3_str.to_view())
        resp.append_view(",\"rating_2\":")
        var r2_str = underlayer_core::int_to_string(summary.rating_2 as i64)
        resp.append_view(r2_str.to_view())
        resp.append_view(",\"rating_1\":")
        var r1_str = underlayer_core::int_to_string(summary.rating_1 as i64)
        resp.append_view(r1_str.to_view())
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

}
