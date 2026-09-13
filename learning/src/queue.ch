// underlayer_learning — Interleaved review queue.
using std::vector
using underlayer_models::ReviewItem

public namespace underlayer_learning {

    public struct ReviewQueue {
        var new_items : vector<ReviewItem>
        var due_items : vector<ReviewItem>
        var max_new_per_day : int
        var max_reviews_per_day : int
        var max_total_per_day : int     // 1.3.14: total daily item limit
        var new_today : int
        var reviews_today : int
        var interleaving_strength : int // 1.3.5: 0=none, 1=low, 2=medium, 3=high

        @make
        func make() : ReviewQueue {
            return ReviewQueue {
                new_items = vector<ReviewItem>(),
                due_items = vector<ReviewItem>(),
                max_new_per_day = 5,
                max_reviews_per_day = 20,
                max_total_per_day = 30,
                new_today = 0,
                reviews_today = 0,
                interleaving_strength = 2
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
        queue.max_total_per_day = max_new + max_reviews
        return queue
    }

    private func copy_review_item(src : *ReviewItem) : ReviewItem {
        var copy = ReviewItem::make()
        copy.id = src.id.copy()
        copy.learner_id = src.learner_id.copy()
        copy.concept_id = src.concept_id.copy()
        copy.course_id = src.course_id.copy()
        copy.item_type = src.item_type.copy()
        copy.front = src.front.copy()
        copy.back = src.back.copy()
        copy.difficulty = src.difficulty
        copy.stability = src.stability
        copy.retrievability = src.retrievability
        copy.next_review = src.next_review
        copy.last_review = src.last_review
        copy.reps = src.reps
        copy.lapses = src.lapses
        copy.ease_factor = src.ease_factor
        return copy
    }

    // 1.3.5: Interleave items by swapping adjacent pairs
    public func interleave_items(items : *vector<ReviewItem>, strength : int) {
        if(strength == 0 || items.size() < 2) { return }
        if(strength >= 1) {
            // Low/Medium: copy to temp, then write back interleaved
            var temp = vector<ReviewItem>()
            var ti : size_t = 0
            while(ti < items.size()) {
                temp.push(copy_review_item(items.get_ptr(ti)))
                ti = ti + 1
            }
            // Write back in interleaved order: even indices first, then odd
            var wi : size_t = 0
            var pos : size_t = 0
            // Even positions
            while(wi < temp.size()) {
                var src = temp.get_ptr(wi)
                var dst = items.get_ptr(pos)
                dst.id = src.id.copy()
                dst.learner_id = src.learner_id.copy()
                dst.concept_id = src.concept_id.copy()
                dst.course_id = src.course_id.copy()
                dst.item_type = src.item_type.copy()
                dst.front = src.front.copy()
                dst.back = src.back.copy()
                dst.difficulty = src.difficulty
                dst.stability = src.stability
                dst.retrievability = src.retrievability
                dst.next_review = src.next_review
                dst.last_review = src.last_review
                dst.reps = src.reps
                dst.lapses = src.lapses
                dst.ease_factor = src.ease_factor
                pos = pos + 1
                wi = wi + 2
            }
            // Odd positions
            wi = 1
            while(wi < temp.size()) {
                var src = temp.get_ptr(wi)
                var dst = items.get_ptr(pos)
                dst.id = src.id.copy()
                dst.learner_id = src.learner_id.copy()
                dst.concept_id = src.concept_id.copy()
                dst.course_id = src.course_id.copy()
                dst.item_type = src.item_type.copy()
                dst.front = src.front.copy()
                dst.back = src.back.copy()
                dst.difficulty = src.difficulty
                dst.stability = src.stability
                dst.retrievability = src.retrievability
                dst.next_review = src.next_review
                dst.last_review = src.last_review
                dst.reps = src.reps
                dst.lapses = src.lapses
                dst.ease_factor = src.ease_factor
                pos = pos + 1
                wi = wi + 2
            }
        }
    }

    // 1.3.6: Adaptive interleaving - increase strength when accuracy is high
    // 1.3.7: Adaptive interleaving - decrease strength when accuracy is low
    public func compute_adaptive_strength(base_strength : int, recent_accuracy : f64, streak : int) : int {
        // If accuracy > 80% and streak >= 3, increase interleaving (more challenge)
        if(recent_accuracy > 0.8 && streak >= 3) {
            var adaptive = base_strength + 1
            if(adaptive > 3) { adaptive = 3 }
            return adaptive
        }
        // If accuracy < 60%, decrease interleaving (focus, less challenge)
        if(recent_accuracy < 0.6) {
            var adaptive = base_strength - 1
            if(adaptive < 0) { adaptive = 0 }
            return adaptive
        }
        return base_strength
    }

    public func get_next_review_items(queue : &ReviewQueue) : vector<ReviewItem> {
        var result = vector<ReviewItem>()
        var remaining_new = queue.max_new_per_day - queue.new_today
        var remaining_reviews = queue.max_reviews_per_day - queue.reviews_today
        var remaining_total = queue.max_total_per_day - queue.new_today - queue.reviews_today

        var di : size_t = 0
        var ni : size_t = 0
        var added_new = 0
        var added_reviews = 0

        // 1.3.14: Respect total daily limit
        while(remaining_total > 0 && (added_new < remaining_new || added_reviews < remaining_reviews)) {
            if(di < queue.due_items.size() && added_reviews < remaining_reviews && remaining_total > 0) {
                var item = queue.due_items.get_ptr(di)
                result.push(copy_review_item(item))
                di = di + 1
                added_reviews = added_reviews + 1
                remaining_total = remaining_total - 1
            }
            if(ni < queue.new_items.size() && added_new < remaining_new && remaining_total > 0) {
                var item = queue.new_items.get_ptr(ni)
                result.push(copy_review_item(item))
                ni = ni + 1
                added_new = added_new + 1
                remaining_total = remaining_total - 1
            }
        }

        while(di < queue.due_items.size() && added_reviews < remaining_reviews && remaining_total > 0) {
            var item = queue.due_items.get_ptr(di)
            result.push(copy_review_item(item))
            di = di + 1
            added_reviews = added_reviews + 1
            remaining_total = remaining_total - 1
        }

        while(ni < queue.new_items.size() && added_new < remaining_new && remaining_total > 0) {
            var item = queue.new_items.get_ptr(ni)
            result.push(copy_review_item(item))
            ni = ni + 1
            added_new = added_new + 1
            remaining_total = remaining_total - 1
        }

        // 1.3.5: Apply interleaving
        interleave_items(&raw result, queue.interleaving_strength)

        return result
    }

}
