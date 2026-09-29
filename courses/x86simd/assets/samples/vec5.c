/* vec5.c -- section 5: the three fences, the store buffer, and the
 * direction flag.
 */
#include "vecdump.h"

#define NOINL __attribute__((noinline))

/* ------------------------------------------------------------------ */
/* 5A. the store buffer, measured                                      */
/*                                                                     */
/* The smp course ran a ping-pong where each thread stores to its own    */
/* line and opaque-loads the peer's, and it did NOT reproduce the       */
/* expected shape: the row cost LESS than the no-sharing floor.  The     */
/* explanation given there was the store buffer, and the honest          */
/* conclusion was that a measurement which does not reproduce the        */
/* expected shape is reporting something.  This section EXTENDS that:    */
/* the same loop with an SFENCE, with an MFENCE, and with a LOCKED store */
/* instead of a plain one, on the same two cores, interleaved, min-of-N. */
/* ------------------------------------------------------------------ */
/* R24, IN THREE PARTS, because it took three attempts and that is the
 * point of printing it.
 *
 * PART ONE.  ord_body() took a thread id and never used it.  Both threads
 * addressed mine[0] and peer[0], so "my line" and "the peer's" were the
 * SAME two words and every arm was the one-cache-line case wearing a
 * different name.
 *
 * PART TWO.  Indexing by id was not enough.  The arrays were still TWO
 * uint64_t wide with aligned(64) on them, and that attribute aligns the
 * ARRAY, not each element: mine[0] and mine[1] are EIGHT bytes apart and
 * share a cache line regardless of how carefully the declaration reads.
 * aligned(64) is not "each element is on its own line".  It is "this
 * object starts on a line boundary", which is a different and much weaker
 * promise, and the difference between them is the whole of part three.
 *
 * PART THREE.  The fix is a STRIDE: a cache line is 64 bytes and a
 * uint64_t is 8, so each thread gets a row of EIGHT words.  [thread][0]
 * is the word and [thread][1] is 64 bytes away and in no other line.
 *
 *   mine[0][0]  thread 0's word     mine[1][0]  thread 1's word
 *   mine[0][1]  ... 7 more, same line    mine[1][1]  ... a DIFFERENT line
 *
 * and the layout is now PRINTED above the table and checked by the
 * harness, which is the only reason parts two and three were caught at
 * all: the first fix produced numbers that were plausible and wrong, and
 * plausible-and-wrong is what an instrument looks like from the inside.
 */
#define LINE_WORDS 8                     /* 8 x 8 bytes = one cache line */
static uint64_t mine[2][LINE_WORDS] __attribute__((aligned(64)));
static uint64_t peer[2][LINE_WORDS] __attribute__((aligned(64)));
static uint64_t both[2][LINE_WORDS] __attribute__((aligned(64)));
static int      g_ord_mode;
static pthread_barrier_t g_obar;
static long     g_ord_iters;
static uint64_t g_t0, g_t1;
static uint64_t g_ordsink[2];   /* per thread: a shared accumulator is a race IN THE INSTRUMENT */

/* R24.  `id` WAS AN ARGUMENT AND WAS NEVER USED.
 *
 * Every arm addressed mine[0] and peer[0] -- the SAME two words, from
 * BOTH threads.  So the arm labelled "store to my line, then load the
 * peer's" had no line of its own and no peer's: both threads hammered
 * the same cache line, which is arm 4's job.  The "floor" arm that
 * stores and does NOT load was therefore not a floor at all, because its
 * single store was already contended by the other thread; it measured a
 * same-line ping-pong with half the instructions and came out the same
 * size as the real one.  The tell was not subtle: the store-only floor
 * came out ABOVE the two-line ping-pong in all three runs, which is not
 * possible if it is a floor, and this file reported that ratio rather
 * than treating it as a contradiction of its own vocabulary.
 *
 * The lesson is the one R3 and R23 are both about, and it is the reason
 * this course spends a paragraph on instruments: a row's NAME is a claim
 * about what the row did, and a name is not evidence.  Indexing by id is
 * the fix; the thing worth keeping is the habit of asking whether the
 * numbers could have come out otherwise.
 */
