	.file	"pair.c"
	.text
	.globl	cas_pair_seqcst                 // -- Begin function cas_pair_seqcst
	.p2align	2
	.type	cas_pair_seqcst,@function
cas_pair_seqcst:                        // @cas_pair_seqcst
	.cfi_startproc
// %bb.0:
	ldp	x11, x10, [x1]
	ldp	x13, x12, [x2]
.LBB0_1:                                // =>This Inner Loop Header: Depth=1
	ldaxp	x9, x8, [x0]
	cmp	x9, x11
	cset	w14, ne
	cmp	x8, x10
	cinc	w14, w14, ne
	cbz	w14, .LBB0_3
// %bb.2:                               //   in Loop: Header=BB0_1 Depth=1
	stlxp	w14, x9, x8, [x0]
	cbnz	w14, .LBB0_1
	b	.LBB0_4
.LBB0_3:                                //   in Loop: Header=BB0_1 Depth=1
	stlxp	w14, x13, x12, [x0]
	cbnz	w14, .LBB0_1
.LBB0_4:
	cmp	x9, x11
	ccmp	x8, x10, #0, eq
	cset	w0, eq
	b.eq	.LBB0_6
// %bb.5:
	stp	x9, x8, [x1]
.LBB0_6:
	ret
.Lfunc_end0:
	.size	cas_pair_seqcst, .Lfunc_end0-cas_pair_seqcst
	.cfi_endproc
                                        // -- End function
	.globl	cas_pair_relaxed                // -- Begin function cas_pair_relaxed
	.p2align	2
	.type	cas_pair_relaxed,@function
cas_pair_relaxed:                       // @cas_pair_relaxed
	.cfi_startproc
// %bb.0:
	ldp	x11, x10, [x1]
	ldp	x13, x12, [x2]
.LBB1_1:                                // =>This Inner Loop Header: Depth=1
	ldxp	x9, x8, [x0]
	cmp	x9, x11
	cset	w14, ne
	cmp	x8, x10
	cinc	w14, w14, ne
	cbz	w14, .LBB1_3
// %bb.2:                               //   in Loop: Header=BB1_1 Depth=1
	stxp	w14, x9, x8, [x0]
	cbnz	w14, .LBB1_1
	b	.LBB1_4
.LBB1_3:                                //   in Loop: Header=BB1_1 Depth=1
	stxp	w14, x13, x12, [x0]
	cbnz	w14, .LBB1_1
.LBB1_4:
	cmp	x9, x11
	ccmp	x8, x10, #0, eq
	cset	w0, eq
	b.eq	.LBB1_6
// %bb.5:
	stp	x9, x8, [x1]
.LBB1_6:
	ret
.Lfunc_end1:
	.size	cas_pair_relaxed, .Lfunc_end1-cas_pair_relaxed
	.cfi_endproc
                                        // -- End function
	.globl	cas_pair_acqrel                 // -- Begin function cas_pair_acqrel
	.p2align	2
	.type	cas_pair_acqrel,@function
cas_pair_acqrel:                        // @cas_pair_acqrel
	.cfi_startproc
// %bb.0:
	ldp	x11, x10, [x1]
	ldp	x13, x12, [x2]
.LBB2_1:                                // =>This Inner Loop Header: Depth=1
	ldaxp	x9, x8, [x0]
	cmp	x9, x11
	cset	w14, ne
	cmp	x8, x10
	cinc	w14, w14, ne
	cbz	w14, .LBB2_3
// %bb.2:                               //   in Loop: Header=BB2_1 Depth=1
	stlxp	w14, x9, x8, [x0]
	cbnz	w14, .LBB2_1
	b	.LBB2_4
.LBB2_3:                                //   in Loop: Header=BB2_1 Depth=1
	stlxp	w14, x13, x12, [x0]
	cbnz	w14, .LBB2_1
.LBB2_4:
	cmp	x9, x11
	ccmp	x8, x10, #0, eq
	cset	w0, eq
	b.eq	.LBB2_6
// %bb.5:
	stp	x9, x8, [x1]
.LBB2_6:
	ret
.Lfunc_end2:
	.size	cas_pair_acqrel, .Lfunc_end2-cas_pair_acqrel
	.cfi_endproc
                                        // -- End function
	.globl	pair_fetch_add                  // -- Begin function pair_fetch_add
	.p2align	2
	.type	pair_fetch_add,@function
pair_fetch_add:                         // @pair_fetch_add
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB3_1:                                // =>This Inner Loop Header: Depth=1
	ldaxr	x0, [x8]
	add	x9, x0, x1
	stlxr	w10, x9, [x8]
	cbnz	w10, .LBB3_1
// %bb.2:
	add	x9, x8, #8
.LBB3_3:                                // =>This Inner Loop Header: Depth=1
	ldaxr	x8, [x9]
	add	x10, x8, x1
	stlxr	w11, x10, [x9]
	cbnz	w11, .LBB3_3
// %bb.4:
	mov	x1, x8
	ret
.Lfunc_end3:
	.size	pair_fetch_add, .Lfunc_end3-pair_fetch_add
	.cfi_endproc
                                        // -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
