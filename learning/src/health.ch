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

}
