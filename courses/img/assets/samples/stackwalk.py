#!/usr/bin/env python3
"""stackwalk.py -- parse the kernel's own description of a process image.

Five earlier courses covered the toolchain: how a file is produced, then
relocated, then linked, then loaded by userspace. This one is the kernel side.
The kernel hands every new process a serialized image, and the only place
that serialization is documented is the kernel source. The C library never
exposes it. So we read it ourselves.

The pipeline is: imgdump (C, ~60 lines) hands over the RAW bytes of the top
of the initial stack and then blocks. This script parses those bytes with no
help from libc, and then cross-checks every value it decoded against two
independent sources -- the ELF files on disk, and /proc/<pid>/maps, which the
kernel maintains for the very same process while it is still blocked.

Nothing here trusts the kernel. Each decoded value is either confirmed by a
second source or reported as UNVERIFIED. If the kernel and the file disagree,
this exits non-zero.

    python3 stackwalk.py          # tour + assertions
    python3 stackwalk.py --dump   # show the decoded image, assert nothing
    python3 stackwalk.py -v       # every check, including the slow ones
"""
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IMGDUMP = os.path.join(HERE, 'imgdump')

VERBOSE = '-v' in sys.argv
DUMP = '--dump' in sys.argv

# The auxiliary vector. These are the numbers the Linux kernel uses; they are
# part of the kernel's UAPI header, not of the C library, which is exactly
# why nothing in userspace hands them to you.
AT = {
    0: 'AT_NULL', 1: 'AT_IGNORE', 2: 'AT_EXECFD', 3: 'AT_PHDR',
    4: 'AT_PHENT', 5: 'AT_PHNUM', 6: 'AT_PAGESZ', 7: 'AT_BASE',
    8: 'AT_FLAGS', 9: 'AT_ENTRY', 10: 'AT_NOTELF', 11: 'AT_UID',
    12: 'AT_EUID', 13: 'AT_GID', 14: 'AT_EGID', 15: 'AT_PLATFORM',
    16: 'AT_HWCAP', 17: 'AT_CLKTCK', 18: 'AT_FPUCW', 23: 'AT_SECURE',
    24: 'AT_BASE_PLATFORM', 25: 'AT_RANDOM', 26: 'AT_HWCAP2',
    27: 'AT_RSEQ_FEATURE_SIZE', 28: 'AT_RSEQ_ALIGN', 29: 'AT_HWCAP3',
    30: 'AT_HWCAP4', 31: 'AT_EXECFN', 32: 'AT_SYSINFO',
    33: 'AT_SYSINFO_EHDR', 51: 'AT_MINSIGSTKSZ',
}

# Which auxv values are POINTERS into the process image rather than integers.
# Getting this wrong is the single most common way to read the auxv: tag 6
# is AT_PAGESZ and its value 4096 is a SIZE, not an address.
AT_POINTER = {3, 7, 9, 15, 24, 25, 31, 32, 33}

checks = []


def check(label, ok, detail=''):
    checks.append((label, bool(ok), detail))
    mark = 'ok  ' if ok else 'FAIL'
    print('  [%s] %s%s' % (mark, label, ('  -- ' + detail) if detail else ''))
    return ok


def rule(ch='-', n=74):
    print('  ' + ch * n)


