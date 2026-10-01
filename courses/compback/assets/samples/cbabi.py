#!/usr/bin/env python3
"""cbabi.py -- what the backend must know BEFORE it emits anything.

THE OBLIGATION IS NOT THE CONVENTION.  `x86abi`, `a64abi` and `rvabi` each
taught their convention in full -- which registers, which alignment, which
set is preserved.  This file does not teach them again and it quotes them
for exactly one line each.  What this file measures is the BACKEND'S SIDE of
the bargain:

    a backend that emits a call must ALREADY know the argument registers,
    the return register, the callee-saved set and the stack alignment, and it
    must know them BEFORE it has allocated a register to anything

The order matters and it is the whole subject of this course's second module.
Register allocation assigns names to values; the ABI assigns names to
ARGUMENTS.  If the ABI is consulted after allocation then the allocator has
already used `rbx` for a value and the prologue now has to save it -- and a
backend that discovers this late pays a prologue it did not plan for.  So
the measurement below is: for each of the three targets, WHICH REGISTERS DOES
THE COMPILER READ as arguments, read out of the emitted bytes.

NO TOOL DECODES ANYTHING IN THE FIRST HALF OF THIS FILE.  It reads
`llvm-objdump-21` TEXT -- a name and a number -- and counts the occurrences of
each register name.  That is a second reader, not a dependency: the claim is
"the disassembly names `r8` and `r9`", and the artifact is counting names in
a text file rather than asking anything what a word means.  The SECOND half
hands the bytes to the sibling courses' own decoders (`a64dec.py`,
`rvdec.py`) so that the register names this file counted can be checked
against the BITS, and that is the only place a decoder is used.
"""

import os
import re

MEAS = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

# The three conventions, QUOTED, one line each.  The documents are named and
# the sections are named because a convention quoted without a source is a
# habit.
CONVENTIONS = (
    ('x86_64', 'rdi rsi rdx rcx r8 r9',
     'System V Application Binary Interface, AMD64 Architecture Processor '
     'Supplement, "The Function Call Interface", section 3.2.1'),
    ('aarch64', 'x0 x1 x2 x3 x4 x5',
     'Procedure Call Standard for the Arm 64-bit Architecture (AAPCS64), '
     '2025Q1, section 6.1, parameter registers'),
    ('riscv64', 'a0 a1 a2 a3 a4 a5',
     'RISC-V ABIs Specification v1.0, "Integer Calling Convention", the '
     'a0-a7 argument registers'),
)

# What each convention RESERVES, which is the number the allocator has to
# subtract.  QUOTED, same documents.
RESERVED = (
    ('x86_64', 'rsp rbp and, for a function that makes a call, rax',
     'SysV AMD64 supplement 3.2.2: %rsp is the stack pointer; %rbp is the '
     'frame pointer when used; %rax holds the number of vector registers '
     'used by a variadic call'),
    ('aarch64', 'x29 (fp) x30 (lr) and, when used, x16 x17',
     'AAPCS64 6.4.1: x29 is the frame record chain, x30 the link register, '
     'x16/x17 are intra-procedure-call temporaries'),
    ('riscv64', 'x2 (sp) and, for a function that makes a call, x1 (ra)',
     'riscv-cc "Integer Calling Convention": x1 is the return address '
     'register and x2 is the stack pointer; neither is allocatable'),
)


def find_sibling(name, env_var, sibling):
    """Locate a sibling course's artifact by walking UP the tree.

    Inherited unchanged from the RISC-V courses' `find_sibling`, for the same
    reason: a hardcoded relative path breaks the first time a directory
    moves, and a course whose artifact only runs in the layout it was written
    in is a course nobody can re-run.
    """
    env = os.environ.get(env_var)
    if env and os.path.exists(os.path.join(env, name)):
        return env
    d = os.path.dirname(os.path.abspath(__file__))
    for _ in range(8):
        cand = os.path.join(os.path.dirname(d), sibling, 'assets', 'samples')
        if os.path.exists(os.path.join(cand, name)):
            return cand
        nxt = os.path.dirname(d)
        if nxt == d:
            break
        d = nxt
    raise SystemExit('%s not found.  Set %s to the directory holding it.'
                     % (name, env_var))


