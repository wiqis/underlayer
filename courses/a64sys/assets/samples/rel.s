/* rel.s -- the page-table reference corpus, and the RELOCATION census.
 *
 * This is the part of page tables that a toolchain can show, and it is the
 * hinge between this course and the ELF and relocation courses.  A page
 * table is an ordinary array of 64-bit words as far as a compiler is
 * concerned, and the ONLY thing that makes it a page table is:
 *
 *   a. its ALIGNMENT, which is a property of its ROLE and not of its type,
 *      and which the object file has to record or a linker cannot honour it;
 *   b. the fact that its ADDRESS has to be a physical address, and no
 *      relocation in the ELF format can say "put this at physical 0x...".
 *
 * Both of those are measurable from an object file, and neither of them is
 * about the page-walk hardware, which is the part that is QUOTED.
 */

	.text
	.balign	4096
	.globl	l0
	.type	l0, %function
l0:	.space	4096
	.balign	4096
	.globl	l1
	.type	l1, %function
l1:	.space	4096
	.balign	0x200000
	.globl	l2
	.type	l2, %function
l2:	.space	4096
	.balign	8
	.globl	odd
	.type	odd, %function
odd:	.space	64

/* The five ways code names an address, and each one is a different
 * relocation or a different PAIR of them. */
	.globl	ref_pair
	.type	ref_pair, %function
ref_pair:
	adrp	x0, l0
	add	x0, x0, :lo12:l0
	ret
	.size	ref_pair, . - ref_pair

	.globl	ref_adr
	.type	ref_adr, %function
ref_adr:
	adr	x0, odd
	ret
	.size	ref_adr, . - ref_adr

	.globl	ref_load
	.type	ref_load, %function
ref_load:
	adrp	x1, l1
	ldr	x2, [x1, :lo12:l1]
	ret
	.size	ref_load, . - ref_load

	.globl	ref_store
	.type	ref_store, %function
ref_store:
	adrp	x3, l2
	str	x4, [x3, :lo12:l2]
	ret
	.size	ref_store, . - ref_store

	.globl	ref_load_uimm
	.type	ref_load_uimm, %function
ref_load_uimm:
	adrp	x5, l2
	ldr	x6, [x5, #0]
	ret
	.size	ref_load_uimm, . - ref_load_uimm

	.globl	ref_svc
	.type	ref_svc, %function
ref_svc:
	mov	x8, #64
	mov	x0, #1
	svc	#0
	ret
	.size	ref_svc, . - ref_svc
