// underlayer_repository — per-learner FSRS parameters (G3).
//
// This file is deliberately free of any dependency on underlayer_learning:
// repository sits below web and must not import a peer module. It stores the
// parameter document as an opaque JSON string and copies the two fields the
// scheduler needs on every request into plain columns. The web layer owns the
// mapping to/from learning::FSRSParams (see handlers_settings.ch).
//
// A learner with no row is NOT an error: every read returns found=false and
// the caller uses the shipped defaults. That is what keeps older databases and
// the anonymous "demo" identity behaving exactly as before this table existed.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct FsrsParamsRecord {
        var params_json : string
        var target_retention : f64
        var daily_review_cap : int
        var found : bool

        @make
        func make() : FsrsParamsRecord {
            return FsrsParamsRecord {
                params_json = string(),
                target_retention = 0.90,
                daily_review_cap = 20,
                found = false
            }
        }
    }

    public func load_fsrs_params(db : *DbClient, learner_id : &string) : FsrsParamsRecord {
        var rec = FsrsParamsRecord::make()
        var sql = string("SELECT params_json, target_retention, daily_review_cap FROM fsrs_params WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.at_ref(0)
            if(row.vals.size() >= 3) {
                rec.params_json = row.vals.at_ref(0).copy()
                rec.target_retention = parse_f64(row.vals.at_ref(1).to_view())
                rec.daily_review_cap = parse_int(row.vals.at_ref(2).to_view())
                rec.found = true
            }
        }
        return rec
    }

    // SQL string literal from a string we built ourselves. JSON emitted by the
    // web layer contains double quotes only, but escaping single quotes here
    // means a future caller cannot turn a parameter document into SQL.
    private func sql_literal(s : &string) : string {
        var out = string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '\'') { out.append('\'') }
            out.append(c)
            i = i + 1
        }
        return out
    }

    // Four-decimal literal, so 0.90 is stored as "0.9000" and parses back
    // through parse_f64 without any locale or exponent handling.
    private func f64_literal(v : f64) : string {
        var out = string()
        var x = v
        if(x < 0.0) { out.append('-'); x = -x }
        var ip = x as i64
        var frac = (((x - (ip as f64)) * 10000.0) + 0.5) as i64
        if(frac < 0) { frac = 0 }
        var ip_s = underlayer_core::int_to_string(ip)
        var fr_s = underlayer_core::int_to_string(frac)
        out.append_view(ip_s.to_view())
        out.append('.')
        if(frac < 1000) { out.append('0') }
        if(frac < 100) { out.append('0') }
        if(frac < 10) { out.append('0') }
        out.append_view(fr_s.to_view())
        return out
    }

    public func save_fsrs_params(db : *DbClient, learner_id : &string, params_json : &string, target_retention : f64, daily_review_cap : int) {
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var id = sql_literal(learner_id)
        var doc = sql_literal(params_json)
        var tr = f64_literal(target_retention)
        var cap = underlayer_core::int_to_string(daily_review_cap as i64)
        var sql = string("INSERT OR REPLACE INTO fsrs_params (learner_id, params_json, target_retention, daily_review_cap, updated_at) VALUES ('")
        sql.append_view(id.to_view())
        sql.append_view("', '")
        sql.append_view(doc.to_view())
        sql.append_view("', ")
        sql.append_view(tr.to_view())
        sql.append_view(", ")
        sql.append_view(cap.to_view())
        sql.append_view(", ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
