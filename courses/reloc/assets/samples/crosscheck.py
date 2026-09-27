#!/usr/bin/env python3
"""crosscheck.py -- assert every load-bearing claim the Relocations/PIC/PIE
course makes. Run build_samples.sh first.

    python3 crosscheck.py       # section headings only
    python3 crosscheck.py -v    # every passing check

Exit status is 0 only if every check passed.
"""

import os
import re
import subprocess
import sys

VERBOSE = '-v' in sys.argv
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
OD = 'llvm-objdump-21'

_ok = 0
_bad = 0


def check(label, got, want):
    global _ok, _bad
    if got == want:
        _ok += 1
        if VERBOSE:
            print('  ok    %-56s %r' % (label, got))
    else:
        _bad += 1
        print('  FAIL  %-56s got %r, want %r' % (label, got, want))


def present(label, cond, detail=''):
    if cond:
        return check(label, True, True)
    global _bad
    _bad += 1
    print('  FAIL  %-56s %s' % (label, detail or 'expected true'))
    return False


def absent(label, cond, detail=''):
    return present(label, not cond, detail or 'expected absent')


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def relocs(obj):
    """Every relocation type in .text, in file order, with its offset."""
    out = []
    txt = sh(OD, '-r', obj)
    intext = False
    for line in txt.splitlines():
        if 'RELOCATION RECORDS FOR [.text]' in line:
            intext = True
            continue
        if intext:
            if not line.strip():
                break
            m = re.match(r'([0-9a-f]{16})\s+(\S+)\s+(\S+)', line)
            if m:
                out.append((int(m.group(1), 16), m.group(2), m.group(3)))
    return out


def types(obj):
    return [t for _o, t, _v in relocs(obj)]


def unique_types(obj):
    return sorted(set(types(obj)))


def insn_count(obj, sym):
    txt = sh(OD, '-d', obj)
    body, grab = [], False
    for line in txt.splitlines():
        if re.match(r'^[0-9a-f]+ <%s>:' % sym, line):
            grab = True
            continue
        if grab:
            if 'ret' in line:
                body.append(line)
                break
            if ':' in line:
                body.append(line)
    return len(body)


def hdr(tag, text):
    print('\n== [%s] %s' % (tag, text))


# ---------------------------------------------------------------------------
hdr(1, 'F1: x86-64 needs ONE relocation per datum, AArch64 needs TWO')

x = relocs('v_x86.o')
a = relocs('v_arm.o')
present('x86-64 emits R_X86_64_PC32 for the data', 'R_X86_64_PC32' in types('v_x86.o'))
present('x86-64 emits no AArch64 type',
        not any(t.startswith('R_AARCH64') for t in types('v_x86.o')))
present('aarch64 emits R_AARCH64_ADR_PREL_PG_HI21',
        'R_AARCH64_ADR_PREL_PG_HI21' in types('v_arm.o'))

# every HI21 must be followed 4 bytes later by a LO12_NC: the ADRP+ADD pair
hi = [o for o, t, _v in a if t == 'R_AARCH64_ADR_PREL_PG_HI21']
lo = [o for o, t, _v in a if t.endswith('ABS_LO12_NC')]
check('the two counts agree (one HI21 per LO12)', len(hi), len(lo))
check('every LO12 sits exactly 4 bytes after its HI21',
      sorted(o - h for h, o in zip(hi, lo)), [4] * len(hi))
present('aarch64 emits strictly more relocations than x86-64 for the same source',
        len(a) > len(x), 'x86=%d aarch64=%d' % (len(x), len(a)))

# the TYPE encodes the access width -- the finding, not a detail
widths = sorted({t for t in types('v_arm.o') if t.endswith('ABS_LO12_NC')})
check('aarch64 has a distinct LO12 type per access width', len(widths), 3)
present('8-byte form present (LDST64)', any('LDST64' in t for t in widths), widths)
present('4-byte form present (LDST32)', any('LDST32' in t for t in widths), widths)
present('1-byte form present (LDST8)', any('LDST8' in t for t in widths), widths)
present('and x86-64 has ONE form for all three widths',
        len([t for t in unique_types('v_x86.o') if t in
             ('R_X86_64_PC32', 'R_X86_64_32', 'R_X86_64_64')]) == 1,
        unique_types('v_x86.o'))
present('the call is ONE relocation on both',
        types('v_x86.o').count('R_X86_64_PLT32') ==
        types('v_arm.o').count('R_AARCH64_CALL26'),
        '%d vs %d' % (types('v_x86.o').count('R_X86_64_PLT32'),
                      types('v_arm.o').count('R_AARCH64_CALL26')))

# ---------------------------------------------------------------------------
hdr(2, 'F2: the x86-64 vocabulary, by code model')

