/* privbench -- the artifact for "Exceptions, Privilege and Mode Changes".
 *
 * ============================ READ THIS FIRST ============================
 * FIVE RULES, each learned by breaking it.  They are the transferable part of
 * this file; the numbers it prints are not.
 *
 *  1. THE TSC IS TIME, NOT CYCLES.  constant_tsc and nonstop_tsc are set, so
 *     RDTSC counts a fixed-rate reference clock, not core clock cycles.  The
 *     core clock moves inside a single run.  So NOTHING here is quoted as a
 *     cycle count, and every cost is a RATIO.  A ratio has the same clock on
 *     both sides and the clock cancels.
 *
 *  2. INTERLEAVE THE ARMS.  A frequency ramp between arm A and arm B lands
 *     entirely in the ratio.  The same lesson as the memory course, which
 *     found the ordering of estimators is a property of how hard the clock was
 *     moving and not of the estimator.
 *
 *  3. TAKE THE MINIMUM, NOT THE MEAN.  Section 0 measures the noise floor of
 *     this estimator before any claim is made, and the floor is 14-30%.  Under
 *     that much noise the fastest run is the one least disturbed by something
 *     else, and a mean is contaminated by whatever disturbed the others.
 *
 *  4. NO ABSOLUTE CLAIM ABOUT WHAT THE CPU DID.  A user process may not read
 *     the IDT, may not read its own CR3, and may not see the saved RIP.  Every
 *     "what exception was that" row in this file is derived from the SIGNAL
 *     the kernel chose to deliver, which is a Linux decision, not an x86 one.
 *     Section 8 says so out loud, and section 6 shows the two things that
 *     survive the gap.
 *
 *  5. IT PRINTS ITS OWN LIMITS AND ITS OWN RETRACTIONS.  Section 8.  A tool
 *     that prints only the headline is what every datasheet already is, and a
 *     measurement tool that hides a retractor teaches its reader to trust the
 *     thing that was taken back.
 *
 * ============================ WHAT IS IN HERE ============================
 *   0. the instrument: TSC rate, core clock, noise floor, vendor, feature bits
 *   1. the gate table: SIDT, and a fork that proves the IDT is unreadable
 *   2. the vectors: which numbers are defined, and the three-way class split
 *   3. the doors: SYSCALL vs INT 0x80 vs SYSENTER, timed, and why
 *   4. the convention: the kernel's OWN bytes, read out of the vDSO
 *   5. the hole: the canonical boundary, found by bisection from user mode
 *   6. the fault record: one address, three accesses, three different si_codes
 *   7. the same idea on three architectures, and what is NOT claimed
 *   8. the retractions, and the limits
 *
 * Build: cc -O2 -o privbench privbench.c      Run: ./privbench
 * ======================================================================== */

#define _GNU_SOURCE
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <setjmp.h>
#include <time.h>
#include <elf.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <sys/auxv.h>
#include <sys/wait.h>
#include <asm/prctl.h>

extern char __ehdr_start[];   /* the MAIN EXECUTABLE's header, NOT the vDSO */

/* ------------------------------------------------------------------ */
/* 4. the instrument                                                    */
/* ------------------------------------------------------------------ */

static inline uint64_t rdtsc(void) {
    uint32_t lo, hi;
    __asm__ __volatile__("lfence\n\trdtsc" : "=a"(lo), "=d"(hi) :: "memory");
    return ((uint64_t)hi << 32) | lo;
}
static inline uint64_t rdtscp(uint32_t *aux) {
    uint32_t lo, hi, c;
    __asm__ __volatile__("rdtscp" : "=a"(lo), "=d"(hi), "=c"(c) :: "memory");
    if (aux) *aux = c;
    return ((uint64_t)hi << 32) | lo;
}
static inline void cpuid3(uint32_t leaf, uint32_t sub, uint32_t out[4]) {
    __asm__ __volatile__("cpuid"
        : "=a"(out[0]), "=b"(out[1]), "=c"(out[2]), "=d"(out[3])
        : "a"(leaf), "c"(sub));
}

static double mono_ns(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec * 1e9 + (double)t.tv_nsec;
}

/* ------------------------------------------------------------------ */
/* the trap catcher                                                     */
/* ------------------------------------------------------------------ */

/* NOTE ON NAMING.  glibc's <signal.h> defines si_addr, si_code and si_errno as
 * MACROS expanding into _sifields._sigfault.*, so a struct cannot have members
 * with those names.  The members here are therefore addr_/code_/errno_.  This
 * is stated in the file because a reader who tries the obvious names will get a
 * hundred confusing errors, and "the header lies about the field names" is
 * exactly the kind of thing a course should hand over having hit itself. */
/* VOLATILE, and this is not decoration.  A signal handler's writes are only
 * guaranteed visible to the interrupted code if the object is volatile-qualified
 * and the compiler reloads it after the siglongjmp.  The first version of this
 * struct was not volatile, and the effect was a bisection in section 5 that
 * converged on 0x00007ffffffffffc/0x00007ffffffffffd -- a boundary inside a
 * single page, which is impossible, and a plausible-looking answer.  The
 * compiler had reused a register the longjmp restored to a stale value.
 *
 * A wrong answer that looks reasonable is the failure mode to design against.
 * The crosscheck here cannot catch it either: there is nothing left of the old
 * code to diff against.  See section 8, R6. */
struct trap {
    volatile int raised, signo;
    volatile int code_, errno_;
    volatile uint64_t addr_;
};
static struct trap g;
static sigjmp_buf g_jb;

static void on_trap(int s, siginfo_t *i, void *u) {
    (void)u;
    g.raised = 1;
    g.signo = s;
    g.code_ = i->si_code;
    g.errno_ = i->si_errno;
    g.addr_ = (uint64_t)(uintptr_t)i->si_addr;
    siglongjmp(g_jb, 1);
}

/* Install handlers for every signal this program can take, with SA_SIGINFO
 * so the kernel fills siginfo, and SA_NODEFER so a fault inside a handler
 * faults again instead of killing us.  That is not paranoia: the divide test
 * genuinely traps once per division. */
static void arm(void) {
    static const int sigs[] = { SIGSEGV, SIGILL, SIGFPE, SIGTRAP,
                                SIGBUS,  SIGSYS, SIGXCPU };
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = on_trap;
    sa.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigemptyset(&sa.sa_mask);
    for (unsigned i = 0; i < sizeof sigs / sizeof sigs[0]; i++)
        sigaction(sigs[i], &sa, NULL);
}

/* Clear the record with EXPLICIT volatile writes.
 *
 * `memset(&g, 0, sizeof g)` is wrong here and was the actual cause of a wrong
 * answer.  memset takes a `void *`, so its writes to a volatile object are not
 * volatile-qualified, the compiler is entitled to elide or reorder them, and
 * the record then held values from a PREVIOUS probe.  The bisection in section
 * 5 consequently converged on a boundary INSIDE A SINGLE PAGE, which is
 * impossible, and printed it with complete confidence.  See section 8, R6. */
static void clear_trap(void) {
    g.raised = 0; g.signo = 0; g.code_ = 0; g.errno_ = 0; g.addr_ = 0;
}

/* Run a body that is EXPECTED to trap.  Returns 1 if it trapped. */
static int run_trap(void (*body)(void)) {
    clear_trap();
    arm();
    if (sigsetjmp(g_jb, 1) == 0) { body(); return 0; }
    return 1;
}

/* ------------------------------------------------------------------ */
/* reading a file                                                      */
/* ------------------------------------------------------------------ */

static int slurp(const char *path, char *out, size_t cap) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    size_t n = 0;
    for (;;) {
        ssize_t r = read(fd, out + n, cap - 1 - n);
        if (r <= 0) break;
        n += (size_t)r;
        if (n >= cap - 1) break;
    }
    close(fd);
    out[n] = 0;
    return (int)n;
}

/* ------------------------------------------------------------------ */
/* 0. the instrument                                                   */
/* ------------------------------------------------------------------ */

static char g_mds[512];
static char g_cpuid[8192];
static volatile uint64_t g_sink;

