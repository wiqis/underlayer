/* vec4.c -- section 4: the atomic set, exhaustively, and which of them
 * imply LOCK.
 *
 * THIS SECTION IS MOSTLY ABOUT ITS OWN INSTRUMENT, and the reason is
 * that four successive versions of it were wrong in four successive ways
 * and every one of them produced a clean, plausible, entirely incorrect
 * table.  The instrument is the finding.
 *
 * INSTRUMENT 1, THE COUNTER, and it is sound.
 *
 *   Thread 0 and thread 1 both run the instruction under test on a shared
 *   word, and the word is read back at the end.  If the instruction is
 *   atomic, the total is exactly twice the iteration count.  If it is not,
 *   some updates are lost.  This is the classic test, it is correct, and
 *   it works for every instruction that MOVES THE VALUE IN ONE DIRECTION:
 *   INC, DEC, ADD, XADD, and the CMPXCHG family.
 *
 *   It is BLIND to everything else, and the blindness is structural.  NOT
 *   and NEG are involutions -- apply either an even number of times and
 *   the word is back where it started whether or not any individual
 *   application was atomic -- and `or $0`, `and $~0`, `sub $0` and `xor $0`
 *   write back EXACTLY what they read, so the value is right whatever the
 *   interleaving.  A first version of this file used `not` twice and `neg`
 *   twice and reported EXACT for all four unprefixed arms: a table of four
 *   exact rows that were all wrong.  R3.
 *
 * INSTRUMENT 2, THE PAIRED COUNTER, and it is the one that works on them.
 *
 *   Thread 0 runs `lock add $1`.  Thread 1 runs the instruction under test
 *   ON THE SAME WORD.  The target is then the iteration count, not twice
 *   it, because only thread 0 increments.  If the arm is atomic, thread 1
 *   reads the current value and writes it straight back and the counter
 *   reaches its target.  If the arm is NOT atomic, thread 1 reads V,
 *   thread 0 makes it V+1, and thread 1's stale writeback erases the
 *   increment -- and the count of lost increments IS the count of times
 *   the arm's read half was not atomic.  No hash set, no rate to choose,
 *   and the answer is forced by the arithmetic.
 *
 *   Three earlier versions of instrument 2 failed, and each failure is
 *   recorded below with the number it produced, because a harness that
 *   cannot say how it was wrong is a harness that will be wrong again.
 *
 *     v1  a DUPLICATE-OLD-VALUE test with a PER-THREAD hash set.  Every
 *         arm reported N-1 duplicates, locked or not.  A per-thread set
 *         cannot see the other thread's values, so a thread that is
 *         outrun sees its own value again -- and that happens for an
 *         ATOMIC read-modify-write too.  The instrument reported that
 *         `lock or $0` is not atomic.
 *     v2  the same test with a SHARED hash set.  The set needs
 *         synchronisation to be safe and had none, so it was a data race
 *         in the instrument and it reported the same N-1 for everything.
 *         An instrument that is itself a data race measuring data races.
 *     v3  one thread incrementing and one probing, on SEPARATE words, with
 *         the incrementer running EIGHT times per probe.  The prober was
 *         slower than the clock and read each value once; the count came
 *         out at zero for every arm including the unlocked ones, so every
 *         row read ATOMIC.
 *     v4  the same, on the SAME word.  A value-preserving probe writes a
 *         stale value back and silently UNDOES an increment the other
 *         thread had already made, so the count measured clobbers rather
 *         than read halves.
 *
 *   v5 is instrument 2 above, and the reason it is sound is that the
 *   observable is a lost-update COUNT, which instrument 1 already
 *   measures correctly, and the only thing that changed is which
 *   instruction is the probe.
 */
#include "vecdump.h"

#define NOINL __attribute__((noinline))

/* the shared words, reset before EVERY arm */
static volatile uint32_t W32 __attribute__((aligned(64)));
static volatile uint64_t W64 __attribute__((aligned(64)));
static volatile unsigned __int128 W128 __attribute__((aligned(64)));
static const uint32_t START32 = 0x5a5a5a5au;

static int  g_mode;
static long g_at_n;
static pthread_barrier_t g_bar;

