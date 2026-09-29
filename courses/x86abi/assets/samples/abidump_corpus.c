/* abidump_corpus.c -- the corpus the audit in abidump.c section 2 reads.
 *
 * Two things make this corpus measure the ABI rather than the optimiser's
 * mood, and both were learned by getting them wrong first:
 *
 *   NOIPA, NOT NOINLINE.  `noinline` stops the inliner and nothing else.
 *   With only `noinline`, gcc at -O2 constant-folded every f1..f8 in the first
 *   draft of this file -- the bodies are pure, so the calls simply vanished
 *   and `call_each` became a run of `mov $0x7,%edi; call abi_sink`.  The
 *   register assignment was no longer in the program at all.  `noipa` adds
 *   `noipa` = no interprocedural analysis of any kind, which is what a
 *   black-box ABI corpus needs.
 *
 *   VOLATILE ARGUMENT SOURCES.  Even with noipa, gcc knows the VALUE of every
 *   argument in `call_each`, and it will propagate it.  The sources are
 *   `volatile` globals so the register each argument lands in is a fact about
 *   the emitted code.
 *
 * Every parameter is forced into a register by an empty asm that NAMES it, so
 * that "which register is argument three in" is a question with an answer
 * rather than a question about dead code.
 */
extern void abi_sink(long);
extern void abi_sinkd(double);

#define NI __attribute__((noinline, noipa))
#define USE1(x)  __asm__ __volatile__("" :: "r"(x))
#define USEF(x)  __asm__ __volatile__("" :: "x"(x))

volatile long v11 = 0x11, v12 = 0x12, v13 = 0x13, v14 = 0x14;
volatile long v15 = 0x15, v16 = 0x16, v17 = 0x17, v18 = 0x18;
volatile long v21 = 0x21, v22 = 0x22, v23 = 0x23, v24 = 0x24;
volatile long v31 = 0x31, v32 = 0x32;
volatile double w1 = 1.0, w2 = 2.0, w3 = 3.0, w4 = 4.0;
volatile double w5 = 5.0, w6 = 6.0, w7 = 7.0, w8 = 8.0, w9 = 9.0;

/* ---- the integer sequence, one function per arity ---------------- */
NI int f0(void) { return 7; }
NI int f1(long a) { USE1(a); abi_sink(a); return 1; }
NI int f2(long a, long b) { USE1(a); USE1(b); abi_sink(a + b); return 2; }
NI int f3(long a, long b, long c) { USE1(a); USE1(b); USE1(c); abi_sink(a + b + c); return 3; }
NI int f4(long a, long b, long c, long d) { USE1(a); USE1(b); USE1(d); abi_sink(a + b + c + d); return 4; }
NI int f5(long a, long b, long c, long d, long e) { USE1(a); USE1(b); USE1(c); USE1(d); USE1(e); abi_sink(a + b + c + d + e); return 5; }
NI int f6(long a, long b, long c, long d, long e, long g) { USE1(a); USE1(b); USE1(c); USE1(d); USE1(e); USE1(g); abi_sink(a + b + c + d + e + g); return 6; }
NI int f7(long a, long b, long c, long d, long e, long g, long h) { USE1(a); USE1(b); USE1(c); USE1(d); USE1(e); USE1(g); USE1(h); abi_sink(a + b + c + d + e + g + h); return 7; }
NI int f8(long a, long b, long c, long d, long e, long g, long h, long i) { USE1(a); USE1(b); USE1(c); USE1(d); USE1(e); USE1(g); USE1(h); USE1(i); abi_sink(a + b + c + d + e + g + h + i); return 8; }

/* ---- the SSE sequence -------------------------------------------- */
NI int g1(double a) { USEF(a); abi_sinkd(a); return 1; }
NI int g2(double a, double b) { USEF(a); USEF(b); abi_sinkd(a + b); return 2; }
NI int g8(double a, double b, double c, double d,
          double e, double f, double g, double h) {
    USEF(a); USEF(b); USEF(c); USEF(d); USEF(e); USEF(f); USEF(g); USEF(h);
    abi_sinkd(a + b + c + d + e + f + g + h);
    return 8;
}
NI int g9(double a, double b, double c, double d, double e,
          double f, double g, double h, double i) {
    USEF(a); USEF(b); USEF(c); USEF(d); USEF(e); USEF(f); USEF(g); USEF(h); USEF(i);
    abi_sinkd(a + b + c + d + e + f + g + h + i);
    return 9;
}