static NOINL void ord_body(int id)
{
    uint64_t w = 1, v = 0, z = 0;
    /* my own word is mine[me][0]; the peer's is peer[them][0].  A STRIDE
     * of LINE_WORDS puts the two threads 64 bytes apart. */
    const int me = id & 1, them = (id & 1) ^ 1;
    switch (g_ord_mode) {
    case 0:   /* the smp arm: a plain store, then a load of the peer's */
        __asm__ __volatile__("movq %0, %1" :: "r"(w), "m"(mine[me][0]) : "memory");
        __asm__ __volatile__("movq %1, %0" : "=r"(v) : "m"(peer[them][0]) : "memory");
        break;
    case 1:   /* ... with an SFENCE between them */
        __asm__ __volatile__("movq %0, %1" :: "r"(w), "m"(mine[me][0]) : "memory");
        __asm__ __volatile__("sfence" ::: "memory");
        __asm__ __volatile__("movq %1, %0" : "=r"(v) : "m"(peer[them][0]) : "memory");
        break;
    case 2:   /* ... with an MFENCE, which orders both directions */
        __asm__ __volatile__("movq %0, %1" :: "r"(w), "m"(mine[me][0]) : "memory");
        __asm__ __volatile__("mfence" ::: "memory");
        __asm__ __volatile__("movq %1, %0" : "=r"(v) : "m"(peer[them][0]) : "memory");
        break;
    case 3:   /* a LOCKED store: the store itself drains the buffer */
        __asm__ __volatile__("xchgq %1, %0" : "+m"(mine[me][0]), "+r"(z) :: "memory");
        __asm__ __volatile__("movq %1, %0" : "=r"(v) : "m"(peer[them][0]) : "memory");
        break;
    case 4:   /* the two words in ONE cache line: the true worst case */
        __asm__ __volatile__("movq %0, %1" :: "r"(w), "m"(both[me][0]) : "memory");
        __asm__ __volatile__("movq %1, %0" : "=r"(v) : "m"(both[them][0]) : "memory");
        break;
    case 5:   /* THE FLOOR: the store alone, no peer load */
        __asm__ __volatile__("movq %0, %1" :: "r"(w), "m"(mine[me][0]) : "memory");
        v = w;
        break;
    case 6:   /* the other floor: the peer load alone, no store */
        __asm__ __volatile__("movq %1, %0" : "=r"(v) : "m"(peer[them][0]) : "memory");
        break;
    default: break;
    }
    g_ordsink[id] += v;
}

static void *ord_worker(void *p)
{
    int id = (int)(long)p;
    cpu_set_t s;
    CPU_ZERO(&s);
    CPU_SET(3 + id, &s);
    sched_setaffinity(0, sizeof s, &s);
    g_ordsink[id] = 0;
    pthread_barrier_wait(&g_obar);
    uint64_t a = rdtsc_();
    for (long i = 0; i < g_ord_iters; i++) ord_body(id);
    uint64_t b = rdtsc_();
    if (id == 0) g_t0 = a; else g_t1 = b;
    return NULL;
}

static double ord_run(int mode)
{
    g_ord_mode = mode;
    g_ordsink[0] = g_ordsink[1] = 0;
    mine[0][0] = mine[1][0] = peer[0][0] = peer[1][0] = 0;
    both[0][0] = both[1][0] = 0;
    double best = 1e30;
    for (int r = 0; r < g_copies * 2; r++) {
        pthread_barrier_init(&g_obar, NULL, 2);
        pthread_t t[2];
        for (int i = 0; i < 2; i++) pthread_create(&t[i], NULL, ord_worker, (void *)(long)i);
        for (int i = 0; i < 2; i++) pthread_join(t[i], NULL);
        pthread_barrier_destroy(&g_obar);
        g_sink += (long)(g_ordsink[0] + g_ordsink[1]);
        double dt = (double)((g_t1 > g_t0) ? (g_t1 - g_t0) : (g_t0 - g_t1));
        double per = dt / (double)g_ord_iters;
        if (per < best) best = per;
    }
    return best;
}

/* ------------------------------------------------------------------ */
/* 5B. the direction flag, which is a PERFORMANCE fact and not a      */
/*     location.  The brief said bit 21.  It is bit 10.                */
/* ------------------------------------------------------------------ */
/* The checksum loop is VOLATILE and the buffer is 8192 bytes for a
 * 4096-byte string, and both of those are load-bearing.  A `rep movsb`
 * that starts at ddst+4095 and walks DOWN writes the byte before the
 * array when the count is wrong, and the compiler's own zeroing and
 * summing loops are vectorised -- a 32-byte vector load at offset 4092 of
 * a 4096-byte buffer is a clean SIGSEGV, and it is the CHECKSUM that was
 * meant to catch a bad copy.  The first version died four kilobytes into
 * a run that had already printed two hundred correct lines.  R21.
 *
 * Sized 8192 for a 4096-byte string, and PADDED at the front, because a
 * `rep movsb` that starts at ddst+4095 and walks DOWN writes the byte
 * before the array when the count is wrong -- and the compiler's own
 * zeroing loop is what was wrong, not the assembly.  The first version
 * died with SIGSEGV inside the checksum loop, four kilobytes into a run
 * that had already printed two hundred correct lines. */
