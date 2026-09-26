#!/usr/bin/env python3
"""A JVM class file decoder, written from the JVM Specification.

This is deliberately NOT a validator. It reads the structure and prints what it
finds; it does not check that the thing it read makes sense. That distinction is
itself a teaching point, and it is why this file is useful to learn from: the
class file format is the rare binary format where a decoder can be completely
correct about the bytes and still be handed a file no JVM will load.

Everything here is BIG-ENDIAN, which is worth saying twice, because it is the
first thing that surprises anyone arriving from ELF, PE or x86, all of which are
little-endian. The 0xCAFEBABE magic is the famous exception that proves the
rule: it is big-endian, so it reads as 0xCAFEBABE in a hex dump and as the
"Java class file" keyword in a file(1) signature. A little-endian reader sees
0xBEBAFECA.

Usage:
    python3 class_decode.py Foo.class
    python3 class_decode.py Foo.class --cp-only
    python3 class_decode.py Foo.class --hex
"""

import struct
import sys

# Constant pool tags, from the JVM Specification, Table 4.4-A.
#
# The two entries marked "2 slots" are the reason the constant pool cannot be
# indexed naively: CONSTANT_Long and CONSTANT_Double are eight bytes of payload
# but consume TWO consecutive constant pool indices, and the second one is
# permanently unusable. See the "lonely double" material in the course.
TAGS = {
    1:  ("Utf8",               1),
    3:  ("Integer",            1),
    4:  ("Float",              1),
    5:  ("Long",               2),
    6:  ("Double",             2),
    7:  ("Class",              1),
    8:  ("String",             1),
    9:  ("Fieldref",           1),
    10: ("Methodref",          1),
    11: ("InterfaceMethodref", 1),
    12: ("NameAndType",        1),
    15: ("MethodHandle",       1),
    16: ("MethodType",         1),
    17: ("Dynamic",            1),
    18: ("InvokeDynamic",      1),
    19: ("Module",             1),
    20: ("Package",            1),
}

# access_flags, Table 4.1-A for classes and 4.1-B for fields and 4.1-C for
# methods. They are DIFFERENT bit assignments that share the same u2 field, and
# reusing one table for all three is a classic source of nonsense output.
# NOTE: 0x0009 is NOT ACC_FINAL. It is ACC_PUBLIC|ACC_STATIC, and javap prints
# the two separately. An earlier version of this file had it as a single entry
# called ACC_FINAL and reported 0x0009 methods as "ACC_PUBLIC ACC_FINAL", which
# is two wrong names and a missing one. Every value below is a single bit.
ACC_CLASS = {
    0x0001: "ACC_PUBLIC", 0x0010: "ACC_FINAL", 0x0020: "ACC_SUPER",
    0x0200: "ACC_INTERFACE", 0x0400: "ACC_ABSTRACT", 0x1000: "ACC_SYNTHETIC",
    0x2000: "ACC_ANNOTATION", 0x4000: "ACC_ENUM", 0x8000: "ACC_MODULE",
}
ACC_FIELD = {
    0x0001: "ACC_PUBLIC", 0x0002: "ACC_PRIVATE", 0x0004: "ACC_PROTECTED",
    0x0008: "ACC_STATIC", 0x0010: "ACC_FINAL", 0x0040: "ACC_VOLATILE",
    0x0080: "ACC_TRANSIENT", 0x1000: "ACC_SYNTHETIC", 0x4000: "ACC_ENUM",
}
ACC_METHOD = {
    0x0001: "ACC_PUBLIC", 0x0002: "ACC_PRIVATE", 0x0004: "ACC_PROTECTED",
    0x0008: "ACC_STATIC", 0x0010: "ACC_FINAL", 0x0020: "ACC_SYNCHRONIZED",
    0x0040: "ACC_BRIDGE", 0x0080: "ACC_VARARGS", 0x0100: "ACC_NATIVE",
    0x0400: "ACC_ABSTRACT", 0x0800: "ACC_STRICT", 0x1000: "ACC_SYNTHETIC",
}

# MethodHandle reference_kind -> what index it points at, Table 4.4.8-A.
REF_KINDS = {
    1: "getField",          2: "getStatic",         3: "putField",
    4: "putStatic",         5: "invokeVirtual",     6: "invokeStatic",
    7: "invokeSpecial",     8: "newInvokeSpecial",  9: "invokeInterface",
}


class Bad(Exception):
    pass


