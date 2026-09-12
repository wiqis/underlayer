// underlayer_learning — FSRS spaced repetition engine, weakness detection, review queue.
using std::string
using std::string_view
using std::vector
using underlayer_models::ReviewItem
using underlayer_models::ConceptState

public namespace underlayer_learning {

    // ============================================================
    // FSRS Spaced Repetition Engine
    // ============================================================

    public const RATING_AGAIN : int = 1
    public const RATING_HARD : int = 2
    public const RATING_GOOD : int = 3
    public const RATING_EASY : int = 4

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

    // ============================================================
    // Review Session Management
    // ============================================================

    public struct ReviewSession {
        var items : vector<ReviewItem>
        var current_index : int
        var params : FSRSParams

        @make
        func make() : ReviewSession {
            return ReviewSession {
                items = vector<ReviewItem>(),
                current_index = 0,
                params = init_fsrs_params()
            }
        }
    }

    public func start_review_session(items : vector<ReviewItem>) : ReviewSession {
        var session = ReviewSession::make()
        session.items = items
        session.current_index = 0
        return session
    }

    public func get_current_item(session : &ReviewSession, out : *mut ReviewItem) {
        if(session.current_index < session.items.size()) {
            var idx = session.current_index as size_t
            var src = session.items.get_ptr(idx)
            // Copy fields manually to avoid dereferencing destructible struct
            out.id = src.id.copy()
            out.learner_id = src.learner_id.copy()
            out.concept_id = src.concept_id.copy()
            out.course_id = src.course_id.copy()
            out.item_type = src.item_type.copy()
            out.front = src.front.copy()
            out.back = src.back.copy()
            out.difficulty = src.difficulty
            out.stability = src.stability
            out.retrievability = src.retrievability
            out.next_review = src.next_review
            out.last_review = src.last_review
            out.reps = src.reps
            out.lapses = src.lapses
        }
    }

    public func advance_session(session : &mut ReviewSession) {
        session.current_index = session.current_index + 1
    }

    public func is_session_complete(session : &ReviewSession) : bool {
        return session.current_index >= session.items.size()
    }

    // ============================================================
    // Weakness Detection
    // ============================================================

    public struct WeaknessReport {
        var concept_id : string
        var accuracy : f64
        var total_attempts : int
        var correct_count : int
        var weak_prerequisites : vector<string>

        @make
        func make() : WeaknessReport {
            return WeaknessReport {
                concept_id = string(),
                accuracy = 0.0,
                total_attempts = 0,
                correct_count = 0,
                weak_prerequisites = vector<string>()
            }
        }
    }

