#!/usr/bin/env python3
"""crosscheck.py -- assert every load-bearing claim the course makes.

Run build_samples.sh first. This does not re-derive the findings from the
specifications; it re-reads the artefacts those findings were measured from and
fails loudly if one of them has stopped being true. A course that quotes a
number should be able to check that number.

    python3 crosscheck.py          # quiet: prints only the section headings
    python3 crosscheck.py -v       # every passing check as it runs

Exit status is 0 only if every check passed.

Two of these checks exist because they caught an over-broad claim in the course
text during development, which is the whole argument for having this file:

  * "the PIE build has no COPY relocation" was false -- a PIE can still get a
    COPY for a libc datum such as `stdout`. The claim that holds is about
    lib_data specifically.
  * "the .plt is identical under -z now" needs the rip-relative displacement
    normalised away, because the GOT moves between the two builds. Comparing
    the raw disassembly reports a difference that is not there.
"""

import os
import re
import struct
import subprocess
import sys

VERBOSE = '-v' in sys.argv
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

_ok = 0
_bad = 0


def check(label, got, want):
    global _ok, _bad
    if got == want:
        _ok += 1
        if VERBOSE:
            print('  ok    %-54s %r' % (label, got))
    else:
        _bad += 1
        print('  FAIL  %-54s got %r, want %r' % (label, got, want))
    return got == want


def absent(label, present, why=''):
    """A negative assertion, spelled so it cannot be inverted by accident."""
    return check(label, bool(present), False)


def present(label, cond, detail=''):
    if cond:
        return check(label, True, True)
    global _bad
    _bad += 1
    print('  FAIL  %-54s %s' % (label, detail or 'expected true'))
    return False


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def run(exe):
    return subprocess.run(['./' + exe], capture_output=True, text=True).stdout


def rc(exe):
    return subprocess.run(['./' + exe], capture_output=True, text=True).returncode


def sections(path):
    out = {}
    for line in sh('readelf', '-SW', path).splitlines():
        m = re.match(r'\s*\[\s*\d+\]\s+(\S+)\s+\S+\s+([0-9a-f]+)\s+'
                     r'([0-9a-f]+)\s+([0-9a-f]+)', line)
        if m:
            out[m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16),
                               int(m.group(4), 16))
    return out


def dynsym_names(path):
    out = []
    for line in sh('readelf', '--dyn-syms', '-W', path).splitlines():
        f = line.split()
        if len(f) >= 8 and f[0].rstrip(':').isdigit():
            out.append(f[7])
    return out


def elf_hash(s):
    """The SysV ELF hash, used by .hash, .gnu.hash AND .gnu.version_d."""
    h = 0
    for c in s.encode():
        h = (h << 4) + c
        g = h & 0xf0000000
        if g:
            h ^= g >> 24
        h &= ~g & 0xffffffff
    return h


def hdr(tag, text):
    print('\n== [%s] %s' % (tag, text))


# ---------------------------------------------------------------------------
hdr(1, 'F1/F2: hidden and internal demote the binding; protected does not')

nm = sh('llvm-nm-21', 'libvis.so')
present('hid_fn is LOCAL (lowercase t)', re.search(r'^[0-9a-f]+ t hid_fn$', nm, re.M), nm)
present('int_fn is LOCAL', re.search(r'^[0-9a-f]+ t int_fn$', nm, re.M))
present('hid_data is LOCAL (lowercase d)', re.search(r'^[0-9a-f]+ d hid_data$', nm, re.M))
present('prot_fn stays GLOBAL (uppercase T)', re.search(r'^[0-9a-f]+ T prot_fn$', nm, re.M))
present('def_fn stays GLOBAL', re.search(r'^[0-9a-f]+ T def_fn$', nm, re.M))
dyn = dynsym_names('libvis.so')
present('DEFAULT is exported', 'def_fn' in dyn)
present('PROTECTED is exported', 'prot_fn' in dyn)
absent('HIDDEN is not in .dynsym', 'hid_fn' in dyn)
absent('INTERNAL is not in .dynsym', 'int_fn' in dyn)
absent('hidden data not in .dynsym', 'hid_data' in dyn)

# ---------------------------------------------------------------------------
hdr(2, 'F3: the duplicate-definition message depends on link order')

a = subprocess.run(['clang', '-o', '/dev/null', 'dup_a.o', 'dup_b.o', 'dup_m.o'],
                   capture_output=True, text=True).stderr
