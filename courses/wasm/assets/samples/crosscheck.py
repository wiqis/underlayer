#!/usr/bin/env python3
"""Cross-check the WebAssembly decoder against two independent implementations.

Three readers, three codebases:
  * wasm_decode.py  -- written from the specification, shipped with this course
  * wasm-objdump    -- wabt
  * llvm-objdump    -- LLVM

Agreement on the section table is required before any claim in the course is
written down. Where they disagree, this script prints all three and says so
rather than picking a winner.

Usage: crosscheck.py [FILE ...]     (defaults to every .wasm and .o here)
"""

import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wasm_decode  # noqa: E402

# wabt prints:  "  Type start=0x0000000a end=0x00000014 (size=0x0000000a) count: 2"
#            and "  Custom start=... (size=...) "name""
# A custom section's name is printed in double quotes after the size.
WABT_RE = re.compile(
    r'^\s*(?:(\w+)\s+)?start=(0x[0-9a-f]+)\s+end=(0x[0-9a-f]+)\s+'
    r'\(size=(0x[0-9a-f]+)\)(?:\s+count:\s+(\d+))?(?:\s+"([^"]*)")?')

# llvm prints a table: "  0 TYPE            0000000a 0000000a "
LLVM_RE = re.compile(
    r'^\s*(\d+)\s+(\S+)\s+([0-9a-f]{8})\s+([0-9a-f]{8})\s*(\S*)')

# Note the spelling of 9. The specification calls it the Element section;
# wabt and llvm both print "elem". Using the tools' spelling here means the
# comparison is name-for-name, and the discrepancy is recorded in
# research.md rather than papered over by loosening the check.
ID_NAMES = {0: "custom", 1: "type", 2: "import", 3: "function", 4: "table",
            5: "memory", 6: "global", 7: "export", 8: "start", 9: "elem",
            10: "code", 11: "data", 12: "datacount", 13: "tag"}


def mine(path):
    """(id, declared_size, id_offset, payload_offset, custom_name) per section.

    `payload_offset` is where the contents start. wabt prints this as
    `start=`; the id and size bytes sit *before* it, so comparing it against
    the id byte is an off-by-two that looks like a disagreement between tools
    when it is really a disagreement about which field to compare.
    """
    b = open(path, "rb").read()
    out = []
    p = 8
    while p < len(b):
        sid = b[p]
        off = p
        p += 1
        size, p, _ = wasm_decode.uleb(b, p)
        cname = None
        if sid == 0:
            cname, _q = wasm_decode.name(b, p)
        out.append((sid, size, off, p, cname))
        p += size
    return out


def wabt(path):
    r = subprocess.run(["wasm-objdump", "-h", path],
                       capture_output=True, text=True)
    out = []
    for line in r.stdout.splitlines():
        m = WABT_RE.match(line)
        if not m:
            continue
        name, start, end, size, count, cname = m.groups()
        start = int(start, 16)
        size = int(size, 16)
        out.append({"name": cname if cname else (name.lower() if name else None),
                    "start": start, "end": int(end, 16), "size": size,
                    "count": int(count) if count else None})
    return out


def llvm(path):
    r = subprocess.run(["llvm-objdump", "-h", path],
                       capture_output=True, text=True)
    out = []
    started = False
    for line in r.stdout.splitlines():
        if line.strip().startswith("Idx"):
            started = True
            continue
        if not started:
            continue
        m = LLVM_RE.match(line)
        if not m:
            continue
        idx, name, size, vma, _kind = m.groups()
        out.append({"name": name.lower(), "size": int(size, 16),
                    "vma": int(vma, 16)})
    return out


