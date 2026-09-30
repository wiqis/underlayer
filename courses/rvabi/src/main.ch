// RISC-V: The ABI, and the Register That Isn't There -- build entry point.
// Renders the landing page and all 4 concept pages to output/.
//
// CONCEPT ORDER, and it is the reverse of the artifact's section order on
// purpose.  The artifact measures the calling convention first because the
// specification has to be quoted before a compiler can be tested against it;
// a READER needs the opposite: the absence comes first, because it is the
// spine, and everything after it is a consequence.
//
//   rv-calling         the contract.  a0-a7, a0/fa0 for the return value,
//                      s0-s11 callee-saved, t0-t6 and a0-a7 caller-saved, ra
//                      and sp privileged, no red zone, frame pointer
//                      OPTIONAL.  And the one row of the contract that a
//                      summary gets wrong: the ninth DOUBLE arrives in a0, an
//                      INTEGER register, because the hardware floating-point
//                      convention falls back to the integer convention.
//   rv-noflags         the spine.  No flags register, no condition codes, no
//                      CMOVcc, no SETcc -- and the CONSTRUCTIVE half, which is
//                      the half nobody states: `sltu` writes a register, so
//                      min/max/clamp/abs are expressible without a
//                      conditional move at all.
//   rv-registers       the register file as ROLES, x0 hardwired to zero, the
//                      two files that share a spelling up to one character,
//                      and why a callee here saves FEWER registers than an
//                      x86-64 callee: there is no flags register to save.
//   rv-compressed-cost the consequence.  A spill, a hot loop and a
//                      call/return pair measured before and after the C
//                      extension, and the two-bit length rule that a
//                      disassembler is built on.  Instruction and byte counts,
//                      explicitly not a speedup.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering RISC-V: The ABI, and the Register That Isn't There pages...\n")

    var html = underlayer_content::render_rvabi_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: the contract -- what the two compilers agreed on
    html = underlayer_content::render_rv_calling()
    fs::write_text_file("output/rv-calling.html", html.data() as *u8, html.size())
    printf("  -> rv-calling.html\n")

    // Module 2: the absence -- what is missing, and what that buys
    html = underlayer_content::render_rv_noflags()
    fs::write_text_file("output/rv-noflags.html", html.data() as *u8, html.size())
    printf("  -> rv-noflags.html\n")

    html = underlayer_content::render_rv_registers()
    fs::write_text_file("output/rv-registers.html", html.data() as *u8, html.size())
    printf("  -> rv-registers.html\n")

    html = underlayer_content::render_rv_compressed_cost()
    fs::write_text_file("output/rv-compressed-cost.html", html.data() as *u8,
                        html.size())
    printf("  -> rv-compressed-cost.html\n")

    printf("Done: 4 concepts + landing page\n")
    printf("NOTHING IN THIS COURSE WAS EXECUTED.  Every number is a bit\n")
    printf("pattern, a count of bit patterns, an arithmetic identity, or a\n")
    printf("refusal from a real assembler.\n")
    return 0
}