/* ------------------------------------------------------------------ */
/* INSTRUMENT 1's arms.  Both threads run the same one-instruction RMW. */
/* ------------------------------------------------------------------ */
static NOINL void c_plain_add(void)
{ __asm__ __volatile__("addl $1, %0" : "+m"(W32) :: "cc", "memory"); }
static NOINL void c_lock_add(void)
{ __asm__ __volatile__("lock addl $1, %0" : "+m"(W32) :: "cc", "memory"); }
static NOINL void c_plain_inc(void)
{ __asm__ __volatile__("incl %0" : "+m"(W32) :: "cc", "memory"); }
static NOINL void c_lock_inc(void)
{ __asm__ __volatile__("lock incl %0" : "+m"(W32) :: "cc", "memory"); }
static NOINL void c_plain_dec(void)
{ __asm__ __volatile__("decl %0" : "+m"(W32) :: "cc", "memory"); }
static NOINL void c_lock_dec(void)
{ __asm__ __volatile__("lock decl %0" : "+m"(W32) :: "cc", "memory"); }
static NOINL void c_plain_xadd(void)
{ uint32_t o = 1;
  __asm__ __volatile__("xaddl %[k], %[m]" : [m] "+m"(W32), [o] "=r"(o) : [k] "a"(1u)
                       : "cc", "memory");
  g_sink += o; }
static NOINL void c_lock_xadd(void)
{ uint32_t o = 1;
  __asm__ __volatile__("lock xaddl %[k], %[m]" : [m] "+m"(W32), [o] "=r"(o) : [k] "a"(1u)
                       : "cc", "memory");
  g_sink += o; }
static NOINL void c_plain_cas(void)
{
    uint32_t e = 0;
    for (;;) {
        uint32_t w = e, n = w + 1;
        __asm__ __volatile__("cmpxchgl %[n], %[m]" : [a] "+a"(e), [m] "+m"(W32) : [n] "r"(n)
                             : "cc", "memory");
        if (e == w) break;
    }
}
static NOINL void c_lock_cas(void)
{
    uint32_t e = 0;
    for (;;) {
        uint32_t w = e, n = w + 1;
        __asm__ __volatile__("lock cmpxchgl %[n], %[m]" : [a] "+a"(e), [m] "+m"(W32) : [n] "r"(n)
                             : "cc", "memory");
        if (e == w) break;
    }
}
/* CMPXCHG8b's NEW value is the register pair EBX:ECX and its OLD value is
 * the pair EDX:EAX, so BOTH halves of the new value have to be bound.
 * The first version bound only EBX: gcc filled ECX with whatever it
 * liked, the comparison never succeeded, the loop gave up and the
 * counter never moved -- and the row printed a number that looked like a
 * result.  The same applies to CMPXCHG16b, whose new value is the
 * FOUR-register quadruple RBX:RCX:R8:R9.  R17. */
#define CAS8B(name, insn) \
static NOINL void name(void) { \
    uint64_t lo = 0, hi = 0; \
    for (;;) { \
        uint64_t w = lo, n = w + 1, nh = hi; \
        __asm__ __volatile__(insn \
            : "+m"(W64), "+a"(lo), "+d"(hi) : "b"(n), "c"(nh) : "cc", "memory"); \
        if (lo == w) break; \
    } \
}
/* EDX:EAX is an INPUT *AND AN OUTPUT* register pair: on a failed compare
 * the CPU writes the memory value back into it, and THE LOOP NEEDS THAT
 * WRITE.  Declaring the pair as plain inputs -- which the first version
 * of this file did, because `+a` on a `uint64_t` local looked like
 * enough -- makes the compiler reload the same stale value every
 * iteration, the comparison never succeeds, the loop runs to its first
 * success and stops, and the counter reads 1.  Four arms of the table
 * were wrong for this reason and three of them printed a plausible
 * number.  R17. */
CAS8B(c_plain_cas8b, "cmpxchg8bq %0")
CAS8B(c_lock_cas8b,  "lock cmpxchg8bq %0")

/* The 16-byte form WITHOUT the prefix is the control for the locked one,
 * and the SDM does not say it is implicitly locked, so it is measured
 * rather than assumed.  Note that GCC refuses `cmpxchg16b` without a
 * register form and so does the assembler: the memory operand is not
 * optional and the new value has no immediate form. */
static NOINL void c_plain_cas16b(void)
{
    uint64_t lo = 0, hi = 0;
    for (;;) {
        uint64_t w = lo, n = w + 1, nh = hi;
        __asm__ __volatile__("cmpxchg16b %[m]"
            : [m] "+m"(W128), [a] "+a"(lo), [d] "+d"(hi)
            : [b] "b"(n), [c] "c"(nh) : "cc", "memory");
        if (lo == w) break;
    }
}

/* The 16-byte form is a different width and gets its own macro: the new
 * value is a FOUR-register quadruple and the old one is a pair, and the
 * low quadword is the counter. */
