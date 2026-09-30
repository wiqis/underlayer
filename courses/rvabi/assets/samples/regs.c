/* regs.c -- the register file as a PARTITIONED NAMESPACE, and what the ABI
 * names mean rather than what they are.
 *
 * The base integer convention partitions x0..x31 by NUMBER:
 *
 *     x0        zero     immutable, NOT a general-purpose register
 *     x1        ra       return address            not preserved
 *     x2        sp       stack pointer             preserved, 128-bit aligned
 *     x3        gp       global pointer           unallocatable
 *     x4        tp       thread pointer           unallocatable
 *     x5-x7    t0-t2    temporaries               not preserved
 *     x8-x9    s0-s1    callee-saved              preserved
 *     x10-x17  a0-a7    arguments                 not preserved
 *     x18-x27  s2-s11   callee-saved              preserved
 *     x28-x31  t3-t6    temporaries               not preserved
 *
 * The ABI names ROLES.  That is the claim this file tests, because a role
 * name and a number are two different things and only one of them is in the
 * encoding: `s0` and `fp` are both x8, and the encoding holds the number.
 *
 * Three questions the artifact asks of the compiler's own output:
 *
 *   1. HOW OFTEN DOES EACH NAME APPEAR.  A census, per name, over every
 *      function at every optimisation level.  The interesting number is not
 *      the largest -- it is that `zero` appears as a SOURCE often and as a
 *      DESTINATION almost never, and the reason is one bit of hardwiring.
 *
 *   2. `mv rd, x0` versus `addi rd, x0, 0`.  Both produce a zero.  One is a
 *      two-byte `c.mv`, the other is a four-byte `addi`.  Which does the
 *      compiler pick for a plain zero, and does the answer change with
 *      -march?
 *
 *   3. HOW MANY REGISTERS DOES A CALLEE HAVE TO SAVE.  RISC-V has no flags
 *      register to save, so the answer is strictly smaller than x86-64's for
 *      the same C, and the difference is countable.
 */

/* zeros -- the compiler has a choice of spellings for a zero. */
int zeros(int a, int b) { int z = 0; return (z + a) * 3 + (z - b) * 5; }

/* zeroargs -- `x < 0` compiles to a comparison against x0 whether the source
 * says `0` or says `x0`, and this is where `zero` earns its name. */
int zeroargs(int x, int y) { return (x < 0) ? y : -y; }

/* many -- twelve live values and eight argument registers, so this function
 * has to reach for callee-saved registers and the artifact can count which
 * ones and how many.  The SET of registers it picks is the measurement: not
 * ten because there are ten, but because there are seven caller-saved
 * temporaries and twelve values that have to live somewhere. */
int many(int a, int b, int c, int d, int e, int f, int g, int h,
         int i, int j, int k, int l)
{ return a * 3 + b * 5 + c * 7 + d * 11 + e * 13 + f * 17 + g * 19
       + h * 23 + i * 29 + j * 31 + k * 37 + l * 41; }

/* manycall -- the SAME body as `many`, plus a call.  The point is that a
 * function which makes no call may not need to save anything at all, so
 * "callee-saved" is a PROMISE the compiler may keep cheaply only when it
 * actually has to. */
int manycall(int a, int b, int c, int d, int e, int f, int g, int h,
             int i, int j, int k, int l);

int shallow(int x) { return x * 3 + 1; }
int manycall(int a, int b, int c, int d, int e, int f, int g, int h,
             int i, int j, int k, int l)
{ return many(a, b, c, d, e, f, g, h, i, j, k, l) + shallow(a); }

/* spilled -- more live values than registers, so there is a frame and the
 * artifact can count the stores.  This is the function that tells a RISC-V
 * callee and an x86-64 callee apart, because there is no red zone: every
 * spilled slot costs an explicit frame. */
int spilled(int a, int b, int c, int d, int e, int f, int g, int h,
            int i, int j)
{ int p0 = a * 3, p1 = b * 5, p2 = c * 7, p3 = d * 11, p4 = e * 13,
      p5 = f * 17, p6 = g * 19, p7 = h * 23, p8 = i * 29, p9 = j * 31;
  return p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9 + a; }