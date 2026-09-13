// underlayer_web — FSRS settings handlers (1.1.24-1.1.28).
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/fsrs/optimize — optimize parameters from review history
    public func handle_fsrs_optimize(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var history = underlayer_repository::get_all_review_history(&raw db, &learner_id)
        if(history.size() < 10) {
            send_error(res, 400u, &string("need at least 10 reviews for optimization"))
            return
        }
        // Extract ratings and intervals
        var ratings = vector<int>()
        var intervals = vector<i64>()
        var hi : size_t = 0
        while(hi < history.size()) {
            var item = history.get_ptr(hi)
            ratings.push(item.rating)
            // Compute interval from consecutive reviews
            var interval : i64 = 1
            if(hi > 0) {
                var prev = history.get_ptr(hi - 1)
                interval = item.reviewed_at - prev.reviewed_at
                if(interval < 1) { interval = 1 }
            }
            intervals.push(interval)
            hi = hi + 1
        }
        var old_params = underlayer_learning::init_fsrs_params()
        var new_params = underlayer_learning::optimize_fsrs_params(&old_params, &ratings, &intervals)
        var log_entry = underlayer_learning::log_param_change(&old_params, &new_params, &string("optimize_from_history"))
        var body = std::string("{\"ok\":true,\"log\":")
        body.append_view(&log_entry.to_view())
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // POST /api/fsrs/reset — reset parameters to defaults
    public func handle_fsrs_reset(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var new_params = underlayer_learning::reset_fsrs_params()
        var exported = underlayer_learning::export_fsrs_params(&new_params)
        var body = std::string("{\"ok\":true,\"params\":")
        body.append_view(&exported.to_view())
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // GET /api/fsrs/export — export current parameters
    public func handle_fsrs_export(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var params = underlayer_learning::init_fsrs_params()
        var exported = underlayer_learning::export_fsrs_params(&params)
        send_json_str(res, &raw exported)
    }

}
