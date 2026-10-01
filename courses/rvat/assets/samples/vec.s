// The vector configuration instruction and its neighbours, hand-written.
//
// THE FILE EXISTS TO MAKE FOUR CLAIMS THAT A COMPILER CANNOT MAKE FOR YOU,
// because the compiler emits one vsetvli per loop and always the same one:
//
//   1. zimm[10:0] is ELEVEN bits and it is NOT the vector length.  Sweeping
//      the element width with everything else held constant moves three bits.
//   2. zimm[10:8] is CONSTANT ZERO in all 112 reachable variants.  Three bits
//      of an eleven-bit field that no reachable vsetvli uses, and the reason
//      it is in the file is that a field map measured by sweep records which
//      bits MOVE -- three bits that never move look exactly like three bits
//      that do.
//   3. The three configuration instructions are told apart by TWO BITS,
//      inst[31:30], and the SAME inst[19:15] is a register in two of them and
//      a five-bit IMMEDIATE in the third.
//   4. The MASK is one bit and it is the same bit in an arithmetic
//      instruction, a unit-stride load and a unit-stride store, which is what
//      makes `vm` a field of the data path rather than of one group.
//
// The 112 variants come first because they are the sweep the section is
// built on, and the rest are the neighbours the sweep does not reach.

        // ---- 112 variants: 4 element widths x 7 LMULs x 2 ta/tu x 2 ma/mu
        vsetvli t0, a1, e8, mf8, ta, ma
        vsetvli t0, a1, e8, mf8, ta, mu
        vsetvli t0, a1, e8, mf8, tu, ma
        vsetvli t0, a1, e8, mf8, tu, mu
        vsetvli t0, a1, e8, mf4, ta, ma
        vsetvli t0, a1, e8, mf4, ta, mu
        vsetvli t0, a1, e8, mf4, tu, ma
        vsetvli t0, a1, e8, mf4, tu, mu
        vsetvli t0, a1, e8, mf2, ta, ma
        vsetvli t0, a1, e8, mf2, ta, mu
        vsetvli t0, a1, e8, mf2, tu, ma
        vsetvli t0, a1, e8, mf2, tu, mu
        vsetvli t0, a1, e8, m1, ta, ma
        vsetvli t0, a1, e8, m1, ta, mu
        vsetvli t0, a1, e8, m1, tu, ma
        vsetvli t0, a1, e8, m1, tu, mu
        vsetvli t0, a1, e8, m2, ta, ma
        vsetvli t0, a1, e8, m2, ta, mu
        vsetvli t0, a1, e8, m2, tu, ma
        vsetvli t0, a1, e8, m2, tu, mu
        vsetvli t0, a1, e8, m4, ta, ma
        vsetvli t0, a1, e8, m4, ta, mu
        vsetvli t0, a1, e8, m4, tu, ma
        vsetvli t0, a1, e8, m4, tu, mu
        vsetvli t0, a1, e8, m8, ta, ma
        vsetvli t0, a1, e8, m8, ta, mu
        vsetvli t0, a1, e8, m8, tu, ma
        vsetvli t0, a1, e8, m8, tu, mu
        vsetvli t0, a1, e16, mf8, ta, ma
        vsetvli t0, a1, e16, mf8, ta, mu
        vsetvli t0, a1, e16, mf8, tu, ma
        vsetvli t0, a1, e16, mf8, tu, mu
        vsetvli t0, a1, e16, mf4, ta, ma
        vsetvli t0, a1, e16, mf4, ta, mu
        vsetvli t0, a1, e16, mf4, tu, ma
        vsetvli t0, a1, e16, mf4, tu, mu
        vsetvli t0, a1, e16, mf2, ta, ma
        vsetvli t0, a1, e16, mf2, ta, mu
        vsetvli t0, a1, e16, mf2, tu, ma
        vsetvli t0, a1, e16, mf2, tu, mu
        vsetvli t0, a1, e16, m1, ta, ma
        vsetvli t0, a1, e16, m1, ta, mu
        vsetvli t0, a1, e16, m1, tu, ma
        vsetvli t0, a1, e16, m1, tu, mu
        vsetvli t0, a1, e16, m2, ta, ma
        vsetvli t0, a1, e16, m2, ta, mu
        vsetvli t0, a1, e16, m2, tu, ma
        vsetvli t0, a1, e16, m2, tu, mu
        vsetvli t0, a1, e16, m4, ta, ma
        vsetvli t0, a1, e16, m4, ta, mu
        vsetvli t0, a1, e16, m4, tu, ma
        vsetvli t0, a1, e16, m4, tu, mu
        vsetvli t0, a1, e16, m8, ta, ma
        vsetvli t0, a1, e16, m8, ta, mu
        vsetvli t0, a1, e16, m8, tu, ma
        vsetvli t0, a1, e16, m8, tu, mu
        vsetvli t0, a1, e32, mf8, ta, ma
        vsetvli t0, a1, e32, mf8, ta, mu
        vsetvli t0, a1, e32, mf8, tu, ma
        vsetvli t0, a1, e32, mf8, tu, mu
        vsetvli t0, a1, e32, mf4, ta, ma
        vsetvli t0, a1, e32, mf4, ta, mu
        vsetvli t0, a1, e32, mf4, tu, ma
        vsetvli t0, a1, e32, mf4, tu, mu
        vsetvli t0, a1, e32, mf2, ta, ma
        vsetvli t0, a1, e32, mf2, ta, mu
        vsetvli t0, a1, e32, mf2, tu, ma
        vsetvli t0, a1, e32, mf2, tu, mu
        vsetvli t0, a1, e32, m1, ta, ma
        vsetvli t0, a1, e32, m1, ta, mu
        vsetvli t0, a1, e32, m1, tu, ma
        vsetvli t0, a1, e32, m1, tu, mu
        vsetvli t0, a1, e32, m2, ta, ma
        vsetvli t0, a1, e32, m2, ta, mu
        vsetvli t0, a1, e32, m2, tu, ma
        vsetvli t0, a1, e32, m2, tu, mu
        vsetvli t0, a1, e32, m4, ta, ma
        vsetvli t0, a1, e32, m4, ta, mu
        vsetvli t0, a1, e32, m4, tu, ma
        vsetvli t0, a1, e32, m4, tu, mu
        vsetvli t0, a1, e32, m8, ta, ma
        vsetvli t0, a1, e32, m8, ta, mu
        vsetvli t0, a1, e32, m8, tu, ma
        vsetvli t0, a1, e32, m8, tu, mu
        vsetvli t0, a1, e64, mf8, ta, ma
        vsetvli t0, a1, e64, mf8, ta, mu
        vsetvli t0, a1, e64, mf8, tu, ma
        vsetvli t0, a1, e64, mf8, tu, mu
        vsetvli t0, a1, e64, mf4, ta, ma
        vsetvli t0, a1, e64, mf4, ta, mu
        vsetvli t0, a1, e64, mf4, tu, ma
        vsetvli t0, a1, e64, mf4, tu, mu
        vsetvli t0, a1, e64, mf2, ta, ma
        vsetvli t0, a1, e64, mf2, ta, mu
        vsetvli t0, a1, e64, mf2, tu, ma
        vsetvli t0, a1, e64, mf2, tu, mu
        vsetvli t0, a1, e64, m1, ta, ma
        vsetvli t0, a1, e64, m1, ta, mu
        vsetvli t0, a1, e64, m1, tu, ma
        vsetvli t0, a1, e64, m1, tu, mu
        vsetvli t0, a1, e64, m2, ta, ma
        vsetvli t0, a1, e64, m2, ta, mu
        vsetvli t0, a1, e64, m2, tu, ma
        vsetvli t0, a1, e64, m2, tu, mu
        vsetvli t0, a1, e64, m4, ta, ma
        vsetvli t0, a1, e64, m4, ta, mu
        vsetvli t0, a1, e64, m4, tu, ma
        vsetvli t0, a1, e64, m4, tu, mu
        vsetvli t0, a1, e64, m8, ta, ma
        vsetvli t0, a1, e64, m8, ta, mu
        vsetvli t0, a1, e64, m8, tu, ma
        vsetvli t0, a1, e64, m8, tu, mu

        // ---- the OTHER TWO configuration instructions, and the fact
        //      that inst[19:15] is a REGISTER in one and an IMMEDIATE in
        //      the other.  uimm = 0 and uimm = 31 are ONE BIT apart at
        //      inst[15], which is the low bit of the field the base ISA
        //      calls rs1, and uimm = 1 and uimm = 0 are one bit apart at
        //      inst[14], so the field is five bits and not four.
        vsetivli t0, 0, e32, m1, ta, ma
        vsetivli t0, 1, e32, m1, ta, ma
        vsetivli t0, 30, e32, m1, ta, ma
        vsetivli t0, 31, e32, m1, ta, ma
        vsetivli t0, 0, e8, m8, tu, mu
        vsetivli t0, 31, e64, m2, ta, mu
        vsetvl   t0, a1, a2
        vsetvl   t0, zero, a2
        vsetvl   t0, a1, zero

        // ---- AVL: the two instructions the SPEC says are the same
        //      length in different spelling, and the one that keeps the
        //      old length.  These are the three rows of the manual's
        //      Table 49 and the artifact prints the table beside them.
        vsetvli a0, a1, e64, m1, ta, ma
        vsetvli a0, zero, e64, m1, ta, ma
        vsetvli zero, zero, e64, m1, ta, ma
        vsetvli a0, a1, e32, m2, tu, mu
        vsetvli a0, zero, e32, m2, tu, mu

        // ---- the PARTIAL policy spellings.  The manual calls the two flags
        //      MANDATORY and says omitting them is deprecated -- and the
        //      assembler ACCEPTS them, defaulting to tu, mu.  §KEEP§SO THE
        //      DEFAULTS CHANGED, THE CHANGE WAS MADE BY REMOVING THE DEFAULT,
        //      AND THE ASSEMBLER STILL HAS ONE: A PROGRAM THAT SAYS NOTHING
        //      GETS tu/mu, WHICH IS THE CONSERVATIVE POLICY, NOT THE FAST
        //      ONE THE SPECIFICATION SAYS IT MIGHT PREFER.
        vsetvli t0, a1, e32, m1
        vsetvli t0, a1, e32, m1, ta
        vsetvli t0, a1, e8, m8, tu

        // ---- the MASK, as one bit in three different groups.  Each pair
        //      below is the SAME instruction with and without `v0.t`, and
        //      the artifact prints the XOR of each pair.  The second of
        //      the load pairs is a different width, so a reader can see
        //      that the mask bit is not in funct3.
        vadd.vv  v1, v2, v3
        vadd.vv  v1, v2, v3, v0.t
        vadd.vi  v1, v2, 7
        vadd.vi  v1, v2, 7, v0.t
        vadd.vx  v1, v2, a0
        vadd.vx  v1, v2, a0, v0.t
        vle8.v   v1, (a0)
        vle8.v   v1, (a0), v0.t
        vle16.v  v1, (a0)
        vle16.v  v1, (a0), v0.t
        vle32.v  v1, (a0)
        vle32.v  v1, (a0), v0.t
        vle64.v  v1, (a0)
        vle64.v  v1, (a0), v0.t
        vse8.v   v1, (a0)
        vse8.v   v1, (a0), v0.t
        vse16.v  v1, (a0)
        vse16.v  v1, (a0), v0.t
        vse32.v  v1, (a0)
        vse32.v  v1, (a0), v0.t
        vse64.v  v1, (a0)
        vse64.v  v1, (a0), v0.t

        // ---- the register GROUP, which is what LMUL buys: nf at the top
        //      three bits, and the same body with one, two, four and eight
        //      registers' worth of it.  The REGISTER NUMBER is constrained
        //      and the constraint is a REFUSAL, not a diagnostic -- a
        //      group of two must start at an even register, and `vl2r.v
        //      v1` is refused while `vl2r.v v8` assembles.  So the group
        //      count and the register alignment are ONE rule, and it is
        //      the rule that makes a register allocator's life harder than
        //      on a machine where a vector register is one register.
        vl1r.v   v1, (a0)
        vl2r.v   v8, (a0)
        vl4r.v   v8, (a0)
        vl8r.v   v8, (a0)
        vl2re64.v v8, (a0)
        vs1r.v   v1, (a0)
        vs2r.v   v8, (a0)
        vs4r.v   v8, (a0)
        vs8r.v   v8, (a0)

        // ---- a mask producer, so `v0` is a DESTINATION in this corpus
        //      and not only a source
        vmsne.vi  v0, v1, 0
        vmsne.vi  v0, v1, 3
        vlm.v     v2, (a0)
        vmv.v.i   v1, 5
        vmv.v.v   v1, v2
        vmv.x.s   a0, v1
        vmv.s.x   v1, a0

        ret