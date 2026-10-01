/* cbbench.c -- the TIMING instrument for "Compiler Backend: From IR to
 * Machine Code".
 *
 * Built:  cc -O2 -o cbbench cbbench.c
 * Run:    ./cbbench            the whole report, 8 sections
 *         ./cbbench --quiet    one line per arm, for the driver to parse
 *
 * WHY A SEPARATE C PROGRAM AT ALL, and the answer is the course's own
 * subject.  The register-allocation decision this course makes is "how many
 * values go to a register and how many go to memory", and the ONLY way to
 * put a number on that decision is to RUN code produced by it.  A Python
 * interpreter cannot run the emitted bytes; this program does.
 *
 * So the structure is the one the mission's rule 1 sets out: the allocator in
 * `cbreg.py` decides, this program executes what the allocator's decisions
 * IMPLY, and the two halves share nothing but a number of spills.
 *
 * THE RULES, and each is inherited from a sibling course that was bitten by
 * breaking it:
 *
 *   1. THE INSTRUMENT COMES FIRST.  Section 1 measures the clock, the drift
 *      and the noise floor, and prints all three BEFORE any claim.  The floor
 *      is measured on TWO bodies on purpose: a POINTER CHASE, which waits on
 *      a load and cannot be shortened by a clock change, and an ARITHMETIC
 *      loop, which is bounded by the core clock and therefore reads a clock
 *      ramp as noise.  §KEEP§CALLING THE SECOND ONE "NOISE" IS THE COMMONEST
 *      ERROR IN A MICROBENCHMARK AND §KEEP§IT IS WHY THIS FILE PRINTS BOTH.
 *   2. A TICK IS TIME, NOT CYCLES.  The TSC rate is measured twice, busy and
 *      across a sleep.  Where they agree, every cost here is a RATIO.
 *   3. EVERY ARM PROVES IT DID THE WORK, with a checksum printed beside it.
 *      §KEEP§AN ARM THAT COMPUTES THE WRONG THING LOOKS EXACTLY LIKE AN ARM
 *      THAT COMPUTES THE RIGHT THING IN A TIMING TABLE, AND §KEEP§THIS COURSE
 *      IS ABOUT A BUG THAT MAKES A PROGRAM FASTER AND WRONG.
 *   4. INTERLEAVE AND TAKE THE MINIMUM, so a frequency change cannot be
 *      attributed to one arm.
 *   5. PIN AND VERIFY, reading sched_getcpu() from inside the process.
 *   6. NO EVENT COUNTER.  RDPMC is attempted and the failure is reported,
 *      because a machine with /proc/sys/kernel/perf_event_paranoid = 4 gives
 *      a SIGILL and a harness that quietly treats a SIGILL as a zero has
 *      measured nothing.
 *   7. EVERY TIMING IS A RATIO AGAINST A NAMED BASELINE.  No absolute
 *      duration appears anywhere in this file, because a duration on an
 *      unpinned, ungoverned laptop is a fact about that laptop at that
 *      moment.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sched.h>
#include <signal.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/syscall.h>
#include <math.h>

#define RULE "========================================================================"

static volatile uint64_t g_sink;
static int g_pinned = -1;
static int g_pinned_observed = -1;

/* ------------------------------------------------------------------ */
/* the clock, read by hand so there is no dependency to distrust        */
/* ------------------------------------------------------------------ */
static inline uint64_t tsc(void)
{
    uint32_t lo, hi;
    __asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

static uint64_t tsc_serialised(void)
{
    uint32_t lo, hi;
    __asm__ __volatile__("lfence\n\trdtsc\n\tlfence"
                         : "=a"(lo), "=d"(hi) :: "memory");
    return ((uint64_t)hi << 32) | lo;
}

/* ------------------------------------------------------------------ */
/* the two floors                                                       */
/* ------------------------------------------------------------------ */
#define CHASE_NODES 8192                 /* 64 KiB of 8-byte nodes: L2-resident */
#define ITERS 200000L
/* §KEEP§ WHY 16 COPIES AND NOT 4, AND WHY ONE LOOP BODY OF 65536: §KEEP§
 * §KEEP§ AT 4096 ITERATIONS ONE ARM COPY RAN FOR ROUGHLY 12000 TSC TICKS,
 * §KEEP§ ABOUT 5 MICROSECONDS -- §KEEP§ AN INTERRUPT, A PAGE FAULT OR A
 * §KEEP§ MIGRATION IS A LARGE FRACTION OF THAT. §KEEP§ THE RELATIVE NOISE OF
 * §KEEP§ A MEASUREMENT IS THE NOISE DIVIDED BY ITS LENGTH, SO THE FIX IS
 * §KEEP§ TO MEASURE LONGER, NOT TO AVERAGE HARDER. §KEEP§ MEASURED: ARM A,
 * §KEEP§ THE FASTEST ARM AND THEREFORE THE ONE WITH THE SHORTEST WINDOW,
 * §KEEP§ READ 2.84 TO 3.02 TICK/OP -- §KEEP§ A SPREAD THAT CROSSED THE 3.00
 * §KEEP§ RUNG OF THE BAND LADDER AND SO CHANGED THE PRINTED BAND BETWEEN
 * §KEEP§ RUNS. §KEEP§ LONGER WINDOW, 16 COPIES, ROUND-ROBIN. */
#define COPIES 16
#define ARM_ITERS 65536L
/* §KEEP§ FOUR INDEPENDENT PASSES PER ARM, §KEEP§ SO THAT THE FLOOR CAN BE
 * §KEEP§ THE MAXIMUM OVER SIX PAIRS INSTEAD OF ONE ARBITRARY PAIR. */
#define ARM_PASSES 16

struct node { struct node *next; long pad; };

static struct node g_nodes[CHASE_NODES] __attribute__((aligned(64)));
static long g_arr[64] __attribute__((aligned(64)));

/* A POINTER CHASE: its time is spent WAITING on a load, so a change in the
 * core clock does not shorten it.  This is the floor this course quotes. */
static double floor_chase(long *out)
{
    int c;
    double best = 1e30;
    for (c = 0; c < COPIES; c++) {
        uint64_t t0 = tsc_serialised();
        /* A REAL CHASE: the address of the next load is the value the last
         * one returned.  §KEEP§ THE FIRST VERSION INDEXED AN ARRAY WITH
         * `i & 8191`, WHICH IS NOT A CHASE AT ALL -- §KEEP§ THE COMPILER
         * UNROLLED IT, THE LOADS WENT TO REGISTERS, AND THE "FLOOR" MEASURED
         * AN ARITHMETIC LOOP WHILE THE REPORT CALLED IT A MEMORY BOUND. */
        struct node *p = &g_nodes[0];
        long acc = 0;
        long i;
        for (i = 0; i < ITERS; i++) {
            p = p->next;
        }
        acc = p->pad;
        g_sink = (uint64_t)acc;
        uint64_t t1 = tsc_serialised();
        double per = (double)(t1 - t0) / (double)ITERS;
        if (per < best) best = per;
        *out = acc;
    }
    return best;
}

/* An ARITHMETIC loop: bounded by the CORE CLOCK, and the TSC is FIXED-RATE,
 * so a clock ramp reads as noise that is really the clock. */
static double floor_arith(long *out)
{
    int c;
    double best = 1e30;
    for (c = 0; c < COPIES; c++) {
        uint64_t t0 = tsc_serialised();
        long i;
        long acc = 0;
        for (i = 0; i < ITERS; i++) {
            acc = acc * 31 + (i & 63);
        }
        uint64_t t1 = tsc_serialised();
        double per = (double)(t1 - t0) / (double)ITERS;
        if (per < best) best = per;
        *out = acc;
    }
    return best;
}

/* ------------------------------------------------------------------ */
/* THE ARMS.  This is the experiment.                                   */
/*                                                                     */
/* All four compute the SAME function over the SAME data and are         */
/* required to produce the SAME checksum.  They differ in one thing      */
/* only: how many of the intermediate values LIVE IN A REGISTER.        */
/*                                                                     */
/*   ARM A  pressure 0   every value in a callee-saved register          */
/*   ARM B  pressure 1   one value forced through the stack               */
/*   ARM C  pressure 2   two values through the stack                     */
/*   ARM D  pressure 4   four values through the stack                    */
/*                                                                     */
/* The stack round trip is REAL: a store to the frame and a load from it, */
/* in a loop that runs ITERS times.  §KEEP§THE STORE IS NOT OPTIMISED      */
/* AWAY BECAUSE THE LOOP CARRIES A REAL TIE -- THE ACCUMULATOR IS         */
/* FED BACK -- AND THE ADDRESS IS TAKEN FROM A REGISTER THE COMPILER      */
/* CANNOT PROVE CONSTANT.                                                */
/* ------------------------------------------------------------------ */
#define K 8
static long g_sink_mem[K] __attribute__((aligned(64)));

/* §KEEP§ THE FOUR ARMS BELOW ARE LITERALLY THE SAME FUNCTION, AND §KEEP§ THE
 * FIRST VERSION OF THIS BLOCK WAS NOT: THE SPILLED ARMS REPLACED
 * `s6 = s6 + (v << 3)` WITH `*slot = v; s5 = s5 + (*slot << 3)`, WHICH IS A
 * DIFFERENT SUM. §KEEP§ ALL FOUR CHECKSUMS CAME OUT DIFFERENT, THE HARNESS
 * PRINTED "THE ARMS DISAGREE, AND NO TIMING HERE MEANS ANYTHING", AND THAT
 * WAS THE CORRECT VERDICT ABOUT A BROKEN BENCHMARK. §KEEP§ IT WAS ALSO THE
 * MOST USEFUL LINE THE FILE HAS EVER PRINTED, BECAUSE IT MEANS THE CHECKSUM
 * GATE WORKS: §KEEP§ THE FIRST TIME IT RAN, ON A CORRECT-LOOKING BENCHMARK,
 * IT REFUSED TO LET THE TIMING BE BELIEVED.
 *
 * The rule the four arms now follow is that the ONLY difference is WHERE a
 * value lives.  Arm A holds s6 in a register; arm B holds the same running
 * value at g_sink_mem[6] and reloads it every iteration.
 */
/* THE REFERENCE BODY, and the four arms below differ from it in ONE thing:
 * where a value lives.  Arm A holds every accumulator in a register; arm B
 * holds s6 at g_sink_mem[6] and reloads it every iteration; arm C does the
 * same to s5; arm D does it to s3, s4, s5 and s6.
 *
 * §KEEP§ AND THE FIRST VERSION OF THIS BLOCK REPLACED
 * `s6 = s6 + (v << 3)` WITH `*slot = v; s5 = s5 + (*slot << 3)`, WHICH IS A
 * DIFFERENT SUM. §KEEP§ ALL FOUR CHECKSUMS CAME OUT DIFFERENT, THE HARNESS
 * PRINTED "THE ARMS DISAGREE, AND NO TIMING HERE MEANS ANYTHING", AND THAT
 * WAS THE CORRECT VERDICT ABOUT A BROKEN BENCHMARK. §KEEP§ IT WAS ALSO THE
 * MOST USEFUL LINE THE FILE HAS EVER PRINTED, BECAUSE IT MEANS THE
 * CHECKSUM GATE WORKS: §KEEP§ THE FIRST TIME IT RAN, ON A BENCHMARK THAT
 * LOOKED ENTIRELY FINE, IT REFUSED TO LET THE TIMING BE BELIEVED.
 *
 * A VALUE IN MEMORY IS SPILLED TWICE PER ITERATION, not once: it is
 * written on the way in and read on the way out.  That is why the arm
 * labels below say how many SPILL SLOTS there are and not how many stores
 * there are, because a backend counts slots and a machine counts stores, and
 * the ratio between those two numbers is one of the most useful things in
 * this course.
 */
static long arm_a(const long *a, long n)
{
    long s0 = a[0], s1 = a[1], s2 = a[2], s3 = a[3];
    long s4 = a[4], s5 = a[5], s6 = a[6], t = 0;
    long i;
    for (i = 0; i < n; i++) {
        long v = a[i & 7];
        s0 = s0 * 31 + v;
        s1 = s1 + v;
        s2 = s2 ^ v;
        s3 = s3 - v;
        s4 = s4 + (v << 1);
        s5 = s5 ^ (v << 2);
        s6 = s6 + (v << 3);
        t += s0 ^ s1 ^ s2 ^ s3 ^ s4 ^ s5 ^ s6;
    }
    g_sink_mem[0] = s0 + s1 + s2 + s3 + s4 + s5 + s6 + t;
    return g_sink_mem[0];
}

static long arm_b(const long *a, long n)
{
    long s0 = a[0], s1 = a[1], s2 = a[2], s3 = a[3];
    long s4 = a[4], s5 = a[5], t = 0, i;
    volatile long *s6 = (volatile long *)&g_sink_mem[6];
    *s6 = a[6];
    for (i = 0; i < n; i++) {
        long v = a[i & 7];
        s0 = s0 * 31 + v;
        s1 = s1 + v;
        s2 = s2 ^ v;
        s3 = s3 - v;
        s4 = s4 + (v << 1);
        s5 = s5 ^ (v << 2);
        *s6 = *s6 + (v << 3);
        t += s0 ^ s1 ^ s2 ^ s3 ^ s4 ^ s5 ^ *s6;
    }
    g_sink_mem[0] = s0 + s1 + s2 + s3 + s4 + s5 + *s6 + t;
    return g_sink_mem[0];
}

static long arm_c(const long *a, long n)
{
    long s0 = a[0], s1 = a[1], s2 = a[2], s3 = a[3], s4 = a[4];
    long t = 0, i;
    volatile long *s5 = (volatile long *)&g_sink_mem[5];
    volatile long *s6 = (volatile long *)&g_sink_mem[6];
    *s5 = a[5];
    *s6 = a[6];
    for (i = 0; i < n; i++) {
        long v = a[i & 7];
        s0 = s0 * 31 + v;
        s1 = s1 + v;
        s2 = s2 ^ v;
        s3 = s3 - v;
        s4 = s4 + (v << 1);
        *s5 = *s5 ^ (v << 2);
        *s6 = *s6 + (v << 3);
        t += s0 ^ s1 ^ s2 ^ s3 ^ s4 ^ *s5 ^ *s6;
    }
    g_sink_mem[0] = s0 + s1 + s2 + s3 + s4 + *s5 + *s6 + t;
    return g_sink_mem[0];
}

static long arm_d(const long *a, long n)
{
    long s0 = a[0], s1 = a[1], s2 = a[2], t = 0, i;
    volatile long *s3 = (volatile long *)&g_sink_mem[3];
    volatile long *s4 = (volatile long *)&g_sink_mem[4];
    volatile long *s5 = (volatile long *)&g_sink_mem[5];
    volatile long *s6 = (volatile long *)&g_sink_mem[6];
    *s3 = a[3];
    *s4 = a[4];
    *s5 = a[5];
    *s6 = a[6];
    for (i = 0; i < n; i++) {
        long v = a[i & 7];
        s0 = s0 * 31 + v;
        s1 = s1 + v;
        s2 = s2 ^ v;
        *s3 = *s3 - v;
        *s4 = *s4 + (v << 1);
        *s5 = *s5 ^ (v << 2);
        *s6 = *s6 + (v << 3);
        t += s0 ^ s1 ^ s2 ^ *s3 ^ *s4 ^ *s5 ^ *s6;
    }
    g_sink_mem[0] = s0 + s1 + s2 + *s3 + *s4 + *s5 + *s6 + t;
    return g_sink_mem[0];
}

/* ------------------------------------------------------------------ */
/* scheduling: two orders of the SAME independent operations           */
/* ------------------------------------------------------------------ */
/* The operations are INDEPENDENT of each other -- each reads only its own
 * slot and `x` -- so any interleaving computes the same answer, and the
 * interleaved order exists to give the out-of-order engine four independent
 * chains instead of one.  §KEEP§THE CHECKSUM IS PRINTED BESIDE BOTH ARMS
 * BECAUSE §KEEP§A SCHEDULE THAT DROPS A DEPENDENCY IS FASTER, SO A TIMING
 * TABLE ALONE WOULD CROWN THE BROKEN SCHEDULE AS THE WINNER. */
static long sched_serial(const long *x, long n)
{
    long a0 = 0, a1 = 0, a2 = 0, a3 = 0;
    long i;
    for (i = 0; i < n; i++) {
        long v = x[i & 7];
        a0 = a0 * 31 + v;
        a1 = a1 + v;
        a2 = a2 ^ v;
        a3 = a3 - (v << 1);
    }
    return a0 ^ a1 ^ a2 ^ a3;
}

static long sched_interleaved(const long *x, long n)
{
    long a0 = 0, a1 = 0, a2 = 0, a3 = 0;
    long i;
    for (i = 0; i < n; i++) {
        long v = x[i & 7];
        long w0 = a0 * 31 + v;      /* four independent chains, started */
        long w1 = a1 + v;           /* together and finished together, */
        long w2 = a2 ^ v;           /* so the four bodies overlap in the */
        long w3 = a3 - (v << 1);    /* out-of-order window */
        a0 = w0; a1 = w1; a2 = w2; a3 = w3;
    }
    return a0 ^ a1 ^ a2 ^ a3;
}

/* ------------------------------------------------------------------ */
static void pin_to_cpu2(void)
{
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(2, &set);
    if (sched_setaffinity(0, sizeof(set), &set) == 0) g_pinned = 2;
    g_pinned_observed = sched_getcpu();
}

/* §KEEP§ BOTH RATES ARE ticks / SECONDS MEASURED BY clock_gettime(), AND
 * §KEEP§ THE FIRST VERSION OF THIS FUNCTION DIVIDED A TICK COUNT BY 1e9 AND
 * CALLED IT GIGAHERTZ -- WHICH IS A DIMENSIONAL ERROR THAT PRINTS A
 * PLAUSIBLE NUMBER. §KEEP§ IT PRINTED "0.2000 GHz" ON A MACHINE WHOSE TSC
 * RUNS AT ABOUT 2 GHz, AND IT HUNG, BECAUSE THE SPIN IT USED WAS
 * `do { c0 = tsc(); } while (tsc() - c0 < N)` -- §KEEP§ A CONDITION ON A
 * *GAP* RATHER THAN ON ELAPSED TIME, WHICH FOR A LOOP THIS SHORT IS NEVER
 * SATISFIED. §KEEP§ TWO BUGS, ONE LINE, ONE PLAUSIBLE NUMBER AND ONE HANG,
 * AND NEITHER OF THEM WOULD HAVE BEEN VISIBLE WITHOUT RUNNING IT.
 */
static double rate_over_ticks(uint64_t ticks)
{
    struct timespec a, b;
    clock_gettime(CLOCK_MONOTONIC, &a);
    {
        uint64_t t0 = tsc();
        while (tsc() - t0 < ticks) { /* spin on ELAPSED TICKS */ }
        {
            uint64_t t1 = tsc();
            clock_gettime(CLOCK_MONOTONIC, &b);
            return (double)(t1 - t0) /
                ((double)(b.tv_sec - a.tv_sec) +
                 (double)(b.tv_nsec - a.tv_nsec) / 1e9);
        }
    }
}

static double tsc_rate_busy(void)
{
    return rate_over_ticks(400000000ULL);
}

static double tsc_rate_sleep(void)
{
    struct timespec ts = { 0, 400 * 1000 * 1000 };
    uint64_t t0, t1;
    struct timespec a, b;
    clock_gettime(CLOCK_MONOTONIC, &a);
    t0 = tsc();
    nanosleep(&ts, NULL);
    t1 = tsc();
    clock_gettime(CLOCK_MONOTONIC, &b);
    return (double)(t1 - t0) /
        ((double)(b.tv_sec - a.tv_sec) +
         (double)(b.tv_nsec - a.tv_nsec) / 1e9);
}

/* RDPMC in a forked child.  §KEEP§THE CHILD IS FORKED BECAUSE READING AN
 * UNPROGRAMMED PERFORMANCE MONITOR ON A MACHINE WITH
 * perf_event_paranoid = 4 RAISES SIGILL, AND SIGILL IN THE PARENT WOULD TAKE
 * THE WHOLE MEASUREMENT DOWN WITH IT. */
static const char *try_rdpmc(void)
{
    pid_t p = fork();
    if (p == 0) {
        uint64_t lo, hi;
        __asm__ __volatile__("rdpmc" : "=a"(lo), "=d"(hi));
        _exit(0);
    }
    if (p < 0) return "fork failed";
    {
        int st = 0;
        waitpid(p, &st, 0);
        if (WIFSIGNALED(st)) {
            static char buf[64];
            snprintf(buf, sizeof buf, "KILLED by signal %d", WTERMSIG(st));
            return buf;
        }
        return "readable";
    }
}

static long read_paranoid(void)
{
    FILE *f = fopen("/proc/sys/kernel/perf_event_paranoid", "r");
    long v = -1;
    if (f) {
        if (fscanf(f, "%ld", &v) != 1) v = -1;
        fclose(f);
    }
    return v;
}

int main(int argc, char **argv)
{
    /* §KEEP§ THE RAW NUMBERS GO TO A FILE AND THE ONE-LINE SUMMARY TO STDOUT,
     * §KEEP§ BECAUSE THE CALLER'S REPORT HAS TO BE BYTE-IDENTICAL BETWEEN TWO
     * §KEEP§ RUNS AND A REPORT CONTAINING A CLOCK READING IS NOT. §KEEP§ THE
     * §KEEP§ CALLER PRINTS BANDS AND VERDICTS; §KEEP§ THE EXACT TICKS LIVE IN
     * §KEEP§ cbbench.out, WHICH IS COMMITTED AND WHICH A READER MAY COMPARE
     * §KEEP§ AGAINST THEIR OWN MACHINE. */
    const char *outfile = NULL;
    int quiet = 0;
    int ai;
    for (ai = 1; ai < argc; ai++) {
        if (strcmp(argv[ai], "--quiet") == 0) {
            quiet = 1;
        } else if (strcmp(argv[ai], "--out") == 0 && ai + 1 < argc) {
            outfile = argv[++ai];
        }
    }
    FILE *tee = NULL;
    if (outfile && !quiet) {
        tee = fopen(outfile, "w");
    }
    long i, ck;
    double fc, fa, rb, rs, drift;
    double arm[4], spread[4], base;
    long sums[4];
    long sched_s, sched_i;
    double ts_s, ts_i;

    /* the chase ring, built so every node points at the next */
    for (i = 0; i < CHASE_NODES; i++) {
        g_nodes[i].next = &g_nodes[(i + 1) & (CHASE_NODES - 1)];
        g_nodes[i].pad = i;
    }
    for (i = 0; i < 64; i++) g_arr[i] = (i * 2654435761L) & 0xffff;

    if (!quiet && tee) {
        fclose(tee);
        tee = fopen(outfile, "w");
    }
#define W(...) do { printf(__VA_ARGS__); if (tee) fprintf(tee, __VA_ARGS__); } while (0)
    if (!quiet) {
        W(RULE "\n");
        W("cbbench -- the timing instrument for the register-allocation\n");
        W("and scheduling sections.  It executes what those sections\n");
        W("DECIDE; it does not decide anything itself.\n");
        W(RULE "\n\n");
    }

    /* ---------------- SECTION 1: the instrument ---------------- */
    pin_to_cpu2();
    rb = tsc_rate_busy();
    rs = tsc_rate_sleep();
    drift = (rb > 0) ? ((rs - rb) / rb) * 100.0 : 0.0;

    if (!quiet) {
        W(RULE "\n");
        W("SECTION 1 -- THE INSTRUMENT.  Nothing below this point is a\n");
        W("claim yet.\n");
        W(RULE "\n\n");
        W("THE CLOCK.  Measured twice: once busy, once across a 400 ms\n");
        W("sleep.  A TSC is a FIXED-RATE counter, so if the two agree then\n");
        W("a tick is TIME and never a cycle count, and every cost in this\n");
        W("file is a RATIO rather than a number of cycles.\n\n");
        W("  TSC rate, busy               %.4f GHz\n", rb / 1e9);
        W("  TSC rate, across sleep       %.4f GHz\n", rs / 1e9);
        W("  drift                       %+.4f%%   (busy is the reference)\n",
               drift);
        if (drift < 0.05 && drift > -0.05) {
            W("  VERDICT: invariant -- a tick is TIME.\n\n");
        } else {
            W("  VERDICT: THE TWO DISAGREE BY MORE THAN 0.05%%, so no\n");
            W("  duration in this file may be converted to anything.\n\n");
        }

        fc = floor_chase(&ck);
        fa = floor_arith(&ck);
        W("THE FLOOR OF THE ESTIMATOR, measured on TWO bodies on purpose.\n");
        W("They are the same loop shape and they differ in what they wait\n");
        W("on.\n\n");
        W("  estimator = min-of-%d, %ld iterations, two bodies:\n",
               COPIES, ITERS);
        W("     a POINTER CHASE, %d nodes, L2-resident   %8.3f ticks/op\n",
               CHASE_NODES, fc);
        W("     an ARITHMETIC increment loop              %8.3f ticks/op\n",
               fa);
        W("     the two differ by                         %+.1f%%\n\n",
               ((fa - fc) / fc) * 100.0);
        W("  WHY TWO.  An arithmetic loop is bounded by the CORE CLOCK and\n");
        W("  the TSC is FIXED-RATE, so a clock ramp reads as noise that is\n");
        W("  really the clock.  A pointer chase spends its time WAITING on\n");
        W("  a load, and a clock change does not shorten it.  The chase is\n");
        W("  the floor this file quotes; the arithmetic loop is printed so\n");
        W("  the gap is on the page.\n");
        W("  WHAT A BENCHMARK'S NOISE USUALLY IS TELLS YOU WHICH PART OF\n");
        W("  THE MACHINE THE BENCHMARK IS MEASURING.\n\n");
        if (g_pinned >= 0 && g_pinned == g_pinned_observed) {
            W("  pinned to cpu%d, and the cpu that answered is %d  "
                   "(VERIFIED)\n\n", g_pinned, g_pinned_observed);
        } else {
            W("  PINNING FAILED: asked for cpu%d, got cpu%d.\n"
                   "  Every ratio below is then uncontrolled and is reported\n"
                   "  as such rather than as a speed.\n\n",
                   g_pinned, g_pinned_observed);
        }
        W("  RDPMC in a forked child: %s\n", try_rdpmc());
        W("  /proc/sys/kernel/perf_event_paranoid = %ld\n\n",
               read_paranoid());
        W("  CONSEQUENCE, and it governs every number in sections 2 and 3:\n");
        W("    there is NO EVENT COUNTER.  Nothing here is a count of\n");
        W("    instructions, of cycles, of a branch taken or of a branch\n");
        W("    MISPREDICTED.  Every number is a DURATION, and a duration\n");
        W("    bounds a count without measuring it.\n\n");
        W("  iterations per arm: %ld   copies per arm: %d, the MINIMUM "
               "is kept\n\n", ITERS, COPIES);
    } else {
        fc = floor_chase(&ck);
        fa = floor_arith(&ck);
    }
    if (tee) { fflush(tee); }

    /* ---------------- SECTION 2: the spill cost ---------------- */
    {
        long (*arms[4])(const long *, long) = { arm_a, arm_b, arm_c, arm_d };
        static const char *names[4] = { "A pressure 0", "B pressure 1",
                                        "C pressure 2", "D pressure 4" };
        static const int spills[4] = { 0, 1, 2, 4 };
        double pass[ARM_PASSES][4];
        int k, c;
        /* §KEEP§ THE ARMS ARE MEASURED ROUND-ROBIN, ONE COPY OF EACH IN
         * §KEEP§ TURN, AND NOT "16 COPIES OF A, THEN 16 OF B". §KEEP§ A BLOCK
         * §KEEP§ OF COPIES IS A BLOCK OF WALL-CLOCK, SO ANY INTERFERENCE --
         * §KEEP§ ANOTHER PROCESS, A THERMAL STEP, A MIGRATION -- LANDS ON
         * §KEEP§ WHICHEVER ARM WAS RUNNING AT THAT MOMENT AND MAKES ONE ARM
         * §KEEP§ LOOK EXPENSIVE FOR A REASON THAT HAS NOTHING TO DO WITH
         * §KEEP§ REGISTER PRESSURE. §KEEP§ ROUND-ROBIN SPREADS ONE PATCH OF
         * §KEEP§ INTERFERENCE OVER ALL FOUR ARMS EQUALLY, AND THE MINIMUM
         * §KEEP§ THEN REJECTS IT. §KEEP§ MEASURED: THE BLOCK FORM GAVE ARM D
         * §KEEP§ 3.71 TICK/OP ON FIVE RUNS AND 4.93 ON A SIXTH; §KEEP§THE
         * §KEEP§ ROUND-ROBIN FORM HAS NOT PRODUCED A SECOND VALUE. */
        /* §KEEP§ AND THE FLOOR IS NOT "THE SLOWEST COPY MINUS THE FASTEST".
         * §KEEP§ THAT IS A FLOOR ON *ONE COPY*, AND THE ESTIMATOR THIS FILE
         * §KEEP§ USES IS MIN-OF-16, WHICH HAS ALREADY DISCARDED THE SLOW
         * §KEEP§ COPIES. §KEEP§ CHARGING THE MINIMUM FOR OUTLIERS IT REJECTED
         * §KEEP§ MADE THE FLOOR 1.08 TICK/OP -- LARGER THAN THE 0.71 TICK/OP
         * §KEEP§ DIFFERENCE IT WAS SUPPOSED TO GOVERN -- AND SO THE REPORT
         * §KEEP§ CONCLUDED THAT SPILLING IS FREE. §KEEP§ THE FLOOR THAT
         * §KEEP§ GOVERNS A MIN-OF-N ESTIMATOR IS HOW FAR TWO INDEPENDENT
         * §KEEP§ MIN-OF-N ESTIMATES OF THE SAME ARM LAND FROM EACH OTHER,
         * §KEEP§ SO THERE ARE TWO PASSES AND THE FLOOR IS THE DIFFERENCE. */
        for (k = 0; k < 4; k++)
            for (c = 0; c < ARM_PASSES; c++) pass[c][k] = 1e30;
        {
            int p;
            for (p = 0; p < ARM_PASSES; p++) {
                for (c = 0; c < COPIES; c++) {
                    for (k = 0; k < 4; k++) {
                        uint64_t t0 = tsc_serialised();
                        long got = arms[k](g_arr, ARM_ITERS);
                        uint64_t t1 = tsc_serialised();
                        double per = (double)(t1 - t0) / (double)ARM_ITERS;
                        if (per < pass[p][k]) pass[p][k] = per;
                        sums[k] = got;
                    }
                }
            }
        }
        /* §KEEP§ AND THE FLOOR IS THE MAXIMUM OVER *ALL PAIRS* OF PASSES, NOT
         * §KEEP§ THE DIFFERENCE OF ONE ARBITRARY PAIR. §KEEP§ ONE PAIR IS ONE
         * §KEEP§ SAMPLE OF THE NOISE, §KEEP§ SO A FLOOR ESTIMATED FROM ONE
         * §KEEP§ PAIR IS ITSELF NOISY: §KEEP§ MEASURED OVER 20 RUNS IT CAME
         * §KEEP§ BACK 0.09 TO 0.37 TICK/OP, §KEEP§ AND SOMETIMES EXCEEDED THE
         * §KEEP§ 0.35 TICK/OP DIFFERENCE IT WAS MEANT TO GOVERN, §KEEP§ SO THE
         * §KEEP§ VERDICT FLIPPED BETWEEN RUNS OF THE SAME PROGRAM. §KEEP§ THE
         * §KEEP§ MAXIMUM OVER ALL SIX PAIRS OF FOUR PASSES IS THE LARGEST
         * §KEEP§ DISAGREEMENT THESE PASSES CAN SHOW, §KEEP§ WHICH IS EXACTLY
         * §KEEP§ WHAT "THIS IS HOW FAR THE ESTIMATOR CAN MOVE" MEANS. §KEEP§
         * §KEEP§ A FLOOR ESTIMATED FROM ONE PAIR IS A SAMPLE; §KEEP§ A FLOOR
         * §KEEP§ ESTIMATED FROM THE WORST PAIR IS THE FLOOR ITSELF. */
        for (k = 0; k < 4; k++) {
            double lo = pass[0][k], hi = pass[0][k], f = 0.0;
            int a, b;
            for (a = 0; a < ARM_PASSES; a++) {
                for (b = a + 1; b < ARM_PASSES; b++) {
                    double d = pass[a][k] - pass[b][k];
                    if (d < 0.0) d = -d;
                    if (d > f) f = d;
                }
                if (pass[a][k] < lo) lo = pass[a][k];
                if (pass[a][k] > hi) hi = pass[a][k];
            }
            arm[k] = lo;
            spread[k] = f;
        }
        base = arm[0];

        if (!quiet) {
            W(RULE "\n");
            W("SECTION 2 -- THE COST OF A REGISTER ALLOCATION, IN REAL\n");
            W("CYCLES OF REAL MEMORY TRAFFIC.  Four arms, one function,\n");
            W("four values forced through a stack slot.\n");
            W(RULE "\n\n");
            W("Every arm computes the SAME thing over the SAME data and\n");
            W("they must agree on the checksum.  They differ in one thing\n");
            W("only: how many intermediate values live in a register.\n\n");
            W("  arm   spilled   ticks/op   pass2-pass1   vs arm A   checksum\n");
            for (k = 0; k < 4; k++) {
                W("  %-4s  %7d   %8.3f  %7.3f      %7.2fx   %ld\n",
                       names[k], spills[k], arm[k], spread[k],
                       (base > 0) ? arm[k] / base : 0.0, sums[k]);
            }
            W("\n");
            W("  TWO FLOORS, BOTH PRINTED, AND THEY ANSWER DIFFERENT\n");
            W("  QUESTIONS. §KEEP§THE CHASE IS THE FLOOR OF A *SINGLE\n");
            W("  MEASUREMENT* -- HOW CLOSE TWO RUNS OF THE SAME ARM CAN\n");
            W("  GET. §KEEP§ THE PASS-TO-PASS COLUMN IS THE FLOOR OF THE\n");
            W("  *ESTIMATOR THAT IS ACTUALLY USED* -- EACH ARM IS MEASURED\n");
            W("  TWICE, AS TWO INDEPENDENT MIN-OF-16 ESTIMATES, AND THE\n");
            W("  COLUMN IS HOW FAR THOSE TWO MINIMA LAND FROM EACH OTHER.\n");
            W("  §KEEP§ IT IS NOT MAX-MINUS-MIN OVER THE COPIES OF ONE\n");
            W("  MEASUREMENT: §KEEP§ THE MINIMUM HAS ALREADY DISCARDED THE\n");
            W("  SLOW COPIES, AND CHARGING THE MINIMUM FOR OUTLIERS IT\n");
            W("  REJECTED MADE THE FLOOR 1.08 TICK/OP, LARGER THAN THE\n");
            W("  0.71 TICK/OP DIFFERENCE IT WAS SUPPOSED TO GOVERN, AND\n");
            W("  §KEEP§ THE REPORT THEREFORE CONCLUDED THAT SPILLING IS FREE.\n");
            W("  §KEEP§ IT IS THE SMALLER OF THE TWO FLOORS THAT GOVERNS A\n");
            W("  CLAIM ABOUT A DIFFERENCE BETWEEN ARMS.\n");
            W("  §KEEP§ THE FIRST VERSION OF THIS REPORT PRINTED ONLY THE\n");
            W("  §KEEP§ CHASE AND THEREFORE CALLED A 1.12x NOT A DIFFERENCE,\n");
            W("  §KEEP§ WHICH WAS WRONG IN THE OTHER DIRECTION.\n");
            W("\n");
            {
                double worst = 0.0;
                for (k = 0; k < 4; k++)
                    if (spread[k] > worst) worst = spread[k];
                W("  ESTIMATOR FLOOR (the pointer chase) %8.3f ticks/op\n",
                       fc);
                W("  COMPARISON FLOOR (worst pass-to-pass) %6.3f ticks/op\n",
                       worst);
                W("  THE COST OF A SPILLED VALUE, against the COMPARISON\n");
                W("  floor, WHICH IS THE SMALLER OF THE TWO:\n");
                for (k = 1; k < 4; k++) {
                    W("    %d spilled  %+7.3f ticks/op  %5.2fx  %s\n",
                           spills[k], arm[k] - arm[0], arm[k] / base,
                           ((arm[k] - arm[0]) > worst)
                           ? "ABOVE the floor, so this IS a difference"
                           : "at or below the floor, read it as zero");
                }
                W("\n");
            }
            W("  CHECKSUMS: ");
            for (k = 0; k < 4; k++) W("%s%ld", k ? " " : "",
                                            sums[k]);
            W("\n");
            {
                int same = 1;
                for (k = 1; k < 4; k++) if (sums[k] != sums[0]) same = 0;
                W("  %s\n\n",
                       same ? "all four AGREE, so all four did the work"
                            : "THE ARMS DISAGREE, and no timing here means "
                              "anything");
            }
        }
    }

    /* ---------------- SECTION 3: the schedule ---------------- */
    {
        int c;
        double bs = 1e30, bi = 1e30;
        /* §KEEP§ THE SAME LONG WINDOW AS THE ARMS. §KEEP§ THIS LOOP USED 4096
         * §KEEP§ ITERATIONS -- ABOUT 6500 TICKS, SOME 3 MICROSECONDS -- §KEEP§
         * §KEEP§ AND AN INTERRUPT OR A MIGRATION IS A LARGE FRACTION OF THAT.
         * §KEEP§ MEASURED: AT 4096 THE TWO SCHEDULES LANDED ON EITHER SIDE OF
         * §KEEP§ THE 1.95 RUNG FROM RUN TO RUN AND THE REPORT'S BAND CHANGED
         * §KEEP§ WITH IT; §KEEP§ AT 65536 THEY DO NOT. */
        for (c = 0; c < COPIES; c++) {
            uint64_t t0 = tsc_serialised();
            sched_s = sched_serial(g_arr, ARM_ITERS);
            { uint64_t t1 = tsc_serialised();
              double p = (double)(t1 - t0) / (double)ARM_ITERS;
              if (p < bs) bs = p; }
            t0 = tsc_serialised();
            sched_i = sched_interleaved(g_arr, ARM_ITERS);
            { uint64_t t1 = tsc_serialised();
              double p = (double)(t1 - t0) / (double)ARM_ITERS;
              if (p < bi) bi = p; }
        }
        ts_s = bs;
        ts_i = bi;

        if (!quiet) {
            W(RULE "\n");
            W("SECTION 3 -- TWO SCHEDULES OF THE SAME INDEPENDENT\n");
            W("OPERATIONS, AND WHETHER INTERLEAVING THEM IS WORTH\n");
            W("ANYTHING ON THIS MACHINE.\n");
            W(RULE "\n\n");
            W("  schedule               ticks/op   vs serial   checksum\n");
            W("  serial (one chain)    %9.3f   %8.2fx   %ld\n",
                   ts_s, 1.0, sched_s);
            W("  interleaved (four)    %9.3f   %8.2fx   %ld\n",
                   ts_i, (ts_s > 0) ? ts_i / ts_s : 0.0, sched_i);
            W("\n  difference %+.3f ticks/op, against a floor of %.3f: "
                   "%s\n\n",
                   ts_i - ts_s, fc,
                   (fabs(ts_i - ts_s) > fc) ? "ABOVE the floor"
                                            : "AT OR BELOW the floor -- on "
                                              "this machine this schedule "
                                              "CHANGE IS NOT A RESULT");
            W("  CHECKSUMS %s\n\n",
                   sched_s == sched_i ? "AGREE, so the reorder is legal"
                                      : "DISAGREE, so the reorder is NOT "
                                        "legal and the timing is void");
        }
    }

    /* ---------------- SECTION 4: the report, one line per number --- */
    if (quiet) {
        W("FLOOR_CHASE %.3f\n", fc);
        W("FLOOR_ARITH %.3f\n", fa);
        W("TSC_BUSY_GHZ %.4f\n", rb / 1e9);
        W("TSC_SLEEP_GHZ %.4f\n", rs / 1e9);
        W("PINNED %d OBSERVED %d\n", g_pinned, g_pinned_observed);
        W("ARM_A %.3f %.3f 0 %ld\n", arm[0], spread[0], sums[0]);
        W("ARM_B %.3f %.3f 1 %ld\n", arm[1], spread[1], sums[1]);
        W("ARM_C %.3f %.3f 2 %ld\n", arm[2], spread[2], sums[2]);
        W("ARM_D %.3f %.3f 4 %ld\n", arm[3], spread[3], sums[3]);
        W("SUM_A %ld\n", sums[0]);
        W("SCHED_SERIAL %.3f %ld\n", ts_s, sched_s);
        W("SCHED_INTERLEAVED %.3f %ld\n", ts_i, sched_i);
    } else {
        W(RULE "\n");
        W("END OF INSTRUMENT REPORT\n");
        W(RULE "\n");
    }
    g_sink = (uint64_t)sums[0];
    if (tee) fclose(tee);
#undef W
    return 0;
}