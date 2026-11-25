// underlayer_content — the top-level native lesson JSON composer.
//
// This is the ONE composer: the HTTP endpoint and the static-page emitter both
// call it, so a served lesson and its bundled .native.json cannot drift.  Every
// value comes from the rendered, journey-patched HTML or the course manifest.
using std::string
using std::string_view
using std::vector

public namespace underlayer_content {

    public func native_lesson_json(
        html : &string,
        facts : &JourneyFacts,
        course_id : &string,
        concept_id : &string
    ) : string {
        var units = native_units(html)
        var unit_fragments = vector<string>()
        var i : size_t = 0
        while(i < units.size()) {
            unit_fragments.push(native_unit_json(units.at_ref(i)))
            i = i + 1
        }

        // The arrival aim is the first unit's derived data-aim; fall back to
        // the manifest description.  No sentence is invented here.
        var objective = string()
        if(units.size() > 0) { objective = units.at_ref(0).aim.copy() }
        if(objective.size() == 0) { objective = facts.description.copy() }

        var c = jquote(course_id)
        var p = jquote(concept_id)
        var t = jquote(&facts.title)
        var d = jquote(&facts.difficulty)
        var o = jquote(&objective)
        var prereq = jnull_or_string(&facts.prereq)
        var minutes = jint(jdigits(&facts.minutes))
        var uj = jarray(&unit_fragments)

        var out = string("{\"schema_version\":1,\"course_id\":")
        out.append_string(&c)
        out.append_view(",\"concept_id\":")
        out.append_string(&p)
        out.append_view(",\"title\":")
        out.append_string(&t)
        out.append_view(",\"minutes\":")
        out.append_string(&minutes)
        out.append_view(",\"difficulty\":")
        out.append_string(&d)
        out.append_view(",\"prerequisite\":")
        out.append_string(&prereq)
        out.append_view(",\"objective\":")
        out.append_string(&o)
        out.append_view(",\"units\":")
        out.append_string(&uj)
        out.append('}')
        return out
    }
}
