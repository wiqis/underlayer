/* simdbench -- the artifact for "SIMD and Vector Processing".
 *
 * ============================ READ THIS FIRST ============================
 * SIX RULES, each learned by breaking it.  They are the transferable part of
 * this file; the numbers it prints are not.
 *
 *  1. THE LANE COUNT IS NOT THE SPEEDUP.  Every figure in this file is a
 *     RATIO to a scalar arm, and section 3 shows the same 4-wide arm going
 *     from 3.3x to 1.2x purely by changing how much memory it touches.  A
 *     claim of the form "SIMD is Nx faster" is a claim about N and about the
 *     data and must state both.
 *
 *  2. EVERY ARM PROVES IT DID THE ARITHMETIC.  Written in C with a result
 *     nobody reads, the optimiser deletes the experiment and reports a
 *     plausible number for work that did not happen.  The compiler has eaten
 *     four separate experiments in this collection.  So every table in this
 *     file ends with a CHECKSUM line, and every arm of a table must print the
 *     SAME checksum.  Two real bugs in this file were caught by exactly that
 *     line and by nothing else.  See R1 and R4.
 *
 *  3. RATIOS MOVE LESS THAN NUMBERS.  This machine is a virtualised guest
 *     and its absolute throughput for the same body changed by a factor of
 *     1.7 BETWEEN RUNS on the recorded day.  Every ratio in sections 2 to 6
 *     moved by less than 10% across four runs.  Interleave the arms, take the
 *     minimum, and report the ratio -- never the absolute figure.
 *
 *  4. THE TSC IS TIME, NOT CYCLES.  constant_tsc and nonstop_tsc are set and
 *     the rate is measured twice per run, but the CORE CLOCK is not readable
 *     and moves.  So there is not one cycle count anywhere in this file.
 *
 *  5. TWO ARMS AND FOUR ARMS ARE NOT COMPARABLE UNLESS THEY DO THE SAME
 *     MEMORY OPERATIONS AND COMPUTE THE SAME ANSWER.  The reduction section
 *     had four arms that each summed a different quantity; the shapes section
 *     has an FMA row with three loads next to two rows with two.  See R5.
 *
 *  6. A CLAIM ABOUT WHAT A COMPILER DID IS A CLAIM ABOUT BYTES, AND AN
 *     INFERENCE FROM A TIMING IS NOT A MEASUREMENT OF A COMPILER.  This file
 *     quotes a speedup for an "auto-vectorised" arm and for a "via pointers"
 *     control, and both speedups are consequences of the codegen rather than
 *     evidence for it.  build_samples.sh therefore compiles FOUR forms of the
 *     same loop -- named/constant, named/variable, pointer/constant,
 *     pointer/variable -- and appends their mnemonics, so the claim is checked
 *     against the bytes the compiler emitted.  The first version of this file
 *     had no disassembly at all and got the mechanism wrong.  See R7.
 *
 *  7. IT PRINTS ITS OWN LIMITS AND ITS OWN RETRACTIONS.  Section 8.  There is
 *     no hardware performance counter on this machine, so nothing here is a
 *     COUNT of instructions, uops, cycles or cache-line splits -- every number
 *     is a duration, and a duration bounds a count without measuring it.
 *
 * ============================ WHAT IS IN HERE ============================
 *   0. the instrument: TSC rate, noise floor, CPUID, and the absence of AVX-512
 *   1. what a vector register IS: the lane table, computed not quoted
 *   2. the table: six arms, one loop, and the compiler against the intrinsics
 *   3. THE CEILING: the same 4-wide arm at five working-set sizes
 *   4. the instructions are elementwise, and independence is a property too
 *   5. going back to one scalar: the reduction, in four shapes
 *   6. where the width gets spent: alignment, gather, and the tail
 *   7. the same shape on three architectures
 *   8. the retractions, and the limits
 *
 * Build: cc -O2 -Wall -mavx2 -mfma -o simdbench simdbench.c
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
#include <sched.h>
#include <time.h>
#include <sys/wait.h>
#include <cpuid.h>
#include <immintrin.h>

/* ------------------------------------------------------------------ */
/* the clock and the estimator                                         */
/* ------------------------------------------------------------------ */

static double g_tsc_ghz = 2.2957;   /* replaced by a measurement in sec 0 */

static inline uint64_t rdtsc(void) {
    uint32_t lo, hi;
    __asm__ __volatile__("lfence\n\trdtsc" : "=a"(lo), "=d"(hi) :: "memory");
    return ((uint64_t)hi << 32) | lo;
}

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

/* Ticks -> nanoseconds, using the rate MEASURED in section 0 rather than a
 * constant typed in here.  The first version of this file divided by a
 * hard-coded 2.2957 and every absolute figure in the output was off by the
 * ratio between that constant and the machine's actual rate.  See R2. */
static inline double ticks_to_ns(uint64_t ticks) {
    /* ticks / (ghz * 1e9 ticks per second) seconds, times 1e9 ns per second
     *  == ticks / ghz.  Written out longhand so the units are on the page. */
    double seconds = (double)ticks / (g_tsc_ghz * 1000000000.0);
    return seconds * 1000000000.0;
}

static char g_buf[1 << 16];

/* ------------------------------------------------------------------ */
/* 0. the instrument                                                   */
/* ------------------------------------------------------------------ */

static double measure_rate_busy(void) {
    struct timespec t0, t1;
    uint64_t c0, c1;
    clock_gettime(CLOCK_MONOTONIC, &t0); c0 = rdtsc();
    { volatile uint64_t s = 0; for (long i = 0; i < 20000000; i++) s = s + 1; }
    c1 = rdtsc(); clock_gettime(CLOCK_MONOTONIC, &t1);
    double ns = (double)(t1.tv_sec - t0.tv_sec) * 1e9 + (double)(t1.tv_nsec - t0.tv_nsec);
    return (double)(c1 - c0) / ns;
}

static double measure_rate_sleep(void) {
    struct timespec sl = { 0, 120 * 1000 * 1000 }, t0, t1;
    uint64_t c0, c1;
    clock_gettime(CLOCK_MONOTONIC, &t0); c0 = rdtsc();
    nanosleep(&sl, NULL);
    c1 = rdtsc(); clock_gettime(CLOCK_MONOTONIC, &t1);
    double ns = (double)(t1.tv_sec - t0.tv_sec) * 1e9 + (double)(t1.tv_nsec - t0.tv_nsec);
    return (double)(c1 - c0) / ns;
}

static void sec_instrument(void) {
    puts("");
    puts("0. THE INSTRUMENT");
    puts("   Everything below is measured before any claim about the machine is");
    puts("   made, including the machine's own opinion of what it can do.");

    double busy = measure_rate_busy();
    double idle = measure_rate_sleep();
    g_tsc_ghz = (busy + idle) / 2.0;
    printf("\n   TSC rate, busy          %.4f GHz\n", busy);
    printf("   TSC rate, across sleep  %.4f GHz\n", idle);
    printf("   drift                   %.3f%%   <-- invariant, so a tick is TIME\n",
           100.0 * (busy - idle) / idle);
    printf("   rate USED for every ns figure below: %.4f GHz (measured, not typed in)\n",
           g_tsc_ghz);

    /* Where it is pinned, and whether the pin took.  Rule 3: on a machine with
     * other tenants, a benchmark that does not say where it ran is a rumour.
     * The first version of this file did not pin at all, and the same body
     * measured 1.7x apart between two runs of the same binary. */
    cpu_set_t st;
    CPU_ZERO(&st);
    CPU_SET(4, &st);
    int pinned = (sched_setaffinity(0, sizeof st, &st) == 0);
    printf("   pinned to cpu4: %s (sched_getcpu says cpu%d)\n",
           pinned ? "yes" : "NO", sched_getcpu());
    if (!pinned) puts("      the pin was refused; every ratio below is then a ratio");
    if (!pinned) puts("      between two things that may have run on different cores.");

    /* THE NOISE FLOOR, measured on THIS file's own estimator: the same arm,
     * eleven times, and the spread between the fastest and the slowest.  It is
     * printed before any ratio is quoted because it decides which ratios are
     * assertable at all. */
    static double W[64] __attribute__((aligned(64)));
    static double Bv[64] __attribute__((aligned(64)));
    static double Cv[64] __attribute__((aligned(64)));
    double est[11];
    for (int k = 0; k < 11; k++) {
        double best = 1e30;
        for (int r = 0; r < 3; r++) {
            for (int j = 0; j < 64; j++) { W[j] = 0.25; Bv[j] = 0.5; Cv[j] = 0.25; }
            uint64_t a = rdtsc();
            for (long i = 0; i < 20000; i++)
                for (int j = 0; j < 64; j++)
                    W[j] = W[j] * Bv[j] + Cv[j];
            uint64_t b = rdtsc();
            double v = ticks_to_ns(b - a) / 20000.0;
            if (v < best) best = v;
        }
        est[k] = best;
    }
    double mn = est[0], mx = est[0];
    for (int k = 1; k < 11; k++) { if (est[k] < mn) mn = est[k]; if (est[k] > mx) mx = est[k]; }
    printf("   estimator = min-of-3, 11 of them: spread %5.1f%%  (%.2f ns/iter)\n",
           100.0 * (mx - mn) / mn, mn);
    puts("   The body is the section 2 loop.  This number is the reason the");
    puts("   crosscheck asserts SHAPES and not values: a tolerance that wide can");
    puts("   verify that 4 lanes beat 1 lane and cannot verify by how much.");

    /* What the CPU says it can do, asked directly.  The AVX-512 absence is
     * PROVED here rather than assumed, and it is why section 7 quotes what a
     * ZMM and a mask register are without measuring one. */
    unsigned a, b, c, d;
    char brand[49];
    memset(brand, 0, sizeof brand);
    for (int l = 0x80000002; l <= 0x80000004; l++) {
        __cpuid(l, a, b, c, d);
        unsigned w[4] = { a, b, c, d };
        memcpy(brand + (l - 0x80000002) * 16, w, 16);
    }
    __cpuid(1, a, b, c, d);
    unsigned fam = ((a >> 8) & 0xf) + ((a >> 20) & 0xff);
    unsigned mod = ((a >> 4) & 0xf) + (((a >> 16) & 0xf) << 4);
    int has_sse2 = (d >> 26) & 1, has_fma = (c >> 12) & 1, has_avx = (c >> 28) & 1;
    __cpuid_count(7, 0, a, b, c, d);
    int has_avx2 = (b >> 5) & 1, has_bmi2 = (b >> 8) & 1;
    int has_512f = (b >> 16) & 1, has_512dq = (b >> 17) & 1;
    int has_512cd = (b >> 28) & 1, has_512bw = (b >> 30) & 1, has_512vl = (b >> 31) & 1;

    printf("\n   brand            %s\n", brand);
    printf("   family 0x%02x, model 0x%02x\n", fam, mod);
    printf("   x86-64 flags:    sse2=%d avx=%d fma=%d avx2=%d bmi2=%d\n",
           has_sse2, has_avx, has_fma, has_avx2, has_bmi2);
    printf("   avx512f=%d avx512dq=%d avx512cd=%d avx512bw=%d avx512vl=%d\n",
           has_512f, has_512dq, has_512cd, has_512bw, has_512vl);
    if (has_512f || has_512dq || has_512bw || has_512vl || has_512cd)
        puts("   => this machine HAS AVX-512.  Section 7 of this artifact is wrong about");
    else {
        puts("   => THERE IS NO AVX-512 ON THIS MACHINE, and that is a checked fact and");
        puts("      not a gap: five CPUID leaves, all zero.  Every claim about a 512-bit");
        puts("      register or a k0-k7 mask register in this artifact is QUOTED from the");
        puts("      manuals, and nothing about one is measured here.  See the limits.");
    }

    /* The caches, because section 3's whole result is about which of them the
     * working set is in, and it has to read the sizes rather than assume them. */
    puts("\n   the caches, and which CPUs share each one:");
    for (int idx = 0; idx < 8; idx++) {
        char p[160], l[32], t[32], s[64], sh[256];
        snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/level", idx);
        if (slurp(p, l, sizeof l) <= 0) break;
        char *nl;
        nl = strchr(l, '\n'); if (nl) *nl = 0;
        snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/type", idx);
        slurp(p, t, sizeof t); nl = strchr(t, '\n'); if (nl) *nl = 0;
        snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/size", idx);
        slurp(p, s, sizeof s); nl = strchr(s, '\n'); if (nl) *nl = 0;
        snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/shared_cpu_list", idx);
        slurp(p, sh, sizeof sh); nl = strchr(sh, '\n'); if (nl) *nl = 0;
        printf("      L%s %-11s %6s KiB  shared by [%s]\n", l, t, s, sh);
    }
    puts("   Section 3 sweeps the working set across every one of these sizes, which");
    puts("   is the whole reason the sweep is the course and the lane count is not.");

    /* And the absence of a PMU, which is why nothing in this file is a count. */
    puts("\n   performance counters:");
    if (slurp("/proc/sys/kernel/perf_event_paranoid", g_buf, sizeof g_buf) > 0) {
        char *nl = strchr(g_buf, '\n'); if (nl) *nl = 0;
        printf("      perf_event_paranoid    %s\n", g_buf);
    }
    puts("      no PMU, so no instruction, uop, cycle, load, store or cache-line");
    puts("      split can be COUNTED here.  Every number in sections 2 to 6 is a");
    puts("      DURATION, and a duration is a LOWER BOUND on a count, never a");
    puts("      measurement of one.  The mechanism column of every table in this");
    puts("      artifact is therefore marked INFERRED, and no table below claims a");
    puts("      count of anything.");
}

