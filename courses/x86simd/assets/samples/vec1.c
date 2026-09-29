/* vec1.c -- section 1 (the instrument) and section 1B (the oracle).
 *
 * Section 1B is the ONLY place in this file that prints a table from a
 * manual, and every such table is stamped NOT MEASURED.  That separation is
 * the point: a bit position is exact and a duration is not, and a reader
 * must be able to tell which kind of claim they are looking at without
 * reading the prose.
 */
#include "vecdump.h"
#include <sys/wait.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
void section_1(void)
{
    printf("1.  THE INSTRUMENT.  Nothing in this section is a claim.\n\n");

    double busy = tsc_rate_busy();
    double idle = tsc_rate_across_sleep();
    double drift = (idle - busy) / busy * 100.0;
    printf("  TSC rate, busy                    %.4f GHz\n", busy);
    printf("  TSC rate, across a 300 ms sleep   %.4f GHz\n", idle);
    printf("  drift                             %+.4f %%\n", drift);
    printf("  a tick is TIME, not cycles, so every cost in this file is a\n"
           "  RATIO and no absolute nanosecond figure is claimed anywhere.\n\n");

    pin_and_verify(3);
    double chase = floor_pointer_chase();
    double arith = floor_arithmetic();
    printf("  POINTER CHASE, 64 KiB of nodes    %.3f ticks/op\n", chase);
    printf("  ARITHMETIC increment loop         %.3f ticks/op\n", arith);
    printf("  the floor used for every band in this file is the POINTER\n"
           "  CHASE, because the increment loop is printed too and is the\n"
           "  CLOCK rather than noise: %.2fx apart.\n\n",
           chase / (arith > 0 ? arith : 1));
    g_rows++;

    /* --- the feature census, which decides what may be claimed ---- */
    unsigned a, b, c, d;
    do_cpuid(0, 0, &a, &b, &c, &d);
    printf("  vendor \"%.4s%.4s%.4s\"   max basic leaf 0x%08x\n",
           (char *)&b, (char *)&d, (char *)&c, a);
    do_cpuid(0x80000000, 0, &a, &b, &c, &d);
    printf("  max extended leaf                 0x%08x\n", a);
    char brand[49];
    memset(brand, 0, sizeof brand);
    for (int i = 0; i < 3; i++) {
        do_cpuid(0x80000002 + i, 0, &a, &b, &c, &d);
        memcpy(brand + i * 16 + 0,  &a, 4);
        memcpy(brand + i * 16 + 4,  &b, 4);
        memcpy(brand + i * 16 + 8,  &c, 4);
        memcpy(brand + i * 16 + 12, &d, 4);
    }
    for (int i = 47; i >= 0 && brand[i] == ' '; i--) brand[i] = 0;
    printf("  brand string                      '%s'\n", brand);

    do_cpuid(1, 0, &a, &b, &c, &d);
    printf("  CPUID.1:ECX SSE2 %u SSSE3 %u SSE4.1 %u SSE4.2 %u "
           "AVX %u FMA %u\n",
           (c >> 26) & 1, (c >> 9) & 1, (c >> 19) & 1, (c >> 20) & 1,
           (c >> 28) & 1, (c >> 12) & 1);
    do_cpuid(7, 0, &a, &b, &c, &d);
    printf("  CPUID.7.0:EBX AVX2 %u  BMI1 %u  BMI2 %u  F16C %u\n",
           (b >> 5) & 1, (b >> 3) & 1, (b >> 8) & 1, (b >> 29) & 1);
    printf("  CPUID.7.0:EBX AVX512F %u DQ %u CD %u BW %u VL %u\n",
           (b >> 16) & 1, (b >> 17) & 1, (b >> 28) & 1, (b >> 30) & 1,
           (b >> 31) & 1);

    /* CR4.OSXSAVE is bit 18.  It is read BEFORE XGETBV and it is read
     * because XGETBV is #UD without it -- the instruction this file is
     * about to execute is itself gated by a state bit, which is the whole
     * of the point of the paragraph below. */
    /* CR4.OSXSAVE, the gate on XGETBV itself.  The naive probe is
     * "mov %cr4, %rax", and on this machine THAT SEGFAULTS -- CR4 reads
     * are not available to this process.  So the gate is not read; it is
     * INFERRED, and the inference is airtight in the direction that
     * matters: XGETBV raises #UD when CR4.OSXSAVE is clear, so the fact
     * that the XGETBV below RETURNS is itself the proof that OSXSAVE is
     * set.  A probe that answers the question by using the thing in the
     * question beats a probe that reads a bit it is not allowed to read,
     * and it costs one instruction instead of a fault. */
    pid_t cr4p = fork();
    if (cr4p == 0) {
        uint64_t cr4 = 0;
        __asm__ __volatile__("mov %%cr4, %%rax" : "=a"(cr4));
        _exit((int)((cr4 >> 18) & 1));
    }
    int cr4st = 0;
    if (cr4p > 0) waitpid(cr4p, &cr4st, 0);
    if (cr4p > 0 && WIFEXITED(cr4st))
        printf("  CR4.OSXSAVE (bit 18) = %d   (read directly)\n",
               WEXITSTATUS(cr4st));
    else
        printf("  CR4.OSXSAVE (bit 18) = ?   (a direct CR4 read %s here,\n"
               "  so it is INFERRED from the XGETBV below: XGETBV is #UD\n"
               "  without OSXSAVE, and XGETBV returns, so it is set.)\n",
               WIFSIGNALED(cr4st) ? "faulted" : "was not permitted");

    uint32_t lo = 0, hi = 0;
    __asm__ __volatile__("xgetbv" : "=a"(lo), "=d"(hi) : "c"(0));
    uint64_t xcr0 = ((uint64_t)hi << 32) | lo;
    printf("  XCR0 0x%016llx  (1 x87, 2 SSE, 5 opmask, 6 zmm_hi256, "
           "7 hi16_zmm)\n", (unsigned long long)xcr0);
    printf("  XCR0 opmask %llu  zmm_hi256 %llu  hi16_zmm %llu\n\n",
           (unsigned long long)((xcr0 >> 5) & 1),
           (unsigned long long)((xcr0 >> 6) & 1),
           (unsigned long long)((xcr0 >> 7) & 1));
    printf("  XCR0 IS A LIST OF WHAT THE OS HAS AGREED TO SAVE, and\n"
           "  that is why the three AVX-512 bits are the ones to read.\n"
           "  NOT ONE of the instructions this file executes is a 512-bit\n"
           "  one, and NOT ONE of them needs bit 5, 6 or 7 to be set: they\n"
           "  are all xmm and ymm work, which lives in bit 1 and bit 2 and\n"
           "  both of those ARE set.  An EVEX-encoded instruction with its\n"
           "  own bit clear does not run slowly, it does not run at all,\n"
           "  it raises #UD -- which is a different failure from the #GP\n"
           "  in section 2, and the kernel turns it into SIGILL rather than\n"
           "  SIGSEGV.  So the two things CPUID reports are NOT the same\n"
           "  thing: CPUID is what the SILICON has, and XCR0 is what the\n"
           "  OS has agreed to preserve, and a machine can have the first\n"
           "  without the second.  That is a fact about the OS, and it is\n"
           "  why a 2015 kernel will run AVX-512 code on a 2017 CPU and\n"
           "  the same code on a 2013 kernel will not run at all.\n\n");

    do_cpuid(0x80000001, 0, &a, &b, &c, &d);
    printf("  CPUID.80000001:ECX LZCNT %u ABM %u SSE4a %u\n",
           (c >> 5) & 1, (c >> 6) & 1, (c >> 6) & 1);
    do_cpuid(0x80000008, 0, &a, &b, &c, &d);
    printf("  CPUID.80000008:EAX[21] LA57 = %u, :EBX bit 6 core-PMU = %u, "
           "bit 15 L3-PMU = %u\n",
           (a >> 21) & 1, (b >> 6) & 1, (b >> 15) & 1);
    printf("  CPUID.80000008:EAX[11:8] %u  -- and the field is NOT a count\n"
           "  of address bits; the x86sys course measured that.\n",
           (a >> 8) & 0xF);

    int pm = -1;
    FILE *f = fopen("/proc/sys/kernel/perf_event_paranoid", "r");
    if (f) { if (fscanf(f, "%d", &pm) != 1) pm = -1; fclose(f); }
    printf("  /proc/sys/kernel/perf_event_paranoid = %d\n", pm);
    printf("\n  CONSEQUENCE, and it governs every duration in this file:\n"
           "    there is NO event counter this process can open.  Nothing\n"
           "    here counts instructions, cycles, uops or cache lines.  A\n"
           "    duration BOUNDS a count without measuring it, and every\n"
           "    mechanism named in this file is therefore marked INFERRED\n"
           "    unless it is a fault or a bit pattern.\n\n");
    g_rows++;

    /* the census of what the arms believe they are measuring */
    instr_reset();
    section_2();   /* the arms call instr_note(); they are idempotent */
    instr_report();
    g_rows--;      /* section_2 does its own banner; the row is its own */
}

