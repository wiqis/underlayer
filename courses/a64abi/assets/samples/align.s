/* align.s -- SP-relative accesses, and the granularity each encoding admits.
 *
 * The AAPCS64 says "SP mod 16 = 0" (QUOTED, section 5.2.2.1 and 5.2.2.2).
 * This file is the attempt to find out WHY, measured at the level of what
 * the assembler will accept.  The answer turns out to be printed by the
 * assembler's own diagnostic: "index must be a multiple of 16 in range
 * [-1024, 1008]".
 *
 * The pairs that matter:
 *   - the 128-bit PAIR scales its offset by 16, so it can only say 16-byte
 *     granular addresses at all;
 *   - the 128-bit SINGLE load/store ALSO has a scaled form with the same
 *     granularity, and a SECOND, unscaled form (STUR) with a signed 9-bit
 *     BYTE offset, which is the only way to express a misaligned vector
 *     access.  Note which one the assembler picks for `str q0, [sp, #8]`.
 *
 * Nothing here is executed.  See section 1 of a64abi.out.
 */
	.text

/* --- the SIMD&FP pair: 16-byte granularity, imm7 signed x 16 --- */
	.globl	pair_q
pair_q:
	stp	q0, q1, [sp]
	stp	q0, q1, [sp, #16]
	ldp	q0, q1, [sp, #-16]
	stp	q0, q1, [sp, #1008]
	stp	q0, q1, [sp, #-1024]
	stp	q2, q3, [sp, #32]!
	ret
	.size	pair_q, .-pair_q

/* --- the 64-bit and 32-bit pairs: 8 and 4 --- */
	.globl	pair_dw
pair_dw:
	stp	d0, d1, [sp]
	stp	d0, d1, [sp, #8]
	stp	x0, x1, [sp, #8]
	stp	w0, w1, [sp, #4]
	ldp	x0, x1, [sp, #8]
	ldp	w0, w1, [sp, #4]
	ret
	.size	pair_dw, .-pair_dw

/* --- the 128-bit SINGLE: a scaled form at 16, and an unscaled form --- */
	.globl	single_q
single_q:
	str	q0, [sp]
	str	q0, [sp, #16]
	str	q0, [sp, #4080]
	ldr	q0, [sp, #16]
	str	q1, [x0, #32]
	ret
	.size	single_q, .-single_q

/* --- the unscaled forms: these are the ones that CAN be misaligned --- */
	.globl	unscaled
unscaled:
	stur	q0, [sp, #8]
	stur	q0, [x0, #4]
	stur	q0, [x0, #-8]
	ldur	q0, [x0, #4]
	stur	d0, [sp, #4]
	stur	s0, [sp, #2]
	stur	w0, [x0, #1]
	ret
	.size	unscaled, .-unscaled

/* --- the 8-byte scalar: a scaled form at 8 and an unscaled form at 1 --- */
	.globl	scalar
scalar:
	str	x0, [sp]
	str	x0, [sp, #8]
	stur	x0, [sp, #3]
	ldur	w0, [x0, #1]
	stur	h0, [x0, #1]
	stur	b0, [x0, #1]
	ret
	.size	scalar, .-scalar

/* --- a 16-byte-aligned local, the object whose alignment the rule exists
 * for.  The offset field of a `q` store is a multiple of 16, so if SP is
 * 16-aligned then [sp, #0] is too, and the compiler can use the SCALED
 * form.  If SP were only 8-aligned it would have to reach for STUR or for
 * a register, and this is the instruction it would have to give up. --- */
	.globl	aligned_local
aligned_local:
	sub	sp, sp, #32
	str	q0, [sp, #16]
	ldr	q1, [sp]
	str	d0, [sp, #8]
	add	sp, sp, #32
	ret
	.size	aligned_local, .-aligned_local

	/* The x86-64 counterpart of a64_leaf_frame16, for the alignment rule
	 * measured in the ENCODING rather than in a manual: x86 encodes
	 * alignment in the instruction (the SSE legacy prefix), and this
	 * assembler adds it silently.  -mno-sse does not exist; -mno-sse2
	 * downgrades the instruction.  We cannot run either, so the fact
	 * that this is the SAME requirement with a DIFFERENT mechanism is
	 * QUOTED and the mechanism is MEASURED from the bytes. */
	.section	.note.GNU-stack,"",%progbits
