# sp.s -- the PAIRING DISTANCE, measured by moving the two LO12s apart.
#
# The psABI says an R_RISCV_PCREL_LO12 record has to be paired with an
# R_RISCV_PCREL_HI20 record in the same 4 KiB region, because the value the
# LO12 needs is the LOW TWELVE BITS OF THE HI20'S OWN RESULT -- and the HI20
# is an `auipc`, whose result is the pc of the AUIPC plus 2^12 times a
# 20-bit immediate.  The low twelve bits of that are the low twelve bits of
# the AUIPC's ADDRESS, which is not the same for two AUIPCs 5 KiB apart.
#
# The rule is a LINKER rule.  There is no RISC-V linker on this host, so what
# is measured here is the other half of the story and the more surprising
# half: THE ASSEMBLER DOES NOT ENFORCE IT.  Every block below asks for one
# HI20 and two LO12s that refer to the same label, and every one of them
# gets exactly one HI20 -- including the block whose two LO12s are 8 KiB
# apart, which a linker is entitled to reject.
#
# `PAD` is filled in by build_samples.sh, once per distance, and the object
# is left in the tree under a name that says which distance it used.  The
# offsets are printed by the artifact, not by this file, because the offset
# of the second LO12 IS the measurement.
#
# THE FILL BYTE IS 0x01 AND NOT 0x0f, and the reason is the cross-check.
# 0x0f is not an instruction in either encoding, so a `.space PAD, 0x0f`
# puts words into the object that BOTH readers decline to name -- and the
# first run of this file reported 4,645 disagreements of which 4,623 were the
# filler.  A cross-check whose disagreement count is mostly its own padding is
# a cross-check measuring the padding, and 0x01 is `c.nop`, which both readers
# name and which is the semantically correct thing to put between two
# instructions that are 8 KiB apart.

        .text
        .globl  go
go:
        auipc t0, %pcrel_hi(tgt)
        addi  t1, t0, %pcrel_lo(go)
#PADLINE#
        addi  t2, t0, %pcrel_lo(go)
        ret

        .section .data
        .align 12
        .globl  tgt
tgt:    .dword 0