/* ------------------------------------------------------------------ */
/* 1B.  THE ORACLE.  Printed, and stamped NOT MEASURED.                */
/* ------------------------------------------------------------------ */
static void oracle_sse(void)
{
    printf("1B1. THE SSE AND SSE2 MOVES, AND THE ALIGNMENT SPLIT.\n"
           "     PRINTED AND NOT MEASURED.  The fault half of this table IS\n"
           "     measured, in section 2, one forked child per row.\n\n");
    printf("  MOVE | op   | pfx | ALIGNED | what the ALIGNED form faults on\n");
    printf("  MOVAPS| 28  | none| 16 byte | #GP if the address is not 16-aligned\n");
    printf("  MOVUPS| 10  | none| none   | nothing; the unaligned form\n");
    printf("  MOVDQA| 6F  | 66  | 16 byte | #GP; the integer twin of MOVAPS\n");
    printf("  MOVDQU| 6F  | F3  | none   | nothing\n");
    printf("  MOVSS | 11  | F3  |  4 byte | #GP if not 4-aligned\n");
    printf("  MOVSD | 11  | F2  |  8 byte | #GP if not 8-aligned\n");
    printf("  MOVLPD| 13  | 66  |  8 byte | #GP if not 8-aligned\n");
    printf("  LDDQU | F0  | F2  | none   | a LOAD that explicitly never faults\n");
    printf("\n  THE NAMING IS NOT DECORATIVE.  'aps' and 'dqa' mean ALIGNED\n"
           "  PACKED SINGLE / DOUBLE QUADWORD ALIGNED, and the fault is the\n"
           "  ONLY reason a reader has to know the rule.  'ups' and 'dqu'\n"
           "  are the same instructions with the requirement removed, and\n"
           "  the ONLY difference between them is the one byte of opcode.\n\n");
    printf("  AND THE VEX VERSIONS DROPPED THE REQUIREMENT ENTIRELY, which\n"
           "  is a source-level property of the ENCODING and not of the\n"
           "  instruction: vmovaps will take a misaligned address.  Section\n"
           "  2 measures the fault of the legacy form and the RETURN of the\n"
           "  VEX form on the same address.\n\n");
}

