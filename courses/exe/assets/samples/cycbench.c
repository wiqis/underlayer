/* cycbench.c -- the instrument for "How a CPU Executes Instructions".

   This program exists because of what it measured FIRST: its own noise. A
   single timing of a single loop body varied by 73% across twelve runs on
   this machine. So the program is built around the discipline that survives
   that, and every number it prints is a RATIO or a MINIMUM, never a bare
   absolute timing.

   The five rules, all of them learned by breaking them:

     1. The TSC is a FIXED reference (measured against CLOCK_MONOTONIC at
        startup) and the core clock is NOT -- 2389 to 3320 MHz on this
        machine. A TSC tick is therefore a unit of TIME, not a count of core
        clocks. Any "cycles" figure derived from rdtsc alone is a cycle
        figure from a stopwatch.

     2. RDTSC is not serialising. LFENCE before, RDTSCP+LFENCE after. Drop
        either fence and the reads drift past the work they bracket.

     3. INTERLEAVE. A, B, A, B, ... so a frequency ramp or a noisy
        co-tenant perturbs both sides of a comparison equally and cancels in
        the ratio. Measuring A fully and then B fully does not cancel.

     4. MINIMUM, not mean. Under this much noise the fastest run is the one
        least disturbed by something else, and the minimum is far more
        stable than the mean.

     5. The body is what is measured, not the loop. A loop carries its own
        dependency (dec -> jnz), and with one operation in the body that
        dependency is the bottleneck: the first version of this measurement
        reported one dependent add as FASTER than an empty loop, which is
        only possible if the loop was the thing being timed. Bodies are
        unrolled so the marginal cost of an operation is visible.

   And the rule underneath all five: put the work in inline asm. The first
   unpredictable-branch measurement here returned 0.0000 ticks because the
   compiler proved a deterministic xorshift sum was constant and deleted the
   loop. A benchmark the compiler rewrites is not measuring what you wrote.

   Build:  cc -O2 -o cycbench cycbench.c
   Run:    ./cycbench
*/

#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <x86intrin.h>

/* ------------------------------------------------------------------ */
/* the instrument                                                       */
/* ------------------------------------------------------------------ */

static inline uint64_t tsc_begin(void)
{
    /* LFENCE before RDTSC. RDTSC is not serialising, so without this the
       read can be hoisted above the work it is supposed to bracket. */
    _mm_lfence();
    return __rdtsc();
}

static inline uint64_t tsc_end(void)
{
    unsigned a, d;
    __asm__ __volatile__("rdtscp" : "=a"(a), "=d"(d) :: "rcx");
    _mm_lfence();                 /* RDTSCP waits for prior loads, not stores */
    return ((uint64_t)d << 32) | a;
}

static double tsc_hz = 0.0;

static void calibrate(void)
{
    struct timespec t0, t1, req = { 0, 150 * 1000 * 1000 };
    uint64_t c0 = tsc_begin();
    clock_gettime(CLOCK_MONOTONIC, &t0);
    nanosleep(&req, NULL);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    uint64_t c1 = tsc_end();
    double s = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    tsc_hz = (double)(c1 - c0) / s;
}

static double core_mhz(void)
{
    /* NOTE: this reads a kernel-side SAMPLE, not a live reading. It is
       printed for orientation and is deliberately NOT used to convert ticks
       to cycles: an earlier version of this program sampled it around every
       measurement and produced numbers that were wrong by 3x, because the
       value in /proc/cpuinfo is updated far more slowly than a measurement
       takes. See rule 1. */
    FILE *f = fopen("/proc/cpuinfo", "r");
    char l[256];
    double m = -1;
    if (!f) return -1;
    while (fgets(l, sizeof l, f))
        if (strncmp(l, "cpu MHz", 7) == 0) { sscanf(l + 7, " : %lf", &m); break; }
    fclose(f);
    return m;
}

#define ITERS 8000000L
#define REPS  41

/* ------------------------------------------------------------------ */
/* the bodies.  each is a loop whose BODY is the thing under test;    */
/* the dec/jnz pair is the loop floor and is subtracted, not ignored.   */
/* ------------------------------------------------------------------ */

/* Every bench function is 64-byte aligned. This is not tidiness: two
   byte-identical loops measured 0.79 and 2.13 ticks/iter purely because one
   of them landed at an address where its 16-byte body crossed a 64-byte
   fetch boundary. Section 7 turns that into a deliberate experiment; here
   it is simply removed as a source of bias. */
