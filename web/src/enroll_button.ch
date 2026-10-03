// underlayer_web — THE ENROLL BUTTON.  (P1 7.1.23)
//
// WHAT THE CHECKLIST SAID, AND IT WAS RIGHT
//
//     P1 7.1.23 Course landing page Enroll button wired to
//          POST /api/courses/:courseId/enroll with can-enroll prerequisite
//          feedback (enrollments API has no UI consumer)
//
// Measured on 2026-10-03 before writing this:
//
//   * `enrollments` is a table with a full CRUD layer.
//   * `GET /api/enrollments` answers 200 with the rows.
//   * `POST /api/courses/:courseId/enroll` answers 200 and inserts.
//   * `GET /api/courses/:courseId/can-enroll` answers 200, and answers
//     `{"can_enroll":false,"missing":[{"required_course_id":...,
//      "min_mastery_pct":80}]}` when a prerequisite is unmet -- which is the
//     prerequisite feedback the checklist asks for, already written.
//   * NO PAGE, ON ANY COURSE, NAMED ANY OF THEM.
//
// tools/integration_holes.py reported both as unreachable. So a learner could
// not see whether they were enrolled in a course, could not say they were
// starting one, and could not find out that a course wanted them to finish
// another first.
//
// THE PART THAT IS NOT OBVIOUS: WHAT DOES ENROLLING ACTUALLY DO?
//
// Measured before deciding what the button should SAY.  repository/src/
// enrollments.ch calls `enroll_learner` from `touch_enrollment`, on the READ
// path: opening a lesson in a course enrols you in it.  So a learner who has
// read anything is already enrolled, and a button that said "Enroll" would 200
// with `{"status":"already_enrolled"}` for most people who clicked it.
//
// That makes this a STATE control rather than an ACTION control, and the copy
// follows from it:
//
//   not enrolled   -> "Enroll"        and pressing it enrols
//   enrolled       -> "Enrolled"      and it says WHEN, from the row
//   no session     -> nothing at all, because the sign-in advisory above the
//                     fold already says the same thing and twice is worse than
//                     once
//
// A button that reports state and only becomes an action when there is an
// action to take is the honest version.  The alternative -- always offering
// "Enroll" and letting the server answer "already_enrolled" -- teaches the
// reader that the button is unreliable.
//
// WHY SERVER-RENDERED.  Same rule as the sign-in gate and the next-step panel:
// the page must be CORRECT BEFORE ANY SCRIPT RUNS.  A client-rendered Enrol
// button means a signed-out reader sees "Enroll", clicks it, and gets a 401 with
// no explanation.  The state is known here -- `handle_course_landing` is given
// the request.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // Renders the control, or "" when there is nothing to render.
    //
    // `enrolled_at` is 0 for a learner who is not enrolled; a real enrolment
    // timestamp comes back otherwise.  The timestamp is printed because "since
    // March" is a different statement from "yes", and a learner who enrolled in
    // March and has not read since deserves to see that gap themselves rather
    // than be told they are on track.
    public func render_enroll_control(course_id : &string, enrolled_at : i64, has_session : bool) : string {
        // No session, no control.  The sign-in advisory already sits above the
        // fold on this page and says why; a second prompt from the enrol control
        // would be the same sentence twice, and the reader learns to ignore both.
        if(!has_session) { return string() }
        var out = std::string()
        var ce = underlayer_core::html_escape(course_id)

        if(enrolled_at > 0) {
            var when = underlayer_core::date_string(enrolled_at)
            out.append_view("<span class=\"enroll-state\" id=\"enroll-state\" data-enrolled=\"1\">Enrolled")
            if(when.size() > 0) {
                out.append_view(" since ")
                var we = underlayer_core::html_escape(&when)
                out.append_view(we.to_view())
            }
            out.append_view("</span>")
            return out
        }

        out.append_view("<span class=\"enroll-wrap\" id=\"enroll-wrap\">")
        out.append_view("<button type=\"button\" class=\"enroll-btn\" id=\"enroll-btn\" data-course=\"")
        out.append_view(ce.to_view())
        out.append_view("\">Enroll</button>")
        // The reason, when there is one.  Ships HIDDEN and is filled from
        // can-enroll, for the same reason the sign-in advisory does: a control
        // that shows its own excuse before there is one is noise.
        out.append_view("<span class=\"enroll-why\" id=\"enroll-why\" hidden></span>")
        out.append_view("</span>")
        return out
    }

    // Whether there is a session at all.  Named distinctly from `has_session`
    // in web/src/pages_auth_gate.ch rather than reusing it, because that one
    // takes the same arguments and returning either would work -- and a reader
    // of either file would have no way to tell which gate a given call site is
    // behind.  Two names, two jobs, both short.
    public func has_session_for(db : *DbClient, req : &http::Request) : bool {
        var learner_id = auth_get_learner_id(db, req)
        return learner_id.size() > 0
    }

    // Where the enrolment state actually came from, and what a reader is told.
    //
    // Returned rather than written, so handle_course_landing decides what to do
    // with a zero. The repository write is the ONLY thing that can create a row,
    // and this is a read path, so the control reports what is there.
    public func enrollment_state(db : *DbClient, req : &http::Request, course_id : &string) : i64 {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { return 0 }
        var e = underlayer_repository::get_enrollment(db, &learner_id, course_id)
        if(e.id.size() == 0) { return 0 }
        return e.enrolled_at
    }

    // Inject the control into the landing page's `.course-actions` div.
    //
    // Sentinel replacement again, for the same reason as the lesson header: the
    // markup is produced by 34 hand-rolled landing functions in content/src and
    // threading a session through all of them would touch the entire corpus.
    // Unlike the lesson header this is NOT a no-op when it cannot patch: a
    // missing Enrol control on a course page is the checklist item, so the
    // caller is told by the return value being the unchanged source.
    public func apply_enroll_control(src : &string, course_id : &string, enrolled_at : i64, has_session : bool) : string {
        var marker = src.find(string_view("course-actions"))
        if(marker == std::NPOS) { return src.copy() }
        // The opening tag ends with '>'; the control goes just inside it.
        var gt = src.to_view().subview(marker, src.size()).find(string_view(">"))
        if(gt == std::NPOS) { return src.copy() }
        var control = render_enroll_control(course_id, enrolled_at, has_session)
        if(control.size() == 0) { return src.copy() }
        // The script travels WITH the control, in the same replacement, rather
        // than being written separately -- which is what made the two drift
        // apart and left a <script> on a page with no button on it.
        control.append_string(&render_enroll_js(course_id, enrolled_at, has_session))
        var at = marker + gt + 1
        var built = std::string()
        built.append_view(src.to_view().subview(0, at))
        built.append_string(&control)
        built.append_view(src.to_view().subview(at, src.size()))
        return built
    }

    // The control's script and styles, emitted into the response.
    //
    // Emitted only when the control was actually rendered -- a reader who is
    // already enrolled gets the state and no script, because there is nothing to
    // do. A page carrying a click handler for a button it does not have is the
    // usual way dead JavaScript accumulates.
    // RETURNS the markup, and does not touch `res`.
    //
    // The first version wrote straight to the ResponseWriter, which COMMITS the
    // response -- so the course page that followed came out as a 2,071 byte
    // document containing a <style> and a <script> and no course at all, on
    // every one of the 34 courses. `/courses/elf` answered 200 the whole time,
    // which is the failure mode a status-code check cannot see.
    //
    // It returns "" when there is nothing to wire, so an already-enrolled reader
    // gets the state and no script: a page carrying a click handler for a button
    // it does not have is how dead JavaScript accumulates.
    public func render_enroll_js(course_id : &string, enrolled_at : i64, has_session : bool) : string {
        if(enrolled_at > 0) { return string() }
        if(!has_session) { return string() }

        var ce = underlayer_core::html_escape(course_id)
        var cid_lit = string("'")
        cid_lit.append_string(&ce)
        cid_lit.append_view("'")

        var js = std::string()
        js.append_view("<style>")
        js.append_view(".enroll-btn{font:inherit;font-size:.92rem;font-weight:600;padding:.5rem 1rem;border-radius:8px;border:1px solid #2563eb;background:#2563eb;color:#fff;cursor:pointer}")
        js.append_view(".enroll-btn:hover{background:#1d4ed8}")
        js.append_view(".enroll-btn:disabled{opacity:.6;cursor:default}")
        js.append_view(".enroll-wrap{display:inline-flex;align-items:center;gap:.6rem;flex-wrap:wrap}")
        js.append_view(".enroll-state{font-size:.9rem;color:#6b7280}")
        js.append_view(".enroll-why{font-size:.85rem;color:#b45309}")
        js.append_view("@media (prefers-color-scheme:dark){.enroll-state{color:#9ca3af}.enroll-why{color:#fbbf24}}")
        js.append_view("</style>")

        // Pure ASCII on purpose: js_cbi cannot lex a non-ASCII byte, which is why
        // the arrow glyph in the button label is a CSS entity rather than a
        // character in this string.
        js.append_view("<script>(function(){var course=")
        js.append_string(&cid_lit)
        js.append_view(";var btn=document.getElementById('enroll-btn');if(!btn){return;}")
        js.append_view("var why=document.getElementById('enroll-why');")
        // THE KEY IS `session_token`, and it was `ul_session_token` until
        // 2026-10-03.  Nothing anywhere writes that name: the login and register
        // handlers in pages_auth.ch:123,306 write `session_token`, and all 20-odd
        // readers in content/src read `session_token`.  So `tok()` always returned
        // "", `hdr()` always sent no Authorization header, and both fetches below
        // answered 401 -- which is why the Enroll button is dead on all 34 course
        // landing pages while the page still returned 200 and the button still
        // looked live.
        //
        // It survived because tools/enroll_check.py checks that the button
        // renders in the right STATE and that the served script PARSES.  Both
        // were true.  Reading the key is the part neither check looked at, which
        // is the same shape as the old hamburger test: a check on the thing that
        // exists rather than on the thing that has to be true.
        js.append_view("function tok(){try{return localStorage.getItem('session_token')||'';}catch(e){return '';}}")
        js.append_view("function hdr(){var h={'Content-Type':'application/json'};var t=tok();if(t){h['Authorization']='Bearer '+t;}return h;}")
        // ASK WHY FIRST, so an unmet prerequisite is explained BEFORE the reader
        // presses a button that would fail.
        js.append_view("fetch('/api/courses/'+encodeURIComponent(course)+'/can-enroll',{headers:hdr()})")
        js.append_view(".then(function(r){return r.ok?r.json():null;})")
        js.append_view(".then(function(d){if(!d||d.can_enroll){return;}")
        js.append_view("var m=d.missing||[];if(!m.length){return;}")
        js.append_view("var names=[];")
        js.append_view("for(var i=0;i<m.length;i++){names.push(m[i].required_course_id+' (needs '+m[i].min_mastery_pct+'% mastery)');}")
        js.append_view("why.textContent='Finish '+names.join(', ')+' first.';")
        js.append_view("why.hidden=false;btn.disabled=true;})")
        js.append_view(".catch(function(){});")
        js.append_view("btn.addEventListener('click',function(){")
        js.append_view("btn.disabled=true;btn.textContent='Enrolling...';")
        js.append_view("fetch('/api/courses/'+encodeURIComponent(course)+'/enroll',{method:'POST',headers:hdr()})")
        js.append_view(".then(function(r){return r.json().then(function(j){return {ok:r.ok,j:j};});})")
        js.append_view(".then(function(out){")
        js.append_view("if(out.ok&&out.j&&out.j.ok){")
        // Change the element's own state rather than replacing it with new
        // markup.  The first version built the replacement HTML in a JavaScript
        // string, which meant a nested attribute-quoted string inside a
        // quoted string, which meant escaping quotes in a Chemical string
        // literal -- and Chemical's escaping collapsed them, so the served
        // script contained
        //     w.outerHTML='<span class='enroll-state' ...>'
        // which is a SYNTAX ERROR.  Every course page carried a <script> the
        // browser refused to parse, so the button did nothing at all and the
        // page still answered 200.
        //
        // tools/enroll_check.py evaluates the served script and reports a parse
        // error as a distinct failure from a disabled button, because "the
        // script will not run" and "the script ran and did the wrong thing" are
        // different bugs and were being reported as one.
        js.append_view("btn.className='enroll-state';btn.textContent='Enrolled just now';")
        js.append_view("btn.disabled=true;why.hidden=true;")
        js.append_view("}else{btn.disabled=false;btn.textContent='Enroll';")
        js.append_view("why.textContent=(out.j&&out.j.error)?out.j.error:'Could not enrol. Try again.';why.hidden=false;}")
        js.append_view("})")
        js.append_view(".catch(function(){btn.disabled=false;btn.textContent='Enrol';why.textContent='Could not enrol. Try again.';why.hidden=false;});")
        js.append_view("});})();</script>")
        return js
    }

}
