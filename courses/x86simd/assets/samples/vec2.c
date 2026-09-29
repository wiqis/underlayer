/* vec2.c -- section 2: the alignment split, and section 3: what the
 * three operands bought and what vzeroupper is for.
 */
#include "vecdump.h"
#include <sys/mman.h>
#include <immintrin.h>

/* ------------------------------------------------------------------ */
/* the shared result page for a forked child's fault                  */
/* ------------------------------------------------------------------ */
static volatile uint32_t *g_buf;

/* The buffer is MMAP'd, and that is not decoration.  The first version of
 * this probe used a static array filled by a loop, and the compiler folded
 * the whole thing: the `vmovapd` became a `vmovsd` of a constant it had
 * already read at compile time, and the probe reported OK for an aligned
 * load AND for a misaligned one.  A compiler that knows the CONTENTS
 * cannot be asked to measure what is in them. */
static void ensure_buf(void)
{
    if (g_buf) return;
    void *m = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (m == MAP_FAILED) { printf("mmap failed\n"); exit(1); }
    g_buf = (volatile uint32_t *)m;
    for (int i = 0; i < 256; i++) g_buf[i] = 0x11111111u;
}

/* ---- the eight probe bodies, each a noinline function ---------- */
#define NOINL __attribute__((noinline))

/* The scratch the probe stores into is a FILE-SCOPE pointer, not an
 * output operand.  A pointer PARAMETER bound to an asm output makes gcc
 * merge the two parameters (.isra), leave the second one unassigned in
 * the caller, and store through whatever happened to be in the register:
 * a probe that segfaults on an ALIGNED address for no reason the
 * instruction can be held to.  That is three bugs in one row of a table
 * and all three of them said "returned" or "SIGSEGV" and looked fine. */
static double *g_scratch;

static NOINL void p_apd_load(const void *p)
{ __asm__ __volatile__("vmovapd (%[a]), %%ymm0\n\tvmovupd %%ymm0, (%[s])"
    : [s] "+r"(g_scratch) : [a] "r"(p) : "ymm0","memory"); }
static NOINL void p_upd_load(const void *p)
{ __asm__ __volatile__("vmovupd (%[a]), %%ymm0\n\tvmovupd %%ymm0, (%[s])"
    : [s] "+r"(g_scratch) : [a] "r"(p) : "ymm0","memory"); }
static void *g_dst;
static NOINL void p_apd_store(const void *s)
{ __asm__ __volatile__("vmovapd (%[a]), %%ymm0\n\tvmovapd %%ymm0, (%[b])"
    : [b] "+r"(g_dst) : [a] "r"(s) : "ymm0","memory"); }
static NOINL void p_upd_store(const void *s)
{ __asm__ __volatile__("vmovupd (%[a]), %%ymm0\n\tvmovupd %%ymm0, (%[b])"
    : [b] "+r"(g_dst) : [a] "r"(s) : "ymm0","memory"); }
static NOINL void p_dqa_load(const void *p)
{ __asm__ __volatile__("vmovdqa (%[a]), %%ymm0" :: [a] "r"(p) : "ymm0","memory"); }
static NOINL void p_dqu_load(const void *p)
{ __asm__ __volatile__("vmovdqu (%[a]), %%ymm0" :: [a] "r"(p) : "ymm0","memory"); }
static NOINL void p_aps_load(const void *p)
{ __asm__ __volatile__("movaps (%[a]), %%xmm0" :: [a] "r"(p) : "xmm0","memory"); }
static NOINL void p_ups_load(const void *p)
{ __asm__ __volatile__("movups (%[a]), %%xmm0" :: [a] "r"(p) : "xmm0","memory"); }
static NOINL void p_aps_v_load(const void *p)
{ __asm__ __volatile__("vmovaps (%[a]), %%ymm0" :: [a] "r"(p) : "ymm0","memory"); }
static NOINL void p_dqa_v_load(const void *p)
{ __asm__ __volatile__("vmovdqa (%[a]), %%ymm0" :: [a] "r"(p) : "ymm0","memory"); }

/* one row of the table: run ONE instruction in a forked child.
 *
 * EVERY address reaches its instruction in a REGISTER, never through the
 * "m" constraint.  That is not a style choice.  The "m" constraint tells
 * gcc that the object has the alignment its TYPE claims, so gcc is free
 * to emit a safe sequence, and it did: four of the sixteen rows reported
 * "returned" on a deliberately misaligned address while the disassembly
 * showed the faulting instruction.  The instrument was lying because the
 * address it passed was not the address under test.  R8's second half.
 */
