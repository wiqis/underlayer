#!/usr/bin/env python3
"""Decode a Unix `ar` archive field by field, from the format description.

Used to verify the Object Files course's claims about archives without
trusting the tool that wrote them.
"""
import struct
import sys

SLIM = b'!<thin>\n'


def members(d):
    """Yield (hdr_off, fields, body_off, body)."""
    off = 8
    n = len(d)
    while off + 60 <= n:
        h = d[off:off + 60]
        if h[58:60] != b'`\n':
            print('  !! no fmag at 0x%x -- stopping' % off)
            return
        f = {
            'name': h[0:16].decode('ascii', 'replace'),
            'mtime': h[16:28].decode('ascii', 'replace').strip(),
            'uid': h[28:34].decode('ascii', 'replace').strip(),
            'gid': h[34:40].decode('ascii', 'replace').strip(),
            'mode': h[40:48].decode('ascii', 'replace').strip(),
            'size': h[48:58].decode('ascii', 'replace').strip(),
            'fmag': h[58:60],
        }
        size = int(f['size'])
        body = d[off + 60:off + 60 + size]
        yield off, f, off + 60, body
        off += 60 + size + (size % 2)


def elf_extern_globals(body):
    """Defined STB_GLOBAL / STB_WEAK symbols of an ELF64 object, in table order."""
    shoff = struct.unpack_from('<Q', body, 0x28)[0]
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', body, 0x3a)
    shdrs = []
    for i in range(shnum):
        o = shoff + i * shentsize
        shdrs.append(struct.unpack_from('<IIQQQQIIQQ', body, o))
    strtab_off = shdrs[shstrndx][4]

    def secname(x):
        e = body.index(b'\x00', strtab_off + x)
        return body[strtab_off + x:e].decode()

    out = []
    for i, sh in enumerate(shdrs):
        if sh[1] != 2:  # SHT_SYMTAB
            continue
        _, _, _, _, sym_off, sym_size, link, _, _, entsize = sh
        stroff = shdrs[link][4]
        for k in range(sym_size // entsize):
            o = sym_off + k * entsize
            st_name, st_info, st_other, st_shndx, st_value, st_size = \
                struct.unpack_from('<IBBHQQ', body, o)
            bind, typ = st_info >> 4, st_info & 0xf
            e = body.index(b'\x00', stroff + st_name)
            name = body[stroff + st_name:e].decode('utf-8', 'replace')
            out.append((k, name, bind, typ, st_shndx))
    return out


def main(path):
    d = open(path, 'rb').read()
    print('=== %s  (%d bytes) ===' % (path, len(d)))
    print('magic: %r  (%d bytes)' % (d[:8], 8))
    print()
    longnames = b''
    for off, f, boff, body in members(d):
        nm = f['name'].rstrip()
        if nm == '//':
            longnames = body
            print('0x%-5x %-16s  LONG-NAME TABLE  %d bytes' % (off, nm, len(body)))
            print('        body: %r' % body)
            print()
            continue
        if nm in ('/', '/SYM64/'):
            print('0x%-5x %-16s  SYMBOL INDEX  size=%d' % (off, nm, len(body)))
            cnt_be = struct.unpack_from('>I', body, 0)[0]
            offs_be = [struct.unpack_from('>I', body, 4 + 4 * i)[0] for i in range(cnt_be)]
            base = 4 + 4 * cnt_be
            strs = body[base:]
            names = [s.decode() for s in strs.split(b'\x00') if s]
            print('        count field is BIG-ENDIAN: %d' % cnt_be)
            print('        %d offsets, then NUL-separated names:' % cnt_be)
            for i in range(cnt_be):
                print('          %-20s -> member header at 0x%x' % (names[i], offs_be[i]))
            if body[1] == 0x02 or body[5] == 0x02:
                cnt_le = struct.unpack_from('<I', body, 4)[0]
                print('        0x02 marker present -> SECOND index at +%d,'
                      ' LITTLE-endian' % (4 + cnt_le))
                base2 = 4 + 4 + 4 * cnt_le
                offs2 = [struct.unpack_from('<I', body, 4 + 4 + 4 * i)[0]
                         for i in range(cnt_le)]
                n2 = [s.decode() for s in body[base2:].split(b'\x00') if s]
                print('        count=%d' % cnt_le)
                for i in range(cnt_le):
                    print('          %-20s -> 0x%x' % (n2[i], offs2[i]))
            print()
            continue
        real = nm
        if nm.startswith('/') and nm[1:].strip().isdigit():
            o = int(nm[1:])
            e = longnames.index(b'\n', o)
            real = longnames[o:e].decode().rstrip()
        print('0x%-5x hdr name=%-17r -> %s' % (off, f['name'], real))
        print('        mtime=%r uid=%r gid=%r mode=%r size=%r fmag=%r'
              % (f['mtime'], f['uid'], f['gid'], f['mode'], f['size'], f['fmag']))
        print('        body at 0x%x, %d bytes, ends 0x%x%s'
              % (boff, len(body), boff + len(body),
                 ' +1 pad byte (odd size)' if len(body) % 2 else ''))
        if body[:4] == b'\x7fELF':
            print('        ELF object, symbol table (bind: 1=GLOBAL 2=WEAK;'
                  ' ndx 0=UNDEF):')
            for k, name, bind, typ, shndx in elf_extern_globals(body):
                if bind not in (1, 2) or shndx == 0:
                    continue
                print('          [%d] %-18s bind=%s type=%d ndx=%d'
                      % (k, name, {1: 'GLOBAL', 2: 'WEAK'}.get(bind, bind),
                         typ, shndx))
        print()


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'libdemo.a')