def objdump_body(path, triple, func='leaf', arch=None):
    """The disassembly of one function, as a list of (address, bytes, text).

    §KEEP§AND THE BYTE COLUMN IS THREE DIFFERENT PRINTING CONVENTIONS ON
    THREE ARCHITECTURES, WHICH IS THE SIXTH TIME IN THIS COURSE THAT A
    DISASSEMBLER'S PRINTING HAD TO BE LEARNED RATHER THAN ASSUMED:

      x86-64    `48 8d 04 77`   four SEPARATE one-byte columns
      AArch64   `8b010408`      ONE eight-digit column, already a 32-bit
                                WORD, and re-splitting it into bytes reverses
                                it -- which is what the first version of
                                this function did, so every AArch64 word
                                this course handed to a decoder was
                                BYTE-REVERSED and the two-reader check
                                reported 0 agrees of 9
      RISC-V    `8b01` or `950e`  two columns, or one four-column word

    §KEEP§ AND THE FIRST REGEX ASKED FOR A SPACE AFTER EVERY BYTE PAIR,
    §KEEP§ WHICH MATCHES NOTHING AT ALL -- `8b010408` HAS ITS SPACES BETWEEN
    §KEEP§ GROUPS AND NOT INSIDE THEM -- §KEEP§ SO THIS FUNCTION RETURNED AN
    §KEEP§ EMPTY LIST FOR EVERY AArch64 OBJECT AND EVERY TWO-READER COUNT
    §KEEP§ OVER AArch64 WAS ZERO. §KEEP§ THE FIFTH TIME IN THIS COLLECTION
    §KEEP§ THAT A ZERO HAS BEEN A BUG WEARING THE COSTUME OF A RESULT.

    `arch` decides the convention and is a REQUIRED argument for that
    reason; when it is absent the column length decides, which is a guess
    and is labelled as one by the caller.
    """
    import subprocess
    out = subprocess.run([OBJDUMP_CMD, '--triple=%s' % triple, '-d', path],
                         capture_output=True, text=True).stdout
    body = []
    started = False
    for line in out.splitlines():
        if re.match(r'^[0-9a-f]+ <%s>:' % re.escape(func), line):
            started = True
            continue
        if not started:
            continue
        # §KEEP§ THE BYTE COLUMN IS *ONE OR MORE* GROUPS AND THE TEXT IS
        # §KEEP§ WHATEVER IS LEFT, SO THE REGEX TAKES THE WHOLE REST OF THE
        # §KEEP§ LINE AND THE SPLIT HAPPENS LATER. §KEEP§ THE FIRST VERSION
        # §KEEP§ USED `(\S+)` FOR THE COLUMN, §KEEP§ WHICH CAPTURES
        # §KEEP§ `8d 04 77` AS ONE TOKEN ON x86-64 -- §KEEP§ AND THEN TREATED
        # §KEEP§ ELEVEN CHARACTERS AS ONE BYTE, §KEEP§ SO EVERY x86-64
        # §KEEP§ INSTRUCTION COUNTED ZERO REGISTERS.
        m = re.match(r'^\s+([0-9a-f]+):\s+(.*)$', line)
        if not m:
            if body:
                break
            continue
        rest = m.group(2)
        mt = re.match(r'((?:[0-9a-f]{2}|[0-9a-f]{8})+(?:\s+(?:[0-9a-f]{2})+)*)'
                      r'\s+(.*)$', rest)
        col = mt.group(1) if mt else rest.split()[0]
        text = (mt.group(2) if mt else '').strip()
        body.append((int(m.group(1), 16), _split_column(col, arch), text))
    return body


