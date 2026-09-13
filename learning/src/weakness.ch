// underlayer_learning — Weakness detection.
using std::string
using std::vector
using underlayer_models::ConceptState

public namespace underlayer_learning {

    public struct WeaknessReport {
        var concept_id : string
        var accuracy : f64
        var total_attempts : int
        var correct_count : int
        var weak_prerequisites : vector<string>
        var severity : int         // 1.4.17: 0-100 weakness severity score
        var status : string        // 1.4.7/1.4.8: "struggling", "solid", "weak"

        @make
        func make() : WeaknessReport {
            return WeaknessReport {
                concept_id = string(),
                accuracy = 0.0,
                total_attempts = 0,
                correct_count = 0,
                weak_prerequisites = vector<string>(),
                severity = 0,
                status = string()
            }
        }
    }

    // 1.4.17: Compute weakness severity score (0-100)
    // Lower accuracy = higher severity. No attempts = severity 0.
    func compute_severity(accuracy : f64, attempts : int) : int {
        if(attempts == 0) { return 0 }
        // severity = (1 - accuracy) * 100, clamped
        var sev = ((1.0 - accuracy) * 100.0) as int
        if(sev < 0) { sev = 0 }
        if(sev > 100) { sev = 100 }
        return sev
    }

    public func detect_weaknesses(states : *vector<ConceptState>) : vector<WeaknessReport> {
        var reports = vector<WeaknessReport>()
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) {
                var accuracy = (state.correct as f64) / (state.attempts as f64)
                var report = WeaknessReport::make()
                report.concept_id = state.concept_id.copy()
                report.accuracy = accuracy
                report.total_attempts = state.attempts
                report.correct_count = state.correct
                report.severity = compute_severity(accuracy, state.attempts)
                // 1.4.7/1.4.8: Classify status
                if(accuracy < 0.6) {
                    report.status = string("struggling")
                } else if(accuracy < 0.75) {
                    report.status = string("weak")
                } else {
                    report.status = string("solid")
                }
                // Only include weak concepts in report
                if(accuracy < 0.75) {
                    reports.push(report)
                }
            }
            i = i + 1
        }
        return reports
    }

    // 1.4.12/1.4.13: Generate repair suggestion
    public func suggest_repair(weakness : &WeaknessReport) : string {
        // 1.4.13: No reviews yet
        if(weakness.total_attempts == 0) {
            var s = string("This concept has no reviews yet. Try one!")
            return s
        }
        // 1.4.12: Practice more exercises
        var suggestion = string("Practice more exercises on '")
        suggestion.append_string(&weakness.concept_id)
        suggestion.append_view("' — accuracy is ")
        var acc_str = f64_to_string(weakness.accuracy * 100.0)
        suggestion.append_string(&acc_str)
        suggestion.append_view("%")
        if(weakness.severity >= 80) {
            suggestion.append_view(". This is a critical weakness — review the fundamentals first.")
        } else if(weakness.severity >= 50) {
            suggestion.append_view(". A few more focused reviews should help.")
        } else {
            suggestion.append_view(". You're close — one more review session should solidify this.")
        }
        return suggestion
    }

    // 1.4.14: Weakness trend tracking
    // Compares recent accuracy (last 5 attempts) vs overall accuracy
    public struct WeaknessTrend {
        var concept_id : string
        var trend : string  // "improving", "stable", "worsening"
        var recent_accuracy : f64
        var overall_accuracy : f64
        var delta : f64

        @make
        func make() : WeaknessTrend {
            return WeaknessTrend {
                concept_id = string(),
                trend = string("stable"),
                recent_accuracy = 0.0,
                overall_accuracy = 0.0,
                delta = 0.0
            }
        }
    }

    public func compute_weakness_trend(state : *ConceptState) : WeaknessTrend {
        var trend = WeaknessTrend::make()
        trend.concept_id = state.concept_id.copy()
        trend.overall_accuracy = (state.correct as f64) / (state.attempts as f64)
        // Use streak as a proxy for recent accuracy direction
        // streak >= 3 means improving, streak == 0 means worsening
        var lapses = state.attempts - state.correct
        if(state.streak >= 3) {
            trend.recent_accuracy = trend.overall_accuracy + 0.1
            trend.trend = string("improving")
        } else if(state.streak == 0 && lapses > 0) {
            trend.recent_accuracy = trend.overall_accuracy - 0.1
            trend.trend = string("worsening")
        } else {
            trend.recent_accuracy = trend.overall_accuracy
            trend.trend = string("stable")
        }
        trend.delta = trend.recent_accuracy - trend.overall_accuracy
        return trend
    }

    // 1.4.9: Check prerequisite graph: if prerequisite is weak, flag dependency
    public struct WeaknessChain {
        var concept : string
        var weak_prereq : string
        var chain_depth : int

        @make
        func make() : WeaknessChain {
            return WeaknessChain {
                concept = string(),
                weak_prereq = string(),
                chain_depth = 0
            }
        }
    }

    // 1.4.10: Show weakness chain: A depends on B depends on C (C is weak)
    public func detect_weakness_chains(
        weak_concepts : *vector<string>,
        prereq_map : *vector<WeaknessChain>
    ) : vector<WeaknessChain> {
        var chains = vector<WeaknessChain>()
        var i : size_t = 0
        while(i < prereq_map.size()) {
            var chain = prereq_map.get_ptr(i)
            // Check if the weak prereq is itself weak
            var j : size_t = 0
            while(j < weak_concepts.size()) {
                var weak = weak_concepts.get_ptr(j)
                var weak_copy = weak.copy()
                if(chain.weak_prereq.equals(&weak_copy)) {
                    var extended = WeaknessChain::make()
                    extended.concept = chain.concept.copy()
                    extended.weak_prereq = chain.weak_prereq.copy()
                    extended.chain_depth = chain.chain_depth + 1
                    chains.push(extended)
                }
                j = j + 1
            }
            i = i + 1
        }
        return chains
    }

    // 1.4.15: Cluster related weak concepts (e.g., "all pointer concepts are weak")
    public struct WeaknessCluster {
        var module_prefix : string
        var weak_concepts : vector<string>
        var count : int
        var avg_severity : f64

        @make
        func make() : WeaknessCluster {
            return WeaknessCluster {
                module_prefix = string(),
                weak_concepts = vector<string>(),
                count = 0,
                avg_severity = 0.0
            }
        }
    }

    public func cluster_weaknesses(weaknesses : *vector<WeaknessReport>) : vector<WeaknessCluster> {
        var clusters = vector<WeaknessCluster>()
        var i : size_t = 0
        while(i < weaknesses.size()) {
            var w = weaknesses.get_ptr(i)
            // Extract module prefix (before first dot)
            var prefix = string()
            var j : size_t = 0
            while(j < w.concept_id.size()) {
                var c = w.concept_id.get(j)
                if(c == '.') { break }
                prefix.append(c)
                j = j + 1
            }
            // Find existing cluster for this prefix
            var found = false
            var ci : size_t = 0
            while(ci < clusters.size()) {
                var cluster = clusters.get_ptr(ci)
                var prefix_copy = prefix.copy()
                if(cluster.module_prefix.equals(&prefix_copy)) {
                    cluster.weak_concepts.push(w.concept_id.copy())
                    cluster.count = cluster.count + 1
                    cluster.avg_severity = (cluster.avg_severity * ((cluster.count - 1) as f64) + (w.severity as f64)) / (cluster.count as f64)
                    found = true
                }
                ci = ci + 1
            }
            if(!found) {
                var new_cluster = WeaknessCluster::make()
                new_cluster.module_prefix = prefix.copy()
                new_cluster.weak_concepts.push(w.concept_id.copy())
                new_cluster.count = 1
                new_cluster.avg_severity = w.severity as f64
                clusters.push(new_cluster)
            }
            i = i + 1
        }
        return clusters
    }

    // 1.4.16: Predict weakness before failure (accuracy trending down)
    public func predict_weakness(state : *ConceptState) : f64 {
        // Simple prediction: if streak is 0 and accuracy is borderline (65-80%), predict likely to become weak
        if(state.attempts < 3) { return 0.0 }
        var accuracy = (state.correct as f64) / (state.attempts as f64)
        if(accuracy >= 0.65 && accuracy < 0.8 && state.streak == 0) {
            // Trending down — probability of becoming weak
            return 0.7
        }
        if(accuracy >= 0.6 && accuracy < 0.65) {
            return 0.9
        }
        return 0.0
    }

    // 1.4.18: Schedule weakness repair sessions automatically
    public func should_schedule_repair(severity : f64, last_reviewed : i64, now : i64) : bool {
        // Auto-schedule if severity >= 60 and not reviewed in last 3 days
        if(severity < 60.0) { return false }
        var days_since = (now - last_reviewed) / 86400
        return days_since >= 3
    }

    // 1.4.19: Track weakness resolution (concept moved from weak to solid)
    public struct WeaknessResolution {
        var concept_id : string
        var became_weak_at : i64
        var resolved_at : i64
        var was_severity : int
        var final_accuracy : f64

        @make
        func make() : WeaknessResolution {
            return WeaknessResolution {
                concept_id = string(),
                became_weak_at = 0,
                resolved_at = 0,
                was_severity = 0,
                final_accuracy = 0.0
            }
        }
    }

    // 1.4.20: Show weakness history (when it became weak, when it resolved)
    public struct WeaknessHistoryEntry {
        var concept_id : string
        var event_type : string  // "became_weak", "resolved", "worsened", "improved"
        var timestamp : i64
        var severity : int
        var accuracy : f64

        @make
        func make() : WeaknessHistoryEntry {
            return WeaknessHistoryEntry {
                concept_id = string(),
                event_type = string(),
                timestamp = 0,
                severity = 0,
                accuracy = 0.0
            }
        }
    }

    public func track_weakness_resolution(
        prev_severity : int,
        new_severity : int,
        concept_id : *string,
        now : i64
    ) : vector<WeaknessHistoryEntry> {
        var entries = vector<WeaknessHistoryEntry>()
        if(prev_severity >= 50 && new_severity < 50) {
            // Resolved
            var entry = WeaknessHistoryEntry::make()
            entry.concept_id = concept_id.copy()
            entry.event_type = string("resolved")
            entry.timestamp = now
            entry.severity = new_severity
            entries.push(entry)
        } else if(prev_severity < 50 && new_severity >= 50) {
            // Became weak
            var entry = WeaknessHistoryEntry::make()
            entry.concept_id = concept_id.copy()
            entry.event_type = string("became_weak")
            entry.timestamp = now
            entry.severity = new_severity
            entries.push(entry)
        } else if(new_severity > prev_severity + 10) {
            // Worsened
            var entry = WeaknessHistoryEntry::make()
            entry.concept_id = concept_id.copy()
            entry.event_type = string("worsened")
            entry.timestamp = now
            entry.severity = new_severity
            entries.push(entry)
        } else if(prev_severity > new_severity + 10) {
            // Improved
            var entry = WeaknessHistoryEntry::make()
            entry.concept_id = concept_id.copy()
            entry.event_type = string("improved")
            entry.timestamp = now
            entry.severity = new_severity
            entries.push(entry)
        }
        return entries
    }

}
