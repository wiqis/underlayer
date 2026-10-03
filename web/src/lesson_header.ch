// underlayer_web — THE LESSON HEADER: how long, how hard, and what to know first.
//
// WHY THIS EXISTS.  Measured on the served lesson pages, 2026-10-03.
//
//     GET /courses/elf/lessons/bytes   -> the visible text is
//
//       Bytes and Binary
//       Concept 1 of 24 in Fundamentals
//       Previous  Next: Binary Representation
//
// and that is ALL of it.  No time.  No difficulty.  No statement of what the
// reader is assumed to already know.
//
// Every one of those is in the manifest, for every concept of every course:
//
//     "id": "bytes", "title": "Bytes and Binary", "module_id": "fundamentals",
//     "estimated_minutes": 12, "difficulty": "beginner",
//     "prerequisites": []
//
// `models/src/Concept` has `estimated_minutes` and `prerequisites` fields.
// `repository/src/load_course` parses them.  `handle_lesson` has the whole
// `Course` in hand at line 12, before it decides whether the lesson exists at
// all.  So all three facts were in memory and none of them was printed.
//
// WHY THAT MATTERS FOR LEARNING, and this is the part worth arguing.
//
// A reader opening a lesson cannot tell whether it is a three-minute read or a
// forty-minute grind, because the platform knows and does not say.  Under a time
// estimate people choose: they plan a session, they stop when they meant to, and
// they come back.  Without one, every lesson feels like an unknown commitment,
// and the natural response to an unknown commitment is to not open the thing.
//
// The same argument applies to DIFFICULTY, and more sharply.  This collection
// teaches ELF formats, x86 and AArch64 encodings, and RISC-V assembly.  A reader
// who does not know that "BRANCH26 has to range-check because 26 bits scaled by
// four caps at 128 MB" is an advanced topic will meet it as an unexplained wall
// of hex.  The manifest already labels that lesson advanced.  Saying so costs
// nothing and turns a wall into a known quantity.
//
// And PREREQUISITES are the third of the trio, for the same reason in reverse: a
// lesson whose prerequisite has not been read is not a lesson the reader can
// start, and the platform knows which one it is.
//
// WHY SENTINEL REPLACEMENT, AGAIN, and the same trade as lesson_pager.ch.
//
// The markup lives in 431 render functions in content/src.  Threading three
// manifest fields through all of them to move data the handler already holds
// would touch the entire corpus -- which 24 verify_*.py checkers assert
// byte-level facts about -- for no new information.  So this replaces the FIRST
// `</h1>` on the page, which is the lesson title's closing tag, and only when
// exactly one is present.
//
// The "only when exactly one" is a safety condition, not tidiness.  A page with
// two `</h1>` is a page this must not touch: injecting after the wrong one puts
// "12 min · beginner" above the navigation instead of under the title.  Failing
// to inject is a cosmetic loss; injecting in the wrong place is a wrong page, and
// it would be wrong on all 431 of them.
//
// WHY THE STATIC PAGES DO NOT GET IT, STATED PLAINLY.
//
// The 432 pre-rendered pages are written by the course binaries, which do not run
// handle_lesson, so a lesson opened straight from disk or from GitHub Pages shows
// the title and none of this.  That is a real limitation of the backend-optional
// rule rather than a decision, and the honest fix is for the static build to apply
// the same substitution from the manifest it already reads -- which
// scripts/build_static.sh could do, and does not yet.  It is named in the audit
// rather than glossed over.
//
// WHAT THIS DOES NOT SHOW.
//
//   * No percentage of anything.  "12 min" is a fact about the lesson;
//     "you are 40% through" is a verdict about the reader, and the design rules
//     in docs/course-design.md are explicit that this collection must normalise
//     struggle rather than measure it against the reader.
//   * No "you are struggling" badge.  That judgement lives on the dashboard's
//     next-step panel, which has the attempt data to justify it.  Putting it
//     here, on every lesson, would be an alarm on the front door.
//   * No prerequisite the reader cannot act on.  The ids are printed as links to
//     the lessons, and a concept with no prerequisites shows nothing at all
//     rather than an empty label.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course
using underlayer_models::ConceptRef

public namespace underlayer_web {

    private func lesson_module_title(course : &Course, module_id : &string) : string {
        var i : size_t = 0
        while(i < course.modules.size()) {
            var m = course.modules.get_ptr(i)
            if(m.id.equals(module_id)) { return m.title.copy() }
            i = i + 1
        }
        return string()
    }

