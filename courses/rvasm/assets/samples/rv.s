# rv.s -- the hand-written half of the corpus: one instruction per line.
#
# The C corpus is what the COMPILER chooses.  This file is what a person
# chooses, and it exists for three reasons:
#
#   1. It puts a known set of words in the file, so the decoder's field
#      derivations can be read against a known answer.
#   2. It holds the three lengths the section plan measured while scoping --
#      `add a0,a0,a1` at 2 bytes, `vsetvli` at 4, `ecall` at 4 -- so the
#      spectrum is visible in the first page of the report and not only in
#      compiler output.
#   3. It holds the compressed forms the compressed-space enumeration needs:
#      one instruction from every cell of the quadrant map, so the decoder's
#      RVC model is exercised by the corpus and not only by the sweep.
#
# Assembled with -march=rv64gcv, so the vector forms are in there too.  The
# decoder does not MODEL the vector extension -- it counts those words and
# prints them unmodelled -- and the reason is in rvdec.py's declared subset.

        .text
        .globl  spectrum
spectrum:
        add     a0, a0, a1          # 2 bytes: the whole argument for C
        vsetvli t0, a1, e64, m1, ta, ma   # 4 bytes: V is never compressed
        ecall                        # 4 bytes: SYSTEM, opcode 0x73
        nop                         # 2 bytes: addi x0,x0,0
        c.nop                       # the same 2 bytes, named
        li         a2, 5            # addi a2,x0,5
        mv         a3, a4           # add a3,x0,a4
        j          1f               # jal x0,1f
        ret                         # jalr x0,ra,0
        ebreak                      # 0x00100073
        fence                       # 0x0ff0000f
        csrr       a0, cycle         # Zicsr: an I-type with a 12-bit CSR
        csrw       cycle, a0
        lui        a1, 0x12345
        auipc      a1, 0
        addi       a1, a1, -1
        slli       a1, a1, 63
        srli       a1, a1, 3
        srai       a1, a1, 3
        andi       a1, a1, -1
        ori        a1, a1, 0x5
        xori       a1, a1, 0x5
        slti       a1, a1, 3
        sltiu      a1, a1, 3
        addw       a1, a1, a2
        subw       a1, a1, a2
        sllw       a1, a1, a2
        mul        a1, a1, a2
        mulh       a1, a1, a2
        mulhu      a1, a1, a2
        div        a1, a1, a2
        divu       a1, a1, a2
        rem        a1, a1, a2
        remu       a1, a1, a2
        fadd.s     fa0, fa1, fa2
        fsub.s     fa0, fa1, fa2
        fmul.s     fa0, fa1, fa2
        fdiv.s     fa0, fa1, fa2
        fsqrt.s    fa0, fa1
        fmadd.s    fa0, fa1, fa2, fa3
        fcvt.w.s   a0, fa0
        fmv.x.w    a0, fa0
        fld        fa0, 0(a1)
        fsd        fa0, 0(a1)
        fadd.d     fa0, fa1, fa2
        fmul.d     fa0, fa1, fa2
        fcvt.d.s   fa0, fa1
        fcvt.s.d   fa0, fa1
        lr.w       a0, (a1)
        sc.w       a2, a0, (a1)
        amoadd.w   a0, a2, (a1)
        amoswap.w  a0, a2, (a1)
        vadd.vv    v0, v1, v2
        vfmul.vv   v0, v1, v2
        vsetivli   t0, 4, e32, m1
        vle64.v    v0, (a1)
        vse64.v    v0, (a1)
        .balign 8
        vadd.vv    v0, v1, v2
        .balign 8

        # --- the compressed half, one per cell of the quadrant map --------
        .balign 2
compressed:
        c.addi4spn a0, sp, 8         # quadrant 0, funct3 000
        c.fld      fa0, 0(a1)        # quadrant 0, funct3 001
        c.lw       a0, 0(a1)         # quadrant 0, funct3 010
        c.ld       a0, 0(a1)         # quadrant 0, funct3 011 (RV64)
        c.fsd      fa0, 0(a1)        # quadrant 0, funct3 101
        c.sw       a0, 0(a1)         # quadrant 0, funct3 110
        c.sd       a0, 0(a1)         # quadrant 0, funct3 111
        c.addi     a0, 1             # quadrant 1, funct3 000
        c.addiw    a0, 1             # quadrant 1, funct3 001 (RV64)
        c.li       a0, 5             # quadrant 1, funct3 010
        c.lui      a0, 1             # quadrant 1, funct3 011
        c.srli     a0, 3             # quadrant 1, funct3 100 (bits 11:10=00)
        c.srai     a0, 3             # quadrant 1, funct3 100 (bits 11:10=01)
        c.andi     a0, -1            # quadrant 1, funct3 100 (bits 11:10=10)
        c.sub      a0, a1            # quadrant 1, funct3 100 (bits 11:10=11)
        c.xor      a0, a1
        c.or       a0, a1
        c.and      a0, a1
        c.subw     a0, a1            # RV64 only
        c.addw     a0, a1            # RV64 only
        c.j        1f                # quadrant 1, funct3 101
        c.beqz     a0, 1f            # quadrant 1, funct3 110
        c.bnez     a0, 1f            # quadrant 1, funct3 111
        c.slli     a0, 3             # quadrant 2, funct3 000
        c.fldsp    fa0, 0(sp)        # quadrant 2, funct3 001
        c.lwsp     a0, 0(sp)         # quadrant 2, funct3 010
        c.ldsp     a0, 0(sp)         # quadrant 2, funct3 011 (RV64)
        c.jr       a0                # quadrant 2, funct3 100
        c.jalr     a0
        c.mv       a0, a1
        c.add      a0, a1
        c.ebreak
        c.fsdsp    fa0, 0(sp)        # quadrant 2, funct3 101
        c.swsp     a0, 0(sp)         # quadrant 2, funct3 110
        c.sdsp     a0, 0(sp)         # quadrant 2, funct3 111
        c.addi16sp sp, 16
        .balign 2
1:
        ret
