	.attribute	4, 16
	.attribute	5, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_b1p0_v1p0_zic64b1p0_zicbom1p0_zicbop1p0_zicboz1p0_ziccamoa1p0_ziccif1p0_zicclsm1p0_ziccrse1p0_zicntr2p0_zicond1p0_zicsr2p0_zifencei2p0_zihintntl1p0_zihintpause2p0_zihpm2p0_zimop1p0_zmmul1p0_za64rs1p0_zaamo1p0_zalrsc1p0_zawrs1p0_zfa1p0_zfhmin1p0_zca1p0_zcb1p0_zcd1p0_zcmop1p0_zba1p0_zbb1p0_zbs1p0_zkt1p0_zvbb1p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvfhmin1p0_zvkb1p0_zvkt1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0_supm1p0"
	.file	"leaf.c"
	.text
	.globl	leaf                            # -- Begin function leaf
	.p2align	1
	.type	leaf,@function
leaf:                                   # @leaf
	.cfi_startproc
# %bb.0:
	sh1add	a0, a1, a0
	sh1add	a1, a2, a2
	sh2add	a2, a4, a4
	add	a0, a0, a1
	sh2add	a0, a3, a0
	add	a0, a0, a2
	sh1add	a1, a5, a5
	sh1add	a0, a1, a0
	ret
.Lfunc_end0:
	.size	leaf, .Lfunc_end0-leaf
	.cfi_endproc
                                        # -- End function
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
