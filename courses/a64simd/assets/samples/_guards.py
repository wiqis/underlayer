#!/usr/bin/env python3
"""scratch: derive fixed-bit guards for the families this course models.

SAME METHOD as courses/a64asm/assets/samples/a64dec.py --fields: assemble
several members of a family, OR the XOR against the first, and the bits that
never move are the family's fixed pattern.  Nothing here is used by the course;
it is the notebook the models were written from.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
T = 'aarch64-linux-gnu'


def asm(src, path='_s.s', extra=()):
    p = os.path.join(HERE, path)
    with open(p, 'w') as f:
        f.write('\t.text\n\t' + src.replace(';', '\n\t') + '\n')
    o = os.path.join(HERE, path[:-2] + '.o')
    r = subprocess.run(['clang', '--target=%s' % T] + list(extra) +
                       ['-c', p, '-o', o], capture_output=True, text=True)
    if r.returncode:
        msg = [l for l in r.stderr.splitlines() if 'error:' in l]
        return None, (msg[0].split('error: ', 1)[1] if msg else 'refused')
    out = subprocess.run(['llvm-objdump-21', '--triple=aarch64', '-d', o],
                         capture_output=True, text=True).stdout
    ws = []
    for ln in out.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s+(.*)$', ln)
        if m:
            ws.append((int(m.group(1), 16), m.group(2).strip()))
    return ws, ''


FAMILIES = [
    ('SIMD ldst single (ldr b/h/s/d/q)',
     'ldr b0, [x0];ldr h0, [x0];ldr s0, [x0];ldr d0, [x0];ldr q0, [x0]'),
    ('SIMD ldst single store',
     'str b0, [x0];str h0, [x0];str s0, [x0];str d0, [x0];str q0, [x0]'),
    ('SIMD ldst single, lane',
     'ldr b0, [x0];ldrb w0, [x0];ldrh w0, [x0];ldrb w0, [x0],#1'),
    ('ldp/stp q',
     'ldp q0, q1, [x0];stp q0, q1, [x0];ldp d0, d1, [x0]'),
    ('SIMD 3 same, int',
     'add v0.16b, v1.16b, v2.16b;add v0.8h, v1.8h, v2.8h;add v0.4s, v1.4s, v2.4s;add v0.2d, v1.2d, v2.2d'),
    ('SIMD 3 same, fp',
     'fadd v0.4s, v1.4s, v2.4s;fadd v0.2d, v1.2d, v2.2d'),
    ('SIMD 3 diff',
     'saddl v0.8h, v1.8b, v2.8b;uaddl v0.8h, v1.8b, v2.8b'),
    ('SIMD 2 reg misc (addv/addp)',
     'addv s0, v1.4s;addp d0, v1.2d;addp v0.2d, v1.2d, v2.2d'),
    ('SIMD structure ld1/ld2/ld3/ld4',
     'ld1 {v0.16b}, [x0];ld2 {v0.16b, v1.16b}, [x0];ld3 {v0.16b,v1.16b,v2.16b}, [x0];ld4 {v0.16b,v1.16b,v2.16b,v3.16b}, [x0]'),
    ('SIMD structure st',
     'st1 {v0.16b}, [x0];st2 {v0.16b,v1.16b}, [x0];st4 {v0.4s,v1.4s,v2.4s,v3.4s}, [x0]'),
    ('SIMD copy (dup/ins/umov)',
     'dup v0.4s, w0;ins v0.s[1], w1;umov w0, v0.s[1];smov w0, v0.h[1]'),
    ('SIMD movi',
     'movi v0.4s, #0;movi v0.2d, #0;movi v0.8h, #0;movi v0.16b, #0'),
    ('exclusive load (ldxr/ldaxr)',
     'ldxr w1, [x0];ldxr x1, [x0];ldaxr w1, [x0];ldaxr x1, [x0];ldaxrb w1, [x0];ldaxrh w1, [x0];ldxrb w1,[x0];ldxrh w1,[x0]'),
    ('exclusive store (stxr/stlxr)',
     'stxr w2, w1, [x0];stxr w2, x1, [x0];stlxr w2, w1, [x0];stlxr w2, x1, [x0];stxrb w2,w1,[x0];stlxrb w2,w1,[x0]'),
    ('exclusive pair load',
     'ldxp w9, w8, [x0];ldxp x9, x8, [x0];ldaxp w9, w8, [x0];ldaxp x9, x8, [x0]'),
    ('exclusive pair store',
     'stxp w14, w9, w8, [x0];stxp w14, x9, x8, [x0];stlxp w14, w9, w8, [x0]'),
    ('ldar/stlr',
     'ldar w1, [x0];ldar x1, [x0];stlr w1, [x0];stlr x1, [x0];ldarb w1, [x0];stlrb w1, [x0]'),
    ('barrier',
     'dmb sy;dmb ish;dmb osh;dsb sy;isb'),
    ('cas (LSE)', 'cas w1, w2, [x0];cas x1, x2, [x0];casa w1,w2,[x0];casl w1,w2,[x0];casb w1,w2,[x0]'),
    ('casp (LSE)', 'casp x0, x1, x2, x3, [x4];caspal x0, x1, x2, x3, [x4]'),
    ('ldadd (LSE)', 'ldadd w1, w2, [x0];ldadd x1, x2, [x0];ldadda w1,w2,[x0];ldaddl w1,w2,[x0];ldaddal w1,w2,[x0];ldaddb w1,w2,[x0]'),
    ('swp (LSE)', 'swp w1, w2, [x0];swp x1, x2, [x0];swpa w1,w2,[x0];swpb w1,w2,[x0]'),
    ('SVE pred', 'whilelo p0.d, x0, x1;whilelo p0.s, x0, x1;ptrue p0.b;ptrue p15.b'),
    ('SVE z dp', 'add z0.d, p0/m, z0.d, z1.d;add z0.s, p0/m, z0.s, z1.s;add z0.b, p0/m, z0.b, z1.b;add z0.h, p0/m, z0.h, z1.h;eor z0.d, p0/m, z0.d, z1.d'),
    ('SVE ldst', 'ld1d {z0.d}, p0/z, [x0];st1d {z0.d}, p0, [x0]'),
    ('clrex', 'clrex'),
]

EXTRA = {'cas (LSE)': ['-march=armv8.1-a'], 'casp (LSE)': ['-march=armv8.1-a'],
         'ldadd (LSE)': ['-march=armv8.1-a'], 'swp (LSE)': ['-march=armv8.1-a'],
         'SVE pred': ['-march=armv8.2-a+sve'], 'SVE z dp': ['-march=armv8.2-a+sve'],
         'SVE ldst': ['-march=armv8.2-a+sve']}


def fixed_mask(words):
    base = words[0]
    and_ = 0xffffffff
    for w, _ in words:
        and_ &= w
    or_ = 0
    for w, _ in words:
        or_ |= w
    return and_, or_


for label, src in FAMILIES:
    ws, diag = asm(src, extra=EXTRA.get(label, []))
    print('=== %s' % label)
    if ws is None:
        print('    REFUSED: %s' % diag)
        continue
    for w, t in ws:
        print('    0x%08x  %s' % (w, t))
    and_, or_ = fixed_mask(ws)
    print('    AND=0x%08x OR=0x%08x  n=%d' % (and_, or_, len(ws)))
    var = or_ ^ and_
    # runs of constant 1
    runs = []
    for b in range(32):
        if and_ >> b & 1:
            if runs and runs[-1][1] == b - 1:
                runs[-1][1] = b
            else:
                runs.append([b, b])
    print('    constant-1 runs: %s'
          % ', '.join(('bits[%d:%d]' % (r[0], r[1])) if r[0] != r[1]
                      else ('bit%d' % r[0]) for r in runs))