b = subprocess.run(['clang', '-o', '/dev/null', 'dup_b.o', 'dup_a.o', 'dup_m.o'],
                   capture_output=True, text=True).stderr
present('order a: b is the duplicate', 'dup_b.c' in a and 'first defined' in a, a)
present('order b: a is the duplicate', 'dup_a.c' in b and 'first defined' in b, b)
check('and the two messages really do differ', a.strip() != b.strip(), True)

# ---------------------------------------------------------------------------
hdr(3, 'F5: COMMON is a storage class, not a weaker definition')

x = sh('readelf', '-sW', 'tent_x.o')
xn = sh('readelf', '-sW', 'tent_xn.o')
present('-fcommon puts cvar in SHN_COMMON', 'COM cvar' in x, x)
present('-fno-common makes it a real .bss definition',
        re.search(r'\s3 cvar', xn) is not None, xn)
present('and the two files are otherwise the same shape',
        'OBJECT' in x and 'OBJECT' in xn)
present('the -fcommon link succeeds and computes 5', rc('tent_com') == 5, rc('tent_com'))
e = subprocess.run(['clang', '-o', '/dev/null', 'tent_xn.o', 'tent_yn.o', 'tent_zn.o'],
                   capture_output=True, text=True).stderr
present('the -fno-common link fails with multiple definition',
        'multiple definition' in e, e)

# ---------------------------------------------------------------------------
hdr(4, 'F6: demand-driven, one pass, left to right')

present('right order links', os.path.exists('ord_ok'))
present('the right order computes 21', rc('ord_ok') == 21, rc('ord_ok'))
absent('the wrong order produced no binary', os.path.exists('ord_bad'))
present('--start-group rescues the wrong order', os.path.exists('ord_grp'))
present('and computes the same 21', rc('ord_grp') == 21, rc('ord_grp'))
mp = open('ord.map').read() if os.path.exists('ord.map') else ''
present('map: libMA.a(ma.o) satisfied mu.o (a_fn)',
        re.search(r'libMA\.a\(ma\.o\)\s+mu\.o \(a_fn\)', mp) is not None, mp[:200])
present('map: libMB.a(db_pic.o) satisfied libMA.a(ma.o) (b_data)',
        re.search(r'libMB\.a\(db_pic\.o\)\s+libMA\.a\(ma\.o\) \(b_data\)', mp) is not None)
absent('map: libMB.a(mb.o) was NEVER extracted', 'libMB.a(mb.o)' in mp)

# ---------------------------------------------------------------------------
hdr(5, 'F7: -z now changes the dynamic section and NOT the code')

check('.plt is the same size in both',
      sections('lt_lazy').get('.plt', (0, 0, 0))[2],
      sections('lt_now').get('.plt', (0, 0, 0))[2])
check('.plt is 0x30 bytes (PLT0 + 2 x 16)', sections('lt_lazy').get('.plt', (0, 0, 0))[2], 0x30)
absent('lazy has no BIND_NOW', 'BIND_NOW' in sh('readelf', '-dW', 'lt_lazy'))
present('eager HAS BIND_NOW', 'BIND_NOW' in sh('readelf', '-dW', 'lt_now'))
present('eager HAS FLAGS_1 ... NOW',
        re.search(r'FLAGS_1.*NOW', sh('readelf', '-dW', 'lt_now')) is not None)


def plt_body(path):
    """Opcodes only. The rip-relative DISPLACEMENT must be normalised away: the
    GOT moves between the two builds, so 0x2fca(%rip) and 0x2faa(%rip) are the
    same instruction at a different address. Comparing raw disassembly reports
    a difference that is not there."""
    out = []
    for line in sh('objdump', '-d', '--no-show-raw-insn', '-j', '.plt', path).splitlines():
        m = re.match(r'\s+[0-9a-f]+:\s+(\S+)\s*(.*)', line)
        if m:
            body = m.group(2).split('#')[0]
            body = re.sub(r'0x[0-9a-f]+\(%rip\)', 'OFF(%rip)', body)
            body = re.sub(r'\b0x[0-9a-f]+\b', 'NUM', body)
            out.append(m.group(1) + ' ' + body.strip())
    return out


check('the PLT instruction sequences are IDENTICAL',
      plt_body('lt_lazy'), plt_body('lt_now'))
