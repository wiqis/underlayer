#!/usr/bin/env python3
"""Cross-check the independent COFF parser against llvm-readobj.

Compares, for each object file: the five header fields, every relocation's
(offset, symbol index), and every section-definition aux record's
(length, relocation count, checksum, section number).

Agreement between two independently written implementations is the evidence
that a claim in the course is correct.
"""
import re
import subprocess
import sys

# Sample objects shipped with the course, one per dialect, plus the two
# constructed cases (lineno.obj has a hand-built line-number table).
# Requires llvm-readobj on PATH; it ships alongside clang.
FILES = ['sample_msvc.obj', 'sample_gnu.obj', 'sample_m32.obj',
         'comdat.obj', 'lineno.obj']


def mine(path):
    out = subprocess.run([sys.executable, 'coff_parse.py', path],
                         capture_output=True, text=True).stdout
    d = {}
    for key, pat in [
        ('machine', r'Machine\s+= (\d+)'),
        ('nsec', r'NumberOfSections\s+= (\d+)'),
        ('symptr', r'PointerToSymbolTable\s+= (\d+)'),
        ('symcnt', r'NumberOfSymbols\s+= (\d+)'),
        ('optsize', r'SizeOfOptionalHeader\s+= (\d+)'),
    ]:
        m = re.search(pat, out)
        d[key] = int(m.group(1)) if m else None
    d['reloc'] = [(int(a, 16), int(b))
                  for a, b in re.findall(
                      r'addr=0x([0-9a-f]+)\s+sym=(\d+)', out)]
    d['aux'] = [(int(a), int(b), int(c, 16), int(n))
                for a, b, c, n in re.findall(
                    r'Length=(\d+) Relocs=(\d+) Checksum=0x([0-9a-f]+) '
                    r'Number=(\d+)', out)]
    return d


def theirs(path):
    out = subprocess.run(
        ['llvm-readobj', '--file-headers', '--relocations', '--symbols', path],
        capture_output=True, text=True).stdout
    d = {}
    for key, pat, base in [
        ('machine', r'Machine: \w+ \(0x([0-9a-fA-F]+)\)', 16),
        ('nsec', r'SectionCount: (\d+)', 10),
        ('symptr', r'PointerToSymbolTable: 0x([0-9a-fA-F]+)', 16),
        ('symcnt', r'SymbolCount: (\d+)', 10),
        ('optsize', r'OptionalHeaderSize: (?:0x)?([0-9a-fA-F]+)', 16),
    ]:
        m = re.search(pat, out)
        d[key] = int(m.group(1), base) if m else 0
    d['reloc'] = [
        (int(off, 16), int(idx))
        for off, _t, _s, idx in re.findall(
            r'^\s+0x([0-9a-fA-F]+) (IMAGE_REL_\w+) (\S+) \((\d+)\)', out, re.M)]
    d['aux'] = [
        (int(ln), int(rl), int(ck, 16), int(no))
        for ln, rl, _lines, ck, no in re.findall(
            r'AuxSectionDef \{\s*Length: (\d+)\s*RelocationCount: (\d+)'
            r'\s*LineNumberCount: (\d+)\s*Checksum: 0x([0-9A-Fa-f]+)'
            r'\s*Number: (\d+)\s*Selection: ', out)]
    return d


def main():
    ok = True
    for f in FILES:
        a, b = mine(f), theirs(f)
        hdiff = [k for k in ('machine', 'nsec', 'symptr', 'symcnt', 'optsize')
                 if a[k] != b[k]]
        r_ok = a['reloc'] == b['reloc']
        x_ok = a['aux'] == b['aux']
        print(f"{f:18s} header={'OK' if not hdiff else 'MISMATCH ' + str(hdiff)}"
              f"  reloc({len(a['reloc'])})={'OK' if r_ok else 'MISMATCH'}"
              f"  aux({len(a['aux'])})={'OK' if x_ok else 'MISMATCH'}")
        if hdiff:
            for k in hdiff:
                print(f"      {k}: mine={a[k]} theirs={b[k]}")
        if not r_ok:
            for i, (x, y) in enumerate(zip(a['reloc'], b['reloc'])):
                if x != y:
                    print(f"      reloc[{i}] mine={x} theirs={y}")
                    break
        if not x_ok:
            for i, (x, y) in enumerate(zip(a['aux'], b['aux'])):
                if x != y:
                    print(f"      aux[{i}] mine={x} theirs={y}")
                    break
        if hdiff or not r_ok or not x_ok:
            ok = False
    print()
    print("CROSS-CHECK:", "TWO INDEPENDENT PARSERS AGREE ON EVERY FIELD"
          if ok else "DISAGREEMENTS FOUND")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
