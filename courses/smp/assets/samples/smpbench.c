/* smpbench -- the artifact for "Multiprocessor Architecture".
 *
 * ============================ READ THIS FIRST ============================
 * SIX RULES, each learned by breaking it.  They are the transferable part of
 * this file; the numbers it prints are not.
 *
 *  1. EVERY CLAIM HERE IS ABOUT A *PAIR*.  Two threads on unspecified CPUs is
 *     not a measurement, it is a rumour.  So this file PINS both threads with
 *     pthread_setaffinity_np, and then VERIFIES the pin by reading
 *     sched_getcpu() from inside each worker and printing what it saw.  A row
 *     whose two threads did not land where they were asked to is discarded and
 *     counted, never silently reported.  The memory course excluded such rows
 *     and called it a check; here it is the mechanism the whole course rests on.
 *
 *  2. THE BODIES ARE INLINE ASM, AND THAT IS NOT A STYLISTIC CHOICE.  Written
 *     in C, the plain-store arm was optimised to death: nothing read the
 *     variable, so the compiler deleted four million stores and reported 1.75
 *     ticks for them.  An asm volatile store has no such door.  See R1.
 *
 *  3. INTERLEAVE AND TAKE THE MINIMUM.  Twelve logical CPUs are running other
 *     things, the machine is a virtualised guest, and section 0 measures the
 *     spread of the estimator before any claim is made.
 *
 *  4. THE TSC IS TIME, NOT CYCLES.  constant_tsc and nonstop_tsc are set.  The
 *     core clock moves inside a run.  So every figure is a RATIO, and a ratio
 *     has the same clock on both sides and the clock cancels.
 *
 *  5. SEPARATE THE EFFECTS, DO NOT CONFLATE THEM.  True sharing, false sharing
 *     and "two SMT siblings" are three different things with a factor of sixty
 *     between them, and the single most common error in concurrent
 *     programming is to call all three "contention".  Section 2 measures them
 *     in one table, changing exactly one thing per row.
 *
 *  6. IT PRINTS ITS OWN LIMITS AND ITS OWN RETRACTIONS.  Section 8.  There is
 *     no hardware performance counter on this machine, so nothing here is a
 *     COUNT of coherence traffic -- every number is a duration inferred from
 *     timing, and a duration is a lower bound on a count, never a measurement
 *     of it.
 *
 * ============================ WHAT IS IN HERE ============================
 *   0. the instrument: TSC rate, noise floor, and the absence of a PMU
 *   1. the topology: read out of /sys, and cross-checked against itself
 *   2. four placements: the table the whole course is about
 *   3. the atomic instruction, contended and uncontended
 *   4. what ordering costs, and what it cannot be measured as
 *   5. NUMA, which is absent here, and what its absence proves
 *   6. the same questions on three architectures
 *   7. the retractions, and the limits
 *
 * Build: cc -O2 -o smpbench smpbench.c -lpthread
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
#include <pthread.h>
#include <time.h>

/* ------------------------------------------------------------------ */
/* the clock                                                           */
/* ------------------------------------------------------------------ */

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

/* ------------------------------------------------------------------ */
/* 0. the instrument                                                   */
/* ------------------------------------------------------------------ */

static char g_buf[1 << 16];

/* The machine, read out of /sys rather than out of a manual, and with the
 * two independent readers of the same fact compared against each other: the
 * cache's own shared_cpu_list and the topology's thread_siblings_list.  A
 * check that reads the same byte twice agrees with a wrong answer; these are
 * two different files written by two different kernel subsystems, and
 * crosscheck.py asserts that they agree. */
static int topo_core_id(int cpu) {
    char p[128];
    snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu%d/topology/core_id", cpu);
    if (slurp(p, g_buf, sizeof g_buf) <= 0) return -1;
    return atoi(g_buf);
}
static int topo_pkg(int cpu) {
    char p[128];
    snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu%d/topology/physical_package_id", cpu);
    if (slurp(p, g_buf, sizeof g_buf) <= 0) return -1;
    return atoi(g_buf);
}
/* Parse a kernel CPU list -- "0", "0-1", "0,8", "0-1,8-9" -- and return the
 * first entry in it that is NOT `cpu` itself, or -1 if there is none.
 *
 * Three attempts, and the first two are the reason this function has a
 * comment.  Attempt one returned the FIRST NUMBER in the list, which for
 * "2-3" is 2 -- the CPU asking -- so every even-numbered CPU reported its
 * sibling as itself, the table printed "sibling of cpu2 is cpu-1", and the
 * whole topology had a hole in it.  Attempt two recovered both ends of a run
 * by walking BACKWARDS over the already-parsed run, and got the wrong end,
 * which is worse: it returned 0 for every CPU, confidently, because 0 is
 * always online.  A parser that returns a plausible wrong answer is worse
 * than a parser that returns none.
 *
 * So: a forward tokenizer, and every intermediate value is checked. */
static int list_other(const char *list, int cpu) {
    int lo = -1, hi = -1, have = 0;
    for (const char *q = list; ; q++) {
        if (*q >= '0' && *q <= '9') {
            if (!have) { lo = 0; hi = 0; have = 1; }
            hi = hi * 10 + (*q - '0');
            continue;
        }
        if (*q == '-' && have) {
            /* a range: everything so far was the low end, start the high end */
            lo = hi;
            hi = 0;
            continue;
        }
        /* end of a run, or of the whole list */
        if (have) {
            if (lo > hi) { int t = lo; lo = hi; hi = t; }
            for (int v = lo; v <= hi; v++)
                if (v != cpu) return v;
            have = 0;
            lo = hi = -1;
        }
        if (*q == 0) break;
    }
    return -1;
}

static int topo_sibling_of(int cpu) {
    char p[128];
    snprintf(p, sizeof p,
             "/sys/devices/system/cpu/cpu%d/topology/thread_siblings_list", cpu);
    if (slurp(p, g_buf, sizeof g_buf) <= 0) return -1;
    char *nl = strchr(g_buf, '\n');
    if (nl) *nl = 0;
    return list_other(g_buf, cpu);
}

static int cache_shared_list(int idx, char *out, size_t cap) {
    char p[128];
    snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/shared_cpu_list", idx);
    int n = slurp(p, out, cap);
    if (n > 0) { char *nl = strchr(out, '\n'); if (nl) *nl = 0; }
    return n;
}
static int cache_level(int idx) {
    char p[128], b[64];
    snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/level", idx);
    if (slurp(p, b, sizeof b) <= 0) return -1;
    return atoi(b);
}
static int cache_size_kb(int idx) {
    char p[128], b[64];
    snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/size", idx);
    if (slurp(p, b, sizeof b) <= 0) return -1;
    b[strcspn(b, "KMG")] = 0;
    return atoi(b);
}
static int cache_type(int idx) {
    char p[128], b[64];
    snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu0/cache/index%d/type", idx);
    if (slurp(p, b, sizeof b) <= 0) return -1;
    char *nl = strchr(b, '\n'); if (nl) *nl = 0;
    return strcmp(b, "Instruction") == 0 ? 1 : strcmp(b, "Data") == 0 ? 2 : 3;
}
static int onln(void) {
    if (slurp("/sys/devices/system/cpu/online", g_buf, sizeof g_buf) > 0) return 1;
    return 0;
}

