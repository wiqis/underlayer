// underlayer_learning — FSRS algorithm core.
using std::string
using std::vector

public namespace underlayer_learning {

    public struct FSRSParams {
        var w : vector<f64>
        var target_retention : f64  // 1.1.4: target retention rate (default 0.90)

        @make
        func make() : FSRSParams {
            return FSRSParams {
                w = vector<f64>(),
                target_retention = 0.90
            }
        }
    }

    public func init_fsrs_params() : FSRSParams {
        var p = FSRSParams::make()
        p.w.push(0.4072)   // w[0]
        p.w.push(0.3366)   // w[1]
        p.w.push(0.2540)   // w[2]
        p.w.push(0.1901)   // w[3]
        p.w.push(0.5530)   // w[4]
        p.w.push(0.0154)   // w[5]
        p.w.push(0.0438)   // w[6]
        p.w.push(0.1242)   // w[7]
        p.w.push(0.2207)   // w[8]
        p.w.push(0.2603)   // w[9]
        p.w.push(0.4722)   // w[10]
        p.w.push(0.3819)   // w[11]
        p.w.push(0.0644)   // w[12]
        p.w.push(0.2169)   // w[13]
        p.w.push(0.7025)   // w[14]
        p.w.push(0.0382)   // w[15]
        p.w.push(0.2276)   // w[16]
        p.w.push(0.9957)   // w[17]
        p.w.push(0.0380)   // w[18]
        p.w.push(0.90)     // w[19] — hard interval factor
        p.w.push(1.15)     // w[20] — easy interval factor
        return p
    }

    public struct ReviewState {
        var difficulty : f64
        var stability : f64
        var elapsed_days : i64
        var scheduled_days : i64
        var reps : int
        var lapses : int
        var ease_factor : f64
        var grad_step : int

        @make
        func make() : ReviewState {
            return ReviewState {
                difficulty = 5.0,
                stability = 1.0,
                elapsed_days = 0,
                scheduled_days = 0,
                reps = 0,
                lapses = 0,
                ease_factor = 2.5,
                grad_step = 0
            }
        }
    }

    func fsrs_init_difficulty(params : &FSRSParams, rating : int) : f64 {
        var d = *params.w.get_ptr(4) - (*params.w.get_ptr(5) * ((rating - 1) as f64))
        if(d < 1.0) { d = 1.0 }
        if(d > 10.0) { d = 10.0 }
        return d
    }

    func fsrs_init_stability(params : &FSRSParams, rating : int) : f64 {
        return *params.w.get_ptr((rating - 1 + 1) as size_t)
    }

    public func fsrs_retrievability(state : &ReviewState, elapsed_days : f64) : f64 {
        if(state.stability <= 0.0) { return 0.0 }
        var base = 1.0 + (elapsed_days / state.stability)
        var log_base = log(base)
        var exponent = -0.0380 * log_base
        return exp(exponent)
    }

    func fsrs_next_stability(params : &FSRSParams, state : &ReviewState, rating : int) : f64 {
        var r = fsrs_retrievability(state, state.elapsed_days as f64)

        if(rating == RATING_AGAIN) {
            var s_new = *params.w.get_ptr(12) * pow(state.difficulty, -*params.w.get_ptr(13))
            s_new = s_new * pow(state.stability + 1.0, *params.w.get_ptr(14)) - 1.0
            s_new = s_new * exp(*params.w.get_ptr(15) * (1.0 - r))
            if(s_new < 1.0) { s_new = 1.0 }
            return s_new
        }

        var hard_factor = 1.0
        if(rating == RATING_HARD) { hard_factor = *params.w.get_ptr(19) }
        if(rating == RATING_EASY) { hard_factor = *params.w.get_ptr(20) }

        var stability_factor = *params.w.get_ptr(16) * pow(state.stability, *params.w.get_ptr(17))
        var s_new = state.stability * (exp(stability_factor) * hard_factor)
        if(s_new < state.stability) { s_new = state.stability }
        return s_new
    }

    public func fsrs_next_interval(params : &FSRSParams, state : &ReviewState, rating : int) : i64 {
        var s_new = fsrs_next_stability(params, state, rating)
        // 1.1.4: Use target retention instead of hardcoded 0.9
        var d_factor = exp(*params.w.get_ptr(8) * (state.difficulty - 3.0)) - 1.0
        var interval = s_new * (d_factor * params.target_retention / 0.9)

        if(rating == RATING_AGAIN) { interval = 1.0 }
        if(rating == RATING_HARD) { interval = interval * *params.w.get_ptr(9) }
        if(rating == RATING_EASY) { interval = interval * *params.w.get_ptr(10) }

        if(interval < 1.0) { interval = 1.0 }
        if(interval > 36500.0) { interval = 36500.0 }

        return interval as i64
    }

    // 1.1.18/1.1.19: Graduation steps for new cards (in days)
    // Step 0: 1 day, Step 1: 3 days, Step 2+: graduated
    public func grad_step_interval(step : int) : i64 {
        if(step == 0) { return 1 }
        if(step == 1) { return 3 }
        return 3  // default
    }