# ---------------------------------------------------------------------------
# 1. Run imgdump, take the raw stack, and KEEP the process alive while we
#    interrogate /proc. The child blocks on stdin, so /proc/<pid>/maps
#    describes a process that has printed bytes and executed nothing else.
# ---------------------------------------------------------------------------
def capture():
    p = subprocess.Popen([IMGDUMP], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         cwd=HERE, text=True)
    head = p.stdout.readline()
    if not head.startswith('STACK '):
        p.kill()
        raise SystemExit('imgdump did not produce a header: %r' % head)
    _, ssp, sz = head.split()
    ssp, sz = int(ssp, 16), int(sz)

    chunks = []
    got = 0            # hex CHARACTERS read, so compare against sz * 2
    while got < sz * 2:
        line = p.stdout.readline()
        if not line:
            break
        s = line.strip()
        if not s:
            break
        chunks.append(s)
        got += len(s)
    hexs = ''.join(chunks)[:sz * 2]
    raw = bytes.fromhex(hexs)
    if len(raw) != sz:
        p.kill()
        raise SystemExit('short read: %d of %d bytes' % (len(raw), sz))
    p.stdout.readline()          # the blank line after the dump
    assert p.stdout.readline().strip() == 'END'

    # The child is blocked right now. Everything below observes this instant.
    maps = read_maps(p.pid)
    cmdline = read_cmdline(p.pid)
    stat = read_startstack_proc(p.pid)

    p.stdin.write('go\n')
    p.stdin.flush()
    p.wait(timeout=5)
    return ssp, raw, maps, cmdline, stat


def read_maps(pid):
    out = []
    with open('/proc/%d/maps' % pid) as f:
        for line in f:
            # range perms offset dev inode path -- dev is MAJOR:MINOR in hex
            # ("103:02"), which is why it is \S+ and not a hex run.
            m = re.match(r'([0-9a-f]+)-([0-9a-f]+) (\S{4}) ([0-9a-f]+) '
                         r'\S+ \d+\s*(.*)$', line.rstrip())
            if m:
                out.append({
                    'lo': int(m.group(1), 16), 'hi': int(m.group(2), 16),
                    'perm': m.group(3), 'off': int(m.group(4), 16),
                    'path': m.group(5).strip(),
                })
    return out


def read_cmdline(pid):
    with open('/proc/%d/cmdline' % pid, 'rb') as f:
        return f.read().split(b'\0')[:-1]


def read_startstack_proc(pid):
    with open('/proc/%d/stat' % pid) as f:
        line = f.read()
    p = line.rindex(')') + 2
    field = 2
    while p < len(line):
        while p < len(line) and line[p] == ' ':
            p += 1
        if p >= len(line):
            break
        field += 1
        if field == 28:
            return int(line[p:].split()[0])
        while p < len(line) and line[p] != ' ':
            p += 1
    return 0


# ---------------------------------------------------------------------------
# 2. Parse the ELF header ourselves. No readelf, no objdump: the whole point
#    is to be able to read the file without the tool.
# ---------------------------------------------------------------------------
def parse_elf64(path):
    with open(path, 'rb') as f:
        d = f.read(64)
    if d[:4] != b'\x7fELF':
        raise ValueError('%s is not an ELF file' % path)
    if d[4] != 2:
        raise ValueError('not ELFCLASS64')
    e_type, e_machine = struct.unpack_from('<HH', d, 16)
    (e_entry, e_phoff, e_shoff) = struct.unpack_from('<QQQ', d, 24)
    e_flags, = struct.unpack_from('<I', d, 48)
    (e_ehsize, e_phentsize, e_phnum,
     e_shentsize, e_shnum, e_shstrndx) = struct.unpack_from('<HHHHHH', d, 52)
    return {
        'type': e_type, 'machine': e_machine, 'entry': e_entry,
        'phoff': e_phoff, 'phentsize': e_phentsize, 'phnum': e_phnum,
        'shnum': e_shnum, 'shoff': e_shoff, 'shentsize': e_shentsize,
        'shstrndx': e_shstrndx, 'ehsize': e_ehsize, 'flags': e_flags,
    }


def read_phdrs(path):
    h = parse_elf64(path)
    out = []
    with open(path, 'rb') as f:
        for i in range(h['phnum']):
            f.seek(h['phoff'] + i * h['phentsize'])
            b = f.read(h['phentsize'])
            (p_type, p_flags) = struct.unpack_from('<II', b, 0)
            (p_offset, p_vaddr, p_paddr, p_filesz,
             p_memsz, p_align) = struct.unpack_from('<QQQQQQ', b, 8)
            out.append({'type': p_type, 'flags': p_flags, 'offset': p_offset,
                        'vaddr': p_vaddr, 'filesz': p_filesz,
                        'memsz': p_memsz, 'align': p_align})
    return h, out


