// underlayer_repository — Bookmark CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct Bookmark {
        var id : string
        var learner_id : string
        var concept_id : string
        var course_id : string
        var note : string
        var created_at : i64

        @make
        func make() : Bookmark {
            return Bookmark {
                id = string(),
                learner_id = string(),
                concept_id = string(),
                course_id = string(),
                note = string(),
                created_at = 0
            }
        }
    }

    private func generate_bookmark_id() : string {
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

    public func add_bookmark(db : *DbClient, learner_id : &string, concept_id : &string, course_id : &string, note : &string) : string {
        var bookmark_id = generate_bookmark_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO bookmarks (id, learner_id, concept_id, course_id, note, created_at) VALUES ('")
        sql.append_string(&bookmark_id)
        sql.append_view("', '")
        sql.append_view(learner_id.to_view())
        sql.append_view("', '")
        sql.append_view(concept_id.to_view())
        sql.append_view("', '")
        sql.append_view(course_id.to_view())
        sql.append_view("', '")
        sql.append_view(note.to_view())
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return bookmark_id
    }

    public func remove_bookmark(db : *DbClient, learner_id : &string, concept_id : &string) {
        var sql = string("DELETE FROM bookmarks WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND concept_id = '")
        sql.append_view(concept_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_bookmarks(db : *DbClient, learner_id : &string) : vector<Bookmark> {
        var bookmarks = vector<Bookmark>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, note, created_at FROM bookmarks WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 6) {
                var bm = Bookmark::make()
                bm.id = row.vals.get_ptr(0).copy()
                bm.learner_id = row.vals.get_ptr(1).copy()
                bm.concept_id = row.vals.get_ptr(2).copy()
                bm.course_id = row.vals.get_ptr(3).copy()
                bm.note = row.vals.get_ptr(4).copy()
                bm.created_at = parse_i64(row.vals.get_ptr(5).to_view())
                bookmarks.push(bm)
            }
            ri = ri + 1
        }
        return bookmarks
    }

    public func get_bookmarks_for_course(db : *DbClient, learner_id : &string, course_id : &string) : vector<Bookmark> {
        var bookmarks = vector<Bookmark>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, note, created_at FROM bookmarks WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND course_id = '")
        sql.append_view(course_id.to_view())
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 6) {
                var bm = Bookmark::make()
                bm.id = row.vals.get_ptr(0).copy()
                bm.learner_id = row.vals.get_ptr(1).copy()
                bm.concept_id = row.vals.get_ptr(2).copy()
                bm.course_id = row.vals.get_ptr(3).copy()
                bm.note = row.vals.get_ptr(4).copy()
                bm.created_at = parse_i64(row.vals.get_ptr(5).to_view())
                bookmarks.push(bm)
            }
            ri = ri + 1
        }
        return bookmarks
    }

    public func is_bookmarked(db : *DbClient, learner_id : &string, concept_id : &string) : bool {
        var sql = string("SELECT COUNT(*) FROM bookmarks WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND concept_id = '")
        sql.append_view(concept_id.to_view())
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                var count = parse_i64(row.vals.get_ptr(0).to_view())
                if(count > 0) { return true }
            }
        }
        return false
    }

}