/* THE TWO SEQUENCES ARE INDEPENDENT.  Four doubles and four longs, and the
 * longs still begin at %rdi.  The first draft of this file was written on the
 * belief that the two sequences share one index, and the belief is the reason
 * this function exists. */
NI int mx(double d1, long i1, double d2, long i2,
          double d3, long i3, double d4, long i4) {
    USEF(d1); USEF(d2); USEF(d3); USEF(d4);
    USE1(i1); USE1(i2); USE1(i3); USE1(i4);
    abi_sinkd(d1 + d2 + d3 + d4);
    abi_sink(i1 + i2 + i3 + i4);
    return 0;
}

/* ---- the return value -------------------------------------------- */
NI long r2(long a, long b) { USE1(a); USE1(b); return a * 3 + b; }
NI double r2d(double a, double b) { USEF(a); USEF(b); return a * 3.0 + b; }

/* ---- THE CALLERS.  ONE FUNCTION PER CALLEE, and that is not tidiness.
 *
 * The first version had a single `call_each` with seventeen calls in it, and
 * the audit had to work out which call site was which by COUNTING, because a
 * call to `abi_sink` is a relocation and objdump cannot name it.  Counting
 * worked and was wrong in the way counting always is: it assumed gcc kept the
 * calls in source order, and an assumption about the optimiser inside the
 * instrument that is supposed to be auditing the optimiser.  One function per
 * call site removes the assumption entirely, and `call c_f4` is a call to a
 * symbol objdump CAN name.
 *
 * Each source is a distinct `volatile` global, so the disassembly identifies
 * which ARGUMENT is in which register rather than merely which registers are
 * occupied.  That is the difference between a census and an audit. --------- */
NI void c_f0(void) { abi_sink(f0()); }
NI void c_f1(void) { abi_sink(f1(v11)); }
NI void c_f2(void) { abi_sink(f2(v11, v12)); }
NI void c_f3(void) { abi_sink(f3(v11, v12, v13)); }
NI void c_f4(void) { abi_sink(f4(v11, v12, v13, v14)); }
NI void c_f5(void) { abi_sink(f5(v11, v12, v13, v14, v15)); }
NI void c_f6(void) { abi_sink(f6(v11, v12, v13, v14, v15, v16)); }
NI void c_f7(void) { abi_sink(f7(v11, v12, v13, v14, v15, v16, v17)); }
NI void c_f8(void) { abi_sink(f8(v11, v12, v13, v14, v15, v16, v17, v18)); }
NI void c_g1(void) { abi_sink(g1(w1)); }
NI void c_g2(void) { abi_sink(g2(w1, w2)); }
NI void c_g8(void) { abi_sink(g8(w1, w2, w3, w4, w5, w6, w7, w8)); }
NI void c_g9(void) { abi_sink(g9(w1, w2, w3, w4, w5, w6, w7, w8, w9)); }
NI void c_mx(void) { abi_sink(mx(w1, v21, w2, v22, w3, v23, w4, v24)); }
NI void c_r2(void) { abi_sink(r2(v31, v32)); }
NI void c_r2d(void) { abi_sink((long)r2d(w1, w2)); }

/* ---- a function that forces gcc to use %rbp as a general register, so the
 *      audit can see that -O2 uses a callee-saved register as scratch and
 *      STILL pushes it, which is the rule holding. ---------------------- */
volatile long va[8];
NI long rbp_pressure(long k) {
    USE1(k);
    abi_sink(va[0]); abi_sink(va[1]); abi_sink(va[2]); abi_sink(va[3]);
    abi_sink(va[4]); abi_sink(va[5]); abi_sink(va[6]); abi_sink(va[7]);
    return va[0] + va[1] + va[2] + va[3] + va[4] + va[5] + va[6] + va[7] + k;
}
