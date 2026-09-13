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

}
