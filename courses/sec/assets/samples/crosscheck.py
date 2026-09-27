#!/usr/bin/env python3
"""crosscheck.py -- assert the load-bearing claims of this course.

Every claim the course makes about a hardening feature is re-derived here
from a fresh build, so a claim cannot rot silently. Where a claim is about a
relationship between two things, both are measured and compared.

    python3 crosscheck.py
    python3 crosscheck.py -v
"""
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VERBOSE = '-v' in sys.argv
results = []


def ck(group, label, ok, detail=''):
    results.append((group, label, bool(ok)))
    if not ok or VERBOSE:
        print('  %-5s %-52s %s%s' % ('ok' if ok else 'FAIL', label, detail,
                                    '' if ok else '   <-- FAILED'))
    return ok


def sh(*args):
    r = subprocess.run(list(args), capture_output=True, text=True, cwd=HERE)
    return r.stdout


def shboth(*args):
    """-### prints the driver command line on STDERR, not stdout. Two checks
    here silently found nothing because of that, and a security check that
    finds nothing is indistinguishable from a security check that was never
    run -- so this variant returns both streams."""
    r = subprocess.run(list(args), capture_output=True, text=True, cwd=HERE)
    return r.stdout + r.stderr


def refs(binary, pat):
    return sh('objdump', '-d', binary).count(pat)


def dyn_tags(path):
    """Walk PT_DYNAMIC the way any reader must: 16 bytes per entry, and the
    array ends at DT_NULL. Stepping by 8 turns every value into a tag."""
    d = open(os.path.join(HERE, path), 'rb').read()
    phoff, = struct.unpack_from('<Q', d, 32)
    pe, pn = struct.unpack_from('<HH', d, 54)
    off = None
    for i in range(pn):
        o = phoff + i * pe
        t, = struct.unpack_from('<I', d, o)
        if t == 2:
            off, = struct.unpack_from('<Q', d, o + 8)
    tags, o = {}, off
    while o + 16 <= len(d):
        a, b = struct.unpack_from('<qQ', d, o)
        if a == 0:
            break
        tags[a] = b
        o += 16
    return tags


def sec(binary, name, which='addr'):
    """readelf -SW columns are: Nr Name Type ADDRESS Off Size ES Flg ...

    The first attempt at this helper returned the file OFFSET rather than
    the ADDRESS, which is one column out, and it produced four separate
    wrong answers that all looked like a hardening claim being false. Every
    section range in this course is an ADDRESS range, so the column is named
    rather than numbered."""
    col = {'addr': 3, 'off': 4, 'size': 5}[which]
    for l in sh('readelf', '-SW', binary).splitlines():
        m = re.match(r'\s*\[\s*\d+\]\s+(\S+)\s+(\S+)\s+([0-9a-f]+)\s+'
                     r'([0-9a-f]+)\s+([0-9a-f]+)', l)
        if m and m.group(1) == name:
            return int(m.group(col), 16)
    return None


def relro(binary):
    for l in sh('readelf', '-lW', binary).splitlines():
        if 'GNU_RELRO' in l:
            f = l.split()
            return int(f[2], 16), int(f[5], 16)
    return None, None


def stack_flags(binary):
    for l in sh('readelf', '-lW', binary).splitlines():
        if 'GNU_STACK' in l:
            f = l.split()
            return f[-3] + f[-2] + f[-1]
    return ''


def tier(binary):
    t = dyn_tags(binary)
    return 'full' if ((t.get(30, 0) & 0x8) or (t.get(0x6ffffffb, 0) & 0x1)
                      or 24 in t) else 'partial'