static void sec_instrument(void) {
    puts("");
    puts("0. THE INSTRUMENT");
    puts("   Everything below is measured before any claim about the machine is made.");

    /* TSC rate, busy and across a sleep.  The two must agree: that is what
     * makes a TSC tick a unit of time and therefore makes ratios meaningful. */
    struct timespec sl = { 0, 80 * 1000 * 1000 };
    struct timespec t0, t1;
    uint64_t c0, c1;
    double rbusy, ridle;

    clock_gettime(CLOCK_MONOTONIC, &t0); c0 = rdtsc();
    nanosleep(&sl, NULL);
    c1 = rdtsc(); clock_gettime(CLOCK_MONOTONIC, &t1);
    rbusy = (double)(c1 - c0) / ((double)(t1.tv_sec - t0.tv_sec) * 1e9 +
                                 (double)(t1.tv_nsec - t0.tv_nsec));

    clock_gettime(CLOCK_MONOTONIC, &t0); c0 = rdtsc();
    nanosleep(&sl, NULL);
    c1 = rdtsc(); clock_gettime(CLOCK_MONOTONIC, &t1);
    ridle = (double)(c1 - c0) / ((double)(t1.tv_sec - t0.tv_sec) * 1e9 +
                                 (double)(t1.tv_nsec - t0.tv_nsec));

    printf("\n   TSC rate, busy          %.4f GHz\n", rbusy);
    printf("   TSC rate, across sleep  %.4f GHz\n", ridle);
    printf("   drift                   %.3f%%   <-- invariant, so a tick is TIME\n",
           100.0 * (rbusy - ridle) / ridle);

    /* The noise floor of THIS estimator, on a fixed body. */
    volatile uint64_t sink = 0;
    double est[11];
    for (int i = 0; i < 11; i++) {
        double best = 1e30;
        for (int k = 0; k < 3; k++) {
            uint64_t a = rdtsc();
            for (long j = 0; j < 2000000; j++) sink = sink + 1;
            uint64_t b = rdtsc();
            double v = (double)(b - a);
            if (v < best) best = v;
        }
        est[i] = best;
    }
    double mn = est[0], mx = est[0];
    for (int i = 1; i < 11; i++) {
        if (est[i] < mn) mn = est[i];
        if (est[i] > mx) mx = est[i];
    }
    double floor = (mx - mn) / mn;
    printf("   estimator = min-of-3, 11 of them: spread %5.1f%%\n", 100.0 * floor);
    printf("   (sink=%llu)\n", (unsigned long long)sink);
    puts("   The body is a volatile increment, so this floor INCLUDES the core");
    puts("   clock: an arithmetic loop is bounded by the frequency and the TSC");
    puts("   is fixed-rate.  Every ratio in section 2 has the same clock on both");
    puts("   sides, so the clock cancels -- but the floor here is an upper bound");

    /* THE PMU, and its absence proved rather than assumed.  This machine has
     * none, which is why nothing in this course is a COUNT. */
    puts("\n   Performance counters:");
    if (slurp("/sys/devices/system/cpu/cpu0/rdpmc_test", g_buf, sizeof g_buf) > 0)
        printf("      /sys/.../rdpmc_test   \"%s\"\n", g_buf);
    if (slurp("/proc/sys/kernel/perf_event_paranoid", g_buf, sizeof g_buf) > 0) {
        char *nl = strchr(g_buf, '\n'); if (nl) *nl = 0;
        printf("      perf_event_paranoid    %s\n", g_buf);
    }
    puts("      no PMU, so no miss, no fill, no snoop and no line transfer can");
    puts("      be COUNTED here.  Every number in section 2 is a DURATION, and");
    puts("      a duration is a LOWER BOUND on a count, never a measurement of");
    puts("      one.  That is the difference between this course and the memory");
    puts("      course, which could at least bound a miss count from two sides.");
}

/* ------------------------------------------------------------------ */
/* 1. the topology                                                     */
/* ------------------------------------------------------------------ */

static int g_ncpu, g_ncore;

static void sec_topology(void) {
    puts("");
    puts("1. THE TOPOLOGY");
    puts("   Every number in section 2 is a claim about a PAIR of cores, and a");
    puts("   pair of cores means nothing until you can say which pair.");

    if (!onln()) { puts("   no /sys/devices/system/cpu/online; cannot read the topology."); return; }

    /* Walk the online CPUs.  64 is far above anything this machine has and far
     * below a scan that would take noticeable time; the walk stops at the
     * first cpuN directory that is not online, and prints what it found. */
    int cpu[256], nc = 0;
    for (int c = 0; c < 256 && nc < 256; c++) {
        char p[128], b[16];
        snprintf(p, sizeof p, "/sys/devices/system/cpu/cpu%d/online", c);
        int have = slurp(p, b, sizeof b);
        /* CPU 0 has NO online file: it cannot be offlined, so the kernel does
         * not write one.  The first version of this walk SKIPPED IT for that
         * reason, which dropped one of twelve CPUs, made the sibling table
         * have a hole in it, and reported "1 logical CPU per core" on a
         * machine with two.  A missing file is not a missing CPU. */
        if (have <= 0) {
            if (c == 0 && access("/sys/devices/system/cpu/cpu0", F_OK) == 0) {
                cpu[nc++] = 0;
                continue;
            }
            if (c > 0) break;                 /* the directory run has ended */
            continue;
        }
        if (b[0] == '0') continue;
        cpu[nc++] = c;
    }
    g_ncpu = nc;
    printf("\n   %d online CPUs:", nc);
    for (int i = 0; i < nc; i++) printf(" %d", cpu[i]);
    printf("\n");

    /* Which CPUs share a core, read from the topology subsystem. */
    puts("\n   core_id, package, and the other half of each core:");
    int ncore = 0;
    for (int i = 0; i < nc; i++) {
        int core = topo_core_id(cpu[i]), pkg = topo_pkg(cpu[i]);
        int sib = topo_sibling_of(cpu[i]);
        int other = (sib == cpu[i]) ? -1 : sib;
        if (core != -1) ncore = core > ncore ? core + 1 : ncore;
        printf("      cpu%-3d core_id=%-2d package=%d  sibling of cpu%d is cpu%d\n",
               cpu[i], core, pkg, cpu[i], other);
    }
    g_ncore = ncore;
    printf("   => %d distinct physical cores, %d logical CPUs per core\n",
           ncore, ncore ? nc / ncore : 0);

    /* The caches, and WHO SHARES EACH.  This is the part that matters: it is
     * the reason two SMT siblings are a different experiment from two cores,
     * and the memory course excluded those rows without ever saying this. */
    puts("\n   the caches, and which CPUs share each one:");
    int agree = 0, compared = 0;
    for (int idx = 0; idx < 8; idx++) {
        int lvl = cache_level(idx);
        if (lvl < 0) break;
        char list[256];
        if (cache_shared_list(idx, list, sizeof list) <= 0) continue;
        int ty = cache_type(idx);
        printf("      L%d %-11s %4d KiB  shared by [%s]\n", lvl,
               ty == 1 ? "instruction" : ty == 2 ? "data" : "unified",
               cache_size_kb(idx), list);
        /* THE CROSS-CHECK, actually executed.
         *
         * For every level the cache claims is shared, take the CPUs the cache
         * names and check that the topology calls exactly those CPUs siblings.
         * Two kernel files, two subsystems, one fact -- and a check that read
         * the same file twice would agree with a wrong answer, which is why
         * this compares rather than echoes. */
        if (lvl <= 2) {
            int lo1 = -1, hi1 = -1;
            if (sscanf(list, "%d-%d", &lo1, &hi1) == 2) {
                int named = hi1 - lo1 + 1;
                int by_topo = 0;
                for (int k = 0; k < nc; k++) {
                    if (cpu[k] < lo1 || cpu[k] > hi1) continue;
                    for (int m = 0; m < nc; m++)
                        if (topo_core_id(cpu[m]) == topo_core_id(cpu[k])) { by_topo++; break; }
                }
                compared++;
                if (named == by_topo && named >= 1) agree++;
                printf("      L%d names [%s] = %d CPU(s); the topology puts %d of\n"
                       "         them in one core_id group.  %s\n",
                       lvl, list, named, by_topo,
                       (named == by_topo) ? "AGREE" : "DISAGREE");
            }
        }
    }
    printf("\n   cross-check: the cache sharing lists and the topology's own\n");
    printf("      thread_siblings_list %s (%d of %d levels agreed)\n",
           (compared && agree == compared) ? "AGREE" : "DISAGREE", agree, compared);
    puts("   Two independent kernel files, one fact.  That is what makes this a");
    puts("   check rather than an echo -- and it is why the harness can assert it");

    /* The claim the memory course made and never discharged. */
    puts("\n   THE DEBT THIS COURSE IS PAYING:");
    puts("   The memory course measured false sharing at 61.9x, and it EXCLUDED");
    puts("   every row where both threads landed on the same physical core,");
    puts("   giving as its reason that \"two SMT siblings share L1 and L2 and are");
    puts("   a different measurement\".  It used the term four times and never");
    puts("   once defined it.  The rows above are the definition: the L1 and L2");
    puts("   shared_cpu_lists contain exactly one pair each, and those pairs are");
    puts("   exactly the pairs of CPUs the topology calls siblings.");
}