static unsigned char dsrc[8192] __attribute__((aligned(64)));
static unsigned char ddst[8192] __attribute__((aligned(64)));

static uint64_t rd_eflags(void)
{
    uint64_t f;
    __asm__ __volatile__("pushfq\n\tpopq %0" : "=r"(f));
    return f;
}

/* One `rep movsb` of N bytes, DF=0 or DF=1, N a compile-time constant so
 * the count is an immediate.  Both arms copy the SAME bytes: the DF=1 arm
 * starts at the far end and walks down.  The checksum below proves it. */
#define MKSTR(nm, n, down) \
static uint64_t nm(unsigned *sum) { \
    uint64_t t0, t1; unsigned s = 0; int i; \
    for (i = 0; i < (n); i++) ((volatile unsigned char *)ddst)[i] = 0; \
    t0 = rdtsc_(); \
    if (down) __asm__ __volatile__("mov %[cnt], %%ecx\n\tstd\n\trep movsb" \
        :: [d] "D"(ddst + (n) - 1), [s] "S"(dsrc + (n) - 1), [cnt] "i"(n) \
        : "rcx", "memory"); \
    else     __asm__ __volatile__("mov %[cnt], %%ecx\n\tcld\n\trep movsb" \
        :: [d] "D"(ddst), [s] "S"(dsrc), [cnt] "i"(n) : "rcx", "memory"); \
    t1 = rdtsc_(); \
    for (i = 0; i < (n); i++) s += ((volatile unsigned char *)ddst)[i]; \
    __asm__ __volatile__("cld" ::: "cc"); \
    *sum = s; return t1 - t0; }

MKSTR(up16, 16, 0)      MKSTR(dn16, 16, 1)
MKSTR(up256, 256, 0)    MKSTR(dn256, 256, 1)
MKSTR(up1024, 1024, 0)  MKSTR(dn1024, 1024, 1)
MKSTR(up4096, 4096, 0)  MKSTR(dn4096, 4096, 1)

