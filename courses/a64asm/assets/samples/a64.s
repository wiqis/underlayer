// a64asm corpus -- hand-written AArch64 assembly.
//
// This file is the FIRST reader's input.  Every label is one instruction the
// course models, assembled by clang's integrated assembler, so the words here
// are not written by hand and not copied from a manual: they are what the
// assembler chose, and the decoder has to agree with the disassembler about
// every one of them.
//
// The file is grouped by the top-level class field, and the groups are the
// four named classes the A64 encoding uses.  Lines that are expected to be
// REFUSED live in refusals.s, not here, because a refusal is evidence the
// artifact captures rather than an instruction it can decode.

        .arch   armv8-a
        .text

// ---------------------------------------------------------------- surface
// The instruction set a person actually writes.  Every one of these is
// fixed 32 bits, which is the claim the first concept makes.
surface:
        nop                                     // 1 byte of work, 4 bytes of file
        ret
        mov     w0, #0
        mov     x0, xzr
        mov     sp, x0
        add     w0, w1, w2
        add     x0, x1, x2
        adds     w0, w1, w2
        sub     w0, w1, w2
        subs     w0, w1, w2
        cmp     w0, w1
        cmn     w0, #1
        neg     w0, w1
        and     w0, w1, w2
        orr     w0, w1, w2
        eor     w0, w1, w2
        ands    w0, w1, w2
        tst     w0, w1
        bic     w0, w1, w2
        orn     w0, w1, w2
        eon     w0, w1, w2
        bics    w0, w1, w2
        mvn     w0, w1
        lsl     w0, w1, #3
        lsr     w0, w1, #3
        asr     w0, w1, #3
        ror     w0, w1, #3
        lsl     w0, w1, w2
        lsr     w0, w1, w2
        asr     w0, w1, w2
        ror     w0, w1, w2
        mul     w0, w1, w2
        madd    w0, w1, w2, w3
        msub    w0, w1, w2, w3
        sdiv    w0, w1, w2
        udiv    w0, w1, w2
        sbfx    w0, w1, #4, #3
        ubfx    w0, w1, #4, #3
        sbfiz    w0, w1, #4, #3
        ubfiz    w0, w1, #4, #3
        sxtw    x0, w1
        uxtw    x0, w1
        clz     w0, w1
        rev     w0, w1
        rev16   w0, w1
        ldp     x0, x1, [sp, #16]
        stp     x0, x1, [sp, #-16]!
        ldp     w0, w1, [x2], #8
        ldr     w0, [x1, #8]
        ldr     x0, [x1, #8]
        ldr     w0, [x1], #4
        ldur    w0, [x1, #-4]
        ldrb    w0, [x1]
        ldrsw   x0, [x1]
        str     w0, [x1, #8]
        stur    w0, [x1, #-4]
        strb    w0, [x1]
        bl      target
        b       target
        br      x0
        blr     x0
        ret

// ---------------------------------------------------------------- immediate
// The two immediate encodings.  `mov` is an ALIAS, not an opcode: each of
// these three lines below assembles to a MOVZ, a MOVK or a MOVN.
immediate:
        movz    w0, #0x1234
        movz    x0, #0x1234, lsl #16
        movk    w0, #0x1234, lsl #16
        movk    x0, #0x1234, lsl #32
        movn    w0, #0x1234
        mov     w0, #0x1234                 // == movz
        add     w0, w1, #0x234
        adds    w0, w1, #0x234
        sub     w0, w1, #0x234
        cmp     w0, #0x234
        add     x0, x1, #0x1000            // the LSL #12 form of the same field
        and     w0, w0, #0xf0f0f0f0
        and     x0, x0, #0xf0f0f0f0f0f0f0f0
        orr     w0, w0, #0xff00ff00
        eor     w0, w0, #0xaaaaaaaa
        ands    w0, w0, #1
        bic     w0, w0, #0xff
        adrp    x0, page
        adr     x1, page
        add     x0, x0, :lo12:page
        extr    x0, x1, x2, #8

// ---------------------------------------------------------------- condition
// The sixteen condition codes, in the four-bit field of a conditional
// select, and the same sixteen in the five-bit field of B.cond.  AL and NV
// are the two the assembler accepts here and refuses for B.cond, and the
// artifact prints both readings.
condition:
        csel    w0, w1, w2, eq
        csel    w0, w1, w2, ne
        csel    w0, w1, w2, cs
        csel    w0, w1, w2, cc
        csel    w0, w1, w2, mi
        csel    w0, w1, w2, pl
        csel    w0, w1, w2, vs
        csel    w0, w1, w2, vc
        csel    w0, w1, w2, hi
        csel    w0, w1, w2, ls
        csel    w0, w1, w2, ge
        csel    w0, w1, w2, lt
        csel    w0, w1, w2, gt
        csel    w0, w1, w2, le
        csel    w0, w1, w2, al
        csel    w0, w1, w2, nv
        cset    w0, eq
        csetm   x0, ne
        csinc   w0, w1, w2, eq
        csinv   w0, w1, w2, ge
        csneg   w0, w1, w2, lt
        cinc    w0, w1, eq
        cinv    w0, w1, ne
        cneg    w0, w1, ge
        csetm   x0, ne
        cinc    w1, w2, eq
        b.eq    target
        b.ne    target
        b.cs    target
        b.hs    target
        b.cc    target
        b.lo    target
        b.mi    target
        b.pl    target
        b.vs    target
        b.vc    target
        b.hi    target
        b.ls    target
        b.ge    target
        b.lt    target
        b.gt    target
        b.le    target
        cbz     w0, target
        cbnz    x0, target
        tbz     w0, #3, target
        tbnz    w0, #31, target
        tbz     x0, #40, target

target:
        nop

// ---------------------------------------------------------------- branch
// The 26-bit unconditional branch, and the 19-bit conditional one, and the
// two compare-and-branch forms that have no displacement field at all.
branch:
        b       far
        bl      far
        cbz     w0, far
far:
        nop
