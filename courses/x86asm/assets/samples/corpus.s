# corpus.s -- the half of the corpus that is a HUMAN's output.
#
# Every line here was assembled by GNU as 2.46 and the resulting bytes are in
# corpus.txt, with objdump's own reading of them beside them.  The course's
# job is to make the reader able to do what build_samples.sh did: take the
# bytes apart and say which bits mean what.
#
# Read the labels left to right.  They go from the oldest encoding to the
# newest, and each one exists because the one before it could not express
# something.

.text

# --- the one-byte map ------------------------------------------------------
# No prefix at all.  The opcode byte is the instruction, and the ModRM byte
# chooses the addressing mode.  There are two operand slots, one of which is
# also the destination, so this form cannot say `a = b + c`.
sse_legacy_addps:      addps   %xmm1, %xmm0
sse_legacy_addpd:      addpd   %xmm1, %xmm0
sse_legacy_movaps:     movaps  %xmm1, %xmm0
sse_legacy_pxor:       pxor    %xmm1, %xmm0
sse_legacy_shufps:     shufps  $0x1b, %xmm1, %xmm0

# `66` is not a decoration.  It is the pp field of a VEX byte written out in
# its legacy costume, and it is the difference between packed single and
# packed double: the opcode below is `addps` WITHOUT it and `addpd` WITH it.
sse_legacy_cvtsi2ss:   cvtsi2ssl %esi, %xmm0

# --- the 0F 38 map ---------------------------------------------------------
# A SECOND escape byte in front of the opcode.  This one is where SSE3 and
# SSE4 went, because the 0F map had already filled up.
sse4_blendvps:         blendvps %xmm0, %xmm1, %xmm2

# --- VEX, two bytes --------------------------------------------------------
# 0xC5 and one more byte.  Three operands instead of two, the destination
# stops being destroyed, and the map and the mandatory prefix both move into
# the fields of that one byte.
vex2_vaddps_xmm:       vaddps  %xmm2, %xmm0, %xmm1
vex2_vaddpd_xmm:       vaddpd  %xmm2, %xmm0, %xmm1
vex2_vaddps_ymm:       vaddps  %ymm2, %ymm0, %ymm1
vex2_vsubps_ymm:       vsubps  %ymm2, %ymm0, %ymm1
# vmovaps is a MOVE, and a move is two-operand even in VEX: the vvvv field
# is still there and must still be 1111, and it still names nothing.  An
# encoding field that has to be a constant is a field the ISA has outgrown.
vex2_vmovaps_ymm:      vmovaps %ymm2, %ymm1
vex2_vpxor_ymm:        vpxor   %ymm2, %ymm0, %ymm1

# --- VEX, three bytes ------------------------------------------------------
# 0xC4 and two more.  Needed for the register numbers above 7, and for the
# instructions with a fourth operand or an immediate, because the two-byte
# form's vvvv field is four inverted bits and that is the whole of it.
vex3_vaddps_xmm8:      vaddps  %xmm10, %xmm8, %xmm9
vex3_vaddps_ymm8:      vaddps  %ymm10, %ymm8, %ymm9
vex3_vpalignr:         vpalignr $0x0f, %xmm2, %xmm0, %xmm1
vex3_vperm2f128:       vperm2f128 $0x01, %ymm2, %ymm0, %ymm1

# --- the integer set -------------------------------------------------------
# The instructions this course exists to teach, one per line, so that every
# mnemonic in the concept pages is a byte string a reader can look up.
int_sub:               sub     %ebx, %eax
int_cmp:               cmp     %ebx, %eax
int_test:              test    %ebx, %eax
int_lea:               lea     0(%rdi,%rsi,4), %rax
int_shl_imm:           shl     $1, %rax
int_shl_cl:            shl     %cl, %rax
int_shr_imm32:         shr     $1, %eax
int_shr_imm64:         shr     $1, %rax
int_rol:               rol     $7, %rax
int_ror:               ror     $7, %rax
int_movzx:             movzbl  %al, %eax
int_movsx:             movsbl  %al, %eax
int_movsxd:            movslq  %eax, %rax
int_setl:              setl    %al
int_cmovl:             cmovl   %ebx, %eax
int_mov32:             mov     %eax, %eax
int_mov16:             mov     %ax, %ax
int_neg:               neg     %rax
int_imul:              imul    %ebx, %eax
int_mul:               mul     %rbx
int_div:               div     %rbx
int_xchg:              xchg    %rax, %rbx
int_xadd:              xadd    %rbx, %rax
# `lock` is a PREFIX, not a mode, and the assembler refuses it on a register
# destination with a message that names the prefix instead of the reason:
# "expecting lockable instruction after `lock'".  The reason is one clause
# long -- LOCK is defined only for a memory destination -- and the error text
# costs the reader a trip to the manual.  Both forms are in the corpus.
int_lock_add:          lock addq $1, (%rax)
int_lock_add_plain:    addq $1, (%rax)
int_cmpxchg:           cmpxchg %rbx, %rax
int_bt:                bt      %rax, %rbx
int_bsf:               bsf     %eax, %ebx
int_popcnt:            popcnt  %eax, %ebx
int_lzcnt:             lzcnt   %eax, %ebx
int_tzcnt:             tzcnt   %eax, %ebx
int_movzx_m:           movzbl  (%rdi), %eax
int_lea_mem:           lea     8(%rdi,%rsi,8), %rax
int_movsxd_mem:        movslq  (%rdi), %rax
int_lea_noindex:       lea     16(%rdi), %rax
