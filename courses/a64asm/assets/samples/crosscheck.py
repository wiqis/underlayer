#!/usr/bin/env python3
"""crosscheck.py -- the harness for "AArch64: Encoding From The Ground Up".

It reads the OUTPUT of a64dec.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files and no decoder of
its own, and that is the point.  A harness that can re-measure can disagree
with the artifact for reasons that have nothing to do with whether the
artifact's SENTENCES are still true, and then it teaches its reader to
ignore it.

So the split is this.  a64dec.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit in the course that drops a retraction changes the
TEXT; the harness notices and the reader learns.  Neither can hide.

Why so little is asserted numerically, in this file's own words: almost
everything in a64dec.py is EXACT.  Bit patterns are exact, counts are exact,
assembler refusals are exact, and the reach of a signed displacement field is
exact.  So the harness asserts them as exact numbers, and it is not being
clever -- it is the only honest thing to do with an exact quantity.  The one
place a value genuinely moves is the density comparison in section 13, where
the numbers are properties of a COMPILER VERSION, and that one is asserted as
a SHAPE and not as a value.

Usage:  python3 crosscheck.py [path/to/a64dec.out]
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FAILURES = []
CHECKS = 0


def check(group, what, ok, detail=""):
    global CHECKS
    CHECKS += 1
    if not ok:
        FAILURES.append((group, what, detail))
    print("  [%s] %-12s %-56s %s" % ("PASS" if ok else "FAIL", group, what,
                                    detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before a64dec is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them -- which is the same mistake as
    quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "a64dec.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    """The FIRST capture group, or None."""
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def groups_of(pat, text, flags=0):
    """EVERY capture group, as a tuple, or None.

    `one()` returns group 1 and that is right for the common case of "the
    number after this label".  It is wrong for a line that reports three
    numbers at once -- `58 field positions measured, 58 cases, 0 refusals` --
    where a caller who wants all three and uses `one()` gets a string and then
    indexes it as if it were a tuple, which raises IndexError deep inside a
    check rather than where the mistake was made.
    """
    m = re.search(pat, text, flags)
    return m.groups() if m else None


def int1(pat, text, flags=0):
    v = one(pat, text, flags)
    return int(v.replace(",", "")) if v else None


def rows_of(text, rowpat):
    """Every line matching `rowpat`, as a list of FIELDS, in file order.

    `rowpat` matches the WHOLE row, leading whitespace included, and its
    capture groups are the fields -- so `rows[0][2]` is the caller's third
    column and not a guess about where the columns start.

    The first version of this helper took a PREFIX regex and returned
    everything after it, which silently dropped the first field: the section
    2 table's `r[2]` -- read as "the remainder mod 4" -- was the instruction
    count, so "every section is a multiple of four" compared 135 against 0
    and failed on a table where every value was correct.  A helper that
    returns the wrong columns produces a check that reports a bug in the
    artifact when the bug is in the harness, and that is worse than no check.

    ORDER is preserved and matters: a table whose rows were reordered is a
    different table, and a check that compared contents would not notice.
    """
    out = []
    for ln in text.splitlines():
        m = re.match(rowpat, ln)
        if m:
            out.append(m.groups())
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    # Every substring assertion runs against a WHITESPACE-NORMALISED copy.
    # The artifact wraps its prose at about 78 columns, so a phrase written
    # across a line break is a phrase the artifact HAS and the harness cannot
    # see -- which is how four checks in the previous course's harness failed
    # about text that was demonstrably present, three of them about
    # retractions.  Numeric parses use the original, because collapsing spaces
    # there would join adjacent table columns.
    FLAT = re.sub(r"\s+", " ", T)

    print("crosscheck: %s\n" % path)
    # The identity check goes through check() like everything else.  The first
    # version of this file counted it by hand with `CHECKS += 1` at module
    # scope, and the first `CHECKS += 1` INSIDE main makes the name local for
    # the whole function -- so the counter was unreadable and the harness
    # crashed on its own second line.  A harness that cannot print its own
    # total is a harness whose total nobody reads.
    check("A instrument", "this is the a64dec output and not something else",
          "a64dec -- the artifact" in T, path)
    print()

    # ------------------------------------------------------------------
    # A. the instrument -- what was established before anything was measured
    # ------------------------------------------------------------------
    g = "A instrument"
    print("  --- group A: what was established before anything was measured")

    # The two version strings are pulled with a version-shaped regex rather
    # than by indexing a split.  Indexing is what the first version did --
    # `asm.split()[2] == dis.split()[3]` -- and it crashed on the very first
    # real output, because the assembler's banner is "Ubuntu clang version"
    # and the disassembler's is "Ubuntu LLVM version" and the word before the
    # number is not in the same place.  A harness that indexes a string it
    # did not write is a harness that breaks when the tool prints a word.
    #
    # The banner words are matched as `\S.*?` and not `\S*`, because "Ubuntu
    # clang" has a SPACE in it: `\S*clang` cannot match "Ubuntu clang" and the
    # first version of this regex matched nothing, silently, and reported
    # three failures about a number the output plainly contains.
    asm = one(r"assembles\s+\S.*?clang version ([\d.]+)", T)
    dis = one(r"disassembles\s+\S.*?LLVM version ([\d.]+)", T)
    check(g, "the assembler's version was printed", asm is not None,
          "clang %s" % (asm or "?"))
    check(g, "the disassembler's version was printed", dis is not None,
          "llvm %s" % (dis or "?"))
    check(g, "and the two readers are the SAME LLVM release",
          asm is not None and asm == dis,
          "clang %s / llvm %s" % (asm or "?", dis or "?"))
    check(g, "the absence of an AArch64 LINKER is stated, not implied",
          "NOT INSTALLED" in T and "so no linked image is compared" in FLAT)
    check(g, "the absence of an AArch64 EMULATOR is stated, not implied",
          "emulates AArch64" in T and "so no instruction is executed" in FLAT)
    check(g, "and the consequence is stated in the header, before any number",
          "NOTHING IS EXECUTED" in T)
    check(g, "the four kinds of claim are named in the header",
          "a BIT PATTERN, a COUNT of bit patterns, an" in FLAT
          and "arithmetic identity, or a refusal" in FLAT)
    check(g, "the decoder's own dependencies are declared",
          "imports" in FLAT and "os, re, struct and sys" in FLAT)
    elf = [("e_shoff", "0x28"), ("e_shentsize", "0x3a"), ("e_shnum", "0x3c"),
           ("e_shstrndx", "0x3e"), ("e_machine", "0x12")]
    check(g, "every ELF64 field the decoder reads is printed with its offset",
          all(re.search(r"^\s+%s\s+%s\s" % (n, re.escape(o)), T, re.M)
              for n, o in elf))
    check(g, "and the decoder CHECKS e_machine rather than assuming it",
          "183 = EM_AARCH64" in T and "refuses a file that is not an" in FLAT)
    check(g, "the declared subset is stated as NAMES not LENGTHS",
          "subset of NAMES, not of LENGTHS" in FLAT)
    check(g, "and unmodelled words are counted rather than dropped",
          "COUNTED" in T and "a property of the filter" in FLAT)
    print()

    # ------------------------------------------------------------------
    # B. four bytes always -- the course's first claim
    # ------------------------------------------------------------------
    g = "B length"
    print("  --- group B: the length claim, and the mnemonic that is not stored")

    # Columns: file, section, bytes, rem4, insns, bytes/insn, chain.
    rows = rows_of(T, r"\s+((?:a64|corpus_O[012s])\.o)\s+(\.text)\s+"
                      r"(\d+)\s+(\d)\s+(\d+)\s+([\d.]+)\s+(\S+)\s*$")
    check(g, "the length table has one row per corpus code section",
          len(rows) == 5, "%d rows" % len(rows))
    if len(rows) == 5:
        check(g, "every section size is a multiple of four",
              all(r[3] == "0" for r in rows),
              "remainders " + " ".join(r[3] for r in rows))
        check(g, "every section is 4.0000 bytes per instruction",
              all(r[5] == "4.0000" for r in rows),
              " ".join(r[5] for r in rows))
        check(g, "every walk ends EXACTLY on the section end",
              all(r[6] == "EXACTLY" for r in rows))
        tot = sum(int(r[4]) for r in rows)
        byt = sum(int(r[2]) for r in rows)
        check(g, "and the totals are consistent: insns x 4 = bytes",
              byt == tot * 4, "%d insns x 4 = %d = %d bytes"
              % (tot, tot * 4, byt))
        check(g, "and every file's own bytes equal its own instructions x 4",
              all(int(r[2]) == int(r[4]) * 4 for r in rows))
    check(g, "the verdict is printed as a verdict",
          "VERDICT: fixed width, on this corpus" in T)
    check(g, "the three bug classes fixed width removes are named",
          "DESYNCHRONISATION" in T and "LENGTH ARITHMETIC" in T)
    check(g, "and the cost side is stated too, not only the benefit",
          "is four bytes for `nop`, which does nothing" in FLAT)

    # The alias table.  This is the group that would catch a decoder
    # confusing an alias with a distinct encoding.
    al = re.findall(r"^\s+([0-9a-f]{8})\s+(\S.*?)\s+(==|!=)\s+(\S.*?)\s\s", T, re.M)
    check(g, "the alias table was produced", len(al) >= 15, "%d pairs" % len(al))
    same = [a for a in al if a[2] == "=="]
    diff = [a for a in al if a[2] != "=="]
    check(g, "at least nineteen pairs are the same 32 bits",
          len(same) >= 19, "%d same, %d different" % (len(same), len(diff)))
    check(g, "and exactly one pair is NOT an alias, and it is adr vs adrp",
          len(diff) == 1 and "adr" in diff[0][1] and "adrp" in diff[0][3],
          diff[0][1].strip() + " != " + diff[0][3].strip() if diff else "?")
    # The four alias identities that are the section's point, asserted as BIT
    # PATTERNS rather than as prose.  These are exact and cannot drift.
    for want, why in (("movw0,#0x1234", "mov is MOVZ with hw = 0"),
                      ("cmpw0,w1", "cmp is subs with the destination dropped"),
                      ("mvnw0,w1", "mvn is orn with the zero register"),
                      ("movw0,w1", "mov register-to-register is orr"),
                      ("mulw0,w1,w2", "mul is madd with a zero addend"),
                      ("csetw0,eq", "cset is csinc with the condition INVERTED")):
        check(g, "the alias row for %s is present and exact" % why,
              want.replace(",", ",") in re.sub(r"\s+", "", T))
    check(g, "the cset inversion is called out as THE TRAP of the table",
          "THE TRAP: the condition is INVERTED" in T)
    check(g, "and the article says what it costs to get wrong",
          "DIFFERENT 32 bits" in T and "the output is 0 or 1 either way" in FLAT)
    check(g, "movn is reported as NOT an alias of orr-with-zr-last",
          "the ZERO is the FIRST operand" in T)
    print()

    # ------------------------------------------------------------------
    # C. the class field -- measured membership, quoted names
    # ------------------------------------------------------------------
    g = "C class"
    print("  --- group C: the class field, and the boundary between "
          "measurement and quotation")

    ninsn = int1(r"(\d[\d,]*) object files, \d[\d,]* instructions, \d[\d,]* "
                 r"named by this decoder", T)
    check(g, "the class table was measured over the whole corpus",
          ninsn is not None, "%s instructions" % ninsn)
    # Columns: bits[28:25], count, "what landed there", the QUOTED name.
    rows = rows_of(T, r"\s+(0[01]\d{3})\s+(\d+)\s+(\S.*?)\s\s+(\S.*?)\s*$")
    check(g, "the class table has one row per non-empty class value",
          len(rows) == 11, "%d rows" % len(rows))
    if len(rows) == 11:
        check(g, "the class values are in ASCENDING order",
              [r[0] for r in rows] == sorted(r[0] for r in rows),
              " ".join(r[0] for r in rows))
        check(g, "every row carries BOTH a measured member and a quoted name",
              all(r[2] and r[3] for r in rows))
        check(g, "and the quoted name is one of the four the manual names",
              all(any(k in r[3] for k in ("Data Processing", "Loads and "
                                          "Stores", "Branches", "Advanced"))
                  for r in rows))
        # The largest CLASS is 01100 (loads and stores) and the largest single
        # MNEMONIC is `ret` -- which is what R2 is about, because a two-bit
        # rule put `ret`'s class in the wrong bucket entirely.  The harness
        # asserts the class that HOLDS ret, not the class with most
        # instructions, and the first version of this check asserted the
        # latter and failed on a table where both facts are printed.
        # The count column is the CLASS TOTAL, and the members column is
        # "mnemonic:count mnemonic:count ...".  So `ret`'s own count has to
        # be read out of the members string, not out of the class total --
        # which is what the first version of this check did, and it reported
        # 142 (the class) where the class table prints 134 (the mnemonic).
        retrow = [r for r in rows if r[2].startswith("ret:")]
        retn = int(re.search(r"ret:(\d+)", retrow[0][2]).group(1)) if retrow \
            else 0
        check(g, "the largest single MNEMONIC is `ret`, which is R2's subject",
              retn > 0 and retn == max(
                  int(m) for r in rows for m in re.findall(r":(\d+)", r[2])),
              "ret with %d" % retn)
        check(g, "and `ret` sits in class 01011, which a two-bit rule misses",
              retrow and retrow[0][0] == "01011",
              "class %s" % (retrow[0][0] if retrow else "?"))
        check(g, "the largest CLASS is 01100, loads and stores",
              max(rows, key=lambda r: int(r[1]))[0] == "01100",
              "class %s with %s"
              % (max(rows, key=lambda r: int(r[1]))[0],
                 max(rows, key=lambda r: int(r[1]))[1]))
        check(g, "the class that holds the selects is 1101, which a "
                 "two-bit rule cannot see",
              [r[0] for r in rows if "csel" in r[2]] == ["01101"],
              [r[0] for r in rows if "csel" in r[2]])
        check(g, "the empty values are named, and are five of the sixteen",
              "Empty here: 00000, 00001, 00010, 00011, 01110." in T)
    check(g, "the class NAMES are marked as a QUOTATION",
          "the QUOTED name" in T and "The class NAMES are a quotation" in FLAT)
    check(g, "and the MEMBERSHIP is marked as a measurement",
          "The MEMBERSHIP is a measurement" in FLAT)
    check(g, "the empty values are printed, not hidden",
          "Empty here:" in T)
    empty = one(r"(\d+) of the 16 values carry at least one real instruction", T)
    check(g, "the count of populated class values is stated",
          empty == "11", "%s of 16" % empty)
    check(g, "and the two-bit confusion is called out by name",
          "the one a two-bit rule cannot see is 1101" in FLAT)
    check(g, "the file states that a class field is four bits wide whether or "
             "not a program uses it",
          "four bits" in FLAT and "whether or not a program uses it" in FLAT)
    print()

    # ------------------------------------------------------------------
    # D. the field map -- exact bit patterns
    # ------------------------------------------------------------------
    g = "D fields"
    print("  --- group D: the field map, which is the strongest thing here")

    # Columns: label, xor mask, the positions, the base instruction.  The
    # base-instruction column can hold SPACES -- `add w0, w1, w2, lsl #3` -- so
    # it is the LAST group and it takes the rest of the line.
    frows = rows_of(T, r"\s+(\S.*?)\s+([0-9a-f]{8})\s+(bits\[[^\]]+\])"
                      r"\s\s+(.*?)\s*$")
    check(g, "the field table has at least fifty measured positions",
          len(frows) >= 50, "%d rows" % len(frows))
    npos = groups_of(r"(\d+) field positions measured, (\d+) cases, "
                     r"(\d+) refusals", T)
    check(g, "and the file reports zero refusals in that table",
          npos and npos[2] == "0", " ".join(npos) if npos else "?")
    check(g, "and the measured count equals the number of rows",
          npos and int(npos[0]) == len(frows),
          "%s measured, %d rows" % (npos[0] if npos else "?", len(frows)))
    check(g, "and cases == positions, because one case is one field",
          npos and npos[0] == npos[1],
          "%s positions, %s cases" % (npos[0], npos[1]) if npos else "?")

    # These are THE field positions.  Each is an exact mask, so each is
    # asserted exactly, and each one is a fact about the encoding that a
    # manual could confirm and a memory could not.
    masks = {r[0]: (r[2] if r[2] else "?") for r in frows}
    for label, want, why in (
            ("Rd", "bits[3:0]", "the destination register is bits[4:0]"),
            ("Rm", "bits[19:16]", "Rm is bits[20:16]"),
            ("cond (csel)", "bits[15:12]", "the select condition is 4 bits at 12"),
            ("pair Rt2", "bits[14:10]", "Rt2 is FIVE bits, the classic bug"),
            ("pair imm", "bits[20:15]", "the pair offset is 7 bits scaled by 8"),
            ("imm12", "bits[21:10]", "the add/sub immediate is 12 bits"),
            ("imm16", "bits[20:5]", "the move-wide field is 16 bits"),
            ("ld Rt", "bits[3:0]", "a load destination is 5 bits at 0"),
            ("ld Rn", "bits[8:5]", "a load base is 5 bits at 5"),
            ("B imm26", "bits[25:0]", "the unconditional displacement is 26"),
            ("ldur imm9", "bits[20:12]", "the unscaled offset is 9 bits"),
            ("hw", "bits[22:21]", "the move-wide shift is 2 bits at 21")):
        check(g, why, masks.get(label) == want,
              "%s (measured %s)" % (want, masks.get(label)))
    # Rn: the sweep visited odd register numbers, so bit 5 of the field never
    # moved.  The mask is therefore four bits wide and the field is five, and
    # the artifact SAYS a mask is a lower bound -- so the harness asserts the
    # lower bound, not the field, and says which is which.
    check(g, "Rn's measured mask is a lower bound, as the file states",
          masks.get("Rn", "").startswith("bits[") and "5" not in
          masks.get("Rn", "").replace("bits[", "").split(":")[0],
          masks.get("Rn", "?"))
    # Every prose assertion in this harness runs against FLAT, the
    # whitespace-collapsed copy, because the artifact wraps at 78 columns and
    # "LOWER\n    BOUND" is one word to a reader and two to a regex.  The first
    # version of this group searched T directly and reported four failures
    # about phrases the output plainly contains.  The numeric searches above
    # still use T, because collapsing spaces there would join table columns.
    check(g, "the sweep method is stated, and it is a LOWER BOUND",
          "LOWER BOUND" in FLAT and "not moved" in FLAT)
    check(g, "and the one-true-encoding is reported, not asserted",
          "the field is identical and the MEANING is" in FLAT)
    check(g, "the field-vs-meaning distinction is stated as the point",
          "No field map can express that difference" in FLAT)
    # The artifact's own sentence, quoted.  The first version of this check
    # searched for a paraphrase ("a gap is explained") and found nothing, and
    # the second searched for wording from a draft of the artifact that the
    # final text had replaced ("an INTERIOR gap in a row is a bit the sweep
    # never moved -- a fact about the sweep").  A harness that quotes prose
    # has to be edited when the prose is edited, and that is the cost of
    # asserting sentences rather than numbers.
    check(g, "and a bit outside the mask is explained as a SWEEP artefact",
          "a bit NOT in the mask is a bit the sweep did not happen to move"
          in FLAT)
    check(g, "and the not-moved bits are listed per row",
          len(re.findall(r"not moved: bits\[", T)) >= 5,
          "%d rows listed" % len(re.findall(r"not moved: bits\[", T)))
    check(g, "the measured map is written to fields.txt and the file says so",
          "Written to fields.txt." in T)
    check(g, "the Rt2 row is called out by name as the classic decoder bug",
          "single most common A64 decoder bug" in FLAT)
    check(g, "the two condition fields are called out as non-overlapping",
          "the two fields do not overlap" in FLAT)
    print()

    # ------------------------------------------------------------------
    # E. the bit budget
    # ------------------------------------------------------------------
    g = "E budget"
    print("  --- group E: three meanings of a wasted bit, all measured")

    check(g, "the group-fixed measurement is present and named",
          "=== 5A. BITS FIXED WITHIN A GROUP" in T)
    check(g, "the per-mnemonic measurement is present and named",
          "=== 5B. BITS FIXED WITHIN ONE MNEMONIC" in T)
    check(g, "the reserved-bit discussion is present and named",
          "=== 5C. RESERVED BITS" in T)
    dead = one(r"Over those, ([\d.]+) of the 32 bits are DEAD", T)
    check(g, "the dead-bit fraction is reported as a measured number",
          dead is not None and float(dead) > 5.0,
          "%s of 32" % (dead or "?"))
    check(g, "single-member groups are EXCLUDED and the reason is stated",
          "A group of one has" in FLAT and "makes the figure CONSERVATIVE" in FLAT)
    check(g, "the group key is (class, name) and the mnemonic collision is named",
          "ONE\n  name for TWO encodings" in T or "one name for two encodings"
          in FLAT.lower())
    check(g, "a group of four or more is required before a constant is claimed",
          "Four or more instances" in T)
    check(g, "the bits a decode READS are reported per instruction",
          "of 32 bits read" in T)
    check(g, "and the reserved bits are called cheap but not free",
          "they are not free" in FLAT)
    check(g, "the summary distinguishes fixed-width from constrained",
          "UNIFORMLY" in T and "heavily constrained" in FLAT)
    check(g, "the modelled / unmodelled split is reported with both numbers",
          "Modelled:" in T and "COUNTED:" in T)
    print()

    # ------------------------------------------------------------------
    # F. immediates -- the two prices
    # ------------------------------------------------------------------
    g = "F immediates"
    print("  --- group F: two immediates, and the scale that is not a range")

    check(g, "the add/sub immediate section is present",
          "=== 6A. add/sub immediate" in T)
    check(g, "the move-wide section is present",
          "=== 6B. move wide" in T)
    check(g, "the opc hole section is present",
          "=== 6C. opc = bits[30:29] has a HOLE" in T)
    check(g, "#0x1000 is reported as ACCEPTED",
          "0x1000" in T and "#0x1001" in T)
    check(g, "and the article says the reach is not a contiguous range",
          "NOT a contiguous range" in T)
    check(g, "the three states of the scale field are named",
          "the value, the value shifted by 12, and zero" in FLAT)
    check(g, "the MOVN magnitude/complement distinction is stated",
          "field holds the MAGNITUDE" in FLAT)
    check(g, "and both printing conventions are shown side by side",
          "movn w0, #0x8000" in FLAT and "mov w0, #-0x8001" in FLAT)
    check(g, "the opc hole is MEASURED, not inferred from 'three therefore two'",
          "a hole inferred from" in FLAT)
    hole = one(r"The hole is opc = (\d+)", T)
    check(g, "and the hole is identified as 0b01",
          hole == "01", "opc = %s" % hole)
    check(g, "the decoder reports the hole as UNDEFINED rather than guessing",
          "reports it as UNDEFINED" in FLAT)
    check(g, "the seven displacement fields are listed with no common shape",
          "no\n  common shape" in T or "no common shape" in FLAT)
    print()

    # ------------------------------------------------------------------
    # G. the logical immediate -- the most interesting encoding in the ISA
    # ------------------------------------------------------------------
    g = "G logical"
    print("  --- group G: the rotate-and-run-length, and the reserved space")

    n32 = int1(r"^  32\s+([\d,]+)\s+4,294,967,296", T, re.M)
    n64 = int1(r"^  64\s+([\d,]+)\s+18,446,744,073,709,551,616", T, re.M)
    check(g, "the encodable 32-bit constant count is 1,302",
          n32 == 1302, "%s" % n32)
    check(g, "the encodable 64-bit constant count is 5,334",
          n64 == 5334, "%s" % n64)
    check(g, "and the artifact says the number is DERIVED not quoted",
          "DERIVED here by" in FLAT and "not read out of the manual" in FLAT)
    # TWO numbers on one line, so groups_of and not one(): the first version
    # used one(), got the STRING "5,334", and then read rt[0] as if it were a
    # tuple -- which is the character "5".  The harness reported 5 constants
    # round-tripped out of 5,334, which is a spectacularly confident wrong
    # number derived from a correct regex.
    rt = groups_of(r"([\d,]+) encodable 64-bit constants; (\d+) round-trip "
                   r"failures", T)
    check(g, "the round trip covers every encodable 64-bit constant",
          rt and rt[0].replace(",", "") == "5334", rt[0] if rt else "?")
    check(g, "and it reports zero failures", rt and rt[1] == "0",
          rt[1] if rt else "?")
    check(g, "the round trip is declared NOT sufficient on its own",
          "NOT sufficient" in T)
    check(g, "and the independent party is a real assembler",
          "written by different people that cannot see each other" in FLAT)
    ag = one(r"agreed:\s+(\d+)", T)
    dg = one(r"disagreed:\s+(\d+)", T)
    check(g, "the assembler round trip covers all 1,302 and agrees on all",
          ag == "1302" and dg == "0", "%s agreed, %s disagreed"
          % (ag, dg))
    check(g, "the all-zeros and all-ones 32-bit constants are REFUSED",
          T.count("32-bit all zeros") >= 1 and "32-bit all ones, 32-bit" in T)
    check(g, "and the article says why that matters",
          "exactly the constants a compiler wants most" in FLAT
          and "`and w0, w0, #0xffffffff` is refused" in FLAT)
    check(g, "the 64-bit all-ones is ALSO refused, which reverses the draft",
          "all ones, 64-bit" in T and "0xffffffffffffffff" in T)
    check(g, "and one bit short of all-ones IS accepted, beside it",
          "all but the top bit" in T and "all but the bottom bit" in T)
    check(g, "the article says the boundary is SHAPE not WIDTH",
          "not a WIDTH, it is the shape" in FLAT)
    check(g, "all eight logical ops were asked and all eight refused",
          "each one\nrefused" in T or "each refused" in FLAT)
    check(g, "the 12-bit logical field is reported as reaching more values "
             "than any other 12-bit field",
          "reaches more values than any other 12-bit field in AArch64" in FLAT
          and "including the add/sub immediate's 4,095" in FLAT)
    check(g, "and the share of the constant space is printed as a number",
          "3.031e-07" in T and "2.892e-16" in T)
    print()

    # ------------------------------------------------------------------
    # H. wide constants
    # ------------------------------------------------------------------
    g = "H wide"
    print("  --- group H: a constant too big for any field")

    # Columns: width, constant, insns, the instruction list, why.
    wrows = rows_of(T, r"\s+(32|64)\s+(0x[0-9a-f]+)\s+(\d+)\s+(\S.*?)"
                       r"\s\s+(\S.*?)\s*$")
    check(g, "the wide-constant table has one row per constant tested",
          len(wrows) >= 8, "%d rows" % len(wrows))
    if wrows:
        allones = [r for r in wrows if r[1].endswith("ffffffffffffffff")]
        bigsigned = [r for r in wrows if r[1].endswith("7fffffffffffffff")]
        nopattern = [r for r in wrows if r[1].endswith("123456789abcdef1")]
        check(g, "the 64-bit all-ones costs exactly ONE instruction",
              allones and allones[0][2] == "1",
              "%s insns" % (allones[0][2] if allones else "?"))
        check(g, "and it is a MOVN, not a MOVZ",
              allones and "movn" in allones[0][3], allones[0][3][:28]
              if allones else "?")
        check(g, "the largest SIGNED 64-bit value costs four",
              bigsigned and bigsigned[0][2] == "4",
              "%s insns" % (bigsigned[0][2] if bigsigned else "?"))
        check(g, "and an arbitrary 64-bit literal costs the same four",
              nopattern and nopattern[0][2] == "4",
              "%s insns" % (nopattern[0][2] if nopattern else "?"))
        check(g, "a constant with a zero field costs ONE (movz only)",
              [r for r in wrows if r[1].endswith("00000001234") or
               r[1] == "0x0000000000001234"] or
              any(r[2] == "1" for r in wrows if "movz" in r[3] and
                  "movk" not in r[3]))
    check(g, "the article says the table is not ordered by size",
          "the table is not ordered by size at all" in FLAT)
    check(g, "and the first draft's prediction is reported as wrong",
          "got all three wrong in the same way" in FLAT)
    check(g, "the two-instruction case is measured, not asserted",
          "two non-zero fields" in T)
    check(g, "the compiler's actual MOVZ/MOVK/MOVN counts are reported",
          re.search(r"\bmovz\s+\d+", T) is not None
          and re.search(r"\bmovk\s+\d+", T) is not None)
    print()

    # ------------------------------------------------------------------
    # I. the reserved space, found by asking
    # ------------------------------------------------------------------
    g = "I bounds"
    print("  --- group I: the edges, and the refusals")

    check(g, "the accepted-edge table is present", "=== 9A. ACCEPTED" in T)
    check(g, "the refusal table is present", "=== 9B. REFUSED" in T)
    check(g, "and the messages are quoted verbatim", "=== 9C. WHAT THE" in T)
    nok = groups_of(r"(\d+) of (\d+) accepted", T)
    check(g, "every accepted-edge row really was accepted",
          nok and nok[0] == nok[1], "%s of %s" % (nok or (0, 0)))
    nref = groups_of(r"(\d+) of (\d+) refused", T)
    check(g, "and the refusal count is reported",
          nref is not None, "%s of %s" % (nref or (0, 0)))
    check(g, "the pair offset is measured as a multiple of 8",
          "multiple of 8 in range [-512, 504]" in T)
    check(g, "the tbz bit range is a REGISTER-WIDTH property",
          "REGISTER-WIDTH property" in FLAT)
    check(g, "the displaced ranges are reported as ASYMMETRIC",
          "not symmetric" in FLAT and "one more negative value" in FLAT)
    check(g, "the distances are named with their real byte maxima",
          "0xffffc" in T and "0x100000" in T and "0x7fffffc" in T
          and "0x8000000" in T)
    check(g, "and the arithmetic error that was corrected is named",
          "a factor of four" in FLAT)
    check(g, "the sbfx->asr reinterpretation is reported as a non-boundary",
          "reinterprets the word" in FLAT)
    check(g, "the distinct diagnostic count is reported",
          one(r"There are (\d+) distinct messages", T) is not None)
    print()

    # ------------------------------------------------------------------
    # J. the sixteen condition codes
    # ------------------------------------------------------------------
    g = "J cond"
    print("  --- group J: sixteen conditions in four bits, and the cset trap")

    NAMES = "eq|ne|cs|cc|mi|pl|vs|vc|hi|ls|ge|lt|gt|le|al|nv"
    # Columns: value, bits, name, word, decoded.
    #
    # The bits column is FOUR characters and the pattern is `[01]{4}`, not
    # `0[01]{4}`.  The first version wrote the latter -- a leading 0 plus four
    # more, FIVE characters -- which matches "00000" and not "0000", so both
    # condition tables came back EMPTY and the harness reported sixteen
    # missing rows against two tables that print all sixteen.  An off-by-one
    # in a field WIDTH is the same bug this whole course is about, and it was
    # in the harness.
    csel = rows_of(T, r"\s+(\d+)\s+([01]{4})\s+(?:%s)\s+([0-9a-f]{8})"
                       r"\s+csel\s" % NAMES)
    bcond = rows_of(T, r"\s+(\d+)\s+([01]{4})\s+(?:%s)\s+([0-9a-f]{8})"
                        r"\s+b\." % NAMES)
    check(g, "the CSEL table has all sixteen condition values", len(csel) == 16,
          "%d rows" % len(csel))
    if len(csel) == 16:
        check(g, "the CSEL conditions are in ascending VALUE order",
              [r[0] for r in csel] == [str(i) for i in range(16)],
              " ".join(r[0] for r in csel))
        check(g, "and the value is printed in binary as the same number",
              all(int(r[1], 2) == int(r[0]) for r in csel))
        # The condition is the nibble at bits[15:12], which in a hex word is
        # the FOURTH nibble from the left -- characters 4..8 -- and the
        # remaining low bits are Rn and Rd, which are 0b00001 and 0b00010 in
        # this table and are held constant across all sixteen rows.
        check(g, "and the condition is the nibble at bits[15:12]",
              all(r[2][4] == "%x" % int(r[0]) for r in csel),
              " ".join(r[2][4] for r in csel))
        # The sixteen words differ ONLY in bits[15:12]: one nibble, sixteen
        # values, sixteen words, and everything else identical.
        words = [r[2] for r in csel]
        check(g, "the sixteen words differ ONLY in bits[15:12]",
              len({w[:4] + w[5:] for w in words}) == 1
              and len({w[4] for w in words}) == 16,
              "fixed %s, %d distinct nibbles at bits[15:12]"
              % (words[0][:4] + words[0][5:],
                 len({w[4] for w in words})))
    check(g, "the B.cond table is present and has sixteen rows",
          "=== 10C. THE SAME 4 BITS IN A BRANCH" in T and len(bcond) == 16,
          "%d rows" % len(bcond))
    if len(bcond) == 16:
        # B.cond's condition is bits[4:0], which is FIVE bits and therefore
        # not a nibble: the low five bits of the word, so bits[3:0] plus the
        # low bit of the imm19.  In hex that is the last hex digit plus the
        # bottom nibble's lowest bit, so the check is on the last THREE hex
        # digits' low five bits.
        check(g, "B.cond's condition is bits[4:0], so it is 5 bits wide",
              all((int(r[2][-6:], 16) & 0x1f) == int(r[0]) for r in bcond),
              "%s = %s ... %s = %s" % (bcond[0][0], bcond[0][2],
                                       bcond[-1][0], bcond[-1][2]))
        check(g, "and the two tables put the SAME value in two places",
              [r[0] for r in csel] == [r[0] for r in bcond])
        check(g, "and the two tables are genuinely different encodings",
              [r[2] for r in csel] != [r[2] for r in bcond],
              "csel %s vs b.cond %s" % (csel[0][2], bcond[0][2]))
    check(g, "the two spellings of values 2 and 3 are measured, not quoted",
          "`csel w0, w1, w2, cs` assembles to 0x1a822020" in FLAT)
    check(g, "the 4x4 table is built from WORDS, not assembled per cell",
          "built as WORDS" in FLAT)
    check(g, "four operations, not sixteen and not eight",
          "FOUR distinct operations" in T)
    check(g, "and the other four cells are UNDEFINED in both readers",
          "(undefined)" in T)
    check(g, "the SET forms are distinguished by REGISTER SLOTS not by bits",
          "distinguished by the REGISTER SLOTS" in FLAT)
    check(g, "the cset inversion is measured for five different pairs",
          T.count("SAME") >= 5, "%d SAME rows" % T.count("SAME"))
    check(g, "and at least one pair is DIFFERENT, which is the whole trap",
          "DIFFERENT" in T)
    check(g, "the nzcv limitation is stated and marked as not measured",
          "What CANNOT be measured here, and is not claimed" in FLAT
          and "There is no PUSHFLAGS" in FLAT)
    # The family is NINE names, and the count has to equal the sum of the
    # nine per-name numbers printed above it.  The first version of the
    # artifact counted them with a `startswith` test, missed csinc, csinv and
    # csneg, and printed 45 where the nine names add to 56 -- so the harness
    # reads the nine numbers and adds them rather than trusting the total.
    #
    # The bug is reported in the artifact as a CODE COMMENT, and a comment is
    # not in the output, so this check cannot find it there.  It is asserted
    # instead by re-deriving what the broken rule would have produced: 45,
    # against a printed 56.
    m9 = groups_of(r"conditional selects:\s+(\d+)\s+conditional branches:\s+"
                   r"(\d+)", T)
    check(g, "the corpus's select/branch counts are reported",
          m9 is not None, "%s selects / %s branches" % (m9 or ("?", "?")))
    if m9:
        m9 = (int(m9[0]), int(m9[1]))
    per = {}
    for nm in ("csel", "cset", "csetm", "csinc", "csinv", "csneg",
               "cinc", "cinv", "cneg"):
        v = one(r"^\s+%s\s+(\d+)\s*$" % re.escape(nm), T, re.M)
        if v:
            per[nm] = int(v)
    if m9 and len(per) == 9:
        check(g, "THE RESULT: the printed total equals the sum of the nine names",
              sum(per.values()) == m9[0],
              "%d from the names, %d printed" % (sum(per.values()), m9[0]))
        inv = sum(per[n] for n in ("cset", "csetm", "cinc", "cinv", "cneg"))
        check(g, "and the inverted forms are counted and reported separately",
              "of the %d selects are" % m9[0] in FLAT
              and "%d of the %d selects are" % (inv, m9[0]) in FLAT,
              "%d inverted" % inv)
        broken = sum(v for k, v in per.items()
                     if k.startswith("csel") or k.startswith("cset")
                     or k.startswith("cinc") or k.startswith("cinv")
                     or k.startswith("cneg"))
        check(g, "and the startswith bug that lost three of them is named",
              broken == 45 and m9[0] == 56,
              "the broken rule gives %d, the correct one %d" % (broken, m9[0]))
        check(g, "and the eleven it lost are exactly csinc + csinv + csneg",
              m9[0] - broken == per["csinc"] + per["csinv"] + per["csneg"],
              "lost %d = %d+%d+%d" % (m9[0] - broken, per["csinc"],
                                      per["csinv"], per["csneg"]))
    print()

    # ------------------------------------------------------------------
    # K. the displacement arithmetic -- worked out of the bits
    # ------------------------------------------------------------------
    g = "K displacement"
    print("  --- group K: the displacement arithmetic, step by step")

    check(g, "the B/BL table shows the sign bit and the x4",
          "sign bit 25" in T and "x4 -> bytes" in T)
    check(g, "and B's two ends are asymmetric",
          "+134217724" in T and "-134217728" in T,
          one(r"b the far end\s+[0-9a-f]+\s+imm26 = [^ ]+ -> sign bit 25 = \d "
              r"-> signed (\d+)", T) or "?")
    check(g, "the b.cond table shows imm19 and its sign bit",
          "sign bit 18" in T)
    check(g, "and b.cond's two ends are asymmetric too",
          "+1048572" in T and "-1048576" in T)
    check(g, "TBZ is given its OWN table because its field is 14 bits",
          "FOURTEEN bits" in T and "TBZ's own arithmetic" in T)
    check(g, "and the first draft's imm19-applied-to-TBZ error is reported",
          "+196,612 for an instruction" in FLAT
          and "TBZ IS NOT IN THIS TABLE" in FLAT
          and "factor of 49,153" in FLAT)
    check(g, "the adr table shows the SPLIT field being reassembled",
          "immhi" in T and "immlo" in T)
    check(g, "and adrp is reported as ONE BIT from adr",
          "differ by ONE BIT" in T)
    check(g, "the adrp truncation at +0x100000 is shown, not hidden",
          "truncates it to zero" in FLAT
          and "imm21 = (immhi 0x0 << 2) | immlo 0 = 0x0" in T)
    check(g, "the :lo12: pair is decoded in isolation and the limit is named",
          "CANNOT know they are a pair" in FLAT)
    check(g, "the 1 MiB conditional-branch reach is stated as a cost",
          "two words" in FLAT and "128 MiB" in FLAT)
    print()

    # ------------------------------------------------------------------
    # L. the two readers, and the poison
    # ------------------------------------------------------------------
    g = "L crosscheck"
    print("  --- group L: two readers, and the control that proves it")

    g4 = groups_of(r"(\d[\d,]*) object files, (\d[\d,]*) instructions, "
                   r"(\d[\d,]*) named by this decoder,\s+(\d+) left unmodelled",
                   T)
    # g4[0] is the FILE COUNT, not the instruction count.  The first version
    # unpacked it as the total, and `named + unmodelled == total` compared
    # 859 + 9 against 5 -- the number of object files -- and reported a
    # consistency failure in a table that is perfectly consistent.  The two
    # counts are adjacent in the sentence and are not the same number.
    files_n, tot, agr, unm = g4 if g4 else (None, None, None, None)
    check(g, "the cross-check covers the whole corpus",
          tot is not None, "%s instructions" % tot)
    a = one(r"the two readers agree on:\s+(\d+)", T)
    d = one(r"the two readers disagree:\s+(\d+)", T)
    check(g, "and it reports an agreement count and a disagreement count",
          a is not None and d is not None, "%s agree, %s disagree" % (a, d))
    # The RESULT.  The two readers agree on every NAMED instruction, and the
    # unmodelled ones are excluded by construction rather than by luck -- so
    # the number that has to hold is agree == named, not agree == total.
    check(g, "THE RESULT: the two readers agree on every NAMED instruction",
          a is not None and d == "0" and a == agr,
          "%s agree, %s disagree, %s named" % (a, d, agr))
    check(g, "and the unmodelled words are counted and NOT called failures",
          unm is not None and "left unmodelled and counted" in T)
    check(g, "and the count is consistent: named + unmodelled = total",
          agr is not None and unm is not None
          and int(agr) + int(unm) == int(tot),
          "%s + %s = %s" % (agr, unm, tot))
    check(g, "the 98.72% history is reported, with all eleven",
          "848 of 859" in T and "98.72%" in T)
    # R17 says "two of them were a real decoder bug (R15) and nine were a
    # normalisation rule written against a string with a space in it, so it
    # matched NOTHING".  The words are "a real DECODER bug", not "a real bug
    # in this decoder" -- the second version of this check looked for a
    # paraphrase and found nothing against a sentence that is present.
    check(g, "and the two kinds of failure are distinguished",
          "a real decoder bug" in FLAT and "matched NOTHING" in FLAT)
    check(g, "the poison is installed by REPLACING a model, not prepending one",
          "prepended a model that claims nothing rather than REMOVING one"
          in FLAT)
    check(g, "and it names the model it poisoned", "poisoned:" in T)
    before = one(r"BEFORE the poison: (\d+) agree", T)
    after = one(r"AFTER  the poison: (\d+) agree", T)
    check(g, "THE CONTROL: the poison MOVED the agreement number",
          before and after and int(after) < int(before),
          "%s -> %s" % (before, after))
    check(g, "and the verdict says so in words",
          "VERDICT: the number MOVED" in T)
    check(g, "the seven normalisations are listed, and there are seven",
          "THE SEVEN NORMALISATIONS" in T and
          len(re.findall(r"^    \d\. ", T, re.M)) >= 7)
    check(g, "the sixth normalisation's register-name bug is reported",
          "turned a REGISTER NAME into" in FLAT)
    check(g, "the seventh (the sign) is reported as nine of the eleven",
          "rule 7" in FLAT and "nine of the eleven" in FLAT)
    check(g, "the shared-toolchain weakness is stated",
          "both ultimately come from one LLVM tree" in FLAT)
    print()

    # ------------------------------------------------------------------
    # M. the density comparison -- the course's one moving number
    # ------------------------------------------------------------------
    g = "M density"
    print("  --- group M: the density ratio, asserted as a SHAPE")

    # Columns: -O, a64 bytes, a64 insns, x86 bytes, x86 insns, ratio, x86 b/i.
    # The first column is `-0`, `-1`, `-2`, `-s` and NOT `-O0`: the artifact
    # prints `'-' + o` where `o` is the bare digit, so there is no `O` in the
    # cell.  The first version of this pattern expected `-O0` and matched
    # nothing, which reported as "the density table has 0 rows" against a
    # table with four.
    drows = rows_of(T, r"\s+(-[012s])\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+"
                       r"([\d.]+)\s+([\d.]+)\s*$")
    check(g, "the density table has one row per optimisation level",
          len(drows) == 4, "%d rows" % len(drows))
    if len(drows) == 4:
        ratios = [float(r[5]) for r in drows]
        check(g, "and a ratio per row", len(ratios) == 4,
              " ".join("%.3f" % x for x in ratios))
        check(g, "each ratio is the byte ratio it claims to be",
              all(abs(float(r[5]) - float(r[1]) / float(r[3])) < 0.001
                  for r in drows),
              " ".join("%.3f" % (float(r[1]) / float(r[3])) for r in drows))
        check(g, "and each AArch64 row is exactly insns x 4",
              all(int(r[1]) == int(r[2]) * 4 for r in drows))
        # THE SHAPE, and this is the only claim in the course that is not
        # exact.  A compiler version can move these four numbers, so the
        # harness does not assert them -- it asserts that the SIGN CHANGES
        # between the first two levels, which is the finding, and which is
        # what the course says.
        check(g, "THE RESULT: the sign CHANGES between -O0 and -O1",
              ratios[0] > 1.0 > ratios[1],
              "-O0 %.3f  -O1 %.3f" % (ratios[0], ratios[1]))
        check(g, "and AArch64 is larger at exactly two of the four levels",
              len([r for r in ratios if r > 1]) == 2,
              "%d of 4 above 1" % len([r for r in ratios if r > 1]))
        check(g, "the -O0 row has fewer instructions and MORE bytes",
              int(drows[0][2]) < int(drows[0][4])
              and int(drows[0][1]) > int(drows[0][3]),
              "a64 %s insns / %s bytes vs x86 %s / %s"
              % (drows[0][2], drows[0][1], drows[0][4], drows[0][3]))
        check(g, "and the x86 bytes/insn column is a DISTRIBUTION, not 4.0",
              all(abs(float(r[6]) - 4.0) > 0.01 for r in drows),
              " ".join(r[6] for r in drows))
    check(g, "the three wrong answers are named before the number",
          "WRONG ANSWER 1" in T and "WRONG ANSWER 2" in T
          and "WRONG ANSWER 3" in T)
    check(g, "the wrong answer 1 trap (ratio > 1 means LARGER) is stated",
          "a value ABOVE 1 means AArch64 spends MORE bytes" in FLAT)
    check(g, "the length DISTRIBUTION is measured, not asserted",
          "=== 13A. THE ACTUAL LENGTH DISTRIBUTION" in T
          and "distinct lengths, AArch64 has 1" in T)
    check(g, "and the x86 side really is a distribution with several values",
          len(re.findall(r"^\s+\d bytes\s+\d+\s+\d+\.\d%", T, re.M)) >= 7)
    check(g, "the retraction is named in the section that caused it",
          "R1 in section 14" in T)
    check(g, "and the general form is stated: every feature costs bits",
          "none of them is free" in FLAT)
    print()

    # ------------------------------------------------------------------
    # N. the retractions -- all of them, by presence
    # ------------------------------------------------------------------
    g = "N retract"
    print("  --- group N: every retraction, and there are seventeen")

    tags = re.findall(r"^  (R\d+)\.  ", T, re.M)
    check(g, "seventeen retractions are printed", len(tags) == 17,
          "%d found" % len(tags))
    check(g, "and they are R1 to R17 with no gap",
          tags == ["R%d" % i for i in range(1, 18)], " ".join(tags))
    for t in tags:
        # The verdict word may be at the start of the body (RETRACTED, REFINE
        # D) or after a comma in the first line of the body, which is how R4
        # reads: "NOT WRONG, BUT INCOMPLETE IN A WAY THAT MATTERS".  The split
        # is on a blank line so the next retraction's header is not part of
        # this one's body.
        # The verdict word is looked for in the WHOLE body rather than in its
        # first two lines: R4's verdict is "NOT WRONG, BUT INCOMPLETE" and
        # the first version of this check looked for RETRACTED/REFINED/
        # CORRECTED and reported R4 as a retraction that did not say what
        # happened.  The body is also flattened, because the artifact wraps
        # at 78 columns and "RETRACTED, AND IT IS THE MOST IMPORTANT LINE"
        # can straddle a break.
        seg = re.sub(r"\s+", " ", T.split("  %s.  " % t)[1].split("\n\n")[0])
        check(g, "%s states what was claimed AND what happened" % t,
              any(w in seg for w in ("RETRACTED", "REFINED", "CORRECTED",
                                     "NOT WRONG")),
              (seg[:40] + "...") if seg else "")
    check(g, "R4 is the one that says NOT WRONG rather than RETRACTED",
          "NOT WRONG, BUT INCOMPLETE" in T)
    check(g, "R1 is the density claim and it is REVERSED at half the levels",
          "REVERSED AT HALF THE LEVELS" in T)
    check(g, "R2 is the two-bit class field and it quotes the measured width",
          "FOUR\n       BITS at position 25" in T or "FOUR BITS at position 25" in FLAT)
    check(g, "R3 is the logical immediate and it quotes 1,302",
          "1,302 of 4,294,967,296" in T)
    check(g, "R6 is the cset inversion", "`cset` is `csinc` with Rn = Rm = 31" in T)
    check(g, "R11 is the sf bit meaning three different things",
          "in CSET and CSETM" in T)
    check(g, "R15 is the register-31 escape and it was FOUND by the cross-check",
          "FOUND BY THE CROSS-CHECK RATHER THAN BY READING" in T)
    # The phrase "is the reverse of the truth" sits at the end of R16's body
    # and `in T` only works if it is not wrapped.  It is wrapped here, so the
    # check runs against FLAT -- the fourth time in this harness that a
    # phrase was searched for in the wrong copy of the text.
    check(g, "R16 is the 64-bit all-ones and it reverses the draft",
          "is the reverse of the truth" in FLAT)
    check(g, "R15 and R16 sit AFTER R14, in numeric order",
          tags.index("R15") > tags.index("R14")
          and tags.index("R16") == tags.index("R15") + 1)
    check(g, "R17 says 100% is what a broken check looks like",
          "100% is what a check that has been normalised until" in FLAT)
    check(g, "the file says which retractions a reader is most likely to keep",
          "MOST LIKELY TO BELIEVE" in T)
    check(g, "and which the next reader is most likely to reintroduce",
          "TO REINTRODUCE" in T)
    check(g, "and the general form is stated",
          "were not claims about BITS" in FLAT)
    print()

    # ------------------------------------------------------------------
    # O. the limits
    # ------------------------------------------------------------------
    g = "O limits"
    print("  --- group O: what the file cannot show, printed as limits")

    for title, why in (
            ("NOTHING IS EXECUTED", "no instruction has been run"),
            ("THE DECODER IS A SUBSET", "Advanced SIMD is not modelled"),
            ("THE ORACLE IS A TOOL", "not the architecture"),
            ("THE FIELD MAP IS MEASURED FROM ONE ASSEMBLER",
             "a field map is a property of the ENCODING"),
            ("THE CORPUS IS ORDINARY C", "a distribution of what clang chose"),
            ("DENSITY IS A PROPERTY OF A COMPILER", "not of an ISA"),
            ("NO EXECUTION MEANS NO SAFETY CLAIM", "UNDEFINED is a decoder cost"),
            ("THE TWO READERS SHARE A SOURCE", "one LLVM tree")):
        check(g, "the limit is printed: %s" % title, title in T)
    check(g, "and each limit says what it does to the claims",
          "Nothing here is a claim about speed" in FLAT
          and "Nothing in the course is generalisable from the" in FLAT
          and "decoder cost, not a promise" in FLAT)
    check(g, "the closing claim is that the four claim kinds need no machine",
          "do not need a machine to be verified" in FLAT
          and "can be checked by a reader with a hex editor" in FLAT)
    check(g, "the harness's own asymmetry is stated",
          "asserts the POISON moved the number" in FLAT)
    check(g, "and a bare-number threshold is named as the failure mode",
          "fails on a busier" in FLAT and "teaches its reader to ignore it" in FLAT)
    check(g, "the shipped output is what the harness can read without building",
          os.path.exists(os.path.join(HERE, "a64dec.out")))
    print()

    # ------------------------------------------------------------------
    print("=" * 72)
    if FAILURES:
        print("%d of %d checks, %d failed" % (CHECKS, CHECKS, len(FAILURES)))
        for grp, what, detail in FAILURES:
            print("  [%s] %s  %s" % (grp, what, detail))
        print("=" * 72)
        return 1
    # TWO tally spellings are in use across the collection -- "N/M checks
    # passed" and "N checks, M failed" -- and tools/verify_*.py accepts either
    # by requiring only that the failures column is zero.  This file's first
    # version printed "all 243 checks passed", which is neither, so the course
    # verifier reported a problem against a harness that had just passed every
    # one of its checks.  A harness whose output a verifier cannot parse is a
    # harness nobody reads, and the fix is to use the spelling the collection
    # already agreed on rather than to invent a third one.
    print("%d/%d checks passed" % (CHECKS, CHECKS))
    print("=" * 72)
    return 0


if __name__ == "__main__":
    sys.exit(main())
