/* pair.c -- the 16-byte case, and the reason it is in its own file.
 *
 * A 128-bit atomic needs a PAIR of exclusive instructions (`ldaxp`/`stlxp`)
 * at baseline and `casp`/`caspal` when FEAT_LSE is available, and the two
 * encodings are in different places in the 32-bit word -- different op0, a
 * different CRn, and a 128-bit memory operand in a machine whose instructions
 * are 32 bits wide.  It gets its own file because the warning clang prints
 * about the alignment is part of the measurement, and a warning printed once
 * per file is a warning about the file.
 *
 * The alignment attribute is LOad-bearing and this comment says so: without
 * `aligned(16)` clang emits a libatomic CALL instead of a `casp`, at BOTH
 * `-march` levels, and the first run of this file reported a library call
 * where the course wanted an instruction.
 */
typedef unsigned long u64;
typedef struct { u64 a, b; } __attribute__((aligned(16))) pair;

int cas_pair_seqcst(pair *p, pair *e, pair *d) {
    return __atomic_compare_exchange(p, e, d, 0, 5, 5);
}
int cas_pair_relaxed(pair *p, pair *e, pair *d) {
    return __atomic_compare_exchange(p, e, d, 1, 0, 0);
}
int cas_pair_acqrel(pair *p, pair *e, pair *d) {
    return __atomic_compare_exchange(p, e, d, 0, 4, 2);
}

/* there is no 128-bit LSE arithmetic, and this function is how the course
 * finds that out: it is two 64-bit `ldaddal`s, not one instruction */
pair pair_fetch_add(pair *p, u64 d) {
    u64 a = __atomic_fetch_add(&p->a, d, 5);
    u64 b = __atomic_fetch_add(&p->b, d, 5);
    pair r = {a, b};
    return r;
}