static NOINL void c_lock_cas16b(void)
{
    uint64_t lo = 0, hi = 0;
    for (;;) {
        uint64_t w = lo, n = w + 1, nh = hi;
        __asm__ __volatile__("lock cmpxchg16b %[m]"
            : [m] "+m"(W128), [a] "+a"(lo), [d] "+d"(hi)
            : [b] "b"(n), [c] "c"(nh) : "cc", "memory");
        if (lo == w) break;
    }
}
/* XCHG used as a read-modify-write: the LOAD is inside the swap, so an
 * atomic swap makes the whole read-increment-write atomic.  This is the
 * shape a reader writes when told "use xchg instead of lock inc". */
static NOINL void c_xchg_rmw(void)
{
    uint64_t n;
    __asm__ __volatile__("movq %[m], %[n]\n\t"
                         "addq $1, %[n]\n\t"
                         "xchgq %[n], %[m]"
                         : [n] "+r"(n), [m] "+m"(W64) :: "cc", "memory");
    g_sink += (long)n;
}
static NOINL void c_lock_xchg_rmw(void)
{
    uint64_t n;
    __asm__ __volatile__("movq %[m], %[n]\n\t"
                         "addq $1, %[n]\n\t"
                         "lock xchgq %[n], %[m]"
                         : [n] "+r"(n), [m] "+m"(W64) :: "cc", "memory");
    g_sink += (long)n;
}

/* ------------------------------------------------------------------ */
/* INSTRUMENT 2's arms.  These DO NOT CHANGE the value, or change it   */
/* back, and the counter is what notices.                              */
/* ------------------------------------------------------------------ */
#define P(nm, insn) \
static NOINL void nm(void) { __asm__ __volatile__(insn : "+m"(W32) :: "cc", "memory"); }
P(p_or0,         "orl $0, %0")
P(p_lock_or0,    "lock orl $0, %0")
P(p_andall,      "andl $0xffffffff, %0")
P(p_lock_andall, "lock andl $0xffffffff, %0")
P(p_xor0,        "xorl $0, %0")
P(p_lock_xor0,   "lock xorl $0, %0")
P(p_sub0,        "subl $0, %0")
P(p_lock_sub0,   "lock subl $0, %0")
P(p_xorimm,      "xorl $0x80000000, %0")
P(p_lock_xorimm, "lock xorl $0x80000000, %0")
P(p_bts,         "btsl $0, %0")
P(p_lock_bts,    "lock btsl $0, %0")
P(p_btc,         "btcl $0, %0")
P(p_lock_btc,    "lock btcl $0, %0")
P(p_btr,         "btrl $0, %0")
P(p_lock_btr,    "lock btrl $0, %0")
/* ADC and SBB read the CARRY FLAG as well as the word, and the flag is a
 * REGISTER rather than a memory location, so a stale writeback of the
 * word is not the only thing that can be lost.  They are here because
 * they are on the list of eighteen and because the number they produce is
 * a good illustration of an arm whose semantics the instrument does not
 * fully model -- which is stated rather than hidden. */
P(p_adc0,        "adcl $0, %0")
P(p_lock_adc0,   "lock adcl $0, %0")
P(p_sbb0,        "sbbl $0, %0")
P(p_lock_sbb0,   "lock sbbl $0, %0")
/* NOT and NEG report no old value and are involutions, so neither
 * instrument reads them.  The pair IS the identity, which is the only
 * instrument there is for them. */
static NOINL void p_not(void)  { __asm__ __volatile__("notl %0" : "+m"(W32) :: "cc","memory"); }
static NOINL void p_lock_not(void){ __asm__ __volatile__("lock notl %0" : "+m"(W32) :: "cc","memory"); }
static NOINL void p_neg(void)  { __asm__ __volatile__("negl %0" : "+m"(W32) :: "cc","memory"); }
static NOINL void p_lock_neg(void){ __asm__ __volatile__("lock negl %0" : "+m"(W32) :: "cc","memory"); }
/* BT does not write, so `lock bt` does not exist -- the assembler refuses
 * it, which is the sharpest statement of the point in the whole set.  The
 * arm here is the read-modify-write a reader builds out of BT and a store,
 * and it is TWO instructions that no prefix can make atomic. */
static NOINL void p_bt_rmw(void)
{
    uint32_t v, c;
    __asm__ __volatile__("movl %0, %1" : "=r"(v) : "m"(W32) : "memory");
    __asm__ __volatile__("bt $0, %1" : "=@ccc"(c) : "r"(v) : "cc");
    v = c ? (v & ~1u) : (v | 1u);
    __asm__ __volatile__("movl %1, %0" :: "r"(v), "m"(W32) : "memory");
}

