	.file	"data.c"
	.text
	.globl	sum_loop                        // -- Begin function sum_loop
	.p2align	2
	.type	sum_loop,@function
sum_loop:                               // @sum_loop
	.cfi_startproc
// %bb.0:
	cmp	x1, #1
	b.lt	.LBB0_3
// %bb.1:
	mov	x8, xzr
.LBB0_2:                                // =>This Inner Loop Header: Depth=1
	ldr	x9, [x0], #8
	subs	x1, x1, #1
	add	x8, x9, x8
	b.ne	.LBB0_2
	b	.LBB0_4
.LBB0_3:
	mov	x8, xzr
.LBB0_4:
	mov	x0, x8
	ret
.Lfunc_end0:
	.size	sum_loop, .Lfunc_end0-sum_loop
	.cfi_endproc
                                        // -- End function
	.globl	max_loop                        // -- Begin function max_loop
	.p2align	2
	.type	max_loop,@function
max_loop:                               // @max_loop
	.cfi_startproc
// %bb.0:
	mov	x8, x0
	ldr	x0, [x0]
	cmp	x1, #2
	b.lt	.LBB1_3
// %bb.1:
	sub	x9, x1, #1
	add	x8, x8, #8
.LBB1_2:                                // =>This Inner Loop Header: Depth=1
	ldr	x10, [x8], #8
	cmp	x10, x0
	csel	x0, x10, x0, gt
	subs	x9, x9, #1
	b.ne	.LBB1_2
.LBB1_3:
	ret
.Lfunc_end1:
	.size	max_loop, .Lfunc_end1-max_loop
	.cfi_endproc
                                        // -- End function
	.globl	axpy_loop                       // -- Begin function axpy_loop
	.p2align	2
	.type	axpy_loop,@function
axpy_loop:                              // @axpy_loop
	.cfi_startproc
// %bb.0:
	cmp	x2, #1
	b.lt	.LBB2_2
.LBB2_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [x1], #8
	subs	x2, x2, #1
	add	x8, x8, x8, lsl #1
	add	x8, x8, #1
	str	x8, [x0], #8
	b.ne	.LBB2_1
.LBB2_2:
	ret
.Lfunc_end2:
	.size	axpy_loop, .Lfunc_end2-axpy_loop
	.cfi_endproc
                                        // -- End function
	.globl	copy_loop                       // -- Begin function copy_loop
	.p2align	2
	.type	copy_loop,@function
copy_loop:                              // @copy_loop
	.cfi_startproc
// %bb.0:
	cmp	x2, #1
	b.lt	.LBB3_2
.LBB3_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [x1], #8
	subs	x2, x2, #1
	str	x8, [x0], #8
	b.ne	.LBB3_1
.LBB3_2:
	ret
.Lfunc_end3:
	.size	copy_loop, .Lfunc_end3-copy_loop
	.cfi_endproc
                                        // -- End function
	.globl	fsum_loop                       // -- Begin function fsum_loop
	.p2align	2
	.type	fsum_loop,@function
fsum_loop:                              // @fsum_loop
	.cfi_startproc
// %bb.0:
	movi	d0, #0000000000000000
	cmp	x1, #1
	b.lt	.LBB4_2
.LBB4_1:                                // =>This Inner Loop Header: Depth=1
	ldr	s1, [x0], #4
	subs	x1, x1, #1
	fadd	s0, s0, s1
	b.ne	.LBB4_1
.LBB4_2:
	ret
.Lfunc_end4:
	.size	fsum_loop, .Lfunc_end4-fsum_loop
	.cfi_endproc
                                        // -- End function
	.globl	sadd                            // -- Begin function sadd
	.p2align	2
	.type	sadd,@function
sadd:                                   // @sadd
	.cfi_startproc
// %bb.0:
	cmp	x3, #1
	b.lt	.LBB5_2
.LBB5_1:                                // =>This Inner Loop Header: Depth=1
	ldrb	w8, [x1], #1
	subs	x3, x3, #1
	ldrb	w9, [x2], #1
	add	w8, w9, w8
	strb	w8, [x0], #1
	b.ne	.LBB5_1
.LBB5_2:
	ret
.Lfunc_end5:
	.size	sadd, .Lfunc_end5-sadd
	.cfi_endproc
                                        // -- End function
	.globl	inc_seq                         // -- Begin function inc_seq
	.p2align	2
	.type	inc_seq,@function
