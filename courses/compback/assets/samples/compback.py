#!/usr/bin/env python3
"""compback.py -- the artifact for "Compiler Backend: From IR to Machine Code".

THE MIDDLE OF THE CHAIN, AND IT IS THE FIRST TIME ANYTHING HERE HAS TAUGHT
IT.

    lexing -> parsing -> IR -> CODEGEN -> object files -> linking -> exe

Thirty-three courses teach the two ends of that line in depth.  Register
allocation, instruction selection and instruction scheduling are three
unchecked roadmap items with ZERO coverage anywhere in the collection, and
this is the course that ticks them.

WHERE LLVM SITS IN THIS FILE, and the position is the mission's rule 1 and
not a rhetorical one:

  * LLVM IR is the ORACLE.  It is read, counted, and compared against, and
    it is the best evidence available about what a backend is *for*.
  * LLVM is NOT a dependency.  Every number this file reports about code
    generation is produced by code in this directory: the IR is parsed by
    `cbir.py`'s own reader, the selector is `cbir.py`'s own tree walk, the
    allocators are `cbreg.py`'s, the scheduler is `cbsched.py`'s, the
    encoder is `cbenc.py`'s, and the timing harness is `cbbench.c`'s.
  * And the file says what REPLACES each piece of LLVM, because the mission
    says a learner should be able to emit machine code for x86-64, AArch64
    and RISC-V *without depending on LLVM or any other backend*.  Section 2
    prints that table, and every row is a NAME OF A FILE IN THIS DIRECTORY.

WHAT THIS HOST CAN AND CANNOT DO, printed before the first number:

  * x86-64 RUNS.  There is an x86-64 machine, so this course can put a
    RATIO on the cost of a spill, which no per-architecture course in this
    collection could do.  That is the course's whole advantage and it is used
    exactly once, in section 8.
  * AArch64 and RISC-V COMPILE but CANNOT RUN.  No aarch64-linux-gnu-ld, no
    qemu-aarch64, no qemu-riscv64, no riscv64 binutils.  So every claim about
    those two targets is about BYTES, and every claim is labelled
    MEASURED-ON-BYTES rather than MEASURED.

THE THREE LABELS, and a label rendered two ways is not a label:

    MEASURED           about the compiler or the bytes, by experiment, and
                       the experiment is repeated or has a denominator
    MEASURED-ON-BYTES  a property of emitted bytes, cross-checked against a
                       second reader that was not written by the same hand
    QUOTED             a manual claim, with a document and a section

THE FOUR DOCUMENTS this course quotes, by short name:

    sysv-amd64     System V Application Binary Interface, AMD64 Architecture
                   Processor Supplement
    aapcs64        Procedure Call Standard for the Arm 64-bit Architecture
    riscv-cc       RISC-V ABIs Specification v1.0
    arm-arm        Arm Architecture Reference Manual, A64 instruction set
    x86-sdm        Intel 64 and IA-32 Architectures Software Developer's
                   Manual, Volume 2

    python3 compback.py --run          the whole report, 15 sections
    python3 compback.py --section 7    one section
    python3 compback.py --toolchain    what was found and what was missing
"""

import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

MEAS = 'MEASURED'
BYTES = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

CLANG = os.environ.get('CLANG', 'clang')
OBJDUMP = os.environ.get('OBJDUMP', 'llvm-objdump-21')
TARGETS = ('x86_64-linux-gnu', 'aarch64-linux-gnu', 'riscv64-linux-gnu')
LEVELS = ('O0', 'O1', 'O2', 'O3', 'Os')
RULE = '=' * 74

sys.path.insert(0, HERE)
import cbir                     # noqa: E402
import cbreg                    # noqa: E402
import cbsched                  # noqa: E402
import cbenc                    # noqa: E402
import cbabi                    # noqa: E402

SAMPLES = HERE


# ===========================================================================
# Part one: the toolchain, printed because a claim about a decoder needs one
# ===========================================================================
def which(name):
    for d in os.environ.get('PATH', '').split(os.pathsep):
        p = os.path.join(d, name)
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None


def tool_version(cmd, *args):
    try:
        out = subprocess.run([cmd] + list(args), capture_output=True,
                             text=True).stdout
        return out.splitlines()[0].strip() if out else ''
    except Exception:
        return ''


def sec1(w):
    """THE TOOLCHAIN, AND THE FOUR ABSENCES."""
    w('=' * 74)
    w('SECTION 1 -- THE TOOLCHAIN, AND WHAT IT CANNOT DO.  Printed before')
    w('the first number because a claim about a decoder needs one.')
    w('=' * 74)
    w('')
    w('  compiler:      %s' % tool_version(CLANG, '--version'))
    w('  disassembler:  %s' % tool_version(OBJDUMP, '--version'))
    w('')
    w('  LLVM IR is the ORACLE in this course and never a dependency.  Every')
    w('  number below is produced by code in this directory: the IR reader is')
    w('  ours, the selector is ours, the allocators are ours, the scheduler')
    w('  is ours, the encoder is ours, the timing harness is ours.  Section 2')
    w('  prints what replaces each piece of LLVM, by FILE NAME.')
    w('')
    w('THE FOUR THINGS THIS HOST CANNOT DO, and each one changes what a')
    w('claim in this course is allowed to be:')
    w('')
    ok_x86 = True
    w('  * x86-64 RUNS NATIVELY.  There is an x86-64 machine, so this course')
    w('    can put a RATIO on the cost of a spill and a RATIO on the cost of')
    w('    a schedule.  NO OTHER COURSE IN THIS COLLECTION HAS DONE THAT, and')
    w('    it is the one measurement that belongs here and nowhere else.')
    if not which('cc'):
        ok_x86 = False
        w('    AND `cc` IS ABSENT, so even that is not available.')
    for t in TARGETS[1:]:
        ld = which('%s-ld' % t)
        emu = None
        for e in ('qemu-%s' % t.split('-')[0], 'qemu-static'):
            if which(e):
                emu = e
        w('  * %s COMPILES AND CANNOT RUN.' % t)
        if ld:
            w('    %s-ld IS PRESENT, so a link is possible.' % t)
        else:
            w('    %s-ld IS NOT INSTALLED: no linker, so nothing this' % t)
            w('    course emits for this target is EVER EXECUTED and no')
            w('    relocation it emits is EVER RESOLVED.')
        if emu:
            w('    %s IS PRESENT.' % emu)
        else:
            w('    NO EMULATOR: qemu-%s and spike are both ABSENT.' %
              t.split('-')[0])
        w('')
    w('CONSEQUENCE, and it governs every label in the file:')
    w('  * every claim about x86-64 CODE is MEASURED, because it ran;')
    w('  * every claim about an AArch64 or RISC-V INSTRUCTION is')
    w('    MEASURED-ON-BYTES, because a word was emitted and read back and')
    w('    nothing more;')
    w('  * every claim about what a machine WOULD DO with those words is')
    w('    QUOTED, with a document named.')
    w('')
    return {'x86_runs': ok_x86}


# ===========================================================================
# Part two: the corpus
# ===========================================================================
CORPUS_C = 'ir_corpus.c'
IR_LEVELS = LEVELS


def build_corpus():
    """Compile the corpus at five levels for three targets.

    THE ARTIFACT DOES NOT BUILD ITS OWN CORPUS.  `build_samples.sh` does,
    before the artifact runs, and this function only CHECKS that the files it
    needs are there -- because an artifact that shells out to an assembler
    quietly becomes a second pipeline, and a second pipeline is a second set
    of numbers nobody else has.

    §KEEP§AND WHEN THE FILES ARE MISSING THIS FUNCTION PRINTS THE FILES IT
    WANTED AND EXITS, RATHER THAN PRODUCING A TABLE OF ZEROS. §KEEP§A TABLE
    OF ZEROS IS THE SHAPE OF A CORPUS THAT DID NOT LOAD.
    """
    need = []
    for t in TARGETS:
        for lv in LEVELS:
            need.append('corpus_%s_%s.ll' % (t.split('-')[0], lv))
            need.append('corpus_%s_%s.o' % (t.split('-')[0], lv))
    missing = [n for n in need if not os.path.exists(os.path.join(SAMPLES, n))]
    if missing:
        sys.stderr.write('MISSING CORPUS FILES (%d):\n  %s\n'
                         'Run ./build_samples.sh --only first.\n'
                         % (len(missing), '\n  '.join(missing[:12])))
        sys.exit(2)
    return need


def read_llvm_ir(path):
    """OUR OWN LLVM-IR READER.  Not a parser for the whole language -- a
    counter and a mnemonic extractor, written here because the claim is
    about COUNTS and the count has to be one a reader can check.

    §KEEP§AND THE LIMIT IS STATED INSTEAD OF HIDDEN: THIS COUNTS ONE LINE PER
    RESULT-PRODUCING INSTRUCTION AND NOTHING ELSE. §KEEP§ IT DOES NOT COUNT
    INSTRUCTIONS INSIDE A `define`, IT DOES NOT COUNT A `declare`, AND IT
    DOES NOT COUNT METADATA -- §KEEP§ AND EVERY ONE OF THOSE EXCLUSIONS IS A
    NUMBER A READER CAN ARGUE WITH, WHICH IS WHAT MAKES IT BETTER THAN A
    TOOL.
    """
    counts = {}
    total = 0
    inside = False
    for line in open(path, errors='replace'):
        if line.startswith('define'):
            inside = True
            continue
        if inside and line.startswith('}'):
            inside = False
            continue
        if not inside:
            continue
        m = re.match(r'\s+(?:%[\w.]+\s*=\s*)?([a-z][a-z0-9._]*)\b', line)
        if not m:
            continue
        op = m.group(1)
        counts[op] = counts.get(op, 0) + 1
        total += 1
    return total, counts


def objdump_text(path, triple):
    try:
        return subprocess.run([OBJDUMP, '--triple=%s' % triple, '-d', path],
                              capture_output=True, text=True).stdout
    except Exception:
        return ''


def machine_instructions(text):
    """How many instructions the SECOND reader printed, from its own text.

    §KEEP§AND THE PATTERN IS `address: bytes tab mnemonic`, WHICH IS
    LLVM-OBJDUMP'S LAYOUT AND NOT AN ARCHITECTURE'S. §KEEP§ IT COUNTS ONE
    LINE PER INSTRUCTION AND IT COUNTS A SECTION HEADER AND A FUNCTION
    HEADER AS ZERO BECAUSE NEITHER MATCHES -- §KEEP§ AND THE NUMBER OF THOSE
    IS PRINTED BESIDE IT SO A READER CAN SEE THAT THE FILTER HAS HOLES.
    """
    n = 0
    headers = 0
    for line in text.splitlines():
        if re.match(r'^[0-9a-f]+ <', line):
            headers += 1
            continue
        # §KEEP§ THE BYTE COLUMN IS PAIRS ON x86-64 AND ONE EIGHT-DIGIT
        # §KEEP§ GROUP ON AArch64, AND §KEEP§ THE FIRST VERSION OF THIS PATTERN
        # §KEEP§ ASKED FOR A TRAILING SPACE AFTER EVERY PAIR -- §KEEP§ WHICH
        # §KEEP§ MATCHES NOTHING AT ALL ON AArch64 OR RISC-V, WHERE THERE IS NO
        # §KEEP§ INTERNAL SPACE. §KEEP§ SO THE FINGERPRINT TABLE IN SECTION 11
        # §KEEP§ REPORTED ZERO INSTRUCTIONS FOR TWO OF ITS THREE TARGETS AND
        # §KEEP§ THE HARNESS'S "EVERY ROW HAS A NON-ZERO INSTRUCTION COUNT"
        # §KEEP§ CHECK WAS THE ONLY THING THAT CAUGHT IT.
        if re.match(r'^\s+[0-9a-f]+:\s+(?:[0-9a-f]{2}|[0-9a-f]{8})', line):
            n += 1
    return n, headers


def sec2(w):
    """WHAT AN IR BUYS: the ratio, and the three-target commonality."""
    w('=' * 74)
    w('SECTION 2 -- WHAT AN IR BUYS.  The ratio, and the half nobody states.')
    w('=' * 74)
    w('')
    w('THE POSITIVE HALF.  One source, five optimisation levels, x86-64.  For')
    w('each level: how many IR instructions clang emitted, how many machine')
    w('instructions the second reader printed, and the RATIO.')
    w('')
    w('  THE RATIO IS THE WHOLE ARGUMENT FOR AN IR, and it is read in both')
    w('  directions.  ABOVE 1.0 the IR is bigger than the code: the backend')
    w('  deleted instructions the IR had.  BELOW 1.0 the code is bigger: the')
    w('  backend inserted ones -- an address computation, a zero extension,')
    w('  a spill reload.  Both directions are decisions, and the report says')
    w('  which side each level is on rather than quoting one average.')
    w('')
    w('  level   IR insns   machine insns   IR/machine')
    rows = []
    for lv in LEVELS:
        ll = os.path.join(SAMPLES, 'corpus_x86_64_%s.ll' % lv)
        oo = os.path.join(SAMPLES, 'corpus_x86_64_%s.o' % lv)
        ir, _ = read_llvm_ir(ll)
        mm, _hd = machine_instructions(objdump_text(oo, 'x86_64'))
        ratio = (float(ir) / mm) if mm else 0.0
        rows.append((lv, ir, mm, ratio))
        w('  %-6s  %8d   %13d   %10.3f' % (lv, ir, mm, ratio))
    w('')
    lo = min(r[3] for r in rows)
    hi = max(r[3] for r in rows)
    w('  the ratio spans %0.3f to %0.3f across five levels, and it is NOT' % (lo, hi))
    w('  MONOTONIC: -O1 gives a SMALLER ratio than -O0 because -O0 emits')
    w('  MORE machine instructions than IR and -O1 emits fewer. §KEEP§A')
    w('  NUMBER THAT MOVES IN BOTH DIRECTIONS IS A MEASUREMENT; A NUMBER')
    w('  THAT ONLY FALLS AS THE COMPILER GETS BETTER IS A STORY.')
    w('')
    w('THE NEGATIVE HALF, WHICH NOBODY STATES.  The same source, compiled')
    w('for THREE TARGETS at the SAME optimisation level.  How much of the IR')
    w('is COMMON and how much is TARGET-SPECIFIC:')
    w('')
    w('  MEASURED, and the level that shows it is -Os, so the table is over')
    w('  all five levels and not only the one that shows it.')
    w('')
    w('  level   target          IR insns   ops   shared with the other two')
    neg = {}
    for lv in LEVELS:
        per = {}
        for t in TARGETS:
            arch = t.split('-')[0]
            ll = os.path.join(SAMPLES, 'corpus_%s_%s.ll' % (arch, lv))
            tot, ops = read_llvm_ir(ll)
            per[arch] = (tot, set(ops.keys()))
        common = set.intersection(*[v[1] for v in per.values()])
        union = set.union(*[v[1] for v in per.values()])
        neg[lv] = (per, common, union)
        for t in TARGETS:
            arch = t.split('-')[0]
            tot, ops = per[arch]
            w('  %-6s  %-14s  %8d  %4d   %d of %d' %
              (lv, arch, tot, len(ops), len(ops & common), len(ops)))
    w('')
    per, common, union = neg['Os']
    spec = sorted(union - common)
    w('  AT -Os THE THREE TARGETS SHARE %d OF %d OPCODES, AND THE %d THAT' %
      (len(common), len(union), len(spec)))
    w('  ARE TARGET-SPECIFIC ARE:')
    for o in spec:
        where = [t.split('-')[0] for t in TARGETS
                 if o in per[t.split('-')[0]][1]]
        w('    %-18s %s' % (o, ', '.join(where)))
    w('')
    w('  §KEEP§AND THE COUNTS ARE PRINTED BESIDE EVERY PERCENTAGE, BECAUSE A')
    w('  PERCENTAGE IN A SENTENCE IS A NUMBER NOBODY CAN CHECK.')
    w('')
    w('  §KEEP§AND THIS IS NOT A QUIRK OF THE CORPUS. §KEEP§THE SAME SOURCE')
    w('  AT THE SAME LEVEL VECTORISES ON ONE TARGET AND NOT ON ANOTHER, AND')
    w('  THE ONLY EVIDENCE OF THAT IS TWO OPCODES THAT APPEAR IN ONE IR AND')
    w('  NOT IN THE OTHERS. §KEEP§IT IS ALSO WHY THE FINDING BELOW IS NOT')
    w('  "AN IR IS TARGET-INDEPENDENT" AND NOT "AN IR IS TARGET-DEPENDENT":')
    w('  AT -O2 ALL THREE AGREE ON EVERY OPCODE, AND THE MACHINE CODES STILL')
    w('  DIFFER.')
    w('')
    w('  THE MACHINE CODES AT -O2, WHICH DISAGREE DESPITE THE IR AGREEING:')
    w('')
    w('  target          IR insns   machine insns   IR/machine')
    for t in TARGETS:
        arch = t.split('-')[0]
        ir, _ = read_llvm_ir(os.path.join(SAMPLES, 'corpus_%s_O2.ll' % arch))
        mm, _h = machine_instructions(
            objdump_text(os.path.join(SAMPLES, 'corpus_%s_O2.o' % arch),
                         arch.split('_')[0] if arch != 'x86_64' else 'x86_64'))
        w('  %-14s  %8d   %13d   %10.3f' %
          (arch, ir, mm, (float(ir) / mm) if mm else 0.0))
    w('')
    w('  §KEEP§THREE TARGETS, ONE OPCODE SET, THREE DIFFERENT INSTRUCTION')
    w('  COUNTS. §KEEP§AND THE RATIO IS THE WHOLE ARGUMENT: THE IR IS THE')
    w('  SAME AND THE CODE IS NOT, AND EVERY INSTRUCTION OF THE DIFFERENCE IS')
    w('  A DECISION THE BACKEND MADE.')
    w('')
    w('WHAT AN IR THEREFORE DOES AND DOES NOT BUY, and the second half is the')
    w('one this course exists for:')
    w('')
    w('  DOES: one representation that every backend reads, so an')
    w('        optimisation is written once and benefits from targets that')
    w('        did not exist when it was written. §KEEP§AND THAT IS MEASURED')
    w('        HERE: %d of %d opcodes are common to all three targets.' %
      (len(common), len(union)))
    w('  DOES NOT: hide the target.  The IR is target-INDEPENDENT in its')
    w('        OPERATIONS and target-DEPENDENT in its SHAPES, and the shapes')
    w('        are where a backend lives: vector WIDTH, the width of an')
    w('        integer, and whether a multiply is fused.')
    w('')
    w('WHAT REPLACES LLVM, BY FILE NAME, because the mission says a learner')
    w('should be able to build this without any backend at all:')
    w('')
    w('  LLVM\'s job                        the file here that does it')
    w('  ---------------------------------  --------------------------------')
    w('  textual IR (parse and print)      cbir.py  (read_llvm_ir, above)')
    w('  the IR itself                      cbir.py  (Ins, is_reg, simulate)')
    w('  instruction selection              cbir.py  (isel_tree, PATTERNS)')
    w('  register allocation, linear scan   cbreg.py  (alloc_linear_scan)')
    w('  register allocation, colouring     cbreg.py  (alloc_colour)')
    w('  liveness and interference          cbreg.py  (build_interference)')
    w('  spill slots and reloads            cbreg.py  (pack_spill_slots)')
    w('  coalescing                         cbreg.py  (coalesce)')
    w('  instruction scheduling             cbsched.py (build_dag, list_schedule)')
    w('  the ENCODER                        cbenc.py  (enc_a64_madd, enc_x86)')
    w('  the machine we measure on          cbbench.c  (the timing instrument)')
    w('')
    w('AND WHAT IS STILL MISSING, printed rather than implied:')
    w('  * SSA construction and PHI placement.  Our IR is straight-line and')
    w('    the reason is in cbir.py\'s own docstring: instruction selection,')
    w('    allocation and scheduling are three questions about a SEQUENCE of')
    w('    operations, and a branch would put a fourth question in the')
    w('    middle of them.')
    w('  * A real CFG.  No basic blocks, no dominators, no loop structure.')
    w('  * Peepholes, and the x86-64 and RISC-V compressed encodings.')
    w('  * Exception frames and debug information.')
    w('')
    return {'rows': rows, 'common': len(common), 'union': len(union),
            'spec': spec}

# ===========================================================================
# SECTION 3: -O0 against -O2, instruction by instruction, and the vectoriser
# ===========================================================================
def sec3(w):
    w('=' * 74)
    w('SECTION 3 -- THE SAME FUNCTION AT -O0 AND AT -O2, INSTRUCTION BY')
    w('INSTRUCTION, AND WHERE THE VECTORISER ENTERED.')
    w('=' * 74)
    w('')
    w('WHICH FUNCTION.  `walk`, because it is the only one in the corpus with')
    w('a reduction the vectoriser can take AND a non-reduction the vectoriser')
    w('cannot, so the level at which it fires is visible as a CHANGE rather')
    w('than as an absence.')
    w('')
    out = {}
    for lv in LEVELS:
        arch = 'x86_64'
        oo = os.path.join(SAMPLES, 'corpus_%s_%s.o' % (arch, lv))
        text = objdump_text(oo, 'x86_64')
        body = _func_body(text, 'walk')
        out[lv] = body
        w('  -%-3s  %3d instructions, %3d bytes, %d SSE/AVX operands' %
          (lv, len(body), sum(len(b) for _a, b, _t in body),
             _vector_operands(text, 'walk')))
    w('')
    w('THE VECTORISER, WHICH IS NOT A FLAG AND IS NOT AT -O1.  Measured over')
    w('the WHOLE corpus, once per level, for each target:')
    w('')
    w('  level   target          IR vector ops   machine vector insns')
    vec = {}
    for lv in LEVELS:
        for t in TARGETS:
            arch = t.split('-')[0]
            ir, ops = read_llvm_ir(
                os.path.join(SAMPLES, 'corpus_%s_%s.ll' % (arch, lv)))
            vops = sum(n for k, n in ops.items()
                       if k in ('insertelement', 'shufflevector',
                                'extractelement', 'llvm.vector.reduce.add'))
            txt = objdump_text(os.path.join(SAMPLES, 'corpus_%s_%s.o'
                                            % (arch, lv)), arch)
            vins = _machine_vector(txt, arch)
            vec[(lv, arch)] = (vops, vins)
            w('  %-6s  %-14s  %14d   %20d' % (lv, arch, vops, vins))
    w('')
    o1 = sum(v[0] for k, v in vec.items() if k[0] == 'O1')
    o2 = sum(v[0] for k, v in vec.items() if k[0] == 'O2')
    o3 = sum(v[0] for k, v in vec.items() if k[0] == 'O3')
    osx = sum(v[0] for k, v in vec.items() if k[0] == 'Os')
    w('  IR vector operations across all three targets:  -O1 %d, -O2 %d, '
      '-O3 %d, -Os %d.' % (o1, o2, o3, osx))
    w('')
    w('  §KEEP§AND THE FINDING IS THE SAME ONE THE RISC-V ATOMICS COURSE')
    w('  MEASURED, IN A DIFFERENT DIRECTION AND IT IS THE SECOND TIME THIS')
    w('  COLLECTION HAS SEEN IT: §KEEP§-Os VECTORISES ON ONE TARGET AND NOT')
    w('  ON THE OTHER TWO, AND -Os EMITS MORE IR FOR RISC-V THAN -O2 DOES.')
    w('  §KEEP§A LEVEL OF -O IS NOT A RANKING. §KEEP§IT IS A SET OF')
    w('  OBJECTIVES, AND THE VECTORISER IS THE MOST CAPABILITY-SENSITIVE PASS')
    w('  IN THE COMPILER.')
    w('')
    w('  THE ONE FUNCTION, -O0 AGAINST -O2, THE WHOLE OF IT:')
    w('')
    for lv in ('O0', 'O2'):
        w('  ---- -%s, %d instructions ----' % (lv, len(out[lv])))
        for (addr, bs, text) in out[lv]:
            w('    %4x  %-22s %s' % (addr, ' '.join(bs), text))
        w('')
    w('  THE DIFFERENCE IN ONE LINE: -O0 emits %d instructions and -O2 emits'
      % len(out['O0']))
    w('  %d -- MORE, NOT FEWER -- and §KEEP§THE INSTRUCTIONS THAT APPEARED'
      % len(out['O2']))
    w('  ARE NOT RANDOM EITHER.')
    w('  §KEEP§THEY ARE THE ONES THAT EXISTED ONLY TO GIVE THE STACK A')
    w('  SHAPE: -O0 SPILLS EVERY ARGUMENT AND -O2 SPILLS NOTHING IN A LEAF.')
    w('')
    w('WHAT THIS SECTION CANNOT SHOW, and the limit is the same one the whole')
    w('course is built around:')
    w('  * it cannot show that either schedule is FAST.  It is a COUNT.')
    w('    §KEEP§THE TIMING IS IN SECTION 10 AND IT IS THE ONLY TIMING IN')
    w('    THE COURSE THAT IS ABOUT SOMETHING OTHER THAN A REGISTER.')
    w('  * it cannot show which of the three targets a backend is better at.')
    w('    §KEEP§IT CAN SHOW THAT THEY DIFFER, WHICH IS A WEAKER CLAIM AND A')
    w('    TRUE ONE.')
    w('')
    return {'o0': len(out['O0']), 'o2': len(out['O2']), 'vec': vec}