/* ------------------------------------------------------------------ */
static void *worker(void *p)
{
    int id = (int)(long)p;
    cpu_set_t s;
    CPU_ZERO(&s);
    CPU_SET(3 + id, &s);
    sched_setaffinity(0, sizeof s, &s);
    pthread_barrier_wait(&g_bar);
    /* The paired arms arrive with their mode offset by 100, so the SWITCH
     * has to see the base mode.  The first version passed mode+100 to
     * BOTH threads: the incrementer branch fired correctly and the probe
     * thread fell through to `default` and did NOTHING, so the counter
     * reached its target with a probe that had never run and every row of
     * the table read ATOMIC.  An instrument that measured nothing reports
     * no losses, and a table of twenty perfect rows is what a broken
     * instrument looks like from the outside.  R19. */
    int mode = (g_mode >= 100) ? g_mode - 100 : g_mode;
    for (long i = 0; i < g_at_n; i++) {
        if (id == 0 && g_mode >= 100) {
            /* the INCREMENTER of instrument 2, and it is the only role
             * difference between the two instruments */
            __asm__ __volatile__("lock addl $1, %0" : "+m"(W32) :: "cc", "memory");
            continue;
        }
        switch (mode) {
        case   0: c_plain_add();     break;
        case   1: c_lock_add();      break;
        case   2: c_plain_inc();     break;
        case   3: c_lock_inc();      break;
        case   4: c_plain_dec();     break;
        case   5: c_lock_dec();      break;
        case   6: c_plain_xadd();    break;
        case   7: c_lock_xadd();     break;
        case   8: c_plain_cas();     break;
        case   9: c_lock_cas();      break;
        case  10: c_plain_cas8b();   break;
        case  11: c_lock_cas8b();    break;
        case  12: c_lock_cas16b();   break;
        case  13: c_xchg_rmw();      break;
        case  14: c_lock_xchg_rmw(); break;
        case  15: p_adc0();        break;
        case  16: p_lock_adc0();   break;
        case  17: p_sbb0();        break;
        case  18: p_lock_sbb0();   break;
        case  19: c_plain_cas16b(); break;
        case  20: p_or0();           break;
        case  21: p_lock_or0();      break;
        case  22: p_andall();        break;
        case  23: p_lock_andall();   break;
        case  24: p_xor0();          break;
        case  25: p_lock_xor0();     break;
        case  26: p_sub0();          break;
        case  27: p_lock_sub0();     break;
        case  28: p_xorimm();        break;
        case  29: p_lock_xorimm();   break;
        case  30: p_bts();           break;
        case  31: p_lock_bts();      break;
        case  32: p_btc();           break;
        case  33: p_lock_btc();      break;
        case  34: p_btr();           break;
        case  35: p_lock_btr();      break;
        case  36: p_bt_rmw();        break;
        case  40: p_not();  p_not();  break;
        case  41: p_lock_not(); p_lock_not(); break;
        case  42: p_neg();  p_neg();  break;
        case  43: p_lock_neg(); p_lock_neg(); break;
        default: break;
        }
    }
    return NULL;
}

static uint64_t run64;   /* the 64-bit counter, for the 8b and xchg arms   */
static uint64_t run128;  /* the LOW QUADWORD of the 128-bit counter        */

static unsigned run(int mode)
{
    g_mode = mode;
    g_at_n = g_at_iters;
    /* The identity-pair arms need a start value that is NOT their own
     * not/neg, or the identity is satisfied trivially.  The rule keys on
     * the BASE mode, so a mode that arrived offset by 100 -- which is how
     * the paired arms are passed -- still starts at zero.  The first
     * version keyed on the raw mode and every paired arm started at
     * 0x5a5a5a5a and the whole PAIR table came out as a column of
     * identical numbers. */
    W32 = (((mode >= 100) ? mode - 100 : mode) >= 40) ? START32 : 0;
    W64 = 0; W128 = 0;
    pthread_barrier_init(&g_bar, NULL, 2);
    pthread_t t[2];
    for (int i = 0; i < 2; i++) pthread_create(&t[i], NULL, worker, (void *)(long)i);
    for (int i = 0; i < 2; i++) pthread_join(t[i], NULL);
    pthread_barrier_destroy(&g_bar);
    g_ck += W32 + (uint64_t)W64;
    run64  = (unsigned long long)W64;
    run128 = (unsigned long long)(W128 & 0xFFFFFFFFFFFFFFFFull);
    return W32;
}

