/* ir_corpus.c -- the corpus for "Compiler Backend: From IR to Machine Code".
 *
 * Ten small functions, chosen so that the IR at -O0 and at -O2 differ in
 * every way that matters for this course: there is a CALL so the backend has
 * to know the ABI, a LOOP so the IR has a control-flow edge, a REDUCTION so
 * the vectoriser has something to vectorise, a SWITCH so the IR has more
 * than two successors, and a MEMORY OPERAND so instruction selection has a
 * memory form to match.
 *
 * Nothing here is written to be clever.  The corpus is small ON PURPOSE: the
 * claim this course makes about the IR-to-machine RATIO is only meaningful
 * with a denominator, and a corpus of ten functions prints its denominator.
 */

int dot(int *a, int *b, int n)
{
    int s = 0;
    for (int i = 0; i < n; i++)
        s += a[i] * b[i];
    return s;
}

int max3(int a, int b, int c)
{
    int m = a;
    if (b > m) m = b;
    if (c > m) m = c;
    return m;
}

long sumld(long *a, long n)
{
    long s = 0;
    for (long i = 0; i < n; i++)
        s += a[i];
    return s;
}

int sw(int x)
{
    switch (x) {
    case 0: return 1;
    case 1: return 2;
    case 2: return 4;
    default: return 0;
    }
}

unsigned cnt(unsigned *p, unsigned n, unsigned v)
{
    unsigned c = 0;
    for (unsigned i = 0; i < n; i++)
        if (p[i] == v) c++;
    return c;
}

int sat(int x, int lo, int hi)
{
    return x < lo ? lo : (x > hi ? hi : x);
}

long mix(long a, long b, long c)
{
    return a * b + c * 3 + (a ^ b) - (c << 1);
}

int cond(int x, int y)
{
    return (x > y) ? (x - y) : (y - x);
}

long walk(long *p, long n)
{
    long s = 0;
    for (long i = 0; i < n; i++)
        s += p[i] * 3 + (p[i] >> 2);
    return s;
}

unsigned popcntish(unsigned x)
{
    unsigned c = 0;
    while (x) { c += x & 1u; x >>= 1; }
    return c;
}

int mul3(int a) { return a * 3; }
