// underlayer_web — JSON parsing/serialization for the mobile sync endpoints.
//
// No SQL here: all storage goes through underlayer_repository::progress_sync_*.
// Kept separate from handlers_mobile.ch so both files stay under the 250-line
// ceiling in AGENTS.md.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::UnitProgress

public namespace underlayer_web {

    // `find_or_npos` has no offset form, so search a subview and translate the
    // relative index back.  `subview(start, end)` takes an ABSOLUTE end index.
    public func find_from(haystack : &string, needle : &string_view, from : size_t) : size_t {
        if(from >= haystack.size()) { return std::NPOS }
        var rest = haystack.to_view().subview(from, haystack.size())
        var rel = rest.find_or_npos(needle)
        if(rel == std::NPOS) { return std::NPOS }
        return from + rel
    }

    // One element of `changes[]`.  Every field is required and type-checked:
    // silently defaulting a missing updated_at to 0 would make an old write
    // look newer than everything on the server.
    public func parse_unit_change(node : &JsonValue, out : &mut UnitProgress) : bool {
        var cn = json_get(node, "course_id")
        if(cn is std::Option.None) { return false }
        var Some(cnv) = cn else unsafe { unreachable }
        var course_id = json_str(cnv)
        if(course_id.size() == 0) { return false }

        var pn = json_get(node, "concept_id")
        if(pn is std::Option.None) { return false }
        var Some(pnv) = pn else unsafe { unreachable }
        var concept_id = json_str(pnv)
        if(concept_id.size() == 0) { return false }

        var un = json_get(node, "unit_id")
        if(un is std::Option.None) { return false }
        var Some(unv) = un else unsafe { unreachable }
        var unit_id = json_str(unv)
        if(unit_id.size() == 0) { return false }

        var sn = json_get(node, "status")
        if(sn is std::Option.None) { return false }
        var Some(snv) = sn else unsafe { unreachable }
        var status = json_str(snv)
        if(status.size() == 0) { return false }

        var step_node = json_get(node, "step_index")
        if(step_node is std::Option.None) { return false }
        var Some(step_val) = step_node else unsafe { unreachable }
        if(!(step_val is JsonValue.Number)) { return false }

        var ts_node = json_get(node, "updated_at")
        if(ts_node is std::Option.None) { return false }
        var Some(ts_val) = ts_node else unsafe { unreachable }
        if(!(ts_val is JsonValue.Number)) { return false }

        out.course_id = course_id
        out.concept_id = concept_id
        out.unit_id = unit_id
        out.status = status
        out.step_index = underlayer_repository::json_i64(step_val)
        out.updated_at = underlayer_repository::json_i64(ts_val)
        return true
    }

    // `changes:[{course_id,concept_id,unit_id,status,step_index,updated_at}]`.
    // The values are the ones the SERVER now holds, not the ones the client
    // sent: a rejected older write comes back with the newer stored timestamp,
    // which is what lets the client converge in one round trip.
    public func append_changes_json(body : &mut string, changes : &vector<UnitProgress>) {
        body.append_view("[")
        var i : size_t = 0
        while(i < changes.size()) {
            if(i > 0) { body.append_view(",") }
            var c = changes.at_ref(i)
            body.append_view("{\"course_id\":\"")
            var crs = underlayer_core::json_escape(&c.course_id.to_view())
            body.append_string(&crs)
            body.append_view("\",\"concept_id\":\"")
            var cid = underlayer_core::json_escape(&c.concept_id.to_view())
            body.append_string(&cid)
            body.append_view("\",\"unit_id\":\"")
            var uid = underlayer_core::json_escape(&c.unit_id.to_view())
            body.append_string(&uid)
            body.append_view("\",\"status\":\"")
            var st = underlayer_core::json_escape(&c.status.to_view())
            body.append_string(&st)
            body.append_view("\",\"step_index\":")
            var step = underlayer_core::int_to_string(c.step_index)
            body.append_string(&step)
            body.append_view(",\"updated_at\":")
            var ts = underlayer_core::int_to_string(c.updated_at)
            body.append_string(&ts)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]")
    }

    // FSRS is read-only here.  One entry per distinct (course, concept) touched
    // by this response, taken from `review_items`, which only
    // /api/review/submit writes.  A concept with no review item reports zeros
    // rather than the ReviewItem defaults (stability 1.0), so a brand-new
    // learner sees an honest empty schedule.
    public func append_fsrs_json(db : *DbClient, body : &mut string, changes : &vector<UnitProgress>) {
        body.append_view(",\"fsrs\":[")
        var first = true
        var i : size_t = 0
        while(i < changes.size()) {
            var c = changes.at_ref(i)
            var duplicate = false
            var j : size_t = 0
            while(j < i) {
                var prev = changes.at_ref(j)
                if(prev.course_id.equals(&c.course_id) && prev.concept_id.equals(&c.concept_id)) {
                    duplicate = true
                }
                j = j + 1
            }
            if(!duplicate) {
                if(!first) { body.append_view(",") }
                first = false
                body.append_view("{\"concept_id\":\"")
                var cid = underlayer_core::json_escape(&c.concept_id.to_view())
                body.append_string(&cid)
                var item = underlayer_repository::get_review_item_by_concept(db, &c.learner_id, &c.course_id, &c.concept_id)
                var stability : f64 = 0.0
                var reps : i64 = 0
                var interval : i64 = 0
                var next_review : i64 = 0
                if(item.id.size() > 0) {
                    stability = item.stability
                    reps = item.reps as i64
                    next_review = item.next_review
                    if(item.last_review > 0 && item.next_review > item.last_review) {
                        interval = (item.next_review - item.last_review) / 86400
                    }
                }
                body.append_view("\",\"stability\":")
                var stab_str = underlayer_repository::f64_to_string_prec(stability, 4)
                body.append_string(&stab_str)
                body.append_view(",\"reps\":")
                var reps_str = underlayer_core::int_to_string(reps)
                body.append_string(&reps_str)
                body.append_view(",\"interval\":")
                var int_str = underlayer_core::int_to_string(interval)
                body.append_string(&int_str)
                body.append_view(",\"next_review\":")
                var nr_str = underlayer_core::int_to_string(next_review)
                body.append_string(&nr_str)
                body.append_view("}")
            }
            i = i + 1
        }
        body.append_view("]")
    }

}
