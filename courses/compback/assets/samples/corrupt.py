#!/usr/bin/env python3
"""corrupt.py -- prove that crosscheck.py's checks CAN FAIL.

A HARNESS WHOSE CHECKS HAVE NEVER BEEN SEEN TO FAIL IS A RUBRIC, and this
collection has retracted four of them for exactly that.  So this takes the
recorded report, corrupts it TWENTY-TWO WAYS, and asserts that each corruption
is CAUGHT.  It is the difference between a harness and a rubric.

The twenty-two cover the FOUR KINDS of assertion crosscheck.py claims to make:

  EXACT     a bit pattern or a field position, edited in a table
  SHAPE     an ordering or a comparison, edited in the prose
  TEXT      a retraction's wording, deleted, de-negated or renumbered
  NEGATIVE  a claim the course must NOT make, added

The last group is the one that matters most, because a course can only fail it
by getting MORE confident, and the first version of this file could not tell
the difference between a harness that watches for over-claiming and one that
merely watches for under-claiming.

§KEEP§EVERY MUTATION IS ASSERTED TO HAVE CHANGED SOMETHING BEFORE THE HARNESS
IS RUN AGAINST IT, BECAUSE A MUTATION THAT MATCHES NOTHING PRODUCES A PASS --
AND A PASS CAUSED BY A NO-OP IS THE MOST DANGEROUS KIND OF GREEN IN THIS WHOLE
COLLECTION. §KEEP§THE FIRST VERSION OF THIS FILE HAD TWO OF THEM, AND BOTH
REPORTED "CAUGHT" FOR THE WRONG REASON UNTIL THE ASSERTION WAS ADDED.

WHY PYTHON AND NOT A SHELL SCRIPT: the mutations are REGULAR EXPRESSIONS over
a file with fixed-width tables, and expressing a regex through three layers of
shell quoting is how a mutation ends up matching nothing.

Usage:  python3 corrupt.py          the tally
        python3 corrupt.py -v       and each check the corruption makes fail
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
VERBOSE = '-v' in sys.argv[1:]
RECORD = 'compback.out'
HARNESS = 'crosscheck.py'

# §KEEP§ THE RECORD IS READ ONCE AND NOT RE-READ PER MUTATION, §KEEP§ BECAUSE
# §KEEP§ A MUTATION THAT READS THE PRISTINE FILE AT CALL TIME IS A FUNCTION
# §KEEP§ WHOSE RESULT DEPENDS ON WHEN IT RAN.
_RECORD = ''
try:
    with open(os.path.join(HERE, RECORD), errors='replace') as _f:
        _RECORD = _f.read()
except Exception:
    pass


# --------------------------------------------------------------------------
# THE TWENTY-TWO.  Each is (name, why, group, function(text) -> text).
# --------------------------------------------------------------------------
def sub(old, new):
    def f(t):
        assert old in t, 'no such text: %r' % (old[:70],)
        return t.replace(old, new)
    return f


def resub(pat, rep):
    def f(t):
        new, n = re.subn(pat, rep, t, flags=re.M)
        assert n, 'pattern matched nothing: %r' % (pat,)
        return new
    return f


def resub_s(pat, rep):
    def f(t):
        new, n = re.subn(pat, rep, t, flags=re.M | re.S)
        assert n, 'pattern matched nothing: %r' % (pat,)
        return new
    return f


def kill_row(label):
    """Delete a whole table row identified by its leading label."""
    def f(t):
        rx = re.compile(r'^\s*%s.*$' % re.escape(label), re.M)
        new, n = rx.subn('', t)
        assert n, 'row not found: %r' % label
        return new
    return f


def after_header(header, col, new, nth=0):
    """Replace one column of the nth ROW AFTER a header line.

    §KEEP§ AND THIS EXISTS BECAUSE THREE OF THESE MUTATIONS ARE ABOUT ROWS
    §KEEP§ THAT ARE INDENTED ELEVEN SPACES AND ALIGNED WITH RUNS OF SPACES, §KEEP§
    §KEEP§ AND EVERY REGULAR EXPRESSION WRITTEN FOR THEM HAD TO ACCOUNT FOR
    §KEEP§ THE INDENT EXPLICITLY. §KEEP§ A HEADER-RELATIVE ROW COUNTER DOES NOT,
    §KEEP§ AND IT IS ALSO THE ONLY WAY TO EDIT THE *FIRST* ROW OF A TABLE
    §KEEP§ WITHOUT MATCHING THE HEADER ITSELF.
    """
    def f(t):
        lines = t.split('\n')
        seen = 0
        start = -1
        for i, l in enumerate(lines):
            if header in l:
                start = i + 1
                break
        assert start >= 0, 'header not found: %r' % header
        for i in range(start, len(lines)):
            if not lines[i].strip():
                continue
            if seen == nth:
                cols = lines[i].split()
                assert len(cols) > col, ('row has %d cols, wanted %d'
                                         % (len(cols), col))
                cols[col] = str(new)
                lines[i] = ' ' * (len(lines[i]) - len(lines[i].lstrip())) \
                    + ' '.join(cols)
                return '\n'.join(lines)
            seen += 1
        raise AssertionError('no row %d after %r' % (nth, header))
    return f


def edit_row(label, col, new):
    """Replace one whitespace-separated column of a labelled table row.

    §KEEP§ AND THE COLUMN IS COUNTED FROM THE LEFT OF THE ROW, §KEEP§ NOT FROM
    §KEEP§ THE RIGHT AND NOT BY ITS ALIGNMENT, §KEEP§ BECAUSE THE COLUMNS ARE
    §KEEP§ SPACE-SEPARATED AND THE ALIGNMENT IS WHATEVER THE FORMAT STRING
    §KEEP§ SAID. §KEEP§ THE FIRST VERSION OF THIS FUNCTION SPLIT ON RUNS OF
    §KEEP§ SPACES AND TOOK THE *LAST* FIELD -- §KEEP§ WHICH IS THE CHECKSUM IN
    §KEEP§ EVERY TABLE IN THE REPORT -- §KEEP§ SO FOUR OF THE FIVE MUTATIONS
    §KEEP§ BUILT WITH IT CHANGED THE CHECKSUM INSTEAD OF THE COLUMN THEY NAMED.
    """
    def f(t):
        out = []
        done = 0
        for line in t.split('\n'):
            m = re.match(r'^(\s*%s\s+)(.*)$' % re.escape(label), line)
            if m and done < 1:
                cols = m.group(2).split()
                assert len(cols) > col, ('row %r has %d columns, wanted %d'
                                         % (label, len(cols), col))
                cols[col] = str(new)
                line = m.group(1) + ' '.join(cols)
                done += 1
            out.append(line)
        assert done, 'row not found: %r' % label
        return '\n'.join(out)
    return f


CORS = (
    # --- EXACT: encodings, field positions, exact counts ---------------
    ('EXACT', 'the fused madd word is byte-swapped',
     'sec5', sub('0x9b000820', '0x9b000028')),

    ('EXACT', 'the add-immediate specimen word is edited',
     'sec5', edit_row('add   x0, x1, #0xfff', 1, '913ffc21')),

    ('EXACT', 'the movz specimen word is edited',
     'sec5', edit_row('movz  w10, #0x6', 1, '528000cb')),

    ('EXACT', 'one of the 7 encoder specimens is reported as NO',
     'sec5', resub(r'(add   x11, x12, x13, lsl #2\s+)(\w+)\s+(\w+)(\s+)yes',
                   r'\g<1>deadbeef deadbeef\g<4>NO')),

    ('EXACT', 'the two-reader word count is halved',
     'sec16', resub(r'Two readers over every word of the aarch64 leaf: (\d+) '
                    r'words,', 'Two readers over every word of the aarch64 '
                    r'leaf: 1 words,')),

    ('EXACT', 'the two-reader disagreement count is made non-zero',
     'sec16', resub(r'words, \d+ agree,\s*\n?\s*(\d+) disagree',
                    r'words, 4 agree, 5 disagree')),

    ('EXACT', 'the spill counts of two policies are made EQUAL, so the '
     'finding that they disagree disappears',
     'sec6', resub(r'(^  Chaitin colour\s+)(\d+)( spills)',
                   lambda m: '%s%s%s' % (m.group(1),
                                         re.search(r'linear scan\s+(\d+) '
                                                   r'spills', _RECORD).group(1),
                                         m.group(3)))),

    ('EXACT', 'a fire-table count is inflated so the three no longer add up',
     'sec16', resub(r'(\d+) rules, (\d+) fired,',
                    lambda m: '%s rules, %d fired,' % (m.group(1),
                                                       int(m.group(2)) + 1))),

    ('EXACT', 'the interference edge arithmetic is broken',
     'sec7', resub(r'closed (\d+), half-open (\d+), LOST (\d+)',
                   lambda m: 'closed %s, half-open %s, LOST %d' %
                   (m.group(1), m.group(2), int(m.group(3)) + 1))),

    # §KEEP§ THE ARM ROWS ARE NOW "A  0  1.00-1.25  <checksum>" -- THREE
    # §KEEP§ COLUMNS, NO TICKS, BECAUSE A TICK IS A READING OF HOW BUSY THE
    # §KEEP§ MACHINE WAS AND IS NOT A CLAIM. §KEEP§ SO THE CHECKSUM IS THE
    # §KEEP§ THIRD FIELD (INDEX 2). §KEEP§ ASKING FOR INDEX 3 HERE RAISES
    # §KEEP§ "row 'D' has 3 columns, wanted 3" AND THE SUITE REPORTS IT AS AN
    # §KEEP§ ERROR, §KEEP§ WHICH IS CORRECT BEHAVIOUR: §KEEP§AN ERROR MEANS THE
    # §KEEP§ MUTATION DID NOT LAND, §KEEP§ NOT THAT IT LANDED AND WAS MISSED,
    # §KEEP§ AND A SUITE THAT REPORTED A FAILED-TO-APPLY MUTATION AS CAUGHT
    # §KEEP§ WOULD BE COUNTING ITS OWN FAILURE AS A SUCCESS.
    ('EXACT', 'one of the four arms carries a different checksum',
     'sec10', edit_row('D', 2, '-1')),

    # --- SHAPE: orderings and comparisons ------------------------------
    ('SHAPE', 'the half-open coalescer is made to merge ZERO pairs, so the '
     'opposite-direction finding disappears',
     'sec7', after_header('merged(half)   UNSOUND(half)', 3, 0, nth=1)),

    ('SHAPE', 'the WITH-memory-dependencies schedule is made to look wrong',
     'sec8', resub(r'(WITH\s+height\s+\[[^\]]*\]\s+\d+\s+)correct',
                  r'\g<1>WRONG ANSWER')),

    ('SHAPE', 'the distinct-address kernel is made to look wrong',
     'sec8', resub_s(r'(the same schedule on DISTINCT addresses.*?)correct',
                     r'\g<1>WRONG ANSWER')),

    ('SHAPE', 'the ratio table is made monotonic in the level',
     'sec2', resub(r'  (O0|O1|O2|O3|Os)\s+(\d+)\s+(\d+)\s+[\d.]+',
                   lambda m: '  %s          %s          %s          9.999'
                   % (m.group(1), m.group(2), m.group(3)))),

    ('SHAPE', 'the poison-2 edge delta is flipped positive, so the poison '
     'still moved but moved the WRONG WAY',
     'poison', resub(r'DELTA: edges ([+-]\d+), checksum changed',
                    'DELTA: edges +15, checksum changed')),

    ('SHAPE', 'the poison-4 hidden count is set to zero',
     'poison', resub(r'DELTA: \d+ of the \d+ planted disagreements were HIDDEN',
                    'DELTA: 0 of the 9 planted disagreements were HIDDEN')),

    # --- TEXT: retractions, limits, scope lists ------------------------
    ('TEXT', 'one retraction is deleted entirely',
     'sec15', kill_row('R7  CLAIMED:')),

    ('TEXT', 'a retraction is renumbered, so the sequence has a gap',
     'sec15', sub('  R5  CLAIMED:', '  R9  CLAIMED:')),

    ('TEXT', 'a retraction loses its SOURCE line',
     'sec15', resub_s(r'(  R9  CLAIMED:.*?)\n        SOURCE: [^\n]*',
                      r'\g<1>')),

    ('TEXT', 'a CANNOT claim sentence is DE-NEGATED, which reverses its '
     'meaning without touching a word the check was written against',
     'sec14', resub(r'^(\s*\* That a schedule which drops a memory '
                    r'dependency is a rare mistake).*$',
                    r'\g<1> that has never once produced a wrong answer in '
                    r'this corpus')),

    ('TEXT', 'a CANNOT claim sentence is DELETED and replaced with a weaker '
     'one that keeps the same words',
     'sec14', resub(r'^\s*\* That the fingerprint in section 11 recovers '
                    r'the ALLOCATION.*$',
                    '    * That section 11 is a nice idea')),

    ('TEXT', 'a CAN claim sentence is given a second, stronger version',
     'sec14', sub('* That linear scan needs no graph and colouring does, '
                  'which is a ',
                  '* That linear scan needs no graph and colouring does and is '
                  'therefore strictly faster, which is a ')),

    # --- NEGATIVE: claims the course must NOT make ---------------------
    ('NEGATIVE', 'the course claims an absolute CYCLE count',
     'negative', sub('NO EVENT COUNTER', 'exactly 4 cycles per spill, '
                                       'NO EVENT COUNTER')),

    ('NEGATIVE', 'the course claims to have beaten clang',
     'negative', sub('THE SELECTOR, RUN', 'AND IT BEATS clang, THE SELECTOR, '
                                        'RUN')),

    ('NEGATIVE', 'the course claims AArch64 code ran',
     'negative', sub('* aarch64-linux-gnu COMPILES AND CANNOT RUN.',
                     '* aarch64-linux-gnu AArch64 instructions was run.')),

    ('NEGATIVE', 'the course claims a RISC-V speedup',
     'negative', sub('NO EVENT COUNTER',
                     'a RISC-V speedup of 1.4x, NO EVENT COUNTER')),

    ('NEGATIVE', 'a limit is deleted, so the scope list is one shorter than '
     'the manifest claims',
     'sec13', kill_row('1. no SSA construction')),
)


def run_harness(path):
    p = subprocess.run([sys.executable, os.path.join(HERE, HARNESS), path],
                       capture_output=True, text=True)
    return p.returncode != 0, p.stdout


def main():
    src = os.path.join(HERE, RECORD)
    if not os.path.isfile(src):
        print("corrupt: %s is not there." % RECORD)
        return 2

    # The control: the pristine recording MUST pass, or nothing below means
    # anything.  A corruption suite run against a failing artifact reports
    # every corruption as "caught" for the wrong reason.
    base_fail, base_out = run_harness(src)
    if base_fail:
        print("corrupt: THE PRISTINE RECORDING ALREADY FAILS THE HARNESS.")
        print("           Every corruption below would be reported as caught")
        print("           for the wrong reason, so the suite refuses to run.")
        print("")
        for line in base_out.splitlines():
            if 'FAIL' in line:
                print("           " + line)
        return 2
    print("corrupt: the pristine recording PASSES the harness, so a failure "
          "below")
    print("        can only have come from the corruption.\n")

    tmp = tempfile.mkdtemp(prefix='cbcorrupt')
    caught = missed = errored = 0
    try:
        for (grp, name, _sect, fn) in CORS:
            with open(src, errors='replace') as f:
                t = f.read()
            try:
                bad = fn(t)
            except (AssertionError, re.error) as e:
                errored += 1
                print("  [ERROR] %-9s %-58s %s" % (grp, name[:58], e))
                continue
            # §KEEP§ THE NO-OP ASSERTION: A MUTATION THAT CHANGED NOTHING
            # §KEEP§ PRODUCES A PASS IN THE HARNESS AND A "CAUGHT" HERE, AND
            # §KEEP§ THAT IS THE MOST DANGEROUS LINE IN THIS FILE.
            if bad == t:
                errored += 1
                print("  [ERROR] %-9s %-58s the mutation was a NO-OP"
                      % (grp, name[:58]))
                continue
            path = os.path.join(tmp, 'c.out')
            with open(path, 'w') as f:
                f.write(bad)
            failed, out = run_harness(path)
            if failed:
                caught += 1
                first = ''
                for line in out.splitlines():
                    if 'FAIL' in line and 'PASS' not in line:
                        first = line.strip()[:58]
                        break
                print("  [%s] %-9s %-58s %s"
                      % ('PASS' if failed else 'MISS', grp, name[:58], first))
                if VERBOSE:
                    for line in out.splitlines():
                        if 'FAILED' in line:
                            print("            " + line.strip()[:70])
            else:
                missed += 1
                print("  [MISS] %-9s %-58s THE HARNESS DID NOT NOTICE"
                      % (grp, name[:58]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    n = len(CORS)
    print("")
    print("corrupt: %d corruptions, %d caught, %d missed, %d errored"
          % (n, caught, missed, errored))
    if missed or errored:
        print("")
        print("§KEEP§A CORRUPTION SUITE THAT MISSES ONE IS NOT A SUITE, IT IS A")
        print("§KEEP§LIST. §KEEP§AND §KEEP§AN ERROR IS WORSE THAN A MISS, BECAUSE")
        print("§KEEP§AN ERROR IS A MUTATION THAT DID NOT CHANGE ANYTHING AND")
        print("§KEEP§REPORTED A PASS FOR IT.")
        return 1
    print("ALL CAUGHT: every corruption was detected by the harness")
    return 0


if __name__ == '__main__':
    sys.exit(main())