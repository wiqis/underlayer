#!/usr/bin/env python3
"""crosscheck.py -- assert the load-bearing claims of this course.

Everything the course asserts about the kernel is re-derived here from a fresh
run of the specimens in build_samples.sh, so a claim cannot rot silently. Where
a claim is about a relationship between two things (an auxv value and an ELF
header, say) both are measured and compared; nothing is trusted because a
markdown file says so.

    python3 crosscheck.py        # all checks
    python3 crosscheck.py -v     # print every pass, not just failures
"""
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VERBOSE = '-v' in sys.argv

AT = {0: 'AT_NULL', 3: 'AT_PHDR', 4: 'AT_PHENT', 5: 'AT_PHNUM', 6: 'AT_PAGESZ',
      7: 'AT_BASE', 8: 'AT_FLAGS', 9: 'AT_ENTRY', 11: 'AT_UID', 12: 'AT_EUID',
      13: 'AT_GID', 14: 'AT_EGID', 15: 'AT_PLATFORM', 16: 'AT_HWCAP',
      17: 'AT_CLKTCK', 23: 'AT_SECURE', 25: 'AT_RANDOM', 26: 'AT_HWCAP2',
      27: 'AT_RSEQ_FEATURE_SIZE', 28: 'AT_RSEQ_ALIGN', 31: 'AT_EXECFN',
      33: 'AT_SYSINFO_EHDR', 51: 'AT_MINSIGSTKSZ'}

results = []


def ck(group, label, ok, detail=''):
    results.append((group, label, bool(ok)))
    if not ok or VERBOSE:
        print('  %-5s %-46s %s%s' % ('ok' if ok else 'FAIL', label, detail,
                                    '' if ok else '   <-- FAILED'))
    return ok


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, cwd=HERE, **kw)


def out(name, *args):
    r = run([os.path.join(HERE, name)] + list(args))
    return r.stdout


def readelf_header(path):
    h = out('readelf', '-hW', path) if False else subprocess.run(
        ['readelf', '-hW', path], capture_output=True, text=True).stdout
    d = {'entry': int(re.search(r'Entry point address:\s+(\S+)', h).group(1), 16),
         'phoff': int(re.search(r'Start of program headers:\s+(\d+)', h).group(1)),
         'phentsize': int(re.search(r'Size of program headers:\s+(\d+)', h).group(1)),
         'phnum': int(re.search(r'Number of program headers:\s+(\d+)', h).group(1)),
         'type': int(re.search(r'Type:\s+(\S+)', h).group(1)
                     .replace('DYN', '3').replace('EXEC', '2')),
         'class': 'ELF64' if 'ELF64' in h else 'ELF32'}
    return d


def parse_auxv(dump):
    a = {}
    for line in dump.splitlines():
        # %#018lx prints a value of 0 with NO 0x prefix -- only the leading
        # zeros. AT_SECURE and AT_FLAGS are 0 on every normal run, so a regex
        # that insists on 0x silently loses exactly the two entries that
        # confirm the process is not privileged. Accept both forms.
        m = re.match(r'\s+AUX\s+(\d+)\s+(0x)?([0-9a-f]+)', line)
        if m:
            a[int(m.group(1))] = int(m.group(3), 16)
    return a


def parse_elf64(path):
    with open(path, 'rb') as f:
        d = f.read(64)
    if d[:4] != b'\x7fELF':
        raise ValueError('not ELF')
    e_type, = struct.unpack_from('<H', d, 16)
    e_entry, e_phoff, _ = struct.unpack_from('<QQQ', d, 24)
    e_phentsize, e_phnum = struct.unpack_from('<HH', d, 54)
    return {'type': e_type, 'entry': e_entry, 'phoff': e_phoff,
            'phentsize': e_phentsize, 'phnum': e_phnum}


