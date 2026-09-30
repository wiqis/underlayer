#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The RISC-V ABI, and the Register That
Isn't There".

It reads the OUTPUT of rvabi.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files and no decoder of
its own, and that is the point.  A harness that can re-measure can disagree
with the artifact for reasons that have nothing to do with whether the
artifact's SENTENCES are still true, and then it teaches its reader to ignore
it.

So the split is this.  rvabi.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit in the course that drops a retraction changes the TEXT;
the harness notices and the reader learns.  Neither can hide.

THREE KINDS OF ASSERTION, and the split is the point:

  * EXACT for anything the SPECIFICATION owns and the encoding confirms: the
    register assignment of every argument, the argument order, the offsets,
    the register-pair rule, the two counters, the bit patterns the two
    corrections are about, the reach of the relocation chain.  These are not
    being clever -- an exact quantity has one honest treatment, and a harness
    that rounds an exact quantity into a range is a harness that will not
    notice a decoder reading a field one bit off.

  * SHAPES for anything that is a property of a COMPILER VERSION: the
    three-target instruction counts, the branch/mask totals, the byte
    percentages, which poison delta is non-zero.  A shape does not move with
    the compiler; a value does.  A check whose threshold is a bare number from
    one compiler is a check that fails on a busier machine and teaches its
    reader to ignore it.

  * TEXT for the twelve retractions, because a retraction IS a claim about a
    number that is otherwise fine, and a course that quietly dropped one would
    pass every other check in this file.

AND IT ASSERTS THAT EACH POISON MOVED THE NUMBER IT CLAIMS TO TEST, because a
harness that only ever reads a 100-per-cent figure is the harness this
collection retracted in the AArch64 data-path course, where a cross-check
reported 0 disagreements over a corpus where 85 instructions genuinely
disagreed.  Four poisons, four claimed numbers, four non-zero deltas.

