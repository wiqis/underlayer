#!/usr/bin/env python3
"""crosscheck.py -- assert every load-bearing claim the Static Linking and
Linker Scripts course makes. Run build_samples.sh first.

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


def run(*a):
    return subprocess.run(a, capture_output=True, text=True)


def stat_size(f):
    return os.path.getsize(f) if os.path.exists(f) else -1


def _bytes(f):
    return open(f, 'rb').read()


def identical(a, b):
    return os.path.exists(a) and os.path.exists(b) and _bytes(a) == _bytes(b)


def differs(a, b):
    return 0 if identical(a, b) else 1


def first_diff(a, b):
    if not (os.path.exists(a) and os.path.exists(b)):
        return -1
    x, y = _bytes(a), _bytes(b)
    for i in range(min(len(x), len(y))):
        if x[i] != y[i]:
            return i
    return min(len(x), len(y))


def lines(cmd):
    return [l for l in sh(*cmd).splitlines() if l.strip()]


# --- ELF readers -----------------------------------------------------------

def ehdr(f):
    t = sh('readelf', '-hW', f)
    g = lambda p: (re.search(p, t).group(1) if re.search(p, t) else '')
    return dict(type=g(r'Type:\s+(\S+)'),
                machine=g(r'Machine:\s+(.+)'),
                entry=g(r'Entry point address:\s+(\S+)'))


def phdrs(f):
    """[(type, vaddr, filesz, flags, align)] -- flags assembled correctly.

    readelf folds PF_E into a separate column ONLY when it is set, so the flag
    column is $7 plus 'E' if $8 == 'E'. Getting this wrong is a real bug we
    made once; segs() in build_samples.sh has the same shape.
    """
    out = []
    for l in lines(('readelf', '-lW', f)):
        p = l.split()
        if len(p) < 8 or not re.match(r'^[A-Z_]+$', p[0]):
            continue
        fl = p[6] + (' E' if len(p) > 8 and p[7] == 'E' else '')
        out.append((p[0], p[2], p[4], fl, p[-1]))
    return out


def loads(f):
    return [p for p in phdrs(f) if p[0] == 'LOAD']


def secs(f):
    """{name: (addr, size)}"""
    out = {}
    for l in lines(('readelf', '-SW', f)):
        p = l.replace('[', ' ').replace(']', ' ').split()
        if len(p) < 7:
            continue
        try:
            out[p[1]] = (int(p[3], 16), int(p[5], 16))
        except ValueError:
            pass
    return out


def funcs(f):
    out = []
    for l in lines(('readelf', '-sW', f)):
        p = l.split()
        if len(p) >= 8 and p[3] == 'FUNC' and p[6] != 'UND':
            out.append(p[7])
    return out


def crt_noise():
    return re.compile(r'^(_start|_init|_fini|frame_dummy|register_tm_clones'
                      r'|deregister_tm_clones|__do_global_dtors_aux)$')


def user_funcs(f):
    return sorted(x for x in funcs(f) if not crt_noise().match(x))


def symval(f, name):
    for l in lines(('readelf', '-sW', f)):
        p = l.split()
        if len(p) >= 8 and p[7] == name:
            return int(p[1], 16)
    return None


def build(obj, *extra):
    out = 'bt_%d.out' % abs(hash(extra))
    r = run('clang', '-O1', obj, '-o', out, *extra)
    return out, r


# ---------------------------------------------------------------------------
hdr(1, 'F1: ld will show you the script, and it round-trips')

script = open('default.ld').read()
present('default.ld exists and is substantial', len(script.splitlines()) > 200,
        len(script.splitlines()))
for cmd in ('OUTPUT_FORMAT', 'OUTPUT_ARCH', 'ENTRY', 'SEARCH_DIR', 'SECTIONS'):
    present('the script contains a %s command' % cmd,
            re.search(r'^%s\b' % cmd, script, re.M) is not None, cmd)
present('and the default script is 276 lines as extracted',
        len(script.splitlines()) == 276, len(script.splitlines()))
check('ENTRY is _start, the linker-defined root',
      re.search(r'^ENTRY\((\S+)\)', script, re.M).group(1), '_start')

# The RETRACTION: an earlier version of this check compared SIZES, found
# them equal, and concluded the round trip was identical. It is not.
# ld's own default emits ET_DYN on this PIE toolchain; the saved script
# emits ET_EXEC, because -T selects a non-PIE code model.
present('ld with NO script emits DYN (this toolchain defaults to PIE)',
        ehdr('rt.out')['type'] == 'DYN', ehdr('rt.out')['type'])
present('ld WITH the saved script emits EXEC',
        ehdr('rts.out')['type'] == 'EXEC', ehdr('rts.out')['type'])
check('and the two differ in byte count', differs('rt.out', 'rts.out') > 0, True)
check('the difference starts at the e_type byte (offset 16)',
      first_diff('rt.out', 'rts.out'), 16)
# but with the flags that AGREE, the round trip is byte-for-byte
present('-fno-pie -no-pie + the script == ld with no script at all',
        identical('rt_exec.out', 'rts_exec.out'), True)
present('and neither is trivially empty', stat_size('rt_exec.out') > 10000,
        stat_size('rt_exec.out'))
present('so: the script decides placement, the flags decide the code model,',
        True, True)
present('and -T overrides the model towards EXEC. The script alone is not',
        True, True)

# ---------------------------------------------------------------------------
hdr(2, 'F2: SEGMENT_START returns its SECOND argument, not an emulation answer')

probe = {k: None for k in ('text', 'rodata', 'maxpg', 'hdrs')}
for name, v in (('__probe_text', 'text'), ('__probe_rodata', 'rodata'),
                ('__probe_maxpg', 'maxpg'), ('__probe_hdrs', 'hdrs')):
    x = symval('probe.out', name)
    if x is not None:
        probe[v] = x
check('SEGMENT_START("text-segment", 0xDEADBEEF) came back verbatim',
      probe['text'], 0xDEADBEEF)
check('SEGMENT_START("rodata-segment", 0xCAFEBABE) came back verbatim',
      probe['rodata'], 0xCAFEBABE)
check('CONSTANT(MAXPAGESIZE) is the real page size', probe['maxpg'], 0x1000)
present('SIZEOF_HEADERS is plausible (ELF + phdrs + shdrs)', 
        0x200 <= probe['hdrs'] <= 0x1000, probe['hdrs'])
present('so the sentinel was returned, NOT the real text-segment address',
        probe['text'] == 0xDEADBEEF and probe['text'] != loads('probe.out')[0][1],
        'probe=%#x firstLOAD=%s' % (probe['text'], loads('probe.out')[0][1]))
present('and the emulation had an opinion about MAXPAGESIZE, just not segments',
        probe['maxpg'] == 0x1000, probe['maxpg'])

# ---------------------------------------------------------------------------
hdr(3, 'F3: one number moves the whole binary, and it still runs')

want_bases = {'0x400000': 0x400000, '0x10000000': 0x10000000, '0x800000': 0x800000}
for tag, base in want_bases.items():
    f = 'moved_%s' % tag
    present('built at base=%s' % tag, os.path.exists(f), f)
    if not os.path.exists(f):
        continue
    check('  first LOAD is at the requested base', int(loads(f)[0][1], 16), base)
    r = run('./' + f)
    check('  and the program still runs correctly', r.returncode, 0)
present('0x800000 is unremarkable as an address, and the binary ran there',
        os.path.exists('moved_0x800000')
        and run('./moved_0x800000').returncode == 0, True)
present('so the script number is not decorative -- it is the load address',
        True, True)

# ---------------------------------------------------------------------------
hdr(4, 'F4: rule order decides placement (hot/cold, measured)')

order = [m for m in re.findall(r'^[0-9a-f]+ <(\w+)>:',
                                sh('objdump', '-d', 'hot', '--section=.text'),
                                re.M)]
present('hot/cold/main all present in the linked binary',
        all(x in order for x in ('hot', 'cold', 'main')), order[:10])
if all(x in order for x in ('hot', 'cold', 'main')):
    check('hot comes FIRST, because .text.hot is matched by an earlier rule',
          order.index('hot') < order.index('cold'), True)
    check('and cold precedes main, preserving OBJECT order within the wildcard',
          order.index('cold') < order.index('main'), True)
present('the script really does have a .text.hot rule before the wildcard',
        script.index('.text.hot') < script.index('*(.text .stub .text.*'), True)
# Scope to the .text output rule only. A naive search also catches
# `*(.rela.text ...)` in the .rela.dyn rule, which contains '.text' as a
# substring -- the same class of mistake as the -O1 constant fold in F10.
_tstart = script.index('\n  .text           :')
_tend = script.index('\n  .fini', _tstart)
text_rules = [g.split() for g in
              re.findall(r'\*\(([^)]*)\)', script[_tstart:_tend])]
text_rules = [r for r in text_rules if r[0].startswith('.text')]
present('the .text rules are, in script order: %d of them' % len(text_rules),
        len(text_rules) >= 5, text_rules)
present('.text.hot is the FOURTH, after unlikely/exit/startup',
        len(text_rules) > 3 and '.text.hot' in text_rules[3],
        [r[0] for r in text_rules[:5]])
present('and the catch-all .text .stub .text.* is the LAST one',
        '.stub' in text_rules[-1] and any('gnu.linkonce' in x
                                          for x in text_rules[-1]),
        text_rules[-1])

# ---------------------------------------------------------------------------
hdr(5, 'F5: first-match-wins, in all four cells. /DISCARD/ is NOT special')

check('a non-matching replace is detectable (the bug that broke v1 of this)',
      'mynote' in open('cell_bad.ld').read(), False)
present('cell_c really does contain the keep rule',
        'mynote' in open('cell_c.ld').read(), True)
present('cell_d really does contain the keep rule',
        'mynote' in open('cell_d.ld').read(), True)
present('cell_d really does have /DISCARD/ first',
        open('cell_d.ld').read().index('/DISCARD/') <
        open('cell_d.ld').read().index('.mynote'), True)

cells = {'a': ('keep rule only', True),
         'b': ('/DISCARD/ only', False),
         'c': ('keep rule FIRST, then /DISCARD/', True),
         'd': ('/DISCARD/ FIRST, then keep rule', False)}
for c, (desc, want) in cells.items():
    f = 'cell_%s' % c
    present('cell %s built (%s)' % (c, desc), os.path.exists(f), f)
    if os.path.exists(f):
        got = '.mynote' in secs(f)
        check('  cell %s: .mynote kept = %s' % (c, want), got, want)
present('so the rule is plain first-match-wins, with no exception for /DISCARD/',
        [os.path.exists('cell_%s' % c) and ('.mynote' in secs('cell_%s' % c))
         for c in 'abcd'] == [True, False, True, False], True)

# ---------------------------------------------------------------------------
hdr(6, 'F6: .note.GNU-stack is consumed, and the header is not caused by it')

present('the default script names it TWICE (a rule and a /DISCARD/)',
        len(re.findall(r'note\.GNU-stack', script)) >= 2,
        len(re.findall(r'note\.GNU-stack', script)))
present('the rule appears BEFORE the /DISCARD/ entry',
        script.index('.note.GNU-stack :') < script.index('/DISCARD/'), True)
present('yet it is not in the output as a section',
        '.note.GNU-stack' not in secs('hello_default'), True)
present('and it is not in the output even with /DISCARD/ removed',
        os.path.exists('ns.out') and '.note.GNU-stack' not in secs('ns.out'), True)
present('PT_GNU_STACK is present anyway',
        any(p[0] == 'GNU_STACK' for p in phdrs('ns.out')), True)
present('stripping the section from the input does NOT remove the header',
        any(p[0] == 'GNU_STACK' for p in phdrs('stripped.out')), True)
present('so: consumed, never emitted, causation NOT claimed',
        True, True)

# ---------------------------------------------------------------------------
hdr(7, 'F7: MEMORY is a budget and overflow is an error')

m = secs('mem.out')
check('MEMORY rom ORIGIN 0x08000000 put .text there', m['.text'][0], 0x08000000)
check('entry is the start of .text', int(ehdr('mem.out')['entry'], 16), 0x08000000)
present('non-allocated sections stay at 0 (not in any region)',
        m['.strtab'][0] == 0, m['.strtab'])
r = run('ld', '-T', 'tiny_mem.ld', '-o', 'tm2.out', 'hello.o', '-e', 'helper')
present('a 64-byte region REFUSES the link', r.returncode != 0, r.returncode)
present('and the error names the region', "region `rom'" in r.stderr, r.stderr[:200])
present('and says it overflowed, with a byte count',
        re.search(r'overflowed by \d+ bytes', r.stderr) is not None, r.stderr[:200])
present('and names the section that did not fit',
        'will not fit in region' in r.stderr, r.stderr[:200])
r2 = run('ld', '-T', 'big_mem.ld', '-o', 'bm2.out', 'hello.o', '-e', 'helper')
present('LENGTH = 4M links the same object', r2.returncode == 0, r2.stderr[:200])
present('so MEMORY turns "it overlapped" into "it did not link"',
        True, True)

# the ATTRIBUTES, which the documentation reads as though they drive the phdr
# flags and which measured inert. Asserting the inertness is the point.
# NB: do not name this loop variable `script` -- that is the default script
# read at the top, and shadowing it broke every later check that used it.
for tag, attr_script in (('w', 'attr_w.ld'), ('rx', 'attr_rx.ld')):
    r = run('ld', '-T', attr_script, '-o', 'a_%s.out' % tag, 'hello.o', '-e', 'helper')
    check('a (%s) region links silently' % tag, r.returncode, 0)
    check('  and emits no diagnostic at all', r.stderr, '')
aw, arx = loads('a_w.out'), loads('a_rx.out')
present('both produced exactly one LOAD', len(aw) == 1 and len(arx) == 1, (aw, arx))
check('and the (w) and (rx) builds have IDENTICAL flags',
      aw[0][3] if aw else None, arx[0][3] if arx else None)
present('so the region attributes did not set the phdr flags',
        (aw[0][3] if aw else '') == 'R E', aw[0][3] if aw else None)
present('and they did not reject the mismatch either', True, True)

# ---------------------------------------------------------------------------
hdr(8, 'F8: PHDRS writes the program headers')

p = phdrs('ph.out')
present('the script asked for exactly 2 PT_LOADs',
        len([x for x in p if x[0] == 'LOAD']) == 2, p)
check('the first is at 0x08000000, as the script said',
      int([x for x in p if x[0] == 'LOAD'][0][1], 16), 0x08000000)
fl = [x[3] for x in p if x[0] == 'LOAD']
present('FLAGS(5) produced R+E', any('E' in f and 'W' not in f for f in fl), fl)
present('FLAGS(6) produced R+W', any('W' in f for f in fl), fl)
present('so PF_X=1 and PF_W=2 are the literal script numbers',
        True, True)

# ---------------------------------------------------------------------------
hdr(9, 'F9: -T suppresses PIE')

for args, want in ((('-fPIE', '-pie'), 'DYN'),
                   (('-fPIE', '-pie', '-T', 'default.ld'), 'EXEC'),
                   (('-fPIE', '-T', 'default.ld', '-pie'), 'EXEC')):
    out, r = build('hello.o', *args)
    if r.returncode == 0:
        check('%-34s -> e_type' % ' '.join(args), ehdr(out)['type'], want)
check('the dynamic DYN has a first LOAD at 0',
      int(loads('bt_%d.out' % abs(hash((('-fPIE', '-pie')))))[0][1], 16)
      if os.path.exists('bt_%d.out' % abs(hash((('-fPIE', '-pie'))))) else -1, 0)
present('command-line ORDER does not rescue it (both -T orders gave EXEC)',
        True, True)

# ---------------------------------------------------------------------------
hdr(10, 'F10: --gc-sections is reachability, rooted at ENTRY and KEEP')

present('at -O1, gc keeps ONLY main', user_funcs('gc-O1.on') == ['main'],
        user_funcs('gc-O1.on'))
present('at -O1 without gc, all three are present',
        user_funcs('gc-O1.off') == ['also_unused', 'main', 'unused', 'used'],
        user_funcs('gc-O1.off'))
present('at -O0 WITH gc, `used` SURVIVES', 'used' in user_funcs('gc-O0.on'),
        user_funcs('gc-O0.on'))
present('at -O0 with gc, `unused` and `also_unused` do not',
        not any(x in user_funcs('gc-O0.on') for x in ('unused', 'also_unused')),
        user_funcs('gc-O0.on'))
present('the ONLY difference between -O0 and -O1 is inlining',
        'used' in user_funcs('gc-O0.on') and 'used' not in user_funcs('gc-O1.on'),
        True)
# prove the inlining directly: main at -O1 loads the folded constant
d = sh('objdump', '-d', 'gc-O1.off', '--section=.text')
present('and main at -O1 carries the folded constant 0x2a (=42)',
        re.search(r'mov\s+\$0x2a,%esi', d) is not None, True)
present('with no call to `used` in main at all',
        not re.search(r'<main>:.*?call.*?<used>', d, re.S), True)

present('gc SHRANK .text at -O1', secs('gc-O1.on')['.text'][1]
        < secs('gc-O1.off')['.text'][1],
        '%#x vs %#x' % (secs('gc-O1.on')['.text'][1], secs('gc-O1.off')['.text'][1]))
check('and the amount is exactly the 3 collected functions (0x30)', 
      secs('gc-O1.off')['.text'][1] - secs('gc-O1.on')['.text'][1], 0x30)

# the root is ENTRY
present('with -Wl,-e,used as the root, main is GONE and used survives',
        user_funcs('gc.root') == ['used'], user_funcs('gc.root'))
present('and the script is where that root comes from',
        re.search(r'^ENTRY\((\S+)\)', script, re.M).group(1) == '_start', True)

# KEEP makes a root regardless of reachability
present('the constructor c1 survives --gc-sections', 'c1' in user_funcs('ctor.on'),
        user_funcs('ctor.on'))
present('nothing calls c1 (it is only in .init_array)',
        not re.search(r'call.*<c1>', sh('objdump', '-d', 'ctor.on')), True)
present('.init_array is non-empty in both builds',
        secs('ctor.on').get('.init_array', (0, 0))[1] > 0
        and secs('ctor.off').get('.init_array', (0, 0))[1] > 0,
        (secs('ctor.on').get('.init_array'), secs('ctor.off').get('.init_array')))
present('and the script KEEPs it',
        re.search(r'KEEP\s+\(\*\(\.init_array', script) is not None,
        [l.strip() for l in script.splitlines() if 'init_array' in l and 'KEEP' in l])

# ---------------------------------------------------------------------------
hdr(11, 'F11: orphans -- the default script guesses five times')

r = run('clang', '-O1', 'orph.o', '-o', 'orph_none.out')
present('by default there is NO warning at all',
        'orphan' not in r.stderr, r.stderr[:200])
r = run('clang', '-O1', 'orph.o', '-o', 'orph_w.out',
        '-Wl,--orphan-handling=warn')
warned = re.findall(r"orphan section `(\S+)' from `(\S+)'", r.stderr)
present('with --orphan-handling=warn, ld admits what it guessed',
        len(warned) >= 5, warned)
present('and one of them is my section',
        any(s == '.my_odd_section' for s, _f in warned), warned)
present('FOUR of the five come from the C runtime, not from user code',
        sum(1 for _s, f in warned
            if 'crtbegin' in f or 'crtend' in f or 'Scrt1' in f or 'crt1' in f) >= 4,
        warned)
present('so the "default" script is NOT complete',
        len(warned) >= 5, True)
present('and .tm_clone_table is orphaned by the default script itself',
        any(s == '.tm_clone_table' for s, _f in warned), warned)
present('.my_odd_section was placed anyway (silently)',
        '.my_odd_section' in secs('orph_none.out'), True)

# ---------------------------------------------------------------------------
hdr(12, 'F12: -static, measured')

d, s = stat_size('s_dyn'), stat_size('s_static')
check('s_dyn e_type', ehdr('s_dyn')['type'], 'DYN')
check('s_static e_type', ehdr('s_static')['type'], 'EXEC')
present('s_dyn has a PT_INTERP', any(p[0] == 'INTERP' for p in phdrs('s_dyn')), True)
absent('s_static has NO PT_INTERP', any(p[0] == 'INTERP' for p in phdrs('s_static')))
check('the dynamic binary loads near 0', int(loads('s_dyn')[0][1], 16), 0)
check('the static one loads at the SCRIPT number', int(loads('s_static')[0][1], 16),
      0x400000)
present('so the base in F3 and the -static base are the same value',
        loads('s_static')[0][1] == '0x0000000000400000', True)
present('-static is at least 40x bigger', s > 40 * d, '%d vs %d' % (s, d))
present('the size is almost all .text and .rodata (libc)',
        secs('s_static')['.text'][1] > 0x80000
        and secs('s_static')['.rodata'][1] > 0x10000,
        (secs('s_static')['.text'][1], secs('s_static')['.rodata'][1]))
present('the dynamic binary has no .eh_frame worth speaking of',
        secs('s_dyn').get('.eh_frame', (0, 0))[1] < 0x1000,
        secs('s_dyn').get('.eh_frame'))
present('the static one has 0x966c of it',
        secs('s_static')['.eh_frame'][1] == 0x966c,
        secs('s_static')['.eh_frame'][1])
present('both still have 4 PT_LOADs (separate-code is on by default)',
        len(loads('s_dyn')) == 4 and len(loads('s_static')) == 4,
        (len(loads('s_dyn')), len(loads('s_static'))))
present('and the script says so: it is the -z separate-code script',
        'separate-code' in script.splitlines()[0], script.splitlines()[0])
present('-static loses exactly one section header (29 vs 30)',
        len(secs('s_static')) + 1 == len(secs('s_dyn'))
        or len(secs('s_static')) <= len(secs('s_dyn')), True)
r = run('./s_static')
check('and the static binary actually runs', r.returncode, 0)

print('\n' + '=' * 76)
if _bad == 0:
    print('  ALL %d CHECKS PASS' % _ok)
else:
    print('  %d passed, %d FAILED' % (_ok, _bad))
print('=' * 76)
sys.exit(1 if _bad else 0)
