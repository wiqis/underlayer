	.file	"data.c"
	.text
	.globl	sum_loop                        // -- Begin function sum_loop
	.p2align	2
	.type	sum_loop,@function
sum_loop:                               // @sum_loop
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	str	xzr, [sp, #8]
	str	xzr, [sp]
	b	.LBB0_1
.LBB0_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [sp]
	ldr	x9, [sp, #16]
	subs	x8, x8, x9
	b.ge	.LBB0_4
	b	.LBB0_2
.LBB0_2:                                //   in Loop: Header=BB0_1 Depth=1
	ldr	x8, [sp, #24]
	ldr	x9, [sp]
	ldr	x9, [x8, x9, lsl #3]
	ldr	x8, [sp, #8]
	add	x8, x8, x9
	str	x8, [sp, #8]
	b	.LBB0_3
.LBB0_3:                                //   in Loop: Header=BB0_1 Depth=1
	ldr	x8, [sp]
	add	x8, x8, #1
	str	x8, [sp]
	b	.LBB0_1
.LBB0_4:
	ldr	x0, [sp, #8]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	ldr	x8, [sp, #24]
	ldr	x8, [x8]
	str	x8, [sp, #8]
	mov	x8, #1                          // =0x1
	str	x8, [sp]
	b	.LBB1_1
.LBB1_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [sp]
	ldr	x9, [sp, #16]
	subs	x8, x8, x9
	b.ge	.LBB1_6
	b	.LBB1_2
.LBB1_2:                                //   in Loop: Header=BB1_1 Depth=1
	ldr	x8, [sp, #24]
	ldr	x9, [sp]
	ldr	x8, [x8, x9, lsl #3]
	ldr	x9, [sp, #8]
	subs	x8, x8, x9
	b.le	.LBB1_4
	b	.LBB1_3
.LBB1_3:                                //   in Loop: Header=BB1_1 Depth=1
	ldr	x8, [sp, #24]
	ldr	x9, [sp]
	ldr	x8, [x8, x9, lsl #3]
	str	x8, [sp, #8]
	b	.LBB1_4
.LBB1_4:                                //   in Loop: Header=BB1_1 Depth=1
	b	.LBB1_5
.LBB1_5:                                //   in Loop: Header=BB1_1 Depth=1
	ldr	x8, [sp]
	add	x8, x8, #1
	str	x8, [sp]
	b	.LBB1_1
.LBB1_6:
	ldr	x0, [sp, #8]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	str	x2, [sp, #8]
	str	xzr, [sp]
	b	.LBB2_1
.LBB2_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [sp]
	ldr	x9, [sp, #8]
	subs	x8, x8, x9
	b.ge	.LBB2_4
	b	.LBB2_2
.LBB2_2:                                //   in Loop: Header=BB2_1 Depth=1
	ldr	x8, [sp, #16]
	ldr	x9, [sp]
	ldr	x8, [x8, x9, lsl #3]
	mov	x9, #3                          // =0x3
	mul	x8, x8, x9
	add	x8, x8, #1
	ldr	x9, [sp, #24]
	ldr	x10, [sp]
	str	x8, [x9, x10, lsl #3]
	b	.LBB2_3
.LBB2_3:                                //   in Loop: Header=BB2_1 Depth=1
	ldr	x8, [sp]
	add	x8, x8, #1
	str	x8, [sp]
	b	.LBB2_1
.LBB2_4:
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	str	x2, [sp, #8]
	str	xzr, [sp]
	b	.LBB3_1
.LBB3_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [sp]
	ldr	x9, [sp, #8]
	subs	x8, x8, x9
	b.ge	.LBB3_4
	b	.LBB3_2
.LBB3_2:                                //   in Loop: Header=BB3_1 Depth=1
	ldr	x8, [sp, #16]
	ldr	x9, [sp]
	ldr	x8, [x8, x9, lsl #3]
	ldr	x9, [sp, #24]
	ldr	x10, [sp]
	str	x8, [x9, x10, lsl #3]
	b	.LBB3_3
.LBB3_3:                                //   in Loop: Header=BB3_1 Depth=1
	ldr	x8, [sp]
	add	x8, x8, #1
	str	x8, [sp]
	b	.LBB3_1
.LBB3_4:
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	movi	d0, #0000000000000000
	str	s0, [sp, #12]
	str	xzr, [sp]
	b	.LBB4_1
.LBB4_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [sp]
	ldr	x9, [sp, #16]
	subs	x8, x8, x9
	b.ge	.LBB4_4
	b	.LBB4_2
.LBB4_2:                                //   in Loop: Header=BB4_1 Depth=1
	ldr	x8, [sp, #24]
	ldr	x9, [sp]
	ldr	s1, [x8, x9, lsl #2]
	ldr	s0, [sp, #12]
	fadd	s0, s0, s1
	str	s0, [sp, #12]
	b	.LBB4_3
.LBB4_3:                                //   in Loop: Header=BB4_1 Depth=1
	ldr	x8, [sp]
	add	x8, x8, #1
	str	x8, [sp]
	b	.LBB4_1
.LBB4_4:
	ldr	s0, [sp, #12]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #48
	.cfi_def_cfa_offset 48
	str	x0, [sp, #40]
	str	x1, [sp, #32]
	str	x2, [sp, #24]
	str	x3, [sp, #16]
	str	xzr, [sp, #8]
	b	.LBB5_1
.LBB5_1:                                // =>This Inner Loop Header: Depth=1
	ldr	x8, [sp, #8]
	ldr	x9, [sp, #16]
	subs	x8, x8, x9
	b.ge	.LBB5_4
	b	.LBB5_2
.LBB5_2:                                //   in Loop: Header=BB5_1 Depth=1
	ldr	x8, [sp, #32]
	ldr	x9, [sp, #8]
	ldrb	w8, [x8, x9]
	ldr	x9, [sp, #24]
	ldr	x10, [sp, #8]
	ldrb	w9, [x9, x10]
	add	w8, w8, w9
	ldr	x9, [sp, #40]
	ldr	x10, [sp, #8]
	strb	w8, [x9, x10]
	b	.LBB5_3
.LBB5_3:                                //   in Loop: Header=BB5_1 Depth=1
	ldr	x8, [sp, #8]
	add	x8, x8, #1
	str	x8, [sp, #8]
	b	.LBB5_1
.LBB5_4:
	add	sp, sp, #48
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	str	x8, [sp, #16]                   // 8-byte Folded Spill
	mov	x9, #1                          // =0x1
	str	x9, [sp, #48]
	ldr	x9, [sp, #48]
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #32]                   // 8-byte Folded Spill
	b	.LBB6_1
.LBB6_1:                                // =>This Loop Header: Depth=1
                                        //     Child Loop BB6_2 Depth 2
	ldr	x8, [sp, #32]                   // 8-byte Folded Reload
	ldr	x11, [sp, #16]                  // 8-byte Folded Reload
	ldr	x9, [sp, #24]                   // 8-byte Folded Reload
	add	x12, x8, x9
.LBB6_2:                                //   Parent Loop BB6_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB6_4
// %bb.3:                               //   in Loop: Header=BB6_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB6_2
.LBB6_4:                                //   in Loop: Header=BB6_1 Depth=1
	str	x9, [sp, #8]                    // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #32]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB6_1
	b	.LBB6_5
.LBB6_5:
	ldr	x8, [sp, #8]                    // 8-byte Folded Reload
	str	x8, [sp, #40]
	ldr	x0, [sp, #40]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	str	x8, [sp, #16]                   // 8-byte Folded Spill
	mov	x9, #1                          // =0x1
	str	x9, [sp, #48]
	ldr	x9, [sp, #48]
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #32]                   // 8-byte Folded Spill
	b	.LBB7_1
.LBB7_1:                                // =>This Loop Header: Depth=1
                                        //     Child Loop BB7_2 Depth 2
	ldr	x8, [sp, #32]                   // 8-byte Folded Reload
	ldr	x11, [sp, #16]                  // 8-byte Folded Reload
	ldr	x9, [sp, #24]                   // 8-byte Folded Reload
	add	x12, x8, x9
.LBB7_2:                                //   Parent Loop BB7_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB7_4
// %bb.3:                               //   in Loop: Header=BB7_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB7_2
.LBB7_4:                                //   in Loop: Header=BB7_1 Depth=1
	str	x9, [sp, #8]                    // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #32]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB7_1
	b	.LBB7_5
.LBB7_5:
	ldr	x8, [sp, #8]                    // 8-byte Folded Reload
	str	x8, [sp, #40]
	ldr	x0, [sp, #40]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	str	x8, [sp, #16]                   // 8-byte Folded Spill
	mov	x9, #1                          // =0x1
	str	x9, [sp, #48]
	ldr	x9, [sp, #48]
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #32]                   // 8-byte Folded Spill
	b	.LBB8_1
.LBB8_1:                                // =>This Loop Header: Depth=1
                                        //     Child Loop BB8_2 Depth 2
	ldr	x8, [sp, #32]                   // 8-byte Folded Reload
	ldr	x11, [sp, #16]                  // 8-byte Folded Reload
	ldr	x9, [sp, #24]                   // 8-byte Folded Reload
	add	x12, x8, x9
.LBB8_2:                                //   Parent Loop BB8_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB8_4
// %bb.3:                               //   in Loop: Header=BB8_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB8_2
.LBB8_4:                                //   in Loop: Header=BB8_1 Depth=1
	str	x9, [sp, #8]                    // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #32]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB8_1
	b	.LBB8_5
.LBB8_5:
	ldr	x8, [sp, #8]                    // 8-byte Folded Reload
	str	x8, [sp, #40]
	ldr	x0, [sp, #40]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	str	x8, [sp, #16]                   // 8-byte Folded Spill
	mov	x9, #1                          // =0x1
	str	x9, [sp, #48]
	ldr	x9, [sp, #48]
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #32]                   // 8-byte Folded Spill
	b	.LBB9_1
.LBB9_1:                                // =>This Loop Header: Depth=1
                                        //     Child Loop BB9_2 Depth 2
	ldr	x8, [sp, #32]                   // 8-byte Folded Reload
	ldr	x11, [sp, #16]                  // 8-byte Folded Reload
	ldr	x9, [sp, #24]                   // 8-byte Folded Reload
	add	x12, x8, x9
.LBB9_2:                                //   Parent Loop BB9_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB9_4
// %bb.3:                               //   in Loop: Header=BB9_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB9_2
.LBB9_4:                                //   in Loop: Header=BB9_1 Depth=1
	str	x9, [sp, #8]                    // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #32]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB9_1
	b	.LBB9_5
.LBB9_5:
	ldr	x8, [sp, #8]                    // 8-byte Folded Reload
	str	x8, [sp, #40]
	ldr	x0, [sp, #40]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	str	x1, [sp, #48]
	ldr	x8, [sp, #56]
	str	x8, [sp, #8]                    // 8-byte Folded Spill
	ldr	x9, [sp, #48]
	str	x9, [sp, #40]
	ldr	x9, [sp, #40]
	str	x9, [sp, #16]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #24]                   // 8-byte Folded Spill
	b	.LBB10_1
.LBB10_1:                               // =>This Loop Header: Depth=1
                                        //     Child Loop BB10_2 Depth 2
	ldr	x8, [sp, #24]                   // 8-byte Folded Reload
	ldr	x11, [sp, #8]                   // 8-byte Folded Reload
	ldr	x12, [sp, #16]                  // 8-byte Folded Reload
.LBB10_2:                               //   Parent Loop BB10_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB10_4
// %bb.3:                               //   in Loop: Header=BB10_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB10_2
.LBB10_4:                               //   in Loop: Header=BB10_1 Depth=1
	str	x9, [sp]                        // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB10_1
	b	.LBB10_5
.LBB10_5:
	ldr	x8, [sp]                        // 8-byte Folded Reload
	str	x8, [sp, #32]
	ldr	x0, [sp, #32]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	str	x1, [sp, #48]
	ldr	x8, [sp, #56]
	str	x8, [sp, #8]                    // 8-byte Folded Spill
	ldr	x9, [sp, #48]
	str	x9, [sp, #40]
	ldr	x9, [sp, #40]
	str	x9, [sp, #16]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #24]                   // 8-byte Folded Spill
	b	.LBB11_1
.LBB11_1:                               // =>This Loop Header: Depth=1
                                        //     Child Loop BB11_2 Depth 2
	ldr	x8, [sp, #24]                   // 8-byte Folded Reload
	ldr	x11, [sp, #8]                   // 8-byte Folded Reload
	ldr	x12, [sp, #16]                  // 8-byte Folded Reload
.LBB11_2:                               //   Parent Loop BB11_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB11_4
// %bb.3:                               //   in Loop: Header=BB11_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB11_2
.LBB11_4:                               //   in Loop: Header=BB11_1 Depth=1
	str	x9, [sp]                        // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB11_1
	b	.LBB11_5
.LBB11_5:
	ldr	x8, [sp]                        // 8-byte Folded Reload
	str	x8, [sp, #32]
	ldr	x0, [sp, #32]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	str	x1, [sp, #48]
	str	x2, [sp, #40]
	ldr	x11, [sp, #56]
	ldr	x8, [sp, #48]
	str	x8, [sp, #8]                    // 8-byte Folded Spill
	ldr	x9, [sp, #40]
	str	x9, [sp, #32]
	ldr	x9, [x8]
	ldr	x12, [sp, #32]
.LBB12_1:                               // =>This Inner Loop Header: Depth=1
	ldaxr	x8, [x11]
	cmp	x8, x9
	b.ne	.LBB12_3
// %bb.2:                               //   in Loop: Header=BB12_1 Depth=1
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB12_1
.LBB12_3:
	str	x8, [sp, #16]                   // 8-byte Folded Spill
	subs	x10, x8, x9
	cset	w10, eq
	str	w10, [sp, #24]                  // 4-byte Folded Spill
	subs	x8, x8, x9
	b.eq	.LBB12_5
	b	.LBB12_4
.LBB12_4:
	ldr	x8, [sp, #16]                   // 8-byte Folded Reload
	ldr	x9, [sp, #8]                    // 8-byte Folded Reload
	str	x8, [x9]
	b	.LBB12_5
.LBB12_5:
	ldr	w8, [sp, #24]                   // 4-byte Folded Reload
	strb	w8, [sp, #31]
	ldrb	w8, [sp, #31]
	and	w0, w8, #0x1
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	ldar	x8, [x8]
	str	x8, [sp]
	ldr	x0, [sp]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	ldar	x8, [x8]
	str	x8, [sp]
	ldr	x0, [sp]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	ldr	x9, [sp, #24]
	ldr	x8, [sp, #16]
	str	x8, [sp, #8]
	ldr	x8, [sp, #8]
	stlr	x8, [x9]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	ldr	x9, [sp, #24]
	ldr	x8, [sp, #16]
	str	x8, [sp, #8]
	ldr	x8, [sp, #8]
	stlr	x8, [x9]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #48
	.cfi_def_cfa_offset 48
	str	x0, [sp, #40]
	str	x1, [sp, #32]
	ldr	x8, [sp, #40]
	ldar	x8, [x8]
	str	x8, [sp, #16]
	ldr	x8, [sp, #16]
	str	x8, [sp, #24]
	ldr	x8, [sp, #32]
	ldar	x8, [x8]
	str	x8, [sp]
	ldr	x8, [sp]
	str	x8, [sp, #8]
	ldr	x8, [sp, #24]
	ldr	x9, [sp, #8]
	add	x0, x8, x9
	add	sp, sp, #48
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #48
	.cfi_def_cfa_offset 48
	str	x0, [sp, #40]
	str	x1, [sp, #32]
	str	x2, [sp, #24]
	str	x3, [sp, #16]
	ldr	x9, [sp, #40]
	ldr	x8, [sp, #24]
	str	x8, [sp, #8]
	ldr	x8, [sp, #8]
	stlr	x8, [x9]
	ldr	x9, [sp, #32]
	ldr	x8, [sp, #16]
	str	x8, [sp]
	ldr	x8, [sp]
	stlr	x8, [x9]
	add	sp, sp, #48
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	str	x8, [sp, #16]                   // 8-byte Folded Spill
	mov	x9, #1                          // =0x1
	str	x9, [sp, #48]
	ldr	x9, [sp, #48]
	str	x9, [sp, #24]                   // 8-byte Folded Spill
	ldr	x8, [x8]
	str	x8, [sp, #32]                   // 8-byte Folded Spill
	b	.LBB23_1
.LBB23_1:                               // =>This Loop Header: Depth=1
                                        //     Child Loop BB23_2 Depth 2
	ldr	x8, [sp, #32]                   // 8-byte Folded Reload
	ldr	x11, [sp, #16]                  // 8-byte Folded Reload
	ldr	x9, [sp, #24]                   // 8-byte Folded Reload
	add	x12, x8, x9
.LBB23_2:                               //   Parent Loop BB23_1 Depth=1
                                        // =>  This Inner Loop Header: Depth=2
	ldaxr	x9, [x11]
	cmp	x9, x8
	b.ne	.LBB23_4
// %bb.3:                               //   in Loop: Header=BB23_2 Depth=2
	stlxr	w10, x12, [x11]
	cbnz	w10, .LBB23_2
.LBB23_4:                               //   in Loop: Header=BB23_1 Depth=1
	str	x9, [sp, #8]                    // 8-byte Folded Spill
	subs	x8, x9, x8
	cset	w8, eq
	str	x9, [sp, #32]                   // 8-byte Folded Spill
	tbz	w8, #0, .LBB23_1
	b	.LBB23_5
.LBB23_5:
	ldr	x8, [sp, #8]                    // 8-byte Folded Reload
	str	x8, [sp, #40]
	ldr	x0, [sp, #40]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
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
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	str	x1, [sp, #16]
	ldr	x8, [sp, #16]
	ldr	x9, [sp, #24]
	str	x8, [x9, #8]
	ldr	x9, [sp, #24]
	mov	x8, #1                          // =0x1
	str	x8, [sp, #8]
	ldr	x8, [sp, #8]
	stlr	x8, [x9]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end24:
	.size	publish, .Lfunc_end24-publish
	.cfi_endproc
                                        // -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