inc_seq:                                // @inc_seq
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB6_1:                                // =>This Inner Loop Header: Depth=1
	ldaxr	x0, [x8]
	add	x9, x0, #1
	stlxr	w10, x9, [x8]
	cbnz	w10, .LBB6_1
// %bb.2:
	ret
.Lfunc_end6:
	.size	inc_seq, .Lfunc_end6-inc_seq
	.cfi_endproc
                                        // -- End function
	.globl	inc_acq                         // -- Begin function inc_acq
	.p2align	2
	.type	inc_acq,@function
inc_acq:                                // @inc_acq
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB7_1:                                // =>This Inner Loop Header: Depth=1
	ldaxr	x0, [x8]
	add	x9, x0, #1
	stxr	w10, x9, [x8]
	cbnz	w10, .LBB7_1
// %bb.2:
	ret
.Lfunc_end7:
	.size	inc_acq, .Lfunc_end7-inc_acq
	.cfi_endproc
                                        // -- End function
	.globl	inc_rel                         // -- Begin function inc_rel
	.p2align	2
	.type	inc_rel,@function
inc_rel:                                // @inc_rel
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB8_1:                                // =>This Inner Loop Header: Depth=1
	ldxr	x0, [x8]
	add	x9, x0, #1
	stlxr	w10, x9, [x8]
	cbnz	w10, .LBB8_1
// %bb.2:
	ret
.Lfunc_end8:
	.size	inc_rel, .Lfunc_end8-inc_rel
	.cfi_endproc
                                        // -- End function
	.globl	inc_relaxed                     // -- Begin function inc_relaxed
	.p2align	2
	.type	inc_relaxed,@function
inc_relaxed:                            // @inc_relaxed
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB9_1:                                // =>This Inner Loop Header: Depth=1
	ldxr	x0, [x8]
	add	x9, x0, #1
	stxr	w10, x9, [x8]
	cbnz	w10, .LBB9_1
// %bb.2:
	ret
.Lfunc_end9:
	.size	inc_relaxed, .Lfunc_end9-inc_relaxed
	.cfi_endproc
                                        // -- End function
	.globl	xchg_seq                        // -- Begin function xchg_seq
	.p2align	2
	.type	xchg_seq,@function
xchg_seq:                               // @xchg_seq
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB10_1:                               // =>This Inner Loop Header: Depth=1
	ldaxr	x0, [x8]
	stlxr	w9, x1, [x8]
	cbnz	w9, .LBB10_1
// %bb.2:
	ret
.Lfunc_end10:
	.size	xchg_seq, .Lfunc_end10-xchg_seq
	.cfi_endproc
                                        // -- End function
	.globl	xchg_acqrel                     // -- Begin function xchg_acqrel
	.p2align	2
	.type	xchg_acqrel,@function
xchg_acqrel:                            // @xchg_acqrel
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB11_1:                               // =>This Inner Loop Header: Depth=1
	ldaxr	x0, [x8]
	stlxr	w9, x1, [x8]
	cbnz	w9, .LBB11_1
// %bb.2:
	ret
.Lfunc_end11:
	.size	xchg_acqrel, .Lfunc_end11-xchg_acqrel
	.cfi_endproc
                                        // -- End function
	.globl	cas64                           // -- Begin function cas64
	.p2align	2
	.type	cas64,@function
cas64:                                  // @cas64
	.cfi_startproc
// %bb.0:
	ldr	x9, [x1]
.LBB12_1:                               // =>This Inner Loop Header: Depth=1
	ldaxr	x8, [x0]
	cmp	x8, x9
	b.ne	.LBB12_4
// %bb.2:                               //   in Loop: Header=BB12_1 Depth=1
	stlxr	w10, x2, [x0]
	cbnz	w10, .LBB12_1
// %bb.3:
	mov	w0, #1                          // =0x1
	tbz	w0, #0, .LBB12_5
	b	.LBB12_6
.LBB12_4:
	mov	w0, wzr
	clrex
	tbnz	w0, #0, .LBB12_6
.LBB12_5:
	str	x8, [x1]
.LBB12_6:
	ret
.Lfunc_end12:
	.size	cas64, .Lfunc_end12-cas64
	.cfi_endproc
                                        // -- End function
	.globl	load_acq                        // -- Begin function load_acq
	.p2align	2
	.type	load_acq,@function
load_acq:                               // @load_acq
	.cfi_startproc
// %bb.0:
	ldar	x0, [x0]
	ret
.Lfunc_end13:
	.size	load_acq, .Lfunc_end13-load_acq
	.cfi_endproc
                                        // -- End function
	.globl	load_seqcst                     // -- Begin function load_seqcst
	.p2align	2
	.type	load_seqcst,@function
