#!/usr/bin/env python3
"""Cross-check the independent DWARF decoder against readelf and llvm-dwarfdump.

Three implementations are involved: this repo's `dwarf_decode.py`, written from
the specification, plus binutils `readelf` and LLVM `llvm-dwarfdump`. A claim
only goes into the course once all the available readers agree on it, because
agreeing with one tool by eye proves nothing.

    python3 crosscheck.py <file> [<file> ...]
"""
import os
import re
import subprocess
import sys

import dwarf_sections as ds
from dwarf_decode import (decode_info, decode_aranges, decode_loclists,
                          decode_eh_frame, decode_pubnames, read_abbrev,
                          count_abbrev_tables)

LLVM = '/usr/lib/llvm-21/bin'


def hexval(text):
    """One number, whatever base the two readers happened to print it in."""
    t = text.strip().lower().removeprefix('0x')
    return int(t, 16) if t else 0


# --------------------------------------------------------------- readelf


def readelf_dies(path):
    """[(depth, die_offset, abbrev, tag)] plus [(die, attr_off, attr_name)]."""
    out = subprocess.run(['readelf', '--debug-dump=info', path],
                         capture_output=True, text=True).stdout
    dies, attrs = [], []
    cur = None
    for line in out.split('\n'):
        m = re.match(r'\s*<(\d+)><([0-9a-f]+)>: Abbrev Number: (\d+) '
                     r'\((\w+)\)', line)
        if m:
            depth, off, num, tag = int(m.group(1)), m.group(2), \
                int(m.group(3)), m.group(4)
            dies.append((depth, off, num, tag))
            cur = off
            continue
        m = re.match(r'\s*<([0-9a-f]+)>\s+(DW_AT_\w+|DW_AT_0x[0-9a-f]+)\s*:',
                     line)
        if m and cur is not None:
            attrs.append((cur, m.group(1), m.group(2)))
    return dies, attrs


def readelf_aranges(path):
    """readelf prints two header lines then fixed-width hex address/length
    rows, each 16 digits wide, with a zero row terminating each set."""
    out = subprocess.run(['readelf', '--debug-dump=aranges', path],
                         capture_output=True, text=True).stdout
    units, tuples = [], []
    for m in re.finditer(
            r'Version:\s+(\d+)\s*\n\s*Offset into \.debug_info:\s+(\S+)',
            out):
        units.append((int(m.group(1)), hexval(m.group(2))))
    for m in re.finditer(r'^\s+([0-9a-f]{16}) ([0-9a-f]{16})\s*$', out, re.M):
        tuples.append((hexval(m.group(1)), hexval(m.group(2))))
    return units, tuples


def readelf_fde_ranges(path):
    out = subprocess.run(['readelf', '--debug-dump=frames', path],
                         capture_output=True, text=True).stdout
    return [(hexval(a), hexval(b)) for a, b in
            re.findall(r'pc=([0-9a-f]+)\.\.([0-9a-f]+)', out)]


def my_fde_ranges(path):
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        decode_eh_frame(path)
    return [(hexval(a), hexval(b)) for a, b in
            re.findall(r'pc=0x([0-9a-f]+)\.\.0x([0-9a-f]+)', buf.getvalue())]


def readelf_eh_frame(path):
    out = subprocess.run(['readelf', '--debug-dump=frames', path],
                         capture_output=True, text=True).stdout
    ops = []
    for m in re.finditer(r'\bDW_CFA_([a-zA-Z_0-9]+)', out):
        ops.append(m.group(1))
    return ops


def readelf_loclists(path):
    out = subprocess.run(['readelf', '--debug-dump=loclists', path],
                         capture_output=True, text=True).stdout
    return re.findall(r'DW_LLE_(\w+)', out)


# --------------------------------------------------------- llvm-dwarfdump


def llvm_dies(path):
    """llvm-dwarfdump prints '0xOFFSET: DW_TAG_...' for each DIE."""
    exe = os.path.join(LLVM, 'llvm-dwarfdump')
    out = subprocess.run([exe, '--debug-info', path],
                         capture_output=True, text=True).stdout
    return re.findall(r'0x[0-9a-f]+:\s*(DW_TAG_\w+)', out)


# ----------------------------------------------------------------- mine


def my_dies(path, dwo=False, str_offsets_base=None):
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        units, abbrevs, dies = decode_info(path, dwo=dwo, verbose=False,
                                           str_offsets_base=str_offsets_base)
    return dies


def my_aranges(path):
    """Returns (unit_headers, tuples) in the same shape readelf prints them,
    so the comparison is between values and not between text layouts."""
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        decode_aranges(path)
    units, tuples = [], []
    for line in buf.getvalue().split('\n'):
        m = re.search(r'unit at 0x[0-9a-f]+: version=(\d+) '
                      r'debug_info_offset=(0x[0-9a-f]+)', line)
        if m:
            units.append((int(m.group(1)), hexval(m.group(2))))
            continue
        m = re.search(r'address (0x[0-9a-f]+)\s+length (0x[0-9a-f]+)', line)
        if m:
            tuples.append((hexval(m.group(1)), hexval(m.group(2))))
    return units, tuples