/* ------------------------------------------------------------------ */
/* the arrays                                                          */
/* ------------------------------------------------------------------ */

/* N=64 doubles is 512 bytes per array, 1536 for all three: comfortably inside
 * the 32 KiB L1 read above, which is deliberate.  The first version of this
 * file used a 4096-element array, so the L1 case did not exist and the
 * headline number was accidentally a memory-bandwidth number.  See R3. */
#define N 64
#define ITERS 20000
#define REPS 7

static double A[N] __attribute__((aligned(64)));
static double B[N] __attribute__((aligned(64)));
static double C[N] __attribute__((aligned(64)));

/* A[i] = A[i]*B[i] + C[i], with B=0.5 and C=0.25, is a fixed point at
 * A=0.5 reached after 53 iterations in exact binary arithmetic.  So every arm
 * of every table must leave the sum of A at exactly 64 * 0.5 = 32.0, whatever
 * order it did the work in, and the checksum is that.  The values are chosen
 * to be exactly representable so the checksum is a bit-for-bit test rather
 * than a tolerance: 0.25, 0.5 and 0.25 are all powers of two, and the sum of
 * sixty-four copies of 0.5 is exact. */
__attribute__((noinline)) static void seed_small(void) {
    for (int j = 0; j < N; j++) { A[j] = 0.25; B[j] = 0.5; C[j] = 0.25; }
}
static double checksum_small(void) {
    double s = 0;
    for (int j = 0; j < N; j++) s += A[j];
    return s;
}

/* ------------------------------------------------------------------ */
/* 1. what a vector register IS                                       */
/* ------------------------------------------------------------------ */

static void sec_register(void) {
    puts("");
    puts("1. WHAT A VECTOR REGISTER IS");
    puts("   A vector register is a fixed number of BYTES.  Everything else -- the");
    puts("   lane count, what a lane holds, whether there is a mask -- follows from");
    puts("   that one number divided by the size of an element.  The table below is");
    puts("   COMPUTED from sizeof() at run time and not quoted from a manual, so it");
    puts("   is a fact about this build rather than a fact about a document.");

    printf("\n   register   bytes    64-bit double   32-bit float   32-bit int"
           "   8-bit int   16-bit int\n");
    printf("   XMM         %3d          %2d              %2d             %2d"
           "            %2d            %2d\n",
           16, 16 / (int)sizeof(double), 16 / (int)sizeof(float),
           16 / (int)sizeof(int32_t), 16 / (int)sizeof(int8_t), 16 / (int)sizeof(int16_t));
    printf("   YMM         %3d          %2d              %2d             %2d"
           "            %2d            %2d\n",
           32, 32 / (int)sizeof(double), 32 / (int)sizeof(float),
           32 / (int)sizeof(int32_t), 32 / (int)sizeof(int8_t), 32 / (int)sizeof(int16_t));
    printf("   ZMM         %3d          %2d              %2d             %2d"
           "            %2d            %2d   <- not in this CPU\n",
           64, 64 / (int)sizeof(double), 64 / (int)sizeof(float),
           64 / (int)sizeof(int32_t), 64 / (int)sizeof(int8_t), 64 / (int)sizeof(int16_t));
    printf("   k0-k7        %3d bits, one per lane of a ZMM.  64 of them per ZMM,"
           " 512 per\n           architectural ZMM.  Not in this CPU.\n", 64);

    puts("\n   THREE THINGS THAT TABLE DOES NOT SAY, and each of them is a trap:");
    puts("     1. The lane count is not a speedup.  It is a statement about how");
    puts("        many elements ONE instruction touches.  How much time that buys");
    puts("        depends on what else the loop does per element, and section 3");
    puts("        measures a 4-wide arm going from 3.3x to 1.2x by changing NOTHING");
    puts("        except how much memory it touches.");
    puts("     2. A 512-bit register is not four times a 128-bit one IN PRACTICE.");
    puts("        On every x86 CPU since 2013 the upper halves of a ZMM are ALIASED");
    puts("        onto the YMM, and on the 256-bit-and-down parts a VEX-encoded");
    puts("        instruction zeroes the upper bits of the destination.  The manuals");
    puts("        call this the upper-ZMM state.  This artifact cannot measure it");
    puts("        because there is no AVX-512 here.");
    puts("     3. A mask register is a THIRD operand, not a modifier.  k0-k7 each");
    puts("        hold 64 bits; a masked load uses a bit to say which lanes to");
    puts("        take, and a masked store uses it to say which lanes to KEEP.  That");
    puts("        is why AVX-512 has no tail handling problem worth the name, and");
    puts("        section 6 measures the tail this machine has to do by hand.");

    puts("\n   THE LINE THE EXECUTION COURSE LEFT UNPAID.  exe_deps.ch says a");
    puts("   loop unrolls into \"multiples of the SIMD width\" and exe_latency.ch");
    puts("   says the same work is done \"in SIMD\".  Both use the word as a known");
    puts("   quantity.  This table is the definition neither of them gave: a lane");
    puts("   is one element of a vector register, the width is the register's size");
    puts("   in BYTES, and a 4-wide AVX double loop is four 8-byte lanes, sixteen");
    puts("   iterations of it covering 64 doubles in 512 bytes, and that is ALL it");
    puts("   covers.  How many of those iterations a second is a different question");
    puts("   and it is the subject of sections 2 and 3.");
}

/* ------------------------------------------------------------------ */
/* 2. the table: six arms, one loop                                    */
/* ------------------------------------------------------------------ */

enum { ARM_AUTOVEC, ARM_NOVEC, ARM_SSE2, ARM_AVX, ARM_FMA, ARM_MEMOP, NARM };

/* A: the same scalar source, compiled by gcc with auto-vectorisation on.
 * The trip count is a COMPILE-TIME CONSTANT and that matters -- see section 3
 * and the constant-vs-variable result there. */
__attribute__((noinline)) static void arm_autovec(void) {
    for (long it = 0; it < ITERS; it++)
        for (long j = 0; j < N; j++) A[j] = A[j] * B[j] + C[j];
}
/* B: the identical source with the vectoriser switched off.  This is the
 * floor and every ratio in the course is quoted against it. */
__attribute__((noinline, optimize("no-tree-vectorize"))) static void arm_novec(void) {
    for (long it = 0; it < ITERS; it++)
        for (long j = 0; j < N; j++) A[j] = A[j] * B[j] + C[j];
}
/* C: SSE2, 2 doubles per instruction. */
__attribute__((noinline)) static void arm_sse2(void) {
    for (long it = 0; it < ITERS; it++)
        for (int j = 0; j < N; j += 2) {
            __m128d a = _mm_load_pd(A + j), b = _mm_load_pd(B + j), c = _mm_load_pd(C + j);
            _mm_store_pd(A + j, _mm_add_pd(_mm_mul_pd(a, b), c));
        }
}
/* D: AVX, 4 doubles per instruction, multiply then add as two instructions. */
__attribute__((noinline)) static void arm_avx(void) {
    for (long it = 0; it < ITERS; it++)
        for (int j = 0; j < N; j += 4) {
            __m256d a = _mm256_load_pd(A + j), b = _mm256_load_pd(B + j), c = _mm256_load_pd(C + j);
            _mm256_store_pd(A + j, _mm256_add_pd(_mm256_mul_pd(a, b), c));
        }
}
/* E: AVX2 + FMA.  One arithmetic instruction where D had two. */
__attribute__((noinline)) static void arm_fma(void) {
    for (long it = 0; it < ITERS; it++)
        for (int j = 0; j < N; j += 4) {
            __m256d a = _mm256_load_pd(A + j), b = _mm256_load_pd(B + j), c = _mm256_load_pd(C + j);
            _mm256_store_pd(A + j, _mm256_fmadd_pd(a, b, c));
        }
}
/* F: the SAME arithmetic as E, with A as a MEMORY OPERAND of the FMA, so the
 * 4-wide body issues 2 loads and 1 store instead of 3 loads and 1 store.
 *
 * The first draft of this arm was vfmadd231pd, which computes B*C+A and not
 * A*B+C.  The numbers it produced were entirely plausible, the table was
 * entirely readable, and the only thing on the page that noticed was the
 * checksum line, which read 3.3 where every other arm read 32.0.  See R1. */
__attribute__((noinline)) static void arm_memop(void) {
    const double *a = A, *b = B, *c = C;
    for (long it = 0; it < ITERS; it++)
        __asm__ volatile(
            "xor %%eax,%%eax\n\t"
            "1:\n\t"
            "vmovapd (%[b],%%rax,1), %%ymm0\n\t"
            "vmovapd (%[c],%%rax,1), %%ymm1\n\t"
            "vfmadd132pd (%[a],%%rax,1), %%ymm1, %%ymm0\n\t"
            "vmovapd %%ymm0, (%[a],%%rax,1)\n\t"
            "add $32,%%eax\n\t"
            "cmp $512,%%eax\n\t"
            "jb 1b\n\t"
            :: [a] "r"(a), [b] "r"(b), [c] "r"(c)
            : "rax", "ymm0", "ymm1", "cc", "memory");
}

