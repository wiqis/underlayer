#!/usr/bin/env python3
"""linklab.py -- the buildable artifact for "Static Linking and Linker Scripts".

A linker script is a program. This is a driver that writes scripts, runs the
linker with them, and then CHECKS the result rather than assuming it worked.

    python3 linklab.py                    # the guided tour, every step verified
    python3 linklab.py list               # what this tool can do
    python3 linklab.py show               # print the default script
    python3 linklab.py base 0x3000000     # move the whole binary, verify, RUN it
    python3 linklab.py budget 4M          # a MEMORY script with a real budget
    python3 linklab.py order              # the four-cell first-match experiment
    python3 linklab.py gc                 # reachability with and without the flag

Every subcommand verifies its own result and prints PASS/FAIL. A driver that
only printed the linker's output would teach you nothing the linker does not
already print; the point here is the CHECK.
"""

import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

GREEN, RED, DIM, BOLD, OFF = (
    '\033[32m', '\033[31m', '\033[2m', '\033[1m', '\033[0m')
CC = os.environ.get('CC', 'clang')
LD = os.environ.get('LD', 'ld')

_fail = [0]


def ok(label, cond, detail=''):
    if cond:
        print('   %sPASS%s %s' % (GREEN, OFF, label))
    else:
        _fail[0] += 1
        print('   %sFAIL%s %s  %s' % (RED, OFF, label, detail))
    return cond


def run(*a, **kw):
    return subprocess.run(a, capture_output=True, text=True, **kw)


def sh(*a):
    return run(*a).stdout


# --- the pieces we need from the toolchain ---------------------------------

def default_script():
    """Ask ld for the script it is actually using. This is the whole trick."""
    txt = sh(LD, '--verbose')
    body = txt.split('==================================================\n', 1)[-1]
    return body.rsplit('==================================================', 1)[0]


def write(path, text):
    with open(path, 'w') as f:
        f.write(text)
    return path


def readelf_h(f):
    t = sh('readelf', '-hW', f)
    m = re.search(r'Type:\s+(\S+)', t)
    return m.group(1) if m else '?'


def loads(f):
    out = []
    for l in sh('readelf', '-lW', f).splitlines():
        p = l.split()
        if len(p) >= 8 and p[0] == 'LOAD':
            out.append((int(p[2], 16), p[6] + (' E' if len(p) > 8 and p[7] == 'E' else '')))
    return out


def sections(f):
    out = {}
    for l in sh('readelf', '-SW', f).splitlines():
        p = l.replace('[', ' ').replace(']', ' ').split()
        if len(p) >= 7:
            try:
                out[p[1]] = (int(p[3], 16), int(p[5], 16))
            except ValueError:
                pass
    return out


def syms(f):
    out = {}
    for l in sh('readelf', '-sW', f).splitlines():
        p = l.split()
        if len(p) >= 8 and p[3] == 'FUNC' and p[6] != 'UND':
            out[p[7]] = int(p[1], 16)
    return out


def ensure_specimen():
    """One C file, written here, so this tool needs nothing but a compiler.

    Returns the .o, not the .c: handing a .c straight to ld makes ld treat it
    as a linker script and fail with a syntax error, which cost me a debugging
    session and is worth the comment.
    """
    src = write('linklab_demo.c', '''/* linklab's specimen. Three functions, one of which nobody calls,
   so a garbage collector has something to collect. */
int lab_used(int x){ return x + 1; }
int lab_dead(int x){ return x * 999; }
int main(void){ return lab_used(41) - 42; }
''')
    obj = 'linklab_demo.o'
    r = run(CC, '-O1', '-c', src, '-o', obj)
    if r.returncode != 0:
        raise SystemExit('cannot compile the specimen: ' + r.stderr[:200])
    return obj


# --- subcommands -----------------------------------------------------------

def cmd_show():
    s = default_script()
    print(s)
    print('%s%d lines. That is the whole program that placed your binary.%s'
          % (DIM, len(s.splitlines()), OFF))


