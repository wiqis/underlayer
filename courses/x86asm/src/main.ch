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
    fs::mkdir("output")
    printf("Rendering x86-64 Assembly and Encoding pages...\n")

    var html = underlayer_content::render_x86asm_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Surface -- what the instructions are
    html = underlayer_content::render_x86_asm()
    fs::write_text_file("output/x86-asm.html", html.data() as *u8, html.size())
    printf("  -> x86-asm.html\n")

    html = underlayer_content::render_x86_integers()
    fs::write_text_file("output/x86-integers.html", html.data() as *u8, html.size())
    printf("  -> x86-integers.html\n")

    html = underlayer_content::render_x86_flags()
    fs::write_text_file("output/x86-flags.html", html.data() as *u8, html.size())
    printf("  -> x86-flags.html\n")

    // Module 2: The Encoding -- what the bytes are
    html = underlayer_content::render_x86_vex()
    fs::write_text_file("output/x86-vex.html", html.data() as *u8, html.size())
    printf("  -> x86-vex.html\n")

    html = underlayer_content::render_x86_map()
    fs::write_text_file("output/x86-map.html", html.data() as *u8, html.size())
    printf("  -> x86-map.html\n")

    printf("Done: 5 concepts + landing page\n")
    return 0
}
