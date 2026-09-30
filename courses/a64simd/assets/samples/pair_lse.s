	.file	"pair.c"
	.text
	.globl	cas_pair_seqcst                 // -- Begin function cas_pair_seqcst
	.p2align	2
	.type	cas_pair_seqcst,@function
cas_pair_seqcst:                        // @cas_pair_seqcst
	.cfi_startproc
// %bb.0:
	ldp	x4, x5, [x1]
	ldp	x6, x7, [x2]
	mov	x2, x4
	mov	x3, x5
	caspal	x2, x3, x6, x7, [x0]
	cmp	x2, x4
	ccmp	x3, x5, #0, eq
	cset	w0, eq
	b.eq	.LBB0_2
// %bb.1:
	stp	x2, x3, [x1]
.LBB0_2:
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
	ldp	x4, x5, [x1]
	ldp	x6, x7, [x2]
	mov	x2, x4
	mov	x3, x5
	casp	x2, x3, x6, x7, [x0]
	cmp	x2, x4
	ccmp	x3, x5, #0, eq
	cset	w0, eq
	b.eq	.LBB1_2
// %bb.1:
	stp	x2, x3, [x1]
.LBB1_2:
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
	ldp	x4, x5, [x1]
	ldp	x6, x7, [x2]
	mov	x2, x4
	mov	x3, x5
	caspal	x2, x3, x6, x7, [x0]
	cmp	x2, x4
	ccmp	x3, x5, #0, eq
	cset	w0, eq
	b.eq	.LBB2_2
// %bb.1:
	stp	x2, x3, [x1]
.LBB2_2:
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
	ldaddal	x1, x8, [x0]
	add	x9, x0, #8
	ldaddal	x1, x1, [x9]
	mov	x0, x8
	ret
.Lfunc_end3:
	.size	pair_fetch_add, .Lfunc_end3-pair_fetch_add
	.cfi_endproc
                                        // -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
