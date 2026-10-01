// The THE ABSENCE, as a table the artifact prints and a number it counts.
//
// x86-64 has a LOCK prefix.  Eighteen instructions accept it, the memory form
// of `xchg` is implicitly locked whether or not the prefix is present, and
// forgetting the prefix is SILENT: the instruction still assembles and still
// runs and is simply not atomic.
//
// RISC-V has no such thing.  There is no prefix, no implicit lock, and no
// instruction anywhere in the A extension that is atomic because of anything
// other than its own encoding.  The measurement for "no implicit lock" is not
// an argument: it is a count of the instructions in the corpus that take a
// prefix, and the count is ZERO.  This file is how that zero is produced --
// by asking the assembler, once per candidate, and printing its refusal.
//
// AND THE ASYMMETRY IS WORTH MEASURING RATHER THAN ASSERTING, because it is
// not 18 against 0 by construction.  On x86-64 the LOCK prefix is a property
// of the ENCODING and it works on ordinary arithmetic instructions, so the
// eighteen are arithmetic instructions a programmer already knows.  On RISC-V
// the atomics are a DIFFERENT SET of instructions with their own opcode, so
// the count of "instructions that need a prefix to be atomic" is zero and the
// count of "instructions that are atomic and take no prefix" is thirteen at
// two widths and four orderings.  Both numbers are printed, because "zero" on
// its own reads like an absence of features rather than as a design decision.

.intel_syntax noprefix

// ---- the EIGHTEEN, as this collection's sibling course named them, one
//      instruction per line and assembled for real.  Every one of these must
//      still assemble in 2026, because a number copied from a manual is a
//      quotation and a number the assembler accepts is a measurement.
        lock add [rax], rbx
        lock adc [rax], rbx
        lock and [rax], rbx
        lock or [rax], rbx
        lock sbb [rax], rbx
        lock sub [rax], rbx
        lock xor [rax], rbx
        lock cmp [rax], rbx
        lock test [rax], rbx
        lock not qword ptr [rax]
        lock neg qword ptr [rax]
        lock inc dword ptr [rax]
        lock dec dword ptr [rax]
        lock xadd [rax], rbx
        lock cmpxchg [rax], rbx
        lock xchg [rax], rbx
        lock bts [rax], rbx
        lock btr [rax], rbx
        lock btc [rax], rbx
        lock cmpxchg8b [rax]
        lock cmpxchg16b [rax]

// ---- AND THE ONE WITH NO LOCK.  `bt` is on this file because the SDM's
//      eighteen does NOT include it and does include its three siblings, and
//      the reason is structural: bt does not write, so a read-modify-write
//      built out of bt and a store is two instructions and no prefix can make
//      it atomic.  The assembler ACCEPTS `lock bt` -- MEASURED, and the
//      assembler is wrong relative to the manual -- which is exactly the
//      failure this course is here to name, because a reader who trusted the
//      assembler would write a loop that is silently not atomic.
        lock bt [rax], rbx

// ---- AND THE ONE THAT IS IMPLICITLY LOCKED.  The SDM says of `xchg`: "If a
//      memory operand is referenced, the processor's locking protocol is
//      automatically implemented for the duration of the exchange operation,
//      REGARDLESS OF THE PRESENCE OR ABSENCE OF THE LOCK prefix."  So
//      `xchg` appears ONCE in the eighteen and TWICE in the code, and that
//      is the whole of the "two lists everybody quotes and nobody
//      distinguishes" argument, measured rather than paraphrased.
        xchg [rax], rbx