    public func fsrs_update_state(params : &FSRSParams, state : &ReviewState, rating : int) : ReviewState {
        var new_state = ReviewState::make()
        new_state.ease_factor = state.ease_factor

        if(state.reps == 0) {
            // ---- New card ----
            new_state.difficulty = fsrs_init_difficulty(params, rating)
            new_state.stability = fsrs_init_stability(params, rating)
            new_state.reps = 1

            if(rating == RATING_AGAIN) {
                // 1.1.18: "Again" on new card — reset to step 0
                new_state.lapses = 1
                new_state.grad_step = 0
                new_state.scheduled_days = 1
            } else if(rating == RATING_EASY) {
                // 1.1.19: "Easy" on new card — graduate immediately
                new_state.lapses = 0
                new_state.grad_step = -1  // graduated
                new_state.scheduled_days = fsrs_next_interval(params, &new_state, rating)
            } else if(rating == RATING_GOOD) {
                // 1.1.18: "Good" on new card — advance to next graduation step
                new_state.lapses = 0
                var next_step = state.grad_step + 1
                if(next_step >= 2) {
                    // All steps completed — graduate
                    new_state.grad_step = -1
                    new_state.scheduled_days = fsrs_next_interval(params, &new_state, rating)
                } else {
                    new_state.grad_step = next_step
                    new_state.scheduled_days = grad_step_interval(next_step)
                }
            } else {
                // RATING_HARD on new card
                new_state.lapses = 0
                new_state.grad_step = state.grad_step
                if(state.grad_step >= 0 && state.grad_step < 2) {
                    new_state.scheduled_days = grad_step_interval(state.grad_step)
                } else {
                    new_state.scheduled_days = 1
                }
            }
        } else {
            // ---- Review card ----
            // 1.1.15: Ease factor adjustment on each rating
            // Again: -0.20, Hard: -0.15, Good: +0.00, Easy: +0.15
            if(rating == RATING_AGAIN) { new_state.ease_factor = state.ease_factor - 0.20 }
            else if(rating == RATING_HARD) { new_state.ease_factor = state.ease_factor - 0.15 }
            else if(rating == RATING_EASY) { new_state.ease_factor = state.ease_factor + 0.15 }
            else { new_state.ease_factor = state.ease_factor }
            // Clamp ease factor to [1.3, 3.0]
            if(new_state.ease_factor < 1.3) { new_state.ease_factor = 1.3 }
            if(new_state.ease_factor > 3.0) { new_state.ease_factor = 3.0 }

            // 1.1.16: Per-item difficulty drift based on review history
            // Use FSRS v4 formula: D' = D - w6 * (rating - 3)
            var w6 = *params.w.get_ptr(6)
            new_state.difficulty = state.difficulty - w6 * ((rating - 3) as f64)
            if(new_state.difficulty < 1.0) { new_state.difficulty = 1.0 }
            if(new_state.difficulty > 10.0) { new_state.difficulty = 10.0 }

            new_state.stability = fsrs_next_stability(params, state, rating)
            new_state.reps = state.reps + 1
            new_state.grad_step = -1  // already graduated

            if(rating == RATING_AGAIN) {
                new_state.lapses = state.lapses + 1
                // 1.1.14: Lapse recovery — when R < 0.5, reset stability to 50% of previous
                var r = fsrs_retrievability(state, state.elapsed_days as f64)
                if(r < 0.5) {
                    new_state.stability = state.stability * 0.5
                }
            } else {
                new_state.lapses = state.lapses
            }

            new_state.scheduled_days = fsrs_next_interval(params, &new_state, rating)
            // 1.1.15: Apply ease factor modifier to interval
            new_state.scheduled_days = (new_state.scheduled_days as f64 * new_state.ease_factor / 2.5) as i64
            if(new_state.scheduled_days < 1) { new_state.scheduled_days = 1 }
        }

        new_state.elapsed_days = state.scheduled_days

        return new_state
    }

    // 1.1.24: Compute prediction error (MSE) for a set of params against review history
    // Returns mean squared error (no sqrt needed for comparison)
    public func compute_prediction_error(params : &FSRSParams, history_ratings : &vector<int>, history_intervals : &vector<i64>) : f64 {
        if(history_ratings.size() == 0) { return 0.0 }
        var total_sq_error : f64 = 0.0
        var state = ReviewState::make()
        var i : size_t = 0
        while(i < history_ratings.size()) {
            var rating = history_ratings.get(i)
            var elapsed : f64 = 0.0
            if(i > 0) {
                elapsed = history_intervals.get(i - 1) as f64
            }
            var predicted_r = fsrs_retrievability(&state, elapsed)
            var actual : f64 = 0.0
            if(rating >= 3) { actual = 1.0 }
            var error = predicted_r - actual
            total_sq_error = total_sq_error + error * error
            state = fsrs_update_state(params, &state, rating)
            i = i + 1
        }
        var n = history_ratings.size() as f64
        return total_sq_error / n
    }