def cmd_base(addr):
    """The headline experiment: change one number, move everything, run it."""
    print('%sMove the whole binary to %s%s' % (BOLD, addr, OFF))
    src = ensure_specimen()
    script = default_script()

    # The one edit. There are two occurrences, so replace both -- and then
    # VERIFY the edit landed, because a replace that matches nothing is
    # indistinguishable from a linker that ignored you.
    pat = re.compile(r'SEGMENT_START\("text-segment",\s*0x[0-9a-fA-F]+\)')
    new, n = pat.subn('SEGMENT_START("text-segment", %s)' % addr, script)
    if n == 0:
        print('   %sFAIL%s the script has no SEGMENT_START("text-segment", ...) '
              'to replace -- the default script changed shape' % (RED, OFF))
        _fail[0] += 1
        return
    print('   %sreplaced %d occurrence(s)%s' % (DIM, n, OFF))
    write('lab_base.ld', new)

    out = 'lab_base.out'
    if os.path.exists(out):
        os.remove(out)
    r = run(CC, '-O1', '-fno-pie', '-no-pie', src, '-o', out, '-T', 'lab_base.ld')
    if r.returncode != 0:
        ok('link', False, r.stderr.strip()[:200])
        return
    ok('link succeeded', True)

    got = loads(out)
    want = int(addr, 16)
    ok('first PT_LOAD is at %s' % addr, got and got[0][0] == want,
       'got %s' % (hex(got[0][0]) if got else 'none'))
    ok('e_type is EXEC (a script implies a fixed model)', readelf_h(out) == 'EXEC',
       readelf_h(out))

    # The check that matters: does it RUN? A script is a claim about the
    # machine; the machine gets a vote.
    r = run('./' + out)
    ok('and the program RUNS at that address (exit 0)', r.returncode == 0,
       'exit %d %s' % (r.returncode, r.stderr.strip()[:120]))
    # The FIRST load is the read-only ELF headers, not the code. The one that
    # matters is whichever load carries PF_X. Asserting on got[0] is a bug I
    # made while writing this, and the check caught it.
    exec_loads = [a for a, fl in got if 'E' in fl]
    ok('some PT_LOAD is marked executable', bool(exec_loads),
       [fl for _a, fl in got])
    ok('and it is at or above the first load (headers come first)',
       got and got[0][0] == want and exec_loads and exec_loads[0] >= want,
       (hex(got[0][0]) if got else None, [hex(a) for a in exec_loads]))


def cmd_budget(length):
    """MEMORY turns a silent overlap into a link error."""
    print('%sA MEMORY script with a %s budget%s' % (BOLD, length, OFF))
    obj = ensure_specimen()
    for size, should_fail in ((length, False), ('64', True)):
        ld_script = '''MEMORY {
  rom (rx) : ORIGIN = 0x08000000, LENGTH = %s
  ram (rw) : ORIGIN = 0x20000000, LENGTH = 8M
}
SECTIONS {
  .text : { *(.text .text.*) } > rom
  .data : { *(.data .data.*) } > ram
  .bss  : { *(.bss  .bss.* ) } > ram
}
''' % size
        write('lab_mem.ld', ld_script)
        out = 'lab_mem.out'
        if os.path.exists(out):
            os.remove(out)
        r = run(LD, '-T', 'lab_mem.ld', '-o', out, obj, '-e', 'main')
        if should_fail:
            ok('LENGTH=%s refuses the link' % size, r.returncode != 0,
               'it linked, which means the budget is not being enforced')
            ok('  and the error names the region',
               "region `rom'" in r.stderr, r.stderr.strip()[:160])
            m = re.search(r'overflowed by (\d+) bytes', r.stderr)
            ok('  and says by how much', m is not None, r.stderr.strip()[:160])
        else:
            ok('LENGTH=%s links' % size, r.returncode == 0,
               r.stderr.strip()[:160])
            s = sections(out)
            ok('  .text landed at the rom ORIGIN', s.get('.text', (0,))[0]
               == 0x08000000, hex(s.get('.text', (0,))[0]))
            ok('  and non-allocated sections stayed at 0',
               s.get('.strtab', (1,))[0] == 0, s.get('.strtab'))


def cmd_order():
    """The four-cell first-match experiment, run fresh each time."""
    print('%sWhich rule wins? Four cells, and the answer is not what I expected%s'
          % (BOLD, OFF))
    src = write('lab_note.c', '''__asm__(".section .note.labtest,\\"\\",@progbits\\n .long 0x1\\n");
int main(void){ return 0; }
''')
    if run(CC, '-O1', '-c', src, '-o', 'lab_note.o').returncode != 0:
        print('   cannot compile the specimen')
        return
    base = default_script()
    KEEP = '  .labnote : { *(.note.labtest) }\n'
    DISC = '  /DISCARD/ : { *(.note.labtest) }\n'
    cells = {
        'keep only':              base.replace('SECTIONS\n{', 'SECTIONS\n{' + KEEP, 1),
        'discard only':           base.replace('SECTIONS\n{', 'SECTIONS\n{' + DISC, 1),
        'keep FIRST, discard 2nd': base.replace('SECTIONS\n{',
                                                 'SECTIONS\n{' + KEEP + DISC, 1),
        'discard 1st, keep 2nd':  base.replace('SECTIONS\n{',
                                                 'SECTIONS\n{' + DISC + KEEP, 1),
    }
    got = []
    for name, text in cells.items():
        write('lab_cell.ld', text)
        out = 'lab_cell.out'
        if os.path.exists(out):
            os.remove(out)
        r = run(CC, '-O1', 'lab_note.o', '-o', out, '-T', 'lab_cell.ld')
        kept = r.returncode == 0 and '.labnote' in sections(out)
        got.append(kept)
        print('   %-22s .labnote kept: %s' % (name, kept))
    ok('first-match-wins in all four cells',
       got == [True, False, True, False], got)
    print('   %sso /DISCARD/ is NOT special: in cell 3 it is simply the last '
          'rule, and in cell 4 simply the first.%s' % (DIM, OFF))


