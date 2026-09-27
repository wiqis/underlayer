// The Instruction Set Architecture -- build entry point.
// Renders all 7 concept pages plus the landing page to output/.
//
// Concept order: the mode first, because "the same bytes have two readings" is
// the fact that makes an encoding worth decoding at all; then the opcode map;
// then the two prefix layers; then addressing; then the arithmetic; then the
// decoder.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Instruction Set Architecture pages...\n")

    var html = underlayer_content::render_isa_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: What the Bytes Are
    html = underlayer_content::render_isa_modes()
    fs::write_text_file("output/isa-modes.html", html.data() as *u8, html.size())
    printf("  -> isa-modes.html\n")

    html = underlayer_content::render_isa_opcodes()
    fs::write_text_file("output/isa-opcodes.html", html.data() as *u8, html.size())
    printf("  -> isa-opcodes.html\n")

    // Module 2: The Prefix Layers
    html = underlayer_content::render_isa_rex()
    fs::write_text_file("output/isa-rex.html", html.data() as *u8, html.size())
    printf("  -> isa-rex.html\n")

    html = underlayer_content::render_isa_modrm()
    fs::write_text_file("output/isa-modrm.html", html.data() as *u8, html.size())
    printf("  -> isa-modrm.html\n")

    // Module 3: Addressing
    html = underlayer_content::render_isa_sib()
    fs::write_text_file("output/isa-sib.html", html.data() as *u8, html.size())
    printf("  -> isa-sib.html\n")

    html = underlayer_content::render_isa_length()
    fs::write_text_file("output/isa-length.html", html.data() as *u8, html.size())
    printf("  -> isa-length.html\n")

    // Module 4: Decode It Yourself
    html = underlayer_content::render_isa_decode()
    fs::write_text_file("output/isa-decode.html", html.data() as *u8, html.size())
    printf("  -> isa-decode.html\n")

    printf("Done: 7 concepts + landing page\n")
    return 0
}
