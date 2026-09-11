// underlayer_models — plain domain structs (no business logic)
// These are the data structures shared across all layers.
using std::string
using std::vector

public namespace underlayer_models {

    // ---- Course ----
    public struct Course {
        var id : string
        var title : string
        var version : int
        var modules : vector<Module>
        var concepts : vector<ConceptRef>

        @make
        func make() : Course {
            return Course {
                id = string(),
                title = string(),
                version = 1,
                modules = vector<Module>(),
                concepts = vector<ConceptRef>()
            }
        }
    }

    public struct Module {
        var id : string
        var title : string
        var concepts : vector<string>
        var order : int

        @make
        func make() : Module {
            return Module {
                id = string(),
                title = string(),
                concepts = vector<string>(),
                order = 0
            }
        }
    }

    // Lightweight concept reference (used in course listing)
    public struct ConceptRef {
        var id : string
        var module_id : string
        var title : string
        var description : string

        @make
        func make() : ConceptRef {
            return ConceptRef {
                id = string(),
                module_id = string(),
                title = string(),
                description = string()
            }
        }
    }

    // ---- Concept (full) ----
    public struct Concept {
        var id : string
        var module_id : string
        var title : string
        var description : string
        var prerequisites : vector<string>
        var estimated_minutes : int

        @make
        func make() : Concept {
            return Concept {
                id = string(),
                module_id = string(),
                title = string(),
                description = string(),
                prerequisites = vector<string>(),
                estimated_minutes = 10
            }
        }
    }

    // ---- Manifest ----
    public struct Manifest {
        var id : string
        var title : string
        var version : int
        var description : string
        var prerequisites : vector<string>

        @make
        func make() : Manifest {
            return Manifest {
                id = string(),
                title = string(),
                version = 1,
                description = string(),
                prerequisites = vector<string>()
            }
        }
    }

    // ---- Learner ----
    public struct Learner {
        var id : string
        var name : string
        var email : string
        var created_at : i64

        @make
        func make() : Learner {
            return Learner {
                id = string(),
                name = string(),
                email = string(),
                created_at = 0
            }
        }
    }

    // ---- ConceptState (per-learner per-concept) ----
    public struct ConceptState {
        var learner_id : string
        var concept_id : string
        var course_id : string
        var status : string   // not_started, learning, reviewing, mastered
        var attempts : int
        var correct : int
        var streak : int
        var last_studied : i64
        var next_review : i64
        var difficulty_rating : f64

        @make
        func make() : ConceptState {
            return ConceptState {
                learner_id = string(),
                concept_id = string(),
                course_id = string(),
                status = string("not_started"),
                attempts = 0,
                correct = 0,
                streak = 0,
                last_studied = 0,
                next_review = 0,
                difficulty_rating = 0.0
            }
        }
    }

    // ---- ReviewItem ----
    public struct ReviewItem {
        var id : string
        var learner_id : string
        var concept_id : string
        var course_id : string
        var item_type : string   // recall, recognize, apply, explain
        var front : string
        var back : string
        var difficulty : f64
        var stability : f64
        var retrievability : f64
        var next_review : i64
        var last_review : i64
        var reps : int
        var lapses : int

        @make
        func make() : ReviewItem {
            return ReviewItem {
                id = string(),
                learner_id = string(),
                concept_id = string(),
                course_id = string(),
                item_type = string("recall"),
                front = string(),
                back = string(),
                difficulty = 5.0,
                stability = 1.0,
                retrievability = 1.0,
                next_review = 0,
                last_review = 0,
                reps = 0,
                lapses = 0
            }
        }
    }

    // ---- Session ----
    public struct Session {
        var id : string
        var learner_id : string
        var start_time : i64
        var end_time : i64
        var session_type : string   // learn, review, mixed
        var exercises_attempted : int
        var exercises_correct : int

        @make
        func make() : Session {
            return Session {
                id = string(),
                learner_id = string(),
                start_time = 0,
                end_time = 0,
                session_type = string("learn"),
                exercises_attempted = 0,
                exercises_correct = 0
            }
        }
    }
}