    // 1.1.24: Simple parameter optimization using coordinate descent
    // Adjusts each w parameter slightly and keeps improvements
    public func optimize_fsrs_params(params : &FSRSParams, history_ratings : &vector<int>, history_intervals : &vector<i64>) : FSRSParams {
        var best = FSRSParams::make()
        var pi : size_t = 0
        while(pi < params.w.size()) {
            best.w.push(params.w.get(pi))
            pi = pi + 1
        }
        best.target_retention = params.target_retention
        var best_rmse = compute_prediction_error(&best, history_ratings, history_intervals)
        // Try adjusting each parameter by small deltas
        var di : size_t = 0
        while(di < best.w.size()) {
            var delta : f64 = 0.01
            var d : int = 0
            while(d < 2) {
                var trial = FSRSParams::make()
                var ti : size_t = 0
                while(ti < best.w.size()) {
                    if(ti == di) {
                        if(d == 0) { trial.w.push(best.w.get(ti) + delta) }
                        else { trial.w.push(best.w.get(ti) - delta) }
                    } else {
                        trial.w.push(best.w.get(ti))
                    }
                    ti = ti + 1
                }
                trial.target_retention = best.target_retention
                var trial_rmse = compute_prediction_error(&trial, history_ratings, history_intervals)
                if(trial_rmse < best_rmse) {
                    best = trial
                    best_rmse = trial_rmse
                }
                d = d + 1
            }
            di = di + 1
        }
        return best
    }

    // 1.1.25: Reset FSRS parameters to defaults
    public func reset_fsrs_params() : FSRSParams {
        return init_fsrs_params()
    }

    // 1.1.27: Export FSRS parameters as JSON string
    public func export_fsrs_params(params : &FSRSParams) : string {
        var json = string("{\"w\":[")
        var i : size_t = 0
        while(i < params.w.size()) {
            if(i > 0) { json.append(',') }
            var val = params.w.get(i)
            var int_part = val as i64
            var frac = val - (int_part as f64)
            var frac_int = (frac * 10000.0) as i64
            var int_str = underlayer_core::int_to_string(int_part)
            var frac_str = underlayer_core::int_to_string(frac_int)
            json.append_view(int_str.to_view())
            json.append('.')
            if(frac_int < 1000) { json.append('0') }
            if(frac_int < 100) { json.append('0') }
            if(frac_int < 10) { json.append('0') }
            json.append_view(frac_str.to_view())
            i = i + 1
        }
        json.append_view("],\"target_retention\":")
        var tr_int = params.target_retention as i64
        var tr_frac_int = ((params.target_retention - (tr_int as f64)) * 10000.0) as i64
        var tr_int_str = underlayer_core::int_to_string(tr_int)
        var tr_frac_str = underlayer_core::int_to_string(tr_frac_int)
        json.append_view(tr_int_str.to_view())
        json.append('.')
        if(tr_frac_int < 1000) { json.append('0') }
        if(tr_frac_int < 100) { json.append('0') }
        if(tr_frac_int < 10) { json.append('0') }
        json.append_view(tr_frac_str.to_view())
        json.append_view("}")
        return json
    }

    // 1.1.28: Log parameter changes (returns a log entry string)
    public func log_param_change(old_params : &FSRSParams, new_params : &FSRSParams, reason : &string) : string {
        var log = string("{\"reason\":\"")
        log.append_string(reason)
        log.append_view("\",\"old_rmse\":null,\"new_rmse\":null,\"changed_params\":[")
        var i : size_t = 0
        var first = true
        while(i < old_params.w.size()) {
            var old_val = old_params.w.get(i)
            var new_val = new_params.w.get(i)
            var diff = old_val - new_val
            if(diff < 0) { diff = -diff }
            if(diff > 0.0001) {
                if(!first) { log.append(',') }
                first = false
                var idx_str = underlayer_core::int_to_string(i as i64)
                log.append_view("{\"index\":")
                log.append_view(idx_str.to_view())
                log.append_view(",\"old\":")
                var ov_int = old_val as i64
                var ov_frac = ((old_val - (ov_int as f64)) * 10000.0) as i64
                var ov_int_str = underlayer_core::int_to_string(ov_int)
                var ov_frac_str = underlayer_core::int_to_string(ov_frac)
                log.append_view(ov_int_str.to_view())
                log.append('.')
                log.append_view(ov_frac_str.to_view())
                log.append_view(",\"new\":")
                var nv_int = new_val as i64
                var nv_frac = ((new_val - (nv_int as f64)) * 10000.0) as i64
                var nv_int_str = underlayer_core::int_to_string(nv_int)
                var nv_frac_str = underlayer_core::int_to_string(nv_frac)
                log.append_view(nv_int_str.to_view())
                log.append('.')
                log.append_view(nv_frac_str.to_view())
                log.append('}')
            }
            i = i + 1
        }
        log.append_view("]}")
        return log
    }

}
