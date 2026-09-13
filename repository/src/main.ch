// underlayer_repository — ALL SQL lives here.
// Schema initialization + CRUD for Phase 1.
// Course loading reads manifest.json from disk.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_db::QueryResult
using underlayer_models::Course
using underlayer_models::Module
using underlayer_models::ConceptRef
using underlayer_models::Manifest
using underlayer_models::Learner
using underlayer_models::ConceptState
using underlayer_models::ReviewItem

public namespace underlayer_repository {

    public func init_schema(db : *DbClient) {
        var sql = string("CREATE TABLE IF NOT EXISTS learners (id TEXT PRIMARY KEY, name TEXT, email TEXT UNIQUE, created_at INTEGER)")
        underlayer_db::exec_sql(db, &raw sql)
        var sql2 = string("CREATE TABLE IF NOT EXISTS concept_states (learner_id TEXT, concept_id TEXT, course_id TEXT, status TEXT DEFAULT 'not_started', attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0, streak INTEGER DEFAULT 0, last_studied INTEGER, next_review INTEGER, difficulty_rating REAL DEFAULT 0, PRIMARY KEY (learner_id, concept_id, course_id))")
        underlayer_db::exec_sql(db, &raw sql2)
        var sql3 = string("CREATE TABLE IF NOT EXISTS review_items (id TEXT PRIMARY KEY, learner_id TEXT, concept_id TEXT, course_id TEXT, type TEXT, front TEXT, back TEXT, difficulty REAL DEFAULT 5.0, stability REAL DEFAULT 1.0, retrievability REAL DEFAULT 1.0, next_review INTEGER, last_review INTEGER, reps INTEGER DEFAULT 0, lapses INTEGER DEFAULT 0)")
        underlayer_db::exec_sql(db, &raw sql3)
        var sql4 = string("CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, learner_id TEXT, start_time INTEGER, end_time INTEGER, type TEXT, exercises_attempted INTEGER DEFAULT 0, exercises_correct INTEGER DEFAULT 0)")
        underlayer_db::exec_sql(db, &raw sql4)
        var idx1 = string("CREATE INDEX IF NOT EXISTS idx_cs_learner ON concept_states(learner_id)")
        underlayer_db::exec_sql(db, &raw idx1)
        var idx2 = string("CREATE INDEX IF NOT EXISTS idx_ri_learner ON review_items(learner_id)")
        underlayer_db::exec_sql(db, &raw idx2)
        var idx3 = string("CREATE INDEX IF NOT EXISTS idx_ri_due ON review_items(next_review)")
        underlayer_db::exec_sql(db, &raw idx3)
        var idx4 = string("CREATE INDEX IF NOT EXISTS idx_sess_learner ON sessions(learner_id)")
        underlayer_db::exec_sql(db, &raw idx4)
    }

    // Helper: parse i64 from string_view
    private func parse_i64(v : std::string_view) : i64 {
        var result : i64 = 0
        var negative = false
        var i : size_t = 0
        if(v.size() > 0 && v.get(0) == '-') { negative = true; i = 1 }
        while(i < v.size()) {
            var c = v.get(i)
            if(c >= '0' && c <= '9') { result = result * 10 + (c as i64 - 48) }
            i = i + 1
        }
        if(negative) { result = -result }
        return result
    }

    // Helper: parse int from string_view
    private func parse_int(v : std::string_view) : int {
        return parse_i64(v) as int
    }

    // Helper: extract string from JsonValue
    private func json_str(val : *JsonValue) : string {
        if(val == null) { return string() }
        if(val is JsonValue.String) {
            var String(s) = *val else unreachable
            return s.copy()
        }
        return string()
    }

    // Helper: extract i64 from JsonValue.Number
    private func json_i64(val : *JsonValue) : i64 {
        if(val == null) { return 0 }
        if(val is JsonValue.Number) {
            var Number(s) = *val else unreachable
            return parse_i64(s.to_view())
        }
        return 0
    }

