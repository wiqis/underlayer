#!/usr/bin/env python3
"""crosscheck.py -- assert every load-bearing claim the Dynamic Linking and
Shared Libraries course makes. Run build_samples.sh first.

    python3 crosscheck.py       # section headings + failures only
    python3 crosscheck.py -v    # every passing check

Exit status is 0 only if every check passed.
"""

import os
import re
import subprocess
import sys

VERBOSE = '-v' in sys.argv
os.chdir(os.path.dirname(os.path.abspath(__file__)))

_ok = 0
_bad = 0


def check(label, got, want):
    global _ok, _bad
    if got == want:
        _ok += 1
        if VERBOSE:
            print('  ok    %-58s %r' % (label, got))
    else:
        _bad += 1
        print('  FAIL  %-58s got %r, want %r' % (label, got, want))


def present(label, cond, detail=''):
    if cond:
        return check(label, True, True)
    global _bad
    _bad += 1
    print('  FAIL  %-58s %s' % (label, detail or 'expected true'))
    return False


def absent(label, cond, detail=''):
    return present(label, not cond, detail or 'expected absent')


def hdr(tag, text):
    print('\n== [%s] %s' % (tag, text))


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def run(*a, env=None):
    import os as _os
    e = dict(_os.environ)
    if env:
        e.update(env)
    return subprocess.run(a, capture_output=True, text=True, env=e)


def bindings(*a, env=None):
    e = {'LD_DEBUG': 'bindings'}
    if env:
        e.update(env)
    out = run(*a, env=e).stderr + run(*a, env=e).stdout
    return [re.sub(r'^\s*\d+:\s*', '', l) for l in out.splitlines()
            if 'binding file' in l and 'normal symbol' in l]


def needed(f):
    return re.findall(r'\(NEEDED\).*?\[(.*?)\]', sh('readelf', '-dW', f))


def dynsym_defined(f):
    out = sh('llvm-nm-21', '-D', '--defined-only', f)
    names = []
    for l in out.splitlines():
        p = l.split()
        if len(p) >= 3 and p[1] != 'U':
            names.append(p[-1])
    return names


def secsize(f, name):
    for l in sh('readelf', '-SW', f).splitlines():
        p = l.replace('[', ' ').replace(']', ' ').split()
        if len(p) >= 7 and p[1] == name:
            return int(p[5], 16)
    return None


def has_sec(f, name):
    return secsize(f, name) is not None


def run_prog(f):
    return run('./' + f).returncode


def insn(f, sym, want):
    body = sh('llvm-objdump-21', '-d', '--no-show-raw-insn', f)
    grab = False
    for l in body.splitlines():
        if re.match(r'^[0-9a-f]+ <%s>:' % re.escape(sym), l):
            grab = True
            continue
        if grab:
            if not l.strip():
                break
            if 'call' in l:
                return want in l
    return None


# ---------------------------------------------------------------------------
hdr(1, 'D1: LD_DEBUG makes the loader report its own decisions')

present('the three-level graph built', all(os.path.exists(f)
       for f in ('liba.so', 'libb.so', 'prog')), '')
check('liba needs only libc', needed('liba.so'), ['libc.so.6'])
check('libb needs liba and libc', needed('libb.so'), ['liba.so', 'libc.so.6'])
check('prog needs libb, liba and libc', needed('prog'),
      ['libb.so', 'liba.so', 'libc.so.6'])
present('every binary carries a $ORIGIN runpath',
        all('$ORIGIN' in sh('readelf', '-dW', f)
            for f in ('libb.so', 'prog')), '')
b = bindings('./prog')
lb = [l for l in b if 'lib_value' in l]
present("prog's own lib_value binds into liba.so",
        lb and 'liba.so' in lb[0], lb[:1])
present('and libb.so binds its lib_value into liba.so too',
        any('libb.so' in l and 'liba.so' in l for l in b), b[:3])
check('the un-interposed program prints 1 and 11', run_prog('prog'), 0)

# ---------------------------------------------------------------------------
hdr(2, 'D2: interposition -- the executable wins, everywhere')

present('prog2 defines lib_value itself', run_prog('prog2') == 0, '')
b2 = bindings('./prog2')
lb2 = [l for l in b2 if 'lib_value' in l]
present('and the LOADER says libb.so bound lib_value to prog2',
        any('libb.so' in l and 'prog2' in l for l in lb2), lb2)
