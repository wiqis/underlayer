/* leaf.c -- the ABI leaf function for "Compiler Backend: From IR to Machine Code".
 *
 * SIX INTEGER ARGUMENTS, because the sixth is the interesting one: on all
 * three conventions of this course the sixth integer argument is still in a
 * register (r9, x5, a5) and the SEVENTH is the one that moves to the stack.
 * A course that wanted to demonstrate that would use seven.  This one uses
 * six, and the limits section says why, because the number of arguments that
 * spill is a fact about the ABI and not about the backend.
 */
long leaf(long a, long b, long c, long d, long e, long f)
{
    return a + b * 2 + c * 3 + d * 4 + e * 5 + f * 6;
}
