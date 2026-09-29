/* corpus.c -- the half of the corpus that is a COMPILER'S output, not a
 * human's.  Every instruction in it was chosen by gcc 15.2 at -O2, and the
 * course's claim about a compiler is a claim about BYTES, so build_samples.sh
 * objdumps this file and the artifact reads the result.  Nothing here is
 * timed; the point is which mnemonics the compiler reached for, for four
 * pieces of C that a reader would guess are spelled one way and are not.
 *
 *   1. `a << b` and `a >> b` -- the shift-count forms, and whether the
 *      compiler can use the immediate form or must go through %cl.
 *   2. `x < y ? p : q`      -- the branchless form, if the compiler chooses it.
 *   3. `unsigned char` arithmetic -- whether the extension is explicit.
 *   4. `p[i] = p[i] + 1` on a `char *` -- whether the width is 8, 32 or 64.
 */

int shift_left(int a, int b) { return a << b; }
int shift_right(int a, int b) { return a >> b; }
int shift_by_one(int a) { return a << 1; }

int pick(int x, int y, int p, int q) { return x < y ? p : q; }

int widen(unsigned char c) { return c + 1; }
int narrow(char c) { return (int)(c + 1); }

void bump(char *p) { p[0] = (char)(p[0] + 1); }
unsigned sum(const unsigned *p, int n) {
    unsigned t = 0;
    for (int i = 0; i < n; i++) t += p[i];
    return t;
}
int cmp_and_branch(const int *p, int n) {
    int t = 0;
    for (int i = 0; i < n; i++) if (p[i] < 0) t++;
    return t;
}