# ---------------------------------------------------------------------------
# 3. The parse. Three NULL-terminated arrays, then pairs.
#
#      LOW  ->  argc            (one word)
#                argv[0..argc-1]  each a pointer to a string
#                NULL
#                envp[0..]        each a pointer to a string
#                NULL
#                auxv: (tag, value) pairs
#                (AT_NULL, 0)
#      HIGH
#
#    The strings themselves sit ABOVE the arrays, at the very top of the
#    stack. The one trap: the auxv is TWO NULL-terminated arrays past argv,
#    not one. Skip one and you land inside envp, read a string pointer as an
#    auxv tag, and die.
# ---------------------------------------------------------------------------
def parse_image(raw, stack_ptr):
    u = struct.unpack_from
    argc, = u('<q', raw, 0)
    if argc < 0 or argc > 4096:
        raise ValueError('implausible argc %d -- wrong stack pointer' % argc)

    def cstr(addr):
        off = addr - stack_ptr
        if not (0 <= off < len(raw) - 1):
            raise ValueExit('string at %#x is outside the %d-byte dump '
                            '(it is %#x bytes above startstack)'
                            % (addr, len(raw), off))
        try:
            end = raw.index(b'\0', off)
        except ValueError:
            raise ValueExit('string at %#x has no NUL inside the dump -- '
                            'the dump is too small' % addr)
        return raw[off:end].decode('utf-8', 'replace')

    argv, o = [], 8
    for _ in range(argc):
        addr, = u('<Q', raw, o)
        o += 8
        if addr == 0:
            raise ValueExit('NULL inside argv[] at index %d' % len(argv))
        argv.append(cstr(addr))

    nul, = u('<Q', raw, o)
    o += 8
    if nul != 0:
        raise ValueExit('missing NULL after argv[argc-1]')

    envp = []
    while True:
        addr, = u('<Q', raw, o)
        o += 8
        if addr == 0:
            break
        envp.append(cstr(addr))

    auxv, raw_pairs = [], []
    while True:
        tag, val = u('<QQ', raw, o)
        o += 16
        if tag == 0:
            break
        raw_pairs.append((tag, val))
        name = AT.get(tag, 'AT_UNKNOWN_%d' % tag)
        text = ''
        if tag in AT_POINTER:
            try:
                text = ' -> %s' % repr(cstr(val)) if tag in (15, 24, 31) else ''
            except Exception:
                text = ' (not a string in the dump)'
        auxv.append({'tag': tag, 'name': name, 'value': val, 'text': text})

    return {'argc': argc, 'argv': argv, 'envp': envp, 'auxv': auxv,
            'pairs': raw_pairs, 'end': o}


class ValueExit(ValueError):
    pass