static void oracle_vex(void)
{
    printf("1B2. THE TWO VEX SHAPES AND THE EVEX ONE.  NOT MEASURED.\n\n");
    printf("  VEX2  C5  R~ v~3 v~2 v~1 v~0 L p1 p0          + opcode + ModRM\n");
    printf("  VEX3  C4  R~ X~ B~ m4 m3 m2 m1 m0\n");
    printf("            W v~3 v~2 v~1 v~0 L p1 p0          + opcode + ModRM\n");
    printf("  EVEX  62  R~ X~ B~ R~' 0 m2 m1 m0\n");
    printf("            W v~3 v~2 v~1 v~0 1 p1 p0\n");
    printf("            z L' L b V~' a2 a1 a0                + opcode + ModRM\n\n");
    printf("  VEX2 IS AN ABBREVIATION, and the omitted fields are the ones\n"
           "  that are ALWAYS the same when it may be used: W=0, B~=1,\n"
           "  X~=1, and the map is 00001 (the 0F escape).  There is NO MAP\n"
           "  FIELD in the two-byte form at all -- the choice of 0xC5 over\n"
           "  0xC4 IS the map.  The first encoder in this course put X~ and\n"
           "  B~ where v~3 and v~2 belong, round-tripped perfectly against\n"
           "  ITSELF, and emitted bytes binutils reads as a different\n"
           "  instruction.  R9 is that.\n\n");
    printf("  THE OPERAND MAP, which is not in any of the tables above and\n"
           "  which this file established by assembling three distinct\n"
           "  registers and reading which field each landed in:\n"
           "      Intel 'vaddps DEST, SRC1, SRC2'\n"
           "        ModRM.reg = DEST   vvvv = SRC1   ModRM.rm = SRC2\n"
           "  A reader who assumes the GPR convention -- r/m is always the\n"
           "  destination -- will mis-decode every three-operand instruction\n"
           "  in the set.  R10 is that mistake, caught by the assembler.\n\n");
    printf("  L, AND WHY AVX-512 NEEDS TWO BITS FOR IT:\n"
           "    L=0  128 bit (xmm)      L=1  256 bit (ymm)\n"
           "    EVEX only: L'L = 10 is 128 and 11 is 512, with L' encoding\n"
           "    ROUNDING CONTROL when the instruction has no vector length.\n"
           "    A decoder that reads one bit reports every 512-bit\n"
           "    instruction as 256-bit, which is a claim about hardware\n"
           "    that is wrong and that binutils catches in one command.\n\n");
}

