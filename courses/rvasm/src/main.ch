// RISC-V: The Encoding Spectrum -- build entry point.
// Renders the landing page and all 5 concept pages to output/.
//
// Concept order, and the reason for it.  The ISA first, because "a set of
// documents" is a fact about the architecture that has to be MEASURED before
// anything about the bits makes sense -- and the measurement surprises: M is
// not additive, and F buys this corpus nothing.  Then the six formats and the
// field map, because on RISC-V the field map is NOT the whole curriculum the
// way it is on AArch64: the register fields are in the same place everywhere
// and the immediates are what vary, which is the plan's prediction inverted.
// Then the compressed extension, because it is the one thing that makes this
// architecture different from BOTH of the other two in this collection and
// the honest half of its story is a cost rather than a saving.  Then the
// immediates, because the +-2 KiB branch range and the assembler's refusal to
// refuse are the best measurements in the course.  And last the cross-check,
// because the cross-check is the part that says which of the other four you
// are allowed to believe -- and because it is the part where the artifact has
// to poison its own normaliser before its 100% means anything.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering RISC-V: The Encoding Spectrum pages...\n")

    var html = underlayer_content::render_rvasm_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Documents -- what the instructions are
    html = underlayer_content::render_rv_isa()
    fs::write_text_file("output/rv-isa.html", html.data() as *u8, html.size())
    printf("  -> rv-isa.html\n")

    // Module 2: The Encoding -- what the bytes are
    html = underlayer_content::render_rv_encoding()
    fs::write_text_file("output/rv-encoding.html", html.data() as *u8, html.size())
    printf("  -> rv-encoding.html\n")

    html = underlayer_content::render_rv_compressed()
    fs::write_text_file("output/rv-compressed.html", html.data() as *u8, html.size())
    printf("  -> rv-compressed.html\n")

    html = underlayer_content::render_rv_immediate()
    fs::write_text_file("output/rv-immediate.html", html.data() as *u8, html.size())
    printf("  -> rv-immediate.html\n")

    html = underlayer_content::render_rv_verify()
    fs::write_text_file("output/rv-verify.html", html.data() as *u8, html.size())
    printf("  -> rv-verify.html\n")

    printf("Done: 5 concepts + landing page\n")
    return 0
}