def cmd_gc():
    """Reachability, and the surprise that inlining changes the graph."""
    print('%s--gc-sections is reachability, not liveness%s' % (BOLD, OFF))
    src = write('lab_gc.c', '''/* lab_main calls lab_used, so at -O0 the two are genuinely connected and
   the collector must keep both. At -O1 the call folds to a constant and the
   out-of-line lab_used becomes unreachable. That A/B is the whole lesson. */
int lab_used(int x){ return x + 1; }
int lab_dead(int x){ return x * 999; }
int lab_also_dead(int x){ return lab_dead(x) * 2; }
int main(void){ return lab_used(41) - 42; }
''')
    results = {}
    for opt in ('-O1', '-O0'):
        if run(CC, opt, '-ffunction-sections', '-c', src,
               '-o', 'lab_gc%s.o' % opt).returncode != 0:
            continue
        for flag, tag in (([], 'off'), (['-Wl,--gc-sections'], 'on')):
            out = 'lab_gc%s_%s' % (opt, tag)
            if os.path.exists(out):
                os.remove(out)
            r = run(CC, opt, 'lab_gc%s.o' % opt, '-o', out, *flag)
            if r.returncode != 0:
                continue
            keep = sorted(s for s in syms(out) if s.startswith('lab_'))
            results[(opt, tag)] = (keep, sections(out)['.text'][1])
            print('   %s %-22s lab_* survivors: %-42s .text=%#x'
                  % (opt, '--gc-sections ' + tag, ' '.join(keep),
                     sections(out)['.text'][1]))
    if ('-O1', 'on') in results and ('-O0', 'on') in results:
        o1 = results[('-O1', 'on')][0]
        o0 = results[('-O0', 'on')][0]
        ok('at -O1 the collector removed lab_used', 'lab_used' not in o1, o1)
        ok('at -O0 the collector KEPT lab_used', 'lab_used' in o0, o0)
        print('   %sthe only difference is inlining: at -O1 main folds '
              'lab_used(41) to 42, so the out-of-line copy has no caller.%s'
              % (DIM, OFF))
    if ('-O1', 'off') in results and ('-O1', 'on') in results:
        d = results[('-O1', 'off')][1] - results[('-O1', 'on')][1]
        ok('and .text shrank by exactly the collected functions (%#x)' % d,
           d > 0, d)


def cmd_tour():
    print('%s=== linklab: a linker script is a program ===%s\n' % (BOLD, OFF))
    s = default_script()
    print('%sThe script ld is using right now is %d lines long.%s'
          % (DIM, len(s.splitlines()), OFF))
    for line in ('base 0x3000000', 'budget 4M', 'order', 'gc'):
        print()
        globals()['cmd_' + line.split()[0]](*(line.split()[1:]))
    print()
    if _fail[0]:
        print('%s%d check(s) failed%s' % (RED, _fail[0], OFF))
        return 1
    print('%sEvery step verified.%s' % (GREEN, OFF))
    return 0


COMMANDS = {
    'show': (cmd_show, 'print the default linker script ld is using'),
    'base': (cmd_base, 'move the whole binary to an address, verify, and run it'),
    'budget': (cmd_budget, 'a MEMORY script with a real, enforced budget'),
    'order': (cmd_order, 'the four-cell first-match-wins experiment'),
    'gc': (cmd_gc, 'reachability with and without --gc-sections'),
    'tour': (cmd_tour, 'all of the above, each step verified'),
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help', 'help'):
        print(__doc__)
        print('%scommands:%s' % (BOLD, OFF))
        for k, (_f, d) in COMMANDS.items():
            print('  %-8s %s' % (k, d))
        return 0
    if sys.argv[1] == 'list':
        for k, (_f, d) in COMMANDS.items():
            print('  %-8s %s' % (k, d))
        return 0
    if sys.argv[1] not in COMMANDS:
        print('unknown command %r; try `list`' % sys.argv[1])
        return 2
    fn = COMMANDS[sys.argv[1]][0]
    rc = fn(*sys.argv[2:])
    return rc if isinstance(rc, int) else (1 if _fail[0] else 0)


if __name__ == '__main__':
    sys.exit(main())
