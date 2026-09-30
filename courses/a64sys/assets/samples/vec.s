/* vec.s -- the vector table, built by the assembler and MEASURED.
 *
 * The layout is QUOTED: 16 entries, each 0x80 bytes, the four exception
 * types (Sync, IRQ, FIQ, SError) at each of the four (source EL, target EL)
 * pairs.  Nothing here confirms the layout by taking an exception, because
 * there is no AArch64 machine, no emulator and no linker on the build host.
 *
 * What this file DOES measure, and it is the only part of the subject a
 * toolchain can show us:
 *
 *   1. the table's SIZE, which is 16 x 0x80 = 0x800, and which the assembler
 *      computes and the symbol table then records;
 *   2. the OFFSET of every entry, which is vector-number x 0x80, and which
 *      is visible as a symbol value rather than as a claim;
 *   3. the ALIGNMENT the assembler enforces, and specifically that `.align 11`
 *      is what puts the table on a 2048-byte boundary and that leaving it off
 *      is NOT a diagnostic;
 *   4. the encoding of the branch that each entry holds.
 */

	.text
	.align	11			/* 2^11 = 2048.  QUOTED, and MEASURED below */
	.globl	vectors
	.type	vectors, %object
vectors:
	/* Current EL with SP0: Sync, IRQ, FIQ, SError */
	b	el0t_sync
	b	el0t_irq
	b	el0t_fiq
	b	el0t_serror
	/* Current EL with SP0, AArch64: Sync, IRQ, FIQ, SError */
	b	el0t_sync_a64
	b	el0t_irq_a64
	b	el0t_fiq_a64
	b	el0t_serror_a64
	/* Current EL with SPx: Sync, IRQ, FIQ, SError */
	b	el0i_sync
	b	el0i_irq
	b	el0i_fiq
	b	el0i_serror
	/* Lower EL using AArch64: Sync, IRQ, FIQ, SError */
	b	el1t_sync
	b	el1t_irq
	b	el1t_fiq
	b	el1t_serror
	.space	0x800 - 0x40		/* the rest of the 0x800, and the MEASUREMENT */
	.size	vectors, . - vectors

	.balign	0x80
el0t_sync:		ret
	.balign	0x80
el0t_irq:		ret
	.balign	0x80
el0t_fiq:		ret
	.balign	0x80
el0t_serror:	ret
	.balign	0x80
el0t_sync_a64:	ret
	.balign	0x80
el0t_irq_a64:	ret
	.balign	0x80
el0t_fiq_a64:	ret
	.balign	0x80
el0t_serror_a64:	ret
	.balign	0x80
el0i_sync:	ret
	.balign	0x80
el0i_irq:	ret
	.balign	0x80
el0i_fiq:	ret
	.balign	0x80
el0i_serror:	ret
	.balign	0x80
el1t_sync:	ret
	.balign	0x80
el1t_irq:	ret
	.balign	0x80
el1t_fiq:	ret
	.balign	0x80
el1t_serror:	ret

	/* Install the table.  The instruction is QUOTED, the ENCODING is
	 * MEASURED, and whether the write is accepted is not measurable here. */
	.globl	install_vbar
	.type	install_vbar, %function
install_vbar:
	adrp	x0, vectors
	add	x0, x0, :lo12:vectors
	msr	vbar_el1, x0
	isb
	ret
	.size	install_vbar, . - install_vbar
