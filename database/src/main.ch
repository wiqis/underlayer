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

    // `ok` and `error_message` are here for the same reason they are on
    // ExecResult: a statement SQLite REFUSED must not be readable as a
    // legitimate empty result.  On the read path that mistake is quieter than
    // on the write path -- `query_sql` returns zero rows, every caller reads
    // zero rows as "no such row", and the endpoint answers 404 for a query
    // that never ran.  A 404 is a plausible answer, so nothing looks broken
    // and the real statement never appears anywhere the caller can see.
    // (notes.ch's ownership check hit exactly this: it could not tell "not
    // yours" from "could not be parsed".)
    public struct QueryResult {
        var columns : vector<string>
        var rows : vector<QueryRow>
        var rows_affected : i64
        var ok : bool
        var error_message : string
    }

    // `ok` and `error_message` exist because a statement SQLite REFUSED used to
    // be indistinguishable from one it ran.  exec_sql() freed SQLite's error
    // message and returned `rows_affected`, and callers that ignored the count
    // reported success for a write that never happened -- which is how a
    // display name containing an apostrophe ("D'Arcy") produced a register
    // response carrying a token for a learner row that was never inserted.
    // A write that failed must be able to say so.
    public struct ExecResult {
        var last_insert_rowid : i64
        var rows_affected : i64
        var ok : bool
        var error_message : string
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

    // True when this build cannot actually talk to the configured database.
    //
    // WHY THIS EXISTS, MEASURED.  Pointed the shipped binary at the remote URL
    // the Dockerfile documents as the production setting:
    //
    //     DATABASE_URL="libsql://example.invalid" ./underlayer.exe
    //       -> /api/health   200
    //       -> POST /api/auth/register   {"error":"could not create the account"}
    //
    // The server booted, reported healthy, accepted traffic, and failed every
    // write -- silently, because the remote backend is not implemented and the
    // two branches in exec_sql/query_sql return "no" with a comment nobody
    // reads. So anyone following the deployment documentation gets a site that
    // looks up and loses registrations, and finds out from a user.
    //
    // A half-working configuration is worse than a refused one. Refusing to
    // start is the only answer that is honest at 3am, and it costs one check.
    //
    // WHAT IT IS NOT.  This does not pretend the remote backend works and does
    // not add a partial one. It says no.
    public func is_unusable_config(url : &string, handle_ok : bool) : bool {
        if(is_remote_url(&raw url)) { return true }
        if(!handle_ok) { return true }
        return false
    }

    // The message, so main() and this file cannot word it differently.
    public func unusable_config_message(url : &string) : string {
        var msg = string("[underlayer_db] FATAL: cannot use this database.\n")
        msg.append_view("  DATABASE_URL = ")
        msg.append_string(url)
        msg.append_view("\n")
        if(is_remote_url(&raw url)) {
            msg.append_view("  The remote (Turso/libSQL) backend is NOT IMPLEMENTED in this build.\n")
            msg.append_view("  Every query and every write would fail while the server reported itself healthy.\n")
            msg.append_view("  Use a local SQLite path instead, e.g. DATABASE_URL=./underlayer.db\n")
            msg.append_view("  (mount a volume at that path for durable state.)\n")
        } else {
            msg.append_view("  SQLite could not open that file. Check the path and write permissions.\n")
        }
        return msg
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
            var rc = sqlite::ffi::sqlite3_exec(db.sqlite_handle, sql.data(), null, null, &raw mut errmsg)
            if(errmsg != null) {
                var msg = std::string()
                var i : size_t = 0
                while(errmsg[i] != 0) { msg.append(errmsg[i]); i = i + 1 }
                // Say what failed and why, instead of freeing the message and
                // returning a result that reads like success.  last_insert_rowid
                // is deliberately NOT reported here: after a failed statement
                // sqlite3_last_insert_rowid still holds the rowid of some EARLIER
                // successful insert, which is a value that means nothing here.
                printf("[underlayer_db] SQL FAILED rc=%d: %s\n", rc, msg.data())
                printf("[underlayer_db]   statement: %s\n", sql.data())
                // stdout is block-buffered when the server is started with its
                // output redirected to a log file, so an unflushed report can
                // sit in the buffer until the process exits -- which is exactly
                // when it is least useful.
                fflush(stdout)
                sqlite::ffi::sqlite3_free(errmsg as *void)
                var failed = ExecResult {
                    last_insert_rowid = 0,
                    rows_affected = 0,
                    ok = false,
                    error_message = msg
                }
                return failed
            }
            var result = ExecResult {
                last_insert_rowid = sqlite::ffi::sqlite3_last_insert_rowid(db.sqlite_handle),
                rows_affected = sqlite::ffi::sqlite3_changes(db.sqlite_handle) as i64,
                ok = true,
                error_message = std::string()
            }
            return result
        }
        // The Turso/HTTP backend is not implemented yet, so there is no path
        // here that can have written anything.  Report that rather than
        // returning a zeroed result that looks like "ran, changed nothing".
        var unsupported = ExecResult {
            last_insert_rowid = 0,
            rows_affected = 0,
            ok = false,
            error_message = std::string("remote (Turso) exec is not implemented")
        }
        return unsupported
    }

    public func query_sql(db : *DbClient, sql : *string) : QueryResult {
        var result = QueryResult {
            columns = vector<string>(),
            rows = vector<QueryRow>(),
            rows_affected = 0,
            ok = true,
            error_message = std::string()
        }
        if(db.is_sqlite && db.sqlite_handle != null) {
            var h_stmt : *mut sqlite::sqlite3_stmt = null
            var res = sqlite::ffi::sqlite3_prepare_v2(db.sqlite_handle, sql.data(), sql.size() as int, &raw mut h_stmt, null)
            if(res != 0 || h_stmt == null) {
                // Same defect as exec_sql: a statement SQLite could not even
                // parse returned an empty result, which every caller reads as
                // "no such row".  Name it in the log so a malformed statement
                // cannot be mistaken for a legitimately empty table.
                // sqlite3_errmsg hands back a pointer SQLite owns, so this
                // message is copied out and never freed here -- freeing it
                // would be a free() of a static.
                var perr : *char = sqlite::ffi::sqlite3_errmsg(db.sqlite_handle)
                var pm = std::string()
                if(perr != null) {
                    var pi : size_t = 0
                    while(perr[pi] != 0) { pm.append(perr[pi]); pi = pi + 1 }
                }
                printf("[underlayer_db] SQL PREPARE FAILED rc=%d: %s (%s)\n", res, pm.data(), sql.data())
                fflush(stdout)
                result.ok = false
                result.error_message = pm
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
            // `last_step` keeps the code that ended the loop.  It cannot be read back
            // off the handle afterwards: sqlite3_errcode() reports SQLITE_DONE
            // (101) for a query that ran perfectly, and 101 is not an error, so
            // asking the handle whether it is happy reports every successful
            // query as a failure.  The value the loop actually stopped on is
            // the only honest answer.
            var last_step : int = 100
            while(true) {
                last_step = sqlite::ffi::sqlite3_step(h_stmt)
                if(last_step != 100) { break }
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
            // A step error is the read-path twin of a refused write: SQLite
            // handed back something other than SQLITE_ROW or SQLITE_DONE.
            // Report it rather than returning the rows gathered so far as if
            // the query had completed.
            var step_rc = last_step
            if(step_rc != 101 && step_rc != 0) {
                var serr : *char = sqlite::ffi::sqlite3_errmsg(db.sqlite_handle)
                var sm = std::string()
                if(serr != null) {
                    var si : size_t = 0
                    while(serr[si] != 0) { sm.append(serr[si]); si = si + 1 }
                }
                printf("[underlayer_db] SQL STEP FAILED rc=%d: %s (%s)\n", step_rc, sm.data(), sql.data())
                fflush(stdout)
                result.ok = false
                result.error_message = sm
            }
            sqlite::ffi::sqlite3_finalize(h_stmt)
            return result
        }
        // Same reasoning as exec_sql's remote branch: there is no code path
        // here that could have read anything, so say so instead of returning
        // an empty result that reads as "the table is empty".
        result.ok = false
        result.error_message = std::string("remote (Turso) query is not implemented")
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