OBJDUMP_CMD = os.environ.get('OBJDUMP', 'llvm-objdump-21')


def _split_column(col, arch):
    """The byte column, as a list of hex strings, in the right order.

    AArch64 prints ONE eight-digit group and it is ALREADY the word, so it
    is returned as a single element and the reassembly step leaves it
    alone.  x86-64 and RISC-V print separate byte columns and they are
    returned in file order.
    """
    if arch == 'aarch64':
        return [col]
    parts = col.split()
    if len(parts) == 1 and len(parts[0]) == 8 and re.match(r'^[0-9a-f]{8}$',
                                                            parts[0]):
        # a RISC-V 32-bit word, printed as one group
        return [parts[0]]
    return parts


def count_regs(body, names):
    """How many times each register NAME appears in a function body.

    §KEEP§ THIS COUNTS NAMES IN TEXT, AND THE LIMIT OF THAT IS STATED WHERE
    IT IS USED: an operand may be printed twice by a mnemonic that is
    destructive (x86 `addq %rax, %rdx` prints two names for one register),
    and an operand may be a MEMORY reference naming a register that is not an
    argument (`leaq (%rdi,%rsi,2), %rax` names rdi, rsi and rax, and only the
    first two are arguments). §KEEP§ SO THIS IS A LOWER BOUND ON ARGUMENT
    USE AND NOT AN UPPER ONE, AND EVERY NUMBER IT PRODUCES IS PRINTED WITH
    THE INSTRUCTION COUNT BESIDE IT SO A READER CAN SEE THE DENOMINATOR.
    """
    counts = dict((n, 0) for n in names)
    for (_addr, _bytes, text) in body:
        for n in names:
            counts[n] += len(re.findall(r'(?<![a-z0-9])%s(?![a-z0-9])' % n,
                                        text))
    return counts


def instruction_count(body):
    return len(body)


def callee_saved_written(body, table):
    """Registers the function WRITES, against the callee-saved set.

    A write is a register that appears as the DESTINATION of an
    instruction.  Getting the destination out of disassembly TEXT is a
    different problem per architecture and it is the reason this function
    takes the register table as an argument: x86 prints the destination LAST
    and AArch64 prints it FIRST, and a parser that assumed one of them would
    report the wrong set on the other.  §KEEP§ THE PARSER BELOW HANDLES BOTH
    ORDERS AND SAYS SO, AND THE CLAIM IS CHECKED BY SECTION 9 AGAINST THE
    BITS WITH THE SIBLING DECODERS -- §KEEP§ WHICH IS THE THIRD TIME THIS
    COLLECTION HAS HAD A TEXT-PARSING CLAIM AND A BYTE-LEVEL CLAIM DISAGREE,
    AND IN BOTH EARLIER CASES THE TEXT PARSER WAS RIGHT ABOUT ITS OWN
    GRAMMAR AND WRONG ABOUT THE ARCHITECTURE.
    """
    written = set()
    for (_addr, _bytes, text) in body:
        m = re.match(r'^(\w+)\s+([^,]+)', text.strip())
        if not m:
            continue
        mnem, first = m.group(1), m.group(2).strip()
        if mnem in ('cmp', 'test', 'push', 'jmp', 'call', 'ret'):
            continue
        if mnem.endswith('q') or mnem.endswith('l'):    # x86 AT&T suffix
            written.add(first)
        else:
            written.add(first)                          # AArch64/RISC-V
    hits = sorted(written & set(table))
    return hits


X86_CALLEE_SAVED = ('rbx', 'rbp', 'r12', 'r13', 'r14', 'r15')
A64_CALLEE_SAVED = ('x19', 'x20', 'x21', 'x22', 'x23', 'x24', 'x25', 'x26',
                    'x27', 'x28')
RV_CALLEE_SAVED = tuple('x%d' % i for i in range(9, 28))