load_seqcst:                            // @load_seqcst
	.cfi_startproc
// %bb.0:
	ldar	x0, [x0]
	ret
.Lfunc_end14:
	.size	load_seqcst, .Lfunc_end14-load_seqcst
	.cfi_endproc
                                        // -- End function
	.globl	store_rel                       // -- Begin function store_rel
	.p2align	2
	.type	store_rel,@function
store_rel:                              // @store_rel
	.cfi_startproc
// %bb.0:
	stlr	x1, [x0]
	ret
.Lfunc_end15:
	.size	store_rel, .Lfunc_end15-store_rel
	.cfi_endproc
                                        // -- End function
	.globl	store_seqcst                    // -- Begin function store_seqcst
	.p2align	2
	.type	store_seqcst,@function
store_seqcst:                           // @store_seqcst
	.cfi_startproc
// %bb.0:
	stlr	x1, [x0]
	ret
.Lfunc_end16:
	.size	store_seqcst, .Lfunc_end16-store_seqcst
	.cfi_endproc
                                        // -- End function
	.globl	fence_seqcst                    // -- Begin function fence_seqcst
	.p2align	2
	.type	fence_seqcst,@function
fence_seqcst:                           // @fence_seqcst
	.cfi_startproc
// %bb.0:
	dmb	ish
	ret
.Lfunc_end17:
	.size	fence_seqcst, .Lfunc_end17-fence_seqcst
	.cfi_endproc
                                        // -- End function
	.globl	fence_acquire                   // -- Begin function fence_acquire
	.p2align	2
	.type	fence_acquire,@function
fence_acquire:                          // @fence_acquire
	.cfi_startproc
// %bb.0:
	dmb	ishld
	ret
.Lfunc_end18:
	.size	fence_acquire, .Lfunc_end18-fence_acquire
	.cfi_endproc
                                        // -- End function
	.globl	fence_release                   // -- Begin function fence_release
	.p2align	2
	.type	fence_release,@function
fence_release:                          // @fence_release
	.cfi_startproc
// %bb.0:
	dmb	ish
	ret
.Lfunc_end19:
	.size	fence_release, .Lfunc_end19-fence_release
	.cfi_endproc
                                        // -- End function
	.globl	fence_relaxed                   // -- Begin function fence_relaxed
	.p2align	2
	.type	fence_relaxed,@function
fence_relaxed:                          // @fence_relaxed
	.cfi_startproc
// %bb.0:
	ret
.Lfunc_end20:
	.size	fence_relaxed, .Lfunc_end20-fence_relaxed
	.cfi_endproc
                                        // -- End function
	.globl	load_then_load                  // -- Begin function load_then_load
	.p2align	2
	.type	load_then_load,@function
load_then_load:                         // @load_then_load
	.cfi_startproc
// %bb.0:
	ldar	x8, [x0]
	ldar	x9, [x1]
	add	x0, x9, x8
	ret
.Lfunc_end21:
	.size	load_then_load, .Lfunc_end21-load_then_load
	.cfi_endproc
                                        // -- End function
	.globl	store_then_store                // -- Begin function store_then_store
	.p2align	2
	.type	store_then_store,@function
store_then_store:                       // @store_then_store
	.cfi_startproc
// %bb.0:
	stlr	x2, [x0]
	stlr	x3, [x1]
	ret
.Lfunc_end22:
	.size	store_then_store, .Lfunc_end22-store_then_store
	.cfi_endproc
                                        // -- End function
	.globl	bump                            // -- Begin function bump
	.p2align	2
	.type	bump,@function
bump:                                   // @bump
	.cfi_startproc
// %bb.0:
	mov	x8, x0
.LBB23_1:                               // =>This Inner Loop Header: Depth=1
	ldaxr	x0, [x8]
	add	x9, x0, #1
	stlxr	w10, x9, [x8]
	cbnz	w10, .LBB23_1
// %bb.2:
	ret
.Lfunc_end23:
	.size	bump, .Lfunc_end23-bump
	.cfi_endproc
                                        // -- End function
	.globl	publish                         // -- Begin function publish
	.p2align	2
	.type	publish,@function
publish:                                // @publish
	.cfi_startproc
// %bb.0:
	mov	w8, #1                          // =0x1
	str	x1, [x0, #8]
	stlr	x8, [x0]
	ret
.Lfunc_end24:
	.size	publish, .Lfunc_end24-publish
	.cfi_endproc
                                        // -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
