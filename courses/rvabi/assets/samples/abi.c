/* abi.c -- the calling convention, with the compiler as the test subject.
 *
 * THE SPECIFICATION IS THE ORACLE AND THIS FILE IS THE SUBJECT, which is the
 * same arrangement a64abi used and for the same reason: a contract that is
 * only quoted is a contract nobody has tested, and a contract tested against a
 * compiler's actual choices is a contract whose every exception is a finding.
 *
 * THE METHOD, and it is the same method x86abi used.  Every argument is read
 * from its OWN volatile global, so the compiler cannot forward-fold it, cannot
 * constant-propagate it and cannot reorder two arguments that happen to have
 * the same value.  A plain `f(a, b)` returning `a - b` compiles to nothing at
 * -O1 and the measurement is then about the compiler and not about the ABI.
 * With volatile sources, each argument's value is forced through a register
 * the ABI chose, and the artifact can then ask the only question worth
 * asking: DID THE NINTH ARGUMENT LAND AT 0(sp)?
 *
 * i0 .. i9    N integer arguments, each from its own volatile global.
 * f0 .. f9    N double arguments, same.
 * m18         9 integers THEN 9 doubles.  This one function exists to separate
 *             the two hypotheses the m8 case cannot: either there is ONE
 *             counter that runs out after eight values of any kind, or there
 *             are two independent ones.  `m8` (4 int + 4 double) agrees with
 *             BOTH hypotheses, so `m8` alone would prove nothing.
 * wide        a long long, which is 2*XLEN bits and therefore a REGISTER PAIR
 *             with the low half in the lower-numbered register -- the rule the
 *             base integer convention states and the one that is easiest to
 *             get backwards.
 * leaf        a function that makes no call, so anything it saves is saved
 *             for its own locals and the saved-register count is not polluted
 *             by the prologue of a callee.
 */

/* WHY EVERY GLOBAL IS IN ITS OWN SECTION.  This is a measurement device and
 * it is worth one paragraph because a reader is entitled to know that the
 * corpus was arranged for the audit.
 *
 * clang's default is to MERGE adjacent globals of the same type into one
 * object called `.L_MergedGlobals` in `.data.rel.ro.local`, and to reach it
 * through an `auipc`+`addi` pair.  A store then looks like
 *
 *     sd   a0, 0x68(a1)     <- a1 = &.L_MergedGlobals + 0x68
 *
 * and the relocation at that store names `.Lpcrel_hi0`, NOT `G8`.  Learning
 * which variable is written takes TWO HOPS: store -> `.Lpcrel_hi0` -> the
 * `auipc` -> `.L_MergedGlobals` -> the pointer-table slot -> the `G8` entry.
 * That chain is real and it is what PIC medlow code IS, and the artifact can
 * follow it -- but a two-hop chain in the middle of the measurement is two
 * chances to be wrong for a reason that has nothing to do with the calling
 * convention.
 *
 * One section per global removes the merge, the store's own relocation then
 * names `G8` DIRECTLY, and the audit measures the ABI instead of the address
 * formation.  The merge behaviour is still measured, in section 3, because
 * it is worth knowing that clang does it. */
#define VG(n) volatile int G##n __attribute__((section(".gi" #n)));
#define VD(n) volatile double D##n __attribute__((section(".gd" #n)));
VG(0) VG(1) VG(2) VG(3) VG(4) VG(5) VG(6) VG(7) VG(8) VG(9)
VD(0) VD(1) VD(2) VD(3) VD(4) VD(5) VD(6) VD(7) VD(8) VD(9)
volatile long long W0 __attribute__((section(".gw")));

void i0(void) { }
void i1(int a0) { G0 = a0; }
void i2(int a0, int a1) { G0 = a0; G1 = a1; }
void i3(int a0, int a1, int a2) { G0 = a0; G1 = a1; G2 = a2; }
void i4(int a0, int a1, int a2, int a3) { G0 = a0; G1 = a1; G2 = a2; G3 = a3; }
void i5(int a0, int a1, int a2, int a3, int a4)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; G4 = a4; }
void i6(int a0, int a1, int a2, int a3, int a4, int a5)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; G4 = a4; G5 = a5; }
void i7(int a0, int a1, int a2, int a3, int a4, int a5, int a6)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; G4 = a4; G5 = a5; G6 = a6; }
void i8(int a0, int a1, int a2, int a3, int a4, int a5, int a6, int a7)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; G4 = a4; G5 = a5; G6 = a6; G7 = a7; }
__attribute__((noinline)) void i9(int a0, int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; G4 = a4; G5 = a5; G6 = a6; G7 = a7;
  G8 = a8; }

