#!/usr/bin/env python3
"""An independent WebAssembly binary decoder.

Written from the binary format specification, not from wabt's source, so that
agreeing with `wasm-objdump` is evidence rather than tautology.

Deliberately not a validator. It decodes and reports what is there; it does not
check that the module is legal. Where the two jobs come apart -- a custom
section's contents, for instance -- that is a teaching point, not an oversight.

Usage:
    wasm_decode.py FILE            decode a module and print its structure
    wasm_decode.py --hex FILE      also dump every section as a hex table
    wasm_decode.py --raw FILE      dump the whole file as a hex table

Run with no arguments to decode every sample in this directory.
"""

import os
import sys

# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------

# The one thing every other decoder gets wrong if it hardcodes it.
MAGIC = b"\x00asm"
VERSION = 1

# section id -> (name, ordered?)  `ordered` is False only for custom sections.
SECTIONS = {
    0:  ("custom",     False),
    1:  ("type",       True),
    2:  ("import",     True),
    3:  ("function",   True),
    4:  ("table",      True),
    5:  ("memory",     True),
    6:  ("global",     True),
    7:  ("export",     True),
    8:  ("start",      True),
    9:  ("element",    True),
    10: ("code",       True),
    11: ("data",       True),
    12: ("datacount",  True),
    13: ("tag",        True),
}

# value types
VALTYPES = {
    0x7f: "i32", 0x7e: "i64", 0x7d: "f32", 0x7c: "f64",
    0x7b: "v128", 0x70: "funcref", 0x6f: "externref",
    # reference types with a type index follow, so they cannot be a single byte
}

# external kinds, shared by the import and export sections
EXTERNS = {0: "func", 1: "table", 2: "memory", 3: "global", 4: "tag"}


class Bad(Exception):
    """The bytes did not decode. Always carries the offset it failed at."""


def uleb(b, p):
    """Unsigned LEB128. Returns (value, new_offset, bytes_consumed)."""
    result = 0
    shift = 0
    start = p
    while True:
        if p >= len(b):
            raise Bad("uleb128 runs past the end at 0x%x" % p)
        byte = b[p]
        p += 1
        result |= (byte & 0x7F) << shift
        if not (byte & 0x80):
            return result, p, p - start
        shift += 7
        if shift > 63:
            raise Bad("uleb128 longer than 10 bytes at 0x%x" % start)


def sleb(b, p):
    """Signed LEB128. Returns (value, new_offset, bytes_consumed).

    The sign handling is the whole point of having a separate function: a
    single-byte 0x7F is -1 here and 127 if you reuse uleb128.
    """
    result = 0
    shift = 0
    start = p
    while True:
        if p >= len(b):
            raise Bad("sleb128 runs past the end at 0x%x" % p)
        byte = b[p]
        p += 1
        result |= (byte & 0x7F) << shift
        shift += 7
        if not (byte & 0x80):
            if byte & 0x40:                 # sign-extend from the last byte
                result -= (1 << shift)
            return result, p, p - start


def name(b, p):
    """A length-prefixed UTF-8 name, as used throughout the format."""
    n, p, _ = uleb(b, p)
    if p + n > len(b):
        raise Bad("name of %d bytes runs past the end at 0x%x" % (n, p))
    s = b[p:p + n]
    p += n
    return s.decode("utf-8", "replace"), p


def limits(b, p):
    """A limits record: a flag byte, then min, then max if the flag says so."""
    flag = b[p]
    p += 1
    has_max = bool(flag & 0x01)
    is_shared = bool(flag & 0x02)
    is_64 = bool(flag & 0x04)
    lo, p, _ = uleb(b, p)
    hi = None
    if has_max:
        hi, p, _ = uleb(b, p)
    kind = "memory64" if is_64 else "memory32"
    text = "min=%d" % lo
    if hi is not None:
        text += " max=%d" % hi
    if is_shared:
        text += " shared"
    return "%s%s" % (kind + " " if kind != "memory32" else "", text), p


# ---------------------------------------------------------------------------
# section decoders.  each takes (bytes, start, end) and returns a list of lines
# ---------------------------------------------------------------------------

