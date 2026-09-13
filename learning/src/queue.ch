// underlayer_learning — Interleaved review queue.
using std::vector
using underlayer_models::ReviewItem

public namespace underlayer_learning {

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
        return copy
    }

    public func get_next_review_items(queue : &ReviewQueue) : vector<ReviewItem> {
        var result = vector<ReviewItem>()
        var remaining_new = queue.max_new_per_day - queue.new_today
        var remaining_reviews = queue.max_reviews_per_day - queue.reviews_today

        var di : size_t = 0
        var ni : size_t = 0
        var added_new = 0
        var added_reviews = 0

        while(added_new < remaining_new && added_reviews < remaining_reviews) {
            if(di < queue.due_items.size() && added_reviews < remaining_reviews) {
                var item = queue.due_items.get_ptr(di)
                result.push(copy_review_item(item))
                di = di + 1
                added_reviews = added_reviews + 1
            }
            if(ni < queue.new_items.size() && added_new < remaining_new) {
                var item = queue.new_items.get_ptr(ni)
                result.push(copy_review_item(item))
                ni = ni + 1
                added_new = added_new + 1
            }
        }

        while(di < queue.due_items.size() && added_reviews < remaining_reviews) {
            var item = queue.due_items.get_ptr(di)
            result.push(copy_review_item(item))
            di = di + 1
            added_reviews = added_reviews + 1
        }

        while(ni < queue.new_items.size() && added_new < remaining_new) {
            var item = queue.new_items.get_ptr(ni)
            result.push(copy_review_item(item))
            ni = ni + 1
            added_new = added_new + 1
        }

        return result
    }

}
