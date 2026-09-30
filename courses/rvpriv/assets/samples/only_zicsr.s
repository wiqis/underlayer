# only_zicsr.s -- one CSR instruction and a `ret`, and nothing else.
#
# This file exists to answer ONE question with a refusal or an acceptance:
# does the assembler know that `csrr` is a Zicsr instruction?
#
# It was compiled at -march=rv64i and at -march=rv64i_zicsr, and BOTH
# builds produced the same four bytes and BOTH objects recorded a
# Tag_RISCV_arch string -- one of them `rv64i2p1` and one of them
# `rv64i2p1_zicsr2p0`.  So the ISA string attribute records what the user
# ASKED for and not what the object CONTAINS, and a linker or a loader that
# trusts the attribute to decide whether a Zicsr instruction is decodable is
# reading a string the assembler wrote without checking itself.
#
# The contrast is in `csr_o2.o` versus `csr_O2.o`, and the reason those are
# different files is in the artifact: the -O2 build of csr.s is the one that
# shows clang emitting `csrr` for a function that has no reason to know about
# privileged architecture at all.

        .text
        .globl  just_a_csr
just_a_csr:
        csrr   t0, cycle
        ret