def init_expr(b, p, end):
    """A constant expression: a short opcode sequence ending in 0x0b (end).

    Returned as a readable string plus the offset just past the 0x0b.

    This has to *walk* the opcodes rather than guess a length, because
    `i32.const` carries a variable-width signed operand and `global.get` a
    variable-width index. A decoder that assumes a fixed size will be right
    on the one-byte cases and wrong on the rest, which is the worst
    possible failure shape.
    """
    parts = []
    while p < end:
        op = b[p]
        p += 1
        if op == 0x0B:                       # end
            parts.append("end")
            return " ".join(parts), p
        elif op == 0x41:                     # i32.const <sleb32>
            v, p, _ = sleb(b, p)
            parts.append("i32.const %d" % v)
        elif op == 0x42:                     # i64.const <sleb64>
            v, p, _ = sleb(b, p)
            parts.append("i64.const %d" % v)
        elif op == 0x43:                     # f32.const <4 bytes LE>
            v = int.from_bytes(b[p:p + 4], "little"); p += 4
            parts.append("f32.const %g" % v)
        elif op == 0x44:                     # f64.const <8 bytes LE>
            v = int.from_bytes(b[p:p + 8], "little"); p += 8
            parts.append("f64.const %g" % v)
        elif op == 0x23:                     # global.get <uleb>
            v, p, _ = uleb(b, p)
            parts.append("global.get %d" % v)
        elif op == 0xD0:                     # ref.null <heaptype>
            t = b[p]; p += 1
            parts.append("ref.null 0x%02x" % t)
        elif op == 0xD2:                     # ref.func <uleb>
            v, p, _ = uleb(b, p)
            parts.append("ref.func %d" % v)
        else:
            parts.append("opcode 0x%02x (unhandled)" % op)
            return " ".join(parts), end
    raise Bad("constant expression has no 0x0b terminator")


