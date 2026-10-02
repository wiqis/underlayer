// underlayer_repository — schema migrations that must be conditional.
//
// WHY THIS FILE EXISTS.  `init_schema` used to run four unconditional
// `ALTER TABLE ... ADD COLUMN` statements right after the matching
// `CREATE TABLE IF NOT EXISTS`.  Both halves always run, and the CREATE TABLE
// already declares the column, so on every single start SQLite refused the
// ALTER with "duplicate column name" and the server logged four failures
// before serving its first request.  The audit called these "benign" because
// the rows end up correct.  They are not benign, they are UNREADABLE: the
// four lines of log are the only evidence a migration is broken, they are
// printed at every boot where nobody reads them, and they teach every future
// reader that this logger cries wolf.  A migration that cannot fail is not a
// migration; a migration that fails silently every boot is worse.
//
// THE FIX.  Ask SQLite whether the column is already there before adding it.
// `PRAGMA table_info(<table>)` returns one row per column with its name in
// column 1.  If the name is present, the migration has already run and there
// is nothing to do -- which is the normal case on every start after the first,
// and costs one prepared statement instead of one failed one.
//
// This is the pattern every future migration must use.  A bare
// `ALTER TABLE ... ADD COLUMN` in this codebase is a defect, because the
// CREATE TABLE above it declares the same column.

using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_repository {

    // True when `table` already has a column named `column`.
    //
    // `table` and `column` are identifiers, not values, so they cannot be
    // bound as SQL parameters -- PRAGMA does not accept a bound argument.
    // Both strings are therefore concatenated into the statement.  They are
    // never request-derived: every call site passes a literal.  The assertion
    // in the comment on each call site is the guard against that changing.
    public func column_exists(db : *DbClient, table : &string_view, column : &string_view) : bool {
        var pragma = string("PRAGMA table_info(")
        pragma.append_view(table)
        pragma.append_view(")")
        var res = underlayer_db::query_sql(db, &raw pragma)
        if(!res.ok) { return false }
        var i : size_t = 0
        while(i < res.rows.size()) {
            var row = res.rows.get_ptr(i)
            // table_info columns: (0)cid (1)name (2)type (3)notnull
            // (4)dflt_value (5)pk -- so the NAME is index 1.
            if(row.vals.size() >= 2) {
                if(row.vals.get_ptr(1).to_view().equals(column)) { return true }
            }
            i = i + 1
        }
        return false
    }

    // Add `column` to `table` only if it is absent.  Returns true when the
    // ALTER ran, false when it was already there or when it failed -- both of
    // which are non-events, and neither is worth a caller's attention.
    //
    // Identifiers, same contract as column_exists: literals only.
    public func add_column_if_missing(db : *DbClient, table : &string_view, column : &string_view, coldef : &string_view) : bool {
        if(column_exists(db, table, column)) { return false }
        var alt = string("ALTER TABLE ")
        alt.append_view(table)
        alt.append_view(" ADD COLUMN ")
        alt.append_view(column)
        alt.append_view(" ")
        alt.append_view(coldef)
        var r = underlayer_db::exec_sql(db, &raw alt)
        if(!r.ok) {
            // Two processes starting at once both see the column missing, and
            // the loser of that race gets "duplicate column name". That is the
            // migration succeeding at a moment too late, not failing.
            var needle = string_view("duplicate column")
            if(r.error_message.to_view().contains(&needle)) { return false }
            return false
        }
        return true
    }

    // The four migrations init_schema used to run unconditionally.  Each one
    // is named for what it adds, not for the ticket that asked for it, so the
    // next reader can tell what it is for without counting lines.
    public func run_conditional_migrations(db : *DbClient) {
        // learners.password_hash -- account management (16.2.1 / 16.1.1, the
        // same column asked for twice; both old statements are replaced).
        var t_learners = string_view("learners")
        var c_ph = string_view("password_hash")
        add_column_if_missing(db, &t_learners, &c_ph, string_view("TEXT"))
        // review_items.ease_factor -- FSRS.  REAL because it is a factor, and
        // the DEFAULT is what every existing row reads back as.
        var t_review = string_view("review_items")
        var c_ef = string_view("ease_factor")
        add_column_if_missing(db, &t_review, &c_ef, string_view("REAL DEFAULT 2.5"))
        // exercises.correct_indices_json -- multi-select answers.  A single
        // correct_index cannot express "both A and C", so multi-select stored
        // its answer as a JSON array and defaulted to the empty array.
        var t_ex = string_view("exercises")
        var c_ci = string_view("correct_indices_json")
        add_column_if_missing(db, &t_ex, &c_ci, string_view("TEXT DEFAULT '[]'"))

        // learning_preferences.onboarding_completed_at -- WHY THIS COLUMN EXISTS
        // RATHER THAN INFERRED FROM daily_goal_minutes.
        //
        // GET /api/onboarding/check decided "has this learner onboarded" by
        // asking whether a learning_preferences row existed.  It does not work:
        // registration itself inserts one (handlers_auth.ch, INSERT OR IGNORE
        // with created_at/updated_at only), so EVERY account has a row from the
        // second it is created and the check answered `completed: true`
        // forever.  Measured: a learner registered, called the check BEFORE
        // doing anything at all, and got {"completed":true}.  The endpoint that
        // gates the whole onboarding flow could therefore never fire, which is
        // why onboarding was reachable only by typing its URL.
        //
        // Comparing daily_goal_minutes against its DEFAULT of 20 is the
        // obvious next guess and it is wrong too: the column defaults to 20, so
        // a learner who genuinely picks "20 minutes a day" becomes
        // indistinguishable from one who never onboarded.  The gate then either
        // never fires or fires forever, depending on a coincidence.
        //
        // An explicit timestamp is the only answer a default cannot produce.
        // NULL means "has not onboarded"; a value means "onboarded at this
        // time" -- and the value is also the answer to "when", which the
        // inferred version could not give at all.
        var t_pref = string_view("learning_preferences")
        var c_oc = string_view("onboarding_completed_at")
        add_column_if_missing(db, &t_pref, &c_oc, string_view("INTEGER"))
    }

}