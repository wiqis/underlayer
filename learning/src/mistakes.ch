// underlayer_learning — Mistake pattern detection (P2 4.2.16) and
// personalized feedback (P2 4.2.17).
// Pattern classification from ConceptState attempt history:
//   consistent_failure — accuracy < 30% with 3+ attempts (needs re-teaching)
//   intermittent       — accuracy 30%..60% with 3+ attempts (needs more reps)
//   streak_reset       — accuracy >= 60% but streak == 0 with 3+ attempts
//   no_pattern         — not enough signal (never returned by detect)
using std::string
using std::vector
using underlayer_models::ConceptState

public namespace underlayer_learning {

    public struct MistakePattern {
        var concept_id : string
        var pattern : string   // "consistent_failure", "intermittent", "streak_reset", "no_pattern"
        var occurrences : int  // number of wrong answers (attempts - correct)
        var confidence : int   // 0-100: how strongly the data supports the pattern

        @make
        func make() : MistakePattern {
            return MistakePattern {
                concept_id = string(),
                pattern = string(),
                occurrences = 0,
                confidence = 0
            }
        }
    }

    // Classify one concept state. Returns "no_pattern" when there is not
    // enough signal (fewer than 3 attempts, or accuracy high with streak intact).
    public func classify_mistake_pattern(state : *ConceptState) : string {
        if(state.attempts < 3) { return string("no_pattern") }
        var accuracy = (state.correct as f64) / (state.attempts as f64)
        // P2 4.2.16: consistent failure — keeps getting it wrong
        if(accuracy < 0.3) { return string("consistent_failure") }
        // Right sometimes, wrong sometimes — unstable retrieval
        if(accuracy < 0.6) { return string("intermittent") }
        // Knows it most of the time but just lapsed
        if(state.streak == 0) { return string("streak_reset") }
        return string("no_pattern")
    }

    // Detect mistake patterns across all concept states.
    // Only concepts with a real pattern are included (no_pattern is skipped).
    public func detect_mistake_patterns(states : *vector<ConceptState>) : vector<MistakePattern> {
        var patterns = vector<MistakePattern>()
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) {
                var kind = classify_mistake_pattern(state)
                var none = string("no_pattern")
                if(!kind.equals(&none)) {
                    var p = MistakePattern::make()
                    p.concept_id = state.concept_id.copy()
                    p.pattern = kind
                    p.occurrences = state.attempts - state.correct
                    // Confidence: share of attempts that were mistakes
                    var conf = ((p.occurrences * 100) / state.attempts)
                    if(conf < 0) { conf = 0 }
                    if(conf > 100) { conf = 100 }
                    p.confidence = conf
                    patterns.push(p)
                }
            }
            i = i + 1
        }
        return patterns
    }

    // P2 4.2.17: Personalized feedback text tailored to the mistake pattern.
    // Returns an empty string when there is no pattern to act on.
    public func personalized_feedback(pattern : *MistakePattern) : string {
        var cf = string("consistent_failure")
        var it = string("intermittent")
        var sr = string("streak_reset")

        if(pattern.pattern.equals(&cf)) {
            var msg = string("You keep missing '")
            msg.append_string(&pattern.concept_id)
            msg.append_view("' (")
            var occ = int_to_string_local(pattern.occurrences)
            msg.append_string(&occ)
            msg.append_view(" mistakes). This concept needs re-teaching, not more reps — go back to the lesson and re-read the core model before your next review.")
            return msg
        }
        if(pattern.pattern.equals(&it)) {
            var msg = string("'")
            msg.append_string(&pattern.concept_id)
            msg.append_view("' is unstable — sometimes right, sometimes wrong. More focused practice will steady it: try a targeted review on just this concept.")
            return msg
        }
        if(pattern.pattern.equals(&sr)) {
            var msg = string("Your streak on '")
            msg.append_string(&pattern.concept_id)
            msg.append_view("' just reset. You clearly know most of this — one careful review should get you back on track.")
            return msg
        }
        return string()
    }

    // Small local helper so this file does not depend on call ordering.
    func int_to_string_local(v : int) : string {
        var out = underlayer_core::int_to_string(v as i64)
        return out
    }

}