def dec_type(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d type definition(s)" % n)
    for i in range(n):
        # Record the offset BEFORE consuming the form byte. The count byte
        # sits between the payload start and the first entry, so recording
        # after the form byte would report every entry one byte late --
        # correct values, wrong positions, which a hand count of the hex
        # dump catches and nothing else does.
        off = p
        form = b[p]
        p += 1
        if form != 0x60:
            out.append("  [%d] @0x%x  form 0x%02x is not 0x60 (func)" % (i, off, form))
            break
        np_, p, _ = uleb(b, p)
        params = []
        for _ in range(np_):
            t = b[p]
            p += 1
            params.append(VALTYPES.get(t, "0x%02x" % t))
        nr, p, _ = uleb(b, p)
        results = []
        for _ in range(nr):
            t = b[p]
            p += 1
            results.append(VALTYPES.get(t, "0x%02x" % t))
        out.append("  [%d] @0x%x  (func (param %s) (result %s))"
                   % (i, off, " ".join(params) or "-", " ".join(results) or "-"))
    return out


def dec_import(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d import(s)" % n)
    for i in range(n):
        mod, p = name(b, p)
        fld, p = name(b, p)
        kind_byte = b[p]
        p += 1
        kind = EXTERNS.get(kind_byte, "?")
        # The body after the kind byte is DIFFERENT for each kind. Reading it
        # as a type index for everything is the classic mistake here, and it
        # does not error -- it reads the limits flag byte as an index.
        if kind_byte == 0x00:                       # func: a type index
            idx, p, _ = uleb(b, p)
            out.append("  [%d] %s.%s  func  type[%d]" % (i, mod, fld, idx))
        elif kind_byte == 0x01:                     # table: elemtype + limits
            et = b[p]; p += 1
            text, p = limits(b, p)
            out.append("  [%d] %s.%s  table elem=0x%02x(%s) %s"
                       % (i, mod, fld, et, VALTYPES.get(et, "?"), text))
        elif kind_byte == 0x02:                     # memory: limits
            text, p = limits(b, p)
            out.append("  [%d] %s.%s  memory %s" % (i, mod, fld, text))
        elif kind_byte == 0x03:                     # global: valtype + mut
            t = b[p]; p += 1
            mut = b[p]; p += 1
            out.append("  [%d] %s.%s  global %s %s"
                       % (i, mod, fld, VALTYPES.get(t, "0x%02x" % t),
                          "mutable" if mut else "const"))
        else:                                       # tag: attribute + typeidx
            attr = b[p]; p += 1
            idx, p, _ = uleb(b, p)
            out.append("  [%d] %s.%s  tag attr=0x%02x type[%d]" % (i, mod, fld, attr, idx))
    return out


def dec_function(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d function(s); each is an index into the type section" % n)
    for i in range(n):
        idx, p, w = uleb(b, p)
        out.append("  [%d] type[%d]%s" % (i, idx, "  (2-byte LEB)" if w > 1 else ""))
    return out


def dec_table(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d table(s)" % n)
    for i in range(n):
        et = b[p]
        p += 1
        text, p = limits(b, p)
        out.append("  [%d] elem=0x%02x(%s)  %s"
                   % (i, et, VALTYPES.get(et, "?"), text))
    return out


def dec_memory(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d memory/memories" % n)
    for i in range(n):
        text, p = limits(b, p)
        out.append("  [%d] %s" % (i, text))
    return out


def dec_global(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d global(s)" % n)
    for i in range(n):
        t = b[p]
        p += 1
        mut = b[p]
        p += 1
        out.append("  [%d] type=%s  mutability=%s"
                   % (i, VALTYPES.get(t, "0x%02x" % t),
                      "var" if mut else "const"))
        text, p = init_expr(b, p, end)
        out.append("       init: %s" % text)
    return out


def dec_export(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d export(s)" % n)
    for i in range(n):
        nm, p = name(b, p)
        kind = EXTERNS.get(b[p], "?")
        p += 1
        idx, p, _ = uleb(b, p)
        out.append("  [%d] %-10s kind=%-6s index=%d" % (i, nm, kind, idx))
    return out


def dec_start(b, p, end):
    idx, p, _ = uleb(b, p)
    return ["function index %d runs before any exported code" % idx]


def dec_code(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d function body/bodies" % n)
    for i in range(n):
        size, q, w = uleb(b, p)
        body_end = q + size
        out.append("  [%d] body size=%d%s, spans 0x%x-0x%x"
                   % (i, size, " (2-byte LEB)" if w > 1 else "", q, body_end))
        r = q
        groups, r, _ = uleb(b, r)
        out.append("       %d local declaration group(s)" % groups)
        total = 0
        for _ in range(groups):
            count, r, _ = uleb(b, r)
            t = b[r]
            r += 1
            total += count
            out.append("         %d x %s" % (count, VALTYPES.get(t, "0x%02x" % t)))
        out.append("       %d local(s) total; instructions: %s"
                   % (total, " ".join("%02x" % c for c in b[r:body_end])))
        p = body_end
    return out


def dec_data(b, p, end):
    out = []
    n, p, _ = uleb(b, p)
    out.append("%d data segment(s)" % n)
    for i in range(n):
        mode, p, _ = uleb(b, p)
        out.append("  [%d] mode=%d %s" % (i, mode,
                   {0: "(active, memory 0, offset expr)",
                    1: "(passive, later dropped or copied)",
                    2: "(active, explicit memory index)"}.get(mode, "?")))
        if mode == 2:
            mi, p, _ = uleb(b, p)
            out.append("       memory index %d" % mi)
        if mode in (0, 2):
            text, p = init_expr(b, p, end)
            out.append("       offset: %s" % text)
        ln, p, _ = uleb(b, p)
        out.append("       %d byte(s): %r" % (ln, b[p:p + ln]))
        p += ln
    return out


def dec_datacount(b, p, end):
    n, p, _ = uleb(b, p)
    return ["%d data segment(s) are declared here" % n]


def dec_custom(b, p, end):
    nm, p = name(b, p)
    out = ['name = "%s"' % nm]
    out.append("contents are NOT specified, so nothing here can be checked "
               "against the format")
    out.append("%d byte(s) after the name" % (end - p))
    return out


DECODERS = {
    0: dec_custom, 1: dec_type, 2: dec_import, 3: dec_function,
    4: dec_table, 5: dec_memory, 6: dec_global, 7: dec_export,
    8: dec_start, 9: None, 10: dec_code, 11: dec_data, 12: dec_datacount,
}


# ---------------------------------------------------------------------------
# the container
# ---------------------------------------------------------------------------

def hexdump(b, base=0, limit=None):
    data = b if limit is None else b[:limit]
    lines = []
    for off in range(0, len(data), 16):
        row = data[off:off + 16]
        hexpart = " ".join("%02x" % c for c in row)
        text = "".join(chr(c) if 32 <= c < 127 else "." for c in row)
        lines.append("  %04x: %-47s  %s" % (base + off, hexpart, text))
    return lines


def decode(path, show_hex=False, show_raw=False):
    b = open(path, "rb").read()
    out = []
    out.append("=" * 72)
    out.append("%s  (%d bytes)" % (os.path.basename(path), len(b)))
    out.append("=" * 72)

    if show_raw:
        out.append("raw file:")
        out += hexdump(b)
        out.append("")

    if b[:4] != MAGIC:
        out.append("NOT A WASM MODULE: magic is %r, expected %r" % (b[:4], MAGIC))
        return out
    version = int.from_bytes(b[4:8], "little")
    out.append("header")
    out.append("  magic    %s   (offset 0..3, four fixed bytes)" % " ".join(
        "%02x" % c for c in b[:4]))
    out.append("  version  %d          (offset 4..7, FOUR FIXED BYTES, little-endian)"
               % version)
    out.append("            -- note: this is NOT a LEB128. A 4-byte little-endian")
    out.append("               field is one of only two fixed-width integers in the")
    out.append("               format's framing; every other count is LEB128.")
    out.append("")

    out.append("sections")
    p = 8
    prev_id = 0
    seen_custom = False
    order_ok = True
    while p < len(b):
        off = p
        sid = b[p]
        p += 1
        try:
            size, q, w = uleb(b, p)
        except Bad as e:
            out.append("  @0x%x  UNDECODABLE: %s" % (off, e))
            break
        sname, ordered = SECTIONS.get(sid, ("id-%d" % sid, True))
        payload = q
        out.append("  @0x%-5x id=%-3d %-11s size=%-6d payload 0x%04x-0x%04x"
                   % (off, sid, sname, size, payload, payload + size))
        out.append("            id and size together occupy %d byte(s)%s"
                   % (1 + w, "  <- 2-byte LEB128 size" if w > 1 else ""))
        if ordered:
            if sid < prev_id:
                order_ok = False
                out.append("            OUT OF ORDER: id %d follows id %d" % (sid, prev_id))
            prev_id = sid
        else:
            seen_custom = True
        fn = DECODERS.get(sid)
        if fn is not None:
            try:
                for line in fn(b, payload, payload + size):
                    out.append("            " + line)
            except Bad as e:
                out.append("            payload decode failed: %s" % e)
            except IndexError:
                out.append("            payload decode ran off the end")
        else:
            out.append("            (decoder not written for this section yet)")
        if show_hex:
            out += hexdump(b[payload:payload + size], payload)
        p = payload + size

    out.append("")
    out.append("ordering")
    out.append("  non-custom sections %s"
               % ("are in increasing id order" if order_ok
                  else "are NOT in increasing id order -- this would fail validation"))
    out.append("  custom sections %sseen" % ("were " if seen_custom else "were not "))
    return out


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("-")]
    flags = {a for a in argv[1:] if a.startswith("-")}
    if not args:
        here = os.path.dirname(os.path.abspath(__file__))
        args = sorted(
            os.path.join(here, f) for f in os.listdir(here)
            if f.endswith(".wasm") or f.endswith(".o"))
    for path in args:
        if not os.path.exists(path):
            print("no such file: %s" % path)
            continue
        try:
            for line in decode(path, "--hex" in flags, "--raw" in flags):
                print(line)
            print()
        except Bad as e:
            print("%s: %s" % (path, e))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
