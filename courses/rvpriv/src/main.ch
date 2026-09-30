// The RISC-V Privileged Architecture -- build entry point.
// Renders the landing page and all 4 concept pages to output/.
//
// CONCEPT ORDER, and it is NOT the artifact's section order.  The artifact
// measures the encoding before it quotes the specification, because a compiler
// has to be run before it can be argued with.  A READER needs the opposite:
// WHAT THE PRIVILEGE IS before WHAT THE BYTES ARE, so concept 1 opens with the
// CSR address -- the twelve bits in which the entire privilege convention
// lives -- and only then opens those twelve bits into instructions.
//
//   rv-modes     the convention.  csr[11:10] and csr[9:8] are twelve bits of
//                ADDRESS that are entirely about PERMISSION, and encoding 2 in
//                the privilege field is a hole the table admits.  Then the
//                twelve instructions that touch one, and the single funct3 bit
//                that separates the register forms from the immediate forms --
//                1^5 = 2^6 = 3^7 = 4, three times.  Then the Zicsr split, where
//                the ISA string does not notice.
//   rv-paging    the translation.  Sv39/48/57 is arithmetic -- 512, 39, 36 --
//                and the two natural wrong satp widths both COMPILE, measured
//                on the compiler's own shifts.  Then the relocations a walk
//                emits, and the asymmetry between the HI20 and the LO12 that
//                is the load-bearing fact about a RISC-V relocation.
//   rv-traps     the trap.  The ecall convention measured AS EMITTED, the five
//                registers and their addresses, and the finding that all three
//                stvec functions emit the same 32 bits -- so the mode is a
//                property of the VALUE and the enforcement is hardware this
//                host does not have.
//   rv-boundary  the boundary itself: 44 provenance rows with the count, 16
//                numbered limits, 8 things a reader cannot conclude beside 10
//                they can, 17 retractions each with a SOURCE, and the four
//                poisons.  Named `rv-boundary` rather than the plan's
//                `rv-verify`, because `rv-verify` belongs to the `rvasm`
//                course and two courses cannot both serve a page from one id.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering The RISC-V Privileged Architecture pages...\n")

    var html = underlayer_content::render_rvpriv_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: the convention -- who may touch what
    html = underlayer_content::render_rv_modes()
    fs::write_text_file("output/rv-modes.html", html.data() as *u8, html.size())
    printf("  -> rv-modes.html\n")

    // Module 2: the translation -- what the bits mean
    html = underlayer_content::render_rv_paging()
    fs::write_text_file("output/rv-paging.html", html.data() as *u8, html.size())
    printf("  -> rv-paging.html\n")

    html = underlayer_content::render_rv_traps()
    fs::write_text_file("output/rv-traps.html", html.data() as *u8, html.size())
    printf("  -> rv-traps.html\n")

    html = underlayer_content::render_rv_boundary()
    fs::write_text_file("output/rv-boundary.html", html.data() as *u8, html.size())
    printf("  -> rv-boundary.html\n")

    printf("Done: 4 concepts + landing page\n")
    printf("NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN.  No exception is\n")
    printf("taken, no page is walked, no TLB is consulted, no ecall is observed\n")
    printf("trapping.  Every number is a bit pattern, a count of bit patterns,\n")
    printf("an arithmetic identity, or a refusal from a real assembler.\n")
    return 0
}