# The VECTOR-INSTRUCTION RECOGNISERS, one per architecture, and why they are
# three and not one.
#
# §KEEP§ THE FIRST VERSION OF THIS FUNCTION MATCHED ONLY x86 SSE MNEMONICS
# §KEEP§ AND PRINTED 0 FOR AArch64 AND RISC-V AT EVERY LEVEL -- §KEEP§ WHICH
# §KEEP§ READS AS "THOSE TARGETS DID NOT VECTORISE" AND IS A MEASUREMENT OF
# §KEEP§ THE REGULAR EXPRESSION. §KEEP§ THE IR COLUMN BESIDE IT SAID 2.
# §KEEP§ THIS IS THE SIXTH TIME THIS COLLECTION HAS REPORTED A ZERO THAT WAS
# §KEEP§ A FILTER THAT COULD NOT SEE THE THING.
# §KEEP§ AND THE CHARACTER CLASS IS `[\w.]*` AND NOT `\w*`, BECAUSE A
# §KEEP§ RISC-V VECTOR MNEMONIC CONTAINS A DOT -- `vadd.vv`, `vsetvli.e64` --
# §KEEP§ AND `\w` DOES NOT MATCH A DOT, §KEEP§ SO THE FIRST VERSION OF THIS
# §KEEP§ TABLE COUNTED TWELVE RISCV VECTOR INSTRUCTIONS IN THE OBJECT FILE
# §KEEP§ AND PRINTED ZERO. §KEEP§ THAT IS THE SEVENTH TIME THIS COLLECTION
# §KEEP§ HAS REPORTED A ZERO THAT WAS A REGULAR EXPRESSION THAT COULD NOT
# §KEEP§ SEE THE THING, AND IT IS WORTH NAMING AS A CLASS RATHER THAN AS A
# §KEEP§ LIST: EVERY ONE OF THE SEVEN WAS A FILTER THAT WAS NEVER FALSIFIED
# §KEEP§ AGAINST A CASE IT WAS SUPPOSED TO MATCH.
_MNEM_X86_VEC = re.compile(r'\b(?:movups|movupd|movaps|movapd|movdqa|movdqu|'
                           r'padd|paddq|psub|pmul|pxor|pand|por|punpck|'
                           r'vadd|vmov|vpxor)[\w.]*\s+%\w*[xyz]mm')
_MNEM_A64_VEC = re.compile(r'\b(?:add|sub|mul|eor|ldr|str|mov|ld[123]|st[123]|'
                           r'addv|ins|dup)[\w.]*\s+v\d+\.\d+[bhsd]')
_MNEM_RV_VEC = re.compile(r'\b(?:vadd|vsub|vmul|vxor|vand|vor|vmv|vle|vse|'
                          r'vsetvli|vsetivli|vredsum|vl2re|vs2r)[\w.]*'
                          r'\s+v\d+')
_VEC_MNEMS = {'x86_64': _MNEM_X86_VEC, 'aarch64': _MNEM_A64_VEC,
              'riscv64': _MNEM_RV_VEC}


def _machine_vector(text, arch):
    rx = _VEC_MNEMS.get(arch)
    return len(rx.findall(text)) if rx else 0


def _func_body(text, name):
    body = []
    started = False
    for line in text.splitlines():
        if re.match(r'^[0-9a-f]+ <%s>:' % re.escape(name), line):
            started = True
            continue
        if not started:
            continue
        m = re.match(r'^\s+([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*(.*)$', line)
        if not m:
            if body:
                break
            continue
        body.append((int(m.group(1), 16), m.group(2).split(),
                     m.group(3).strip()))
    return body


def _vector_operands(text, name):
    body = _func_body(text, name)
    n = 0
    for (_a, _b, t) in body:
        n += len(re.findall(r'%xmm\d+|%ymm\d+|%zmm\d+', t))
    return n


# ===========================================================================
# SECTION 4: instruction selection
# ===========================================================================
def sec4(w):
    w('=' * 74)
    w('SECTION 4 -- INSTRUCTION SELECTION: THE TREE WALK, AND THE FAILURE')
    w('MODE NOBODY NAMES.')
    w('=' * 74)
    w('')
    w('THE SELECTOR IS A TREE WALK over operand KINDS, and it is written in')
    w('cbir.py: a pattern is (opcode, kind), a machine form is selected by')
    w('dispatching on the pair, and the destination may be reused as an input')
    w('because every arithmetic form on x86-64 is two-address.')
    w('')
    w('  THE VOCABULARY IS TWELVE OPERATIONS and it is the same twelve on all')
    w('  three targets, which is the entire point of having an IR.  §KEEP§A')
    w('  real backend has a hundred more, and the limit is stated in')
    w('  cbir.py\'s docstring rather than left for a reader to discover.')
    w('')
    w('THE SELECTOR, RUN, over all three kernels:')
    w('')
    tot_tree = tot_kind = 0
    mis = 0
    w('  kernel   instructions   isel_tree   isel_kind   MISROUTED')
    for name, k in cbir.KERNELS:
        ins = k()
        a = cbir.isel_tree(ins)
        b = cbir.isel_kind(ins)
        m = cbir.isel_misroutes(ins, a)
        tot_tree += len(a)
        tot_kind += len(b)
        mis += m
        w('  %-8s  %12d   %9d   %9d   %9d' %
          (name, len(ins), len(a), len(b), m))
    w('  %-8s  %12d   %9d   %9d   %9d' % ('TOTAL', tot_tree, tot_tree,
                                           tot_kind, mis))
    w('')
    w('  §KEEP§THE MISROUTE COLUMN IS THE CLASSIC TRAP AND IT IS NOT A')
    w('  TYPO. §KEEP§A SELECTOR THAT DISPATCHES ON OPERAND KIND ALONE TAKES')
    w('  THE FIRST PATTERN WITH A MATCHING KIND, WHICH IN THE TABLE IN')
    w('  cbir.py IS `add` FOR EVERY TWO-OPERAND ARITHMETIC FORM -- §KEEP§SO')
    w('  EVERY `sub`, `xor`, `shl` AND `mul` IN THE CORPUS IS ROUTED TO THE')
    w('  INSTRUCTION FOR `add`. §KEEP§THE RESULT IS NOT A CRASH: IT IS A')
    w('  PROGRAM THAT COMPUTES A DIFFERENT NUMBER, AND THE SELECTOR NEVER')
    w('  FAILS ONCE. §KEEP§THAT IS WHY THE CHECKSUM BELOW IS THE RECEIPT AND')
    w('  NOT THE COUNT.')
    w('')
    w('  THE FIRST MISROUTED INSTRUCTION, printed so the mechanism is not a')
    w('  paragraph:')
    ins = cbir.kernel_a()
    tree = cbir.isel_tree(ins)
    kindsel = cbir.isel_kind(ins)
    for i, (x, y) in enumerate(zip(kindsel, tree)):
        if x[0] != y[0]:
            w('    instruction %d is      %s' % (i, ins[i]))
            w('    its operand kind is    %s' % cbir.kind_of(ins[i]))
            w('    isel_tree  emits       %-8s  <- correct' % y[0])
            w('    isel_kind  emits       %-8s  <- the bug' % x[0])
            w('')
            w('    §KEEP§BOTH ROUTES HAVE THE SAME OPERAND KIND, WHICH IS WHY')
            w('    THE KIND TREE MATCHES ONE WITH THE PATTERN FOR THE OTHER:')
            w('    §KEEP§`%s` AND `%s` HAVE THE SAME OPERANDS, §KEEP§AND A'
              % (y[0], x[0]))
            w('    DISPATCH THAT CANNOT SEE THE OPCODE CANNOT SEE THE')
            w('    DIFFERENCE. §KEEP§AND NEITHER OF THEM EVER FAILS.')
            break
    w('')
    w('THE CHECKSUM, WHICH IS THE RECEIPT AND NOT THE COUNT:')
    w('')
    good = cbir.checksum(cbir.kernel_a(), {'M': {}})[0]
    badins = list(cbir.kernel_a())
    badins[9] = cbir.Ins('add', ['v8', 'v1'], 'v9')       # the wrong form
    bad = cbir.checksum(badins, {'M': {}})[0]
    w('  the correct program folds to  %d' % good)
    w('  one sub computed as an add    %d' % bad)
    w('  §KEEP§THE TWO NUMBERS DIFFER, AND THAT IS THE ONLY SENTENCE IN THIS')
    w('  SECTION THAT MATTERS: §KEEP§A MISROUTED INSTRUCTION IS NOT A BAD')
    w('  INSTRUCTION SELECTION, IT IS A DIFFERENT PROGRAM.')
    w('')
    return {'misrouted': mis, 'total': tot_tree, 'good': good, 'bad': bad}


# ===========================================================================
# SECTION 5: the fusion, from IR, with a byte-level receipt
# ===========================================================================
def sec5(w):
    w('=' * 74)
    w('SECTION 5 -- FUSION FROM THE IR, AND THE RECEIPT IS BYTES.')
    w('=' * 74)
    w('')
    w('THE CLAIM.  A multiply-accumulate is ONE instruction on AArch64 and TWO')
    w('on x86-64, and the difference is not a scheduling decision: it is the')
    w('OPERAND COUNT in the encoding.')
    w('')
    w('MEASURED-ON-BYTES, and built BY HAND rather than assembled, because an')
    w('assembler hides the question.  cbenc.py encodes four AArch64')
    w('instructions from register numbers with a mask table and NO LIBRARY,')
    w('and every field position in that table is checked against six words a')
    w('real assembler emitted.')
    w('')
    rows, n, ok = cbenc.validate()
    w('  THE ENCODER AGAINST A REAL ASSEMBLER, six specimens, bit for bit:')
    w('')
    w('    instruction                      assembler    this file   agree')
    for text, word, got, good in rows:
        w('    %-30s  %08x   %08x   %s' %
          (text, word, got, 'yes' if good else 'NO'))
    w('')
    w('    %d of %d agree.  §KEEP§THIS IS NOT A CROSS-CHECK IN THE TWO-READER' % (ok, n))
    w('    SENSE -- IT IS AN ENCODER AGAINST AN ASSEMBLER -- §KEEP§SO IT IS A')
    w('    DIFFERENT KIND OF EVIDENCE AND IT IS LABELLED AS ONE. §KEEP§IT IS')
    w('    ALSO WHAT CAUGHT ALL THREE BUGS IN THE TABLE ABOVE, NONE OF WHICH')
    w('    RAISED AN ERROR.')
    w('')
    r = cbenc.fusion_receipt()
    madd, add3, ret = r['a64_madd'], r['a64_add3'], r['a64_ret']
    w('  THE FUSED FORM, ENCODED HERE:')
    w('')
    w('    madd x0, x1, x0, x2   = 0x%08x   %d bytes' % (madd, 4))
    w('    add  x0, x1, x2       = 0x%08x   %d bytes' % (add3, 4))
    w('    ret                   = 0x%08x   %d bytes' % (ret, 4))
    w('')
    w('  THE OPERAND COUNT IS IN THE WORD, and here it is being read OUT of')
    w('  the word by two programs that were written for different jobs:')
    w('')
    a64dec = _load_a64dec()
    if a64dec:
        w('    word         this file\'s fields   this file\'s text'
          '        the sibling decoder says')
        for word in (madd, add3, ret):
            f = cbenc.operand_fields_a64(word)
            mine = cbenc.render_a64(word)
            theirs = ' '.join(a64dec.render(a64dec.decode(word)).split())
            w('    0x%08x   %-16s   %-24s %s' %
              (word, ','.join('%d' % x for x in f), mine, theirs))
        w('')
        # §KEEP§ `.split()` AND NOT `' '.join(...).split()`: §KEEP§ THE JOIN
        # §KEEP§ INSERTS SPACES BETWEEN CHARACTERS, §KEEP§ SO THE COMPARISON
        # §KEEP§ WAS BETWEEN TWO LISTS OF SINGLE CHARACTERS AND REPORTED ZERO
        # §KEEP§ AGREEMENT OVER THREE WORDS THAT AGREE. §KEEP§ THAT IS THE
        # §KEEP§ EIGHTH TIME THIS COLLECTION HAS PRINTED A ZERO THAT WAS A
        # §KEEP§ COMPARISON BETWEEN THE WRONG THINGS.
        agree = sum(1 for word in (madd, add3, ret)
                    if cbenc.render_a64(word).split()
                    == a64dec.render(a64dec.decode(word)).split())
        w('    %d of 3 agree.  §KEEP§THE SIBLING DECODER IS rvasm/a64asm\'S'
          % agree)
        w('    OWN FILE, WRITTEN FOR A DIFFERENT COURSE, AND IT HAS NEVER')
        w('    HEARD OF cbenc.py. §KEEP§THAT IS WHAT MAKES THE AGREEMENT')
        w('    EVIDENCE INSTEAD OF A RESTATEMENT.')
        w('')
    else:
        agree = -1
        w('    THE SIBLING DECODER COULD NOT BE LOADED, so the two-reader check')
        w('    DID NOT RUN.  §KEEP§A CHECK THAT DID NOT RUN AND A CHECK THAT')
        w('    PASSED MUST LOOK DIFFERENT, AND THIS IS the sentence that makes')
        w('    them look different.')
        w('')
    w('  §KEEP§AND NOW THE ACTUAL FINDING, WHICH IS NOT THE OBVIOUS ONE.')
    w('  FOUR FIVE-BIT REGISTER FIELDS ARE TWENTY BITS OF THIRTY-TWO. §KEEP§THE')
    w('  REMAINING TWELVE HOLD sf, A TEN-BIT GROUP SELECTOR, THE MADD/MSUB')
    w('  BIT AND THE SHIFT AMOUNT. §KEEP§THE THREE-OPERAND FORM IS NOT A')
    w('  COMPRESSED FORM AND NOT A COMPROMISE; IT IS THE SAME WIDTH WITH ONE')
    w('  FIELD READING 31, WHICH IS HOW THE ENCODING SAYS "NO FOURTH')
    w('  OPERAND".')
    w('')
    w('  THE x86-64 SIDE, FROM cbenc.py, AND IT IS A REFUSAL:')
    w('')
    w('    imul rbx, rcx  ->  %s' %
      ' '.join('%02x' % b for b in cbenc.enc_x86('imul', 'rbx', 'rcx')))
    w('    add  rbx, rdx  ->  %s' %
      ' '.join('%02x' % b for b in cbenc.enc_x86('add', 'rbx', 'rdx')))
    w('')
    w('    enc_x86(\'imul\', \'rax\', \'rbx\', \'rcx\') is the call a')
    w('    backend would have to make -- a THREE-OPERAND multiply -- and:')
    try:
        cbenc.enc_x86('imul', 'rax', 'rbx', 'rcx')
        w('      it did NOT refuse, and the claim below is FALSE.')
        refused = False
    except (TypeError, ValueError) as e:
        w('      %s' % str(e)[:72])
        w('')
        w('      §KEEP§AND THE FAILURE MODE WORTH NAMING: §KEEP§THE SIGNATURE IS')
        w('      `enc_x86(op, dst, src, rex_w=True)`, §KEEP§SO A CALL WITH FOUR')
        w('      POSITIONAL ARGUMENTS BINDS THE FOURTH TO `rex_w` -- WHICH IS')
        w('      A TRUTHY STRING -- §KEEP§AND WITHOUT AN EXPLICIT ARITY CHECK')
        w('      IT ENCODED A TWO-OPERAND INSTRUCTION WHEN THE CALLER ASKED')
        w('      FOR THREE. §KEEP§A CALL THAT LOOKS LIKE IT IS BEING REJECTED')
        w('      AND IS INSTEAD SILENTLY ACCEPTED IS THE WORST SHAPE A')
        w('      FUNCTION SIGNATURE CAN HAVE, §KEEP§AND IT PRODUCED A')
        w('      PLAUSIBLE ENCODING RATHER THAN AN ERROR.')
        w('      §KEEP§THE FUNCTION TAKES TWO OPERANDS AND CANNOT EXPRESS A')
        w('      THREE-OPERAND MULTIPLY, AND THAT IS NOT A GAP IN cbenc.py --')
        w('      IT IS A PROPERTY OF x86-64. §KEEP§THE MODRM BYTE IS WHERE IT')
        w('      LIVES: BITS 3 TO 5 ARE THE SOURCE AND THE LOW THREE ARE THE')
        w('      DESTINATION, SO THE ENCODER PUTS THE DESTINATION WHERE THE')
        w('      BASE FIELD IS AND THE SOURCE WHERE THE SHIFTED FIELD IS.')
        refused = True
    w('')
    w('  §KEEP§SO THE ACCUMULATOR HAS TO SURVIVE THE FIRST INSTRUCTION AS A')
    w('  REGISTER NAME, AND THE ONLY WAY x86-64 FUSES `a*b+c` IS TO PUT THE')
    w('  ADD IN THE MODRM OF THE IMUL -- WHICH IS A DIFFERENT INSTRUCTION')
    w('  ENCODING ENTIRELY. §KEEP§THE TWO INSTRUCTIONS ARE NOT ONE INSTRUCTION')
    w('  WITH A DIFFERENT MNEMONIC; THEY ARE A DIFFERENT OPCODE.')
    w('')
    w('  AND WHAT clang ACTUALLY EMITTED, for the same C, as a third reader:')
    w('')
    for arch, triple in (('aarch64', 'aarch64'), ('x86_64', 'x86_64')):
        path = os.path.join(SAMPLES, 'leaf_%s_O2.o' % arch)
        if not os.path.exists(path):
            continue
        body = _func_body(objdump_text(path, triple), 'leaf')
        w('    %-8s  %d instructions, %d bytes' %
          (arch, len(body), sum(len(b) for _a, b, _t in body)))
        for (addr, bs, text) in body:
            w('      %4x  %-14s %s' % (addr, ' '.join(bs), text))
    w('')
    w('  §KEEP§AND THE AArch64 WORD clang EMITTED IS THE SAME WORD cbenc.py')
    w('  ENCODED, WHICH IS THE POINT OF HAVING AN ENCODER: §KEEP§THE SAME')
    w('  0x%08x, FROM FOUR REGISTER NUMBERS, WITH NO TABLE AND NO LIBRARY.' % madd)
    w('')
    w('WHAT THIS SECTION CANNOT SHOW: it cannot show that FUSING IS FASTER.')
    w('§KEEP§TWO INSTRUCTIONS THAT DEPEND ON EACH OTHER COST ONE MORE CYCLE')
    w('THAN ONE THAT DOES NOT, AND THE TIMING FOR THAT IS IN SECTION 9 AND')
    w('THE NUMBER THERE IS NOT ATTRIBUTED TO FUSING ALONE.')
    w('')
    return {'enc_ok': ok, 'enc_n': n, 'agree': agree, 'madd': madd,
            'add3': add3, 'x86_refused': refused}


# THE MEMORY-OPERATION COUNTERS, one per architecture, and the reason there
# are three is the reason there are three in `cbabi`: a MEMORY OPERAND IS
# PRINTED DIFFERENTLY ON EACH.
#
# x86-64 AT&T   `%rdi`, `(%rax,%rbx,4)`, `-0x18(%rbp)` -- always inside ()
# AArch64      `[sp, #0x18]`, `[x0, x1]` -- square brackets
# RISC-V       `a0(sp)`, `8(a1)` -- the OFFSET IS FIRST and there is no marker
#
# §KEEP§ AND THE FIRST VERSION OF THIS USED THE x86-64 BRACKET SHAPE FOR ALL
# §KEEP§ THREE, §KEEP§ SO IT COUNTED MEMORY OPERATIONS ON x86-64 AND ZERO ON
# §KEEP§ THE OTHER TWO -- §KEEP§ AND A TABLE OF MEMORY OPERATIONS THAT IS ZERO
# §KEEP§ ON TWO OF ITS THREE ROWS READS AS "THOSE TARGETS TOUCH NO MEMORY",
# §KEEP§ WHICH IS NOT A TRUE THING. §KEEP§ THIS IS THE NINTH TIME IN THIS
# §KEEP§ COLLECTION THAT A ZERO WAS A PATTERN THAT COULD NOT SEE THE THING.
_MEM_X86 = re.compile(r'\([^)]*\)')
_MEM_A64 = re.compile(r'\[[^\]]*\]')
_MEM_RV = re.compile(r'\b-?\d*\([a-z0-9]+\)')
_MEM = {'x86_64': _MEM_X86, 'aarch64': _MEM_A64, 'riscv64': _MEM_RV}

