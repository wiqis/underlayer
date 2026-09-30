/* sys.c -- the corpus for "The AArch64 Machine: Modes, Memory and Faults".
 *
 * One rule shapes every line: every ARGUMENT is a `volatile` GLOBAL with its
 * own distinctive constant, and every RESULT is stored to a `volatile` GLOBAL.
 * A volatile read cannot be deleted and a volatile write cannot be dead, so
 * the call survives optimisation and the disassembly NAMES which argument
 * went where -- `x4 = 0x5555` is argument four.  A census would say "five
 * registers were written"; an AUDIT says *which argument was in which
 * register, by name*, and can therefore disagree with a specification
 * instead of merely agreeing with itself.
 *
 * THE SYSCALL NUMBERS ARE QUOTED, not measured.  They come from
 * `include/uapi/asm-generic/unistd.h` in the Linux tree, and nothing on the
 * build host can confirm one by running it: there is no AArch64 machine, no
 * AArch64 emulator and no AArch64 linker here.  The section 4 table prints
 * the document and the section for every number, and the artifact says in
 * its own words that a number confirmed only by a header file is a weaker
 * kind of claim than one confirmed by a return value.
 *
 * Compiled four ways: -O0, -O1, -O2, -Os.  Same source, same registers, four
 * different amounts of care.  Every table that prints a count says which
 * corpus and which level it came from.
 */

/* Linux asm-generic/unistd.h -- QUOTED, section 4 of the artifact. */
#define NR_fcntl      25
#define NR_openat     56
#define NR_read       63
#define NR_write      64
#define NR_mmap       222     /* __NR3264_mmap, __NR_mmap 222 on a 64-bit arch */
#define NR_exit_group 94

volatile long VA0 = 0x1111, VA1 = 0x2222, VA2 = 0x3333, VA3 = 0x4444;
volatile long VA4 = 0x5555, VA5 = 0x6666, VA6 = 0x7777, VA7 = 0x8888;
volatile long VN   = NR_write;              /* the number, LOADED */
volatile long VSTACK[2] = { 0xa0a0, 0xb0b0 };
volatile long VRET;

/* ===================================================================
 * 1. THE SYSCALL.  `mov x8, #N ; svc #0`, the Linux AArch64 convention.
 *
 * Two shapes differing only in where the 64 came from.  A literal is a
 * MOVZ/MOVK pair; a load is an adrp/ldr pair, and the second one can FAULT
 * -- which is a difference about a machine this course cannot run and a
 * compiler it can, so the instruction COUNT is the measured part and the
 * faulting is the quoted part.
 * =================================================================== */

long sys_const(void) {
    register long x8 __asm__("x8") = NR_write;
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1) : "memory","cc");
    VRET = x0;
    return x0;
}

long sys_global(void) {
    register long x8 __asm__("x8") = VN;
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1) : "memory","cc");
    VRET = x0;
    return x0;
}

/* x8 NOT MENTIONED.  So x8 is not a reserved register as far as the compiler
 * is concerned, and the interesting question is what it does with it. */
long sys_no_number(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1) : "memory","cc");
    VRET = x0;
    return x0;
}

/* The immediate is a CONSTANT IN THE INSTRUCTION on AArch64, so the whole
 * question "is the syscall number an argument or a constant" has a different
 * answer here than it does on x86-64, where `syscall` has no immediate at
 * all.  This function is the one that makes the two comparable. */
long sys_immediate_constant(void) {
    __asm__ volatile("svc #0x40" : : "r"(0L) : "memory","cc");
    return VRET;
}

/* ===================================================================
 * 2. THE ARGUMENT AUDIT.  How many argument registers does the compiler
 * FILL, in which order, and what happens to the ninth?
 * =================================================================== */