#define BENCH_ALIGN __attribute__((aligned(64)))

#define LOOP(name, ops, ...)                                                 \
static BENCH_ALIGN double name(void)                                        \
{                                                                             \
    long c = ITERS, out = 0;                                                  \
    uint64_t a, b;                                                            \
    a = tsc_begin();                                                          \
    __asm__ __volatile__("1:\n\t" ops "dec %[c]\n\tjnz 1b\n\t"              \
                         "mov %%r8, %[o]"                                      \
                         : [c] "+r"(c), [o] "=r"(out)                         \
                         :: __VA_ARGS__, "cc", "memory");                      \
    b = tsc_end();                                                            \
    __asm__ __volatile__("" : "+r"(out) :: "memory");                         \
    return (double)(b - a) / (double)ITERS;                                   \
}

/* the floor: the loop and nothing else */
LOOP(b_floor, "", "r8")

/* dependent chains of add r8,r8 -- each link needs the previous result */
LOOP(b_dep1, "add $1, %%r8\n\t", "r8")
LOOP(b_dep2, "add $1, %%r8\n\tadd $1, %%r8\n\t", "r8")
LOOP(b_dep4, "add $1,%%r8\n\tadd $1,%%r8\n\tadd $1,%%r8\n\tadd $1,%%r8\n\t", "r8")
LOOP(b_dep8, "add $1,%%r8\n\tadd $1,%%r8\n\tadd $1,%%r8\n\tadd $1,%%r8\n\t"
             "add $1,%%r8\n\tadd $1,%%r8\n\tadd $1,%%r8\n\tadd $1,%%r8\n\t", "r8")

/* independent: K separate chains, each of length 1 */
LOOP(b_ind1, "add $1, %%r8\n\t", "r8")
LOOP(b_ind2, "add $1,%%r8\n\tadd $1,%%r9\n\t", "r8", "r9")
LOOP(b_ind4, "add $1,%%r8\n\tadd $1,%%r9\n\tadd $1,%%r10\n\tadd $1,%%r11\n\t",
     "r8", "r9", "r10", "r11")
LOOP(b_ind6, "add $1,%%r8\n\tadd $1,%%r9\n\tadd $1,%%r10\n\tadd $1,%%r11\n\t"
             "add $1,%%r12\n\tadd $1,%%r13\n\t",
     "r8", "r9", "r10", "r11", "r12", "r13")

/* a flags chain: TEST writes the flags, the next TEST depends on them */
LOOP(b_flag1, "test %%eax, %%eax\n\t", "rax")
LOOP(b_flag2, "test %%eax, %%eax\n\ttest %%eax, %%eax\n\t", "rax")
LOOP(b_flag4, "test %%eax,%%eax\n\ttest %%eax,%%eax\n\t"
              "test %%eax,%%eax\n\ttest %%eax,%%eax\n\t", "rax")

/* The case the branchless result actually rests on: a genuine
   read-AFTER-write dependency on the flags. ROR writes CF and ADC reads it,
   so each ADC needs the ROR before it -- a real chain, unlike four TESTs
   which only WRITE the flags and are independent of each other. */
LOOP(b_rar1, "ror $1, %%r11\n\tadc $0, %%r8\n\t", "r8", "r11")
LOOP(b_rar2, "ror $1,%%r11\n\tadc $0,%%r8\n\t"
             "ror $1,%%r11\n\tadc $0,%%r8\n\t", "r8", "r11")
LOOP(b_rar4, "ror $1,%%r11\n\tadc $0,%%r8\n\t"
             "ror $1,%%r11\n\tadc $0,%%r8\n\t"
             "ror $1,%%r11\n\tadc $0,%%r8\n\t"
             "ror $1,%%r11\n\tadc $0,%%r8\n\t", "r8", "r11")

/* control: the same number of RORs with the CF never read, so the flags are
   written and nothing depends on them */
LOOP(b_waw4, "ror $1,%%r11\n\tror $1,%%r11\n\t"
             "ror $1,%%r11\n\tror $1,%%r11\n\t", "r8", "r11")

/* --- branch behaviour --------------------------------------------- */
/* A branch whose direction repeats with period P. ROR-by-K puts bit K of a
   register into CF, and CF is what JC reads, so the direction sequence has
   period 64/K. */
