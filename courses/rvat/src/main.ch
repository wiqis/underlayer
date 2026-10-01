// RISC-V Atomics and the Vector Extension -- build entry point.
// Renders the landing page and all 4 concept pages to output/.
//
// CONCEPT ORDER, and it is the ARTIFACT's order rather than a pedagogical
// one, with one deliberate exception.  The artifact measures before it argues
// (section 1 is a count, section 2 is a zero), and a reader usually needs the
// opposite.  The compromise is made once, here, and stated: the two ATOMIC
// concepts keep the artifact's order because the second is genuinely the
// continuation of the first -- the aq/rl bits are a fence with a part deleted,
// and reading about fences before reading the bits would leave the bits
// unmotivated.  The VECTOR concepts are in their own module and do not depend
// on the atomic ones at all.
//
//   rv-amo       THE ZERO, then the encoding, then lr/sc.  The concept opens
//                with a count -- zero instructions take a lock prefix, against
//                x86-64's measured twenty-two -- because the count is the
//                difference in kind and a paragraph would only assert it.
//                Then eleven funct5 values and twenty-one holes, the width as
//                ONE BIT of funct3 (twelve pairs, every one 0x1000), and
//                aq/rl as two adjacent bits proved by XOR.  Then why the retry
//                loop is the instruction rather than syntax around it, and the
//                seven instructions clang emits for one attempt.
//   rv-fence     the four fields, fifteen named spellings and the sixteenth
//                printed as a hole, three instructions on one opcode -- and
//                then the compiler's translation of the six C11 strengths,
//                including the two that surprise everybody: ACQ_REL becomes
//                fence.tso, and a seq_cst load is an acquire load PLUS TWO
//                FENCES.
//   rv-vector    vsetvli, and the length that is not in it.  zimm[10:8] is
//                measured as constant zero across all 120 reachable variants,
//                which `rvasm` found first and this page builds on.  The tail
//                policy is where portable vector code goes to get hard,
//                because the specification declines to require the fast
//                outcome to be deterministic.
//   rv-dataflow  the mask as one bit in three instruction groups and a
//                register that is NOT in the encoding; the compiler's output
//                at five levels and the -Os finding; two readers on the same
//                bytes with the unmodelled count printed BESIDE the
//                disagreement count; four poisons; and the 58-row
//                measured/quoted boundary with eighteen retractions.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering RISC-V Atomics and the Vector Extension pages...\n")

    var html = underlayer_content::render_rvat_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: atomic -- the zero, the encoding, and the fence
    html = underlayer_content::render_rv_amo()
    fs::write_text_file("output/rv-amo.html", html.data() as *u8, html.size())
    printf("  -> rv-amo.html\n")

    html = underlayer_content::render_rv_fence()
    fs::write_text_file("output/rv-fence.html", html.data() as *u8, html.size())
    printf("  -> rv-fence.html\n")

    // Module 2: vector -- the configuration instruction and the data path
    html = underlayer_content::render_rv_vector()
    fs::write_text_file("output/rv-vector.html", html.data() as *u8, html.size())
    printf("  -> rv-vector.html\n")

    html = underlayer_content::render_rv_dataflow()
    fs::write_text_file("output/rv-dataflow.html", html.data() as *u8, html.size())
    printf("  -> rv-dataflow.html\n")

    printf("Done: 4 concepts + landing page\n")
    printf("NOTHING IN THIS COURSE IS EVER EXECUTED.  No reservation is ever\n")
    printf("HELD, no AMO is ever observed to be atomic, no fence is ever\n")
    printf("observed to order anything, and no vector instruction is ever run.\n")
    printf("There are NO TIMINGS and NO SPEEDUPS: every figure is a bit\n")
    printf("pattern, a count of bit patterns, an arithmetic identity, or a\n")
    printf("refusal from a real assembler.\n")
    return 0
}
