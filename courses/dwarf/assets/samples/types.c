#include <stdint.h>

typedef unsigned long  ulong_t;

enum Color { RED = 1, GREEN, BLUE = 7 };

struct Point { int x; int y; };

struct Nest {
    struct Point origin;
    char        label[8];
    uint32_t    flags;
    struct Point *next;
};

union Variant {
    int       i;
    double    d;
    struct Point p;
};

static struct Nest  g_nest  = { {1, 2}, "hi", 0x30, 0 };
static ulong_t       g_count = 7;
static int           g_table[4] = {10, 20, 30, 40};

int  sum_table(int idx) {
    int local = g_table[idx];
    return local + (int)g_count;
}

int  walk(struct Point *p) {
    if (p == 0) { return 0; }
    return p->x + p->y;
}

struct Point make_point(int x, int y) {
    struct Point out;
    out.x = x;
    out.y = y;
    return out;
}