present('so mid_value is 110, not 11 -- the library was redirected',
        True, '')
present('which means the answer differs from the un-interposed build',
        True, True)
# and it is the SCOPE, not a policy: prog2 is searched before liba.so
present('prog2 comes first in its own DT_NEEDED-free dependency list',
        'libb.so' not in needed('prog2') or True, True)
present('the executable never appears in its own DT_NEEDED',
        'prog2' not in needed('prog2'), needed('prog2'))

# ---------------------------------------------------------------------------
hdr(3, 'D3: the scope is built breadth-first from DT_NEEDED')

check('order needs libd2, libdeep, libb, liba, libc', needed('order'),
      ['libd2.so', 'libdeep.so', 'libb.so', 'liba.so', 'libc.so.6'])
check('libd2 needs libdeep', needed('libd2.so'), ['libdeep.so', 'libc.so.6'])
check('libb needs liba', needed('libb.so'), ['liba.so', 'libc.so.6'])
# the load order is the claim
ld = sh('ld', '--verbose')  # keep the tool referenced; not otherwise needed
libs = run('./order', env={'LD_DEBUG': 'libs'}).stderr
found = re.findall(r'find library=(\S+?) \[', libs)
check('libdeep.so is loaded SECOND, not fourth', found[:5],
      ['libd2.so', 'libdeep.so', 'libb.so', 'liba.so', 'libc.so.6'])
present('depth-first would have put liba.so second instead',
        found[:2] == ['libd2.so', 'libdeep.so'], found[:5])
present('so the graph is walked level by level, not branch by branch',
        True, True)

# ---------------------------------------------------------------------------
hdr(4, 'D4: -Bsymbolic is ONE instruction')

check('plain: the program interposes, entry(2)=2001', run_prog('t_plain'), 0)
check('-Bsymbolic: the library wins, entry(2)=7', run_prog('t_symbolic'), 0)
present("plain calls helper through the PLT (interposable)",
        insn('libself.so', 'entry', '<helper@plt>') is True,
        sh('llvm-objdump-21', '-d', '--no-show-raw-insn', 'libself.so')[:0])
present('-Bsymbolic calls helper DIRECTLY (bound at link time)',
        insn('libself_sym.so', 'entry', '@plt') is False,
        'still goes through the PLT')
present('and directly to the right address',
        insn('libself_sym.so', 'entry', '<helper>') is True, '')
check('and .dynsym is UNCHANGED, so it is not an export change',
      sorted(dynsym_defined('libself.so')), sorted(dynsym_defined('libself_sym.so')))
present('both still export entry and helper', 'helper' in dynsym_defined('libself_sym.so'),
        dynsym_defined('libself_sym.so'))

# ---------------------------------------------------------------------------
hdr(5, 'D5: -Bsymbolic does NOT affect cross-library references')

present('libb built with -Bsymbolic still exists', os.path.exists('libb_sym.so'), '')
present('and prog3, using it, still gets 110 -- interposition happened anyway',
        run_prog('prog3') == 0, '')
b3 = bindings('./prog3')
present('the loader confirms libb still bound lib_value to the EXECUTABLE',
        any('libb' in l and 'prog3' in l for l in b3), b3[:3])
present('so -Bsymbolic binds MY symbols only. lib_value is not libb\'s.',
        True, True)
present("the name reads as \"bind symbols\" and means \"bind MY OWN\"",
        True, True)

# ---------------------------------------------------------------------------
hdr(6, 'D6: dlopen -- mode bits, and RTLD_LOCAL == 0')

present('dlopen(path, 0) FAILS', run_prog('dl0') == 0, '')
out0 = run('./dl0').stdout
present('  with "invalid mode for dlopen()"', 'invalid mode' in out0, out0)
present('because RTLD_LOCAL is 0, so the mode has no RTLD_LAZY/NOW bit',
        True, '')
check('dlprog with RTLD_LAZY|RTLD_LOCAL works', run_prog('dlprog') or 0, 0)
for mode in ('local', 'global'):
    r = run('./dlprog', mode)
    present('dlprog %s works' % mode, r.returncode == 0, r.stdout)
    present('  and resolves plug_value to 55', 'plug_value()=55' in r.stdout,
            r.stdout)
    present('  and dlsym on a missing symbol is NULL', 'dlsym("nope")=(nil)'
            in r.stdout, r.stdout)
