// Extra exercise types for the 8 lesson UI kinds (4.1.29).
// Complements the types defined in main.ch without growing that file.
using std::string

public namespace underlayer_models {

    public func exercise_type_hex_inspect() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("hex_inspect")
        t.label = string("Hex Inspect")
        t.description = string("Read a value from a hex dump.")
        return t
    }

    public func exercise_type_ordering() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("ordering")
        t.label = string("Ordering")
        t.description = string("Put items in the correct order.")
        return t
    }

    public func exercise_type_labeling() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("labeling")
        t.label = string("Labeling")
        t.description = string("Label parts of a diagram or structure.")
        return t
    }

    public func exercise_type_predict() : ExerciseType {
        var t = ExerciseType::make()
        t.id = string("predict")
        t.label = string("Predict")
        t.description = string("Predict what happens given a change.")
        return t
    }

}