long sys_arg1(void) {
    register long x0 __asm__("x0") = VA0;
    __asm__ volatile("svc #0" : "+r"(x0) : : "memory","cc");
    VRET = x0; return x0;
}
long sys_arg2(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1) : "memory","cc");
    VRET = x0; return x0;
}
long sys_arg5(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    register long x2 __asm__("x2") = VA2;
    register long x3 __asm__("x3") = VA3;
    register long x4 __asm__("x4") = VA4;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4)
                     : "memory","cc");
    VRET = x0; return x0;
}
long sys_arg6(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    register long x2 __asm__("x2") = VA2;
    register long x3 __asm__("x3") = VA3;
    register long x4 __asm__("x4") = VA4;
    register long x5 __asm__("x5") = VA5;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4),
                     "r"(x5) : "memory","cc");
    VRET = x0; return x0;
}
/* x6 and x7: two MORE argument registers than a Linux syscall has arguments.
 * AArch64 does not care; the kernel does.  Measured here as an ENCODING --
 * the compiler fills them because they were named -- and the limit is
 * quoted, because no kernel here will ever read them. */
long sys_arg7(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    register long x2 __asm__("x2") = VA2;
    register long x3 __asm__("x3") = VA3;
    register long x4 __asm__("x4") = VA4;
    register long x5 __asm__("x5") = VA5;
    register long x6 __asm__("x6") = VA6;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4),
                     "r"(x5), "r"(x6) : "memory","cc");
    VRET = x0; return x0;
}
long sys_arg8(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    register long x2 __asm__("x2") = VA2;
    register long x3 __asm__("x3") = VA3;
    register long x4 __asm__("x4") = VA4;
    register long x5 __asm__("x5") = VA5;
    register long x6 __asm__("x6") = VA6;
    register long x7 __asm__("x7") = VA7;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4),
                     "r"(x5), "r"(x6), "r"(x7) : "memory","cc");
    VRET = x0; return x0;
}
/* The NINTH argument.  AAPCS64 has eight argument registers and no more, so
 * the ninth goes on the stack -- and this is a `volatile` C object rather
 * than a register constraint, which is exactly what "on the stack" means. */
long sys_arg9_stack(void) {
    register long x0 __asm__("x0") = VA0;
    register long x1 __asm__("x1") = VA1;
    register long x2 __asm__("x2") = VA2;
    register long x3 __asm__("x3") = VA3;
    register long x4 __asm__("x4") = VA4;
    register long x5 __asm__("x5") = VA5;
    register long x6 __asm__("x6") = VA6;
    register long x7 __asm__("x7") = VA7;
    __asm__ volatile("svc #0" : "+r"(x0)
                     : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x6),
                       "r"(x7), "m"(VSTACK[0]) : "memory","cc");
    VRET = x0; return x0;
}

/* ===================================================================
 * 3. THE FUNCTION CALL, for the contrast.  AAPCS64 says arguments go in
 * x0-x7 and the return comes back in x0 -- the SAME register the syscall
 * result comes back in.  So a wrapper that must call a function between
 * setting up a syscall and making it has to save something, and the question
 * is what the compiler saves and whether it says so.
 * =================================================================== */

long helper(long a, long b);
long call_then_syscall(long a, long b, long c) {
    register long x8 __asm__("x8") = NR_write;
    register long x0 __asm__("x0") = a;
    register long x1 __asm__("x1") = b;
    register long x2 __asm__("x2") = c;
    long r = helper(a, b);
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2)
                     : "memory","cc");
    VRET = r + x0;
    return r + x0;
}
long helper(long a, long b) { return a * 3 + b; }

/* ===================================================================
 * 4. THE SYNDROME READER.  ESR_ELx's EC is bits 31:26, IL is bit 25, ISS is
 * bits 24:0 -- QUOTED, ARM DDI 0597 AArch64_ExceptionClass.  What is
 * MEASURED is the ENCODING of the MRS that reads the register, and the
 * instructions the compiler emits to take the three fields apart.
 * =================================================================== */

