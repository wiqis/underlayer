/* bits.c -- the PTE and satp bit assignments, expressed in C, so that the
 * COMPILER emits them and the artifact can read the shifts back out of the
 * bytes.
 *
 * The point of writing them in C rather than quoting the manual's figure is
 * that the compiler's output is a THIRD reader.  Given `((p) >> 7) & 1` it
 * emits `slli rd, rs, 0x38 ; srli rd, rd, 0x3f`, and 0x38 is 56 and 63 - 56
 * is 7 and 7 is the bit the manual's figure says D occupies.  Seven of
 * those in a run is not a coincidence, and a run of seven is a thing a
 * reader can check against the manual's picture in one look.
 *
 * The VPN and satp macros are here for the same reason and for a second
 * one: the two shifts in each pair ENCODE the position and the width
 * separately, and separating them is what makes the field table checkable
 * rather than memorised.  64 - width - position is the left shift, and
 * 64 - width is the right shift.
 */

typedef unsigned long long pte_t;
typedef unsigned long va_t;

/* ---- the eight permission/flag bits, 0 through 7 ----------------------- */
pte_t pte_v(pte_t p) { return ((p) >> 0) & 1; }   /* 0 */
pte_t pte_r(pte_t p) { return ((p) >> 1) & 1; }   /* 1 */
pte_t pte_w(pte_t p) { return ((p) >> 2) & 1; }   /* 2 */
pte_t pte_x(pte_t p) { return ((p) >> 3) & 1; }   /* 3 */
pte_t pte_u(pte_t p) { return ((p) >> 4) & 1; }   /* 4 */
pte_t pte_g(pte_t p) { return ((p) >> 5) & 1; }   /* 5 */
pte_t pte_a(pte_t p) { return ((p) >> 6) & 1; }   /* 6 */
pte_t pte_d(pte_t p) { return ((p) >> 7) & 1; }   /* 7 */

/* ---- the Sv39/Sv48/Sv57 address split --------------------------------- */
/* Nine index bits per level, twelve bits of page offset. */
va_t vpn0(va_t va) { return ((va) >> 30) & 0x1ff; }   /* Sv39 level 2 */
va_t vpn1(va_t va) { return ((va) >> 21) & 0x1ff; }   /* Sv39 level 1 */
va_t vpn2(va_t va) { return ((va) >> 12) & 0x1ff; }   /* Sv39 level 0 */
va_t vpn3(va_t va) { return ((va) >> 39) & 0x1ff; }   /* Sv48 level 3 */
va_t vpn4(va_t va) { return ((va) >> 48) & 0x1ff; }   /* Sv57 level 4 */
va_t pgoff(va_t va) { return (va) & 0xfff; }           /* 12 bits, untranslated */

/* ---- the PPN, at THREE widths, all three of which are interesting ------ */
/* The 46-bit field a PTE has: PTE[53:8]. */
pte_t ppn_46(pte_t p) { return ((p) >> 8) & 0x3fffffffffffULL; }
/* The 44 bits the manual's figure shows, PTE[53:10]. */
pte_t ppn_44(pte_t p) { return ((p) >> 10) & 0xfffffffffffULL; }
/* The bits the manual reserves above the PPN, PTE[63:54]. */
pte_t pte_reserved(pte_t p) { return ((p) >> 54) & 0x3ff; }

/* ---- satp, three fields, and the trap at the end ----------------------- */
/* MODE is the top four bits of a 64-bit satp.  ASID is sixteen.  PPN is
 * the rest of the address, and the width of "the rest" is the interesting
 * arithmetic: 64 - 4 (MODE) - 16 (ASID) - 8 (the shift) = 36. */
va_t satp_mode(va_t s) { return (s >> 60) & 0xf; }
va_t satp_asid(va_t s) { return (s >> 44) & 0xffff; }
va_t satp_ppn36(va_t s) { return (s >> 8) & 0xfffffffffULL; }

/* TWO MASKS THAT ARE WRONG, kept deliberately.  The first is 54 bits, which
 * is the width of the PPN field in a PTE, applied to satp.  The second is
 * 44 bits, which is the width the manual's PPN figure shows, also applied to
 * satp.  Both are natural mistakes -- the field in a PTE really is 54 bits
 * wide, and the manual really does show 44 -- and both compile to a
 * plausible-looking pair of shifts.  Section 8 measures what each one
 * actually returns and section 13 retracts them. */
va_t satp_ppn54_wrong(va_t s) { return (s >> 8) & 0x3fffffffffffffULL; }
va_t satp_ppn44_wrong(va_t s) { return (s >> 8) & 0xfffffffffffULL; }