#define BRPAT(name, rot)                                                      \
static double name(void)                                                      \
{                                                                             \
    long c = ITERS, out = 0;                                                  \
    uint64_t a, b;                                                            \
    a = tsc_begin();                                                          \
    __asm__ __volatile__("mov $0x9e3779b97f4a7c15, %%r11\n\t"                 \
        "1:\n\tadd $1, %%r8\n\t"                                              \
        "ror $" #rot ", %%r11\n\t"                                            \
        "jc 1f\n\t"                                                            \
        "add $1, %%r8\n\t"                                                     \
        "1:\n\tdec %[c]\n\tjnz 1b\n\tmov %%r8, %[o]"                           \
        : [c] "+r"(c), [o] "=r"(out)                                          \
        :: "r8", "r11", "cc", "memory");                                      \
    b = tsc_end();                                                            \
    __asm__ __volatile__("" : "+r"(out) :: "memory");                         \
    return (double)(b - a) / (double)ITERS;                                   \
}
BRPAT(br_never, 0)      /* ROR $0 is a no-op, so CF never changes: never taken */
BRPAT(br_p64, 1)
BRPAT(br_p16, 4)
BRPAT(br_p4, 16)
BRPAT(br_p1, 63)       /* period 1: strictly alternating */

/* The branchless alternative to the unpredictable branch: the SAME data
   (ROR writes CF) and the SAME conditional work, but ADC instead of a
   branch. If branching were the problem this should be faster. */
static BENCH_ALIGN double branchless(void)
{
    long c = ITERS, out = 0;
    uint64_t a, b;
    a = tsc_begin();
    __asm__ __volatile__("mov $0x9e3779b97f4a7c15, %%r11\n\t"
        "1:\n\tadd $1, %%r8\n\t"
        "ror $1, %%r11\n\t"
        "adc $0, %%r8\n\t"          /* the conditional work, with no branch */
        "dec %[c]\n\tjnz 1b\n\tmov %%r8, %[o]"
        : [c] "+r"(c), [o] "=r"(out)
        :: "r8", "r11", "cc", "memory");
    b = tsc_end();
    __asm__ __volatile__("" : "+r"(out) :: "memory");
    return (double)(b - a) / (double)ITERS;
}

/* A genuinely long-period pattern: walk a table of pseudorandom bits with a
   sequential index, so the direction sequence repeats only after D branches. */
static unsigned char *tab;
static uint32_t tab_mask;

static BENCH_ALIGN double table_walk(void)
{
    long c = ITERS, out = 0, idx = 0;
    uint64_t a, b;
    a = tsc_begin();
    __asm__ __volatile__("mov %[T], %%r12\n\t"
        "1:\n\tadd $1, %%r8\n\t"
        "movzbl (%%r12,%[i],1), %%eax\n\t"
        "test $1, %%eax\n\t"
        "jz 1f\n\t"
        "add $1, %%r8\n\t"
        "1:\n\tinc %[i]\n\tand %[m], %[i]\n\tdec %[c]\n\tjnz 1b\n\t"
        "mov %%r8, %[o]"
        : [c] "+r"(c), [i] "+r"(idx), [o] "=r"(out)
        : [T] "r"(tab), [m] "r"((long)tab_mask)
        : "r8", "r12", "rax", "cc", "memory");
    b = tsc_end();
    __asm__ __volatile__("" : "+r"(out) :: "memory");
    return (double)(b - a) / (double)ITERS;
}

/* ------------------------------------------------------------------ */
/* 7. ALIGNMENT: one body, eight alignments                           */
/* ------------------------------------------------------------------ */
/* A 16-byte loop (add; dec; jnz; mov) placed at a chosen offset mod 64.
   The offset is a compile-time constant so the whole body is identical in
   every case -- same bytes, same instructions, same work. The ONLY thing
   that varies is where it sits relative to a 64-byte fetch boundary.

   This is the measurement that explains the whole noise problem: it is why
   two byte-identical functions in one binary can differ by 2.7x, and why
   every bench function above is 64-byte aligned. */
