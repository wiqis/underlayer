// underlayer_web — apply the guided journey to backend-rendered lesson pages.
//
// handle_lesson renders each lesson from content/src.  About three quarters of
// those renderers already call the shared lesson assets and therefore already
// carry the shell; this patcher only acts on the rest, and is a strict no-op
// when the shell is present.  It also gives the shell the manifest facts
// (minutes, difficulty, the previous lesson) that a static page cannot know.
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
        if(injected.size() == src.size()) { return injected }

        var name = string("course")
        var with_course = underlayer_content::patch_journey_attr(&injected, &name, course_id)
        name = string("concept")
        var with_concept = underlayer_content::patch_journey_attr(&with_course, &name, concept_id)

        var idx : i64 = -1
        var i : size_t = 0
        while(i < course.concepts.size()) {
            if(course.concepts.at_ref(i).id.equals(concept_id)) { idx = i as i64 }
            i = i + 1
        }
        if(idx < 0) { return with_concept }

        var cref = course.concepts.at_ref(idx as size_t)
        var minutes = underlayer_core::int_to_string(cref.estimated_minutes as i64)
        name = string("minutes")
        var with_minutes = underlayer_content::patch_journey_attr(&with_concept, &name, &minutes)
        name = string("difficulty")
        var with_diff = underlayer_content::patch_journey_attr(&with_minutes, &name, &cref.difficulty)

        if(idx == 0) { return with_diff }
        var prev = course.concepts.at_ref((idx - 1) as size_t).id.copy()
        name = string("prereq")
        var with_prev = underlayer_content::patch_journey_attr(&with_diff, &name, &prev)
        return with_prev
    }
}
