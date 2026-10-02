// underlayer_web — GET /api/user/login-history.
//
// Split out of the 606-line handlers_auth.ch.  Small, self-contained, and it
// has a job the other two do not: it is the only endpoint that READS the
// audit trail, so it is the only place where answering for the wrong learner
// would expose someone else's login history.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {
    // ---- 16.10.1: GET /api/user/login-history ----

    public func handle_login_history(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var learner_safe = underlayer_repository::sql_escape(&learner_id)
        var sel_sql = string("SELECT id, learner_id, ip_address, user_agent, success, failure_reason, created_at FROM login_history WHERE learner_id = '")
        sel_sql.append_string(&learner_safe)
        sel_sql.append_view("' ORDER BY created_at DESC LIMIT 20")
        var result = underlayer_db::query_sql(db, &raw sel_sql)
        var resp = string("[")
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            if(ri > 0) { resp.append_view(",") }
            var row = result.rows.get_ptr(ri)
            var val0 = row.vals.get_ptr(0).copy()
            var val1 = row.vals.get_ptr(1).copy()
            var val2 = row.vals.get_ptr(2).copy()
            var val3 = row.vals.get_ptr(3).copy()
            var val4 = row.vals.get_ptr(4).copy()
            var val5 = row.vals.get_ptr(5).copy()
            var val6 = row.vals.get_ptr(6).copy()
            resp.append_view("{\"id\":")
            resp.append_string(&val0)
            resp.append_view(",\"learner_id\":\"")
            resp.append_string(&val1)
            resp.append_view("\",\"ip_address\":\"")
            resp.append_string(&val2)
            resp.append_view("\",\"user_agent\":\"")
            resp.append_string(&val3)
            resp.append_view("\",\"success\":")
            var one = string("1")
            if(val4.equals(&one)) { resp.append_view("true") } else { resp.append_view("false") }
            resp.append_view(",\"failure_reason\":\"")
            resp.append_string(&val5)
            resp.append_view("\",\"created_at\":")
            resp.append_string(&val6)
            resp.append_view("}")
            ri = ri + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

}