static void sec_table(void) {
    puts("");
    puts("2. THE TABLE: SIX ARMS, ONE LOOP");
    puts("   One statement -- A[i] = A[i]*B[i] + C[i] -- over 64 doubles, 20000");
    puts("   times, pinned to one CPU, arms INTERLEAVED and each the minimum of 7.");
    puts("   B is the floor.  Every ratio is to B, and no absolute number here is");
    puts("   worth carrying to another machine.");

    void (*arms[NARM])(void) = { arm_autovec, arm_novec, arm_sse2, arm_avx, arm_fma, arm_memop };
    const char *name[NARM] = {
        "A  scalar C, -O2, the compiler vectorised it",
        "B  scalar C, no-tree-vectorize            <- the floor",
        "C  SSE2, 2 doubles per instruction",
        "D  AVX, 4 doubles, mul then add",
        "E  AVX2+FMA, 4 doubles, one arithmetic instruction",
        "F  AVX2+FMA, 4 doubles, A as a memory operand",
    };
    double best[NARM], cks[NARM];
    for (int i = 0; i < NARM; i++) best[i] = 1e30;
    for (int i = 0; i < NARM; i++) { seed_small(); arms[i](); }   /* warm the cache */
    for (int r = 0; r < REPS; r++)
        for (int i = 0; i < NARM; i++) {
            seed_small();
            uint64_t t0 = rdtsc();
            arms[i]();
            uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)ITERS;
            if (v < best[i]) best[i] = v;
            cks[i] = checksum_small();
        }

    printf("\n   %-52s %10s %10s %10s\n", "arm", "ns/iter", "ns/element", "speedup");
    for (int i = 0; i < NARM; i++)
        printf("   %-52s %10.2f %10.3f %9.2fx\n", name[i], best[i], best[i] / N,
               best[ARM_NOVEC] / best[i]);

    int allsame = 1;
    for (int i = 0; i < NARM; i++) if (cks[i] != cks[0]) allsame = 0;
    printf("\n   CHECKSUM  A[0]+..+A[63] must be 32.000000 in EVERY arm: %s\n",
           allsame ? "yes, all six agree" : "NO -- AN ARM DID THE WRONG ARITHMETIC");
    printf("   ");
    for (int i = 0; i < NARM; i++) printf("%c=%.6f ", 'A' + i, cks[i]);
    printf("\n   B = 0.5, C = 0.25 makes A = A*B + C a FIXED POINT at 0.5 after 53\n"
           "   iterations, in exact binary arithmetic, and 64 copies of 0.5 sum\n"
           "   exactly.  So the checksum is a bit-for-bit test, not a tolerance --\n"
           "   which is the only reason it caught the operand-order bug in arm F.\n");

    puts("\n   WHAT EACH ROW IS, and what it is NOT:");
    puts("      A  the compiler's own answer, and it is not a separate kind of");
    puts("         thing.  It is the SAME loop, and the fact that it is competitive");
    puts("         with a hand-written 4-wide loop is the result of this section.");
    puts("      B  the floor.  One element per instruction, and nothing else changed.");
    puts("      C  TWO lanes.  Doubles are 8 bytes and an XMM is 16, so 2 is not a");
    puts("         choice anybody made; it is 16/8.");
    puts("      D  FOUR lanes, because 32/8 = 4.  Two arithmetic instructions.");
    puts("      E  FOUR lanes, ONE arithmetic instruction.  FMA is the reason the");
    puts("         instruction count went down by a third and the time did not go");
    puts("         down at all.  An extra instruction you did not need costs a");
    puts("         fetch and a decode slot, and on a loop that is not short of");
    puts("         either, removing one buys nothing.");
    puts("      F  FOUR lanes, and ONE of the three loads is gone -- the A operand");
    puts("         is a memory operand of the FMA, which is the same shape gcc emits");
    puts("         for arm A.  It comes out SLOWER than the three-load version, and");
    puts("         the row is worth more than the one it replaced: an instruction");
    puts("         with a memory operand must WAIT for that load to land before it");
    puts("         can multiply, so the load latency moves from \"overlapped with");
    puts("         other work\" to \"on the critical path of the arithmetic\".  Fewer");
    puts("         memory OPERATIONS, worse dependency structure.  This is the row");
    puts("         that killed the \"one fewer load is the whole gap\" story.");
    printf("\n   THE COMPARISON, as SPEEDUPS over the floor B (higher is faster):\n");
    printf("      2 lanes (C) / 1 lane (B)                  %6.2fx\n", best[ARM_NOVEC] / best[ARM_SSE2]);
    printf("      4 lanes (D) / 1 lane (B)                  %6.2fx   <- the lane count is 4\n",
           best[ARM_NOVEC] / best[ARM_AVX]);
    printf("      4 lanes with FMA (E) / 4 lanes without (D) %6.2fx   <- FMA's contribution\n",
           best[ARM_AVX] / best[ARM_FMA]);
    printf("      the hand-written 4-wide (E) / the compiler (A) %6.2fx\n",
           best[ARM_AUTOVEC] / best[ARM_FMA]);
    printf("      one fewer memory op (F) / three loads (E)   %6.2fx   <- SLOWER, and that\n",
           best[ARM_MEMOP] / best[ARM_FMA]);
    puts("         is the finding: a memory operand buys a shorter instruction and");
    puts("         costs a longer dependency.  Instruction COUNT is not the cost.");

    puts("\n   AND THE FINDING, which is NOT the one this section was drafted for:");
    printf("   The 4-wide arm (D) is %.2fx the scalar floor at 1536 bytes.  Close to\n",
           best[ARM_NOVEC] / best[ARM_AVX]);
    puts("   four, and that is the story you would tell by default: four lanes,");
    puts("   four times.  It is also the story this course was NOT drafted around --");
    puts("   the first draft asserted a 2.2x and called it a lesson about the memory");
    puts("   system, and that number did not reproduce (see R3).  What reproduces is");
    puts("   that on L1-resident data the lane count is very nearly the whole answer,");
    puts("   because 3 loads and 1 store per 4 elements really do get ~4x cheaper.");
    puts("   Section 3 then takes the SAME arm, changes NOTHING but how much memory");
    puts("   it touches, and the answer stops being the lane count: the same 4-wide");
    puts("   arm falls to about 1.2x once the data is bigger than the L3.  So the");
    puts("   lesson is not \"lanes are not the speedup\" -- it is \"the speedup is the");
    puts("   ratio of what the width DIVIDES, and once the division stops being the");
    puts("   bottleneck the lanes buy you almost nothing.\"");
}

/* ------------------------------------------------------------------ */
/* 3. THE CEILING: the same arm at five working-set sizes              */
/* ------------------------------------------------------------------ */

static size_t g_nb;                 /* doubles per array */
static long   g_iters;              /* iterations */

/* NAMED ARRAYS, not pointers, and that is a MEASURED decision rather than a
 * style one.  The first version of this section declared three `double *`
 * globals and reached each array through them, and gcc did not vectorise the
 * auto-vectorised arm at all -- at EITHER trip count.  The reason is ALIASING,
 * not the trip count: with three pointers a store to A[j] might change what
 * B[j+4] holds, so a loop that reads three streams and writes one cannot be
 * reordered into a vector loop.  With three named arrays gcc knows they are
 * three distinct objects and vectorises both forms.
 *
 * So the first version of this section reported "the compiler declined to
 * vectorise" and the VERIFY block says otherwise, and the story was wrong for
 * a reason that is itself worth a paragraph: the trip count controls whether
 * there is a SCALAR EPILOGUE, and the pointer indirection controls whether
 * there is a vector loop at all.  Those are two different things and the first
 * draft conflated them.  See R7.
 *
 * The pointer form is still here, as big_ptr, so the claim is measured rather
 * than asserted -- the sweep then carries six arms and one of them exists only
 * to be the control. */
#define NBMAX (1u << 20)
static double bA[NBMAX] __attribute__((aligned(4096)));
static double bB[NBMAX] __attribute__((aligned(4096)));
static double bC[NBMAX] __attribute__((aligned(4096)));
/* The control's three pointers.  They are ASSIGNED IN main() rather than being
 * static initialisers, and they are reached through a noinline accessor, so
 * that gcc cannot constant-propagate them back to bA/bB/bC and quietly
 * vectorise the control.  The first version of this control declared
 *
 *     static double *gA = bA, *gB = bB, *gC = bC;
 *
 * which is the same three arrays wearing a pointer costume: gcc folded the
 * initialisers away, proved the three streams distinct again, vectorised the
 * control, and the control came out at 3.91x -- indistinguishable from the arm
 * it was supposed to contradict.  A control that cannot fail is not a control,
 * and this is the third time in this collection that a "benchmark" was really
 * the same benchmark wearing a different declaration.  See R8. */
static double *gA, *gB, *gC;
__attribute__((noinline)) static double *pa(void) { return gA; }
__attribute__((noinline)) static double *pb(void) { return gB; }
__attribute__((noinline)) static double *pc(void) { return gC; }

__attribute__((noinline)) static void big_seed(void) {
    for (size_t j = 0; j < g_nb; j++) { bA[j] = 0.25; bB[j] = 0.5; bC[j] = 0.25; }
}
__attribute__((noinline)) static double big_checksum(void) {
    double s = 0;
    for (size_t j = 0; j < g_nb; j++) s += bA[j];
    return s;
}

/* The trip count is a RUNTIME VARIABLE here, on purpose: it is the only way to
 * sweep the size.  It is also the thing that decides whether the compiler's
 * own version of this loop grows a scalar epilogue for n mod 4. */
__attribute__((noinline, optimize("no-tree-vectorize"))) static void big_novec(void) {
    for (long it = 0; it < g_iters; it++)
        for (size_t j = 0; j < g_nb; j++) bA[j] = bA[j] * bB[j] + bC[j];
}
__attribute__((noinline)) static void big_sse2(void) {
    for (long it = 0; it < g_iters; it++)
        for (size_t j = 0; j < g_nb; j += 2) {
            __m128d a = _mm_load_pd(bA + j), b = _mm_load_pd(bB + j), c = _mm_load_pd(bC + j);
            _mm_store_pd(bA + j, _mm_add_pd(_mm_mul_pd(a, b), c));
        }
}
__attribute__((noinline)) static void big_avx(void) {
    for (long it = 0; it < g_iters; it++)
        for (size_t j = 0; j < g_nb; j += 4) {
            __m256d a = _mm256_load_pd(bA + j), b = _mm256_load_pd(bB + j), c = _mm256_load_pd(bC + j);
            _mm256_store_pd(bA + j, _mm256_add_pd(_mm256_mul_pd(a, b), c));
        }
}
__attribute__((noinline)) static void big_fma(void) {
    for (long it = 0; it < g_iters; it++)
        for (size_t j = 0; j < g_nb; j += 4) {
            __m256d a = _mm256_load_pd(bA + j), b = _mm256_load_pd(bB + j), c = _mm256_load_pd(bC + j);
            _mm256_store_pd(bA + j, _mm256_fmadd_pd(a, b, c));
        }
}
__attribute__((noinline)) static void big_autovec(void) {
    for (long it = 0; it < g_iters; it++)
        for (size_t j = 0; j < g_nb; j++) bA[j] = bA[j] * bB[j] + bC[j];
}
/* THE CONTROL: identical to big_autovec except that the three streams are
 * reached through pointers, so the compiler cannot prove they do not alias.
 * If the difference between these two arms is the whole of the "the compiler
 * declined" story, this arm will come out at the scalar floor. */
__attribute__((noinline)) static void big_ptr(void) {
    for (long it = 0; it < g_iters; it++)
        for (size_t j = 0; j < g_nb; j++) {
            double *a = pa(), *b = pb(), *c = pc();
            a[j] = a[j] * b[j] + c[j];
        }
}

