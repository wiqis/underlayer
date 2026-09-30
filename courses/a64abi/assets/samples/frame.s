/* frame.s -- the frame shapes, written by hand so that the two
 * architectures are handed THE SAME C and the difference in the output is
 * the ABI's rather than the compiler's mood.
 *
 * The lesson of this file is the red zone.  AArch64 has none: a leaf that
 * needs memory has to move the stack pointer down and then move it back, and
 * the move back has to coexist with `ldr x0, [sp], #16` in one instruction.
 * x86-64 leaf functions write at 8(%rsp) .. 128(%rsp) and never touch %rsp
 * at all.
 *
 * NOTHING HERE IS EXECUTED.  There is no AArch64 machine on this host and no
 * emulator; see section 1 of a64abi.out.
 */
	.text

/* ---- AArch64 ---- */
	.globl	a64_leaf_noframe
	.type	a64_leaf_noframe, %function
a64_leaf_noframe:
	mul	x8, x1, x0
	madd	x0, x0, x8, x8
	ret
	.size	a64_leaf_noframe, .-a64_leaf_noframe

	.globl	a64_leaf_frame
	.type	a64_leaf_frame, %function
a64_leaf_frame:
	sub	sp, sp, #16
	str	x0, [sp, #8]
	str	x1, [sp]
	ldr	x8, [sp, #8]
	ldr	x9, [sp]
	add	x8, x8, x9
	ldr	x0, [sp, #8]
	ldr	x9, [sp]
	add	x0, x8, x9
	add	sp, sp, #16
	ret
	.size	a64_leaf_frame, .-a64_leaf_frame

	.globl	a64_nonleaf
	.type	a64_nonleaf, %function
a64_nonleaf:
	stp	x29, x30, [sp, #-16]!
	str	x0, [sp, #8]
	bl	a64_leaf_noframe
	ldr	x8, [sp, #8]
	add	x0, x0, x8
	ldp	x29, x30, [sp], #16
	ret
	.size	a64_nonleaf, .-a64_nonleaf

	/* A tail call: no frame at all, and the callee inherits SP unchanged. */
	.globl	a64_tail
	.type	a64_tail, %function
a64_tail:
	b	a64_leaf_noframe
	.size	a64_tail, .-a64_tail

	/* Two pairs of callee-saved registers, in one pre-indexed STP each, so
	 * the allocation and the save are the SAME instruction. */
	.globl	a64_pair_save
	.type	a64_pair_save, %function
a64_pair_save:
	stp	x19, x20, [sp, #-16]!
	stp	x29, x30, [sp, #-16]!
	add	x0, x19, x20
	ldp	x29, x30, [sp], #16
	ldp	x19, x20, [sp], #16
	ret
	.size	a64_pair_save, .-a64_pair_save

	/* The writeback epilogue: the load and the deallocation are one
	 * instruction, which is the AArch64 answer to x86's `leave`. */
	.globl	a64_writeback
	.type	a64_writeback, %function
a64_writeback:
	str	x0, [sp, #-16]!
	ldr	x0, [sp, #8]
	ldr	x0, [sp], #16
	ret
	.size	a64_writeback, .-a64_writeback
