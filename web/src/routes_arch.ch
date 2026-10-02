// underlayer_web — Route 3 of 3: every architecture, then the backend.
//
// The mission's rule 2 is "every instruction, every architecture", and the
// operational shape it settled on is: neutral courses teach the principle and
// contrast all three ISAs, the per-architecture course teaches one in depth.
// Route 2 is the first half of that.  This is the second half, and it is why
// x86-64 is first -- the other two per-architecture courses are written as
// contrasts against it, so reading AArch64 or RISC-V without it costs you the
// comparison the mission says is the payoff.
//
// The last step is the compiler backend, which declares six of the twelve
// courses above it and is therefore the collection's endpoint rather than a
// course you can start early.
using std::string
using std::vector

public namespace underlayer_web {

    public func route_architectures() : PathRoute {
        var r = PathRoute::make()
        r.id = string("arch")
        r.name = string("Every architecture, then the backend")
        r.tagline = string("x86-64, then AArch64, then RISC-V, then IR to all three.")
        r.blurb = string("Twelve courses that pay the exhaustive per-architecture reference the mission asks for, then the backend that has to emit any of them. The order inside each architecture is fixed by its own prerequisites; the order between the three is a choice, and it is made here so that each one can be read as a contrast against the one before it.")
        r.steps.push(mk_step(string("x86asm"), string("The instruction surface and the encoding behind it. Declares isa, exe, priv, simd and smp -- all of Route 2 -- and is the reference the other two architectures are measured against.")))
        r.steps.push(mk_step(string("x86abi"), string("The calling convention: why the fourth argument of a call is in rcx and the fourth argument of a syscall is in r10, which is a difference of one instruction.")))
        r.steps.push(mk_step(string("x86sys"), string("The privileged side as an inventory: every instruction a ring-3 process can try, and the signal it dies from. The set is not the one in the manual.")))
        r.steps.push(mk_step(string("x86simd"), string("SSE, AVX and AVX-512, then the instructions that imply LOCK without saying so. Declares x86asm, x86abi, smp, simd and mem -- the last data-path course for this architecture.")))
        r.steps.push(mk_step(string("a64asm"), string("AArch64 encoding from the ground up: fixed 32-bit, a four-bit class field, and a logical-immediate encoding that reaches 1,302 of 4,294,967,296 constants.")))
        r.steps.push(mk_step(string("a64abi"), string("AAPCS64. The no-flags-register contrast with x86-64 is the reason this is worth reading after x86abi rather than instead of it: one machine needs csel, another does not have a condition to select.")))
        r.steps.push(mk_step(string("a64sys"), string("Modes, exceptions, interrupts, virtual memory and page tables -- six concepts in two modules, the AArch64 half of what x86sys did for x86-64.")))
        r.steps.push(mk_step(string("a64simd"), string("NEON, atomics and memory ordering, where one bit carries two meanings depending on which register it is in. Completes the AArch64 half.")))
        r.steps.push(mk_step(string("rvasm"), string("The encoding spectrum: 16 or 32 bits, decided by two bits that are also the two bits saying 'this is a 32-bit instruction', and a second three-bit register encoding in the compressed extension.")))
        r.steps.push(mk_step(string("rvabi"), string("The calling convention, and the register that isn't there: no flags register and no condition codes anywhere in the base ISA.")))
        r.steps.push(mk_step(string("rvpriv"), string("The privileged architecture as a document. Declares rvasm, rvabi and obj, and reads the privileged specification the way a compiler author has to read it: encodings, field widths, and the records a page-table walk emits.")))
        r.steps.push(mk_step(string("rvat"), string("Atomics, fences and the vector extension. Declares all three data-path courses and both privileged predecessors, which is why it closes the RISC-V half rather than coming earlier in it.")))
        r.steps.push(mk_step(string("compback"), string("IR to machine code: instruction selection, register allocation, scheduling, and the ABI contract, across all three targets. Declares elf, obj, reloc, link and six of the twelve courses above.")))
        return r
    }

}