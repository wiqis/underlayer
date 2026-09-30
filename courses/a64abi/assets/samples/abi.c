/* abi.c -- the corpus for "The AArch64 Procedure Call Standard".
 *
 * One rule shapes every line: every ARGUMENT arrives in its own `volatile`
 * global with its own immediate offset, and every RESULT leaves in its own
 * `volatile` global.  A volatile read cannot be deleted and a volatile write
 * cannot be dead, so the call survives optimisation and the disassembly
 * NAMES which argument went where -- `#8k` means argument k.  A census would
 * say "eight registers were written"; an audit says *which argument was in
 * which register, by name*, and can therefore disagree with the
 * specification instead of merely agreeing with itself.
 *
 * Compiled four ways: -O0, -O1, -O2, -Os.  Same source, same registers, four
 * different amounts of care.
 */

#include <stdarg.h>

volatile long   ARGI[32];
volatile double ARGD[32];
volatile long   OUTI[32];
volatile double OUTD[32];

/* ===================================================================
 * 1. THE CALLEES.  Each writes every argument to a distinct slot, so the
 *    body is a list of stores and the ABI's assignment is visible in the
 *    order the stores appear in.
 * =================================================================== */

__attribute__((noinline))
void i9(long a0, long a1, long a2, long a3, long a4,
        long a5, long a6, long a7, long a8)
{
    OUTI[0] = a0; OUTI[1] = a1; OUTI[2] = a2; OUTI[3] = a3; OUTI[4] = a4;
    OUTI[5] = a5; OUTI[6] = a6; OUTI[7] = a7; OUTI[8] = a8;
}

__attribute__((noinline))
void d9(double a0, double a1, double a2, double a3, double a4,
        double a5, double a6, double a7, double a8)
{
    OUTD[0] = a0; OUTD[1] = a1; OUTD[2] = a2; OUTD[3] = a3; OUTD[4] = a4;
    OUTD[5] = a5; OUTD[6] = a6; OUTD[7] = a7; OUTD[8] = a8;
}

/* The mixed case: the two register sequences are INDEPENDENT, and the
 * interesting question is whether they interleave by source order or each
 * keeps its own counter.  This function has 4 integers and 4 doubles
 * alternating, which is the arrangement that makes the two hypotheses
 * disagree. */
__attribute__((noinline))
void m8(long a0, double b0, long a1, double b1,
        long a2, double b2, long a3, double b3)
{
    OUTI[0] = a0 + a1 + a2 + a3;
    OUTD[0] = b0 + b1 + b2 + b3;
}

/* 9 integers AND 9 doubles in one call: 16 register slots, 8 integers and
 * 8 doubles fit, and BOTH ninths go on the stack.  The AAPCS64 says the
 * first stacked argument is at the initial value of SP, so the two of them
 * must be at SP+0 and SP+8 -- in which order is the measurement. */
__attribute__((noinline))
void m18(long a0, double b0, long a1, double b1, long a2, double b2,
         long a3, double b3, long a4, double b4, long a5, double b5,
         long a6, double b6, long a7, double b7, long a8, double b8)
{
    OUTI[0] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8;
    OUTD[0] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7 + b8;
}

/* The return value.  x0 for an integer, d0 for a double: the result comes
 * back in the register the FIRST argument would have used. */
__attribute__((noinline)) long  r1(long a) { return a * 3; }
__attribute__((noinline)) double r1d(double a) { return a * 3.0; }

/* A function that returns a struct too large for a register, so the answer
 * is the address of memory the CALLER allocated -- and the AAPCS64 puts that
 * address in x8, which is not x0. */
struct big { long v[8]; };
__attribute__((noinline)) struct big rbig(long a)
{
    struct big r; int k;
    for (k = 0; k < 8; k++) r.v[k] = a + k;
    return r;
}

/* ===================================================================
 * 2. THE CALLERS.  Each is the audit: it names its arguments through the
 *    `ARGI[k]` / `ARGD[k]` offsets, and the compiler cannot invent a plan.
 * =================================================================== */

void c9(void)
{
    i9(ARGI[0], ARGI[1], ARGI[2], ARGI[3], ARGI[4],
       ARGI[5], ARGI[6], ARGI[7], ARGI[8]);
}

