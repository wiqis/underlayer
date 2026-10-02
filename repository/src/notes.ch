// underlayer_repository — Notes CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct Note {
        var id : string
        var learner_id : string
        var concept_id : string
        var course_id : string
        var content : string
        var section_ref : string
        var created_at : i64
        var updated_at : i64

        @make
        func make() : Note {
            return Note {
                id = string(),
                learner_id = string(),
                concept_id = string(),
                course_id = string(),
                content = string(),
                section_ref = string(),
                created_at = 0,
                updated_at = 0
            }
        }
    }

    private func generate_note_id() : string {
        var buf : [16]u8
        osrand::random_fill(&raw mut buf[0], 16)
        var hex_out : [33]char
        var i0 : size_t = 0
        while(i0 < 33) { hex_out[i0] = 0; i0 = i0 + 1 }
        encoding::hex_encode(&raw buf[0], 16, &raw mut hex_out[0], 33)
        var result = string()
        var i : size_t = 0
        while(i < 32 && hex_out[i] != 0) { result.append(hex_out[i]); i = i + 1 }
        return result
    }

    // Every value goes through sql_escape.  `content` and `section_ref` are
    // free text a learner typed; an apostrophe in either one used to make the
    // INSERT a syntax error that exec_sql logged and every caller read as
    // success, which is the same silent-loss defect the audit found on
    // register (F2) -- the note simply never arrived.
    public func create_note(db : *DbClient, learner_id : &string, concept_id : &string, course_id : &string, content : &string, section_ref : &string) : string {
        var note_id = generate_note_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var lid = sql_escape(learner_id)
        var cid = sql_escape(concept_id)
        var crs = sql_escape(course_id)
        var body = sql_escape(content)
        var sref = sql_escape(section_ref)
        var sql = string("INSERT INTO learner_notes (id, learner_id, concept_id, course_id, content, section_ref, created_at, updated_at) VALUES ('")
        sql.append_string(&note_id)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&cid)
        sql.append_view("', '")
        sql.append_string(&crs)
        sql.append_view("', '")
        sql.append_string(&body)
        sql.append_view("', '")
        sql.append_string(&sref)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return note_id
    }

    // THE OWNERSHIP PREDICATE IS NOT OPTIONAL.  `update_note` was
    // `WHERE id = '...'` and nothing else, while the handler resolved the
    // caller's learner_id and then never used it -- so ANY authenticated
    // learner could rewrite ANY note whose id they could name.  The id is 32
    // hex characters of CSPRNG output, so it is not guessable by brute force,
    // but it is printed in full by GET /api/notes, and a note id shared in a
    // support thread is a note id in someone else's hand.
    //
    // The WHERE clause is the fix; the RETURN VALUE is how the handler learns
    // it took effect.  Zero rows means "not yours, or not there", and both get
    // the same 404 so the endpoint is not an existence oracle for other
    // learners' note ids.
    public func update_note(db : *DbClient, learner_id : &string, note_id : &string, content : &string) : i64 {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var lid_s = sql_escape(learner_id)
        var lid = lid_s.to_view()
        var nid_s = sql_escape(note_id)
        var nid = nid_s.to_view()
        var body_s = sql_escape(content)
        var body = body_s.to_view()
        var sql = string("UPDATE learner_notes SET content = '")
        sql.append_view(&body)
        sql.append_view("', updated_at = ")
        sql.append_view(now_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_view(&nid)
        sql.append_view("' AND learner_id = '")
        sql.append_view(&lid)
        sql.append_view("'")
        var res = underlayer_db::exec_sql(db, &raw sql)
        return res.rows_affected
    }

    // Same defect, same fix: `DELETE FROM learner_notes WHERE id = '...'` let
    // any authenticated learner destroy any note on the platform.
    public func delete_note(db : *DbClient, learner_id : &string, note_id : &string) : i64 {
        var lid_s = sql_escape(learner_id)
        var lid = lid_s.to_view()
        var nid_s = sql_escape(note_id)
        var nid = nid_s.to_view()
        var sql = string("DELETE FROM learner_notes WHERE id = '")
        sql.append_view(&nid)
        sql.append_view("' AND learner_id = '")
        sql.append_view(&lid)
        sql.append_view("'")
        var res = underlayer_db::exec_sql(db, &raw sql)
        return res.rows_affected
    }

    public func get_notes_for_concept(db : *DbClient, learner_id : &string, concept_id : &string) : vector<Note> {
        var notes = vector<Note>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, content, section_ref, created_at, updated_at FROM learner_notes WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND concept_id = '")
        sql.append_view(concept_id.to_view())
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var n = Note::make()
                n.id = row.vals.get_ptr(0).copy()
                n.learner_id = row.vals.get_ptr(1).copy()
                n.concept_id = row.vals.get_ptr(2).copy()
                n.course_id = row.vals.get_ptr(3).copy()
                n.content = row.vals.get_ptr(4).copy()
                n.section_ref = row.vals.get_ptr(5).copy()
                n.created_at = parse_i64(row.vals.get_ptr(6).to_view())
                n.updated_at = parse_i64(row.vals.get_ptr(7).to_view())
                notes.push(n)
            }
            ri = ri + 1
        }
        return notes
    }

    public func get_notes_for_course(db : *DbClient, learner_id : &string, course_id : &string) : vector<Note> {
        var notes = vector<Note>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, content, section_ref, created_at, updated_at FROM learner_notes WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND course_id = '")
        sql.append_view(course_id.to_view())
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var n = Note::make()
                n.id = row.vals.get_ptr(0).copy()
                n.learner_id = row.vals.get_ptr(1).copy()
                n.concept_id = row.vals.get_ptr(2).copy()
                n.course_id = row.vals.get_ptr(3).copy()
                n.content = row.vals.get_ptr(4).copy()
                n.section_ref = row.vals.get_ptr(5).copy()
                n.created_at = parse_i64(row.vals.get_ptr(6).to_view())
                n.updated_at = parse_i64(row.vals.get_ptr(7).to_view())
                notes.push(n)
            }
            ri = ri + 1
        }
        return notes
    }

    public func search_notes(db : *DbClient, learner_id : &string, query : &string) : vector<Note> {
        var notes = vector<Note>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, content, section_ref, created_at, updated_at FROM learner_notes WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND content LIKE '%")
        sql.append_view(query.to_view())
        sql.append_view("%' ORDER BY updated_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var n = Note::make()
                n.id = row.vals.get_ptr(0).copy()
                n.learner_id = row.vals.get_ptr(1).copy()
                n.concept_id = row.vals.get_ptr(2).copy()
                n.course_id = row.vals.get_ptr(3).copy()
                n.content = row.vals.get_ptr(4).copy()
                n.section_ref = row.vals.get_ptr(5).copy()
                n.created_at = parse_i64(row.vals.get_ptr(6).to_view())
                n.updated_at = parse_i64(row.vals.get_ptr(7).to_view())
                notes.push(n)
            }
            ri = ri + 1
        }
        return notes
    }

    public func get_all_notes(db : *DbClient, learner_id : &string) : vector<Note> {
        var notes = vector<Note>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, content, section_ref, created_at, updated_at FROM learner_notes WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' ORDER BY updated_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var n = Note::make()
                n.id = row.vals.get_ptr(0).copy()
                n.learner_id = row.vals.get_ptr(1).copy()
                n.concept_id = row.vals.get_ptr(2).copy()
                n.course_id = row.vals.get_ptr(3).copy()
                n.content = row.vals.get_ptr(4).copy()
                n.section_ref = row.vals.get_ptr(5).copy()
                n.created_at = parse_i64(row.vals.get_ptr(6).to_view())
                n.updated_at = parse_i64(row.vals.get_ptr(7).to_view())
                notes.push(n)
            }
            ri = ri + 1
        }
        return notes
    }

}