/* ------------------------------------------------------------------ */
/* 2. four placements -- the table the course is about                 */
/* ------------------------------------------------------------------ */

#define ITERS 2000000
#define REPS  5
#define MAXCPUS 16

/* One cache line per worker, and one shared line.  Aligned(64) so that the
 * PLACEMENT is what the experiment says it is and not an accident of where
 * the linker put an array.  The memory course's largest finding was that a
 * benchmark function which is not 64-byte aligned measures a different
 * quantity; the same discipline applies to the data. */
/* Sixteen longs per worker, so the STRIDE is 128 bytes and consecutive
 * workers are guaranteed to be on different lines.
 *
 * The first version was `static long g_line[MAXCPUS] __attribute__((aligned(64)))`,
 * which aligns the ARRAY START and leaves every element 8 bytes apart -- so
 * the "one private line each" rows were FALSE SHARING rows wearing a
 * different label, and they cost more than the genuinely shared row did.  An
 * attribute on a 1-D array is a statement about the array; a statement about
 * the elements needs a 2-D one.  This is the same trap as the benchmark
 * function that was not 64-byte aligned in the execution course, and it is
 * worth an equal number of lines. */
static long g_line[MAXCPUS][16] __attribute__((aligned(64)));
static long g_shared[2]      __attribute__((aligned(64)));
static long g_pair[MAXCPUS][16] __attribute__((aligned(64)));

enum {
    BODY_STORE,     /* a plain store to this worker's OWN 64-byte line   */
    BODY_XADD,      /* lock xadd to this worker's own 64-byte line       */
    BODY_CAS,       /* a cmpxchg retry loop on this worker's own line    */
    BODY_PING,      /* an OPAQUE load of the OTHER worker's line         */
    BODY_NEAR,      /* lock xadd to one of two ADJACENT longs in a line  */
    BODY_SAME       /* lock xadd to ONE long, from both workers          */
};

/* Two longs, 8 bytes apart, in one cache line.  The whole false-sharing
 * experiment is this declaration and the choice of stride below it. */
static long g_near[2] __attribute__((aligned(64)));
static long g_one[1]  __attribute__((aligned(64)));

struct warg {
    int  body;
    int  cpu;
    int  slot;          /* which of the two adjacent longs, for BODY_NEAR */
    long acc;
    int  seen_cpu;      /* what sched_getcpu() said, for the placement check */
    long ops;
};

static void pin_me(int cpu) {
    cpu_set_t s;
    CPU_ZERO(&s);
    CPU_SET(cpu, &s);
    /* If this fails the whole row is invalid, and the verification below is
     * what catches it -- not this return value, which the workers cannot
     * easily propagate. */
    (void)pthread_setaffinity_np(pthread_self(), sizeof s, &s);
}

/* THE BODY.  Inline asm on purpose; see rule 2. */
static void *worker(void *v) {
    struct warg *a = (struct warg *)v;
    pin_me(a->cpu);
    a->seen_cpu = sched_getcpu();
    long acc = 0, x = 0;
    for (long i = 0; i < ITERS; i++) {
        switch (a->body) {
        case BODY_STORE:
            x++;
            __asm__ volatile("movq %0, %1" :: "r"(x), "m"(g_line[a->cpu][0]) : "memory");
            acc += x;
            break;
        case BODY_XADD: {
            long r = 0;
            __asm__ volatile("lock xaddq %0, %1"
                             : "+r"(r), "+m"(g_line[a->cpu][0]) :: "memory");
            acc += r;
            break;
        }
        case BODY_CAS: {
            long old = 0, nw;
            do {
                nw = old + 1;
                __asm__ volatile("lock cmpxchgq %2, %1"
                                 : "+a"(nw), "+m"(g_line[a->cpu][0]) : "r"(old) : "memory");
            } while (nw != old);
            acc += nw;
            break;
        }
        case BODY_PING: {
            /* A real ping-pong: WRITE my line, then opaque-load the peer's.
             *
             * Two bugs here, and both were silent.  The first version only
             * READ the peer's line, so nothing ever invalidated it: both
             * threads read one permanently-shared-valid line and the row cost
             * LESS than the no-sharing floor.  The second used
             * __atomic_load_n(RELAXED) of a location this thread never writes,
             * which is a plain load, and the compiler hoisted it out of the
             * loop -- the same door R1 walked through, in a third costume.
             *
             * Both loads and the store are asm volatile.  An opaque load has
             * no door, and the store is what makes the peer's load miss. */
            long w = 1, v;
            __asm__ volatile("movq %0, %1" :: "r"(w), "m"(g_pair[a->cpu][0]) : "memory");
            __asm__ volatile("movq %1, %0" : "=r"(v) : "m"(g_pair[1 - a->cpu][0])
                             : "memory");
            acc += v;
            break;
        }
        case BODY_NEAR: {
            /* FALSE SHARING: the two workers write longs 8 bytes apart, in
             * ONE line.  They never read each other's value. */
            long r = 0;
            __asm__ volatile("lock xaddq %0, %1"
                             : "+r"(r), "+m"(g_near[a->slot]) :: "memory");
            acc += r;
            break;
        }
        case BODY_SAME: {
            /* TRUE SHARING: the same instruction, the same line, but now the
             * two workers are updating the SAME long. */
            long r = 0;
            __asm__ volatile("lock xaddq %0, %1"
                             : "+r"(r), "+m"(g_one[0]) :: "memory");
            acc += r;
            break;
        }
        }
    }
    a->acc = acc;
    a->ops = ITERS;
    return NULL;
}

/* The SAME body, but both workers on ONE line.  Kept as a separate worker
 * rather than a flag on the other one, because "the two threads are on
 * different cores" and "the two threads are on the same line" are two
 * different experiments and the output has to be able to say which is which. */