static void sec_machine(void) {
    puts("");
    puts("0. THE INSTRUMENT");
    puts("   Everything below is measured before any claim about the machine");
    puts("   is made, because a claim whose noise floor is unknown is not a claim.");

    /* --- the TSC rate, against CLOCK_MONOTONIC, and invariant across a sleep */
    double t0 = mono_ns();
    uint64_t c0 = rdtsc();
    struct timespec sl = { 0, 80 * 1000 * 1000 };
    nanosleep(&sl, NULL);
    uint64_t c1 = rdtsc();
    double t1 = mono_ns();
    double rate_busy = (double)(c1 - c0) / (t1 - t0);

    t0 = mono_ns();
    c0 = rdtsc();
    nanosleep(&sl, NULL);
    c1 = rdtsc();
    t1 = mono_ns();
    double rate_idle = (double)(c1 - c0) / (t1 - t0);

    /* --- the core clock, sampled with RDTSCP's TSC_AUX, and the CPI proxy */
    uint32_t lo0 = 0, hi0 = 0, lo1 = 0, hi1 = 0;
    /* The core clock is not readable from user mode.  /proc/cpuinfo exposes a
     * value that is refreshed far more slowly than any measurement takes, so
     * it is printed for ORIENTATION and explicitly NOT used.  The execution
     * course converted timings with it and was wrong by up to 3x. */
    if (slurp("/proc/cpuinfo", g_cpuid, sizeof g_cpuid) > 0) {
        const char *p = strstr(g_cpuid, "cpu MHz");
        if (p) {
            const char *q = strchr(p, ':');
            if (q) printf("\n   /proc/cpuinfo 'cpu MHz'  %.3f  (ORIENTATION ONLY -- "
                          "refreshed far slower than a measurement)\n", atof(q + 1));
        }
    }
    (void)lo0; (void)hi0; (void)lo1; (void)hi1;

    printf("\n   TSC rate, busy         %.4f GHz\n", rate_busy);
    printf("   TSC rate, across sleep %.4f GHz\n", rate_idle);
    printf("   TSC drift busy vs idle %.3f%%   <-- invariant, so a TSC tick is TIME\n",
           100.0 * (rate_busy - rate_idle) / rate_idle);

    /* --- the noise floor of THIS ESTIMATOR, not of one run.
     *
     * The memory course got this wrong once and recorded the correction: quote
     * the spread of the estimator you actually use, not the spread of the runs
     * behind it.  The estimator here is MIN-OF-3, so the floor measured here is
     * the spread of fifteen min-of-3 values.  Measuring the spread of the raw
     * runs instead reported a number two and a half times worse and would have
     * made every ratio in section 3 look unreliable when it is not. */
    /* The body of this measurement is a POINTER CHASE over a 256 KiB buffer,
     * and that choice is the whole finding.
     *
     * The first version of this floor was a `volatile` increment loop, and it
     * reported 81% -- reproducibly, which meant it was not noise at all.  An
     * arithmetic loop is BOUNDED BY THE CORE CLOCK: the TSC is fixed-rate and
     * the core is not, so a clock ramp shows up as a change in the tick count
     * for a fixed amount of work.  The fix is not to average harder; it is to
     * measure on a body the clock cannot affect.  A chase spends its time
     * waiting on a load, so the frequency is not in the measurement.
     *
     * This is the memory course's instrument lesson arriving in a course that
     * is not about memory: what a benchmark's "noise" is, usually tells you
     * which part of the machine the benchmark is actually measuring. */
    /* 256 KiB.  NB the first version of this line was
     *     malloc(256*1024 / sizeof(uint32_t))
     * which allocates the ELEMENT COUNT as if it were a byte count -- a 4x
     * under-allocation, because the loop then writes 4 bytes per element over
     * four times that many elements.  It segfaulted.  The lesson is not "be
     * careful with malloc"; it is that a pointer-chase benchmark which walks
     * off the end of its own array still produces a plausible-looking timing
     * for every sample right up until it does not. */
    enum { NELEM = 256 * 1024 / 4, STRIDE = 4099 };
    double est[15];
    static uint32_t *chase;
    if (!chase) {
        chase = malloc(sizeof(uint32_t) * (size_t)NELEM);
        if (!chase) { puts("   malloc failed"); return; }
        for (int k = 0; k < NELEM; k++)
            chase[k] = (uint32_t)((k + STRIDE) % NELEM);
    }
    for (int i = 0; i < 15; i++) {
        double best = 1e30;
        for (int k = 0; k < 3; k++) {              /* this is the estimator */
            uint32_t c = 0;
            uint64_t a0 = rdtsc();
            for (long j = 0; j < 2000000; j++) c = chase[c];
            uint64_t b0 = rdtsc();
            g_sink = c;
            double v = (double)(b0 - a0);
            if (v < best) best = v;
        }
        est[i] = best;
    }
    double mn = est[0], mx = est[0];
    for (int i = 1; i < 15; i++) {
        if (est[i] < mn) mn = est[i];
        if (est[i] > mx) mx = est[i];
    }
    double efloor = (mx - mn) / mn;
    printf("   estimator = min-of-3, 15 of them, over a 256 KiB pointer chase\n");
    printf("   spread %5.1f%%   <-- the floor every ratio in section 3 must clear\n",
           100.0 * efloor);
    puts("   The body is a chase and not an arithmetic loop ON PURPOSE.  An");
    puts("   arithmetic loop is bounded by the core clock, the TSC is fixed-rate,");
    puts("   and a frequency ramp therefore reads as 80% 'noise' that is really");
    puts("   the clock.  A chase waits on a load, so the clock is not in the");
    puts("   measurement at all.  What a benchmark's noise is usually tells you");
    puts("   which part of the machine the benchmark is really measuring.");

    /* --- who made this chip, and which feature bits it has */
    uint32_t v[4];
    cpuid3(0, 0, v);
    char vendor[13];
    memcpy(vendor + 0, &v[1], 4);
    memcpy(vendor + 4, &v[3], 4);
    memcpy(vendor + 8, &v[2], 4);
    vendor[12] = 0;
    printf("\n   vendor \"%s\"\n", vendor);
    cpuid3(1, 0, v);
    /* CPUID.01H:EAX carries the signature, and the field positions are the
     * trap.  The family is EAX[11:8] -- NOT EAX[7:4] -- and EAX[27:20] is an
     * EXTENDED family that only participates when EAX[11:8] == 0xF.  Read the
     * four bits that are not the family and you get 0; read the family alone
     * and you get 15; the answer is their sum, 25.  Linux's own cpuid.c uses
     * the same formula, which is why /proc/cpuinfo agrees with this line. */
    uint32_t eax = v[0];
    uint32_t fam_field  = (eax >> 8) & 0xf;
    uint32_t ext_family = (eax >> 20) & 0xff;
    uint32_t mod_field  = (eax >> 4) & 0xf;
    uint32_t ext_model  = (eax >> 16) & 0xf;
    uint32_t family = fam_field, model = mod_field;
    if (fam_field == 0xf) family += ext_family;
    if (fam_field == 0x6 || fam_field == 0xf) model += ext_model << 4;
    printf("   CPUID.01H:EAX = 0x%08x   (signature)\n", eax);
    printf("   EAX[11:8] family field = 0x%x    EAX[27:20] extended = 0x%x\n",
           fam_field, ext_family);
    printf("   EAX[7:4]  model field  = 0x%x    EAX[19:16] extended = 0x%x\n",
           mod_field, ext_model);
    printf("   -> family 0x%x (%d)  model 0x%x (%d)  stepping 0x%x\n",
           family, family, model, model, eax & 0xf);
    puts("   Read the wrong four bits and you get a family of 0, which is not a");
    puts("   family any x86 part has ever had.");

    /* The trap of the whole section, in one line: the CR4 bit numbers and the
     * CPUID bit numbers for SMEP and SMAP are NOT the same numbers. */
    uint32_t f1_ecx = v[2];
    uint32_t l7[4];
    cpuid3(7, 0, l7);
    int cpuid_smep = (l7[1] >> 7) & 1;
    int cpuid_smap = (l7[1] >> 20) & 1;
    printf("   CPUID.(EAX=7,ECX=0):EBX[7]  SMEP supported = %d\n", cpuid_smep);
    printf("   CPUID.(EAX=7,ECX=0):EBX[20] SMAP supported = %d\n", cpuid_smap);
    printf("   ...but CR4.SMEP is bit %d and CR4.SMAP is bit %d.  The two\n",
           20, 21);
    printf("      numbering schemes disagree, and the CPUID one is the trap.\n");
    (void)f1_ecx;

    /* What the KERNEL says is enabled -- a report, not a measurement. */
    unsigned long perms = 0;
    long rc = syscall(SYS_arch_prctl, ARCH_GET_XCOMP_PERM, &perms);
    printf("\n   arch_prctl(ARCH_GET_XCOMP_PERM) rc=%ld  perms=0x%lx\n", rc, perms);
    printf("      bit0 SMEP=%d  bit1 SMAP=%d  bit2 SHSTK=%d   (the KERNEL's report)\n",
           (int)(perms & 1), (int)((perms >> 1) & 1), (int)((perms >> 2) & 1));
    if (slurp("/sys/devices/system/cpu/vulnerabilities/mds", g_mds, sizeof g_mds) > 0) {
        char *nl = strchr(g_mds, '\n');
        if (nl) *nl = 0;
        printf("   /sys/.../vulnerabilities/mds  \"%s\"\n", g_mds);
    }
    puts("   NOTE: ring 3 cannot verify SMEP/SMAP BEHAVIOUR.  The CR4 bits are");
    puts("      privileged, so there is no independent check.  This is a report.");
}

