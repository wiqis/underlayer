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
    course_writer::ensure_output()
    println(`Rendering RISC-V: The ABI, and the Register That Isn't There pages...`)

    var html = underlayer_content::render_rvabi_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: the contract -- what the two compilers agreed on
    html = underlayer_content::render_rv_calling()
    course_writer::write_page("output/rv-calling.html", &html)
    println(`  -> rv-calling.html`)

    // Module 2: the absence -- what is missing, and what that buys
    html = underlayer_content::render_rv_noflags()
    course_writer::write_page("output/rv-noflags.html", &html)
    println(`  -> rv-noflags.html`)

    html = underlayer_content::render_rv_registers()
    course_writer::write_page("output/rv-registers.html", &html)
    println(`  -> rv-registers.html`)

    html = underlayer_content::render_rv_compressed_cost()
    course_writer::write_page("output/rv-compressed-cost.html", &html)
    println(`  -> rv-compressed-cost.html`)

    println(`Done: 4 concepts + landing page`)
    println(`NOTHING IN THIS COURSE WAS EXECUTED.  Every number is a bit`)
    println(`pattern, a count of bit patterns, an arithmetic identity, or a`)
    println(`refusal from a real assembler.`)
    return 0
}
