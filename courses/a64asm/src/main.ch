// AArch64: Encoding From The Ground Up -- build entry point.
// Renders the landing page and all 5 concept pages to output/.
//
// Concept order, and the reason for it.  The length first, because it is the
// one property of the encoding that is free and because every later concept
// depends on it: a decoder that does not know what a word means still knows
// how long it is, and that is the whole difference from x86 in one sentence.
// Then the class field and the field map, because the field map IS the
// curriculum on this architecture -- there are no prefixes to discover and no
// length arithmetic to get wrong, so the bits are the work.  Then the
// immediates, because the logical immediate is the one place in the whole
// architecture where you cannot read the number out, and it reaches more
// values than any other 12-bit field.  Then the conditions, because the
// cset inversion is the sharpest trap in the encoding and it produces output
// that looks right.  And last the cross-check, because the cross-check is
// the part that says which of the other four you are allowed to believe --
// and because it is the part where the artifact has to poison its own table
// before its 100% means anything.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering AArch64: Encoding From The Ground Up pages...`)

    var html = underlayer_content::render_a64asm_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Surface -- what the instructions are
    html = underlayer_content::render_a64_asm()
    course_writer::write_page("output/a64-asm.html", &html)
    println(`  -> a64-asm.html`)

    html = underlayer_content::render_a64_cond()
    course_writer::write_page("output/a64-cond.html", &html)
    println(`  -> a64-cond.html`)

    // Module 2: The Encoding -- what the bytes are
    html = underlayer_content::render_a64_encoding()
    course_writer::write_page("output/a64-encoding.html", &html)
    println(`  -> a64-encoding.html`)

    html = underlayer_content::render_a64_immediate()
    course_writer::write_page("output/a64-immediate.html", &html)
    println(`  -> a64-immediate.html`)

    html = underlayer_content::render_a64_verify()
    course_writer::write_page("output/a64-verify.html", &html)
    println(`  -> a64-verify.html`)

    println(`Done: 5 concepts + landing page`)
    return 0
}
