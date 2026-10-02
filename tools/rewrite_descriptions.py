#!/usr/bin/env python3
"""rewrite_descriptions.py -- the 34 rewritten storefront descriptions, in one place.

This file is not imported by anything.  It is the RECORD of what the
descriptions were changed to and why each one is worded the way it is, kept
next to tools/description_check.py which enforces the result.  Rewriting them
through a script rather than by hand is what makes the result auditable as a
diff: 34 edits in 34 files, all of them one field, all of them reviewable in
one place.

THE RULE EACH DESCRIPTION FOLLOWS, and it is the founder's, not mine:

    > "these things are supposed to be internal, known to us, not the user, we
    >  are working to improve the courses, we are not supposed to advertise our
    >  courses are flawed, therefore shouldn't be learned through"

So a description says WHAT THE LEARNER WILL BE ABLE TO DO and nothing else.
Every one opens with a verb a reader can act on.  None of them mentions a
machine, a host, an emulator, an evidence label, a retraction, a harness, or
another course.

WHAT WAS CUT, and it is the same list for all 34, because it is one editorial
decision applied consistently:

  * "There is no AArch64 machine on the machine that wrote this course and no
    emulator, so not one instruction in it has been run" -- the exact sentence
    the founder quoted.  It is a true statement about the BUILD, printed on a
    page a shopper is deciding whether to read.  It belongs in the lesson that
    needs it (a64sys's own concept 6 prints the whole measured/quoted boundary)
    and not in a two-line pitch.
  * "MEASURED, MEASURED-ON-BYTES, QUOTED" -- this collection's internal
    evidence vocabulary.  A reader does not know what a "MEASURED-ON-BYTES"
    row means before they read a concept that defines it, so on a storefront it
    is three capitalised words that ask for trust instead of giving it.
  * "N retractions", "17 limits", "four poisons", "a 171-check harness" --
    these are properties of the ARTIFACT, and they are the collection's best
    quality signal, which is exactly why they belong inside the course next to
    the evidence rather than in the sentence that sells it.
  * "the middle of the chain", "the fourth and last course of the AArch64
    section", "the sibling", "taught in depth elsewhere" -- course-against-
    course positioning.  It makes a reader feel they are being sequenced rather
    than taught, and it is stale the moment a course moves.

WHAT WAS KEPT, and this is the part that matters:

The substance did not move an inch.  Every claim that used to be in a
description is still in the lesson that earned it, paired with the measurement
and a reader can see why it does not diminish the course.  No file under
content/src/ was edited for this change except three route reasons, and no
concept page was touched at all.  The descriptions were the only place the
caveats were being advertised to people who had not asked.
"""

