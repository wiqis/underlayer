// Shared DB type-string ↔ ExerciseType mapping (4.1.29).
// Used by exercises.ch (read/write) and review_seed.ch (manifest import)
// so the 8 lesson UI types stay consistent across every path.
using std::string
using underlayer_models::ExerciseType

public namespace underlayer_repository {

    public func exercise_type_from_str(type_str : &string) : ExerciseType {
        if(type_str.equals(string("multiple_choice"))) {
            return underlayer_models::exercise_type_recognize()
        }
        if(type_str.equals(string("multi_recognize"))) {
            return underlayer_models::exercise_type_multi_recognize()
        }
        if(type_str.equals(string("free_recall"))) {
            return underlayer_models::exercise_type_recall()
        }
        if(type_str.equals(string("cued_recall"))) {
            return underlayer_models::exercise_type_apply()
        }
        if(type_str.equals(string("fill_blank"))) {
            return underlayer_models::exercise_type_fill_blank()
        }
        if(type_str.equals(string("true_false"))) {
            return underlayer_models::exercise_type_true_false()
        }
        if(type_str.equals(string("matching"))) {
            return underlayer_models::exercise_type_matching()
        }
        if(type_str.equals(string("hex_inspect"))) {
            return underlayer_models::exercise_type_hex_inspect()
        }
        if(type_str.equals(string("ordering"))) {
            return underlayer_models::exercise_type_ordering()
        }
        if(type_str.equals(string("labeling"))) {
            return underlayer_models::exercise_type_labeling()
        }
        if(type_str.equals(string("predict"))) {
            return underlayer_models::exercise_type_predict()
        }
        if(type_str.equals(string("order_steps"))) {
            return underlayer_models::exercise_type_order_steps()
        }
        if(type_str.equals(string("byte_range"))) {
            return underlayer_models::exercise_type_byte_range()
        }
        if(type_str.equals(string("decode_field"))) {
            return underlayer_models::exercise_type_decode_field()
        }
        if(type_str.equals(string("output_match"))) {
            return underlayer_models::exercise_type_output_match()
        }
        if(type_str.equals(string("specimen_lab"))) {
            return underlayer_models::exercise_type_specimen_lab()
        }
        return underlayer_models::exercise_type_recognize()
    }

    public func exercise_type_to_str(t : &ExerciseType) : string {
        if(t.id.equals(string("recall"))) { return string("free_recall") }
        if(t.id.equals(string("apply"))) { return string("cued_recall") }
        if(t.id.equals(string("multi_recognize"))) { return string("multi_recognize") }
        if(t.id.equals(string("recognize"))) { return string("multiple_choice") }
        if(t.id.equals(string("explain"))) { return string("explain") }
        if(t.id.equals(string("fill_blank"))) { return string("fill_blank") }
        if(t.id.equals(string("true_false"))) { return string("true_false") }
        if(t.id.equals(string("matching"))) { return string("matching") }
        if(t.id.equals(string("hex_inspect"))) { return string("hex_inspect") }
        if(t.id.equals(string("ordering"))) { return string("ordering") }
        if(t.id.equals(string("labeling"))) { return string("labeling") }
        if(t.id.equals(string("predict"))) { return string("predict") }
        if(t.id.equals(string("order_steps"))) { return string("order_steps") }
        if(t.id.equals(string("byte_range"))) { return string("byte_range") }
        if(t.id.equals(string("decode_field"))) { return string("decode_field") }
        if(t.id.equals(string("output_match"))) { return string("output_match") }
        if(t.id.equals(string("specimen_lab"))) { return string("specimen_lab") }
        return string("multiple_choice")
    }

}