    // Helper: extract int from JsonValue.Number
    private func json_int(val : *JsonValue) : int {
        return json_i64(val) as int
    }

    // Helper: get field from JsonValue.Object
    private func json_get(obj : *JsonValue, key : *char) : *mut JsonValue {
        if(obj == null) { return null }
        if(!(obj is JsonValue.Object)) { return null }
        var Object(map) = *obj else unreachable
        var k = string::make_no_len(key)
        return map.get_ptr(&k)
    }

    // Helper: get string field from JsonValue.Object
    private func json_get_str(obj : *JsonValue, key : *char) : string {
        var field = json_get(obj, key)
        return json_str(field)
    }

    // Helper: get int field from JsonValue.Object
    private func json_get_int(obj : *JsonValue, key : *char) : int {
        var field = json_get(obj, key)
        return json_int(field)
    }

    // ---- Course Loading ----

    // Load a course from disk (reads manifest.json), falls back to hardcoded data
    public func load_course(courses_dir : &string, course_id : &string) : Course {
        // Try loading from disk first
        var disk_course = load_course_from_disk(courses_dir, course_id)
        if(disk_course.id.size() > 0) {
            return disk_course
        }
        // Fallback to hardcoded data
        return load_course_hardcoded(course_id)
    }

    // Load a course from manifest.json on disk
    private func load_course_from_disk(courses_dir : &string, course_id : &string) : Course {
        var course = Course::make()

        // Build path: courses_dir/course_id/manifest.json
        var path = courses_dir.copy()
        path.append_view(string_view("/"))
        path.append_string(course_id)
        path.append_view(string_view("/manifest.json"))

        // Read the file
        var content_res = fs::read_entire_file(path.data())
        if(content_res is std::Result.Err) {
            return course
        }
        var Ok(bytes) = content_res else unreachable

        // Convert bytes to string
        var text = string()
        var i : size_t = 0
        while(i < bytes.size()) {
            text.append(bytes.get(i) as char)
            i = i + 1
        }

        // Parse JSON
        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) {
            return course
        }
        var Ok(root) = json_res else unreachable

        // Extract fields
        course.id = json_get_str(&raw root, "id")
        course.title = json_get_str(&raw root, "title")
        course.version = json_get_int(&raw root, "version")
        if(course.version == 0) { course.version = 1 }

        // Parse modules array
        var modules_val = json_get(&raw root, "modules")
        if(modules_val != null && modules_val is JsonValue.Array) {
            var Array(modules_arr) = *modules_val else unreachable
            var mi : size_t = 0
            while(mi < modules_arr.size()) {
                var mod_val = modules_arr.get_ptr(mi)
                var mod = Module::make()
                mod.id = json_get_str(mod_val, "id")
                mod.title = json_get_str(mod_val, "title")
                mod.order = mi as int + 1

                // Parse concepts array inside module
                var concepts_val = json_get(mod_val, "concepts")
                if(concepts_val != null && concepts_val is JsonValue.Array) {
                    var Array(concepts_arr) = *concepts_val else unreachable
                    var ci : size_t = 0
                    while(ci < concepts_arr.size()) {
                        var cval = concepts_arr.get_ptr(ci)
                        if(cval is JsonValue.String) {
                            var String(cid) = *cval else unreachable
                            mod.concepts.push(cid.copy())
                        }
                        ci = ci + 1
                    }
                }
                course.modules.push(mod)
                mi = mi + 1
            }
        }

        // Parse concepts array
        var concepts_val = json_get(&raw root, "concepts")
        if(concepts_val != null && concepts_val is JsonValue.Array) {
            var Array(concepts_arr) = *concepts_val else unreachable
            var ci : size_t = 0
            while(ci < concepts_arr.size()) {
                var cval = concepts_arr.get_ptr(ci)
                var cref = ConceptRef::make()
                if(cval is JsonValue.Object) {
                    cref.id = json_get_str(cval, "id")
                    cref.title = json_get_str(cval, "title")
                    cref.module_id = json_get_str(cval, "module_id")
                    cref.description = json_get_str(cval, "description")
                } else if(cval is JsonValue.String) {
                    // Simple string reference — use as concept id
                    var String(cid) = *cval else unreachable
                    cref.id = cid.copy()
                }
                course.concepts.push(cref)
                ci = ci + 1
            }
        }