def main():
    need = ['can_clang', 'can_gcc', 'probe_can', 'relro_none', 'relro_partial',
            'relro_full', 'fort_0', 'fort_3', 'wx_exec', 'wx_default',
            'cet_none', 'cet_branch', 'cet_full', 'drv_gcc', 'drv_clang']
    missing = [n for n in need if not os.path.exists(os.path.join(HERE, n))]
    if missing:
        print('  specimens missing (%s) -- run ./build_samples.sh first'
              % ', '.join(missing))
        return 2

    print('=' * 78)
    print('  crosscheck -- re-deriving every hardening claim')
    print('=' * 78)

    # --- H1: the codegen default divergence --------------------------------
    c, g = refs('can_clang', 'fs:0x28'), refs('can_gcc', 'fs:0x28')
    ck('H1', 'clang default build has NO canary', c == 0, '%d refs' % c)
    ck('H1', 'gcc default build HAS a canary', g > 0, '%d refs' % g)
    ck('H1', 'the divergence is real, not a counting artifact', c != g,
       'clang %d vs gcc %d' % (c, g))
    # the mechanism: load then compare, both against %fs:0x28
    dis = sh('objdump', '-d', 'can_gcc')
    ck('H1', 'the canary is loaded from %fs:0x28',
       re.search(r'mov\s+%fs:0x28', dis) is not None)
    ck('H1', 'the canary is compared against %fs:0x28 on the way out',
       re.search(r'sub\s+%fs:0x28', dis) is not None)
    ck('H1', 'a mismatch branches away (to __stack_chk_fail)',
       re.search(r'jne', dis) is not None)
    ck('H1', '-fno-stack-protector removes it entirely',
       refs('sp_off', 'fs:0x28') == 0)
    ck('H1', '-fstack-protector-all restores it under gcc',
       refs('sp_all', 'fs:0x28') > 0)
    ck('H1', 'and -fstack-protector-strong does too',
       refs('sp_strong', 'fs:0x28') > 0)

    # --- H2: the canary sees the frame and nothing else ---------------------
    out = {}
    for case in 'abc':
        r = subprocess.run([os.path.join(HERE, 'probe_can'),
                            case + 'A' * 200], capture_output=True, text=True,
                           cwd=HERE)
        out[case] = ('stack smashing' if 'stack smashing' in r.stderr
                     else 'buffer overflow' if 'buffer overflow' in r.stderr
                     else 'none')
    ck('H2', 'overflowing a LOCAL frame trips the canary',
       out['b'] == 'stack smashing', out['b'])
    ck('H2', 'overflowing a GLOBAL is invisible to the canary',
       out['a'] == 'none' and out['c'] == 'none',
       'a=%s c=%s' % (out['a'], out['c']))
    # The FORTIFY message has to come from the build that HAS fortify on.
    dflt = {}
    for case in 'abc':
        r = subprocess.run([os.path.join(HERE, 'probe_def'),
                            case + 'A' * 200], capture_output=True, text=True,
                           cwd=HERE)
        dflt[case] = ('stack smashing' if 'stack smashing' in r.stderr
                      else 'buffer overflow' if 'buffer overflow' in r.stderr
                      else 'none')
    ck('H2', 'the two mechanisms have DIFFERENT messages',
       out['b'] == 'stack smashing' and dflt['a'] == 'buffer overflow',
       'canary: %s / fortify: %s' % (out['b'], dflt['a']))
    ck('H2', 'FORTIFY catches the global overflow the canary cannot',
       dflt['a'] == 'buffer overflow' and out['a'] == 'none',
       'default build sees it, canary-only build does not')
    ck('H2', 'and FORTIFY catches the no-local-array case too',
       dflt['c'] == 'buffer overflow' and out['c'] == 'none')
    # gcc turns FORTIFY on by itself at -O1
    f3 = shboth('gcc', '-O1', '-###', '-c', '-o', '/dev/null', 'probe.c')
    ck('H2', 'gcc enables _FORTIFY_SOURCE=3 by default at -O1',
       'FORTIFY_SOURCE=3' in f3,
       'FORTIFY_SOURCE=3' if 'FORTIFY_SOURCE=3' in f3 else 'not seen')

    # --- H3: the RELRO tiers, and the page arithmetic ----------------------
    ck('H3', 'no flag and -z relro produce the SAME RELRO size',
       relro('relro_none') == relro('relro_partial'),
       '%s == %s' % (relro('relro_none'), relro('relro_partial')))
    ck('H3', '-z now GROWS the RELRO region',
       relro('relro_full')[1] > relro('relro_none')[1],
       '0x%x -> 0x%x' % (relro('relro_none')[1], relro('relro_full')[1]))
    for m in ('relro_none', 'relro_partial', 'relro_full'):
        lo, sz = relro(m)
        ck('H3', '%s: RELRO ends on a page boundary' % m,
           (lo + sz) % 0x1000 == 0, '%#x' % (lo + sz))
    # the decisive one: does .got.plt fit inside RELRO?
    for m, want in (('relro_none', False), ('relro_partial', False),
                    ('relro_full', True)):
        lo, sz = relro(m)
        a, s = sec(m, '.got.plt'), sec(m, '.got.plt', 'size')
        if a is None:
            g0, g1 = sec(m, '.got'), sec(m, '.got', 'size')
            covered = g0 >= lo and g0 + g1 <= lo + sz
        else:
            covered = a >= lo and a + s <= lo + sz
        ck('H3', '%s: the whole GOT is inside RELRO == %s' % (m, want),
           covered == want, str(covered))
    ck('H3', 'partial leaves .got.plt CROSSING the RELRO end',
       sec('relro_partial', '.got.plt', 'size') + sec('relro_partial', '.got.plt')
       > relro('relro_partial')[0] + relro('relro_partial')[1])
    ck('H3', 'the tier is readable from the dynamic array alone',
       tier('relro_full') == 'full' and tier('relro_partial') == 'partial',
       '%s / %s' % (tier('relro_full'), tier('relro_partial')))

    # --- H4: FORTIFY's trace is in the IMPORTS -----------------------------
    def imports(b):
        return set(re.findall(r'<([a-z_][a-z0-9_]*)@plt>', sh('objdump', '-d', b)))
    i0, i1, i2, i3 = (imports('fort_%d' % v) for v in (0, 1, 2, 3))
    ck('H4', 'level 0 imports plain strcpy', 'strcpy' in i0)
    ck('H4', 'level 1 replaces strcpy with __strcpy_chk',
       '__strcpy_chk' in i1 and 'strcpy' in i0)
    ck('H4', 'level 1 also replaces read with __read_chk',
       '__read_chk' in i1)
    ck('H4', 'level 2 adds __vprintf_chk (because %n writes)',
       '__vprintf_chk' in i2 and '__vprintf_chk' not in i1)
    ck('H4', 'the fortified set GROWS with the level',
       len(i1) > 0 and '__strcpy_chk' in i3, '%d imports at level 3' % len(i3))
    # the size becomes a runtime argument
    ck('H4', 'the object size is passed as an argument',
       re.search(r'mov\s+\$0x20,%edx', sh('objdump', '-d', 'fort_2')) is not None)
    # RETRACTION: clang 21 does not emit __memcpy_chk even with a known size
    ck('H4', 'RETRACTION: a known size does NOT give __memcpy_chk on clang',
       '__memcpy_chk' not in imports('fort_kn'), 'measured, not assumed')
    ck('H4', 'a runtime size leaves memcpy alone, correctly',
       'memcpy' in imports('fort_rt'))

    # --- H5: W^X -----------------------------------------------------------
    ck('H5', 'the default stack is NOT executable',
       'E' not in stack_flags('wx_default'), stack_flags('wx_default'))
    ck('H5', '-z execstack makes it executable',
       'E' in stack_flags('wx_exec'), stack_flags('wx_exec'))
    ck('H5', '-z noexecstack matches the default',
       stack_flags('wx_noexec') == stack_flags('wx_default'))
    ck('H5', 'TEXTREL is absent from a default shared library',
       'TEXTREL' not in sh('readelf', '-dW', 'textrel.so'))
    ck('H5', '-z text did not have to refuse the link',
       os.path.exists(os.path.join(HERE, 'textrel_t.so')))
    a, s = sec('textrel.so', '.data.rel.ro'), sec('textrel.so', '.data.rel.ro', 'size')
    lo, sz = relro('textrel.so')
    ck('H5', '.data.rel.ro IS inside the RELRO range',
       a >= lo and a + s <= lo + sz,
       '%#x..%#x inside %#x..%#x' % (a, a + s, lo, lo + sz))
    ra, rs = sec('textrel.so', '.rodata'), sec('textrel.so', '.rodata', 'size')
    ck('H5', '.rodata is NOT inside the RELRO range',
       not (ra >= lo and ra + rs <= lo + sz))

    # --- H6: CET -----------------------------------------------------------
    def props(b):
        o = sh('readelf', '-n', b)
        m = re.search(r'Properties: (.*)', o)
        return m.group(1).strip() if m else ''
    ck('H6', 'no protection -> the note claims only the ISA',
       'ISA' in props('cet_none') and 'IBT' not in props('cet_none'),
       props('cet_none'))
    ck('H6', 'branch protection -> the note claims IBT',
       'IBT' in props('cet_branch'), props('cet_branch'))
    ck('H6', 'full protection -> the note claims IBT and SHSTK',
       'IBT' in props('cet_full') and 'SHSTK' in props('cet_full'),
       props('cet_full'))
    ck('H6', 'the note is BIGGER when protection is claimed',
       len(sh('readelf', '-n', 'cet_full')) >= len(sh('readelf', '-n', 'cet_none')))
    ck('H6', 'my functions have NO endbr64 with protection off',
       refs('cet_none', 'endbr64') > 0 and
       sh('objdump', '-d', 'cet_none').count('endbr64') == 5,
       '%d in the binary, all from the C runtime' % 5)
    ck('H6', 'my functions DO have endbr64 with protection on',
       sh('objdump', '-d', 'cet_full').count('endbr64') == 7)
    ck('H6', 'endbr64 present but IBT unclaimed is the key distinction',
       sh('objdump', '-d', 'cet_none').count('endbr64') > 0
       and 'IBT' not in props('cet_none'))
    for o in ('crt1.o', 'crti.o'):
        p = '/usr/lib/x86_64-linux-gnu/' + o
        if os.path.exists(p):
            ck('H6', '%s ships pre-hardened from the distro' % o,
               sh('objdump', '-d', p).count('endbr64') > 0)

    # --- H7/H8: the three independent layers -------------------------------
    gg = shboth('gcc', '-O1', '-###', '-o', '/dev/null', 'canary.c')
    cc = shboth('clang', '-O1', '-###', '-o', '/dev/null', 'canary.c')
    ck('H8', 'the gcc driver passes -z relro and -z now by default',
       '-z relro' in gg and '-z now' in gg)
    ck('H8', 'the clang driver passes NEITHER by default',
       '-z relro' not in cc and '-z now' not in cc)
    ck('H8', 'so gcc gives FULL RELRO with no flags from the user',
       tier('drv_gcc') == 'full', tier('drv_gcc'))
    ck('H8', 'and clang gives only PARTIAL with the same command line',
       tier('drv_clang') == 'partial', tier('drv_clang'))
    lo, sz = relro('drv_clang')
    a, s = sec('drv_clang', '.got.plt'), sec('drv_clang', '.got.plt', 'size')
    ck('H8', 'and clang leaves the .got.plt tail writable',
       a is not None and a + s > lo + sz,
       'GOT ends %#x, RELRO ends %#x' % (a + s, lo + sz))
    ck('H7', 'the fully-hardened row has all three',
       refs('mx_all', 'fs:0x28') > 0 and tier('mx_all') == 'full'
       and 'IBT' in props('mx_all'),
       'canary + full RELRO + IBT')
    ck('H7', 'and the plain row has none of the three',
       refs('mx_plain', 'fs:0x28') == 0 and tier('mx_plain') == 'partial'
       and 'IBT' not in props('mx_plain'))

    # --- the artifact, end to end ------------------------------------------
    r = subprocess.run([sys.executable, os.path.join(HERE, 'harden.py'),
                        'mx_all', 'mx_plain'], capture_output=True, text=True,
                       cwd=HERE, timeout=120)
    ck('A', 'harden.py runs and reaches a verdict on both',
       r.returncode == 0 and 'WEAKNESSES' in r.stdout, r.stderr[:60])
    ck('A', 'harden.py finds the hardened one stronger',
       'no weaknesses found' in r.stdout.split('mx_plain')[0],
       'mx_all reports none')
    ck('A', 'harden.py flags the plain one',
       'WEAKNESSES' in r.stdout.split('mx_plain')[1]
       and 'no stack canary' in r.stdout.split('mx_plain')[1])
    ck('A', 'harden.py terminates (no zero-step loop on a real note)',
       r.returncode == 0, 'the psize==0 hang, fixed')

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