void cd9(void)
{
    d9(ARGD[0], ARGD[1], ARGD[2], ARGD[3], ARGD[4],
       ARGD[5], ARGD[6], ARGD[7], ARGD[8]);
}

void cm8(void)
{
    m8(ARGI[0], ARGD[0], ARGI[1], ARGD[1], ARGI[2], ARGD[2], ARGI[3], ARGD[3]);
}

void cm18(void)
{
    m18(ARGI[0], ARGD[0], ARGI[1], ARGD[1], ARGI[2], ARGD[2],
        ARGI[3], ARGD[3], ARGI[4], ARGD[4], ARGI[5], ARGD[5],
        ARGI[6], ARGD[6], ARGI[7], ARGD[7], ARGI[8], ARGD[8]);
}

long use_ret(long a) { return r1(a) + 1; }
double use_retd(double a) { return r1d(a) + 1.0; }
long use_big(long a) { struct big b = rbig(a); return b.v[0] + b.v[7]; }

/* ===================================================================
 * 3. THE FRAME.  Four shapes: a leaf that needs no memory, a leaf that
 *    does, a non-leaf, and a big one.  The leaf-that-does is the whole
 *    red-zone story on this architecture, because there is nowhere else
 *    for its locals to go.
 * =================================================================== */

long leaf_reg(long a, long b)  { return a * a + b * b - 3 * a; }

long leaf_spill(long a, long b)
{
    volatile long t0 = a + b, t1 = a * b, t2 = a - b;
    return t0 + t1 + t2;
}

__attribute__((noinline)) long inner(long a, long b)
{
    volatile long s = a * b;
    return s + 1;
}

long nonleaf(long a, long b)
{
    volatile long s = a - b;
    return inner(s, a) + s;
}

long big_frame(long a)
{
    volatile long t[8];
    long s = 0; int k;
    for (k = 0; k < 8; k++) t[k] = a + k;
    for (k = 0; k < 8; k++) s += t[k];
    return s;
}

/* A leaf that needs a 16-byte-aligned object in memory.  This is the
 * function whose frame has to satisfy the alignment rule, and it is the
 * reason the rule is 16 and not 4. */
typedef struct { double x, y; } vec2;
long leaf_vec(vec2 v, double w)
{
    volatile vec2 t;
    t.x = v.x * w; t.y = v.y * w;
    return (long)(t.x + t.y);
}

/* ===================================================================
 * 4. CALLEE-SAVED.  Values live ACROSS a call, so they cannot live in the
 *    caller-saved temporaries x9-x15 (seven of them) or d0-d7 (eight of
 *    them), and the compiler has to reach further down the file.
 * =================================================================== */

__attribute__((noinline)) long sink(long v) { OUTI[0] = v; return v + 1; }

__attribute__((noinline))
long many(long a0, long a1, long a2, long a3, long a4, long a5,
          long a6, long a7, long a8, long a9, long a10, long a11)
{
    long s = 0;
    s += sink(a0); s += sink(a1); s += sink(a2); s += sink(a3);
    s += sink(a4); s += sink(a5); s += sink(a6); s += sink(a7);
    s += sink(a8); s += sink(a9); s += sink(a10); s += sink(a11);
    return s;
}

__attribute__((noinline)) double fsink(double v) { OUTD[0] = v; return v * 2.0; }

__attribute__((noinline))
double fmany(double a0, double a1, double a2, double a3, double a4,
             double a5, double a6, double a7, double a8, double a9)
{
    double s = 0.0;
    s += fsink(a0); s += fsink(a1); s += fsink(a2); s += fsink(a3);
    s += fsink(a4); s += fsink(a5); s += fsink(a6); s += fsink(a7);
    s += fsink(a8); s += fsink(a9);
    return s;
}

/* The variadic case, because it is the one place the callee MUST copy the
 * argument registers into memory of its own -- and the copy is all 128 bits
 * of v0-v7, which is where the 16-byte alignment of SP stops being a
 * style rule. */
long va(int n, ...)
{
    va_list ap; long t = 0; double d = 0.0; int i;
    va_start(ap, n);
    for (i = 0; i < n; i++) { t += va_arg(ap, long); d += va_arg(ap, double); }
    va_end(ap);
    OUTI[1] = t; OUTD[1] = d;
    return t;
}
