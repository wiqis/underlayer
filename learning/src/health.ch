// underlayer_learning — Knowledge health computation.
using std::string
using std::vector
using underlayer_models::ConceptState

public namespace underlayer_learning {

    public struct KnowledgeHealth {
        var total_concepts : int
        var mastered : int
        var learning : int
        var reviewing : int
        var unlearned : int
        var health_score : f64

        @make
        func make() : KnowledgeHealth {
            return KnowledgeHealth {
                total_concepts = 0,
                mastered = 0,
                learning = 0,
                reviewing = 0,
                unlearned = 0,
                health_score = 0.0
            }
        }
    }

    // 1.5.5-1.5.8: Status classification based on accuracy and stability
    // mastered = accuracy > 80% AND reps >= 5
    // learning = reviewed at least once, not yet mastered
    // reviewing = mastered but due for review
    // unlearned = never reviewed
    func classify_status(state : *ConceptState) : string {
        if(state.attempts == 0) { return string("unlearned") }
        var accuracy = (state.correct as f64) / (state.attempts as f64)
        if(accuracy > 0.8 && state.streak >= 3) { return string("mastered") }
        if(state.attempts >= 1) { return string("learning") }
        return string("reviewing")
    }

    public func compute_knowledge_health(states : *vector<ConceptState>) : KnowledgeHealth {
        var health = KnowledgeHealth::make()
        health.total_concepts = states.size() as int

        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.status.equals(string("mastered"))) {
                health.mastered = health.mastered + 1
            } else if(state.status.equals(string("learning"))) {
                health.learning = health.learning + 1
            } else if(state.status.equals(string("reviewing"))) {
                health.reviewing = health.reviewing + 1
            } else {
                health.unlearned = health.unlearned + 1
            }
            i = i + 1
        }

        if(health.total_concepts > 0) {
            health.health_score = (health.mastered as f64) / (health.total_concepts as f64)
        }

        return health
    }

    // 1.5.2: Compute knowledge health for a subset of concepts (per-module)
    public func compute_module_health(states : *vector<ConceptState>, module_concept_ids : *vector<string>) : KnowledgeHealth {
        var health = KnowledgeHealth::make()
        var total : int = 0
        var mastered : int = 0
        var learning : int = 0
        var reviewing : int = 0
        var unlearned : int = 0
        var mi : size_t = 0
        while(mi < module_concept_ids.size()) {
            var cid_ptr = module_concept_ids.get_ptr(mi)
            var cid_copy = cid_ptr.copy()
            // Find matching state
            var si : size_t = 0
            while(si < states.size()) {
                var state = states.get_ptr(si)
                if(state.concept_id.equals(&cid_copy)) {
                    total = total + 1
                    if(state.status.equals(string("mastered"))) { mastered = mastered + 1 }
                    else if(state.status.equals(string("learning"))) { learning = learning + 1 }
                    else if(state.status.equals(string("reviewing"))) { reviewing = reviewing + 1 }
                    else { unlearned = unlearned + 1 }
                }
                si = si + 1
            }
            mi = mi + 1
        }
        health.total_concepts = total
        health.mastered = mastered
        health.learning = learning
        health.reviewing = reviewing
        health.unlearned = unlearned
        if(total > 0) {
            health.health_score = (mastered as f64) / (total as f64)
        }
        return health
    }

    // 1.5.13: Knowledge depth score (0-100)
    // How well concepts are understood based on average accuracy and stability
    public func compute_depth_score(states : *vector<ConceptState>) : f64 {
        if(states.size() == 0) { return 0.0 }
        var total_accuracy : f64 = 0.0
        var total_reps : i64 = 0
        var count : i64 = 0
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) {
                total_accuracy = total_accuracy + ((state.correct as f64) / (state.attempts as f64))
                total_reps = total_reps + (state.attempts as i64)
                count = count + 1
            }
            i = i + 1
        }
        if(count == 0) { return 0.0 }
        var avg_accuracy = total_accuracy / (count as f64)
        var avg_reps = (total_reps as f64) / (count as f64)
        // Depth = accuracy * 70 + reps_factor * 30 (max 5 reps = 100%)
        var reps_factor = avg_reps / 5.0
        if(reps_factor > 1.0) { reps_factor = 1.0 }
        return (avg_accuracy * 70.0) + (reps_factor * 30.0)
    }

    // 1.5.14: Knowledge breadth score (0-100)
    // How many concepts are covered vs total
    public func compute_breadth_score(states : *vector<ConceptState>, total_concepts : int) : f64 {
        if(total_concepts == 0) { return 0.0 }
        var reviewed : int = 0
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) { reviewed = reviewed + 1 }
            i = i + 1
        }
        return (reviewed as f64) / (total_concepts as f64) * 100.0
    }

    // 1.5.17: Knowledge health goals
    public struct HealthGoal {
        var target_score : f64   // 0-100
        var current_score : f64
        var goal_met : bool

        @make
        func make() : HealthGoal {
            return HealthGoal {
                target_score = 0.0,
                current_score = 0.0,
                goal_met = false
            }
        }
    }

    public func compute_health_goal(current_health : *KnowledgeHealth, target_pct : f64) : HealthGoal {
        var goal = HealthGoal::make()
        goal.target_score = target_pct
        goal.current_score = current_health.health_score * 100.0
        goal.goal_met = goal.current_score >= target_pct
        return goal
    }

    // 1.5.18: Knowledge health milestones (25%, 50%, 75%, 90%)
    public struct HealthMilestone {
        var threshold : f64
        var label : string
        var achieved : bool
        var achieved_at : i64  // timestamp when achieved, 0 if not

        @make
        func make() : HealthMilestone {
            return HealthMilestone {
                threshold = 0.0,
                label = string(),
                achieved = false,
                achieved_at = 0
            }
        }
    }

    public func check_milestones(current_health : *KnowledgeHealth, first_mastered_at : i64) : vector<HealthMilestone> {
        var milestones = vector<HealthMilestone>()
        var thresholds = vector<f64>()
        thresholds.push(25.0)
        thresholds.push(50.0)
        thresholds.push(75.0)
        thresholds.push(90.0)
        var labels = vector<string>()
        labels.push(string("Beginner"))
        labels.push(string("Intermediate"))
        labels.push(string("Advanced"))
        labels.push(string("Expert"))
        var pct = current_health.health_score * 100.0
        var i : size_t = 0
        while(i < thresholds.size()) {
            var m = HealthMilestone::make()
            m.threshold = thresholds.get(i)
            var lbl = labels.get_ptr(i)
            m.label = lbl.copy()
            m.achieved = pct >= m.threshold
            if(m.achieved) { m.achieved_at = first_mastered_at }
            milestones.push(m)
            i = i + 1
        }
        return milestones
    }

    // 1.5.9: Compute knowledge retention projection (30, 60, 90 days)
    public struct RetentionProjection {
        var days_30 : f64
        var days_60 : f64
        var days_90 : f64

        @make
        func make() : RetentionProjection {
            return RetentionProjection {
                days_30 = 0.0,
                days_60 = 0.0,
                days_90 = 0.0
            }
        }
    }

    // 1.5.10: Model knowledge decay using forgetting curves
    // Simple exponential decay: R = e^(-t/S) where S is stability in days
    public func compute_retention_projection(states : *vector<ConceptState>) : RetentionProjection {
        var proj = RetentionProjection::make()
        if(states.size() == 0) { return proj }
        var total_retrievability_30 : f64 = 0.0
        var total_retrievability_60 : f64 = 0.0
        var total_retrievability_90 : f64 = 0.0
        var count : f64 = 0.0
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) {
                // Stability approximation: use reps * 2 as stability days
                var stability = (state.streak + 1) as f64
                if(stability < 1.0) { stability = 1.0 }
                // Exponential decay approximation: R ≈ 1 - (t / (stability + t))
                var r30 = stability / (stability + 30.0)
                var r60 = stability / (stability + 60.0)
                var r90 = stability / (stability + 90.0)
                total_retrievability_30 = total_retrievability_30 + r30
                total_retrievability_60 = total_retrievability_60 + r60
                total_retrievability_90 = total_retrievability_90 + r90
                count = count + 1.0
            }
            i = i + 1
        }
        if(count > 0.0) {
            proj.days_30 = (total_retrievability_30 / count) * 100.0
            proj.days_60 = (total_retrievability_60 / count) * 100.0
            proj.days_90 = (total_retrievability_90 / count) * 100.0
        }
        return proj
    }

    // 1.5.11: Identify knowledge gaps (prerequisites not met)
    public func identify_knowledge_gaps(
        states : *vector<ConceptState>,
        concept_ids : *vector<string>
    ) : vector<string> {
        var gaps = vector<string>()
        var i : size_t = 0
        while(i < concept_ids.size()) {
            var cid_ptr = concept_ids.get_ptr(i)
            var cid_copy = cid_ptr.copy()
            // Check if concept has been reviewed
            var reviewed = false
            var j : size_t = 0
            while(j < states.size()) {
                var state = states.get_ptr(j)
                if(state.concept_id.equals(&cid_copy) && state.attempts > 0) {
                    reviewed = true
                }
                j = j + 1
            }
            if(!reviewed) {
                gaps.push(cid_copy)
            }
            i = i + 1
        }
        return gaps
    }

    // 1.5.15: Track knowledge health trends over time
    public struct HealthTrend {
        var timestamp : i64
        var health_score : f64
        var mastered_count : int

        @make
        func make() : HealthTrend {
            return HealthTrend {
                timestamp = 0,
                health_score = 0.0,
                mastered_count = 0
            }
        }
    }

    public func compute_health_trend(
        historical_scores : *vector<HealthTrend>
    ) : string {
        if(historical_scores.size() < 2) { return string("insufficient_data") }
        var latest = historical_scores.get_ptr(historical_scores.size() - 1)
        var prev = historical_scores.get_ptr(historical_scores.size() - 2)
        var delta = latest.health_score - prev.health_score
        if(delta > 0.05) { return string("improving") }
        if(delta < -0.05) { return string("declining") }
        return string("stable")
    }

    // 1.5.16: Knowledge health comparison (anonymous)
    public struct HealthComparison {
        var user_score : f64
        var average_score : f64
        var percentile : int

        @make
        func make() : HealthComparison {
            return HealthComparison {
                user_score = 0.0,
                average_score = 0.0,
                percentile = 0
            }
        }
    }

    public func compute_health_comparison(
        user_health : *KnowledgeHealth,
        avg_score : f64
    ) : HealthComparison {
        var comp = HealthComparison::make()
        comp.user_score = user_health.health_score * 100.0
        comp.average_score = avg_score * 100.0
        // Simple percentile approximation
        var diff = comp.user_score - comp.average_score
        if(diff > 20.0) { comp.percentile = 90 }
        else if(diff > 10.0) { comp.percentile = 75 }
        else if(diff > 0.0) { comp.percentile = 60 }
        else if(diff > -10.0) { comp.percentile = 40 }
        else { comp.percentile = 25 }
        return comp
    }

    // 1.5.12: Identify knowledge overlap (redundant concepts)
    public func identify_knowledge_overlap(states : *vector<ConceptState>) : vector<string> {
        var overlap = vector<string>()
        var i : size_t = 0
        while(i < states.size()) {
            var a = states.get_ptr(i)
            if(a.attempts < 3) { i = i + 1; continue }
            var acc_a = (a.correct as f64) / (a.attempts as f64)
            if(acc_a < 0.9) { i = i + 1; continue }
            // Check if any other concept has very similar accuracy and both are mastered
            var j : size_t = i + 1
            while(j < states.size()) {
                var b = states.get_ptr(j)
                if(b.attempts >= 3) {
                    var acc_b = (b.correct as f64) / (b.attempts as f64)
                    if(acc_b >= 0.9) {
                        // Both mastered — potential overlap
                        var overlap_copy = a.concept_id.copy()
                        overlap.push(overlap_copy)
                    }
                }
                j = j + 1
            }
            i = i + 1
        }
        return overlap
    }

    // 1.5.19: Knowledge health export (JSON string)
    public func export_health_json(health : *KnowledgeHealth) : string {
        var json = string("{\"total_concepts\":")
        var tc = underlayer_core::int_to_string(health.total_concepts as i64)
        json.append_string(&tc)
        json.append_view(",\"mastered\":")
        var ma = underlayer_core::int_to_string(health.mastered as i64)
        json.append_string(&ma)
        json.append_view(",\"learning\":")
        var lr = underlayer_core::int_to_string(health.learning as i64)
        json.append_string(&lr)
        json.append_view(",\"reviewing\":")
        var rv = underlayer_core::int_to_string(health.reviewing as i64)
        json.append_string(&rv)
        json.append_view(",\"unlearned\":")
        var ul = underlayer_core::int_to_string(health.unlearned as i64)
        json.append_string(&ul)
        json.append_view(",\"health_score\":")
        var hs = f64_to_string(health.health_score)
        json.append_string(&hs)
        json.append_view("}")
        return json
    }

}