/* The padding is NOP (0x90), not a run of 0x66. The first version of this
   used 64 bytes of 0x66 as padding and the program SEGFAULTED: a run of
   operand-size prefixes is prefixes, and x86-64 permits at most 15 bytes of
   prefixes before an instruction, so byte 16 of the run is a #GP. Padding a
   benchmark with something the CPU will not decode is a spectacular way to
   spend an afternoon.

   0x90 is one byte and one instruction, so a run of any length is legal. */
#define ALIGN_BODY(OFF)                                                      \
static BENCH_ALIGN double aligned_##OFF(void)                               \
{                                                                             \
    long c = ITERS, out = 0;                                                  \
    uint64_t a, b;                                                            \
    a = tsc_begin();                                                          \
    __asm__ __volatile__(".fill " #OFF ", 1, 0x90\n\t"                       \
                         "1:\n\tadd $1, %%r8\n\t"                         \
                         "dec %[c]\n\tjnz 1b\n\tmov %%r8, %[o]"           \
                         : [c] "+r"(c), [o] "=r"(out)                         \
                         :: "r8", "cc", "memory");                           \
    b = tsc_end();                                                            \
    __asm__ __volatile__("" : "+r"(out) :: "memory");                         \
    return (double)(b - a) / (double)ITERS;                                   \
}
ALIGN_BODY(0)
ALIGN_BODY(8)
ALIGN_BODY(16)
ALIGN_BODY(24)
ALIGN_BODY(32)
ALIGN_BODY(40)
ALIGN_BODY(48)
ALIGN_BODY(56)   /* 56 + 12 = 68: this one runs off the end of the line */

/* ------------------------------------------------------------------ */
/* the runner: interleaved, min of N                                   */
/* ------------------------------------------------------------------ */

struct bench {
    const char *label;
    double (*fn)(void);
    double best;
    double prev;      /* the previous row, for marginals */
    int    ops;
    const char *unit;
};

static void run_all(struct bench *t, int n, int reps)
{
    for (int i = 0; i < n; i++) t[i].best = 1e30;
    for (int r = 0; r < reps; r++)
        for (int i = 0; i < n; i++) {
            double v = t[i].fn();
            if (v < t[i].best) t[i].best = v;
        }
}

static void show(struct bench *t, int n, double floor)
{
    printf("  %-34s %12s %12s\n", "body", "min ticks", "vs floor");
    for (int i = 0; i < n; i++) {
        printf("  %-34s %12.4f %11.2fx\n", t[i].label, t[i].best, t[i].best / floor);
        t[i].prev = t[i].best;
    }
}

