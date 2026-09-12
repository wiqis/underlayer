// underlayer_repository — ALL SQL lives here.
// Schema initialization + CRUD for Phase 1.
// All string params use &string (references).
// NOTE: Filesystem reads (fs::read_entire_file) cause TCC linker errors
// due to Result type destructors. Course data is hardcoded for now.
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

    // Load a course — hardcoded data (filesystem loading deferred to LLVM backend)
    public func load_course(courses_dir : &string, course_id : &string) : Course {
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

    // List all courses
    public func list_courses(courses_dir : &string) : vector<Course> {
        var courses = vector<Course>()
        var elf_id = string("elf")
        var course = load_course(courses_dir, &elf_id)
        courses.push(course)
        return courses
    }

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
        sql.append_view(", 0.0)")
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
}
