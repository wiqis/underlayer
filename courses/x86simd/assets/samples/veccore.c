/* veccore.c -- the instrument, the census, and main().  Everything here
 * runs BEFORE any claim is made, and section 1 prints the result before
 * section 2 starts.
 */
#include "vecdump.h"

/* ------------------------------------------------------------------ */
/* the globals every file in this module shares                        */
/* ------------------------------------------------------------------ */
volatile long g_sink     = 0;
uint64_t      g_ck       = 0;
long          g_iters    = 300000;
int           g_copies   = 7;
int           g_quick    = 0;
int           g_rows     = 0;
int           g_pinned   = -1;
int           g_at_iters = 60000;
char         *g_dis      = NULL;

/* ------------------------------------------------------------------ */
/* the instrument                                                      */
/* ------------------------------------------------------------------ */
double wall_seconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

void nap_ms(long ms)
{
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

void do_cpuid(unsigned leaf, unsigned sub, unsigned *a, unsigned *b,
              unsigned *c, unsigned *d)
{
    __asm__ __volatile__("cpuid" : "=a"(*a), "=b"(*b), "=c"(*c), "=d"(*d)
                         : "a"(leaf), "c"(sub));
}

void banner(const char *s) { printf("\n%s\n\n", s); }
void endbanner(void)      { printf("\n"); }

void pin_and_verify(int cpu)
{
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(cpu, &set);
    if (sched_setaffinity(0, sizeof(set), &set) != 0) {
        printf("  !! could not pin to cpu%d, continuing UNPINNED\n", cpu);
        printf("     every figure below is then a figure about WHATEVER\n");
        printf("     the scheduler chose, and this file says so.\n");
        return;
    }
    g_pinned = sched_getcpu();
    printf("  pinned to cpu%d, and the cpu that answered is %d  %s\n",
           cpu, g_pinned,
           cpu == g_pinned
             ? "(VERIFIED -- the rows below are a controlled experiment)"
             : "(MISMATCH -- they are not)");
}

/* Both rates are timed by clock_gettime.  A busy rate measured by spinning
 * until the TSC had advanced N ticks and dividing by ONE SECOND returns N
 * GHz on a machine whose TSC is nowhere near N, because the numerator is
 * then a threshold and not a measurement. */
double tsc_rate_busy(void)
{
    double w0 = wall_seconds();
    uint64_t t0 = rdtsc_(), k = 0;
    do {
        for (int i = 0; i < 100000; i++) k += (uint64_t)i * (uint64_t)i;
    } while (wall_seconds() - w0 < 0.300);
    uint64_t t1 = rdtsc_();
    double w1 = wall_seconds();
    g_sink += (long)k;
    return (double)(t1 - t0) / (w1 - w0) / 1e9;
}

double tsc_rate_across_sleep(void)
{
    double w0 = wall_seconds();
    uint64_t t0 = rdtsc_();
    nap_ms(300);
    uint64_t t1 = rdtsc_();
    double w1 = wall_seconds();
    return (double)(t1 - t0) / (w1 - w0) / 1e9;
}

/* The floor, on two bodies, because they measure two different things.  A
 * pointer chase's "noise" is memory; an arithmetic loop's is mostly the
 * core clock, and calling that noise is the commonest error there is. */
double floor_pointer_chase(void)
{
    enum { NPTR = 16384, STRIDE = 1021 };
    uint32_t *nodes = NULL;
    if (posix_memalign((void **)&nodes, 64, NPTR * sizeof(uint32_t)) != 0) {
        printf("out of memory in the floor\n");
        exit(1);
    }
    for (int i = 0; i < NPTR; i++) nodes[i] = (uint32_t)((i + STRIDE) % NPTR);
    uint32_t p = 0;
    double best = 1e30;
    for (int r = 0; r < g_copies * 2; r++) {
        uint64_t t0 = rdtsc_();
        for (long i = 0; i < g_iters; i++) p = nodes[p];
        uint64_t t1 = rdtsc_();
        double per = (double)(t1 - t0) / (double)g_iters;
        if (per < best) best = per;
        g_sink += p;
    }
    free(nodes);
    return best;
}

double floor_arithmetic(void)
{
    double best = 1e30;
    uint64_t a = 1;
    for (int r = 0; r < g_copies * 2; r++) {
        uint64_t t0 = rdtsc_();
        for (long i = 0; i < g_iters; i++)
            __asm__ __volatile__("add $1, %0" : "+r"(a) :: "cc");
        uint64_t t1 = rdtsc_();
        double per = (double)(t1 - t0) / (double)g_iters;
        if (per < best) best = per;
    }
    g_sink += (long)a;
    return best;
}

/* ------------------------------------------------------------------ */
/* the instruction census                                             */
/*                                                                     */
/* A claim like "this file measured AVX2" is a claim about a BINARY, and */
/* a binary can be counted.  Every noinline arm body calls instr_note()  */
/* with the mnemonic it exists to measure, and section 1 prints the tally */
/* BEFORE any timing that depends on it.  Without this the -mavx2 flag is  */
/* a claim about a build command, and the first version of the SIMD      */
/* course lost an entire experiment to exactly that.                     */
/* ------------------------------------------------------------------ */
static char g_seen[64][24];
static int  g_hits[64];
static int  g_n = 0;

void instr_reset(void)
{
    g_n = 0;
    memset(g_hits, 0, sizeof g_hits);
}

void instr_note(const char *s)
{
    for (int i = 0; i < g_n; i++)
        if (!strcmp(g_seen[i], s)) { g_hits[i]++; return; }
    if (g_n < 64) {
        snprintf(g_seen[g_n], sizeof g_seen[0], "%s", s);
        g_hits[g_n] = 1;
        g_n++;
    }
}

int instr_count(const char *s)
{
    for (int i = 0; i < g_n; i++)
        if (!strcmp(g_seen[i], s)) return g_hits[i];
    return 0;
}

void instr_report(void)
{
    printf("  the instructions the arms BELIEVE they are measuring:\n");
    int n = 0;
    for (int i = 0; i < g_n; i++) {
        printf("    %-14s x%d\n", g_seen[i], g_hits[i]);
        n++;
    }
    printf("  %d distinct instruction bodies recorded.  The authority on\n"
           "  whether they are really there is objdump on this binary, and\n"
           "  section 1B prints that count.\n\n", n);
    g_rows++;
}

/* ------------------------------------------------------------------ */
/* main                                                                */
/* ------------------------------------------------------------------ */
int main(int argc, char **argv)
{
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--quick")) g_quick = 1;
        else if (!strncmp(argv[i], "--iters=", 8))
            g_iters = atol(argv[i] + 8);
        else if (!strncmp(argv[i], "--at-iters=", 11))
            g_at_iters = atol(argv[i] + 11);
        else if (!strcmp(argv[i], "--dis")) g_dis = (char *)"vecdump_dis.txt";
        else if (!strcmp(argv[i], "--emit-maps")) { maps_emit(); return 0; }
    }
    if (g_quick) { g_iters = 40000; g_at_iters = 20000; g_copies = 3; }

    section_1();
    section_1b();
    section_2();
    section_3();
    section_4();
    section_5();
    section_6();
    section_7();

    printf("\n  rows measured: %d\n", g_rows);
    printf("  checksums folded in: 0x%016llx\n",
           (unsigned long long)(g_ck + (uint64_t)g_sink));
    printf("  g_sink: %ld\n", (long)g_sink);
    return 0;
}