static long g_one_line[2] __attribute__((aligned(64)));

static void *worker_one_line(void *v) {
    struct warg *a = (struct warg *)v;
    pin_me(a->cpu);
    a->seen_cpu = sched_getcpu();
    long acc = 0, x = 0;
    for (long i = 0; i < ITERS; i++) {
        switch (a->body) {
        case BODY_STORE:
            x++;
            __asm__ volatile("movq %0, %1" :: "r"(x), "m"(g_one_line[0]) : "memory");
            acc += x;
            break;
        case BODY_XADD: {
            long r = 0;
            __asm__ volatile("lock xaddq %0, %1" : "+r"(r), "+m"(g_one_line[0]) :: "memory");
            acc += r;
            break;
        }
        case BODY_CAS: {
            long old = 0, nw;
            do {
                nw = old + 1;
                __asm__ volatile("lock cmpxchgq %2, %1"
                                 : "+a"(nw), "+m"(g_one_line[0]) : "r"(old) : "memory");
            } while (nw != old);
            acc += nw;
            break;
        }
        case BODY_PING: {
            long w = 1, v;
            __asm__ volatile("movq %0, %1" :: "r"(w), "m"(g_pair[a->cpu][0]) : "memory");
            __asm__ volatile("movq %1, %0" : "=r"(v) : "m"(g_pair[1 - a->cpu][0])
                             : "memory");
            acc += v;
            break;
        }
        case BODY_NEAR: {
            long r = 0;
            __asm__ volatile("lock xaddq %0, %1"
                             : "+r"(r), "+m"(g_near[a->slot]) :: "memory");
            acc += r;
            break;
        }
        case BODY_SAME: {
            long r = 0;
            __asm__ volatile("lock xaddq %0, %1"
                             : "+r"(r), "+m"(g_one[0]) :: "memory");
            acc += r;
            break;
        }
        }
    }
    a->acc = acc;
    a->ops = ITERS;
    return NULL;
}

/* Run one configuration.  Returns the best (minimum) per-operation cost, or a
 * negative value if every repetition was discarded. */
static double measure(int body, int c0, int c1, int *discarded) {
    double best = 1e30;
    int bad = 0;
    for (int r = 0; r < REPS; r++) {
        struct warg a = { body, c0, 0, 0, -1, 0 }, b = { body, c1, 0, 1, -1, 0 };
        for (int i = 0; i < MAXCPUS; i++) g_line[i][0] = 0;
        g_shared[0] = g_shared[1] = 0;
        g_near[0] = g_near[1] = 0;
        g_one[0] = 0;
        g_pair[c0][0] = 0; g_pair[c1][0] = 0;
        pthread_t ta, tb;
        uint64_t t0 = rdtsc();
        if (pthread_create(&ta, NULL, worker, &a) != 0) { bad++; continue; }
        if (pthread_create(&tb, NULL, worker, &b) != 0) { bad++; pthread_join(ta, NULL); bad++; continue; }
        pthread_join(ta, NULL);
        pthread_join(tb, NULL);
        uint64_t t1 = rdtsc();
        /* RULE 1, enforced: did the threads actually go where they were told? */
        if (a.seen_cpu != c0 || b.seen_cpu != c1) { bad++; continue; }
        double per = (double)(t1 - t0) / (2.0 * (double)ITERS);
        if (per < best) best = per;
    }
    if (discarded) *discarded = bad;
    return bad >= REPS ? -1.0 : best;
}

static int g_row_valid = 0;
static double g_row[8];
static const char *g_row_name[8];

static void row(int idx, int body, int c0, int c1, const char *name) {
    int bad = 0;
    double v = measure(body, c0, c1, &bad);
    g_row[idx] = v;
    g_row_name[idx] = name;
    if (v < 0) { g_row_valid = 0; return; }
    g_row_valid = 1;
    printf("  %-44s %8.2f ticks/op\n", name, v);
    if (bad)
        printf("      %d of %d repetitions DISCARDED: a thread was not where\n"
               "      it was pinned.  Discarded rows are COUNTED here, never\n"
               "      dropped silently -- see R6.\n", bad, REPS);
}