    private func lesson_module_order(course : &Course, module_id : &string) : int {
        var i : size_t = 0
        while(i < course.modules.size()) {
            var m = course.modules.get_ptr(i)
            if(m.id.equals(module_id)) { return m.order }
            i = i + 1
        }
        return 0
    }

    // The header itself.  Returns "" when there is nothing to say, which is the
    // right answer for a concept with no estimated_minutes and no prerequisites:
    // an empty strip is worse than no strip.
    public func lesson_header_html(course : &Course, concept_id : &string) : string {
        // Find the concept, inline.  The first version of this used a helper with
        // three out-parameters, because `models/src/Concept` has no `copy()` and
        // returning it by value was not available either -- and Chemical has no
        // `append_int` either, so the minutes could not be written back out.
        // Four fields are needed and three of them are strings: one loop that
        // copies what it needs is simpler than any of the alternatives.
        var module_id = string()
        var minutes = 0
        var difficulty = string()
        var found = false
        var i : size_t = 0
        while(i < course.concepts.size()) {
            var c = course.concepts.get_ptr(i)
            if(c.id.equals(concept_id)) {
                module_id = c.module_id.copy()
                minutes = c.estimated_minutes
                difficulty = c.difficulty.copy()
                found = true
            }
            i = i + 1
        }
        if(!found) { return string() }

        var out = string("<div class=\"lesson-head\">")

        // ── time ────────────────────────────────────────────────────
        // 0 and negative are treated as "not stated" rather than rendered as
        // "0 min", because a zero-length lesson is a manifest bug and printing
        // it as a fact would send the reader looking for the mistake.
        if(minutes > 0) {
            var mins = underlayer_core::int_to_string(minutes as i64)
            out.append_view("<span class=\"lesson-head-item\" title=\"About how long this lesson takes to read and do\"><span class=\"lesson-head-ico\" aria-hidden=\"true\">&#9201;</span>")
            out.append_string(&mins)
            out.append_view(" min</span>")
        }

        // ── difficulty ──────────────────────────────────────────────
        // PER-CONCEPT, and the first version of this used the COURSE's
        // difficulty -- which is wrong in a way that matters.  Measured across
        // the collection: all 398 concepts carry their own `difficulty`
        // (beginner / intermediate / advanced) and repository/src/courses.ch
        // parses it into ConceptRef.difficulty.  A course-level label would tell
        // a reader in the x86 course that everything is advanced, including the
        // lesson that counts bytes, which is the one beginner lesson they could
        // have started with.  The per-concept value is the one the author wrote
        // for that lesson.
        var diff = difficulty
        if(diff.size() > 0) {
            var de = underlayer_core::html_escape(&diff)
            out.append_view("<span class=\"lesson-head-item lesson-head-diff\" title=\"The course's overall level; this lesson may be harder\"><span class=\"lesson-head-ico\" aria-hidden=\"true\">&#9650;</span>")
            out.append_view(de.to_view())
            out.append_view("</span>")
        }

        // ── position in the module ──────────────────────────────────
        var mod_title = lesson_module_title(course, &module_id)
        if(mod_title.size() > 0) {
            var ord = lesson_module_order(course, &module_id)
            var me = underlayer_core::html_escape(&mod_title)
            out.append_view("<span class=\"lesson-head-item lesson-head-mod\" title=\"Which part of the course this is\"><span class=\"lesson-head-ico\" aria-hidden=\"true\">&#9776;</span>Module ")
            if(ord > 0) {
                var ord_s = underlayer_core::int_to_string(ord as i64)
                out.append_string(&ord_s)
                out.append_view(": ")
            }
            out.append_view(me.to_view())
            out.append_view("</span>")
        }

        // ── prerequisites ───────────────────────────────────────────
        // The one piece of this header that is a real instruction rather than a
        // fact, and it is the piece that most changes whether a lesson can be
        // started at all.  Printed as links, because a prerequisite you cannot
        // open is not information.
        // ── can you start here? ─────────────────────────────────────
        //
        // MEASURED BEFORE WRITING THIS: across all 34 course manifests, 0 of
        // 398 concepts declare a `prerequisites` list.  The field exists in
        // models/src/ConceptRef, courses.ch parses it, and not one manifest
        // supplies it -- so a header built on prerequisites alone would have
        // rendered an empty label on every one of the 431 lesson pages, which is
        // worse than rendering nothing.
        //
        // What IS true, and is what a reader actually needs to know, is the
        // course order: these courses declare `navigation: "linear"`, and every
        // course landing page says the lessons read in order and each assumes
        // the one before it.  So the honest statement on a mid-course lesson is
        // "continues from <the previous one>", and on the first lesson of the
        // course it is nothing at all -- because the first lesson has nothing
        // before it, and a reader arriving there needs no warning.
        //
        // An explicit `prerequisites` list still wins when a manifest supplies
        // one, because an author who wrote it meant it. The two are not combined:
        // saying both would imply the course order and the author's list are
        // different information, and they are not.
        var prereqs = vector<string>()
        var prev_title = string()
        var prev_id = string()
        var first = true
        var pi2 : size_t = 0
        while(pi2 < course.concepts.size()) {
            var c2 = course.concepts.get_ptr(pi2)
            if(c2.prerequisites.size() > 0 && c2.id.equals(concept_id)) {
                var pk : size_t = 0
                while(pk < c2.prerequisites.size()) {
                    prereqs.push_back(c2.prerequisites.get_ptr(pk).copy())
                    pk = pk + 1
                }
            }
            // The previous concept in COURSE order.  `course.concepts` is filled
            // in manifest order and the manifest lists concepts in reading
            // order, so the vector order is the reading order -- which is the
            // same assumption the prev/next pager already makes.
            if(c2.id.equals(concept_id)) { first = false }
            else if(first) {
                prev_title = c2.title.copy()
                prev_id = c2.id.copy()
            }
            pi2 = pi2 + 1
        }
        // Whether the list is the author's or the course order's.  The label
        // differs, and getting this wrong is how a reader who deliberately
        // jumped into module 4 was told they were behind: the first version
        // computed "explicit" from the list LENGTH, which is 1 for the
        // course-order case as well, so every mid-course lesson said "Assumes
        // you have read" when it meant "Continues from".
        var from_manifest = false
        if(prereqs.size() > 0) { from_manifest = true }
        if(prereqs.size() == 0 && prev_id.size() > 0) {
            prereqs.push_back(prev_id.copy())
        }
        if(prereqs.size() > 0) {
            // "Continues from" rather than "assumes you have read", for the
            // course-order case: the second implies the reader is behind, and
            // the first just says where the course has got to.  A reader who
            // jumped here deliberately is told what they missed without being
            // told they failed.
            out.append_view("<span class=\"lesson-head-prereq\">")
            var pi : size_t = 0
            while(pi < prereqs.size()) {
                var pidv = prereqs.get_ptr(pi).copy()
                if(pi > 0) {
                    if(pi + 1 == prereqs.size()) { out.append_view(" and") }
                    else { out.append_view(",") }
                    out.append_view(" ")
                } else if(!from_manifest) {
                    out.append_view("Continues from ")
                } else {
                    out.append_view("Assumes you have read ")
                }
                var pe = underlayer_core::html_escape(&pidv)
                out.append_view("<a href=\"/courses/")
                // course.id, NOT concept_id.
                //
                // The first version used `concept_id` here and produced
                //   /courses/binary-representation/lessons/bytes
                // -- a course path built from a concept id, on all 431 lesson
                // pages, which is a 404 for every reader who clicked it. It was
                // visible immediately because the concept id is right next to it
                // in the function and the two read alike.
                var ce = underlayer_core::html_escape(&course.id)
                out.append_view(ce.to_view())
                out.append_view("/lessons/")
                out.append_view(pe.to_view())
                out.append_view("\">")
                out.append_view(pe.to_view())
                out.append_view("</a>")
                pi = pi + 1
            }
            out.append_view("</span>")
        }

        out.append_view("</div>")
        return out
    }

    // Insert the header after the lesson's </h1>.
    //
    // Returns the source UNCHANGED when the page does not have exactly one
    // </h1>.  See the file header for why "exactly one" is a safety condition
    // rather than a convenience.
    public func apply_lesson_header(src : &string, course : &Course, concept_id : &string) : string {
        var first = src.find(string_view("</h1>"))
        if(first == std::NPOS) { return src.copy() }
        // A second one means this is not the shape we know how to patch.
        var second = src.to_view().subview(first + 5, src.size()).find(string_view("</h1>"))
        if(second != std::NPOS) { return src.copy() }

        var header = lesson_header_html(course, concept_id)
        if(header.size() == 0) { return src.copy() }

        var at = first + 5
        var built = std::string()
        // `subview(start, end)` takes an END INDEX, not a length. lesson_pager.ch
        // carries the long version of this because getting it wrong truncated
        // every lesson page on the platform; this is the short version.
        built.append_view(src.to_view().subview(0, at))
        built.append_string(&header)
        built.append_view(src.to_view().subview(at, src.size()))
        return built
    }

}
