// underlayer_learning — FSRS algorithm core.
using std::vector

public namespace underlayer_learning {

    public struct FSRSParams {
        var w : vector<f64>

        @make
        func make() : FSRSParams {
            return FSRSParams {
                w = vector<f64>()
            }
        }
    }

    public func init_fsrs_params() : FSRSParams {
        var p = FSRSParams::make()
        p.w.push(0.4072)
        p.w.push(0.3366)
        p.w.push(0.2540)
        p.w.push(0.1901)
        p.w.push(0.5530)
        p.w.push(0.0154)
        p.w.push(0.0438)
        p.w.push(0.1242)
        p.w.push(0.2207)
        p.w.push(0.2603)
        p.w.push(0.4722)
        p.w.push(0.3819)
        p.w.push(0.0644)
        p.w.push(0.2169)
        p.w.push(0.7025)
        p.w.push(0.0382)
        p.w.push(0.2276)
        p.w.push(0.9957)
        p.w.push(0.0380)
        return p
    }

    public struct ReviewState {
        var difficulty : f64
        var stability : f64
        var elapsed_days : i64
        var scheduled_days : i64
        var reps : int
        var lapses : int

        @make
        func make() : ReviewState {
            return ReviewState {
                difficulty = 5.0,
                stability = 1.0,
                elapsed_days = 0,
                scheduled_days = 0,
                reps = 0,
                lapses = 0
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
        var d_factor = exp(*params.w.get_ptr(8) * (state.difficulty - 3.0)) - 1.0
        var interval = s_new * d_factor

        if(rating == RATING_AGAIN) { interval = 1.0 }
        if(rating == RATING_HARD) { interval = interval * *params.w.get_ptr(9) }
        if(rating == RATING_EASY) { interval = interval * *params.w.get_ptr(10) }

        if(interval < 1.0) { interval = 1.0 }
        if(interval > 36500.0) { interval = 36500.0 }

        return interval as i64
    }

    public func fsrs_update_state(params : &FSRSParams, state : &ReviewState, rating : int) : ReviewState {
        var new_state = ReviewState::make()

        if(state.reps == 0) {
            new_state.difficulty = fsrs_init_difficulty(params, rating)
            new_state.stability = fsrs_init_stability(params, rating)
            new_state.reps = 1
            if(rating == RATING_AGAIN) { new_state.lapses = 1 } else { new_state.lapses = 0 }
        } else {
            new_state.difficulty = state.difficulty + (rating - 2) as f64 * 0.1
            if(new_state.difficulty < 1.0) { new_state.difficulty = 1.0 }
            if(new_state.difficulty > 10.0) { new_state.difficulty = 10.0 }
            new_state.stability = fsrs_next_stability(params, state, rating)
            new_state.reps = state.reps + 1
            if(rating == RATING_AGAIN) {
                new_state.lapses = state.lapses + 1
            } else {
                new_state.lapses = state.lapses
            }
        }

        new_state.elapsed_days = state.scheduled_days
        new_state.scheduled_days = fsrs_next_interval(params, state, rating)

        return new_state
    }

}
