// underlayer_db — database abstraction over SQLite (local) and Turso HTTP (production).
//
// Backend is chosen by the connection URL:
//   * starts with http:// or https:// or libsql:// -> Turso HTTP
//   * anything else (e.g. ./underlayer.db) -> embedded SQLite3
using std::string
using std::string_view
using std::vector
using std::Result

public namespace underlayer_db {

    public struct QueryRow {
        var vals : vector<string>
    }

    public struct QueryResult {
        var columns : vector<string>
        var rows : vector<QueryRow>
        var rows_affected : i64
    }

    public struct ExecResult {
        var last_insert_rowid : i64
        var rows_affected : i64
    }

    public struct DbClient {
        var is_sqlite : bool
        var sqlite_handle : *mut sqlite::sqlite3
        var turso_client : http::Client
        var turso_url : string
        var turso_token : string
    }

    public func is_remote_url(url : *string) : bool {
        var n = url.size()
        if(n < 7) { return false }
        var ok = url.get(0) == 'h' && url.get(1) == 't' && url.get(2) == 't' && url.get(3) == 'p' && url.get(4) == ':' && url.get(5) == '/' && url.get(6) == '/'
        if(!ok && n >= 9) {
            var lb = url.get(0) == 'l' && url.get(1) == 'i' && url.get(2) == 'b' && url.get(3) == 's' && url.get(4) == 'q' && url.get(5) == 'l' && url.get(6) == ':' && url.get(7) == '/' && url.get(8) == '/'
            if(lb) { return true }
        }
        return ok
    }

    private func normalize_url(url : *string) : string {
        var n = url.size()
        if(n >= 9 && url.get(0) == 'l' && url.get(1) == 'i' && url.get(2) == 'b' && url.get(3) == 's' && url.get(4) == 'q' && url.get(5) == 'l' && url.get(6) == ':' && url.get(7) == '/' && url.get(8) == '/') {
            var out = string("https://")
            out.append_view(url.to_view().skip(9))
            return out
        }
        return url.copy()
    }

    public func make_client(url : string, token : string) : DbClient {
        if(is_remote_url(&raw url)) {
            var http_url = normalize_url(&raw url)
            printf("[underlayer_db] Connecting to remote database: %s\n", http_url.data())
            var client = http::Client()
            client.default_timeout_secs = 15
            var result = DbClient {
                is_sqlite = false,
                sqlite_handle = null,
                turso_client = client,
                turso_url = http_url.copy(),
                turso_token = token.copy()
            }
            return result
        }
        var h : *mut sqlite::sqlite3 = null
        var open_res = sqlite::ffi::sqlite3_open_v2(url.data(), &raw mut h, (sqlite::OpenFlag.READWRITE | sqlite::OpenFlag.CREATE) as int, null)
        if(open_res != 0 || h == null) {
            printf("[underlayer_db] Error opening SQLite database: rc=%d\n", open_res)
            var result = DbClient {
                is_sqlite = true,
                sqlite_handle = null,
                turso_client = http::Client(),
                turso_url = string(),
                turso_token = string()
            }
            return result
        }
        // Apply PRAGMAs directly via FFI
        apply_pragmas(h)
        var local_result = DbClient {
            is_sqlite = true,
            sqlite_handle = h,
            turso_client = http::Client(),
            turso_url = string(),
            turso_token = string()
        }
        return local_result
    }