unsigned long rd_esr(void) { unsigned long v;
    __asm__ volatile("mrs %0, esr_el1" : "=r"(v)); return v; }
unsigned long rd_elr(void) { unsigned long v;
    __asm__ volatile("mrs %0, elr_el1" : "=r"(v)); return v; }
unsigned long rd_far(void) { unsigned long v;
    __asm__ volatile("mrs %0, far_el1" : "=r"(v)); return v; }
unsigned long rd_vbar(void) { unsigned long v;
    __asm__ volatile("mrs %0, vbar_el1" : "=r"(v)); return v; }
unsigned long rd_ttbr0(void) { unsigned long v;
    __asm__ volatile("mrs %0, ttbr0_el1" : "=r"(v)); return v; }
unsigned long rd_ttbr1(void) { unsigned long v;
    __asm__ volatile("mrs %0, ttbr1_el1" : "=r"(v)); return v; }
unsigned long rd_tcr(void) { unsigned long v;
    __asm__ volatile("mrs %0, tcr_el1" : "=r"(v)); return v; }
unsigned long rd_sctlr(void) { unsigned long v;
    __asm__ volatile("mrs %0, sctlr_el1" : "=r"(v)); return v; }

void wr_vbar(unsigned long v) {
    __asm__ volatile("msr vbar_el1, %0" :: "r"(v) : "memory"); }
void wr_tcr(unsigned long v) {
    __asm__ volatile("msr tcr_el1, %0" :: "r"(v) : "memory"); }
void wr_ttbr0(unsigned long v) {
    __asm__ volatile("msr ttbr0_el1, %0" :: "r"(v) : "memory"); }

/* The three syndrome fields as C, and the instructions each costs. */
unsigned long ec_of(unsigned long esr)  { return esr >> 26; }
unsigned long il_of(unsigned long esr)  { return (esr >> 25) & 1; }
unsigned long iss_of(unsigned long esr) { return esr & 0x1ffffffUL; }
unsigned long ec_is(unsigned long esr, unsigned c) {
    return ((esr >> 26) & 0x3f) == c; }
/* EC 0x24 and 0x25 -- the Data Aborts from lower ELs, the two a page fault
 * arrives as.  QUOTED: DDI 0597 asserts EC IN {0x24,0x25} && iss[24]==0 forces
 * IL=1, which is the reason the IL bit is not simply "did it fault". */
int is_lower_data_abort(unsigned long esr) {
    unsigned long ec = (esr >> 26) & 0x3f;
    return ec == 0x24 || ec == 0x25;
}
/* ISS[6:0] under EC 0x24/0x25 is the DFSC.  QUOTED, and the point is that
 * the SAME 25 bits mean a DFSC here and a condition-failed NZCV there. */
unsigned long dfsc_of(unsigned long esr) { return esr & 0x7f; }
unsigned long esr_all(void) {
    unsigned long a = 0, b = 0, c = 0;
    __asm__ volatile("mrs %0, esr_el1" : "=r"(a));
    __asm__ volatile("mrs %0, elr_el1" : "=r"(b));
    __asm__ volatile("mrs %0, far_el1" : "=r"(c));
    return a ^ b ^ c;
}

/* ===================================================================
 * 5. THE PAGE TABLES.  Four levels, 512 entries, 8 bytes each, and the
 * descriptor arithmetic -- all QUOTED from the architecture.  What is
 * MEASURED is what the compiler and the ASSEMBLER emit when code has to
 * NAME one of these tables, because that is the half of the subject an
 * object file can show, and the half the ELF courses need.
 * =================================================================== */

#define PGSZ_4K    0x1000UL
#define PGSZ_2M    0x200000UL
#define PGSZ_1G    0x40000000UL

/* valid | table/page | user | AF | AP | AttrIndx<<2 | SH<<8 | PXN | UXN */
#define DESC_PAGE(pa, attr, sh) \
    (((pa) & ~(PGSZ_4K - 1)) | 1UL | (1UL << 1) | (1UL << 10) \
     | ((unsigned long)(attr) << 2) | ((unsigned long)(sh) << 8))