void f0(void) { }
void f1(double a0) { D0 = a0; }
void f2(double a0, double a1) { D0 = a0; D1 = a1; }
void f3(double a0, double a1, double a2) { D0 = a0; D1 = a1; D2 = a2; }
void f4(double a0, double a1, double a2, double a3)
{ D0 = a0; D1 = a1; D2 = a2; D3 = a3; }
void f5(double a0, double a1, double a2, double a3, double a4)
{ D0 = a0; D1 = a1; D2 = a2; D3 = a3; D4 = a4; }
void f6(double a0, double a1, double a2, double a3, double a4, double a5)
{ D0 = a0; D1 = a1; D2 = a2; D3 = a3; D4 = a4; D5 = a5; }
void f7(double a0, double a1, double a2, double a3, double a4, double a5,
        double a6)
{ D0 = a0; D1 = a1; D2 = a2; D3 = a3; D4 = a4; D5 = a5; D6 = a6; }
void f8(double a0, double a1, double a2, double a3, double a4, double a5,
        double a6, double a7)
{ D0 = a0; D1 = a1; D2 = a2; D3 = a3; D4 = a4; D5 = a5; D6 = a6; D7 = a7; }
__attribute__((noinline)) void f9(double a0, double a1, double a2, double a3, double a4, double a5,
        double a6, double a7, double a8)
{ D0 = a0; D1 = a1; D2 = a2; D3 = a3; D4 = a4; D5 = a5; D6 = a6; D7 = a7;
  D8 = a8; }

/* m8 -- 4 ints then 4 doubles.  AGREES WITH BOTH HYPOTHESES and is in the
 * corpus precisely so the artifact can print that fact rather than infer it. */
void m8(int a0, int a1, int a2, int a3, double d0, double d1, double d2,
        double d3)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; D0 = d0; D1 = d1; D2 = d2; D3 = d3; }

/* m18 -- 9 ints THEN 9 doubles.  The function that decides the question. */
__attribute__((noinline)) void m18(int a0, int a1, int a2, int a3, int a4, int a5, int a6, int a7,
         int a8, double d0, double d1, double d2, double d3, double d4,
         double d5, double d6, double d7, double d8)
{ G0 = a0; G1 = a1; G2 = a2; G3 = a3; G4 = a4; G5 = a5; G6 = a6; G7 = a7;
  G8 = a8; D0 = d0; D1 = d1; D2 = d2; D3 = d3; D4 = d4; D5 = d5; D6 = d6;
  D7 = d7; D8 = d8; }

/* wide -- a 2*XLEN scalar, so the specification's REGISTER PAIR rule applies:
 * low-order bits in the LOWER-numbered register.  The rule is easy to state
 * and easy to state backwards, and nothing in the corpus but this function
 * tests it. */
void wide(long long a0, long long a1, int a2, long long a3)
{ W0 = a0 + a1 + a3; G0 = a2; }

/* leaf -- a leaf that needs several callee-saved registers, so the artifact
 * can count what a RISC-V callee has to save and compare it with what an
 * x86-64 callee has to save for the SAME C. */
int leaf(int a, int b, int c, int d, int e, int g, int h, int i, int j)
{ int x = a + b, y = c + d, z = e + g, u = h + i;
  return x * 3 + y * 5 + z * 7 + u * 11 + j; }

/* caller -- the CALLER side of the same three calls, in one function.
 *
 * This exists because a callee's register audit alone cannot tell a
 * disagreement from a mistake in the audit.  If the callee says "the ninth
 * double arrived in a0" and the caller says "and I put it in a0", that is
 * two independent pieces of evidence about the same ABI decision, and the
 * only one that counts.  The single most surprising row in the whole course is
 * the ninth DOUBLE, and it is surprising in a way that is INVISIBLE from the
 * callee alone.
 *
 * The three CALLEES are marked noinline and the caller is not.  That is not
 * decoration: at -O1 and above clang inlines i9, f9 and m18 into `caller`,
 * the calls disappear, and the experiment silently starts measuring the
 * inliner's register allocation instead of the calling convention.  The
 * first version of this file measured -O1 and -O2 and got a caller with four
 * instructions and no `jal` in it at either level. */

void caller(void)
{ i9(1, 2, 3, 4, 5, 6, 7, 8, 9);
  f9(1, 2, 3, 4, 5, 6, 7, 8, 9);
  m18(1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4, 5, 6, 7, 8, 9); }
