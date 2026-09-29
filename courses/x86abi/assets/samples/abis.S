/* abis.s -- the hand-written half of the x86-64 ABI course's artifact.
 *
 * Everything in here is a case gcc will not emit, or will repair, and the
 * course is about the difference between what a specification says and what a
 * compiler does.  Each block is named for the concept that uses it and is
 * referenced from abidump.c by one extern declaration.
 *
 * Build:  as -o abis.o abis.S   (.S, not .s: the file uses CPP)
 */

/* =================================================================== */
/* 1. THE RETURN ADDRESS AND THE ENTRY ALIGNMENT.                      */
/*                                                                    */
/*    A `call` pushes 8 bytes and a `ret` pops 8, so the value of %rsp  */
/*    at a callee's first instruction is 8 (mod 16) if and only if the  */
/*    caller kept %rsp 16-byte aligned at the call.  The whole of the  */
/*    alignment rule is that one sentence, and arm 2 turns it into a   */
/*    fault.                                                          */
/* =================================================================== */

        .text
        .globl abi_entry_rsp
        .type  abi_entry_rsp, @function
abi_entry_rsp:
        movq    %rsp, %rax                /* rsp at the callee's first insn */
        ret
        .size   abi_entry_rsp, .-abi_entry_rsp

        .globl abi_entry_retaddr
        .type  abi_entry_retaddr, @function
abi_entry_retaddr:
        movq    (%rsp), %rax              /* 0(%rsp) IS the return address */
        ret
        .size   abi_entry_retaddr, .-abi_entry_retaddr

/* the caller that obeys the rule: `subq $8, %rsp` is the ABI's own idiom,
 * and it is there because the 8 bytes of outgoing argument area it just
 * reserved have to be 16-byte aligned for the callee that reads them. */
/* BOTH NUMBERS FROM ONE CALL.  The first version asked for %rsp and for
 * 0(%rsp) in two separate calls, and they came from two different stack
 * depths, so the subtraction of the two produced a number near 2^64 and
 * printed as an address-looking value that is obviously wrong to a reader and
 * was not caught for a whole build.  A difference between two readings of a
 * register is only meaningful if they are the same reading of the same
 * instant, and a call is the only way to arrange that from C. */
        .globl abi_entry_pair
        .type  abi_entry_pair, @function
abi_entry_pair:
        movq    %rsp, (%rdi)             /* rdi = &rsp_out */
        movq    (%rsp), %rax
        movq    %rax, (%rsi)             /* rsi = &ret_out  */
        ret
        .size   abi_entry_pair, .-abi_entry_pair

        .globl abi_call_conforming
        .type  abi_call_conforming, @function
abi_call_conforming:
        subq    $8, %rsp
        call    abi_entry_rsp@PLT
        addq    $8, %rsp
        ret
        .size   abi_call_conforming, .-abi_call_conforming

/* the same call with the idiom deleted. */
        .globl abi_call_violating
        .type  abi_call_violating, @function
abi_call_violating:
        call    abi_entry_rsp@PLT
        ret
        .size   abi_call_violating, .-abi_call_violating

/* the same call delivered by a TAIL JMP, which pushes nothing, and which
 * therefore wants the OPPOSITE adjustment.  These two arms are the reason the
 * alignment rule is two rules and not one. */
/* The tail-call arms need a target that RECORDS what it was entered with
 * rather than one that returns to a C caller, because a tail call has no
 * caller to return to.  Each probe below is self-contained: it tail-jumps,
 * the landing point records %rsp, and the probe puts %rsp back so that it can
 * still return.  Without the put-back the recording probe would kill the
 * process, which is the point of the LAST arm, and having both in one file
 * means the difference between them is three instructions.
 *
 * A shared-memory global would NOT have worked for the dying arm: after
 * fork() a write to a .bss global lands in the child's copy-on-write page and
 * the parent never sees it, so the parent would have reported the PREVIOUS
 * probe's answer and the number would have been confidently wrong. */
        .globl abi_tail_target
        .type  abi_tail_target, @function
