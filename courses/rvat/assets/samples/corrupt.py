#!/usr/bin/env python3
"""corrupt.py -- prove that crosscheck.py's checks CAN FAIL.

A HARNESS WHOSE CHECKS HAVE NEVER BEEN SEEN TO FAIL IS A RUBRIC, and this
collection has retracted four of them for exactly that.  So this takes the
recorded report, corrupts it TWENTY-SIX WAYS, and asserts that each corruption
is CAUGHT.  It is the difference between a harness and a rubric.

The twenty-six cover the FOUR KINDS of assertion the harness claims to make,
and the four failures this harness's own history has already produced:

  EXACT     a bit pattern or a field position, edited in a table
  SHAPE     an ordering or a comparison, edited in the prose
  TEXT      a retraction's wording, deleted, de-negated or renumbered
  NEGATIVE  a claim the course must NOT make, added

The last group is the one that matters most, because a course can only fail it
by getting MORE confident, and the first version of this file could not tell
the difference between a harness that watches for over-claiming and one that
merely watches for under-claiming.

§KEEP§EVERY MUTATION IS ASSERTED TO HAVE CHANGED SOMETHING BEFORE THE HARNESS IS
RUN AGAINST IT, BECAUSE A MUTATION THAT MATCHES NOTHING PRODUCES A PASS -- AND A
PASS CAUSED BY A NO-OP IS THE MOST DANGEROUS KIND OF GREEN IN THIS WHOLE
COLLECTION.  §KEEP§THE FIRST VERSION OF THIS FILE HAD THREE OF THEM, AND ALL
THREE REPORTED "CAUGHT" FOR THE WRONG REASON UNTIL THE ASSERTION WAS ADDED.

WHY PYTHON AND NOT A SHELL SCRIPT: the mutations are REGULAR EXPRESSIONS over a
file with fixed-width tables, and expressing a regex through three layers of
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

RECORD = 'rvat.out'

# --------------------------------------------------------------------------
# THE TWENTY-SIX.  Each is (name, why, function(text) -> text).
# --------------------------------------------------------------------------
def sub(old, new, count=0):
    def f(t):
        assert old in t, 'no such text: %r' % (old[:60],)
        return t.replace(old, new) if count else t.replace(old, new)
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


def add_after(anchor, text):
    def f(t):
        assert anchor in t, 'no anchor: %r' % (anchor[:60],)
        return t.replace(anchor, anchor + text, 1)
    return f


EXACT = [
    ('amo-word-flipped',
     'amoadd.d 0x00b6352f -> 0x00b6353f, bit 12 of funct3 flipped -- the ONE '
     'BIT the whole section is about',
     sub('0x00b6352f', '0x00b6353f')),
    ('aq-bit-moved',
     'the aq XOR 0x04000000 -> 0x02000000, which is bit 25 and NOT bit 26',
     sub('THE SET OF aq XORs OVER THE WHOLE CORPUS: 0x04000000',
         'THE SET OF aq XORs OVER THE WHOLE CORPUS: 0x02000000')),
    ('width-xor-two-bits',
     '"12 of 12 pairs XOR to exactly 0x1000" -> 0x3000, two bits instead of one',
     sub('12 of 12 pairs XOR to exactly 0x1000.',
         '12 of 12 pairs XOR to exactly 0x3000.')),
    ('mask-xor-becomes-aq',
     'the eleven mask XORs 0x02000000 -> 0x04000000, which is the ACQUIRE bit',
     sub('11 pairs, 11 of them XOR to exactly 0x02000000, 0 exceptions.',
         '11 pairs, 11 of them XOR to exactly 0x04000000, 0 exceptions.')),
    ('zimm-reserved-moved',
     'zimm[10:8] "is 0b000 in all N" -> 0b001, i.e. the three reserved bits DO '
     'move, which is the claim R15 retracted',
     resub(r'zimm\[10:8\] is 0b000 in all \d+', 'zimm[10:8] is 0b001 in all 117')),
    ('vlenb-csr-one-digit',
     'the vlenb CSR 0xC22 -> 0xC21, one digit, and the decomposition with it',
     sub('csr = inst[31:20] = 0xc22', 'csr = inst[31:20] = 0xc21')),
    ('fence-word-becomes-another',
     '`fence r, r` 0x0220000f -> 0x0230000f, which is `fence r, rw`',
     sub('0x0220000f', '0x0230000f')),
    ('width-bit-position',
     'the width table says bit 11 of funct3 instead of bit 12',
     sub('0x00001000  1                bit 12 of funct3',
         '0x00001000  1                bit 11 of funct3')),
    ('vsetvli-instruction-renamed',
     'the vsetvl word 0x80c5f2d7 row now claims inst[31:30] = 0b00',
     sub('0x80c5f2d7   vsetvl     t0, a1, a2               0b10',
         '0x80c5f2d7   vsetvl     t0, a1, a2               0b00')),
]

SHAPE = [
    ('zero-count-inflated',
     'the ZERO becomes twenty-two, i.e. RISC-V has x86-64\'s prefix count and '
     'the whole second section is false',
     sub('0 instructions in the RISC-V corpus take a lock prefix',
         '22 instructions in the RISC-V corpus take a lock prefix')),
    ('march-sweep-row-deleted',
     'one -march row deleted, so the table is five rows and the comparison is '
     'not one letter',
     resub(r'^  rv64ima    9.*\n', '')),
    ('disagree-count-inflated',
     'the two readers now DISAGREE on 47 instructions, which is a failure '
     'presented as a result',
     resub(r'^\s+0  DISAGREE', '      47  DISAGREE')),
    ('unmodelled-line-deleted',
     'the UNMODELLED line deleted, which is precisely the failure a sibling '
     'course shipped when it watched only the agreement count',
     resub(r'^\s+\d+  unmodelled -- counted, never dropped\n', '')),
    ('corpus-incomplete-hidden',
     'the corpus-completeness check now says the corpus IS incomplete',
     sub('THE CORPUS IS INCOMPLETE: no.', 'THE CORPUS IS INCOMPLETE: yes.')),
    ('level-claim-flipped',
     '"-O1 DOES NOT VECTORISE" -> "-O1 VECTORISES", the OPPOSITE of the '
     'measured finding, de-negated mid-sentence while the number stays 0',
     sub('-O1 DOES NOT VECTORISE THIS CORPUS AT ALL',
         '-O1 VECTORISES THIS CORPUS AT WILL')),
    ('inherited-decoder-two-bits',
     'the SECTION 8 explanation of R1 says the inherited decoder reads TWO bits '
     'where it reads THREE -- the retraction itself is untouched, and the first '
     'version of the harness could not tell the difference',
     sub('WHICH IS inst[31:29] -- THREE BITS -- AND COMPARES',
         'WHICH IS inst[31:30] -- TWO BITS -- AND COMPARES')),
    ('section8-r1-corroboration',
     'the SAME sentence de-negated in the other direction -- "computes '
     'inst[31:29] -- THREE BITS --" -> "TWO BITS" in the SECTION rather than in '
     'the retraction',
     sub('WHICH IS inst[31:29] -- THREE BITS -- AND COMPARES',
         'WHICH IS inst[31:29] -- TWO BITS -- AND COMPARES')),
    ('poison-delta-zeroed',
     'poison 1\'s unmodelled delta zeroed, so the control moved nothing and '
     'still says FIRED',
     sub('DELTA: named -47, disagreements +0, unmodelled +47',
         'DELTA: named +0, disagreements +0, unmodelled +0')),
]

TEXT = [
    ('r5-denied',
     'R5 de-negated: the compiler DOES emit amoswap.w in place of the loop',
     sub('IT DOES NOT, AND THE CLAIM WAS WRONG',
         'IT DOES, AND THE CLAIM WAS RIGHT')),
    ('r7-denied',
     'R7 de-negated: the register group IS a scalar, which was the claim -- '
     'edited in the SECTION, where the retraction\'s own copy is untouched',
     sub('SO LMUL IS NOT A SCALAR AND IT IS NOT A WIDER REGISTER.  IT\n'
         '  IS AN ALIGNMENT CONSTRAINT ON A REGISTER ALLOCATOR',
         'SO LMUL IS A SCALAR AND IT IS A WIDER REGISTER.  IT\n'
         '  IS A SCALAR INSTEAD, WHICH IS WHAT A LOOP UNROLLS ON')),
    ('r7-denied-in-the-retraction',
     'and the SAME retraction de-negated in its OWN block, which is the copy '
     'the first version of the harness was reading',
     sub('IT IS AN ALIGNMENT CONSTRAINT, and the refusal is the evidence',
         'IT IS A SCALAR, and the refusal is the evidence')),
    ('r18-deleted',
     'R18 deleted outright, and a retraction that is quietly dropped is the one '
     'failure no number in the file can catch',
     resub_s(r'  R18  CLAIMED:.*?(?=\nTHE CLAIM THAT TIES)', '\n')),
    ('r9-softened',
     'R9 softened: "the same instruction AND the same fence PLUS another '
     'fence" -> "the same instruction", which is the true-but-incomplete claim '
     'R9 exists to name',
     sub('THEY ARE THE SAME INSTRUCTION AND THE SAME FENCE PLUS ANOTHER FENCE',
         'THEY ARE THE SAME INSTRUCTION AND NOTHING ELSE')),
    ('r13-flipped',
     'R13 flipped: fence.tso is a request for a STRONGER barrier',
     sub('SO FENCE.TSO IS A\n                REQUEST FOR A WEAKER BARRIER',
         'SO FENCE.TSO IS A\n                REQUEST FOR A STRONGER BARRIER')),
    ('r16-softened',
     'R16 softened: the zeroes are because the ASSEMBLER emits zeroes, which '
     'is the claim R16 retracted',
     sub('THEY HAVE ZEROES BECAUSE THE MANUAL REQUIRES THEM TO',
         'THEY HAVE ZEROES BECAUSE THE ASSEMBLER EMITS ZEROES')),
    ('r1-two-bits',
     'R1 de-negated: THREE bits -> TWO, which is the original error the '
     'retraction names',
     sub('it computes inst[31:29] -- THREE BITS -- and compares against',
         'it computes inst[31:29] -- TWO BITS -- and compares against')),
    ('retraction-renumbered',
     'R9 RENUMBERED to R19: the count is preserved and the order destroyed, '
     'which is why the ids are checked as well as the count',
     sub('  R9  CLAIMED:', '  R19  CLAIMED:')),
]

NEGATIVE = [
    ('speedup-invented',
     'a 6.31x speedup invented -- the claim this course\'s own section 1 says '
     'it has no hardware to make',
     sub('  NO TIMINGS and NO SPEEDUPS',
         '  The vector loop measures 6.31x against the scalar loop.  NO SPEEDUPS')),
    ('atomicity-claimed',
     'the AMO claimed to BE ATOMIC, i.e. the promise read as an observation',
     sub('  THE LOOP IS IN THE OUTPUT.',
         '  THE LOOP IS IN THE OUTPUT, AND THE AMO IS ATOMIC BECAUSE IT IS IN '
         'OPCODE 0101111.')),
    ('observation-claimed',
     'a reservation claimed to have been OBSERVED being held, which nothing on '
     'this host could have done',
     add_after('  THE RESERVATION ITSELF IS QUOTED',
               '  We observed a reservation being held on another hart.  ')),
    ('fence-observed-ordering',
     'a fence claimed to have ORDERED two stores, which is the other absence',
     sub('  AND WHAT THE COMPILER CHOSE, because the model being definitional',
         '  A fence was observed to order two stores on a real hart.  '
         'AND WHAT THE COMPILER CHOSE, because the model being definitional')),
    ('retired-link-added',
     'a retired id linked: /lessons/x86-atom, a PREFIX of the live x86-atomics, '
     'so the negative has to be a whole-segment match or this passes',
     sub('/courses/x86simd/lessons/x86-atomics',
         '/courses/x86simd/lessons/x86-atom')),
    ('cycle-count-invented',
     'a cycle count invented, which is the one number this course says it has '
     'no instrument for',
     sub('  1. NO TIMING.',
         '  1. NO TIMING, except that the loop takes 14 cycles.')),
]

GROUPS = [('A. EXACT -- a bit pattern or a field position, in a table', EXACT),
          ('B. SHAPE -- an ordering or a comparison, in the prose', SHAPE),
          ('C. TEXT -- a retraction deleted, de-negated or renumbered', TEXT),
          ('D. NEGATIVE -- a claim the course must NOT make, added', NEGATIVE)]


def run_harness(work, out_path):
    r = subprocess.run([sys.executable, 'crosscheck.py', out_path],
                       cwd=work, capture_output=True, text=True)
    return r.stdout


def main():
    work = tempfile.mkdtemp(prefix='rvat-corrupt-')
    try:
        shutil.copy(os.path.join(HERE, 'crosscheck.py'), work)
        shutil.copy(os.path.join(HERE, 'rvat.py'), work)
        # The harness finds rvdec.py by walking UP the tree, and a temp
        # directory has no sibling.  A CONTROL THAT CANNOT RUN IS NOT A CONTROL.
        sib = os.path.join(os.path.dirname(work), 'rvasm')
        if not os.path.exists(sib):
            os.symlink(os.path.join(HERE, '..', '..', 'rvasm'), sib)
        with open(os.path.join(HERE, RECORD), errors='replace') as f:
            base = f.read()

        caught = missed = errored = 0
        for title, group in GROUPS:
            print('\n== %s ==' % title)
            for name, why, fn in group:
                try:
                    t = fn(base)
                except AssertionError as e:
                    print('  [ERROR] %-28s %s' % (name, e))
                    errored += 1
                    continue
                path = os.path.join(work, 'corrupt.out')
                with open(path, 'w') as f:
                    f.write(t)
                out = run_harness(work, 'corrupt.out')
                n = len(re.findall(r'^  \[FAIL\]', out, re.M))
                if n == 0:
                    print('  [MISSED] %-28s %s' % (name, why))
                    missed += 1
                else:
                    print('  [CAUGHT] %-28s %d check(s) failed -- %s'
                          % (name, n, why))
                    caught += 1
                    if VERBOSE:
                        for ln in re.findall(r'^  \[FAIL\].*', out, re.M)[:3]:
                            print('           %s' % ln.strip())

        # THE EMPTY FILE, which is the failure that ACTUALLY HAPPENED here: the
        # first recorded rvat.out was 0 bytes and 557 checks were hidden behind
        # it.  §KEEP§A HARNESS THAT FAILS ALL ITS POSITIVE CHECKS ON AN EMPTY
        # FILE IS A HARNESS, AND THE ASSERTION BELOW IS WHY THE SHIPPED REPORT'S
        # SIZE IS CHECKED IN build_samples.sh.
        print('\n== E. the empty file, which is the one that actually happened ==')
        n = 0
        with open(os.path.join(work, 'empty.out'), 'w'):
            pass
        out = run_harness(work, 'empty.out')
        n = len(re.findall(r'^  \[FAIL\]', out, re.M))
        if n > 300:
            print('  [CAUGHT] %-28s %d check(s) failed -- a 0-byte report fails'
                  % ('rvat.out truncated', n))
            caught += 1
        else:
            print('  [MISSED] %-28s only %d check(s) failed, so an empty report'
                  % ('rvat.out truncated', n))
            print('           is nearly tolerated and a course could ship one.')
            missed += 1

        total = caught + missed + errored
        print('\n== the tally ==')
        print('  %d corruptions, %d caught, %d missed, %d errored'
              % (total, caught, missed, errored))
        if missed or errored:
            print('  SOMETHING IS NOT WATCHED, so a check in this file does not')
            print('  watch what it claims to, and the file is a rubric.')
            return 1
        print('  EVERY CORRUPTION WAS CAUGHT, so this is a harness.')
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)
        sib = os.path.join(os.path.dirname(work), 'rvasm')
        if os.path.islink(sib):
            os.unlink(sib)


if __name__ == '__main__':
    sys.exit(main())