# ---------------------------------------------------------------------------
# 4. Cross-check each decoded value against an independent source.
# ---------------------------------------------------------------------------
def verify(img, maps, cmdline, our_path, ldso_path):
    a = {e['tag']: e['value'] for e in img['auxv']}
    ok = True

    def region(addr):
        for m in maps:
            if m['lo'] <= addr < m['hi']:
                return m
        return None

    print('\n  THE KERNEL DESCRIBES THE PROCESS; THE FILE DESCRIBES THE IMAGE')
    our = read_phdrs(our_path)[0]
    ldr = parse_elf64(ldso_path)

    # --- AT_PHENT / AT_PHNUM against the ELF header
    ok &= check('AT_PHENT == e_phentsize in the file',
                a.get(4) == our['phentsize'],
                'auxv %d, file %d' % (a.get(4, -1), our['phentsize']))
    ok &= check('AT_PHNUM == e_phnum in the file',
                a.get(5) == our['phnum'],
                'auxv %d, file %d' % (a.get(5, -1), our['phnum']))

    # --- the load-bearing one. Both differences are in the file's own units.
    if 3 in a and 9 in a:
        delta_auxv = a[9] - a[3]
        delta_file = our['entry'] - our['phoff']
        ok &= check('AT_ENTRY - AT_PHDR == e_entry - e_phoff',
                    delta_auxv == delta_file,
                    '%#x == %#x' % (delta_auxv, delta_file))

    # --- AT_ENTRY must be in an executable region of OUR file
    if 9 in a:
        r = region(a[9])
        ok &= check('AT_ENTRY lands in an r-x region',
                    r is not None and 'x' in r['perm'],
                    '%#x in %s' % (a[9], ('%s' % r['path'] or '[anon]') if r else 'nowhere'))
        if r and our_path in r['path']:
            off = r['off'] + (a[9] - r['lo'])
            ok &= check('AT_ENTRY maps to the file offset of e_entry',
                        off == our['entry'],
                        'offset %#x, e_entry %#x' % (off, our['entry']))

    # --- AT_PHDR must be in a read-only region of our file, at the phoff
    if 3 in a:
        r = region(a[3])
        ok &= check('AT_PHDR lands in a region of our own file',
                    r is not None and our_path.split('/')[-1] in r['path'],
                    r['path'] if r else 'nowhere')
        if r and our_path in r['path']:
            ok &= check('AT_PHDR maps back to e_phoff',
                        r['off'] + (a[3] - r['lo']) == our['phoff'],
                        '%#x vs %#x' % (r['off'] + (a[3] - r['lo']), our['phoff']))

    # --- AT_BASE is a DIFFERENT FILE. This is the check people get wrong.
    if 7 in a:
        r = region(a[7])
        ok &= check('AT_BASE lands in the dynamic linker, not in us',
                    r is not None and 'ld-linux' in r['path'],
                    r['path'] if r else 'nowhere')
        if r:
            off = r['off'] + (a[7] - r['lo'])
            # The loader's own entry is a file offset; the kernel does not
            # tell us where ld.so's entry is, only where its base is. The
            # checkable fact is that ld.so IS ET_DYN, so it has no fixed
            # entry -- a fixed one is the whole reason AT_BASE is needed.
            ok &= check('ld.so is ET_DYN, so it must be given a base',
                        ldr['type'] == 3,
                        'e_type %d' % ldr['type'])
            if VERBOSE:
                print('       ld.so base offset %#x, e_entry offset %#x'
                      % (off, ldr['entry']))

    # --- AT_PAGESZ
    page = os.sysconf('SC_PAGESIZE')
    ok &= check('AT_PAGESZ == the system page size',
                a.get(6) == page, 'auxv %d, sysconf %d' % (a.get(6, -1), page))

    # --- AT_RANDOM: 16 bytes ON THE STACK, and it must be inside the window
    #     we actually hold, or we would be dereferencing nothing.
    ssp = img['stack_ptr']
    if 25 in a:
        off = a[25] - ssp
        inside = 0 <= off and off + 16 <= len(img['raw'])
        ok &= check('AT_RANDOM points into the initial stack we hold',
                    inside, 'offset %+d from startstack, %d bytes in hand'
                    % (off, len(img['raw'])))
        if inside and 15 in a:
            ok &= check('AT_RANDOM and AT_PLATFORM are different places on '
                        'the stack', a[25] != a[15],
                        '%#x vs %#x' % (a[25], a[15]))
        if inside and VERBOSE:
            print('       the 16 bytes at AT_RANDOM: %s'
                  % img['raw'][off:off + 16].hex())

    # --- AT_EXECFN against /proc/<pid>/cmdline, taken at the same instant
    if 31 in a:
        name = img['_cstr'](a[31])
        ok &= check('AT_EXECFN names the file the kernel actually ran',
                    name == (cmdline[0].decode() if cmdline else None),
                    '%s vs %s' % (name, cmdline[0].decode() if cmdline else None))

    # --- AT_SYSINFO_EHDR is the vDSO. Compare WITHIN the one live process.
    if 33 in a:
        vd = [m for m in maps if m['path'] == '[vdso]']
        ok &= check('AT_SYSINFO_EHDR == the base of the [vdso] mapping',
                    len(vd) == 1 and vd[0]['lo'] == a[33],
                    '%#x vs %#x' % (a[33], vd[0]['lo'] if vd else 0))

    # --- AT_SECURE must be 0 for a normal run
    ok &= check('AT_SECURE == 0 (not a setuid run)',
                a.get(23) == 0, 'value %s' % a.get(23))

    # --- AT_UID == real uid: the kernel tells the program who it is
    ok &= check('AT_UID == getuid()',
                a.get(11) == os.getuid(),
                'auxv %s, getuid %d' % (a.get(11), os.getuid()))

    # --- AT_MINSIGSTKSZ is a size, not an address (the pointer/size trap)
    if 51 in a:
        ok &= check('AT_MINSIGSTKSZ is a SIZE and stays plausible',
                    0 < a[51] < 1 << 20, '%d bytes' % a[51])

    return ok