DESCRIPTIONS = {
    # ---- the x86-64 section ----------------------------------------
    'x86asm': (
        "Write and read x86-64 assembly: the legacy, VEX and EVEX encodings, "
        "the flags, the conditionals and the addressing modes a compiler emits."
    ),
    'x86abi': (
        "Place arguments, results and callee-saved registers the way x86-64 "
        "code requires, including why a system call moves the return address "
        "into r10 instead of rcx."
    ),
    'x86sys': (
        "Find out what a ring-3 process can and cannot ask the CPU for, and "
        "tell a privilege check apart from a page table that will not map you."
    ),
    'x86simd': (
        "Write correct x86-64 atomics and vector code, and know which "
        "LOCK-prefixed forms are exact, which only look it, and what alignment "
        "really costs."
    ),

    # ---- the AArch64 section ---------------------------------------
    'a64asm': (
        "Decode any AArch64 instruction from its 32 bits: the register classes, "
        "the logical-immediate encoding, the conditionals and the bit patterns "
        "that do not mean what they first look like."
    ),
    'a64abi': (
        "Pass arguments and return values the way AArch64 code expects, and "
        "know the rules clang obeys that the C source never mentions, from the "
        "stack alignment to the unwind table."
    ),
    'a64sys': (
        "Handle an exception, take a page-table walk and place the registers an "
        "interrupt saves, on the machine an embedded target actually runs on."
    ),
    'a64simd': (
        "Read and write AArch64 SIMD registers, express an atomic in the form "
        "the architecture defines, and put a barrier where one is actually "
        "needed rather than where habit puts it."
    ),

    # ---- the RISC-V section ----------------------------------------
    'rvasm': (
        "Decode RISC-V instructions, compressed or not, and see why one format "
        "scatters its immediates while the compressed extension adds a second "
        "register field entirely."
    ),
    'rvabi': (
        "Pass arguments and results the way RISC-V code requires, and "
        "understand why the architecture needs no condition-code register at "
        "all -- and what a compiler does instead."
    ),
    'rvpriv': (
        "Read the RISC-V privileged specification as a compiler author: CSR "
        "encodings and their accessibility fields, the satp page-table format, "
        "and the relocation records a walk emits."
    ),
    'rvat': (
        "Write correct RISC-V atomics and memory ordering, and set up a vector "
        "whose length and element width are programmed at run time rather than "
        "fixed in the encoding."
    ),

    # ---- neutral: formats -------------------------------------------
    'elf': (
        "Read any ELF binary end to end: headers, sections, segments, symbols, "
        "relocations, and the dynamic structures that connect it to a shared "
        "library."
    ),
    'macho': (
        "Read any Mach-O binary: headers, load commands, segments, sections, "
        "symbols, dyld, code signing, and how macOS maps an image into memory."
    ),
    'pe': (
        "Read any Windows PE image: the DOS and COFF headers, data "
        "directories, sections, imports, exports, base relocations, TLS and "
        "resources."
    ),
    'coff': (
        "Read a COFF object file: its file header, its section table, and the "
        "symbol and relocation records a linker uses to place code whose final "
        "address nobody knows yet."
    ),
    'jvm': (
        "Read a .class file: the magic number, the versions, the constant pool "
        "everything points into, the code a verifier checks, and the attribute "
        "that has carried every new language feature for years."
    ),
    'wasm': (
        "Read a WebAssembly binary: its eight-byte header, its ordered "
        "sections, the variable-width LEB128 encoding almost every number uses, "
        "and the object file built on top."
    ),
    'dwarf': (
        "Take an address in a running program back to the file, line and local "
        "variable it came from, by reading the DWARF sections a compiler emits."
    ),

    # ---- neutral: the link, IR to a process -------------------------
    'obj': (
        "Read the object file your compiler emits: its sections, its symbol "
        "tables, its fixup records and the holes left for a linker to fill."
    ),
    'sym': (
        "Explain how a linker turns a name into an address: binding, "
        "visibility, archive extraction, versioning and the symbols the linker "
        "invents on your behalf."
    ),
    'reloc': (
        "Choose the right relocation for a reference, explain what position "
        "independence actually costs, and recognise the two ways it goes wrong."
    ),
    'link': (
        "Follow a link from object files to a finished executable, and write "
        "the linker script that decides where every section lands and why."
    ),
    'dyn': (
        "Trace an undefined symbol from the first reference to the shared "
        "library that answers it: the lookup scope, .dynsym, versioning, TLS "
        "blocks and loading at run time."
    ),
    'img': (
        "Follow a program from an executable image to its first instruction: "
        "the kernel's mapping, the auxiliary vector, the initial stack and the "
        "addresses you are handed."
    ),
    'sec': (
        "Say what each hardening flag does to the bytes it produces, and which "
        "of the three layers -- compiler, linker or driver -- is where that "
        "decision gets made."
    ),
    'isa': (
        "Decode x86-64 from bytes yourself: the mode, the opcode map, the "
        "prefix layers, ModRM and SIB, and the length arithmetic a tool has to "
        "do with no help."
    ),
    'exe': (
        "Explain why one instruction sequence runs faster than another: "
        "dependencies, execution width, the front end, branch prediction and "
        "speculation."
    ),
    'mem': (
        "Predict what a memory access will cost: cache sizes and "
        "associativity, the translation path, prefetching, and the point where "
        "a huge page stops paying for itself."
    ),
    'priv': (
        "Explain what happens when a program asks for something it cannot do "
        "itself: the gate tables, the ways in, and what the privilege boundary "
        "really protects."
    ),
    'smp': (
        "Reason about a program running on more than one core: topologies, true "
        "and false sharing, memory ordering, and when an atomic instruction "
        "buys anything at all."
    ),
    'simd': (
        "Decide when vectorisation pays, read a vector instruction, and use "
        "gathers, reductions and lane boundaries without a data-dependent stall."
    ),

    # ---- the backend ------------------------------------------------
    'compback': (
        "Read a compiler backend from front to back: instruction selection, "
        "register allocation, scheduling and encoding, and see every one of "
        "those decisions in the emitted bytes."
    ),

    # ---- HAT --------------------------------------------------------
    'hat': (
        "Prepare for the HEC Higher Education Aptitude Test: the paper and how "
        "it is weighted, quantitative and verbal practice, analytical "
        "reasoning, timed drills and full mocks."
    ),
}

# The order the courses are listed in the storefront, for the report.
ORDER = [
    'elf', 'macho', 'pe', 'coff', 'jvm', 'wasm', 'dwarf',
    'obj', 'sym', 'reloc', 'link', 'dyn', 'img', 'sec',
    'isa', 'exe', 'mem', 'priv', 'smp', 'simd',
    'x86asm', 'x86abi', 'x86sys', 'x86simd',
    'a64asm', 'a64abi', 'a64sys', 'a64simd',
    'rvasm', 'rvabi', 'rvpriv', 'rvat',
    'compback', 'hat',
]

if __name__ == '__main__':
    for cid in ORDER:
        d = DESCRIPTIONS[cid]
        flag = 'OK ' if 120 <= len(d) <= 200 else 'BAD'
        print('%s %-9s %3d  %s' % (flag, cid, len(d), d))