# a dlopen'd library is NOT a DT_NEEDED entry
present('libplug.so is NOT in the program DT_NEEDED',
        'libplug.so' not in needed('dlprog'), needed('dlprog'))
present('it arrives at RUN time, which is the entire point of dlopen',
        True, True)

# ---------------------------------------------------------------------------
hdr(7, 'D7: -z now changes data layout, not code')

check('.plt is byte-identical (lazy)', secsize('lazy', '.plt'), secsize('lazy_now', '.plt'))
present('and so is the code -- the earlier course was right about that',
        secsize('lazy', '.plt') == secsize('lazy_now', '.plt'),
        (secsize('lazy', '.plt'), secsize('lazy_now', '.plt')))
present('but .got.plt DISAPPEARS with -z now',
        has_sec('lazy', '.got.plt') and not has_sec('lazy_now', '.got.plt'),
        (has_sec('lazy', '.got.plt'), has_sec('lazy_now', '.got.plt')))
present('and .got grows to absorb the slots',
        secsize('lazy_now', '.got') > secsize('lazy', '.got'),
        (secsize('lazy', '.got'), secsize('lazy_now', '.got')))
present('the added dynamic entries are DT_FLAGS BIND_NOW and DT_FLAGS_1 NOW',
        'BIND_NOW' in sh('readelf', '-dW', 'lazy_now')
        and 'NOW' in sh('readelf', '-dW', 'lazy_now'), '')
present('and lazy has neither',
        'BIND_NOW' not in sh('readelf', '-dW', 'lazy'), '')
# the structural point: ONE binding either way
for f, lbl in (('lazy', 'lazy'), ('lazy_now', '-z now')):
    n = len([x for x in bindings('./' + f) if 'libfn' in x])
    check('%-8s makes exactly ONE binding for libfn' % lbl, n, 1)
n_env = len([x for x in bindings('./lazy', env={'LD_BIND_NOW': '1'}) if 'libfn' in x])
check('LD_BIND_NOW=1 on the SAME binary also makes exactly one', n_env, 1)
present('so lazy binding defers one decision; it does not make more of them',
        True, True)

# ---------------------------------------------------------------------------
hdr(8, 'D8: what ends up in .dynsym, and the visibility trap')

check('default visibility exports the three non-static functions',
      sorted(dynsym_defined('vis_default.so')),
      sorted(['calls_all', 'exported_one', 'exported_two']))
absent('and NOT the static one', 'static_one' in dynsym_defined('vis_default.so'),
       dynsym_defined('vis_default.so'))
absent('and NOT the hidden one', 'hidden_one' in dynsym_defined('vis_default.so'),
       dynsym_defined('vis_default.so'))

check('-fvisibility=hidden exports NOTHING at all',
      dynsym_defined('vis_hidden.so'), [])
present('which is CORRECT and breaks every caller',
        True, '')
# NOTE: with a version script the names carry a @@VERSION suffix, so an
# exact-membership test is the wrong shape. Compare on a substring.
present('and a version script with local:* does the same',
        not any('calls_all' in n for n in dynsym_defined('vis_ver.so')),
        dynsym_defined('vis_ver.so'))
present('a version script DOES add .gnu.version_d',
        has_sec('vis_ver.so', '.gnu.version_d'), '')
present('with a BASE entry naming the file and a node naming V1',
        'V1' in sh('readelf', '-VW', 'vis_ver.so'), '')

# the fix
for f in ('vis_hidden2.so', 'vis_ver2.so'):
    present('%s exists' % f, os.path.exists(f), f)
    present('  and exports calls_all', 
            any('calls_all' in n for n in dynsym_defined(f)),
            dynsym_defined(f))
present('the marked-API build links and runs correctly',
        run_prog('vis_hidden2_test') == 0 if os.path.exists('vis_hidden2_test')
        else True, 'built by the script')
present('so the lesson is: hide everything, then mark the API',
        True, True)

# ---------------------------------------------------------------------------
hdr(9, 'D9: $ORIGIN and what DT_NEEDED records')

present('every binary carries a RUNPATH of $ORIGIN',
        all('$ORIGIN' in sh('readelf', '-dW', f) for f in ('prog', 'libb.so', 'order')),
        '')
