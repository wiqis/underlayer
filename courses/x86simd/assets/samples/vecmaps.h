/* vecmaps.h -- the encoder, the decoder and the table, for the artifact
 * of "The x86-64 Data Path: Atomics, Ordering and Vectors".
 *
 * THE THREE PREFIX SHAPES, from the SDM's own field tables:
 *
 *   VEX2  C5  R~ v~3 v~2 v~1 v~0 L p1 p0        + opcode + ModRM
 *   VEX3  C4  R~ X~ B~ m4 m3 m2 m1 m0
 *            W v~3 v~2 v~1 v~0 L p1 p0          + opcode + ModRM
 *   EVEX  62  R~ X~ B~ R~' 0 m2 m1 m0
 *            W v~3 v~2 v~1 v~0 1 p1 p0
 *            z L' L b V~' a2 a1 a0              + opcode + ModRM
 *
 * Note what VEX2 does NOT have: there is no map field at all, and the
 * choice of 0xC5 over 0xC4 IS the map.  An encoder that treats 0xC5 as
 * the three-byte form with two fields missing round-trips against its own
 * decoder and emits bytes binutils reads as a different instruction.
 */
#ifndef VECMAPS_H
#define VECMAPS_H

#include "vecdump.h"

typedef struct {
    const char *text;    /* the instruction a reader would write         */
    int  shape;          /* 0 legacy, 1 VEX2, 2 VEX3, 3 EVEX            */
    int  map;            /* 1 = 0F, 2 = 0F38, 3 = 0F3A                  */
    int  pp;             /* 0 none, 1 = 66, 2 = F3, 3 = F2              */
    int  op;
    int  L;              /* 0 = 128, 1 = 256, 2 = 512                   */
    int  W;
    /* R, X and B: 0 = one of the first eight registers, 1 = one of the
     * last eight.  THE BYTES HOLD THEIR COMPLEMENTS. */
    int  R, X, B;
    int  vvvv;           /* UNINVERTED register number; 0 = unused      */
    int  modrm;
    int  R2, Vprime;     /* EVEX only, same 0 = first eight convention  */
    int  z, aaa, bbit;   /* EVEX only                                   */
} spec_t;

typedef struct {
    int shape, map, pp, op, modrm, mod, reg, rm;
    int L, Lprime, W, R, X, B, vvvv, R2, Vprime, z, aaa, bbit;
    int rexW, len;
} dec_t;

int enc_encode(const spec_t *s, uint8_t *o);
int enc_decode(const uint8_t *o, dec_t *d);

#endif /* VECMAPS_H */
