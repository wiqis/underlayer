// The RISC-V A extension, hand-written, one instruction per line, no labels
// and no directives inside the instruction run.  The artifact pairs source
// line N with word N and CHECKS the pairing on every run, so a file that
// changed shape fails loudly rather than silently mis-pairing a field.
//
// WHY HAND-WRITTEN AND NOT COMPILED FROM C.  The claim this corpus has to
// support is a claim about ENCODINGS: that `aq` is bit 26, that `rl` is bit
// 25, that the `.w`/`.d` suffix is one bit of funct3, and that the eleven
// operations are eleven distinct five-bit funct5 values.  A compiler's
// choice of which atomics to emit is a different claim and section 5 measures
// it separately, from C.

        // ---- the eleven operations, at both widths --------------------
        amoadd.w        a0, a1, (a2)
        amoadd.d        a0, a1, (a2)
        amoswap.w       a0, a1, (a2)
        amoswap.d       a0, a1, (a2)
        amoxor.w        a0, a1, (a2)
        amoxor.d        a0, a1, (a2)
        amoand.w        a0, a1, (a2)
        amoand.d        a0, a1, (a2)
        amoor.w         a0, a1, (a2)
        amoor.d         a0, a1, (a2)
        amomin.w        a0, a1, (a2)
        amomin.d        a0, a1, (a2)
        amomax.w        a0, a1, (a2)
        amomax.d        a0, a1, (a2)
        amominu.w       a0, a1, (a2)
        amominu.d       a0, a1, (a2)
        amomaxu.w       a0, a1, (a2)
        amomaxu.d       a0, a1, (a2)

        // ---- the reservation pair, at both widths ---------------------
        lr.w            a0, (a1)
        lr.d            a0, (a1)
        sc.w            a0, a1, (a2)
        sc.d            a0, a1, (a2)

        // ---- aq and rl, on all THREE of load, store and AMO -----------
        amoadd.w.aq     a0, a1, (a2)
        amoadd.w.rl     a0, a1, (a2)
        amoadd.w.aqrl   a0, a1, (a2)
        amoadd.d.aq     a0, a1, (a2)
        amoadd.d.rl     a0, a1, (a2)
        amoadd.d.aqrl   a0, a1, (a2)
        amoswap.w.aq    a0, a1, (a2)
        amoswap.w.rl    a0, a1, (a2)
        amoswap.w.aqrl  a0, a1, (a2)
        lr.w.aq         a0, (a1)
        lr.w.rl         a0, (a1)
        lr.w.aqrl       a0, (a1)
        lr.d.aq         a0, (a1)
        lr.d.aqrl       a0, (a1)
        sc.w.aq         a0, a1, (a2)
        sc.w.rl         a0, a1, (a2)
        sc.w.aqrl       a0, a1, (a2)
        sc.d.aq         a0, a1, (a2)
        sc.d.rl         a0, a1, (a2)
        sc.d.aqrl       a0, a1, (a2)

        // ---- the discards: rd = x0 and rs2 = x0, because they are the
        //      forms portable code writes and the ones whose encoding is
        //      worth having in the corpus
        amoswap.w       a0, x0, (a1)
        amoswap.d       a0, x0, (a1)
        amoswap.w.rl    x0, a1, (a2)
        amoswap.w.aq    x0, a1, (a2)
        amoadd.w        x0, a1, (a2)
        amoor.w         a0, a1, (a2)

        ret