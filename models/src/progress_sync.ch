// underlayer_models — the wire/repository shape for mobile progress sync.
//
// One row per (learner, course, concept, unit).  This is deliberately NOT a
// ConceptState: that table is keyed per concept and carries the FSRS columns,
// which a client must never write.  Keeping the unit-level journey state in its
// own struct is what makes it structurally impossible for a sync write to zero
// stability / reps / next_review the way /api/progress/import does.
using std::string

public namespace underlayer_models {

    public struct UnitProgress {
        var learner_id : string
        var course_id : string
        var concept_id : string
        var unit_id : string
        var status : string      // seen | retrieved | mastered (client-chosen text)
        var step_index : i64
        var updated_at : i64     // unix seconds, client clock; LWW key

        @make
        func make() : UnitProgress {
            return UnitProgress {
                learner_id = string(),
                course_id = string(),
                concept_id = string(),
                unit_id = string(),
                status = string(),
                step_index = 0,
                updated_at = 0
            }
        }
    }

}
