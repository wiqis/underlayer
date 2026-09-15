// underlayer_models — plain domain structs (no business logic)
// These are the data structures shared across all layers.
using std::string
using std::vector

public namespace underlayer_models {

    // ---- Course writing features (2.1.9-2.1.20) ----

    // 2.1.9: Alternative path through content
    public struct BranchPath {
        var from_concept : string
        var to_concept : string
        var condition : string     // e.g., "mastery < 0.5"
        var description : string

        @make
        func make() : BranchPath {
            return BranchPath {
                from_concept = string(),
                to_concept = string(),
                condition = string(),
                description = string()
            }
        }
    }

    // 2.1.10: Multiple courses as one package
    public struct CourseBundle {
        var id : string
        var title : string
        var course_ids : vector<string>

        @make
        func make() : CourseBundle {
            return CourseBundle {
                id = string(),
                title = string(),
                course_ids = vector<string>()
            }
        }
    }

    // 2.1.14: Course assets declaration
    public struct CourseAsset {
        var id : string
        var asset_type : string    // image, sample, data, binary
        var path : string
        var description : string
        var concept_id : string    // which concept uses this asset

        @make
        func make() : CourseAsset {
            return CourseAsset {
                id = string(),
                asset_type = string(),
                path = string(),
                description = string(),
                concept_id = string()
            }
        }
    }

    // 2.1.15: Review items declaration (per concept)
    public struct ReviewItemDecl {
        var concept_id : string
        var item_type : string     // recall, recognize, apply, explain
        var front : string
        var back : string
        var difficulty : f64

        @make
        func make() : ReviewItemDecl {
            return ReviewItemDecl {
                concept_id = string(),
                item_type = string("recall"),
                front = string(),
                back = string(),
                difficulty = 0.5
            }
        }
    }

    // 2.1.16: Exercises declaration (per concept)
    public struct ExerciseDecl {
        var concept_id : string
        var exercise_type : string   // recall, recognize, apply, explain, multi_recognize, fill_blank, true_false, matching
        var question : string
        var answer : string
        var options : vector<string>
        var correct_index : int
        var explanation : string
        var difficulty : f64

        @make
        func make() : ExerciseDecl {
            return ExerciseDecl {
                concept_id = string(),
                exercise_type = string("recall"),
                question = string(),
                answer = string(),
                options = vector<string>(),
                correct_index = 0,
                explanation = string(),
                difficulty = 0.5
            }
        }
    }

    // 2.1.17: Visualizations declaration (per concept)
    public struct VisualizationDecl {
        var concept_id : string
        var vis_type : string       // hex_viewer, memory_map, header_dump, struct_layout, graph
        var title : string
        var data_source : string    // "elf_header", "section_table", "custom"
        var config : string         // JSON config for the visualization

        @make
        func make() : VisualizationDecl {
            return VisualizationDecl {
                concept_id = string(),
                vis_type = string(),
                title = string(),
                data_source = string(),
                config = string()
            }
        }
    }

    // 2.1.20: Course certificate template
    public struct CertificateConfig {
        var template_id : string
        var badge_url : string
        var title : string
        var description : string
        var criteria : string       // completion criteria text

        @make
        func make() : CertificateConfig {
            return CertificateConfig {
                template_id = string(),
                badge_url = string(),
                title = string(),
                description = string(),
                criteria = string()
            }
        }
    }

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
        // 2.1.9: Course branching
        var branching : bool
        var alternative_paths : vector<BranchPath>
        // 2.1.10: Course bundling
        var bundles : vector<CourseBundle>
        // 2.1.13: Minimum platform version
        var min_platform_version : string
        // 2.1.14: Course assets
        var assets : vector<CourseAsset>
        // 2.1.15: Review items declaration
        var review_item_decls : vector<ReviewItemDecl>
        // 2.1.16: Exercises declaration
        var exercise_decls : vector<ExerciseDecl>
        // 2.1.17: Visualizations declaration
        var visualization_decls : vector<VisualizationDecl>
        // 2.1.18: Navigation structure (linear or tree)
        var navigation : string
        // 2.1.20: Certificate configuration
        var certificate : CertificateConfig

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
                concepts = vector<ConceptRef>(),
                branching = false,
                alternative_paths = vector<BranchPath>(),
                bundles = vector<CourseBundle>(),
                min_platform_version = string("1.0"),
                assets = vector<CourseAsset>(),
                review_item_decls = vector<ReviewItemDecl>(),
                exercise_decls = vector<ExerciseDecl>(),
                visualization_decls = vector<VisualizationDecl>(),
                navigation = string("linear"),
                certificate = CertificateConfig::make()
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
        // 2.1.9-2.1.20: Extended manifest fields
        var branching : bool
        var alternative_paths : vector<BranchPath>
        var bundles : vector<CourseBundle>
        var min_platform_version : string
        var assets : vector<CourseAsset>
        var review_item_decls : vector<ReviewItemDecl>
        var exercise_decls : vector<ExerciseDecl>
        var visualization_decls : vector<VisualizationDecl>
        var navigation : string
        var certificate : CertificateConfig

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
                language = string("en"),
                branching = false,
                alternative_paths = vector<BranchPath>(),
                bundles = vector<CourseBundle>(),
                min_platform_version = string("1.0"),
                assets = vector<CourseAsset>(),
                review_item_decls = vector<ReviewItemDecl>(),
                exercise_decls = vector<ExerciseDecl>(),
                visualization_decls = vector<VisualizationDecl>(),
                navigation = string("linear"),
                certificate = CertificateConfig::make()
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