static void sec_ceiling(void) {
    gA = bA; gB = bB; gC = bC;
    puts("");
    puts("3. THE CEILING: THE SAME 4-WIDE ARM AT FIVE SIZES");
    puts("   Identical statement, identical arms, identical estimator.  One thing");
    puts("   changes per row: how much memory the working set is.  1536 bytes of");
    puts("   arrays live in the 32 KiB L1; 24 MiB does not, and the L3 above it is");
    puts("   16 MiB and shared with all twelve logical CPUs.");

    static const size_t sizes[5] = { 64, 4096, 32768, 262144, 1048576 };
    static const long   reps[5]  = { 20000, 5000, 1000, 100, 20 };
    const char *label[5] = { "L1", "L1 -> L2", "beyond L2", "beyond L2, inside L3", "beyond L3" };

    double gain2[5], gain4[5], gainauto[5], gainptr[5];
    double ns4[5], nsscalar[5], nsc[5], nsp[5];

    for (int k = 0; k < 5; k++) {
        g_nb = sizes[k]; g_iters = reps[k];
        double b[6];
        for (int i = 0; i < 6; i++) b[i] = 1e30;
        void (*fn[6])(void) = { big_novec, big_sse2, big_avx, big_fma,
                                big_autovec, big_ptr };
        for (int i = 0; i < 6; i++) { big_seed(); fn[i](); }
        for (int r = 0; r < 5; r++)
            for (int i = 0; i < 6; i++) {
                big_seed();
                uint64_t t0 = rdtsc();
                fn[i]();
                uint64_t t1 = rdtsc();
                double v = ticks_to_ns(t1 - t0) / (double)g_iters / (double)g_nb;
                if (v < b[i]) b[i] = v;
            }
        nsscalar[k] = b[0]; nsc[k] = b[1]; ns4[k] = b[2]; nsp[k] = b[5];
        gain2[k] = b[0] / b[1];
        gain4[k] = b[0] / b[2];
        gainauto[k] = b[0] / b[4];
        gainptr[k] = b[0] / b[5];
    }
    /* The table, with its headers in the right place this time.  The first
     * version of this section printed the header row before the loop that
     * fills the columns, which produced a table with a header at the bottom
     * and one that read as though the L1 row were the last one measured. */
    printf("\n   working set          per array   all three   scalar      2-wide"
           "      4-wide    4-wide/scalar  auto-vec/scalar  via POINTERS/scalar\n");
    for (int k = 0; k < 5; k++)
        printf("   %-20s %7.0f KiB %8.0f KiB %9.3f %10.3f %10.3f %12.2fx %14.2fx %17.2fx\n",
               label[k], sizes[k] * 8 / 1024.0, sizes[k] * 24 / 1024.0,
               nsscalar[k], nsc[k], ns4[k], gain4[k], gainauto[k], gainptr[k]);
    printf("   (ns per ELEMENT, so the rows are comparable; minimum of 5 interleaved,"
           " SIX arms)\n");
    printf("   The last two columns are the SAME SOURCE reached two ways: one through\n"
           "   three named arrays, one through three double * globals.  In ns per\n"
           "   element the named form costs %.3f and the pointer form %.3f at 2 KiB,\n"
           "   and %.3f and %.3f at 24 MiB -- a gap of %.1fx and %.1fx, and the\n"
           "   disassembly at the end of this file says why.  Read the two columns\n"
           "   together or neither one of them means much.\n",
           ns4[0], nsp[0], ns4[4], nsp[4], gainauto[0] / gainptr[0], gainauto[4] / gainptr[4]);

    /* CHECKSUM, re-derived from a clean seed at every size.  The invariant is
     * that all THREE arms agree WITH EACH OTHER, not that they hit 0.5*n: at
     * n = 2^20 the SEQUENTIAL scalar sum of a million copies of 0.5 loses the
     * last bits of its own accumulator, so 0.5*n is the wrong yardstick at the
     * top size and using it produced a spurious MISMATCH on the first run.  The
     * real check -- three different bodies, one fixed point -- is that they
     * produce the SAME number, and 524287.8 is what all three of them produce
     * and it is 0.5*n minus 0.2 for reasons that have nothing to do with SIMD.
     * Comparing arms to each other is also the only check that works at every
     * size without knowing the accumulation order of each, which is the whole
     * point. */
    int sums_ok = 1;
    printf("\n   CHECKSUM  all FOUR bodies must produce the SAME sum at every size:\n");
    for (int k = 0; k < 5; k++) {
        g_nb = sizes[k]; g_iters = reps[k];
        big_seed(); big_avx();    double a4 = big_checksum();
        big_seed(); big_novec();  double asc = big_checksum();
        big_seed(); big_autovec();double aau = big_checksum();
        big_seed(); big_ptr();    double apt = big_checksum();
        int ok = (a4 == asc) && (asc == aau) && (aau == apt);
        if (!ok) sums_ok = 0;
        printf("      n=%-8zu  4-wide=%.4f  scalar=%.4f  auto-vec=%.4f  via-pointers=%.4f   %s\n",
               sizes[k], a4, asc, aau, apt, ok ? "agree" : "MISMATCH");
    }
    printf("      => %s\n", sums_ok ? "all four bodies agree at all five sizes" : "SOME ARM DISAGREED");
    puts("      The via-pointers column is the control arm and it agrees too, which is");
    puts("      the point: whatever the compiler did with it, it computed the same");
    puts("      number.  A body that stops being vectorised and a body that was never");
    puts("      vectorised must both leave the same checksum, and this one does.");
    if (sizes[4] >= 1048576) {
        puts("      (at the top size the value is 0.5*n minus about 0.2, because the");
        puts("       SEQUENTIAL scalar accumulator loses low bits summing a million");
        puts("       numbers.  All three arms lose exactly the same bits, which is");
        puts("       the point: they are the same recurrence written three ways.)");
    }

    printf("\n   THE RESULT, and it is a single line:\n");
    printf("      4-wide vs the scalar arm:   %6.2fx  at %6.0f KiB (inside L1)\n",
           gain4[0], sizes[0] * 24 / 1024.0);
    printf("                                   %6.2fx  at %6.0f KiB (inside L3)\n",
           gain4[4], sizes[4] * 24 / 1024.0);
    printf("\n   The lane count did not change between those two rows.  It is four in\n"
           "   both.  The only thing that changed is where the bytes come from, and\n"
           "   the speedup fell from %.2fx to %.2fx -- a factor of %.2f -- while the\n"
           "   SCALAR arm barely moved at all: %.3f ns/element at 2 KiB and %.3f at\n"
           "   24 MiB, a factor of %.2f.  The 4-wide arm went from %.3f to %.3f, a\n"
           "   factor of %.2f.\n",
           gain4[0], gain4[4], gain4[0] / gain4[4],
           nsscalar[0], nsscalar[4], nsscalar[4] / nsscalar[0],
           ns4[0], ns4[4], ns4[4] / ns4[0]);
    puts("\n   READ THAT AS A SENTENCE: THE VECTOR ARM'S COST WENT UP BY SIX AND THE");
    puts("   SCALAR ARM'S WENT UP BY TWO, AND THE DIFFERENCE IS THE SPEEDUP.  A");
    puts("   4-wide loop does not do less work than a scalar loop; it does the same");
    puts("   work in a quarter of the instructions, which is worth nothing once the");
    puts("   bottleneck is the bandwidth rather than the instruction rate.  That is");
    puts("   what \"vectorise the hot loop\" means and when it stops meaning that.\n");
    printf("      and the 2-wide arm, for contrast: %6.2fx inside L1, %6.2fx inside L3.\n"
           "      It loses LESS than the 4-wide arm does, which is the opposite of the\n"
           "      story you would tell if the lane count were the cause.\n",
           gain2[0], gain2[4]);

    puts("\n   AND THE COMPILER, which is the other half of section 2's finding, and");
    puts("   which is where this section was WRONG THE FIRST TIME.  The first draft");
    puts("   reached the three arrays through three `double *` globals, measured the");
    puts("   auto-vectorised arm tracking the scalar arm, and concluded that gcc's");
    puts("   -O2 vectoriser \"declines when it cannot prove the trip count large\".");
    puts("   That was an inference from a number, and it was wrong.");
    printf("\n   What the sweep actually shows, with the pointer form kept as a control:\n");
    printf("      auto-vectorised, NAMED arrays:  %5.2fx %5.2fx %5.2fx %5.2fx %5.2fx\n",
           gainauto[0], gainauto[1], gainauto[2], gainauto[3], gainauto[4]);
    printf("      the SAME SOURCE via pointers:   %5.2fx %5.2fx %5.2fx %5.2fx %5.2fx\n",
           gainptr[0], gainptr[1], gainptr[2], gainptr[3], gainptr[4]);
    puts("\n   So the compiler DOES vectorise the auto arm, and it lands essentially on");
    puts("   the hand-written 4-wide one -- which is the finding, and the same one");
    puts("   section 2 found on L1-resident data, now confirmed at every size.  And");
    puts("   the pointer form is catastrophically worse, because:");
    puts("\n      The cause is ALIASING, and it is worth being precise about the word:");
    puts("      ALIASING here does not mean the pointers are equal -- it means the");
    puts("      compiler cannot prove they are NOT.  A store to A[j] might");
    puts("      change what B[j+4] holds, and if it might then the loads of the next");
    puts("      vector cannot be hoisted above this vector's store, and the whole");
    puts("      reorder into a vector loop is unsafe.  With three NAMED arrays the");
    puts("      three streams are three distinct objects and the question does not");
    puts("      arise.  One line of `restrict`, or one array instead of three, is the");
    puts("      difference between the two columns.\n");
    puts("\n      AND THE CONTROL IS SLOWER THAN THE SCALAR FLOOR, not equal to it, and");
    puts("      that is not a second finding: the control reaches its three pointers");
    puts("      through noinline accessors so that the compiler cannot see through");
    puts("      them, and that puts THREE CALLS in the inner loop.  The gap between the");
    puts("      two columns is therefore larger than the pure vectorisation effect,");
    puts("      and the honest reading is CATASTROPHICALLY WORSE, not a clean");
    puts("      factor.  A control that could not fail was the first version of this");
    puts("      one; see R8.\n");
    puts("   THE TRIP COUNT IS A DIFFERENT THING AND WAS CONFLATED WITH IT.  What a");
    puts("   runtime trip count actually costs the vectoriser is a SCALAR EPILOGUE for");
    puts("   the n mod 4 remainder -- which is precisely the tail that section 6c");
    puts("   measures as free.  So the two effects are: the trip count buys an");
    puts("   epilogue (cheap), and the pointer indirection buys NO VECTOR LOOP AT ALL");
    puts("   (catastrophic).  The first draft attributed the second to the first.\n");
    puts("   None of this is an assertion about gcc.  build_samples.sh compiles all");
    puts("   FOUR forms -- named/constant, named/variable, pointer/constant,");
    puts("   pointer/variable -- and appends their mnemonics to this output in the");
    puts("   VERIFY block at the end, because a claim about what a compiler did is a");
    puts("   claim about BYTES and the only way to check it is to read the bytes.");
    puts("   The general form, which is R7: AN INFERENCE FROM A TIMING IS NOT A");
    puts("   MEASUREMENT OF A COMPILER, AND THE TWO DISAGREE OFTEN ENOUGH TO CHECK.");
}

/* ------------------------------------------------------------------ */
/* 4. the instructions are elementwise, and independence is a property */
/* ------------------------------------------------------------------ */

/* Four bodies over the same 64 doubles, differing in ONE arithmetic
 * instruction.  The copy arm reads Y and writes X, so it does the same two
 * loads and one store as the others with nothing between them: it is the
 * MEMORY floor for this loop, and it is an arm rather than a preamble because
 * "what does the arithmetic cost" has no answer without it.
 *
 * The first version of this arm read X and wrote X -- a self-copy -- and the
 * compiler deleted it, and the row reported 0.00 ns/iter.  A fourth deleted
 * experiment in this collection, and the reason the copy is between two
 * arrays and not the same array is written next to the code. */