class Reader:
    """A big-endian cursor over the whole file."""

    def __init__(self, data):
        self.d = data
        self.p = 0

    def u1(self):
        v = self.d[self.p]
        self.p += 1
        return v

    def u2(self):
        v = struct.unpack_from(">H", self.d, self.p)[0]
        self.p += 2
        return v

    def u4(self):
        v = struct.unpack_from(">I", self.d, self.p)[0]
        self.p += 4
        return v

    def u8(self):
        v = struct.unpack_from(">Q", self.d, self.p)[0]
        self.p += 8
        return v

    def raw(self, n):
        v = self.d[self.p:self.p + n]
        if len(v) != n:
            raise Bad("wanted %d bytes, only %d left" % (n, len(v)))
        self.p += n
        return v

    def at(self, pos):
        self.p = pos

    def pos(self):
        return self.p


class Entry:
    """One constant pool entry.

    `slots` is 2 for Long and Double. The next usable index is index + slots,
    and for those two the index in between is a hole that no valid reference can
    ever point at.
    """

    def __init__(self, index, tag, name, value, slots, offset):
        self.index = index
        self.tag = tag
        self.name = name
        self.value = value
        self.slots = slots
        self.offset = offset


def utf8_of(b):
    """Decode a CONSTANT_Utf8, which is NOT standard UTF-8.

    Java's "modified UTF-8" differs from the real thing in two ways, and both
    were confirmed against javac output for the Str.class sample in this
    course's assets:

    1. NUL is encoded as 0xC0 0x80 -- two bytes -- so that no string can
       contain a zero byte and be truncated by something that stops at NUL.
       Verified: the Java source "a\0b" appears as 61 c0 80 62.

    2. A character OUTSIDE the Basic Multilingual Plane is encoded as its
       UTF-16 SURROGATE PAIR, with each surrogate encoded separately as three
       bytes. Verified: the emoji U+1F389 appears as
       ed a0 bc ed be 89 -- six bytes, where real UTF-8 uses four. This is
       CESU-8, and it is why a plain UTF-8 decoder rejects the bytes outright.

    Both deviations are undone here. Surrogates are recombined first, because
    combining them afterwards would produce a pair that cannot be re-encoded,
    and then the 0xC0 0x80 pairs are collapsed to a real NUL.
    """
    # 1. CESU-8: recombine the surrogate pairs into real astral characters.
    out = bytearray()
    i = 0
    n = len(b)
    while i < n:
        # An encoded surrogate is ED A0-AF xx (high) or ED B0-BF xx (low).
        if (b[i] == 0xED and i + 2 < n
                and 0xA0 <= b[i + 1] <= 0xBF and 0x80 <= b[i + 2] <= 0xBF):
            hi = 0xD000 | ((b[i + 1] & 0x3F) << 6) | (b[i + 2] & 0x3F)
            if (i + 5 < n and b[i + 3] == 0xED
                    and 0xB0 <= b[i + 4] <= 0xBF and 0x80 <= b[i + 5] <= 0xBF):
                lo = 0xD000 | ((b[i + 4] & 0x3F) << 6) | (b[i + 5] & 0x3F)
                cp = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
                out += chr(cp).encode("utf-8")
                i += 6
                continue
            # An unpaired surrogate: keep it as the replacement character
            # rather than silently dropping it.
            out += b"\xef\xbf\xbd"
            i += 3
            continue
        out.append(b[i])
        i += 1
    # 2. 0xC0 0x80 is a NUL.
    return bytes(out).replace(b"\xc0\x80", b"\x00").decode("utf-8", "replace")


def pool_holes(entries, count):
    """The indices in 1..count-1 that no entry occupies.

    These are the second halves of every CONSTANT_Long and CONSTANT_Double. The
    reason this is a shared function rather than something each caller works
    out for itself: an earlier version computed the hole list in TWO places --
    once in dump() and once in the crosscheck harness -- and the harness only
    exercised its own copy. A deliberate fault injected into dump()'s copy went
    completely undetected, which is exactly the failure mode duplicated logic
    invites. One implementation, and the harness covers it.
    """
    return [i for i in range(1, count) if i not in entries]


def read_pool(r):
    """Read the whole constant pool.

    Returns (entries_by_index, count) where count is the u2 from the file, i.e.
    one more than the number of usable entries, because the pool is 1-indexed
    and index 0 is never valid.
    """
    count = r.u2()
    entries = {}
    i = 1
    while i < count:
        off = r.pos()
        tag = r.u1()
        if tag not in TAGS:
            raise Bad("constant pool entry %d has unknown tag %d at 0x%x"
                      % (i, tag, off))
        name, slots = TAGS[tag]
        if tag == 1:                                  # Utf8
            n = r.u2()
            v = utf8_of(r.raw(n))
        elif tag == 3:                                # Integer
            v = r.u4()
        elif tag == 4:                                # Float
            v = struct.unpack(">f", struct.pack(">I", r.u4()))[0]
        elif tag == 5:                                # Long
            v = struct.unpack(">q", struct.pack(">Q", r.u8()))[0]
        elif tag == 6:                                # Double
            v = struct.unpack(">d", struct.pack(">Q", r.u8()))[0]
        elif tag in (7, 8, 16, 19, 20):               # Class, String, MethodType, Module, Package
            v = r.u2()
        elif tag in (9, 10, 11, 12, 17, 18):          # the *ref family
            v = (r.u2(), r.u2())
        elif tag == 15:                               # MethodHandle
            v = (r.u1(), r.u2())
        else:
            raise Bad("unhandled tag %d at 0x%x" % (tag, off))
        entries[i] = Entry(i, tag, name, v, slots, off)
        i += slots
    return entries, count