    // ---- AggregateStats (cross-learner aggregation for anonymous comparison) ----
    public struct AggregateStats {
        var total_attempts : i64
        var total_correct : i64
        var learner_count : i64
        var accuracy : f64
        var average_severity : f64

        @make
        func make() : AggregateStats {
            return AggregateStats {
                total_attempts = 0,
                total_correct = 0,
                learner_count = 0,
                accuracy = 0.0,
                average_severity = 0.0
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

    // ---- Account management models (Section 16) ----

    // 16.5: Learner profile
    public struct LearnerProfile {
        var learner_id : string
        var display_name : string
        var username : string
        var avatar_url : string
        var bio : string
        var learning_goals : string
        var location : string
        var website : string
        var social_twitter : string
        var social_github : string
        var social_linkedin : string
        var visibility : string    // public, private, anonymous
        var username_changed_at : i64

        @make func make() : LearnerProfile {
            return LearnerProfile {
                learner_id = string(), display_name = string(), username = string(),
                avatar_url = string(), bio = string(), learning_goals = string(),
                location = string(), website = string(),
                social_twitter = string(), social_github = string(), social_linkedin = string(),
                visibility = string("public"), username_changed_at = 0
            }
        }
    }

    // 16.6: Learner settings
    public struct LearnerSettings {
        var learner_id : string
        var theme : string          // light, dark, system
        var font_size : string      // small, medium, large
        var language : string
        var timezone : string
        var date_format : string    // MM/DD/YYYY, DD/MM/YYYY, YYYY-MM-DD
        var email_notifications : bool
        var push_notifications : bool
        var in_app_notifications : bool
        var compact_mode : bool

        @make func make() : LearnerSettings {
            return LearnerSettings {
                learner_id = string(), theme = string("system"), font_size = string("medium"),
                language = string("en"), timezone = string("UTC"), date_format = string("YYYY-MM-DD"),
                email_notifications = true, push_notifications = true,
                in_app_notifications = true, compact_mode = false
            }
        }
    }

    // 16.7: Learning preferences
    public struct LearningPreferences {
        var learner_id : string
        var daily_goal_minutes : int
        var daily_review_items : int
        var session_length_minutes : int
        var break_reminder_minutes : int
        var preferred_session_time : string   // morning, afternoon, evening, flexible
        var energy_checkin : bool
        var difficulty_preference : string    // easy, normal, hard, auto
        var interleaving_preference : string  // blocked, interleaved, auto
        var review_scheduling : string        // morning, evening, flexible
        var show_streaks : bool
        var show_leaderboards : bool
        var show_achievements : bool
        var auto_play_audio : bool

        @make func make() : LearningPreferences {
            return LearningPreferences {
                learner_id = string(), daily_goal_minutes = 20, daily_review_items = 10,
                session_length_minutes = 30, break_reminder_minutes = 25,
                preferred_session_time = string("flexible"), energy_checkin = true,
                difficulty_preference = string("auto"), interleaving_preference = string("auto"),
                review_scheduling = string("flexible"), show_streaks = true,
                show_leaderboards = true, show_achievements = true, auto_play_audio = false
            }
        }
    }

    // 16.10.1: Login history entry
    public struct LoginHistoryEntry {
        var id : i64
        var learner_id : string
        var ip_address : string
        var user_agent : string
        var success : bool
        var failure_reason : string

        @make func make() : LoginHistoryEntry {
            return LoginHistoryEntry {
                id = 0, learner_id = string(), ip_address = string(),
                user_agent = string(), success = true, failure_reason = string()
            }
        }
    }

    // 16.2.14: Auth session (JWT)
    public struct AuthSession {
        var id : string
        var learner_id : string
        var token_hash : string
        var device_info : string
        var ip_address : string
        var expires_at : i64
        var last_active : i64

        @make func make() : AuthSession {
            return AuthSession {
                id = string(), learner_id = string(), token_hash = string(),
                device_info = string(), ip_address = string(),
                expires_at = 0, last_active = 0
            }
        }
    }

    // 16.3.3: Password reset token
    public struct PasswordResetToken {
        var id : string
        var learner_id : string
        var token_hash : string
        var expires_at : i64
        var used : bool

        @make func make() : PasswordResetToken {
            return PasswordResetToken {
                id = string(), learner_id = string(), token_hash = string(),
                expires_at = 0, used = false
            }
        }
    }

    // 16.4.2: Email verification token
    public struct EmailVerificationToken {
        var id : string
        var learner_id : string
        var email : string
        var token_hash : string
        var expires_at : i64
        var used : bool

        @make func make() : EmailVerificationToken {
            return EmailVerificationToken {
                id = string(), learner_id = string(), email = string(),
                token_hash = string(), expires_at = 0, used = false
            }
        }
    }

    // 16.10.7: API key
    public struct ApiKey {
        var id : string
        var learner_id : string
        var key_hash : string
        var name : string
        var last_used_at : i64
        var expires_at : i64

        @make func make() : ApiKey {
            return ApiKey {
                id = string(), learner_id = string(), key_hash = string(),
                name = string(), last_used_at = 0, expires_at = 0
            }
        }
    }

    // 16.10.14: Audit log entry
    public struct AuditLogEntry {
        var id : i64
        var learner_id : string
        var action : string
        var details : string
        var ip_address : string

        @make func make() : AuditLogEntry {
            return AuditLogEntry {
                id = 0, learner_id = string(), action = string(),
                details = string(), ip_address = string()
            }
        }
    }
}
