// The x86-64 Data Path: Atomics, Ordering and Vectors -- build entry point.
// Renders all 6 concept pages plus the landing page to output/.
//
// Concept order, and the order is the argument.  The first three concepts
// are the VECTORS: what the register is and what the alignment rule costs,
// what the three-operand encoding changed and what a YMM's upper half holds,
// and then the width this machine cannot execute, where every claim has to be
// demoted from measured to quoted.  The next two are ORDERING, and they are
// the same registers used by two cores at once: the atomic set exhaustively,
// then TSO and the three fences with the direction flag's history.  The last
// one is the artifact, and it is the encoder/decoder pair cross-checked
// against a disassembler that was not written from the same table -- which is
// the only kind of check that has ever caught an encoder bug in this
// collection, including the two it had to be fixed for itself.
public func main() : int {
    fs::mkdir("output")
    printf("Rendering The x86-64 Data Path pages...\n")

    var html = underlayer_content::render_x86simd_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: the vector registers and what the encoding changed
    html = underlayer_content::render_x86_sse()
    fs::write_text_file("output/x86-sse.html", html.data() as *u8, html.size())
    printf("  -> x86-sse.html\n")

    html = underlayer_content::render_x86_avx()
    fs::write_text_file("output/x86-avx.html", html.data() as *u8, html.size())
    printf("  -> x86-avx.html\n")

    html = underlayer_content::render_x86_avx512()
    fs::write_text_file("output/x86-avx512.html", html.data() as *u8, html.size())
    printf("  -> x86-avx512.html\n")

    // Module 2: atomics and ordering, and the instructions that imply LOCK
    html = underlayer_content::render_x86_atomics()
    fs::write_text_file("output/x86-atomics.html", html.data() as *u8, html.size())
    printf("  -> x86-atomics.html\n")

    html = underlayer_content::render_x86_order()
    fs::write_text_file("output/x86-order.html", html.data() as *u8, html.size())
    printf("  -> x86-order.html\n")

    html = underlayer_content::render_x86_bytes()
    fs::write_text_file("output/x86-bytes.html", html.data() as *u8, html.size())
    printf("  -> x86-bytes.html\n")

    printf("Done: 6 concepts + landing page\n")
    return 0
}