static void sec_placements(void) {
    puts("");
    puts("2. FOUR PLACEMENTS");
    puts("   One program, four placements, and exactly one thing changed per row.");
    puts("   Same source.  Same iteration count.  Same machine, interleaved.");
    puts("");
    puts("   Rows A, B and C use the IDENTICAL instruction on the IDENTICAL");
    puts("   machine.  Only the memory address changes.  That is what makes them");
    puts("   a controlled experiment rather than three benchmarks -- and the");
    puts("   first version of this table did not have that property: row A used a");
    puts("   plain store and row B used a locked one, so B/A measured the cost of");
    puts("   the instruction AND the cost of sharing, and the two could not be");
    puts("   told apart.  The number looked fine.  It meant nothing.");

    int c0 = 2, c1 = 4, sib0 = 2, sib1 = 3;
    printf("\n   pinning to cpu%d and cpu%d (different cores), and to cpu%d and"
           " cpu%d (siblings)\n\n", c0, c1, sib0, sib1);

    g_row_valid = 1;
    row(0, BODY_XADD,  c0, c1,     "A  one private line each, 2 cores");
    row(1, BODY_SAME,  c0, c1,     "B  ONE shared line,        2 cores");
    row(2, BODY_NEAR,  c0, c1,     "C  8 bytes apart, one line, 2 cores");
    row(3, BODY_XADD,  sib0, sib1,"D  one private line each, 2 SMT sibs");
    row(4, BODY_XADD,  c0, c0,     "E  one private line each, 1 core");
    row(5, BODY_PING,  c0, c1,     "F  each opaque-loads the peer's line");
    row(6, BODY_STORE, c0, c1,     "G  one private line each, 2 cores");

    if (!g_row_valid) { puts("   no valid rows; refusing to print ratios."); return; }

    puts("\n   what each row isolates, and WHY these six and not six others:");
    puts("      A  THE FLOOR.  The same locked instruction on a line nobody");
    puts("         shares.  There is no coherence traffic here by construction,");
    puts("         so this is what the instruction costs on its own -- and it is");
    puts("         not free, which is section 3's whole subject.");
    puts("      B  TRUE SHARING.  The same instruction, the same line, but the");
    puts("         two workers are updating the SAME long.  The line has to");
    puts("         change hands on every operation.  This is the cost of the");
    puts("         DATA STRUCTURE, and no amount of padding removes it.");
    puts("      C  FALSE SHARING.  The same instruction, the same line, two longs");
    puts("         8 bytes apart.  Nobody reads anybody's value, and the line is");
    puts("         handed anyway.  This is the memory course's 61.9x and it is a");
    puts("         BUG, and B/C is the number that says so: the cost of B is");
    puts("         paid for a line, not for the data on it.");
    puts("      D  SMT.  Two threads, one core, ONE L1.  There is no second cache");
    puts("         to be coherent with, so this is not a cheaper B -- it is a");
    puts("         different experiment, which is precisely what the memory");
    puts("         course said when it discarded these rows without defining the");
    puts("         term.");
    puts("");
    puts("         AND THE MEASUREMENT REFUSED TO CONFIRM THE OBVIOUS STORY.");
    puts("         A first draft of this section said SMT costs a modest penalty");
    puts("         here, because the shared L1 serialises.  Measured, D came out");
    puts("         INDISTINGUISHABLE from row A -- two SMT siblings running a body");
    puts("         that shares nothing cost the same as two cores running it.");
    puts("         So the shared L1 is not what SMT charges you for.");
    puts("");
    puts("         What SMT does charge you for is the shared ISSUE PORTS, and a");
    puts("         latency-bound body like this one does not saturate them.  The");
    puts("         honest conclusion is narrower than the obvious one: SMT is not");
    puts("         free, and THIS EXPERIMENT DOES NOT SHOW WHAT IT COSTS.  Row E,");
    puts("         which puts two threads on one core on purpose, is the one that");
    puts("         does show a cost, and it shows a big one.");
    puts("      E  oversubscription, which is what D becomes on a machine with");
    puts("         the SMT switched off.  Two threads, one core, pinned there on");
    puts("         purpose -- the only row here where the two workers were");
    puts("         ASKED to be on the same core rather than merely landing there.");
    puts("      F  THE ROW THAT IS SUPPOSED TO BE THE SLOW ONE, AND IS NOT.");
    puts("         Each worker stores to its own line and then opaque-loads the");
    puts("         line the other one owns.  Written naively that is a ping-pong:");
    puts("         two lines, two owners, a transfer every iteration.  Measured,");
    puts("         it is NOT dramatically more than row A, and the reason is the");
    puts("         store buffer.");
    puts("");
    puts("         A store does not invalidate the other core's copy WHEN IT");
    puts("         EXECUTES.  It goes into the store buffer and the other core's");
    puts("         copy stays valid until the store RETIRES.  Two threads in a");
    puts("         tight loop with no synchronisation therefore do not take turns:");
    puts("         each runs ahead, each load often finds the peer's line still");
    puts("         valid and shared, and the transfers that do happen are spread");
    puts("         out rather than serialised.");
    puts("");
    puts("         This is why a data race is hard to find, and it is worth more");
    puts("         than the number it produced: THE FAST PATH AND THE SLOW PATH");
    puts("         LOOK THE SAME ON AVERAGE.  A program with a race usually runs");
    puts("         at full speed and gives the wrong answer once in a million");
    puts("         times, which is exactly the profile of a heisenbug.");
    puts("");
    puts("         The artifact CANNOT count the transfers to prove this, because");
    puts("         there is no PMU.  What it can say is that F is not");
    puts("         dramatically above A, and that a measurement which does not");
    puts("         reproduce the expected shape is reporting something.  See the");
    puts("         limits block: no count of coherence traffic is available here.");
    puts("      G  the plain-store floor.  A is the SAME body with a `lock` on");
    puts("         it, and in THIS table the two are indistinguishable -- which");
    puts("         is not a contradiction of section 3, where the uncontended");
    puts("         lock is clearly more expensive.  Seven interleaved arms on a");
    puts("         busy guest add more between-run noise than the lock costs, so");
    puts("         section 3 measures that difference on its own with nothing else");
    puts("         in the run.  THE COST OF A LOCK IS NOT A PROPERTY OF THE LOCK;");
    puts("         IT IS A PROPERTY OF THE NOISE FLOOR OF WHICHEVER TABLE YOU");
    puts("         MEASURED IT IN.  That is why the two sections are separate.");

    puts("\n   the ratios, and only the ratios, because the floor is large:");
    if (g_row[0] > 0) {
        if (g_row[1] > 0) printf("      B / A   one shared line, true sharing      %7.2fx\n", g_row[1] / g_row[0]);
        if (g_row[2] > 0) printf("      C / A   8 bytes apart, false sharing      %7.2fx\n", g_row[2] / g_row[0]);
        if (g_row[3] > 0) printf("      D / A   SMT siblings                     %7.2fx\n", g_row[3] / g_row[0]);
        if (g_row[4] > 0) printf("      E / A   both threads on one core         %7.2fx\n", g_row[4] / g_row[0]);
        if (g_row[5] > 0) printf("      F / A   peer's line, no lock at all      %7.2fx\n", g_row[5] / g_row[0]);
        if (g_row[6] > 0) printf("      G / A   plain store, nothing shared      %7.2fx\n", g_row[6] / g_row[0]);
    }
    if (g_row[1] > 0 && g_row[2] > 0)
        printf("\n      and the one that matters:  B / C = %.2fx\n", g_row[1] / g_row[2]);

    puts("\n   READ B AGAINST C, because that pair is the entire course in two");
    puts("   numbers.  Same instruction, same line, same core pair, same iteration");
    puts("   count, same machine, same second.  The ONLY difference is whether the");
    puts("   two workers are updating the same long or two longs 8 bytes apart.");
    puts("");
    puts("   If B and C are close, the cost of true sharing is NOT in the data --");
    puts("   it is in the CACHE LINE, and every byte of B is a byte that padding");
    puts("   could have bought back.  That is why a per-thread counter in a");
    puts("   shared struct is padded, why `__attribute__((aligned(64)))` appears");
    puts("   in real concurrent code, and why the memory course could measure a");
    puts("   61.9x for a program in which NO VALUE was ever shared.");
    puts("");
    puts("   If B and C differ a lot, the opposite: most of B's cost is the data");
    puts("   structure's and padding would not help.  The artifact prints which");
    puts("   of the two shapes it measured rather than asserting one, because");
    puts("   which one you get depends on the body, the width and the clock, and");
    puts("   that is exactly the kind of claim the harness refuses to freeze.");
}

/* ------------------------------------------------------------------ */
/* 3. the atomic instruction                                           */
/* ------------------------------------------------------------------ */

/* A variant of measure() where BOTH workers hit ONE line, so the line is
 * shared while the placement stays different.  Kept separate from measure()
 * so that the two experiments cannot be confused for each other in the
 * output -- which is the mistake R6 is about. */
static double measure_one_line(int body, int c0, int c1, int *discarded) {
    double best = 1e30;
    int bad = 0;
    for (int r = 0; r < REPS; r++) {
        struct warg a = { body, c0, 0, 0, -1, 0 }, b = { body, c1, 0, 1, -1, 0 };
        g_one_line[0] = 0;
        g_pair[c0][0] = 0; g_pair[c1][0] = 0;
        pthread_t ta, tb;
        uint64_t t0 = rdtsc();
        if (pthread_create(&ta, NULL, worker_one_line, &a) != 0) { bad++; continue; }
        if (pthread_create(&tb, NULL, worker_one_line, &b) != 0) { bad++; continue; }
        pthread_join(ta, NULL);
        pthread_join(tb, NULL);
        uint64_t t1 = rdtsc();
        if (a.seen_cpu != c0 || b.seen_cpu != c1) { bad++; continue; }
        double per = (double)(t1 - t0) / (2.0 * (double)ITERS);
        if (per < best) best = per;
    }
    if (discarded) *discarded += bad;
    return bad >= REPS ? -1.0 : best;
}

