/* data.c -- the corpus for "The AArch64 Data Path: NEON, Atomics and Ordering".
 *
 * Same rule the two earlier courses in this section use, and for the same
 * reason: there is no AArch64 sysroot on this host, so nothing here may
 * include a header.  `unsigned long` is spelled out and every global is
 * `volatile` so that a read cannot be deleted and a write cannot be dead.
 *
 * Compiled at -O0, -O1, -O2, -Os and, for the two files that matter, with and
 * without `-march=armv8.1-a`.  The compiler is the TEST SUBJECT: every count
 * in the course is a fact about clang 21.1.8 at one optimisation level, and
 * the harness asserts the SHAPE of those counts, never the values.
 *
 * THERE ARE NO TIMINGS IN THIS COURSE.  There is no AArch64 machine, no
 * emulator and no linker on this host, so not one instruction below has been
 * run.  The sibling x86-64 course measured 4.92x for a syscall and 27.65x for
 * a mode change; nothing here has a counterpart and nothing here fakes one.
 */

/* ===================================================================
 * 1.  THE VECTOR REGISTER FILE, as the compiler sees it.  The same C
 *     twice: once the vectoriser is free and once it is not.  The
 *     comparison the course reports is an INSTRUCTION COUNT and the
 *     section that prints it says so in the same words.
 * =================================================================== */

long sum_loop(const long *a, long n) {
    long s = 0;
    for (long i = 0; i < n; i++) s += a[i];
    return s;
}

long max_loop(const long *a, long n) {
    long m = a[0];
    for (long i = 1; i < n; i++) if (a[i] > m) m = a[i];
    return m;
}

void axpy_loop(long *y, const long *a, long n) {
    for (long i = 0; i < n; i++) y[i] = a[i] * 3 + 1;
}

void copy_loop(long *d, const long *s, long n) {
    for (long i = 0; i < n; i++) d[i] = s[i];
}

/* a FLOAT loop, because the scalar and vector register files are separate
 * and a 64-bit integer loop never has to touch a `v` register at all */
float fsum_loop(const float *a, long n) {
    float s = 0.0f;
    for (long i = 0; i < n; i++) s += a[i];
    return s;
}

/* an integer add on bytes, which is where the 16-byte view is the only one
 * that works and the 8-byte view is refused by the compiler itself */
void sadd(unsigned char *d, const unsigned char *a, const unsigned char *b, long n) {
    for (long i = 0; i < n; i++) d[i] = a[i] + b[i];
}

/* ===================================================================
 * 2.  THE EXCLUSIVE MONITOR, as the compiler emits it.  Every
 *     `__atomic_*` below is a case the C standard already fixed; the
 *     course claims nothing about C and everything about what clang
 *     chose.
 * =================================================================== */

unsigned long inc_seq(unsigned long *p)    { return __atomic_fetch_add(p, 1, 5); }
unsigned long inc_acq(unsigned long *p)    { return __atomic_fetch_add(p, 1, 2); }
unsigned long inc_rel(unsigned long *p)    { return __atomic_fetch_add(p, 1, 3); }
unsigned long inc_relaxed(unsigned long *p) { return __atomic_fetch_add(p, 1, 0); }
unsigned long xchg_seq(unsigned long *p, unsigned long v) { return __atomic_exchange_n(p, v, 5); }
unsigned long xchg_acqrel(unsigned long *p, unsigned long v) { return __atomic_exchange_n(p, v, 4); }

int cas64(unsigned long *p, unsigned long *e, unsigned long d) {
    return __atomic_compare_exchange_n(p, e, d, 0, 5, 5);
}

/* ===================================================================
 * 3.  ORDERING AS ACCESS MODES.  The four cases a reader would guess are
 *     four different instructions, and the barrier census in section 9
 *     is the number that decides the concept.
 * =================================================================== */

unsigned long load_acq(unsigned long *p)     { return __atomic_load_n(p, 2); }
unsigned long load_seqcst(unsigned long *p)  { return __atomic_load_n(p, 5); }
void store_rel(unsigned long *p, unsigned long v)      { __atomic_store_n(p, v, 3); }
void store_seqcst(unsigned long *p, unsigned long v)   { __atomic_store_n(p, v, 5); }
void fence_seqcst(void)  { __atomic_thread_fence(5); }
void fence_acquire(void) { __atomic_thread_fence(2); }
void fence_release(void) { __atomic_thread_fence(3); }
void fence_relaxed(void) { __atomic_thread_fence(0); }

unsigned long load_then_load(unsigned long *p, unsigned long *q) {
    unsigned long a = __atomic_load_n(p, 5);
    unsigned long b = __atomic_load_n(q, 5);
    return a + b;
}
void store_then_store(unsigned long *p, unsigned long *q,
                      unsigned long a, unsigned long b) {
    __atomic_store_n(p, a, 5);
    __atomic_store_n(q, b, 5);
}

typedef struct { unsigned long count, payload; } cell;
unsigned long bump(cell *c) { return __atomic_fetch_add(&c->count, 1, 5); }
void publish(cell *c, unsigned long v) {
    c->payload = v;
    __atomic_store_n(&c->count, 1, 5);
}
