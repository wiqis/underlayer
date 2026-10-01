	.file	"leaf.c"
	.text
	.globl	leaf                            # -- Begin function leaf
	.p2align	4
	.type	leaf,@function
leaf:                                   # @leaf
	.cfi_startproc
# %bb.0:
	leaq	(%rdi,%rsi,2), %rax
	leaq	(%rdx,%rdx,2), %rdx
	addq	%rax, %rdx
	leaq	(%rdx,%rcx,4), %rax
	leaq	(%r8,%r8,4), %rcx
	addq	%rax, %rcx
	leaq	(%r9,%r9,2), %rax
	leaq	(%rcx,%rax,2), %rax
	retq
.Lfunc_end0:
	.size	leaf, .Lfunc_end0-leaf
	.cfi_endproc
                                        # -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