        return course
    }

    // Hardcoded course data (fallback when manifest.json is missing)
    private func load_course_hardcoded(course_id : &string) : Course {
        var course = Course::make()
        var elf_check = string("elf")
        if(course_id.equals(&elf_check)) {
            course.id = course_id.copy()
            course.title = string("Executable and Linkable Format")
            course.version = 1

            var mod1 = Module::make()
            mod1.id = string("fundamentals")
            mod1.title = string("Fundamentals")
            mod1.order = 1
            mod1.concepts.push(string("bytes"))
            mod1.concepts.push(string("binary-representation"))
            mod1.concepts.push(string("file-layout"))
            course.modules.push(mod1)

            var mod2 = Module::make()
            mod2.id = string("elf-header")
            mod2.title = string("ELF Header")
            mod2.order = 2
            mod2.concepts.push(string("elf-identification"))
            mod2.concepts.push(string("elf-header-fields"))
            mod2.concepts.push(string("entry-point"))
            course.modules.push(mod2)

            var mod3 = Module::make()
            mod3.id = string("program-headers")
            mod3.title = string("Program Headers")
            mod3.order = 3
            mod3.concepts.push(string("program-header-table"))
            mod3.concepts.push(string("segment-types"))
            mod3.concepts.push(string("memory-mapping"))
            course.modules.push(mod3)

            var mod4 = Module::make()
            mod4.id = string("sections")
            mod4.title = string("Sections")
            mod4.order = 4
            mod4.concepts.push(string("section-header-table"))
            mod4.concepts.push(string("common-sections"))
            mod4.concepts.push(string("section-vs-segment"))
            course.modules.push(mod4)

            var c1 = ConceptRef::make()
            c1.id = string("bytes")
            c1.title = string("Bytes and Binary")
            c1.module_id = string("fundamentals")
            c1.description = string("Understanding bytes.")
            course.concepts.push(c1)

            var c2 = ConceptRef::make()
            c2.id = string("binary-representation")
            c2.title = string("Binary Representation")
            c2.module_id = string("fundamentals")
            c2.description = string("How bytes encode numbers.")
            course.concepts.push(c2)

            var c3 = ConceptRef::make()
            c3.id = string("file-layout")
            c3.title = string("File Layout")
            c3.module_id = string("fundamentals")
            c3.description = string("How an ELF file is organized.")
            course.concepts.push(c3)

            var c4 = ConceptRef::make()
            c4.id = string("elf-identification")
            c4.title = string("ELF Identification")
            c4.module_id = string("elf-header")
            c4.description = string("The e_ident array.")
            course.concepts.push(c4)

            var c5 = ConceptRef::make()
            c5.id = string("elf-header-fields")
            c5.title = string("ELF Header Fields")
            c5.module_id = string("elf-header")
            c5.description = string("Every field in the ELF header.")
            course.concepts.push(c5)

            var c6 = ConceptRef::make()
            c6.id = string("entry-point")
            c6.title = string("Entry Point")
            c6.module_id = string("elf-header")
            c6.description = string("Where execution begins.")
            course.concepts.push(c6)

            var c7 = ConceptRef::make()
            c7.id = string("program-header-table")
            c7.title = string("Program Header Table")
            c7.module_id = string("program-headers")
            c7.description = string("How segments are loaded.")
            course.concepts.push(c7)

            var c8 = ConceptRef::make()
            c8.id = string("segment-types")
            c8.title = string("Segment Types")
            c8.module_id = string("program-headers")
            c8.description = string("PT_LOAD, PT_DYNAMIC, PT_INTERP.")
            course.concepts.push(c8)

            var c9 = ConceptRef::make()
            c9.id = string("memory-mapping")
            c9.title = string("Memory Mapping")
            c9.module_id = string("program-headers")
            c9.description = string("File offsets to virtual addresses.")
            course.concepts.push(c9)

            var c10 = ConceptRef::make()
            c10.id = string("section-header-table")
            c10.title = string("Section Header Table")
            c10.module_id = string("sections")
            c10.description = string("The section descriptor table.")
            course.concepts.push(c10)

            var c11 = ConceptRef::make()
            c11.id = string("common-sections")
            c11.title = string("Common Sections")
            c11.module_id = string("sections")
            c11.description = string(".text, .data, .bss, .rodata.")
            course.concepts.push(c11)

            var c12 = ConceptRef::make()
            c12.id = string("section-vs-segment")
            c12.title = string("Section vs Segment")
            c12.module_id = string("sections")
            c12.description = string("Why they are different.")
            course.concepts.push(c12)
        }
        return course
    }

    // List all courses — scans courses_dir for subdirectories with manifest.json
    public func list_courses(courses_dir : &string) : vector<Course> {
        var courses = vector<Course>()
        // Known course IDs (directory scanning not available without fs::read_dir)
        var known = vector<string>()
        known.push(string("elf"))
        var i : size_t = 0
        while(i < known.size()) {
            var cid_ptr = known.get_ptr(i)
            var cid_val = cid_ptr.copy()
            var course = load_course(courses_dir, &cid_val)
            if(course.id.size() > 0) {
                courses.push(course)
            }
            i = i + 1
        }
        return courses
    }

    // ---- Learner CRUD ----

    public func create_learner(db : *DbClient, learner_id : &string, name : &string, email : &string) {
        var sql = string("INSERT OR IGNORE INTO learners (id, name, email, created_at) VALUES ('")
        sql.append_string(learner_id)
        sql.append_view("', '")
        sql.append_string(name)
        sql.append_view("', '")
        sql.append_string(email)
        sql.append_view("', ")
        var ts = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        sql.append_view(ts.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_learner(db : *DbClient, learner_id : &string) : Learner {
        var learner = Learner::make()
        var sql = string("SELECT id, name, email, created_at FROM learners WHERE id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 4) {
                learner.id = row.vals.get_ptr(0).copy()
                learner.name = row.vals.get_ptr(1).copy()
                learner.email = row.vals.get_ptr(2).copy()
                learner.created_at = parse_i64(row.vals.get_ptr(3).to_view())
            }
        }
        return learner
    }

    // ---- Concept State CRUD ----

    public func get_concept_state(db : *DbClient, learner_id : &string, concept_id : &string, course_id : &string) : ConceptState {
        var state = ConceptState::make()
        var sql = string("SELECT status, attempts, correct, streak, last_studied, next_review, difficulty_rating FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 7) {
                state.learner_id = learner_id.copy()
                state.concept_id = concept_id.copy()
                state.course_id = course_id.copy()
                state.status = row.vals.get_ptr(0).copy()
                state.attempts = parse_i64(row.vals.get_ptr(1).to_view()) as int
                state.correct = parse_i64(row.vals.get_ptr(2).to_view()) as int
                state.streak = parse_i64(row.vals.get_ptr(3).to_view()) as int
                state.last_studied = parse_i64(row.vals.get_ptr(4).to_view())
                state.next_review = parse_i64(row.vals.get_ptr(5).to_view())
            }
        }
        return state
    }

    public func upsert_concept_state(db : *DbClient, state : *ConceptState) {
        var sql = string("INSERT OR REPLACE INTO concept_states (learner_id, concept_id, course_id, status, attempts, correct, streak, last_studied, next_review, difficulty_rating) VALUES ('")
        var lid = state.learner_id.copy()
        sql.append_string(&lid)
        sql.append_view("', '")
        var cid = state.concept_id.copy()
        sql.append_string(&cid)
        sql.append_view("', '")
        var crsid = state.course_id.copy()
        sql.append_string(&crsid)
        sql.append_view("', '")
        var sstat = state.status.copy()
        sql.append_string(&sstat)
        sql.append_view("', ")
        var a = underlayer_core::int_to_string(state.attempts as i64)
        sql.append_view(a.to_view())
        sql.append_view(", ")
        var b = underlayer_core::int_to_string(state.correct as i64)
        sql.append_view(b.to_view())
        sql.append_view(", ")
        var c = underlayer_core::int_to_string(state.streak as i64)
        sql.append_view(c.to_view())
        sql.append_view(", ")
        var d = underlayer_core::int_to_string(state.last_studied)
        sql.append_view(d.to_view())
        sql.append_view(", ")
        var e = underlayer_core::int_to_string(state.next_review)
        sql.append_view(e.to_view())
        sql.append_view(", ")
        var f = underlayer_core::int_to_string(state.difficulty_rating as i64)
        sql.append_view(f.to_view())
        sql.append_view(".0)")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_all_concept_states(db : *DbClient, learner_id : &string, course_id : &string) : vector<ConceptState> {
        var states = vector<ConceptState>()
        var sql = string("SELECT concept_id, status, attempts, correct, streak, last_studied, next_review, difficulty_rating FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var state = ConceptState::make()
                state.learner_id = learner_id.copy()
                state.concept_id = row.vals.get_ptr(0).copy()
                state.course_id = course_id.copy()
                state.status = row.vals.get_ptr(1).copy()
                state.attempts = parse_i64(row.vals.get_ptr(2).to_view()) as int
                state.correct = parse_i64(row.vals.get_ptr(3).to_view()) as int
                state.streak = parse_i64(row.vals.get_ptr(4).to_view()) as int
                state.last_studied = parse_i64(row.vals.get_ptr(5).to_view())
                state.next_review = parse_i64(row.vals.get_ptr(6).to_view())
                states.push(state)
            }
            ri = ri + 1
        }
        return states
    }

    // ---- Review Item CRUD ----

    // Get review items due for a learner (next_review <= now)
    public func get_due_review_items(db : *DbClient, learner_id : &string, course_id : &string, limit : int) : vector<ReviewItem> {
        var items = vector<ReviewItem>()
        var now = underlayer_core::current_timestamp()
        var sql = string("SELECT id, concept_id, type, front, back, difficulty, stability, retrievability, next_review, reps, lapses FROM review_items WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' AND next_review <= ")
        var now_str = underlayer_core::int_to_string(now)
        sql.append_view(now_str.to_view())
        sql.append_view(" ORDER BY next_review ASC LIMIT ")
        var lim_str = underlayer_core::int_to_string(limit as i64)
        sql.append_view(lim_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 11) {
                var item = ReviewItem::make()
                item.id = row.vals.get_ptr(0).copy()
                item.learner_id = learner_id.copy()
                item.concept_id = row.vals.get_ptr(1).copy()
                item.course_id = course_id.copy()
                item.item_type = row.vals.get_ptr(2).copy()
                item.front = row.vals.get_ptr(3).copy()
                item.back = row.vals.get_ptr(4).copy()
                item.difficulty = parse_i64(row.vals.get_ptr(5).to_view()) as f64
                item.stability = parse_i64(row.vals.get_ptr(6).to_view()) as f64
                item.retrievability = parse_i64(row.vals.get_ptr(7).to_view()) as f64
                item.next_review = parse_i64(row.vals.get_ptr(8).to_view())
                item.reps = parse_i64(row.vals.get_ptr(9).to_view()) as int
                item.lapses = parse_i64(row.vals.get_ptr(10).to_view()) as int
                items.push(item)
            }
            ri = ri + 1
        }
        return items
    }

    // Update a review item after a rating
    public func update_review_item(db : *DbClient, item : *ReviewItem) {
        var sql = string("UPDATE review_items SET difficulty = ")
        var diff_str = underlayer_core::int_to_string(item.difficulty as i64)
        sql.append_view(diff_str.to_view())
        sql.append_view(", stability = ")
        var stab_str = underlayer_core::int_to_string(item.stability as i64)
        sql.append_view(stab_str.to_view())
        sql.append_view(", retrievability = ")
        var ret_str = underlayer_core::int_to_string(item.retrievability as i64)
        sql.append_view(ret_str.to_view())
        sql.append_view(", next_review = ")
        var nr_str = underlayer_core::int_to_string(item.next_review)
        sql.append_view(nr_str.to_view())
        sql.append_view(", last_review = ")
        var lr_str = underlayer_core::int_to_string(item.last_review)
        sql.append_view(lr_str.to_view())
        sql.append_view(", reps = ")
        var reps_str = underlayer_core::int_to_string(item.reps as i64)
        sql.append_view(reps_str.to_view())
        sql.append_view(", lapses = ")
        var lapses_str = underlayer_core::int_to_string(item.lapses as i64)
        sql.append_view(lapses_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_string(&item.id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // Insert a new review item
    public func insert_review_item(db : *DbClient, item : *ReviewItem) {
        var sql = string("INSERT OR IGNORE INTO review_items (id, learner_id, concept_id, course_id, type, front, back, difficulty, stability, retrievability, next_review, last_review, reps, lapses) VALUES ('")
        sql.append_string(&item.id)
        sql.append_view("', '")
        sql.append_string(&item.learner_id)
        sql.append_view("', '")
        sql.append_string(&item.concept_id)
        sql.append_view("', '")
        sql.append_string(&item.course_id)
        sql.append_view("', '")
        sql.append_string(&item.item_type)
        sql.append_view("', '")
        var front_esc = underlayer_core::json_escape(&item.front.to_view())
        sql.append_view(front_esc.to_view())
        sql.append_view("', '")
        var back_esc = underlayer_core::json_escape(&item.back.to_view())
        sql.append_view(back_esc.to_view())
        sql.append_view("', ")
        var diff_str = underlayer_core::int_to_string(item.difficulty as i64)
        sql.append_view(diff_str.to_view())
        sql.append_view(", ")
        var stab_str = underlayer_core::int_to_string(item.stability as i64)
        sql.append_view(stab_str.to_view())
        sql.append_view(", ")
        var ret_str = underlayer_core::int_to_string(item.retrievability as i64)
        sql.append_view(ret_str.to_view())
        sql.append_view(", ")
        var nr_str = underlayer_core::int_to_string(item.next_review)
        sql.append_view(nr_str.to_view())
        sql.append_view(", ")
        var lr_str = underlayer_core::int_to_string(item.last_review)
        sql.append_view(lr_str.to_view())
        sql.append_view(", ")
        var reps_str = underlayer_core::int_to_string(item.reps as i64)
        sql.append_view(reps_str.to_view())
        sql.append_view(", ")
        var lapses_str = underlayer_core::int_to_string(item.lapses as i64)
        sql.append_view(lapses_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // ---- Session CRUD ----

    public func insert_session(db : *DbClient, session : *underlayer_models::Session) {
        var sql = string("INSERT OR IGNORE INTO sessions (id, learner_id, start_time, end_time, type, exercises_attempted, exercises_correct) VALUES ('")
        sql.append_string(&session.id)
        sql.append_view("', '")
        sql.append_string(&session.learner_id)
        sql.append_view("', ")
        var st_str = underlayer_core::int_to_string(session.start_time)
        sql.append_view(st_str.to_view())
        sql.append_view(", ")
        var et_str = underlayer_core::int_to_string(session.end_time)
        sql.append_view(et_str.to_view())
        sql.append_view(", '")
        sql.append_string(&session.session_type)
        sql.append_view("', ")
        var ea_str = underlayer_core::int_to_string(session.exercises_attempted as i64)
        sql.append_view(ea_str.to_view())
        sql.append_view(", ")
        var ec_str = underlayer_core::int_to_string(session.exercises_correct as i64)
        sql.append_view(ec_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }
}