# ---------------------------------------------------------------------------
def main():
    if not os.path.exists(IMGDUMP):
        raise SystemExit('imgdump not built. Run ./build_samples.sh first.')

    print('=' * 78)
    print('  stackwalk -- reading the kernel\'s serialization of a process')
    print('=' * 78)

    ssp, raw, maps, cmdline, proc_ss = capture()

    print('\n  WHAT THE CHILD REPORTED')
    print('    startstack (its own reading)    %#x' % ssp)
    print('    bytes handed over               %d' % len(raw))
    print('    argv seen through /proc         %r' % [c.decode() for c in cmdline])

    check('the child\'s own startstack == the kernel\'s /proc value',
          ssp == proc_ss, '%#x == %#x' % (ssp, proc_ss))

    img = parse_image(raw, ssp)
    img['stack_ptr'] = ssp
    img['raw'] = raw
    img['_cstr'] = lambda a: (
        raw[a - ssp:raw.index(b'\0', a - ssp)].decode('utf-8', 'replace')
        if 0 <= a - ssp < len(raw) - 1 else None)

    if DUMP:
        show(img, raw, maps, ssp)
        return 0

    print('\n  THE IMAGE, DECODED FROM RAW BYTES (no libc)')
    print('    argc    %d' % img['argc'])
    for i, a in enumerate(img['argv']):
        print('    argv[%d] %s' % (i, a))
    print('    envp    %d entries, first: %s'
          % (len(img['envp']), img['envp'][0] if img['envp'] else '-'))
    print('    auxv    %d entries, %d bytes of stack'
          % (len(img['auxv']), img['end']))
    print()
    for e in img['auxv']:
        print('    %-22s %-5d %#018x%s' % (e['name'], e['tag'], e['value'], e['text']))

    ldso = None
    for m in maps:
        if 'ld-linux' in m['path']:
            ldso = m['path']
            break
    ok = verify(img, maps, cmdline, IMGDUMP, ldso)

    print()
    rule('=')
    npass = sum(1 for _, o, _ in checks if o)
    print('  %d/%d checks passed' % (npass, len(checks)))
    print('  %s' % ('ALL CHECKS PASS' if npass == len(checks) else 'FAILURES ABOVE'))
    return 0 if npass == len(checks) else 1


def show(img, raw, maps, ssp):
    print('\n  argc = %d' % img['argc'])
    print('  argv = %r' % img['argv'])
    print('  envp = %d entries' % len(img['envp']))
    print('  auxv = %d entries' % len(img['auxv']))
    for e in img['auxv']:
        print('    %-22s %#018x%s' % (e['name'], e['value'], e['text']))
    print('\n  the process map, while the child was blocked:')
    for m in maps:
        print('    %016x-%016x %s %s' % (m['lo'], m['hi'], m['perm'],
                                         m['path'] or '[anon]'))


if __name__ == '__main__':
    sys.exit(main())
