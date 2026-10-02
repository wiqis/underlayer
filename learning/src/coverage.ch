// underlayer_learning — Course coverage: "how far through the course am I".
//
// WHY THIS FILE EXISTS, and it is the direct answer to a measured defect.
//
// `progress_percentage` on GET /api/progress used to be
// `(health.health_score * 100.0) as i64`, and compute_knowledge_health sets
// health_score = mastered / total_concepts where total_concepts is
// `states.size()` -- the number of concept_states ROWS.  A row only exists
// once the learner has touched the concept, so the denominator is "how many
// concepts have I already touched" and the numerator is "how many of those are
// mastered".  Measured on 2026-10-02: six /api/learning/view calls across
// elf, rvasm and compback left every course at `learning=3` and
// `progress_percentage=0` -- which is arithmetically forced, not a rounding
// artefact: 0/3 is 0, and it stays 0/3 until the learner has answered five
// exercises correctly with a streak, because nothing on the READING path ever
// writes the string "mastered".  A learner who reads the whole course and
// never quizzes sees 0% forever, and a learner who quizzes sees a number
// that jumps from 0 to 100 with nothing in between.
//
// Two different questions were being asked by one number:
//
//   * "how much of the course have I been through?"  -> COVERAGE.
//     touched / course_total.  Moves on the first read.
//   * "how much of it do I actually know?"           -> MASTERY.
//     mastered / touched.  Moves only on retrieval practice.
//
// They are reported as `progress_percentage` and `mastery_percentage`
// respectively, and they are not the same field.  The old value is still
// available, under the name that says what it is.
//
// THE DENOMINATOR IS THE MANIFEST, NOT THE DATABASE.  concepts_total comes
// from the course manifest (`course.concepts.size()`), because a denominator
// made of the rows the learner has already created is a denominator that grows
// as they study and therefore cannot ever report completion.  When the
// manifest is unavailable (a course id with no manifest) the honest fallback
// is the row count itself, and started is clamped to it, so the number stays
// inside 0..100 instead of exceeding it.
using std::string
using std::vector
using underlayer_models::ConceptState

public namespace underlayer_learning {

    public struct CourseCoverage {
        var course_id : string
        var concepts_total : int
        var concepts_started : int
        var concepts_mastered : int
        var concepts_due : int
        var progress_percentage : int
        var mastery_percentage : int
        var source_total : string     // "manifest" or "states" — which denominator

        @make
        func make() : CourseCoverage {
            return CourseCoverage {
                course_id = string(),
                concepts_total = 0,
                concepts_started = 0,
                concepts_mastered = 0,
                concepts_due = 0,
                progress_percentage = 0,
                mastery_percentage = 0,
                source_total = string("states")
            }
        }
    }

    public func pct_of(part : int, whole : int) : int {
        if(whole <= 0) { return 0 }
        var p = (part * 100) / whole
        if(p < 0) { return 0 }
        if(p > 100) { return 100 }
        return p
    }

    // concepts_total_from_manifest: how many concepts the course actually has.
    // Passed in rather than read here because the manifest loader lives in
    // repository/ and learning/ is below web/ but must not depend on it.
    public func compute_course_coverage(
        course_id : &string,
        states : *vector<ConceptState>,
        concepts_total_from_manifest : int
    ) : CourseCoverage {
        var cov = CourseCoverage::make()
        cov.course_id = course_id.copy()
        cov.concepts_started = states.size() as int

        var i : size_t = 0
        while(i < states.size()) {
            var s = states.get_ptr(i)
            if(s.status.equals(string("mastered"))) {
                cov.concepts_mastered = cov.concepts_mastered + 1
            }
            if(s.next_review > 0) {
                if(s.next_review <= underlayer_core::current_timestamp()) {
                    cov.concepts_due = cov.concepts_due + 1
                }
            }
            i = i + 1
        }

        if(concepts_total_from_manifest > 0) {
            cov.concepts_total = concepts_total_from_manifest
            cov.source_total = string("manifest")
        } else {
            cov.concepts_total = cov.concepts_started
            cov.source_total = string("states")
        }
        if(cov.concepts_started > cov.concepts_total) {
            cov.concepts_started = cov.concepts_total
        }
        if(cov.concepts_mastered > cov.concepts_started) {
            cov.concepts_mastered = cov.concepts_started
        }

        cov.progress_percentage = pct_of(cov.concepts_started, cov.concepts_total)
        cov.mastery_percentage = pct_of(cov.concepts_mastered, cov.concepts_started)
        return cov
    }

}