    public func detect_weaknesses(states : *vector<ConceptState>) : vector<WeaknessReport> {
        var reports = vector<WeaknessReport>()
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) {
                var accuracy = (state.correct as f64) / (state.attempts as f64)
                if(accuracy < 0.7) {
                    var report = WeaknessReport::make()
                    report.concept_id = state.concept_id.copy()
                    report.accuracy = accuracy
                    report.total_attempts = state.attempts
                    report.correct_count = state.correct
                    reports.push(report)
                }
            }
            i = i + 1
        }
        return reports
    }

    public func suggest_repair(weakness : &WeaknessReport) : string {
        var suggestion = string("Review '")
        suggestion.append_string(&weakness.concept_id)
        suggestion.append_view("' — accuracy is ")
        var acc_str = f64_to_string(weakness.accuracy)
        suggestion.append_string(&acc_str)
        suggestion.append_view("%. ")
        if(weakness.accuracy < 0.5) {
            suggestion.append_view("Consider reviewing prerequisites first.")
        } else {
            suggestion.append_view("A few more reviews should help solidify this.")
        }
        return suggestion
    }

    // ============================================================
    // Interleaved Review Queue
    // ============================================================

    public struct ReviewQueue {
        var new_items : vector<ReviewItem>
        var due_items : vector<ReviewItem>
        var max_new_per_day : int
        var max_reviews_per_day : int
        var new_today : int
        var reviews_today : int

        @make
        func make() : ReviewQueue {
            return ReviewQueue {
                new_items = vector<ReviewItem>(),
                due_items = vector<ReviewItem>(),
                max_new_per_day = 5,
                max_reviews_per_day = 20,
                new_today = 0,
                reviews_today = 0
            }
        }
    }

    public func build_review_queue(
        new_items : vector<ReviewItem>,
        due_items : vector<ReviewItem>,
        max_new : int,
        max_reviews : int
    ) : ReviewQueue {
        var queue = ReviewQueue::make()
        queue.new_items = new_items
        queue.due_items = due_items
        queue.max_new_per_day = max_new
        queue.max_reviews_per_day = max_reviews
        return queue
    }

    public func get_next_review_items(queue : &ReviewQueue) : vector<ReviewItem> {
        var result = vector<ReviewItem>()
        var remaining_new = queue.max_new_per_day - queue.new_today
        var remaining_reviews = queue.max_reviews_per_day - queue.reviews_today

        // Interleave: alternate between due reviews and new items
        var di : size_t = 0
        var ni : size_t = 0
        var added_new = 0
        var added_reviews = 0

        while(added_new < remaining_new && added_reviews < remaining_reviews) {
            // Add one due item
            if(di < queue.due_items.size() && added_reviews < remaining_reviews) {
                var item = queue.due_items.get_ptr(di)
                var copy = ReviewItem::make()
                copy.id = item.id.copy()
                copy.learner_id = item.learner_id.copy()
                copy.concept_id = item.concept_id.copy()
                copy.course_id = item.course_id.copy()
                copy.item_type = item.item_type.copy()
                copy.front = item.front.copy()
                copy.back = item.back.copy()
                copy.difficulty = item.difficulty
                copy.stability = item.stability
                copy.retrievability = item.retrievability
                copy.next_review = item.next_review
                copy.last_review = item.last_review
                copy.reps = item.reps
                copy.lapses = item.lapses
                result.push(copy)
                di = di + 1
                added_reviews = added_reviews + 1
            }
            // Add one new item
            if(ni < queue.new_items.size() && added_new < remaining_new) {
                var item = queue.new_items.get_ptr(ni)
                var copy = ReviewItem::make()
                copy.id = item.id.copy()
                copy.learner_id = item.learner_id.copy()
                copy.concept_id = item.concept_id.copy()
                copy.course_id = item.course_id.copy()
                copy.item_type = item.item_type.copy()
                copy.front = item.front.copy()
                copy.back = item.back.copy()
                copy.difficulty = item.difficulty
                copy.stability = item.stability
                copy.retrievability = item.retrievability
                copy.next_review = item.next_review
                copy.last_review = item.last_review
                copy.reps = item.reps
                copy.lapses = item.lapses
                result.push(copy)
                ni = ni + 1
                added_new = added_new + 1
            }
        }

        // Fill remaining due reviews
        while(di < queue.due_items.size() && added_reviews < remaining_reviews) {
            var item = queue.due_items.get_ptr(di)
            var copy = ReviewItem::make()
            copy.id = item.id.copy()
            copy.learner_id = item.learner_id.copy()
            copy.concept_id = item.concept_id.copy()
            copy.course_id = item.course_id.copy()
            copy.item_type = item.item_type.copy()
            copy.front = item.front.copy()
            copy.back = item.back.copy()
            copy.difficulty = item.difficulty
            copy.stability = item.stability
            copy.retrievability = item.retrievability
            copy.next_review = item.next_review
            copy.last_review = item.last_review
            copy.reps = item.reps
            copy.lapses = item.lapses
            result.push(copy)
            di = di + 1
            added_reviews = added_reviews + 1
        }

        // Fill remaining new items
        while(ni < queue.new_items.size() && added_new < remaining_new) {
            var item = queue.new_items.get_ptr(ni)
            var copy = ReviewItem::make()
            copy.id = item.id.copy()
            copy.learner_id = item.learner_id.copy()
            copy.concept_id = item.concept_id.copy()
            copy.course_id = item.course_id.copy()
            copy.item_type = item.item_type.copy()
            copy.front = item.front.copy()
            copy.back = item.back.copy()
            copy.difficulty = item.difficulty
            copy.stability = item.stability
            copy.retrievability = item.retrievability
            copy.next_review = item.next_review
            copy.last_review = item.last_review
            copy.reps = item.reps
            copy.lapses = item.lapses
            result.push(copy)
            ni = ni + 1
            added_new = added_new + 1
        }

        return result
    }

    // ============================================================
    // Knowledge Health
    // ============================================================

    public struct KnowledgeHealth {
        var total_concepts : int
        var mastered : int
        var learning : int
        var reviewing : int
        var unlearned : int
        var health_score : f64  // 0.0 - 1.0

        @make
        func make() : KnowledgeHealth {
            return KnowledgeHealth {
                total_concepts = 0,
                mastered = 0,
                learning = 0,
                reviewing = 0,
                unlearned = 0,
                health_score = 0.0
            }
        }
    }

    public func compute_knowledge_health(states : *vector<ConceptState>) : KnowledgeHealth {
        var health = KnowledgeHealth::make()
        health.total_concepts = states.size() as int

        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.status.equals(string("mastered"))) {
                health.mastered = health.mastered + 1
            } else if(state.status.equals(string("learning"))) {
                health.learning = health.learning + 1
            } else if(state.status.equals(string("reviewing"))) {
                health.reviewing = health.reviewing + 1
            } else {
                health.unlearned = health.unlearned + 1
            }
            i = i + 1
        }

        if(health.total_concepts > 0) {
            health.health_score = (health.mastered as f64) / (health.total_concepts as f64)
        }

        return health
    }

    // ============================================================
    // Utility
    // ============================================================

    func f64_to_string(val : f64) : string {
        var int_part = val as i64
        var frac_part = ((val - (int_part as f64)) * 100.0) as i64
        var result = underlayer_core::int_to_string(int_part)
        result.append_view(".")
        var frac_str = underlayer_core::int_to_string(frac_part)
        result.append_view(frac_str.to_view())
        return result
    }
}
