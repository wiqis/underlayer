# csr.s -- every CSR access this course can measure, in one file.
#
# The subject is the Zicsr instruction group and the CSR ADDRESS, and the
# file is hand-written rather than compiled from C for two reasons that are
# both about what a compiler can decide:
#
#   * The compiler has no idea these CSRs are privileged.  It will assemble
#     `csrr a0, satp` in U-mode code just as cheerfully as in M-mode code,
#     because nothing in the instruction says so.  A C file with inline asm
#     measures that; THIS file measures the encoding.
#   * The pseudo-instructions are two-word aliases for three-operand forms,
#     and the only way to see that is to put both spellings in the same file
#     and read the words back.
#
# Nothing in this file is ever EXECUTED.  There is no RISC-V machine, no
# emulator and no RISC-V linker on the build host.

        .text

# --- the six Zicsr instructions, register source form ---------------------
# The four pseudo-spellings FIRST, because a reader's first guess is that
# `csrr` is a distinct instruction, and it is not.
        csrr   t0, cycle            # == csrrs t0, cycle, x0
        csrw   cycle, t0            # == csrrw x0, cycle, t0
        csrs   cycle, t0            # == csrrs x0, cycle, t0
        csrc   cycle, t0            # == csrrc x0, cycle, t0

# --- the six Zicsr instructions, IMMEDIATE source form --------------------
# The difference between each pair below is ONE BIT of funct3, and the file
# is laid out so that the words come out adjacent in the listing.
        csrwi  cycle, 5             # == csrrwi x0, cycle, 5
        csrsi  cycle, 5             # == csrrsi x0, cycle, 5
        csrci  cycle, 5             # == csrrci x0, cycle, 5

# --- the same six again with a destination, so rd is not always x0 --------
        csrrw  t0, cycle, t1
        csrrs  t0, cycle, t1
        csrrc  t0, cycle, t1
        csrrwi t0, cycle, 5
        csrrsi t0, cycle, 5
        csrrci t0, cycle, 5

# --- and the three-operand forms the pseudo-spellings above are aliases for,
#     spelled out LONGHAND.  Each of these must assemble to the same four
#     bytes as the two-word form at the top of the file, and the artifact
#     prints the comparison rather than the claim.  `zero` and `x0` are the
#     same register spelled two ways, which is the same kind of aliasing one
#     level down and is in the file because otherwise the check needs a
#     special case.
        csrrw  zero, cycle, t0      # what `csrw cycle, t0` is
        csrrw  x0, cycle, t0        # the same, with the register spelled x0
        csrrs  zero, cycle, t0      # what `csrs cycle, t0` is
        csrrc  zero, cycle, t0      # what `csrc cycle, t0` is
        csrrs  t0, cycle, zero      # what `csrr t0, cycle` is
        csrrwi zero, cycle, 5       # what `csrwi cycle, 5` is
        csrrsi zero, cycle, 5       # what `csrsi cycle, 5` is
        csrrci zero, cycle, 5       # what `csrci cycle, 5` is

# --- the CSR ADDRESS, by name where the assembler knows it -----------------
# Every one of these is a supervisor or machine register.  The assembler
# resolves the NAME to a 12-bit number and puts it in the same field an
# arithmetic immediate occupies in `addi`.
        csrr   t0, sstatus
        csrr   t0, sie
        csrr   t0, sip
        csrr   t0, stvec
        csrr   t0, sepc
        csrr   t0, scause
        csrr   t0, stval
        csrr   t0, satp
        csrr   t0, sscratch
        csrr   t0, 0x114            # sieh: RV32 only by name, numeric is fine
        csrr   t0, 0x154            # siph: RV32 only by name, numeric is fine
        csrr   t0, mstatus
        csrr   t0, mtvec
        csrr   t0, mepc
        csrr   t0, mcause
        csrr   t0, mie
        csrr   t0, mip
        csrr   t0, medeleg
        csrr   t0, mideleg
        csrr   t0, mcounteren
        csrr   t0, scounteren
        csrr   t0, stimecmp

# --- the CSR ADDRESS, by number, including the U-mode ones -----------------
# `utvec` and `uepc` are written numerically because this assembler does not
# accept them by name, and that refusal is itself a measurement.
        csrr   t0, 0x005
        csrr   t0, 0x041
        csrr   t0, 0x042
        csrr   t0, 0x043
        csrr   t0, 0x004
        csrr   t0, 0x044
# --- two more, chosen to MOVE A BIT none of the named registers move -------
# Every named CSR in this file and every U-mode address above has bit 5 of
# its address clear, so a sweep over all of them reports ELEVEN bits moved
# for a field that is TWELVE wide -- a mask is a lower bound and this is
# what a lower bound looks like.  0x025 and 0x045 have bit 5 set and nothing
# else in a standard allocation uses that, which is the point: the sweep has
# to be WIDE ENOUGH or it measures the corpus rather than the field.
        csrr   t0, 0x025
        csrr   t0, 0x045

# --- the counters, which are USER-READABLE and are the sharpest test of
#     the csr[11:10] accessibility bits, because their address is 0xc00 -----
        csrr   t0, cycle
        csrr   t0, time
        csrr   t0, instret
        csrr   t0, 0xb00            # hpmcounter3
        csrr   t0, mvendorid
        csrr   t0, 0xf11            # mvendorid, spelled numerically

        ret