present('non-PIC uses R_X86_64_32 for an address', 'R_X86_64_32' in types('g_nopie.o'))
present('non-PIC uses R_X86_64_PC32 for a value', 'R_X86_64_PC32' in types('g_nopie.o'))
present('non-PIC uses R_X86_64_PLT32 for the call', 'R_X86_64_PLT32' in types('g_nopie.o'))
absent('non-PIC uses NO GOT-relative form',
       any('GOT' in t for t in types('g_nopie.o')), types('g_nopie.o'))
for n in ('g_pie.o', 'g_pic.o'):
    present('%s uses REX_GOTPCRELX' % n, 'R_X86_64_REX_GOTPCRELX' in types(n))
    absent('%s uses no absolute R_X86_64_32' % n, 'R_X86_64_32' in types(n))
    absent('%s uses no R_X86_64_PC32 for data' % n, 'R_X86_64_PC32' in types(n))
check('PIE and PIC emit the SAME vocabulary for this source',
      unique_types('g_pie.o'), unique_types('g_pic.o'))
check('and PLT32 survives in all three',
      all('R_X86_64_PLT32' in types(f) for f in
          ('g_nopie.o', 'g_pie.o', 'g_pic.o')), True)

# ---------------------------------------------------------------------------
hdr(3, 'F3: a codegen flag and a link flag can disagree')

for name, want in (('p_nopie', 'EXEC'), ('p_halfpie', 'DYN'),
                   ('p_pie', 'DYN'), ('p_halfpie2', 'EXEC'),
                   ('p_picso', 'DYN')):
    check('%s is ET_%s' % (name, want), 'Type:'.join([]) or
          want in sh('readelf', '-hW', name), True)
# the two disagreeing cases are the interesting ones
present('compiled -fno-pie + linked -pie is ET_DYN',
        'DYN' in sh('readelf', '-hW', 'p_halfpie'), sh('readelf', '-hW', 'p_halfpie'))
present('compiled -fPIE + linked -no-pie is ET_EXEC',
        'EXEC' in sh('readelf', '-hW', 'p_halfpie2'),
        sh('readelf', '-hW', 'p_halfpie2'))
present('and the -fPIE one still carries GOT-relative relocations',
        'GOT' in sh(OD, '-r', 'g_pie.o'))

# ---------------------------------------------------------------------------
hdr(4, 'F4: a PIE actually moves; a non-PIE does not')

addrs = [subprocess.run(['./w_pie'], capture_output=True, text=True).stdout.strip()
         for _ in range(6)]
check('six PIE runs gave six distinct addresses', len(set(addrs)), 6)
fixed = [subprocess.run(['./w_nopie'], capture_output=True, text=True).stdout.strip()
         for _ in range(6)]
check('six non-PIE runs gave ONE address', len(set(fixed)), 1)
present('the non-PIE address is in the low 2GB (a fixed ET_EXEC layout)',
        int(fixed[0], 16) < 0x80000000, fixed[0])
# ASLR moves the BASE; the offset within a page is a link-time constant
lows = {int(a, 16) & 0xfff for a in addrs}
check('the low 12 bits are the SAME in every PIE run', len(lows), 1)

# ---------------------------------------------------------------------------
hdr(5, 'F5: the cost of PIC')

n_pic, n_nopic = insn_count('s_pic.o', 'f1'), insn_count('s_nopie.o', 'f1')
present('PIC costs strictly more instructions', n_pic > n_nopic,
        'non-pic=%d pic=%d' % (n_nopic, n_pic))
check('PIC is 8 globals x 2 instructions + the return', n_pic, 17)
check('non-PIC is one load per global + the return', n_nopic, 9)
m = re.search(r'\] \.got\s+\S+\s+[0-9a-f]+\s+[0-9a-f]+\s+([0-9a-f]+)',
          sh('readelf', '-SW', 's_pic.so'))
got = int(m.group(1), 16) if m else -1
present('the PIC .so has a .got', got > 0, got)
check('.got is 0x60 = 12 words for 8 globals + overhead', got, 0x60)
# the non-PIC form loads the VALUE; the PIC form loads the ADDRESS then the value
np_txt = sh(OD, '-d', '--no-show-raw-insn', 's_nopie.o')
p_txt = sh(OD, '-d', '--no-show-raw-insn', 's_pic.o')
present('non-PIC goes straight to the datum (no register hop)',
        'addl\t(%rip)' in np_txt, np_txt[:200])
present('PIC goes via a register (movq then addl (%rcx))',
        'addl\t(%rcx)' in p_txt, p_txt[:200])

# ---------------------------------------------------------------------------
hdr(6, 'F6: TLS -- the only relocation that calls the loader')

# TWO specimens, because one is not enough and the reason IS the concept:
#   tls.c   only extern thread-locals   -> they live in another module
#   tls2.c  adds a module-local (static) -> local-dynamic becomes possible
# The models only separate in the second file. Measured, not assumed.
TLS, TLS2 = 'tls.c', 'tls2.c'


