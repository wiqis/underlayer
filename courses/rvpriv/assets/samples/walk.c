/* walk.c -- a page-table walk, compiled, so that the RELOCATIONS the
 * assembler emitted can be read back out of the object file.
 *
 * This is the hinge between the privileged architecture and the object-file
 * half of this collection.  A page-table walk is a chain of loads, and every
 * one of those loads names an address the compiler does not know at compile
 * time: the root table, and then a table named by a PTE.  So each one is a
 * reference the assembler has to record, and the number and KIND of the
 * records is a property of the object file that a linker has to satisfy.
 *
 * `rvasm` already measured the reach of `auipc` -- 32 bits of immediate,
 * plus a 12-bit `addi`, plus the sign-extension rules -- and this file
 * repeats none of it.  What is measured here is the OTHER half: the
 * relocation RECORDS, their types and codes, and the fact that the number
 * of records has nothing to do with the number of page tables the walk
 * touches.
 *
 * `sp2.c` is the controlled version of that last claim: the same walk, the
 * same compiler, and the only difference is where the three tables sit.
 */

typedef unsigned long long pte_t;
typedef unsigned long va_t;

/* PPN is PTE[53:8]; A is bit 6, D is bit 7, G 5, U 4, X 3, W 2, R 1, V 0. */
#define PPN(p)     (((p) >> 8) & 0x3fffffffffffffULL)
#define ADDR(p)    ((pte_t *)(unsigned long)PPN(p))
#define SLOT(b, i) ((pte_t *)(b) + (i))
#define PTE_V(p)   ((p) & 1)
#define PTE_R(p)   (((p) >> 1) & 1)
#define PTE_W(p)   (((p) >> 2) & 1)
#define PTE_X(p)   (((p) >> 3) & 1)
#define PTE_U(p)   (((p) >> 4) & 1)
#define PTE_G(p)   (((p) >> 5) & 1)
#define PTE_A(p)   (((p) >> 6) & 1)
#define PTE_D(p)   (((p) >> 7) & 1)

/* Sv39: three levels, VPN[38:30] VPN[29:21] VPN[20:12], offset 11:0. */
#define VPN0(va)   (((va) >> 30) & 0x1ff)
#define VPN1(va)   (((va) >> 21) & 0x1ff)
#define VPN2(va)   (((va) >> 12) & 0x1ff)
#define PGOFF(va)  ((va) & 0xfff)

/* Sv48: FOUR levels, and one more table and one more set of index bits. */
#define VPN3_48(va) (((va) >> 39) & 0x1ff)

pte_t *root;
pte_t *l1tab;
pte_t *l2tab;

/* A three-level walk.  Every intermediate pointer is forced into a
 * register and USED, so the addresses are real references rather than one
 * dead load the optimiser removed. */
pte_t *walk39(va_t va, int fill)
{
    pte_t *a = SLOT(root, VPN0(va));
    if (fill && !PTE_V(*a))
        *a = ((pte_t)(unsigned long)l1tab & ~0xffULL) | 1;
    pte_t *b = SLOT(ADDR(*a), VPN1(va));
    if (fill && !PTE_V(*b))
        *b = ((pte_t)(unsigned long)l2tab & ~0xffULL) | 1;
    pte_t *c = SLOT(ADDR(*b), VPN2(va));
    if (fill && !PTE_V(*c))
        *c = ((pte_t)(unsigned long)(l2tab + 1) & ~0xffULL) | 0x0f;
    /* The eight flag bits, so that the PTE layout is in the code and not
     * only in a comment. */
    (void)PGOFF(va);
    (void)PTE_V(*c); (void)PTE_R(*c); (void)PTE_W(*c); (void)PTE_X(*c);
    (void)PTE_U(*c); (void)PTE_G(*c); (void)PTE_A(*c); (void)PTE_D(*c);
    return c;
}

/* A four-level walk, which is Sv48 and which needs one more table. */
pte_t *walk48(va_t va, int fill)
{
    pte_t *z = SLOT(root, VPN3_48(va));
    if (fill && !PTE_V(*z))
        *z = ((pte_t)(unsigned long)(root + 1) & ~0xffULL) | 1;
    pte_t *a = SLOT(ADDR(*z), VPN0(va));
    if (fill && !PTE_V(*a))
        *a = ((pte_t)(unsigned long)l1tab & ~0xffULL) | 1;
    pte_t *b = SLOT(ADDR(*a), VPN1(va));
    if (fill && !PTE_V(*b))
        *b = ((pte_t)(unsigned long)l2tab & ~0xffULL) | 1;
    pte_t *c = SLOT(ADDR(*b), VPN2(va));
    if (fill && !PTE_V(*c))
        *c = ((pte_t)(unsigned long)(l2tab + 1) & ~0xffULL) | 0x0f;
    return c;
}

/* satp, and the three masks.  See bits.c for why two of them are wrong. */
unsigned long get_satp(void);
unsigned long get_satp(void)
{
    unsigned long v;
    __asm__ volatile ("csrr %0, satp" : "=r"(v));
    return v;
}
va_t satp_mode(va_t s)  { return (s >> 60) & 0xf; }
va_t satp_asid(va_t s)  { return (s >> 44) & 0xffff; }
va_t satp_ppn36(va_t s) { return (s >> 8) & 0xfffffffffULL; }

/* sfence.vma, the instruction that says "the page tables I just wrote are
 * now the page tables".  It is a SYSTEM instruction with funct3 = 0 and a
 * 12-bit funct12, which is the same field the CSR NUMBER occupies in the
 * other six SYSTEM instructions. */
void fence_va_all(void)      { __asm__ volatile ("sfence.vma" : : : "memory"); }
void fence_va_asid(va_t a)   { __asm__ volatile ("sfence.vma %0" : : "r"(a) : "memory"); }
void fence_va_addr(va_t v)   { __asm__ volatile ("sfence.vma %0, zero" : : "r"(v) : "memory"); }