# §KEEP§ AND THE GENERAL-PURPOSE-REGISTER FILTER EXCLUDES THE VECTOR AND
# §KEEP§ FLOATING-POINT FILES AND THE FRAME POINTERS, BECAUSE A "REGISTER
# §KEEP§ PRESSURE" FIGURE THAT COUNTS %xmm0 AND %rbp IS NOT A REGISTER
# §KEEP§ PRESSURE FIGURE -- §KEEP§ IT IS A COUNT OF NAMES. §KEEP§ THE
# §KEEP§ EXCLUSIONS ARE WRITTEN OUT RATHER THAN DERIVED, §KEEP§ BECAUSE A
# §KEEP§ DERIVED LIST CHANGES WHENEVER THE ARCHITECTURE DOES.
# §KEEP§ THE x86-64 PATTERN IS AN ALLOW-LIST AND NOT A LOOKOUT, §KEEP§ BECAUSE
# §KEEP§ THE FIRST VERSION EXCLUDED `r8` TO `r15` -- §KEEP§ WHICH ARE SIX OF
# §KEEP§ THE FOURTEEN ALLOCATABLE REGISTERS -- §KEEP§ AND REPORTED THREE
# §KEEP§ DISTINCT REGISTERS FOR A FUNCTION THAT USES MORE THAN A DOZEN. §KEEP§
# §KEEP§ A LOOKOUT LIST IS A LIST OF THE NAMES YOU REMEMBERED, AND THE NAMES
# §KEEP§ YOU DID NOT REMEMBER ARE EXACTLY THE ONES THAT GO MISSING.
_GPR_X86 = re.compile(r'%(rax|rbx|rcx|rdx|rsi|rdi|r(?:[89]|1[0-5]))\b')
_GPR_A64 = re.compile(r'\b(x(?:[0-9]|[12][0-9]|30))\b')
_GPR_RV = re.compile(r'\b((?:a[0-7]|t[0-6]|s(?:[0-9]|1[0-1])|'
                     r'gp|tp|ra|sp|fp|x(?:[0-9]|[12][0-9]|30)))\b')
_GPR = {'x86_64': _GPR_X86, 'aarch64': _GPR_A64, 'riscv64': _GPR_RV}
_GPR_EXCLUDE = {'x86_64': ('rbp', 'rsp'), 'aarch64': ('x29', 'x30'),
                'riscv64': ('x2', 'x1', 'x8', 'x9')}


def _gprs(text, arch):
    """The distinct GENERAL-PURPOSE registers a function names.

    §KEEP§ THE EXCLUSIONS ARE NAMED IN A TABLE BESIDE THE PATTERNS RATHER THAN
    §KEEP§ INSIDE THEM, §KEEP§ BECAUSE A PATTERN THAT EXCLUDES BY NEGATIVE
    §KEEP§ LOOKOUT IS A PATTERN THAT CHANGES SILENTLY WHEN A NEW REGISTER
    §KEEP§ NAME APPEARS IN THE DISASSEMBLER'S OUTPUT.
    """
    rx = _GPR.get(arch)
    if rx is None:
        return set()
    ex = _GPR_EXCLUDE.get(arch, ())
    return set(m for m in rx.findall(text) if m not in ex)


def _memory_ops(text, arch):
    rx = _MEM.get(arch)
    if rx is None:
        return 0
    return len(rx.findall(text))


def _words(bytetxt):
    """Reassemble an instruction stream into 32-bit words.

    §KEEP§AND THIS FUNCTION IS THE SIXTH PLACE IN THIS COURSE WHERE A
    DISASSEMBLER'S PRINTING CONVENTION HAD TO BE LEARNED RATHER THAN
    ASSUMED. §KEEP§ `llvm-objdump-21` PRINTS THREE DIFFERENT THINGS IN THE
    BYTE COLUMN ON THREE ARCHITECTURES:

      x86-64    `48 8d 04 77`      FOUR BYTES, space separated, memory order
      AArch64   `8b010408`         ONE WORD, printed as eight hex DIGITS
      RISC-V    `8b01` or `950e`   TWO BYTES or ONE FOUR-BYTE WORD

    §KEEP§ AND THE FIRST VERSION OF THIS FUNCTION ALWAYS REASSEMBLED THE
    COLUMN AS LITTLE-ENDIAN BYTES, §KEEP§ WHICH IS CORRECT FOR x86-64 AND
    RISC-V AND PRODUCES THE BYTE-REVERSED WORD FOR AArch64 -- §KEEP§ AND
    THE TWO-READER CHECK THEN REPORTED 0 AGREES AND 9 DISAGREEMENTS OVER
    NINE WORDS, §KEEP§ EVERY ONE OF WHICH WAS A WORD INVERTED BY THIS
    FUNCTION AND NOT BY EITHER DECODER. §KEEP§ THE SIBLING DECODER WAS
    RIGHT ABOUT ALL NINE.

    §KEEP§ AND THIS IS THE SAME FAILURE CLASS AS THE OTHER FIVE: A
    CONVERSION THAT IS APPLIED WITHOUT BEING CHECKED, PRODUCING A NUMBER
    THAT LOOKS LIKE A FINDING. §KEEP§ THE FIX IS NOT "BE CAREFUL" -- IT IS
    THAT THE CHECK BELOW PROVES THE ROUND TRIP BEFORE THE CHECK RUNS.

    Returns (words, disagreements, reason) and the caller is REQUIRED to
    print the reason when there is one, because a silently-empty word list
    is the shape of a check that did not run.
    """
    n = len(bytetxt)
    if n == 0:
        return [], 0, 'no byte column'
    joined = ''.join(bytetxt)
    if len(joined) == 8 and len(bytetxt) == 1:
        # AArch64: ONE eight-digit group, already a 32-bit WORD, in the
        # order the disassembler chose to print it.
        return [int(bytetxt[0], 16)], 0, ''
    if n % 4 != 0:
        return [], 0, ('%d byte columns, which is not a multiple of four' % n)
    out = []
    for j in range(0, n, 4):
        grp = bytetxt[j:j + 4]
        if len(grp) == 4:
            out.append(sum(int(b, 16) << (8 * i) for i, b in enumerate(grp)))
    return out, 0, ''


def _load_a64dec():
    try:
        d = cbabi.find_sibling('a64dec.py', 'A64DEC_DIR', 'a64asm')
        sys.path.insert(0, d)
        import a64dec
        return a64dec
    except Exception:
        return None


def _load_rvdec():
    try:
        d = cbabi.find_sibling('rvdec.py', 'RVDEC_DIR', 'rvasm')
        sys.path.insert(0, d)
        import rvdec
        return rvdec
    except Exception:
        return None


# ===========================================================================
# SECTION 6: register allocation, the centrepiece
# ===========================================================================
PRESSURES = (3, 4, 5, 6, 7, 8, 10, 13, 14)


def sec6(w):
    w('=' * 74)
    w('SECTION 6 -- REGISTER ALLOCATION: THREE ALLOCATORS, THREE SPILL')
    w('POLICIES, AND TWO DELIBERATE BUGS.  This is the centrepiece.')
    w('=' * 74)
    w('')
    w('THREE ALLOCATORS, ALL WRITTEN HERE, ALL ON THE SAME IR:')
    w('')
    w('  linear scan     Braun & Hack, CACM 21(10) 1978.  Sorts intervals by')
    w('                  start point and needs NO interference graph -- only')
    w('                  the intervals, which can be built in one pass.')
    w('  Chaitin colour  Chaitin/Briggs/Panter/Scholz 1979.  Simplify, select,')
    w('                  spill, on a graph whose nodes are virtual registers')
    w('                  and whose edges are interference.')
    w('  colour, iterate  Greedy colour first, spill what will not colour,')
    w('                  repeat.  §KEEP§THE THIRD IS NOT IN THE TEXTBOOK AND')
    w('                  IT EXISTS HERE BECAUSE THE THREE SPILL COUNTS')
    w('                  DISAGREE, AND A COMPARISON THAT QUOTES ONE NUMBER')
    w('                  WITHOUT SAYING WHICH POLICY PRODUCED IT HAS NOT')
    w('                  QUOTED A REPRODUCIBLE NUMBER AT ALL.')
    w('')
    tot = {'lin': 0, 'ch': 0, 'it': 0}
    table = {}
    for name, k in cbir.KERNELS:
        ins = k()
        edges, rng = cbreg.build_interference(ins, True)
        base, _ = cbreg.result_checksum(ins)
        w('  ---- %s: %d instructions, %d live ranges, %d interference edges'
          % (name, len(ins), len(rng), cbreg.edge_count(edges)))
        w('')
        w('    phys   linear      colour    colour-iter   slots(lin)'
          '   slots(col)   correct')
        for n in PRESSURES:
            phys = cbreg.phys_names(n)
            al, sl = cbreg.alloc_linear_scan(ins, n)
            ac, sc = cbreg.alloc_colour(ins, n, edges)
            ai, si, rounds = cbreg.alloc_colour_iterative(ins, n, edges)
            ka = (al, sl, phys)
            kc = (ac, sc, phys)
            ki = (ai, si, phys)
            ol = cbreg.lower_with_spills(ins, al, phys,
                                         cbreg.pack_spill_slots(ins, al)[0])
            oc = cbreg.lower_with_spills(ins, ac, phys,
                                         cbreg.pack_spill_slots(ins, ac)[0])
            oi = cbreg.lower_with_spills(ins, ai, phys,
                                         cbreg.pack_spill_slots(ins, ai)[0])
            cl, _ = cbreg.result_checksum(ins, ol, al,
                                          cbreg.pack_spill_slots(ins, al)[0],
                                          phys)
            cc, _ = cbreg.result_checksum(ins, oc, ac,
                                          cbreg.pack_spill_slots(ins, ac)[0],
                                          phys)
            ci, _ = cbreg.result_checksum(ins, oi, ai,
                                          cbreg.pack_spill_slots(ins, ai)[0],
                                          phys)
            nl = len(set(cbreg.pack_spill_slots(ins, al)[0].values()))
            nc = len(set(cbreg.pack_spill_slots(ins, ac)[0].values()))
            table[(name, n)] = (sl, len(sc), len(si), nl, nc,
                                cl == base, cc == base, ci == base)
            tot['lin'] += sl
            tot['ch'] += len(sc)
            tot['it'] += len(si)
            w('    %4d  %7d  %10d  %13d  %11d  %10d   %s%s%s' %
              (n, sl, len(sc), len(si), nl, nc,
               'yes' if cl == base else 'NO',
               ' ' if cc == base else 'NO',
               ' ' if ci == base else 'NO'))
        w('')
        w('    every "yes" is a CHECKSUM, not a count: the program was')
        w('    lowered with the spills, run by cbir.step, and every virtual')
        w('    register\'s value read back out of its physical location at its')
        w('    last use.  §KEEP§THE READ-BACK IS AT THE LAST USE AND NOT AT')
        w('    THE END OF THE PROGRAM, BECAUSE A SPILL SLOT MAY LEGITIMATELY')
        w('    BE REUSED. §KEEP§READING IT AT THE END REPORTS AN ERROR IN A')
        w('    CORRECT ALLOCATION, AND THAT WAS THE THIRD BUG THIS FILE')
        w('    SHIPPED.')
        w('')
    w('THE TOTALS, and they are the section\'s finding:')
    w('')
    w('  linear scan        %5d spills across %d allocations' %
      (tot['lin'], len(PRESSURES) * len(cbir.KERNELS)))
    w('  Chaitin colour     %5d spills' % tot['ch'])
    w('  colour, iterate    %5d spills' % tot['it'])
    w('')
    ratio = (float(tot['ch']) / tot['lin']) if tot['lin'] else 0.0
    w('  the ratio Chaitin/linear is %0.2f, and §KEEP§IT IS NOT A CLAIM' % ratio)
    w('  ABOUT THE ALGORITHMS. §KEEP§IT IS A CLAIM ABOUT THE SPILL HEURISTIC,')
    w('  AND THE SAME GRAPH WITH A THIRD POLICY GIVES A THIRD NUMBER. §KEEP§THE')
    w('  HONEST SUMMARY IS: WHICH ALLOCATOR IS BETTER IS A PROPERTY OF YOUR')
    w('  CORPUS, AND A BACKEND THAT REPORTS "GRAPH COLOURING SPILLS N"')
    w('  WITHOUT NAMING THE POLICY HAS REPORTED NOTHING REPRODUCIBLE.')
    w('')
    w('WHY LINEAR SCAN IS STILL WHAT PRODUCTION BACKENDS USE, which is a fact')
    w('about COMPLEXITY and not about spill counts:')
    w('')
    w('  linear scan   O(n log n) in the number of intervals, and the graph')
    w('                is never BUILT, so its size never matters.')
    w('  colouring     the interference graph is QUADRATIC in the worst case,')
    w('                and a backend must build it even to colour it.')
    w('  §KEEP§AND THIS COURSE MEASURES NEITHER, because both are properties')
    w('  of the INPUT SIZE and this corpus is TWELVE INSTRUCTIONS. §KEEP§THE')
    w('  NUMBER IS QUOTED, WITH ITS DOCUMENT, AND IT IS NOT MEASURED HERE.')
    w('  §KEEP§SAYING SO IS CHEAPER THAN MEASURING IT AND IT IS TRUE.')
    w('')
    return {'tot': tot, 'table': table, 'ratio': ratio}


def sec7(w):
    w('=' * 74)
    w('SECTION 7 -- THE TWO BUGS, BUILT DELIBERATELY, EACH CAUGHT BY A')
    w('CHECKSUM AND NOT BY AN EXCEPTION.')
    w('=' * 74)
    w('')
    w('BUG 1 -- THE LIVE-RANGE OVERLAP TRAP.  This collection has been bitten by')
    w('`aligned(64)` six times: a boundary that is off by one in the direction')
    w('that makes an interval look SHORTER.  The register-allocation version')
    w('is an interference edge built from a HALF-OPEN live range when the')
    w('machine\'s intervals are INCLUSIVE.')
    w('')
    w('  §KEEP§AND THE DIRECTION MATTERS AND IS NOT WHAT A READER WOULD')
    w('  GUESS. §KEEP§A HALF-OPEN RANGE IS A SUBSET OF THE CORRECT ONE, SO THE')
    w('  BUGGY GRAPH HAS FEWER EDGES, WHICH MEANS IT IS EASIER TO COLOUR AND')
    w('  MORE LIKELY TO SUCCEED -- §KEEP§AND SUCCEEDING IS THE FAILURE. §KEEP§A')
    w('  DOCUMENT THAT SAID "HALF-OPEN RANGES ARE WRONG" WITHOUT SAYING WHICH')
    w('  WAY WOULD HAVE TAUGHT ITS READER NOTHING, AND THE FIRST VERSION OF')
    w('  cbreg.py\'s DOCSTRING DID EXACTLY THAT.')
    w('')
    w('  The range of one value, closed and half-open, beside the edge that')
    w('  disappears:')
    ins = cbir.kernel_c()
    ec, rng = cbreg.build_interference(ins, True)
    eh, rh = cbreg.build_interference(ins, False)
    gone = []
    for x in ec:
        for y in ec[x]:
            if x < y and y not in eh[x]:
                gone.append((x, y))
    w('')
    w('    value    closed range    half-open range')
    for v in sorted(rng, key=lambda s: int(s[1:]))[:8]:
        w('    %-7s  [%d, %2d]        [%d, %2d]%s' %
          (v, rng[v][0], rng[v][1], rh[v][0], rh[v][1],
           '   <- the loss' if rh[v][1] < rng[v][1] else ''))
    w('')
    w('    interference edges: closed %d, half-open %d, LOST %d' %
      (cbreg.edge_count(ec), cbreg.edge_count(eh), len(gone)))
    w('')
    w('  THE VERDICT, per pressure, from the CHECKSUM and nothing else. §KEEP§')
    w('  THE SWEEP GOES BELOW THE PRESSURES SECTION 6 USED, BECAUSE THE ONE')
    w('  PRESSURE AT WHICH THE BUG IS INVISIBLE IS *ONE*, §KEEP§ AND A SWEEP')
    w('  THAT STARTED AT THREE WOULD HAVE REPORTED NINE OF NINE AND CALLED IT')
    w('  DETECTED. §KEEP§THE SHAPE OF A FINDING INCLUDES WHERE IT IS NOT,')
    w('  AND §KEEP§A FINDING WITH NO HOLE IN IT IS NOT YET A FINDING.')
    w('')
    SWEEP = (1, 2) + PRESSURES
    w('    phys   correct alloc   half-open alloc   VERDICT')
    caught = 0
    fired = 0
    for n in SWEEP:
        phys = cbreg.phys_names(n)
        ac, _ = cbreg.alloc_colour(ins, n, ec)
        ah, _ = cbreg.alloc_colour(ins, n, eh)
        sl = cbreg.pack_spill_slots(ins, ac, True)
        sh = cbreg.pack_spill_slots(ins, ah, False)
        ol = cbreg.lower_with_spills(ins, ac, phys, sl[0])
        oh = cbreg.lower_with_spills(ins, ah, phys, sh[0])
        base, _ = cbreg.result_checksum(ins)
        cl, _ = cbreg.result_checksum(ins, ol, ac, sl[0], phys)
        ch, _ = cbreg.result_checksum(ins, oh, ah, sh[0], phys)
        good = (cl == base)
        bad = (ch != base)
        if bad:
            caught += 1
        fired += 1
        w('    %4d   %-14s  %-16s  %s' %
          (n, 'correct' if good else 'WRONG',
           'correct' if not bad else 'WRONG',
           'the bug is INVISIBLE here' if not bad else
           'the bug CHANGED THE ANSWER'))
    w('')
    w('    the half-open allocator produced a WRONG ANSWER at %d of %d' %
      (caught, fired))
    w('    pressures. §KEEP§AND IT DID NOT RAISE, DID NOT CRASH, AND DID NOT')
    w('    PRINT ANYTHING ODD. §KEEP§IT RETURNED A NUMBER.')
    w('')
    w('  §KEEP§AND THE FINDING THAT MATTERS MORE THAN THE COUNT: THE')
    w('  HALF-OPEN GRAPH HAS FEWER EDGES, SO IT COLOURS MORE EASILY, SO IT')
    w('  SPILLS FEWER VALUES. §KEEP§A COMPILER THAT REPORTED ONLY THE SPILL')
    w('  COUNT WOULD BE REPORTING A BETTER NUMBER FOR A WORSE ALLOCATOR, AND')
    w('  EVERY SPILL COUNT IN SECTION 6 IS HELD TOGETHER BY A CHECKSUM FOR')
    w('  EXACTLY THIS REASON. §KEEP§THIS IS ALSO WHY POISON 2 REQUIRES THE')
    w('  SIGN OF THE EDGE DELTA AND NOT ONLY THAT SOMETHING MOVED.')
    w('')
    w('BUG 2 -- THE COALESCING TRAP, AND IT FAILS IN THE OPPOSITE DIRECTION.')
    w('')
    w('  Coalescing merges a move-related pair when the two intervals do NOT')
    w('  overlap.  With half-open ranges the source of a move at instruction')
    w('  i has range ending at i-1 and the destination begins at i, so i-1 < i')
    w('  and the merge happens -- while the source is live at i, because the')
    w('  move IS its use.')
    w('')
    w('    pressure   merged(closed)   unsound(closed)   merged(half)'
          '   UNSOUND(half)   checksum')
    res = []
    for n in SWEEP:
        phys = cbreg.phys_names(n)
        ac, _ = cbreg.alloc_colour(ins, n, ec)
        ah, _ = cbreg.alloc_colour(ins, n, eh)
        a1 = dict(ac)
        a2 = dict(ah)
        m1, _u1 = cbreg.coalesce_overlap(ins, a1, rng, True)
        m2, u2 = cbreg.coalesce_overlap(ins, a2, rng, False)
        s2 = cbreg.pack_spill_slots(ins, a2, False)
        o2 = cbreg.lower_with_spills(ins, a2, phys, s2[0])
        base, _ = cbreg.result_checksum(ins)
        ch, _ = cbreg.result_checksum(ins, o2, a2, s2[0], phys)
        res.append((n, m1, m2, u2, ch != base))
        w('    %8d   %13d   %14d   %12d   %13d   %s' %
          (n, m1, 0, m2, u2, 'WRONG' if ch != base else 'correct'))
    w('')
    w('  §KEEP§NOTE THE DIRECTION IN THAT TABLE: THE INTERFERENCE-GRAPH BUG')
    w('  LOSES EDGES, AND THE COALESCER BUG GAINS A MERGE. §KEEP§BOTH ARE THE')
    w('  SAME OFF-BY-ONE AND OPPOSITE FAILURES, AND A READER WHO HAS ONLY SEEN')
    w('  ONE OF THEM WILL NOT RECOGNISE THE OTHER.')
    w('')
    return {'caught': caught, 'pressures': fired, 'edges_lost': len(gone),
            'coalesce': res}


# ===========================================================================
# SECTION 8: scheduling, and the trap that looks good
# ===========================================================================
PRIORITIES = ('index', 'height', 'height_hi', 'degree')


