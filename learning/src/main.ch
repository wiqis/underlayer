// underlayer_learning — Module root.
// All code lives in separate files:
//   fsrs.ch       — FSRSParams, ReviewState, fsrs_update_state, fsrs_next_interval
//   session.ch    — ReviewSession, start_review_session, get_current_item, advance_session
//   weakness.ch   — WeaknessReport, detect_weaknesses, suggest_repair
//   queue.ch      — ReviewQueue, build_review_queue, get_next_review_items
//   health.ch     — KnowledgeHealth, compute_knowledge_health
//   utils.ch      — f64_to_string

public namespace underlayer_learning {
    public const RATING_AGAIN : int = 1
    public const RATING_HARD : int = 2
    public const RATING_GOOD : int = 3
    public const RATING_EASY : int = 4
}
