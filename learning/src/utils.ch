// underlayer_learning — Utility functions.
using std::string

public namespace underlayer_learning {

    // TWO decimals is the right precision for a FIGURE A PERSON READS (a health
    // score, a percentage, a retention projection) and the wrong precision for a
    // VALUE THE SCHEDULER READS BACK.
    //
    // It was wrong for stability, and the failure was silent and total. FSRS
    // initialises stability from w[rating], and w[3] -- S0 for "Good" -- is
    // 0.1901. The next-stability formula does raise it:
    //
    //   s_new = S * exp(w16 * S^w17)
    //     S=0.1901 -> 0.1985 -> 0.2080 -> ...
    //
    // but every one of those values is BELOW 0.20, and two decimals cannot
    // distinguish 0.1901 from 0.1985. Each computed stability was rounded back
    // to 0.19 on the way into the column, so the next rating read 0.19 again,
    // computed 0.1985 again, and stored 0.19 again. Ten consecutive successful
    // reviews moved stability from 0.19 to 0.19.
    //
    // THAT IS WHY THE READ FIX ALONE DID NOTHING, and it is worth stating
    // plainly: fixing the write-up while rounding the value at the boundary
    // leaves the loop intact. A round-trip has to preserve every bit the next
    // step depends on.
    //
    // So: four decimals, which resolves the whole 0.19-1.0 range the scheduler
    // spends its early reviews in, and is exact for f64 at these magnitudes.
    public func f64_to_string(val : f64) : string {
        return f64_to_string_prec(val, 4)
    }

    // `places` decimals, zero-padded. Shared by the readable figures (4, via
    // f64_to_string) and by the stored scheduler state.
    public func f64_to_string_prec(val : f64, places : i64) : string {
        var int_part = val as i64
        var scale = 1.0
        var k : i64 = 0
        while(k < places) { scale = scale * 10.0; k = k + 1 }
        var frac_part = ((val - (int_part as f64)) * scale) as i64
        var result = underlayer_core::int_to_string(int_part)
        result.append_view(".")
        // Zero-pad, or a small fraction produces a MALFORMED number rather than
        // a rounded one: 0.05 at two places came out as "0.5", ten times the
        // value, because the single digit was appended with no tens place.
        var pad = places - 1
        while(pad > 0) {
            if(frac_part < 100) { result.append_view("0") }
            pad = pad - 1
        }
        var frac_str = underlayer_core::int_to_string(frac_part)
        result.append_view(frac_str.to_view())
        return result
    }

}