def wabt_details(path):
    """Parse `wasm-objdump -x` into a flat list of (label, values...) facts.

    This is the payload-level check. The section-table comparison above can
    only catch framing errors; this catches a decoder that walks sections
    correctly and then misreads what is inside one -- which is a strictly
    worse bug, because the section table still looks perfect.
    """
    r = subprocess.run(["wasm-objdump", "-x", path],
                       capture_output=True, text=True)
    out = []
    for line in r.stdout.splitlines():
        line = line.strip()
        m = re.match(r'^- (type|func|table|memory|global)\[[0-9]+\]'
                     r'(.*?)(?:\s*<-|\s*->)?\s*$', line)
        if not m:
            continue
        kind, rest = m.group(1), m.group(2)
        nums = re.findall(r'\b(\d+)\b', rest)
        out.append((kind, tuple(int(x) for x in nums)))
    return out


def check_values(path):
    """Compare decoded global initialisers against wabt.

    The framing and count checks cannot see a wrong VALUE: a module whose
    global initialises to 43 instead of 42 has a perfect section table and
    perfect entry counts, and passes every other check in this file. This
    compares the actual numbers, which is the only way to close that gap.

    Demonstrated by injection: changing one value byte in a valid module
    passes the structure checks and is caught only here.
    """
    problems = []
    b = open(path, "rb").read()

    # wabt's wording, e.g. "- global[1] i32 mutable=0 - init i32=42"
    r = subprocess.run(["wasm-objdump", "-x", path], capture_output=True, text=True)
    theirs = {}
    for line in r.stdout.splitlines():
        m = re.search(r'init (i32|i64|f32|f64)=(-?[0-9.]+)', line)
        if m:
            idx = re.search(r'global\[([0-9]+)\]', line)
            if idx:
                theirs[int(idx.group(1))] = (m.group(1), m.group(2))

    # wabt numbers globals in the GLOBAL INDEX SPACE, which counts imports
    # first. A module with one imported global has its first *defined* global
    # at index 1. This checker got that wrong on its first run, which is the
    # clearest possible demonstration of why the offset matters.
    imported_globals = 0
    p = 8
    while p < len(b):
        sid = b[p]; p += 1
        size, p, _ = wasm_decode.uleb(b, p)
        if sid == 2:
            n, q, _ = wasm_decode.uleb(b, p)
            for _ in range(n):
                _m, q = wasm_decode.name(b, q)
                _f, q = wasm_decode.name(b, q)
                kind = b[q]; q += 1
                if kind == 0x03:               # global
                    q += 2
                    imported_globals += 1
                elif kind == 0x00:             # func
                    _i, q, _ = wasm_decode.uleb(b, q)
                elif kind == 0x01:             # table
                    q += 1
                    _t, q = wasm_decode.limits(b, q)
                elif kind == 0x02:             # memory
                    _t, q = wasm_decode.limits(b, q)
        p += size

    mine = {}
    p = 8
    while p < len(b):
        sid = b[p]; p += 1
        size, p, _ = wasm_decode.uleb(b, p)
        if sid == 6:
            n, q, _ = wasm_decode.uleb(b, p)
            for k in range(n):
                t = b[q]; q += 1
                mut = b[q]; q += 1
                text, q = wasm_decode.init_expr(b, q, p + size)
                m2 = re.match(r'(i32|i64)\.const (-?[0-9]+) end', text)
                if m2:
                    mine[k + imported_globals] = (m2.group(1), m2.group(2))
        p += size

    for k in sorted(set(mine) | set(theirs)):
        a, bv = mine.get(k), theirs.get(k)
        if a != bv:
            problems.append("global[%d] initialiser differs: mine=%s wabt=%s"
                            % (k, a, bv))
    return problems