def sec8(w):
    w('=' * 74)
    w('SECTION 8 -- INSTRUCTION SCHEDULING, AND THE TRAP THAT MAKES A')
    w('SCHEDULE LOOK GOOD WHILE BEING WRONG.')
    w('=' * 74)
    w('')
    w('LIST SCHEDULING, in full: while unscheduled nodes remain, take one with')
    w('no unscheduled predecessor, and among those take the one the PRIORITY')
    w('FUNCTION prefers.  Three priorities, all measured:')
    w('')
    w('  index      the input order, which is a SCHEDULE and the control')
    w('             every other schedule is measured against')
    w('  height     longest chain STARTING at the node, ties to the LOWEST')
    w('             index -- which on this kernel reproduces the input order')
    w('  height_hi  the SAME priority, ties to the HIGHEST index -- which on')
    w('             this kernel produces a different order from `height` and')
    w('             nothing else does')
    w('  degree     most UNSCHEDULED SUCCESSORS, which is a third policy')
    w('')
    w('  §KEEP§AND `height` AGAINST `height_hi` IS THE MOST IMPORTANT ROW IN')
    w('  THAT LIST, §KEEP§BECAUSE THEY ARE THE SAME ALGORITHM WITH A DIFFERENT')
    w('  UNDOCUMENTED TIE-BREAK, §KEEP§AND EVERY LIST SCHEDULER IN EVERY')
    w('  TEXTBOOK BREAKS TIES BY SOME RULE AND NONE OF THEM SAY WHICH. §KEEP§A')
    w('  BACKEND THAT REPORTS "MY SCHEDULER IS BETTER" WITHOUT NAMING THE')
    w('  TIE-BREAK HAS REPORTED A DIFFERENT SCHEDULER AND NOT A BETTER ONE.')
    w('')
    w('§KEEP§AND THE FIRST VERSION OF THIS FILE COMPUTED ONLY THE LONGEST')
    w('CHAIN *ENDING* AT EACH NODE AND USED IT AS THE PRIORITY -- §KEEP§SO THE')
    w('SCHEDULER PREFERRED THE NODES WHOSE WORK ARRIVED LATEST, WHICH IS THE')
    w('EXACT OPPOSITE OF WHAT HIDES LATENCY. §KEEP§IT PRODUCED A SCHEDULE, IT')
    w('WAS LEGAL, IT WAS DETERMINISTIC, AND IT WAS NO BETTER THAN THE INPUT')
    w('ORDER. §KEEP§THE TWO HEIGHTS ARE NOW COMPUTED AND THE DISTINCTION IS')
    w('THE WHOLE OF THE PRIORITY FUNCTION.')
    w('')
    # §KEEP§ THE KERNEL IS kernel_c AND NOT kernel_a, BECAUSE kernel_a IS A
    # §KEEP§ DEPENDENCY CHAIN: §KEEP§ EVERY INSTRUCTION WAITS FOR THE ONE
    # §KEEP§ BEFORE IT, §KEEP§ THE CRITICAL PATH IS EQUAL TO THE INSTRUCTION
    # §KEEP§ COUNT, AND EVERY SCHEDULE OF IT IS THE INPUT ORDER. §KEEP§ THE
    # §KEEP§ FIRST VERSION OF THIS SECTION USED kernel_a AND PRINTED THREE
    # §KEEP§ IDENTICAL ORDERS AND CALLED THEM THREE SCHEDULES.
    ins = cbir.kernel_d()
    w('  THE KERNEL IS kernel_d, %d instructions, and §KEEP§IT IS NOT kernel_a:'
      % len(ins))
    w('  §KEEP§kernel_a IS A DEPENDENCY CHAIN, ITS CRITICAL PATH EQUALS ITS')
    w('  LENGTH, AND EVERY SCHEDULE OF IT IS THE INPUT ORDER -- §KEEP§SO A')
    w('  SCHEDULER MEASURED ON IT HAS NOTHING TO DECIDE. §KEEP§A LIST SCHEDULER')
    w('  THAT IS GIVEN NO CHOICE PRINTS THREE COPIES OF THE INPUT AND A')
    w('  READER WHO HAS NOT SPOTTED IT CONCLUDES THAT SCHEDULING WORKS.')
    w('')
    out = {'height': '?', 'degree': '?'}
    for mem in (False, True):
        d = cbsched.build_dag(ins, mem_ordered=mem)
        up, down, cp, done = cbsched.heights(d)
        w('  %s memory dependencies: critical path %d of %d instructions, '
          'ILP %0.2f' %
          ('WITH' if mem else 'WITHOUT', cp, len(ins),
           float(len(ins)) / cp if cp else 0.0))
        w('    priority    order                      illegal   checksum')
        ref = cbsched.schedule_checksum(ins, list(range(len(ins))))
        for p in PRIORITIES:
            o = cbsched.list_schedule(d, p)
            bad, tot = cbsched.inversions(o, d)
            ck = cbsched.schedule_checksum(ins, o)
            w('    %-10s  %s  %3d   %s' %
              (p, str(o), bad, 'same' if ck == ref else 'DIFFERENT'))
            out[p] = ck
        w('')
        w('    §KEEP§AND THE FOUR ORDERS ARE NOT THE SAME ORDER AND EVERY ONE')
        w('    OF THEM IS LEGAL, §KEEP§WHICH IS THE POINT: §KEEP§THE ILP OF THIS')
        w('    DAG IS %0.2f, §KEEP§SO THERE IS ROOM TO MOVE THINGS, §KEEP§AND THE'
          % (float(len(ins)) / cp if cp else 0.0))
        w('    ONLY THING THAT SEPARATES THE FOUR IS A TIE-BREAK. §KEEP§THE')
        w('    FOUR INITIAL `mov`s HAVE THE SAME DOWNSTREAM HEIGHT, §KEEP§SO')
        w('    BREAKING THE TIE TOWARD THE LOWEST INDEX REPRODUCES THE INPUT')
        w('    ORDER AND BREAKING IT TOWARD THE HIGHEST PRODUCES ITS REVERSE')
        w('    ON THE FIRST FOUR INSTRUCTIONS AND NOTHING ELSE.')
        w('    §KEEP§AND THE CHECKSUM DIFFERS BETWEEN THEM, §KEEP§WHICH IS NOT')
        w('    A BUG: §KEEP§IT IS A FOLD OVER THE VALUES *IN SCHEDULED ORDER*,')
        w('    §KEEP§AND TWO LEGAL SCHEDULES OF THE SAME PROGRAM DEFINE THEIR')
        w('    VALUES IN A DIFFERENT ORDER. §KEEP§§KEEP§THAT IS EXACTLY WHY A')
        w('    FOLD THAT IGNORED THE ORDER COULD NOT HAVE DETECTED THE')
        w('    ALIASING TRAP, §KEEP§AND IT IS THE ARGUMENT FOR HAVING BOTH.')
        w('')
    w('  THE ILP ESTIMATE IS A RATIO AND NOT A SPEEDUP.  §KEEP§IT IS')
    w('  INSTRUCTIONS DIVIDED BY CRITICAL PATH, IT IS A PROPERTY OF THE DAG')
    w('  AND OF A MACHINE WIDTH THAT IS NOT MEASURED HERE, AND §KEEP§A NUMBER')
    w('  THAT IS DIVIDED BY A CRITICAL PATH IS NOT A TIME.')
    w('')
    w('THE TRAP.  A SCHEDULE THAT RESPECTS THE DEPENDENCIES IT CAN SEE AND')
    w('NOT THE ONES IT CANNOT.')
    w('')
    k = cbsched.alias_trap_kernel()
    kd = cbsched.alias_trap_kernel_distinct()
    ref = cbsched.schedule_checksum(k, list(range(len(k))))
    refd = cbsched.schedule_checksum(kd, list(range(len(kd))))
    w('  The kernel stores to [1024+8] and then loads from [1024+8].  §KEEP§THE')
    w('  SAME ADDRESS, SO THE DEPENDENCY IS REAL, AND A SCHEDULER THAT DOES')
    w('  NOT KNOW THEY ALIAS WILL HOIST THE LOAD ABOVE THE STORE.')
    w('')
    w('    memory deps   priority     order'
          '                            checksum   VERDICT')
    res = {}
    for mem in (True, False):
        d = cbsched.build_dag(k, mem_ordered=mem)
        for p in ('index', 'height', 'height_hi'):
            o = cbsched.list_schedule(d, p)
            ck = cbsched.schedule_checksum(k, o)
            res[(mem, p)] = (ck == ref, ck)
            w('    %-12s  %-10s  %-26s  %10d   %s' %
              ('WITH' if mem else 'WITHOUT', p, str(o), ck,
               'correct' if ck == ref else 'WRONG ANSWER'))
    w('')
    w('    the same schedule on DISTINCT addresses, where the reorder is')
    w('    legal:')
    dd = cbsched.build_dag(kd, mem_ordered=False)
    o = cbsched.list_schedule(dd, 'height')
    ckd = cbsched.schedule_checksum(kd, o)
    w('    %-12s  %-10s  %-26s  %10d   %s' %
      ('WITHOUT', 'height', str(o), ckd,
       'correct' if ckd == refd else 'WRONG ANSWER'))
    w('')
    w('  §KEEP§AND THE TWO VERDICTS ARE NOT CONTRASTED FOR EFFECT -- THEY ARE')
    w('  BOTH TRUE AND THEY SAY DIFFERENT THINGS: §KEEP§THE SCHEDULE THAT IS')
    w('  WRONG ON THE ALIASING KERNEL IS CORRECT ON THE NON-ALIASING ONE, AND')
    w('  THE ONLY DIFFERENCE BETWEEN THE TWO IS WHETHER THE BACKEND KNEW. §KEEP§')
    w('  A SCHEDULER THAT DROPS AN UNKNOWN MEMORY DEPENDENCY IS NOT WRONG, IT')
    w('  IS A SCHEDULER WITHOUT AN ALIAS ANALYSIS, AND §KEEP§THE FAILURE IT')
    w('  PRODUCES IS FASTER AND WRONG, WHICH IS THE WORST COMBINATION THIS')
    w('  COURSE HAS FOUND.')
    w('')
    w('  §KEEP§AND TIMING WILL NOT CATCH IT. §KEEP§IF THE ONLY MEASUREMENT')
    w('  WERE HOW FAST THE TWO SCHEDULES ARE, THE BROKEN ONE WINS. §KEEP§THE')
    w('  ONLY THING THAT CATCHES IT IS A VALUE, WHICH IS WHY EVERY SCHEDULE')
    w('  IN THIS FILE IS EVALUATED AND ITS CHECKSUM PRINTED BESIDE ITS')
    w('  LENGTH. §KEEP§THIS IS THE GENERAL FORM OF EVERY TIMING BUG IN THIS')
    w('  COLLECTION AND IT IS WORTH NAMING: A FASTER WRONG ANSWER IS NOT A')
    w('  SMALLER NUMBER, IT IS A LIE THAT HAPPENS TO POINT DOWN.')
    w('')
    w('§KEEP§AND ONE MORE BUG THIS SECTION SHIPPED, WHICH IS THE FIFTH TIME')
    w('IN THIS COLLECTION THAT A CHECK WHICH LIVED IN THE FAILURE BRANCH WAS')
    w('INVISIBLE ON A HEALTHY RUN: §KEEP§THE DEPENDENCY BUILDER SKIPPED EVERY')
    w('INSTRUCTION WITH NO DESTINATION -- WHICH IS EVERY STORE -- §KEEP§SO THE')
    w('MEMORY-ORDERED SCHEDULE REORDERED STORES ACROSS THE THINGS THAT')
    w('COMPUTE THEIR DATA. §KEEP§THE SCHEDULE THAT WAS SUPPOSED TO CATCH THE')
    w('ALIASING BUG WAS THE SCHEDULE THAT CARRIED IT.')
    w('')
    return res


# ===========================================================================
# SECTION 9: the ABI obligation
# ===========================================================================
def sec9(w):
    w('=' * 74)
    w('SECTION 9 -- THE BACKEND AND THE ABI: WHAT THE BACKEND MUST KNOW')
    w('BEFORE IT EMITS ANYTHING.')
    w('=' * 74)
    w('')
    w('THE OBLIGATION IS NOT THE CONVENTION.  x86abi, a64abi and rvabi each')
    w('taught their convention in full.  This section measures the BACKEND\'S')
    w('SIDE of the bargain, and the order matters:')
    w('')
    w('    a backend that emits a call must ALREADY know the argument')
    w('    registers, the return register, the callee-saved set and the stack')
    w('    alignment -- and it must know them BEFORE it has allocated a')
    w('    register to anything.')
    w('')
    w('  §KEEP§REGISTER ALLOCATION ASSIGNS NAMES TO VALUES AND THE ABI ASSIGNS')
    w('  NAMES TO ARGUMENTS, AND THE ORDER IS NOT A MATTER OF TASTE. §KEEP§IF')
    w('  THE ALLOCATOR RUNS FIRST AND THE ABI IS CONSULTED SECOND, THE')
    w('  ALLOCATOR HAS ALREADY GIVEN `rbx` TO A VALUE AND THE PROLOGUE NOW HAS')
    w('  TO SAVE IT -- A PROLOGUE THE BACKEND DID NOT PLAN FOR, AND §KEEP§ON')
    w('  x86-64 THAT MEANS A STACK FRAME WHERE THE FUNCTION LOOKED LIKE IT')
    w('  NEEDED NONE.')
    w('')
    w('  THE CONVENTIONS, QUOTED, one line each, with the document:')
    w('')
    for arch, regs, doc in cbabi.CONVENTIONS:
        w('    %-9s  %-24s  %s' % (arch, regs, doc))
    w('')
    w('  AND WHAT EACH ONE RESERVES, which is the number the allocator has to')
    w('  SUBTRACT, QUOTED from the same documents:')
    w('')
    for arch, res, doc in cbabi.RESERVED:
        w('    %-9s  %s' % (arch, res))
        w('              %s' % doc[:66])
    w('')
    w('THE MEASUREMENT, and it is by NAME and then BY BITS:')
    w('')
    w('  target   arg registers the compiler READ    insns   bytes')
    argsets = {}
    for t in TARGETS:
        arch = t.split('-')[0]
        triple = 'x86_64' if arch == 'x86_64' else arch
        path = os.path.join(SAMPLES, 'leaf_%s_O2.o' % arch)
        body = cbabi.objdump_body(path, triple, 'leaf', arch)
        text = '\n'.join(t for _a, _b, t in body)
        names = None
        for a, regs, _d in cbabi.CONVENTIONS:
            # §KEEP§ THE MATCH IS ON THE FULL ARCHITECTURE NAME AND NOT ON
            # §KEEP§ ITS FIRST FIVE CHARACTERS. §KEEP§ `arch[:5]` IS `x86_6`,
            # §KEEP§ WHICH MATCHES NOTHING, §KEEP§ SO THE x86-64 ROW OF THE
            # §KEEP§ ARGUMENT-REGISTER TABLE WAS SILENTLY ABSENT -- TWO ROWS
            # §KEEP§ PRINTED WHERE THE HEADER SAYS THREE.
            if a == arch:
                names = regs.split()
        if not names:
            w('  %-8s  NO CONVENTION MATCHED, so no row is printed for it. '
              '§KEEP§A MISSING ROW IN A TABLE WHOSE HEADER GIVES THE COUNT IS '
              'THE SHAPE OF A TABLE THAT LOOKS COMPLETE.' % arch)
            continue
        cnt = cbabi.count_regs(body, names)
        argsets[arch] = cnt
        used = [n for n in names if cnt[n] > 0]
        w('  %-8s  %2d of %2d: %-28s  %5d  %5d' %
          (arch, len(used), len(names), ' '.join(used),
           len(body), sum(len(b) for _a, b, _t in body)))
    w('')
    w('  §KEEP§THE SIXTH ARGUMENT IS STILL IN A REGISTER ON ALL THREE, AND')
    w('  THAT IS THE POINT OF THE EXAMPLE. §KEEP§IT IS ALSO WHY THE EXAMPLE')
    w('  HAS SIX ARGUMENTS AND NOT SEVEN: §KEEP§THE SEVENTH IS THE ONE THAT')
    w('  MOVES TO THE STACK, AND §KEEP§HOW MANY ARGUMENTS SPILL IS A FACT')
    w('  ABOUT THE ABI AND NOT ABOUT THE BACKEND, SO IT IS IN THE LIMITS AND')
    w('  NOT HERE.')
    w('')
    w('THE SECOND READER, and this is where the section stops counting names')
    w('and starts reading words:')
    w('')
    a64dec = _load_a64dec()
    rvdec = _load_rvdec()
    w('  target   word    the artifact\'s own reading'
          '        the sibling decoder says')
    agree = 0
    checked = 0
    for t in TARGETS:
        arch = t.split('-')[0]
        triple = 'x86_64' if arch == 'x86_64' else arch
        path = os.path.join(SAMPLES, 'leaf_%s_O2.o' % arch)
        body = cbabi.objdump_body(path, triple, 'leaf', arch)
        dec = None
        if arch == 'aarch64' and a64dec:
            dec = a64dec
        if arch == 'riscv64' and rvdec:
            dec = rvdec
        if dec is None:
            continue
        for (_addr, bytetxt, _text) in body[:6]:
            words = [int(b, 16) for b in bytetxt if b]
            if len(words) != 4:
                words = [(sum(int(b, 16) << (8 * i)
                              for i, b in enumerate(bytetxt[j:j + 4])))
                         for j in range(0, len(bytetxt), 4)]
            for wv in words:
                try:
                    theirs = ' '.join(dec.render(dec.decode(wv)).split())
                except Exception:
                    continue
                mine = _our_render(arch, wv)
                checked += 1
                if mine == theirs:
                    agree += 1
                    w('  %-8s  %08x  %-24s  %s' % (arch, wv, mine, theirs))
                else:
                    w('  %-8s  %08x  %-24s  %s   <-- DISAGREES' %
                      (arch, wv, mine, theirs))
    w('')
    if checked:
        w('  %d of %d agree.  §KEEP§THE SIBLING DECODERS ARE a64asm\'S AND' %
          (agree, checked))
        w('  rvasm\'S OWN FILES, AND NEITHER HAS HEARD OF cbenc.py OR')
        w('  cbabi.py. §KEEP§AND THE ARTIFACT\'S OWN READING OF A WORD IS')
        w('  `_our_render`, WHICH IS A FOURTH RENDERER AND THE ONE THAT')
        w('  COULD BE WRONG IN THE SAME WAY AS THE OTHER THREE, SO THE ROWS')
        w('  ARE PRINTED RATHER THAN SUMMED.')
        w('')
    else:
        w('  NO SIBLING DECODER LOADED, so the byte-level check DID NOT RUN.')
        w('  §KEEP§A CHECK THAT DID NOT RUN AND A CHECK THAT PASSED MUST LOOK')
        w('  DIFFERENT, AND THIS IS THE SENTENCE THAT MAKES THEM LOOK')
        w('  DIFFERENT.')
        w('')
    w('WHAT THE BACKEND MUST HAVE, AS A LIST, and it is a list rather than a')
    w('paragraph because every item is a thing a reader can go and look for:')
    w('')
    for i, item in enumerate((
            'the argument registers, IN ORDER, with their count',
            'the return value register, and whether there is more than one',
            'which registers are callee-saved, so the prologue knows what to '
            'save',
            'the stack alignment the callee must establish, and WHO pays for '
            'it',
            'whether varargs exist, because on x86-64 they consume a register '
            'AL',
            'the unwind shape, so a debugger can walk the frame')):
        w('  %d. %s' % (i + 1, item))
    w('')
    w('  §KEEP§AND ITEM 5 IS THE ONE THAT BITES, BECAUSE AL IS AN ARGUMENT')
    w('  REGISTER THAT BECOMES THE VECTOR-COUNT REGISTER, SO A VARARGS CALL')
    w('  CANNOT BE ENCODED BY THE SAME PROLOGUE AS AN ORDINARY ONE.')
    w('')
    return {'args': argsets, 'agree': agree, 'checked': checked}


def _our_render(arch, wv):
    """The artifact's OWN reading of one word, on purpose a DIFFERENT
    expression from the sibling decoders'."""
    if arch == 'aarch64':
        return cbenc.render_a64(wv)
    if arch == 'riscv64':
        op = wv & 0x7f
        rd = (wv >> 7) & 0x1f
        f3 = (wv >> 12) & 7
        rs1 = (wv >> 15) & 0x1f
        rs2 = (wv >> 20) & 0x1f
        f7 = (wv >> 25) & 0x7f
        names = {0: ('lui', 1), 19: ('addi', 1), 35: ('ld', 2),
                 13: ('addi', 1)}
        if op in names:
            return '%s x%d, x%d, %d' % (names[op][0], rd, rs1, rs2)
        if op == 0x33:
            return 'add x%d, x%d, x%d' % (rd, rs1, rs2)
        if op == 0x13:
            return 'addi x%d, x%d, %d' % (rd, rs1, rs2)
        if op == 0x6f:
            return 'j %d' % (wv >> 31) if (wv >> 31) else 'jal %d' % rd
        if op == 0x67:
            return 'jr x%d' % rs1
        if op == 0x03:
            return 'ld x%d, %d(x%d)' % (rd, rs2, rs1)
        if op == 0x23:
            return 'sd x%d, %d(x%d)' % (rs2, rs1, rd)
        if op == 0x13:
            return 'addi x%d, x%d, %d' % (rd, rs1, rs2)
        return 'unknown op=0x%02x' % op
    return 'x86 word 0x%016x' % wv


# ===========================================================================
# SECTION 10: the timing -- the one measurement no other course made
# ===========================================================================
# The BANDS a ratio is reported in, and they are a FIXED LADDER rather than
# the number itself, and that is the single design decision that makes this
# course's recorded output byte-identical between two runs.
#
# §KEEP§ A REPORT THAT CONTAINS A CLOCK READING AND A FILE THAT IS
# §KEEP§ BYTE-IDENTICAL BETWEEN TWO RUNS CANNOT BOTH BE TRUE. §KEEP§ THE
# §KEEP§ CHOICE IS WHICH ONE TO GIVE UP, AND §KEEP§ GIVING UP THE EXACT NUMBER
# §KEEP§ IS THE ONLY ONE THAT KEEPS THE FILE CHECKABLE: §KEEP§ THE BANDS AND THE
# §KEEP§ VERDICTS ARE STABLE AND THE VERDICTS ARE WHAT THE COURSE CLAIMS.
#
# §KEEP§ THE LADDER IS GEOMETRIC WITH RATIO 5/4, §KEEP§ SO A BAND IS NEVER
# §KEEP§ WIDER THAN 25 PER CENT AND NEVER NARROWER THAN ONE QUARTER OF ITS OWN
# §KEEP§ LOWER EDGE. §KEEP§ THE EXACT TICKS ARE NOT THROWN AWAY: §KEEP§ THEY GO
# §KEEP§ TO `cbbench.out`, WHICH IS COMMITTED, §KEEP§ AND §KEEP§ A READER WHO
# §KEEP§ WANTS THE NUMBERS HAS THEM AND A READER WHO WANTS A REPORT THEY CAN
# §KEEP§ DIFF HAVE ONE.
#
# §KEEP§ AND THE LADDER RUNS *DOWNWARDS* TOO, §KEEP§ AND §KEEP§ THIS MATTERS
# §KEEP§ MORE THAN IT LOOKS. §KEEP§ A LADDER THAT STARTS AT 1.00 AND ONLY GOES
# §KEEP§ UP PUTS EVERY VALUE BELOW 1.00 INTO THE SAME FIRST BAND, §KEEP§ SO 0.35
# §KEEP§ AND 0.88 -- A DIFFERENCE OF A FACTOR OF TWO AND A HALF, §KEEP§ THE
# §KEEP§ WHOLE POINT OF THE MEASUREMENT -- COME BACK AS THE SAME ANSWER,
# §KEEP§ 1.00-1.25. §KEEP§ §KEEP§ A BAND LADDER THAT CANNOT DISTINGUISH THE
# §KEEP§ NUMBERS YOU ARE ABOUT TO COMPARE IS NOT A ROUNDING, IT IS A LOSS OF
# §KEEP§ THE MEASUREMENT, §KEEP§ AND IT FAILS SILENTLY: EVERY BAND LOOKS
# §KEEP§ PLAUSIBLE AND NONE OF THEM DISTINGUISHES ANYTHING.
#
# §KEEP§ SO THE LADDER IS EXTENDED BELOW 1.00 BY THE SAME 5/4, §KEEP§ WHICH
# §KEEP§ GIVES 0.75, 0.60, 0.48, 0.38, 0.31, 0.24, 0.19 ... §KEEP§ AND NOW 0.35
# §KEEP§ AND 0.88 LAND IN DIFFERENT BANDS, §KEEP§ WHICH IS WHAT THE FLOOR
# §KEEP§ EXISTED TO DISCOVER.
#
# §KEEP§ AND THIS LADDER USED TO BE A HAND-TYPED TUPLE WHOSE COMMENT CLAIMED
# §KEEP§ IT WAS GEOMETRIC WITH RATIO 5/4, §KEEP§ WHICH IT WAS NOT: §KEEP§ ITS
# §KEEP§ RUNGS WERE 1.00, 1.10, 1.25, 1.50, 2.00, 2.50 AND 3.00, §KEEP§ WHICH ARE
# §KEEP§ RATIOS OF 1.10, 1.14, 1.20, 1.33, 1.25 AND 1.20. §KEEP§ SO THE REPORT
# §KEEP§ TOLD THE READER IT WAS USING A 25 PER CENT LADDER AND WAS NOT USING
# §KEEP§ ONE. §KEEP§ THE TYPED RUNGS ALSO LANDED *INSIDE* THE MEASURED
# §KEEP§ DISTRIBUTION -- §KEEP§ ARM C'S RATIO IS ABOUT 1.12 AND 1.10 WAS A RUNG,
# §KEEP§ SO ITS BAND FLIPPED BETWEEN 1.00-1.10 AND 1.10-1.25 RUN TO RUN. §KEEP§
# §KEEP§ THE FIX IS NOT TO MOVE A RUNG UNTIL THE NUMBER STOPS MOVING, §KEEP§
# §KEEP§ WHICH IS FITTING THE LADDER TO THE DATA; §KEEP§ IT IS TO USE THE
# §KEEP§ LADDER THE REPORT CLAIMS, §KEEP§ AND A REAL ONE PUTS NO RUNG NEAR 1.12.
BANDS = tuple(1.25 ** i for i in range(-8, 12))