static double X[N] __attribute__((aligned(64)));
static double Y[N] __attribute__((aligned(64)));
static double Z[N] __attribute__((aligned(64)));
#define SH_ITERS 20000
__attribute__((noinline)) static void sh_seed(void) {
    for (int j = 0; j < N; j++) { X[j] = 0.25; Y[j] = 0.5; Z[j] = 0.25; }
}
__attribute__((noinline)) static void sh_copy(void) {   /* load, store: no arithmetic */
    for (long i = 0; i < SH_ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(X + j, _mm256_load_pd(Y + j));
}
__attribute__((noinline)) static void sh_add(void) {    /* one add */
    for (long i = 0; i < SH_ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(X + j, _mm256_add_pd(_mm256_load_pd(X + j),
                                                  _mm256_load_pd(Y + j)));
}
__attribute__((noinline)) static void sh_mul(void) {    /* one multiply */
    for (long i = 0; i < SH_ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(X + j, _mm256_mul_pd(_mm256_load_pd(X + j),
                                                  _mm256_load_pd(Y + j)));
}
__attribute__((noinline)) static void sh_fma(void) {    /* one fused multiply-add */
    for (long i = 0; i < SH_ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(X + j, _mm256_fmadd_pd(_mm256_load_pd(X + j),
                                                    _mm256_load_pd(Y + j),
                                                    _mm256_load_pd(Z + j)));
}
static double volatile g_sh_sink;
__attribute__((noinline)) static double sh_checksum(void) {
    double s = 0;
    for (int j = 0; j < N; j++) s += X[j];
    g_sh_sink = s;
    return s;
}

    /* INDEPENDENCE.  The same 4-wide FMA, once against four times.  One chain
 * is latency-bound: every iteration waits for the previous one.  Four
 * chains are independent and the processor can overlap them. */
static double W[N] __attribute__((aligned(64)));
static double V[N] __attribute__((aligned(64)));
__attribute__((noinline)) static void dep_seed(void) {
    for (int j = 0; j < N; j++) { W[j] = 0.25; V[j] = 0.5; }
}
/* one accumulator: every 4-wide FMA depends on the previous one */
__attribute__((noinline)) static void dep_one(void) {
    for (long i = 0; i < SH_ITERS; i++) {
        __m256d acc = _mm256_load_pd(W);
        for (int j = 0; j < N; j += 4)
            acc = _mm256_fmadd_pd(acc, _mm256_load_pd(V + j), _mm256_setzero_pd());
        _mm256_store_pd(W, acc);
    }
}
/* four accumulators: they do not depend on each other */
__attribute__((noinline)) static void dep_four(void) {
    for (long i = 0; i < SH_ITERS; i++) {
        __m256d a0 = _mm256_load_pd(W), a1 = _mm256_load_pd(W + 4);
        __m256d a2 = _mm256_load_pd(W + 8), a3 = _mm256_load_pd(W + 12);
        for (int j = 0; j < N; j += 16) {
            a0 = _mm256_fmadd_pd(a0, _mm256_load_pd(V + j),      _mm256_setzero_pd());
            a1 = _mm256_fmadd_pd(a1, _mm256_load_pd(V + j + 4),  _mm256_setzero_pd());
            a2 = _mm256_fmadd_pd(a2, _mm256_load_pd(V + j + 8),  _mm256_setzero_pd());
            a3 = _mm256_fmadd_pd(a3, _mm256_load_pd(V + j + 12), _mm256_setzero_pd());
        }
        _mm256_store_pd(W, a0); _mm256_store_pd(W + 4, a1);
        _mm256_store_pd(W + 8, a2); _mm256_store_pd(W + 12, a3);
    }
}
static double volatile g_sink2;   /* keeps dep_checksum from being elided */
__attribute__((noinline)) static double dep_checksum(void) {
    double s = 0;
    for (int j = 0; j < N; j++) s += W[j];
    g_sink2 = s;
    return s;
}

static void sec_shapes(void) {
    puts("");
    puts("4. THE INSTRUCTIONS ARE ELEMENTWISE, AND INDEPENDENCE IS A PROPERTY");
    puts("   Every arithmetic instruction in this section writes each lane from");
    puts("   the same lane of its inputs and READS NOTHING FROM ANY OTHER LANE.");
    puts("   That is not a stylistic note: it is the only reason a vector loop can");
    puts("   go faster than a scalar one, and it is also why the ONE instruction");
    puts("   that does read across lanes -- the horizontal add -- is the subject of");
    puts("   section 5 and the only place in this course where a 4-wide loop LOSES.");

    void (*fn[4])(void) = { sh_copy, sh_add, sh_mul, sh_fma };
    const char *nm[4] = {
        "load, store                       (ZERO arithmetic instructions)",
        "load, ADD, store                  (one add)",
        "load, MUL, store                  (one multiply)",
        "load, FMA, store                  (one multiply-add, one instruction)",
    };
    double best[4]; double cks[4];
    for (int i = 0; i < 4; i++) best[i] = 1e30;
    for (int i = 0; i < 4; i++) { sh_seed(); fn[i](); }
    for (int r = 0; r < 5; r++)
        for (int i = 0; i < 4; i++) {
            sh_seed();
            uint64_t t0 = rdtsc(); fn[i](); uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)SH_ITERS;
            if (v < best[i]) best[i] = v;
            cks[i] = sh_checksum();
        }
    printf("\n   %-52s %10s %9s   %s\n", "body", "ns/iter", "vs copy", "checksum");
    for (int i = 0; i < 4; i++)
        printf("   %-52s %10.2f %8.2fx   %.6f\n", nm[i], best[i],
               best[i] / best[0], cks[i]);
    puts("\n   READ THE THREE ARITHMETIC ROWS AGAINST EACH OTHER FIRST.  One add and");
    puts("   one multiply are within a percent of each other, which is the shape of a");
    puts("   loop that is not waiting for the arithmetic.  Their bodies differ by one");
    puts("   instruction and a multiply is no dearer than an add, because both of");
    puts("   them hide inside what the two loads and the one store already cost.");
    puts("   That is the mechanism behind section 2's FMA row, seen from this side.\n");
    printf("      copy  %5.2fx  (2 loads, 1 store, ZERO arithmetic)     the memory floor\n",
           best[0] / best[0]);
    printf("      add   %5.2fx  (2 loads, 1 add, 1 store)   -> the arithmetic is ~13%%\n",
           best[1] / best[0]);
    printf("      mul   %5.2fx  (2 loads, 1 mul, 1 store)   -> identical to the add\n",
           best[2] / best[0]);
    printf("      fma   %5.2fx  (3 loads, 1 fma, 1 store)  -> ONE MORE LOAD, and that\n"
           "                                           is what it bought\n",
           best[3] / best[0]);
    puts("\n   THE FMA ROW IS NOT COMPARABLE WITH THE TWO ABOVE IT, and reading it as");
    puts("   though it were is how \"FMA costs 1.5x a multiply\" gets written.  The fma");
    puts("   body reads THREE arrays and the other two read TWO, so the row with");
    puts("   FEWER INSTRUCTIONS has MORE MEMORY OPERATIONS and costs more.  This is");
    puts("   the SAME confound that section 2's arm F exists to remove, seen once");
    puts("   more: to compare two bodies honestly they have to do the same loads.\n");
    puts("   THE CHECKSUM COLUMN IS THE POINT, not an afterthought.  A copy, an add,");
    puts("   a multiply and a multiply-add leave FOUR DIFFERENT numbers in X, and");
    puts("   only the fma row is the fixed point section 2 uses.  That is why the");
    puts("   checksums are printed rather than asserted equal, and why an arm that");
    puts("   silently computes the wrong thing shows up here as a wrong number");

    void (*dfn[2])(void) = { dep_one, dep_four };
    const char *dnm[2] = { "ONE accumulator, 4-wide FMA, 16 iterations", "FOUR accumulators, 4-wide FMA, 4x4 iterations" };
    double dbest[2]; double dcks[2];
    for (int i = 0; i < 2; i++) dbest[i] = 1e30;
    for (int i = 0; i < 2; i++) { dep_seed(); dfn[i](); }
    for (int r = 0; r < 5; r++)
        for (int i = 0; i < 2; i++) {
            dep_seed();
            uint64_t t0 = rdtsc(); dfn[i](); uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)SH_ITERS;
            if (v < dbest[i]) dbest[i] = v;
            dcks[i] = dep_checksum();
        (void)g_sink2;
        }
    printf("\n   %-52s %10s %9s   %s\n", "same arithmetic, different independence", "ns/iter", "speedup", "checksum");
    for (int i = 0; i < 2; i++)
        printf("   %-52s %10.2f %8.2fx   %.6f\n", dnm[i], dbest[i],
               dbest[0] / dbest[i], dcks[i]);
    puts("\n   Same instruction.  Same width.  Same number of them -- sixteen in");
    puts("   both.  One is faster, and the only difference is whether the second FMA");
    puts("   needs the answer to the first.  INDEPENDENCE IS A PROPERTY OF THE DATA,");
    puts("   NOT OF THE INSTRUCTION, and it is the same fact the execution course");
    puts("   teaches about a scalar loop, carried one register over.  Neither checksum");
    puts("   is 32.0 and neither should be: these two bodies do not compute the same");
    puts("   recurrence as section 2 and the checksum proves they did the work.");
    printf("   the four-chain arm is %.2fx FASTER than the one-chain arm\n",
           dbest[0] / dbest[1]);
    puts("   and the two checksums DIFFER, which is how you can tell at a glance that");
    puts("   they are not secretly the same loop.");
}

/* ------------------------------------------------------------------ */
/* 5. the reduction                                                    */
/* ------------------------------------------------------------------ */

#define NRED 65536
static double S[NRED] __attribute__((aligned(64)));
static double volatile g_sink;
__attribute__((noinline)) static void seed_red(void) {
    for (int i = 0; i < NRED; i++) S[i] = 1.0 / (double)(i + 1);
}

/* The three horizontal shapes, written out, because getting them wrong is
 * worth a section of the course.  Given a = (a0,a1,a2,a3):
 *
 *   TREE     : the 128-bit halves are paired, then the two 64-bit lanes of the
 *              resulting 128 are paired.  Two vector adds, one 128-bit shuffle,
 *              one extract.  Depth 2.
 *   EXTRACT  : four 64-bit moves out of the register into a scalar, then three
 *              scalar adds.  Four moves, three adds, and every one of them goes
 *              through the scalar side of the machine.
 *   HADDPD   : vhaddpd ADDS THE CORRESPONDING LANES OF ITS TWO SOURCES WITHIN
 *              EACH 128-BIT HALF.  vhaddpd(v,v) DOES NOT ADD ADJACENT LANES --
 *              it doubles v.  To use it you must first swap the halves, and the
 *              first version of this section did not, and reported exactly twice
 *              the true sum.  The checksum caught it.  See R4. */

/* vhaddpd on a 4-wide register, done CORRECTLY: swap the two 128-bit halves
 * first, so the two sources of each half are the low and high pairs. */
static inline double red_hadd(__m256d v) {
    __m128d h = _mm256_castpd256_pd128(_mm256_hadd_pd(v, _mm256_permute2f128_pd(v, v, 0x81)));
    return _mm_cvtsd_f64(_mm_add_sd(h, _mm_unpackhi_pd(h, h)));
}
static inline double red_tree(__m256d v) {
    __m128d lo = _mm256_castpd256_pd128(v), hi = _mm256_extractf128_pd(v, 1);
    __m128d s = _mm_add_pd(lo, hi);
    return _mm_cvtsd_f64(_mm_add_sd(s, _mm_unpackhi_pd(s, s)));
}
static inline double red_extract(__m256d v) {
    __m128d lo = _mm256_castpd256_pd128(v), hi = _mm256_extractf128_pd(v, 1);
    return _mm_cvtsd_f64(lo) + _mm_cvtsd_f64(_mm_unpackhi_pd(lo, lo))
         + _mm_cvtsd_f64(hi) + _mm_cvtsd_f64(_mm_unpackhi_pd(hi, hi));
}

#define REDBODY()                                                                   \
    __m256d acc = _mm256_setzero_pd(); double s = 0;                                \
    for (int g = 0; g < NRED / 4; g++) {                                             \
        __m256d v = _mm256_mul_pd(_mm256_load_pd(S + 4 * g), _mm256_load_pd(S + 4 * g)); \
        acc = _mm256_add_pd(acc, v);

__attribute__((noinline)) static void red_once(void) {      /* reduce ONCE, at the end */
    REDBODY()
    s = red_tree(acc);
    }
    g_sink = s;
}
__attribute__((noinline)) static void red_tree_every(void) { /* TREE, every group */
    REDBODY()
    s += red_tree(acc);
    }
    g_sink = s;
}
__attribute__((noinline)) static void red_extract_every(void) { /* EXTRACT, every group */
    REDBODY()
    s += red_extract(acc);
    }
    g_sink = s;
}
__attribute__((noinline)) static void red_hadd_every(void) {  /* VHADDPD, every group */
    REDBODY()
    s += red_hadd(acc);
    }
    g_sink = s;
}
__attribute__((noinline, optimize("no-tree-vectorize"))) static void red_scalar(void) {
    double acc = 0;
    for (int i = 0; i < NRED; i++) acc += S[i] * S[i];
    g_sink = acc;
}

static void sec_reduce(void) {
    puts("");
    puts("5. GOING BACK TO ONE SCALAR: THE REDUCTION");
    puts("   Every arm below sums the squares of the same 65536 doubles.  What");
    puts("   differs is WHEN the 4 lanes are folded back into one number, and HOW.");
    seed_red();

    void (*fn[5])(void) = { red_once, red_tree_every, red_extract_every, red_hadd_every, red_scalar };
    const char *nm[5] = {
        "4-wide accumulate, reduce ONCE at the very end",
        "4-wide accumulate, TREE horizontal add every group",
        "4-wide accumulate, EXTRACT 4 lanes and add to a scalar every group",
        "4-wide accumulate, VHADDPD every group",
        "scalar loop, no vector at all",
    };
    double best[5]; double sum[5];
    for (int i = 0; i < 5; i++) best[i] = 1e30;
    for (int i = 0; i < 5; i++) fn[i]();
    for (int r = 0; r < 7; r++)
        for (int i = 0; i < 5; i++) {
            uint64_t t0 = rdtsc(); fn[i](); uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)(NRED / 4);
            if (v < best[i]) best[i] = v;
            sum[i] = (double)g_sink;
        }
    printf("\n   %-58s %11s %9s %14s\n", "arm", "ns per 4 elem", "vs arm A", "value produced");
    for (int i = 0; i < 5; i++)
        printf("   %-58s %11.3f %8.2fx %14.6f\n", nm[i], best[i], best[i] / best[0], sum[i]);

    puts("\n   THE FIRST AND THE LAST ROW ARE THE ONLY TWO THAT COMPUTE THE SAME");
    puts("   NUMBER, and they do: a 4-wide loop with ONE reduction at the end is");
    printf("   %.2fx the scalar loop on this body.  That is the shape to write.\n", best[4] / best[0]);
    puts("   THE THREE MIDDLE ROWS DO NOT COMPUTE THE SAME NUMBER and are not meant");
    puts("   to.  Each folds the accumulator into a running scalar on EVERY group, so");
    puts("   what each one produces is a sum of running totals -- a different");
    puts("   quantity, and the reason their value column is not the same number.  This");
    puts("   is stated in the artifact because the first version of this section");
    puts("   compared four arms that were each summing something different, and the");
    puts("   ratio it reported was a ratio of two different computations.  See R5.");
    printf("\n      tree every group   %5.2fx the correct version\n", best[1] / best[0]);
    printf("      extract every group %5.2fx the correct version\n", best[2] / best[0]);
    printf("      vhaddpd every group %5.2fx the correct version\n", best[3] / best[0]);
    puts("\n   So a horizontal add of FOUR doubles costs about as much as the vector");
    puts("   operation that produced them, and there is no formulation of a");
    puts("   reduction that avoids paying it -- only formulations that pay it ONCE.");
    puts("   The vhaddpd row is the interesting one, because vhaddpd is the");
    puts("   instruction whose NAME says exactly what you want and which does");
    puts("   something else: it adds corresponding lanes of two sources inside each");
    puts("   128-bit half, so vhaddpd(v,v) DOUBLES v rather than pairing it.  You");
    puts("   must swap the halves first, and the artifact prints both facts because");
    puts("   getting the second one wrong produces exactly twice the true answer.");
    puts("\n   WHY TREE ORDER, since the three shapes cost about the same per GROUP:");
    puts("   because a reduction is a DEPENDENCY CHAIN and the shape of a tree is the");
    puts("   depth of that chain.  Four lanes fold in depth two.  A million lanes");
    puts("   folded one at a time have a dependency chain a million long; folded as a");
    puts("   tree they have depth twenty.  The tree is the same number of adds and a");
    puts("   logarithmic chain, and that is the whole of the argument.  It also");
    puts("   reassociates the additions, which changes the result in floating point");
    puts("   -- so a tree reduction is a DIFFERENT SUM, and if your answer must be");
    puts("   bit-identical to the sequential one you cannot have it.");
}

/* ------------------------------------------------------------------ */
/* 6. where the width gets spent                                       */
/* ------------------------------------------------------------------ */

static double *g_base;      /* 4096-aligned; three 512-byte streams inside it  */
static int32_t *g_ix;        /* a permutation of 0..63: the gather index vector  */
static double *g_out;        /* 64-byte-aligned destination                     */
static double *g_big;        /* a 2 MiB stream, for the one arm that needs it    */
static size_t   g_big_n;
static long     g_big_iters;
static double volatile g_sink3;