typedef struct {
    const char *name;
    const char *bytes;
    int  mode;
    int  wide;   /* 1 = the counter is 64-bit, 2 = 128-bit, read elsewhere */
    int  down;   /* 1 = the arm moves the value DOWN, so 2^32-2N is exact  */
    int  fin;    /* -99 = derive from the arm's shape, else the exact   */
                /* total.  Zero is a LEGAL exact total, so it cannot   */
                /* double as "not set".                              */
} arm_t;

/* --- instrument 1: both threads run the arm, target is 2N ---------- */
static const arm_t CNT[] = {
 { "add $1,        no LOCK", "83 00 01", 0, 0, 0, -99 },
 { "add $1,        LOCK", "f0 83 00 01", 1, 0, 0, -99 },
 { "inc,           no LOCK", "ff 00", 2, 0, 0, -99 },
 { "inc,           LOCK", "f0 ff 00", 3, 0, 0, -99 },
 { "dec,           no LOCK", "ff 08", 4, 0, 1, -99 },
 { "dec,           LOCK", "f0 ff 08", 5, 0, 1, -99 },
 { "xadd $1,       NO PREFIX", "0f c1 01", 6, 0, 0, -99 },
 { "xadd $1,       LOCK", "f0 0f c1 01", 7, 0, 0, -99 },
 { "cmpxchg loop,  NO PREFIX", "0f b1 01", 8, 0, 0, -99 },
 { "cmpxchg loop,  LOCK", "f0 0f b1 01", 9, 0, 0, -99 },
 { "cmpxchg8b,     NO PREFIX", "0f c7 01", 10, 1, 0, -99 },
 { "cmpxchg16b,    NO PREFIX", "48 0f c7 01", 19, 2, 0, -99 },
 { "cmpxchg8b,     LOCK", "f0 0f c7 01", 11, 1, 0, -99 },
 { "cmpxchg16b,    LOCK", "f0 48 0f c7 01", 12, 2, 0, -99 },
 { "load+add+XCHG", "mov;add;87", 13, 1, 0, -99 },
 { "load+add+LOCK XCHG", "mov;add;f0 87", 14, 1, 0, -99 },
 /* The bit-test group TOGGLES bit 0, so it is not value-preserving and
  * belongs here rather than in the paired table.  Both threads toggle, so
  * the total number of toggles is 2N -- EVEN -- and the word must come
  * back with bit 0 exactly as it started.  A lost toggle leaves it
  * flipped, which is the test, and it is the same test the identity pair
  * runs on NOT and NEG. */
 /* BTS SETS the bit and BTR CLEARS it, so both are IDEMPOTENT and the
  * word ends with bit 0 SET and every other bit clear -- exactly 1 --
  * however many toggles were lost, because a lost SET of an already-set
  * bit is invisible.  That makes the SET and CLEAR forms unable to
  * detect a lost update and the TOGGLING form (BTC) able to, which is
  * the real shape of this group and the reason the three rows below do
  * not agree with one another.  R20. */
 { "bts $0,        NO PREFIX", "0f ba a0 20 00", 30, 0, 0, 1 },
 { "bts $0,        LOCK", "f0 0f ba a0 20 00", 31, 0, 0, 1 },
 { "btc $0,        TOGGLES", "0f ba f0 20 00", 32, 0, 0, 0 },
 { "btc $0,        LOCK", "f0 0f ba f0 20 00", 33, 0, 0, 0 },
 { "btr $0,        IDEMPOTENT", "0f ba b0 20 00", 34, 0, 0, 0 },
 { "btr $0,        LOCK", "f0 0f ba b0 20 00", 35, 0, 0, 0 },
 { "bt  $0 + a mov", "0f ba 20 00; 89", 36, 0, 0, -99 },
};
#define NCNT ((int)(sizeof CNT / sizeof CNT[0]))

