// G13 — one-shot tokens for the guest → account progress takeover.
//
// ALL SQL lives here. A token is minted as 64 hex characters of CSPRNG output
// and stored only as its SHA-256. `takeover_token_consume` is an atomic
// compare-and-set: UPDATE ... WHERE used_at = 0 returns rows_affected 1 exactly
// once. A replay therefore cannot reach the replay path (and no FSRS column is
// touched anywhere in this file).
using std::string
using underlayer_db::DbClient

public namespace underlayer_repository {

    public func takeover_token_create(db : *DbClient) : string {
        var token = underlayer_core::random_hex(32)
        if(token.size() == 0) { return string() }
        var hash_view = token.to_view()
        var hash = underlayer_core::sha256_hex(&hash_view)
        var hash_s = sql_escape(&hash)
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var sql = string("INSERT INTO progress_takeover_tokens (token_hash, created_at, used_at, learner_id) VALUES ('")
        sql.append_string(&hash_s)
        sql.append_view("', ")
        sql.append_view(now.to_view())
        sql.append_view(", 0, '')")
        var result = underlayer_db::exec_sql(db, &raw sql)
        if(!result.ok) { return string() }
        return token
    }

    // Atomically mark the token used for this learner. Returns false for an
    // unknown token, an already-used token or a token older than one hour.
    public func takeover_token_consume(db : *DbClient, token : &string, learner_id : &string) : bool {
        if(token.size() != 64 || learner_id.size() == 0) { return false }
        var token_view = token.to_view()
        var hash = underlayer_core::sha256_hex(&token_view)
        var hash_s = sql_escape(&hash)
        var lid = sql_escape(learner_id)
        var now_i = underlayer_core::current_timestamp()
        var now = underlayer_core::int_to_string(now_i)
        var cutoff = underlayer_core::int_to_string(now_i - 3600)
        var sql = string("UPDATE progress_takeover_tokens SET used_at = ")
        sql.append_string(&now)
        sql.append_view(", learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' WHERE token_hash = '")
        sql.append_string(&hash_s)
        sql.append_view("' AND used_at = 0 AND created_at >= ")
        sql.append_view(cutoff.to_view())
        var result = underlayer_db::exec_sql(db, &raw sql)
        return result.ok && result.rows_affected > 0
    }

}
