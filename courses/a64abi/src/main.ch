// The AArch64 Procedure Call Standard -- build entry point.
// Renders the landing page and all 5 concept pages to output/.
//
// Concept order, and the reason for it.
//
// 1. `a64-aapcs` first, because the alignment rule is the one requirement that
//    every other rule has to be compatible with: if SP is not a multiple of 16
//    then the q-register load/store pair is not available to anyone, and a
//    contract whose alignment clause is wrong is not a contract.  It is also
//    the page that carries the largest retraction, which is why it is first --
//    the course's reason for existing is printed where the rule is, not in a
//    preface.
// 2. `a64-registers` second, because "which register" is the whole subject of a
//    calling convention and because the answer here is NOT the x86-64 shape:
//    one register with two names, and the number 31 meaning three different
//    things.  A reader arriving from `x86abi` needs this page before the third,
//    not after it.
// 3. `a64-frame` third, because without a red zone the frame is not an
//    optimisation and it is a REQUIREMENT, and because that is the one place
//    where the two architectures' prologues differ by a measurable, constant,
//    two instructions.
// 4. `a64-save` fourth, because who must save what is the other half of the
//    contract, and because the count of zero -- x18, NZCV -- is only surprising
//    to a reader who already knows what the x86-64 answer looks like.
// 5. `a64-unwind` last, because it is the only concept here whose evidence is
//    not the instructions at all: the frame is described a second time, in a
//    second language, and the ratio between the two descriptions is the
//    measurement.  It is last for the same reason `a64-verify` is last in the
//    encoding course: it is the part that says which of the other four you are
//    allowed to believe, and the part where the artifact has to poison its own
//    table before its 100% means anything.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering The AArch64 Procedure Call Standard pages...\n")

    var html = underlayer_content::render_a64abi_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Call -- who passes what, and in which register
    html = underlayer_content::render_a64_aapcs()
    fs::write_text_file("output/a64-aapcs.html", html.data() as *u8, html.size())
    printf("  -> a64-aapcs.html\n")

    html = underlayer_content::render_a64_registers()
    fs::write_text_file("output/a64-registers.html", html.data() as *u8, html.size())
    printf("  -> a64-registers.html\n")

    // Module 2: The Frame -- what the callee must ask for, and describe
    html = underlayer_content::render_a64_frame()
    fs::write_text_file("output/a64-frame.html", html.data() as *u8, html.size())
    printf("  -> a64-frame.html\n")

    html = underlayer_content::render_a64_save()
    fs::write_text_file("output/a64-save.html", html.data() as *u8, html.size())
    printf("  -> a64-save.html\n")

    html = underlayer_content::render_a64_unwind()
    fs::write_text_file("output/a64-unwind.html", html.data() as *u8, html.size())
    printf("  -> a64-unwind.html\n")

    printf("Done: 5 concepts + landing page\n")
    return 0
}
