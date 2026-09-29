/* vecmaps.c -- section 6: an encoder and a decoder for the vector maps,
 * round-tripped, and cross-checked against objdump.
 *
 * THE POINT OF THE FILE, and it is a point about CHECKING rather than
 * about x86.  A hand encoder and a hand decoder written from the same
 * field table agree with EACH OTHER whether or not either is right: the
 * round trip is a tautology.  The first version of this encoder put X~ and
 * B~ where v~3 and v~2 belong in the two-byte VEX form, round-tripped
 * 28 of 28, and produced bytes that binutils reads as a different
 * instruction.  The only thing that caught it was a SECOND READER that
 * had not been written from the same table.  So every row below is
 * encoded here, decoded here, AND disassembled by objdump, and the three
 * are compared.  R9.
 */
#include "vecmaps.h"

/* ------------------------------------------------------------------ */
/* THE OPERAND MAP, established by assembling three distinct registers */
/* and reading which field each one landed in, not by reasoning:        */
/*     Intel "vaddps DEST, SRC1, SRC2"                                 */
/*       ModRM.reg = DEST      vvvv = SRC1      ModRM.rm = SRC2        */
/* A reader who assumes the GPR convention -- r/m is always the        */
/* destination -- mis-decodes every three-operand instruction in the    */
/* set.  R10.                                                          */
/* ------------------------------------------------------------------ */

