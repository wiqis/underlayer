/* regs.s -- the register file as a PARTITIONED NAMESPACE, written by hand so
 * that the two questions have controlled specimens:
 *
 *   1. are x0 and w0 the same register?  Six pairs, and the answer is
 *      visible as a one-bit XOR.
 *   2. what does register number 31 mean?  It is SP in a load/store base
 *      and in ADD/SUB, it is the ZERO register in a compare-and-branch, and
 *      the SAME 5-bit field is used for all of them.
 *
 * Nothing here is executed.  See section 1 of a64abi.out.
 */
	.text

/* --- part 1: six pairs, w against x, same operand, one bit apart --- */
	.globl	w_x_pairs
w_x_pairs:
	mov	w0, #1
	mov	x0, #1
	add	w0, w0, #1
	add	x0, x0, #1
	sub	w0, w0, w1
	sub	x0, x0, x1
	mov	w0, w1
	mov	x0, x1
	mov	w0, #-1
	mov	x0, #-1
	mov	w0, wzr
	mov	x0, xzr
	ret
	.size	w_x_pairs, .-w_x_pairs

/* --- part 2: the two "move a constant into a register" encodings ---
 * `mov x0, sp` and `mov x0, xzr` LOOK like the same instruction and are not:
 * the first is ADD (immediate) and the second is ORR (shifted register), and
 * the difference is which of the two meanings the encoding gives register 31
 * in the Rn slot. */
	.globl	reg31_means
reg31_means:
	mov	x0, sp
	mov	x0, xzr
	mov	w0, wsp
	mov	w0, wzr
	add	sp, sp, #16
	sub	sp, sp, #16
	add	x0, sp, #0
	add	x0, xzr, x1
	cmp	x0, #0
	cmp	w0, #0
	cbz	w31, reg31_done
	cbz	x31, reg31_done
	cbz	w30, reg31_done
	cbz	x30, reg31_done
	ret
reg31_done:
	ret
	.size	reg31_means, .-reg31_means

/* --- part 3: the three load/store base forms, and what the assembler
 * refuses.  The refusal is the measurement: there is a base slot in which
 * register 31 CANNOT be named as a general register, and the assembler will
 * not let you try. */
	.globl	loadstore_bases
loadstore_bases:
	str	w0, [sp, #12]
	ldr	w0, [sp, #12]
	str	x0, [x1, #12]
	ldr	x0, [x1, #12]
	str	x0, [x2], #8
	ret
	.size	loadstore_bases, .-loadstore_bases

/* --- part 4: the instruction that would read the alignment check bit.
 * SCTLR_ELx.A is the control that decides whether an unaligned access to
 * memory via SP is a fault or not.  We can MEASURE the encoding of the
 * instruction that reads that bit.  We cannot measure the fault. */
	.globl	read_sctlr
read_sctlr:
	mrs	x0, sctlr_el1
	msr	sctlr_el1, x0
	ret
	.size	read_sctlr, .-read_sctlr
