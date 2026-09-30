/* corpus.c -- the C this course makes every claim about.
 *
 * Eleven functions, chosen so that each RISC-V extension letter has something
 * to do and so that the `-march` sweep in section 3 of rvdec.py has something
 * to diff.  Nothing here is exotic: it is arithmetic, masks, conditionals, a
 * loop, a struct walk, a multiply, a divide, a float accumulator and a call.
 *
 * The choice is a choice, and rvdec.py says so in its own limits section: the
 * distribution of mnemonics in the output is a distribution of what clang
 * chose for THIS file, not a property of the architecture.  What IS a property
 * of the architecture is everything about the ENCODING, and that is what the
 * decoder measures.
 */

typedef struct pair { long x, y; } pair;
extern const long table[1024];
extern const char label[];

long fib(long n)
{
    long a = 0, b = 1;
    while (n--) { long t = a + b; a = b; b = t; }
    return a;
}

long gcd(long a, long b)
{
    while (b) { long t = b; b = a % b; a = t; }
    return a;
}

unsigned udiv(unsigned a, unsigned b) { return b ? a / b : 0u; }

long lmul(long a, long b) { return a * b; }

int popcount(unsigned x)
{
    int n = 0;
    while (x) { n += x & 1u; x >>= 1; }
    return n;
}

long sum(const long *p, long n)
{
    long s = 0;
    for (long i = 0; i < n; i++) s += p[i];
    return s;
}

long dot(const pair *p, long n)
{
    long s = 0;
    for (long i = 0; i < n; i++) s += p[i].x * p[i].y;
    return s;
}

int cmp(long a, long b)
{
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}

long bits(long x) { return (x << 3) | (x >> 5) ^ (x & 0xff); }

long sw(long a, long b)
{
    long t = a; a = b; b = t;
    return a * 3 - b;
}

long dsum(const double *p, long n)
{
    double s = 0.0;
    for (long i = 0; i < n; i++) s += p[i] * p[i];
    return (long)s;
}

long pick(long i) { return table[i]; }

int name(void) { return label[0]; }
