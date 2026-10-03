// underlayer_repository — SEED COURSE PREREQUISITES FROM THE MANIFESTS.
//
// WHY THIS EXISTS, MEASURED.
//
// Measured on 2026-10-03, on the running server:
//
//     SELECT COUNT(*) FROM course_prerequisites;   ->   0
//
// and 32 of the 34 course manifests declare a `dependencies` list:
//
//     "a64abi"  -> ["a64asm"]
//     "pe"      -> ["elf"]
//     "x86sys"  -> ["x86asm","x86abi","isa","smp","simd","mem","priv"]
//
// So the whole prerequisite feature was dead, and dead in the quietest way
// possible.  The pieces all exist and all work:
//
//   * repository/src/prerequisites.ch has check_prerequisites(),
//     get_missing_prerequisites(), get_prerequisites() and add_prerequisite()
//   * GET /api/courses/:courseId/can-enroll answers with
//     `{"can_enroll": false, "missing": [...]}` -- including the mastery a
//     prerequisite demands -- and it is the "can-enroll prerequisite feedback"
//     P1 7.1.23 asks the Enroll button to show
//   * the enrol button now asks can-enroll before enabling itself
//
// but every one of them read an empty table, so can-enroll answered
// `{"can_enroll": true}` for every course on the platform.  A learner could
// open the AArch64 ABI course having never read AArch64 assembly, and nothing in
// the product said a word.  A shipped feature that always answers "yes" is worse
// than an absent one, because the checklist says it exists.
//
// WHY IT IS SEEDED AND NOT LEFT TO A MIGRATION.
//
// The dependencies live in the manifests, which are content, and the table is
// derived from them.  Seeding at startup -- beside the existing exercise seeding,
// which has the same shape -- means a course's prerequisites follow its manifest
// with no second edit, and deleting a line from the manifest removes the
// prerequisite.  A hand-maintained table would drift from the manifests within a
// week and there would be no way to tell which one was right.
//
// It is IDEMPOTENT, and that matters more than usual here: the seed runs on
// every boot, so a non-idempotent version would either multiply rows or fail to
// start.  Each row is INSERT OR REPLACE, and -- see below -- rows for
// dependencies that have been REMOVED from a manifest are deleted, so the table
// converges on the manifests rather than accumulating.
//
// THE THRESHOLD, WHICH THE MANIFESTS DO NOT SUPPLY.
//
// `dependencies` is a list of course ids.  There is no per-dependency mastery
// figure anywhere in any of the 34 manifests (checked: the only related key is
// `dependencies`, and `min_score` belongs to the certificate, not to a
// prerequisite).  So the number has to be chosen here, and choosing it is a
// product decision that is written down rather than buried:
//
//     70%
//
// because a prerequisite should mean "substantially learned", and:
//
//   * 100% would make the collection unusable.  `check_prerequisites` computes
//     mastery as correct*100/attempts and then requires that share of concepts
//     to clear the SAME threshold, so a 100% bar demands a perfect record on
//     every question ever attempted in that course.  One wrong answer on one
//     concept would lock the next course forever, with no way to recover except
//     the account delete.
//   * 50% would let someone in on half-understood material, which is exactly the
//     failure the collection is trying to avoid -- a reader who cannot decode a
//     four-byte instruction field meets the next course's instruction encoding
//     and has nowhere to stand.
//
// 70% means: across the concepts you have actually attempted in the prerequisite
// course, you were right at least 70% of the time on at least 70% of them.  That
// is learnable, it is checkable, and a learner who does not meet it is told
// exactly which course and which bar -- which is the feedback the Enroll button
// exists to deliver.
//
// A course that wants a different bar needs one field added to the manifest
// (`dependencies` accepting `{"course": "...", "min_mastery_pct": 80}`) and one
// branch in `prerequisite_threshold`.  That is a small change and it is NOT done
// here, because inventing a manifest schema no course uses is a change with no
// user.
using std::string
using underlayer_db::DbClient
using underlayer_models::Course

public namespace underlayer_repository {

    // The bar a dependency is held to. See the header for why 70 and not 100.
    private func prerequisite_threshold() : int { return 70 }

    // Write one prerequisite row.
    private func seed_one_prerequisite(db : *DbClient, course_id : &string, required : &string) {
        var pct = prerequisite_threshold()
        var c_esc = sql_escape(course_id)
        var r_esc = sql_escape(required)
        var pct_s = underlayer_core::int_to_string(pct as i64)
        var sql = string("INSERT OR REPLACE INTO course_prerequisites (course_id, required_course_id, min_mastery_pct) VALUES ('")
        sql.append_string(&c_esc)
        sql.append_view("', '")
        sql.append_string(&r_esc)
        sql.append_view("', ")
        sql.append_view(pct_s.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // Remove rows for a course that no longer declares that dependency.
    //
    // Without this the table only ever grows: a dependency removed from a
    // manifest would stay enforced forever, and nothing on the platform would
    // say so. The table is derived state, so it is made to agree.
    private func prune_prerequisites(db : *DbClient, course_id : &string, course : &Course) {
        // Delete every row for this course whose required course is not in the
        // Delete every row for this course whose required course is not in the
        // manifest list.  Compared in Chemical rather than in SQL: `json_each`
        // is not assumed to be available in whatever SQLite build is in use, and
        // the list is a handful of entries read once at startup.
        //
        // There was a first version of this that did it in SQL with a
        // json_each subselect against a `course_catalog` table that does not
        // exist.  It was left in the file with a comment saying it was unused,
        // which is worse than not having written it: a reader would have had to
        // work out which of two DELETE statements actually ran.
        var existing = get_prerequisites(db, course_id)
        var j : size_t = 0
        while(j < existing.size()) {
            var row = existing.get_ptr(j)
            var req_id = row.required_course_id.copy()
            var found = false
            var k : size_t = 0
            while(k < course.dependencies.size()) {
                var d = course.dependencies.get_ptr(k)
                if(d.equals(&req_id)) { found = true }
                k = k + 1
            }
            if(!found) {
                var c_esc2 = sql_escape(course_id)
                var r_esc2 = sql_escape(&req_id)
                var del2 = string("DELETE FROM course_prerequisites WHERE course_id = '")
                del2.append_string(&c_esc2)
                del2.append_view("' AND required_course_id = '")
                del2.append_string(&r_esc2)
                del2.append_view("'")
                underlayer_db::exec_sql(db, &raw del2)
            }
            j = j + 1
        }
    }

    // Seed one course's prerequisites from its manifest. Returns how many rows
    // the manifest declares, so a caller can log a number rather than nothing.
    public func seed_prerequisites_from_manifest(db : *DbClient, course : &Course) : int {
        var n = 0
        var i : size_t = 0
        while(i < course.dependencies.size()) {
            var req = course.dependencies.get_ptr(i).copy()
            // A course that depends on ITSELF would make it permanently
            // un-enrollable, because check_prerequisites would be asking
            // whether the learner had completed the course they are trying to
            // start. No manifest does this; skipping it is cheap and turns a
            // content mistake into a warning rather than a dead end.
            if(req.equals(&course.id)) {
                i = i + 1
                continue
            }
            seed_one_prerequisite(db, &course.id, &req)
            n = n + 1
            i = i + 1
        }
        prune_prerequisites(db, &course.id, course)
        return n
    }

}
