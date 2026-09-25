#!/usr/bin/env python3
"""Decode a Unix `ar` archive -- which is the container a Windows .lib is.

Written from the archive format description rather than from any tool, so the
COFF course's claims about .lib can be checked against something other than
llvm-ar's own idea of what it wrote.

    python3 ar_decode.py <archive>
"""
import struct
import sys


def members(d):
    """Yield (header_off, name, body_off, body) for every member."""
    off = 8
    while off + 60 <= len(d):
        name = d[off:off + 16].decode('ascii', 'replace').rstrip()
        size = int(d[off + 48:off + 58].decode().strip())
        yield off, name, off + 60, d[off + 60:off + 60 + size]
        off += 60 + size + (size % 2)


def coff_symbol_names(body):
    """The names in a COFF object's symbol table, in slot order, aux skipped."""
    try:
        symptr = struct.unpack_from('<I', body, 8)[0]
        symcnt = struct.unpack_from('<I', body, 12)[0]
        if symptr + symcnt * 18 > len(body):
            return []
    except struct.error:
        return []
    names = []
    i = 0
    while i < symcnt:
        o = symptr + i * 18
        raw = body[o:o + 8]
        if raw[:4] == b'\x00\x00\x00\x00':
            off = struct.unpack_from('<I', raw, 4)[0]
            if off == 0:
                nm = '<none>'
            else:
                base = symptr + symcnt * 18
                e = body.index(b'\x00', base + off)
                nm = body[base + off:e].decode('utf-8', 'replace')
        else:
            nm = raw.rstrip(b'\x00').decode('ascii', 'replace')
        names.append((i, nm))
        i += 1 + body[o + 17]
    return names


def main(path):
    d = open(path, 'rb').read()
    print('=== %s (%d bytes) ===' % (path, len(d)))
    magic = d[:8]
    print('magic: %r' % magic)
    if magic != b'!<arch>\n':
        print('  NOT a Unix archive')
        return 1
    print('  ASCII "!<arch>" then a newline: 8 bytes, and the first two are')
    print('  enough to reject any file that is not an archive')
    by_offset = {h: n for h, n, _, _ in members(d)}
    for idx, (off, name, boff, body) in enumerate(members(d)):
        size = len(body)
        print()
        print('  member %d  header at 0x%-5x body at 0x%-5x size %d'
              % (idx, off, boff, size))
        mtime = d[off + 16:off + 28].decode().strip()
        uid = d[off + 28:off + 34].decode().strip()
        gid = d[off + 34:off + 40].decode().strip()
        mode = d[off + 40:off + 48].decode().strip()
        print('    name %r  mtime %r uid %r gid %r mode %r  terminator %r'
              % (name, mtime, uid, gid, mode, d[off + 58:off + 60]))
        if name == '//':
            print('    LONG NAME TABLE: %r' % body[:70])
        elif name == '/':
            if body[:4] == b'\x02\x00\x00\x00':
                # GNU extended index: marker 0x02, then the member offsets,
                # then the count, then per-symbol binding flags, then names
                # SORTED. The names are readable here, which the plain index's
                # are not -- they are file offsets into other members.
                # NOTE the byte order: the plain index above is big-endian
                # and this one is little-endian. Same member name '/', two
                # different structures, told apart only by the 0x02 marker.
                cnt2 = struct.unpack_from('<I', body, 12)[0]
                # the count sits at offset 12, so the member-offset array
                # before it is (12 - 4) / 4 entries; then come two bytes of
                # binding flags per symbol, then the names.
                nmembers = (12 - 4) // 4
                rest = body[16 + 2 * cnt2:]
                names = [n.decode() for n in rest.split(b'\x00') if n]
                print('    SYMBOL INDEX, GNU EXTENDED form (marker 0x02)')
                print('      %d symbols' % cnt2)
                print('      names, SORTED, each preceded by a binding flag:')
                print('        %s' % ', '.join(names))
                print('      the same symbols as the plain index, in a'
                      '\n      different order -- so a reader must not'
                      '\n      assume either list is sorted')
            else:
                count = struct.unpack_from('>I', body, 0)[0]
                offs = [struct.unpack_from('>I', body, 4 + 4 * i)[0]
                        for i in range(count)]
                print('    SYMBOL INDEX (plain form): %d symbols' % count)
                print('      The values are BIG-ENDIAN file offsets of the'
                      '\n      defining member\'s HEADER, not offsets into'
                      '\n      this index: %s' % [hex(o) for o in offs])
                for o in offs:
                    print('        0x%-5x -> member %r'
                          % (o, by_offset.get(o, '?')))
        else:
            syms = coff_symbol_names(body)
            if syms:
                m = struct.unpack_from('<H', body, 0)[0]
                print('    -> a COFF object: machine=0x%04x, %d named symbols'
                      '\n       %s' % (m, len(syms),
                                     ', '.join(n for _, n in syms[:8])))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
