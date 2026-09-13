// underlayer_learning — Utility functions.
using std::string

public namespace underlayer_learning {

    public func f64_to_string(val : f64) : string {
        var int_part = val as i64
        var frac_part = ((val - (int_part as f64)) * 100.0) as i64
        var result = underlayer_core::int_to_string(int_part)
        result.append_view(".")
        var frac_str = underlayer_core::int_to_string(frac_part)
        result.append_view(frac_str.to_view())
        return result
    }

}
