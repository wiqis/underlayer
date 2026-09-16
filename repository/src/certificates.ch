// underlayer_repository — Certificate issuance and retrieval.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_db::QueryRow

public namespace underlayer_repository {

    public struct Certificate {
        var id : string
        var learner_id : string
        var course_id : string
        var learner_name : string
        var course_title : string
        var completion_date : string
        var certificate_url : string
        var created_at : i64
        @make func make() : Certificate { return Certificate { id = string(), learner_id = string(), course_id = string(), learner_name = string(), course_title = string(), completion_date = string(), certificate_url = string(), created_at = 0 } }
    }

    private func row_to_cert(row : *QueryRow) : Certificate {
        var cert = Certificate::make()
        if(row.vals.size() >= 8) {
            cert.id = row.vals.get_ptr(0).copy()
            cert.learner_id = row.vals.get_ptr(1).copy()
            cert.course_id = row.vals.get_ptr(2).copy()
            cert.learner_name = row.vals.get_ptr(3).copy()
            cert.course_title = row.vals.get_ptr(4).copy()
            cert.completion_date = row.vals.get_ptr(5).copy()
            cert.certificate_url = row.vals.get_ptr(6).copy()
            cert.created_at = parse_i64(row.vals.get_ptr(7).to_view())
        }
        return cert
    }

    public func issue_certificate(db : *DbClient, learner_id : &string, course_id : &string, learner_name : &string, course_title : &string) : string {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var cert_id = underlayer_core::int_to_string(now)
        cert_id.append_view("_")
        cert_id.append_string(learner_id)
        cert_id.append_view("_")
        cert_id.append_string(course_id)
        var completion_date = string()
        var year = now / 31536000 + 1970
        var y_str = underlayer_core::int_to_string(year)
        completion_date.append_view(y_str.to_view())
        completion_date.append_view("-")
        var month = (now % 31536000) / 2592000 + 1
        if(month < 10) { completion_date.append_view("0") }
        var m_str = underlayer_core::int_to_string(month)
        completion_date.append_view(m_str.to_view())
        completion_date.append_view("-")
        var day = ((now % 31536000) % 2592000) / 86400 + 1
        if(day < 10) { completion_date.append_view("0") }
        var d_str = underlayer_core::int_to_string(day)
        completion_date.append_view(d_str.to_view())
        var cert_url = string("/certificates/")
        cert_url.append_string(&cert_id)
        var name_esc = underlayer_core::json_escape(&learner_name.to_view())
        var title_esc = underlayer_core::json_escape(&course_title.to_view())
        var sql = string("INSERT INTO certificates (id, learner_id, course_id, learner_name, course_title, completion_date, certificate_url, created_at) VALUES ('")
        sql.append_string(&cert_id)
        sql.append_view("', '")
        sql.append_string(learner_id)
        sql.append_view("', '")
        sql.append_string(course_id)
        sql.append_view("', '")
        sql.append_string(&name_esc)
        sql.append_view("', '")
        sql.append_string(&title_esc)
        sql.append_view("', '")
        sql.append_string(&completion_date)
        sql.append_view("', '")
        sql.append_string(&cert_url)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return cert_id
    }

    public func get_certificate(db : *DbClient, certificate_id : &string) : Certificate {
        var cert = Certificate::make()
        var sql = string("SELECT id, learner_id, course_id, learner_name, course_title, completion_date, certificate_url, created_at FROM certificates WHERE id = '")
        sql.append_string(certificate_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            cert = row_to_cert(row)
        }
        return cert
    }

    public func get_learner_certificates(db : *DbClient, learner_id : &string) : vector<Certificate> {
        var certs = vector<Certificate>()
        var sql = string("SELECT id, learner_id, course_id, learner_name, course_title, completion_date, certificate_url, created_at FROM certificates WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            var cert = row_to_cert(row)
            certs.push(cert)
            ri = ri + 1
        }
        return certs
    }

    public func has_certificate(db : *DbClient, learner_id : &string, course_id : &string) : bool {
        var sql = string("SELECT id FROM certificates WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) { return true }
        return false
    }

}
