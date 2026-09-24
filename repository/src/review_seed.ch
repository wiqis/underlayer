// underlayer_repository — Seed data (P1 2.4.21 + P1 4.1.27).
//
// Review item seeding: insert_review_item/update_review_item had zero callers,
// so review_items stayed empty and /api/review/due always returned []. Items
// are seeded per (learner, course, concept) on demand with deterministic ids
// "<learner_id>_<course_id>_<concept_id>" so INSERT OR IGNORE is idempotent.
//
// Exercise seeding: the exercises table started empty and the seed endpoint
// was manual-only. seed_exercises_from_manifest loads exercise_decls from a
// course manifest with deterministic ids "<course>_<concept>_<index>".
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::ReviewItem
using underlayer_models::Exercise

public namespace underlayer_repository {

    // Seed due review items for a learner+course from the course's concept list.
    // Only creates items for concepts the learner has actually engaged with
    // (a concept_states row exists) so brand-new learners don't get the whole
    // course dumped into their queue. Returns the number of items created.
    public func seed_review_items(db : *DbClient, learner_id : &string, course_id : &string) : int {
        var created = 0

        // Load the course to know its concepts (disk manifest first, fallback second)
        var courses_dir = get_courses_dir()
        var course = load_course(&courses_dir, course_id)

        var now = underlayer_core::current_timestamp()
        var i : size_t = 0
        while(i < course.concepts.size()) {
            var concept = course.concepts.get_ptr(i)

            // Only seed for concepts the learner has engaged with at least once
            var state = get_concept_state(db, learner_id, &concept.id, course_id)
            if(state.attempts > 0) {
                var item_id = string()
                item_id.append_string(learner_id)
                item_id.append_view("_")
                item_id.append_string(course_id)
                item_id.append_view("_")
                item_id.append_string(&concept.id)

                var item = ReviewItem::make()
                item.id = item_id
                item.learner_id = learner_id.copy()
                item.concept_id = concept.id.copy()
                item.course_id = course_id.copy()
                // Recall prompt derived from the concept title/description
                item.item_type = string("recall")
                var front = string("Explain in your own words: ")
                front.append_string(&concept.title)
                item.front = front
                var back = string()
                back.append_string(&concept.description)
                back.append_view(" (")
                back.append_string(&concept.title)
                back.append_view(")")
                item.back = back
                item.difficulty = 5.0
                item.stability = 1.0
                item.retrievability = 1.0
                // Due immediately on first creation so it enters the queue
                item.next_review = now
                item.last_review = 0
                item.reps = 0
                item.lapses = 0
                item.ease_factor = 2.5

                var before = count_review_items(db, learner_id, course_id)
                insert_review_item(db, &raw item)
                var after = count_review_items(db, learner_id, course_id)
                if(after > before) { created = created + 1 }
            }
            i = i + 1
        }
        return created
    }