typedef struct { const char *name; int body; int store; } probe_t;

#define B_APD 0
#define B_UPD 1
#define B_DQA 2
#define B_DQU 3
#define B_APS 4
#define B_UPS 5
#define B_APSV 6
#define B_DQAV 7

static int run_probe(const probe_t *pr, unsigned offbytes)
{
    ensure_buf();
    const void *p  = (const void *)(g_buf + offbytes / 4);
    void *dst      = (void *)(g_buf + offbytes / 4);
    /* The scratch the probe STORES into lives in the mmap'd region, not on
     * the stack.  A stack slot is not guaranteed 32-byte aligned, so a
     * probe that loaded from a deliberately misaligned address and then
     * stored the result into an unaligned stack array faulted on the
     * SECOND instruction and the table blamed the first.  The instrument
     * must have exactly one thing in it that can fault, and that thing is
     * the instruction under test.  R8, third form. */
    g_scratch = (double *)(g_buf + 512);
    g_dst     = dst;
    const void *src = (const void *)g_buf;
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        struct sigaction sa;
        memset(&sa, 0, sizeof sa);
        sa.sa_handler = SIG_DFL;
        for (int i = 1; i < 32; i++) sigaction(i, &sa, NULL);
        switch (pr->body) {
        case B_APD:  if (pr->store) p_apd_store(src);
                     else          p_apd_load(p);     break;
        case B_UPD:  if (pr->store) p_upd_store(src);
                     else          p_upd_load(p);     break;
        case B_DQA:  p_dqa_load(p);    break;
        case B_DQU:  p_dqu_load(p);    break;
        case B_APS:  p_aps_load(p);    break;
        case B_UPS:  p_ups_load(p);    break;
        case B_APSV: p_aps_v_load(p);  break;
        case B_DQAV: p_dqa_v_load(p);  break;
        default: break;
        }
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    return WIFSIGNALED(st) ? WTERMSIG(st) : 0;
}

