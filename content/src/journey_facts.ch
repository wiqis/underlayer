// underlayer_content — manifest facts for the guided journey.
//
// Both delivery paths need the same five facts (time, level, prerequisite,
// previous and next concept id): the backend already loaded the Course to decide
// the lesson exists, and the static injector reads the same manifest.json from
// disk.  One struct and two constructors keep the two paths from drifting.
using std::string
using std::string_view
using underlayer_models::Course

public namespace underlayer_content {

    public struct JourneyFacts {
        var title : string
        var description : string
        var minutes : string
        var difficulty : string
        var prereq : string
        var prev_id : string
        var next_id : string

        @make
        func make() : JourneyFacts {
            return JourneyFacts {
                title = string(),
                description = string(),
                minutes = string(),
                difficulty = string(),
                prereq = string(),
                prev_id = string(),
                next_id = string()
            }
        }
    }

    public func journey_facts_from_course(course : &Course, concept_id : &string) : JourneyFacts {
        var facts = JourneyFacts::make()
        var i : size_t = 0
        while(i < course.concepts.size()) {
            if(course.concepts.at_ref(i).id.equals(concept_id)) {
                var cref = course.concepts.at_ref(i)
                facts.title = cref.title.copy()
                facts.description = cref.description.copy()
                facts.minutes = underlayer_core::int_to_string(cref.estimated_minutes as i64)
                facts.difficulty = cref.difficulty.copy()
                if(i > 0) {
                    facts.prereq = course.concepts.at_ref(i - 1).title.copy()
                    facts.prev_id = course.concepts.at_ref(i - 1).id.copy()
                }
                if(i + 1 < course.concepts.size()) {
                    facts.next_id = course.concepts.at_ref(i + 1).id.copy()
                }
                return facts
            }
            i = i + 1
        }
        return facts
    }

    // The three tiny JSON helpers below mirror repository/src/helpers.ch.  They
    // stay local so the static injector need not pull in the database module.
    private func jf_get(obj : &JsonValue, key : *char) : std::Option<&JsonValue> {
        var k = unsafe(std::string::make_no_len(key))
        switch(obj) {
            Object(values) => { return values.get(&k) }
            default => { return std::Option.None<&JsonValue>() }
        }
    }

    private func jf_str(obj : &JsonValue, key : *char) : string {
        var found = jf_get(obj, key)
        if(found is std::Option.Some) {
            var Some(value) = found else unsafe { unreachable }
            switch(value) {
                String(s) => { return s.copy() }
                default => { return string() }
            }
        }
        return string()
    }

    private func jf_int(obj : &JsonValue, key : *char) : int {
        var found = jf_get(obj, key)
        if(found is std::Option.Some) {
            var Some(value) = found else unsafe { unreachable }
            switch(value) {
                Number(n) => {
                    var out : int = 0
                    var i : size_t = 0
                    while(i < n.size()) {
                        var c = n.at(i)
                        if(c >= '0' && c <= '9') { out = out * 10 + (c as int - 48) }
                        i = i + 1
                    }
                    return out
                }
                default => { return 0 }
            }
        }
        return 0
    }

    private func jf_len(node : &JsonValue) : size_t {
        switch(node) {
            Array(values) => { return values.size() }
            default => { return 0 }
        }
    }

    private func jf_at(node : &JsonValue, i : size_t) : std::Option<&JsonValue> {
        switch(node) {
            Array(values) => {
                if(i >= values.size()) { return std::Option.None<&JsonValue>() }
                return values.get(i)
            }
            default => { return std::Option.None<&JsonValue>() }
        }
    }

    public func journey_facts_from_manifest(manifest_path : &string, concept_id : &string) : JourneyFacts {
        var facts = JourneyFacts::make()
        var p = path::Path.new(std::str.make_view(manifest_path.to_view()))
        var read_res = fs::read_to_string(&p)
        if(read_res is std::Result.Err) { return facts }
        var Ok(text) = read_res else unsafe { unreachable }
        var parsed = json::parse(text.to_view())
        if(parsed is std::Result.Err) { return facts }
        var Ok(root) = parsed else unsafe { unreachable }
        var concepts = jf_get(&root, "concepts")
        if(concepts is std::Option.None) { return facts }
        var Some(arr) = concepts else unsafe { unreachable }
        var i : size_t = 0
        var total = jf_len(arr)
        while(i < total) {
            var elem = jf_at(arr, i)
            var Some(item) = elem else unsafe { unreachable }
            if(item is JsonValue.Object) {
                if(jf_str(item, "id").equals(concept_id)) {
                    facts.title = jf_str(item, "title")
                    facts.description = jf_str(item, "description")
                    facts.minutes = underlayer_core::int_to_string(jf_int(item, "estimated_minutes") as i64)
                    facts.difficulty = jf_str(item, "difficulty")
                    if(i > 0) {
                        var before = jf_at(arr, i - 1)
                        var Some(prev) = before else unsafe { unreachable }
                        facts.prev_id = jf_str(prev, "id")
                        facts.prereq = jf_str(prev, "title")
                    }
                    if(i + 1 < total) {
                        var after = jf_at(arr, i + 1)
                        var Some(next) = after else unsafe { unreachable }
                        facts.next_id = jf_str(next, "id")
                    }
                    return facts
                }
            }
            i = i + 1
        }
        return facts
    }
}