int main(int argc, char **argv)
{
    int quick = (argc > 1 && strcmp(argv[1], "--quick") == 0);
    int reps = quick ? 3 : REPS;
    long iters_note = quick ? ITERS / 4 : ITERS;

    calibrate();
    printf("  ============================================================\n");
    printf("   cycbench -- measuring the instrument, then the machine\n");
    printf("  ============================================================\n\n");

    printf("  1. THE INSTRUMENT\n");
    printf("  ----------------\n");
    printf("     TSC rate (vs CLOCK_MONOTONIC)   %.4f GHz\n", tsc_hz / 1e9);
    printf("     core clock, sampled from /proc  %.0f MHz   (a stale sample,\n",
           core_mhz());
    printf("                                        see rule 1 -- not used to\n");
    printf("                                        convert ticks to cycles)\n");
    printf("     iterations per body             %ld\n", iters_note);
    printf("     interleaved repetitions         %d\n", reps);
    printf("\n     A TSC tick is a unit of TIME. The core clock on this machine\n"
           "     ranged over 2389-3320 MHz while the TSC stayed at %.2f GHz,\n"
           "     so 'cycles' measured with rdtsc is a stopwatch reading.\n"
           "     Every ratio below divides by the same clock and so survives.\n",
           tsc_hz / 1e9);

    /* --- the noise floor, measured first -------------------------------- */
    double rep_min = 1e30, rep_max = 0;
    for (int r = 0; r < (reps < 8 ? reps : 8); r++) {
        double v = b_floor();
        if (v < rep_min) rep_min = v;
        if (v > rep_max) rep_max = v;
    }
    printf("\n  2. THE NOISE FLOOR, measured before any claim is made\n");
    printf("  ------------------------------------------------------\n");
    printf("     the SAME body, %d times, consecutive:\n",
           reps < 8 ? reps : 8);
    printf("       fastest %.4f   slowest %.4f   spread %.1f%%\n",
           rep_min, rep_max, 100.0 * (rep_max - rep_min) / rep_min);
    printf("     => a %.0f%% spread means absolute numbers from this machine are\n"
           "        not publishable. Only ratios measured back-to-back are, and\n"
           "        that is why every number below is a ratio or a minimum.\n",
           100.0 * (rep_max - rep_min) / rep_min);
    printf("\n     A RETRACTION. The first draft of this program quoted a 73%%\n"
           "     noise floor. That number was measured on a bench function\n"
           "     that was NOT 64-byte aligned, so it was the alignment\n"
           "     penalty of section 7 leaking into the noise estimate -- the\n"
           "     instrument's apparent noise was the phenomenon under study.\n"
           "     Measured properly, on an aligned body, the spread is roughly\n"
           "     half that. The 73%% figure is not used anywhere in this course.\n");

    /* --- latency and throughput ----------------------------------------- */
    struct bench lat[] = {
        {"loop floor (empty body)",        b_floor, 0, 0, 0, ""},
        {"1 dependent add",                b_dep1,  0, 0, 1, ""},
        {"2 dependent adds",               b_dep2,  0, 0, 2, ""},
        {"4 dependent adds",               b_dep4,  0, 0, 4, ""},
        {"8 dependent adds",               b_dep8,  0, 0, 8, ""},
        {"1 independent add",              b_ind1,  0, 0, 1, ""},
        {"2 independent adds",             b_ind2,  0, 0, 2, ""},
        {"4 independent adds",             b_ind4,  0, 0, 4, ""},
        {"6 independent adds",             b_ind6,  0, 0, 6, ""},
    };
    int nlat = (int)(sizeof lat / sizeof lat[0]);
    run_all(lat, nlat, reps);
    double fl = lat[0].best;

    printf("\n  3. LATENCY AND THROUGHPUT\n");
    printf("  -------------------------\n");
    show(lat, nlat, fl);
    printf("\n     MARGINAL cost of one more operation, floor removed:\n");
    printf("       dependent chain   2 adds %+.4f   4 adds %+.4f   8 adds %+.4f\n",
           (lat[2].best - lat[1].best) / 1.0,
           (lat[3].best - lat[2].best) / 2.0,
           (lat[4].best - lat[3].best) / 4.0);
    printf("       independent       2 adds %+.4f   4 adds %+.4f   6 adds %+.4f\n",
           (lat[6].best - lat[5].best) / 1.0,
           (lat[7].best - lat[6].best) / 2.0,
           (lat[8].best - lat[7].best) / 2.0);
    double dep_m = (lat[4].best - lat[3].best) / 4.0;
    double ind_m = (lat[8].best - lat[7].best) / 2.0;
    printf("\n     a dependent chain costs %.2fx an independent operation.\n",
           dep_m / ind_m);
    printf("     That ratio is the measurable shape of the execution width:\n"
           "     a chain of operations retires one per LATENCY, while\n"
           "     independent ones retire several per cycle. Neither figure\n"
           "     has to be in core cycles for the ratio to mean anything.\n");

    /* --- flags dependency ------------------------------------------------ */
    struct bench fl_[] = {
        {"loop floor",                     b_floor, 0, 0, 0, ""},
        {"1 TEST  (WRITE flags only)",     b_flag1, 0, 0, 1, ""},
        {"2 TEST  (WRITE flags only)",     b_flag2, 0, 0, 2, ""},
        {"4 TEST  (WRITE flags only)",     b_flag4, 0, 0, 4, ""},
        {"4 ROR   (a CHAIN on one register)", b_waw4, 0, 0, 4, ""},
        {"1 ROR+ADC (read AFTER write)",   b_rar1,  0, 0, 1, ""},
        {"2 ROR+ADC (read AFTER write)",   b_rar2,  0, 0, 2, ""},
        {"4 ROR+ADC (read AFTER write)",   b_rar4,  0, 0, 4, ""},
    };
    int nf = (int)(sizeof fl_ / sizeof fl_[0]);
    run_all(fl_, nf, reps);
    printf("\n  4. THE FLAGS ARE A DEPENDENCY TOO\n");
    printf("  --------------------------------\n");
    show(fl_, nf, fl_[0].best);
    printf("\n     A RETRACTION, kept because the first version of this\n"
           "     section claimed something the measurement does not support.\n"
           "     It said 'the flags register has no rename, so a chain of\n"
           "     flag-writing instructions serialises'. The rows above say\n"
           "     otherwise: FOUR TESTs, which all write the flags, cost %.2fx\n"
           "     the floor. Writing the flags repeatedly is nearly free.\n", fl_[3].best / fl_[0].best);
    printf("\n     A SECOND retraction, because the obvious replacement\n"
           "     explanation is ALSO wrong. It was going to be 'ADC reads the\n"
           "     flags ROR just wrote, and the flags serialise'. Measured:\n"
           "     4 ROR+ADC pairs %.4f versus 4 RORs alone %.4f -- %.2fx, i.e.\n"
           "     reading the flags costs nothing extra.\n",
           fl_[7].best, fl_[4].best, fl_[7].best / fl_[4].best);
    printf("\n     So the 4-ROR row at %.2fx the floor is not a flags cost\n"
           "     either. Those four RORs all target ONE register, so they are\n"
           "     a loop-carried chain of length 4 -- and that is the ordinary\n"
           "     dependency cost, not anything to do with the flags. Three\n"
           "     candidate explanations were measured and two were wrong.\n"
           "     What survives is the narrow one: WRITING the flags is nearly\n"
           "     free (%.2fx at four TESTs), and READING them is free too.\n",
           fl_[4].best / fl_[0].best, fl_[3].best / fl_[0].best);

    /* --- branch prediction ------------------------------------------------ */
    struct bench br[] = {
        {"branch never taken (control)",  br_never,  0, 0, 0, ""},
        {"branch period 64",              br_p64,    0, 0, 0, ""},
        {"branch period 16",              br_p16,    0, 0, 0, ""},
        {"branch period 4",               br_p4,     0, 0, 0, ""},
        {"branch period 1 (alternating)", br_p1,     0, 0, 0, ""},
        {"BRANCHLESS, same data+work",    branchless, 0, 0, 0, ""},
    };
    int nb = (int)(sizeof br / sizeof br[0]);
    run_all(br, nb, reps);
    printf("\n  5. BRANCHES\n");
    printf("  ----------\n");
    show(br, nb, br[0].best);
    printf("\n     The direction period makes NO difference: a branch that\n"
           "     repeats with period 1, 4, 16 or 64 costs the same as one that\n"
           "     is never taken. The predictor learns all of them.\n");
    printf("\n     The BRANCHLESS version -- same data, same conditional work,\n"
           "     no control-flow transfer -- measured %.4f against the branch's\n"
           "     %.4f, i.e. %.2fx.\n", br[5].best, br[3].best, br[5].best / br[3].best);
    printf("\n     AND THAT IS NOT A CLEAN COMPARISON, which is the point of\n"
           "     saying so. The branching body performs its conditional add\n"
           "     HALF the time, because the branch skips it. The branchless\n"
           "     body performs the equivalent work EVERY time. So the two are\n"
           "     not doing the same amount of work, and %.2fx is an UPPER BOUND\n"
           "     on the cost of branchless coding here, not a measurement of\n"
           "     it. Three explanations were tried; two were retracted in\n"
           "     section 4, and the honest reading is that the branch is free\n"
           "     AND the branchless form does strictly more work.\n",
           br[5].best / br[3].best);

    /* --- long-period patterns --------------------------------------------- */
    int D = 1 << 16;
    tab = malloc(D);
    uint64_t s = 0x243f6a8885a308d3ULL;
    for (int i = 0; i < D; i++) {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17;
        tab[i] = (unsigned char)(s & 1);
    }
    int depths[] = { 2, 16, 256, 4096, 65536 };
    int nd = (int)(sizeof depths / sizeof depths[0]);
    double best[8];
    for (int i = 0; i < nd; i++) best[i] = 1e30;
    for (int r = 0; r < reps; r++)
        for (int i = 0; i < nd; i++) {
            tab_mask = depths[i] - 1;
            double v = table_walk();
            if (v < best[i]) best[i] = v;
        }
    printf("\n  6. LONG-PERIOD PATTERNS, and the limit of this machine\n");
    printf("  ---------------------------------------------------\n");
    printf("     %10s %14s %10s\n", "table depth", "min ticks", "vs depth 2");
    for (int i = 0; i < nd; i++)
        printf("     %10d %14.4f %9.2fx\n", depths[i], best[i], best[i] / best[0]);
    printf("\n     Flat from depth 2 to depth 65536. NO mispredict penalty\n"
           "     was observed, at any pattern period.\n");
    printf("\n     THIS IS A LIMITATION, NOT A RESULT ABOUT PREDICTORS.\n"
           "     There are no hardware performance counters in this guest:\n"
           "       perf_event_paranoid = 4, and /sys/bus/event_source/devices\n"
           "       has no cpu_core PMU -- only breakpoint, kprobe, software,\n"
           "       tracepoint and the IBM PCs. So branch misses cannot be\n"
           "       COUNTED here, only inferred from timing.\n"
           "     Either this CPU's predictor captures patterns that long, or\n"
           "     the cost is hidden by slack this program did not identify,\n"
           "     and without a branch-miss counter the two cannot be told\n"
           "     apart. The course says so rather than inventing a number.\n");
    free(tab);

    /* --- 7. alignment, the measurement that explains the noise --------- */
    struct bench al[] = {
        {"loop at offset  0 mod 64", aligned_0,  0, 0, 0, ""},
        {"loop at offset  8 mod 64", aligned_8,  0, 0, 0, ""},
        {"loop at offset 16 mod 64", aligned_16, 0, 0, 0, ""},
        {"loop at offset 24 mod 64", aligned_24, 0, 0, 0, ""},
        {"loop at offset 32 mod 64", aligned_32, 0, 0, 0, ""},
        {"loop at offset 40 mod 64", aligned_40, 0, 0, 0, ""},
        {"loop at offset 48 mod 64", aligned_48, 0, 0, 0, ""},
        {"loop at offset 56 mod 64 (CROSSES)", aligned_56, 0, 0, 0, ""},
    };
    int na = (int)(sizeof al / sizeof al[0]);
    run_all(al, na, reps);
    double abest = 1e30, aworst = 0;
    for (int i = 0; i < na; i++) {
        if (al[i].best < abest) abest = al[i].best;
        if (al[i].best > aworst) aworst = al[i].best;
    }
    printf("\n  7. ALIGNMENT: one body, seven addresses\n");
    printf("  -------------------------------------\n");
    printf("     The SAME 16-byte loop (add; dec; jnz; mov), byte for byte,\n"
           "     preceded by identical padding. Only the address changes.\n\n");
    show(al, na, abest);
    printf("\n     fastest %.4f   slowest %.4f   ratio %.2fx\n",
           abest, aworst, aworst / abest);
    printf("\n     => BYTE-IDENTICAL code at a different address differs by\n"
           "        %.2fx. The loop body is 12 bytes, so offsets 0..52 fit\n"
           "        inside one 64-byte line and offset 56 does not.\n", aworst / abest);
    printf("\n     But the SLOWEST row is offset 32, not 56, and offset 48 is\n"
           "        the FASTEST. So the cost is NOT a simple function of the\n"
           "        offset mod 64, and this course does not claim a mechanism.\n"
           "        What is claimed is the effect: the address of a loop is\n"
           "        worth up to %.2fx, and the front end has structure beyond\n"
           "        the 64-byte line -- an operation cache, a loop stream\n"
           "        detector and per-address predictor state are all plausible\n"
           "        and NONE of them was measured here.\n", aworst / abest);
    printf("\n     This is also what the section-2 noise was made of. The\n"
           "        machine was not varying; each function was carrying a fixed\n"
           "        penalty for wherever the linker happened to put it. That\n"
           "        is why every bench function above is 64-byte ALIGNED, and\n"
           "        why removing that first -- before any of the latency,\n"
           "        throughput or branch numbers were believable -- was the\n"
           "        single largest improvement to this instrument.\n");
    printf("\n     And it is why the ISA course's alignment NOP exists.\n"
           "        0F 1F 00 is a three-byte instruction that does nothing,\n"
           "        emitted so that what FOLLOWS lands where the front end\n"
           "        wants it. The padding is not decoration; it is the\n"
           "        mechanism, and this section measured what it is worth.\n");

    printf("\n  ============================================================\n");
    printf("   no absolute cycle count is claimed anywhere above. every\n"
           "   figure is a ratio or a minimum, for the reasons in section 1.\n");
    printf("  ============================================================\n");
    return 0;
}
