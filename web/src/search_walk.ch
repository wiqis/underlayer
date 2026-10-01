// underlayer_web — Walk every concept of every course and keep what matches.
//
// One walk, four fields per concept: the concept title, its description, the
// course title and the module title.  The module title is in there because
// "the line number program" is a module of `dwarf` and not a concept title,
// and a learner who remembers a module name should find it.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func search_concepts(courses : &vector<Course>, query_raw : &string) : vector<SearchHit> {
        var hits = vector<SearchHit>()
        var qsv = query_raw.to_view()
        var query = ascii_lower(&raw qsv)
        if(query.size() == 0) { return hits }
        var ci : size_t = 0
        while(ci < courses.size()) {
            var course = courses.get_ptr(ci)
            var ct_view = course.title.to_view()
            var course_title_l = ascii_lower(&raw ct_view)
            var course_title_hit = find_bytes(&course_title_l, &query)
            var course_desc = course.description.copy()
            var cd_view = course_desc.to_view()
            var course_desc_l = ascii_lower(&raw cd_view)
            var course_desc_hit = find_bytes(&course_desc_l, &query)
            var course_id = course.id.copy()
            var kci : size_t = 0
            while(kci < course.concepts.size()) {
                var cref = course.concepts.get_ptr(kci)
                var title = cref.title.copy()
                var desc = cref.description.copy()
                var ti_view = title.to_view()
                var title_l = ascii_lower(&raw ti_view)
                var de_view = desc.to_view()
                var desc_l = ascii_lower(&raw de_view)
                var concept_id = cref.id.copy()
                var module_title = module_title_for(course, &concept_id)
                var mo_view = module_title.to_view()
                var module_l = ascii_lower(&raw mo_view)

                var score = hit_score(&query, &title_l, &desc_l)
                var field = string()
                if(score == 100) { field = string("concept title") }
                else if(score == 80) { field = string("concept title") }
                else if(score == 60) { field = string("description") }
                else if(score == 40) { field = string("description") }
                else if(find_bytes(&module_l, &query) >= 0) {
                    score = 30
                    field = string("module")
                } else if(course_title_hit >= 0) {
                    score = 20
                    field = string("course title")
                } else if(course_desc_hit >= 0) {
                    // The term is in the course's own blurb and in none of its
                    // lessons -- "cmpxchg" is in rvat's description and in
                    // none of its four concept descriptions.  Reporting nothing
                    // is the failure mode a search page exists to prevent, so
                    // the whole course comes back at the lowest tier.
                    score = 15
                    field = string("course description")
                }

                if(score > 0) {
                    var hit = SearchHit::make()
                    hit.course_id = course_id.copy()
                    hit.course_title = course.title.copy()
                    hit.concept_id = concept_id.copy()
                    hit.concept_title = title.copy()
                    hit.concept_description = snippet_of(&desc, &query, SNIPPET_WIDTH, SNIPPET_LEAD)
                    hit.module_title = module_title.copy()
                    var href = string("/courses/")
                    href.append_string(&course_id)
                    href.append_view(string_view("/lessons/"))
                    href.append_string(&concept_id)
                    hit.href = href
                    hit.matched_field = field.copy()
                    hit.score = score
                    hits.push(hit)
                }
                kci = kci + 1
            }
            ci = ci + 1
        }
        sort_hits(&hits)
        return hits
    }

}