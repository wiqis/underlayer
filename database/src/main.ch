// underlayer_db — database abstraction over SQLite (local) and Turso HTTP (production).
//
// Backend is chosen by the connection URL:
//   * starts with http:// or https:// or libsql:// -> Turso HTTP
//   * anything else (e.g. ./underlayer.db) -> embedded SQLite3
//
// SAFETY SHAPE OF THIS FILE.  Everything above the `ffi` calls below is safe
// code.  The raw SQLite handle is the one thing that has to be a pointer (the C
// library hands it out and owns it), so the pointer is admitted through one
// small set of helpers at the bottom of the file — `open_handle`,
// `exec_raw`, `prepare_raw`, `step_raw`, `finalize_raw`, `errmsg_of`,
// `last_rowid`, `changes_of`, `close_handle`, `copy_c_string` — and every
// `unsafe` in the file belongs to one of them.  That is the FFI boundary: no
// other function in this module touches a raw pointer or calls an `@extern`.
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

    // -----------------------------------------------------------------------
    // The FFI boundary.  Nine helpers, each one extern call, each one `unsafe`.
    // -----------------------------------------------------------------------

    // Opens (or creates) `path`.  A null handle means SQLite refused.
    private func open_handle(path : &string, flags : int) : *mut sqlite::sqlite3 {
        var h : *mut sqlite::sqlite3 = null
        var rc = unsafe(sqlite::ffi::sqlite3_open_v2(path.data(), &raw mut h, flags, null))
        if(rc != 0) { return null }
        return h
    }

    // `sqlite3_exec` with its error message copied out and freed.  The outcome
    // is (rc, message); the caller decides what to report.
    private func exec_raw(h : *mut sqlite::sqlite3, sql : &string) : int {
        var errmsg : *mut char = null
        var rc = unsafe(sqlite::ffi::sqlite3_exec(h, sql.data(), null, null, &raw mut errmsg))
        if(errmsg != null) {
            unsafe { sqlite::ffi::sqlite3_free(errmsg as *void) }
        }
        return rc
    }

    // Statement-only form, for the PRAGMAs whose rc nobody reads.
    private func run_raw(h : *mut sqlite::sqlite3, sql : &string) {
        var _rc = exec_raw(h, sql)
    }

    private func prepare_raw(h : *mut sqlite::sqlite3, sql : &string) : *mut sqlite::sqlite3_stmt {
        var h_stmt : *mut sqlite::sqlite3_stmt = null
        var rc = unsafe(sqlite::ffi::sqlite3_prepare_v2(h, sql.data(), sql.size() as int, &raw mut h_stmt, null))
        if(rc != 0) { return null }
        return h_stmt
    }

    // SQLITE_ROW (100) / SQLITE_DONE (101) / anything else is an error code.
    private func step_raw(stmt : *mut sqlite::sqlite3_stmt) : int {
        return unsafe(sqlite::ffi::sqlite3_step(stmt))
    }

    private func finalize_raw(stmt : *mut sqlite::sqlite3_stmt) {
        unsafe { sqlite::ffi::sqlite3_finalize(stmt) }
    }

    private func column_count_of(stmt : *mut sqlite::sqlite3_stmt) : int {
        return unsafe(sqlite::ffi::sqlite3_column_count(stmt))
    }

    private func column_name_of(stmt : *mut sqlite::sqlite3_stmt, i : int) : string {
        return copy_c_string(unsafe(sqlite::ffi::sqlite3_column_name(stmt, i)))
    }

    private func column_text_of(stmt : *mut sqlite::sqlite3_stmt, i : int) : string {
        return copy_c_string(unsafe(sqlite::ffi::sqlite3_column_text(stmt, i)))
    }

    // SQLite owns this buffer for the life of the connection; it is copied, never
    // freed here.
    private func errmsg_of(h : *mut sqlite::sqlite3) : string {
        return copy_c_string(unsafe(sqlite::ffi::sqlite3_errmsg(h)))
    }

    private func last_rowid(h : *mut sqlite::sqlite3) : i64 {
        return unsafe(sqlite::ffi::sqlite3_last_insert_rowid(h))
    }

    private func changes_of(h : *mut sqlite::sqlite3) : i64 {
        return unsafe(sqlite::ffi::sqlite3_changes(h)) as i64
    }

    private func close_handle(h : *mut sqlite::sqlite3) {
        unsafe { sqlite::ffi::sqlite3_close_v2(h) }
    }

    // Copies a NUL-terminated C string.  Walking the buffer is the raw-pointer
    // part; the result is an owned Chemical string.
    private func copy_c_string(p : *char) : string {
        var out = std::string()
        if(p == null) { return out }
        var i : size_t = 0
        while(unsafe(p[i]) != 0) {
            out.append(unsafe(p[i]))
            i = i + 1
        }
        return out
    }

    // -----------------------------------------------------------------------
    // Safe surface
    // -----------------------------------------------------------------------

    // True when this client is backed by an open SQLite handle.  Callers outside
    // this module ask this instead of reading the handle field.
    public func is_using_sqlite(db : &DbClient) : bool {
        if(!db.is_sqlite) { return false }
        return db.sqlite_handle != null
    }

    public func is_remote_url(url : &string) : bool {
        var n = url.size()
        if(n >= 7 && url.at(0) == 'h' && url.at(1) == 't' && url.at(2) == 't' && url.at(3) == 'p' && url.at(4) == ':' && url.at(5) == '/' && url.at(6) == '/') {
            return true
        }
        if(n >= 9 && url.at(0) == 'l' && url.at(1) == 'i' && url.at(2) == 'b' && url.at(3) == 's' && url.at(4) == 'q' && url.at(5) == 'l' && url.at(6) == ':' && url.at(7) == '/' && url.at(8) == '/') {
            return true
        }
        return false
    }

    private func normalize_url(url : &string) : string {
        if(is_remote_url(url)) {
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
        if(is_remote_url(url)) { return true }
        if(!handle_ok) { return true }
        return false
    }

    // The message, so main() and this file cannot word it differently.
    public func unusable_config_message(url : &string) : string {
        var msg = string("[underlayer_db] FATAL: cannot use this database.\n")
        msg.append_view("  DATABASE_URL = ")
        msg.append_string(url)
        msg.append_view("\n")
        if(is_remote_url(url)) {
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
        if(is_remote_url(&url)) {
            var http_url = normalize_url(&url)
            var connect_msg = string("[underlayer_db] Connecting to remote database: ")
            connect_msg.append_string(&http_url)
            underlayer_core::log_line(&connect_msg)
            // The Turso HTTP backend is not implemented; the client is kept so the
            // DbClient shape does not change when it lands.
            var client = http::Client()
            var result = DbClient {
                is_sqlite = false,
                sqlite_handle = null,
                turso_client = client,
                turso_url = http_url.copy(),
                turso_token = token.copy()
            }
            return result
        }
        var h = open_handle(&url, (sqlite::OpenFlag.READWRITE | sqlite::OpenFlag.CREATE) as int)
        if(h == null) {
            var open_msg = string("[underlayer_db] Error opening SQLite database: ")
            open_msg.append_string(&url)
            underlayer_core::log_line(&open_msg)
            var result = DbClient {
                is_sqlite = true,
                sqlite_handle = null,
                turso_client = http::Client(),
                turso_url = string(),
                turso_token = string()
            }
            return result
        }
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
        var pragma1 = string("PRAGMA journal_mode=WAL")
        run_raw(h, &pragma1)
        var pragma2 = string("PRAGMA busy_timeout=5000")
        run_raw(h, &pragma2)
        var pragma3 = string("PRAGMA synchronous=NORMAL")
        run_raw(h, &pragma3)
        var pragma4 = string("PRAGMA foreign_keys=ON")
        run_raw(h, &pragma4)
    }

    public func exec_sql(db : *DbClient, sql : *string) : ExecResult {
        // One read of the handle at the boundary; the rest of the function works
        // on the copy.
        var h = unsafe(db.sqlite_handle)
        if(h == null) {
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
        var statement = unsafe(sql.copy())
        var rc = exec_raw(h, &statement)
        if(rc != 0) {
            var msg = errmsg_of(h)
            // Say what failed and why, instead of freeing the message and
            // returning a result that reads like success.  last_insert_rowid
            // is deliberately NOT reported here: after a failed statement
            // sqlite3_last_insert_rowid still holds the rowid of some EARLIER
            // successful insert, which is a value that means nothing here.
            var fail_msg = string("[underlayer_db] SQL FAILED rc=")
            fail_msg.append_integer(rc)
            fail_msg.append_view(": ")
            fail_msg.append_string(&msg)
            underlayer_core::log_line(&fail_msg)
            var stmt_msg = string("[underlayer_db]   statement: ")
            stmt_msg.append_string(&statement)
            underlayer_core::log_line(&stmt_msg)
            var failed = ExecResult {
                last_insert_rowid = 0,
                rows_affected = 0,
                ok = false,
                error_message = msg
            }
            return failed
        }
        var result = ExecResult {
            last_insert_rowid = last_rowid(h),
            rows_affected = changes_of(h),
            ok = true,
            error_message = std::string()
        }
        return result
    }

    public func query_sql(db : *DbClient, sql : *string) : QueryResult {
        var result = QueryResult {
            columns = vector<string>(),
            rows = vector<QueryRow>(),
            rows_affected = 0,
            ok = true,
            error_message = std::string()
        }
        var h = unsafe(db.sqlite_handle)
        if(h == null) {
            // Same reasoning as exec_sql's remote branch: there is no code path
            // here that could have read anything, so say so instead of returning
            // an empty result that reads as "the table is empty".
            result.ok = false
            result.error_message = std::string("remote (Turso) query is not implemented")
            return result
        }
        var statement = unsafe(sql.copy())
        var h_stmt = prepare_raw(h, &statement)
        if(h_stmt == null) {
            // Same defect as exec_sql: a statement SQLite could not even
            // parse returned an empty result, which every caller reads as
            // "no such row".  Name it in the log so a malformed statement
            // cannot be mistaken for a legitimately empty table.
            var pm = errmsg_of(h)
            var prep_msg = string("[underlayer_db] SQL PREPARE FAILED: ")
            prep_msg.append_string(&pm)
            prep_msg.append_view(" (")
            prep_msg.append_string(&statement)
            prep_msg.append_view(")")
            underlayer_core::log_line(&prep_msg)
            result.ok = false
            result.error_message = pm
            return result
        }
        var col_count = column_count_of(h_stmt)
        var ci : int = 0
        while(ci < col_count) {
            result.columns.push(column_name_of(h_stmt, ci))
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
            last_step = step_raw(h_stmt)
            if(last_step != 100) { break }
            var row = QueryRow { vals = vector<string>() }
            var ri : int = 0
            while(ri < col_count) {
                row.vals.push(column_text_of(h_stmt, ri))
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
            var sm = errmsg_of(h)
            var step_msg = string("[underlayer_db] SQL STEP FAILED rc=")
            step_msg.append_integer(step_rc as i64)
            step_msg.append_view(": ")
            step_msg.append_string(&sm)
            step_msg.append_view(" (")
            step_msg.append_string(&statement)
            step_msg.append_view(")")
            underlayer_core::log_line(&step_msg)
            result.ok = false
            result.error_message = sm
        }
        finalize_raw(h_stmt)
        return result
    }

    public func query_sql_single(db : *DbClient, sql : *string) : vector<string> {
        var result = query_sql(db, sql)
        if(result.rows.size() > 0) {
            var vals = vector<string>()
            var i : size_t = 0
            while(i < result.rows.at_ref(0).vals.size()) {
                vals.push(result.rows.at_ref(0).vals.at_ref(i).copy())
                i = i + 1
            }
            return vals
        }
        return vector<string>()
    }

    public func close(db : *DbClient) {
        var h = unsafe(db.sqlite_handle)
        if(h != null) {
            close_handle(h)
        }
    }
}
