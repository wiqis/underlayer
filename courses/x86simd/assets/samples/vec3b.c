/* vec3b.c -- the bodies for the vzeroupper timing table in section 3C.
 *
 * The 'SSE' arm is a RAW LEGACY ENCODING.  An intrinsics version is
 * compiled by gcc to VEX, and a VEX-128 instruction has no AVX-SSE
 * transition penalty at all, so the first version of this experiment
 * measured nothing.  See R13.
 */
#include "vecdump.h"
#include <immintrin.h>

#define NOINL __attribute__((noinline))

static double AA[8]  __attribute__((aligned(64)));
static float  FF[32] __attribute__((aligned(64)));
static volatile float g_sink_f;

/* 256-bit: leaves the upper halves of ymm0..ymm7 dirty */
static NOINL float avx_body(void)
{
    __m256 a = _mm256_set1_ps(1.0f), x = _mm256_set1_ps(0.5f), t;
    for (int i = 0; i < 8; i++) { t = _mm256_add_ps(a, x); a = t; }
    float o[8];
    _mm256_storeu_ps(o, a);
    return o[0];
}

/* 128-bit, LEGACY 0F 58, written out byte for byte */
static NOINL float sse_legacy(void)
{
    __asm__ __volatile__(
        "movaps 0(%1), %%xmm0\n\t"      /* 0f 28 */
        "movaps 16(%1), %%xmm1\n\t"
        "mov $8, %%ecx\n\t"
        "1:\n\t"
        "addps %%xmm1, %%xmm0\n\t"      /* 0f 58, TWO operands */
        "addps %%xmm1, %%xmm0\n\t"
        "sub $1, %%ecx\n\t"
        "jnz 1b\n\t"
        "movaps %%xmm0, (%0)\n\t"       /* 0f 29 */
        : : "r"(&FF[0]), "r"(&FF[16]) : "xmm0", "xmm1", "ecx", "memory");
    return FF[0];
}

/* 128-bit, VEX.  The CONTROL: same arithmetic, different encoding. */
static NOINL float sse_vex(void)
{
    __asm__ __volatile__(
        "vmovaps 0(%1), %%xmm0\n\t"
        "vmovaps 16(%1), %%xmm1\n\t"
        "mov $8, %%ecx\n\t"
        "1:\n\t"
        "vaddps %%xmm1, %%xmm0, %%xmm0\n\t"
        "vaddps %%xmm1, %%xmm0, %%xmm0\n\t"
        "sub $1, %%ecx\n\t"
        "jnz 1b\n\t"
        "vmovaps %%xmm0, (%0)\n\t"
        : : "r"(&FF[0]), "r"(&FF[16]) : "xmm0", "xmm1", "ecx", "memory");
    return FF[0];
}

static NOINL void vzu(void)
{
    __asm__ __volatile__("vzeroupper" ::: "ymm0", "ymm1", "memory");
}

/* Reset the scratch array between EVERY arm.  A first version inherited
 * the previous arm's FF[] and the arms were not comparing the same thing. */
static void reset_ff(void)
{
    for (int i = 0; i < 32; i++) FF[i] = 1.0f;
}

double vzu_run(double *out)
{
    long N = g_iters / 8;
    if (N < 16) N = 16;
    for (int i = 0; i < 8; i++) AA[i] = i;
    double best[6];
    for (int i = 0; i < 6; i++) best[i] = 1e30;
    double sink = 0;

    for (int r = 0; r < g_copies * 2; r++) {
        double t;
        uint64_t a, b;

        reset_ff();
        a = rdtsc_();
        for (long i = 0; i < N; i++) sink += avx_body();
        b = rdtsc_(); t = (double)(b - a) / N; if (t < best[0]) best[0] = t;

        reset_ff();
        a = rdtsc_();
        for (long i = 0; i < N; i++) sink += sse_legacy();
        b = rdtsc_(); t = (double)(b - a) / N; if (t < best[1]) best[1] = t;

        reset_ff();
        a = rdtsc_();
        for (long i = 0; i < N; i++) sink += sse_vex();
        b = rdtsc_(); t = (double)(b - a) / N; if (t < best[2]) best[2] = t;

        reset_ff();
        a = rdtsc_();
        for (long i = 0; i < N; i++) { sink += avx_body(); sink += sse_legacy(); }
        b = rdtsc_(); t = (double)(b - a) / (2 * N); if (t < best[3]) best[3] = t;

        reset_ff();
        a = rdtsc_();
        for (long i = 0; i < N; i++) { sink += avx_body(); vzu(); sink += sse_legacy(); }
        b = rdtsc_(); t = (double)(b - a) / (2 * N); if (t < best[4]) best[4] = t;

        reset_ff();
        a = rdtsc_();
        for (long i = 0; i < N; i++) { sink += sse_vex(); sink += sse_legacy(); }
        b = rdtsc_(); t = (double)(b - a) / (2 * N); if (t < best[5]) best[5] = t;
    }
    g_sink += (long)sink;
    g_ck  += (uint64_t)(sink * 1000.0);
    for (int i = 0; i < 6; i++) out[i] = best[i];
    instr_note("vaddps ymm"); instr_note("addps xmm 0F 58");
    instr_note("vaddps xmm c5 f8"); instr_note("vzeroupper");
    return sink;
}
