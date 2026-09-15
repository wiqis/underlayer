// underlayer_web — FSRS settings handlers (1.1.24-1.1.28).
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_repository::parse_f64

public namespace underlayer_web {

    // GET /settings — render settings page
    public func handle_settings_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html_out = render_settings_page()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    // GET /u/:username — render public profile page
    public func handle_profile_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 2) {
            res.status = 404u
            var ct = std::string_view("text/plain")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("Not found")
            var bv = body.to_view()
            res.write_view(&bv)
            return
        }
        var username_sv = segments.get_ptr(1)
        var username = username_sv.to_string()
        var html_out = render_profile_page(&raw username)
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    // POST /api/auth/register — real implementation in handlers_auth.ch

    // POST /api/auth/login — real implementation in handlers_auth.ch

    // POST /api/auth/logout — real implementation in handlers_auth.ch

    // GET /api/auth/me — real implementation in handlers_auth.ch

    // POST /api/auth/forgot-password — real implementation in handlers_auth.ch

    // POST /api/auth/reset-password — real implementation in handlers_auth.ch

    // POST /api/auth/verify-email — real implementation in handlers_auth.ch

    // GET /api/user/login-history — real implementation in handlers_auth.ch

    // GET /api/user/profile — real implementation in handlers_profiles.ch

    // PUT /api/user/profile — real implementation in handlers_profiles.ch

    // GET /api/user/:username — real implementation in handlers_profiles.ch

    // GET /api/user/settings — real implementation in handlers_settings_api.ch

    // PUT /api/user/settings — real implementation in handlers_settings_api.ch

    // GET /api/user/learning-preferences — real implementation in handlers_settings_api.ch

    // PUT /api/user/learning-preferences — real implementation in handlers_settings_api.ch

    // GET /api/user/export — real implementation in handlers_data.ch

    // DELETE /api/user/data/:type — real implementation in handlers_data.ch

    // DELETE /api/user/account — real implementation in handlers_data.ch

    // POST /api/user/deactivate — real implementation in handlers_data.ch

    // POST /api/user/reactivate — real implementation in handlers_data.ch

    // POST /api/progress/share — real implementation in handlers_data.ch

    // GET /api/progress/shared/:token — real implementation in handlers_data.ch

    // POST /api/progress/import — real implementation in handlers_data.ch

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

    // POST /api/fsrs/import — import FSRS parameters from Anki JSON (1.1.26)
    // Accepts JSON array of weights: [0.4072, 0.3366, ...] or full object {"w":[...]}
    public func handle_fsrs_import(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_weights = string("weights")
        var weights_v = req.query.get(&q_weights.to_view())
        if(weights_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: weights (JSON array of floats)"))
            return
        }
        var weights_str = sv_to_string(&raw weights_v)
        var weights_view = weights_str.to_view()
        // Parse JSON array of floats
        var new_params = underlayer_learning::FSRSParams::make()
        new_params.target_retention = 0.90
        // Strip [ and ] if present
        var start : size_t = 0
        var end : size_t = weights_view.size()
        if(weights_view.get(0) == '[') { start = 1 }
        if(weights_view.get(end - 1) == ']') { end = end - 1 }
        var pos : size_t = start
        while(pos < end) {
            // Find next comma or end
            var comma_pos = end
            var ci : size_t = pos
            while(ci < end) {
                if(weights_view.get(ci) == ',') {
                    comma_pos = ci
                    ci = end
                }
                ci = ci + 1
            }
            // Parse number between pos and comma_pos
            var num_str = string()
            var ni : size_t = pos
            while(ni < comma_pos) {
                var c = weights_view.get(ni)
                if(c != ' ' && c != '\n' && c != '\r') {
                    num_str.append(c)
                }
                ni = ni + 1
            }
            if(num_str.size() > 0) {
                var val = parse_f64(num_str.to_view())
                new_params.w.push(val)
            }
            pos = comma_pos + 1
        }
        // Ensure we have at least 21 weights
        while(new_params.w.size() < 21) {
            new_params.w.push(0.0)
        }
        var exported = underlayer_learning::export_fsrs_params(&new_params)
        var body = std::string("{\"ok\":true,\"params\":")
        body.append_view(&exported.to_view())
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
