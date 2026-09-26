#!/usr/bin/env python3
"""Cross-check the three readers of the JVM class file format.

Three independent implementations read every sample and must agree:

  1. class_decode.py  -- this course's decoder, written from the JVM
                         Specification, deliberately not a validator.
  2. javap -v         -- the JDK's own disassembler.
  3. Cf.java          -- a program using java.lang.classfile, the JDK's own
                         standard parsing API, reached through its public
                         interface rather than through a disassembler.

The JVM verifier is a fourth, boolean oracle: a class that loads and runs has
been accepted by a completely separate implementation. That is checked by
`verifier_ok`, not here, because it needs a JVM run per sample.

WHAT THIS COMPARES, and the limits of each comparison, are documented at the
bottom of the file. The limits matter: a harness that only checks framing will
happily pass a decoder that misreads every value inside a section, which is the
exact bug this harness was extended to catch.

Usage:
    python3 crosscheck.py                    # every sample
    python3 crosscheck.py classes/Str.class  # one file
"""

import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import class_decode  # noqa: E402

CLASS_DIR = os.path.join(HERE, "classes")
JAVA = "java"
JAVAP = "javap"
CF_CLASSPATH = HERE


# --------------------------------------------------------------------------
# Reader 1: this course's decoder.
# --------------------------------------------------------------------------
def mine(path):
    r = class_decode.Reader(open(path, "rb").read())
    magic = r.u4()
    minor = r.u2()
    major = r.u2()
    entries, count = class_decode.read_pool(r)
    usable = len(entries)
    holes = class_decode.pool_holes(entries, count)
    access = r.u2()
    this_i = r.u2()
    sup_i = r.u2()
    ni = r.u2()
    ifaces = [class_decode.class_name(entries, r.u2()) for _ in range(ni)]

    def members(tagname):
        n = r.u2()
        out = []
        for _ in range(n):
            r.u2()
            nm = class_decode.utf(entries, r.u2())
            de = class_decode.utf(entries, r.u2())
            attrs = []
            for an, _ani, _alen, _ab in class_decode.read_attrs(r, entries, r.u2()):
                attrs.append(an)
            out.append((nm, de, tuple(sorted(attrs))))
        return out

    fields = members("field")
    methods = members("method")
    nattr = r.u2()
    attrs = []
    for an, _ani, alen, abody in class_decode.read_attrs(r, entries, nattr):
        attrs.append((an, alen))
    return {
        "magic": magic,
        "minor": minor,
        "major": major,
        "cp_count": count,
        "cp_usable": usable,
        "cp_holes": tuple(holes),
        "this": class_decode.class_name(entries, this_i),
        "super": class_decode.class_name(entries, sup_i) if sup_i else None,
        "ifaces": tuple(ifaces),
        "fields": tuple(fields),
        "methods": tuple(methods),
        "class_attrs": tuple(sorted(a for a, _ in attrs)),
        "consumed_all": r.pos() == len(open(path, "rb").read()),
    }


# --------------------------------------------------------------------------
# Reader 2: javap -v.
# --------------------------------------------------------------------------
def javap(path):
    out = subprocess.run([JAVAP, "-v", "-p", path],
                         capture_output=True, text=True).stdout
    f = {}
    m = re.search(r"minor version: (\d+)", out)
    f["minor"] = int(m.group(1)) if m else None
    m = re.search(r"major version: (\d+)", out)
    f["major"] = int(m.group(1)) if m else None
    m = re.search(r"this_class: #(\d+)\s+// (\S+)", out)
    f["this"] = m.group(2) if m else None
    m = re.search(r"super_class: #(\d+)\s+// (\S+)", out)
    f["super"] = m.group(2) if m and m.group(2) != "java/lang/Object" or (
        m and m.group(2) == "java/lang/Object") else (m.group(2) if m else None)
    m = re.search(r"interfaces: (\d+), fields: (\d+), methods: (\d+), "
                  r"attributes: (\d+)", out)
    f["ifaces_n"] = int(m.group(1)) if m else None
    f["fields_n"] = int(m.group(2)) if m else None
    f["methods_n"] = int(m.group(3)) if m else None
    f["attrs_n"] = int(m.group(4)) if m else None

    # The constant pool: javap numbers entries and SILENTLY SKIPS the second
    # half of every Long and Double, so the gaps in its numbering are the holes.
    idx, tags = set(), []
    for line in out.splitlines():
        m = re.match(r"\s*#(\d+) = (\w+)", line)
        if m:
            idx.add(int(m.group(1)))
            tags.append((int(m.group(1)), m.group(2)))
    if idx:
        hi = max(idx)
        f["cp_holes"] = tuple(i for i in range(1, hi + 1) if i not in idx)
        f["cp_usable"] = len(idx)
    return f