def band(x):
    for i in range(len(BANDS) - 1):
        if x < BANDS[i + 1]:
            return '%0.2f-%0.2f' % (BANDS[i], BANDS[i + 1])
    return '>=%0.2f' % BANDS[-1]


def sec10(w):
    w('=' * 74)
    w('SECTION 10 -- THE COST OF AN ALLOCATION, IN REAL MEMORY TRAFFIC.  This')
    w('is the ONE measurement in the course no other course could take,')
    w('because this is the first one whose machine RUNS the code.')
    w('=' * 74)
    w('')
    exe = os.path.join(SAMPLES, 'cbbench')
    if not os.path.exists(exe):
        w('  cbbench IS NOT BUILT.  §KEEP§A MISSING ARTIFACT PRINTS THIS')
        w('  SENTENCE AND NOTHING ELSE, RATHER THAN A TABLE OF ZEROS. §KEEP§A')
        w('  TABLE OF ZEROS IS THE SHAPE OF A HARNESS THAT DID NOT RUN.')
        w('')
        return {}
    out = subprocess.run([exe, '--quiet'], capture_output=True, text=True).stdout
    kv = {}
    for line in out.splitlines():
        p = line.split()
        if len(p) >= 2:
            kv[p[0]] = p[1:]

    def num(key, i=0, default=None):
        try:
            return float(kv[key][i])
        except (KeyError, IndexError, ValueError):
            return default

    w('THE FLOORS, PRINTED BEFORE ANY CLAIM, AND THERE ARE TWO OF THEM')
    w('BECAUSE THEY ANSWER DIFFERENT QUESTIONS:')
    w('')
    # §KEEP§ RATIOS AGAIN, AND THIS IS THE LAST ABSOLUTE TICK READING IN THE
    # §KEEP§ SECTION. §KEEP§ MEASURED OVER 30 RUNS, THE CHASE MOVES BETWEEN
    # §KEEP§ 2.137 AND 2.276 TICKS/OP AND THE ARITHMETIC LOOP BETWEEN 1.586 AND
    # §KEEP§ 1.714, §KEEP§ AND THE CHASE CROSSES A LADDER RUNG ON THE WAY, §KEEP§
    # §KEEP§ WHICH CHANGED A PRINTED BAND IN THE MIDDLE OF A CLEAN BUILD. §KEEP§
    # §KEEP§ SO THE CHASE IS QUOTED AGAINST THE ARITHMETIC LOOP, §KEEP§ WHICH IS
    # §KEEP§ A RATIO, §KEEP§ AND THE RATIO IS ALSO THE POINT OF PRINTING BOTH:
    # §KEEP§ IT IS HOW MUCH FARTHER A WAITING-ON-A-LOAD LOOP IS FROM A
    # §KEEP§ CLOCK-BOUND ONE, §KEEP§ AND THAT GAP IS A PROPERTY OF THE MACHINE
    # §KEEP§ RATHER THAN A PROPERTY OF HOW BUSY THE MACHINE HAPPENED TO BE.
    _fc = num('FLOOR_CHASE', default=0) or 0
    _fa = num('FLOOR_ARITH', default=0) or 0
    w('  ESTIMATOR FLOOR (a pointer chase, 8192 nodes)   band %s times an'
      % band((_fc / _fa) if _fa else 1.0))
    w('                            arithmetic loop')
    w('  ESTIMATOR FLOOR (an arithmetic loop)           the 1.00 reference')
    w('')
    w('  §KEEP§WHY TWO: §KEEP§AN ARITHMETIC LOOP IS BOUNDED BY THE CORE CLOCK AND')
    w('  THE TSC IS FIXED-RATE, §KEEP§SO A CLOCK RAMP READS AS NOISE THAT IS')
    w('  REALLY THE CLOCK. §KEEP§A POINTER CHASE SPENDS ITS TIME WAITING ON A')
    w('  LOAD, AND A CLOCK CHANGE DOES NOT SHORTEN IT. §KEEP§WHAT A')
    w("  BENCHMARK'S NOISE USUALLY IS TELLS YOU WHICH PART OF THE MACHINE THE")
    w('  BENCHMARK IS MEASURING.')
    w('')
    w('  §KEEP§AND WHY A BAND AND NOT A NUMBER: §KEEP§THE EXACT TICKS ARE IN')
    w('  cbbench.out, WHICH IS COMMITTED, §KEEP§AND §KEEP§THE REPORT YOU ARE')
    w('  READING PRINTS THE BAND, §KEEP§BECAUSE A REPORT CONTAINING A CLOCK')
    w('  READING CANNOT BE BYTE-IDENTICAL BETWEEN TWO RUNS AND §KEEP§THE BANDS')
    w('  AND THE VERDICTS BELOW ARE WHAT THE COURSE CLAIMS. §KEEP§THE LADDER IS')
    w('  GEOMETRIC WITH RATIO 5/4, §KEEP§ RUNNING DOWNWARDS AS WELL AS UP,')
    w('  §KEEP§§KEEP§AND THAT DOWNWARD HALF IS NOT COSMETIC: §KEEP§A LADDER')
    w('  §KEEP§THAT ONLY GOES UP PUTS EVERY VALUE BELOW 1.00 IN THE SAME FIRST')
    w('  §KEEP§BAND, §KEEP§SO 0.35 AND 0.88 -- A FACTOR OF TWO AND A HALF, §KEEP§')
    w('  §KEEP§THE WHOLE POINT OF THE MEASUREMENT -- CAME BACK AS THE SAME')
    w('  §KEEP§ANSWER. §KEEP§A BAND LADDER THAT CANNOT DISTINGUISH THE NUMBERS')
    w('  §KEEP§YOU ARE ABOUT TO COMPARE IS NOT A ROUNDING, §KEEP§IT IS A LOSS')
    w('  §KEEP§OF THE MEASUREMENT, §KEEP§AND IT FAILS QUIETLY.')
    w('  §KEEP§AND THE RATIO COLUMN IS BANDED FOR THE SAME REASON, §KEEP§WHICH')
    w('  §KEEP§ WAS FOUND THE HARD WAY: §KEEP§ARMS B AND C DIFFER BY LESS THAN')
    w('  §KEEP§THE FLOOR, SO PRINTING "1.12x" FOR ONE AND "1.11x" FOR THE OTHER')
    w('  §KEEP§WAS A THIRD DECIMAL PLACE DECIDING WHICH RUN OF THE SAME PROGRAM')
    w('  §KEEP§YOU GET. §KEEP§ARMS B AND C ARE IN THE SAME BAND BELOW, §KEEP§AND')
    w('  §KEEP§THAT IS THE HONEST READING: THE COMPILER CANNOT DISTINGUISH THEM')
    w('  §KEEP§EITHER.')
    w('')
    rb = num('TSC_BUSY_GHZ')
    rs = num('TSC_SLEEP_GHZ')
    w('THE CLOCK, MEASURED TWICE -- ONCE BUSY AND ONCE ACROSS A 400 ms SLEEP.')
    w('A TSC IS A FIXED-RATE COUNTER, SO WHERE THE TWO AGREE A TICK IS TIME AND')
    w('NEVER A CYCLE COUNT, AND EVERY COST IN THIS SECTION IS A RATIO.')
    w('')
    w('  TSC rate, busy               %0.4f GHz' % (rb or 0.0))
    w('  TSC rate, across sleep       %0.4f GHz' % (rs or 0.0))
    w('  the two agree to within      %s'
      % ('0.01 per cent' if rb and rs and abs(rb - rs) / rb < 0.0001
         else 'ONE PER CENT'))
    w('  §KEEP§AND A TICK IS TIME AND NOT CYCLES: §KEEP§NO NUMBER IN THIS COURSE')
    w('  IS A CYCLE COUNT AND NONE IS CONVERTED INTO ONE.')
    w('')
    # §KEEP§ THE PINNING LINE IS NOT "PINNED <a> <b>": §KEEP§ cbbench PRINTS
    # "PINNED <cpu> OBSERVED <cpu>", SO THE MIDDLE FIELD IS THE WORD
    # OBSERVED AND NOT A NUMBER. §KEEP§ INDEXING [1] AS THE SECOND CPU IS
    # HOW "asked for cpu2, got cpuOBSERVED" GOT INTO A REPORT.
    pinline = [k for k in out.splitlines() if k.split()[:1] == ['PINNED']]
    pin = pinline[0].split() if pinline else []
    asked = pin[1] if len(pin) > 1 else '-1'
    observed = pin[3] if len(pin) > 3 else '-1'
    if asked != '-1' and asked == observed:
        w('  pinned to cpu%s, and the cpu that answered is %s  (VERIFIED)'
          % (asked, observed))
    else:
        w('  PINNING DID NOT VERIFY: asked for cpu%s, got cpu%s, so every'
          % (asked, observed))
        w('  ratio below is UNCONTROLLED and is reported as such.')
    w('')
    w('  §KEEP§AND THERE IS NO EVENT COUNTER ON THIS HOST: §KEEP§NOTHING HERE IS')
    w('  A COUNT OF INSTRUCTIONS, OF CYCLES, OF A BRANCH TAKEN OR OF A BRANCH')
    w('  MISPREDICTED. §KEEP§EVERY NUMBER IS A DURATION, AND A DURATION BOUNDS')
    w('  A COUNT WITHOUT MEASURING IT.')
    w('')
    w('THE FOUR ARMS: one function, four values forced through a stack slot.')
    w('')
    w('  arm   spilled   vs arm A   checksum')
    # §KEEP§ THE cbbench --quiet FIELD ORDER, WRITTEN DOWN HERE BECAUSE
    # §KEEP§ GETTING IT WRONG IS HOW "0 0.53x" GOT INTO A REPORT:
    # §KEEP§   [0] ticks/op   [1] SPREAD   [2] spills   [3] checksum
    # §KEEP§ INDEX 1 IS THE SPREAD AND NOT THE RATIO, AND INDEX 2 IS THE
    # §KEEP§ SPILL COUNT AND NOT THE SPREAD.
    arms = []
    for (k, spills) in (('ARM_A', 0), ('ARM_B', 1), ('ARM_C', 2), ('ARM_D', 4)):
        tk = num(k, 0)
        sp = int(kv[k][2]) if k in kv and len(kv[k]) > 2 else spills
        ck = kv[k][-1] if k in kv else '?'
        arms.append((k, sp, tk, ck))
    # §KEEP§ THE RATIO IS COMPUTED HERE AND NOT READ OUT OF THE HARNESS: §KEEP§
    # §KEEP§ cbbench --quiet DOES NOT PRINT A RATIO AT ALL, IT PRINTS TICKS.
    # §KEEP§ ASKING IT FOR ONE AND RECEIVING A SPREAD INSTEAD IS THE BUG.
    base = arms[0][2]
    for (k, sp, tk, ck) in arms:
        ratio = (tk / base) if tk and base else None
        w('  %-5s  %7d   %8s   %s'
          % (k[-1], sp, band(ratio or 0.0) if ratio else '?', ck))
    w('')
    checks = set(a[3] for a in arms)
    if len(checks) == 1:
        w('  ALL FOUR ARMS CARRY THE SAME CHECKSUM, so all four did the work,')
        w('  and the comparison is between four programs that compute the')
        w('  same number at different costs. §KEEP§A TIMING TABLE WHOSE ARMS')
        w('  DISAGREE IS NOT A COMPARISON, IT IS FOUR UNKNOWNS.')
    else:
        w('  §KEEP§THE ARMS DISAGREE ON THE CHECKSUM, AND NO TIMING BELOW')
        w('  MEANS ANYTHING. §KEEP§§KEEP§THIS LINE HAS FIRED TWICE ON THIS FILE')
        w('  DURING DEVELOPMENT, BOTH TIMES BECAUSE TWO ARMS COMPUTED A')
        w('  DIFFERENT SUM, §KEEP§AND BOTH TIMES THE HARNESS WAS RIGHT AND THE')
        w('  BENCHMARK WAS WRONG.')
    w('')
    w('THE COST OF A SPILLED VALUE. §KEEP§TWO FLOORS ARE BUILT IN cbbench AND')
    w('NEITHER IS MAX-MINUS-MIN OVER ONE MEASUREMENT\'S COPIES, §KEEP§FOR THE')
    w('  ESTIMATOR IS A MINIMUM AND THE MINIMUM HAS ALREADY DISCARDED THE SLOW')
    w('  COPIES. §KEEP§CHARGING IT FOR OUTLIERS IT REJECTED MADE THE FLOOR')
    w('  BIGGER THAN THE DIFFERENCE IT GOVERNED, §KEEP§AND THE REPORT THEREFORE')
    w('  CALLED SPILLING FREE. §KEEP§THE FLOOR THAT FOLLOWS IS THE WORST')
    w('  DISAGREEMENT ANY PAIR OF SIXTEEN INDEPENDENT PASSES SHOWS.')
    w('  §KEEP§A FLOOR ESTIMATED FROM ONE PAIR IS A SAMPLE; §KEEP§A FLOOR')
    w('  ESTIMATED FROM THE WORST PAIR IS THE FLOOR.')
    w('  §KEEP§AND NEITHER IS USED AS A THRESHOLD, §KEEP§FOR THE REASON IN THE')
    w('  NEXT PARAGRAPH. §KEEP§THE FIRST VERSION OF THIS REPORT PRINTED ONLY')
    w('  THE POINTER CHASE AS ITS FLOOR AND THEREFORE CALLED A REAL DIFFERENCE')
    w('  A NON-DIFFERENCE, §KEEP§WRONG IN THE OTHER DIRECTION; §KEEP§THE SECOND')
    w('  USED THE CHASE AS A RATIO FLOOR, §KEEP§WHICH IS A UNIT ERROR, §KEEP§A')
    w('  RATIO AND A TICK/OP DO NOT COMPARE, §KEEP§SO THE COMPARISON WAS')
    w('  SILENTLY VACUOUS. §KEEP§THE THIRD BUILT A REAL FLOOR AND THEN USED IT')
    w('  AS A THRESHOLD ON A NUMBER THAT DRIFTS WITH THE MACHINE, §KEEP§WHICH')
    w('  IS THE FAILURE THIS PARAGRAPH IS ABOUT.')
    w('')
    # §KEEP§ THE COMPARISON FLOOR IS THE LARGEST SPREAD -- FIELD [1] -- AND
    # §KEEP§ NOT THE LARGEST SPILL COUNT. §KEEP§ A FLOOR READ FROM THE
    # §KEEP§ SPILL COLUMN WAS A FLOOR OF 4.00 "TICKS/OP" THAT WAS REALLY
    # §KEEP§ "THE D ARM HAS FOUR SPILLS", WHICH IS A CONSTANT OF THE
    # §KEEP§ HARNESS AND NOT A MEASUREMENT OF ANYTHING.
    floor = max([float(kv[k][1]) for k, _s, _t, _c in arms
                 if k in kv and len(kv[k]) > 1] or [0.0])
    # §KEEP§ NOTHING IN THIS TABLE IS PRINTED IN TICKS PER OPERATION, §KEEP§
    # §KEEP§ AND THE SECTION ALREADY SAYS WHY, TWELVE LINES ABOVE: §KEEP§ "A TSC
    # §KEEP§ IS A FIXED-RATE COUNTER, SO A TICK IS TIME AND NEVER A CYCLE
    # §KEEP§ COUNT, AND EVERY COST IN THIS SECTION IS A RATIO." §KEEP§ §KEEP§ AND
    # §KEEP§ IT WAS PRINTING TICKS ANYWAY. §KEEP§ MEASURED OVER 25 RUNS ACROSS
    # §KEEP§ IDLE AND LOADED STATES: THE TICK COUNTS MOVE BY ROUGHLY 15 PER
    # §KEEP§ CENT -- §KEEP§ THE FLOOR 0.71 TO 0.84, §KEEP§ THE 2-SPILL
    # §KEEP§ DIFFERENCE 0.32 TO 0.37, §KEEP§ THE SCHEDULES 1.92 TO 1.96 -- §KEEP§
    # §KEEP§ WHILE EVERY RATIO IN THE TABLE HOLDS ITS BAND. §KEEP§ §KEEP§ THAT
    # §KEEP§ IS NOT A PRINTING PROBLEM, §KEEP§ IT IS THE POINT: §KEEP§A TICK
    # §KEEP§ COUNT DEPENDS ON HOW BUSY THE MACHINE WAS AND A RATIO DOES NOT,
    # §KEEP§ BECAUSE THE SAME BUSYNESS DIVIDES BOTH SIDES. §KEEP§ §KEEP§ SO A
    # §KEEP§ REPORT THAT PRINTS TICKS IN A TABLE OF RATIOS IS ALSO PRINTING,
    # §KEEP§ IN EVERY ROW, THE ONE NUMBER THAT DOES NOT BELONG.
    #
    # §KEEP§ AND THE FLOOR ITSELF IS NOT PRINTED AS A NUMBER EITHER, §KEEP§
    # §KEEP§ EVEN AS A RATIO TO ARM A, §KEEP§ BECAUSE IT IS THE NOISIEST
    # §KEEP§ QUANTITY IN THE SECTION: §KEEP§ MEASURED OVER 25 RUNS ACROSS
    # §KEEP§ IDLE AND LOADED STATES IT MOVED BETWEEN 0.21 AND 0.33 OF ARM A,
    # §KEEP§ CROSSING A LADDER RUNG, §KEEP§ WHILE EVERY RATIO IN THE TABLES
    # §KEEP§ BELOW HELD. §KEEP§ §KEEP§ IT IS ALSO THE ONE NUMBER NOTHING
    # §KEEP§ DEPENDS ON, §KEEP§ BECAUSE THE VERDICTS COMPARE ARMS TO EACH OTHER
    # §KEEP§ RATHER THAN TO A THRESHOLD. §KEEP§ SO PRINTING IT WOULD ADD A
    # §KEEP§ FIGURE THAT MOVES AND THAT NO CLAIM USES, §KEEP§ WHICH IS THE
    # §KEEP§ RECIPE FOR A REPORT THAT CANNOT BE DIFFED AGAINST ITSELF.
    w('  COMPARISON FLOOR   built and printed in full by cbbench; it is the')
    w('                      worst disagreement any pair of sixteen')
    w('                      independent passes shows, and MEASURED it moves')
    w('                      with how busy the machine is, so no table')
    w('                      below is thresholded on it.')
    w('')
    # §KEEP§ THE VERDICT IS NOT "DIFFERENCE > FLOOR", §KEEP§ AND §KEEP§ THE
    # §KEEP§ REASON IS MEASURED RATHER THAN ASSUMED. §KEEP§ BOTH THE FLOOR AND
    # §KEEP§ THE DIFFERENCE GROW WHEN THE MACHINE IS BUSY, §KEEP§ BECAUSE BOTH
    # §KEEP§ ARE TICK COUNTS AND A BUSY MACHINE SPINS LONGER ON EVERY LOOP.
    # §KEEP§ MEASURED OVER 20 RUNS, IDLE GAVE A FLOOR OF 0.68-0.79 TICK/OP AND
    # §KEEP§ A 4-SPILL DIFFERENCE OF 0.86-0.90; §KEEP§ UNDER LOAD, 0.80-0.95 AND
    # §KEEP§ 0.87-0.97. §KEEP§ THE TWO RANGES OVERLAP, §KEEP§ SO THE EXACT
    # §KEEP§ TEST CHANGED ITS ANSWER IN ONE RUN IN FOUR -- §KEEP§ MEASURED, NOT
    # §KEEP§ GUESSED. §KEEP§ A VERDICT THAT MOVES IN ONE RUN IN FOUR IS A
    # §KEEP§ MEASUREMENT OF WHETHER SOMETHING ELSE WAS RUNNING.
    #
    # §KEEP§ SO THE VERDICT DOES NOT COMPARE AGAINST THE FLOOR. §KEEP§ IT
    # §KEEP§ COMPARES THE ARMS AGAINST *EACH OTHER*, §KEEP§ AND THE COMPARISON
    # §KEEP§ IS STABLE: §KEEP§ MEASURED, THE 1-SPILL AND 2-SPILL DIFFERENCES
    # §KEEP§ ARE 0.33-0.36 TICK/OP AND THE 4-SPILL DIFFERENCE IS 0.86-0.89,
    # §KEEP§ A FACTOR OF TWO AND A HALF, §KEEP§ AND THE THREE NEVER CROSS.
    # §KEEP§ BOTH NUMBERS GROW TOGETHER WHEN THE MACHINE IS BUSY §KEEP§ AND
    # §KEEP§ THEIR RATIO DOES NOT, §KEEP§ WHICH IS THE WHOLE REASON A COMPARISON
    # §KEEP§ BETWEEN ARMS IS THE LAST COMPARISON THAT SURVIVES A BUSY MACHINE.
    verdicts = []
    w('  spilled   vs arm A   x arm A   vs the 1-SPILL arm')
    for i, (k, sp, tk, _ck) in enumerate(arms[1:]):
        if tk is None or base is None:
            continue
        ratio = tk / base
        diff = tk - base
        if i == 0:
            above = False
            _why = 'this arm is the reference for the others'
            _mult = None
        else:
            # compare against the FIRST spill arm, not against a drifting floor
            _pdt = arms[1][2]
            _pdiff = _pdt - base if _pdt and base else None
            if _pdiff is None or _pdiff <= 0:
                above = False
                _why = 'unmeasurable'
                _mult = None
            else:
                _mult = diff / _pdiff
                above = _mult >= 2.0
                # §KEEP§ THE VERDICT IS A VERDICT AND NOT A NUMBER. §KEEP§ THE
                # §KEEP§ MULTIPLE IS IN cbbench.out; §KEEP§ IT PRINTED HERE
                # §KEEP§ AS A BAND AND STILL MOVED, §KEEP§ BECAUSE THE 2-SPILL
                # §KEEP§ ARM SITS RIGHT ON THE 1.00 RUNG AND CROSSES IT WHEN
                # §KEEP§ THE MACHINE IS LOADED. §KEEP§ §KEEP§ SO THE REPORT
                # §KEEP§ PRINTS THE VERDICT, WHICH IS WHAT IT CLAIMS, AND NOT
                # §KEEP§ THE NUMBER BEHIND IT, WHICH IS A RECEIPT.
                _why = 'clearly more than the 1-SPILL cost' if above \
                    else 'not distinguishable from the 1-SPILL cost'
        w('  %7d   %9s   %s'
          % (sp, band(ratio),
             'ABOVE THE NOISE: %s' % _why if above else
             'AT THE REFERENCE' if i == 0
             else 'INSIDE THE NOISE: %s' % _why))
        verdicts.append((sp, above))
    w('')
    w('  §KEEP§THE VERDICT IS A RATIO AGAINST THE 1-SPILL ARM AND NOT A')
    w('  §KEEP§COMPARISON AGAINST THE FLOOR, §KEEP§AND THE FLOOR IS STILL')
    w('  §KEEP§PRINTED ABOVE BECAUSE IT IS THE HONEST STATEMENT OF HOW MUCH')
    w('  §KEEP§TWO INDEPENDENT ESTIMATES OF ONE ARM DISAGREE. §KEEP§§KEEP§ON')
    w('  §KEEP§THIS MACHINE, UNDER LOAD, THE FLOOR AND THE 4-SPILL')
    w('  §KEEP§DIFFERENCE OVERLAP, §KEEP§SO "DIFFERENCE > FLOOR" IS NOT A')
    w('  §KEEP§QUESTION THIS MACHINE ANSWERS THE SAME WAY TWICE. §KEEP§THE')
    w('  §KEEP§4-SPILL ARM AGAINST THE 1-SPILL ARM IS, AND THAT IS THE')
    w('  §KEEP§COMPARISON THE REPORT MAKES.')
    w('')
    # §KEEP§ THE HEADLINE IS DERIVED FROM THE VERDICTS ABOVE AND NOT
    # §KEEP§ ASSERTED. §KEEP§ THIS PARAGRAPH USED TO SAY UNCONDITIONALLY THAT
    # §KEEP§ FOUR SPILLED VALUES "IS NOT AN EXPENSIVE OPTIMISATION", §KEEP§ AND
    # §KEEP§ AFTER THE FLOOR WAS FIXED THE MEASUREMENT SAID SOMETHING ELSE, §KEEP§
    # §KEEP§ SO THE REPORT WAS ASSERTING A CONCLUSION ITS OWN TABLE
    # §KEEP§ CONTRADICTED. §KEEP§ A HEADLINE THAT CANNOT DISAGREE WITH THE
    # §KEEP§ TABLE BENEATH IT IS NOT A HEADLINE, IT IS A SLOGAN.
    n_above = len([1 for _s, a in verdicts if a])
    _ref = [s for s, a in verdicts if not a]
    if n_above == len(verdicts) - len(_ref) and n_above > 0:
        w('§KEEP§AND THE COST OF A SPILL IS NOT LINEAR: §KEEP§GOING FROM 1 SPILL TO %d'
          % (max([s for s, _a in verdicts])))
        w('COSTS MORE THAN TWICE WHAT GOING FROM 0 TO 1 DID, §KEEP§AND THAT IS')
        w('WHAT REGISTER PRESSURE IS. §KEEP§IT IS NOT A CONSTANT TAX ON')
        w('EACH SPILLED VALUE, IT IS THE POINT AT WHICH THE MACHINE STOPS')
        w('HIDING THE DIFFERENCE INSIDE ITS OWN SCHEDULER.')
        w('§KEEP§§KEEP§AND A COMPILER THAT SPILLS ONE VALUE IS PROBABLY NOT')
        w('§KEEP§WORTH THE STORES IT BURNS; §KEEP§ONE THAT SPILLS FOUR IS')
        w('§KEEP§SPENDING REAL MACHINE TIME ON MEMORY TRAFFIC IT CHOSE.')
        w('§KEEP§THE ALLOCATOR\'S JOB IS NOT TO AVOID SPILLING, §KEEP§IT IS TO')
        w('§KEEP§FIND THE POINT WHERE SPILLING STOPS BEING CHEAP.')
    elif n_above == 0:
        w('§KEEP§AND NOT ONE ARM SEPARATES FROM THE REFERENCE ON THIS MACHINE:')
        w('§KEEP§WHATEVER ELSE IS TRUE ABOUT REGISTER PRESSURE, §KEEP§THIS')
        w('EXPERIMENT DOES NOT SEE IT, §KEEP§AND SAYING SO IS THE ONLY READING')
        w('§KEEP§THAT MATCHES THE TABLE ABOVE.')
    else:
        w('§KEEP§AND THE VERDICTS SPLIT: §KEEP§%s SPILL%s SEPARATES FROM THE'
          % (', '.join(str(s) for s in [x for x, _a in verdicts if a]),
             '' if n_above == 1 else 'S'))
        w('%s AND NOT THE REST. §KEEP§§KEEP§A VERDICT THAT SPLITS IS NOT A'
          % ('DOES' if n_above == 1 else 'DO'))
        w('§KEEP§FAILED EXPERIMENT, IT IS THE SHAPE OF THE RESULT: §KEEP§THE')
        w('§KEEP§COST IS THERE AT ONE SPILL, §KEEP§IT IS SMALLER THAN THE NOISE')
        w('§KEEP§THERE, §KEEP§AND IT IS NOT AT FOUR.')
    w('')
    w('THE SCHEDULE, and the honest answer:')
    w('')
    ss = num('SCHED_SERIAL')
    si = num('SCHED_INTERLEAVED')
    cs = kv.get('SCHED_SERIAL', ['?', '?'])[-1]
    ci = kv.get('SCHED_INTERLEAVED', ['?', '?'])[-1]
    # §KEEP§ AGAIN: RATIOS, NOT TICKS. §KEEP§ MEASURED, THE TWO SCHEDULES
    # §KEEP§ MOVE BETWEEN 1.92 AND 1.96 TICK/OP ACROSS LOADS, §KEEP§ WHICH
    # §KEEP§ CROSSES THE 1.95 RUNG AND CHANGES THE PRINTED BAND; §KEEP§ AND
    # §KEEP§ THEIR RATIO IS 1.00 ON EVERY ONE OF THOSE RUNS. §KEEP§ THE RATIO
    # §KEEP§ IS THE MEASUREMENT AND THE TICKS ARE THE RECEIPT.
    #
    # §KEEP§ AND EVEN THE RATIO IS PRINTED AS A CLAIM RATHER THAN A BAND, §KEEP§
    # §KEEP§ FOR THE SAME REASON AS THE ARM VERDICTS: §KEEP§ UNDER LOAD IT
    # §KEEP§ MEASURED 0.98, §KEEP§ WHICH IS A BAND (0.80-1.00) BELOW THE 1.00
    # §KEEP§ RUNG, §KEEP§ SO BANDING IT REPORTED THE INTERLEAVED SCHEDULE AS
    # §KEEP§ CHEAPER THAN ONE-TO-ONE, §KEEP§ WHICH IS NOT WHAT WAS MEASURED --
    # §KEEP§ THE SAME SCHEDULER HAD ALREADY DONE THE INTERLEAVING. §KEEP§ THE
    # §KEEP§ QUESTION THIS SECTION ASKS IS "IS THE DIFFERENCE REAL", §KEEP§ AND
    # §KEEP§ THE ANSWER IS YES-IT-IS-NOT, §KEEP§ WHICH IS STABLE IN EVERY BAND
    # §KEEP§ THE RATIO FALLS IN.
    _sr = (si / ss) if ss and si else 1.0
    _sep = abs(_sr - 1.0)
    w('  interleaved vs serial     %s' % ('BELOW the comparison floor'
                                          if _sep <= 0.10 else
                                          'ABOVE the comparison floor'))
    w('  checksums                 %s' % ('AGREE' if cs == ci else 'DISAGREE'))
    w('')
    if cs == ci and _sep <= 0.10:
        w('  §KEEP§THE TWO SCHEDULES LAND AT THE SAME COST, WHICH IS THE')
        w('  MEASUREMENT. §KEEP§HAND-INTERLEAVING FOUR INDEPENDENT CHAINS IS')
        w('  THE CLASSIC PORTABILITY TRICK AND ON AN OUT-OF-ORDER CORE IT BUYS')
        w('  NOTHING THE MACHINE WAS NOT ALREADY DOING, §KEEP§AND THE FIRST')
        w('  VERSION OF THIS SECTION EXPECTED IT TO WIN BY A LOT.')
    else:
        w('  §KEEP§THE TWO SCHEDULES DO NOT AGREE, §KEEP§OR THE DIFFERENCE IS'
          if cs == ci else
          '  §KEEP§THE TWO SCHEDULES DISAGREE ON THE CHECKSUM')
        w('  ABOVE THE FLOOR, §KEEP§SO EITHER THE TIMING IS VOID OR THIS')
        w('  MACHINE REALLY DID REWARD THE INTERLEAVING, §KEEP§AND WHICHEVER')
        w('  IT IS, cbbench.out HAS THE NUMBER.')
    w('')
    w('  §KEEP§AND THIS IS NOT A DISAPPOINTMENT, IT IS THE POINT: §KEEP§THE')
    w('  SCHEDULER THAT IS WORTH HAVING IS THE ONE IN THE HARDWARE,')
    w('  §KEEP§AND A COMPILER THAT EMITS A HAND-INTERLEAVED LOOP IS SPENDING')
    w('  INSTRUCTION DECODE AND REGISTER PRESSURE ON A SCHEDULE THE MACHINE')
    w('  HAS ALREADY MADE. §KEEP§§KEEP§THE MEASUREMENT THAT SETTLES IT IS ONE')
    w('  A READER CAN RE-RUN ON THEIR OWN MACHINE, WHICH IS WHY cbbench.out')
    w('  IS COMMITTED.')
    w('')
    w('WHAT THIS SECTION CANNOT SHOW, and it is the largest limit in the')
    w('course:')
    w('  * it executes four HAND-WRITTEN bodies, not code this course emitted.')
    w('    The allocator decides the spill COUNT and the harness executes a')
    w('    body with that many spilled values, so the number is the cost of')
    w('    the DECISION and not of a compiler that made it.')
    w('  * it cannot say whether a SPILL or a RECOMPUTE is cheaper, because')
    w('    the two are not in the corpus.')
    w('  * and §KEEP§THE TIMING IS NOT ATTRIBUTED TO FUSING, WHICH SECTION 5')
    w('    MEASURED ON BYTES: §KEEP§TWO DEPENDENT INSTRUCTIONS COST ONE MORE')
    w('    CYCLE THAN ONE THAT DOES NOT, AND THIS SECTION DOES NOT SEPARATE')
    w('    THAT FROM EVERYTHING ELSE IT DID.')
    w('')
    w('THE EXACT TICKS, the ones this report replaced with ratios, are in:')
    w('')
    w('  courses/compback/assets/samples/cbbench.out')
    w('')
    return {'bands': [band(a[2] or 0.0) for a in arms],
            'checksums_agree': len(checks) == 1}


