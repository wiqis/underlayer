# pt.s -- page-table references, written by hand, so that the RELOCATION
# RECORDS are the assembler's answers and not clang's choices.
#
# `rvasm` measured the reach of the `auipc`/`addi` pair.  This file does not
# repeat that.  It measures the four things a LINKER has to be told about
# every address in a program, and it does it with references to a data
# object that is deliberately a page table:
#
#   1. `la` on this target is NOT `auipc`+`addi` by default.  It is
#      `auipc` + `ld` with an R_RISCV_GOT_HI20, because the riscv64-linux-gnu
#      target defaults to position-independent code and an external
#      symbol's address lives in the global offset table.  `-fno-pic` is the
#      switch, and it is the switch a page-table kernel normally wants.
#   2. The PC-relative pair is R_RISCV_PCREL_HI20 + R_RISCV_PCREL_LO12_I
#      (or LO12_S for a store), and the LO12 record names the ADDRESS OF THE
#      AUIPC, not the address being materialised.  Three loads off one
#      AUIPC produce one HI20 and three LO12s, and all three LO12s name the
#      same symbol.
#   3. The 12-bit immediate field of the LO12 instruction is left at ZERO in
#      the object.  The linker computes (low 12 of the HI20 result) + addend
#      and writes it.  So the pair is a two-instruction arithmetic expression
#      and the object stores one half of it in the instruction word and the
#      other half in the relocation table.
#   4. The absolute form is R_RISCV_HI20 + R_RISCV_LO12_I over `lui`, and it
#      is what a linker is asked to do when the code is not PC-relative.
#
# The assembler does NOT enforce the 4 KiB pairing rule the psABI states; the
# `pad` blocks in `sp.s` measure that, and section 9 reports it.

        .section .data
        .align 12                   /* a page table is page-aligned */
root_pte:
        .dword 0x000000000000000C   /* a leaf PTE; the BITS are not the point */
l1_pte:
        .dword 0x0000000000000001   /* a pointer PTE: R=W=X=0, V=1 */
l2_pte:
        .dword 0x0000000000000001

        .text

# --- `la` with the target's DEFAULT code model ----------------------------
        .globl  load_root
load_root:
        la    t0, root_pte
        ld    t1, 0(t0)
        ret

# --- the PC-relative pair, explicit, three references off one AUIPC -------
        .globl  walk_three
walk_three:
        auipc t0, %pcrel_hi(l1_pte)
        ld    t1, %pcrel_lo(walk_three)(t0)     /* +0 : the index at 0       */
        ld    t2, %pcrel_lo(walk_three)(t0)     /* +0 : the PTE at 0         */
        addi  t3, t0, %pcrel_lo(walk_three)     /* the base itself          */
        ret

# --- the same, with the offsets in the ADDEND rather than the immediate ----
        .globl  walk_offsets
walk_offsets:
        auipc t0, %pcrel_hi(l2_pte)
        ld    t1, %pcrel_lo(walk_offsets)+0(t0)
        ld    t2, %pcrel_lo(walk_offsets)+8(t0)
        ld    t3, %pcrel_lo(walk_offsets)+0x800(t0)
        ret

# --- the STORE form, which is a DIFFERENT LO12 relocation -----------------
        .globl  store_pte
store_pte:
        auipc t0, %pcrel_hi(l1_pte)
        sd    t1, %pcrel_lo(store_pte)(t0)
        ret

# --- the ABSOLUTE pair over `lui` -----------------------------------------
        .globl  abs_l1
abs_l1:
        lui   t0, %hi(l1_pte)
        addi  t0, t0, %lo(l1_pte)
        ret

# --- and a CSR read in the middle of it, because a page-table kernel does --
        .globl  enter
enter:
        la    t0, root_pte
        csrr  t1, satp
        ret