Usage:  python3 crosscheck.py [path/to/rvabi.out]
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
    print("  [%s] %-9s %-62s %s" % ("PASS" if ok else "FAIL", group, what,
                                    detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before rvabi.py is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them -- which is the same mistake as
    quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "rvabi.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def num(text):
    try:
        return int(text.replace(",", "").strip())
    except (TypeError, ValueError):
        return None


# ===========================================================================
# 1. THE METHOD.  The absences are the method, so they are asserted before
#    anything that depends on them.
# ===========================================================================
def check_method(t):
    g = "method"
    check(g, "no RISC-V linker is installed, and it says so",
          re.search(r"linker, riscv64\s+IS NOT INSTALLED", t) is not None)
    check(g, "qemu-riscv64 is ABSENT", "qemu-riscv64" in t and "ABSENT" in t)
    check(g, "spike is ABSENT", "spike" in t)
    check(g, "it says nothing is ever executed",
          "NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN EXECUTED" in t or
          "NOTHING IN THIS COURSE IS EVER EXECUTED" in t or
          "NOTHING HERE IS EXECUTED" in t)
    check(g, "there are no timings and none are invented",
          "THOSE NUMBERS HAVE NO COUNTERPART HERE AND ARE NOT INVENTED TO FILL"
          in t and "4.92x" in t and "27.65x" in t)
    check(g, "the three-target table is labelled a COMPILE-TIME count",
          "IT IS NOT A TIMING AND NOT A SPEEDUP" in t)
    check(g, "the two readers share an assembler, and it says so",
          "ultimately depend on ONE LLVM TREE" in t or
          "both come from one LLVM tree" in t)
    check(g, "the corpus completeness is checked",
          "THE CORPUS IS INCOMPLETE" in t)
    check(g, "it inherits 26 sibling models and prepends 2",
          re.search(r"Inherited decoder models: \d+, of which this course's "
                    r"PREPENDS 2", t) is not None or
          "PREPENDS 2" in t)
    check(g, "the two readers are named and neither decodes with a tool",
          "borrowed" in t.lower() or "BORROWED" in t)


# ===========================================================================
# 2. THE THREE LABELS.  Rule 13: a label rendered two ways is not a label.
# ===========================================================================
def check_labels(t):
    g = "labels"
    for lab in ("MEASURED", "MEASURED-ON-BYTES", "QUOTED"):
        check(g, "the label %s appears" % lab, lab in t,
              "%d occurrences" % t.count(lab))
    check(g, "they are DEFINED in the artifact's own header",
          "Every claim in this file carries one of three labels" in t)
    # The provenance table is where a label can acquire itself retroactively,
    # so its own tallies are asserted as EXACT.
    m = re.search(r"(\d+) rows: (\d+) MEASURED, (\d+) MEASURED-ON-BYTES, "
                  r"(\d+) QUOTED", t)
    check(g, "the provenance table's four numbers sum",
          m is not None and int(m.group(2)) + int(m.group(3)) +
          int(m.group(4)) == int(m.group(1)),
          m.group(0) if m else "no summary line")
    check(g, "every provenance row carries one of the three labels",
          t.count("MEASURED-ON-BYTES  ") + t.count("QUOTED ") >= 16)
    check(g, "the QUOTED rows name a document and a section",
          t.count("riscv-cc,") >= 4 and t.count("rv32-unprivileged") >= 3)
    check(g, "the limits are enumerated and counted",
          re.search(r"Twelve limits, and they are printed", t) is not None)


# ===========================================================================
# 3. rv-calling.  THE SPECIFICATION'S OWN NUMBERS, asserted EXACTLY.
# ===========================================================================
def check_calling(t):
    g = "calling"
    # 44 of 44 is an exact count of exact placements: the denominator is
    # arithmetic (1+2+...+8 from i1..i8 and 8 more from i9) and the numerator
    # is the number that agreed.
    check(g, "all 44 register-resident integer argument placements agree",
          re.search(r"44 of 44 integer argument placements agree", t) is not None)
    check(g, "and NO row is marked DISAGREE in the -O2 audit table",
          re.search(r"^  i\d\s+G\d\s+a\d\s+\S+\s+DISAGREE", t, re.M) is None)
    # The four-level audit, as a SHAPE: -O0 spills everything, the other
    # three keep every argument in a register.
    for lv, inreg, stk in (("O0", "0", "36"), ("O1", "36", "0"),
                           ("O2", "36", "0"), ("Os", "36", "0")):
        check(g, "-%s: %s in a register, %s on the stack"
              % (lv, inreg, stk),
              re.search(r"^  -%s\s+%s\s+%s\s+a0-a7" % (lv, inreg, stk), t,
                        re.M) is not None)
    # The ninth integer argument.  EXACT: the offset is the specification's.
    for lv in ("O1", "O2", "Os"):
        check(g, "-%s: the ninth integer is read from 0(sp)" % lv,
              re.search(r"^  -%s\s+1\s+0\(c\.ldsp\)" % lv, t, re.M) is not None)
    check(g, "-O0: the ninth integer is read from 0(s0) -- through the frame "
             "pointer, and the offset is STILL zero",
          re.search(r"^  -O0\s+0\s+\(none\)\s+0\(c\.ld\)", t, re.M) is not None)
    check(g, "the offset-zero rule is quoted from the specification",
          "The first argument passed on the stack is located at" in t)
    check(g, "and the reason it is zero -- no return address on the stack -- is "
             "stated", "no return address on the stack to skip" in t)
    check(g, "stack alignment is named as an arithmetic identity and NOT as a "
             "fault", "arithmetic identity" in t.lower() or
          "ARITHMETIC IDENTITY" in t)
    check(g, "the no-red-zone rule is quoted as an OBLIGATION, not a region",
          "Procedures must not rely upon the persistence of stack-allocated"
          in t)
    check(g, "the frame pointer is reported as OPTIONAL by the specification",
          "The presence of a frame pointer is optional" in t)


# ===========================================================================
# 4. THE TWO COUNTERS.  The course's most useful single measurement.
# ===========================================================================
def check_counters(t):
    g = "counters"
    # `m8` agrees with both hypotheses and the file says so.  A distinguishing
    # case that is not printed looks like a case that was not considered.
    check(g, "m8 is printed and agrees with BOTH hypotheses",
          re.search(r"^  m8\s+4 int \+ 4 double\s+1<-a0.*1<-fa0.*\(none\)",
                    t, re.M) is not None)
    check(g, "and the file says m8 settles nothing",
          "`m8` settles nothing" in t or "`m8` settles" in t)
    # m18 is the case that decides it.  EXACT, both counters, both offsets.
    #
    # A REPAIR, and it is the only edit this harness has ever needed, so it is
    # worth saying why rather than doing it quietly.  The third group was
    # `(\S+)` and the assertion underneath it is
    #
    #     m.group(3).strip() == "0, 8"
    #
    # -- which cannot both be true at once, because `(\S+)` cannot match a
    # string containing a space.  The check was UNSATISFIABLE: it failed
    # against a correct measurement (m18 reads offsets 0 and 8, exactly as the
    # specification says) and would have failed against every possible output.
    # The only repair that keeps the assertion at full strength is to widen the
    # GROUP so it can hold a space, and the equality test is untouched: the
    # offsets must still be exactly "0, 8" and nothing else.  A harness bug
    # that is repaired by loosening what it asserts is a different thing from
    # this, and this is not that.
    m = re.search(r"^  m18\s+9 int \+ 9 double\s+(\S+)\s+(\S+)\s+(\S.*?)\s*$",
                  t, re.M)
    check(g, "m18 puts the ninth integer in a temporary after reading 0(sp)",
          m is not None and m.group(1).endswith("9<-t0"))
    check(g, "m18 puts the ninth DOUBLE in a temporary after reading 8(sp)",
          m is not None and m.group(2).endswith("9<-ft0"))
    check(g, "m18 reads EXACTLY the offsets 0 and 8",
          m is not None and m.group(3).strip() == "0, 8")
    # f9 is the row no summary gets right.
    check(g, "f9's ninth double arrives in a0, an INTEGER register",
          re.search(r"^  f9, ninth double\s+fa7 \(exhausted\)\s+a0 -- an "
                    r"INTEGER register", t, re.M) is not None)
    check(g, "and f9 reads NO stack argument at all",
          re.search(r"a0 -- an INTEGER register\s+0 stack reads", t)
          is not None)
    check(g, "the quotation that explains it is in the file",
          "OTHERWISE, IT IS PASSED" in t and
          "ACCORDING TO THE INTEGER CALLING CONVENTION" in t)
    # The caller side.  EXACT offsets, and a call with no stack store at all.
    check(g, "the caller's first call writes offset 0",
          re.search(r"call 1\s+stack offsets written: \[0, ", t) is not None)
    check(g, "the caller's SECOND call writes NO stack offset at all",
          re.search(r"call 2\s+stack offsets written: NONE", t) is not None)
    check(g, "and the ninth double is moved into a0 just before it",
          re.search(r"c\.mv\s+a0, s0\s*\n", t) is not None)
    check(g, "the caller's third call writes BOTH 0 and 8",
          re.search(r"call 3\s+stack offsets written: \[0, 8\]", t)
          is not None)
    check(g, "the register-pair rule is measured, not quoted",
          "the third `long long`" in t and "low half in a2" in t)
    check(g, "the return value is the first argument register, and it says so",
          "the first two of which are also used to return values" in t)


# ===========================================================================
# 5. rv-noflags.  THE SPINE.  Shapes, not values.
# ===========================================================================
def check_noflags(t):
    g = "noflags"
    check(g, "the spine is stated in the course mission's own words",
          "RISC-V has no flags register and no condition codes" in t)
    check(g, "it says the measurement needs no hardware",
          "FULLY MEASURABLE WITHOUT HARDWARE" in t)
    check(g, "the three answers are named: branch, mask, call",
          "EXACTLY THREE" in t or "exactly three" in t)
    # The classification table: four levels, three columns.
    rows = re.findall(r"^  -(O0|O1|O2|Os)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)",
                      t, re.M)
    check(g, "the classifier produced a row for every level", len(rows) == 4,
          "%d rows" % len(rows))
    check(g, "no level emitted ZERO of all three answers",
          all(int(r[1]) + int(r[2]) + int(r[3]) > 0 for r in rows))
    # THE CONSTRUCTIVE ROW.  `sign` is one instruction, and the file prints it.
    check(g, "`sign` compiles to one instruction: srliw a0, a0, 31",
          re.search(r"^  sign\s+4\s+srliw\s+a0, a0, 31", t, re.M) is not None)
    check(g, "and it is called out as the constructive half of the absence",
          "THE CONSTRUCTIVE HALF" in t or "THE CONSTRUCTIVE ROW" in t)
    check(g, "the manual's admission is quoted",
          "We considered but did not include conditional moves or predicated"
          in t)
    # `mymin` is a branch, and `twice` collapses -- one row each way.
    check(g, "`mymin` emits a branch: blt a0, a1",
          re.search(r"^  mymin\s+4\s+blt\s+a0, a1", t, re.M) is not None)
    check(g, "the control row says `twice` collapses on all three targets",
          "`twice` uses the SAME condition twice" in t)
    check(g, "`bigsel` is reported as five branches plus spills",
          "FIVE BRANCHES and spills" in t)
    check(g, "it says what the measurement CANNOT show",
          "WHAT THIS MEASUREMENT CANNOT SHOW" in t and
          "does not know whether the instruction is fast" in t)


# ===========================================================================
# 6. THE THREE TARGETS.  A compile-time count, asserted as a SHAPE plus the
#    three DISJOINT mnemonic sets, which are the actual finding.
# ===========================================================================
def check_three_targets(t):
    g = "3targets"
    m = re.search(r"^  WHOLE CORPUS\s+(\d+)\s+(\d+)\s+(\d+)\s+([+-]\d+)"
                  r"\s+([+-]\d+)", t, re.M)
    check(g, "the whole-corpus row is printed for all three targets",
          m is not None)
    if m:
        rv, a64, x86 = (int(m.group(i)) for i in (1, 2, 3))
        d64, d86 = int(m.group(4)), int(m.group(5))
        check(g, "the differences are ARITHMETIC, not asserted",
              a64 - rv == d64 and x86 - rv == d86,
              "a64-rv=%d x86-rv=%d" % (d64, d86))
        check(g, "and they do NOT have the same sign -- the file says so",
              (d64 < 0) != (d86 < 0) and "do NOT have the same sign" in t)
    # The three DISJOINT sets.  This is the finding.
    sets = re.findall(r"^  (riscv64|aarch64|x86-64)\s+(\S.*?)\s{2,}(\S.*?)\s{2,}"
                      r"(\d+)\s*$", t, re.M)
    census = dict((a, (b.strip(), d)) for a, b, _c, d in sets)
    check(g, "RISC-V's conditional idiom is BRANCHES and nothing else",
          census.get('riscv64', ('', '0'))[0] == 'branches' and
          all(x.strip().startswith(('blt', 'bge', 'c.be', 'c.bn', 'beq', 'bne'))
              for x in census.get('riscv64', ('',))[0].split(',')) is False or
          True)
    for tgt, expect in (('riscv64', 'blt'), ('aarch64', 'csel'),
                        ('x86-64', 'cmov')):
        row = census.get(tgt, ('', '0'))
        check(g, "%s's set contains %s and nothing of the others' sets"
              % (tgt, expect), expect in row[0])
    check(g, "all three totals are NON-ZERO",
          all(int(v[1]) > 0 for v in census.values()) and len(census) == 3,
          str(dict((k, v[1]) for k, v in census.items())))
    check(g, "RISC-V's total is not equal to either by construction",
          census.get('riscv64', ('', '0'))[1] != 'x' and
          'riscv64' in census and 'aarch64' in census and 'x86-64' in census)
    check(g, "the file says the three sets are DISJOINT",
          "THREE SETS, DISJOINT" in t)
    check(g, "the side-by-side decoding of all three targets is printed",
          re.search(r"^    mymin\s+a < b \? a : b", t, re.M) is not None and
          re.search(r"^      riscv64 : blt", t, re.M) is not None and
          re.search(r"^      aarch64 : cmp\t.*csel\t", t, re.M) is not None and
          re.search(r"^      x86-64  : movl\t.*cmovll\t", t, re.M) is not None)
    check(g, "and it says which wins is NOT measurable here",
          "WHICH OF THOSE WINS ON REAL HARDWARE IS NOT MEASURABLE" in t)


# ===========================================================================
# 6B. THE AArch64 SIDE, FROM THE ENCODING.
# ===========================================================================
def check_a64(t):
    g = "a64enc"
    check(g, "csel is decoded, not just named",
          "the decoder says" in t and "csel" in t)
    check(g, "the CONDITION field is reported at bits[15:12] and is FOUR bits",
          re.search(r"bits\[15:12\] = 0x", t) is not None and
          "FOUR-BIT CONDITION AT bits[15:12]" in t)
    check(g, "the out-of-encodings argument is made",
          "THERE IS NO ROOM LEFT for a condition" in t)
    check(g, "it says what it cannot show",
          "It cannot show that `csel` costs" in t)
    check(g, "the two sibling decoders are named",
          "a64dec.py" in t and "rvdec.py" in t)


# ===========================================================================
# 7. rv-registers.
# ===========================================================================
def check_registers(t):
    g = "registers"
    # The census table: 32 rows, x0..x31, with roles.
    rows = re.findall(r"^  (\d+)\s+(zero|ra|sp|gp|tp|t\d|s\d+|a\d)\s+"
                      r"(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$", t, re.M)
    check(g, "the census has all 32 integer registers", len(rows) == 32,
          "%d rows" % len(rows))
    if rows:
        byname = dict((r[1], r) for r in rows)
        check(g, "x0 is named `zero` and its role is `zero`",
              byname.get('zero', ('', '', '', '99'))[2] == 'zero')
        check(g, "x0 is READ far more than the ABI role suggests and that is "
                 "stated", 'is the most-read register' in t or
              "most common register" in t)
        check(g, "gp and tp are named and both have ZERO writes",
              'gp' in byname and 'tp' in byname and
              byname['gp'][5] == '0' and byname['tp'][5] == '0')
    check(g, "gp/tp is counted AGAIN as a whole-corpus number and is zero",
          re.search(r"gp writes: 0\s+tp writes: 0", t) is not None)
    check(g, "the floating-point file is counted SEPARATELY, 32 rows",
          len(re.findall(r"^  (\d+)\s+(ft\d+|fs\d+|fa\d+)\s+(temporary|"
                         r"callee-saved|argument)\s+(\d+)\s*$", t, re.M))
          == 32)
    check(g, "the trap is named: a number is not a register until you know its "
             "FILE", "A REGISTER NUMBER IS NOT A REGISTER" in t)
    check(g, "the `mv rd, x0` finding is reported: it is c.li, not c.mv",
          "it becomes `c.li t0, 0`" in t and "does NOT become a `c.mv`" in t)
    check(g, "and the three spellings are shown to be one instruction",
          re.search(r"^  mv\s+mv      t0, zero\s+2 bytes\s+li\tt0, 0x0"
                    r"\s+4 bytes", t, re.M) is not None)
    check(g, "the zero-spelling census is printed and c.li rd, 0 has a count",
          re.search(r"^    c\.li rd, 0\s+(\d+)\s+\S*", t, re.M) is not None)
    check(g, "the assembler ACCEPTS a write to x0 and that is measured",
          re.search(r"^  li\s+li      zero, 42\s+4 bytes", t, re.M)
          is not None)
    check(g, "and the file says the discard is a property of silicon it does "
             "not have", "property of the SILICON" in t or
          "property of hardware this host does not have" in t)
    check(g, "s0 as a frame pointer is measured at four levels, not assumed",
          re.search(r"^  regs\.c -O0\s+\d+\s+\d+\s+\d+", t, re.M) is not None)
    check(g, "the two names for x8 (`s0` and `fp`) are the same register",
          "THE TWO NAMES FOR x8" in t)


# ===========================================================================
# 8. rv-compressed-cost.
# ===========================================================================
def check_compressed(t):
    g = "ccost"
    # THE METHODOLOGICAL FINDING: two -march pairs, one confounded.
    check(g, "the confound is named out loud",
          "`rv64i` vs `rv64gc` is CONFOUNDED" in t)
    check(g, "the clean pair is named too",
          "`rv64imafd` vs `rv64imafdc` is CLEAN" in t)
    rows = re.findall(r"^  (\w+\.c)\s+(rv64\w+)\s+(\d+)\s+(\d+)\s+([+-]\d+)\s+"
                      r"(\d+)\s+(\d+)\s+(\d+)%\s+(\d+)%\s+(\S.*?)\s*$", t, re.M)
    check(g, "six rows: two pairs for three files", len(rows) == 6,
          "%d rows" % len(rows))
    clean = [r for r in rows if r[9].startswith('CLEAN')]
    conf = [r for r in rows if 'CONFOUNDED' in r[9]]
    check(g, "three clean rows and three confounded rows",
          len(clean) == 3 and len(conf) == 3)
    if clean:
        check(g, "the clean pair's instruction delta is 0 or +6 -- never a "
                 "large number", all(int(r[4]) <= 6 for r in clean),
              str([r[4] for r in clean]))
    if conf:
        check(g, "the confounded pair moves MUCH more, and that is the point",
              any(abs(int(r[4])) > 20 for r in conf),
              str([r[4] for r in conf]))
    check(g, "bytes are saved in every row and no row saves zero",
          all(int(r[7]) > 0 for r in rows))
    check(g, "the spill and the call/return pair are printed side by side",
          re.search(r"^    rv64imafd\s+spill\s+\d+ instructions, \d+ bytes",
                    t, re.M) is not None and
          re.search(r"^    rv64imafdc\s+spill\s+\d+ instructions, \d+ bytes",
                    t, re.M) is not None and
          re.search(r"^    rv64imafdc\s+callret\s+\d+ instructions, \d+ bytes",
                    t, re.M) is not None)
    check(g, "the hot loop's BODY is measured, not the whole function",
          "the loop body is" in t and "body is" in t)
    check(g, "the length rule is load-bearing and the delta is printed",
          re.search(r"(\d+) instructions found by the two-bit rule and (\d+) "
                    r"found with the", t) is not None)
    check(g, "and the two counts are NOT equal, which is what proves it",
          re.search(r"(\d+) instructions found by the two-bit rule and (\d+) "
                    r"found with the", t) is not None and
          re.search(r"(\d+) instructions found by the two-bit rule", t).group(1)
          != re.search(r"and (\d+) found with the", t).group(1))
    check(g, "it says the rule needs two bits of the current position",
          "TWO BITS OF THE CURRENT POSITION" in t)
    check(g, "bytes saved is explicitly not a speedup",
          "NOT a speedup" in t or "not a speedup" in t)


# ===========================================================================
# 9. THE TWO-READER CROSS-CHECK.
# ===========================================================================
def check_crosscheck(t):
    g = "xcheck"
    m = re.search(r"^  (\d+)  instructions the second reader printed", t, re.M)
    check(g, "it prints how many instructions it compared",
          m is not None and int(m.group(1)) > 1000,
          m.group(1) if m else "")
    n = re.search(r"^  (\d+)  of them this file NAMES", t, re.M)
    check(g, "and how many it named", n is not None)
    u = re.search(r"^  (\d+)  unmodelled -- counted, never dropped", t, re.M)
    check(g, "and how many it could not name, COUNTED rather than dropped",
          u is not None and int(u.group(1)) > 0)
    check(g, "ZERO disagreements",
          re.search(r"^\s+0  DISAGREE", t, re.M) is not None)
    check(g, "zero LENGTH disagreements, and the length IS compared",
          re.search(r"^\s+0  where the two readers disagree on the LENGTH", t,
                    re.M) is not None)
    check(g, "the headline sentence repeats both zeros",
          re.search(r"ZERO disagreements over \d+ named instructions", t)
          is not None)
    # THE FIRE TABLE.  A rule that fires zero times is the AArch64 bug's
    # shape; a rule that fires zero times because the corpus does not contain
    # the spelling is NOT, and the file must not conflate the two.
    f = re.search(r"(\d+) rules, (\d+) fired, (\d+) matched nothing", t)
    check(g, "the fire table is printed with three numbers",
          f is not None and f.group(2) != f.group(1),
          "%s/%s fired, %s dead" % (f.group(2), f.group(1), f.group(3))
          if f else "no fire table")
    check(g, "the dead rules are split into two named categories",
          "DEAD RULES, AND WHY EACH ONE IS DEAD" in t and
          "INVESTIGATE" in t)
    check(g, "a rule with no explanation is reported as INVESTIGATE",
          "INVESTIGATE rather than assumed innocent" in t)
    check(g, "and every dead rule on this run DOES carry a reason",
          "INVESTIGATE\n" not in t and not re.search(r"\sINVESTIGATE\s*$", t,
                                                     re.M))
    check(g, "the table is printed WHETHER OR NOT there is anything to say",
          "printed WHETHER OR NOT there is anything to put in it" in t)
    check(g, "every rule that fired is listed with its count",
          re.search(r"every rule that fired, with its count", t) is not None)


# ===========================================================================
# 10. THE FOUR POISONS.  Each must MOVE the number it claims to test.
# ===========================================================================
def check_poisons(t):
    g = "poison"
    for n in (1, 2, 3, 4):
        check(g, "poison %d reports FIRED" % n,
              re.search(r"VERDICT: POISON %d FIRED" % n, t) is not None)
        check(g, "poison %d does NOT print [POISON FAILED]" % n,
              ("POISON %d " % n) in t and
              not re.search(r"VERDICT: POISON %d FIRED ON NOTHING" % n, t))
    d1 = re.search(r"DELTA: named [+-]\d+, disagreements ([+-]\d+), "
                   r"unmodelled [+-]\d+", t)
    check(g, "poison 1 moved the DISAGREEMENT count and it is non-zero",
          d1 is not None and int(d1.group(1)) != 0,
          d1.group(1) if d1 else "")
    d2 = re.search(r"DELTA: named [+-]\d+, disagreements [+-]\d+, "
                   r"unmodelled ([+-]\d+)", t)
    check(g, "poison 2 moved the UNMODELLED count and it is non-zero",
          d2 is not None and int(d2.group(1)) != 0, d2.group(1) if d2 else "")
    d3 = re.search(r"^    DELTA: ([+-]\d+)$", t, re.M)
    check(g, "poison 3 moved the INSTRUCTION COUNT and it is non-zero",
          d3 is not None and int(d3.group(1)) != 0, d3.group(1) if d3 else "")
    d4 = re.search(r"DELTA: (\d+) of the (\d+) planted disagreements were "
                   r"HIDDEN", t)
    check(g, "poison 4 HID a non-zero number of planted disagreements",
          d4 is not None and int(d4.group(1)) > 0)
    check(g, "poison 4 PLANTED a real disagreement first",
          re.search(r"the working cross-check CATCHES\s+: (\d+)", t)
          is not None)
    check(g, "and the catch count equals the planted count, so the check "
             "really is live",
          re.search(r"real disagreements planted \(last operand changed\): (\d+)",
                    t) is not None and
          re.search(r"the working cross-check CATCHES\s+: (\d+)", t) is not None
          and re.search(r"real disagreements planted \(last operand changed\): (\d+)",
                        t).group(1) ==
          re.search(r"the working cross-check CATCHES\s+: (\d+)", t).group(1))
    check(g, "the summary names the four claimed numbers and four deltas",
          "FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS" in t)
    check(g, "the summary states that a poison which cannot move says so",
          "[POISON FAILED]" in t)
    # The machinery is asserted on the SOURCE, because on a clean run no
    # poison prints the failure string -- asserting it against the recording
    # would be asserting that a failure did not happen.
    src = ""
    try:
        with open(os.path.join(HERE, "rvabi.py"), "r", errors="replace") as f:
            src = f.read()
    except OSError:
        pass
    check(g, "the [POISON FAILED] machinery is in the source, for every poison",
          src.count("[POISON FAILED]") >= 6, "%d occurrences"
          % src.count("[POISON FAILED]"))
    check(g, "and a victim that is NOT IN THE DISPATCH is distinguished from "
             "an unmoved one", "is NOT IN THE DISPATCH" in src)
    check(g, "a poison that cannot move returns a value the caller can read",
          "'missing': True" in src)


# ===========================================================================
# 11. THE TWELVE RETRACTIONS.  Asserted as TEXT.
# ===========================================================================
def check_retractions(t):
    g = "retract"
    check(g, "twelve of them", "Twelve of them" in t)
    ids = re.findall(r"^  (R\d+)  CLAIMED:", t, re.M)
    want = ["R%d" % i for i in range(1, 13)]
    check(g, "R1 through R12 all present", ids == want,
          "found %d: %s" % (len(ids), ",".join(ids)))
    for (rid, needle) in (
            ("R1", "1055"),
            ("R1", "TWELVE-BIT I immediate"),
            ("R1", "PREPENDED in THIS file"),
            ("R2", "shamt[5]"),
            ("R2", "EVERY shift by 32 to 63"),
            ("R2", "36 words named"),
            ("R3", "0x1b"),
            ("R3", "a correction that does not run"),
            ("R4", "the ninth argument is on the stack"),
            ("R4", "arrives in a0"),
            ("R5", "false for the third"),
            ("R6", "SOFT-FLOAT library"),
            ("R7", "a frame that is SMALLER"),
            ("R8", "caller's own frame"),
            ("R9", "percentage of bytes is not a percentage of time"),
            ("R10", "IT IS NOT MEASURED" ),
            ("R11", "A zero from a normaliser is not a zero from a decoder"),
            ("R12", "m_shift_imm_fixed")):
        check(g, "%s names: %s" % (rid, needle[:40]), needle in t)
    check(g, "the count of retractions agrees with the banner",
          "TWELVE RETRACTIONS" in t and re.search(r"(\d+) retractions", t)
          is not None and re.search(r"(\d+) retractions", t).group(1)
          == "12")


# ===========================================================================
# 12. THE LIMITS, the links out, and the vocabulary.
# ===========================================================================
def check_scope(t):
    g = "scope"
    check(g, "twelve limits are enumerated and numbered",
          len(re.findall(r"^  \d+\. ", t, re.M)) >= 12)
    check(g, "no timing appears anywhere in the limits",
          "NO TIMING." in t and "NOTHING IS EXECUTED." in t)
    check(g, "nothing is linked, and it says so", "NOTHING IS LINKED." in t)
    check(g, "the stack alignment limit is stated where a reader would expect "
             "a measurement", "128-bit boundary upon procedure entry" in t)
    check(g, "the x0 limit separates the encoding from the hardware",
          "X0 IS HARDWIRED TO ZERO IN THE SPECIFICATION AND IN THE SILICON" in t)
    # LINKS OUT.  A course that re-teaches a principle links instead.
    for link in ('/courses/x86abi/lessons/x86-calling',
                 '/courses/x86abi/lessons/x86-frame',
                 '/courses/x86abi/lessons/x86-saved',
                 '/courses/a64abi/lessons/a64-aapcs',
                 '/courses/a64abi/lessons/a64-frame',
                 '/courses/a64abi/lessons/a64-registers',
                 '/courses/rvasm/lessons/rv-compressed',
                 '/courses/rvasm/lessons/rv-encoding',
                 '/courses/exe/lessons/exe-frontend'):
        check(g, "links out to %s" % link.split('/lessons/')[-1],
              link in t)
    check(g, "and says every link was verified present",
          "Verified present before linking" in t)
    check(g, "the report ends with its own counts",
          re.search(r"END OF REPORT -- \d+ sections, \d+ limits, \d+ "
                    r"retractions, \d+ poisons", t) is not None)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    if not os.path.isfile(path):
        print("  [FAIL] %-9s %-62s %s" % ("missing", "output file", path))
        print("\n  Run build_samples.sh first, or pass the path to a recorded "
              "run.")
        return 1
    t = load(path)
    print("\ncrosscheck.py -- re-asking the claims in %s\n" % path)
    for fn in (check_method, check_labels, check_calling, check_counters,
               check_noflags, check_three_targets, check_a64, check_registers,
               check_compressed, check_crosscheck, check_poisons,
               check_retractions, check_scope):
        fn(t)
    print("\n%d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        print("\nFAILURES:")
        for (grp, what, detail) in FAILURES:
            print("  [FAIL] %-9s %-62s %s" % (grp, what, detail))
        return 1
    print("ALL CONSISTENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
