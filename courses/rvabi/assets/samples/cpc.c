/* cpc.c -- what the C extension does to the ABI and to disassembly.
 *
 * The sibling course `rvasm` already measured the ENCODING side: how many
 * code points are reserved, which displacements share five bit positions and
 * are assigned seven different orders, and how a compressed register field
 * means x8 where a five-bit field would mean x0.  None of that is repeated
 * here.  What is repeated, deliberately, is the CONSEQUENCE, because that is a
 * different subject with a different evidence:
 *
 *   * a SPILLING SEQUENCE, before and after compression -- the store and the
 *     reload of one callee-saved register;
 *   * a HOT LOOP, before and after -- a body that runs n times, where the byte
 *     count is the number of bytes FETCHED PER ITERATION;
 *   * a JAL/RET PAIR, before and after -- the two instructions that are the
 *     whole of a function call.
 *
 * Every number here is an INSTRUCTION COUNT and a BYTE COUNT.  They are not a
 * speedup, because there is no RISC-V machine, no emulator and no RISC-V
 * binutils on this host to measure a speedup ON.  Fewer bytes is a property of
 * the BYTES and a statement about instruction fetch, and the artifact says so
 * in the sentence under every table it prints them in.
 */

/* shallow -- the leaf every `jal` in this file calls.  Declared here rather
 * than shared, so each of the four C files is self-contained and can be
 * compiled for three targets without a header. */
int shallow(int x) { return x * 3 + 1; }

/* spill -- one callee-saved register, stored and reloaded around one call.
 * This is the canonical frame, and it is four instructions of which the two
 * that matter are a store and a load. */
long spill(long x) { long y = x * 3; return (long)shallow((int)y) + y; }

/* spilln -- eight callee-saved registers.  The compressed form has FOUR
 * stack-pointer-relative encodings (c.sdsp and friends) with a 6-bit
 * displacement, and the 32-bit form has an S-type immediate of 12 bits, so the
 * same frame is 4 bytes wider per instruction and 2 bytes narrower per slot
 * depending on the register class. */
long spilln(long a, long b, long c, long d, long e, long f, long g, long h)
{ long x0 = a * 3, x1 = b * 5, x2 = c * 7, x3 = d * 11;
  long x4 = e * 13, x5 = f * 17, x6 = g * 19, x7 = h * 23;
  long s = (long)shallow(a + b + c + d + e + f + g + h);
  return s + x0 + x1 + x2 + x3 + x4 + x5 + x6 + x7; }

/* hot -- a loop whose body is six instructions.  The body is what matters,
 * because the loop runs n times and the surrounding code runs once, so a
 * whole-function byte count measures the wrong code.  The artifact extracts
 * the body between the branch target and the backward branch and counts THAT. */
int hot(const int *p, int n)
{ int s = 0;
  for (int i = 0; i < n; i++) s += p[i] * 3;
  return s; }

/* callret -- a call and a return, and nothing else.  `jal ra, f` and
 * `ret` are the two instructions whose compressed forms exist, and they are
 * on the critical path of EVERY function boundary in the program. */
int callret(int a) { return shallow(a) + 1; }