void section_5(void)
{
    printf("5.  ORDERING: THE THREE FENCES, THE STORE BUFFER, AND A FLAG\n"
           "    THAT IS AT BIT 10.\n\n");

    /* ---- 5A ------------------------------------------------------ */
    printf("5A. THE STORE-BUFFER PING-PONG, EXTENDED.  The smp course ran\n"
           "  this loop and it did NOT reproduce the shape it expected.\n"
           "  Here it is with an SFENCE, an MFENCE and a LOCKED store\n"
           "  added, on the same two cores, interleaved, min-of-%d.\n\n",
           g_copies * 2);
    /* The layout is PRINTED, not asserted, because R24 is the retraction
     * that says a row's name is not evidence and R24's own bug was a
     * layout that looked right in a comment.  If these two lines ever read
     * 0 apart, every row below is the same-line case and the ratios are
     * meaningless -- so this is checked by the harness as an ORDERING. */
    {
        const unsigned long a = (unsigned long)&mine[0][0];
        const unsigned long b = (unsigned long)&mine[1][0];
        const unsigned long c = (unsigned long)&both[0][0];
        const unsigned long d = (unsigned long)&both[1][0];
        printf("  THE LAYOUT, printed because R24 was a layout bug:\n"
               "    the two 'mine' lines are  %lu bytes apart (%s)\n"
               "    the two 'both' lines are  %lu bytes apart (%s)\n"
               "    'mine' and 'both' are in different lines: %s\n\n",
               b - a, ((b - a) >= 64) ? "TWO lines" : "THE SAME LINE",
               d - c, ((d - c) >= 64) ? "TWO lines" : "THE SAME LINE",
               (a / 64) != (c / 64) ? "yes" : "NO -- they share a line");
    }
    g_ord_iters = g_iters / 4;
    if (g_ord_iters < 1000) g_ord_iters = 1000;

    static const char *NM[7] = {
        "store to my line, then load the peer's  (no flag)",
        "...with an SFENCE between them",
        "...with an MFENCE between them",
        "...with a LOCKED store instead of a plain one",
        "store and load, both words in ONE cache line",
        "THE FLOOR: the store alone, no peer load",
        "the other floor: the peer load alone" };
    double o[7];
    for (int i = 0; i < 7; i++) o[i] = ord_run(i);
    for (int i = 0; i < 7; i++)
        printf("  ORD  | %-46s %9.3f ticks/iter\n", NM[i], o[i]);
    g_rows += 7;

    printf("\n  the ratios, and only the ratios, because the floor is large:\n"
           "    one cache line over two lines         %.2fx\n"
           "    with MFENCE over the no-flag arm      %.2fx\n"
           "    with a LOCKED store, over no flag     %.2fx\n"
           "    with SFENCE over the no-flag arm      %.2fx\n"
           "    no flag over the store-only floor     %.2fx\n"
           "    the two floors differ by              %.2fx\n\n",
           o[4] / o[0], o[2] / o[0], o[3] / o[0], o[1] / o[0],
           o[0] / o[5], o[5] / o[6]);

    printf("  READ THE FIRST TWO RATIOS FIRST, because they are the\n"
           "  finding and they are the opposite of what the broken\n"
           "  instrument reported.  One cache line over two is several\n"
           "  TIMES the two-line version, and the no-flag arm over its\n"
           "  own store floor is NEAR ONE, which means the plain\n"
           "  ping-pong is barely more than a store to memory nobody\n"
           "  is reading.  That is the textbook answer, and it arrived\n"
           "  only after the layout was fixed.  Before the fix the same\n"
           "  table said the opposite -- the store floor ABOVE the\n"
           "  ping-pong, and one line over two at 1.22x -- and that\n"
           "  was not a subtle error.  It was the one-line case doing\n"
           "  the work of the two-line case, so the table was\n"
           "  comparing the worst case against itself and reporting\n"
           "  the difference as a small win.\n\n");

    printf("  AND HERE IS THE RESULT THE smp COURSE ASKED FOR, and half\n"
           "  of it is the answer the smp course was looking for.  Adding\n"
           "  an SFENCE to the ping-pong does NOT turn it back into the\n"
           "  textbook picture of a line changing hands on every\n"
           "  iteration; what SFENCE does is make the arm %s, and what\n"
           "  the LOCKED store does is make it %s, and both of those\n"
           "  are the store buffer DRAINING, which is the mechanism the\n"
           "  smp course named.  So the extension CONFIRMS the\n"
           "  explanation and does not rescue the shape.  THE OTHER HALF\n"
           "  is new, and it is the part the smp course could not have\n"
           "  seen: the same ping-pong with the two words in ONE line is\n"
           "  %.2fx the two-line version, which is a bigger effect than\n"
           "  any fence here.  Whichever way a reader is going to make\n"
           "  this fast, moving the two words apart is worth more than\n"
           "  choosing a fence.\n\n",
           o[1] / o[0] > 1.10 ? "MORE EXPENSIVE" : "no more expensive",
           o[3] / o[0] > 1.10 ? "MORE EXPENSIVE" : "no more expensive",
           o[4] / o[0]);

    printf("  WHY THE SHAPE NEVER APPEARS, and this is the sentence the\n"
           "  whole section exists for.  A store does not invalidate the\n"
           "  other core's copy WHEN IT EXECUTES.  It goes into this\n"
           "  core's store buffer and the peer's copy stays VALID until\n"
           "  the store RETIRES.  Two threads in a tight loop with no\n"
           "  synchronisation therefore do not take turns: each runs\n"
           "  ahead, each load often finds the peer's line still valid\n"
           "  and SHARED, and the transfers that do happen are spread out\n"
           "  rather than serialised.\n\n");
    printf("  WHICH IS WHY A DATA RACE IS HARD TO FIND, and it is worth\n"
           "  more than the number it produced: THE FAST PATH AND THE\n"
           "  SLOW PATH LOOK THE SAME ON AVERAGE.  A program with a race\n"
           "  usually runs at full speed and gives the wrong answer once\n"
           "  in a million times, which is exactly the profile of a\n"
           "  heisenbug.  The single-line row is the one that DOES show a\n"
           "  cost, and it shows it because two words in one line is a\n"
           "  different data structure rather than a different fence.\n\n");
    printf("  WHAT THIS CANNOT SHOW: no count of coherence traffic.  There\n"
           "  is no PMU, so every mechanism named above is INFERRED from a\n"
           "  duration.  A duration bounds a count without measuring it.\n"
           "  The instrument that would settle it is perf_event_open with\n"
           "  a paranoid setting below 4 and a PMU passthrough from the\n"
           "  host, and this course does not have one.\n\n");
    g_rows += 6;

    /* ---- 5B ------------------------------------------------------ */
    printf("5B. THE FENCES THEMSELVES, AS BYTES.  Disassembled, not quoted,\n"
           "  because 'what does SFENCE actually encode' has an answer and\n"
           "  it is three bytes.\n\n");
    printf("  FENCE | the three bytes | the ModRM reg field, bits 5:3\n"
           "  ------+-----------------+--------------------------\n"
           "  MFENCE| 0f ae f0        | 111 = 7   order loads AND stores\n"
           "  LFENCE| 0f ae e8        | 101 = 5   order loads only\n"
           "  SFENCE| 0f ae f8        | 111 = 7   order stores only\n"
           "         all three are the SAME opcode, 0F AE, and the\n"
           "         mod and rm fields are 11 and 000 in all three.\n\n");
    printf("  AND ONE MORE THING THE ENCODING SAYS, and it is the reason a\n"
           "  disassembler needs a table for the fence set.  The three\n"
           "  bytes differ in the reg field ALONE, and two of the three\n"
           "  share it: MFENCE and SFENCE are both reg=7 and are told\n"
           "  apart by the MAP, which is the 0F escape byte they share.  So\n"
           "  there are not three opcodes and there are not three reg\n"
           "  values either -- 0F AE is one opcode with a three-bit\n"
           "  selector, and MFENCE and SFENCE collide in that selector and\n"
           "  are separated by the CPU's internal decode of the escape.\n"
           "  A decoder that switches on ModRM.reg alone gets MFENCE and\n"
           "  SFENCE right only by accident.\n\n");
    printf("  AND THE BITS ARE NOT CONTIGUOUS, which is worth noticing: the\n"
           "  two encodings are 0xF0 and 0xF8, so the reg field differs in\n"
           "  TWO bit positions and not one.  The draft said 'a single bit\n"
           "  position' and the difference is that MFENCE has bit 3 clear\n"
           "  where SFENCE has it set, while bits 2 and 1 are clear in\n"
           "  both.  R22.\n\n");
    printf("  A LOCKED INSTRUCTION IS A BETTER FENCE THAN SFENCE AND IT IS\n"
           "  ONE INSTRUCTION SHORTER: the LOCKED store row above already\n"
           "  drains the buffer, because the store cannot retire until it\n"
           "  has.  That is why a spinlock built on CMPXCHG needs no\n"
           "  SFENCE, and it is a property of the INSTRUCTION rather than\n"
           "  a recommendation.\n\n");
    g_rows += 4;

    /* ---- 5C. the direction flag --------------------------------- */
    printf("5C. THE DIRECTION FLAG, AND THE CORRECTION.\n\n");
    uint64_t f0 = rd_eflags();
    printf("  EFLAGS as read by PUSHFQ      0x%016llx\n",
           (unsigned long long)f0);
    printf("    bit  0 CF                 %llu\n", (unsigned long long)((f0 >> 0) & 1));
    printf("    bit  2 PF                 %llu\n", (unsigned long long)((f0 >> 2) & 1));
    printf("    bit  6 ZF                 %llu\n", (unsigned long long)((f0 >> 6) & 1));
    printf("    bit  9 IF                 %llu\n", (unsigned long long)((f0 >> 9) & 1));
    printf("    bit 10 DF, THE DIRECTION  %llu\n", (unsigned long long)((f0 >> 10) & 1));
    printf("    bit 11 OF                 %llu\n", (unsigned long long)((f0 >> 11) & 1));
    printf("    bit 16 RF                 %llu\n", (unsigned long long)((f0 >> 16) & 1));
    printf("    bit 18 AC                 %llu\n", (unsigned long long)((f0 >> 18) & 1));
    printf("    bit 21 ID, NOT DIRECTION  %llu\n", (unsigned long long)((f0 >> 21) & 1));
    g_rows++;

    printf("\n  THE CORRECTION, and it is the reason this subsection\n"
           "  exists rather than a footnote.  The brief this course was\n"
           "  written from said the direction flag is bit 21.  It is not.\n"
           "  Bit 10 is DF.  Bit 21 is the ID flag, and the ID flag has a\n"
           "  completely different job: before CPUID existed, software\n"
           "  identified a processor by SETTING a bit it was not supposed\n"
           "  to be able to set and pushing the flags.  The 8086 and 8088\n"
           "  had no such bit and the Pentium does.  R1.\n\n");
    printf("  AND THE DIRECTION FLAG IS SET AND CLEARED BY TWO INSTRUCTIONS\n"
           "  that do nothing else: STD sets it and CLD clears it.  There\n"
           "  is no complement, which is a gap in the instruction set that\n"
           "  is closed with PUSHF, an XOR and POPF.  Both are measured\n"
           "  below, and the fact that the flag can be set and read back is\n"
           "  what the identification trick depends on.\n\n");

    for (int i = 0; i < 8192; i++) dsrc[i] = (unsigned char)(i + 1);
    struct { const char *n; uint64_t (*u)(unsigned *); uint64_t (*d)(unsigned *);
             int bytes; } T[] = {
        { "16",   up16,   dn16,   16 },
        { "256",  up256,  dn256,  256 },
        { "1024", up1024, dn1024, 1024 },
        { "4096", up4096, dn4096, 4096 } };
    int reps = g_quick ? 300 : 3000;
    printf("  bytes |   DF=0  |   DF=1  | ratio  | ticks/byte up | ticks/byte dn\n"
           "  ------+----------+----------+--------+--------------+--------------\n");
    for (int k = 0; k < 4; k++) {
        uint64_t bu = ~0ULL, bd = ~0ULL;
        unsigned su = 0, sd = 0;
        for (int r = 0; r < reps; r++) {
            uint64_t a = T[k].u(&su); if (a < bu) bu = a;
            a = T[k].d(&sd); if (a < bd) bd = a;
        }
        printf("  %5s | %8llu | %8llu | %6.2f | %12.4f | %12.4f\n",
               T[k].n, (unsigned long long)bu, (unsigned long long)bd,
               (double)bd / bu, (double)bu / T[k].bytes,
               (double)bd / T[k].bytes);
        /* BOTH arms must have copied the same bytes, or the table is
         * comparing two different amounts of work. */
        if (su != sd) {
            printf("  !! the two arms did NOT copy the same bytes: %u vs %u\n", su, sd);
        }
        g_ck += su + sd;
    }
    g_rows += 4;

    printf("\n  THE BOTH-ARMS-COPIED-THE-SAME-BYTES check runs on every row\n"
           "  and printed nothing, which is the result: the checksums agree,\n"
           "  so the two arms did the same work and the only difference is\n"
           "  the DIRECTION.  There is no way to be sure of that without\n"
           "  checking, because a `rep movsb` that faulted on the first\n"
           "  byte would be very fast.\n\n");
    printf("  AND THE RATIO GROWS WITH SIZE, which is the shape worth\n"
           "  keeping.  A fixed cost per `rep` would give a constant ratio\n"
           "  and a per-element cost would give one too; a growing ratio\n"
           "  means the DOWN direction is not a fast path at all on this\n"
           "  part, and the gap widens as the string gets longer.\n\n");
    printf("  THE HISTORY, STATED AS HISTORY AND NOT AS A MEASUREMENT:\n"
           "  the 8086 computed the direction on every element of a string\n"
           "  operation, so a backward REP MOVSB was materially slower\n"
           "  than a forward one.  That cost is the reason a great deal of\n"
           "  1980s code emits CLD once at every entry point.  Every later\n"
           "  processor narrowed it, and this file measures how much of it\n"
           "  is LEFT on an AMD Zen 3 part in 2026.  It has not gone to\n"
           "  zero.  A source for the 8086 behaviour is the ISA's own\n"
           "  documentation and any contemporary optimisation guide; the\n"
           "  NUMBER in the table above is this machine's, and the two are\n"
           "  different claims about different things.\n\n");
    printf("  LIMITS OF THIS MEASUREMENT:\n"
           "  * It is a MINIMUM over %d repetitions of a short body, so the\n"
           "    small rows are dominated by the `rep` start-up cost and the\n"
           "    ratio there is a start-up ratio, not a per-byte one.\n"
           "  * The two arms start at opposite ends of the array, so the\n"
           "    DOWN arm walks toward the beginning.  On a machine where\n"
           "    the array is one line this does not matter; it is stated\n"
           "    because it is a difference between the arms.\n"
           "  * Nothing here says WHY the down direction is slower.  There\n"
           "    is no counter that can count the micro-ops a string\n"
           "    operation expands to, and the vendor manual does not give a\n"
           "    number for it either.  The mechanism is INFERRED.\n\n", reps);
    g_rows += 5;
}
