// underlayer_web — shared course/concept validation for the mobile lesson APIs.
//
// render_concept dispatches GLOBALLY by concept id.  Both /units and /native
// must reject a concept that exists but belongs to another course, so the
// check lives in one place and both endpoints report the same 404 body.
using std::string
using std::string_view
using underlayer_models::Course

public namespace underlayer_web {

    public struct LessonPairValidation {
        var course : Course
        var ok : bool
        var error_status : u16
        var error_message : string

        @make
        func make() : LessonPairValidation {
            return LessonPairValidation {
                course = Course::make(),
                ok = false,
                error_status = 0u,
                error_message = string()
            }
        }
    }

    public func validate_lesson_pair(
        courses_dir : &string,
        course_id : &string_view,
        concept_id : &string_view
    ) : LessonPairValidation {
        var result = LessonPairValidation::make()
        var cid = sv_to_string(course_id)
        var pid = sv_to_string(concept_id)
        var course = underlayer_repository::load_course(courses_dir, &cid)
        if(course.id.size() == 0) {
            result.error_status = 404u
            result.error_message = string("course not found")
            return result
        }
        var belongs = false
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.at_ref(ci)
            if(cref.id.equals(&pid)) { belongs = true }
            ci = ci + 1
        }
        if(!belongs) {
            result.error_status = 404u
            result.error_message = string("concept not found in course")
            return result
        }
        result.course = course
        result.ok = true
        return result
    }
}
