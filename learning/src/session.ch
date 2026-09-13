// underlayer_learning — Review session management.
using std::vector
using underlayer_models::ReviewItem

public namespace underlayer_learning {

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
            out.ease_factor = src.ease_factor
        }
    }

    public func advance_session(session : &mut ReviewSession) {
        session.current_index = session.current_index + 1
    }

    public func is_session_complete(session : &ReviewSession) : bool {
        return session.current_index >= session.items.size()
    }

}