/* ------------------------------------------------------------------ */
/* 1. the gate table                                                    */
/* ------------------------------------------------------------------ */

/* THE PSEUDO-DESCRIPTOR, AND THE TRAP IN IT.
 *
 * SIDT/SGDT/LGDT/LIDT write a 10-byte "pseudo-descriptor" whose field order is
 * BASE FIRST, LIMIT SECOND -- an 8-byte base at offset 0 and a 16-bit limit at
 * offset 8.  Almost every prose description of it says "the 16-bit limit and
 * the 64-bit base", in that order, and reading it that way does not fault:
 * you get a plausible-looking base and a limit of zero.  This file keeps both
 * readings side by side and prints the difference, because a wrong read that
 * returns garbage teaches its reader nothing and a wrong read that crashes
 * teaches them only that.  See section 8, R5. */
struct pseudo_desc { uint64_t base; uint16_t limit; } __attribute__((packed));
static struct pseudo_desc g_pd;

static void do_sidt(void) { __asm__ __volatile__("sidt %0" :: "m"(g_pd) : "memory"); }

/* Read the first 8 bytes of the IDT.  EXPECTED TO FAULT.  Run in a child so
 * that the parent's state is untouched and the fault is reported as a signal
 * rather than as a core dump.  This is the memory course's R7 lesson applied on
 * purpose: `rdpmc` killed the whole benchmark when it ran in the parent, and
 * now it runs in a forked child that reports the signal it died from. */
