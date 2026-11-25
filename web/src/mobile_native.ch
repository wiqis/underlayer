// underlayer_web — structured lesson JSON for the Android native renderer.
//
// GET /api/courses/:courseId/lessons/:conceptId/native
//
// The contract lives in docs/native-lesson-contract.md.  Nothing here builds
// markup: the lesson is rendered exactly as the browser receives it, put
// through the SAME journey patcher (so data-remember / data-aim exist), then
// composed into JSON by the shared underlayer_content::native_lesson_json.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_lesson_native(
        courses_dir : &string,
        course_id : &string_view,
        concept_id : &string_view,
        req : &http::Request
    ) : http::Response {
        var check = validate_lesson_pair(courses_dir, course_id, concept_id)
        if(!check.ok) { return send_error(check.error_status, &check.error_message) }

        var cid = sv_to_string(course_id)
        var pid = sv_to_string(concept_id)
        var html = render_concept(&pid)
        if(html.size() == 0) {
            var err = string("lesson not found")
            return send_error(404u, &err)
        }

        // Mandatory: without the journey pass the unit tags carry no derived
        // takeaway attributes and the JSON would have to guess them.
        var journeyed = apply_lesson_journey(&html, &check.course, &cid, &pid)
        var facts = underlayer_content::journey_facts_from_course(&check.course, &pid)
        var body = underlayer_content::native_lesson_json(&journeyed, &facts, &cid, &pid)
        return send_json_str(&body)
    }
}
