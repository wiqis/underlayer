// Compiler Backend: From IR to Machine Code -- build entry point.
// Renders the landing page and all 6 concept pages to output/.
//
// CONCEPT ORDER, and it is NOT the artifact's section order.  The artifact
// measures the encoder between selection and allocation, because the encoder
// is what makes the allocation's output checkable.  A READER needs the
// pipeline in the order the questions are asked:
//
//   cb-ir        WHAT IS BEING TRANSLATED.  The representation, and the two
//                halves of what it buys: the ratio, read in BOTH directions,
//                and the half nobody states -- the same source at the same
//                level emits different OPCODE SETS per target.  Opens with
//                the toolchain's four absences, because a claim about a
//                decoder needs one.
//
//   cb-isel      WHICH MACHINE FORM.  The tree walk, and the failure mode
//                nobody names: dispatching on operand KIND alone routes 49 of
//                61 instructions to the wrong form and never fails once.  The
//                checksum is the receipt, not the count.  Then fusion, which
//                is a property of the OPERAND COUNT in the encoding and not a
//                scheduling decision -- and the x86-64 side is a REFUSAL
//                rather than an approximation.
//
//   cb-regalloc  WHICH REGISTER.  Three allocators, three spill POLICIES, two
//                deliberate off-by-ones that fail in OPPOSITE directions, and
//                the ONE measurement in the whole collection no other course
//                could take: a machine that RUNS the code, four arms, four
//                values forced through a stack slot.  The cost of a spill is
//                NOT linear and the page says so without softening it.
//
//   cb-sched     WHICH ORDER.  List scheduling, three priorities, and the
//                kernel chosen on purpose -- kernel_d and NOT kernel_a,
//                because a scheduler given no choice prints three copies of
//                the input and a reader who has not spotted it concludes that
//                scheduling works.  Then the trap: a schedule without an alias
//                analysis is FAST and WRONG, which is the worst combination
//                this course has found.
//
//   cb-abi       WHAT THE CONTRACT IS, FROM THE BACKEND'S SIDE.  Not the
//                convention -- x86abi, a64abi and rvabi each taught their
//                convention in full and are LINKED, not repeated -- but the
//                ORDER: a backend must know the ABI before it allocates,
//                and the reason that is not a matter of taste.
//
//   cb-verify    WHICH OF THE ABOVE YOU ARE ALLOWED TO BELIEVE.  Reading a
//                backend's decisions back out of the bytes with no symbol
//                table and no debug information, then the boundary itself:
//                25 provenance rows with the count, 15 limits, 11 cannot-
//                conclude beside 11 can, 18 retractions, four poisons, and
//                the two-reader check with its normaliser fire table.
//
// Named `cb-verify` for the last concept rather than `cb-boundary` as its
// siblings are: the RISC-V and x86-64 sections both used `*-boundary` for a
// concept that was the measured/quoted table, and the reason they could not
// all take one name is that a concept id is resolved GLOBALLY by
// render_concept() in web/src/helpers.ch with no course in the key, so a
// collision does not 404 -- it silently serves another course's page under
// this course's URL.  Every id in this course is `cb-` prefixed and every one
// was grepped out of that file BEFORE a page was written.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Compiler Backend: From IR to Machine Code pages...`)

    var html = underlayer_content::render_compback_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: the representation
    html = underlayer_content::render_cb_ir()
    course_writer::write_page("output/cb-ir.html", &html)
    println(`  -> cb-ir.html`)

    // Module 2: the three questions about a sequence of operations
    html = underlayer_content::render_cb_isel()
    course_writer::write_page("output/cb-isel.html", &html)
    println(`  -> cb-isel.html`)

    html = underlayer_content::render_cb_regalloc()
    course_writer::write_page("output/cb-regalloc.html", &html)
    println(`  -> cb-regalloc.html`)

    html = underlayer_content::render_cb_sched()
    course_writer::write_page("output/cb-sched.html", &html)
    println(`  -> cb-sched.html`)

    // Module 3: the contract, and reading the decisions back out
    html = underlayer_content::render_cb_abi()
    course_writer::write_page("output/cb-abi.html", &html)
    println(`  -> cb-abi.html`)

    html = underlayer_content::render_cb_verify()
    course_writer::write_page("output/cb-verify.html", &html)
    println(`  -> cb-verify.html`)

    println(`Done: 6 concepts + landing page`)
    println(`X86-64 RAN.  AArch64 AND RISC-V DID NOT: no cross-linker for either`)
    println(`and no emulator, so nothing emitted for those two targets was ever`)
    println(`executed and no relocation they emit was ever resolved.  Every claim`)
    println(`is MEASURED, MEASURED-ON-BYTES or QUOTED, and the label is the claim.`)
    return 0
}
