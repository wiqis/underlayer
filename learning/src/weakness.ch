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

        @make
        func make() : WeaknessReport {
            return WeaknessReport {
                concept_id = string(),
                accuracy = 0.0,
                total_attempts = 0,
                correct_count = 0,
                weak_prerequisites = vector<string>()
            }
        }
    }

    public func detect_weaknesses(states : *vector<ConceptState>) : vector<WeaknessReport> {
        var reports = vector<WeaknessReport>()
        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.attempts > 0) {
                var accuracy = (state.correct as f64) / (state.attempts as f64)
                if(accuracy < 0.7) {
                    var report = WeaknessReport::make()
                    report.concept_id = state.concept_id.copy()
                    report.accuracy = accuracy
                    report.total_attempts = state.attempts
                    report.correct_count = state.correct
                    reports.push(report)
                }
            }
            i = i + 1
        }
        return reports
    }

    public func suggest_repair(weakness : &WeaknessReport) : string {
        var suggestion = string("Review '")
        suggestion.append_string(&weakness.concept_id)
        suggestion.append_view("' — accuracy is ")
        var acc_str = f64_to_string(weakness.accuracy)
        suggestion.append_string(&acc_str)
        suggestion.append_view("%. ")
        if(weakness.accuracy < 0.5) {
            suggestion.append_view("Consider reviewing prerequisites first.")
        } else {
            suggestion.append_view("A few more reviews should help solidify this.")
        }
        return suggestion
    }

}
