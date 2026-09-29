/* vecdump.c -- the artifact for "The x86-64 Data Path: Atomics, Ordering
 * and Vectors".
 *
 * NOT a table from a manual.  Section 1B prints the reference tables and
 * marks them NOT MEASURED; every other number in this file is a FAULT
 * observed, a BIT PATTERN read out of a register here, a BYTE read out of a
 * disassembled object here, or a DURATION measured here.  Section 7 is the
 * retractions and the limits, printed rather than footnoted.
 *
 * Build:  cc -O2 -Wall -Wextra -mavx2 -mfma -o vecdump vecdump.c -lpthread
 *
 * THE FLAG MATTERS and it is worth printing: without -mavx2 the compiler
 * emits SSE2 and NOT ONE of the instructions this file is trying to measure
 * appears in the binary.  Section 1 prints the instruction census of the
 * binary itself, so the claim "we measured AVX2" is checkable against the
 * object rather than against the build command.
 *
 * THE RULES THIS FILE FOLLOWS, each learned in one of the eight courses
 * before this one rather than in a README:
 *
 *   1. THE INSTRUMENT COMES FIRST.  Section 1 measures the clock, its drift
 *      and the noise floor, and prints all three BEFORE any claim.
 *   2. A TICK IS TIME, NOT CYCLES.  Every cost here is a RATIO.
 *   3. EVERY ARM PROVES IT DID THE WORK.  A checksum is printed for every
 *      timing table and every one is compared against what the arm's own
 *      definition says it should be.
 *   4. STATE IS RESET BETWEEN ARMS.  An arm inheriting the previous one's
 *      array reads plausible numbers and is wrong.
 *   5. EVERYTHING THAT MIGHT FAULT RUNS IN A FORKED CHILD, so a fault is a
 *      signal number rather than a dead artifact.
 *   6. A CLAIM THAT DID NOT SURVIVE MEASUREMENT IS RETRACTED, in public, in
 *      section 7, and the retraction is printed here so that a later edit
 *      cannot quietly drop it.
 *
 * A NOTE ON WHAT IS QUOTED AND WHAT IS MEASURED, because the machine cannot
 * execute one instruction in this course at all:  CPUID says there is NO
 * AVX-512 on this part (five bits, all zero, printed in section 1).  So
 * everything about a ZMM register and everything about a k0-k7 mask is
 * QUOTED and marked so, and the ONE thing section 6 does with AVX-512 is
 * decode its bytes -- which needs no silicon at all.
 */
#define _GNU_SOURCE
#include "vecdump.h"