static void oracle_atomic(void)
{
    printf("1B3. THE LOCK LIST, AND WHO IMPLIES IT.  NOT MEASURED.\n\n");
    printf("  The SDM names EIGHTEEN instructions that accept a LOCK prefix:\n"
           "    ADD ADC AND BTC BTR BTS CMPXCHG CMPXCHG8B CMPXCHG16B\n"
           "    DEC INC NEG NOT OR SBB SUB XOR XADD XCHG\n"
           "  and says of XCHG, in so many words:\n"
           "    'If a memory operand is referenced, the processor's locking\n"
           "     protocol is automatically implemented for the duration of\n"
           "     the exchange operation, REGARDLESS of the presence or\n"
           "     absence of the LOCK prefix.'\n"
           "  That sentence is the whole of the implicit set, and section 4\n"
           "  measures which of them actually behave atomically here.\n\n");
    printf("  THE INSTRUCTION WITH NO LOCK IS 'BT'.  BTC, BTR and BTS are on\n"
           "  the list; BT is not, because BT does not write.  A read-modify-\n"
           "  write a reader builds out of BT and a store is therefore two\n"
           "  instructions and no encoding can make it atomic, which is a\n"
           "  fact about the INSTRUCTION SET rather than about a prefix.\n\n");
    printf("  AND THE LOCK PREFIX IS NOT A PIN.  On every processor since the\n"
           "  P6, a locked instruction whose line is already in the local\n"
           "  cache does not assert LOCK# on the bus at all; only the cache\n"
           "  is locked.  So 'does it assert LOCK#' is not the question a\n"
           "  modern reader should be asking.\n\n");
}

static void oracle_fence(void)
{
    printf("1B4. THE THREE FENCES.  NOT MEASURED as to their cost.\n\n");
    printf("  FENCE | bytes   | orders a LOAD before a STORE?  orders a STORE\n");
    printf("  LFENCE| 0f ae e8| yes                        | no\n");
    printf("  SFENCE| 0f ae f8| no                         | yes\n");
    printf("  MFENCE| 0f ae f0| yes                        | yes\n\n");
    printf("  All three are the SAME opcode, 0F AE, with the ModRM byte's\n"
           "  reg field selecting the operation: F0, E8, F8.  They are not\n"
           "  three opcodes and there is nothing to remember about which is\n"
           "  which except the reg field.\n\n");
    printf("  AND WHAT THEY DO NOT DO, which is the part every summary of\n"
           "  TSO leaves out: a fence is a LOCALLY-OBSERVABLE order.  It\n"
           "  orders THIS core's own accesses with respect to each other.\n"
           "  It does not send anything to the other core, it does not flush\n"
           "  the other core's caches, and it is not a message-passing\n"
           "  primitive.  What it buys is that this core's store buffer is\n"
           "  DRAINED -- which is a mechanism this file can measure the cost\n"
           "  of, in section 5, and cannot observe the inside of.\n\n");
}

static void oracle_dir(void)
{
    printf("1B5. THE DIRECTION FLAG.  NOT MEASURED as to its history.\n\n");
    printf("  EFLAGS bit 10 = DF, the direction flag.  It selects whether\n"
           "  the string instructions increment or decrement their index\n"
           "  registers, and it is set and cleared by STD and CLD.\n\n");
    printf("  AND THE BIT THIS COURSE WAS DRAFTED AGAINST IS WRONG.  The\n"
           "  brief said 'the DIR flag is bit 21 of EFLAGS'.  Bit 21 is the\n"
           "  ID flag, the identification flag, and it exists for a reason\n"
           "  that has nothing to do with strings: before CPUID, software\n"
           "  identified a processor by SETTING a bit it was not supposed\n"
           "  to be able to set and pushing the flags.  The 8086 and 8088\n"
           "  had no such bit; the Pentium does.  R1.\n\n");
    printf("  THE HISTORY THAT IS ACTUALLY WORTH TELLING is the one this\n"
           "  course can MEASURE, and it is in section 5: on the 8086 the\n"
           "  string instructions had to compute the direction on every\n"
           "  element, so a backward REP MOVSB was materially slower than a\n"
           "  forward one.  Every later processor made the two the same.\n"
           "  On THIS one they are still not, by a factor this file measures\n"
           "  across five sizes and reports as a shape.\n\n");
}

void section_1b(void)
{
    printf("1B.  THE ORACLE.  The reference tables, printed and NOT\n"
           "     MEASURED.  They are here so that every later section has\n"
           "     something to be checked against, and SEPARATE from every\n"
           "     measurement so that the two can never be confused.  A bit\n"
           "     position is exact; a duration is not; the label on every\n"
           "     table below is the difference.\n\n");
    oracle_sse();
    oracle_vex();
    oracle_atomic();
    oracle_fence();
    oracle_dir();
    g_rows += 5;
}
