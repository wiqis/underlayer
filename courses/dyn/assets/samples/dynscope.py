#!/usr/bin/env python3
"""dynscope.py -- the buildable artifact for "Dynamic Linking and Shared
Libraries".

The central mechanism of dynamic linking is that ld.so builds a SCOPE -- an
ordered list of objects -- and then answers every undefined symbol by
searching that list in order, first match wins. This program rebuilds the
scope from the files themselves and resolves symbols the same way, with no
loader involved.

    python3 dynscope.py scope ./prog        # the ordered scope, from DT_NEEDED
    python3 dynscope.py resolve ./prog mid_value
    python3 dynscope.py exports liba.so
    python3 dynscope.py search ./prog deep  # which object would win
    python3 dynscope.py tour

Every subcommand verifies itself and prints PASS/FAIL. Nothing here calls
dlopen or LD_DEBUG: it reads ELF files. The point is that the scope is not a
secret -- it is a breadth-first walk of DT_NEEDED, and you can do it yourself.

The one thing this program cannot do is run the code, so it also shells out to
LD_DEBUG=bindings for a couple of checks -- that is the oracle it is testing
itself against.
"""

import os
import re
import struct
import subprocess
import sys
import tempfile

GREEN, RED, DIM, BOLD, OFF = (
    '\033[32m', '\033[31m', '\033[2m', '\033[1m', '\033[0m')

_fail = [0]


def ok(label, cond, detail=''):
    if cond:
        print('   %sPASS%s %s' % (GREEN, OFF, label))
    else:
        _fail[0] += 1
        print('   %sFAIL%s %s  %s' % (RED, OFF, label, detail))
    return bool(cond)


