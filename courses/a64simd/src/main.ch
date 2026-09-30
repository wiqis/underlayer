// The AArch64 Data Path: NEON, Atomics and Ordering -- build entry point.
// Renders the landing page and all 5 concept pages to output/.
//
// Concept order, and the reason for it.  This is the LAST course of the
// AArch64 section, so the order is also the section's order, and the one thing
// worth noticing about it is how much of the reasoning is "this page needs the
// reader to have met that page first".
//
// 1. `a64-neon` first, because it is the cheapest possible demonstration of
//    the distinction the whole section turns on: a field's POSITION is a
//    property of an instruction group, and the evidence is one XOR of two
//    words.  `ldr b0` and `ldr q0` differ in bit 23, and bit 30 -- which really
//    is the Q bit in the three-same group -- is not it.  It also has the
//    lowest QUOTED fraction of the five, so it establishes the method before
//    the reader has to trust it.
// 2. `a64-neonspace` second, because it is the direct consequence: the same
//    four element sizes live at two different bit positions in three groups
//    and at NO position for the vector length in the fourth, and the table that
//    makes the reader see it is at the bottom of concept 1.  It is also the
//    course's cleanest single measurement -- five compiles, five identical
//    words -- which is why it comes second and not last: a reader who has been
//    told twice that positions move needs to see once that a field can be
//    absent.
// 3. `a64-atomic` third, because the subject changes from DATA WIDTH to
//    ATOMICITY and that is the point at which "what is in the word" becomes
//    "what the interface allows the instruction to do".  The loop is forced by
//    the status register, and the reader needs the exclusive family before the
//    LSE suffixes mean anything.
// 4. `a64-order` fourth, because it is the payoff of the suffixes concept 3
//    measured: a C11 seq_cst load and a C11 acquire load are the SAME
//    instruction, and a barrier census over the whole corpus finds three.  It
//    cannot come before concept 3 because "acquire" is a bit until concept 3
//    says which bit.
// 5. `a64-dataflow` last, for the same reason `a64-verify` is last in the
//    encoding course, `a64-unwind` is last in the ABI course and
//    `a64-evidence` is last in the machine course: it is the part that says
//    which of the other four you are allowed to believe, and the part where the
//    artifact has to poison its own cross-check -- three of them, because the
//    first version had one that could not fail -- before its zero means
//    anything.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering The AArch64 Data Path: NEON, Atomics and Ordering pages...\n")

    var html = underlayer_content::render_a64simd_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: neon -- the vector register file and the space it shares
    html = underlayer_content::render_a64_neon()
    fs::write_text_file("output/a64-neon.html", html.data() as *u8, html.size())
    printf("  -> a64-neon.html\n")

    html = underlayer_content::render_a64_neonspace()
    fs::write_text_file("output/a64-neonspace.html", html.data() as *u8, html.size())
    printf("  -> a64-neonspace.html\n")

    // Module 2: atomic -- the atomics, the ordering, and the cross-check
    html = underlayer_content::render_a64_atomic()
    fs::write_text_file("output/a64-atomic.html", html.data() as *u8, html.size())
    printf("  -> a64-atomic.html\n")

    html = underlayer_content::render_a64_order()
    fs::write_text_file("output/a64-order.html", html.data() as *u8, html.size())
    printf("  -> a64-order.html\n")

    // The artifact, and the concept that makes the other four trustworthy.
    html = underlayer_content::render_a64_dataflow()
    fs::write_text_file("output/a64-dataflow.html", html.data() as *u8, html.size())
    printf("  -> a64-dataflow.html\n")

    printf("Done: 5 concepts + landing page\n")
    return 0
}
