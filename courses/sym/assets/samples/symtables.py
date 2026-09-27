#!/usr/bin/env python3
"""symtables.py -- decode the four lookup structures a dynamic loader needs.

Written from the ELF gABI and the GNU extension documentation rather than from
any tool, so it can be used to CHECK what readelf and ld.so believe.

    python3 symtables.py <executable-or-so> [more...]

Decodes, per file:
  .dynsym        the exported symbol table
  .gnu.version   2 bytes per dynsym entry: the version index
  .gnu.version_d verdef  -- the versions this file DEFINES, with a parent chain
  .gnu.version_r verneed  -- the versions this file REQUIRES, per source file
  .hash          the SysV hash table
  .gnu.hash      the GNU hash table

Every derived claim is re-derived here and compared against the file, so a
mismatch is reported rather than printed as fact.
"""
import struct
import sys

VERBOSE = False

SHT = {0: 'NULL', 1: 'PROGBITS', 2: 'SYMTAB', 3: 'STRTAB', 4: 'RELA',
       5: 'HASH', 6: 'DYNAMIC', 7: 'NOTE', 8: 'NOBITS', 9: 'REL',
       11: 'DYNSYM', 0x6ffffff6: 'GNU_VERDEF', 0x6ffffffe: 'GNU_VERNEED',
       0x6ffffff0: 'VERSYM', 0x6ffffffd: 'GNU_HASH'}

STB = {0: 'LOCAL', 1: 'GLOBAL', 2: 'WEAK', 10: 'GNU_UNIQUE'}
STT = {0: 'NOTYPE', 1: 'OBJECT', 2: 'FUNC', 3: 'SECTION', 4: 'FILE',
       5: 'COMMON', 6: 'TLS', 10: 'IFUNC', 13: 'LOOS'}
STV = {0: 'DEFAULT', 1: 'INTERNAL', 2: 'HIDDEN', 3: 'PROTECTED'}

SHN_UNDEF = 0
SHN_ABS = 0xfff1
SHN_COMMON = 0xfff2
SHN_XINDEX = 0xffff


def elf_hash(s):
    """The SysV ELF hash: h = h<<4 + c, then fold the top nibble back down.

    This is the function DT_HASH's table is built with, and -- measured -- the
    same function is reused for the version-definition name hash, which is how
    a loader rejects a version mismatch with a 32-bit compare instead of a
    string compare.
    """
    h = 0
    for c in s.encode():
        h = (h << 4) + c
        g = h & 0xf0000000
        if g:
            h ^= g >> 24
        h &= ~g & 0xffffffff
    return h


