// underlayer_repository — Exercise CRUD.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::Exercise
using underlayer_models::ExerciseType

public namespace underlayer_repository {

    // Exercise stats for a concept
    public struct ExerciseStats {
        var concept_id : string
        var exercise_count : int
        var avg_difficulty : f64
        
        @make
        func make() : ExerciseStats {
            return ExerciseStats { concept_id = string(), exercise_count = 0, avg_difficulty = 0.0 }
        }
    }

    // Get exercises for a concept
    public func get_exercises_for_concept(db : *DbClient, concept_id : &string, limit : int) : vector<Exercise> {
        var exercises = vector<Exercise>()
        var sql = string("SELECT id, concept_id, type, question, answer, options_json, correct_index, explanation, hint1, hint2, hint3, difficulty, correct_indices_json FROM exercises WHERE concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("' ORDER BY RANDOM() LIMIT ")
        var lim_str = underlayer_core::int_to_string(limit as i64)
        sql.append_view(lim_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 13) {
                var ex = Exercise::make()
                ex.id = row.vals.get_ptr(0).copy()
                ex.concept_id = row.vals.get_ptr(1).copy()
                var type_str = row.vals.get_ptr(2).copy()
                if(type_str.equals(string("multiple_choice"))) {
                    ex.exercise_type = underlayer_models::exercise_type_recognize()
                } else if(type_str.equals(string("multi_recognize"))) {
                    ex.exercise_type = underlayer_models::exercise_type_multi_recognize()
                } else if(type_str.equals(string("free_recall"))) {
                    ex.exercise_type = underlayer_models::exercise_type_recall()
                } else if(type_str.equals(string("cued_recall"))) {
                    ex.exercise_type = underlayer_models::exercise_type_apply()
                } else {
                    ex.exercise_type = underlayer_models::exercise_type_recognize()
                }
                ex.question = row.vals.get_ptr(3).copy()
                ex.answer = row.vals.get_ptr(4).copy()
                // Parse options from pipe-separated string
                var opts_str = row.vals.get_ptr(5).to_view()
                if(opts_str.size() > 0) {
                    var opt_start : size_t = 0
                    var oi : size_t = 0
                    while(oi <= opts_str.size()) {
                        if(oi == opts_str.size() || opts_str.get(oi) == '|') {
                            var opt = string()
                            var oj : size_t = opt_start
                            while(oj < oi) {
                                opt.append(opts_str.get(oj))
                                oj = oj + 1
                            }
                            ex.options.push(opt)
                            opt_start = oi + 1
                        }
                        oi = oi + 1
                    }
                }
                ex.correct_index = parse_i64(row.vals.get_ptr(6).to_view()) as int
                ex.explanation = row.vals.get_ptr(7).copy()
                ex.hint1 = row.vals.get_ptr(8).copy()
                ex.hint2 = row.vals.get_ptr(9).copy()
                ex.hint3 = row.vals.get_ptr(10).copy()
                ex.difficulty = parse_f64(row.vals.get_ptr(11).to_view()) as float
                // Parse correct_indices from comma-separated string (12th column)
                var ci_str = row.vals.get_ptr(12).to_view()
                if(ci_str.size() > 2) {
                    // Strip [ and ] brackets
                    var inner_start : size_t = 1
                    var inner_end : size_t = ci_str.size() - 1
                    var ci_start : size_t = inner_start
                    var cii : size_t = inner_start
                    while(cii <= inner_end) {
                        if(cii == inner_end || ci_str.get(cii) == ',') {
                            var num_str = string()
                            var cij : size_t = ci_start
                            while(cij < cii) {
                                num_str.append(ci_str.get(cij))
                                cij = cij + 1
                            }
                            if(num_str.size() > 0) {
                                ex.correct_indices.push(parse_i64(num_str.to_view()) as int)
                            }
                            ci_start = cii + 1
                        }
                        cii = cii + 1
                    }
                }
                exercises.push(ex)
            }
            ri = ri + 1
        }
        return exercises
    }

