/* sp2.c -- THE CONTROLLED EXPERIMENT for the relocation claim.
 *
 * One page-table walk.  Three page tables.  The ONLY difference between the
 * two builds is WHERE the three tables sit in memory, and the number of
 * R_RISCV_PCREL_HI20 relocations the assembler emits changes by a factor of
 * three.
 *
 * That is the measurement, and it is the reason the page-table walk is worth
 * showing in an object-file course rather than a virtual-memory one: the
 * number of relocation records a linker has to resolve is a function of the
 * DATA LAYOUT, not of the number of page tables the code touches.  A reader
 * who counts records and reasons about how many addresses the program knows
 * is reasoning about the wrong number.
 *
 * -DSPARSE -DSPARSE_KB=4096 puts 4 KiB of unrelated data between each pair
 * of tables.  Both builds are at -O2 with the same source otherwise.
 */

typedef unsigned long long pte_t;
typedef unsigned long va_t;

#define PPN(p)     (((p) >> 8) & 0x3fffffffffffffULL)
#define ADDR(p)    ((pte_t *)(unsigned long)PPN(p))
#define SLOT(b, i) ((pte_t *)(b) + (i))
#define PTE_V(p)   ((p) & 1)

pte_t *root, *l1tab, *l2tab;

pte_t *walk(va_t va, int fill)
{
    pte_t *a = SLOT(root, (va >> 30) & 0x1ff);
    if (fill && !PTE_V(*a))
        *a = ((pte_t)(unsigned long)l1tab & ~0xffULL) | 1;
    pte_t *b = SLOT(ADDR(*a), (va >> 21) & 0x1ff);
    if (fill && !PTE_V(*b))
        *b = ((pte_t)(unsigned long)l2tab & ~0xffULL) | 1;
    pte_t *c = SLOT(ADDR(*b), (va >> 12) & 0x1ff);
    if (fill && !PTE_V(*c))
        *c = ((pte_t)(unsigned long)(l2tab + 1) & ~0xffULL) | 0x0f;
    return c;
}

#ifdef SPARSE
/* Three tables, each 4 KiB away from the next.  The alignment is there so
 * that the sparseness is a property of the layout and not of the compiler
 * deciding to reorder. */
char pad1[SPARSE_KB] __attribute__((used));
pte_t *l1tab __attribute__((aligned(4096)));
char pad2[SPARSE_KB] __attribute__((used));
pte_t *l2tab __attribute__((aligned(4096)));
char pad3[SPARSE_KB] __attribute__((used));
#endif
/* Without -DSPARSE the three tables are adjacent, because the definitions
 * above already put them in one declaration. */
