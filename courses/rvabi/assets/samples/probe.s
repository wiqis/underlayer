/* probe.s -- one instruction per line, hand written, for the questions that a
 * C file cannot answer without a compiler's help in between.
 *
 * The reason these are hand written rather than compiled is the same reason
 * rvasm's `rv.s` is: a compiler is a CHOOSER, and every question about which
 * spelling of a zero the assembler will accept has to be asked of the
 * ASSEMBLER.  Nothing here is a measurement of clang's preferences; these are
 * the encodings themselves, and the artifact reads them back out of an object
 * file with the decoder rvasm built and llvm-objdump-21 as the second reader.
 */

	.text

# --- x0 is not a general-purpose register -------------------------------
# Every one of these WRITES a register from x0.  The manual says x0 "is
# hardwired with all bits equal to 0", and these four lines are what that
# looks like in an object file: four DIFFERENT encodings of "put a zero in
# this register", none of them touching x0 itself.
zero_mv:      mv      t0, zero        # the c.mv form, two bytes
zero_addi:    addi    t0, zero, 0     # the same value, four bytes
zero_li:      li      t0, 0           # what li with a zero constant lowers to
zero_nop:     nop                     # the canonical zero-to-zero no-operation

# The other direction: an instruction that wants to WRITE x0 is accepted by
# the assembler and does not write it.  That is the hardwiring, and it is the
# reason `zero` appears as a destination in the encoding space of every
# instruction and in almost no compiler's output.
wzero_add:    add     zero, t0, t1
wzero_li:     li      zero, 42
wzero_mv:     mv      zero, t0

# --- the two-register-pair rule for a 2*XLEN scalar --------------------
# low-order bits in the LOWER-numbered register.  These two lines differ in
# which register holds which half, and getting it backwards is a bug that
# only shows up in the values.
pair_lo:      ld      t0, 0(a0)
pair_hi:      ld      t1, 8(a0)

# --- no flags register, and the instruction that stands in for it -------
# sltiu writes a REGISTER.  It sets nothing.  That is why min/max/clamp are
# one instruction on this architecture and a conditional move elsewhere.
sltiu_test:   sltiu   t0, t0, 1
slt_test:     slt     t0, t0, t1
slti_test:    slti    t0, t0, 0
xor_mask:     xor     t0, t0, t1

# --- the compressed forms the C extension buys -------------------------
# Same operations, same results, and the byte counts are the measurement.
c_move:       mv      a0, a1          # 2 bytes with C
c_add:        add     a0, a0, a1     # 2 bytes with C
c_jalr:       ret                    # 2 bytes with C
c_sdsp:       sd      ra, 8(sp)      # 2 bytes with C
sd_full:      sd      ra, 8(sp)      # the same store without C