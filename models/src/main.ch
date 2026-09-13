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
        var description : string
        var author : string
        var license : string
        var language : string
        var difficulty : string     // beginner, intermediate, advanced
        var importance : string     // core, important, supplementary
        var dependencies : vector<string>  // 2.1.12: requires other courses
        var completion_criteria : string    // 2.1.19: all_concepts or min_score
        var min_score : f64                // 2.1.19: minimum score for completion
        var modules : vector<Module>
        var concepts : vector<ConceptRef>

        @make
        func make() : Course {
            return Course {
                id = string(),
                title = string(),
                version = 1,
                description = string(),
                author = string(),
                license = string(),
                language = string("en"),
                difficulty = string("intermediate"),
                importance = string("core"),
                dependencies = vector<string>(),
                completion_criteria = string("all_concepts"),
                min_score = 0.0,
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
        var estimated_minutes : int
        var difficulty : string     // beginner, intermediate, advanced
        var importance : string     // core, important, supplementary
        var prerequisites : vector<string>

        @make
        func make() : ConceptRef {
            return ConceptRef {
                id = string(),
                module_id = string(),
                title = string(),
                description = string(),
                estimated_minutes = 10,
                difficulty = string("intermediate"),
                importance = string("core"),
                prerequisites = vector<string>()
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
        var difficulty : string     // beginner, intermediate, advanced
        var importance : string     // core, important, supplementary
        var estimated_minutes : int
        var author : string
        var license : string
        var language : string

        @make
        func make() : Manifest {
            return Manifest {
                id = string(),
                title = string(),
                version = 1,
                description = string(),
                prerequisites = vector<string>(),
                difficulty = string("intermediate"),
                importance = string("core"),
                estimated_minutes = 0,
                author = string(),
                license = string(),
                language = string("en")
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
        var ease_factor : f64    // 1.1.15: per-item ease factor

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
                lapses = 0,
                ease_factor = 2.5
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

    // ---- ExerciseType (how the learner interacts) ----
    public struct ExerciseType {
        var id : string
        var label : string
        var description : string

        @make
        func make() : ExerciseType {
            return ExerciseType {
                id = string(),
                label = string(),
                description = string()
            }
        }
    }

    // Standard exercise types
    public func exercise_type_recall() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("recall")
        t.label = string("Free Recall")
        t.description = string("Answer from memory without hints.")
        return t
    }

    public func exercise_type_recognize() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("recognize")
        t.label = string("Recognition")
        t.description = string("Choose the correct answer from options.")
        return t
    }

    public func exercise_type_apply() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("apply")
        t.label = string("Apply")
        t.description = string("Use the knowledge to solve a problem.")
        return t
    }

    public func exercise_type_explain() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("explain")
        t.label = string("Explain")
        t.description = string("Explain a concept in your own words.")
        return t
    }

    public func exercise_type_multi_recognize() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("multi_recognize")
        t.label = string("Multi-Select")
        t.description = string("Select all correct answers from options.")
        return t
    }

    // 4.1.8: Fill in the blank
    public func exercise_type_fill_blank() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("fill_blank")
        t.label = string("Fill in the Blank")
        t.description = string("Complete a sentence or code block by filling in the missing part.")
        return t
    }

    // 4.1.10: True/False
    public func exercise_type_true_false() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("true_false")
        t.label = string("True or False")
        t.description = string("Determine whether a statement is true or false.")
        return t
    }

    // 4.1.12: Matching
    public func exercise_type_matching() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("matching")
        t.label = string("Matching")
        t.description = string("Match terms to their definitions or code to output.")
        return t
    }

    // ---- Exercise (a single question/task) ----
    public struct Exercise {
        var id : string
        var concept_id : string
        var exercise_type : ExerciseType
        var question : string
        var answer : string
        var options : vector<string>    // for recognize type: the choices
        var correct_index : int         // index into options for recognize type
        var correct_indices : vector<int>  // for multi_recognize: multiple correct indices
        var explanation : string        // shown after answering (4.2.2, 4.2.3)
        var hint1 : string              // 4.2.4/4.2.5: conceptual hint
        var hint2 : string              // 4.2.4: directional hint
        var hint3 : string              // 4.2.4: almost answer
        var difficulty : float          // 0.0 (easy) to 1.0 (hard)

        @make
        func make() : Exercise {
            return Exercise {
                id = string(),
                concept_id = string(),
                exercise_type = ExerciseType::make(),
                question = string(),
                answer = string(),
                options = vector<string>(),
                correct_index = 0,
                correct_indices = vector<int>(),
                explanation = string(),
                hint1 = string(),
                hint2 = string(),
                hint3 = string(),
                difficulty = 0.5f
            }
        }
    }
}
