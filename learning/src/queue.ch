// underlayer_learning — Interleaved review queue.
using std::string
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

    // 1.3.8: Track interleaving effectiveness (accuracy vs blocked practice)
    public struct InterleaveEffectiveness {
        var interleaved_accuracy : f64
        var blocked_accuracy : f64
        var interleaved_count : int
        var blocked_count : int
        var effectiveness_delta : f64  // positive = interleaving helped

        @make
        func make() : InterleaveEffectiveness {
            return InterleaveEffectiveness {
                interleaved_accuracy = 0.0,
                blocked_accuracy = 0.0,
                interleaved_count = 0,
                blocked_count = 0,
                effectiveness_delta = 0.0
            }
        }
    }

    // 1.3.9: Interleave prerequisite concepts with target concepts
    public func should_interleave_prereqs(concept_prereqs : *vector<string>, weak_concepts : *vector<string>) : bool {
        var i : size_t = 0
        while(i < concept_prereqs.size()) {
            var prereq_ptr = concept_prereqs.get_ptr(i)
            var prereq_copy = prereq_ptr.copy()
            var j : size_t = 0
            while(j < weak_concepts.size()) {
                var weak_ptr = weak_concepts.get_ptr(j)
                var weak_copy = weak_ptr.copy()
                if(prereq_copy.equals(&weak_copy)) { return true }
                j = j + 1
            }
            i = i + 1
        }
        return false
    }

    // 1.3.10: Interleave related concepts (same module, different topics)
    public func is_related_concept(concept_a : *string, concept_b : *string) : bool {
        var a_copy = concept_a.copy()
        var b_copy = concept_b.copy()
        if(a_copy.equals(&b_copy)) { return false }
        var i : size_t = 0
        var dot_pos_a : i64 = -1
        var dot_pos_b : i64 = -1
        while(i < a_copy.size()) {
            if(a_copy.get(i) == '.') { dot_pos_a = i as i64 }
            i = i + 1
        }
        i = 0
        while(i < b_copy.size()) {
            if(b_copy.get(i) == '.') { dot_pos_b = i as i64 }
            i = i + 1
        }
        if(dot_pos_a < 0 || dot_pos_b < 0) { return false }
        var same_prefix = true
        var j : size_t = 0
        while(j < (dot_pos_a as size_t) && j < (dot_pos_b as size_t)) {
            if(a_copy.get(j) != b_copy.get(j)) { same_prefix = false }
            j = j + 1
        }
        return same_prefix
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
        var done = false
        while(!done && remaining_total > 0 && (added_new < remaining_new || added_reviews < remaining_reviews)) {
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
            if(di >= queue.due_items.size() && ni >= queue.new_items.size()) { done = true }
            if(added_new >= remaining_new && added_reviews >= remaining_reviews) { done = true }
            if(remaining_total <= 0) { done = true }
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

    // 1.3.11: Interleave unrelated concepts (cross-module, random)
    public func is_unrelated_concept(concept_a : *string, concept_b : *string) : bool {
        var a_copy = concept_a.copy()
        var b_copy = concept_b.copy()
        if(a_copy.equals(&b_copy)) { return false }
        var i : size_t = 0
        var dot_pos_a : i64 = -1
        var dot_pos_b : i64 = -1
        while(i < a_copy.size()) {
            if(a_copy.get(i) == '.') { dot_pos_a = i as i64 }
            i = i + 1
        }
        i = 0
        while(i < b_copy.size()) {
            if(b_copy.get(i) == '.') { dot_pos_b = i as i64 }
            i = i + 1
        }
        // Both have module prefix — check if different modules
        if(dot_pos_a >= 0 && dot_pos_b >= 0) {
            var j : size_t = 0
            var different = false
            var min_len = dot_pos_a
            if(dot_pos_b < min_len) { min_len = dot_pos_b }
            while(j < (min_len as size_t)) {
                if(a_copy.get(j) != b_copy.get(j)) { different = true }
                j = j + 1
            }
            return different
        }
        return true
    }

}