def flags_str(v, table):
    """Render an access_flags u2 as names.

    The unknown-bit mask is built from the OR of every defined bit rather than
    from ~sum(table): summing the values is wrong the moment two entries share
    a bit, and `v & ~sum(...)` in Python mixes in the sign extension of a
    negative number, which reports bits that are not set.
    """
    mask = 0
    for b in table:
        mask |= b
    out = [n for b, n in sorted(table.items()) if v & b == b and b]
    extra = v & (~mask & 0xFFFF)
    if extra:
        out.append("UNKNOWN(0x%04x)" % extra)
    return " ".join(out) if out else "(none)"


def utf(entries, i):
    e = entries.get(i)
    if e is None or e.tag != 1:
        return "<not a Utf8: #%d>" % i
    return e.value


def resolve(entries, i):
    """Render a reference the way a human reads it: name + descriptor."""
    e = entries.get(i)
    if e is None:
        return "<no entry #%d>" % i
    if e.name in ("Methodref", "Fieldref", "InterfaceMethodref"):
        cls, nat = e.value
        return "%s.%s:%s" % (class_name(entries, cls), utf(entries, nat[0]),
                             utf(entries, nat[1]))
    if e.name == "NameAndType":
        return "%s:%s" % (utf(entries, e.value[0]), utf(entries, e.value[1]))
    if e.name == "Class":
        return class_name(entries, i)
    if e.name == "String":
        return '"%s"' % utf(entries, e.value)
    return str(e.value)


def class_name(entries, i):
    e = entries.get(i)
    if e is None or e.name != "Class":
        return "<not a Class: #%d>" % i
    return utf(entries, e.value).replace("/", ".")


def read_attrs(r, entries, n):
    """Read exactly `n` attributes.

    The count is a PARAMETER, not something this function reads. Three of the
    four call sites already had to read it to print a summary, and letting this
    function read it as well meant the class-level call consumed the count
    twice -- which showed up as a plausible attribute_name_index, a garbage
    attribute_length, and a cursor that jumped 131KB past the end of a 409-byte
    file. Taking the count as an argument makes the contract impossible to
    get wrong.
    """
    out = []
    for _ in range(n):
        ni = r.u2()
        ln = r.u4()
        body_at = r.pos()
        out.append((utf(entries, ni), ni, ln, body_at))
        r.at(body_at + ln)
    return out


def cp_line(entries, e):
    """One printable line for one constant pool entry."""
    v = e.value
    if e.name == "Utf8":
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"')
    if e.name in ("Methodref", "Fieldref", "InterfaceMethodref"):
        return "%s.#%d" % (class_name(entries, v[0]), v[1])
    if e.name == "NameAndType":
        return "#%d:#%d" % v
    if e.name == "Class":
        return "#%d" % v
    if e.name == "String":
        return "#%d" % v
    if e.name == "MethodType":
        return "#%d" % v
    if e.name in ("Module", "Package"):
        return "#%d" % v
    if e.name == "MethodHandle":
        return "%s #%d" % (REF_KINDS.get(v[0], "kind%d" % v[0]), v[1])
    if e.name in ("Dynamic", "InvokeDynamic"):
        return "bsm#%d %s" % (v[0], resolve(entries, v[1]))
    return str(v)