    // Count review items for a learner+course (used to detect whether an
    // insert actually created a row).
    public func count_review_items(db : *DbClient, learner_id : &string, course_id : &string) : int {
        var sql = string("SELECT COUNT(*) FROM review_items WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql_single(db, &raw sql)
        if(result.size() == 0) { return 0 }
        return parse_int(result.get_ptr(0).to_view())
    }

    // Courses directory — same default as core load_config. Kept local to the
    // repository layer because seeding must not depend on web/.
    private func get_courses_dir() : string {
        var s = underlayer_core::get_env_str("COURSES_DIR")
        if(s.size() == 0) { return string("./courses") }
        return s
    }

    // Seed the exercises table from a course manifest's exercise_decls.
    // Idempotent (INSERT OR IGNORE with deterministic ids). Returns inserted count.
    // (P1 4.1.27 — the exercises table started empty and /api/exercises/seed was manual-only.)
    public func seed_exercises_from_manifest(db : *DbClient, courses_dir : &string, course_id : &string) : int {
        var inserted_count = 0

        var manifest_path = string()
        manifest_path.append_string(courses_dir)
        manifest_path.append_view("/")
        manifest_path.append_string(course_id)
        manifest_path.append_view("/manifest.json")

        var manifest_result = fs::read_entire_file(manifest_path.data())
        if(manifest_result is std::Result.Err) { return 0 }
        var Ok(manifest_data) = manifest_result else unreachable

        var manifest_content = string()
        var di2 : size_t = 0
        while(di2 < manifest_data.size()) {
            manifest_content.append(manifest_data.get(di2) as char)
            di2 = di2 + 1
        }
        if(manifest_content.size() == 0) { return 0 }

        var manifest_json = json::parse(manifest_content.to_view())
        if(manifest_json is std::Result.Err) { return 0 }
        var Ok(manifest_val) = manifest_json else unreachable

        var exercise_decls = json_get(&raw manifest_val, "exercise_decls")
        if(exercise_decls == null) { return 0 }
        if(!(exercise_decls is JsonValue.Array)) { return 0 }
        var Array(decls) = *exercise_decls else unreachable

        var di : size_t = 0
        while(di < decls.size()) {
            var decl_ptr = decls.get_ptr(di)
            var ex = Exercise::make()
            ex.concept_id = json_get_str(decl_ptr, "concept_id")
            ex.question = json_get_str(decl_ptr, "question")
            ex.answer = json_get_str(decl_ptr, "answer")
            ex.explanation = json_get_str(decl_ptr, "explanation")
            ex.hint1 = json_get_str(decl_ptr, "hint1")
            ex.hint2 = json_get_str(decl_ptr, "hint2")
            ex.hint3 = json_get_str(decl_ptr, "hint3")
            ex.correct_index = json_get_int(decl_ptr, "correct_index")
            var diff_val = json_get(decl_ptr, "difficulty")
            if(diff_val != null && diff_val is JsonValue.Number) {
                var Number(diff_num) = *diff_val else unreachable
                ex.difficulty = parse_f64(diff_num.to_view()) as float
            }

            var type_str = json_get_str(decl_ptr, "type")
            ex.exercise_type = exercise_type_from_str(&type_str)

            // multi_recognize: comma-separated correct option indices (e.g. "0,2")
            var ci_str = json_get_str(decl_ptr, "correct_indices")
            if(ci_str.size() > 0) {
                var ci_start : size_t = 0
                var cii : size_t = 0
                while(cii <= ci_str.size()) {
                    if(cii == ci_str.size() || ci_str.get(cii) == ',') {
                        var num_str = string()
                        var cj : size_t = ci_start
                        while(cj < cii) { num_str.append(ci_str.get(cj)); cj = cj + 1 }
                        if(num_str.size() > 0) {
                            ex.correct_indices.push(parse_i64(num_str.to_view()) as int)
                        }
                        ci_start = cii + 1
                    }
                    cii = cii + 1
                }
            }

            var options_str = json_get_str(decl_ptr, "options")
            if(options_str.size() > 0) {
                var opt_start : size_t = 0
                var oi : size_t = 0
                while(oi <= options_str.size()) {
                    if(oi == options_str.size() || options_str.get(oi) == '|') {
                        var opt = string()
                        var oj : size_t = opt_start
                        while(oj < oi) {
                            opt.append(options_str.get(oj))
                            oj = oj + 1
                        }
                        ex.options.push(opt)
                        opt_start = oi + 1
                    }
                    oi = oi + 1
                }
            }

            var id_str = string()
            id_str.append_string(course_id)
            id_str.append_view("_")
            id_str.append_string(&ex.concept_id)
            id_str.append_view("_")
            var di_str = underlayer_core::int_to_string(di as i64)
            id_str.append_string(&di_str)
            ex.id = id_str

            if(ex.concept_id.size() > 0) {
                var before = count_exercises(db, &ex.concept_id)
                insert_exercise(db, &raw ex)
                var after = count_exercises(db, &ex.concept_id)
                if(after > before) { inserted_count = inserted_count + 1 }
            }
            di = di + 1
        }
        return inserted_count
    }

}