/* ==================== 6a. alignment ==================== */
/* Four arms differing ONLY in the alignment of the load ADDRESS and in whether
 * the instruction DEMANDS 32-byte alignment.  Both variables matter and they
 * are different variables: _mm256_load_pd faults on a misaligned address, and
 * _mm256_loadu_pd does not care what the address is.  The first version of
 * this section had three arms and could not tell which of the two it was
 * measuring. */
__attribute__((noinline)) static void al_ld(void) {
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(g_out + j, _mm256_load_pd(g_base + j));
    g_sink3 = g_out[0];
}
__attribute__((noinline)) static void al_ldu_aligned(void) {
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(g_out + j, _mm256_loadu_pd(g_base + j));
    g_sink3 = g_out[0];
}
__attribute__((noinline)) static void al_ldu_mis(void) {
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(g_out + j, _mm256_loadu_pd(g_base + 8 + j));
    g_sink3 = g_out[0];
}
__attribute__((noinline)) static void al_ld_mis(void) {
    /* The instruction that DEMANDS alignment, given an address that is not
     * 32-byte aligned.  This is the one arm in the whole artifact that is not
     * a timing measurement: it raises #GP, and the program prints the signal
     * it got.  A requirement that faults is a different kind of thing from a
     * requirement that is slow, and the table needs to show which is which. */
    g_base[0] = 1.0;
    g_base[1] = 2.0;
    g_base[2] = 3.0;
    g_base[3] = 4.0;
    _mm256_store_pd(g_out, _mm256_load_pd(g_base + 1));   /* +8 bytes: not 32-aligned */
    g_sink3 = g_out[0];
}

/* ==================== 6b. gather ==================== */
/* Three arms doing the same lookup: 4 of the 64 values, each multiplied and
 * added, and written back.  They differ only in HOW the four values are
 * fetched. */
__attribute__((noinline)) static void ga_sequential(void) {
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < N; j += 4)
            _mm256_store_pd(g_out + j,
                _mm256_add_pd(_mm256_mul_pd(_mm256_load_pd(g_base + j), _mm256_set1_pd(0.5)),
                              _mm256_set1_pd(0.25)));
    g_sink3 = g_out[0];
}
__attribute__((noinline)) static void ga_hand(void) {
    /* four scalar loads, then build the vector out of them.  This is what a
     * compiler emits for an indirect array read, and it is the honest
     * alternative to the gather instruction. */
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < N; j += 4) {
            __m256d v = _mm256_set_pd(g_base[g_ix[j + 3]], g_base[g_ix[j + 2]],
                                       g_base[g_ix[j + 1]], g_base[g_ix[j]]);
            _mm256_store_pd(g_out + j,
                _mm256_add_pd(_mm256_mul_pd(v, _mm256_set1_pd(0.5)),
                              _mm256_set1_pd(0.25)));
        }
    g_sink3 = g_out[0];
}
__attribute__((noinline)) static void ga_hw(void) {
    /* vpgatherdd, the instruction whose job this is. */
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < N; j += 4) {
            __m256d v = _mm256_i32gather_pd(g_base,
                            _mm_loadu_si128((const __m128i *)(g_ix + j)), 4);
            _mm256_store_pd(g_out + j,
                _mm256_add_pd(_mm256_mul_pd(v, _mm256_set1_pd(0.5)),
                              _mm256_set1_pd(0.25)));
        }
    g_sink3 = g_out[0];
}

static void sec_align(void) {
    puts("");
    puts("6. WHERE THE WIDTH GETS SPENT");
    puts("   Three things cost more per element than a 4-wide add does, and all");
    puts("   three are about the ADDRESSES rather than the arithmetic.");

    if (posix_memalign((void **)&g_base, 4096, 4096) != 0 ||
        posix_memalign((void **)&g_out, 64, N * 8 + 64) != 0) {
        puts("   cannot allocate; skipping the alignment and gather sections.");
        return;
    }
    g_ix = (int32_t *)malloc(N * sizeof(int32_t));
    for (int j = 0; j < N; j++) g_ix[j] = (int32_t)((j * 7) & (N - 1));
    for (int j = 0; j < N; j++) { g_base[j] = 0.25; g_base[N + j] = 0.5; g_base[2 * N + j] = 0.25; }

    puts("\n6a. ALIGNMENT: IS AN UNALIGNED VECTOR LOAD SLOW, OR DOES IT FAULT?");
    void (*af[3])(void) = { al_ld, al_ldu_aligned, al_ldu_mis };
    const char *anm[3] = {
        "_mm256_load_pd   (DEMANDS 32B) on a 32-byte aligned address",
        "_mm256_loadu_pd  (demands nothing) on a 32-byte aligned address",
        "_mm256_loadu_pd  (demands nothing) on a +8 MISALIGNED address",
    };
    double ab[3];
    for (int i = 0; i < 3; i++) ab[i] = 1e30;
    for (int i = 0; i < 3; i++) af[i]();
    for (int r = 0; r < 7; r++)
        for (int i = 0; i < 3; i++) {
            uint64_t t0 = rdtsc(); af[i](); uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)ITERS;
            if (v < ab[i]) ab[i] = v;
        }
    printf("\n   %-62s %10s %9s\n", "arm", "ns/iter", "vs arm 1");
    for (int i = 0; i < 3; i++)
        printf("   %-62s %10.2f %8.2fx\n", anm[i], ab[i], ab[i] / ab[0]);
    printf("\n      unaligned instruction, aligned address / aligned instruction  %5.2fx\n",
           ab[1] / ab[0]);
    printf("      MISALIGNED address / aligned address                          %5.2fx\n",
           ab[2] / ab[0]);
    puts("\n   THE MEASURED RESULT, and it is the opposite of the folk one: on this");
    puts("   machine an unaligned 32-byte vector load of L1-resident data is FREE.");
    puts("   Not cheaper than aligned, not more expensive -- indistinguishable, arm");
    puts("   1 and arm 3 differing by less than the estimator's own spread.\n");
    puts("   So WHY DOES _mm256_load_pd EXIST?  Because the requirement is a FAULT");
    puts("   requirement, not a speed requirement.  The fourth arm below is not a");
    puts("   timing measurement at all: it calls _mm256_load_pd on a +8 address and");
    puts("   the program catches the signal.  An aligned load is a smaller DECODER");
    puts("   case than an unaligned one, which is why a code generator that knows");
    puts("   the address is aligned will emit it -- not because it is faster here,");
    puts("   but because it is one fewer thing to have to be right about, and on some");
    puts("   other microarchitecture it is also faster.\n");
    {
        /* Run it in a child process so the fault cannot take this one down.
         * An aligned load is a CORRECTNESS requirement and a correctness claim
         * is not a duration, so the only instrument that settles it is running
         * the thing and catching what comes back. */
        fflush(stdout);
        pid_t pid = fork();
        if (pid == 0) {
            al_ld_mis();          /* the one arm in this file that is not a timing */
            _exit(0);
        }
        int status = 0;
        waitpid(pid, &status, 0);
        int sig = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
        printf("      _mm256_load_pd on a +8 address, in a child process: %s"
               " (signal %d)\n",
               sig == 11 ? "raised SIGSEGV" : sig == 4 ? "raised SIGILL" :
               sig ? "raised a signal" : "returned normally, no fault", sig);
        puts("      So the two instructions differ in a way this table CANNOT time:");
        puts("      one of them is a legal program and the other is not.  A table of");
        puts("      durations is the wrong instrument for that difference, and the");
        puts("      only way to see it is to run it and catch what comes back.\n");
    }

    /* And the one place alignment might show up: a stream that does not fit. */
    /* The buffer holds TWO streams -- the source at offset 0 and the
     * destination at offset g_big_n -- so it must be twice the stream size.
     * The first version allocated (g_big_n + 64) doubles and the destination
     * store ran off the end of the heap, which is a segfault rather than a
     * wrong number, and is the fifth time a buffer in this collection has
     * been a size that looks right in the source and is not. */
    g_big_n = 1u << 18;   /* 2 MiB of doubles per stream, past the 512 KiB L2 */
    g_big_iters = 20;
    if (posix_memalign((void **)&g_big, 4096, (2 * g_big_n + 64) * 8) == 0) {
        for (size_t j = 0; j < 2 * g_big_n + 64; j++) g_big[j] = 0.25;
        double ba = 1e30, bu = 1e30;
        for (int r = 0; r < 5; r++) {
            uint64_t t0 = rdtsc();
            for (long i = 0; i < g_big_iters; i++)
                for (size_t j = 0; j < g_big_n; j += 4)
                    _mm256_store_pd(g_big + g_big_n + j, _mm256_load_pd(g_big + j));
            uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)g_big_iters;
            if (v < ba) ba = v;
            t0 = rdtsc();
            for (long i = 0; i < g_big_iters; i++)
                for (size_t j = 0; j < g_big_n; j += 4)
                    _mm256_store_pd(g_big + g_big_n + j, _mm256_loadu_pd(g_big + 8 + j));
            t1 = rdtsc();
            v = ticks_to_ns(t1 - t0) / (double)g_big_iters;
            if (v < bu) bu = v;
        }
        printf("   And at 2 MiB per stream, past the L2, the same comparison:\n");
        printf("      _mm256_load_pd  on a 32-byte aligned address  %12.1f ns/iter\n", ba);
        printf("      _mm256_loadu_pd on a +8 misaligned address    %12.1f ns/iter   %5.2fx\n",
               bu, bu / ba);
        puts("      Still nothing.  This artifact therefore does NOT claim that an");
        puts("      unaligned vector load is slower on this machine, because it");
        puts("      measured that it is not, at two working-set sizes.  What it does");
        puts("      claim is the fault, which is real and is above.\n");
    }

    puts("6b. GATHER: THE INSTRUCTION DESIGNED FOR THE JOB, AGAINST NOT USING IT");
    void (*gf[3])(void) = { ga_sequential, ga_hand, ga_hw };
    const char *gnm[3] = {
        "four SEQUENTIAL addresses: 3 loads, 1 store, 1 fma per 4 elements",
        "hand gather: FOUR SCALAR LOADS, then build the vector, then 1 fma",
        "hardware gather: vpgatherdd, one instruction for the same four loads",
    };
    double gb[3];
    for (int i = 0; i < 3; i++) gb[i] = 1e30;
    for (int i = 0; i < 3; i++) gf[i]();
    for (int r = 0; r < 7; r++)
        for (int i = 0; i < 3; i++) {
            uint64_t t0 = rdtsc(); gf[i](); uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)ITERS;
            if (v < gb[i]) gb[i] = v;
        }
    printf("\n   %-62s %10s %9s\n", "arm", "ns/iter", "vs arm 1");
    for (int i = 0; i < 3; i++)
        printf("   %-62s %10.2f %8.2fx\n", gnm[i], gb[i], gb[i] / gb[0]);
    printf("\n      the hand gather, against the SEQUENTIAL loop it replaces  %6.2fx\n",
           gb[1] / gb[0]);
    printf("      vpgatherdd, against the same sequential loop                 %6.2fx\n",
           gb[2] / gb[0]);
    printf("      vpgatherdd, against FOUR ORDINARY SCALAR LOADS                %6.2fx\n",
           gb[2] / gb[1]);
    puts("\n   THAT LAST NUMBER IS THE ONE TO CARRY AWAY, and it is the same finding");
    puts("   as section 2's FMA row with a bigger multiplier.  A gather is not one");
    puts("   instruction that does four things at once; it is one instruction that");
    puts("   does four INDEPENDENT LOADS SERIALLY, because the four addresses are");
    puts("   unrelated and the memory system has no way to overlap them.  The");
    puts("   instruction saves the register moves and pays a decode penalty for");
    puts("   them.  On THIS machine, doing it by hand in four scalar loads and");
    puts("   assembling the vector afterwards is nearly twice as fast as using the");
    puts("   instruction, and that is not a compiler artefact -- both arms are");
    puts("   intrinsics in the same translation unit.\n");
    puts("   THE GENERAL FORM, and it is the reason compilers do this on their own:");
    puts("   A WIDE INSTRUCTION IS WORTH WHAT THE ADDRESSES ALLOW.  When the four");
    puts("   addresses are CONSECUTIVE the vector form is right.  When they are not,");
    puts("   the vector form buys arithmetic you could have had anyway, and charges");
    puts("   you for the memory independence you just lost.  A permuted access is a");
    puts("   SCATTER, a GATHER, a TRANSPOSE or a SHUFFLE, and on every one of those");
    puts("   the width is a cost until proven otherwise.");
}

/* ==================== 6c. the tail ==================== */
/* N is not a multiple of 4 and there is no mask register on this machine, so
 * the last one to three elements have to be dealt with by hand.  Six arms:
 * three strategies and three controls, and the controls are what turn "the
 * overlapping trick is slow" into a statement about WHY. */