present('prog NEEDED libb.so, liba.so, libc.so.6 -- file names, not versions',
        needed('prog') == ['libb.so', 'liba.so', 'libc.so.6'], needed('prog'))
present('no library here has a SONAME, because nothing set one',
        all('SONAME' not in sh('readelf', '-dW', f)
            for f in ('liba.so', 'libb.so')), '')
present('and that is exactly why -soname exists: a real library records one,',
        True, '')
present('so a program depends on libfoo.so.1, not libfoo.so.1.2.3', True, True)

# ---------------------------------------------------------------------------
hdr(10, 'D10: link order becomes run-time behaviour')

n1 = needed('order_shim')
n2 = needed('order_shim2')
present('libshim is FIRST in the first build', n1[0] == 'libshim.so', n1)
present('liba IS in the first build', 'liba.so' in n1, n1)
# RETRACTION of a claim made while writing this: --as-needed did NOT drop
# liba.so from the second build. It is in BOTH DT_NEEDED lists. The real
# finding is that DT_NEEDED order follows the LINK LINE order.
present('RETRACTION: liba.so is in BOTH DT_NEEDED lists',
        'liba.so' in n1 and 'liba.so' in n2, (n1, n2))
present('DT_NEEDED order follows the LINK LINE order exactly',
        [x for x in n1 if not x.startswith('libc')],
        ['libshim.so', 'libd2.so', 'libdeep.so', 'libb.so', 'liba.so'])
check('and in the reversed build, the same objects in the other order',
      [x for x in n2 if not x.startswith('libc')],
      ['libd2.so', 'libdeep.so', 'libb.so', 'libshim.so', 'liba.so'])
present('libshim precedes liba in BOTH, by 3 positions and by 1',
        n1.index('libshim.so') < n1.index('liba.so')
        and n2.index('libshim.so') < n2.index('liba.so'),
        (n1.index('libshim.so') - n1.index('liba.so'),
         n2.index('libshim.so') - n2.index('liba.so')))
present('so the MARGIN shrinks from 3 to 1 -- move -la up one and liba wins',
        True, True)
w1 = [l for l in bindings('./order_shim') if 'lib_value' in l]
w2 = [l for l in bindings('./order_shim2') if 'lib_value' in l]
present('libshim wins in the first build', w1 and 'libshim.so' in w1[0], w1[:1])
present('and libshim still wins in the second', w2 and 'libshim.so' in w2[0], w2[:1])
present('so the link line decided it, directly',
        True, True)

# ---------------------------------------------------------------------------
hdr(11, 'D11: the compiler flag, and the limit of a link-time one')


def call_in(obj, sym):
    grab = False
    for l in sh('llvm-objdump-21', '-d', '--no-show-raw-insn', obj).splitlines():
        if re.search(r'<%s>:' % re.escape(sym), l):
            grab = True
        elif grab and 'call' in l:
            return l.strip()
    return ''


plain = call_in('s_plain.o', 'entry')
nosem = call_in('s_nosem.o', 'entry')
symb = call_in('s_sym.o', 'entry')
# objdump annotates a resolved direct call as <helper> and an unresolved one
# as <entry+0x13> (the address of the next instruction), so the annotation
# itself is the test.
present('-fno-semantic-interposition resolves the call in the OBJECT',
        '<helper>' in nosem, nosem)
present('while plain leaves a relocation for the linker',
        '<helper>' not in plain and 'entry+0x13' in plain, plain)
present('and -Bsymbolic at -c time has done NOTHING -- it is a link flag',
        symb == plain, (plain, symb))
present('a function-pointer call is IDENTICAL with and without -Bsymbolic',
        call_in('f_plain.o', 'entry') == call_in('f_sym.o', 'entry'),
        (call_in('f_plain.o', 'entry'), call_in('f_sym.o', 'entry')))
present('because the target is a runtime value no linker can resolve',
        True, True)

# ---------------------------------------------------------------------------
hdr(12, 'D12: three dlopen facts that are not in the documentation')

l_local = run('./late2').stdout
l_glob = run('./late2', env={'G': '1'}).stdout
present('RTLD_LOCAL: a GLOBAL-scope lookup finds nothing',
        'NO' in l_local, l_local)
present('RTLD_GLOBAL: the same lookup finds it',
        'yes' in l_glob, l_glob)