abi_tail_target:
        movq    %rsp, abi_g_tail_rsp(%rip)
        movq    (%rsp), %rax
        ret
        .size   abi_tail_target, .-abi_tail_target

        .globl abi_tail_plain
        .type  abi_tail_plain, @function
abi_tail_plain:
        jmp     abi_tail_target          /* no adjustment at all */
        .size   abi_tail_plain, .-abi_tail_plain

        .globl abi_tail_plain_rsp
        .type  abi_tail_plain_rsp, @function
abi_tail_plain_rsp:
        jmp     abi_tail_rec_a
abi_tail_rec_a:
        movq    %rsp, abi_g_tail_rsp(%rip)
        ret
        .size   abi_tail_plain_rsp, .-abi_tail_plain_rsp

/* The WRONG adjustment, recorded safely. */
        .globl abi_tail_adj_rsp
        .type  abi_tail_adj_rsp, @function
abi_tail_adj_rsp:
        subq    $8, %rsp
        jmp     abi_tail_rec_b
abi_tail_rec_b:
        movq    %rsp, abi_g_tail_rsp(%rip)
        addq    $8, %rsp                  /* so that THIS probe can return */
        ret
        .size   abi_tail_adj_rsp, .-abi_tail_adj_rsp

/* The WRONG adjustment, not put back.  It does not merely misalign: it puts
 * 8 bytes between the callee and the return address that its `ret` will pop,
 * so the process is gone.  Both facts are reported, and the second is the
 * reason a PLT stub contains no `subq $8, %rsp`. */
        .globl abi_tail_adjusted
        .type  abi_tail_adjusted, @function
abi_tail_adjusted:
        subq    $8, %rsp
        jmp     abi_tail_target
        .size   abi_tail_adjusted, .-abi_tail_adjusted

/* =================================================================== */
/* 2. THE FAULT.  A 16-byte aligned store, and the identical store in    */
/*    its unaligned-tolerant form.  The callee is EXACTLY the prologue  */
/*    gcc -O0 emits: push rbp; mov rsp,rbp; sub; and a 16-byte vector   */
/*    local at -16(%rbp), which is 16-byte aligned iff %rbp is, and    */
/*    %rbp is the caller's %rsp minus 8.                                 */
/* =================================================================== */

        .globl abi_store_aps
        .type  abi_store_aps, @function
abi_store_aps:
        endbr64
        pushq   %rbp
        movq    %rsp, %rbp
        subq    $32, %rsp
        movaps  %xmm0, -16(%rbp)          /* REQUIRES a 16-byte aligned address */
        movups  -16(%rbp), %xmm1
        movq    %xmm1, %rax
        movq    %rbp, %rsp
        popq    %rbp
        ret
        .size   abi_store_aps, .-abi_store_aps

        .globl abi_store_ups
        .type  abi_store_ups, @function
abi_store_ups:
        endbr64
        pushq   %rbp
        movq    %rsp, %rbp
        subq    $32, %rsp
        movups  %xmm0, -16(%rbp)          /* the same store, no requirement */
        movups  -16(%rbp), %xmm1
        movq    %xmm1, %rax
        movq    %rbp, %rsp
        popq    %rbp
        ret
        .size   abi_store_ups, .-abi_store_ups

        .globl abi_run_ok_aps
        .type  abi_run_ok_aps, @function
abi_run_ok_aps:
        subq    $8, %rsp
        call    abi_store_aps@PLT
        addq    $8, %rsp
        ret
        .size   abi_run_ok_aps, .-abi_run_ok_aps

        .globl abi_run_bad_aps
        .type  abi_run_bad_aps, @function
abi_run_bad_aps:
        call    abi_store_aps@PLT         /* the SAME callee, the subq deleted */
        ret
        .size   abi_run_bad_aps, .-abi_run_bad_aps

        .globl abi_run_bad_ups
        .type  abi_run_bad_ups, @function
abi_run_bad_ups:
        call    abi_store_ups@PLT         /* the unaligned store, same caller */
        ret
        .size   abi_run_bad_ups, .-abi_run_bad_ups