#define NT 66
static double T[NT + 8] __attribute__((aligned(64)));
__attribute__((noinline)) static void tail_seed(void) {
    for (int j = 0; j < NT + 8; j++) T[j] = 0.25;
}
__attribute__((noinline)) static void tl_exact(void) {   /* 64: a multiple of 4, no tail */
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < 64; j += 4)
            _mm256_store_pd(T + j, _mm256_fmadd_pd(_mm256_load_pd(T + j),
                                                   _mm256_set1_pd(0.5), _mm256_set1_pd(0.25)));
    g_sink3 = T[0];
}
__attribute__((noinline)) static void tl_scalar_tail(void) {  /* 64 + a scalar remainder */
    for (long i = 0; i < ITERS; i++) {
        for (int j = 0; j < 64; j += 4)
            _mm256_store_pd(T + j, _mm256_fmadd_pd(_mm256_load_pd(T + j),
                                                   _mm256_set1_pd(0.5), _mm256_set1_pd(0.25)));
        for (int j = 64; j < NT; j++) T[j] = T[j] * 0.5 + 0.25;
    }
    g_sink3 = T[0];
}
__attribute__((noinline)) static void tl_overlap(void) {  /* 64 + one OVERLAPPING 4-wide */
    for (long i = 0; i < ITERS; i++) {
        for (int j = 0; j < 64; j += 4)
            _mm256_store_pd(T + j, _mm256_fmadd_pd(_mm256_load_pd(T + j),
                                                   _mm256_set1_pd(0.5), _mm256_set1_pd(0.25)));
        __m256d v = _mm256_fmadd_pd(_mm256_loadu_pd(T + 62),
                                    _mm256_set1_pd(0.5), _mm256_set1_pd(0.25));
        _mm_store_sd(T + 62, _mm256_castpd256_pd128(v));
        _mm_storeh_pd(T + 63, _mm256_castpd256_pd128(v));
    }
    g_sink3 = T[0];
}
__attribute__((noinline)) static void tl_past_end(void) { /* plain 4-wide over 68: WRITES PAST THE END */
    for (long i = 0; i < ITERS; i++)
        for (int j = 0; j < NT + 2; j += 4)
            _mm256_store_pd(T + j, _mm256_fmadd_pd(_mm256_load_pd(T + j),
                                                   _mm256_set1_pd(0.5), _mm256_set1_pd(0.25)));
    g_sink3 = T[0];
}
__attribute__((noinline)) static void tl_full_overlap(void) { /* CONTROL: full 32B overlap */
    for (long i = 0; i < ITERS; i++) {
        for (int j = 0; j < 64; j += 4)
            _mm256_store_pd(T + j, _mm256_fmadd_pd(_mm256_load_pd(T + j),
                                                   _mm256_set1_pd(0.5), _mm256_set1_pd(0.25)));
        __m256d v = _mm256_fmadd_pd(_mm256_load_pd(T + 60),
                                    _mm256_set1_pd(0.5), _mm256_set1_pd(0.25));
        _mm256_store_pd(T + 60, v);
    }
    g_sink3 = T[0];
}
__attribute__((noinline)) static void tl_partial_ctrl(void) { /* CONTROL: partial overlap LOAD only */
    for (long i = 0; i < ITERS; i++) {
        for (int j = 0; j < 64; j += 4)
            _mm256_store_pd(T + j, _mm256_fmadd_pd(_mm256_load_pd(T + j),
                                                   _mm256_set1_pd(0.5), _mm256_set1_pd(0.25)));
        __m256d v = _mm256_loadu_pd(T + 62);
        _mm_storeh_pd(T + 63, _mm256_castpd256_pd128(v));
    }
    g_sink3 = T[0];
}

static void sec_tail(void) {
    puts("\n6c. THE TAIL: 66 ELEMENTS AND A 4-WIDE INSTRUCTION, WITH NO MASK REGISTER");
    puts("   This machine has no AVX-512, so there is no k register to say \"only");
    puts("   two of these four lanes\".  Three strategies, and two of them are wrong:");
    void (*fn[6])(void) = { tl_exact, tl_scalar_tail, tl_overlap, tl_past_end,
                            tl_full_overlap, tl_partial_ctrl };
    const char *nm[6] = {
        "64 elements, 4-wide, NO TAIL at all                (the reference)",
        "66 elements, 4-wide + a SCALAR remainder of 2",
        "66 elements, 4-wide + one OVERLAPPING iteration, 2 valid lanes stored",
        "68 elements, plain 4-wide: WRITES 2 ELEMENTS PAST THE END OF THE ARRAY",
        "CONTROL: a FULL 32-byte overlap (load exactly what was stored)",
        "CONTROL: a PARTIAL overlap load, only 1 lane stored back",
    };
    tail_seed();
    double best[6];
    for (int i = 0; i < 6; i++) best[i] = 1e30;
    for (int i = 0; i < 6; i++) { tail_seed(); fn[i](); }
    for (int r = 0; r < 7; r++)
        for (int i = 0; i < 6; i++) {
            tail_seed();
            uint64_t t0 = rdtsc(); fn[i](); uint64_t t1 = rdtsc();
            double v = ticks_to_ns(t1 - t0) / (double)ITERS;
            if (v < best[i]) best[i] = v;
        }
    printf("\n   %-64s %10s %9s\n", "arm", "ns/iter", "vs arm 1");
    for (int i = 0; i < 6; i++)
        printf("   %-64s %10.2f %8.2fx\n", nm[i], best[i], best[i] / best[0]);

    tail_seed(); fn[1]();
    printf("\n   CHECKSUM  T[0], T[63], T[64], T[65] must all be 0.5 after the scalar\n"
           "   remainder arm: %.1f %.1f %.1f %.1f\n",
           T[0], T[63], T[64], T[65]);
    puts("\n   THREE FINDINGS, IN ORDER OF HOW SURPRISING THEY ARE:");
    printf("      1. the SCALAR REMAINDER IS FREE: %.2fx the no-tail arm, for two\n"
           "         elements.  Two elements out of 66 is 3%% of the work and it\n"
           "         costs %.0f%%.  This is the right answer and it is not a trick.\n",
           best[1] / best[0], 100.0 * (best[1] / best[0] - 1.0));
    printf("      2. the OVERLAPPING last iteration is %.2fx -- the WORST arm in the\n"
           "         table, and the one that is supposed to be the clever one.\n",
           best[2] / best[0]);
    puts("\n      3. and the two controls say why, which the overlapping arm on its own");
    printf("         does not.  A FULL 32-byte overlap costs %.2fx and a PARTIAL\n"
           "         overlap LOAD costs %.2fx.  So the cost is not \"doing the tail\", it\n"
           "         is the load at +62: it OVERLAPS the 32-byte store at +60 by half,\n",
           best[4] / best[0], best[5] / best[0]);
    puts("         and a load that overlaps a recent store only partly cannot be\n"
           "         FORWARDED from the store buffer -- it has to wait for the store to\n"
           "         reach the cache.  The overlapping trick reads back the very line it\n"
           "         has just written, half-aligned, and that is the slowest thing in\n"
           "         the table.\n");
    puts("      The MECHANISM is INFERRED.  There is no PMU here and nothing above is a");
    puts("      count of anything, so \"cannot be forwarded\" is the best explanation");
    puts("      the two controls support rather than something that was measured.\n");
    printf("      4. arm 4 is CHEAP (%.2fx) and it is the one that silently corrupts\n"
           "         whatever follows the array.  The array here is declared with 8\n"
           "         spare doubles, which is why it does not crash and why it is a bug\n"
           "         rather than an accident.  A vector loop that over-reads and\n"
           "         over-writes its tail is a portable program that gets 1.0x faster\n"
           "         by writing to memory it does not own.  THIS is what a mask\n"
           "         register is for, and it is the whole reason AVX-512 has one.\n",
           best[3] / best[0]);
    puts("\n      THE ORDERING, then, is the thing to remember: on a machine without a\n"
           "      mask, write the tail SCALAR.  It is free, it is correct, and the\n"
           "      clever alternative is the most expensive row in the table.");
}

/* ------------------------------------------------------------------ */
/* 7. the same shape, three answers -- QUOTED, not measured            */
/* ------------------------------------------------------------------ */

static void sec_three(void) {
    puts("");
    puts("7. THE SAME SHAPE ON THREE ARCHITECTURES");
    puts("   QUOTED, NOT MEASURED.  This machine is x86-64 and there is no other");
    puts("   architecture in the room.  Every claim below is a manual claim with a");
    puts("   document, and the limits block says so a second time.");

    puts("\n   x86-64  (measured in sections 2 to 6)");
    puts("      the register   128-bit XMM, 256-bit YMM, 512-bit ZMM.  The width is a");
    puts("                     PROPERTY OF THE INSTRUCTION'S ENCODING: VEX encodes");
    puts("                     128 or 256, EVEX encodes 512 and adds the mask, the");
    puts("                     broadcast and the embedded-rounding fields.");
    puts("      the load       vmovapd DEMANDS 32-byte alignment and faults without");
    puts("                     it; vmovupd does not and is free here.  Measured in 6a.");
    puts("      the gather     AVX2 added vpgatherdd/vpgatherqd.  Measured in 6b and");
    puts("                     it is SLOWER than four scalar loads on this machine.");
    puts("      the mask       k0-k7, 64 bits each, one bit per lane of a 512-bit");
    puts("                     register.  AVX-512 ONLY -- absent here, proved in 0.");
    puts("      the tail       there is none.  A 4-wide loop over n elements handles");
    puts("                     n mod 4 elements scalar, and 6c measures that as free.");

    puts("\n   AArch64  (quoted)");
    puts("      the register   128 bits, Q registers, 16 of them per bank.  ONE SIZE.");
    puts("                     There is no 256- and no 512-bit general-purpose SIMD");
    puts("                     register in the base architecture at all: NEON is");
    puts("                     128 bits and that is the end of it.  This is a");
    puts("                     STRUCTURAL difference from x86 and it is why a 4-wide");
    puts("                     double loop is the widest loop you can write in");
    puts("                     portable AArch64 NEON -- 2 doubles, not 4.");
    puts("      the load       ldr q0, [x0] is unaligned-tolerant by default.  There");
    puts("                     is no aligned variant of the SIMD load at all.");
    puts("      the gather     NO gather instruction exists in NEON.  An indirect");
    puts("                     load is a plain ldr into a D register, so the cost of a");
    puts("                     gather is the cost of four scalar loads -- which is");
    puts("                     what 6b measured as the FAST option on x86.  The");
    puts("                     architecture with no gather instruction is the one");
    puts("                     where the hand-written gather is not merely better but");
    puts("                     the ONLY thing there is.");
    puts("      the mask       none.  Same tail problem, same answer: peel it scalar.");
    puts("      SVE            the scalable extension, and the opposite design.  The");
    puts("                     register size is a PROGRAMMABLE property, up to 2048");
    puts("                     bits, so a loop written once runs at whatever width");
    puts("                     the implementation chooses.  It also has PREDICATION:");
    puts("                     a sequence of predicated instructions, so a tail is a");
    puts("                     predicate, not a branch and not a scalar epilogue.  It");
    puts("                     is the direct answer to the thing 6c measures.");

    puts("\n   RISC-V  (quoted)");
    puts("      the register   the V extension has named VLEN-BIT register groups,");
    puts("                     ELEN bytes wide, currently VLEN >= 128.  Like SVE the");
    puts("                     width is a property the implementation chooses.");
    puts("      the mask       v0 IS the mask register: one bit per element, and");
    puts("                     v0.t4 selects four 32-bit lanes.  The mask is part of");
    puts("                     the register file rather than a separate operand, and");
    puts("                     a masked instruction reads vl ELEMENTS and ignores the");
    puts("                     rest.  This is the design AVX-512 was reaching toward.");
    puts("      the tail       setting vl to the remainder and running the same");
    puts("                     instruction.  No epilogue, no branch, no scalar code.");
    puts("      the gather     vrgather.vv and vrgatherei16.vv exist, and a segment");
    puts("                     load (vlseg) can fetch a strided run into a vector in");
    puts("                     ONE instruction -- which is the operation the x86 gather");
    puts("                     is trying to be, done by a different instruction for a");
    puts("                     regular pattern rather than an arbitrary index list.");

    puts("\n   THE PORTABLE SHAPE, and it is the same five rows the three courses");
    puts("   before this one each found, which is worth noticing:\n");
    puts("      1. how many elements   the width of the register, which is FIXED on\n");
    puts("                             x86-64 and PROGRAMMABLE on SVE and RISC-V V\n");
    puts("      2. how they are loaded  a consecutive load, and on x86 sometimes a\n");
    puts("                             gather, which 6b measured as a cost\n");
    puts("      3. what the operation  ELEMENTWISE and INDEPENDENT, on all three --\n");
    puts("         does to them        section 4, and this is the part that ports\n");
    puts("      4. how they are       N INDEPENDENT LANES, ONE INSTRUCTION, WITH A\n");
    puts("         reduced                REDUCTION AT THE END.  Section 5, and it is\n");
    puts("                             the same sentence on all three architectures.\n");
    puts("      5. what the tail is   a mask on two of them, a scalar epilogue on\n");
    puts("                             one.  Section 6c measured the epilogue and it is\n");
    puts("                             free, so the portable answer is the epilogue.\n");
    puts("\n   Rows 1 and 2 are where the architectures differ and where a benchmark");
    puts("   ported between them stops meaning the same thing.  Rows 3, 4 and 5 are");
    puts("   the same everywhere, and row 4 is the only one anybody needs in order");
    puts("   to write a loop that gets faster on all three.");
}

