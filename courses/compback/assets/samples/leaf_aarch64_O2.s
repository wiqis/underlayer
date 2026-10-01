	.file	"leaf.c"
	.text
	.globl	leaf                            // -- Begin function leaf
	.p2align	2
	.type	leaf,@function
leaf:                                   // @leaf
	.cfi_startproc
// %bb.0:
	add	x8, x0, x1, lsl #1
	add	x9, x2, x2, lsl #1
	mov	w10, #6                         // =0x6
	add	x8, x8, x9
	add	x9, x4, x4, lsl #2
	add	x8, x8, x3, lsl #2
	add	x8, x8, x9
	madd	x0, x5, x10, x8
	ret
.Lfunc_end0:
	.size	leaf, .Lfunc_end0-leaf
	.cfi_endproc
                                        // -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
