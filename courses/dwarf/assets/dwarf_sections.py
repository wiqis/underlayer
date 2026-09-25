#!/usr/bin/env python3
"""Read a section's bytes out of an ELF file without using readelf.

Written for the DWARF course research so that the decoder below is not
depending on the same tool it is being checked against.
"""
import struct
import sys


def read_elf_sections(path):
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF':
        raise ValueError('not an ELF file')
    is64 = d[4] == 2
    little = d[5] == 1
    end = '<' if little else '>'
    if is64:
        e_shoff, = struct.unpack_from(end + 'Q', d, 0x28)
        e_shentsize, e_shnum, e_shstrndx = struct.unpack_from(end + 'HHH', d, 0x3a)
    else:
        e_shoff, = struct.unpack_from(end + 'I', d, 0x20)
        e_shentsize, e_shnum, e_shstrndx = struct.unpack_from(end + 'HHH', d, 0x2e)

    def sh(i):
        o = e_shoff + i * e_shentsize
        if is64:
            name, typ, flags, addr, off, size = struct.unpack_from(
                end + 'IIQQQQ', d, o)
            link, info, align, entsize = struct.unpack_from(end + 'IIII', d, o + 40)
        else:
            name, typ, flags, addr, off, size = struct.unpack_from(
                end + 'IIIIII', d, o)
            link, info, align, entsize = struct.unpack_from(end + 'IIII', d, o + 24)
        return dict(name_off=name, type=typ, flags=flags, addr=addr,
                    offset=off, size=size, link=link, info=info,
                    align=align, entsize=entsize)

    strtab = sh(e_shstrndx)
    names = d[strtab['offset']:strtab['offset'] + strtab['size']]

    out = []
    for i in range(e_shnum):
        s = sh(i)
        no = s['name_off']
        end_n = names.index(b'\x00', no)
        s['name'] = names[no:end_n].decode('ascii', 'replace')
        s['index'] = i
        s['data'] = d[s['offset']:s['offset'] + s['size']] if s['size'] else b''
        out.append(s)
    return out, d


def section(path, name):
    secs, _ = read_elf_sections(path)
    for s in secs:
        if s['name'] == name:
            return s
    raise KeyError('%s has no section %r (have: %s)'
                   % (path, name, ', '.join(s['name'] for s in secs)))


def cstr(buf, off):
    end = buf.index(b'\x00', off)
    return buf[off:end].decode('utf-8', 'replace')


if __name__ == '__main__':
    secs, d = read_elf_sections(sys.argv[1])
    want = sys.argv[2] if len(sys.argv) > 2 else None
    for s in secs:
        if want and s['name'] != want:
            continue
        print('  [%2d] %-24s off=0x%06x size=0x%05x addr=0x%x'
              % (s['index'], s['name'], s['offset'], s['size'], s['addr']))