    private func apply_pragmas(h : *mut sqlite::sqlite3) {
        var errmsg : *mut char = null
        var pragma1 = string("PRAGMA journal_mode=WAL")
        sqlite::ffi::sqlite3_exec(h, pragma1.data(), null, null, &raw mut errmsg)
        if(errmsg != null) { sqlite::ffi::sqlite3_free(errmsg as *void); errmsg = null }
        var pragma2 = string("PRAGMA busy_timeout=5000")
        sqlite::ffi::sqlite3_exec(h, pragma2.data(), null, null, &raw mut errmsg)
        if(errmsg != null) { sqlite::ffi::sqlite3_free(errmsg as *void); errmsg = null }
        var pragma3 = string("PRAGMA synchronous=NORMAL")
        sqlite::ffi::sqlite3_exec(h, pragma3.data(), null, null, &raw mut errmsg)
        if(errmsg != null) { sqlite::ffi::sqlite3_free(errmsg as *void); errmsg = null }
        var pragma4 = string("PRAGMA foreign_keys=ON")
        sqlite::ffi::sqlite3_exec(h, pragma4.data(), null, null, &raw mut errmsg)
        if(errmsg != null) { sqlite::ffi::sqlite3_free(errmsg as *void); errmsg = null }
    }

    public func exec_sql(db : *DbClient, sql : *string) : ExecResult {
        if(db.is_sqlite && db.sqlite_handle != null) {
            var errmsg : *mut char = null
            sqlite::ffi::sqlite3_exec(db.sqlite_handle, sql.data(), null, null, &raw mut errmsg)
            if(errmsg != null) {
                sqlite::ffi::sqlite3_free(errmsg as *void)
            }
            var result = ExecResult {
                last_insert_rowid = sqlite::ffi::sqlite3_last_insert_rowid(db.sqlite_handle),
                rows_affected = sqlite::ffi::sqlite3_changes(db.sqlite_handle) as i64
            }
            return result
        }
        var result = ExecResult { last_insert_rowid: 0, rows_affected: 0 }
        return result
    }

    public func query_sql(db : *DbClient, sql : *string) : QueryResult {
        var result = QueryResult {
            columns = vector<string>(),
            rows = vector<QueryRow>(),
            rows_affected = 0
        }
        if(db.is_sqlite && db.sqlite_handle != null) {
            var h_stmt : *mut sqlite::sqlite3_stmt = null
            var res = sqlite::ffi::sqlite3_prepare_v2(db.sqlite_handle, sql.data(), sql.size() as int, &raw mut h_stmt, null)
            if(res != 0 || h_stmt == null) {
                return result
            }
            var col_count = sqlite::ffi::sqlite3_column_count(h_stmt)
            var ci : int = 0
            while(ci < col_count) {
                var col_name_ptr = sqlite::ffi::sqlite3_column_name(h_stmt, ci)
                var col_str = string()
                if(col_name_ptr != null) {
                    var ch_idx : size_t = 0
                    while(col_name_ptr[ch_idx] != 0) { col_str.append(col_name_ptr[ch_idx]); ch_idx = ch_idx + 1 }
                }
                result.columns.push(col_str)
                ci = ci + 1
            }
            while(true) {
                var step_res = sqlite::ffi::sqlite3_step(h_stmt)
                if(step_res != 100) { break }
                var row = QueryRow { vals = vector<string>() }
                var ri : int = 0
                while(ri < col_count) {
                    var text_ptr = sqlite::ffi::sqlite3_column_text(h_stmt, ri)
                    var val_str = string()
                    if(text_ptr != null) {
                        var vi : size_t = 0
                        while(text_ptr[vi] != 0) { val_str.append(text_ptr[vi]); vi = vi + 1 }
                    }
                    row.vals.push(val_str)
                    ri = ri + 1
                }
                result.rows.push(row)
            }
            sqlite::ffi::sqlite3_finalize(h_stmt)
            return result
        }
        return result
    }

    public func query_sql_single(db : *DbClient, sql : *string) : vector<string> {
        var result = query_sql(db, sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            var vals = vector<string>()
            var i : size_t = 0
            while(i < row.vals.size()) {
                var s_ptr = row.vals.get_ptr(i)
                vals.push(s_ptr.copy())
                i = i + 1
            }
            return vals
        }
        return vector<string>()
    }

    public func close(db : *DbClient) {
        if(db.is_sqlite && db.sqlite_handle != null) {
            sqlite::ffi::sqlite3_close_v2(db.sqlite_handle)
        }
    }
}