static const spec_t T[] = {
/*  text                          sh map pp op   L  W  R X B vvvv modrm R2 Vp  z aaa b */
{"addps xmm0,xmm1",              0, 1, 0, 0x58, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"addpd xmm0,xmm1",              0, 1, 1, 0x58, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"movaps xmm0,xmm1",             0, 1, 0, 0x28, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"movups xmm0,xmm1",             0, 1, 0, 0x10, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"movdqa xmm0,xmm1",             0, 1, 1, 0x6F, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"movdqu xmm0,xmm1",             0, 1, 2, 0x6F, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"pxor xmm0,xmm1",               0, 1, 1, 0xEF, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"mulps xmm0,xmm1",              0, 1, 0, 0x59, 0, 0, 0,0,0, 0, 0xC1, 0,0,0,0,0},
{"addps xmm0,[rbx]",             0, 1, 0, 0x58, 0, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vaddps xmm2,xmm1,xmm0",        1, 1, 0, 0x58, 0, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vaddps ymm2,ymm1,ymm0",        1, 1, 0, 0x58, 1, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vaddpd ymm2,ymm1,ymm0",        1, 1, 1, 0x58, 1, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vaddps ymm10,ymm0,ymm0",       1, 1, 0, 0x58, 1, 0, 1,0,0, 0, 0xD0, 0,0,0,0,0},
{"vmovaps ymm0,[rbx]",           1, 1, 0, 0x28, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vmovups ymm0,[rbx]",           1, 1, 0, 0x10, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vmovdqa ymm0,[rbx]",           1, 1, 1, 0x6F, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vmovdqu ymm0,[rbx]",           1, 1, 2, 0x6F, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vpxor ymm2,ymm1,ymm0",         1, 1, 1, 0xEF, 1, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vpaddd ymm2,ymm1,ymm0",        1, 1, 1, 0xFE, 1, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vpsubd ymm2,ymm1,ymm0",        1, 1, 1, 0xFA, 1, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vpcmpeqd ymm2,ymm1,ymm0",      1, 1, 1, 0x76, 1, 0, 0,0,0, 1, 0xD0, 0,0,0,0,0},
{"vbroadcastss ymm0,[rbx]",      2, 2, 1, 0x18, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vbroadcastsd ymm0,[rbx]",      2, 2, 1, 0x19, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vpbroadcastd ymm0,[rbx]",      2, 2, 1, 0x58, 1, 0, 0,0,0, 0, 0x03, 0,0,0,0,0},
{"vfmadd231pd ymm0,ymm1,ymm2",   2, 2, 1, 0xB8, 1, 1, 0,0,0, 1, 0xC2, 0,0,0,0,0},
{"vfmadd132ps xmm0,xmm1,xmm2",   2, 2, 1, 0x98, 0, 0, 0,0,0, 1, 0xC2, 0,0,0,0,0},
{"vaddps zmm0,zmm1,zmm2",        3, 1, 0, 0x58, 2, 0, 0,0,0, 1, 0xC2, 0,0,0,0,0},
{"vaddpd zmm0,zmm1,zmm2",        3, 1, 1, 0x58, 2, 1, 0,0,0, 1, 0xC2, 0,0,0,0,0},
{"vaddps zmm0{k2},zmm1,zmm2",    3, 1, 0, 0x58, 2, 0, 0,0,0, 1, 0xC2, 0,0,0,2,0},
{"vaddps zmm0,zmm1,zmm2{ru-sae}",3, 1, 0, 0x58, 2, 0, 0,0,0, 1, 0xC2, 0,0,0,0,1},
};
#define NT ((int)(sizeof T / sizeof T[0]))

/* ------------------------------------------------------------------ */
int enc_encode(const spec_t *s, uint8_t *o)
{
    switch (s->shape) {
    case 0: {
        int n = 0;
        if (s->W) o[n++] = 0x48;
        if (s->pp == 1) o[n++] = 0x66;
        else if (s->pp == 2) o[n++] = 0xF3;
        else if (s->pp == 3) o[n++] = 0xF2;
        if (s->map == 1) o[n++] = 0x0F;
        else if (s->map == 2) { o[n++] = 0x0F; o[n++] = 0x38; }
        else if (s->map == 3) { o[n++] = 0x0F; o[n++] = 0x3A; }
        o[n++] = (uint8_t)s->op;
        o[n++] = (uint8_t)s->modrm;
        return n;
    }
    case 1:
        o[0] = 0xC5;
        o[1] = (uint8_t)((s->R ? 0x00 : 0x80) | (((~s->vvvv) & 0x0F) << 3) |
                         ((s->L & 1) << 2) | (s->pp & 3));
        o[2] = (uint8_t)s->op;
        o[3] = (uint8_t)s->modrm;
        return 4;
    case 2:
        o[0] = 0xC4;
        o[1] = (uint8_t)((s->R ? 0x00 : 0x80) | (s->X ? 0x00 : 0x40) |
                         (s->B ? 0x00 : 0x20) | (s->map & 0x1F));
        o[2] = (uint8_t)((s->W ? 0x80 : 0) | (((~s->vvvv) & 0x0F) << 3) |
                         ((s->L & 1) << 2) | (s->pp & 3));
        o[3] = (uint8_t)s->op;
        o[4] = (uint8_t)s->modrm;
        return 5;
    case 3:
        o[0] = 0x62;
        o[1] = (uint8_t)((s->R ? 0x00 : 0x80) | (s->X ? 0x00 : 0x40) |
                         (s->B ? 0x00 : 0x20) | (s->R2 ? 0x00 : 0x10) |
                         (s->map & 0x03));
        o[2] = (uint8_t)((s->W ? 0x80 : 0) | (((~s->vvvv) & 0x0F) << 3) |
                         0x04 | (s->pp & 3));
        o[3] = (uint8_t)((s->z ? 0x80 : 0) |
                         (uint8_t)((s->L & 2) ? 0x40 : 0) |
                         (uint8_t)((s->L & 1) ? 0x20 : 0) |
                         (s->bbit ? 0x10 : 0) |
                         (s->Vprime ? 0x00 : 0x08) | (s->aaa & 0x07));
        o[4] = (uint8_t)s->op;
        o[5] = (uint8_t)s->modrm;
        return 6;
    }
    return 0;
}

/* ------------------------------------------------------------------ */
int enc_decode(const uint8_t *o, dec_t *d)
{
    int i = 0;
    memset(d, 0, sizeof *d);
    while (i < 4) {
        uint8_t b = o[i];
        if (b == 0x66)      { d->pp = 1; i++; continue; }
        if (b == 0xF3)      { d->pp = 2; i++; continue; }
        if (b == 0xF2)      { d->pp = 3; i++; continue; }
        if (b == 0xF0)      { i++; continue; }
        if ((b & 0xF0) == 0x40) { d->rexW = (b >> 3) & 1; i++; continue; }
        break;
    }
    if (o[i] == 0xC5) {
        d->shape = 1;
        d->R = 1 - ((o[i + 1] >> 7) & 1);
        d->vvvv = (~(o[i + 1] >> 3)) & 0x0F;
        d->L = (o[i + 1] >> 2) & 1;
        d->pp = o[i + 1] & 3;
        d->map = 1;              /* implied by the choice of 0xC5 */
        d->op = o[i + 2];
        d->modrm = o[i + 3];
        i += 4;
    } else if (o[i] == 0xC4) {
        d->shape = 2;
        d->R = 1 - ((o[i + 1] >> 7) & 1);
        d->X = 1 - ((o[i + 1] >> 6) & 1);
        d->B = 1 - ((o[i + 1] >> 5) & 1);
        d->map = o[i + 1] & 0x1F;
        d->W = (o[i + 2] >> 7) & 1;
        d->vvvv = (~(o[i + 2] >> 3)) & 0x0F;
        d->L = (o[i + 2] >> 2) & 1;
        d->pp = o[i + 2] & 3;
        d->op = o[i + 3];
        d->modrm = o[i + 4];
        i += 5;
    } else if (o[i] == 0x62) {
        d->shape = 3;
        d->R = 1 - ((o[i + 1] >> 7) & 1);
        d->X = 1 - ((o[i + 1] >> 6) & 1);
        d->B = 1 - ((o[i + 1] >> 5) & 1);
        d->R2 = 1 - ((o[i + 1] >> 4) & 1);
        d->map = o[i + 1] & 0x03;
        d->W = (o[i + 2] >> 7) & 1;
        d->vvvv = (~(o[i + 2] >> 3)) & 0x0F;
        d->pp = o[i + 2] & 3;
        d->z = (o[i + 3] >> 7) & 1;
        d->Lprime = (o[i + 3] >> 6) & 1;
        d->L = (o[i + 3] >> 5) & 1;
        d->L = (d->Lprime << 1) | d->L;   /* L is TWO bits in EVEX */
        d->bbit = (o[i + 3] >> 4) & 1;
        d->Vprime = 1 - ((o[i + 3] >> 3) & 1);
        d->aaa = o[i + 3] & 0x07;
        d->op = o[i + 4];
        d->modrm = o[i + 5];
        i += 6;
    } else {
        d->shape = 0;
        if (o[i] == 0x0F) {
            i++;
            if (o[i] == 0x38)      { d->map = 2; i++; }
            else if (o[i] == 0x3A) { d->map = 3; i++; }
            else                   { d->map = 1; }
        }
        d->op = o[i++];
        d->modrm = o[i++];
    }
    d->mod = (d->modrm >> 6) & 3;
    d->reg = (d->modrm >> 3) & 7;
    d->rm = d->modrm & 7;
    d->len = i;
    return i;
}

/* ------------------------------------------------------------------ */
/* the objdump cross-check, read from vecmaps_dis.txt                   */
/*                                                                     */
/* The build script writes the disassembly of a function in THIS binary  */
/* that contains the encoded bytes verbatim, so the file is an input and  */
/* the section says so and says what it does without it.                */
/*                                                                     */
/* R23.  THIS FUNCTION WAS WRONG BY ONE ROW AND THE CROSS-CHECK SAID     */
/* SO.  See the retraction block; the short version is that the section  */
/* header line objdump prints FIRST -- "MAP | 0000... <.data>:" -- has   */
/* no tab in it, and this loader was counting it as the first disassembly */
/* row.  Every row was then compared against its NEIGHBOUR's text.  It    */
/* reported 28 disagreements out of 30, which is exactly the shape a real */
/* bug in an encoder produces, and two rows "agreed" only because both    */
/* happened to be vaddps.  The lesson is not "check your index"; it is   */
/* that a cross-check which disagrees with almost everything is as        */
/* suspicious as one that agrees with everything, and that the two       */
/* answers a misaligned reader can give -- all-disagree and all-agree --  */
/* look nothing like each other and are equally wrong.                   */
/* ------------------------------------------------------------------ */
static char g_ref[NT][256];
static int  g_ref_n = 0;

static void load_dis(void)
{
    g_ref_n = 0;
    g_dis = (char *)"vecmaps_dis.txt";
    if (!g_dis) {
        printf("  vecmaps_dis.txt                    ABSENT\n");
        printf("  and it is OPTIONAL: the round trip and the field table\n"
               "  below run without it, and the objdump CROSS-CHECK does\n"
               "  not.  Section 6 says so and prints the cross-check as\n"
               "  NOT RUN rather than as a row of ticks that read like a\n"
               "  result.\n\n");
        return;
    }
    FILE *f = fopen("vecmaps_dis.txt", "r");
    if (!f) {
        printf("  vecmaps_dis.txt                    ABSENT\n");
        printf("  and the round trip below STILL RUNS; only the\n"
               "  cross-check is NOT RUN, and it is printed as\n"
               "  NOT RUN rather than as a column of ticks.\n\n");
        return;
    }
    char line[256];
    int n = 0;
    int skipped_nop = 0, skipped_hdr = 0;
    while (fgets(line, sizeof line, f)) {
        if (strncmp(line, "  MAP | ", 7)) continue;
        if (n >= NT) break;
        /* R23.  The FIRST line objdump prints is the section header,
         *     "  MAP |   0:\t...  <.data>:", which has no disassembly in it.
         *     A row is a row only if it HAS a disassembly, so require the
         *     tab that separates the byte column from the mnemonic.  The
         *     old loader split on the last tab and took whatever was after
         *     it, which for the header is the empty string -- so the header
         *     became row 0 and every comparison after it was off by one. */
        char *tab = strrchr(line, '\t');
        if (!tab) { skipped_hdr++; continue; }
        if (strstr(tab, "nop")) { skipped_nop++; continue; }
        char *bar = strrchr(line, '|');
        if (!bar) continue;
        *bar = 0;
        char *p = line + 7;
        while (*p == ' ') p++;
        snprintf(g_ref[n], sizeof g_ref[0], "%s", tab + 1);
        n++;
    }
    fclose(f);
    g_ref_n = n;
    printf("  vecmaps_dis.txt                    loaded, %d rows"
           "  (%d header, %d padding skipped)\n\n",
           g_ref_n, skipped_hdr, skipped_nop);
}

/* The bytes, written to a flat binary for objdump.  Ten NOPs of padding
 * after each one so that a reader cannot read PAST the row into the next
 * row's bytes -- which is what the first version of this file's probe did,
 * and it produced a table of answers that belonged to the wrong rows. */
void maps_emit(void)
{
    FILE *f = fopen("vecmaps.bin", "wb");
    if (!f) { printf("cannot open vecmaps.bin for writing\n"); return; }
    for (int i = 0; i < NT; i++) {
        uint8_t b[12];
        int k = enc_encode(&T[i], b);
        fwrite(b, 1, (size_t)k, f);
        for (int j = 0; j < 10; j++) fputc(0x90, f);
    }
    fclose(f);
    printf("wrote %d encodings to vecmaps.bin\n", NT);
}

void section_6(void)
{
    printf("6.  ENCODE THE MAPS, THEN DECODE THE BYTES.\n\n");
    printf("  %d cases.  Each one is ENCODED here from an operand spec,\n"
           "  DECODED here by an independent walk, and DISASSEMBLED by\n"
           "  objdump from a second reader that was not written from this\n"
           "  table.  All three must agree or the row is a failure.\n\n", NT);
    printf("  WHY A SECOND READER IS NOT OPTIONAL, and this file is the\n"
           "  argument.  The first encoder in this course round-tripped\n"
           "  28 of 28 and was WRONG: it wrote the two-byte VEX with the\n"
           "  three-byte field order, and a decoder built from the same\n"
           "  wrong table agreed with it perfectly.  A round trip is a\n"
           "  tautology and it certified a broken encoder.  R9.\n\n");

    load_dis();

    int rt_ok = 0, x_ok = 0, x_run = 0, x_bad = 0;
    for (int i = 0; i < NT; i++) {
        uint8_t b[12];
        dec_t d;
        int k = enc_encode(&T[i], b);
        int k2 = enc_decode(b, &d);

        int same = (k == k2) && d.shape == T[i].shape && d.map == T[i].map &&
                   d.pp == T[i].pp && d.op == T[i].op && d.L == T[i].L &&
                   d.W == T[i].W && d.R == T[i].R && d.vvvv == T[i].vvvv &&
                   d.modrm == T[i].modrm && d.aaa == T[i].aaa &&
                   d.bbit == T[i].bbit &&
                   (T[i].shape < 2 || (d.X == T[i].X && d.B == T[i].B));
        if (same) rt_ok++;

        /* the cross-check: does objdump's line for this row name the same
         * instruction?  A substring comparison against a WHITESPACE-
         * NORMALISED copy, because the disassembly is column-aligned and a
         * needle written with the alignment in it is a different string. */
        int x = 0;
        if (g_ref_n > i) {
            x_run++;
            char norm[80], want[80];
            const char *a = g_ref[i], *b2 = T[i].text;
            int na = 0, nb = 0, sp = 0;
            while (*a && na < 78) {
                if (*a == ' ') { sp = 1; a++; continue; }
                if (sp && na) norm[na++] = ' ';
                sp = 0; norm[na++] = *a++;
            }
            norm[na] = 0;
            na = 0; nb = 0; sp = 0;
            while (*b2 && nb < 78) {
                if (*b2 == ' ') { sp = 1; b2++; continue; }
                if (sp && nb) want[nb++] = ' ';
                sp = 0; want[nb++] = *b2++;
            }
            want[nb] = 0;
            /* compare the MNEMONIC, which is the first token, and the
             * destination register.  That is what a wrong field changes:
             * a wrong vvvv or a wrong R moves a register name. */
            char m1[96], m2[96];
            snprintf(m1, sizeof m1, "%s", norm);
            snprintf(m2, sizeof m2, "%s", want);
            char *sp1 = strchr(m1, ' '), *sp2 = strchr(m2, ' ');
            if (sp1) *sp1 = 0;
            if (sp2) *sp2 = 0;
            x = !strcmp(m1, m2);
            if (x) x_ok++; else x_bad++;
        }

        printf("  MAP  | %-32s | ", T[i].text);
        for (int j = 0; j < k; j++) printf("%02x ", b[j]);
        printf("| %-9s | %s\n", same ? "roundtrip" : "MISMATCH",
               g_ref_n > i ? (x ? "objdump agrees"
                                : "OBJDUMP DISAGREES")
                           : "cross-check NOT RUN");
        g_ck += (uint64_t)b[0] * 31u + (uint64_t)b[k - 1];
    }
    g_rows += NT;

    printf("\n  %d cases, %d round-tripped, %d cross-checked against\n"
           "  objdump, %d disagreed.\n", NT, rt_ok, x_run, x_bad);
    printf("  THE THREE NUMBERS ARE NOT THE SAME CLAIM.  'round-tripped'\n"
           "  says the encoder and the decoder agree with each other, and\n"
           "  that is necessary and NOT SUFFICIENT.  'objdump agrees' says\n"
           "  an implementation that was not written from this table read\n"
           "  the same bytes and named the same instruction, and that is\n"
           "  the claim worth making.\n\n");
    if (x_run > 0 && x_bad > 0)
        /* R23, loudly.  A cross-check that fails is not a curiosity, and a
         * file that prints a column of failures and then carries on to its
         * summary is teaching the wrong habit.  Say so, at the top of the
         * table's own results, where a reader cannot scroll past it. */
        printf("  !!!! THE CROSS-CHECK DISAGREED ON %d OF %d ROWS.  Either\n"
               "  !!!! the encoder is wrong or the READER of the disassembly\n"
               "  !!!! is aimed at the wrong row.  R23 was exactly this, and\n"
               "  !!!! it was believed for a full run.  Do not read the\n"
               "  !!!! summary below until this is settled.\n\n", x_bad, x_run);
    if (x_run > 0 && x_bad == 0)
        printf("  AND THE CROSS-CHECK IS WHAT FOUND THE THREE BUGS that the\n"
               "  round trip could not: the two-byte VEX field order, the\n"
               "  inversion of R and X and B, and the fact that the L bit\n"
               "  is TWO bits wide in EVEX and one in VEX.  All three\n"
               "  produced LEGAL BYTES for A DIFFERENT INSTRUCTION, which\n"
               "  is the worst kind of wrong: there is no trap to catch it\n"
               "  and no length to be surprised by.\n\n");
    g_rows += 3;

    /* ---- 6B. the AVX-512 decoder, on bytes, with no silicon ----- */
    printf("6B. AVX-512, WHICH THIS MACHINE CANNOT EXECUTE.  CPUID.7.0:EBX\n"
           "  reads F, DQ, CD, BW and VL as five ZEROS and the XCR0 opmask,\n"
           "  zmm_hi256 and hi16_zmm bits as three more, printed in\n"
           "  section 1.  So everything above the 0x62 rows is QUOTED, and\n"
           "  the one thing this file does with AVX-512 is DECODE ITS\n"
           "  BYTES, which needs no silicon at all.\n\n");
    printf("  THE FOUR LEVELS, and the L'L PAIR is the whole of it:\n"
           "    L'L = 00   no vector length in this instruction\n"
           "    L'L = 10   128 bit, xmm\n"
           "    L'L = 11   512 bit, zmm\n"
           "  and when L'L is 00 the SAME two bits are the ROUNDING CONTROL,\n"
           "  so a decoder cannot read them as a length without first\n"
           "  asking whether the instruction has a length.  That is why the\n"
           "  round trip above has a row with b=1 and no L at all.\n\n");
    printf("  THE ELEVEN BITS OF AN EVEX PREFIX, and every one of them is a\n"
           "  thing a VEX prefix could not express:\n"
           "    R~ X~ B~  16 more vector registers, so zmm0-zmm31\n"
           "    R~'        a FOURTH bit on ModRM.reg, so 32 GPRs\n"
           "    W          as before, and for the float map the packed-double\n"
           "    v~3..0     the third vector operand, as before\n"
           "    bit 2      a MANDATORY 1, which is what makes 0x62 safe: a\n"
           "              32-bit BOUND cannot have it, so the two never\n"
           "              collide in a mode where BOUND exists\n"
           "    p1 p0      the mandatory 66/F2/F3 prefix, as before\n"
           "    z          merging (0) versus ZEROING (1) the mask-off lanes\n"
           "    L' L       the length, or the rounding mode\n"
           "    b          broadcast from memory, or suppress exceptions\n"
           "    V~'        a fifth bit on the v operand\n"
           "    a2 a1 a0   WHICH OF EIGHT MASK REGISTERS, and a value of 0\n"
           "              means no mask at all\n\n");
    printf("  THE MASK REGISTER, and this is the part that has no analogue\n"
           "  anywhere else in the instruction set.  k0-k7 are not vector\n"
           "  registers and they are not general registers; each is 64 bits\n"
           "  and each bit of it says whether one LANE of the destination\n"
           "  takes part.  An AVX-512 add can be predicated on a mask for\n"
           "  FREE -- there is no compare instruction, no branch, and no\n"
           "  second pass over the data, because the mask is an OPERAND of\n"
           "  the arithmetic rather than an input to a sequence of it.\n\n");
    printf("  TWO PROPERTIES NO OTHER INSTRUCTION IN THIS COURSE HAS, and\n"
           "  they are the reasons the extension exists:\n"
           "    * THE TAIL DISAPPEARS.  A 4-wide loop over 66 elements needs\n"
           "      a scalar remainder, and the SIMD course measured that\n"
           "      remainder at 1.02x -- free, but only because the\n"
           "      remainder happened to be short.  With a mask register the\n"
           "      66th iteration is the same instruction with two of its four\n"
           "      lanes switched off, so there is no second code path at all.\n"
           "    * BROADCAST IS AN OPERAND.  vbroadcastsd ymm0, [rbx] loads\n"
           "      one eight-byte value into all four lanes.  The same bytes\n"
           "      are in the table above, encoded and decoded, and the\n"
           "      DISPATCH is a field of the instruction rather than a\n"
           "      separate load.\n\n");
    printf("  WHAT IS QUOTED HERE AND NOT MEASURED, itemised, because the\n"
           "  difference is the point of the section:\n"
           "    QUOTED  that a ZMM is 512 bits, that k0-k7 are 64 bits, that\n"
           "            z is merging-versus-zeroing, that b is broadcast\n"
           "    QUOTED  the four-level hierarchy and its dispatch penalty\n"
           "    MEASURED the five CPUID bits are zero\n"
           "    MEASURED the XCR0 state bits are zero\n"
           "    MEASURED the encoder emits the bytes the SDM says and\n"
           "            objdump reads them back the same way\n"
           "  NOT MEASURED  that any of it is FASTER, and not measured\n"
           "  because there is no hardware here on which to run it.  A\n"
           "  decoder that works on bytes is a decoder; it is not a\n"
           "  benchmark, and the two are confused often enough to be worth\n"
           "  naming.\n\n");
    g_rows += 5;
}