body = plt_body('lt_lazy')
check('the lazy path is a bare "push $NUM" index push',
      sum(1 for i in body if i.strip() == 'push $NUM'), 2)
check('each one jumps back to PLT0', sum(1 for i in body if 'jmp 401020' in i), 2)
present('PLT0 pushes the link_map then jumps to the resolver',
        body[0].startswith('push OFF(%rip)') and body[1].startswith('jmp *OFF(%rip)'),
        str(body[:2]))

# ---------------------------------------------------------------------------
hdr(6, 'F8: lazy binding never resolves a symbol that is never called')


def bound_by(exe):
    env = dict(os.environ, LD_DEBUG='bindings')
    p = subprocess.run(['./' + exe], capture_output=True, text=True, env=env)
    return set(re.findall(r"symbol `([a-z_]+)'",
                          '\n'.join(l for l in p.stderr.splitlines()
                                    if 'binding file ./' + exe in l)))


lazy_bound = bound_by('lt_lazy')
now_bound = bound_by('lt_now')
present('the call to lib_fn EXISTS in the binary',
        'lib_fn' in sh('objdump', '-d', '--no-show-raw-insn', '-j', '.plt', 'lt_lazy'))
absent('lazy does NOT resolve lib_fn', 'lib_fn' in lazy_bound)
present('-z now DOES resolve lib_fn', 'lib_fn' in now_bound)
present('printf is resolved by both (it is actually called)',
        ('printf' in lazy_bound) and ('printf' in now_bound))
check('-z now resolves a SUPERSET of the lazy set', lazy_bound <= now_bound, True)

# ---------------------------------------------------------------------------
hdr(7, 'F9: the code model picks GLOB_DAT or COPY')

pie = sh('readelf', '-rW', 'own_pie')
nopie = sh('readelf', '-rW', 'own_nopie')
present('PIE main.o yields R_X86_64_GLOB_DAT for lib_data',
        re.search(r'GLOB_DAT.*lib_data', pie) is not None, pie)
present('non-PIE main.o yields R_X86_64_COPY for lib_data',
        re.search(r'COPY.*lib_data', nopie) is not None, nopie)
# NOT "the PIE has no COPY": a PIE can still get a COPY for a libc datum such
# as stdout. The claim is about lib_data.
absent('no COPY for lib_data in the PIE build',
       re.search(r'COPY.*lib_data', pie) is not None)
absent('no GLOB_DAT for lib_data in the non-PIE build',
       re.search(r'GLOB_DAT.*lib_data', nopie) is not None)
present('own_pie is ET_DYN', 'DYN' in sh('readelf', '-hW', 'own_pie'))
present('own_nopie is ET_EXEC', 'EXEC' in sh('readelf', '-hW', 'own_nopie'))

# ---------------------------------------------------------------------------
hdr(8, 'F10: COPY means one storage; the library reads the executable copy')

for exe in ('own_pie', 'own_nopie'):
    out = run(exe)
    present('%s: the value starts at 7' % exe, 'lib_data=7' in out, out)
    present('%s: the library sees the executable write (999)' % exe,
            'lib_fn(0)=999' in out, out)

# ---------------------------------------------------------------------------
hdr(9, 'F16/F17: linker-defined symbols')

sym = sh('readelf', '-sW', 'lddef')
for name in ('_end', '__bss_start', 'etext', 'edata'):
    m = re.search(r'^\s*\d+: [0-9a-f]+ \s+(\d+) NOTYPE  GLOBAL\s+DEFAULT\s+\d+ %s$'
                  % re.escape(name), sym, re.M)
    check('%s is NOTYPE with size 0' % name, bool(m) and m.group(1) == '0', True)
m1 = re.search(r'^\s*\d+: ([0-9a-f]+) \s+\d+ NOTYPE  GLOBAL\s+DEFAULT\s+\d+ edata$',
               sym, re.M)
m2 = re.search(r'^\s*\d+: ([0-9a-f]+) \s+\d+ NOTYPE  GLOBAL\s+DEFAULT\s+\d+ __bss_start$',
               sym, re.M)
check('edata and __bss_start share an address (bss follows data)',
      m1.group(1), m2.group(1))

ss = sh('readelf', '-sW', 'segmark')
for name in ('__start_mysecd', '__stop_mysecd'):
    present('%s is GLOBAL PROTECTED' % name,
            re.search(r'NOTYPE  GLOBAL PROTECTED\s+\d+ %s$' % name, ss, re.M) is not None, ss)
