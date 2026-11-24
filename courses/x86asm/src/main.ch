// x86-64 Assembly and Encoding -- build entry point.
// Renders all 5 concept pages plus the landing page to output/.
//
// Concept order: the syntaxes first, because every number in the other four
// concepts is quoted out of a disassembly and a reader who cannot read one
// cannot check any of them.  Then the integer set as a set, which nothing in
// the collection teaches and which the neutral ISA course deliberately does
// not: it taught the DECODING of an instruction, not the collection of them.
// Then the flags, where the branchless forms live and where the sharpest
// experiment in the course lives -- a failing cmov reads its source, and the
// instrument for that is an unreadable page rather than a clock.  Then the
// prefix encodings, which is the first thing in the course whose subject is
// BYTES rather than behaviour.  And last the audit, because the audit is the
// part that says which of the other four you are allowed to believe.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering x86-64 Assembly and Encoding pages...`)

    var html = underlayer_content::render_x86asm_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Surface -- what the instructions are
    html = underlayer_content::render_x86_asm()
    course_writer::write_page("output/x86-asm.html", &html)
    println(`  -> x86-asm.html`)

    html = underlayer_content::render_x86_integers()
    course_writer::write_page("output/x86-integers.html", &html)
    println(`  -> x86-integers.html`)

    html = underlayer_content::render_x86_flags()
    course_writer::write_page("output/x86-flags.html", &html)
    println(`  -> x86-flags.html`)

    // Module 2: The Encoding -- what the bytes are
    html = underlayer_content::render_x86_vex()
    course_writer::write_page("output/x86-vex.html", &html)
    println(`  -> x86-vex.html`)

    html = underlayer_content::render_x86_map()
    course_writer::write_page("output/x86-map.html", &html)
    println(`  -> x86-map.html`)

    println(`Done: 5 concepts + landing page`)
    return 0
}