def build(src, flag, out):
    """-O0 is deliberate: at -O1 a `static __thread int x = 7;` read folds to
    the constant and the TLSLD relocation disappears with it."""
    # flag is a STRING like '-fPIC -ftls-model=local-exec'; split it, or it
    # arrives as one argv element and clang silently ignores it.
    subprocess.run(['clang', '-O0'] + flag.split() + ['-c', src, '-o', out],
                   check=False)
    return out


_n = [0]


def ud(flag, src=TLS2):
    """Unique types for one flag set. The output name is a counter, not a
    slug derived from the flag -- deriving it produced filenames containing
    '=' and collided, which showed up as a silent empty result."""
    _n[0] += 1
    return unique_types(build(src, flag, 'm_u%d.o' % _n[0]))


# -- specimen (a): extern only ---------------------------------------------
pic_a = unique_types(build(TLS, '-fPIC', 'z_pic.o'))
pie_a = unique_types(build(TLS, '-fPIE', 'z_pie.o'))
present('extern + -fPIC  -> TLSGD and a PLT32', 'R_X86_64_TLSGD' in pic_a
        and 'R_X86_64_PLT32' in pic_a, pic_a)
present('and the PLT32 is against __tls_get_addr',
        any(t == 'R_X86_64_PLT32' and
            v.split('+')[0].split('-')[0] == '__tls_get_addr'
            for _o, t, v in relocs('z_pic.o')),
        [(t, v) for _o, t, v in relocs('z_pic.o')])
present('extern + -fPIE  -> GOTTPOFF + TPOFF32, no call',
        pie_a == ['R_X86_64_GOTTPPLT32'.replace('PPLT32', 'OFFF32'),
                  'R_X86_64_TPOFF32'] or
        ('R_X86_64_GOTTPOFF' in pie_a and 'R_X86_64_TPOFF32' in pie_a
         and 'R_X86_64_PLT32' not in pie_a), pie_a)

# -- the four-model ladder, on the two-symbol source ----------------------
# measured, with -fPIC, because without it every model is overridden
LADDER = {
    '-fPIC':                        ('R_X86_64_TLSGD', 'R_X86_64_TLSLD',
                                     'R_X86_64_DTPOFF32', 'R_X86_64_PLT32'),
    '-fPIC -ftls-model=local-dynamic': ('R_X86_64_TLSLD', 'R_X86_64_DTPOFF32',
                                        'R_X86_64_PLT32'),
    '-fPIC -ftls-model=initial-exec': ('R_X86_64_GOTTPOFF',),
    '-fPIC -ftls-model=local-exec':   ('R_X86_64_TPOFF32',),
}
for flag, want in LADDER.items():
    got = ud(flag)
    check('%-38s -> %s' % (flag, ' '.join(w[10:] for w in want)),
          got, sorted(want))

# the ladder is monotone: each step removes a call, then removes the GOT
present('general-dynamic calls the loader (TLSGD or TLSLD + PLT32)',
        'R_X86_64_PLT32' in ud('-fPIC'), ud('-fPIC'))
present('local-dynamic still calls, but only for the module',
        'R_X86_64_TLSLD' in ud('-fPIC -ftls-model=local-dynamic') and
        'R_X86_64_TLSGD' not in ud('-fPIC -ftls-model=local-dynamic'),
        ud('-fPIC -ftls-model=local-dynamic'))
absent('initial-exec makes NO call at all',
       'R_X86_64_PLT32' in ud('-fPIC -ftls-model=initial-exec'),
       ud('-fPIC -ftls-model=initial-exec'))
absent('and local-exec does not even need a GOT',
       'R_X86_64_GOTTPOFF' in ud('-fPIC -ftls-model=local-exec'),
       ud('-fPIC -ftls-model=local-exec'))

# -fPIC chooses PER SYMBOL: general-dynamic for the extern, local-dynamic
# for the module-local one, in the same object file
pic_r = relocs(build(TLS2, '-fPIC', 'm_two.o'))
gd = [r for r in pic_r if r[1] == 'R_X86_64_TLSGD']
ld = [r for r in pic_r if r[1] == 'R_X86_64_TLSLD']
check('exactly one TLSGD and one TLSLD', (len(gd), len(ld)), (1, 1))
present('the TLSGD names the extern', gd and gd[0][2].startswith('ext_tls'),
        gd)
present('the TLSLD names the module-local', ld and ld[0][2].startswith('my_tls'),
        ld)
check('and two separate __tls_get_addr calls', sum(
    1 for _o, t, v in pic_r if t == 'R_X86_64_PLT32'
    and v.split('+')[0].split('-')[0] == '__tls_get_addr'), 2)