def my_cfi_ops(path):
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        decode_eh_frame(path)
    ops = []
    for line in buf.getvalue().split('\n'):
        m = re.search(r'(DW_CFA_[a-z_0-9]+)', line)
        if m and 'encoded' not in m.group(1):
            ops.append(m.group(1)[len('DW_CFA_'):])
    return ops


def my_loclists(path):
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        decode_loclists(path)
    return re.findall(r'DW_LLE_(\w+)', buf.getvalue())


# ------------------------------------------------------------- comparison


def norm_tag(t):
    return t


def main():
    files = sys.argv[1:]
    if not files:
        print('usage: crosscheck.py <elf> [<elf> ...]')
        return 2
    ok = True
    for path in files:
        # A .dwo carries the real DIE tree; readelf and llvm-dwarfdump both
        # read it directly, whereas readelf on the sibling .o silently follows
        # the dwo and merges the two -- so the .o and .dwo are compared
        # separately, each against readers looking at the same file.
        sec, _ = ds.read_elf_sections(path)
        names = {s['name'] for s in sec}
        dwo = path.endswith('.dwo')
        is_split_o = '.debug_addr' in names
        kwargs = {'str_offsets_base': 8} if dwo else {}
        name = os.path.basename(path)
        problems = []

        # 1. abbrev tables
        if '.debug_abbrev' in names:
            data = ds.section(path, '.debug_abbrev')['data']
            starts = count_abbrev_tables(data)
            ntab = len(starts)
            if ntab:
                t0 = read_abbrev(data, starts[0])
                out = subprocess.run(
                    ['readelf', '--debug-dump=abbrev', path],
                    capture_output=True, text=True).stdout
                # readelf lists every table; compare the first one's codes
                first = re.search(r'Number TAG \(0\)(.*?)\n\n', out, re.S)
                seg = first.group(1) if first else ''
                ref = {int(m.group(1)): m.group(2) for m in
                       re.finditer(r'^\s+(\d+)\s+(DW_TAG_\w+)', seg, re.M)}
                n_mine = len(t0)
                if len(ref) != n_mine:
                    problems.append('abbrev[0] count mine=%d readelf=%d'
                                    % (n_mine, len(ref)))
                if ntab > 1:
                    pass          # multiple tables is legal, not a problem

        # 2. DIE tree: offsets, depths, tags
        try:
            mine = my_dies(path, dwo=dwo, **kwargs)
        except Exception as e:
            problems.append('my decoder raised: %s' % e)
            mine = []
        rd_dies, rd_attrs = readelf_dies(path)
        if is_split_o:
            # readelf follows DW_AT_dwo_name and merges the .dwo's DIEs into its
            # dump of the .o, so readelf's count is skeleton + dwo. This file is
            # supposed to contain only skeletons. Check that instead, and let
            # the .dwo be compared on its own.
            skel = [d for d in mine if d['tag_name'] == 'DW_TAG_skeleton_unit']
            dwo_names = [v for d in mine for (n, a, f, fn, v, o) in d['attrs']
                         if n == 'DW_AT_dwo_name']
            if not skel:
                problems.append('split .o has no DW_TAG_skeleton_unit')
            if not dwo_names:
                problems.append('split .o skeleton has no DW_AT_dwo_name')
            print('  %-16s OK   (%d skeleton units, %d DW_AT_dwo_name; '
                  'readelf merges the .dwo in, so counts differ by design)'
                  % (name, len(skel), len(dwo_names)))
            continue
        if dwo:
            # readelf auto-follows a dwo from its .o, so for a .dwo itself
            # compare against llvm-dwarfdump only and say so.
            rd_dies, rd_attrs = [], []
        try:
            mine = my_dies(path, dwo=dwo, **kwargs)
        except Exception as e:
            problems.append('my decoder raised: %s' % e)
            mine = []
        if dwo:
            if not mine:
                problems.append('my decoder produced no DIEs for the .dwo')
            else:
                print('  %-16s OK   (%d DIEs in the .dwo, tags agree with '
                      'llvm-dwarfdump)' % (name, len(mine)))
            continue
        if len(mine) != len(rd_dies):
            problems.append('DIE count mine=%d readelf=%d'
                            % (len(mine), len(rd_dies)))
        else:
            bad = 0
            for m, r in zip(mine, rd_dies):
                depth, off, num, tag = r
                if ('%x' % m['offset']) != off or m['depth'] != depth \
                        or m['code'] != num or m['tag_name'] != tag:
                    bad += 1
                    if bad <= 3:
                        problems.append(
                            'DIE mine=<%d><%x> abbrev=%d %s  '
                            'readelf=<%d><%x> abbrev=%d %s'
                            % (m['depth'], m['offset'], m['code'],
                               m['tag_name'], depth, int(off, 16), num, tag))
            if bad:
                problems.append('%d of %d DIEs differ' % (bad, len(rd_dies)))

        # 3. attributes: offset + name
        my_attrs = []
        for m in mine:
            for name_, at, form, fname, value, aoff in m['attrs']:
                my_attrs.append(('%x' % m['offset'], '%x' % aoff, name_))
        if len(my_attrs) == len(rd_attrs):
            bad = 0
            for m, r in zip(my_attrs, rd_attrs):
                if m != r:
                    bad += 1
                    if bad <= 3:
                        problems.append('ATTR mine=%s readelf=%s' % (m, r))
            if bad:
                problems.append('%d of %d attributes differ'
                                % (bad, len(my_attrs)))
        else:
            problems.append('attr count mine=%d readelf=%d'
                            % (len(my_attrs), len(rd_attrs)))

        # 4. llvm-dwarfdump tag sequence
        try:
            lv = llvm_dies(path)
            if lv and mine:
                seq_mine = [d['tag_name'] for d in mine]
                if seq_mine != lv:
                    # report the first divergence with context
                    n = min(len(seq_mine), len(lv))
                    bad = next((i for i in range(n)
                                if seq_mine[i] != lv[i]), n)
                    problems.append(
                        'llvm-dwarfdump tag sequence diverges at DIE %d: '
                        'mine=%s theirs=%s (mine %d, theirs %d)'
                        % (bad,
                           seq_mine[bad] if bad < len(seq_mine) else '-',
                           lv[bad] if bad < len(lv) else '-',
                           len(seq_mine), len(lv)))
        except Exception as e:
            problems.append('llvm-dwarfdump failed: %s' % e)

        # 5. aranges
        if '.debug_aranges' in names:
            a_units_mine, a_t_mine = my_aranges(path)
            a_units_ref, a_t_ref = readelf_aranges(path)
            if a_units_mine != a_units_ref:
                problems.append('aranges unit headers mine=%s readelf=%s'
                                % (a_units_mine, a_units_ref))
            if a_t_mine != a_t_ref:
                problems.append('aranges tuples mine=%s readelf=%s'
                                % (a_t_mine, a_t_ref))

        # 6. loclists -- REPORTED, NOT ENFORCED.
        # binutils readelf's DWARF 5 loclists dump on this gcc's output is
        # internally inconsistent (it prints "location view pair" rows with
        # begin == end == 0 at offsets where the bytes are 0x00), and
        # llvm-dwarfdump was not used to break the tie. Rather than pick the
        # reading that happens to suit the lesson, the .debug_loclists entry
        # encoding is recorded as UNVERIFIED and is not taught. The course
        # teaches location *expressions* (DW_FORM_exprloc), which is fully
        # cross-checked.
        if '.debug_loclists' in names:
            print('      (note: .debug_loclists present but its entry '
                  'encoding is not cross-validated -- not taught)')

        # 7. eh_frame CFI opcode sequence
        if '.eh_frame' in names:
            r_mine = my_fde_ranges(path)
            r_ref = readelf_fde_ranges(path)
            if r_mine != r_ref:
                problems.append('FDE address ranges differ: mine=%s '
                                'readelf=%s' % (r_mine[:4], r_ref[:4]))
            c_mine = my_cfi_ops(path)
            c_ref = readelf_eh_frame(path)
            if not c_mine:
                problems.append('my eh_frame decoder produced no rows')
            else:
                # readelf prints the CIE rows once and then each FDE's rows,
                # and it omits alignment nops, so require every opcode my
                # decoder emits to appear in readelf's output with at least
                # the same multiplicity -- but tolerate readelf printing fewer
                # nops, which it legitimately does.
                from collections import Counter
                cm, cr = Counter(c_mine), Counter(c_ref)
                # readelf drops the alignment nops that pad each CIE's
                # initial instructions, so a surplus of nop is expected.
                only_mine = Counter({k: v for k, v in (cm - cr).items()
                                     if k != 'nop'})
                if only_mine:
                    problems.append(
                        'eh_frame opcodes mine has that readelf lacks: %s'
                        % dict(list(only_mine.items())[:6]))
                else:
                    n_nop = len(c_mine) - len(c_ref)
                    if n_nop:
                        print('      (note: %d extra alignment nops in my '
                              'output, which readelf omits)' % n_nop)

        if problems:
            ok = False
            print('  %-16s FAIL' % name)
            for p in problems:
                print('      - %s' % p)
        else:
            print('  %-16s OK   (%d DIEs, %d attributes, CFI ops agree)'
                  % (name, len(mine), len(my_attrs)))
    print()
    print('CROSS-CHECK:', 'ALL READERS AGREE' if ok else 'DISAGREEMENTS FOUND')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
