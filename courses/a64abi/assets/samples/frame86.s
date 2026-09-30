/* frame86.s -- the SAME C as frame.s, compiled by the compiler for x86-64,
 * and the hand-written control functions for the red zone.
 *
 * This is a COMPILE-TIME comparison and nothing else.  There is no timing
 * in it, because there is no way to time an AArch64 instruction from this
 * host and the x86-64 half therefore has nothing to be compared WITH.  The
 * number that is real is the count of instructions, and the count is a
 * property of a COMPILER VERSION.
 */
	.text

/* ---- hand-written x86-64, in the red zone: %rsp is never touched ---- */
	.globl	x86_leaf_noframe
	.type	x86_leaf_noframe, %function
x86_leaf_noframe:
	imulq	%rsi, %rax
	addq	%rdi, %rax
	retq
	.size	x86_leaf_noframe, .-x86_leaf_noframe

	.globl	x86_leaf_frame
	.type	x86_leaf_frame, %function
x86_leaf_frame:
	movq	%rdi, -8(%rsp)
	movq	%rsi, -16(%rsp)
	movq	-8(%rsp), %rax
	addq	-16(%rsp), %rax
	movq	-8(%rsp), %rcx
	addq	-16(%rsp), %rcx
	addq	%rcx, %rax
	retq
	.size	x86_leaf_frame, .-x86_leaf_frame

	.globl	x86_nonleaf
	.type	x86_nonleaf, %function
x86_nonleaf:
	pushq	%rbp
	movq	%rdi, -8(%rsp)
	callq	x86_leaf_noframe
	addq	-8(%rsp), %rcx
	addq	%rcx, %rax
	popq	%rbp
	retq
	.size	x86_nonleaf, .-x86_nonleaf

	.globl	x86_pair_save
	.type	x86_pair_save, %function
x86_pair_save:
	pushq	%rbx
	pushq	%rbp
	movq	%rbx, -8(%rsp)
	movq	%rsp, %rbp
	addq	%rbx, -16(%rsp)
	movq	-16(%rsp), %rbx
	popq	%rbp
	popq	%rbx
	retq
	.size	x86_pair_save, .-x86_pair_save

	.globl	x86_leaf_16
	.type	x86_leaf_16, %function
	/* x86 has no SP-alignment rule below 16, so a leaf that wants a
	 * 16-byte object uses MOVAPS, which the hardware honours without a
	 * penalty on this class of machine.  The AArch64 counterpart of this
	 * function is a64_leaf_frame16 in frame.s. */
x86_leaf_16:
	movq	%rdi, -8(%rsp)
	movsd	%xmm0, -16(%rsp)
	movaps	-16(%rsp), %xmm1
	movsd	-16(%rsp), %xmm2
	addsd	%xmm1, %xmm2
	mulsd	%xmm1, %xmm0
	addsd	%xmm0, %xmm2
	movq	-8(%rsp), %rax
	retq
	.size	x86_leaf_16, .-x86_leaf_16
