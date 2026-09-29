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
    fs::mkdir("output")
    printf("Rendering AArch64: Encoding From The Ground Up pages...\n")

    var html = underlayer_content::render_a64asm_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Surface -- what the instructions are
    html = underlayer_content::render_a64_asm()
    fs::write_text_file("output/a64-asm.html", html.data() as *u8, html.size())
    printf("  -> a64-asm.html\n")

    html = underlayer_content::render_a64_cond()
    fs::write_text_file("output/a64-cond.html", html.data() as *u8, html.size())
    printf("  -> a64-cond.html\n")

    // Module 2: The Encoding -- what the bytes are
    html = underlayer_content::render_a64_encoding()
    fs::write_text_file("output/a64-encoding.html", html.data() as *u8, html.size())
    printf("  -> a64-encoding.html\n")

    html = underlayer_content::render_a64_immediate()
    fs::write_text_file("output/a64-immediate.html", html.data() as *u8, html.size())
    printf("  -> a64-immediate.html\n")

    html = underlayer_content::render_a64_verify()
    fs::write_text_file("output/a64-verify.html", html.data() as *u8, html.size())
    printf("  -> a64-verify.html\n")

    printf("Done: 5 concepts + landing page\n")
    return 0
}