/* =================================================================== */
/* 3. THE RED ZONE.  128 bytes below %rsp that a LEAF may use with no    */
/*    frame at all.  The trap is not that something else will scribble   */
/*    on it: it is that `call` writes INTO it, because 0(%rsp) at a      */
/*    callee's entry is the return-address slot, and that is the first   */
/*    eight bytes of the caller's red zone.                              */
/* =================================================================== */

#define RZ_MAGIC 0x5a5a5a5a5a5a5a5a

        .globl abi_rz_leaf
        .type  abi_rz_leaf, @function
abi_rz_leaf:
        movabsq $RZ_MAGIC, %rax
        movq    %rax, -8(%rsp)            /* the LAST legal byte of a red zone
                                           * is [rsp-128]; [rsp-8] is the first */
        movq    %rax, -128(%rsp)
        movq    -8(%rsp), %rdi
        movq    -128(%rsp), %rsi
        xorq    %rax, %rdi                /* each becomes 0 if it survived */
        xorq    %rax, %rsi
        orq     %rdi, %rsi                /* 0 iff BOTH survived */
        setz    %al
        movzbl  %al, %eax
        ret                             /* <-- and %rsp is never touched */
        .size   abi_rz_leaf, .-abi_rz_leaf

/* the same stores, and then a CALL.  The call's return address lands on
 * exactly the slot the first store used. */
        .globl abi_rz_then_call
        .type  abi_rz_then_call, @function
abi_rz_then_call:
        movabsq $RZ_MAGIC, %rax
        movq    %rax, -8(%rsp)
        movq    %rax, -128(%rsp)
        call    abi_rz_whoami@PLT         /* writes %rsp's value into a global */
        movq    -8(%rsp), %rdi
        movq    -128(%rsp), %rsi
        xorq    %rax, %rdi
        xorq    %rax, %rsi
        orq     %rdi, %rsi                /* 0 iff BOTH survived */
        setz    %al
        movzbl  %al, %eax
        ret
        .size   abi_rz_then_call, .-abi_rz_then_call

        .globl abi_rz_whoami
        .type  abi_rz_whoami, @function
abi_rz_whoami:
        movq    %rsp, %rax                /* 0(%rsp) here == the red-zone slot */
        movq    %rax, abi_g_last_rsp(%rip)
        movq    (%rsp), %rax              /* and this word is the return address */
        movq    %rax, abi_g_last_ret(%rip)
        ret
        .size   abi_rz_whoami, .-abi_rz_whoami

/* a "leaf" that uses the red zone and then calls a function that BUILDS A
 * FRAME, so the callee's locals land on top of the caller's red zone. */
        .globl abi_rz_then_frame
        .type  abi_rz_then_frame, @function
abi_rz_then_frame:
        movabsq $RZ_MAGIC, %rax
        movq    %rax, -8(%rsp)
        movq    %rax, -16(%rsp)
        movq    %rax, -64(%rsp)
        movq    %rax, -128(%rsp)
        call    abi_frame_eater@PLT
        movq    -8(%rsp), %rdi
        movq    -16(%rsp), %rsi
        movq    -64(%rsp), %rdx
        movq    -128(%rsp), %rcx
        xorq    %rax, %rdi
        xorq    %rax, %rsi
        xorq    %rax, %rdx
        xorq    %rax, %rcx
        orq     %rdi, %rsi
        orq     %rdx, %rcx
        orq     %rsi, %rcx                /* 0 iff ALL FOUR survived */
        setz    %al
        movzbl  %al, %eax
        ret
        .size   abi_rz_then_frame, .-abi_rz_then_frame

        .globl abi_frame_eater
        .type  abi_frame_eater, @function
abi_frame_eater:
        pushq   %rbp
        movq    %rsp, %rbp
        subq    $1024, %rsp               /* an ordinary non-leaf frame */
        movq    %rbp, -8(%rsp)
        movq    %rbp, -16(%rsp)
        movq    %rbp, -64(%rsp)
        movq    %rbp, -128(%rsp)
        movq    %rbp, %rax
        movq    %rbp, %rsp
        popq    %rbp
        ret
        .size   abi_frame_eater, .-abi_frame_eater