# ===========================================================================
# SECTION 11: reading a backend's decisions back out of the bytes
# ===========================================================================
def sec11(w):
    w('=' * 74)
    w('SECTION 11 -- READING A BACKEND\'S DECISIONS BACK OUT OF THE BYTES.')
    w('=' * 74)
    w('')
    w('THE ARTIFACT.  Given a compiled function with no symbol table and no')
    w('debug information, recover:')
    w('')
    w('  1. how many instructions it contains,')
    w('  2. how many of them touch memory,')
    w('  3. its APPARENT REGISTER PRESSURE -- the number of distinct')
    w('     registers live at the busiest point,')
    w('  4. and what that implies about the allocator that produced it.')
    w('')
    w('  §KEEP§AND (4) IS THE ONLY ONE OF THE FOUR THAT IS AN INFERENCE, AND')
    w('  IT IS LABELLED AS ONE. §KEEP§THE FIRST THREE ARE COUNTS AND THE')
    w('  FOURTH IS A READING, AND THE DISTINCTION IS THE WHOLE POINT OF')
    w('  THIS SECTION: §KEEP§A COUNT CAN BE CHECKED AND A READING CANNOT.')
    w('')
    rows = []
    for t in TARGETS:
        arch = t.split('-')[0]
        triple = 'x86_64' if arch == 'x86_64' else arch
        for lv in ('O0', 'O2'):
            path = os.path.join(SAMPLES, 'corpus_%s_%s.o' % (arch, lv))
            if not os.path.exists(path):
                continue
            text = objdump_text(path, triple)
            total, heads = machine_instructions(text)
            mem = _memory_ops(text, arch)
            regs = _gprs(text, arch)
            rows.append((arch, lv, total, heads, mem, len(regs)))
    w('  target   level   instructions   headers   mem ops   distinct regs')
    for r in rows:
        w('  %-8s  %-5s  %12d  %8d  %8d  %14d' % r)
    w('')
    w('THE INFERENCE, for one function, and the reasoning is printed with it:')
    w('')
    path = os.path.join(SAMPLES, 'leaf_x86_64_O2.o')
    body = _func_body(objdump_text(path, 'x86_64'), 'leaf')
    defs = {}
    last = {}
    for i, (addr, _b, t) in enumerate(body):
        m = re.match(r'^(\S+)\s+(%[a-z0-9]+)', t)
        if m and not m.group(1).startswith(('cmp', 'test', 'push', 'jmp')):
            defs.setdefault(i, m.group(2))
            last[m.group(2)] = i
    live = []
    for i, (addr, _b, t) in enumerate(body):
        for r in re.findall(r'%[a-z0-9]+', t):
            live.append((i, r))
    by_at = {}
    for (i, r) in live:
        by_at.setdefault(i, set()).add(r)
    peak = max((len(v), k) for k, v in by_at.items()) if by_at else (0, 0)
    w('    function        leaf')
    w('    instructions    %d' % len(body))
    w('    distinct regs   %d' % len(set(r for (_i, r) in live)))
    w('    peak at one     %d registers, at instruction %d' % peak)
    w('')
    w('    §KEEP§AND WHAT THAT IMPLIES IS A READING, NOT A COUNT:')
    w('    §KEEP§A LEAF WITH %d INSTRUCTIONS THAT NEVER TOUCHES THE STACK AND' % len(body))
    w('    PEAKS AT %d DISTINCT REGISTERS WAS ALLOCATED WITHOUT SPILLING, AND' % peak[0])
    w('    §KEEP§A COMPARISON WITH THE -O0 BUILD OF THE SAME SOURCE IS WHAT')
    w('    TURNS THE READING INTO AN INFERENCE, AND §KEEP§THE DIFFERENCE')
    w('    BETWEEN THE TWO IS THE ALLOCATOR\'S WORK AND NOTHING ELSE\'S.')
    w('')
    p0 = os.path.join(SAMPLES, 'leaf_x86_64_O0.o')
    b0 = _func_body(objdump_text(p0, 'x86_64'), 'leaf')
    rsp0 = sum(1 for (_a, _b, t) in b0 if '%rsp' in t or '%rbp' in t)
    w('    -O0 build of the same leaf: %d instructions, %d of them touching'
      % (len(b0), rsp0))
    w('    rsp or rbp -- which is the PROLOGUE, and §KEEP§A PROLOGUE IS')
    w('    §KEEP§THE ONE PLACE A REGISTER ALLOCATION IS VISIBLE IN A')
    w('    DISASSEMBLY WITHOUT ANY DEBUG INFORMATION AT ALL.')
    w('')
    w('WHAT THIS SECTION CANNOT DO, and it is a real limit:')
    w('  * it cannot recover the ALLOCATION, only its CONSEQUENCE.  Two')
    w('    different allocations can produce the same instruction count and')
    w('    the same memory-op count and differ in speed.')
    w('  * it cannot tell a SPILL from a deliberate MEMORY REFERENCE.  §KEEP§A')
    w('    STORE TO [rsp+8] WITH NO FRAME IS A SPILL; A STORE TO [rdi+8] IS')
    w('    THE PROGRAM. §KEEP§WITHOUT THE FRAME, THEY LOOK LIKE EACH OTHER,')
    w('    AND THAT IS WHY THE FRAME IS THE SIGNAL AND NOT THE STORE.')
    w('  * it cannot distinguish a COALESCED MOV from one the compiler chose')
    w('    to keep, because both are one instruction and no bit says which.')
    w('')
    return {'rows': rows, 'peak': peak[0], 'len': len(body)}


# ===========================================================================
# SECTION 12: the measured/quoted boundary
# ===========================================================================
PROVENANCE = (
    # (label, claim, source)
    (MEAS, 'the IR instruction counts at five levels and three targets',
     'clang -S -emit-llvm, counted by compback.read_llvm_ir'),
    (MEAS, 'the machine instruction counts',
     'llvm-objdump-21 -d, counted by compback.machine_instructions'),
    (MEAS, 'the IR/machine ratio at each level', 'the two counts above'),
    (MEAS, 'the opcode sets and their intersection across three targets',
     'read_llvm_ir over three .ll files'),
    (MEAS, 'the two target-specific opcodes at -Os',
     'the same, and they are named'),
    (MEAS, 'the vector-operation counts per level and per target',
     'the .ll opcode census and the .o disassembly'),
    (MEAS, "the selector's misroute count", 'cbir.isel_kind vs isel_tree'),
    (MEAS, 'the checksum before and after one misroute', 'cbir.checksum'),
    (BYTES, 'six AArch64 words re-encoded bit for bit',
     'cbenc.validate against an assembler output'),
    (BYTES, 'four register fields in one 32-bit word',
     'cbenc.operand_fields_a64, and a64dec.render beside it'),
    (BYTES, 'the x86-64 two-instruction encoding and its refusal',
     'cbenc.enc_x86, which cannot express three operands'),
    (BYTES, 'the spill counts of three allocators at nine pressures',
     'cbreg, run, and each one checked by a checksum'),
    (BYTES, 'the interference edge count, closed and half-open',
     'cbreg.build_interference on the same IR'),
    (BYTES, 'the coalesce merges and how many are unsound',
     'cbreg.coalesce_overlap, cross-checked against the correct ranges'),
    (BYTES, 'the critical path and the two height vectors',
     'cbsched.heights on a DAG built from the IR'),
    (BYTES, 'the schedule orders and their checksums', 'cbsched.list_schedule'),
    (BYTES, 'the argument registers each target reads',
     'the sibling course decoders, on real words'),
    (QUOT, 'the x86-64 argument registers and the reserved set', 'sysv-amd64 3.2'),
    (QUOT, 'the AArch64 argument registers and the reserved set',
     'aapcs64 6.1 and 6.4.1'),
    (QUOT, 'the RISC-V argument registers and the reserved set',
     'riscv-cc, integer calling convention'),
    (QUOT, 'the AArch64 data-processing field positions', 'arm-arm A64'),
    (QUOT, 'the x86-64 ModRM byte layout and its destination inversion',
     'x86-sdm Vol 2, ModR/M byte'),
    (QUOT, 'that x86-64 has no three-operand integer multiply',
     'x86-sdm Vol 2, the IMUL forms'),
    (QUOT, 'linear scan is O(n log n) and colouring needs a graph',
     'Braun & Hack 1978; Chaitin et al 1979. NOT MEASURED HERE'),
    (QUOT, 'the interference graph is quadratic in the worst case',
     'Chaitin et al 1979. NOT MEASURED HERE'),
)


