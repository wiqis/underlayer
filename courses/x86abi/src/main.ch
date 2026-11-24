// The x86-64 ABI -- build entry point.
// Renders all 6 concept pages plus the landing page to output/.
//
// Concept order: the CALL first, because a reader who does not know which
// register the fourth argument is in cannot check anything else, and because
// the course's central correction is about that register.  Then the frame,
// where the alignment rule and the red zone both turn out to be narrower than
// the slogans.  Then the saved registers, established by experiment rather
// than by a table, and the two floating-point control registers that point the
// other way.  Then varargs, the one place the convention has to describe
// itself, and the place where a lie is measurable.  Then the SECOND
// description of the same frame -- unwinding -- because it is the same frame
// again and a reader who has just spent a course learning one description of
// it is the reader most likely to assume there is only one.  And last the
// audit, which is the part that says which of the other five you are allowed
// to believe.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering The x86-64 ABI pages...`)

    var html = underlayer_content::render_x86abi_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Frame -- what a call owes whom
    html = underlayer_content::render_x86_calling()
    course_writer::write_page("output/x86-calling.html", &html)
    println(`  -> x86-calling.html`)

    html = underlayer_content::render_x86_frame()
    course_writer::write_page("output/x86-frame.html", &html)
    println(`  -> x86-frame.html`)

    html = underlayer_content::render_x86_saved()
    course_writer::write_page("output/x86-saved.html", &html)
    println(`  -> x86-saved.html`)

    html = underlayer_content::render_x86_varargs()
    course_writer::write_page("output/x86-varargs.html", &html)
    println(`  -> x86-varargs.html`)

    // Module 2: The Second Description -- unwinding and the audit
    html = underlayer_content::render_x86_unwind()
    course_writer::write_page("output/x86-unwind.html", &html)
    println(`  -> x86-unwind.html`)

    html = underlayer_content::render_x86_verify()
    course_writer::write_page("output/x86-verify.html", &html)
    println(`  -> x86-verify.html`)

    println(`Done: 6 concepts + landing page`)
    return 0
}