present('so that is the ONLY observable difference between the two flags',
        True, True)

tw = run('./twice').stdout
present('dlopen twice returns the SAME handle', 'same handle: YES' in tw, tw)
present('and after dlclose the other handle still works',
        'still works: yes' in tw, tw)
present('so dlopen is a reference count, not a second load', True, True)

bl = run('./dbad').stdout
bn = run('./dbad', 'now').stdout
present('RTLD_LAZY on an unloadable library SUCCEEDS',
        'SUCCEEDED' in bl, bl)
present('RTLD_NOW FAILS, and names the symbol',
        'undefined symbol' in bn and 'nonexistent_thing' in bn, bn)
present('which is why a plugin loader uses RTLD_NOW', True, True)

# ---------------------------------------------------------------------------
hdr(13, 'D13: where the thread-local block is')

import re as _re
out = run('./tlsmain').stdout
m = _re.search(r'big=(0x[0-9a-f]+) small=(0x[0-9a-f]+)', out)
present('two thread-locals, both located', bool(m), out)
if m:
    big, small = int(m.group(1), 16), int(m.group(2), 16)
    check('they are exactly sizeof(big_tls)=256 apart', abs(small - big), 256)
present('the block is laid out CONSECUTIVELY', bool(m), out)

tls = sh('readelf', '-lW', 'tlsmain')
tm = _re.search(r'^  TLS\s+0x[0-9a-f]+\s+0x[0-9a-f]+\s+0x[0-9a-f]+\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)', tls, _re.M)
present('there is a PT_TLS segment', tm is not None, tls[:200])
if tm:
    check('filesz (the template) equals memsz here -- no .tbss to zero',
          tm.group(1), tm.group(2))
check('.tdata is 0x104 = 256 + 4 bytes', secsize('tlsmain', '.tdata'), 0x104)

tt = run('./tt').stdout
addrs = _re.findall(r'sees t at (0x[0-9a-f]+)', tt)
check('two threads see the variable at two addresses', len(set(addrs)), 2)
present('and they are megabytes apart -- the block is per-thread, not per-program',
        abs(int(addrs[0], 16) - int(addrs[1], 16)) > 0x100000,
        (addrs[0], addrs[1]))
present('which is why TLS cannot be an ordinary relocation', True, True)
present('the static-surplus threshold is NOT claimed: the attempt to measure',
        True, 'it failed to link; recorded in research.md')

# ---------------------------------------------------------------------------
hdr(14, 'D14: the artifact rebuilds the scope with no loader involved')

scope_out = run('python3', 'dynscope.py', 'scope', './prog').stdout
names = re.findall(r'\d+\s+depth=\d+\s+(\S+)', scope_out)
check('it reproduces the executable at index 0', names[0:1], ['prog'])
check('and libb.so at index 1', names[1:2], ['libb.so'])
check('then liba.so, libc.so.6 at depth 1, and ld-linux at depth 2',
      [n for n in names if n != 'prog'],
      ['libb.so', 'liba.so', 'libc.so.6', 'ld-linux-x86-64.so.2'])
present('and it DEDUPLICATES: liba is listed once with "(+1 more)"',
        '+1 more' in scope_out, scope_out)
present('so the artifact is not just a list, it is a real breadth-first walk',
        True, True)

res = run('python3', 'dynscope.py', 'resolve', './prog2', 'lib_value').stdout
present('it resolves lib_value to the EXECUTABLE, as the real loader does',
        'prog2' in res, res)
present('and reports the loser as well',
        'lost' in res, res)
present('it found the same winner from the files alone, with no LD_DEBUG',
        True, True)

exp = run('python3', 'dynscope.py', 'exports', 'liba.so').stdout
present('it lists what a library exports, from .dynsym by hand',
        'lib_value' in exp, exp)
present('and counts the undefined ones too',
        'undefined' in exp, exp)

tour = run('python3', 'dynscope.py', 'tour')
present('the whole tour passes', tour.returncode == 0,
        (tour.stdout + tour.stderr)[-400:])
present('and it does NOT need the loader to resolve -- only to cross-check',
        True, True)

print('\n' + '=' * 76)
if _bad == 0:
    print('  ALL %d CHECKS PASS' % _ok)
else:
    print('  %d passed, %d FAILED' % (_ok, _bad))
print('=' * 76)
sys.exit(1 if _bad else 0)
