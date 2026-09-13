// underlayer_learning — FSRS algorithm core.
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

}