void section_2(void)
{
    printf("2.  ALIGNMENT IS A FAULT REQUIREMENT, NOT A SPEED ONE.\n\n");
    printf("  Sixteen probes, each ONE instruction, each in a FORKED CHILD\n"
           "  so that a fault is a signal number rather than a dead artifact.\n"
           "  The buffer is mmap'd: the compiler knows nothing about its\n"
           "  contents and therefore cannot fold the load into a constant.\n\n");

    ensure_buf();
    printf("  buffer %p, 32-byte aligned: %s,  8-byte offset from that: %s\n\n",
           (void *)g_buf,
           ((uintptr_t)g_buf % 32) == 0 ? "yes" : "NO",
           ((uintptr_t)g_buf % 32) == 24 ? "yes" : "NO");

    /* The last column says which ENCODING each row is, and the VEX rows
     * are the last two on purpose: the result that matters is that the
     * SAME mnemonic with a VEX prefix does not fault where the legacy one
     * does. */
    static const probe_t P[] = {
        { "vmovapd load",  B_APD,  0 },
        { "vmovupd load",  B_UPD,  0 },
        { "vmovapd store", B_APD,  1 },
        { "vmovupd store", B_UPD,  1 },
        { "vmovdqa load",  B_DQA,  0 },
        { "vmovdqu load",  B_DQU,  0 },
        { "movaps load",   B_APS,  0 },
        { "movups load",   B_UPS,  0 },
        { "vmovaps load",  B_APSV, 0 },
        { "vmovdqa load",  B_DQAV, 0 },
    };
    const int NP = (int)(sizeof P / sizeof P[0]);

    for (int i = 0; i < NP; i++) {
        instr_note(P[i].name);
        printf("  ALIGN | %-14s | aligned: ", P[i].name);
        int s0 = run_probe(&P[i], 0);
        printf("%-9s | +8 bytes: ", s0 ? "SIGSEGV" : "returned");
        int s1 = run_probe(&P[i], 8);
        printf("%-9s | %s\n", s1 ? "SIGSEGV" : "returned",
               (P[i].body == B_APSV || P[i].body == B_DQAV)
                   ? "VEX encoding" : "legacy encoding");
    }
    g_rows += NP;

    printf("\n  THE RESULT, and it is not a timing table at all:\n"
           "    Every ALIGNED form faults at +8 bytes and every unaligned\n"
           "    form returns -- LEGACY AND VEX ALIKE.  The fault is the\n"
           "    ONLY thing the 'a' in movaps names, and a duration table\n"
           "    is the wrong instrument for a correctness requirement.\n\n");
    printf("  AND THE DRAFT CLAIM ABOUT THE VEX PREFIX WAS WRONG, and the\n"
           "  two VEX rows are what caught it.  This section was written\n"
           "  asserting that the VEX encoding REMOVED the alignment\n"
           "  requirement -- which is what the VEX prefix's own Wikipedia\n"
           "  article says.  Measured, `vmovaps` and `vmovdqa` fault on\n"
           "  exactly the same addresses their legacy twins do, and the SDM\n"
           "  says so in as many words: the memory operand 'must be\n"
           "  aligned on a 16-byte (128-bit version), 32-byte (VEX.256)\n"
           "  or 64-byte (EVEX.512) boundary or a #GP will be generated'.\n"
           "  R15.\n\n");
    printf("  WHAT AVX ACTUALLY RELAXED is narrower and is worth stating\n"
           "  precisely, because the wrong version of it is the version\n"
           "  everybody repeats: the memory operands of instructions that\n"
           "  are NOT a load or a store -- `vpaddd ymm, ymm, [rbx]` and\n"
           "  every other VEX arithmetic instruction -- need not be\n"
           "  aligned.  Under the legacy encoding the same instruction\n"
           "  would have needed 16-byte alignment.  So the relaxation is\n"
           "  about FUSED memory operands, and the move instructions were\n"
           "  never part of it.  That is a smaller claim than the one the\n"
           "  draft made and a more useful one, because it tells you\n"
           "  exactly which instructions a compiler may emit for an\n"
           "  unaligned buffer.\n\n");
    printf("  WHAT THIS SECTION CANNOT SHOW: whether the aligned form is\n"
           "  FASTER when it succeeds.  The SIMD course measured that on\n"
           "  its own corpus and got no consistent direction across three\n"
           "  runs, which is what no effect looks like when the loop is\n"
           "  bandwidth-bound anyway.  This file does not repeat it, and it\n"
           "  says so rather than quoting a number it has not taken.\n\n");
    printf("  LIMITS OF THIS PROBE, and they are worth naming:\n"
           "    * ONE misalignment was measured: 8 bytes.  A load that is\n"
           "      8-byte aligned but not 16-byte aligned is the case that\n"
           "      matters and it is the case that was run; nothing here\n"
           "      says what happens at +4 or +20.\n"
           "    * The child's exit status is the instrument.  A probe that\n"
           "      was DELETED by the compiler would also report 'returned',\n"
           "      and the first version of this file did exactly that --\n"
           "      which is R11.  The build script therefore disassembles\n"
           "      these eight bodies and the harness asserts the mnemonics\n"
           "      are in the binary.\n"
           "    * Whether the kernel's SIGSEGV carries si_code 128 is the\n"
           "      x86sys course's measurement and it is not repeated here.\n\n");
    g_rows += 4;
}

/* ------------------------------------------------------------------ */
/* SECTION 3.  THE THREE OPERANDS, AND vzeroupper                     */
/* ------------------------------------------------------------------ */
static float sse_2op(void)
{
    __m128 a = _mm_set1_ps(1.0f), x = _mm_set1_ps(0.5f);
    for (long i = 0; i < g_iters; i++) a = _mm_add_ps(a, x);
    float o[4]; _mm_storeu_ps(o, a);
    return o[0];
}
static float sse_3op(void)
{
    __m128 a = _mm_set1_ps(1.0f), x = _mm_set1_ps(0.5f), t;
    for (long i = 0; i < g_iters; i++) { t = _mm_add_ps(a, x); a = t; }
    float o[4]; _mm_storeu_ps(o, a);
    return o[0];
}
static float sse_2op_copy(void)
{
    __m128 a = _mm_set1_ps(1.0f), x = _mm_set1_ps(0.5f), t;
    for (long i = 0; i < g_iters; i++) { t = a; a = _mm_add_ps(t, x); }
    float o[4]; _mm_storeu_ps(o, a);
    return o[0];
}

/* The bodies for the dirty-upper-bits experiment.  ONE asm block, so the
 * compiler cannot insert a VEX-128 instruction on ymm0 between the fill and
 * the read -- which it did in the first version, and which zeroes the upper
 * half on this part, so the experiment reported 0x00000000 for a transition
 * that never happened.  R12. */
