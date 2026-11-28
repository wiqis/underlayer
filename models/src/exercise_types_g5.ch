// G5 — graded exercise types derived from verified lesson text.
// These are presentation/grading kinds only: no byte, offset or spec claim is
// authored here. The answer keys live in the course manifests with a
// source_ref/source_quote pointing at the lesson that produced them.
using std::string

public namespace underlayer_models {

    public func exercise_type_order_steps() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("order_steps")
        t.label = string("Order steps")
        t.description = string("Put the verified steps in their documented order.")
        return t
    }

    public func exercise_type_byte_range() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("byte_range")
        t.label = string("Byte range")
        t.description = string("Name a byte or range quoted in the lesson or specimen.")
        return t
    }

    public func exercise_type_decode_field() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("decode_field")
        t.label = string("Decode field")
        t.description = string("Identify a field's verified value from the lesson text.")
        return t
    }

    public func exercise_type_output_match() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("output_match")
        t.label = string("Output match")
        t.description = string("Match the verified output recorded in the lesson.")
        return t
    }

    // One specimen lab per six course families (G5). The lab OPENs the
    // course's existing specimen bundle; the graded key is still a quoted
    // string from that course's verified lesson text.
    public func exercise_type_specimen_lab() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("specimen_lab")
        t.label = string("Specimen lab")
        t.description = string("Read the course specimen bundle and match a quoted fact.")
        return t
    }

}