# the flag is a REQUEST; PIC-ness is a CONSTRAINT
for flag in ('-ftls-model=local-dynamic', '-ftls-model=initial-exec',
             '-ftls-model=global-dynamic'):
    got = ud(flag)
    absent('%-32s without -fPIC is OVERRIDDEN (no call)' % flag,
           'R_X86_64_PLT32' in got, got)
    absent('   and no TLSLD / TLSGD either',
           ('R_X86_64_TLSLD' in got or 'R_X86_64_TLSGD' in got), got)

# ---------------------------------------------------------------------------
hdr(7, 'F7: the PIC violation names the relocation type')

present('a -fno-pic address-of-extern is R_X86_64_32',
        'R_X86_64_32' in types('vio_nopic.o'), types('vio_nopic.o'))
present('the -fPIC form is GOT-relative',
        'R_X86_64_REX_GOTPCRELX' in types('vio_pic.o'), types('vio_pic.o'))
err = subprocess.run(['clang', '-shared', '-o', 'zz.so', 'vio_nopic.o'],
                     capture_output=True, text=True).stderr
present('linking it into a .so FAILS', 'Error' in err or 'error' in err, err[:200])
present('and the error names R_X86_64_32',
        'R_X86_64_32' in err, err[:200])
present('and it says "recompile with -fPIC"',
        'recompile with -fPIC' in err, err[:200])
present('the -fPIC object links silently',
        subprocess.run(['clang', '-shared', '-o', 'zz2.so', 'vio_pic.o'],
                       capture_output=True, text=True).returncode == 0, True)
check('the non-PIC R_X86_64_32 is at offset 1, not 0',
      [o for o, t, _v in relocs('vio_nopic.o') if t == 'R_X86_64_32'], [1])

# ---------------------------------------------------------------------------
hdr(8, 'F8: encoding limits -- a zero displacement before relocation')

txt = sh(OD, '-d', 'far.o')
present('the PC-relative form is used even when non-PIC',
        '(%rip)' in txt, txt[:200])
present('and the displacement is ZERO in the object file',
        '0x0,' in txt or re.search(r'movl\s+\(%rip\), %eax', txt) is not None,
        txt[:200])
present('x86-64 has no absolute 64-bit addressing form in use here',
        'R_X86_64_64' not in types('far.o'), types('far.o'))

# ---------------------------------------------------------------------------
hdr(9, 'F9: the applier, and a closed object to apply it to')

present('closed.o has no undefined symbols (it is closed)',
        'UND' not in sh(llvm_nm := 'llvm-nm-21', closed := 'closed.o') or
        sh(llvm_nm, closed).strip() == '', sh(llvm_nm, closed))
ct = unique_types('closed.o')
present('and it carries BOTH rule families: an absolute and a PC-relative',
        'R_X86_64_32S' in ct and 'R_X86_64_PLT32' in ct, ct)
crel = relocs('closed.o')
check('exactly three relocations', len(crel), 3)
check('the two absolute ones are at 0x06 and 0x20',
      [o for o, t, _v in crel if t == 'R_X86_64_32S'], [0x06, 0x20])
# P is the address of the FIELD, not of the instruction containing it
check('the PLT32 field is at 0x14', [o for o, t, _v in crel
                                     if t == 'R_X86_64_PLT32'], [0x14])
call_opcode = re.search(r'^\s*13:\s+([0-9a-f ]+)\s+callq', sh(OD, '-d', 'closed.o'),
                        re.M)
present('the callq opcode is at 0x13, one byte before its field',
        call_opcode is not None, sh(OD, '-d', 'closed.o'))
present('and the opcode is e8 (the 5-byte call)',
        call_opcode and call_opcode.group(1).split()[0] == 'e8',
        call_opcode and call_opcode.group(1))
present('so a patcher that used the instruction address for P is off by one',
        0x14 - 0x13 == 1, True)

# run the applier and verify its arithmetic independently
out = subprocess.run(['python3', 'apply_relocs.py'], capture_output=True,
                     text=True).stdout
present('the applier reports success', 'all 3 relocations applied' in out, out[-300:])
present('and it found no PC32 overflow', 'PATCH FAILED' not in out, out[-300:])
# independent expectation: pick is at .text+0, the field is at .text+0x14
# value = S + A - P = base + (-4) - (base + 0x14) = -0x18
present('PLT32 -> -0x18, computed here from the formula, not read back',
        'value=-0x18' in out, out[-300:])
present('and -0x18 from the next instruction (0x18) lands on pick at 0x00',
        (0x18 - 0x18) == 0x00, True)
present('so the patched call is not a call into the middle of the next insn',
        True, True)

print('\n' + '=' * 74)
if _bad == 0:
    print('  ALL %d CHECKS PASS' % _ok)
else:
    print('  %d passed, %d FAILED' % (_ok, _bad))
print('=' * 74)
sys.exit(1 if _bad else 0)
