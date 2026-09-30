	.file	"sys.c"
	.text
	.globl	sys_const                       // -- Begin function sys_const
	.p2align	2
	.type	sys_const,@function
sys_const:                              // @sys_const
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	mov	x8, #64                         // =0x40
	str	x8, [sp, #24]
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #16]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #8]
	ldr	x0, [sp, #16]
	ldr	x8, [sp, #24]
	ldr	x1, [sp, #8]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #16]
	ldr	x8, [sp, #16]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #16]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end0:
	.size	sys_const, .Lfunc_end0-sys_const
	.cfi_endproc
                                        // -- End function
	.globl	sys_global                      // -- Begin function sys_global
	.p2align	2
	.type	sys_global,@function
sys_global:                             // @sys_global
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	adrp	x8, VN
	ldr	x8, [x8, :lo12:VN]
	str	x8, [sp, #24]
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #16]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #8]
	ldr	x0, [sp, #16]
	ldr	x8, [sp, #24]
	ldr	x1, [sp, #8]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #16]
	ldr	x8, [sp, #16]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #16]
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end1:
	.size	sys_global, .Lfunc_end1-sys_global
	.cfi_endproc
                                        // -- End function
	.globl	sys_no_number                   // -- Begin function sys_no_number
	.p2align	2
	.type	sys_no_number,@function
sys_no_number:                          // @sys_no_number
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #8]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp]
	ldr	x0, [sp, #8]
	ldr	x1, [sp]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end2:
	.size	sys_no_number, .Lfunc_end2-sys_no_number
	.cfi_endproc
                                        // -- End function
	.globl	sys_immediate_constant          // -- Begin function sys_immediate_constant
	.p2align	2
	.type	sys_immediate_constant,@function
sys_immediate_constant:                 // @sys_immediate_constant
	.cfi_startproc
// %bb.0:
	mov	x8, xzr
	//APP
	svc	#0x40
	//NO_APP
	adrp	x8, VRET
	ldr	x0, [x8, :lo12:VRET]
	ret
.Lfunc_end3:
	.size	sys_immediate_constant, .Lfunc_end3-sys_immediate_constant
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg1                        // -- Begin function sys_arg1
	.p2align	2
	.type	sys_arg1,@function
sys_arg1:                               // @sys_arg1
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end4:
	.size	sys_arg1, .Lfunc_end4-sys_arg1
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg2                        // -- Begin function sys_arg2
	.p2align	2
	.type	sys_arg2,@function
sys_arg2:                               // @sys_arg2
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #8]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp]
	ldr	x0, [sp, #8]
	ldr	x1, [sp]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end5:
	.size	sys_arg2, .Lfunc_end5-sys_arg2
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg5                        // -- Begin function sys_arg5
	.p2align	2
	.type	sys_arg5,@function
sys_arg5:                               // @sys_arg5
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #48
	.cfi_def_cfa_offset 48
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #40]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #32]
	adrp	x8, VA2
	ldr	x8, [x8, :lo12:VA2]
	str	x8, [sp, #24]
	adrp	x8, VA3
	ldr	x8, [x8, :lo12:VA3]
	str	x8, [sp, #16]
	adrp	x8, VA4
	ldr	x8, [x8, :lo12:VA4]
	str	x8, [sp, #8]
	ldr	x0, [sp, #40]
	ldr	x1, [sp, #32]
	ldr	x2, [sp, #24]
	ldr	x3, [sp, #16]
	ldr	x4, [sp, #8]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #40]
	ldr	x8, [sp, #40]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #40]
	add	sp, sp, #48
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end6:
	.size	sys_arg5, .Lfunc_end6-sys_arg5
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg6                        // -- Begin function sys_arg6
	.p2align	2
	.type	sys_arg6,@function
sys_arg6:                               // @sys_arg6
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #48
	.cfi_def_cfa_offset 48
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #40]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #32]
	adrp	x8, VA2
	ldr	x8, [x8, :lo12:VA2]
	str	x8, [sp, #24]
	adrp	x8, VA3
	ldr	x8, [x8, :lo12:VA3]
	str	x8, [sp, #16]
	adrp	x8, VA4
	ldr	x8, [x8, :lo12:VA4]
	str	x8, [sp, #8]
	adrp	x8, VA5
	ldr	x8, [x8, :lo12:VA5]
	str	x8, [sp]
	ldr	x0, [sp, #40]
	ldr	x1, [sp, #32]
	ldr	x2, [sp, #24]
	ldr	x3, [sp, #16]
	ldr	x4, [sp, #8]
	ldr	x5, [sp]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #40]
	ldr	x8, [sp, #40]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #40]
	add	sp, sp, #48
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end7:
	.size	sys_arg6, .Lfunc_end7-sys_arg6
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg7                        // -- Begin function sys_arg7
	.p2align	2
	.type	sys_arg7,@function
sys_arg7:                               // @sys_arg7
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #56]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #48]
	adrp	x8, VA2
	ldr	x8, [x8, :lo12:VA2]
	str	x8, [sp, #40]
	adrp	x8, VA3
	ldr	x8, [x8, :lo12:VA3]
	str	x8, [sp, #32]
	adrp	x8, VA4
	ldr	x8, [x8, :lo12:VA4]
	str	x8, [sp, #24]
	adrp	x8, VA5
	ldr	x8, [x8, :lo12:VA5]
	str	x8, [sp, #16]
	adrp	x8, VA6
	ldr	x8, [x8, :lo12:VA6]
	str	x8, [sp, #8]
	ldr	x0, [sp, #56]
	ldr	x1, [sp, #48]
	ldr	x2, [sp, #40]
	ldr	x3, [sp, #32]
	ldr	x4, [sp, #24]
	ldr	x5, [sp, #16]
	ldr	x6, [sp, #8]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #56]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end8:
	.size	sys_arg7, .Lfunc_end8-sys_arg7
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg8                        // -- Begin function sys_arg8
	.p2align	2
	.type	sys_arg8,@function
sys_arg8:                               // @sys_arg8
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #56]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #48]
	adrp	x8, VA2
	ldr	x8, [x8, :lo12:VA2]
	str	x8, [sp, #40]
	adrp	x8, VA3
	ldr	x8, [x8, :lo12:VA3]
	str	x8, [sp, #32]
	adrp	x8, VA4
	ldr	x8, [x8, :lo12:VA4]
	str	x8, [sp, #24]
	adrp	x8, VA5
	ldr	x8, [x8, :lo12:VA5]
	str	x8, [sp, #16]
	adrp	x8, VA6
	ldr	x8, [x8, :lo12:VA6]
	str	x8, [sp, #8]
	adrp	x8, VA7
	ldr	x8, [x8, :lo12:VA7]
	str	x8, [sp]
	ldr	x0, [sp, #56]
	ldr	x1, [sp, #48]
	ldr	x2, [sp, #40]
	ldr	x3, [sp, #32]
	ldr	x4, [sp, #24]
	ldr	x5, [sp, #16]
	ldr	x6, [sp, #8]
	ldr	x7, [sp]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #56]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end9:
	.size	sys_arg8, .Lfunc_end9-sys_arg8
	.cfi_endproc
                                        // -- End function
	.globl	sys_arg9_stack                  // -- Begin function sys_arg9_stack
	.p2align	2
	.type	sys_arg9_stack,@function
sys_arg9_stack:                         // @sys_arg9_stack
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #64
	.cfi_def_cfa_offset 64
	adrp	x8, VA0
	ldr	x8, [x8, :lo12:VA0]
	str	x8, [sp, #56]
	adrp	x8, VA1
	ldr	x8, [x8, :lo12:VA1]
	str	x8, [sp, #48]
	adrp	x8, VA2
	ldr	x8, [x8, :lo12:VA2]
	str	x8, [sp, #40]
	adrp	x8, VA3
	ldr	x8, [x8, :lo12:VA3]
	str	x8, [sp, #32]
	adrp	x8, VA4
	ldr	x8, [x8, :lo12:VA4]
	str	x8, [sp, #24]
	adrp	x8, VA5
	ldr	x8, [x8, :lo12:VA5]
	str	x8, [sp, #16]
	adrp	x8, VA6
	ldr	x8, [x8, :lo12:VA6]
	str	x8, [sp, #8]
	adrp	x8, VA7
	ldr	x8, [x8, :lo12:VA7]
	str	x8, [sp]
	ldr	x0, [sp, #56]
	ldr	x1, [sp, #48]
	ldr	x2, [sp, #40]
	ldr	x3, [sp, #32]
	ldr	x4, [sp, #24]
	ldr	x5, [sp, #16]
	ldr	x6, [sp, #8]
	ldr	x7, [sp]
	adrp	x8, VSTACK
	add	x8, x8, :lo12:VSTACK
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #56]
	ldr	x8, [sp, #56]
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x0, [sp, #56]
	add	sp, sp, #64
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end10:
	.size	sys_arg9_stack, .Lfunc_end10-sys_arg9_stack
	.cfi_endproc
                                        // -- End function
	.globl	call_then_syscall               // -- Begin function call_then_syscall
	.p2align	2
	.type	call_then_syscall,@function
call_then_syscall:                      // @call_then_syscall
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #80
	.cfi_def_cfa_offset 80
	stp	x29, x30, [sp, #64]             // 16-byte Folded Spill
	add	x29, sp, #64
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	stur	x0, [x29, #-8]
	stur	x1, [x29, #-16]
	stur	x2, [x29, #-24]
	mov	x8, #64                         // =0x40
	str	x8, [sp, #32]
	ldur	x8, [x29, #-8]
	str	x8, [sp, #24]
	ldur	x8, [x29, #-16]
	str	x8, [sp, #16]
	ldur	x8, [x29, #-24]
	str	x8, [sp, #8]
	ldur	x0, [x29, #-8]
	ldur	x1, [x29, #-16]
	bl	helper
	str	x0, [sp]
	ldr	x0, [sp, #24]
	ldr	x8, [sp, #32]
	ldr	x1, [sp, #16]
	ldr	x2, [sp, #8]
	//APP
	svc	#0
	//NO_APP
	str	x0, [sp, #24]
	ldr	x8, [sp]
	ldr	x9, [sp, #24]
	add	x8, x8, x9
	adrp	x9, VRET
	str	x8, [x9, :lo12:VRET]
	ldr	x8, [sp]
	ldr	x9, [sp, #24]
	add	x0, x8, x9
	.cfi_def_cfa wsp, 80
	ldp	x29, x30, [sp, #64]             // 16-byte Folded Reload
	add	sp, sp, #80
	.cfi_def_cfa_offset 0
	.cfi_restore w30
	.cfi_restore w29
	ret
.Lfunc_end11:
	.size	call_then_syscall, .Lfunc_end11-call_then_syscall
	.cfi_endproc
                                        // -- End function
	.globl	helper                          // -- Begin function helper
	.p2align	2
	.type	helper,@function
helper:                                 // @helper
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	str	x1, [sp]
	ldr	x8, [sp, #8]
	mov	x9, #3                          // =0x3
	mul	x8, x8, x9
	ldr	x9, [sp]
	add	x0, x8, x9
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end12:
	.size	helper, .Lfunc_end12-helper
	.cfi_endproc
                                        // -- End function
	.globl	rd_esr                          // -- Begin function rd_esr
	.p2align	2
	.type	rd_esr,@function
rd_esr:                                 // @rd_esr
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, ESR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end13:
	.size	rd_esr, .Lfunc_end13-rd_esr
	.cfi_endproc
                                        // -- End function
	.globl	rd_elr                          // -- Begin function rd_elr
	.p2align	2
	.type	rd_elr,@function
rd_elr:                                 // @rd_elr
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, ELR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end14:
	.size	rd_elr, .Lfunc_end14-rd_elr
	.cfi_endproc
                                        // -- End function
	.globl	rd_far                          // -- Begin function rd_far
	.p2align	2
	.type	rd_far,@function
rd_far:                                 // @rd_far
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, FAR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end15:
	.size	rd_far, .Lfunc_end15-rd_far
	.cfi_endproc
                                        // -- End function
	.globl	rd_vbar                         // -- Begin function rd_vbar
	.p2align	2
	.type	rd_vbar,@function
rd_vbar:                                // @rd_vbar
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, VBAR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end16:
	.size	rd_vbar, .Lfunc_end16-rd_vbar
	.cfi_endproc
                                        // -- End function
	.globl	rd_ttbr0                        // -- Begin function rd_ttbr0
	.p2align	2
	.type	rd_ttbr0,@function
rd_ttbr0:                               // @rd_ttbr0
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, TTBR0_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end17:
	.size	rd_ttbr0, .Lfunc_end17-rd_ttbr0
	.cfi_endproc
                                        // -- End function
	.globl	rd_ttbr1                        // -- Begin function rd_ttbr1
	.p2align	2
	.type	rd_ttbr1,@function
rd_ttbr1:                               // @rd_ttbr1
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, TTBR1_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end18:
	.size	rd_ttbr1, .Lfunc_end18-rd_ttbr1
	.cfi_endproc
                                        // -- End function
	.globl	rd_tcr                          // -- Begin function rd_tcr
	.p2align	2
	.type	rd_tcr,@function
rd_tcr:                                 // @rd_tcr
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, TCR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end19:
	.size	rd_tcr, .Lfunc_end19-rd_tcr
	.cfi_endproc
                                        // -- End function
	.globl	rd_sctlr                        // -- Begin function rd_sctlr
	.p2align	2
	.type	rd_sctlr,@function
rd_sctlr:                               // @rd_sctlr
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	//APP
	mrs	x8, SCTLR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x0, [sp, #8]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end20:
	.size	rd_sctlr, .Lfunc_end20-rd_sctlr
	.cfi_endproc
                                        // -- End function
	.globl	wr_vbar                         // -- Begin function wr_vbar
	.p2align	2
	.type	wr_vbar,@function
wr_vbar:                                // @wr_vbar
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	//APP
	msr	VBAR_EL1, x8
	//NO_APP
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end21:
	.size	wr_vbar, .Lfunc_end21-wr_vbar
	.cfi_endproc
                                        // -- End function
	.globl	wr_tcr                          // -- Begin function wr_tcr
	.p2align	2
	.type	wr_tcr,@function
wr_tcr:                                 // @wr_tcr
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	//APP
	msr	TCR_EL1, x8
	//NO_APP
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end22:
	.size	wr_tcr, .Lfunc_end22-wr_tcr
	.cfi_endproc
                                        // -- End function
	.globl	wr_ttbr0                        // -- Begin function wr_ttbr0
	.p2align	2
	.type	wr_ttbr0,@function
wr_ttbr0:                               // @wr_ttbr0
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	//APP
	msr	TTBR0_EL1, x8
	//NO_APP
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end23:
	.size	wr_ttbr0, .Lfunc_end23-wr_ttbr0
	.cfi_endproc
                                        // -- End function
	.globl	ec_of                           // -- Begin function ec_of
	.p2align	2
	.type	ec_of,@function
ec_of:                                  // @ec_of
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	lsr	x0, x8, #26
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end24:
	.size	ec_of, .Lfunc_end24-ec_of
	.cfi_endproc
                                        // -- End function
	.globl	il_of                           // -- Begin function il_of
	.p2align	2
	.type	il_of,@function
il_of:                                  // @il_of
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	lsr	x8, x8, #25
	and	x0, x8, #0x1
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end25:
	.size	il_of, .Lfunc_end25-il_of
	.cfi_endproc
                                        // -- End function
	.globl	iss_of                          // -- Begin function iss_of
	.p2align	2
	.type	iss_of,@function
iss_of:                                 // @iss_of
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x0, x8, #0x1ffffff
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end26:
	.size	iss_of, .Lfunc_end26-iss_of
	.cfi_endproc
                                        // -- End function
	.globl	ec_is                           // -- Begin function ec_is
	.p2align	2
	.type	ec_is,@function
ec_is:                                  // @ec_is
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	str	w1, [sp, #4]
	ldr	x8, [sp, #8]
	lsr	x8, x8, #26
	and	x8, x8, #0x3f
	ldr	w9, [sp, #4]
                                        // kill: def $x9 killed $w9
	subs	x8, x8, x9
	cset	w9, eq
                                        // implicit-def: $x8
	mov	w8, w9
	and	x0, x8, #0x1
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end27:
	.size	ec_is, .Lfunc_end27-ec_is
	.cfi_endproc
                                        // -- End function
	.globl	is_lower_data_abort             // -- Begin function is_lower_data_abort
	.p2align	2
	.type	is_lower_data_abort,@function
is_lower_data_abort:                    // @is_lower_data_abort
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, #24]
	ldr	x8, [sp, #24]
	lsr	x8, x8, #26
	and	x8, x8, #0x3f
	str	x8, [sp, #16]
	ldr	x9, [sp, #16]
	mov	w8, #1                          // =0x1
	subs	x9, x9, #36
	str	w8, [sp, #12]                   // 4-byte Folded Spill
	b.eq	.LBB28_2
	b	.LBB28_1
.LBB28_1:
	ldr	x8, [sp, #16]
	subs	x8, x8, #37
	cset	w8, eq
	str	w8, [sp, #12]                   // 4-byte Folded Spill
	b	.LBB28_2
.LBB28_2:
	ldr	w8, [sp, #12]                   // 4-byte Folded Reload
	and	w0, w8, #0x1
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end28:
	.size	is_lower_data_abort, .Lfunc_end28-is_lower_data_abort
	.cfi_endproc
                                        // -- End function
	.globl	dfsc_of                         // -- Begin function dfsc_of
	.p2align	2
	.type	dfsc_of,@function
dfsc_of:                                // @dfsc_of
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x0, x8, #0x7f
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end29:
	.size	dfsc_of, .Lfunc_end29-dfsc_of
	.cfi_endproc
                                        // -- End function
	.globl	esr_all                         // -- Begin function esr_all
	.p2align	2
	.type	esr_all,@function
esr_all:                                // @esr_all
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	xzr, [sp, #24]
	str	xzr, [sp, #16]
	str	xzr, [sp, #8]
	//APP
	mrs	x8, ESR_EL1
	//NO_APP
	str	x8, [sp, #24]
	//APP
	mrs	x8, ELR_EL1
	//NO_APP
	str	x8, [sp, #16]
	//APP
	mrs	x8, FAR_EL1
	//NO_APP
	str	x8, [sp, #8]
	ldr	x8, [sp, #24]
	ldr	x9, [sp, #16]
	eor	x8, x8, x9
	ldr	x9, [sp, #8]
	eor	x0, x8, x9
	add	sp, sp, #32
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end30:
	.size	esr_all, .Lfunc_end30-esr_all
	.cfi_endproc
                                        // -- End function
	.globl	build_walk                      // -- Begin function build_walk
	.p2align	2
	.type	build_walk,@function
build_walk:                             // @build_walk
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x8, x8, #0xfffffffffffff000
	orr	x8, x8, #0x1
	orr	x8, x8, #0x2
	orr	x8, x8, #0x400
	orr	x8, x8, #0x800
	adrp	x9, l0
	str	x8, [x9, :lo12:l0]
	ldr	x8, [sp, #8]
	add	x8, x8, #1, lsl #12             // =4096
	and	x8, x8, #0xfffffffffffff000
	orr	x8, x8, #0x1
	orr	x8, x8, #0x2
	orr	x8, x8, #0x400
	orr	x8, x8, #0x800
	adrp	x9, l1
	str	x8, [x9, :lo12:l1]
	adrp	x10, l2
	adrp	x9, l2
	add	x9, x9, :lo12:l2
	mov	x8, #1031                       // =0x407
	movk	x8, #32768, lsl #16
	str	x8, [x10, :lo12:l2]
	mov	x8, #1031                       // =0x407
	movk	x8, #32800, lsl #16
	str	x8, [x9, #8]
	adrp	x9, l2_big
	mov	x8, #1031                       // =0x407
	movk	x8, #16384, lsl #16
	str	x8, [x9, :lo12:l2_big]
	adrp	x10, l3
	adrp	x9, l3
	add	x9, x9, :lo12:l3
	mov	x8, #1799                       // =0x707
	movk	x8, #16384, lsl #16
	str	x8, [x10, :lo12:l3]
	mov	x8, #5895                       // =0x1707
	movk	x8, #16384, lsl #16
	str	x8, [x9, #8]
	mov	x8, #1027                       // =0x403
	movk	x8, #32768, lsl #16
	str	x8, [x9, #16]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end31:
	.size	build_walk, .Lfunc_end31-build_walk
	.cfi_endproc
                                        // -- End function
	.globl	ref_l0                          // -- Begin function ref_l0
	.p2align	2
	.type	ref_l0,@function
ref_l0:                                 // @ref_l0
	.cfi_startproc
// %bb.0:
	adrp	x0, l0
	add	x0, x0, :lo12:l0
	ret
.Lfunc_end32:
	.size	ref_l0, .Lfunc_end32-ref_l0
	.cfi_endproc
                                        // -- End function
	.globl	ref_l1                          // -- Begin function ref_l1
	.p2align	2
	.type	ref_l1,@function
ref_l1:                                 // @ref_l1
	.cfi_startproc
// %bb.0:
	adrp	x0, l1
	add	x0, x0, :lo12:l1
	ret
.Lfunc_end33:
	.size	ref_l1, .Lfunc_end33-ref_l1
	.cfi_endproc
                                        // -- End function
	.globl	ref_l2                          // -- Begin function ref_l2
	.p2align	2
	.type	ref_l2,@function
ref_l2:                                 // @ref_l2
	.cfi_startproc
// %bb.0:
	adrp	x0, l2
	add	x0, x0, :lo12:l2
	ret
.Lfunc_end34:
	.size	ref_l2, .Lfunc_end34-ref_l2
	.cfi_endproc
                                        // -- End function
	.globl	ref_l2_big                      // -- Begin function ref_l2_big
	.p2align	2
	.type	ref_l2_big,@function
ref_l2_big:                             // @ref_l2_big
	.cfi_startproc
// %bb.0:
	adrp	x0, l2_big
	add	x0, x0, :lo12:l2_big
	ret
.Lfunc_end35:
	.size	ref_l2_big, .Lfunc_end35-ref_l2_big
	.cfi_endproc
                                        // -- End function
	.globl	ref_l3                          // -- Begin function ref_l3
	.p2align	2
	.type	ref_l3,@function
ref_l3:                                 // @ref_l3
	.cfi_startproc
// %bb.0:
	adrp	x0, l3
	add	x0, x0, :lo12:l3
	ret
.Lfunc_end36:
	.size	ref_l3, .Lfunc_end36-ref_l3
	.cfi_endproc
                                        // -- End function
	.globl	d0                              // -- Begin function d0
	.p2align	2
	.type	d0,@function
d0:                                     // @d0
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x9, x8, #0x1ff
	adrp	x8, l0
	add	x8, x8, :lo12:l0
	ldr	x0, [x8, x9, lsl #3]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end37:
	.size	d0, .Lfunc_end37-d0
	.cfi_endproc
                                        // -- End function
	.globl	d1                              // -- Begin function d1
	.p2align	2
	.type	d1,@function
d1:                                     // @d1
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x9, x8, #0x1ff
	adrp	x8, l1
	add	x8, x8, :lo12:l1
	ldr	x0, [x8, x9, lsl #3]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end38:
	.size	d1, .Lfunc_end38-d1
	.cfi_endproc
                                        // -- End function
	.globl	d2                              // -- Begin function d2
	.p2align	2
	.type	d2,@function
d2:                                     // @d2
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x9, x8, #0x1ff
	adrp	x8, l2
	add	x8, x8, :lo12:l2
	ldr	x0, [x8, x9, lsl #3]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end39:
	.size	d2, .Lfunc_end39-d2
	.cfi_endproc
                                        // -- End function
	.globl	d3                              // -- Begin function d3
	.p2align	2
	.type	d3,@function
d3:                                     // @d3
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x9, x8, #0x1ff
	adrp	x8, l3
	add	x8, x8, :lo12:l3
	ldr	x0, [x8, x9, lsl #3]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end40:
	.size	d3, .Lfunc_end40-d3
	.cfi_endproc
                                        // -- End function
	.globl	w3                              // -- Begin function w3
	.p2align	2
	.type	w3,@function
w3:                                     // @w3
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	str	x1, [sp]
	ldr	x8, [sp]
	ldr	x9, [sp, #8]
	and	x10, x9, #0x1ff
	adrp	x9, l3
	add	x9, x9, :lo12:l3
	str	x8, [x9, x10, lsl #3]
	ldr	x0, [sp]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end41:
	.size	w3, .Lfunc_end41-w3
	.cfi_endproc
                                        // -- End function
	.globl	big0                            // -- Begin function big0
	.p2align	2
	.type	big0,@function
big0:                                   // @big0
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x9, x8, #0x1ff
	adrp	x8, l2_big
	add	x8, x8, :lo12:l2_big
	ldr	x0, [x8, x9, lsl #3]
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end42:
	.size	big0, .Lfunc_end42-big0
	.cfi_endproc
                                        // -- End function
	.globl	t0sz_for                        // -- Begin function t0sz_for
	.p2align	2
	.type	t0sz_for,@function
t0sz_for:                               // @t0sz_for
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x9, [sp, #8]
	mov	x8, #64                         // =0x40
	subs	x0, x8, x9
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end43:
	.size	t0sz_for, .Lfunc_end43-t0sz_for
	.cfi_endproc
                                        // -- End function
	.globl	regime_bytes                    // -- Begin function regime_bytes
	.p2align	2
	.type	regime_bytes,@function
regime_bytes:                           // @regime_bytes
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x9, [sp, #8]
	mov	x8, #64                         // =0x40
	subs	x9, x8, x9
	mov	x8, #1                          // =0x1
	lsl	x0, x8, x9
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end44:
	.size	regime_bytes, .Lfunc_end44-regime_bytes
	.cfi_endproc
                                        // -- End function
	.globl	ttbr1_52                        // -- Begin function ttbr1_52
	.p2align	2
	.type	ttbr1_52,@function
ttbr1_52:                               // @ttbr1_52
	.cfi_startproc
// %bb.0:
	mov	x0, #-281474976710656           // =0xffff000000000000
	ret
.Lfunc_end45:
	.size	ttbr1_52, .Lfunc_end45-ttbr1_52
	.cfi_endproc
                                        // -- End function
	.globl	ttbr0_48                        // -- Begin function ttbr0_48
	.p2align	2
	.type	ttbr0_48,@function
ttbr0_48:                               // @ttbr0_48
	.cfi_startproc
// %bb.0:
	mov	x0, xzr
	ret
.Lfunc_end46:
	.size	ttbr0_48, .Lfunc_end46-ttbr0_48
	.cfi_endproc
                                        // -- End function
	.globl	l0_index                        // -- Begin function l0_index
	.p2align	2
	.type	l0_index,@function
l0_index:                               // @l0_index
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	lsr	x8, x8, #39
	and	x0, x8, #0x1ff
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end47:
	.size	l0_index, .Lfunc_end47-l0_index
	.cfi_endproc
                                        // -- End function
	.globl	l1_index                        // -- Begin function l1_index
	.p2align	2
	.type	l1_index,@function
l1_index:                               // @l1_index
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	lsr	x8, x8, #30
	and	x0, x8, #0x1ff
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end48:
	.size	l1_index, .Lfunc_end48-l1_index
	.cfi_endproc
                                        // -- End function
	.globl	l2_index                        // -- Begin function l2_index
	.p2align	2
	.type	l2_index,@function
l2_index:                               // @l2_index
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	lsr	x8, x8, #21
	and	x0, x8, #0x1ff
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end49:
	.size	l2_index, .Lfunc_end49-l2_index
	.cfi_endproc
                                        // -- End function
	.globl	l3_index                        // -- Begin function l3_index
	.p2align	2
	.type	l3_index,@function
l3_index:                               // @l3_index
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	lsr	x8, x8, #12
	and	x0, x8, #0x1ff
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end50:
	.size	l3_index, .Lfunc_end50-l3_index
	.cfi_endproc
                                        // -- End function
	.globl	page_off                        // -- Begin function page_off
	.p2align	2
	.type	page_off,@function
page_off:                               // @page_off
	.cfi_startproc
// %bb.0:
	sub	sp, sp, #16
	.cfi_def_cfa_offset 16
	str	x0, [sp, #8]
	ldr	x8, [sp, #8]
	and	x0, x8, #0xfff
	add	sp, sp, #16
	.cfi_def_cfa_offset 0
	ret
.Lfunc_end51:
	.size	page_off, .Lfunc_end51-page_off
	.cfi_endproc
                                        // -- End function
	.type	VA0,@object                     // @VA0
	.data
	.globl	VA0
	.p2align	3, 0x0
VA0:
	.xword	4369                            // 0x1111
	.size	VA0, 8

	.type	VA1,@object                     // @VA1
	.globl	VA1
	.p2align	3, 0x0
VA1:
	.xword	8738                            // 0x2222
	.size	VA1, 8

	.type	VA2,@object                     // @VA2
	.globl	VA2
	.p2align	3, 0x0
VA2:
	.xword	13107                           // 0x3333
	.size	VA2, 8

	.type	VA3,@object                     // @VA3
	.globl	VA3
	.p2align	3, 0x0
VA3:
	.xword	17476                           // 0x4444
	.size	VA3, 8

	.type	VA4,@object                     // @VA4
	.globl	VA4
	.p2align	3, 0x0
VA4:
	.xword	21845                           // 0x5555
	.size	VA4, 8

	.type	VA5,@object                     // @VA5
	.globl	VA5
	.p2align	3, 0x0
VA5:
	.xword	26214                           // 0x6666
	.size	VA5, 8

	.type	VA6,@object                     // @VA6
	.globl	VA6
	.p2align	3, 0x0
VA6:
	.xword	30583                           // 0x7777
	.size	VA6, 8

	.type	VA7,@object                     // @VA7
	.globl	VA7
	.p2align	3, 0x0
VA7:
	.xword	34952                           // 0x8888
	.size	VA7, 8

	.type	VN,@object                      // @VN
	.globl	VN
	.p2align	3, 0x0
VN:
	.xword	64                              // 0x40
	.size	VN, 8

	.type	VSTACK,@object                  // @VSTACK
	.globl	VSTACK
	.p2align	3, 0x0
VSTACK:
	.xword	41120                           // 0xa0a0
	.xword	45232                           // 0xb0b0
	.size	VSTACK, 16

	.type	VRET,@object                    // @VRET
	.bss
	.globl	VRET
	.p2align	3, 0x0
VRET:
	.xword	0                               // 0x0
	.size	VRET, 8

	.type	l0,@object                      // @l0
	.local	l0
	.comm	l0,4096,4096
	.type	l1,@object                      // @l1
	.local	l1
	.comm	l1,4096,4096
	.type	l2,@object                      // @l2
	.local	l2
	.comm	l2,4096,4096
	.type	l2_big,@object                  // @l2_big
	.local	l2_big
	.comm	l2_big,1048576,2097152
	.type	l3,@object                      // @l3
	.local	l3
	.comm	l3,4096,4096
	.ident	"Ubuntu clang version 21.1.8 (6ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym helper
	.addrsig_sym VA0
	.addrsig_sym VA1
	.addrsig_sym VA2
	.addrsig_sym VA3
	.addrsig_sym VA4
	.addrsig_sym VA5
	.addrsig_sym VA6
	.addrsig_sym VA7
	.addrsig_sym VN
	.addrsig_sym VSTACK
	.addrsig_sym VRET
	.addrsig_sym l0
	.addrsig_sym l1
	.addrsig_sym l2
	.addrsig_sym l2_big
	.addrsig_sym l3
