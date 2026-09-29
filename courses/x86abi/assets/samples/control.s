/* control.s -- the POSITIVE CONTROL for abilint.py, in ASSEMBLY and not in C.
 *
 * The first version of this file was C, and the compiler repaired two of its
 * three violations before the linter ever saw them: it pushed %rbx around
 * `movq %0, %%rbx` on its own, and it deleted the `leaq 8(%rsp),%rdi` that was
 * supposed to misalign the call.  Which is the point of the file, stated
 * differently: THE COMPILER REPAIRS WHAT IT CAN, so a positive control for an
 * ABI linter has to be written in a language the compiler does not repair.
 *
 * Expected verdict, which crosscheck.py asserts by name:
 *
 *   ct_clobber_rbx      FLAGGED   rbx     the rule itself
 *   ct_clobber_r12      FLAGGED   r12     above %rsp, same rule
 *   ct_clobber_r13      FLAGGED   r13     in a function that also CALLS
 *   ct_ok_leaf          NOT       rbx     saved and restored: must NOT appear
 *   ct_ok_leaf4         NOT       r12-r15 all four saved and restored
 *   ct_misaligned_call  ALIGN     off 0 at a `call`, where the rule wants 8
 *   ct_aligned_call     NOT       the control for the arm above
 *   ct_pushes           --        a push/pop census, 6 of each
 */
        .text
        .globl ct_clobber_rbx
        .type  ct_clobber_rbx, @function
ct_clobber_rbx:
        endbr64
        movq    %rdi, %rbx                /* the violation: no push first */
        subq    $8, %rsp                  /* an ALIGNED call site, so that the */
        call    ct_sink@PLT               /* ONLY alignment flag in this file is */
        addq    $8, %rsp                  /* ct_misaligned_call and nothing else */
        movq    %rbx, %rax
        ret
        .size   ct_clobber_rbx, .-ct_clobber_rbx

        .globl ct_clobber_r12
        .type  ct_clobber_r12, @function
ct_clobber_r12:
        endbr64
        movq    %rdi, %r12                /* a LEAF that clobbers r12 */
        movq    %r12, %rax
        ret
        .size   ct_clobber_r12, .-ct_clobber_r12

        .globl ct_clobber_r13
        .type  ct_clobber_r13, @function
ct_clobber_r13:
        endbr64
        movq    %rdi, %r13                /* a NON-LEAF that clobbers r13 */
        subq    $8, %rsp                  /* and again an aligned call site */
        call    ct_sink@PLT
        addq    $8, %rsp
        movq    %r13, %rax
        ret
        .size   ct_clobber_r13, .-ct_clobber_r13

        .globl ct_ok_leaf
        .type  ct_ok_leaf, @function
ct_ok_leaf:
        endbr64
        pushq   %rbx                      /* conforming: push first */
        movq    %rdi, %rbx
        addq    %rbx, %rax
        popq    %rbx                      /* and restore it */
        ret
        .size   ct_ok_leaf, .-ct_ok_leaf

        .globl ct_ok_leaf4
        .type  ct_ok_leaf4, @function
ct_ok_leaf4:
        endbr64
        pushq   %r12
        pushq   %r13
        pushq   %r14
        pushq   %r15
        movq    %rdi, %r12
        movq    %rdi, %r13
        movq    %rdi, %r14
        movq    %rdi, %r15
        addq    %r12, %rax
        addq    %r13, %rax
        addq    %r14, %rax
        addq    %r15, %rax
        popq    %r15
        popq   %r14
        popq   %r13
        popq   %r12
        ret
        .size   ct_ok_leaf4, .-ct_ok_leaf4

        .globl ct_misaligned_call
        .type  ct_misaligned_call, @function
ct_misaligned_call:
        endbr64
        pushq   %rbx                      /* off = 8 after one push ... */
        pushq   %r12                      /* ... and 16, i.e. 0 mod 16, after two */
        call    ct_sink@PLT               /* so %rsp is 16-ALIGNED at this call */
        popq    %r12
        popq    %rbx
        ret
        .size   ct_misaligned_call, .-ct_misaligned_call

        .globl ct_aligned_call
        .type  ct_aligned_call, @function
ct_aligned_call:
        endbr64
        subq    $8, %rsp                  /* the ABI's own idiom */
        call    ct_sink@PLT
        addq    $8, %rsp
        ret
        .size   ct_aligned_call, .-ct_aligned_call

        .globl ct_pushes
        .type  ct_pushes, @function
ct_pushes:
        endbr64
        pushq   %rbx
        pushq   %rbp
        pushq   %r12
        pushq   %r13
        pushq   %r14
        pushq   %r15
        subq    $8, %rsp
        call    ct_sink@PLT
        addq    $8, %rsp
        popq    %r15
        popq    %r14
        popq    %r13
        popq    %r12
        popq    %rbp
        popq    %rbx
        ret
        .size   ct_pushes, .-ct_pushes

        .section .note.GNU-stack,"",@progbits