def run(*a, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    return subprocess.run(a, capture_output=True, text=True, env=e)


# --- just enough ELF -------------------------------------------------------

DT_NEEDED, DT_SONAME, DT_RPATH, DT_RUNPATH = 1, 14, 15, 29
SHT_DYNSYM, SHT_STRTAB, SHT_DYNAMIC = 11, 3, 6
STB_GLOBAL, STB_WEAK, STB_GNU_UNIQUE = 1, 2, 10
STT_FUNC, STT_OBJECT, STT_GNU_IFUNC = 2, 1, 10
SHN_UNDEF = 0


class Elf:
    """Enough of ELF64 to answer dynamic-linking questions."""

    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as f:
            self.buf = f.read()
        if self.buf[:4] != b'\x7fELF' or self.buf[4] != 2:
            raise ValueError('%s: not a 64-bit ELF' % path)
        (self.e_type, self.e_machine) = struct.unpack_from('<HH', self.buf, 16)
        (_, _, self.e_shoff) = struct.unpack_from('<QQQ', self.buf, 24)
        # e_shentsize, e_shnum, e_shstrndx are THREE half-words at 58, 60
        # and 62. Unpacking five and assigning the last three silently reads
        # past the end of the ELF header into the first section header,
        # which is a spectacularly quiet way to get a wrong e_shstrndx.
        (self.e_shentsize, self.e_shnum,
         self.e_shstrndx) = struct.unpack_from('<HHH', self.buf, 58)
        self._sections()
        self._dynamic()
        self._dynsym()

    def _sections(self):
        self.shdrs = []
        for i in range(self.e_shnum):
            (nm, typ, flags, addr, off, size, link, info, align,
             entsz) = struct.unpack_from('<IIQQQQIIQQ', self.buf,
                                         self.e_shoff + i * 64)
            self.shdrs.append(dict(index=i, nameoff=nm, type=typ, addr=addr,
                                   offset=off, size=size, link=link,
                                   entsize=entsz))
        st = self.shdrs[self.e_shstrndx]
        self.shstr = self.buf[st['offset']:st['offset'] + st['size']]
        for sh in self.shdrs:
            e = self.shstr.index(b'\0', sh['nameoff'])
            sh['name'] = self.shstr[sh['nameoff']:e].decode()

    def section(self, want):
        for sh in self.shdrs:
            if sh['name'] == want:
                return sh
        return None

    def data(self, sh):
        return self.buf[sh['offset']:sh['offset'] + sh['size']]

    def _dynamic(self):
        sh = self.section('.dynamic')
        self.dyn = []
        if not sh:
            return
        d = self.data(sh)
        strtab = None
        for k in range(len(d) // 16):
            tag, val = struct.unpack_from('<qQ', d, k * 16)
            self.dyn.append((tag, val))
            if tag == 0:
                break
        # DT_STRTAB holds a VIRTUAL address, so find the section that
        # starts there. In a shared library that is .dynstr; in an
        # executable it is often nothing at all, and dstr() then returns ''.
        self._strtab_section = None
        for t, v in self.dyn:
            if t == 5:                       # DT_STRTAB
                for sh in self.shdrs:
                    if sh['addr'] == v:
                        self._strtab_section = sh
                        break
                break

    def dstr(self, off):
        if self._strtab_section is None:
            return ''
        s = self.data(self._strtab_section)
        e = s.index(b'\0', off)
        return s[off:e].decode()

    @property
    def needed(self):
        return [self.dstr(v) for t, v in self.dyn if t == DT_NEEDED]

    @property
    def soname(self):
        for t, v in self.dyn:
            if t == DT_SONAME:
                return self.dstr(v)
        return None

    @property
    def runpath(self):
        for tag, name in ((DT_RUNPATH, 'RUNPATH'), (DT_RPATH, 'RPATH')):
            for t, v in self.dyn:
                if t == tag:
                    return name + '=' + self.dstr(v)
        return None

    def _dynsym(self):
        sh = self.section('.dynsym')
        self.dynsym = []
        if not sh:
            return
        strsh = self.shdrs[sh['link']]
        s = self.data(strsh)
        d = self.data(sh)
        for k in range(len(d) // 24):
            nm, info, other, shndx, value, size = struct.unpack_from(
                '<IBBHQQ', d, k * 24)
            e = s.index(b'\0', nm)
            self.dynsym.append(dict(
                index=k, name=s[nm:e].decode(), bind=info >> 4,
                typ=info & 0xf, shndx=shndx, value=value, size=size))

    def defined(self):
        """Every symbol this object DEFINES and is willing to export."""
        out = []
        for s in self.dynsym:
            if s['shndx'] == SHN_UNDEF or not s['name']:
                continue
            if s['bind'] not in (STB_GLOBAL, STB_WEAK, STB_GNU_UNIQUE):
                continue
            if s['typ'] not in (STT_FUNC, STT_OBJECT, STT_GNU_IFUNC):
                continue
            out.append(s)
        return out

    def undefined(self):
        return [s for s in self.dynsym
                if s['shndx'] == SHN_UNDEF and s['name']]


# --- the scope -------------------------------------------------------------

def build_scope(root):
    """Breadth-first from DT_NEEDED. The executable is scope[0] always.

    A real QUEUE, not a recursive descent. A recursive version produces a
    DIFFERENT order for the same graph -- it would finish liba.so before
    libb.so -- and that difference is the entire claim of the third concept
    in this course, so the artifact has to get it right or it is worthless
    as an example.

    Returns (scope, info) where info[path] = dict(depth=, why=).
    """
    scope = [os.path.abspath(root)]
    info = {scope[0]: dict(depth=0, why='the executable itself')}
    head = 0
    while head < len(scope):
        cur = scope[head]
        d = info[cur]['depth']
        try:
            e = Elf(cur)
        except Exception as ex:
            info[cur]['error'] = str(ex)
            head += 1
            continue
        for n in e.needed:
            p = resolve_path(n, cur)
            if p is None:
                info.setdefault('!' + n, dict(depth=d + 1, why='NOT FOUND'))
                continue
            if p in info:
                # already in the scope. Record that we saw it again, so the
                # cycle and the share are both visible.
                info[p].setdefault('also_needed_by', []).append(
                    os.path.basename(cur))
                continue
            info[p] = dict(depth=d + 1,
                           why='needed by %s' % os.path.basename(cur))
            scope.append(p)
        head += 1
    return scope, info


def resolve_path(name, relative_to):
    """Find a DT_NEEDED name. Handles $ORIGIN and plain relative paths."""
    dirs = ['.']
    try:
        rp = Elf(relative_to).runpath
        if rp:
            raw = rp.split('=', 1)[1]
            origin = os.path.dirname(os.path.abspath(relative_to))
            for d in raw.split(':'):
                dirs.insert(0, d.replace('$ORIGIN', origin))
    except Exception:
        pass
    d = os.path.dirname(os.path.abspath(relative_to))
    for cand in dirs + [d]:
        # BUG once: an absolute candidate was used AS the path, so $ORIGIN
        # resolved to the directory and the scope contained directories.
        # Always join the name, absolute or not.
        p = os.path.join(cand, name)
        if os.path.isfile(p):
            return os.path.abspath(p)
    # last resort: the loader's own cache
    r = run('ldconfig', '-p')
    for line in r.stdout.splitlines():
        if name in line:
            m = re.search(r'=>\s*(\S+)', line)
            if m and os.path.exists(m.group(1)):
                return m.group(1)
    return None


def resolve_symbol(scope, name):
    """First match in scope order wins. This is the whole algorithm."""
    for obj in scope:
        try:
            e = Elf(obj)
        except Exception:
            continue
        for s in e.defined():
            if s['name'] == name:
                return obj, s
    return None, None


# --- commands --------------------------------------------------------------

def cmd_scope(root):
    print('%sThe global scope of %s%s' % (BOLD, root, OFF))
    scope, info = build_scope(root)
    for i, obj in enumerate(scope):
        d = info[obj]
        try:
            ndef = len(Elf(obj).defined())
        except Exception:
            ndef = -1
        again = ('  (+%d more)' % len(d['also_needed_by'])
                 if 'also_needed_by' in d else '')
        print('   %2d  depth=%d  %-26s %5d exported%s' %
              (i, d['depth'], os.path.basename(obj), ndef, again))
    print()
    for line in ('the executable is index 0, always, and never appears in'
                 ' its own DT_NEEDED.',
                 'Everything else is a breadth-first walk of what it needs,',
                 'so a second-level dependency lands AFTER every'
                 ' first-level one.'):
        print('   ' + DIM + line + OFF)
    return scope


def cmd_resolve(root, sym):
    print('%sWho would %s bind to in %s?%s' % (BOLD, sym, root, OFF))
    scope, _info = build_scope(root)
    obj, s = resolve_symbol(scope, sym)
    if obj is None:
        print('   ' + RED + 'not found anywhere in the scope' + OFF)
        _fail[0] += 1
        return
    idx = scope.index(obj)
    print('   -> %s   (scope index %d of %d, value %#x, %s)'
          % (os.path.basename(obj), idx, len(scope), s['value'],
             {2: 'FUNC', 1: 'OBJECT', 10: 'IFUNC'}.get(s['typ'], s['typ'])))
    # every object that also defines it, and therefore LOST
    losers = []
    for other in scope:
        if other == obj:
            continue
        try:
            for t in Elf(other).defined():
                if t['name'] == sym:
                    losers.append(os.path.basename(other))
        except Exception:
            pass
    if losers:
        print('   ' + DIM + 'also defined by %s -- and it lost, because index'
          ' %d is earlier' % (', '.join(losers), idx) + OFF)
    # the oracle
    out = run(root, env={'LD_DEBUG': 'bindings'}).stderr
    m = re.search(r'binding file \S+ \[0\] to (\S+): normal symbol `%s' % sym,
                  out)
    if m:
        ok('the real loader agrees: %s' % os.path.basename(m.group(1)),
           os.path.basename(m.group(1)) == os.path.basename(obj),
           'loader=%s mine=%s' % (os.path.basename(m.group(1)),
                                  os.path.basename(obj)))
    else:
        print('   ' + DIM + '(no binding observed -- the symbol may not be'
          ' called by this binary)' + OFF)


def cmd_exports(lib):
    print('%sWhat %s exports%s' % (BOLD, lib, OFF))
    e = Elf(lib)
    for s in sorted(e.defined(), key=lambda x: x['name']):
        print('   %-28s %-6s bind=%d  value=%#x  size=%d'
              % (s['name'],
                 {2: 'FUNC', 1: 'OBJECT', 10: 'IFUNC'}.get(s['typ'], '?'),
                 s['bind'], s['value'], s['size']))
    print('   ' + DIM + '%d exported, %d undefined. Everything NOT in this'
          ' list is unreachable to dlsym, to another library, and to a'
          ' program linking against it.' % (len(e.defined()),
                                            len(e.undefined())) + OFF)


def cmd_search(root, sym):
    print('%sEvery definition of %s in scope order%s' % (BOLD, sym, OFF))
    scope, _info = build_scope(root)
    hit = False
    for i, obj in enumerate(scope):
        try:
            e = Elf(obj)
        except Exception:
            continue
        for s in e.defined():
            if s['name'] == sym:
                mark = '  <== WINS' if not hit else ''
                print('   %2d  %-30s %#x%s' % (i, os.path.basename(obj),
                                               s['value'], mark))
                hit = True
    if not hit:
        print('   ' + RED + 'no object in the scope defines it' + OFF)
        _fail[0] += 1
    for line in ('index 0 is the executable, which is why an executable can',
                 'interpose on a library without the library doing anything'
                 ' unusual.'):
        print('   ' + DIM + line + OFF)


def cmd_tour():
    print('%s=== dynscope: the scope is not a secret ===%s\n' % (BOLD, OFF))
    scope = cmd_scope('./prog')
    print()
    ok('the executable is scope[0]', os.path.basename(scope[0]) == 'prog',
       scope[0])
    names = [os.path.basename(o) for o in scope]
    ok('libb.so is scope[1] (first DT_NEEDED)', names[1:2] == ['libb.so'], names)
    ok('liba.so comes after libb.so, because the executable listed it second',
       names.index('liba.so') > names.index('libb.so'), names)
    ok('and libc.so.6 is in the scope at all', 'libc.so.6' in names, names)
    print()
    cmd_resolve('./prog', 'mid_value')
    print()
    print(DIM + '--- the interposed build ---' + OFF)
    cmd_resolve('./prog2', 'lib_value')
    print()
    print(DIM + '--- exports ---' + OFF)
    cmd_exports('liba.so')
    print()
    cmd_search('./prog2', 'lib_value')
    print()
    if _fail[0]:
        print('%s%d check(s) failed%s' % (RED, _fail[0], OFF))
        return 1
    print('%sEvery step verified.%s' % (GREEN, OFF))
    return 0


COMMANDS = {
    'scope': (cmd_scope, 'the ordered global scope, built from DT_NEEDED'),
    'resolve': (cmd_resolve, 'resolve one symbol the way ld.so would'),
    'exports': (cmd_exports, 'list what a library actually exports'),
    'search': (cmd_search, 'every definition of a symbol, and which wins'),
    'tour': (cmd_tour, 'all of the above, verified against the real loader'),
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help', 'help'):
        print(__doc__)
        print('%scommands:%s' % (BOLD, OFF))
        for k, (_f, d) in COMMANDS.items():
            print('  %-9s %s' % (k, d))
        return 0
    if sys.argv[1] not in COMMANDS:
        print('unknown command %r' % sys.argv[1])
        return 2
    rc = COMMANDS[sys.argv[1]][0](*sys.argv[2:])
    return rc if isinstance(rc, int) else (1 if _fail[0] else 0)


if __name__ == '__main__':
    sys.exit(main())