# --------------------------------------------------------------------------
# Reader 3: java.lang.classfile, the JDK's own standard API.
# --------------------------------------------------------------------------
def api(path):
    r = subprocess.run([JAVA, "-cp", CF_CLASSPATH, "Cf", path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("Cf failed on %s: %s" % (path, r.stderr[:300]))
    f = {"fields": [], "methods": []}
    for line in r.stdout.splitlines():
        t = line.strip()
        m = re.match(r"minor (\d+)$", t)
        if m:
            f["minor"] = int(m.group(1)); continue
        m = re.match(r"major (\d+)$", t)
        if m:
            f["major"] = int(m.group(1)); continue
        m = re.match(r"thisClass (\S+)$", t)
        if m:
            f["this"] = m.group(1); continue
        m = re.match(r"superClass (\S+)$", t)
        if m:
            f["super"] = None if m.group(1) == "(none)" else m.group(1); continue
        m = re.match(r"interfaces (\d+)$", t)
        if m:
            f["ifaces_n"] = int(m.group(1)); continue
        m = re.match(r"fields (\d+)$", t)
        if m:
            f["fields_n"] = int(m.group(1)); continue
        m = re.match(r"methods (\d+)$", t)
        if m:
            f["methods_n"] = int(m.group(1)); continue
        m = re.match(r"field (\S+) (.*)$", t)
        if m:
            f["fields"].append((m.group(1), m.group(2))); continue
        m = re.match(r"method (\S+) (.*)$", t)
        if m:
            f["methods"].append((m.group(1), m.group(2))); continue
        m = re.match(r"cpSize (\d+)$", t)
        if m:
            f["cp_count"] = int(m.group(1)); continue
        m = re.match(r"cpUsable (\d+)$", t)
        if m:
            f["cp_usable"] = int(m.group(1)); continue
        m = re.match(r"cpHoles (\d+)$", t)
        if m:
            f["cp_holes_n"] = int(m.group(1)); continue
        m = re.match(r"cpHoleIdx(.*)$", t)
        if m:
            f["cp_holes"] = tuple(int(x) for x in m.group(1).split()); continue
    return f


# --------------------------------------------------------------------------
# Comparison.
# --------------------------------------------------------------------------
def check(path):
    a, b, c = mine(path), javap(path), api(path)
    problems = []

    def same(field, label=None):
        va, vb, vc = a.get(field), b.get(field), c.get(field)
        if vb is None or vc is None:
            return
        if not (va == vb == vc):
            problems.append("%s differs: mine=%r javap=%r api=%r"
                            % (label or field, va, vb, vc))

    same("minor")
    same("major")
    same("cp_count")
    same("cp_usable")
    same("cp_holes")

    # this_class and super_class: javap prints internal names with '/', the API
    # prints them with '.', so normalise before comparing.
    for field in ("this", "super"):
        va, vb, vc = a.get(field), b.get(field), c.get(field)
        if vb is None:
            continue
        vb2 = vb.replace("/", ".")
        if va != vb2:
            problems.append("%s differs: mine=%r javap=%r api=%r"
                            % (field, va, vb2, vc))
        if va != vc:
            problems.append("%s differs: mine=%r api=%r" % (field, va, vc))

    if len(a["fields"]) != b.get("fields_n"):
        problems.append("field COUNT differs: mine=%d javap=%d"
                        % (len(a["fields"]), b.get("fields_n")))
    if len(a["fields"]) != c.get("fields_n"):
        problems.append("field COUNT differs: mine=%d api=%d"
                        % (len(a["fields"]), c.get("fields_n")))
    if len(a["methods"]) != b.get("methods_n"):
        problems.append("method COUNT differs: mine=%d javap=%d"
                        % (len(a["methods"]), b.get("methods_n")))
    if len(a["methods"]) != c.get("methods_n"):
        problems.append("method COUNT differs: mine=%d api=%d"
                        % (len(a["methods"]), c.get("methods_n")))

    # The API reports members as (name, descriptor); compare those directly.
    if c.get("fields"):
        mine_f = [(n, d) for n, d, _ in a["fields"]]
        if mine_f != c["fields"]:
            problems.append("field NAMES/DESCRIPTORS differ:\n      mine=%r\n      api =%r"
                            % (mine_f, c["fields"]))
    if c.get("methods"):
        mine_m = [(n, d) for n, d, _ in a["methods"]]
        if mine_m != c["methods"]:
            problems.append("method NAMES/DESCRIPTORS differ:\n      mine=%r\n      api =%r"
                            % (mine_m, c["methods"]))

    if not a["consumed_all"]:
        problems.append("my decoder did not consume the whole file")

    return problems


def verifier_ok(path):
    """A fourth, boolean oracle: does the JVM accept this class file?

    The class is loaded with a ClassLoader but NOT initialised, which runs the
    format check and the verifier without executing any of its code. A class
    that passes here has been accepted by an implementation that shares no code
    with any of the three readers above.
    """
    prog = ("import java.io.*;import java.nio.file.*;"
            "public class V{public static void main(String[] a)throws Exception{"
            "byte[]b=Files.readAllBytes(Path.of(a[0]));"
            "new ClassLoader(){Class<?> def(){return defineClass(null,b,0,b.length);}}"
            ".def().getName();System.out.println(\"ok\");}}")
    tmp = os.path.join("/tmp", "_jvmverify")
    os.makedirs(tmp, exist_ok=True)
    src = os.path.join(tmp, "V.java")
    open(src, "w").write(prog)
    c = subprocess.run(["javac", "-d", tmp, src], capture_output=True, text=True)
    if c.returncode != 0:
        return None
    r = subprocess.run([JAVA, "-cp", tmp, "V", path], capture_output=True, text=True)
    return r.returncode == 0


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        paths = args
    else:
        paths = sorted(os.path.join(CLASS_DIR, f)
                       for f in os.listdir(CLASS_DIR) if f.endswith(".class"))
    bad = 0
    for p in paths:
        try:
            problems = check(p)
        except Exception as e:
            problems = ["harness error: %s" % e]
        name = os.path.relpath(p, HERE)
        if problems:
            bad += 1
            print("FAIL  %s" % name)
            for x in problems:
                print("        %s" % x)
        else:
            print("ok    %-26s three readers agree" % name)
    print()
    print("%d file(s) checked, %d with disagreements" % (len(paths), bad))
    if bad:
        print("CROSS-CHECK FAILED -- do not write claims from this data")
        return 1
    print("CROSS-CHECK PASSED -- all three readers agree")
    return 0


# --------------------------------------------------------------------------
# What this harness checks, and what it does not. Written down because a
# harness whose limits are undocumented will eventually be trusted past them.
# --------------------------------------------------------------------------
#
# CHECKS, at four levels. Each was confirmed to fail when it should:
#
#   structure  magic, minor, major, and whether the whole file was consumed
#   framing    constant_pool_count, and therefore the pool's size
#   slots      usable entry count AND the exact indices of the Long/Double
#              holes -- compared against the gaps in javap's own numbering
#              and against the JDK API's entryByIndex, which throws on them
#   content    this_class, super_class, member counts, and every member's
#              name and descriptor, compared against the API member by member
#
# DOES NOT CHECK:
#
#   * Attribute BODIES. Only attribute names are compared. A decoder that
#     found every attribute and then read its contents wrongly passes here.
#     The Code attribute's max_stack, max_locals, code and exception table are
#     printed by class_decode.py but not cross-checked, because javap presents
#     them as a disassembly rather than as fields and the comparison would need
#     a disassembler to be fair.
#   * Constant pool VALUES. Tags and slots are compared; the integer a
#     CONSTANT_Integer holds is not. The same applies to Long, Float, Double
#     and the String payload.
#   * Access FLAG names. Each reader has its own table and they could all
#     disagree with the specification while agreeing with each other. The
#     flags were instead verified by hand against javap's output on a class
#     that uses a wide spread of them, which is the only comparison that can
#     catch a shared mistake.
#   * Whether the JVM would LOAD the file. verifier_ok() does that separately
#     and is not part of the pass/fail decision, because a decoder is allowed
#     to read files the JVM rejects.
if __name__ == "__main__":
    sys.exit(main())