/* =================================================================== */
/* 4. CALLEE-SAVED AND CALLER-SAVED, BY EXPERIMENT.                     */
/* =================================================================== */

/* a callee that tramples every CALLEE-SAVED register it is allowed to */
        .globl abi_clobber_saved
        .type  abi_clobber_saved, @function
abi_clobber_saved:
        movabsq $0x1111111111111111, %rbx
        movabsq $0x2222222222222222, %r12
        movabsq $0x3333333333333333, %r13
        movabsq $0x4444444444444444, %r14
        movabsq $0x5555555555555555, %r15
        movq    $0x7777777777777777, %rax
        ret
        .size   abi_clobber_saved, .-abi_clobber_saved

/* a conforming callee: tramples all nine CALLER-SAVED registers and restores
 * the callee-saved one it used */
        .globl abi_clobber_caller_saved
        .type  abi_clobber_caller_saved, @function
abi_clobber_caller_saved:
        movq    $0x7777777777777777, %rax
        movabsq $0x1111111111111111, %rdi
        movabsq $0x2222222222222222, %rsi
        movabsq $0x3333333333333333, %rdx
        movabsq $0x4444444444444444, %rcx
        movabsq $0x5555555555555555, %r8
        movabsq $0x6666666666666666, %r9
        movabsq $0x7777777777777777, %r10
        movabsq $0x8888888888888888, %r11
        pushq   %rbx                      /* it USES %rbx, so it must SAVE it */
        movabsq $0x9999999999999999, %rbx
        popq    %rbx
        ret
        .size   abi_clobber_caller_saved, .-abi_clobber_caller_saved

/* the whole of the callee-saved rule, in six bytes: push, use, pop */
        .globl abi_conform_rbx
        .type  abi_conform_rbx, @function
abi_conform_rbx:
        pushq   %rbx
        movabsq $0x9999999999999999, %rbx
        addq    %rbx, %rdi
        movq    %rdi, %rax
        popq    %rbx
        ret
        .size   abi_conform_rbx, .-abi_conform_rbx

        .globl abi_conform_r12
        .type  abi_conform_r12, @function
abi_conform_r12:
        pushq   %r12
        movabsq $0x9999999999999999, %r12
        addq    %r12, %rdi
        movq    %rdi, %rax
        popq    %r12
        ret
        .size   abi_conform_r12, .-abi_conform_r12

/* %rbp is the sixth callee-saved register and clobbering it is not a lost
 * value, it is a dead process: a caller built with a frame pointer ends with
 * `leave`, which is `movq %rbp,%rsp; popq %rbp`.  The caller's side has to be
 * assembly because gcc refuses to let an inline-asm block name %rbp at all. */
        .globl abi_rbp_bad
        .type  abi_rbp_bad, @function
abi_rbp_bad:
        pushq   %rbp
        movq    %rsp, %rbp
        movq    %rbp, %rdi
        call    abi_clobber_rbp@PLT
        movq    %rbp, %rax
        movq    %rbp, %rsp                 /* what `leave` does, and %rbp is junk */
        popq    %rbp
        ret
        .size   abi_rbp_bad, .-abi_rbp_bad

        .globl abi_rbp_good
        .type  abi_rbp_good, @function
abi_rbp_good:
        pushq   %rbp
        movq    %rsp, %rbp
        movq    %rbp, %rdi
        call    abi_clobber_caller_saved@PLT
        movq    %rbp, %rax                 /* untouched: a conforming callee */
        popq    %rbp
        ret
        .size   abi_rbp_good, .-abi_rbp_good

        .globl abi_clobber_rbp
        .type  abi_clobber_rbp, @function
abi_clobber_rbp:
        movabsq $0x6666666666666666, %rbp
        ret
        .size   abi_clobber_rbp, .-abi_clobber_rbp

/* THE DIRECTION FLAG.  The ABI requires DF to be 0 on entry to and on exit
 * from a function, which is a rule the CALLER keeps rather than the callee. */
        .globl abi_df_inside
        .type  abi_df_inside, @function
