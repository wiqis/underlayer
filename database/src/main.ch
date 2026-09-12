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
        var sqlite_conn : sqlite::Database
        var turso_client : http::Client
        var turso_url : string
        var turso_token : string
    }

    private struct QueryCallbackData {
        var result : *QueryResult
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
                sqlite_conn = unsafe(sqlite::Database.make(null)),
                turso_client = client,
                turso_url = http_url.copy(),
                turso_token = token.copy()
            }
            return result
        }
        var db_result = sqlite::Database.open(url.to_view())
        if(db_result is Result.Err) {
            printf("[underlayer_db] Error opening SQLite database\n")
            var result = DbClient {
                is_sqlite = true,
                sqlite_conn = unsafe(sqlite::Database.make(null)),
                turso_client = http::Client(),
                turso_url = string(),
                turso_token = string()
            }
            return result
        }
        var Ok(db) = db_result else unreachable
        apply_sqlite_pragmas(&raw db)
        var local_result = DbClient {
            is_sqlite = true,
            sqlite_conn = unsafe(sqlite::Database.make(null)),
            turso_client = http::Client(),
            turso_url = string(),
            turso_token = string()
        }
        // Transfer ownership of database connection
        unsafe { memcpy(&raw mut local_result.sqlite_conn, &raw db, sizeof(sqlite::Database)) }
        return local_result
    }

    private func apply_sqlite_pragmas(db : *sqlite::Database) {
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA busy_timeout=5000")
        db.execute("PRAGMA synchronous=NORMAL")
        db.execute("PRAGMA foreign_keys=ON")
    }

    public func exec_sql(db : *DbClient, sql : *string) : ExecResult {
        if(db.is_sqlite) {
            db.sqlite_conn.execute(sql.to_view())
            var result = ExecResult {
                last_insert_rowid = db.sqlite_conn.last_insert_rowid(),
                rows_affected = db.sqlite_conn.changes() as i64
            }
            return result
        }
        // Turso HTTP path (Phase 2)
        var result = ExecResult { last_insert_rowid = 0, rows_affected = 0 }
        return result
    }

    public func query_sql(db : *DbClient, sql : *string) : QueryResult {
        var result = QueryResult {
            columns = vector<string>(),
            rows = vector<QueryRow>(),
            rows_affected = 0
        }
        if(db.is_sqlite) {
            var stmt_res = db.sqlite_conn.prepare(sql.to_view())
            if(stmt_res is Result.Err) {
                return result
            }
            var Ok(stmt) = stmt_res else unreachable
            // Get column names from first step
            var col_count = stmt.column_count()
            var ci : int = 0
            while(ci < col_count) {
                var col_name = stmt.column_name(ci)
                var col_str = string()
                var ch_idx : size_t = 0
                while(ch_idx < col_name.size()) {
                    col_str.append(col_name.get(ch_idx))
                    ch_idx = ch_idx + 1
                }
                result.columns.push(col_str)
                ci = ci + 1
            }
            // Iterate rows
            while(true) {
                var step_res = stmt.step()
                if(step_res is Result.Err) { break }
                var Ok(has_row) = step_res else unreachable
                if(!has_row) { break }
                var row = QueryRow { vals = vector<string>() }
                var ri : int = 0
                while(ri < col_count) {
                    var text = stmt.column_text(ri)
                    var val_str = string()
                    var vi : size_t = 0
                    while(vi < text.size()) {
                        val_str.append(text.get(vi))
                        vi = vi + 1
                    }
                    row.vals.push(val_str)
                    ri = ri + 1
                }
                result.rows.push(row)
            }
            return result
        }
        // Turso HTTP path (Phase 2)
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
        if(db.is_sqlite) {
            db.sqlite_conn.close()
        }
    }
}