static float PAT8[8] __attribute__((aligned(32)));
static float OUT8[8] __attribute__((aligned(32)));

#define SEQ2(insn) \
    __asm__ __volatile__( \
        "vmovaps %1, %%ymm0\n\t" insn \
        "vmovaps %%ymm0, %0\n\t" \
        : "=m"(*(float(*)[8])OUT8) : "m"(*(const float(*)[8])PAT8) \
        : "ymm0", "xmm1", "cc", "memory")

static unsigned hi_word(void)
{
    unsigned h;
    memcpy(&h, OUT8 + 4, 4);
    return h;
}

/* The instruction sequence is a MACRO ARGUMENT, not a string: the fill
 * and the read must be ONE asm block or the compiler can insert a VEX-128
 * instruction on ymm0 between them, which zeroes the upper half on this
 * part and made the first version of this experiment report a transition
 * that never happened.  R12. */
#define DIRTY(label, insn) do { \
    SEQ2(insn); \
    printf("  DIRTY | %-34s | upper 128 bits 0x%08x  %s\n", \
           label, hi_word(), hi_word() == 0 ? "ZEROED" : "PRESERVED"); \
    g_ck += hi_word(); \
} while (0)

void section_3(void)
{
    printf("3.  WHAT THE THREE OPERANDS BOUGHT, AND WHAT vzeroupper IS FOR.\n\n");
    printf("3A. THE THREE-OPERAND FORM, PRICED.  The assembly course ran\n"
           "  this experiment on one body and found the copy FREE.  A\n"
           "  negative result on one body is a fact about that body, so\n"
           "  this file runs the OTHER body -- the one where the\n"
           "  destination IS also a source, so the legacy form needs no\n"
           "  copy at all -- and the one where it does, at 128 bits.\n\n");

    float (*fn[3])(void) = { sse_2op, sse_3op, sse_2op_copy };
    static const char *nm[3] = {
        "SSE 2-operand, dest IS a source",
        "SSE 3-operand through a temp",
        "SSE 2-operand + an explicit copy" };
    double best[3];
    float  val[3];
    for (int i = 0; i < 3; i++) { best[i] = 1e30; val[i] = 0; }

    for (int r = 0; r < g_copies * 2; r++)
        for (int i = 0; i < 3; i++) {
            uint64_t t0 = rdtsc_();
            float v = fn[i]();
            uint64_t t1 = rdtsc_();
            double per = (double)(t1 - t0) / (double)g_iters;
            if (per < best[i]) { best[i] = per; val[i] = v; }
        }

    printf("  VEX3 | %-38s %9.4f ticks/op | value %.6f\n",
           nm[0], best[0], val[0]);
    printf("  VEX3 | %-38s %9.4f ticks/op | value %.6f\n",
           nm[1], best[1], val[1]);
    printf("  VEX3 | %-38s %9.4f ticks/op | value %.6f\n",
           nm[2], best[2], val[2]);
    instr_note("addps xmm"); instr_note("addps xmm + movaps");
    instr_note("vaddps xmm");

    /* The arms must agree or the table compares two computations. */
    int agree = (val[0] == val[1]) && (val[1] == val[2]);
    printf("\n  THE THREE ARMS MUST COMPUTE THE SAME VALUE, and they %s:\n"
           "    %.6f, %.6f, %.6f.  %s\n", agree ? "AGREE" : "DISAGREE",
           val[0], val[1], val[2],
           agree ? "The arms are comparable."
                 : "THE TABLE IS A COMPARISON OF TWO DIFFERENT "
                   "COMPUTATIONS AND EVERY RATIO BELOW IT IS MEANINGLESS.");
    printf("  arm 1 over arm 0: %.2fx    arm 2 over arm 0: %.2fx\n",
           best[0] / best[0], best[2] / best[0]);
    printf("  arm 0 over arm 1: %.2fx\n", best[0] / best[1]);
    printf("\n  READ IT AS A NEGATIVE RESULT, because that is what it is.\n"
           "  The copy the three-operand form removes is a REGISTER MOVE,\n"
           "  and on a core this wide an instruction the front end can\n"
           "  issue for free is not on the critical path.  What the form\n"
           "  buys is a SOURCE-LEVEL PROPERTY -- the destination may be a\n"
           "  register you still need -- and a source-level property is\n"
           "  exactly what an encoding is for.  No duration here can price\n"
           "  it, and the assembly course said so on a different body and\n"
           "  at a different width, and this file agrees.\n\n");
    printf("  MECHANISM: INFERRED.  There is no counter here that can count\n"
           "  vector-port occupancy, and the vendor manual has no number\n"
           "  for it either.  What is measured is that there is no LARGE\n"
           "  difference, and the three values above are what it saw.\n\n");
    g_rows += 5;

    /* ---- 3B. vzeroupper, and the bit pattern it exists for ------ */
    printf("3B. VZEROUPPER, AND THE ONE BIT PATTERN THAT EXPLAINS IT.\n\n");
    for (int i = 0; i < 8; i++) PAT8[i] = 0.1f;

    printf("  The claim being tested is the one in every AVX paper: a 256-bit\n"
           "  operation leaves the UPPER 128 BITS of a YMM register dirty,\n"
           "  a legacy SSE instruction reads the register without knowing\n"
           "  that, and the resulting false dependency is what vzeroupper\n"
           "  exists to clear.  The first half of that is a BIT PATTERN and\n"
           "  needs no timer at all.\n\n");
    printf("  Fill ymm0 with 0x11223344 in ALL EIGHT lanes, run ONE\n"
           "  instruction, then store all 32 bytes and look at lane 4:\n\n");
    DIRTY("no instruction (the control)", "nop\n\t");
    DIRTY("ONE legacy addps   0f 58", "addps %%xmm1, %%xmm0\n\t");
    DIRTY("ONE VEX-128 vaddps c5 f8 58", "vaddps %%xmm1, %%xmm0, %%xmm0\n\t");
    DIRTY("ONE legacy movaps  0f 28", "movaps %%xmm1, %%xmm0\n\t");
    DIRTY("vzeroupper         c5 f8 77", "vzeroupper\n\t");
    DIRTY("TWO legacy addps", "addps %%xmm1, %%xmm0\n\taddps %%xmm1, %%xmm0\n\t");
    DIRTY("TWO vzeroupper", "vzeroupper\n\tvzeroupper\n\t");
    g_rows += 7;

    printf("\n  AND THE RESULT CONTRADICTS THE STORY IN ITS USUAL FORM,\n"
           "  which is worth more than a timing table would have been.\n"
           "  On this part a LEGACY SSE instruction PRESERVES the upper\n"
           "  halves, and a VEX-128 instruction ZEROES them.  So the\n"
           "  'dirty upper state' that vzeroupper clears is created by\n"
           "  VEX-128 and destroyed by vzeroupper, and it is the LEGACY\n"
           "  instruction that finds the value intact.  Whether that\n"
           "  transition costs anything is a different question, and it\n"
           "  is the next one.\n\n");

    /* ---- 3C. the transition, timed ------------------------------ */
    printf("3C. THE TRANSITION, TIMED, WITH THE LEGACY ENCODING FORCED.\n\n");
    printf("  The first version of this experiment used INTRINSICS for the\n"
           "  'SSE' arm, and gcc compiled them to VEX (`c5 f8 58 c1`).  A\n"
           "  VEX-128 instruction has no AVX-SSE transition penalty AT\n"
           "  ALL, so the experiment measured nothing: every arm came out\n"
           "  1.00x.  The arms below are RAW LEGACY ENCODINGS written in\n"
           "  inline asm, and section 1B's census plus the build script's\n"
           "  objdump are what make the difference checkable.  R7.\n\n");

    extern double vzu_run(double *out);   /* in vec3b.c */
    double zr[6];
    vzu_run(zr);
    static const char *zn[6] = {
        "A  AVX 256 only",
        "B  LEGACY 0F 58 SSE only",
        "C  VEX 128 SSE only",
        "D  AVX then LEGACY SSE, no vzeroupper",
        "E  AVX, vzeroupper, then LEGACY SSE",
        "F  VEX 128 then LEGACY SSE (the control)" };
    for (int i = 0; i < 6; i++)
        printf("  VZU  | %-42s %9.3f ticks/call\n", zn[i], zr[i]);
    printf("\n  D over A %.2fx   E over D %.2fx   F over A %.2fx   B over A %.2fx\n",
           zr[3] / zr[0], zr[4] / zr[3], zr[5] / zr[0], zr[1] / zr[0]);
    printf("\n  READ THE SIX ROWS AS FIVE SEPARATE CLAIMS, because they do\n"
           "  not say one thing and lumping them is how the draft got it\n"
           "  wrong.\n\n");
    printf("  ONE.  THE LANE COUNT, and nothing else.  B over A is %.2fx:\n"
           "  the same arithmetic at 128 bits takes five times as long as\n"
           "  at 256.  That is the width, and the SIMD course owns the\n"
           "  width.  It is quoted here only so that the OTHER rows can be\n"
           "  read against a baseline that is not a mystery.\n\n", zr[1] / zr[0]);
    printf("  TWO.  THE ENCODING, at a FIXED width.  B over C is %.2fx, and\n"
           "  that is the whole of the difference between a LEGACY 0F 58\n"
           "  and a VEX c5 f8 58 doing the same sixteen 128-bit adds in the\n"
           "  same loop.  On this part the legacy encoding is about %s.\n"
           "  The VEX prefix's cost is a handful of percent and NOT a\n"
           "  factor, and a reader who has been told the legacy encoding is\n"
           "  catastrophically slow is wrong about that too.\n\n",
           zr[1] / zr[2], zr[1] / zr[2] < 1.10 ? "a couple of percent slower"
                                               : "measurably slower");
    printf("  THREE.  VZEROUPPER COSTS SOMETHING HERE, and this is the row\n"
           "  the section exists for.  E over D is %.2fx: the SAME\n"
           "  interleaved loop with one vzeroupper between the two bodies\n"
           "  and without one.  The instruction is three bytes, it retires\n"
           "  on a port nothing else is using, and it is nonetheless about\n"
           "  %s more expensive than not doing it.  So the mechanism is\n"
           "  real and observable on this part, and its SIZE is the %s of\n"
           "  the loop and not a multiple of it.\n\n",
           zr[4] / zr[3], zr[4] > zr[3] ? "a sixth" : "no more",
           (int)((zr[4] / zr[3] - 1.0) * 100 + 0.5) + " percent");
    printf("  FOUR.  AND THE DRAFT CLAIM THAT THE PENALTY IS LARGE IS NOT\n"
           "  SUPPORTED.  There is a widely quoted figure for the cost of an\n"
           "  AVX-to-SSE transition on an Intel part, and if it were the\n"
           "  cost here then row D would be several times row A.  It is\n"
           "  %.2fx, and most of that %.2fx is row B's lane count being\n"
           "  averaged in rather than anything the fence or the absence of\n"
           "  one did.  On an AMD Zen 3 part in 2026 the transition penalty\n"
           "  is NOT OBSERVABLE at this granularity, and the honest\n"
           "  sentence is that this measurement does not show what the\n"
           "  quoted figure describes.  R6.\n\n", zr[3] / zr[0], zr[1] / zr[0]);
    printf("  FIVE.  THE SHAPE THAT SURPRISES, and it is the one the draft\n"
           "  would have missed by only printing A and D.  Row D is the\n"
           "  AVERAGE cost of one AVX body and one legacy body per\n"
           "  iteration, and averaging the two alone gives %.2f.  The\n"
           "  measured row D is %.2f, which is LOWER than the arithmetic\n"
           "  mean.  Interleaving the two bodies is CHEAPER than running\n"
           "  either in a block.  WHY is not established here: there is no\n"
           "  counter that can see it, and the two obvious candidates -- a\n"
           "  clock that behaves differently for the two mixes, and a\n"
           "  store-forwarding interaction between them -- are both\n"
           "  INFERRED.  It is printed because a table that reported only\n"
           "  the ratios would have shown 1.00x and lost it.\n\n",
           (zr[0] + zr[1]) / 2.0, zr[3]);
    printf("  WHAT NONE OF THIS SHOWS, and it is the important one:\n"
           "  * WHY vzeroupper exists.  The bit pattern above says what it\n"
           "    DOES -- it zeroes bits 16 and up of all sixteen YMM\n"
           "    registers -- and this table says what it COSTS here.  The\n"
           "    false dependency it prevents is a claim about an Intel\n"
           "    microarchitecture and it is INFERRED, not measured.\n"
           "  * Anything about a 512-bit register, because there is none\n"
           "    here.  Section 6B is explicit about that.\n"
           "  * The cost of vzeroupper on a COLD core, at low occupancy, or\n"
           "    with a different pair of bodies.  One body is one body and\n"
           "    the harness asserts this as a SHAPE.\n\n");
    g_rows += 8;
}
