/* noflags.c -- the section's spine: what a compiler does when there is no
 * flags register, no condition codes, no CMOV and no SETcc.
 *
 * EVERY FUNCTION HERE IS A `?:` ON AN INTEGER CONDITION, because that is the
 * only conditional thing RISC-V has and the question is what the compiler
 * emits instead of a conditional move.  There are exactly three answers and
 * this corpus is built so that all three appear:
 *
 *   1. A BRANCH.           `blt a0, a1, .LBB` -- the condition IS the branch.
 *   2. ARITHMETIC MASKING. `sltiu`/`slt`/`xor`/`sub`/`and`/`xori` -- the
 *                          condition becomes 0 or 1 in a register and the
 *                          selection is done with ordinary arithmetic.
 *   3. A CALL TO A HELPER. the condition is expensive enough that the
 *                          compiler emits a `jal` to something like
 *                          `__muloti4` -- and then the cost is not in this
 *                          function at all, which is why counting CALLS is
 *                          part of the measurement and not an afterthought.
 *
 * The three targets are compiled from this ONE file, so the three-target
 * table at the bottom of the artifact is not a comparison of three bodies of
 * work -- it is one file, one compiler, three `--target=` flags.
 *
 * AND IT IS A COMPILE-TIME COMPARISON.  There is no RISC-V machine, no
 * emulator and no RISC-V binutils on this host, so nothing here has been
 * executed and NO TIMING APPEARS ANYWHERE IN THIS COURSE.  The x86-64 section
 * measured 4.92x and 27.65x; those numbers have no counterpart here and are
 * not invented to fill the gap.  What replaces a ratio is an instruction
 * count, and a count says something different from a ratio: it does not know
 * whether the instruction is fast.
 */

int myabs(int x) { return x < 0 ? -x : x; }
int mymin(int a, int b) { return a < b ? a : b; }
int mymax(int a, int b) { return a > b ? a : b; }
int myclamp(int x, int lo, int hi) { return x < lo ? lo : (x > hi ? hi : x); }
int mysel(int c, int a, int b) { return c ? a : b; }

/* twice -- the condition is used TWICE and the two uses are NOT
 * commutative.  This is the case the manual's note about "multiple branches
 * ... based on the same condition codes" is about, and it is the one case
 * where a compiler with flags has an advantage a compiler without them does
 * not.  It is in the corpus so the measurement can come out the OTHER WAY. */
int twice(int c, int a, int b) { int x = (c < 0); return (x ? a : b) + (x ? b : a); }

/* swap -- one branch, two sides, and the answer is a genuine swap.  The
 * canonical branch-versus-cmov case, and the one x86-64's `CMOV` exists for. */
int swap(int a, int b) { int t; if (a > b) { t = a; a = b; b = t; } return a * 31 + b; }

/* mask -- the condition as arithmetic, written in C, so the compiler has a
 * branch to choose and does not choose one.  `t >> 31` on a signed int is an
 * arithmetic shift, and that is the bit the RISC-V encoder can reach with
 * `sraiw`. */
int mask(int x) { int t = x >> 31; return (x ^ t) - t; }

/* sign -- `x < 0` as a 0-or-1 value, which is `srai rd, rs, 31` and nothing
 * else.  This is the constructive half of the absence: an EXPRESSION that
 * x86-64 has no single instruction for, because it would need `SETL`. */
int sign(int x) { return (x < 0) ? 1 : 0; }

/* absu -- the unsigned absolute value, which cannot use the sign trick and so
 * has to be either a branch or a select.  The comparison against `myabs` is
 * the interesting row: the SAME source shape costs different amounts on the
 * two sign conventions, and the reason is in the encoding. */
unsigned absu(unsigned x) { unsigned t = x >> 31; return (x ^ t) - t; }

/* cmp3 -- three comparisons, one ternary chain, and no way to avoid the
 * branches because each comparison's value is needed for the NEXT one. */
int cmp3(int a, int b, int c) { return a < b ? (b < c ? b : c) : (a < c ? a : c); }

/* bigsel -- enough live values that the masking form needs a scratch
 * register the function does not otherwise have.  This is the case where a
 * compiler is supposed to give up on masking and branch, and the measurement
 * is whether it does. */
int bigsel(int c, int a, int b, int p, int q, int r, int s, int t, int u,
           int v, int w, int y, int z, int k, int m)
{ return (c ? a : b) + (p ? q : r) + (s ? t : u) + (v ? w : y) + (z ? k : m); }