present('__start/__stop bound the section exactly (count=4)', 'count=4' in run('segmark'))

# ---------------------------------------------------------------------------
hdr(10, 'F18/F19: hash style, and the hash is of the BASE name')

present('default build has .gnu.hash', '.gnu.hash' in sections('hs_gnu'))
absent('default build has NO .hash', '.hash' in sections('hs_gnu'))
present('--hash-style=sysv has .hash', '.hash' in sections('hs_sysv'))
absent('--hash-style=sysv has no .gnu.hash', '.gnu.hash' in sections('hs_sysv'))
present('--hash-style=both has both',
        ('.hash' in sections('hs_both')) and ('.gnu.hash' in sections('hs_both')))

sys.path.insert(0, HERE)
import symtables  # noqa: E402

# The .hash chain reconstruction is the fully verified one: rebuild every
# symbol's bucket from elf_hash(name) % nbucket and walk the chains.
e = symtables.Elf('hs_sysv')
h = e.sysv_hash()
dyn = e.dynsym()
bucket_of = {}
for b, head in enumerate(h['buckets']):
    k = head
    while k != 0:
        bucket_of[k] = b
        k = h['chains'][k]
ok = bad = 0
for i, s in enumerate(dyn):
    if not s['name'] or i == 0:
        continue
    base = s['name'].split('@')[0]
    if bucket_of.get(i) == elf_hash(base) % h['nbucket']:
        ok += 1
    else:
        bad += 1
check('SysV .hash: every symbol lands in elf_hash(name) %% nbucket', bad, 0)
if VERBOSE:
    print('        (%d symbols verified)' % ok)

# ---------------------------------------------------------------------------
hdr(11, 'F11/F12: the parent is the LAST verdaux, and vd_hash is elf_hash')

e = symtables.Elf('ver/libv.so')
nodes, byndx = e.verdef()
base = [n for n in nodes if n['flags'] & 1]
check('exactly one BASE node', len(base), 1)
check('the BASE node is the SONAME', base[0]['names'][0], 'libv.so')
for n in nodes:
    check('vd_hash of %s == elf_hash(%s)' % (n['names'][0], n['names'][0]),
          n['hash'], elf_hash(n['names'][0]))
chained = [n for n in nodes if n['parent']]
check('V2 and V3 have parents', [n['names'][0] for n in chained], ['V2', 'V3'])
check('V2 parent is V1', chained[0]['parent'], 'V1')
check('V3 parent is V2', chained[1]['parent'], 'V2')
check('a node WITH a parent has two verdaux', len(chained[0]['names']), 2)
check('V1 has no parent and one verdaux',
      [len(n['names']) for n in nodes if n['names'][0] == 'V1'], [1])
vs, _l = e.versym()
present('.gnu.version has one entry per dynsym', len(vs) == len(e.dynsym()),
        '%d vs %d' % (len(vs), len(e.dynsym())))

# ---------------------------------------------------------------------------
hdr(12, 'F13/F14/F15: versioning traps')

dup = sh('llvm-nm-21', '-D', '--defined-only', 'ver/libv_dup.so')
check('compute listed in V1 and V3 yields exactly ONE entry',
      len(re.findall(r'\bcompute\b', dup)), 1)
present('and it is @@V1 -- the FIRST node wins', 'compute@@V1' in dup, dup)
hid = sh('llvm-nm-21', '-D', '--defined-only', 'ver/libv_hidden.so')
for fn in ('compute', 'added_in_v2', 'removed_in_v3', 'vtag'):
    absent('-fvisibility=hidden keeps %s unexported' % fn,
           re.search(r'\b%s\b' % fn, hid) is not None)
check('but the version-node symbols themselves survive',
      len(re.findall(r'\bV[123]@@', hid)), 3)
err = subprocess.run(['clang', '-O1', '-fPIC', '-shared',
                      '-Wl,--version-script=ver/vmap_at', '-o', '/dev/null',
                      'ver/vlib.c'], capture_output=True, text=True).stderr
present('name@version in a version script is a syntax error',
        'syntax error' in err or 'invalid character' in err, err)

# ---------------------------------------------------------------------------
print('\n' + '=' * 72)
if _bad == 0:
    print('  ALL %d CHECKS PASS' % _ok)
else:
    print('  %d passed, %d FAILED' % (_ok, _bad))
print('=' * 72)
sys.exit(1 if _bad else 0)