    // Get a single exercise by ID
    public func get_exercise(db : *DbClient, exercise_id : &string) : Exercise {
        var ex = Exercise::make()
        var sql = string("SELECT id, concept_id, type, question, answer, options_json, correct_index, explanation, hint1, hint2, hint3, difficulty, correct_indices_json FROM exercises WHERE id = '")
        sql.append_string(exercise_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 13) {
                ex.id = row.vals.get_ptr(0).copy()
                ex.concept_id = row.vals.get_ptr(1).copy()
                var type_str = row.vals.get_ptr(2).copy()
                if(type_str.equals(string("multiple_choice"))) {
                    ex.exercise_type = underlayer_models::exercise_type_recognize()
                } else if(type_str.equals(string("multi_recognize"))) {
                    ex.exercise_type = underlayer_models::exercise_type_multi_recognize()
                } else if(type_str.equals(string("free_recall"))) {
                    ex.exercise_type = underlayer_models::exercise_type_recall()
                } else {
                    ex.exercise_type = underlayer_models::exercise_type_recognize()
                }
                ex.question = row.vals.get_ptr(3).copy()
                ex.answer = row.vals.get_ptr(4).copy()
                var opts_str = row.vals.get_ptr(5).to_view()
                if(opts_str.size() > 0) {
                    var opt_start : size_t = 0
                    var oi : size_t = 0
                    while(oi <= opts_str.size()) {
                        if(oi == opts_str.size() || opts_str.get(oi) == '|') {
                            var opt = string()
                            var oj : size_t = opt_start
                            while(oj < oi) {
                                opt.append(opts_str.get(oj))
                                oj = oj + 1
                            }
                            ex.options.push(opt)
                            opt_start = oi + 1
                        }
                        oi = oi + 1
                    }
                }
                ex.correct_index = parse_i64(row.vals.get_ptr(6).to_view()) as int
                ex.explanation = row.vals.get_ptr(7).copy()
                ex.hint1 = row.vals.get_ptr(8).copy()
                ex.hint2 = row.vals.get_ptr(9).copy()
                ex.hint3 = row.vals.get_ptr(10).copy()
                ex.difficulty = parse_f64(row.vals.get_ptr(11).to_view()) as float
                // Parse correct_indices
                var ci_str = row.vals.get_ptr(12).to_view()
                if(ci_str.size() > 2) {
                    var inner_start : size_t = 1
                    var inner_end : size_t = ci_str.size() - 1
                    var ci_start : size_t = inner_start
                    var cii : size_t = inner_start
                    while(cii <= inner_end) {
                        if(cii == inner_end || ci_str.get(cii) == ',') {
                            var num_str = string()
                            var cij : size_t = ci_start
                            while(cij < cii) {
                                num_str.append(ci_str.get(cij))
                                cij = cij + 1
                            }
                            if(num_str.size() > 0) {
                                ex.correct_indices.push(parse_i64(num_str.to_view()) as int)
                            }
                            ci_start = cii + 1
                        }
                        cii = cii + 1
                    }
                }
            }
        }
        return ex
    }

    // Insert an exercise
    public func insert_exercise(db : *DbClient, ex : *Exercise) {
        var sql = string("INSERT OR IGNORE INTO exercises (id, concept_id, type, question, answer, options_json, correct_index, explanation, hint1, hint2, hint3, difficulty, correct_indices_json) VALUES ('")
        sql.append_string(&ex.id)
        sql.append_view("', '")
        sql.append_string(&ex.concept_id)
        sql.append_view("', '")
        // Determine type string
        var type_str = string("multiple_choice")
        if(ex.exercise_type.id.equals(string("recall"))) { type_str = string("free_recall") }
        if(ex.exercise_type.id.equals(string("apply"))) { type_str = string("cued_recall") }
        if(ex.exercise_type.id.equals(string("multi_recognize"))) { type_str = string("multi_recognize") }
        sql.append_string(&type_str)
        sql.append_view("', '")
        var q_raw = sql_escape(&ex.question)
        var q_esc = underlayer_core::json_escape(&q_raw.to_view())
        sql.append_view(q_esc.to_view())
        sql.append_view("', '")
        var a_raw = sql_escape(&ex.answer)
        var a_esc = underlayer_core::json_escape(&a_raw.to_view())
        sql.append_view(a_esc.to_view())
        sql.append_view("', '")
        // Join options with |
        var opts = string()
        var oi : size_t = 0
        while(oi < ex.options.size()) {
            if(oi > 0) { opts.append('|') }
            var opt_ptr = ex.options.get_ptr(oi)
            var opt_view = opt_ptr.to_view()
            var oj : size_t = 0
            while(oj < opt_view.size()) {
                opts.append(opt_view.get(oj))
                oj = oj + 1
            }
            oi = oi + 1
        }
        var opts_raw = sql_escape(&opts)
        var opts_esc = underlayer_core::json_escape(&opts_raw.to_view())
        sql.append_view(opts_esc.to_view())
        sql.append_view("', ")
        var ci_str = underlayer_core::int_to_string(ex.correct_index as i64)
        sql.append_view(ci_str.to_view())
        sql.append_view(", '")
        var exp_raw = sql_escape(&ex.explanation)
        var exp_esc = underlayer_core::json_escape(&exp_raw.to_view())
        sql.append_view(exp_esc.to_view())
        sql.append_view("', '")
        var h1_raw = sql_escape(&ex.hint1)
        var h1_esc = underlayer_core::json_escape(&h1_raw.to_view())
        sql.append_view(h1_esc.to_view())
        sql.append_view("', '")
        var h2_raw = sql_escape(&ex.hint2)
        var h2_esc = underlayer_core::json_escape(&h2_raw.to_view())
        sql.append_view(h2_esc.to_view())
        sql.append_view("', '")
        var h3_raw = sql_escape(&ex.hint3)
        var h3_esc = underlayer_core::json_escape(&h3_raw.to_view())
        sql.append_view(h3_esc.to_view())
        sql.append_view("', ")
        // Write difficulty as a REAL (0.30), not int-truncated
        var diff_str = f64_to_string(ex.difficulty as f64)
        sql.append_view(diff_str.to_view())
        sql.append_view(", '")
        // Build correct_indices JSON array
        var ci_json = string("[")
        var cii : size_t = 0
        while(cii < ex.correct_indices.size()) {
            if(cii > 0) { ci_json.append(',') }
            var idx_val = ex.correct_indices.get(cii)
            var idx_str = underlayer_core::int_to_string(idx_val as i64)
            ci_json.append_view(idx_str.to_view())
            cii = cii + 1
        }
        ci_json.append(']')
        sql.append_view(&ci_json.to_view())
        sql.append_view("')")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // Get total exercise count for a concept
    public func count_exercises(db : *DbClient, concept_id : &string) : int {
        var sql = string("SELECT COUNT(*) FROM exercises WHERE concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 1) {
                return parse_i64(row.vals.get_ptr(0).to_view()) as int
            }
        }
        return 0
    }

    // Bulk insert exercises
    public func insert_exercises_bulk(db : *DbClient, exercises : *vector<Exercise>) : int {
        var inserted_count = 0
        var i : size_t = 0
        while(i < exercises.size()) {
            var ex = exercises.get_ptr(i)
            insert_exercise(db, ex)
            inserted_count = inserted_count + 1
            i = i + 1
        }
        return inserted_count
    }

    // Get exercise stats for all concepts
    public func get_exercise_stats(db : *DbClient) : vector<ExerciseStats> {
        var stats = vector<ExerciseStats>()
        var sql = string("SELECT concept_id, COUNT(*) as exercise_count, AVG(difficulty) as avg_difficulty FROM exercises GROUP BY concept_id ORDER BY concept_id")
        var result = underlayer_db::query_sql(db, &raw sql)
        var i : size_t = 0
        while(i < result.rows.size()) {
            var row = result.rows.get_ptr(i)
            if(row.vals.size() >= 3) {
                var stat = ExerciseStats::make()
                stat.concept_id = row.vals.get_ptr(0).copy()
                stat.exercise_count = parse_i64(row.vals.get_ptr(1).to_view()) as int
                // Parse average difficulty
                var avg_diff_str = row.vals.get_ptr(2).to_view()
                if(avg_diff_str.size() > 0) {
                    stat.avg_difficulty = parse_i64(avg_diff_str) as f64
                }
                stats.push(stat)
            }
            i = i + 1
        }
        return stats
    }

}