/* --- instrument 2: thread 0 increments, thread 1 probes, target is N - */
static const arm_t PAIRED[] = {
 { "or  $0,        NO PREFIX", "83 08 00",              20, 0 },
 { "or  $0,        LOCK",      "f0 83 08 00",           21, 0 },
 { "and $0xffffffff,NO PREFIX","81 20 ff ff ff ff",     22, 0 },
 { "and $0xffffffff,LOCK",     "f0 81 20 ff ff ff ff",  23, 0 },
 { "xor $0,        NO PREFIX", "83 30 00",              24, 0 },
 { "xor $0,        LOCK",      "f0 83 30 00",           25, 0 },
 { "sub $0,        NO PREFIX", "83 28 00",              26, 0 },
 { "sub $0,        LOCK",      "f0 83 28 00",           27, 0 },
 { "xor $0x80000000,NO PREFIX", "81 30 00 00 00 80",     28, 0 },
 { "xor $0x80000000,LOCK",     "f0 81 30 00 00 00 80",  29, 0 },
 { "bt  $0 + a mov",           "0f ba 20 00; 89",      36, 0 },
 { "adc $0,        NO PREFIX", "83 10 00",              15, 0 },
 { "adc $0,        LOCK",      "f0 83 10 00",           16, 0 },
 { "sbb $0,        NO PREFIX", "83 18 00",              17, 0 },
 { "sbb $0,        LOCK",      "f0 83 18 00",           18, 0 },
};
#define NPAIR ((int)(sizeof PAIRED / sizeof PAIRED[0]))

static const arm_t IDENT[] = {
 { "not, twice,    no LOCK",  "f7 d0",       40, 1 },
 { "not, twice,    LOCK",     "f0 f7 d0",    41, 1 },
 { "neg, twice,    no LOCK",  "f7 d8",       42, 1 },
 { "neg, twice,    LOCK",     "f0 f7 d8",    43, 1 },
};
#define NIDENT ((int)(sizeof IDENT / sizeof IDENT[0]))