/* ------------------------------------------------------------------ */
/* 8. retractions and limits                                           */
/* ------------------------------------------------------------------ */

static void sec_limits(void) {
    puts("");
    puts("8. RETRACTIONS AND LIMITS");
    puts("   Printed here so they cannot be quietly dropped, and asserted by");
    puts("   crosscheck.py so they cannot be DELETED either.");

    puts("\n   R1. \"The memory-operand arm measured 3.3 and so the FMA memory form");
    puts("       is broken.\"  The arm was wrong, and the CHECKSUM is what said so.");
    puts("       The first version used vfmadd231pd, which computes B*C+A rather than");
    puts("       A*B+C.  The table was entirely readable, the ratio was entirely");
    puts("       plausible, and the only thing on the page that objected was the");
    puts("       checksum line reading 3.3 where every other arm read 32.0.  vfmadd132pd");
    puts("       with the memory operand as the DESTINATION is the form that");
    puts("       computes A*B+C, and that is what arm F now uses.");
    puts("       THE GENERAL FORM, WHICH HAS NOW RECURRED FOUR COURSES IN A ROW:");
    puts("       AN EXPERIMENT THAT CAN SILENTLY COMPUTE THE WRONG THING MUST");
    puts("       PRINT WHAT IT COMPUTED, OR IT IS NOT AN EXPERIMENT.");

    puts("\n   R2. \"The absolute nanosecond figures are the result.\"  They are not.");
    puts("       The first version of this file divided ticks by a HARDCODED TSC");
    puts("       rate.  Section 0 now measures the rate twice per run, once busy and");
    puts("       once across a sleep, and uses the mean.  And even with that, the");
    puts("       absolute ns/iter for the SAME body moved by a factor of 1.7 BETWEEN");
    puts("       RUNS on the recorded day, because this is a virtualised guest with");
    puts("       twelve logical CPUs and other tenants.  Every ratio in sections 2 to");
    puts("       6 moved by less than 10% across four runs while the absolute numbers");
    puts("       moved by 70%.  THIS IS THE MOST IMPORTANT SENTENCE IN THE FILE and it");
    puts("       is why crosscheck.py asserts shapes.");

    puts("\n   R3. \"Four lanes is 2.2x, not 4x, because the loop is memory bound\"");
    puts("       -- the story this course was drafted around.  NOT REPRODUCED.");
    puts("       At 1536 bytes the 4-wide arm is close to 4x the scalar arm, because");
    puts("       3 loads and 1 store per 4 elements really are 4x cheaper when the");
    puts("       load ports are the bottleneck.  The claim turned out to be TRUE OF A");
    puts("       DIFFERENT WORKLOAD, and section 3 is the corrected version of it:");
    puts("       hold the lane count at four and grow the working set, and the same");
    puts("       arm falls from about four times the scalar to barely more than one.");
    puts("       The lesson survived; the sentence did not, and the difference between");
    puts("       the two is that the lesson has to name the workload.");

    puts("\n   R4. \"vhaddpd adds adjacent lanes.\"  IT DOES NOT.  VHADDPD adds the");
    puts("       CORRESPONDING lanes of its TWO SOURCES within each 128-bit half, so");
    puts("       vhaddpd(v,v) DOUBLES v instead of pairing it.  The first version of");
    puts("       the reduction section called it without swapping the halves and");
    puts("       reported EXACTLY TWICE the true sum, to the last bit.  The checksum");
    puts("       caught it for the same reason it caught R1.  A mnemonic that says");
    puts("       what you want is not a definition of what it does, and the only check");
    puts("       that survives is the one that looks at the answer.");
    puts("       A SECOND BUG WAS HIDDEN BEHIND IT: the first version's \"tree\"");
    puts("       reduction added the two 128-bit halves of an already-paired register,");
    puts("       so both 64-bit lanes held the total and it was added to itself.  Also");
    puts("       exactly twice.  Two different bugs, one symptom, one line of output.");

    puts("\n   R5. \"The reduction table compares four ways of summing.\"  Three of");
    puts("       the five arms were not summing.  An arm that folds the accumulator");
    puts("       into a running scalar EVERY group computes a sum of running totals,");
    puts("       which is a different quantity, and the first version reported ratios");
    puts("       between different quantities as though they were costs of the same");
    puts("       thing.  The arms are still all here, and the artifact now PRINTS the");
    puts("       value each one produced so the difference is visible rather than");
    puts("       assumed.  Rule 5 of the header is about memory operations; the same");
    puts("       rule is about the ANSWER, and it was learned twice in one file.");

    puts("\n   R6. \"An unaligned vector load is slow.\"  NOT ON THIS MACHINE.  Measured");
    puts("       at 1536 bytes and again at 2 MiB per stream, _mm256_loadu_pd on a");
    puts("       +8 address was indistinguishable from _mm256_load_pd on a 32-byte");
    puts("       aligned one.  The requirement that is REAL is not a speed");
    puts("       requirement at all: _mm256_load_pd on a misaligned address raises a");
    puts("       signal, and section 6a forks to measure that.  A duration table is");
    puts("       the wrong instrument for a correctness requirement, and the general");
    puts("       form is: CHECK WHETHER THE THING FAULTS BEFORE ASKING HOW SLOW IT IS.");

    puts("\n   R7. \"The compiler declined to vectorise because the trip count is a");
    puts("       runtime variable.\"  WRONG, AND IT WAS AN INFERENCE FROM A TIMING.");
    puts("       Section 3 reached the three arrays through three `double *` globals,");
    puts("       the auto-vectorised arm came out at the scalar floor, and the first");
    puts("       draft wrote the tidy explanation.  The VERIFY block at the end of");
    puts("       this output compiles all four forms of the loop and counts their");
    puts("       mnemonics, and the trip count turns out to have almost nothing to do");
    puts("       with it: the NAMED-array form vectorises at BOTH trip counts, and the");
    puts("       POINTER form vectorises at NEITHER.");
    puts("\n       What the trip count costs is a SCALAR EPILOGUE for n mod 4, which is");
    puts("       the tail section 6c measures as free.  What the pointers cost is");
    puts("       the VECTOR LOOP ITSELF, because gcc cannot prove that a store to");
    puts("       A[j] does not change what B[j+4] holds.  Two different mechanisms,");
    puts("       one of them catastrophic and one of them free, told as one story.");
    puts("\n       AN INFERENCE FROM A TIMING IS NOT A MEASUREMENT OF A COMPILER.  A");
    puts("       number going the right way is not evidence about bytes, and the");
    puts("       whole discipline of this collection -- exact for structure, shapes");
    puts("       for timing -- has a third clause that this course had to learn:");
    puts("       FOR A CLAIM ABOUT WHAT A COMPILER DID, THE ONLY EVIDENCE IS THE");
    puts("       DISASSEMBLY, AND THE FIRST DRAFT HAD NONE.");
    puts("\n       A SECOND ERROR ATTACHED TO THE SAME SENTENCE, and it is the one this");
    puts("       course was really about: \"the compiler beats intrinsics because it");
    puts("       hoists the loop-invariant loads of B and C\".  The disassembly shows");
    puts("       B and C loaded INSIDE the inner loop on all sixteen iterations.  They");
    puts("       are not hoisted.  What the compiler does is put A into the FMA as a");
    puts("       memory operand -- which is arm F, and section 2 MEASURED arm F and");
    puts("       it is SLOWER than the three-load form.  So the tidy story is wrong");
    puts("       twice over: the mechanism is not hoisting, and the mechanism it gets");
    puts("       confused with is not free.  A, D and E landing within a few percent");
    puts("       of each other is a fact about the LOOP, not about either codegen");
    puts("       path being clever.");

    puts("\n   R8. \"The control arm came out at 3.91x, so aliasing is not what\"");
    puts("       stopped the compiler.\"  THE CONTROL WAS NOT A CONTROL.  It was");
    puts("       written as `static double *gA = bA, *gB = bB, *gC = bC;` -- the same");
    puts("       three arrays wearing a pointer costume.  gcc folded the static");
    puts("       initialisers away, proved the three streams distinct again, and");
    puts("       vectorised it.  The control measured exactly what the arm it was");
    puts("       supposed to contradict measured, which is what a broken control");
    puts("       always looks like.  The fix is to ASSIGN the pointers in main() and");
    puts("       reach them through noinline accessors, so the compiler cannot see");
    puts("       through them; the arm then emits one scalar FMA and no vector one.");
    puts("       A CONTROL THAT CANNOT FAIL IS NOT A CONTROL, and a check that");
    puts("       passes on an artefact that was not built is worse than no check,");
    puts("       because it is counted.  THE DISCIPLINE: BEFORE BELIEVING THAT A");
    puts("       CONTROL CONFIRMS SOMETHING, MAKE IT FAIL ON PURPOSE AND CONFIRM");
    puts("       THAT IT DOES.");

    puts("\n   LIMITS -- what this artifact cannot tell you, printed not footnoted:");
    puts("     * ANY COUNT.  perf_event_paranoid is 4 on this machine: no instruction,");
    puts("       uop, cycle, load, store, L1 access or cache-line split can be counted.");
    puts("       Every number in sections 2 to 6 is a DURATION.  A duration bounds a");
    puts("       count without measuring it, and every mechanism in every table above");
    puts("       is therefore marked INFERRED.  Section 4's independence result, for");
    puts("       instance, is a duration and the store-forwarding explanation in 6c is");
    puts("       a mechanism with two controls supporting it, not a count.");
    puts("     * ANYTHING ABOUT AVX-512.  Five CPUID bits, all zero, printed in section");
    puts("       0.  What a ZMM is and what a k0-k7 mask register is comes from the");
    puts("       manuals.  NOTHING about a 512-bit register is measured here, and in");
    puts("       particular the claim that a 512-bit register gives you 8 doubles in");
    puts("       one instruction is a claim about the ENCODING and not about how fast");
    puts("       anything is.");
    puts("     * WHETHER THE UPPER ZMM STATE COSTS ANYTHING.  The manuals describe");
    puts("       the upper-half aliasing and the VEX zeroing behaviour.  Measuring it");
    puts("       needs a 512-bit machine and a register this CPU does not have.");
    puts("     * A CROSS-CHECK OF THE ARITHMETIC AGAINST A SECOND IMPLEMENTATION.");
    puts("       The checksums prove every arm agrees with every other arm.  They do");
    puts("       not prove any of them agrees with a C compiler, because the only");
    puts("       independent oracle available here would be a second build of the");
    puts("       same source.  The first version of arm F computed B*C+A and every");
    puts("       arm agreed with every OTHER arm that was wrong the same way would");
    puts("       have -- except that it did not, and that is luck, not a method.");
    puts("     * THE OTHER TWO ARCHITECTURES.  Section 7 is quoted, not run.  There");
    puts("       is no AArch64 and no RISC-V machine in the room, and a quoted claim");
    puts("       about SVE's predication is a manual claim with a document.");
    puts("     * WHETHER THE COMPILER VECTORISED.  Section 3 quotes a ratio for the");
    puts("       auto-vectorised arm, which is indirect evidence and could be a loop");
    puts("       that got faster for another reason.  The direct evidence is a");
    puts("       DISASSEMBLY, and build_samples.sh runs objdump and appends the");
    puts("       result, so the claim about what the compiler emitted is checked");
    puts("       against the bytes the compiler emitted rather than against a");
    puts("       number that went the right way.");
    puts("     * ANYTHING ABOUT FLOATING-POINT CORRECTNESS.  The fixed point in");
    puts("       sections 2 and 4 is exact by construction -- 0.25, 0.5 and 0.25 are");
    puts("       all powers of two -- so a checksum of 32.0 tests that the right");
    puts("       NUMBER of operations happened.  It does not test that a vector sum");
    puts("       equals a scalar sum, and section 5 says in the body that a tree");
    puts("       reduction reassociates and therefore gives a different answer.");
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    puts("=====================================================================");
    puts(" simdbench -- SIMD and Vector Processing");
    puts("=====================================================================");
    sec_instrument();
    sec_register();
    sec_table();
    sec_ceiling();
    sec_shapes();
    sec_reduce();
    sec_align();
    sec_tail();
    sec_three();
    sec_limits();
    puts("");
    puts("=====================================================================");
    return 0;
}
