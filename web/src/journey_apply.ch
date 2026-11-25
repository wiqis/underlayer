// underlayer_web — apply the guided journey to backend-rendered lesson pages.
//
// handle_lesson renders each lesson from content/src.  About three quarters of
// those renderers already call the shared lesson assets and therefore already
// carry the shell; this patcher only adds the shell to the rest.  Metadata and
// per-step pedagogy are applied in BOTH cases through the one shared choke
// point in content/src/journey_pedagogy.ch, so a lesson with a pre-built shell
// still gets its manifest facts and derived takeaways.
//
// Same delivery contract as lesson_pager.ch / lesson_header.ch: build a NEW
// string for every patch.  Writing `out = patch(&out, ...)` aliases storage that
// is still being read and has previously truncated served pages.
using std::string
using std::string_view
using underlayer_models::Course

public namespace underlayer_web {

    public func apply_lesson_journey(src : &string, course : &Course, course_id : &string, concept_id : &string) : string {
        var injected = underlayer_content::apply_journey_to_document(src)
        var facts = underlayer_content::journey_facts_from_course(course, concept_id)
        return underlayer_content::journey_apply_metadata(&injected, &facts, course_id, concept_id)
    }
}