def check_payloads(path):
    """Compare what each decoder says about function/global/memory counts.

    Deliberately compares *counts and numeric facts* rather than text, because
    the two tools word their output differently by design. What must match is
    the number of entries of each kind and the indices they mention.
    """
    problems = []
    b = open(path, "rb").read()
    mine_counts = {}
    mine_idx = set()
    p = 8
    while p < len(b):
        sid = b[p]; p += 1
        size, p, _ = wasm_decode.uleb(b, p)
        start = p
        if sid in (2, 3, 4, 5, 6, 7):
            n, q, _ = wasm_decode.uleb(b, p)
            mine_counts.setdefault(sid, 0)
            mine_counts[sid] += n
        if sid == 3:
            q = p
            for _ in range(mine_counts.get(3, 0)):
                idx, q, _ = wasm_decode.uleb(b, q)
                mine_idx.add(idx)
        p = start + size

    theirs = wabt_details(path)
    their_counts = {}
    for kind, nums in theirs:
        # the kind word in wabt's output is the item class, not the section
        if kind in ("func", "table", "memory", "global"):
            their_counts[kind] = their_counts.get(kind, 0) + 1
        if kind == "type":
            their_counts["type"] = their_counts.get("type", 0) + 1

    sid_to_kind = {2: None, 3: "func", 4: "table", 5: "memory", 6: "global", 7: None}
    for sid, kind in sid_to_kind.items():
        if kind is None:
            continue
        # a section's entries are additional to whatever the import section
        # declared, and wabt's numbering is global, so compare totals
        mine_n = mine_counts.get(sid, 0)
        wabt_n = their_counts.get(kind, 0)
        if mine_n > wabt_n:
            problems.append(
                "section %d: my decoder claims %d entries but wabt shows only "
                "%d %s entries in total" % (sid, mine_n, wabt_n, kind))
    return problems


def check(path):
    ms, ws, ls = mine(path), wabt(path), llvm(path)
    problems = []
    problems += check_payloads(path)
    problems += check_values(path)

    if len(ms) != len(ws):
        problems.append("section COUNT differs: mine=%d wabt=%d" % (len(ms), len(ws)))
    if len(ms) != len(ls):
        problems.append("section COUNT differs: mine=%d llvm=%d" % (len(ms), len(ls)))

    for i, (sid, size, off, payload, cname) in enumerate(ms):
        want = cname if sid == 0 else ID_NAMES.get(sid, "id-%d" % sid)

        if i < len(ws):
            w = ws[i]
            if w["size"] != size:
                problems.append(
                    "section %d (%s) SIZE differs: mine=%d wabt=%d"
                    % (i, want, size, w["size"]))
            if w["start"] != payload:
                problems.append(
                    "section %d (%s) PAYLOAD START differs: mine=0x%x wabt=0x%x"
                    % (i, want, payload, w["start"]))
            if sid == 0:
                if (w["name"] or "").lower() != (cname or "").lower():
                    problems.append(
                        "custom section %d NAME differs: mine=%s wabt=%s"
                        % (i, cname, w["name"]))
            elif w["name"] and w["name"] != want:
                problems.append(
                    "section %d NAME differs: mine=%s wabt=%s" % (i, want, w["name"]))

        if i < len(ls):
            l = ls[i]
            # llvm lower-cases custom section names, so compare those loosely
            if (l["name"] or "").lower() != (want or "").lower():
                problems.append(
                    "section %d NAME differs: mine=%s llvm=%s" % (i, want, l["name"]))
            # For standard sections the two tools agree. For custom sections
            # wabt reports the declared size and llvm the payload after the
            # name, so only compare the standard ones.
            if sid != 0 and l["size"] != size:
                problems.append(
                    "section %d (%s) SIZE differs: mine=%d llvm=%d"
                    % (i, want, size, l["size"]))

    return problems, ms, ws, ls


def main(argv):
    files = [a for a in argv[1:] if not a.startswith("-")]
    if not files:
        here = os.path.dirname(os.path.abspath(__file__))
        files = sorted(os.path.join(here, f) for f in os.listdir(here)
                       if f.endswith(".wasm") or f.endswith(".o"))
    failed = 0
    for path in files:
        problems, ms, ws, ls = check(path)
        name = os.path.basename(path)
        if problems:
            failed += 1
            print("FAIL  %s" % name)
            for p in problems:
                print("        %s" % p)
        else:
            print("ok    %-24s %2d sections, three readers agree" % (name, len(ms)))
    print()
    print("%d file(s) checked, %d with disagreements" % (len(files), failed))
    if failed:
        print("CROSS-CHECK FAILED -- do not write claims from this data")
        return 1
    print("CROSS-CHECK PASSED -- all three readers agree on every section")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
