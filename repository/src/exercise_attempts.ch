// underlayer_repository — Per-exercise attempt tracking (4.4.1, 4.4.3).
//
// WHY THIS TABLE HAD TO BE ADDED.  The user asked one question the platform
// could not answer at all: "which quiz did I fail?".  /api/exercises/submit
// graded every answer correctly and then threw it away.  It wrote an aggregate
// onto concept_states -- attempts, correct, streak -- and the aggregate is
// enough to score the CONCEPT and useless for the question as asked, because
// it cannot say WHICH question was wrong, only that somewhere in that concept
// something was.  With three exercises in a concept and two right, the
// question "which one did I get wrong" has two possible answers and the
// database does not distinguish them.  No view could have surfaced it, so this
// is a recording gap, not a display gap.
//
// One row per submission.  NOT upserted: an exercise submitted wrong three
// times is three failures and the third one is the one that tells the learner
// something they do not already know.  get_failed_exercises() collapses the
// history per exercise so the learner sees "you have missed this one twice",
// and the count is the honest one.
//
// The `answer` column is deliberately absent.  A wrong answer is not a secret,
// but storing it here would make this table the place to leak a learner's
// mistakes from, and nothing reads it back; the learner's own history view
// links to the exercise, which still has its question and explanation.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    // One submitted answer.  `correct` is an INTEGER 0/1 rather than a bool so
    // the SQL stays portable to the Turso backend, which has no boolean type.
    public struct ExerciseAttempt {
        var learner_id : string
        var course_id : string
        var concept_id : string
        var exercise_id : string
        var question : string
        var correct : int
        var submitted_at : i64
        var misses : int          // how many times this exercise has been missed

        @make
        func make() : ExerciseAttempt {
            return ExerciseAttempt {
                learner_id = string(),
                course_id = string(),
                concept_id = string(),
                exercise_id = string(),
                question = string(),
                correct = 0,
                submitted_at = 0,
                misses = 0
            }
        }
    }

    // Every interpolated value goes through sql_escape().  This is not defensive
    // habit, it is a bug this function shipped with: `course_id` arrives
    // straight off the request query string (web/src/handlers_exercises.ch
    // reads the "course_id" query param and hands it here unexamined), so a
    // course_id of "x',''); DROP TABLE exercises; --" was being concatenated
    // into a live statement.  The question text comes from the exercise seed,
    // and a question containing one apostrophe would break the INSERT outright
    // -- which is how it fails: the write errors, the answer is still graded
    // and shown to the learner as correct, and nothing is recorded.
    // repository/src/exercises.ch already escapes every one of these fields;
    // this table was written without copying that.
    public func record_exercise_attempt(
        db : *DbClient,
        learner_id : &string,
        course_id : &string,
        concept_id : &string,
        exercise_id : &string,
        correct : bool,
        question : &string
    ) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var correct_num : int = 0
        if(correct) { correct_num = 1 }
        var lid = sql_escape(learner_id)
        var crs = sql_escape(course_id)
        var cid = sql_escape(concept_id)
        var eid = sql_escape(exercise_id)
        var q = sql_escape(question)
        var sql = string("INSERT INTO exercise_attempts (learner_id, course_id, concept_id, exercise_id, correct, question, submitted_at) VALUES ('")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&crs)
        sql.append_view("', '")
        sql.append_string(&cid)
        sql.append_view("', '")
        sql.append_string(&eid)
        sql.append_view("', ")
        var correct_str = underlayer_core::int_to_string(correct_num as i64)
        sql.append_view(correct_str.to_view())
        sql.append_view(", '")
        sql.append_string(&q)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // Every exercise this learner got wrong at least once, most-missed first,
    // with the miss count.  ONE ROW PER EXERCISE, not per attempt: the
    // dashboard list is "go back and fix these", and repeating an exercise
    // three times because it was missed three times makes that list useless.
    // The per-attempt history stays in the table and is readable by id.
    public func get_failed_exercises(
        db : *DbClient,
        learner_id : &string,
        limit : int
    ) : vector<ExerciseAttempt> {
        var out = vector<ExerciseAttempt>()
        var lid = sql_escape(learner_id)
        var sql = string("SELECT a.exercise_id, a.course_id, a.concept_id, COUNT(*) AS misses, MAX(a.submitted_at) AS last_at, MAX(a.question) AS q FROM exercise_attempts a WHERE a.learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' AND a.correct = 0 GROUP BY a.exercise_id, a.course_id, a.concept_id ORDER BY misses DESC, last_at DESC LIMIT ")
        var lim_str = underlayer_core::int_to_string(limit as i64)
        sql.append_view(lim_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var i : size_t = 0
        while(i < result.rows.size()) {
            var row = result.rows.get_ptr(i)
            if(row.vals.size() >= 6) {
                var a = ExerciseAttempt::make()
                a.exercise_id = row.vals.get_ptr(0).copy()
                a.course_id = row.vals.get_ptr(1).copy()
                a.concept_id = row.vals.get_ptr(2).copy()
                a.misses = parse_i64(row.vals.get_ptr(3).to_view()) as int
                a.submitted_at = parse_i64(row.vals.get_ptr(4).to_view())
                a.question = row.vals.get_ptr(5).copy()
                a.correct = 0
                out.push(a)
            }
            i = i + 1
        }
        return out
    }

    // How many distinct exercises this learner has missed.  The number the
    // dashboard shows; the list is get_failed_exercises().
    public func count_failed_exercises(db : *DbClient, learner_id : &string) : int {
        var lid = sql_escape(learner_id)
        var sql = string("SELECT COUNT(DISTINCT exercise_id) FROM exercise_attempts WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' AND correct = 0")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                return parse_i64(row.vals.get_ptr(0).to_view()) as int
            }
        }
        return 0
    }

}