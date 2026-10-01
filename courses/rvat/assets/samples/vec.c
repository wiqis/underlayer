// The vectorised loops, so that "what does the compiler emit" is measured at
// four optimisation levels and with and without `v` in -march.
//
// THREE LOOPS AND THREE DIFFERENT VECTORISATIONS, which is the point: the
// course does not get one example and call it the vector extension.
//
//   vadd_d    a pointwise double add.  The compiler picks LMUL = 2 and emits
//             SEGMENT loads (vl2re64.v), so the register GROUP is visible in
//             the load's nf field rather than in the vsetvli.
//   vsum_d    a double reduction.  A reduction is a DIFFERENT vector problem
//             -- it needs vfredosum.vs and a scalar epilogue -- and it is the
//             row that links out to the neutral reduction lesson.
//   vmul_s8   a signed-byte multiply.  SEW = 8, and this is the row where the
//             element width is not the width of a scalar register at all.
//
// The arguments are all USED in the output, so nothing here can be dead-code
// eliminated and the instruction counts are counts of the loops.

void vadd_d(const double *a, const double *b, double *c, long n) {
    for (long i = 0; i < n; ++i) c[i] = a[i] + b[i];
}

void vsum_d(const double *a, double *out, long n) {
    double s = 0.0;
    for (long i = 0; i < n; ++i) s += a[i];
    *out = s;
}

void vmul_s8(const signed char *a, const signed char *b,
             signed char *c, long n) {
    for (long i = 0; i < n; ++i) c[i] = (signed char)(a[i] * b[i]);
}

// A fourth loop that the compiler does NOT vectorise, on purpose: an integer
// multiply-accumulate over an array of longs with a carry, because a corpus
// that contains only vectorisable loops would let a reader conclude that
// -march=rv64gcv vectorises, and the honest answer is "it vectorises THESE,
// at -O2 and above, and it needs to read the vector length register to know
// how many elements it has".
long vmac_l(const long *a, const long *b, long n) {
    long acc = 0;
    for (long i = 0; i < n; ++i) acc += a[i] * b[i];
    return acc;
}