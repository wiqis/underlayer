/* vecdump.h -- shared declarations for the x86simd artifact.
 *
 * The artifact is four translation units rather than one, because a single
 * 2000-line C file is a file nobody reviews.  They are compiled with ONE
 * command (see build_samples.sh) so reproducing it is still one line.
 */
#ifndef VECDUMP_H
#define VECDUMP_H

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sched.h>
#include <signal.h>
#include <pthread.h>
#include <sys/wait.h>
#include <sys/mman.h>

/* ---- the instrument, shared by every section ------------------- */
extern volatile long g_sink;
extern uint64_t      g_ck;
extern long          g_iters;
extern int           g_copies;
extern int           g_quick;
extern int           g_rows;
extern int           g_pinned;
extern int           g_at_iters;
extern char         *g_dis;

static inline uint64_t rdtsc_(void)
{
    uint32_t lo, hi;
    __asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

void do_cpuid(unsigned leaf, unsigned sub, unsigned *a, unsigned *b,
              unsigned *c, unsigned *d);
double wall_seconds(void);
void   nap_ms(long ms);
void   pin_and_verify(int cpu);
void   banner(const char *s);
void   endbanner(void);

/* ---- the instruction census ------------------------------------ */
double tsc_rate_busy(void);
double tsc_rate_across_sleep(void);
double floor_pointer_chase(void);
double floor_arithmetic(void);
void   maps_emit(void);
void   instr_reset(void);
void instr_note(const char *s);
int  instr_count(const char *s);
void instr_report(void);

/* ---- the sections ---------------------------------------------- */
void section_1(void);
void section_1b(void);
void section_2(void);   /* alignment: a FAULT requirement            */
void section_3(void);   /* VEX three operands, and vzeroupper        */
void section_4(void);   /* the atomic set, exhaustively               */
void section_5(void);   /* the fences, and the store buffer          */
void section_6(void);   /* encode the maps, decode the bytes          */
void section_7(void);   /* retractions and limits                     */

/* ---- section 4: the atomic arms -------------------------------- */
typedef struct {
    const char *name;    /* "incl, no LOCK"                            */
    const char *bytes;   /* the exact encoding, asserted to the bit    */
    int         uses;    /* 1 = the arm counts lost updates            */
    int         implicit;/* 1 = the SDM says the memory form is locked */
} atomic_arm_t;
extern atomic_arm_t ATOMIC[];
extern const int    NATOMIC;

#endif /* VECDUMP_H */