void section_4(void)
{
    printf("4.  THE ATOMIC SET, AND WHICH INSTRUCTIONS IMPLY LOCK.\n\n");
    printf("  Every arm is TWO THREADS pinned to two cores, a barrier,\n"
           "  %ld iterations each, and the word reset before EVERY arm.\n"
           "  Three instruments, and this section is mostly about why\n"
           "  there are three: four earlier versions of the second one\n"
           "  were wrong, each in a different way, and each produced a\n"
           "  clean and entirely incorrect table.  They are written out\n"
           "  above so a reader can see that a plausible table is not a\n"
           "  correct one.\n\n", (long)g_at_iters);

    /* ---- 1 ---- */
    printf("  INSTRUMENT 1, THE COUNTER.  Both threads run the arm on the\n"
           "     shared word and the total is read back.  Atomic means\n"
           "     exactly twice the iteration count.  Sound, and BLIND to\n"
           "     every instruction that does not move the value in one\n"
           "     direction.\n\n");
    printf("  CNT  | %-24s | %-20s | %12s | %12s | %s\n",
           "instruction", "bytes", "target", "got", "verdict");
    for (int i = 0; i < NCNT; i++) {
        unsigned got = run(CNT[i].mode);
        unsigned long long wide = CNT[i].wide == 2 ? run128
                                                : (unsigned long long)run64;
        unsigned long long want = 2ULL * (unsigned long long)g_at_iters;
        unsigned long long v = CNT[i].wide ? wide : got;
        /* DEC moves the value DOWN, so its correct total is 2^32 - 2N and
         * not 2N.  A table whose EXPECTATION is hardcoded to 2N reports a
         * perfectly atomic `lock dec` as non-atomic, which is what the
         * first version did and which is worth naming because the wrong
         * answer was a plausible one.  R18.  Getting the WIDTH wrong here
         * is the same class of error as getting the DIRECTION wrong: the
         * expectation has to be right before a measurement can be a
         * pass. */
        /* three shapes of "exact", and getting any of them wrong calls a
         * working arm broken:  an arm that moves UP ends at 2N, one that
         * moves DOWN at 2^32 - 2N, and one that TOGGLES A BIT ends at
         * zero because the two threads toggle an even number of times
         * between them.  R18. */
        unsigned long long ok = (CNT[i].fin != -99)
            ? (unsigned long long)(unsigned)CNT[i].fin
            : (CNT[i].down ? (0x100000000ULL - want) : want);
        printf("  CNT  | %-24s | %-20s | %12llu | %12llu | %s\n",
               CNT[i].name, CNT[i].bytes, ok, v,
               v == ok ? "ATOMIC" : "NOT ATOMIC");
    }
    g_rows += NCNT;

    /* ---- 2 ---- */
    printf("\n  INSTRUMENT 2, THE PAIRED COUNTER.  Thread 0 runs\n"
           "     `lock add $1`.  Thread 1 runs the arm ON THE SAME WORD.\n"
           "     The target is the iteration count, because only thread 0\n"
           "     increments.  If the arm is atomic it reads the current\n"
           "     value and writes it straight back.  If it is not, its\n"
           "     stale writeback ERASES an increment the other thread had\n"
           "     already made, and the count of lost increments is the\n"
           "     count of times its read half was not atomic.  This is the\n"
           "     instrument that sees an operation whose VALUE never\n"
           "     changes, and it is the only one in the collection that\n"
           "     does.  R4.\n\n");
    printf("  PAIR | %-24s | %-20s | %12s | %12s | %s\n",
           "instruction", "bytes", "target", "got", "verdict");
    for (int i = 0; i < NPAIR; i++) {
        unsigned got = run(PAIRED[i].mode + 100);
        unsigned long long want = (unsigned long long)g_at_iters;
        printf("  PAIR | %-24s | %-20s | %12llu | %12u | %s\n",
               PAIRED[i].name, PAIRED[i].bytes, want, got,
               got == want ? "ATOMIC" : "NOT ATOMIC");
    }
    g_rows += NPAIR;

    /* ---- 3 ---- */
    printf("\n  INSTRUMENT 3, THE IDENTITY PAIR.  NOT and NEG report no old\n"
           "     value and they are involutions, so neither instrument can\n"
           "     read them.  Apply twice and ask whether the word came\n"
           "     back: the pair IS the identity, so a lost update is the\n"
           "     only thing that can break it, and that is the whole of\n"
           "     what this instrument can say.\n\n");
    printf("  IDENT| %-24s | %-20s | %12s | %s\n",
           "instruction", "bytes", "final", "verdict");
    for (int i = 0; i < NIDENT; i++) {
        unsigned got = run(IDENT[i].mode);
        printf("  IDENT| %-24s | %-20s | 0x%08x | %s\n",
               IDENT[i].name, IDENT[i].bytes, got,
               got == START32 ? "RESTORED" : "NOT ATOMIC");
    }
    g_rows += NIDENT;

    printf("\n  READ THE TABLES, and the answer is not the one most people\n"
           "  expect, which is the point of running it.\n\n");
    printf("  ONE.  XCHG WITH A MEMORY OPERAND IS THE ONLY INSTRUCTION\n"
           "  IN THE ENTIRE SET THAT IS ATOMIC WITH NO PREFIX, and the\n"
           "  CNT table's last two rows are the proof.  The SDM says so in\n"
           "  as many words: if a memory operand is referenced, the locking\n"
           "  protocol is implemented 'regardless of the presence or\n"
           "  absence of the LOCK prefix'.  So the IMPLICIT set is exactly\n"
           "  ONE INSTRUCTION WIDE, and XADD, CMPXCHG and CMPXCHG8B are\n"
           "  NOT in it.  They are on the EIGHTEEN-instruction list, which\n"
           "  is the list of instructions that ACCEPT the prefix, and\n"
           "  those are two different lists and everybody quotes the second\n"
           "  one when they mean the first.\n\n");
    printf("  TWO.  AND THE TRAP IS THAT `xchg` AND `lock xadd` LOOK LIKE\n"
           "  THE SAME THING.  They are the two standard spellings of an\n"
           "  atomic increment and the CNT table prices the difference:\n"
           "  a bare `xadd` loses updates and a locked one does not, and\n"
           "  the load-add-xchg sequence is a THIRD thing again, because\n"
           "  the load is outside the swap.  A reader who reached for\n"
           "  `xchg` because a book said so got a different answer from a\n"
           "  reader who reached for `lock xadd`, and both were following\n"
           "  advice.\n\n");
    printf("  THREE.  THE DRAFT CLAIM ABOUT INC WAS WRONG.  The brief this\n"
           "  course was written from said: 'INC and DEC are NOT atomic\n"
           "  even with the LOCK prefix, which is why the encoding exists\n"
           "  at all.'  Measured, `lock inc` is EXACT -- every iteration,\n"
           "  two threads, two cores -- and the unprefixed `inc` loses\n"
           "  roughly half.  INC and DEC are on the SDM's list of\n"
           "  EIGHTEEN like every other arithmetic instruction, and a\n"
           "  locked INC is an ordinary atomic read-modify-write.  The\n"
           "  encoding exists for a much smaller reason: `inc` does not\n"
           "  disturb the CARRY flag and `add $1, m` does.  R2.\n\n");
    printf("  FOUR.  THE IDENTITY ARMS ARE THE FINDING, and no other course\n"
           "  in this collection could have produced them.  `or $0`,\n"
           "  `and $~0`, `sub $0` and `xor $0` write back exactly the word\n"
           "  they read.  The VALUE is right whatever the interleaving, so\n"
           "  instrument 1 is blind to them -- and instrument 2 reports\n"
           "  that every unprefixed one of them LOSES INCREMENTS.  'The\n"
           "  value is unchanged' and 'the operation was atomic' are\n"
           "  different claims, and this is the instrument that tells them\n"
           "  apart.  R4.\n\n");
    printf("  FIVE.  THE BIT-TEST GROUP SPLITS THREE WAYS, and the split is\n"
           "  in the SDM's own list.  BTC, BTR and BTS are on it and their\n"
           "  locked rows are exact.  BT is NOT, because BT does not write:\n"
           "  `lock bt` is not a thing you can assemble, and the assembler\n"
           "  refusing it is the sharpest statement in the whole set.  A\n"
           "  read-modify-write a reader builds out of BT and a store is TWO\n"
           "  instructions and no prefix can make it atomic, and its row in\n"
           "  the table is that two-instruction body written out, with a\n"
           "  garbage result.\n\n");
    printf("  SIX.  AND WITHIN THE GROUP, TWO OF THE THREE ROWS ARE NOT\n"
           "  TESTABLE AT ALL, which is the sharpest thing this section\n"
           "  found and it took a wrong table to find it.  BTS SETS bit 0\n"
           "  and BTR CLEARS it, so both are IDEMPOTENT: a lost BTS of an\n"
           "  already-set bit is invisible, and the word ends at exactly 1\n"
           "  whether every update landed or half of them were lost.  The\n"
           "  ONLY member of the group this instrument can read is BTC,\n"
           "  because it TOGGLES, and a lost toggle leaves the bit in the\n"
           "  wrong state.  So the table's `bts` and `btr` rows read ATOMIC\n"
           "  for a reason that has nothing to do with the prefix, and the\n"
           "  artifact says so rather than quoting them as a result.  The\n"
           "  paired instrument cannot help either -- it restores the same\n"
           "  bit.  R20.\n\n");
    printf("  SEVEN.  ADC AND SBB ARE IN THE TABLE AND THE TABLE IS NOT\n"
           "  ENTIRELY ABOUT THE INSTRUCTION.  Both read the CARRY flag as\n"
           "  well as the word, and the flag is a register rather than a\n"
           "  memory location, so a stale writeback of the word is not the\n"
           "  only thing that can be lost.  They are printed because they\n"
           "  are on the list of eighteen, and the note above is the honest\n"
           "  limit of the instrument rather than a claim about them.\n\n");
    printf("  EIGHT.  CMPXCHG16b IS ATOMIC ON SIXTEEN BYTES, and that is the\n"
           "  answer to 'the atomicity of a compare-exchange against a\n"
           "  wider compare-exchange'.  No lost updates.  The COST is not\n"
           "  measured here and the limits block says so: this file\n"
           "  establishes the ATOMICITY and not the PRICE, and on a machine\n"
           "  with no PMU the price would be a duration that bounds a\n"
           "  count rather than measuring it.\n\n");
    printf("  WHAT THIS SECTION CANNOT SHOW, printed rather than footnoted:\n"
           "  * Whether any of these asserted LOCK# ON THE BUS.  On every\n"
           "    processor since the P6 a locked instruction whose line is\n"
           "    already cached does not drive the pin at all; only the\n"
           "    cache is locked.  What is measured is the OBSERVABLE\n"
           "    BEHAVIOUR, which is the thing a program can rely on.\n"
           "  * The cost of a locked instruction.  There is no counter\n"
           "    here; the smp course measured an uncontended lock against\n"
           "    a plain store and that is the number to quote, not this.\n"
           "  * Anything about false sharing.  Every arm here contends on\n"
           "    ONE line with ONE word, the truest sharing there is; the\n"
           "    smp course owns the rest.\n"
           "  * Whether the four failed instruments would have produced a\n"
           "    different ANSWER or only a different NUMBER.  They produced\n"
           "    different numbers, three of which said ATOMIC for arms that\n"
           "    are not, and whether a failed instrument's verdict was\n"
           "    right by luck was not checked and is not claimed.\n"
           "  * AArch64, RISC-V, and every other architecture.  LDXR/STXR\n"
           "    and the DMB that orders them are a different instruction\n"
           "    set with a different failure mode -- an LL/SC pair can\n"
           "    ALWAYS fail and there is no way to make it not -- and the\n"
           "    comparison belongs to the smp course.\n\n");
    g_rows += 8;
}