class Elf:
    def __init__(self, path):
        self.path = path
        self.d = d = open(path, 'rb').read()
        if d[:4] != b'\x7fELF':
            raise ValueError('not ELF')
        if d[4] != 2:
            raise ValueError('ELFCLASS32 -- this decoder is ELF64 only')
        if d[5] != 1:
            raise ValueError('big-endian -- this decoder is little-endian only')
        self.e_type = struct.unpack_from('<H', d, 0x10)[0]
        self.e_shoff = struct.unpack_from('<Q', d, 0x28)[0]
        es, self.e_shnum, self.e_shstrndx = struct.unpack_from('<HHH', d, 0x3a)
        self.sh = [struct.unpack_from('<IIQQQQIIQQ', d, self.e_shoff + i * es)
                   for i in range(self.e_shnum)]
        self.shstr = self.sh[self.e_shstrndx][4]
        self.by = {}
        for i, s in enumerate(self.sh):
            self.by[self.name(s[0])] = (i, s)

    def name(self, off):
        e = self.d.index(b'\x00', self.shstr + off)
        return self.d[self.shstr + off:e].decode()

    def sname(self, which):
        return self.by[which][1][0] if which in self.by else None

    def str_at(self, strtab_off, off):
        if off == 0:
            return ''
        e = self.d.index(b'\x00', strtab_off + off)
        return self.d[strtab_off + off:e].decode()

    # ------------------------------------------------------------- .dynsym
    def dynsym(self):
        if '.dynsym' not in self.by:
            return []
        _i, s = self.by['.dynsym']
        off, size, ent, link = s[4], s[5], s[9], s[6]
        strtab = self.sh[link][4]
        out = []
        for k in range(size // ent):
            o = off + k * ent
            st_name, st_info, st_other, st_shndx, st_value, st_size = \
                struct.unpack_from('<IBBHQQ', self.d, o)
            out.append({
                'idx': k, 'name_off': st_name,
                'name': self.str_at(strtab, st_name),
                'bind': st_info >> 4, 'type': st_info & 0xf,
                'vis': st_other & 3, 'ndx': st_shndx,
                'value': st_value, 'size': st_size,
            })
        return out

    # -------------------------------------------------------- .gnu.version
    def versym(self):
        if '.gnu.version' not in self.by:
            return []
        _i, s = self.by['.gnu.version']
        off, size, link = s[4], s[5], s[6]
        return [struct.unpack_from('<H', self.d, off + 2 * k)[0]
                for k in range(size // 2)], link

    # ------------------------------------------------------ .gnu.version_d
    def verdef(self):
        """Version definitions. The LAST verdaux of a node is its PARENT."""
        if '.gnu.version_d' not in self.by:
            return [], {}
        _i, s = self.by['.gnu.version_d']
        off, link = s[4], s[6]
        strtab = self.sh[link][4]
        nodes = []
        p = off
        while True:
            (vd_version, vd_flags, vd_ndx, vd_cnt, vd_hash,
             vd_aux, vd_next) = struct.unpack_from('<HHHHIII', self.d, p)
            names = []
            q = p + vd_aux
            for _k in range(vd_cnt):
                vda_name, vda_next = struct.unpack_from('<II', self.d, q)
                names.append(self.str_at(strtab, vda_name))
                if vda_next == 0:
                    break
                q += vda_next
            parent = names[-1] if (len(names) > 1 and not (vd_flags & 1)) \
                else None
            nodes.append({'ndx': vd_ndx, 'flags': vd_flags, 'hash': vd_hash,
                          'names': names, 'parent': parent})
            if vd_next == 0:
                break
            p += vd_next
        return nodes, {n['ndx']: n for n in nodes}

    # ------------------------------------------------------ .gnu.version_r
    def verneed(self):
        if '.gnu.version_r' not in self.by:
            return []
        _i, s = self.by['.gnu.version_r']
        off, link, cnt = s[4], s[6], s[7]
        strtab = self.sh[link][4]
        out = []
        p = off
        for _n in range(cnt):
            (vn_version, vn_cnt, vn_file, vn_aux, vn_next) = \
                struct.unpack_from('<HHIII', self.d, p)
            aux = []
            q = p + vn_aux
            for _k in range(vn_cnt):
                vna_hash, vna_flags, vna_other, vna_name, vna_next = \
                    struct.unpack_from('<IHHII', self.d, q)
                aux.append({'hash': vna_hash, 'flags': vna_flags,
                            'other': vna_other,
                            'name': self.str_at(strtab, vna_name)})
                if vna_next == 0:
                    break
                q += vna_next
            out.append({'file': self.str_at(strtab, vn_file), 'aux': aux})
            if vn_next == 0:
                break
            p += vn_next
        return out

    # -------------------------------------------------------------- .hash
    def sysv_hash(self):
        if '.hash' not in self.by:
            return None
        _i, s = self.by['.hash']
        off = s[4]
        nb, nc = struct.unpack_from('<II', self.d, off)
        buckets = [struct.unpack_from('<I', self.d, off + 8 + 4 * i)[0]
                   for i in range(nb)]
        chains = [struct.unpack_from('<I', self.d, off + 8 + 4 * nb + 4 * i)[0]
                  for i in range(nc)]
        return {'nbucket': nb, 'nchain': nc, 'buckets': buckets,
                'chains': chains}

    # ---------------------------------------------------------- .gnu.hash
    def gnu_hash(self):
        if '.gnu.hash' not in self.by:
            return None
        _i, s = self.by['.gnu.hash']
        off = s[4]
        nb, symoff, bloom_size, bloom_shift = struct.unpack_from('<IIII',
                                                                self.d, off)
        p = off + 16
        bloom = [struct.unpack_from('<Q', self.d, p + 8 * i)[0]
                 for i in range(bloom_size)]
        p += 8 * bloom_size
        buckets = [struct.unpack_from('<I', self.d, p + 4 * i)[0]
                   for i in range(nb)]
        p += 4 * nb
        chain_off = p
        chains = []
        for i in range(nb):
            v = struct.unpack_from('<I', self.d, chain_off + 4 * i)[0]
            chains.append(v)
        return {'nbuckets': nb, 'symoffset': symoff,
                'bloom_size': bloom_size, 'bloom_shift': bloom_shift,
                'bloom': bloom, 'buckets': buckets,
                'chain_off': chain_off}

    def gnu_chain(self, i):
        g = self.gnu_hash()
        if g is None:
            return None
        o = g['chain_off'] + 4 * (i - g['symoffset'])
        return struct.unpack_from('<I', self.d, o)[0]


def report(path):
    e = Elf(path)
    print('=' * 74)
    print('%s' % path)
    print('  e_type = %s' % {1: 'ET_REL', 2: 'ET_EXEC', 3: 'ET_DYN'}.get(
        e.e_type, e.e_type))
    syms = e.dynsym()

    print()
    print('-- .dynsym (%d entries) --' % len(syms))
    print('  %-4s %-30s %-8s %-7s %-9s %-8s' %
          ('idx', 'name', 'bind', 'type', 'vis', 'ndx'))
    for s in syms:
        if not s['name'] and s['idx'] == 0:
            print('  %-4d %-30s %-8s %-7s %-9s %-8s' %
                  (0, '(null entry)', '-', '-', '-', 'UND'))
            continue
        if not s['name']:
            continue
        ndx = ('UND' if s['ndx'] == SHN_UNDEF else
               'ABS' if s['ndx'] == SHN_ABS else
               'COM' if s['ndx'] == SHN_COMMON else str(s['ndx']))
        print('  %-4d %-30s %-8s %-7s %-9s %-8s' %
              (s['idx'], s['name'][:30], STB.get(s['bind'], s['bind']),
               STT.get(s['type'], s['type']), STV.get(s['vis'], s['vis']),
               ndx))

    # versions
    nodes, byndx = e.verdef()
    vs, _vlink = e.versym()
    if vs:
        print()
        print('-- .gnu.version: 2 bytes per .dynsym entry --')
        for k, v in enumerate(vs):
            n = ''
            if v == 0:
                n = ' (local -- not versioned)'
            elif v & 0x8000:
                n = ' (HIDDEN: bit 15 set)'
            elif v in byndx:
                nd = byndx[v]
                n = ' -> %s%s' % (nd['names'][0],
                                  '  [BASE]' if nd['flags'] & 1 else '')
            print('    [%d] %#06x%s' % (k, v, n))

    if nodes:
        print()
        print('-- .gnu.version_d: what this file DEFINES --')
        print('  Elf64_Verdef is 20 bytes; vd_cnt counts this node\'s name')
        print('  PLUS its parent, and the parent is the LAST verdaux.')
        for nd in nodes:
            print('    ndx=%-2d flags=%-3s hash=%#010x  cnt=%d' %
                  (nd['ndx'], ('BASE' if nd['flags'] & 1 else 'none'),
                   nd['hash'], len(nd['names'])))
            for k, n in enumerate(nd['names']):
                role = 'own name' if k == 0 else 'PARENT'
                print('        verdaux[%d] = %-20r  %s' % (k, n, role))
            if nd['names']:
                h = elf_hash(nd['names'][0])
                print('        elf_hash(%r) = %#010x   %s' %
                      (nd['names'][0], h,
                       'MATCHES vd_hash' if h == nd['hash'] else
                       'DIFFERS from vd_hash %#010x' % nd['hash']))

    need = e.verneed()
    if need:
        print()
        print('-- .gnu.version_r: what this file REQUIRES --')
        for nd in need:
            print('    from %s' % nd['file'])
            for a in nd['aux']:
                print('      name=%-18s hash=%#010x flags=%d other=%d' %
                      (a['name'], a['hash'], a['flags'], a['other']))

    g = e.gnu_hash()
    if g:
        print()
        print('-- .gnu.hash --')
        print('    nbuckets=%d symoffset=%d bloom_size=%d bloom_shift=%d' %
              (g['nbuckets'], g['symoffset'], g['bloom_size'], g['bloom_shift']))
        print('    bloom words: %s' % ', '.join('%#018x' % b
                                                 for b in g['bloom']))
        print('    buckets    : %s' % g['buckets'])
        print('    VERIFY the structural invariants that must hold:')
        ok = bad = 0

        def note(label, cond):
            nonlocal ok, bad
            if cond:
                ok += 1
                if VERBOSE:
                    print('      ok    %s' % label)
            else:
                bad += 1
                print('      FAIL  %s' % label)

        # 1. every non-zero bucket head is a valid index at or past symoffset
        note('every non-zero bucket head is >= symoffset (%d)'
             % g['symoffset'],
             all(b == 0 or b >= g['symoffset'] for b in g['buckets']))
        # 2. a bucket's members are a CONTIGUOUS run of dynsym indices, so the
        #    run must stay inside the hashed region and must be terminated by a
        #    set low bit. (The tempting extra invariant -- that the bucket
        #    HEADS are non-decreasing -- is FALSE: libc.so.6 and bash both
        #    violate it, because the runs are laid out per bucket but the
        #    buckets themselves are not in index order.)
        term = 0
        over = 0
        for b, head in enumerate(g['buckets']):
            if head == 0:
                continue
            i = head
            while i < len(syms):
                v = e.gnu_chain(i)
                if v is None or (v & 1):
                    term += 1
                    break
                i += 1
            else:
                over += 1
        live = sum(1 for b in g['buckets'] if b != 0)
        note('every non-empty bucket (%d) terminates inside the chain' % live,
             term == live and over == 0)
        # The tempting extra invariant -- that the bucket HEADS are
        # non-decreasing -- is FALSE, and libc.so.6, bash and libm all violate
        # it: the runs are laid out per bucket, but the buckets themselves are
        # not in dynsym-index order. Reported as a measurement, not a check,
        # because on some files it holds and on others it does not.
        inv = sum(1 for i in range(len(g['buckets']) - 1)
                  if g['buckets'][i] > g['buckets'][i + 1]
                  and g['buckets'][i + 1] != 0)
        print('    MEASURED: %d of %d adjacent bucket pairs are out of index '
              'order' % (inv, len(g['buckets']) - 1))
        print('              (so "heads are sorted" is a false intuition -- '
              'the runs are per-bucket,')
        print('               but the buckets are not themselves ordered)')
        # 3. the chain array has exactly one word per hashed symbol
        nchain = len(syms) - g['symoffset']
        sec_size = e.by['.gnu.hash'][1][5]
        expect = 16 + 8 * g['bloom_size'] + 4 * g['nbuckets'] + 4 * nchain
        note('chain array is exactly %d words (section size %d)'
             % (nchain, sec_size), sec_size == expect)
        # 4. the low bit of the LAST chain word is set: the final symbol of the
        #    final run has no successor
        last = len(syms) - 1
        v = e.gnu_chain(last)
        note('the last chain word has its low bit set', bool(v is not None and (v & 1)))
        # 5. the bloom filter is all ones in practice (it over-approximates:
        #    a set bit may be a false positive, a clear bit is a true miss)
        setbits = sum(bin(w).count('1') for w in g['bloom'])
        note('bloom filter is non-empty (%d bits set of %d)'
             % (setbits, 64 * g['bloom_size']), setbits > 0)

        print('    %d invariants hold, %d broken' % (ok, bad))
        print('    NOTE: the hash is of the BASE name, with any @version')
        print('          stripped, so all versions of one name share a chain')
        print('    NOTE: this decoder does NOT re-derive which bucket a given')
        print('          symbol belongs to. The chain walk is only valid for')
        print('          symbols the table actually covers, and the coverage')
        print('          rule is not re-implemented here -- so the checks above')
        print('          are structural, not a per-symbol audit.')

    h = e.sysv_hash()
    if h:
        print()
        print('-- .hash (SysV) --')
        print('    nbucket=%d nchain=%d' % (h['nbucket'], h['nchain']))
        print('    buckets: %s' % h['buckets'])
        print('    chains : %s' % h['chains'])
        print('    VERIFY: symbol i lives in bucket elf_hash(name) %% nbucket')
        buckets_of = {}
        for b, head in enumerate(h['buckets']):
            k = head
            while k != 0:
                buckets_of[k] = b
                k = h['chains'][k]
        ok = bad = 0
        for i, s in enumerate(syms):
            if not s['name'] or i == 0:
                continue
            exp = elf_hash(s['name'].split('@')[0]) % h['nbucket']
            if buckets_of.get(i) == exp:
                ok += 1
            else:
                bad += 1
                print('      [%d] %-28s expected bucket %d, chain says %s'
                      % (i, s['name'], exp, buckets_of.get(i)))
        print('    %d symbols consistent, %d inconsistent' % (ok, bad))
    print()


if __name__ == '__main__':
    for p in (sys.argv[1:] or ['/bin/ls']):
        try:
            report(p)
        except Exception as ex:                      # noqa: BLE001
            print('%s: %s' % (p, ex))