#define DESC_TABLE(pa) \
    (((pa) & ~(PGSZ_4K - 1)) | 1UL | (1UL << 1) | (1UL << 10) | (1UL << 11))
#define DESC_BLOCK2M(pa, attr) \
    (((pa) & ~(PGSZ_2M - 1)) | 1UL | (1UL << 1) | (1UL << 10) \
     | ((unsigned long)(attr) << 2))
#define DESC_BLOCK1G(pa, attr) \
    (((pa) & ~(PGSZ_1G - 1)) | 1UL | (1UL << 1) | (1UL << 10) \
     | ((unsigned long)(attr) << 2))

static unsigned long l0[512] __attribute__((aligned(4096)));
static unsigned long l1[512] __attribute__((aligned(4096)));
static unsigned long l2[512] __attribute__((aligned(4096)));
static unsigned long l3[512] __attribute__((aligned(4096)));
/* A table that must be 2 MiB aligned: the STRONGER requirement, and the one
 * whose absence is a silent failure rather than a diagnostic. */
static unsigned long l2_big[512 * 256] __attribute__((aligned(0x200000)));

void build_walk(unsigned long root_pa) {
    l0[0] = DESC_TABLE(root_pa);
    l1[0] = DESC_TABLE(root_pa + PGSZ_4K);
    l2[0] = DESC_BLOCK2M(0x80000000UL, 1);
    l2[1] = DESC_BLOCK2M(0x80200000UL, 1);
    l2_big[0] = DESC_BLOCK1G(0x40000000UL, 1);
    l3[0] = DESC_PAGE(0x40000000UL, 1, 3);
    l3[1] = DESC_PAGE(0x40001000UL, 1, 3);
    l3[2] = DESC_PAGE(0x80000000UL, 0, 0);
}

/* Every way code can name a table.  Each is one place a relocation is born,
 * and the census of which relocation is which is the measured part. */
unsigned long *ref_l0(void)          { return l0; }
unsigned long *ref_l1(void)          { return l1; }
unsigned long *ref_l2(void)          { return l2; }
unsigned long *ref_l2_big(void)      { return l2_big; }
unsigned long *ref_l3(void)          { return l3; }
unsigned long  d0(unsigned long i)   { return l0[i & 511]; }
unsigned long  d1(unsigned long i)   { return l1[i & 511]; }
unsigned long  d2(unsigned long i)   { return l2[i & 511]; }
unsigned long  d3(unsigned long i)   { return l3[i & 511]; }
unsigned long  w3(unsigned long i, unsigned long v) { l3[i & 511] = v; return v; }
unsigned long  big0(unsigned long i) { return l2_big[i & 511]; }

/* The regime arithmetic, in C, so that it is EXECUTED BY THE COMPILER and
 * not merely written on a page.  Every one of these is an identity. */
#define VA_BITS_48   48
#define VA_BITS_52   52
#define VA_BITS_39   39
unsigned long t0sz_for(unsigned long bits) { return 64 - bits; }
unsigned long regime_bytes(unsigned long tsz) { return 1UL << (64 - tsz); }
unsigned long ttbr1_52(void) {
    /* 52-bit VA in the HIGH half, so TTBR1 covers [0xffff000000000000, 2^64) */
    return 0xffff000000000000UL;
}
unsigned long ttbr0_48(void) { return 0x0000000000000000UL; }
unsigned long l0_index(unsigned long va) { return (va >> 39) & 0x1ff; }
unsigned long l1_index(unsigned long va) { return (va >> 30) & 0x1ff; }
unsigned long l2_index(unsigned long va) { return (va >> 21) & 0x1ff; }
unsigned long l3_index(unsigned long va) { return (va >> 12) & 0x1ff; }
unsigned long page_off(unsigned long va)  { return va & 0xfff; }
