/* a64asm corpus -- the C whose compiled bytes this course decodes.
 *
 * The point of this file is that it is ORDINARY code.  Nothing in it is
 * written to produce a particular instruction; it is the kind of C a
 * compiler spends its day on, so that the distribution this course reports
 * is a distribution of what clang actually chose rather than of what the
 * author asked for.  Where a constant is a mask or a magic number that is
 * deliberate and the reason is a comment on the function.
 */

/* ---- 1. integer arithmetic, the three forms ---- */
int arith_chain(int a, int b) { return a + b; }
long arith_wide(long a, long b) { return a * b - (a / (b | 1)); }
unsigned umod(unsigned a, unsigned b) { return a % (b + 1); }

/* ---- 2. masks: this is where LOGICAL IMMEDIATES live ----
 * Every constant below is a repeat of a run of one bits, which is the
 * only shape a logical immediate can express.  The one that is NOT
 * (mask_norepeat) is the control. */
int mask_nibble(int a) { return a & 0x0f0f0f0f; }          /* NOT encodable */
int mask_bytes(int a)  { return a & 0xff00ff00; }          /* NOT encodable */
int mask_runs4(int a)  { return a & 0xf0f0f0f0; }          /* a 4-bit run   */
int mask_runs2(int a)  { return a & 0xcccccccc; }          /* a 2-bit run   */
int mask_runs1(int a)  { return a & 0xaaaaaaaa; }          /* a 1-bit run   */
int mask_all(int a)    { return a | ~0; }                  /* all ones      */
int mask_one(int a)    { return a & 1; }                   /* a single bit  */
int mask_top(int a)    { return (int)((unsigned)a << 31); }

/* ---- 3. wide constants: MOVZ / MOVK / MOVN ---- */
long c_small(long x)  { return x + 0x1234; }              /* one MOVZ     */
long c_16bit(long x)  { return x + 0x12345678; }          /* one MOVZ     */
long c_32bit(long x)  { return x + 0x123456789abcdefLL; } /* three parts  */
long c_holes(long x)  { return x * 0x0001000000000001LL; }/* four parts  */
long c_negative(long x) { return x - 0x7fffffffffffffffLL; }/* MOVN + add  */

/* ---- 4. conditionals: the branch / csel / cset / tbz question ---- */
int cond_sum(int a, int b) { return a < b ? a + b : a - b; }
int cond_and(int a, int b) { return (a & b) ? 1 : 0; }
int cond_zero(int a)       { return a == 0; }
int cond_sign(int a)       { return a < 0 ? -1 : 1; }
int cond_shift(int a, int n) { return a << n; }
int cond_clamp(int a)      { return a < 0 ? 0 : (a > 255 ? 255 : a); }

/* ---- 5. bit tests: the range-load trick ---- */
unsigned bit_test(unsigned a) { return (a & 0x80000000u) ? 1u : 0u; }
unsigned bit_range(unsigned a) { return (a & 0xff) ? 1u : 0u; }
unsigned bit_mixed(unsigned a) { return (a & 0x1ff) ? 1u : 0u; }

/* ---- 6. control flow, so the corpus has branches to look at ---- */
int loop_sum(const int *p, int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += p[i];
    return s;
}
int sw(int a) { switch (a) { case 0: return 1; case 1: return 2;
                             case 7: return 3; default: return 0; } }
int early(int a, int b) {
    if (a < 0) return -1;
    if (b > 1000) return b;
    return a * 2;
}

/* ---- 7. a struct walk, so there is memory traffic to look at ---- */
struct point { int x, y, z; };
int dot(const struct point *a, const struct point *b) {
    return a->x * b->x + a->y * b->y + a->z * b->z;
}

/* ---- 8. calls and returns, so the corpus has a real prologue shape ---- */
extern long other(long);
long call_through(long a, long b) { return other(a) + other(b); }
