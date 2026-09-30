/* wrap.c -- the ecall convention, as the COMPILER emits it, and the trap
 * CSRs, as the compiler emits THOSE.
 *
 * WHY THE ARGUMENTS ARE USED TWICE.  The first version of this file wrote
 *
 *     long sys_write(long fd, const char *buf, long n) {
 *         register long a7 __asm__("a7") = 64;
 *         __asm__ volatile ("ecall" : "+r"(a0) : ... );
 *         return a0;
 *     }
 *
 * and at -O1 and above clang compiled the whole function to
 *
 *     li a7, 0x40
 *     ecall
 *     ret
 *
 * DELETING the three argument loads.  Nothing was wrong with the compiler:
 * the arguments were genuinely dead as far as the compiler could see, and
 * what the measurement had become was a measurement of dead-code
 * elimination.  Adding `+ nfd + n` to the return value makes the arguments
 * live, and the count is then a count of the convention rather than of the
 * optimiser.  The confound is recorded rather than hidden, because "the
 * compiler deleted my arguments" is a thing that happens and a reader who
 * has not been warned will read the short version as the finding.
 *
 * The last two functions are the CONTROL: the same call with the number in
 * a6 instead of a7.  a7 is the Linux convention and a6 is what a reader
 * would guess from x86-64, where the number goes in rax.  Nothing in the
 * encoding knows the difference, and the two functions differ in exactly one
 * instruction word, which is the measurement.
 */

long sys_write(long nfd, const char *buf, long n)
{
    register long a7 __asm__("a7") = 64;      /* __NR_write on RISC-V */
    register long a0 __asm__("a0") = nfd;
    register long a1 __asm__("a1") = (long)buf;
    register long a2 __asm__("a2") = n;
    __asm__ volatile ("ecall"
                      : "+r"(a0)
                      : "r"(a1), "r"(a2), "r"(a7)
                      : "memory");
    return a0 + nfd + n;
}

long sys_getpid(void)
{
    register long a7 __asm__("a7") = 172;     /* __NR_getpid */
    register long a0 __asm__("a0") = 0;
    __asm__ volatile ("ecall" : "+r"(a0) : "r"(a7) : "memory");
    return a0;
}

/* THE CONTROL: the syscall number in a6. */
long sys_write_a6(long nfd, const char *buf, long n)
{
    register long a6 __asm__("a6") = 64;
    register long a0 __asm__("a0") = nfd;
    register long a1 __asm__("a1") = (long)buf;
    register long a2 __asm__("a2") = n;
    __asm__ volatile ("ecall"
                      : "+r"(a0)
                      : "r"(a1), "r"(a2), "r"(a6)
                      : "memory");
    return a0 + nfd + n;
}

/* The trap CSRs.  These names exist only because a machine-mode program is
 * running; the compiler resolves them to three-digit hexadecimal numbers
 * and has no further opinion.  That is the whole of what is measured here:
 * the numbers are the CSR ADDRESSES, and the encoding has one field for
 * them. */
unsigned long rd_sstatus(void) { unsigned long v; __asm__("csrr %0, sstatus" : "=r"(v)); return v; }
unsigned long rd_sie(void)     { unsigned long v; __asm__("csrr %0, sie"     : "=r"(v)); return v; }
unsigned long rd_stvec(void)   { unsigned long v; __asm__("csrr %0, stvec"   : "=r"(v)); return v; }
unsigned long rd_sepc(void)    { unsigned long v; __asm__("csrr %0, sepc"    : "=r"(v)); return v; }
unsigned long rd_scause(void)  { unsigned long v; __asm__("csrr %0, scause"  : "=r"(v)); return v; }
unsigned long rd_stval(void)   { unsigned long v; __asm__("csrr %0, stval"   : "=r"(v)); return v; }
unsigned long rd_sip(void)     { unsigned long v; __asm__("csrr %0, sip"     : "=r"(v)); return v; }
unsigned long rd_satp(void)    { unsigned long v; __asm__("csrr %0, satp"    : "=r"(v)); return v; }

/* The interrupts.  A supervisor timer interrupt is cause 5, a supervisor
 * external interrupt is cause 9 and a supervisor software interrupt is
 * cause 1, so the three enable bits are 1<<1, 1<<5 and 1<<9.  All three are
 * ordinary twelve-bit immediates and nothing in the encoding knows which
 * bit is which. */
unsigned long enable_ssie(void) { unsigned long v, r; __asm__("csrr %0, sie" : "=r"(v)); r = v | (1UL << 1);  __asm__("csrw sie, %0" :: "r"(r)); return r; }
unsigned long enable_stie(void) { unsigned long v, r; __asm__("csrr %0, sie" : "=r"(v)); r = v | (1UL << 5);  __asm__("csrw sie, %0" :: "r"(r)); return r; }
unsigned long enable_seie(void) { unsigned long v, r; __asm__("csrr %0, sie" : "=r"(v)); r = v | (1UL << 9);  __asm__("csrw sie, %0" :: "r"(r)); return r; }

/* stvec.  Two values, one Direct and one Vectored, and the ONLY difference
 * between them is the constant that goes into a register.  The instruction
 * that writes the CSR is the same word in all three functions, which is the
 * sharpest thing this course can say about the mode field.
 *
 * EACH ONE READS THE CSR BACK rather than returning the constant, and that
 * is not decoration.  The first draft returned the constant, clang computed
 * the return value in a1 and the argument in a0, and the three `csrw` words
 * came out as 0x10559073, 0x10551073 and 0x10551073 -- TWO distinct words
 * across three functions that are supposed to differ in nothing but a value.
 * The difference was `rs1`, and a section whose whole claim is "the
 * instruction does not carry the mode" had a table with a register
 * difference in it.  Reading the CSR back makes a0 the return register in
 * all three, which is what the claim needs, and it is also what a caller
 * would want. */
unsigned long set_stvec_direct(void)
{ unsigned long r = 0x0000000000001000UL; __asm__("csrw stvec, %0" :: "r"(r));
  { unsigned long v; __asm__("csrr %0, stvec" : "=r"(v)); return v; } }
unsigned long set_stvec_vectored(void)
{ unsigned long r = 0x0000000000001001UL; __asm__("csrw stvec, %0" :: "r"(r));
  { unsigned long v; __asm__("csrr %0, stvec" : "=r"(v)); return v; } }
/* 0x123 is NOT 4-byte aligned and its low two bits are 3, which is MODE = 3:
 * a RESERVED mode.  The specification says the CSR holds only bits XLEN-1
 * through 2 of BASE and that "the lower two bits are filled with zeroes", so
 * the value this writes is not 0x123.  Nothing diagnoses it, because the
 * instruction does not know the value. */
unsigned long set_stvec_misaligned(void)
{ unsigned long r = 0x0000000000000123UL; __asm__("csrw stvec, %0" :: "r"(r));
  { unsigned long v; __asm__("csrr %0, stvec" : "=r"(v)); return v; } }
