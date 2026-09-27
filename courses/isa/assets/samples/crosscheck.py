#!/usr/bin/env python3
"""crosscheck.py -- re-derive every claim the x86-64 course makes.

Run ./build_samples.sh first. Every number the course states is measured here
again from a fresh build, so a claim cannot rot silently.

    python3 crosscheck.py       # the summary
    python3 crosscheck.py -v    # every check, passing or not

The load-bearing check is I7: x86dec.py and objdump are two independent
decoders, and the question is whether they agree on WHERE EVERY INSTRUCTION
STARTS AND HOW LONG IT IS. That is a single number per section -- does the
chain of instruction boundaries consume the section exactly? -- and it cannot
be satisfied by a coincidence, because one wrong length desynchronises every
boundary after it.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
VERBOSE = '-v' in sys.argv
results = []


def ck(group, label, ok, detail=''):
    results.append((group, label, bool(ok)))
    if not ok or VERBOSE:
        print('  %-4s %-56s %s%s' % ('ok' if ok else 'FAIL', label, detail,
                                     '' if ok else '   <-- FAILED'))
    return ok


def sh(*args):
    r = subprocess.run(list(args), capture_output=True, text=True, cwd=HERE)
    return r.stdout + r.stderr


def dis1(hexbytes, mode='i386:x86-64'):
    """The oracle, for a single raw byte string.

    Returns a list of (nbytes, text) per instruction, with the byte count
    WRAP-AWARE: objdump prints at most 7 bytes of an encoding on one line and
    the remainder on a continuation line with no mnemonic field, so an
    instruction is not a line. This bit the length checks until it was fixed
    here too.
    """
    p = os.path.join(HERE, '_cc.bin')
    with open(p, 'wb') as f:
        f.write(bytes.fromhex(hexbytes.replace(' ', '')))
    out = subprocess.run(['objdump', '-D', '-b', 'binary', '-m', mode,
                          '-M', 'intel', p], capture_output=True, text=True).stdout
    got, prev = [], None
    for l in out.splitlines():
        c = l.split('\t')
        if len(c) < 2:
            continue
        try:
            int(c[0].strip().rstrip(':'), 16)
        except ValueError:
            continue
        n = len(c[1].split())
        if prev is not None and len(c) == 2 and prev == 7:
            got[-1] = (got[-1][0] + n, got[-1][1])
        else:
            got.append((n, c[2].strip() if len(c) > 2 else ''))
        prev = n
    return got


# objdump WRAPS long instructions: it prints at most 7 bytes of an encoding on
# the first line and any remainder on a continuation line that has NO mnemonic
# field. So "one instruction" is not "one line". This bit me twice while the
# decoder was already correct: a naive line-per-instruction parser counted a
# 10-byte NOP as 7 bytes and a 1-instruction section as 2, which made a
# working decoder look broken. Two rules distinguish the cases:
#   a 2-field line CONTINUES the previous instruction iff the previous line's
#       byte field was exactly 7 bytes long (objdump's wrap width);
#   otherwise it is a real entry that objdump could not name.

def objdump_ref(binary, addr, size):
    """objdump's instruction boundaries for [addr, addr+size).

    The line parser here is deliberately LENIENT. objdump sometimes prints an
    entry with a byte field and no mnemonic at all -- a raw byte run it could
    not name. An earlier version of this file required three tab-separated
    fields and silently dropped those entries, which made x86dec.py look wrong
    on three sections when x86dec.py was right and the CHECK was wrong. A
    check that fails for the wrong reason is worse than no check, because it
    teaches you to ignore it.
    """
    out = subprocess.run(['objdump', '-d',
                          '--start-address=%#x' % addr,
                          '--stop-address=%#x' % (addr + size), binary],
                         capture_output=True, text=True).stdout
    ref, prev = [], None
    for l in out.splitlines():
        c = l.split('\t')
        if len(c) < 2:
            continue
        try:
            a = int(c[0].strip().rstrip(':'), 16)
        except ValueError:
            continue
        nbytes = len(c[1].split())
        if prev is not None and len(c) == 2 and prev[1] == 7:
            ref[-1] = (ref[-1][0], ref[-1][1] + nbytes)   # a continuation
        else:
            ref.append((a - addr, nbytes))
        prev = (a, nbytes)
    return ref


def main():
    import x86dec

    need = ['probe.o', 'corpus', 'mini']
    missing = [n for n in need if not os.path.exists(os.path.join(HERE, n))]
    if missing:
        print('  specimens missing (%s) -- run ./build_samples.sh first'
              % ', '.join(missing))
        return 2

    print('=' * 78)
    print('  crosscheck -- re-deriving every x86-64 encoding claim')
    print('=' * 78)

    # ---------------------------------------------------------------- I1
    # Mode dependence: the same three bytes are one instruction or two.
    a64 = dis1('40 89 e8', 'i386:x86-64')
    a32 = dis1('40 89 e8', 'i386')
    ck('I1', '40 89 e8 is ONE instruction in 64-bit', len(a64) == 1, str(a64))
    ck('I1', '40 89 e8 is TWO instructions in 32-bit', len(a32) == 2, str(a32))
    ck('I1', 'the 32-bit split is 1 byte then 2',
       len(a32) == 2 and a32[0][0] == 1 and a32[1][0] == 2,
       '%d then %d bytes' % (a32[0][0], a32[1][0]))
    ck('I1', '0x40 is INC in 32-bit', a32[0][1].startswith('inc'), a32[0][1])
    # x86dec is a 64-BIT decoder and says so; it has no 32-bit mode, so the
    # honest check is that it treats 40 as a REX and produces ONE instruction.
    # Asserting a 32-bit split from a 64-bit-only decoder would be a claim the
    # tool cannot support.
    ck('I1', 'x86dec treats 40 as a REX and gets ONE 3-byte instruction',
       len(x86dec.decode_stream(bytes.fromhex('4089e8'), 0, 3)[0]) == 1)

    # ---------------------------------------------------------------- I2
    # The REX bits, and the ADD-8 rule.
    for h, frag in (('44 89 e0', 'r12d'), ('4c 89 e0', 'r12'),
                    ('49 89 e0', 'r8'), ('49 8b 00', '[r8]')):
        g = dis1(h)
        ck('I2', 'REX extension in %s -> %s' % (h, frag),
           len(g) == 1 and frag in g[0][1], g[0][1] if g else '?')
    ck('I2', 'REX.R=1 with reg=000 is r8, NOT r9',
       'r8' in dis1('44 8b c0')[0][1] and 'r9' not in dis1('44 8b c0')[0][1],
       dis1('44 8b c0')[0][1])
    ck('I2', 'a bare REX prefix does not change the instruction',
       len(dis1('40 89 c3')) == 1)
    # REX must be LAST: a legacy prefix after REX becomes the opcode.
    ck('I2', '66 then REX is ONE instruction', len(dis1('66 48 8b c0')) == 1)
    ck('I2', 'REX then 66 is TWO objdump entries', len(dis1('48 66 8b c0')) == 2)
    ck('I2', 'x86dec agrees on the 66-then-REX case',
       len(x86dec.decode_stream(bytes.fromhex('66488bc0'), 0, 4)[0]) == 1)
    # The two readers DISAGREE on the second case, and the disagreement is
    # worth stating rather than smoothing. Architecturally a byte after REX is
    # the opcode, and 0x66 as an opcode in 64-bit mode is PUSH ES, which is
    # invalid -- so the instruction faults. objdump instead prints a bare
    # `rex.W` and then re-reads 0x66 as a prefix, which is a diagnostic
    # convenience rather than the architectural reading. x86dec refuses.
    _r = x86dec.decode_stream(bytes.fromhex('48668bc0'), 0, 4)
    ck('I2', 'x86dec REFUSES REX-then-0x66, which is the architectural reading',
       len(_r[0]) == 0 and _r[2] is not None,
       'refused: %s' % (_r[2][1] if _r[2] else 'nothing'))

    # ---------------------------------------------------------------- I3
    # All 256 ModRM bytes, each completed with the trailing bytes its form
    # needs, must decode as exactly ONE instruction.
    def full(modrm):
        mod, rm = modrm >> 6, modrm & 7
        b = bytes([0x8b, modrm])
        if mod == 3:
            return b
        if mod == 1:
            b += b'\x11'
        elif mod == 2:
            b += b'\x11\x22\x33\x44'
        elif mod == 0 and rm == 5:
            b += b'\x44\x33\x22\x11'
        if rm == 4:
            b += b'\x24'
        return b
    bad = []
    regforms = 0
    for m in range(256):
        g = dis1(' '.join('%02x' % x for x in full(m)))
        if len(g) != 1:
            bad.append(m)
        if m >> 6 == 3:
            regforms += 1
    ck('I3', 'all 256 ModRM bytes decode as exactly one instruction',
       not bad, 'failures: %s' % bad[:10])
    ck('I3', 'mod=11 is exactly 64 of 256 (a quarter)', regforms == 64,
       '%d' % regforms)
    ck('I3', 'mod=00 rm=101 is RIP-relative',
       'rip' in dis1('8b 05 44 33 22 11')[0][1])
    ck('I3', 'x86dec agrees on all 256 lengths',
       all(len(x86dec.decode_stream(full(m), 0, len(full(m)))[0]) == 1
           for m in range(256)))

    # ---------------------------------------------------------------- I4
    # SIB: the byte order, and the two special field values.
    ck('I4', 'the SIB byte comes BEFORE the displacement',
       'rsp+0x44332211' in dis1('8b 84 24 11 22 33 44')[0][1],
       dis1('8b 84 24 11 22 33 44')[0][1])
    ck('I4', 'the other order decodes as a DIFFERENT instruction',
       'rcx' in dis1('8b 84 11 22 33 44 24')[0][1],
       dis1('8b 84 11 22 33 44 24')[0][1])
    ck('I4', 'index=100 with REX.X=0 means NO index',
       dis1('8b 04 24')[0][1].strip().endswith('[rsp]'), dis1('8b 04 24')[0][1])
    ck('I4', 'index=101 is rbp, not "none"',
       'rbp' in dis1('8b 04 2c')[0][1], dis1('8b 04 2c')[0][1])
    ck('I4', 'base=101 with mod=00 is an ABSOLUTE address',
       '0x44332211' in dis1('8b 04 25 11 22 33 44')[0][1],
       dis1('8b 04 25 11 22 33 44')[0][1])
    ck('I4', 'base=101 with mod=01 is the register rbp',
       '[rbp' in dis1('8b 44 25 11')[0][1], dis1('8b 44 25 11')[0][1])
    for ss, sc in ((0, '1'), (1, '2'), (2, '4'), (3, '8')):
        ck('I4', 'SIB ss=%d scales by %s' % (ss, sc),
           '*%s' % sc in dis1('8b 44 %02x 11' % (ss << 6 | 0 << 3 | 5))[0][1],
           dis1('8b 44 %02x 11' % (ss << 6 | 0 << 3 | 5))[0][1])

    # ---------------------------------------------------------------- I5
    # The opcode map, the 0F escape, and the holes in it.
    def first(b):
        g = dis1('%02x' % b)
        return g[0][1] if g and len(g[0]) > 1 and g[0][1] else ''
    one = [b for b in range(256)
           if first(b) and not first(b).startswith(
               ('data', 'rep', 'lock', 'cs', 'ds', 'es', 'fs', 'gs', 'ss',
                'addr', 'rex'))]
    ck('I5', 'the one-byte map is mostly decoded, not mostly empty',
       len(one) > 180, '%d of 256 byte values decode to an instruction' % len(one))
    ck('I5', '0f 0b is UD2, a deliberately undefined opcode',
       dis1('0f 0b')[0][1].startswith('ud2'), dis1('0f 0b')[0][1])
    ck('I5', '0f 05 is SYSCALL', dis1('0f 05')[0][1].startswith('syscall'))
    ck('I5', 'cd 80 is INT 0x80 -- the older syscall path',
       'int' in dis1('cd 80')[0][1], dis1('cd 80')[0][1])
    ck('I5', 'f3 0f 1e fa is ENDBR64 and is exactly 4 bytes',
       dis1('f3 0f 1e fa')[0][1].startswith('endbr64') and
       dis1('f3 0f 1e fa')[0][0] == 4)
    ck('I5', 'bare 0f 1e fa is a multi-byte NOP, not endbr64',
       not dis1('0f 1e fa')[0][1].startswith('endbr64'), dis1('0f 1e fa')[0][1])

    # ---------------------------------------------------------------- I6
    # The sixteen condition codes, shared by Jcc and SETcc.
    cc = []
    for lo in range(8):
        for hi in (0, 1):
            g = dis1('0f %02x 11 22 33 44' % (0x80 | (lo | hi << 3)))
            cc.append(g[0][1].split()[0] if g else '?')
    ck('I6', 'the 16 near-jump condition codes are all distinct',
       len(set(cc)) == 16, ' '.join(cc))
    for name, code in (('jo', 0x80), ('jno', 0x81), ('jb', 0x82), ('jae', 0x83),
                       ('je', 0x84), ('jne', 0x85), ('jbe', 0x86), ('ja', 0x87),
                       ('js', 0x88), ('jns', 0x89), ('jp', 0x8a), ('jnp', 0x8b),
                       ('jl', 0x8c), ('jge', 0x8d), ('jle', 0x8e), ('jg', 0x8f)):
        ck('I6', '0f %02x is %s' % (code, name),
           dis1('0f %02x 11 22 33 44' % code)[0][1].startswith(name),
           dis1('0f %02x 11 22 33 44' % code)[0][1])
    ck('I6', 'SETcc uses the SAME 16 conditions on 0F 90-9F',
       dis1('0f 94 c0')[0][1].startswith('sete') and
       dis1('0f 9c c0')[0][1].startswith('setl'),
       '%s / %s' % (dis1('0f 94 c0')[0][1], dis1('0f 9c c0')[0][1]))
    ck('I6', 'Jcc rel8 and Jcc rel32 name the same conditions',
       dis1('74 05')[0][1].startswith('je') and
       dis1('0f 84 05 00 00 00')[0][1].startswith('je'))

    # ---------------------------------------------------------------- I7
    # THE LOAD-BEARING CHECK. Two independent decoders must agree on every
    # instruction boundary in a real code section, and the chain must consume
    # the section exactly.
    for target in ('corpus', 'mini', 'probe.o'):
        try:
            data, secs = x86dec.code_sections(os.path.join(HERE, target))
        except Exception as e:
            ck('I7', 'read %s' % target, False, str(e))
            continue
        for nm, addr, off, size in secs:
            body = data[off:off + size]
            mine, end, bad = x86dec.decode_stream(body, 0, len(body))
            ref = objdump_ref(os.path.join(HERE, target), addr, size)
            if not ref:
                continue
            agree = sum(1 for a, b in zip(mine, ref)
                        if a.offset == b[0] and a.length == b[1])
            lbl = '%s %s (%d B)' % (target, nm, size)
            ck('I7', '%s: same instruction COUNT' % lbl,
               len(mine) == len(ref), '%d vs %d' % (len(mine), len(ref)))
            ck('I7', '%s: every boundary and length agrees' % lbl,
               agree == len(ref), '%d/%d' % (agree, len(ref)))
            ck('I7', '%s: the chain consumes the section exactly' % lbl,
               end == size, 'ended at %d of %d' % (end, size))
            if not (len(mine) == len(ref) and agree == len(ref)):
                for a, b in zip(mine, ref):
                    if a.offset != b[0] or a.length != b[1]:
                        ck('I7', '%s: first divergence' % lbl, False,
                           'mine off=%d len=%d %r | ref off=%d len=%d'
                           % (a.offset, a.length, a.text, b[0], b[1]))
                        break

    # ---------------------------------------------------------------- I8
    # The length arithmetic, stated once and checked as a formula.
    #   length = prefixes + opcode + modrm + sib + displacement + immediate
    for h, why in (('8b 00', 'no REX, mod=00 rm=000'),
                   ('48 8b 00', 'a REX prefix adds 1'),
                   ('8b 04 24', 'rm=100 adds a SIB byte'),
                   ('8b 40 11', 'mod=01 adds a disp8'),
                   ('8b 80 11 22 33 44', 'mod=10 adds a disp32'),
                   ('8b 05 44 33 22 11', 'mod=00 rm=101 is RIP+disp32'),
                   ('48 b8 11 22 33 44 55 66 77 88', 'REX.W makes the immediate 8 bytes'),
                   ('66 b8 11 22', 'the 0x66 prefix makes it 2 bytes'),
                   ('48 83 c0 01', 'group opcode, reg selects, imm8'),
                   ('66 2e 0f 1f 84 00 00 00 00 00', 'the 10-byte multi-byte NOP')):
        nb = len(h.split())
        g = dis1(h)
        ck('I8', 'oracle length of %-26s = %d  (%s)' % (h, nb, why),
           len(g) == 1 and g[0][0] == nb, 'got %s' % (g,))
        _d = x86dec.decode_stream(bytes.fromhex(h), 0, nb)
        _i = _d[0][0] if _d[0] else None
        ck('I8', 'x86dec agrees:  %-26s = %d' % (h, nb),
           _i is not None and _i.length == nb,
           '' if _i is None else 'x86dec says %d' % _i.length)
    ck('I8', 'REX.W widens the immediate from 4 bytes to 8',
       dis1('48 b8 11 22 33 44 55 66 77 88')[0][0] == 10 and
       dis1('b8 11 22 33 44')[0][0] == 5,
       '%d vs %d' % (dis1('48 b8 11 22 33 44 55 66 77 88')[0][0],
                     dis1('b8 11 22 33 44')[0][0]))
    ck('I8', 'but REX.W does NOT widen a C7 /0 immediate: 8 bytes, not 11',
       dis1('48 c7 40 20 00 00 00 00')[0][0] == 8,
       'the imm32 is sign-extended, not stored')
    ck('I8', 'the F6/F7 groups: the immediate depends on the ModRM reg field',
       dis1('f6 c0 01')[0][0] == 3 and dis1('f6 d0')[0][0] == 2,
       'f6 c0 01 = %d bytes (test), f6 d0 = %d bytes (not)'
       % (dis1('f6 c0 01')[0][0], dis1('f6 d0')[0][0]))

    # ---------------------------------------------------------------- A
    # The artifact, end to end.
    r = subprocess.run([sys.executable, os.path.join(HERE, 'x86dec.py'),
                        '4889e84883ec205bc3'], capture_output=True, text=True)
    ck('A', 'x86dec.py decodes a known prologue',
       r.returncode == 0 and r.stdout.count('\n') == 4, r.stderr[:70])
    ck('A', 'and names the instructions correctly',
       'mov' in r.stdout and 'sub' in r.stdout and 'pop' in r.stdout
       and 'ret' in r.stdout, r.stdout.strip().replace('\n', ' | ')[:70])
    r2 = subprocess.run([sys.executable, os.path.join(HERE, 'x86dec.py'),
                         os.path.join(HERE, 'corpus')], capture_output=True, text=True)
    ck('A', 'x86dec.py walks a real ELF and reports a mean length',
       r2.returncode == 0 and 'mean' in r2.stdout, r2.stderr[:70])
    r3 = subprocess.run([sys.executable, os.path.join(HERE, 'x86dec.py'),
                         '--why', '8b 44 24 20'.replace(' ', '')],
                        capture_output=True, text=True)
    # The negative half checks that no REX PREFIX was claimed, by its own
    # wording. An earlier version asserted the bare word 'REX' was absent,
    # which failed for the right reason and the wrong one at once: the SIB
    # explanation legitimately mentions REX.X.
    ck('A', '--why explains every field it consumed',
       'is a REX prefix' not in r3.stdout and 'ModRM' in r3.stdout
       and 'SIB' in r3.stdout and 'displacement' in r3.stdout
       and 'little-endian' in r3.stdout,
       'REX prefix claimed: %s' % ('is a REX prefix' in r3.stdout))
    r4 = subprocess.run([sys.executable, os.path.join(HERE, 'x86dec.py'),
                         '48'], capture_output=True, text=True)
    ck('A', 'a truncated instruction refuses rather than inventing bytes',
       ('ran off the end' in r4.stdout or 'truncated' in r4.stdout
        or r4.returncode != 0), (r4.stdout + r4.stderr).strip()[:60])
    r5 = subprocess.run([sys.executable, os.path.join(HERE, 'x86dec.py'),
                         'not-hex-at-all'], capture_output=True, text=True)
    ck('A', 'a non-hex argument is not fed to the hex parser',
       'fromhex' not in r5.stderr, r5.stderr.strip()[:60])

    # ---------------------------------------------------------------- I9
    # THE WHOLE TABLE, audited. Every entry in the decoder's opcode tables is
    # built into a minimal instruction of the form the table claims, and the
    # length is compared with the oracle. This is the check that finds the
    # errors no hand-written example would: it found 0F F4 mislabelled as HLT
    # (it is PMULUDQ), D3 given an immediate it does not have, and BSWAP given
    # a ModRM byte it does not have.
    def ora(bs):
        open(os.path.join(HERE, '_cc.bin'), 'wb').write(bs)
        out = subprocess.run(['objdump', '-D', '-b', 'binary', '-m',
                              'i386:x86-64', '-M', 'intel',
                              os.path.join(HERE, '_cc.bin')],
                             capture_output=True, text=True).stdout
        n, started, txt = 0, False, ''
        for l in out.splitlines():
            c = l.split('\t')
            if len(c) < 2:
                continue
            try:
                int(c[0].strip().rstrip(':'), 16)
            except ValueError:
                continue
            nb = len(c[1].split())
            if not started:
                n, started = nb, True
            else:
                n += nb
            if len(c) > 2:
                txt = c[2].strip()
            if len(c) < 3 or nb != 7:
                break
        return n, txt

    disagree, skipped, audited = [], 0, 0
    for tbl, label, pre in ((x86dec.ONEBYTE, 'one', b''),
                            (x86dec.TWO_BYTE, '0f ', bytes([0x0f]))):
        for key, (mn, form) in sorted(tbl.items()):
            if form in (None, 'unknown'):
                continue
            audited += 1
            op = pre + bytes.fromhex(key)
            f = x86dec.FORMS.get(form, {})
            cand = op + bytes([0xc0]) if f.get('modrm') else op
            if form in ('rm_i8', 'rm_imm8', 'rm_x_imm8', 'rm8_i8', 'imm_i8',
                        'acc_i8', 'r_i8', 'rel8'):
                cand += b'\x11'
            elif form in ('rm_i32', 'imm_i32', 'acc_i32', 'r_i32', 'moffs',
                          'f_imm16', 'rel32', 'enter'):
                cand += b'\x11\x22\x33\x44'
            on, otxt = ora(cand)
            if '(bad)' in otxt or otxt.startswith('.byte') or \
                    otxt.split()[:1] in (['rex'], ['rex2']):
                skipped += 1        # the oracle refuses: not a disagreement
                continue
            try:
                my = x86dec.decode_one(cand, 0, len(cand)).length
            except Exception:
                my = -1
            if my != on:
                disagree.append('%s%s mine=%d oracle=%d (%s)'
                                % (label, key, my, on, otxt))
    ck('I9', 'the whole opcode table was audited: %d entries' % audited,
       audited > 300, '%d entries, %d skipped as invalid' % (audited, skipped))
    ck('I9', 'and every one agrees with the oracle on LENGTH',
       not disagree, '; '.join(disagree[:4]) if disagree else
       '0 disagreements')

    print()
    print('=' * 78)
    by = {}
    for gname, _, o in results:
        by.setdefault(gname, [0, 0])
        by[gname][0 if o else 1] += 1
    for gname in sorted(by):
        p, f = by[gname]
        print('  %-4s %2d passed  %2d failed' % (gname, p, f))
    npass = sum(1 for _, _, o in results if o)
    print('-' * 78)
    print('  %d/%d checks passed' % (npass, len(results)))
    print('  %s' % ('ALL CLAIMS HOLD' if npass == len(results)
                    else 'FAILURES -- the course asserts something that no longer holds'))
    return 0 if npass == len(results) else 1


if __name__ == '__main__':
    sys.exit(main())