def dump(path, cp_only=False, show_hex=False):
    data = open(path, "rb").read()
    r = Reader(data)
    out = []

    magic = r.u4()
    if magic != 0xCAFEBABE:
        raise Bad("magic is 0x%08X, not 0xCAFEBABE -- this is not a class file, "
                  "or it is little-endian" % magic)
    minor = r.u2()
    major = r.u2()
    out.append("file: %s  (%d bytes)" % (path, len(data)))
    out.append("  magic   0x%08X  (big-endian: cafebabe)" % magic)
    out.append("  minor   %d" % minor)
    out.append("  major   %d" % major)

    entries, cp_count = read_pool(r)
    n_usable = len(entries)
    longest = max(entries) if entries else 0
    out.append("  constant_pool_count %d  -> %d usable entries, highest index %d"
               % (cp_count, n_usable, longest))
    if cp_count - 1 != n_usable:
        out.append("    (%d slots consumed by Long/Double, which take two each)"
                   % (cp_count - 1 - n_usable))
    holes = pool_holes(entries, cp_count)
    if holes:
        out.append("    UNUSABLE indices (second half of a Long/Double): %s"
                   % ", ".join(str(i) for i in holes))
    if cp_only:
        for i in sorted(entries):
            e = entries[i]
            out.append("    #%-3d %-18s %s" % (i, e.name, cp_line(entries, e)))
        return "\n".join(out)

    access = r.u2()
    this_i = r.u2()
    super_i = r.u2()
    out.append("  access_flags 0x%04X  %s" % (access, flags_str(access, ACC_CLASS)))
    out.append("  this_class  #%d  %s" % (this_i, class_name(entries, this_i)))
    out.append("  super_class #%d  %s"
               % (super_i, class_name(entries, super_i) if super_i else "(none)"))

    ni = r.u2()
    ifaces = [r.u2() for _ in range(ni)]
    out.append("  interfaces %d  %s" % (ni, ", ".join(
        "#%d=%s" % (i, class_name(entries, i)) for i in ifaces)))

    nf = r.u2()
    out.append("  fields %d" % nf)
    for k in range(nf):
        af = r.u2()
        nm = r.u2()
        de = r.u2()
        out.append("    [%d] 0x%04X %s  %s %s"
                   % (k, af, flags_str(af, ACC_FIELD), utf(entries, nm),
                      utf(entries, de)))
        for an, ani, alen, _ in read_attrs(r, entries, r.u2()):
            out.append("         attr %s (%d bytes)" % (an, alen))

    nm = r.u2()
    out.append("  methods %d" % nm)
    for k in range(nm):
        af = r.u2()
        nmi = r.u2()
        de = r.u2()
        out.append("    [%d] 0x%04X %s  %s %s"
                   % (k, af, flags_str(af, ACC_METHOD), utf(entries, nmi),
                      utf(entries, de)))
        # read_attrs leaves the cursor after the LAST attribute, which is
        # exactly where the sequential walk needs to be, so there is nothing to
        # restore here. Only the Code sub-parse below moves the cursor, and it
        # puts it back itself.
        for an, ani, alen, abody in read_attrs(r, entries, r.u2()):
            out.append("         attr %s (%d bytes) at 0x%x" % (an, alen, abody))
            if an == "Code":
                # Saving AFTER read_attrs has finished is deliberate: the
                # cursor is already past every attribute, and the Code body is
                # somewhere behind us. Restoring to this position puts the
                # walk back on the right track.
                keep = r.pos()
                r.at(abody)
                ms = r.u2()
                ml = r.u2()
                clen = r.u4()
                code = r.raw(clen)
                out.append("           max_stack=%d max_locals=%d code_length=%d"
                           % (ms, ml, clen))
                out.append("           code: %s" % code.hex(" "))
                etl = r.u2()
                out.append("           exception_table_length=%d" % etl)
                for _ in range(etl):
                    s, e, h, ct = r.u2(), r.u2(), r.u2(), r.u2()
                    out.append("             from=%d to=%d target=%d type=%s"
                               % (s, e, h,
                                  "#%d=%s" % (ct, class_name(entries, ct))
                                  if ct else "(any)"))
                for sn, sni, slen, sbody in read_attrs(r, entries, r.u2()):
                    out.append("           code-attr %s (%d bytes)" % (sn, slen))
                r.at(keep)

    na = r.u2()
    out.append("  attributes %d" % na)
    for an, ani, alen, abody in read_attrs(r, entries, na):
        out.append("    attr %s (%d bytes) at 0x%x" % (an, alen, abody))
        if an == "BootstrapMethods":
            r.at(abody)
            n = r.u2()
            out.append("      %d bootstrap method(s)" % n)
            for b in range(n):
                mr = r.u2()
                na2 = r.u2()
                args = [r.u2() for _ in range(na2)]
                out.append("      [%d] method_ref #%d  args: %s"
                           % (b, mr, ", ".join(
                               "#%d=%s" % (a, cp_line(entries, entries[a]))
                               if a in entries else "#%d" % a for a in args)))

    out.append("  consumed %d of %d bytes" % (r.pos(), len(data)))
    if r.pos() != len(data):
        out.append("  *** %d trailing bytes ***" % (len(data) - r.pos()))

    if show_hex:
        out.append("  hex:")
        for o in range(0, min(len(data), 512), 16):
            row = data[o:o + 16]
            hexs = " ".join("%02x" % c for c in row)
            txt = "".join(chr(c) if 32 <= c < 127 else "." for c in row)
            out.append("    %04x  %-47s  %s" % (o, hexs, txt))
    return "\n".join(out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if not args:
        print(__doc__)
        return 2
    for p in args:
        try:
            print(dump(p, "--cp-only" in flags, "--hex" in flags))
        except Bad as e:
            print("%s: BAD: %s" % (p, e), file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