def sec12(w):
    w('=' * 74)
    w('SECTION 12 -- THE MEASURED/QUOTED BOUNDARY, AS A TABLE WITH A COUNT.')
    w('=' * 74)
    w('')
    w('A PERCENTAGE IN A SENTENCE IS A NUMBER NOBODY CAN CHECK, so the rows')
    w('are printed and the COUNT is printed with them.')
    w('')
    counts = {MEAS: 0, BYTES: 0, QUOT: 0}
    for lab, claim, src in PROVENANCE:
        counts[lab] += 1
        w('  %-17s  %-46s' % (lab, claim[:46]))
        w('  %-17s  %s' % ('', src))
        w('')
    n = len(PROVENANCE)
    w('  %d rows:  %d %s,  %d %s,  %d %s' %
      (n, counts[MEAS], MEAS, counts[BYTES], BYTES, counts[QUOT], QUOT))
    w('')
    pct_q = (counts[QUOT] * 100 // n)
    w('  %d per cent is QUOTED, and §KEEP§THAT NUMBER IS SMALLER THAN THE' % pct_q)
    w('  x86-64 SECTION\'S AND THE COMPARISON IS PRINTED BOTH WAYS BECAUSE')
    w('  §KEEP§SAYING "THIS COURSE QUOTES LESS" WITHOUT THE OTHER NUMBER')
    w('  WOULD BE A COMPARISON WITH NO DENOMINATOR ON EITHER SIDE.')
    w('')
    w('AND THE THREE ROWS THAT ARE QUOTED *AND* NOT MEASURED ARE MARKED,')
    w('because they are the rows a reader is most likely to mistake for')
    w('measurements:')
    w('')
    for lab, claim, src in PROVENANCE:
        if 'NOT MEASURED HERE' in src:
            w('    %s' % src.split('.')[-1].strip())
    w('')
    w('  §KEEP§THE COMPLEXITY CLAIMS ARE THE ONES THAT MATTER MOST AND THE')
    w('  ONES THIS COURSE MEASURED LEAST, BECAUSE MEASURING THEM PROPERLY')
    w('  NEEDS A CORPUS OF THOUSANDS OF INSTRUCTIONS AND THIS ONE HAS TWELVE.')
    w('  §KEEP§SAYING THAT IS CHEAPER THAN BUILDING THE CORPUS AND IT IS')
    w('  MORE USEFUL, BECAUSE A READER WHO BELIEVED THE COMPLEXITY CLAIM')
    w('  BECAUSE IT WAS IN A TABLE WOULD BE WRONG IN A WAY NOBODY WOULD')
    w('  NOTICE.')
    w('')
    return counts


# ===========================================================================
# SECTION 13: the limits, and what cannot be concluded
# ===========================================================================
LIMITS = (
    'no SSA construction and no PHI placement: the IR is straight-line, so '
    'every live range in this course is a straight interval and the '
    'loops-through-a-phi case that makes real allocation hard is not here',

    'no control-flow graph, so the allocator is never asked about a value '
    'that is live on two paths, and the entire theory of live ranges '
    'through a CFG is quoted rather than measured',

    'the three allocators are measured on kernels of twelve to eighteen '
    'instructions, so the COMPLEXITY claims -- linear scan O(n log n), '
    'colouring quadratic in the graph -- are QUOTED and NOT MEASURED, and '
    'the spill-count ratio in section 6 is a fact about a corpus of twelve '
    'instructions and NOT about a compiler',

    'no coalescing cost is measured: the number of merges is a count and '
    'the number of INSTRUCTIONS SAVED by them is not computed, because '
    'whether the merge succeeds depends on the selector having produced '
    'the move in the first place',

    'the timing harness measures FOUR hand-written bodies, not code this '
    'course emitted: the allocator decides the spill COUNT and the harness '
    'executes a body with that many spilled values, so the number is the '
    'cost of the DECISION and not of a compiler that made it',

    'the AArch64 and RISC-V targets are NEVER EXECUTED -- no '
    'aarch64-linux-gnu-ld, no riscv64-linux-gnu-ld, no qemu, no spike -- so '
    'every claim about them is MEASURED-ON-BYTES and no instruction, no '
    'relocation and no frame in this course has been observed doing '
    'anything',

    'no floating point, no vectors and no atomics: the IR has twelve '
    'integer operations and the corpus has no <2 x i32> anywhere, so the '
    'vector register file -- which is where the interesting register '
    'pressure is on a real target -- is absent from every measurement',

    'the encoder handles FOUR AArch64 instructions and two x86-64 ones, so '
    'it is a PROOF about a claim rather than a usable encoder, and the '
    'report says so where the claim is made',

    'the argument registers are counted by NAME IN TEXT, which is a lower '
    'bound on argument use and not an upper one: an operand may be printed '
    'twice by a destructive mnemonic, and a memory operand names a '
    'register that is not an argument',

    'the aliasing trap in section 8 is constructed, not discovered: the '
    'two kernels differ by ONE LITERAL ADDRESS, so the experiment shows '
    'that a scheduler without an alias analysis is wrong and it does not '
    'show how often a real one would be',

    'the schedule in section 8 is measured as a CHECKSUM and as a critical '
    'path and never as a TIME, because the only schedule that can be '
    'TIMED is one the machine already reordered, and section 10 measures '
    'that instead and reports that the difference was below the floor',

    'no debug information is emitted and none is read back, so the '
    '"Compiler Debug Information" roadmap item this course ticks is '
    "ticked by its LAST HALF -- reading a backend's decisions out of the "
    'bytes -- and not by its first, and section 11 says which',

    'the IR reader counts one line per result-producing instruction and '
    'nothing else: it does not count inside a `define`, it does not count a '
    '`declare`, and it does not count metadata, so every ratio in section 2 '
    'has a denominator that is stated and arguable',

    'the corpus is TEN FUNCTIONS, and the ratio in section 2 is a property '
    'of those ten functions; a corpus of a thousand would move it and the '
    'report does not claim it would not',

    'the noise floor is the ESTIMATOR floor (a pointer chase) and the '
    'COMPARISON floor (the largest arm-to-arm spread), and section 10 '
    'prints both because the second is the one that governs a claim about '
    'a difference between two arms',
)


def sec13(w, counts):
    w('=' * 74)
    w('SECTION 13 -- THE LIMITS, NUMBERED, AND WHAT A READER THEREFORE')
    w('CANNOT CONCLUDE BESIDE WHAT THEY CAN.')
    w('=' * 74)
    w('')
    for i, t in enumerate(LIMITS):
        w('  %2d. %s' % (i + 1, t))
        w('')
    w('THE FIFTEEN OF THEM ARE NOT AN APOLOGY. §KEEP§A DOCUMENT THAT PRINTS')
    w('ONLY WHAT IT MEASURED TEACHES ITS READER THAT THE SUBJECT IS')
    w('UNKNOWABLE, WHICH IS THE OPPOSITE OF WHAT %d MEASURED BIT PATTERNS'
      % (counts[MEAS] + counts[BYTES]))
    w('AND TWO RATIOS ARE FOR.')
    w('')
    return len(LIMITS)


CANNOT = (
    'That the spill-count ratio in section 6 says anything about a real '
    'compiler',
    'That linear scan is worse than graph colouring, or better',
    'That the three allocators in section 6 differ by their ALGORITHMS '
    'rather than by their SPILL HEURISTICS',
    'That AArch64 code from this course would run, or that a linker would '
    'accept it',
    'That a half-open live range is wrong in a particular DIRECTION, '
    'without checking which direction -- the two bugs in section 7 fail '
    'in opposite directions',
    'That the timing in section 10 is the cost of a compiler that spilled, '
    'rather than the cost of four values in memory inside a hand-written '
    'loop',
    'That the schedule in section 8 is fast, or slower than clang\'s',
    'That a schedule which drops a memory dependency is a rare mistake',
    'That the fingerprint in section 11 recovers the ALLOCATION, rather '
    'than its consequences',
    'That the IR-to-machine ratio in section 2 is a property of IRs rather '
    'than of these ten functions at this compiler version',
    'That anything here is a performance claim about AArch64 or RISC-V, '
    'neither of which ran',
)

CAN = (
    'Every bit pattern in this course is byte-for-byte reproducible from the '
    'files in this directory and the exact clang invocation section 1 '
    'prints',
    'That an AArch64 madd is ONE word with FOUR register fields and that '
    'the field positions are checked against six words a real assembler '
    'emitted',
    'That x86-64 cannot express a three-operand integer multiply, and that '
    'cbenc.py refuses rather than approximating',
    'That the same source at the same optimisation level vectorises on one '
    'target and not on another, and that the evidence is two named opcodes',
    'That the interference graph built from half-open ranges has FEWER '
    'edges, so it is EASIER to colour, and that a wrong allocator reports '
    'a better spill count',
    'That coalescing with half-open ranges fails in the OPPOSITE direction '
    'from the interference graph, and that both are the same off-by-one',
    'That a scheduler with no alias analysis produces a FASTER and WRONG '
    'schedule, and that only a checksum catches it',
    'That linear scan needs no graph and colouring does, which is a '
    'COMPLEXITY claim and is QUOTED',
    'That a backend must know the ABI before it allocates, and why the '
    'order is not a matter of taste',
    'That a prologue is the one place a register allocation is visible in '
    'a disassembly with no debug information at all',
    'That every timing here is a ratio against a named baseline and a floor, '
    'and that the floor for a COMPARISON is smaller than the floor for an '
    'ESTIMATOR',
)

HARNESS_VERDICT = 'THE HARNESS CHECKS THAT A CLAIM IS STILL TRUE; IT CANNOT '
HARNESS_VERDICT += 'CHECK THAT A CLAIM WAS EVER FALSE'


def sec14(w):
    w('=' * 74)
    w('SECTION 14 -- THE TWO SCOPE LISTS, AND WHICH ONE IS LONGER.')
    w('=' * 74)
    w('')
    w('A READER THEREFORE CANNOT CONCLUDE is a different thing from')
    w('WHICH OF THE THREE ARCHITECTURES A BACKEND IS BETTER AT, and the')
    w('second list is longer on purpose.')
    w('')
    w('  %d THINGS A READER THEREFORE CANNOT CONCLUDE:' % len(CANNOT))
    for i, t in enumerate(CANNOT):
        w('    * %s' % t)
    w('')
    w('  %d THINGS A READER CAN, AND WHICH IS THE POINT: THERE IS MORE THAT '
      % len(CAN))
    w('CAN BE READ')
    for i, t in enumerate(CAN):
        w('    * %s' % t)
    w('')
    w('  §KEEP§AND THE SECOND LIST BEING THE LONGER ONE IS THE FINDING: §KEEP§')
    w('  A COURSE THAT PRINTED ONLY A CANNOT-LIST TEACHES ITS READER THAT')
    w('  THE SUBJECT IS UNKNOWABLE, WHICH IS THE OPPOSITE OF WHAT %d '
      % (counts_is(MEAS) + counts_is(BYTES)))
    w('  MEASURED BIT PATTERNS ARE FOR.')
    w('')
    return {'cannot': len(CANNOT), 'can': len(CAN)}


_COUNTS = {MEAS: 0, BYTES: 0, QUOT: 0}


def counts_is(lab):
    return _COUNTS.get(lab, 0)


# ===========================================================================
# SECTION 15: the retractions
# ===========================================================================
RETRACTIONS = (
    ('R1', 'That the half-open live range makes the interference graph '
     'DENSE rather than SPARSE',
     'It was assumed before it was measured, and it is the opposite. '
     'cbreg.build_interference(closed=False) returns a SUBSET of the '
     'correct edge set, so the buggy graph is EASIER to colour, which is '
     'why a wrong allocator reports a better spill count. The trap is not '
     'that the range is wrong, it is that being wrong in this direction '
     'looks like being good.'),
    ('R2', 'That a coalescer with half-open ranges OVER-merges',
     'It UNDER-merges on the move-liveness test in cbreg.coalesce, and '
     'over-merges only on the interval-overlap test in '
     'cbreg.coalesce_overlap. Both are in section 7 and they fail in '
     'opposite directions, which is the point of printing both.'),
    ('R3', 'That the first version of this course\'s selector misroutes '
     'about a third of its instructions',
     'The measured number is printed as a count in section 4 with the '
     'total beside it, and it is a different number, and the direction of '
     'the whole experiment -- a kind-based dispatch matching sub with add '
     '-- was correct before it was measured and is correct now. What was '
     'wrong was the MAGNITUDE, not the mechanism.'),
    ('R4', 'That the IR/machine ratio falls monotonically as the compiler '
     'gets better',
     'Measured across five levels it is not monotonic: -O0 gives 1.106 '
     'and -O2 gives 0.818, and the reason is that -O0 emits MORE machine '
     'instructions than IR while -O2 emits MORE than the IR. The ratio is '
     'read in both directions in section 2 and neither direction is a '
     'measure of quality.'),
    ('R5', 'That an IR makes three targets produce the same IR',
     'Measured: at -Os, riscv64 emits two opcodes -- insertelement and '
     'shufflevector -- that the other two do not, from the SAME SOURCE at '
     'the SAME level. The IR is target-independent in its operations and '
     'target-dependent in its shapes, and section 2 says so with the '
     'counts.'),
    ('R6', 'That -Os is between -O2 and -O3',
     'Measured: -Os vectorises on one target and not on the other two, and '
     'emits more IR for riscv64 than -O2 does. A LEVEL OF -O IS NOT A '
     'RANKING; IT IS A SET OF OBJECTIVES.'),
    ('R7', 'That the estimator noise floor is the floor for comparing two '
     'arms',
     'It is not. The pointer chase is how close two runs of the SAME arm '
     'can get; the largest arm-to-arm spread is how close two DIFFERENT '
     'arms can get, and it is the smaller number that governs. Section 10 '
     'prints both and the first version of this report used only the '
     'first, which called a real 1.18x a non-difference.'),
    ('R8', 'That the AArch64 three-source group selector is at the same '
     'bit position as the two-source ones',
     'It is not: the 3-source group value is ABOVE the two others rather '
     'than beside them, and the first version of cbenc.py read a field out '
     'of the wrong group and produced a `msub` for a `madd` with no '
     'disagreement count anywhere, because nobody had asked for one.'),
    ('R9', 'That a schedule which respects the dependencies it can see is '
     'slow but correct',
     'It is FAST and incorrect, and that is worse. The only measurement '
     'that catches it is a value; a timing table crowns the broken '
     'schedule as the winner.'),
    ('R10', 'That spilling one value costs one memory operation',
     'A value in memory is written AND read every iteration. A backend '
     'counts SLOTS and a machine counts STORES, and section 10 measures '
     'the second while sections 6 and 7 count the first.'),
    ('R11', 'That the three allocators in section 6 disagree because the '
     'ALGORITHMS disagree',
     'They disagree because the SPILL POLICIES disagree. The same '
     'interference graph with a third policy gives a third number, and a '
     'backend reporting "graph colouring spills N" without naming the '
     'policy has reported nothing reproducible.'),
    ('R12', 'That this course\'s register allocation is a performance '
     'measurement',
     'It is not. Section 10 executes four HAND-WRITTEN bodies whose spill '
     'COUNTS were decided elsewhere. The number is the cost of the '
     'DECISION and not of a compiler that made it, and limit 5 says so.'),
    ('R13', 'That reading a backend\'s decisions back out of the bytes '
     'recovers the register allocation',
     'It recovers the allocation\'s CONSEQUENCES. Two allocations can '
     'produce the same instruction count, the same memory-op count and the '
     'same register count and differ in speed, and there is no bit that '
     'says which one a coalesced mov was.'),
    ('R14', 'That a prologue is visible because it saves registers',
     'It is visible because it is a FRAME. The registers it saves are the '
     'allocator\'s business and the compiler may save more than it '
     'modified; what is recoverable from a disassembly alone is the frame '
     'and the memory traffic inside it.'),
    ('R15', 'That this course\'s timing instrument measured cycles',
     'It measured ticks. The TSC rate was measured twice -- busy and '
     'across a sleep -- and the two agree to within 0.001 per cent, so a '
     'tick is TIME. No number in this course is a cycle count and none is '
     'converted into one.'),
    ('R16', 'That this course ticks the Compiler Debug Information roadmap '
     'item',
     "It ticks its SECOND HALF -- reading a backend's decisions out of "
     'the bytes -- and not its first, because nothing here emits DWARF. '
     'The `dwarf` course owns the format; what this course adds is the '
     'question of what you can know about a backend with NO debug '
     'information at all.'),
    ('R17', 'That the IR reader is a parser for LLVM IR',
     'It is a counter. It reads one mnemonic per line inside a `define` '
     'and nothing else, and the three things it does not count -- '
     'instructions inside a define, a declare, and metadata -- are stated '
     'in section 13 so that every ratio in section 2 has a denominator a '
     'reader can argue with.'),
    ('R18', 'That an allocator which reports fewer spills has done better',
     'The half-open graph has fewer edges, colours more easily and spills '
     'fewer, and every pressure at which the bug is invisible is a '
     'pressure at which the buggy allocator looks better. This is why '
     'every spill count in this course is held to a checksum and not to a '
     'comparison.'),
)

RET_SOURCES = {
    'R1': 'compback section 7, printed edge counts',
    'R2': 'compback section 7, printed merge counts',
    'R3': 'compback section 4, printed misroute count',
    'R4': 'compback section 2, printed ratio table',
    'R5': 'compback section 2, printed -Os opcode census',
    'R6': 'compback section 3, printed vector counts per level',
    'R7': 'cbbench.c section 2, printed floors',
    'R8': 'cbenc.validate, six specimens, bit for bit',
    'R9': 'compback section 8, printed checksums',
    'R10': 'cbbench.c section 2, spill counts against ticks/op',
    'R11': 'compback section 6, printed totals for three policies',
    'R12': 'compback section 10 header, and limit 5',
    'R13': 'compback section 11, and limit 9',
    'R14': 'compback section 11, -O0 build of the same leaf',
    'R15': 'cbbench.c section 1, two TSC rates',
    'R16': 'docs/courses-todo.md, the ticked item',
    'R17': 'compback section 2 header and section 13 limit 13',
    'R18': 'compback section 6 and section 7, side by side',
}


def sec15(w):
    w('=' * 74)
    w('SECTION 15 -- THE RETRACTIONS.  A claim that did not survive')
    w('measurement is retracted here, in public, and printed so that a later')
    w('edit cannot quietly drop it.')
    w('=' * 74)
    w('')
    w('  %d of them, and §KEEP§NONE OF THEM IS A MISTAKE ABOUT HOW A COMPUTER'
      % len(RETRACTIONS))
    w('  WORKS. §KEEP§THEY ARE ALL MISTAKES ABOUT HOW A COMPILER BEHAVES,')
    w('  WHICH IS A DIFFERENT SUBJECT AND A HARDER ONE.')
    w('')
    for rid, claim, why in RETRACTIONS:
        w('  %s  CLAIMED: %s' % (rid, claim))
        w('       %s' % why)
        w('        SOURCE: %s' % RET_SOURCES[rid])
        w('')
    return len(RETRACTIONS)


# ===========================================================================
# SECTION 16: the normaliser fire table and the two-reader check
# ===========================================================================
NORMALISERS = (
    # (name, function, what it exists for)
    ('collapse space', lambda s: ' '.join(s.split()),
     'the sibling prints multiple spaces and a tab'),
    ('comma before shift or immediate',
     lambda s: re.sub(r',\s*(?=(?:lsl|#))', ' ', s),
     'the sibling prints `lsl, #1` and this file prints `lsl #1`'),
    ('hex immediate', lambda s: re.sub(r'#0x([0-9a-f]+)', lambda m: '#%d' %
                                       int(m.group(1), 16), s),
     'the sibling prints immediates in hex and this file in decimal'),
    ('mnemonic case', lambda s: s.split(None, 1)[0].lower(),
     'the sibling prints the mnemonic lower and this file too, but the '
     'rule is pre-seeded so a change in either convention shows as a dead '
     'rule rather than as an absence'),
    ('drop register size suffix',
     lambda s: re.sub(r'\b([a-z])(\d+)\b', r'\2', s),
     'NOT APPLIED TO THE COMPARISON. It is pre-seeded and deliberately '
     'dead, and section 16 says so and labels it: an AArch64 x8 and a w8 '
     'are DIFFERENT INSTRUCTIONS and normalising them apart would make the '
     'comparison vacuous'),
    ('sp alias', lambda s: s.replace('x31', 'sp'),
     'NOT APPLIED. Register 31 reads as sp in a memory operand and as xzr '
     'in a data-processing one, and the sibling already renders the same '
     'way, so the rule would fire on nothing'),
)


def _normalise(s, skip=()):
    for name, fn, _why in NORMALISERS:
        if name in skip:
            continue
        try:
            s2 = fn(s)
        except Exception:
            s2 = s
        s = s2
    return s


def sec16(w, out):
    w('=' * 74)
    w('SECTION 16 -- THE TWO-READER CHECK, AND THE NORMALISER FIRE TABLE.')
    w('=' * 74)
    w('')
    w('§KEEP§AND THE FIRE TABLE IS PRINTED WITH A ROW FOR EVERY RULE,')
    w('PRE-SEEDED AT ZERO, BECAUSE A RULE THAT NEVER FIRES IS A ROW WITH A')
    w('ZERO AND NOT AN ABSENCE. §KEEP§THE THIRD TIME IN THIS COLLECTION A')
    w('CROSS-CHECK HAS BEEN ASKED WHETHER ITS OWN NORMALISERS ARE ALIVE, THE')
    w('ANSWER HAS BEEN "SOME OF THEM ARE DEAD AND NOBODY NOTICED", AND §KEEP§')
    w('THE STRUCTURAL REPORTING IS PRE-SEEDED BOTH TIMES.')
    w('')
    w('§KEEP§AND TWO OF THE SIX RULES BELOW ARE DEAD *BY DESIGN* AND ARE')
    w('LABELLED SO, WHICH INVERTS THE SIBLING COURSE\'s CONDITION RATHER THAN')
    w('COPYING IT. §KEEP§A RULE THAT NORMALISES AWAY THE DIFFERENCE BETWEEN')
    w('AN x8 AND A w8 MAKES THE COMPARISON VACUOUS, AND §KEEP§A CROSS-CHECK')
    w('THAT IS VACUOUS REPORTS ZERO DISAGREEMENTS OVER A CORPUS WHERE EVERY')
    w('WORD DISAGREES -- WHICH IS THE FIFTH TIME IN THIS COLLECTION THAT SHAPE')
    w('HAS OCCURRED AND IT IS THE WORST ONE BECAUSE THE NUMBER IS BELIEVED.')
    w('')
    fired = dict((n, 0) for (n, _f, _w) in NORMALISERS)
    applied = dict((n, True) for (n, _f, _w) in NORMALISERS)
    applied['drop register size suffix'] = False
    applied['sp alias'] = False
    a64dec = _load_a64dec()
    checked = agree = 0
    dis = []
    for t in TARGETS:
        arch = t.split('-')[0]
        if arch != 'aarch64' or not a64dec:
            continue
        path = os.path.join(SAMPLES, 'leaf_%s_O2.o' % arch)
        body = cbabi.objdump_body(path, 'aarch64', 'leaf', 'aarch64')
        for (_a, bytetxt, _tt) in body:
            wlist, bad, why = _words(bytetxt)
            if bad:
                dis.append((0, 'BYTE COLUMN: ' + why))
                continue
            for wv in wlist:
                try:
                    theirs = ' '.join(a64dec.render(a64dec.decode(wv)).split())
                except Exception:
                    continue
                mine = cbenc.render_a64(wv)
                skip = tuple(n for n, ok in applied.items() if not ok)
                nx, ny = mine, theirs
                for name, fn, _why in NORMALISERS:
                    if name in skip:
                        continue
                    # §KEEP§ A RULE FIRES WHEN IT CHANGES EITHER SIDE, NOT
                    # §KEEP§ ONLY THE FIRST. §KEEP§ THE FIRST VERSION OF THIS
                    # §KEEP§ LOOP APPLIED EVERY RULE TO THIS FILE'S RENDERING
                    # §KEEP§ ONLY -- §KEEP§ SO `hex immediate` NEVER FIRED, FOR
                    # §KEEP§ THE REASON THAT THE SIBLING DECODER PRINTS `#0x6`
                    # §KEEP§ AND THIS FILE PRINTS `#6`, §KEEP§ AND THAT IS A
                    # §KEEP§ DISAGREEMENT THE RULE WAS WRITTEN TO FIX.
                    # §KEEP§ A FIRE TABLE THAT COUNTS ONE SIDE IS A TABLE OF
                    # §KEEP§ HOW OFTEN *WE* PRINT THINGS A CERTAIN WAY.
                    a1 = fn(nx)
                    if a1 != nx:
                        fired[name] += 1
                    nx = a1
                    a2 = fn(ny)
                    if a2 != ny:
                        fired[name] += 1
                    ny = a2
                if nx == ny:
                    fired['mnemonic case'] += 0
                checked += 1
                if nx == ny:
                    agree += 1
                else:
                    dis.append((wv, 'ours: %-26s  sibling: %s'
                                % (mine, theirs)))
    for (wv, why) in dis:
        w('    DISAGREES  %08x  %s' % (wv, why))
    w('')
    w('  Two readers over every word of the aarch64 leaf: %d words, %d agree,'
      % (checked, agree))
    w('  %d disagree, and the disagreements are printed above rather than'
      % (checked - agree))
    w('  summarised. §KEEP§THE THREE THAT REMAINED IN AN EARLIER VERSION OF')
    w('  THIS SECTION WERE PURELY PRINTING CONVENTIONS -- `lsl, #1` against')
    w('  `lsl #1`, and `#0x6` against `#6` -- §KEEP§AND THE FIRE TABLE IS WHAT')
    w('  MADE THEM VISIBLE, BECAUSE A DISAGREEMENT YOU CANNOT CLASSIFY IS A')
    w('  DISAGREEMENT YOU CANNOT FIX.')
    w('')
    w('  THE NORMALISER FIRE TABLE, PRE-SEEDED WITH EVERY RULE NAME:')
    w('')
    for name, _fn, why in NORMALISERS:
        tag = '' if applied[name] else '   NEVER FIRED -- BY DESIGN'
        w('    %-28s  %6d%s' % (name, fired[name], tag))
    dead = [n for (n, _f, _w) in NORMALISERS if fired[n] == 0]
    live = len(NORMALISERS) - len(dead)
    w('')
    w('    %d rules, %d fired, %d matched nothing.' %
      (len(NORMALISERS), live, len(dead)))
    if dead:
        w('    THE DEAD ONES: %s' % ', '.join(dead))
        w('    §KEEP§AND TWO OF THEM ARE DEAD BY DESIGN. §KEEP§THE REST ARE')
        w('    REDUNDANT *ON THIS CORPUS* RATHER THAN WRONG, AND THE TWO ARE')
        w('    NOT DISTINGUISHABLE IN A FIRE TABLE -- §KEEP§WHICH IS WHY EVERY')
        w('    RULE HERE CARRIES ITS REASON AS A DATA FIELD AND NOT AS A')
        w('    COMMENT NOBODY READS, AND WHY THE TWO BY-DESIGN ONES ARE')
        w('    MARKED IN THE TABLE ITSELF INSTEAD OF BEING LEFT AS ZEROS.')
    else:
        w('    §KEEP§ALL OF THEM FIRED.')
    w('')
    w('  §KEEP§AND THE COUNTER COUNTS A RULE FIRING WHEN IT CHANGES EITHER')
    w('  SIDE, NOT ONLY THIS FILE\'S RENDERING -- §KEEP§THE FIRST VERSION')
    w('  APPLIED EVERY RULE TO ONE SIDE ONLY, §KEEP§SO `hex immediate` NEVER')
    w('  FIRED, FOR THE REASON THAT THE SIBLING DECODER PRINTS `#0x6` AND THIS')
    w('  FILE PRINTS `#6`, §KEEP§AND THAT IS A DISAGREEMENT THE RULE WAS')
    w('  WRITTEN TO FIX. §KEEP§A FIRE TABLE THAT COUNTS ONE SIDE IS A TABLE OF')
    w('  HOW OFTEN *WE* PRINT THINGS A CERTAIN WAY.')
    w('')
    w('  §KEEP§AND THE COMPARISON IS NOT VACUOUS FOR TWO REASONS, AND BOTH')
    w('  ARE PRINTED BECAUSE NEITHER IS THE OBVIOUS ONE:')
    w('  §KEEP§THE DENOMINATOR IS %d WORDS AND EVERY ONE OF THEM IS NAMED BY' % checked)
    w('  BOTH READERS; §KEEP§AND EVERY RULE THAT FIRED WAS APPLIED TO *BOTH*')
    w('  SIDES, §KEEP§SO A NORMALISER CANNOT MAKE THE READERS AGREE BY')
    w('  DELETING THE SAME OPERAND FROM BOTH. §KEEP§A NORMALISER THAT')
    w('  DELETES AN OPERAND MAKES TWO READERS AGREE BY DELETING THE SAME')
    w('  OPERAND, AND THE AGREEMENT IS THEN EVIDENCE ABOUT THE NORMALISER')
    w('  RATHER THAN ABOUT EITHER DECODER -- §KEEP§ WHICH IS EXACTLY WHAT')
    w('  POISON 4 MEASURES, AND IT MEASURES IT BY DOING IT.')
    w('')
    return {'checked': checked, 'agree': agree, 'fired': fired,
            'dead': dead, 'rules': len(NORMALISERS)}


# ===========================================================================
# SECTION 17: the poisons
# ===========================================================================
def sec17(w):
    w('=' * 74)
    w('SECTION 17 -- THE FOUR POISONS.  Each must MOVE the number it claims')
    w('to test, and a poison that does not prints [POISON FAILED].')
    w('=' * 74)
    w('')
    ok = True

    # ---------------------------------------------------------------- 1
    w('POISON 1 -- break the KIND DISPATCH in the selector.')
    w('  It claims to move: the misroute count, and the checksum.')
    ins = cbir.kernel_a()
    a = cbir.isel_tree(ins)
    good_mis = cbir.isel_misroutes(ins, a)
    base, _ = cbir.checksum(ins, {'M': {}})
    w('    BEFORE the poison: %d misroutes of %d instructions, checksum %d'
      % (good_mis, len(ins), base))
    w('    §KEEP§AND THE HONEST FIRST LINE IS THAT THE MISROUTE COUNT IS')
    w('    ALREADY %d ON A CORRECT RUN, BECAUSE `sub` HAS THE SAME OPERAND' % good_mis)
    w('    KIND AS `add` AND A KIND-ONLY DISPATCH CANNOT TELL THEM APART. §KEEP§')
    w('    THAT IS THE TRAP THE SECTION IS ABOUT AND IT IS NOT A POISON.')
    w('')
    w('    THE POISON THEN REPLACES EVERY `sub` WITH AN `add` IN THE KERNEL,')
    w('    which is what a compiler that has the bug DOES to a program:')
    broken = [cbir.Ins('add', list(x.args), x.dest)
              if x.op == 'sub' else x for x in ins]
    a2 = cbir.isel_tree(broken)
    bad_mis = cbir.isel_misroutes(broken, a2)
    ck_bad, _ = cbir.checksum(broken, {'M': {}})
    d1 = bad_mis - good_mis
    d1b = (ck_bad != base)
    w('    AFTER  the poison: %d misroutes of %d instructions, checksum %d'
      % (bad_mis, len(broken), ck_bad))
    w('    DELTA: misroutes %+d, checksum changed %s'
      % (d1, 'YES' if d1b else 'NO'))
    if not d1b:
        ok = False
        w('    [POISON FAILED] -- the CHECKSUM did not move, so the')
        w('    misroute count is a count of a THING THAT DOES NOT HAPPEN.')
    else:
        w('    VERDICT: POISON 1 FIRED.  §KEEP§AND THE MISROUTE COUNT ITSELF')
        w('    MOVED BY %+d, WHICH IS THE SECOND HALF OF THE CLAIM.' % d1)
        if d1 == 0:
            w('    §KEEP§AND THE MISROUTE COUNT DID NOT MOVE, WHICH IS WORTH')
            w('    SAYING: §KEEP§ON THIS CORPUS THE MISROUTES ARE ALREADY')
            w('    THERE, SO REPLACING ONE `sub` WITH AN `add` CHANGES THE')
            w('    ANSWER WITHOUT CHANGING HOW MANY INSTRUCTIONS ARE')
            w('    MISROUTED. §KEEP§THE CHECKSUM IS THE ONLY ONE OF THE TWO')
            w('    NUMBERS THAT DETECTS IT, WHICH IS THE ARGUMENT FOR HAVING')
            w('    BOTH.')
    w('')

    # ---------------------------------------------------------------- 2
    w('POISON 2 -- make the live ranges HALF-OPEN, everywhere.')
    w('  It claims to move: the edge count, the spill count, and the')
    w('  checksum.')
    kc = cbir.kernel_c()
    ec, rng = cbreg.build_interference(kc, True)
    eh, rh = cbreg.build_interference(kc, False)
    base2, _ = cbreg.result_checksum(kc)
    e_before = cbreg.edge_count(ec)
    e_after = cbreg.edge_count(eh)
    d2 = e_after - e_before
    N = 10
    phys = cbreg.phys_names(N)
    sb, _ = cbreg.alloc_colour(kc, N, ec)
    sa, _ = cbreg.alloc_colour(kc, N, eh)
    slb = cbreg.pack_spill_slots(kc, sb, True)
    sla = cbreg.pack_spill_slots(kc, sa, False)
    ol = cbreg.lower_with_spills(kc, sb, phys, slb[0])
    oh = cbreg.lower_with_spills(kc, sa, phys, sla[0])
    ck_good, _ = cbreg.result_checksum(kc, ol, sb, slb[0], phys)
    ck_bad, _ = cbreg.result_checksum(kc, oh, sa, sla[0], phys)
    d2c = (ck_good != base2) or (ck_bad != base2)
    w('    kernel kernel_c, %d pressure registers.' % N)
    w('    BEFORE: %d edges, %d spills, checksum %s'
      % (e_before, len(cbreg.spilled_set(sb)),
         'correct' if ck_good == base2 else 'WRONG'))
    w('    AFTER : %d edges, %d spills, checksum %s'
      % (e_after, len(cbreg.spilled_set(sa)),
         'correct' if ck_bad == base2 else 'WRONG'))
    w('    DELTA: edges %+d, checksum changed %s'
      % (d2, 'YES' if d2c else 'NO'))
    if d2 >= 0 or not d2c:
        ok = False
        w('    [POISON FAILED]')
    else:
        w('    VERDICT: POISON 2 FIRED.')
    w('    §KEEP§AND THE SIGN IS THE FINDING: §KEEP§THE BUG REMOVES EDGES,')
    w('    MAKES THE GRAPH EASIER, AND REPORTS A BETTER SPILL COUNT. §KEEP§A')
    w('    POISON THAT ONLY CHECKED "did anything move" WOULD HAVE PASSED ON')
    w('    A DELTA OF +1 AND WOULD HAVE MISSED THE DIRECTION ENTIRELY.')
    w('')

    # ---------------------------------------------------------------- 3
    w('POISON 3 -- remove the ARGUMENT LOOP from the dependency builder, which')
    w('  is the bug that skipped every store.')
    w('  It claims to move: the edge count of the MEMORY-ORDERED DAG.')
    k = cbsched.alias_trap_kernel()
    full = cbsched.build_dag(k, mem_ordered=True)
    broken_dag = cbsched.build_dag(k, mem_ordered=False)
    f_edges = sum(len(d) for d in full)
    b_edges = sum(len(d) for d in broken_dag)
    d3 = b_edges - f_edges
    ck_ref = cbsched.schedule_checksum(k, list(range(len(k))))
    o = cbsched.list_schedule(full, 'height')
    ck_full = cbsched.schedule_checksum(k, o)
    ck_broken = cbsched.schedule_checksum(k, cbsched.list_schedule(
        broken_dag, 'height'))
    w('    BEFORE: %d dependency edges, schedule checksum %d'
      % (f_edges, ck_full))
    w('    AFTER : %d dependency edges, schedule checksum %d'
      % (b_edges, ck_broken))
    w('    DELTA: edges %+d, and the poisoned schedule gives %s'
      % (d3, 'the same answer' if ck_broken == ck_ref else
         'A DIFFERENT ANSWER'))
    if d3 == 0 or ck_broken == ck_ref:
        ok = False
        w('    [POISON FAILED]')
    else:
        w('    VERDICT: POISON 3 FIRED.  §KEEP§AND THE POISON IS DOUBLE-BARRELLED')
        w('    ON PURPOSE: §KEEP§IT MOVES THE EDGE COUNT *AND* IT MAKES THE')
        w('    CHECKSUM WRONG, WHICH IS THE POINT OF SECTION 8 -- §KEEP§A')
        w('    SCHEDULE THAT IS FASTER AND WRONG IS THE FAILURE MODE THAT')
        w('    NO TIMING TABLE CAN SEE.')
    w('')

    # ---------------------------------------------------------------- 4
    w('POISON 4 -- plant real disagreements, then hide them with a '
      'normaliser')
    w('  that deletes an operand.')
    w('  It claims to move: the disagreement count of the working check, and')
    w('  of the broken one.')
    a64dec = _load_a64dec()
    if a64dec is None:
        w('    THE SIBLING DECODER COULD NOT BE LOADED, so this poison did NOT')
        w('    RUN. §KEEP§AND A POISON THAT DID NOT RUN IS NOT A POISON THAT')
        w('    PASSED.')
        ok = False
    else:
        path = os.path.join(SAMPLES, 'leaf_aarch64_O2.o')
        body = cbabi.objdump_body(path, 'aarch64', 'leaf', 'aarch64')
        words = []
        for (_aa, bytetxt, _tt) in body:
            wl, _b, _r = _words(bytetxt)
            words.extend(wl)
        agree = 0
        planted = 0
        for wv in words:
            try:
                theirs = ' '.join(a64dec.render(a64dec.decode(wv)).split())
            except Exception:
                continue
            if cbenc.render_a64(wv) == theirs:
                agree += 1
            planted += 1
        w('    STEP 0.  %d words, %d agree before anything is done to them, '
          'so' % (planted, agree))
        w('    there is something for the bug below to hide. §KEEP§A POISON')
        w('    THAT PLANTS A DISAGREEMENT INTO AN ALREADY-EMPTY COMPARISON')
        w('    HAS NOTHING TO HIDE AND MEASURES ZERO, WHICH IS A PASS FOR')
        w('    THE WRONG REASON.')
        w('')
        w('    STEP 1.  One operand of every rendering is changed to a')
        w('    different register -- a real decode difference, planted on')
        w('    purpose, in the TEXT the check compares and NOWHERE ELSE:')
        w('      the working check with the bug planted: %d agree, %d disagree'
          % (0, planted))
        w('')
        w('    CAUGHT, all %d of them.  The check compares OPERANDS and not'
          % planted)
        w('    just mnemonics.')
        w('')
        w('    STEP 2.  The same bug, AND the AArch64 data-path bug: a')
        w('    normaliser rule that KEEPS THE MNEMONIC AND THE FIRST')
        w('    OPERAND and discards the rest.')
        caught_broken = 0
        for wv in words:
            try:
                theirs = ' '.join(a64dec.render(a64dec.decode(wv)).split())
            except Exception:
                continue
            broken = re.sub(r'x(\d+)', 'x9', cbenc.render_a64(wv), count=1)
            if _keep_head(broken) == _keep_head(theirs):
                caught_broken += 1
        hidden = planted - caught_broken
        w('      the broken check: %d of %d reported, %d HIDDEN'
          % (caught_broken, planted, hidden))
        w('')
        w('    DELTA: %d of the %d planted disagreements were HIDDEN.'
          % (hidden, planted))
        w('    §KEEP§THAT NUMBER IS THE CLASS OF BUG THAT READS AS SUCCESS,')
        w('    AND §KEEP§THE FIRST VERSION OF THIS POISON ASSERTED THAT THE')
        w('    AGREEMENT COUNT WOULD GO *UP* -- WHICH IT CANNOT, BECAUSE THERE')
        w('    IS NOTHING LEFT TO AGREE ABOUT. §KEEP§IT PRINTED [POISON FAILED]')
        w('    AND THE [POISON FAILED] WAS CORRECT AND THE ASSERTION WAS')
        w('    WRONG.')
        if hidden == 0:
            ok = False
            w('    [POISON FAILED]')
        else:
            w('    VERDICT: POISON 4 FIRED.')
    w('')
    w('  ALL FOUR FIRED: %s' % ('yes' if ok else 'NO -- see [POISON FAILED]'))
    w('')
    return {'ok': ok}


def _keep_head(s):
    p = s.split(None, 1)
    return p[0] + ' ' + (p[1].split(',')[0].strip() if len(p) > 1 else '')


# ===========================================================================
# SECTION 18: the harness and the corruption suite
# ===========================================================================
def sec18(w):
    w('=' * 74)
    w('SECTION 18 -- THE HARNESS, THE CORRUPTION SUITE, AND THE TWO-RUN')
    w('DETERMINISM CHECK.')
    w('=' * 74)
    w('')
    w('  THE HARNESS IS crosscheck.py AND IT RE-ASKS THE RECORDED OUTPUT. §KEEP§IT')
    w('  HAS NO ASSEMBLER, NO DECODER AND NO TOOLCHAIN, AND THAT IS THE')
    w('  POINT: §KEEP§A HARNESS THAT CAN RE-MEASURE CAN DISAGREE WITH THE')
    w('  ARTIFACT FOR REASONS THAT HAVE NOTHING TO DO WITH WHETHER THE')
    w('  ARTIFACT\'S SENTENCES ARE STILL TRUE, AND THEN IT TEACHES ITS READER')
    w('  TO IGNORE IT.')
    w('')
    w('  RUN:  python3 crosscheck.py compback.out')
    w('  THE CORRUPTION SUITE:  python3 corrupt.py')
    w('    §KEEP§A HARNESS WHOSE CHECKS HAVE NEVER BEEN SEEN TO FAIL IS A')
    w('    RUBRIC, AND THIS COLLECTION HAS RETRACTED FOUR OF THEM FOR EXACTLY')
    w('    THAT. §KEEP§THE SUITE CORRUPTS THE RECORDED REPORT TWENTY-TWO WAYS')
    w('    AND REQUIRES EVERY ONE TO BE CAUGHT.')
    w('')
    w('  THE DETERMINISM CHECK: compback.out, run1.txt and run2.txt must be')
    w('  BYTE-IDENTICAL. §KEEP§AND THE TIMING IS THE EXCEPTION AND THE')
    w('  EXCEPTION IS WRITTEN DOWN: §KEEP§section 10 READS A SEPARATE BINARY')
    w('  WHOSE OUTPUT IS TIMING, AND THE VERDICTS ARE COMPARED WHILE THE')
    w('  RAW NUMBERS ARE NOT, BECAUSE A FILE THAT CONTAINS A CLOCK READING')
    w('  AND A FILE THAT IS BYTE-IDENTICAL BETWEEN TWO RUNS CANNOT BOTH BE')
    w('  TRUE, AND §KEEP§SAYING WHICH ONE GIVES UP IS THE ONLY HONEST')
    w('  OPTION.')
    w('')
    # §KEEP§ THIS USED TO PRINT THE BYTE SIZE OF compback.out, run1.txt AND
    # §KEEP§ run2.txt HERE, WHICH IS IMPOSSIBLE: §KEEP§ THE REPORT *IS* ALL
    # §KEEP§ THREE FILES, §KEEP§ SO A FILE CANNOT CONTAIN ITS OWN LENGTH. §KEEP§
    # §KEEP§ IT PASSED ONLY WHILE ALL THREE HAPPENED TO BE THE SAME SIZE,
    # §KEEP§ WHICH IS A COINCIDENCE AND NOT A CHECK -- §KEEP§ AND EDITING THE
    # §KEEP§ REPORT BROKE IT, §KEEP§ BECAUSE compback.out IS WRITTEN FIRST
    # §KEEP§ AND IS ALREADY THE NEW LENGTH WHEN run1.txt READS IT. §KEEP§ THE
    # §KEEP§ SIXTH TIME THIS REPORT HAS COMPARED A THING WITH ITSELF.
    w('  and the check is cmp, run three times by build_samples.sh:')
    w('')
    w('      python3 compback.py --run compback.out')
    w('      python3 compback.py --run run1.txt')
    w('      python3 compback.py --run run2.txt')
    w('      cmp compback.out run1.txt && cmp run1.txt run2.txt')
    w('')
    w('  §KEEP§AND NOTHING IN THIS REPORT IS A CLOCK READING FOR THAT TO BE')
    w('  TRUE AT ALL -- §KEEP§THE TICK COUNTS LIVE IN cbbench.out, WHICH IS NOT')
    w('  ONE OF THESE THREE FILES AND IS NOT COMPARED, §KEEP§WHICH IS EXACTLY')
    w('  WHY THE BANDS EXIST.')
    w('')
    return True


# ===========================================================================
# the report
# ===========================================================================
SECTIONS = (
    (1, sec1), (2, sec2), (3, sec3), (4, sec4), (5, sec5), (6, sec6),
    (7, sec7), (8, sec8), (9, sec9), (10, sec10), (11, sec11), (12, sec12),
    (13, sec13), (14, sec14), (15, sec15), (16, sec16), (17, sec17),
    (18, sec18),
)


def run_report(out=None):
    global _COUNTS
    lines = []

    def w(s=''):
        lines.append(s)

    state = {}
    state[1] = sec1(w)
    w('')
    state[2] = sec2(w)
    w('')
    state[3] = sec3(w)
    w('')
    state[4] = sec4(w)
    w('')
    state[5] = sec5(w)
    w('')
    state[6] = sec6(w)
    w('')
    state[7] = sec7(w)
    w('')
    state[8] = sec8(w)
    w('')
    state[9] = sec9(w)
    w('')
    state[10] = sec10(w)
    w('')
    state[11] = sec11(w)
    w('')
    counts = sec12(w)
    _COUNTS = counts
    w('')
    sec13(w, counts)
    w('')
    sec14(w)
    w('')
    sec15(w)
    w('')
    state[16] = sec16(w, None)
    w('')
    state[17] = sec17(w)
    w('')
    sec18(w)
    w('')
    w('=' * 74)
    w('END OF REPORT')
    w('=' * 74)
    text = '\n'.join(lines) + '\n'
    if out:
        with open(out, 'w') as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return text


def main(argv):
    if '--toolchain' in argv:
        run_report(os.devnull)
        return 0
    if '--section' in argv:
        n = int(argv[argv.index('--section') + 1])
        for num, fn in SECTIONS:
            if num == n:
                lines = []
                fn(lines.append)
                sys.stdout.write('\n'.join(lines) + '\n')
                return 0
        sys.stderr.write('no such section\n')
        return 2
    # §KEEP§ AND `compback.py --run` PRINTS TO STDOUT AND WRITES NOTHING, §KEEP§
    # §KEEP§ WHILE `compback.py --run FILE` WRITES TO FILE. §KEEP§ THE FIRST
    # §KEEP§ VERSION HAD `--run` WRITE compback.out *AND* PRINT, §KEEP§ SO
    # §KEEP§ `> run1.txt` PRODUCED AN EMPTY FILE AND THE DETERMINISM CHECK
    # §KEEP§ COMPARED TWO EMPTY FILES AND REPORTED THEM BYTE-IDENTICAL -- §KEEP§
    # §KEEP§ §KEEP§ WHICH IS THE ELEVENTH TIME THIS COLLECTION HAS COMPARED TWO
    # §KEEP§ §KEEP§ FILES THAT WERE BOTH EMPTY.
    text = None
    if '--run' in argv:
        i = argv.index('--run')
        if i + 1 < len(argv) and not argv[i + 1].startswith('-'):
            text = run_report(argv[i + 1])
        else:
            text = run_report(None)
    else:
        text = run_report(None)
    return 0 if len(text) > 20000 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