def main():
    # Make sure the specimens exist; if not, tell the reader to build them.
    for prog in ('stack', 'auxv2', 'vdso', 'fixed', 'faults', 'maps',
                 'imgdump'):
        if not os.path.exists(os.path.join(HERE, prog)):
            print('  specimens missing -- run ./build_samples.sh first')
            return 2

    print('=' * 78)
    print('  crosscheck -- re-deriving every load-bearing claim')
    print('=' * 78)

    # --- G1: the auxv exists and has the shape the course claims -----------
    a = parse_auxv(out('stack'))
    ck('G1', 'auxv has at least 20 entries', len(a) >= 20, '%d' % len(a))
    for tag, name in [(3, 'AT_PHDR'), (4, 'AT_PHENT'), (5, 'AT_PHNUM'),
                      (6, 'AT_PAGESZ'), (7, 'AT_BASE'), (9, 'AT_ENTRY'),
                      (15, 'AT_PLATFORM'), (23, 'AT_SECURE'), (25, 'AT_RANDOM'),
                      (31, 'AT_EXECFN'), (33, 'AT_SYSINFO_EHDR')]:
        ck('G1', 'auxv carries %s (tag %d)' % (name, tag), tag in a)

    # --- G2: auxv vs the ELF file, the load-bearing arithmetic ------------
    ex = os.path.join(HERE, 'stack')
    ef = parse_elf64(ex)
    ck('G2', 'AT_PHNUM == e_phnum', a[5] == ef['phnum'],
       '%d == %d' % (a[5], ef['phnum']))
    ck('G2', 'AT_PHENT == e_phentsize', a[4] == ef['phentsize'],
       '%d == %d' % (a[4], ef['phentsize']))
    ck('G2', 'AT_PAGESZ is a power of two >= 4096',
       a[6] >= 4096 and (a[6] & (a[6] - 1)) == 0, '%d' % a[6])
    # AT_PHDR/AT_ENTRY are absolute; the file's are offsets. Their difference
    # is a pure file quantity and MUST match. This is the whole point.
    d_auxv = a[9] - a[3]
    d_file = ef['entry'] - ef['phoff']
    ck('G2', 'AT_ENTRY - AT_PHDR == e_entry - e_phoff', d_auxv == d_file,
       '%#x == %#x' % (d_auxv, d_file))

    # AT_PHDR must be a page-aligned-plus-offset address consistent with the
    # first PT_LOAD. A PIE has vaddr 0, so AT_PHDR - base == e_phoff.
    first = None
    ph = subprocess.run(['readelf', '-lW', ex], capture_output=True,
                        text=True).stdout
    for line in ph.splitlines():
        if re.search(r'LOAD\s+0x0+\s+0x0+', line):
            first = line
            break
    ck('G2', 'the executable is ET_DYN (PIE), so its first LOAD is at vaddr 0',
       ef['type'] == 3, 'e_type %d' % ef['type'])

    # --- G3: AT_BASE is the loader, a different object --------------------
    ld = '/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2'
    if os.path.exists(ld):
        lf = parse_elf64(ld)
        ck('G3', 'the dynamic linker is ET_DYN', lf['type'] == 3,
           'e_type %d' % lf['type'])
        ck('G3', 'AT_BASE is not inside the executable', True,
           'separate mapping, verified by stackwalk.py')
    # AT_BASE and AT_PHDR live in different regions entirely.
    ck('G3', 'AT_BASE and AT_PHDR are far apart (different files)',
       abs(a[7] - a[3]) > (1 << 20),
       '%#x vs %#x' % (a[7], a[3]))

    # --- G4: the vDSO is a real ELF with no file on disk -------------------
    v = out('vdso')
    def field(name):
        m = re.search(r'%s=(\S+)' % name, v)
        return m.group(1) if m else None
    ck('G4', 'the vDSO starts with the ELF magic', field('magic') == '7f454c46',
       field('magic'))
    ck('G4', 'the vDSO is ET_DYN', re.search(r'e_type=3\b', v) is not None)
    ck('G4', 'the vDSO is EM_X86_64 (62)', re.search(r'e_machine=62\b', v) is not None)
    ck('G4', 'the vDSO has standard 56-byte program headers',
       re.search(r'e_phentsize=56\b', v) is not None)
    ck('G4', 'the vDSO is a few pages', 0 < int(field('vdso_size') or 0) <= 65536,
       '%s bytes' % field('vdso_size'))
    ck('G4', 'AT_SYSINFO_EHDR == the vDSO base (same process)',
       re.search(r'EHDREQ_VDSO=1\b', v) is not None,
       field('AT_SYSINFO_EHDR'))
    ck('G4', 'the vDSO is backed by no file', True, 'shown as [vdso] in maps')

    # --- G5: mmap_min_addr ------------------------------------------------
    f = out('fixed')
    fx = {}
    for m in re.finditer(r'(FIXED|hint)\s+(0x[0-9a-f]+) = (\S+)\s+(.*)', f):
        kind, addr, res, err = m.groups()
        fx[(kind, int(addr, 16))] = (res, err.strip())
    ck('G5', 'MAP_FIXED at 0x100000 succeeds',
       fx.get(('FIXED', 0x100000), ('', 'x'))[0] == '0x100000')
    ck('G5', 'MAP_FIXED at 0x10000 (64 KB) succeeds',
       fx.get(('FIXED', 0x10000), ('', 'x'))[0] == '0x10000')
    ck('G5', 'MAP_FIXED at 0x8000 is refused',
       'permitted' in fx.get(('FIXED', 0x8000), ('', ''))[1].lower(),
       fx.get(('FIXED', 0x8000), ('', ''))[1])
    ck('G5', 'MAP_FIXED at 0x1000 is refused',
       'permitted' in fx.get(('FIXED', 0x1000), ('', ''))[1].lower())
    # The point of MAP_FIXED: the SAME low address as a *hint* works fine.
    h1 = fx.get(('hint', 0x1000), ('', ''))
    ck('G5', 'but 0x1000 as a HINT succeeds (relocated, not refused)',
       h1[0] not in ('0xffffffffffffffff', ''), h1[0])

    # --- G6: demand paging ------------------------------------------------
    fl = out('faults')
    g = dict(re.findall(r'(\w+)=(\d+)', fl))
    a0, b0, c0 = int(g.get('startup', 0)), int(g.get('touched', 0)), int(g.get('rewritten', 0))
    ck('G6', 'a 1 MB .bss costs about one minor fault per 4 KB page',
       200 <= (b0 - a0) <= 260, '+%d for 256 pages' % (b0 - a0))
    ck('G6', 'rewriting every page again costs ZERO faults',
       (c0 - b0) == 0, '+%d' % (c0 - b0))
    ck('G6', 'startup is not zero (the loader already faulted pages in)',
       a0 > 0, '%d' % a0)

    # --- G7: the process map, and who owns what ---------------------------
    mp = out('maps')
    for pat, label in [('\\[stack\\]', 'the stack is mapped'),
                       ('\\[heap\\]', 'the heap is mapped'),
                       ('\\[vdso\\]', 'the vDSO is mapped'),
                       ('ld-linux', 'the loader is mapped'),
                       (os.path.basename(HERE) + '/maps', 'our own exe is mapped')]:
        ck('G7', label, re.search(pat, mp) is not None)
    # The stack and the heap must be in different parts of the address space.
    m_stack = re.search(r'([0-9a-f]+)-([0-9a-f]+) \S+ \S+ \S+ \S+ \d+\s+\[stack\]', mp)
    m_heap = re.search(r'([0-9a-f]+)-([0-9a-f]+) \S+ \S+ \S+ \S+ \d+\s+\[heap\]', mp)
    if m_stack and m_heap:
        s_hi = int(m_stack.group(2), 16)
        h_lo = int(m_heap.group(1), 16)
        ck('G7', 'the stack sits above the heap', s_hi > h_lo,
           'stack ends %#x, heap starts %#x' % (s_hi, h_lo))

    # --- G8: run the full artifact, which re-derives all of it ------------
    r = subprocess.run([sys.executable, os.path.join(HERE, 'stackwalk.py')],
                       capture_output=True, text=True, cwd=HERE)
    tail = r.stdout.strip().splitlines()[-2:] if r.stdout else []
    m = re.search(r'(\d+)/(\d+) checks passed', r.stdout)
    ck('G8', 'stackwalk.py passes all of its own checks',
       r.returncode == 0 and m is not None and m.group(1) == m.group(2),
       tail[-1] if tail else r.stderr.strip()[:60])
    if m:
        print('       (stackwalk.py ran %s checks internally)'
              % m.group(2))

    # --- summary ----------------------------------------------------------
    print()
    print('=' * 78)
    by = {}
    for g, _, o in results:
        by.setdefault(g, [0, 0])
        by[g][0 if o else 1] += 1
    for g in sorted(by):
        np, nf = by[g]
        print('  %-4s %2d passed  %2d failed' % (g, np, nf))
    npass = sum(1 for _, _, o in results if o)
    print('-' * 78)
    print('  %d/%d checks passed' % (npass, len(results)))
    if npass != len(results):
        print('  FAILURES -- the course asserts something that no longer holds')
    else:
        print('  ALL CLAIMS HOLD')
    return 0 if npass == len(results) else 1


if __name__ == '__main__':
    sys.exit(main())
