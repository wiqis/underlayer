// underlayer_web — the one definition of "this course is finished", used as a
// gate rather than drawn as a decoration.
//
// WHAT WAS HAPPENING.  `POST /api/certificates` asked `has_certificate()` and
// nothing else.  It never asked whether the learner had read the course.  The
// only thing standing between a learner and an unearned certificate was the
// placement of the claim button on the course landing page, and a button's
// position is not a guarantee -- the endpoint is one POST away from anyone.
// Verified before this change: a learner with one concept read in `elf` received
// a certificate, and `/certificates/<id>` then served a page asserting they had
// "successfully completed the course".
//
// WHICH NUMBER IS "COMPLETE".  Not a new one.  `learning/src/coverage.ch`
// already answers "how far through this course am I" as
//
//     progress_percentage = concepts_started * 100 / concepts_total
//
// where `concepts_total` is the count in the course's own manifest, not the
// number of rows the learner happens to have created.  That denominator is the
// whole reason the number can ever reach 100, and it is already the number
// every other part of the platform shows a learner: GET /api/progress reports it,
// the 25/50/75/100 milestones are computed from it, and the claim button in
// content/src/certificate_claim_js.ch appears at `pct >= 100`.  The gate is that
// same expression, so the button and the server cannot disagree -- a button that
// appears means the claim will be accepted, and a button that does not appear
// means the claim will be refused.
//
// WHY COVERAGE AND NOT MASTERY.  Mastery (`mastery_percentage`, mastered over
// started) is the other number coverage.ch exists to separate out, and it moves
// only when retrieval practice marks a concept `mastered`.  A learner who reads
// every lesson and never quizzes has mastered nothing and would be refused a
// certificate for a course they finished -- which is the same defect
// coverage.ch was written to fix, reappearing on the certificate path.  The
// course's own completion criterion is coverage: the claim button's label says
// "Every concept in this course read."
//
// THE THRESHOLD IS >= 100, NOT > 100.  `pct_of` is integer division, so a
// learner who has started every concept in the manifest gets exactly 100, and
// exactly 100 must be allowed to claim.  `>` would refuse the learner who did
// the whole thing.
//
// WHY concepts_total MUST ALSO BE NON-ZERO.  When a course id has no manifest,
// compute_course_coverage falls back to `concepts_started` as the denominator --
// and `pct_of(x, x)` is 100.  So a learner who studied a bogus course id could
// reach 100% of nothing and be handed a certificate for it.  Requiring a
// non-zero manifest count means an unknown course can never be completed,
// which is the honest answer: there is no such course to finish.
using std::string
using underlayer_db::DbClient

public namespace underlayer_web {

    // True when the learner may claim a certificate for `course_id`.  On false
    // the 403 has already been written, with the numbers that caused it, so the
    // page can say "14 of 24 read" instead of "could not issue it".
    public func require_course_complete(
        db : *DbClient,
        courses_dir : &string,
        learner_id : &string,
        course_id : &string,
        res : *mut http::ResponseWriter
    ) : bool {
        var states = underlayer_repository::get_all_concept_states(db, learner_id, course_id)
        var total = manifest_concept_total(courses_dir, course_id)
        var cov = underlayer_learning::compute_course_coverage(course_id, &raw states, total)
        if(cov.concepts_total > 0 && cov.progress_percentage >= 100) { return true }

        // Named locals, not `&underlayer_core::int_to_string(...)` inline:
        // taking the address of a temporary is the shape that
        // tools/check_inline_string_temporaries.py exists to keep out of this
        // tree.
        var started_s = underlayer_core::int_to_string(cov.concepts_started as i64)
        var total_s = underlayer_core::int_to_string(cov.concepts_total as i64)
        var pct_s = underlayer_core::int_to_string(cov.progress_percentage as i64)
        var reason = string("{\"error\":\"course not complete\",\"course_id\":\"")
        reason.append_string(course_id)
        reason.append_view("\",\"concepts_started\":")
        reason.append_string(&started_s)
        reason.append_view(",\"concepts_total\":")
        reason.append_string(&total_s)
        reason.append_view(",\"progress_percentage\":")
        reason.append_string(&pct_s)
        reason.append_view("}")
        res.status = 403u
        send_json_str(res, &raw reason)
        return false
    }

}