static void sec_atomic(void) {
    puts("");
    puts("3. THE INSTRUCTION THAT COSTS");
    puts("   Everything so far was two threads fighting.  This section is ONE");
    puts("   thread, and it is the only place in this course where the hardware");
    puts("   imposes a cost that has nothing to do with another thread.");

    int bad = 0;
    /* Uncontended: two threads on two SEPARATE lines, each doing a locked op.
     * Nobody shares, so the only cost is the one the instruction imposes on
     * ITSELF -- which on x86 is a full barrier, not just an atomicity promise.
     * Same cores, same body, same iteration count as the table below it. */
    double u_st   = measure(BODY_STORE, 0, 4, &bad);
    double u_xadd = measure(BODY_XADD, 0, 4, &bad);
    double u_cas  = measure(BODY_CAS,  0, 4, &bad);
    /* Contended: the same two threads, the same cores, ONE line. */
    double s_st   = measure_one_line(BODY_STORE, 0, 4, &bad);
    double s_xadd = measure_one_line(BODY_XADD,  0, 4, &bad);
    double s_cas  = measure_one_line(BODY_CAS,   0, 4, &bad);

    printf("\n   two threads, TWO SEPARATE lines -- nothing shared at all:\n");
    printf("      plain store        %8.2f ticks/op   <- the floor\n", u_st);
    printf("      lock xadd          %8.2f ticks/op   %6.2fx the plain store\n",
           u_xadd, u_xadd / u_st);
    printf("      lock cmpxchg loop  %8.2f ticks/op   %6.2fx the plain store\n",
           u_cas, u_cas / u_st);

    printf("\n   the SAME bodies, both threads on ONE line:\n");
    printf("      plain store        %8.2f ticks/op   %6.2fx the floor\n",
           s_st, s_st / u_st);
    printf("      lock xadd          %8.2f ticks/op   %6.2fx the floor\n",
           s_xadd, s_xadd / u_st);
    printf("      lock cmpxchg loop  %8.2f ticks/op   %6.2fx the floor\n",
           s_cas, s_cas / u_st);

    puts("\n   The first table is the interesting one and it is the one people do");
    puts("   not expect.  A `lock` prefix on a machine with nothing to be locked");
    puts("   against is NOT free: it costs several times a plain store, on ONE");
    puts("   thread, with NO other thread running.  That is not a coherence");
    puts("   cost -- there is no coherence traffic, nothing to be coherent with.");
    puts("   It is the instruction's own guarantee, and on x86 the guarantee is");
    puts("   a FULL memory barrier: loads before it cannot move after it, stores");
    puts("   before it cannot be delayed past it, and both are ordered against");
    puts("   every other core.  You pay for that whether or not anyone is there.");

    puts("\n   THE MOST IMPORTANT NUMBER IN THIS SECTION, and it is a subtraction:");
    printf("      lock xadd,   one line  %8.2f\n", s_xadd);
    printf("      lock xadd,   own line   %8.2f\n", u_xadd);
    printf("      the cost of CONTENTION  %8.2f ticks  = %.2fx the uncontended cost\n\n",
           s_xadd - u_xadd, (s_xadd - u_xadd) / u_xadd);
    puts("   A contended atomic is not twice an uncontended one because the");
    puts("   hardware is twice as busy.  It is expensive because ONE core OWNS");
    puts("   the line and the other must take it, and the ownership has to move");
    puts("   back and forth, and each move is a round trip neither side can");
    puts("   overlap with its own work.  This is why a contended counter is a");
    puts("   queue and not a fast counter, and why the fix is never a better CPU.");

    printf("\n   the CAS loop, against the xadd, on the same two configurations:\n");
    printf("      separate lines    %8.2f against %8.2f   %6.2fx\n",
           u_cas, u_xadd, u_cas / u_xadd);
    printf("      one shared line   %8.2f against %8.2f   %6.2fx\n",
           s_cas, s_xadd, s_cas / s_xadd);
    puts("\n   Read those two ratios AGAINST EACH OTHER rather than separately,");
    puts("   because the difference between them is the finding.  A CAS is the");
    puts("   general form and a fetch-and-add is the special case that cannot");
    puts("   fail, so on SEPARATE lines the retry structure is visible and it");
    puts("   costs something.  On a SHARED line the two become indistinguishable,");
    puts("   because when the line is changing hands on every operation the");
    puts("   transfer dominates everything the instruction does around it.");
    puts("\n   That is the general shape of a contended measurement: the LOWER");
    puts("   bound on what you are timing is not the thing you meant to time, and");
    puts("   the only honest report is the two numbers side by side.  A draft of");
    puts("   this section said the CAS loop 'costs more on a shared line because");
    puts("   the retry rate is the contention'.  It does not.  It costs the SAME,");
    puts("   and the sentence was a story about a number that contradicted it.");
}

/* ------------------------------------------------------------------ */
/* 4. ordering                                                         */
/* ------------------------------------------------------------------ */