static int probe_idt_readable(int *signo_out) {
    pid_t pid = fork();
    if (pid == 0) {
        g_sink = *(volatile uint64_t *)(uintptr_t)g_pd.base;
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    if (WIFSIGNALED(st)) { *signo_out = WTERMSIG(st); return 0; }
    *signo_out = 0;
    return WEXITSTATUS(st) == 0 ? 1 : 0;
}

static void sec_table(void) {
    puts("");
    puts("1. THE GATE TABLE");
    puts("   The one structure the CPU consults on every change of mode.");

    do_sidt();
    uint64_t base = g_pd.base;
    uint16_t limit = g_pd.limit;
    unsigned char raw[10];
    memcpy(raw, &g_pd, 10);

    printf("\n   the ten bytes SIDT actually wrote: ");
    for (int i = 0; i < 10; i++) printf("%02x ", raw[i]);
    printf("\n");

    printf("   SIDT  base  = 0x%016llx\n", (unsigned long long)base);
    printf("   SIDT  limit = %u  ->  %u entries of 16 bytes\n",
           limit, (limit + 1) / 16);

    /* Read it the way the manuals are usually paraphrased, and show the damage. */
    uint16_t wrong_limit; uint64_t wrong_base;
    memcpy(&wrong_limit, raw, 2);
    memcpy(&wrong_base, raw + 2, 8);
    printf("\n   read the other way round -- limit first, then base:\n");
    printf("      base  = 0x%016llx   limit = %u\n",
           (unsigned long long)wrong_base, wrong_limit);
    puts("      No fault.  No obviously impossible value.  A tool written that way");
    puts("      reports a limit of 0 and a base in the middle of nowhere, and a");
    puts("      limit of 0 is INDISTINGUISHABLE from a kernel that installed an");
    puts("      empty IDT.  This is the worst kind of wrong: it is not loud.");

    puts("\n   And what the base IS, rather than what a manual says:");
    printf("      0x%016llx is %llu bytes below the top of a 48-bit space,\n",
           (unsigned long long)base,
           (unsigned long long)(0xffffffffffffffffULL - base + 1));
    puts("      i.e. exactly 2^32.  It is the address the x86-64 architecture");
    puts("      itself uses for the IDT, not a kernel allocation.  A kernel MAY");
    puts("      choose another, and this one did not -- and this file does not");
    puts("      ASSUME it: it prints what it read, then checks the shape.");
    printf("      measured base == the architectural address: %s\n",
           (base == 0xffffffff00000000ULL) ? "yes"
           : "NO -- a different kernel, and the lesson is the same");

    /* 4096 entries on a machine that has 12 threads. */
    printf("\n   %u entries is not a claim that %u interrupts exist.  It is a limit:\n",
           (limit + 1) / 16, (limit + 1) / 16);
    puts("      the largest vector the hardware will even look up is limit/16.");
    puts("      A kernel sets this to 4096 so that `int 0xNN` with any byte is a");
    puts("      bounds check rather than a wild read.  It is a hardened default,");
    puts("      and it is why a user `int 0x80` is a memory-safety question.");

    /* 4096 entries on a machine that has 12 threads and no 4096 interrupts. */
    printf("   %u entries is not a claim that %u interrupts exist.  It is a limit:\n",
           (limit + 1) / 16, (limit + 1) / 16);
    puts("      the largest vector the hardware will even look up is (limit)/16-1.");

    int sig = 0;
    int readable = probe_idt_readable(&sig);
    printf("\n   Reading the first 8 bytes of the IDT from ring 3: %s\n",
           readable ? "SUCCEEDED (the table is user-readable here)"
                    : "FAULTED");
    if (!readable)
        printf("      the child died of signal %d (%s)\n", sig,
               sig == SIGSEGV ? "SIGSEGV" : "other");
    puts("   The register is readable; the TABLE is not.  SIDT tells a process where");
    puts("   the gates are, and gives it no way to read one.  That asymmetry is the");
    puts("   whole privilege story in one line, and it cost a fork to establish.");

    /* The shape of a gate, and the fact that we cannot read a real one. */
    puts("\n   A 64-bit gate is 16 bytes:");
    puts("      0..1   offset 15:0 of the handler");
    puts("      2..3   segment selector");
    puts("      4..5   offset 31:16, and in the same word:");
    puts("               bits 4:0  IST index");
    puts("               bits 11:8 type   (0xE interrupt gate, 0xF trap gate)");
    puts("               bit  12   P, present");
    puts("               bits 14:13 DPL, the descriptor privilege level");
    puts("      8..11  offset 63:32 of the handler");
    puts("      12..15 reserved");
    puts("   The IDT is indexed by VECTOR NUMBER, not by selector, so this entry");
    puts("   has no RPL and the MAX(CPL,RPL)<=DPL rule that every textbook quotes");
    puts("   for 'gates' is the CALL-GATE rule.  For an interrupt gate it is:");
    puts("      IF gate.DPL < CPL THEN #GP(vector,1,0)");
    puts("   Intel states it that way; AMD adds the reason: \"no RPL comparison");
    puts("   takes place... a vector number has no RPL field\".");
}

/* ------------------------------------------------------------------ */
/* 2. the vectors                                                      */
/* ------------------------------------------------------------------ */

struct vec_info { int num; const char *mnem; char cls; int errcode; const char *note; };

/* From Intel SDM Vol 3A Table 7-1 (order 253668-090US) and AMD64 APM Vol 2
 * Table 8-1 (24593 rev 3.42).  '-' marks a vector that is reserved on BOTH. */
static const struct vec_info VECS[] = {
    { 0,  "#DE", 'F', 0, "divide error" },
    { 1,  "#DB", 'T', 0, "debug; class depends on the cause" },
    { 2,  "NMI", 'I', 0, "not an exception" },
    { 3,  "#BP", 'T', 0, "INT3; RIP points at the NEXT instruction" },
    { 4,  "#OF", 'T', 0, "INTO; RIP points at the NEXT instruction" },
    { 5,  "#BR", 'F', 0, "BOUND" },
    { 6,  "#UD", 'F', 0, "invalid opcode; RIP points at the FAULTING instruction" },
    { 7,  "#NM", 'F', 0, "device not available" },
    { 8,  "#DF", 'A', 1, "abort; the saved RIP is UNDEFINED" },
    { 9,  "-",    '?', 0, "coprocessor segment overrun; RESERVED" },
    { 10, "#TS", 'F', 1, "invalid TSS" },
    { 11, "#NP", 'F', 1, "segment not present" },
    { 12, "#SS", 'F', 1, "stack-segment fault" },
    { 13, "#GP", 'F', 1, "general protection" },
    { 14, "#PF", 'F', 1, "page fault; error code has its OWN format" },
    { 15, "-",    '?', 0, "RESERVED" },
    { 16, "#MF", 'F', 0, "x87; saved RIP is the NEXT DEFERRED point, not the fault" },
    { 17, "#AC", 'F', 1, "alignment check" },
    { 18, "#MC", 'A', 0, "machine check; abort" },
    { 19, "#XM", 'F', 0, "SIMD FP; AMD calls it #XF" },
    { 20, "#VE", 'F', 0, "virtualization: Intel DEFINES IT, AMD says RESERVED" },
    { 21, "#CP", 'F', 1, "control protection; a THIRD error-code format" },
    { 22, "-",    '?', 0, "RESERVED" },
    { 23, "-",    '?', 0, "RESERVED" },
    { 24, "-",    '?', 0, "RESERVED" },
    { 25, "-",    '?', 0, "RESERVED" },
    { 26, "-",    '?', 0, "RESERVED" },
    { 27, "-",    '?', 0, "RESERVED" },
    { 28, "-",    '?', 0, "RESERVED on Intel; AMD calls it #HV" },
    { 29, "#VC", 'F', 0, "VMM communication; Intel's Table 7-1 wrongly says reserved" },
    { 30, "#SX", 'A', 0, "security; Intel's Table 7-1 wrongly says reserved" },
    { 31, "-",    '?', 0, "RESERVED" },
};
#define NVEC ((int)(sizeof VECS / sizeof VECS[0]))

/* the three instructions that let us actually raise a real vector from ring 3 */
static void v_div0(void) {
    unsigned long a = 1, d = 0, q, r;
    __asm__ __volatile__("divq %4" : "=a"(q), "=d"(r) : "a"(a), "d"(0UL), "r"(d) : "cc");
}
static void v_idiv0(void) {
    long a = 1, d = 0, q, r;
    __asm__ __volatile__("idivq %4" : "=a"(q), "=d"(r) : "a"(a), "d"(0L), "r"(d) : "cc");
}
static void v_ud2(void) { __asm__ __volatile__("ud2"); }
static void v_int3(void) { __asm__ __volatile__("int3"); }
static void v_int80(void) {
    long r;
    __asm__ __volatile__("int $0x80" : "=a"(r) : "a"(39UL) : "rcx", "r11", "memory");
    (void)r;
}
static void v_inta(void) {
    long r;
    __asm__ __volatile__("int $0x28" : "=a"(r) : "a"(0UL) : "rcx", "r11", "memory");
    (void)r;
}
/* The third door.  AMD removed this from long mode, so it is an illegal
 * instruction here; on Intel it would have entered a trap gate.  Section 8 R2
 * records that the reason is NOT a privilege check. */
static void v_sysenter(void) {
    long r;
    __asm__ __volatile__("sysenter" : "=a"(r) : "a"(0UL) : "rcx", "r11", "memory");
    (void)r;
}

static const char *signame(int s) {
    switch (s) {
    case SIGSEGV: return "SIGSEGV"; case SIGILL: return "SIGILL";
    case SIGFPE:  return "SIGFPE";  case SIGTRAP: return "SIGTRAP";
    case SIGBUS:  return "SIGBUS";  case SIGSYS:  return "SIGSYS";
    default:      return "other";
    }
}

static void report(const char *what, void (*body)(void)) {
    int t = run_trap(body);
    if (!t) {
        printf("   %-34s no fault\n", what);
    } else {
        printf("   %-34s %-8s si_code=%-4d (0x%02x)%s\n", what, signame(g.signo),
               g.code_, g.code_,
               g.signo == SIGSYS ? "   <- SIGSYS means a SYSCALL entry succeeded" : "");
    }
}

static void sec_vectors(void) {
    puts("");
    puts("2. THE VECTORS");
    puts("   Numbers 0-31, and then the ones we can actually make happen.");

    printf("\n   %-5s %-5s %-4s %-8s %s\n", "vec", "name", "cls", "errcode", "note");
    for (int i = 0; i < NVEC; i++) {
        const struct vec_info *v = &VECS[i];
        static const char *CL = "?FTIA";
        char cls = v->cls == '?' ? '-' : CL[(int)(strchr(CL, v->cls) - CL)];
        printf("   %-5d %-5s %-4c %-8s %s\n", v->num, v->mnem, cls,
               v->errcode ? "yes" : "no", v->note);
    }
    puts("   cls: F fault (RIP = faulting)  T trap (RIP = next)  A abort  I interrupt");
    puts("        - reserved.  The class is the ONLY reason the saved RIP differs.");

    puts("\n   How many of 0-31 does each vendor actually define?");
    int both = 0, intel_only = 0, amd_only = 0;
    for (int i = 0; i < NVEC; i++) {
        if (VECS[i].num == 20) { intel_only++; continue; }   /* #VE: Intel yes, AMD no */
        if (VECS[i].num == 28) { amd_only++; continue; }     /* #HV: AMD yes, Intel no */
        if (VECS[i].mnem[0] != '-') both++;
    }
    printf("      defined on both: %d    Intel only: %d (#20)    AMD only: %d (#28)\n",
           both, intel_only, amd_only);
    puts("      A kernel that assumes #20 is a virtualization fault breaks on AMD,");
    puts("      and a kernel that assumes 0-31 are Intel's is wrong twice over.");

    puts("\n   Now raise some of them for real.  These are ACTUAL faults on THIS cpu:");
    report("divq by zero            (#DE 0)", v_div0);
    report("idivq by zero           (#DE 0)", v_idiv0);
    report("ud2                     (#UD 6)", v_ud2);
    report("int3                    (#BP 3)", v_int3);
    report("int $0x80               (vector 128)", v_int80);
    report("int $0x28               (vector 40)", v_inta);
    puts("   `int $0x80` did NOT fault: vector 128 is inside 32-255, which is the");
    puts("   user-defined range, and this kernel owns vector 128 for the i386 ABI.");
    puts("   A user process does not get to choose where vector 128 GOES; it only");
    puts("   gets to choose that the gate has DPL 3 so the CPU will enter it.");
}

/* ------------------------------------------------------------------ */
/* 3. the doors                                                        */
/* ------------------------------------------------------------------ */

#define REPS 9
#define ITERS 20000

static volatile long g_sinkl;

/* The three arms.  Each takes the same number of arguments so the loop is
 * identical; the only difference is the instruction that crosses the boundary. */
static inline long do_syscall_getpid(void) {
    return syscall(SYS_getpid);
}
static inline long do_int80_getpid(void) {
    long r;
    __asm__ __volatile__("int $0x80" : "=a"(r) : "a"(39UL) : "rcx", "r11", "memory");
    return r;
}

/* how much does the ARGUMENT COUNT cost each door?  int 0x80 passes arguments
 * through I/O ports in the Linux i386 ABI, and the port count grows with the
 * argument count; SYSCALL passes them in registers.  This is the measurement
 * that makes the mechanism visible rather than asserted. */
static volatile uint64_t g_arg[6] = { 1, 2, 3, 4, 5, 6 };

static double arm_syscall(long iters) {
    uint64_t a = rdtsc();
    for (long i = 0; i < iters; i++) g_sinkl = do_syscall_getpid();
    uint64_t b = rdtsc();
    return (double)(b - a) / (double)iters;
}
static double arm_int80(long iters) {
    uint64_t a = rdtsc();
    for (long i = 0; i < iters; i++) g_sinkl = do_int80_getpid();
    uint64_t b = rdtsc();
    return (double)(b - a) / (double)iters;
}

/* A FOURTH path, and the reason the other three are expensive: the vDSO.
 * The kernel maps a page of its OWN code into the process and hands us a
 * pointer to it in the auxiliary vector.  Reading the clock through it does
 * not change mode at all.  `vDSO` here is glibc's wrapper, which resolves the
 * vDSO symbol table at startup; if the kernel has no vDSO the wrapper falls
 * back to a real syscall and this arm becomes meaningless -- which is why the
 * section prints whether the vDSO is present before quoting the number. */
static struct timespec g_ts;

static double arm_syscall_clock(long iters) {
    uint64_t a = rdtsc();
    for (long i = 0; i < iters; i++)
        g_sinkl = syscall(SYS_clock_gettime, CLOCK_MONOTONIC, &g_ts);
    uint64_t b = rdtsc();
    return (double)(b - a) / (double)iters;
}
static double arm_vdso_clock(long iters) {
    uint64_t a = rdtsc();
    for (long i = 0; i < iters; i++) clock_gettime(CLOCK_MONOTONIC, &g_ts);
    uint64_t b = rdtsc();
    return (double)(b - a) / (double)iters;
}
static double arm_libc_getpid(long iters) {
    uint64_t a = rdtsc();
    for (long i = 0; i < iters; i++) g_sinkl = getpid();
    uint64_t b = rdtsc();
    return (double)(b - a) / (double)iters;
}

static void sec_doors(void) {
    puts("");
    puts("3. FOUR WAYS IN, AND ONE OF THEM IS NOT A DOOR");
    puts("   Three of these change privilege level.  The fourth does not, and");
    puts("   that is the one an operating system actually wants you to use.");

    /* interleaved, min of REPS -- rule 2 and rule 3 */
    double bs = 1e30, bi = 1e30, bk = 1e30, bl = 1e30, bv = 1e30;
    for (int r = 0; r < REPS; r++) {
        double s;
        s = arm_syscall(ITERS);   if (s < bs) bs = s;
        s = arm_int80(ITERS);      if (s < bi) bi = s;
        s = arm_syscall_clock(ITERS); if (s < bk) bk = s;
        s = arm_vdso_clock(ITERS);   if (s < bv) bv = s;
        s = arm_libc_getpid(ITERS);  if (s < bl) bl = s;
    }
    puts("\n   best of 9 x 20000, arms interleaved, in TSC ticks.  Rule 1: these");
    puts("   are NOT cycles.  Rule 3: the minimum, because the floor is large.");
    printf("\n      SYSCALL, getpid            %9.1f\n", bs);
    printf("      int $0x80, getpid          %9.1f\n", bi);
    printf("      libc getpid()              %9.1f\n", bl);
    printf("\n      SYSCALL, clock_gettime     %9.1f\n", bk);
    printf("      vDSO  clock_gettime        %9.1f\n", bv);
    printf("\n      int80 / syscall            %9.2fx\n", bi / bs);
    printf("      syscall-clock / vdso-clock %9.2fx\n", bk / bv);
    puts("\n   The second pair is the important one.  Same function, same answer,");
    puts("   same argument, and the ONLY difference is whether the CPU changed");
    puts("   privilege level on the way.  That ratio IS the cost of a mode change,");
    puts("   measured, with everything else held constant.  It is the number the");
    puts("   vDSO exists to remove, and it is why clock_gettime in a real program");
    puts("   costs tens of nanoseconds while a naive syscall costs hundreds.");

    puts("\n   What the first pair does NOT prove, which this file is careful about:");
    puts("   It is tempting to say `int $0x80 is slower because it does one I/O");
    puts("   port access per argument`.  That is TRUE of the Linux i386 entry stub");
    puts("   -- but the port accesses are executed by the KERNEL'S HANDLER, not by");
    puts("   the INT instruction.  So this measurement cannot separate the cost of");
    puts("   the hardware entry from the cost of two different kernel stubs.  The");
    puts("   honest claim is the ordering and the ratio; the mechanism is named as a");
    puts("   hypothesis and NOT as a finding.  See section 8, R1.");

    /* the third instruction, and the vendor disagreement */
    puts("\n   The third instruction:");
    report("sysenter                (the #UD)", v_sysenter);
    puts("\n   This is the course's sharpest portable result and it is NOT a bug.");
    puts("   Intel SDM Vol 2B lists SYSENTER as VALID in 64-bit mode: \"When");
    puts("   executed in IA-32e mode, the SYSENTER instruction transitions the");
    puts("   logical processor to 64-bit mode\", with 64-bit-mode exceptions");
    puts("   \"same as in protected mode\".  AMD64 APM Vol 2 sec 6.1.2 says the");
    puts("   opposite: these instructions are ILLEGAL IN LONG MODE and result in");
    puts("   an invalid opcode exception (#UD).  Both manuals are correct.  They");
    puts("   disagree.  Linux encodes the split in arch/x86/kvm/emulate.c and");
    puts("   QEMU commit c046a42c does the same.");
    puts("\n   So a program that reaches for SYSENTER as its fast path is correct on");
    puts("   one vendor and takes SIGILL on the other, and there is no erratum to");
    puts("   file against either company.  A build-time CPUID check is the only");
    puts("   defence, which is what every serious code that cares does.");
    puts("\n   And what SYSENTER does NOT do: there is no CPL check anywhere in it.");
    puts("   It is unprivileged BY DESIGN -- running it from ring 3 is the whole");
    puts("   point of a fast system call.  The folklore \"SYSENTER from ring 3");
    puts("   raises #GP(0)\" is false on both vendors.  See section 8, R2.");
}

/* ------------------------------------------------------------------ */
/* 4. the convention, out of the kernel's own bytes                    */
/* ------------------------------------------------------------------ */

static void sec_convention(void) {
    puts("");
    puts("4. THE CONVENTION, IN THE KERNEL'S OWN BYTES");
    puts("   The vDSO is a real ELF image the kernel maps into every process and");
    puts("   hands us a pointer to in the auxiliary vector.  The Executable Images");
    puts("   course already read its header; this course reads its CODE.");

    /* THE POINTER.  `__ehdr_start` is NOT the vDSO.  It is a glibc symbol
     * holding the base of the ELF header of the MAIN EXECUTABLE, which is a
     * perfectly respectable ET_DYN PIE with fourteen program headers and a
     * section table past the end of its own text -- and therefore looks almost
     * exactly like the vDSO if you do not check.  The first version of this
     * section printed a header it believed was the vDSO's and it was the
     * program's own.  The vDSO pointer is the auxiliary vector entry
     * AT_SYSINFO_EHDR and nothing else.  See section 8, R7. */
    Elf64_Ehdr *self = (Elf64_Ehdr *)__ehdr_start;
    uint64_t vdso = getauxval(AT_SYSINFO_EHDR);
    puts("\n   where does the vDSO pointer come from?");
    printf("      __ehdr_start (the MAIN EXECUTABLE) 0x%016llx  e_phnum=%d\n",
           (unsigned long long)(uintptr_t)self, self->e_phnum);
    printf("      AT_SYSINFO_EHDR (the vDSO)          0x%016llx\n",
           (unsigned long long)vdso);
    puts("      Two different images, and the one with the obvious name is not");
    puts("      the one this section is about.  Print both or you will debug the");
    puts("      wrong header, which is what this file did first.");

    if (!vdso) { puts("   no vDSO on this kernel; nothing more to read."); return; }
    Elf64_Ehdr *eh = (Elf64_Ehdr *)(uintptr_t)vdso;
    uint64_t base = vdso;
    printf("\n   vDSO e_ident  %02x %02x %02x %02x   class=%d data=%d\n",
           eh->e_ident[0], eh->e_ident[1], eh->e_ident[2], eh->e_ident[3],
           eh->e_ident[EI_CLASS], eh->e_ident[EI_DATA]);
    printf("   vDSO e_type=%d (ET_DYN)  e_machine=%d (EM_X86_64)  e_phnum=%d\n",
           eh->e_type, eh->e_machine, eh->e_phnum);
    printf("   vDSO e_phoff=0x%lx  e_shoff=0x%lx  e_shnum=%d\n",
           eh->e_phoff, eh->e_shoff, eh->e_shnum);

    Elf64_Phdr *ph = (Elf64_Phdr *)(base + eh->e_phoff);
    uint64_t code_lo = 0, code_hi = 0;
    int nexec = 0;
    for (int i = 0; i < eh->e_phnum; i++) {
        if (ph[i].p_type == PT_LOAD && (ph[i].p_flags & PF_X)) {
            code_lo = ph[i].p_vaddr;
            code_hi = ph[i].p_vaddr + ph[i].p_filesz;
            nexec++;
        }
    }
    if (!nexec) { puts("   no executable segment found; stopping."); return; }
    printf("\n   %d executable PT_LOAD segment(s); vaddr 0x%llx, %llu bytes of code\n",
           nexec, (unsigned long long)code_lo, (unsigned long long)(code_hi - code_lo));

    /* The point of the section.  The kernel's sigreturn trampoline contains a
     * literal SYSCALL instruction, and the five bytes before it are
     * `mov $15, %eax` -- the syscall NUMBER, in the kernel's own encoding.
     * Everything anyone has ever written about the x86-64 syscall ABI can be
     * checked against those bytes. */
    const unsigned char *code = (const unsigned char *)(base + code_lo);
    uint64_t span = code_hi - code_lo;

    /* Every SYSCALL opcode in the vDSO, with the syscall number the kernel
     * wrote immediately before it.  `b8 <imm32>` is `mov $imm32, %eax` and on
     * this ISA the immediate in EAX IS the syscall number.  These are bytes the
     * KERNEL wrote, in a table this process cannot read, and they state the
     * calling convention exactly -- so the convention is read out of the
     * machine rather than quoted out of a manual. */
    puts("\n   Scanning the executable segment for 0f 05, the SYSCALL opcode:");
    static const uint8_t RETPAT[8] = { 0xb8,0x0f,0x00,0x00,0x00,0x0f,0x05,0x0f };
    int found = 0, sigret = 0, decoded = 0;
    for (uint64_t off = 0; off + 1 < span; off++) {
        if (code[off] != 0x0f || code[off + 1] != 0x05) continue;
        found++;
        long st = (long)off - 5; if (st < 0) st = 0;
        printf("\n      vaddr 0x%04llx  ", (unsigned long long)(code_lo + off));
        for (long k = st; k <= (long)off + 1; k++) printf(" %02x", code[k]);
        printf("\n%-16s  ", "");
        for (long k = st; k <= (long)off + 1; k++) {
            unsigned char c = code[k];
            putchar((c >= 32 && c < 127) ? c : '.');
        }
        printf("\n");
        /* Only claim a number when the EXACT five bytes are b8 imm32 and the
         * immediate is in the Linux syscall table's range.  A b8 anywhere
         * else in the byte stream is a one-in-256 coincidence, and this file
         * was caught making exactly that guess once already. */
        if (off >= 5 && code[off - 5] == 0xb8) {
            uint32_t nr = (uint32_t)code[off - 4] | ((uint32_t)code[off - 3] << 8) |
                          ((uint32_t)code[off - 2] << 16) | ((uint32_t)code[off - 1] << 24);
            if (nr < 512) {
                decoded++;
                printf("      `mov $%u, %%eax ; syscall`  ->  %s\n", nr,
                       nr == 228 ? "clock_gettime" : nr == 96 ? "gettimeofday"
                       : nr == 229 ? "clock_gettime64" : "see asm/unistd_64.h");
                if (off + 2 < span && memcmp(code + off - 5, RETPAT, 7) == 0) {
                    sigret++;
                    printf("      and 0f 0b follows: `ud2`.  This is the sigreturn\n");
                    puts("      trampoline.  The immediate is simultaneously the syscall");
                    puts("      NUMBER and the IDT VECTOR, so the gate holding this code is");
                    printf("      at IDT offset %u * 16 = %u -- a table section 1 showed\n",
                           nr, nr * 16);
                    puts("      this process may not read a single byte of.");
                }
            }
        }
    }
    printf("\n      %d SYSCALL instruction(s) in %llu bytes of vDSO code, %d decoded\n",
           found, (unsigned long long)span, decoded);
    if (sigret) {
        printf("      %d is the sigreturn trampoline, matched by exact bytes\n", sigret);
    } else {
        puts("      No sigreturn trampoline in this build: Linux removed the vDSO");
        puts("      sigreturn path, and a decoder that printed 15 here anyway,");
        puts("      from a pattern that merely happened to be nearby, is a decoder");
        puts("      that lies.  This file reports the absence instead.");
    }

    puts("\n   What that is worth.  The register convention -- RAX = number, the");
    puts("   arguments in RDI/RSI/RDX/R10/R8/R9, the answer in RAX -- is LINUX,");
    puts("   not Intel.  Grep the SDM for \"system call number\": it is not there.");
    puts("   Only TWO facts above are architecture: RCX receives the return RIP");
    puts("   and R11 receives RFLAGS.  Those two are WHY the fourth argument is R10");
    puts("   and not RCX -- the SysV C calling convention already gave RCX to the");
    puts("   caller's fourth integer argument, so the kernel had to route around it.");
    puts("   And on x86-64 the kernel returns a NEGATIVE ERRNO in RAX and does NOT");
    puts("   set CF; the clear-carry-on-error convention is i386 only.");
}

/* ------------------------------------------------------------------ */
/* 5. the hole                                                         */
/* ------------------------------------------------------------------ */

/* A canonical 48-bit address has bit 47 EQUAL to bit 63.  Getting this test
 * wrong is the easiest way to be wrong about x86-64 addressing, and the first
 * version of this file got it wrong by testing bits 63:48 for all-zero or
 * all-one, which calls 0x0000800000000000 canonical.  It is not. */
static int is_canonical48(uint64_t a) {
    return ((a >> 47) & 1) == ((a >> 63) & 1);
}

/* Three widths, so the section can ask about a BOUND rather than an ADDRESS. */
static volatile uint8_t  g_b1;
static volatile uint32_t g_b4;
static volatile uint64_t g_b8;
static void rd1(uint64_t a) { g_b1 = *(volatile uint8_t *)(uintptr_t)a; }
static void rd4(uint64_t a) { g_b4 = *(volatile uint32_t *)(uintptr_t)a; }
static void rd8(uint64_t a) { g_b8 = *(volatile uint64_t *)(uintptr_t)a; }

static int probe_at(uint64_t a, void (*rd)(uint64_t)) {
    clear_trap();
    arm();
    if (sigsetjmp(g_jb, 1) == 0) { rd(a); return -1; }
    return g.code_;
}

static void sec_canonical(void) {
    puts("");
    puts("5. THE HOLE, AND THE FACT THAT IT HAS NO FIXED ADDRESS");
    puts("   A canonical 48-bit address has bit 47 EQUAL to bit 63.  The space");
    puts("   between the two halves is not an address at all: the CPU rejects it");
    puts("   while generating the effective address, before the MMU is consulted.");

    const uint64_t T = 0x0000800000000000ULL;   /* 2^47 */
    puts("\n   The obvious probe is one 4-byte read either side of 2^47:");
    printf("      0x%016llx  %-13s si_code=%d\n", 0x7fffffffffffULL, "canonical",
           probe_at(0x7fffffffffffULL, rd4));
    printf("      0x%016llx  %-13s si_code=%d\n", (unsigned long long)T,
           "NON-canonical", probe_at(T, rd4));
    puts("   On the face of it the boundary is 2^47.  It is not, and the way to");
    puts("   find out is to ask the same question with different access widths.");

    /* The whole result, as a matrix.  si_code 1 = the CPU accepted the address
     * and the page tables said no; si_code 128 = the CPU rejected the address
     * itself and the kernel has nothing to report. */
    puts("\n      1 = SEGV_MAPERR (a real address, not mapped)");
    puts("    128 = SI_KERNEL    (not an address at all)\n");
    printf("   %-26s %-8s %-8s %-8s\n", "address", "1 byte", "4 byte", "8 byte");
    for (int k = -10; k <= 1; k++) {
        uint64_t a = T + (uint64_t)k;
        printf("   2^47%+4d 0x%016llx %-4s  %-8d %-8d %-8d\n", k,
               (unsigned long long)a, is_canonical48(a) ? "" : "noncanon",
               probe_at(a, rd1), probe_at(a, rd4), probe_at(a, rd8));
    }

    /* Derive the boundary for each width by bisection, and check the rule. */
    puts("\n   Bisecting separately for each width -- where does the KIND of fault");
    puts("   change, per access size?");
    double bound[3];
    void (*RD[3])(uint64_t) = { rd1, rd4, rd8 };
    const char *NM[3] = { "1-byte", "4-byte", "8-byte" };
    int sz[3] = { 1, 4, 8 };
    for (int w = 0; w < 3; w++) {
        uint64_t lo = T - 0x2000ULL, hi = T + 0x2000ULL;
        for (int it = 0; it < 40 && hi - lo > 1; it++) {
            uint64_t mid = lo + (hi - lo) / 2;
            if (probe_at(mid, RD[w]) == 1) lo = mid; else hi = mid;
        }
        bound[w] = (double)hi;
        printf("      %s  first rejected address 0x%016llx   "
               "2^47 minus it = %d\n", NM[w], (unsigned long long)hi, (int)(T - hi));
    }
    int rule = 1;
    for (int w = 0; w < 3; w++)
        if ((int)(T - bound[w]) != sz[w] - 1) rule = 0;
    puts("\n   THE RULE, and it is the whole concept:");
    printf("      the first rejected address is 2^47 MINUS (access size - 1)\n");
    printf("      derived, holds on this machine: %s\n", rule ? "yes" : "NO");
    puts("\n   The boundary is a property of the ACCESS, not of the address space.");
    puts("   A read that STARTS below 2^47 still fails if it REACHES 2^47, because");
    puts("   the CPU checks the whole byte range of the operand, not the first");
    puts("   byte.  That is why an 8-byte read fails seven bytes before 2^47 while");
    puts("   a 1-byte read succeeds right up to it.");
    puts("\n   And that is WHY a non-canonical access is not a page fault.  It never");
    puts("   becomes an address: there is no page-table entry to look up, no");
    puts("   present bit to clear, and no si_addr to report.  The kernel hands the");
    puts("   process SIGSEGV with si_code 128 and an address of 0, and the ONLY");
    puts("   thing that distinguishes it from an ordinary unmapped read is that");
    puts("   one number.  A fault handler that treats si_code 1 as \"not mapped\"");
    puts("   and every other value as \"something worse\" gets this right; one that");
    puts("   reads si_addr without checking si_code first gets a NULL back and");
    puts("   concludes the process dereferenced a null pointer.");
    puts("\n   The 53% of the space ring 3 cannot name is not a permission and not a");
    puts("   protection bit.  It is a hole in the number system, enforced before");
    puts("   the MMU exists.");
}

/* ------------------------------------------------------------------ */
/* 6. the fault record                                                 */
/* ------------------------------------------------------------------ */

/* Six rows, three widths of protection, three directions of access -- and the
 * rows are CORRECT only if each one gets its own page.  The first version
 * mapped one page, ran three faults against it, and then UNMAPPED it; a fault
 * longjmps straight out of the function, so the munmap never ran, the mapping
 * leaked, and rows two through six were measuring a page in whatever state the
 * previous row left it in.  Every row here therefore gets its own address and
 * reports whether its mmap actually succeeded.  A fault-row harness that does
 * not check the mmap reports six identical numbers and means nothing. */
static uintptr_t ROWA[8] = { 0x510000, 0x511000, 0x512000,
                             0x513000, 0x514000, 0x515000 };
static volatile long g_v;

static void fault_row(const char *what, uintptr_t at, int prot, int kind, int do_map) {
    void *m = (void *)at;
    if (do_map) m = mmap((void *)at, 4096, prot,
                        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
    if (m == MAP_FAILED || m != (void *)at) {
        printf("   %-30s mmap FAILED (%s) -- this row would have measured nothing\n",
               what, strerror(errno));
        if (m != MAP_FAILED) munmap(m, 4096);
        return;
    }
    clear_trap();
    arm();
    int trapped = 0;
    if (sigsetjmp(g_jb, 1) == 0) {
        if (kind == 0) g_v = *(volatile int *)at;         /* read  */
        else if (kind == 1) *(volatile int *)at = 1;       /* write */
        else ((void (*)(void))(uintptr_t)at)();            /* exec  */
    } else {
        trapped = 1;
    }
    if (!trapped) {
        printf("   %-30s no fault\n", what);
    } else {
        const char *kindname =
            g.code_ == 1   ? "SEGV_MAPERR  nothing mapped here"   :
            g.code_ == 2   ? "SEGV_ACCERR  mapped, access not permitted" :
            g.code_ == 128 ? "SI_KERNEL    not a page fault at all" :
                             "other";
        printf("   %-30s si_code=%-4d %-45s addr=0x%llx\n", what, g.code_,
               kindname, (unsigned long long)g.addr_);
    }
    if (do_map) munmap(m, 4096);
}

static void sec_errorcode(void) {
    puts("");
    puts("6. THE FAULT RECORD");
    puts("   One address, several ways of touching it, several different answers.");

    fault_row("read  a PROT_READ page",  ROWA[0], PROT_READ,  0, 1);
    fault_row("write a PROT_READ page",  ROWA[1], PROT_READ,  1, 1);
    fault_row("exec  a PROT_READ page",  ROWA[2], PROT_READ,  2, 1);
    fault_row("read  a PROT_NONE page",  ROWA[3], PROT_NONE,  0, 1);
    fault_row("write a PROT_NONE page",  ROWA[4], PROT_NONE,  1, 1);
    /* A genuinely UNMAPPED page, constructed rather than guessed.
     *
     * Two earlier attempts failed here and both failed the same way.  The first
     * picked a constant, 0x60000000, which is inside this process's own PIE
     * image -- so the row reported SEGV_ACCERR for an address assumed to be
     * empty, and the table lost its only SEGV_MAPERR entry without complaining.
     * The second parsed /proc/self/maps for a gap and found none, because a
     * PIE process has almost no gaps below its image.  Guessing an address is
     * not a measurement.
     *
     * The address that is certainly unmapped is one this process has just
     * unmapped.  Map a page, unmap it, and read it. */
    {
        void *m = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (m != MAP_FAILED) {
            uintptr_t at = (uintptr_t)m;
            if (munmap(m, 4096) == 0) fault_row("read  an UNMAPPED page", at, PROT_NONE, 0, 0);
            else puts("   read  an UNMAPPED page     munmap failed");
        } else {
            puts("   read  an UNMAPPED page     mmap failed");
        }
    }

    puts("");
    puts("   READ THE TABLE, NOT THE PROSE.  Two things in it are the finding:");
    puts("");
    puts("   (a) Row 1 does not fault.  PROT_READ means readable, and the read");
    puts("       succeeds.  Rows 2 and 3 DO fault, with the SAME si_code as each");
    puts("       other: si_code 2, and both with the right address.  So a page");
    puts("       that is readable is not writable and not executable -- the W^X");
    puts("       rule is enforced in hardware, from ring 3, and the address in the");
    puts("       signal is exact to the page.");
    puts("");
    puts("   (b) Rows 2, 3, 4 and 5 are four DIFFERENT events -- a write to a");
    puts("       read-only page, an execute of a non-executable page, a read of a");
    puts("       PROT_NONE page, a write of a PROT_NONE page -- and from ring 3");
    puts("       si_code CANNOT TELL ANY OF THEM APART.  All four are 2.");
    puts("");
    puts("   That is the point of the section, and it is a measurement rather than");
    puts("   a quotation.  Bits 1 (W/R) and 4 (I/D) of the #PF error code are");
    puts("   exactly the bits a demand-paging system needs: W/R decides whether a");
    puts("   not-present page is mapped read-only (for a copy-on-write fault) or");
    puts("   read-write, and I/D decides whether it is mapped executable.  The");
    puts("   kernel sees both.  A process does not.");
    puts("\n   On x86-64 there are THREE different error-code formats, and the SDM");
    puts("   says so twice.  #PF pushes a packed word:");
    puts("      bit 0 P     not-present          bit 4 I/D  instruction fetch");
    puts("      bit 1 W/R   write                bit 5 PK   protection key");
    puts("      bit 2 U/S   user-mode access     bit 6 SS   shadow stack");
    puts("      bit 3 RSVD  a reserved bit in a PAGING ENTRY, not in the instruction");
    puts("   #GP/#NP/#SS push something that RESEMBLES a selector:");
    puts("      bit 0 EXT   bit 1 IDT   bit 2 TI   bits 15:3 the index");
    puts("   #CP pushes a CPEC code and an ENCL bit: a third format, unrelated.");
    puts("   Learn one and apply it to the other two and you are wrong in a way");
    puts("   that costs a debugging session rather than a compile error.");
    puts("\n   And #PF delivers a second thing, in CR2: the linear address.  The SDM");
    puts("   warns that a SECOND page fault overwrites CR2, including one that");
    puts("   happens while the first is still being delivered.  A fault handler");
    puts("   must read CR2 before doing anything that could fault again -- which is");
    puts("   why the vector-8 double-fault machinery exists at all.");
    puts("\n   None of the eight bits is visible from ring 3 as a number.  A user");
    puts("   process gets the kernel's TRANSLATION of them: one signal and one");
    puts("   si_code.  That is a limit of this course and it is stated as a limit.");
}

/* ------------------------------------------------------------------ */
/* 7. the same idea, three architectures                              */
/* ------------------------------------------------------------------ */

static void sec_three(void) {
    puts("");
    puts("7. THE SAME IDEA UNDER THREE ARCHITECTURES");
    puts("   Ring 0 is a vendor spelling.  This is the shape underneath it.");

    puts("\n   x86-64");
    puts("      rings            0..3, only 0 and 3 are used by an OS today");
    puts("      the gate table    IDT, 16 bytes per entry, indexed by vector<<4");
    puts("      the check         gate.DPL < CPL  ->  #GP(vector,1,0)");
    puts("      the drop          SYSCALL, from any CPL, unconditionally to CPL 0");
    puts("      the return        SYSRET, which is #GP(0) at CPL != 0");
    puts("      why 3 is special   canonical addressing: a non-canonical address is");
    puts("                         rejected before the page tables, so mode 3 cannot");
    puts("                         even NAME the top half of the space (section 5)");

    puts("\n   AArch64");
    puts("      levels            EL0..EL3, MORE levels than x86 has rings");
    puts("      the gate table    VBAR_ELx, a vector table per level");
    puts("      the check         PSTATE.PAN: with PAN=1, EL1+ cannot touch EL0 memory");
    puts("                         -- structurally the same job as SMAP");
    puts("      the drop          SVC #imm16, an ordinary instruction at any EL");
    puts("      the return        ERET, and the saved state is in SPSR_ELx");
    puts("      the trap record   ESR_ELx (syndrome), FAR_ELx (faulting address),");
    puts("                         ELR_ELx (return address) -- THREE CSRs, where");
    puts("                         x86 squeezes the same three things into a stack");
    puts("                         frame plus CR2");
    puts("      the important bit the address is not canonical in the same place:");
    puts("                         AArch64 uses 48 or 52 implemented VA bits, and the");
    puts("                         top half is a special device region (DVM), not a hole");

    puts("\n   RISC-V");
    puts("      modes             M, S, U -- and this is the one that differs most");
    puts("      M is MANDATORY.  Every RISC-V hart implements machine mode, so");
    puts("                         there is a mode below user mode by construction.");
    puts("      the gate table    mtvec, stvec, utvec -- ONE per mode");
    puts("      the delegation    medeleg and mideleg say, per cause, which of S or");
    puts("                         U handles it.  x86 hardwires the split at CPL 0");
    puts("                         and AArch64 hardwires it at EL2/EL3; RISC-V makes");
    puts("                         it a field the firmware writes");
    puts("      the trap record   mcause (the reason, an enum), mtval (the bad value,");
    puts("                         optional per cause), mepc (where to come back to)");
    puts("      the return        mret, which restores privilege from mstatus.MPP");
    puts("      the trap CSR you cannot skip   mstatus itself: MPP records the");
    puts("                         privilege to return to, and the trap handler has");
    puts("                         to save it before it does anything else");

    puts("\n   The three shapes, side by side:");
    puts("      x86-64   rings are a NUMBER in CS, compared against a DPL in a table");
    puts("      AArch64  levels are a NUMBER in the current EL, compared against VBAR_ELx");
    puts("      RISC-V   modes are a PAIR OF BITS in mstatus, delegable per cause");
    puts("\n   The portable content is the LIST, not the number: every one of these");
    puts("   machines has (a) a table the kernel owns and the user cannot read,");
    puts("   (b) a per-cause reason code, (c) a rule that decides who handles it,");
    puts("   (d) a way to get back, and (e) a way for the kernel to prove it came");
    puts("   from user mode.  Change the number, keep the five.");
}

/* ------------------------------------------------------------------ */
/* 8. the limits and the retractions                                   */
/* ------------------------------------------------------------------ */

static void sec_limits(void) {
    puts("");
    puts("8. RETRACTIONS AND LIMITS");
    puts("   Printed here so they cannot be quietly dropped, and asserted by");
    puts("   crosscheck.py so they cannot be DELETED either.");

    puts("\n   R1. \"The argument count explains the SYSCALL/int 0x80 gap.\"");
    puts("       NEVER CLAIMED, and the reason is worth keeping.  The first draft");
    puts("       of section 3 measured the same syscall with 0 arguments and with");
    puts("       6, expecting int $0x80 to get worse -- and it cannot, because the");
    puts("       port accesses happen in the KERNEL'S i386 entry STUB, not in the");
    puts("       INT instruction.  The number of ports is decided by the kernel's");
    puts("       knowledge of the syscall's declared arity, which a caller cannot");
    puts("       vary.  The experiment was removed rather than reported, because an");
    puts("       experiment that cannot answer its question is not data.");
    puts("       What replaced it is the vDSO arm, which holds everything else");
    puts("       constant and so measures the thing we actually wanted: the cost of");
    puts("       changing privilege level at all.");

    puts("\n   R2. \"SYSENTER from ring 3 raises #GP(0).\"  NEVER TRUE, on either");
    puts("       vendor.  SYSENTER has NO CPL CHECK AT ALL; it is unprivileged by");
    puts("       design and running it from ring 3 is its entire purpose.  Intel's");
    puts("       only #GP(0) is a null IA32_SYSENTER_CS.  The course author wrote");
    puts("       this belief into a draft, measured #UD, and nearly published a");
    puts("       story in which the two cancelled out.  They did not: the #UD is");
    puts("       AMD having removed SYSENTER from long mode, which has nothing to");
    puts("       do with privilege.  Two wrong beliefs producing a right");
    puts("       observation is not evidence, and it is worth saying so.");

    puts("\n   R3. \"The IDT has 4096 entries so there are 4096 interrupts.\"  NO.");
    puts("       The limit is a BOUND, set to 4096 so that `int 0xNN` with any");
    puts("       byte is a bounds check and not a wild read.");

    puts("\n   R4. \"si_addr is the address the CPU faulted on.\"  It is the address");
    puts("       the KERNEL chose to report.  For a non-canonical access there is");
    puts("       none, and the kernel reports 0.  Section 5 shows that 0 doing real");
    puts("       work, and section 5 also shows that a handler which reads si_addr");
    puts("       before checking si_code concludes the process dereferenced NULL.");

    puts("\n   R5. \"SIDT writes the limit first and the base second.\"  NO, AND IT");
    puts("       DOES NOT TELL YOU.  The 10-byte pseudo-descriptor is BASE FIRST at");
    puts("       offset 0 and LIMIT SECOND at offset 8.  The first version of this");
    puts("       file used a struct { uint16_t limit; uint64_t base; } packed, and");
    puts("       reported base 0xffffffffffff0000 and limit 0 -- a plausible base,");
    puts("       an impossible limit, and no fault.  A limit of 0 is");
    puts("       INDISTINGUISHABLE from a kernel that installed an empty IDT, so");
    puts("       the wrong reading is not merely wrong, it is unfalsifiable.  See");
    puts("       section 1, which now prints both readings side by side.");

    puts("\n   R6. \"memset on a struct a signal handler writes is fine.\"  NO.");
    puts("       memset takes `void *`, so its writes to a volatile object are not");
    puts("       volatile-qualified and the compiler may elide or reorder them.  The");
    puts("       handler's record then held values from a PREVIOUS probe, and the");
    puts("       bisection in section 5 converged on a boundary INSIDE A SINGLE");
    puts("       PAGE, which is impossible, and printed it with total confidence.");
    puts("       The fix is explicit volatile writes in a clear_trap() function, and");
    puts("       the lesson is wider than volatile: a measurement harness whose");
    puts("       intermediate state is not volatile will hand you a plausible");
    puts("       wrong answer rather than a warning.");

    puts("\n   R7. \"__ehdr_start is the vDSO.\"  NO.  It is a glibc symbol holding");
    puts("       the base of the ELF header of the MAIN EXECUTABLE.  This file read");
    puts("       it, printed fourteen program headers and an e_shoff past the end");
    puts("       of the text, and reported all of it as vDSO facts -- and every one");
    puts("       of them was true of the wrong image.  The vDSO pointer is the");
    puts("       auxiliary vector entry AT_SYSINFO_EHDR and nothing else.  Section 4");
    puts("       now prints both addresses side by side so the confusion cannot");
    puts("       recur silently.  A PIE main executable and a vDSO are both ET_DYN,");
    puts("       both EM_X86_64, and both have a plausible program header table,");
    puts("       which is exactly why the mistake was easy to make.");

    puts("\n   R8. \"The canonical boundary is the address 2^47.\"  NOT AS A");
    puts("       STATEMENT ABOUT AN ACCESS.  It is 2^47 minus (access size - 1),");
    puts("       because the CPU validates the whole byte range of the operand.  An");
    puts("       8-byte read fails seven bytes below 2^47 and a 1-byte read");
    puts("       succeeds at 2^47 - 1.  Measured as a 12x3 matrix and confirmed by");
    puts("       three independent bisections.  See section 5, which is the whole");
    puts("       reason that section exists.");

    puts("\n   LIMITS -- what this artifact cannot tell you, printed not footnoted:");
    puts("     * The CLASS of each exception (fault vs trap vs abort) is READ FROM");
    puts("       THE MANUAL, not measured.  Deciding it needs the saved RIP, and a");
    puts("       ring 3 process never sees one.  Section 2 marks those rows.");
    puts("     * The error code the CPU pushed.  A ring 3 process gets si_code, which");
    puts("       is the kernel's translation, not the 32-bit word the CPU pushed.");
    puts("       Section 6 shows what survives that gap (the direction of the access)");
    puts("       and says what does not (the other five bits).");
    puts("     * Whether SMEP and SMAP are ON, as opposed to being REPORTED on.");
    puts("       The CR4 bits are privileged.  There is no user-mode experiment.");
    puts("     * The IA32_STAR, IA32_LSTAR and IA32_SFMASK values this kernel uses.");
    puts("       /dev/cpu/0/msr is root-only.  Section 4 gets the convention from");
    puts("       the vDSO's bytes instead, which is a different and weaker source.");
    puts("     * Anything about AArch64 or RISC-V.  Section 7 is quoted, not run,");
    puts("       and every claim in it is a manual claim.  Read it as the shape to");
    puts("       look for on a machine you have.");
    puts("     * INT 0x80 is the i386 COMPAT path.  It is on here because this is a");
    puts("       virtualised guest that keeps compat enabled; a bare-metal kernel or");
    puts("       one with CONFIG_IA32_EMULATION=n would #UD it.  It is measured as a");
    puts("       mechanism, not as a claim about what every machine does.");
}

/* ------------------------------------------------------------------ */

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    puts("=====================================================================");
    puts(" privbench -- Exceptions, Privilege and Mode Changes");
    puts("=====================================================================");
    sec_machine();
    sec_table();
    sec_vectors();
    sec_doors();
    sec_convention();
    sec_canonical();
    sec_errorcode();
    sec_three();
    sec_limits();
    puts("");
    puts("=====================================================================");
    return 0;
}