abi_df_inside:
        pushfq
        popq    %rax
        andq    $0x400, %rax              /* bit 10 only */
        movq    %rax, %rdi
        cld                                  /* and a conforming callee clears it */
        ret
        .size   abi_df_inside, .-abi_df_inside

        .globl abi_df_dirty
        .type  abi_df_dirty, @function
abi_df_dirty:
        std                                  /* and a non-conforming one need not */
        ret
        .size   abi_df_dirty, .-abi_df_dirty

/* =================================================================== */
/* 5. THE FLOATING-POINT CONTROL WORDS, WHERE THE DIRECTION IS REVERSED. */
/*    MXCSR's control bits are CALLER-saved: a callee may change them and   */
/*    need not put them back.  The x87 control word goes the other way.   */
/* =================================================================== */

        .globl abi_fp_dirty
        .type  abi_fp_dirty, @function
abi_fp_dirty:
        pushq   %rbp
        movq    %rsp, %rbp
        subq    $16, %rsp
        movl    $0x6000, -4(%rbp)          /* MXCSR RC=11: round toward zero */
        ldmxcsr -4(%rbp)
        fldcw  abi_cw_double(%rip)         /* x87 PC=10: double precision */
        addq    $16, %rsp
        popq    %rbp
        ret
        .size   abi_fp_dirty, .-abi_fp_dirty

        .globl abi_fp_clean
        .type  abi_fp_clean, @function
abi_fp_clean:
        ret
        .size   abi_fp_clean, .-abi_fp_clean

/* =================================================================== */
/* 6. THE SAME LIE, THROUGH THE C LIBRARY.                              */
/*    A hand-written variadic CALLER, because the whole point of the    */
/*    experiment is to put a chosen value in %al and a C caller cannot   */
/*    be made to.  The `andq $-16, %rsp` is here for the same reason it  */
/*    is in every prologue gcc emits: an aligned call site.  The first   */
/*    version of this was an inline-asm `call printf` in C, and the      */
/*    compiler's %rsp was whatever it happened to be, so the callee was  */
/*    entered misaligned, printf's 16-byte-aligned register save area    */
/*    landed wrong, and the program printed fragments of other lines and  */
/*    then died.  THE SYMPTOM OF BREAKING THE ALIGNMENT RULE FROM       */
/*    INLINE ASM IS NOT A DIAGNOSTIC.                                     */
/* =================================================================== */
        .globl abi_libc_printf
        .type  abi_libc_printf, @function
abi_libc_printf:                    /* rdi = the value to put in %al, xmm0/xmm1 = a and b */
        pushq   %rbp
        movq    %rsp, %rbp
        andq    $-16, %rsp           /* %rsp is 16-ALIGNED at the call below */
        movq    %rdi, %rax           /* and %al is the low byte of this */
        movq    %rdi, %rsi                /* printf's second argument */
        lea     abi_fmt2(%rip), %rdi
        call    printf@PLT
        movq    %rbp, %rsp
        popq    %rbp
        ret
        .size   abi_libc_printf, .-abi_libc_printf

        .section .rodata
        .align  2
abi_fmt2:
        .asciz  "glibc printf, al=%ld: %f %f\n"
/* The x87 control word, field by field, because getting the field wrong is
 * how this file's first attempt at this experiment managed to change the
 * ROUNDING mode while claiming to change the PRECISION mode.  The PC field is
 * bit 8 together with bits 0-5; the RC field is bits 11-12.  0x037f is what
 * this process starts with: PC = 1:111111 = extended, RC = 00 = nearest.
 * 0x0210 is the same word with PC = 0:010000 = double precision. */
abi_cw_double:
        .short  0x0210                    /* x87 PC = double precision, RC = 00 */

        .section .bss
        .align  8
        .globl abi_g_last_rsp
abi_g_last_rsp:  .quad 0
        .globl abi_g_last_ret
abi_g_last_ret:  .quad 0
        .globl abi_g_tail_rsp
abi_g_tail_rsp:  .quad 0

        .section .note.GNU-stack,"",@progbits