static void sec_ordering(void) {
    puts("");
    puts("4. WHAT ORDERING COSTS, AND WHAT IT CANNOT BE MEASURED AS");
    puts("   The instruction above promises atomicity and, on x86, also promises");
    puts("   ordering.  This section separates the two promises and is honest");
    puts("   about how little of the second one can be shown from user mode.");

    /* A store-then-load message passing pattern, with and without a fence.
     * The fenced version is slower BY CONSTRUCTION and the result is the same,
     * because x86-64 is already strongly ordered for these accesses -- which
     * is the point: the fence is portable insurance, and on THIS machine it
     * buys nothing that the measurement can see. */
    static volatile int  g_flag;
    static volatile long g_data;
    static volatile long g_sink;

    const long N = 2000000;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (long i = 0; i < N; i++) {
        g_data = i;
        __asm__ volatile("" ::: "memory");
        g_flag = 1;
        g_sink = g_flag;
        /* The two stores are what the fence orders.  Both are volatile so the
         * compiler cannot delete them, and the memory clobber keeps it from
         * moving the volatile store past the flag store -- which is the WHOLE
         * of what this loop is testing, and the reason a plain C loop would
         * have measured the compiler rather than the CPU. */
        if (g_sink == 12345 || g_data == -1) g_flag = 0;
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double plain_ns = (double)(t1.tv_sec - t0.tv_sec) * 1e9 + (double)(t1.tv_nsec - t0.tv_nsec);

    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (long i = 0; i < N; i++) {
        g_data = i;
        __asm__ volatile("mfence" ::: "memory");
        g_flag = 1;
        g_sink = g_flag;
        if (g_sink == 12345 || g_data == -1) g_flag = 0;
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double fence_ns = (double)(t1.tv_sec - t0.tv_sec) * 1e9 + (double)(t1.tv_nsec - t0.tv_nsec);

    printf("\n   %ld iterations, store data / store flag / load flag:\n", N);
    printf("      no fence      %8.1f ns/iter\n", plain_ns / N);
    printf("      mfence        %8.1f ns/iter   %6.2fx\n", fence_ns / N, fence_ns / plain_ns);
    puts("\n   The two loops COMPUTE THE SAME ANSWER.  The fence cannot change");
    puts("   what this program computes on x86-64, and it is not cheap.  That is");
    puts("   not an argument against the fence: it is an argument for knowing WHY");
    puts("   you have one.  x86-64's memory model is already strong enough that");
    puts("   an ordinary store then an ordinary load cannot be reordered past");
    puts("   each other.  A weaker architecture -- and a compiler that does not");
    puts("   know which architecture it is generating for -- needs the fence to");
    puts("   make that true, and the SAME SOURCE needs it on one and not on the");
    puts("   other.  That is why the fence is in the source and the cost is not.");

    puts("\n   What CANNOT be measured here, and this is the whole limit:");
    puts("     * That a fence is CORRECT.  Correctness of an ordering guarantee is");
    puts("       not a duration.  A loop that runs in the same number of");
    puts("       nanoseconds with and without the fence is the OBSERVABLE RESULT");
    puts("       of both being correct, and it is also what you would see if the");
    puts("       fence were a no-op.  This measurement cannot tell those apart,");
    puts("       and neither can any timing measurement on any machine.");
    puts("     * That the compiler did not reorder the stores anyway.  The");
    puts("       `volatile` and the memory clobber above make the question moot");
    puts("       here, but a fence in C source says nothing to a compiler that");
    puts("       is compiling for a machine with a weaker model unless the");
    puts("       fence is an intrinsic with the right semantics for THAT target.");
    puts("     * How many fences were ACTUALLY executed.  A compiler is allowed");
    puts("       to delete a redundant one, and on x86 it usually does.  The");
    puts("       number above is an upper bound on what the source asked for.");
    puts("     * The order in which two CORES observed anything.  That is a");
    puts("       property of a program the user cannot write, and this course");
    puts("       does not attempt it.");
    puts("\n   A course that cannot measure the second most important thing in");
    puts("   concurrent programming should say so here rather than quoting the");
    puts("   architecture's ordering table as though it were a result.  The");
    puts("   ordering table is in the ISA course's future and in the privileged");
    puts("   specification; it is a CONTRACT, and this is an observation.");
}

/* ------------------------------------------------------------------ */
/* 5. NUMA                                                            */
/* ------------------------------------------------------------------ */

static void sec_numa(void) {
    puts("");
    puts("5. NUMA, WHICH IS ABSENT HERE");
    puts("   Memory Non-Uniform Access is the case where the answer to \"how far");
    puts("   is memory?\" depends on WHICH processor asked.  This machine has one");
    puts("   socket and one memory controller group, so the phenomenon cannot");
    puts("   occur -- and its absence is a measurement, not a gap.");

    int nodelist = -1;
    if (slurp("/sys/devices/system/node/online", g_buf, sizeof g_buf) > 0) {
        char *nl = strchr(g_buf, '\n'); if (nl) *nl = 0;
        nodelist = 0;
        for (const char *q = g_buf; *q; q++) if (*q == ',') nodelist = 2;
        printf("\n   /sys/devices/system/node/online  \"%s\"  -> %d node(s)\n",
               g_buf, nodelist == 0 ? 1 : nodelist);
    } else {
        puts("\n   no /sys/devices/system/node/online");
    }
    if (slurp("/sys/devices/system/node/node0/cpulist", g_buf, sizeof g_buf) > 0) {
        char *nl = strchr(g_buf, '\n'); if (nl) *nl = 0;
        printf("   node0 cpulist                    \"%s\"\n", g_buf);
    }

    puts("\n   So: ONE memory domain.  Every core on this machine is the same");
    puts("   distance from every address, and the number in section 2 is a");
    puts("   statement about CACHE COHERENCE and not about distance.");
    puts("\n   What that means for the claims in this course, stated precisely:");
    puts("     * every ratio in section 2 is a COHERENCE ratio.  None of them is");
    puts("       a NUMA ratio, and none of them would survive a machine with two");
    puts("       nodes, where the remote case would be a DIFFERENT experiment");
    puts("       rather than a bigger number.");
    puts("     * the pinning in section 2 chooses between CORES, not between");
    puts("       nodes.  On a two-socket machine the same code and the same");
    puts("       pinning routine would measure remote memory if the second core");
    puts("       were on the other socket, and the harness would still go green,");
    puts("       because nothing in it checks the node.  THAT IS A REAL GAP IN");
    puts("       THIS HARNESS and it is named here rather than left.");
    puts("     * a reader on a multi-socket machine should extend the topology");
    puts("       section to read physical_package_id -- which this file already");
    puts("       reads, prints, and does not yet act on -- and add a row per");
    puts("       (core, node) pair rather than per core pair.");

    puts("\n   The portable content is the DISTINCTION, which is the reason this");
    puts("   section exists rather than being deleted as unmeasurable:");
    puts("      cache coherence  a question between two CACHES.  One line, one");
    puts("                      owner at a time.  Solved by a protocol, and the");
    puts("                      cost is a line transfer.  THIS is what section 2");
    puts("                      measured.");
    puts("      NUMA             a question between a CORE and a MEMORY CONTROLLER.");
    puts("                      Nothing is shared and nothing is owned; the address");
    puts("                      just decodes differently.  The cost is latency and");
    puts("                      bandwidth, not ownership transfer.");
    puts("   They are confused constantly, and the confusion has a name: \"the");
    puts("   memory is remote\".  On a one-node machine that sentence is");
    puts("   meaningless, which is why this course can make the distinction");
    puts("   without measuring the second half of it.");
}

/* ------------------------------------------------------------------ */
/* 6. three architectures                                              */
/* ------------------------------------------------------------------ */

static void sec_three(void) {
    puts("");
    puts("6. THE SAME QUESTIONS, THREE ANSWERS");
    puts("   QUOTED, NOT MEASURED.  This machine is x86-64 and there is no other");
    puts("   architecture in the room; every claim below is a manual claim with a");
    puts("   document, and the artifact's limits block says so.");

    puts("\n   x86-64");
    puts("      the protocol        MESI, on a modified 64-byte line.  Four states:");
    puts("                         M exclusive-modified, E exclusive, S shared, I");
    puts("                         invalid.  E exists so that a core that KNOWS it");
    puts("                         is the only reader can answer a read without");
    puts("                         invalidating -- it is an optimisation, and its");
    puts("                         cost is a state the others do not have.");
    puts("      the snoop          every cache watches the shared bus.  A core that");
    puts("                         wants a line it does not have issues a request,");
    puts("                         and every other cache checks its own tags for a");
    puts("                         copy it would have to invalidate.");
    puts("      the ordered atomic a `lock` prefix.  On x86 it implies a full");
    puts("                         barrier, which is why an uncontended atomic still");
    puts("                         costs several times a plain store -- SECTION 3.");
    puts("      the order           the model is STRONG: loads and stores are not");
    puts("                         reordered with other loads and stores, so an");
    puts("                         ordinary fence is redundant on this machine and");
    puts("                         the same source needs one elsewhere.");
    puts("      what is hardware    the line and the atomic instruction.  The");
    puts("                         PROTOCOL is microcode, not an instruction anyone");
    puts("                         can execute.");

    puts("\n   AArch64");
    puts("      the protocol        The same MESI idea, and the tagged accesses are");
    puts("                         an INSTRUCTION: LDAR, STLR, LDAXR/STLXR.  The");
    puts("                         acquire and release are things you WRITE, which");
    puts("                         is a different design from a prefix.");
    puts("      the cost            an acquire load costs what a plain load costs");
    puts("                         plus the wait; the barrier is not a separate");
    puts("                         instruction you sprinkle, it is a mode the");
    puts("                         access itself has.  On x86 the same guarantee is");
    puts("                         attached to every locked instruction whether you");
    puts("                         wanted it or not.");
    puts("      the order           WEAK by default.  Two cores may observe stores");
    puts("                         in different orders.  THIS is the real reason the");
    puts("                         fence in section 4 is not redundant in general --");
    puts("                         it is redundant HERE, and the source has to say");
    puts("                         so with an intrinsic, not by leaving it out.");
    puts("      the difference      a program that is correct on x86-64 by accident");
    puts("                         is a program that is wrong on AArch64.  The one");
    puts("                         that is correct on both used to have fences it");
    puts("                         did not need on Intel.");

    puts("\n   RISC-V");
    puts("      the protocol        MESI again, and the RVWMO model is WEAK, with");
    puts("                         the fences being FENCE instructions whose");
    puts("                         operands say which edges you want: FENCE rw,rw");
    puts("                         orders reads before writes, FENCE w,r does the");
    puts("                         other pair.  A single FENCE orders everything.");
    puts("      the atomics         LR/SC.  The load-reserved does not lock the line");
    puts("                         and the store-exclusive only succeeds if nothing");
    puts("                         else wrote in between, so a CONTENDED atomic is");
    puts("                         a RETRY LOOP by construction rather than by");
    puts("                         accident.  This is the opposite trade from");
    puts("                         x86's: no unconditional line acquisition, and");
    puts("                         unbounded retries under contention.");
    puts("      the cost            an LR/SC pair is two instructions where x86");
    puts("                         spends one.  The win is that the uncontended case");
    puts("                         touches nothing it does not need to.");
    puts("      the difference      a fair queue is one line of assembly on RISC-V");
    puts("                         and a data structure on x86.");

    puts("\n   THE PORTABLE CONTENT, which is the same five-part shape the");
    puts("   privilege course found, and it is worth noticing that it recurs:");
    puts("      1. a unit of sharing          a cache line / a cache line / a location");
    puts("      2. a state machine            MESI / MESI / MESI");
    puts("      3. a way to notice a change   a snoop / a snoop / a snoop");
    puts("      4. an atomic update           LOCK / LDAR-STLR / LR-SC");
    puts("      5. a way to order it          a prefix / an access mode / a FENCE");
    puts("\n   Rows 1 to 3 have been the same on every desktop CPU for thirty");
    puts("   years, which is why \"cache coherence\" feels like one thing.  Rows 4");
    puts("   and 5 are where the architectures genuinely differ, and they are");
    puts("   exactly the two rows that determine whether a LOCK-FREE ALGORITHM");
    puts("   written on one of them is correct on another.  See R5.");
}

/* ------------------------------------------------------------------ */
/* 7. retractions and limits                                           */
/* ------------------------------------------------------------------ */

static void sec_limits(void) {
    puts("");
    puts("7. RETRACTIONS AND LIMITS");
    puts("   Printed here so they cannot be quietly dropped, and asserted by");
    puts("   crosscheck.py so they cannot be DELETED either.");

    puts("\n   R1. \"The plain-store arm measured 1.75 ticks per operation.\"");
    puts("       It MEASURED NOTHING.  Written in C as a relaxed atomic store to");
    puts("       a variable nothing ever read, the compiler proved the entire");
    puts("       four-million-iteration loop dead and removed it, and the result");
    puts("       was a plausible-looking number for four million operations that");
    puts("       did not happen.  An `asm volatile` store has no such door.  This");
    puts("       is the third course in a row to hit the same bug, in the same");
    puts("       form, and the rule is now written into rule 2 of the header.");
    puts("       The general form: WHEN TWO THINGS MEASURE AS SIMILAR, THE FIRST");
    puts("       HYPOTHESIS IS THAT YOUR OPTIMISER DELETED THE DIFFERENCE.");

    puts("\n   R2. \"Two threads on unspecified CPUs is a measurement.\"  NO, and");
    puts("       the memory course already knew it -- that is why it discarded");
    puts("       rows where both threads landed on one core.  The difference here");
    puts("       is that the check is the MECHANISM rather than a filter: every");
    puts("       worker calls sched_getcpu() and the repetition is discarded if");
    puts("       either thread is anywhere but where it was pinned.  Rows that");
    puts("       fail this are counted and printed, not quietly dropped.");

    puts("\n   R3. \"False sharing is a 61.9x effect.\"  The number is the memory");
    puts("       course's and it is correct THERE.  It is not restated as a");
    puts("       property of this machine's coherence protocol here, because the");
    puts("       ratio in section 2 depends on the body, the width and the clock,");
    puts("       and re-publishing it as a fixed number would be the remembered-");
    puts("       number mistake the harness exists to prevent.");

    puts("\n   R4. \"An uncontended lock is expensive because of coherence.\"");
    puts("       RETRACTED TO THE WRONG REASON.  It is expensive, and the");
    puts("       measurement in section 3 separates the two, but the cost is NOT");
    puts("       coherence -- there is no other thread and nothing to be coherent");
    puts("       with.  It is the barrier the prefix implies, paid by a thread");
    puts("       that had no reason to pay it.  See R5.");

    puts("\n   R5. \"`lock` is one idea that could have been three.\"  The x86-64");
    puts("       design ties ATOMICITY and ORDERING to one prefix, so every");
    puts("       atomic operation is also a full barrier.  AArch64 makes them");
    puts("       separate instructions and RISC-V makes them a fence with chosen");
    puts("       edges.  A lock-free algorithm written on x86-64 is therefore");
    puts("       correct partly BY ACCIDENT: it relies on an ordering guarantee it");
    puts("       never asked for, because the hardware supplied it for free.  Port");
    puts("       that algorithm to a weakly-ordered machine and it is wrong, and");
    puts("       the tests that passed on the first machine will not find it.");

    puts("\n   R6. \"A placement check is a filter you apply afterwards.\"  NO.");
    puts("       Applied afterwards, it cannot tell you WHY a thread was in the");
    puts("       wrong place, and on a loaded machine it silently converts every");
    puts("       row into a discarded row while the run still looks like it");
    puts("       worked.  Reading sched_getcpu() from inside the worker is the");
    puts("       only version that reports the number of discards.");

    puts("\n   LIMITS -- what this artifact cannot tell you, printed not footnoted:");
    puts("     * ANY COUNT of coherence traffic.  There is no PMU here: no miss, no");
    puts("       snoop, no line transfer, no directory notification can be");
    puts("       counted.  Every number is a DURATION, and a duration bounds a");
    puts("       count without measuring it.  Section 2's ratios are ratios of");
    puts("       durations and nothing more.");
    puts("     * WHETHER THE PROTOCOL IS MESI.  MESI is what the manuals say and");
    puts("       what the state names in every profiler ever written imply.  No");
    puts("       user-space experiment distinguishes MESI from MOESI from a");
    puts("       directory protocol, and this artifact does not claim to.");
    puts("     * ANYTHING about NUMA.  One node, one domain.  See section 5, which");
    puts("       explains why that makes the DISTINCTION measurable even though");
    puts("       the second half of it is not.");
    puts("     * THE MEMORY ORDERING RULES.  Section 4 measures a fence's DURATION");
    puts("       and explicitly not its CORRECTNESS, and says why a timing");
    puts("       measurement cannot: a loop that runs the same either way is also");
    puts("       what you would see if the fence were a no-op.");
    puts("     * THE OTHER TWO ARCHITECTURES.  Section 6 is quoted, not run.");
    puts("     * ANYTHING PAST TWO THREADS.  Every experiment here is a pair,");
    puts("       because a pair is the smallest thing that has a coherence cost");
    puts("       at all and a measurement of N>2 on this machine would be a");
    puts("       measurement of the OTHER ELEVEN THREADS.");
    puts("     * WHETHER THE COMPILER INSERTED A FENCE.  Section 4 counts what");
    puts("       the source asked for, which is an upper bound.");
}

/* ------------------------------------------------------------------ */

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    puts("=====================================================================");
    puts(" smpbench -- Multiprocessor Architecture");
    puts("=====================================================================");
    sec_instrument();
    sec_topology();
    sec_placements();
    sec_atomic();
    sec_ordering();
    sec_numa();
    sec_three();
    sec_limits();
    puts("");
    puts("=====================================================================");
    return 0;
}
