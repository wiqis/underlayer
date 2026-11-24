// The Instruction Set Architecture -- build entry point.
// Renders all 7 concept pages plus the landing page to output/.
//
// Concept order: the mode first, because "the same bytes have two readings" is
// the fact that makes an encoding worth decoding at all; then the opcode map;
// then the two prefix layers; then addressing; then the arithmetic; then the
// decoder.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Instruction Set Architecture pages...`)

    var html = underlayer_content::render_isa_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: What the Bytes Are
    html = underlayer_content::render_isa_modes()
    course_writer::write_page("output/isa-modes.html", &html)
    println(`  -> isa-modes.html`)

    html = underlayer_content::render_isa_opcodes()
    course_writer::write_page("output/isa-opcodes.html", &html)
    println(`  -> isa-opcodes.html`)

    // Module 2: The Prefix Layers
    html = underlayer_content::render_isa_rex()
    course_writer::write_page("output/isa-rex.html", &html)
    println(`  -> isa-rex.html`)

    html = underlayer_content::render_isa_modrm()
    course_writer::write_page("output/isa-modrm.html", &html)
    println(`  -> isa-modrm.html`)

    // Module 3: Addressing
    html = underlayer_content::render_isa_sib()
    course_writer::write_page("output/isa-sib.html", &html)
    println(`  -> isa-sib.html`)

    html = underlayer_content::render_isa_length()
    course_writer::write_page("output/isa-length.html", &html)
    println(`  -> isa-length.html`)

    // Module 4: Decode It Yourself
    html = underlayer_content::render_isa_decode()
    course_writer::write_page("output/isa-decode.html", &html)
    println(`  -> isa-decode.html`)

    println(`Done: 7 concepts + landing page`)
    return 0
}
