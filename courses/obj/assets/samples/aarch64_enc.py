#!/usr/bin/env python3
"""aarch64_enc.py -- encode and decode the AArch64 fields a fixup must patch.

The point of this file: on x86-64 a relocation patches a *contiguous run of
bytes* that holds one little-endian integer.  On AArch64 the patch target is a
*bit range inside the instruction word itself*, split in two, and the linker
must read-modify-write.  This program builds ADRP + LDR words from a symbol
offset and prints the bit ranges, so the rule can be checked rather than
believed.

    $ python3 aarch64_enc.py            # decode the words clang emits
    $ python3 aarch64_enc.py --build 3  # build ADRP with page delta 3
"""
import struct
import sys

# ---------------------------------------------------------------- the rules
#
# ADRP  <imm>          encoding: 1 immlo(2) 10000 immhi(19) Rd(5)
#                        the 21-bit signed value is page_delta * 4096,
#                        split as immlo = bits 30:29, immhi = bits 23:5
#
# LDR   <Rt>, [<Rn>, #imm]   imm12 occupies bits 21:10, scaled by the
#                             access size (4 for a 32-bit load)

ADR_OP = 1 << 31
ADR_FIXED = 0b10000 << 24
ADR_IMMLO_SHIFT = 29
ADR_IMMHI_SHIFT = 5
ADR_IMM_MASK = 0x7FFFF           # 19 bits
ADR_IMMLO_MASK = 0x3              # 2 bits

LDR_32_FIXED = (0b111001 << 24) | (0b01 << 22)   # size=10, unsigned imm
LDR_64_FIXED = (0b111001 << 24) | (0b11 << 22)   # size=11, unsigned imm
LDR_IMM_SHIFT = 10
LDR_IMM_MASK = 0xFFF


def sign21(v):
    v &= 0x1FFFFF
    if v & (1 << 20):
        v -= 1 << 21
    return v


def adrp(page_delta, rd):
    """Encode ADRP with a 21-bit SIGNED page delta (in 4KiB pages)."""
    v = sign21(page_delta)
    immlo = v & 0x3
    immhi = (v >> 2) & ADR_IMM_MASK
    return (ADR_OP | (immlo << ADR_IMMLO_SHIFT) | ADR_FIXED |
            (immhi << ADR_IMMHI_SHIFT) | (rd & 0x1F))


def ldr_imm(rt, rn, byte_off, is64=False):
    """Encode LDR (immediate, unsigned offset). byte_off must be size-aligned."""
    scale = 8 if is64 else 4
    if byte_off % scale or not (0 <= byte_off < 4096):
        raise ValueError('offset %d not a valid unsigned imm12 for scale %d'
                         % (byte_off, scale))
    fixed = LDR_64_FIXED if is64 else LDR_32_FIXED
    return (fixed | ((byte_off // scale) << LDR_IMM_SHIFT) |
            ((rn & 0x1F) << 5) | (rt & 0x1F))


def show_adrp(word):
    lo = (word >> ADR_IMMLO_SHIFT) & ADR_IMMLO_MASK
    hi = (word >> ADR_IMMHI_SHIFT) & ADR_IMM_MASK
    delta = sign21((hi << 2) | lo)
    print('  ADRP  word = 0x%08x   bits = %s' % (word, format(word, '032b')))
    print('          bit 31      op      = %d  (1 = ADRP, 0 = ADR)'
          % ((word >> 31) & 1))
    print('          bits 30:29  immlo   = %d' % lo)
    print('          bits 28:24  fixed   = %s  (must be 10000)'
          % format((word >> 24) & 0x1F, '05b'))
    print('          bits 23:5   immhi   = %d  (0x%05x)' % (hi, hi))
    print('          bits 4:0    Rd      = x%d' % (word & 0x1F))
    print('          => 21-bit signed page delta = %d pages = %+d bytes'
          % (delta, delta * 4096))


def show_ldr(word):
    imm12 = (word >> LDR_IMM_SHIFT) & LDR_IMM_MASK
    size = (word >> 30) & 3
    scale = 8 if size == 3 else 4
    print('  LDR   word = 0x%08x   bits = %s' % (word, format(word, '032b')))
    print('          bits 31:30  size    = %d  (2 = 32-bit, 3 = 64-bit)' % size)
    print('          bits 29:24  fixed   = %s'
          % format((word >> 24) & 0x3F, '06b'))
    print('          bits 23:22  opc     = %d' % ((word >> 22) & 3))
    print('          bits 21:10  imm12   = %d  (0x%03x)' % (imm12, imm12))
    print('          bits 9:5    Rn      = x%d' % ((word >> 5) & 0x1F))
    print('          bits 4:0    Rt      = x%d' % (word & 0x1F))
    print('          => byte offset within the page = %d' % (imm12 * scale))


def build(n):
    a = adrp(n, 8)
    l = ldr_imm(0, 8, 0x24)          # byte offset 36 within the page
    print('built with page delta %d pages:' % n)
    show_adrp(a)
    print()
    show_ldr(l)
    print()
    print('  encoded words little-endian: %s   %s'
          % (struct.pack('<I', a).hex(' '), struct.pack('<I', l).hex(' ')))
    return a, l


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--build':
        build(int(sys.argv[2]))
    else:
        print('The two words clang emits for ONE reference to g32,')
        print('read out of a real -fno-pic AArch64 object:')
        print()
        show_adrp(0x90000008)
        print()
        show_ldr(0xB9400100)
        print()
        print('Both carry zero, because a relocatable object has no')
        print('addresses yet. That is the point: the linker supplies BOTH')
        print('fields, from ONE symbol, in TWO records -- and neither field')
        print('is a little-endian integer sitting in the byte stream.')
        print()
        print('  --build N   build an ADRP carrying page delta N and show the')
        print('              bits. Cross-check it against a real decoder by')
        print('              placing the word with .inst and disassembling:')
        print('                clang -target aarch64-linux-gnu -O0 -c t.c')
        print('                llvm-objdump-21 -d t.o')
