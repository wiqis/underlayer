#!/usr/bin/env python3
"""cbir.py -- the IR, and the selector that lowers it.

THIS IS PART ONE OF THE ARTIFACT for "Compiler Backend: From IR to Machine
Code", and it is the part that does not run anything.  Nothing here opens a
file produced by clang, and nothing here shells out to a disassembler.  It is
a small IR, a small pattern language, and a tree-walking selector, written
from scratch, because the mission's rule 1 is "teach it, then rebuild it" and
a reader cannot rebuild a thing whose first half is a call into a library.

WHAT AN IR IS, as used here, and nothing more:

  * a FLAT list of instructions, in a target-independent vocabulary;
  * each instruction names VIRTUAL REGISTERS (`v0`, `v1`, ...) and never a
    physical one, so the same IR can be lowered for three architectures;
  * control flow is explicit and is NOT in this file.  The first kernels the
    artifact emits are straight-line, because instruction selection, register
    allocation and scheduling are three questions about a SEQUENCE of
    operations, and a branch would put a fourth question in the middle of
    them.  The loop the timing harness measures is a separate kernel
    (`cbemit.py`), and the reason is stated there.

THE VOCABULARY IS TWELVE OPERATIONS, and it is the same twelve on all three
targets, which is the entire point of the file:

    add  sub  mul  and  or  xor  shl  shr
    mov  ld   st   call

and nothing else.  A real backend has a hundred more.  The limit is here so
that a reader can hold the whole thing in their head, and section 1 of the
report says so out loud rather than letting the file imply it is complete.

THE THREE-LABEL RULE applies to every claim the report makes about this file.
The selector's *behaviour* is MEASURED (it is run, on a real corpus, and its
output is counted).  Its *contents* -- the fact that these twelve operations
are the ones a real x86-64 backend must all be able to express -- is QUOTED
from the instruction set manuals, with the document named.
"""

import re

MEAS = 'MEASURED'
BYTES = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

# The twelve operations, and the operand kinds each takes.  `kind` is what
# makes the trap in `isel` possible at all: an ADD and a SUB have the SAME
# operand kinds, so a matcher that dispatches on kind alone cannot tell them
# apart, and the whole of `isel_trap_count()` is that observation with a
# number attached.
OPS = {
    'add': ('rr', 'rm', 'ri'),
    'sub': ('rr', 'rm', 'ri'),
    'mul': ('rr', 'rm', 'ri'),
    'and': ('rr', 'rm', 'ri'),
    'or':  ('rr', 'rm', 'ri'),
    'xor': ('rr', 'rm', 'ri'),
    'shl': ('rr', 'rm', 'ri'),
    'shr': ('rr', 'rm', 'ri'),
    'mov': ('rr', 'rm', 'ri'),
    'ld':  ('rr', 'mem'),
    'st':  ('mem', 'rm'),
    'call': ('rr', 'mem'),
}

# A pattern is (opcode, kind) plus a REUSABILITY flag, which is what the
# tree-walking selector actually uses.  The flag says whether the matched
# operands may be REUSED as the destination -- that is, whether the machine
# form computes into one of its inputs.  It is TRUE for all nine arithmetic
# operations on x86-64 because they are two-address, and it is the reason
# the backend needs a COPY the IR does not have.
PATTERNS = [
    ('add', 'rr', True),
    ('add', 'rm', True),
    ('add', 'ri', True),
    ('sub', 'rr', True),
    ('sub', 'rm', True),
    ('sub', 'ri', True),
    ('mul', 'rr', True),
    ('mul', 'rm', True),
    ('mul', 'ri', True),
    ('and', 'rr', True),
    ('and', 'rm', True),
    ('and', 'ri', True),
    ('or', 'rr', True),
    ('or', 'rm', True),
    ('or', 'ri', True),
    ('xor', 'rr', True),
    ('xor', 'rm', True),
    ('xor', 'ri', True),
    ('shl', 'rr', True),
    ('shl', 'rm', True),
    ('shl', 'ri', True),
    ('shr', 'rr', True),
    ('shr', 'rm', True),
    ('shr', 'ri', True),
    ('mov', 'rr', True),
    ('mov', 'rm', False),
    ('mov', 'ri', False),
    ('ld', 'rr', False),
    ('ld', 'mem', False),
    ('st', 'mem', False),
    ('st', 'rm', False),
    ('call', 'rr', False),
    ('call', 'mem', False),
]


class Ins(object):
    """One IR instruction.  `defs` and `uses` are LISTS because `call` has
    none and one, and because a future version of this file will need an
    operation with two destinations.  A reader who notices that a real IR
    has operations with two DESTINATIONS has understood more about the
    problem than the file states."""

    __slots__ = ('op', 'kind', 'args', 'dest', 'text')

    def __init__(self, op, args, dest=None, text=None):
        self.op = op
        self.kind = None
        self.args = list(args)
        self.dest = dest
        self.text = text

    def __repr__(self):
        d = ('%s = ' % self.dest) if self.dest else ''
        return '%s%s %s' % (d, self.op, ', '.join(self.args))


def vreg(n):
    return 'v%d' % n


def is_reg(a):
    """Is this operand a REGISTER rather than an immediate or an address?

    The check is a shape test on the name and nothing else, and that is the
    whole convention: virtual registers are `v` plus digits.  A reader who
    wonders what happens to a virtual register named `x` should read this
    line and then read the IR constructors below, and the answer is that
    there are none.

    THE CONSEQUENCE, which is worth stating because it is a class of bug and
    not a slip: an immediate that leaked into the live-range table would be
    treated as a value with a live range, would get a register, and would
    then be compared against another immediate -- so the bug is invisible in
    the allocator and visible only in the checksum.  `simulate` is what
    catches it, which is why this file has an interpreter at all.
    """
    return len(a) > 1 and a[0] == 'v' and a[1:].isdigit()


def live_ranges(insns, nregs=None):
    """A live range per virtual register, as INCLUSIVE [start, end].

    THE INCLUSIVE END IS THE WHOLE COURSE'S CENTRAL TRAP, so it is stated
    here in the function that computes the ranges rather than in a section
    eleven pages away.

    A register is live from the instruction that DEFINES it (inclusive) to
    the instruction that last USES it (INCLUSIVE -- that is the point).  A
    half-open range would end one instruction early, which is correct for a
    register whose value is *read* at the same instruction that kills it and
    wrong for one that is *defined* there.  `cbreg.build_interference(closed
    =False)` builds the bug on purpose; this function is the version that is
    correct, and the two are compared edge-for-edge in the report.

    Returns a dict vreg -> (first_def, last_use), both INCLUSIVE.
    """
    first = {}
    last = {}
    for i, ins in enumerate(insns):
        if ins.dest is not None and is_reg(ins.dest):
            first.setdefault(ins.dest, i)
            last[ins.dest] = i
        for a in ins.args:
            if not is_reg(a):
                continue
            if a in first:
                last[a] = i
            else:
                # a use with no def in this straight-line kernel is a
                # function ARGUMENT, live from the entry
                first.setdefault(a, 0)
                last[a] = i
    for a in first:
        if a not in last:
            last[a] = len(insns) - 1
    return dict((k, (first[k], last[k])) for k in first)


def overlaps(a, b):
    """Do two INCLUSIVE ranges overlap at a program point?

    `a = (0, 3)` and `b = (4, 7)` do not, because instruction 3 and
    instruction 4 are different instructions and a value dies before the
    next one begins.  `a = (0, 4)` and `b = (4, 7)` DO, because
    instruction 4 reads the first and defines the second, so both names are
    live at the same point and a register allocator that gives them the same
    register has produced a program that computes something else.

    THE TRAP IS THE SECOND OF THOSE, and it is the register-allocation
    equivalent of the `aligned(64)` bug this collection has now been bitten
    by six times: a boundary that is off by one in the direction that makes
    an interval look SHORTER, and therefore makes interference look SMALLER
    than it is.
    """
    return not (a[1] < b[0] or b[1] < a[0])


def opclass(a):
    """`v3` -> 'r', `%rbx` -> 'r', `[v1+8]` -> 'm', `12` -> 'i'."""
    if a.startswith('v') and a[1:].isdigit():
        return 'r'
    if a.startswith('['):
        return 'm'
    if a.startswith('%'):
        return 'r'
    try:
        int(a, 0)
        return 'i'
    except ValueError:
        return 'r'


def kind_of(ins):
    """The operand KIND of an IR instruction, from its operands.

    This is the function the trap is built on.  It returns a KIND, never an
    OPERATION, so `add v0, v1, v2` and `sub v0, v1, v2` are the same kind
    and a matcher keyed on kind alone matches both.  The reason is not a
    defect in this function: it is the shape of the IR.  An IR that records
    an opcode string has the information; an IR that recorded only operand
    kinds would not, and every IR in wide use records both, which is why the
    trap has to be built by DELIBERATELY IGNORING the opcode.
    """
    if ins.op == 'call':
        return 'call'
    if ins.op == 'ld':
        return 'mem' if ins.args and opclass(ins.args[0]) == 'm' else 'rr'
    if ins.op == 'st':
        return 'mem'
    ks = [opclass(a) for a in ins.args]
    if ks == ['m', 'r']:
        return 'rm'
    if ks == ['r', 'm']:
        return 'mr'
    if ks == ['r', 'r']:
        return 'rr'
    if ks == ['r', 'i']:
        return 'ri'
    if ks == ['i']:
        return 'ri'
    # §KEEP§ A ONE-OPERAND FORM IS 'rr' AND NOT 'r'. §KEEP§ THE DESTINATION
    # §KEEP§ IS A SEPARATE FIELD IN THIS IR, §KEEP§ SO `v20 = mov v3` HAS ONE
    # §KEEP§ OPERAND AND ITS MACHINE FORM STILL HAS TWO -- §KEEP§ AND THE
    # §KEEP§ FIRST VERSION OF THIS FUNCTION RETURNED 'r', §KEEP§ WHICH MATCHED
    # §KEEP§ NO PATTERN IN THE TABLE, §KEEP§ AND EVERY REGISTER-TO-REGISTER
    # §KEEP§ MOVE IN kernel_c WAS REPORTED AS UNSELECTED.
    if ks == ['r']:
        return 'rr'
    return ks[0] if ks else 'none'


# --------------------------------------------------------------------------
# THE SELECTOR.
# --------------------------------------------------------------------------
# Two selectors, and the difference between them is the entire failure mode
# of instruction selection as a technique.
#
#   isel_tree()  dispatches on (opcode, kind) -- the CORRECT selector, and
#                the one every textbook describes.
#   isel_kind()  dispatches on kind alone, because the tree it walks is a
#                kind tree -- the SELECTOR THE TREE IMPLIES rather than the
#                selector that is correct.  It is in this file because the
#                mistake is not a typo; it is what you get if you write the
#                dispatch table from the grammar of the IR's operands instead
#                of from the IR's operations.
#
# Both return a list of machine "actions" as strings.  Nothing is encoded
# here: encoding is `cbenc.py`'s job and a separate question.
def isel_tree(insns):
    out = []
    for ins in insns:
        k = kind_of(ins)
        hit = None
        for (op, kind, reuse) in PATTERNS:
            if op == ins.op and kind == k:
                hit = (op, kind, reuse)
                break
        if hit is None:
            # No pattern: the IR operation has no machine form in this
            # table, and the honest backend result is NOT a silent skip.
            # §KEEP§ THE TUPLE HAS FOUR ELEMENTS LIKE EVERY OTHER ONE HERE,
            # §KEEP§ BECAUSE THE FIRST VERSION OF THIS BRANCH APPENDED THREE
            # §KEEP§ AND EVERY CALLER THAT READS index 1 GOT THE OPCODE
            # §KEEP§ INSTEAD OF THE KIND -- §KEEP§ WHICH MADE `UNSELECTED`
            # §KEEP§ COMPARE UNEQUAL TO EVERY REAL ROUTE AND REPORTED A
            # §KEEP§ MISROUTE THAT WAS NOT ONE.
            out.append(('UNSELECTED', None, False, ins))
            continue
        out.append((hit[0], hit[1], hit[2], ins))
    return out


def isel_kind(insns):
    """THE SELECTOR THE TREE IMPLIES, AND NOT THE ONE THAT IS CORRECT.

    §KEEP§IT IS HERE BECAUSE THE MISTAKE IS NOT A TYPO: §KEEP§IT IS WHAT YOU
    §KEEP§ GET IF YOU WRITE THE DISPATCH TABLE FROM THE GRAMMAR OF THE IR'S
    §KEEP§ OPERANDS INSTEAD OF FROM THE IR'S OPERATIONS. §KEEP§A KIND TREE HAS
    §KEEP§ NODES FOR `rr`, `ri`, `mem` AND NOTHING FOR `add` OR `sub`, BECAUSE
    §KEEP§ `add v0, v1, v2` AND `sub v0, v1, v2` HAVE THE SAME OPERANDS AND
    §KEEP§ THE TREE HAS NOWHERE TO PUT THE DIFFERENCE.

    §KEEP§AND SO THE FIRST PATTERN WITH A MATCHING KIND IS TAKEN -- WHICH, IN
    §KEEP§ THE TABLE ABOVE, IS `add` FOR EVERY TWO-OPERAND ARITHMETIC FORM.
    §KEEP§THAT IS THE BUG, WRITTEN AS CODE RATHER THAN DESCRIBED, AND ITS
    §KEEP§ OUTPUT IS COMPARABLE WITH `isel_tree`'s BY THE ONE THING THAT
    §KEEP§ MATTERS: THE MACHINE OPCODE IT WOULD EMIT.

    §KEEP§AND THIS IS ALSO WHY THE MISROUTE COUNT IS NOT A COUNT OF CRASHES.
    §KEEP§THE SELECTOR BELOW NEVER FAILS. §KEEP§IT RETURNS A CONFIDENT
    §KEEP§ ANSWER FOR EVERY INSTRUCTION, AND THE ANSWER IS THE WRONG
    §KEEP§ INSTRUCTION.
    """
    out = []
    for ins in insns:
        k = kind_of(ins)
        hit = None
        for (op, kind, reuse) in PATTERNS:
            if kind == k:
                hit = (op, k, reuse)
                break
        if hit is None:
            out.append(('UNSELECTED', None, False, ins))
            continue
        out.append((hit[0], hit[1], hit[2], ins))
    return out


def isel_misroutes(a, b):
    """How many instructions `isel_kind` routes to the WRONG machine form.

    Measured as a COUNT over the corpus, and the count is compared against
    the total in the same section so a reader can see it is a fraction of
    something rather than a free-standing number.  A selector that misroutes
    one instruction in three is not a selector with a bug; it is a selector
    that produces a program which computes a different function, and the
    report says so and prints the checksum that catches it.
    """
    wrong = 0
    for x, y in zip(isel_kind(a), isel_tree(a)):
        # §KEEP§ THE COMPARISON IS ON THE MACHINE OPCODE AND NOT ON THE
        # §KEEP§ KIND, BECAUSE A KIND-ONLY SELECTOR AND A CORRECT ONE AGREE
        # §KEEP§ ON THE KIND BY CONSTRUCTION -- §KEEP§ THEY BOTH READ THE SAME
        # §KEEP§ KIND OUT OF THE SAME INSTRUCTION -- §KEEP§ AND COMPARING THE
        # §KEEP§ KIND COMPARES A FUNCTION WITH ITSELF.
        if x[0] != y[0]:
            wrong += 1
    return wrong


# The kernel the selector is measured on.  It is written here as IR rather
# than as C so that the reader can see that NOTHING about it is x86-64: the
# same list lowers for three targets and the three lowerings are compared in
# section 4 of the report.
#
# `kernel_a` is straight-line arithmetic with enough simultaneous live
# values to make a register allocator work.  `kernel_b` is the same shape
# with a LOAD and a STORE, so the memory-operand patterns are exercised.
def kernel_a():
    return [
        Ins('mov', ['7'], 'v0'),
        Ins('mov', ['11'], 'v1'),
        Ins('mul', ['v0', 'v1'], 'v2'),
        Ins('add', ['v2', 'v0'], 'v3'),
        Ins('shl', ['v3', 'v1'], 'v4'),
        Ins('and', ['v4', 'v0'], 'v5'),
        Ins('xor', ['v5', 'v2'], 'v6'),
        Ins('or', ['v6', 'v3'], 'v7'),
        Ins('shr', ['v7', 'v0'], 'v8'),
        Ins('sub', ['v8', 'v1'], 'v9'),
        Ins('add', ['v9', 'v0'], 'v10'),
        Ins('mul', ['v10', 'v4'], 'v11'),
    ]


def kernel_b():
    """The same shape plus a LOAD and a STORE, so the memory-operand
    patterns are exercised and so the memory part of the checksum has
    something to fold in.

    The base address is a LITERAL (1024) rather than a register, and the
    reason is a bug this file shipped once.  The first version computed the
    base into `v12` and used `[v12+0]`, which is the realistic thing to do --
    and it made the spill mechanism below have to spill an ADDRESS REGISTER
    as well as a value, which needs a second spill class, an address
    recomputation, and a rule about when the address is still live.  None of
    that is what this file is for.  `cbreg.py`'s spill lowering reloads VALUES
    only, and this kernel's addresses are literals, so the two halves of the
    file do not have to agree about anything except values.

    The cost of that choice is stated rather than hidden: it means these
    kernels do NOT measure the cost of spilling an address, and the report's
    limits section says so.
    """
    return kernel_a() + [
        Ins('ld', ['[1024+0]'], 'v12'),
        Ins('add', ['v11', 'v12'], 'v13'),
        Ins('st', ['[1024+8]', 'v13']),
        Ins('ld', ['[1024+8]'], 'v14'),
        Ins('xor', ['v14', 'v13'], 'v15'),
    ]


def kernel_c():
    """kernel_a with THREE register-to-register MOVEs, which is the only
    thing coalescing has to work with.

    §KEEP§WITHOUT MOVES THE COALESCER MEASURES NOTHING, AND THE FIRST VERSION
    OF THIS FILE HAD THREE KERNELS NONE OF WHICH CONTAINED ONE -- so the
    coalescing section reported ZERO merges on a correct run and printed no
    verdict. §KEEP§ A CONTROL THAT CANNOT MOVE IS A COMMENT THAT SAYS THE
    WORD POISONED, AND A SECTION THAT FINDS NOTHING HAS NOTHING TO REPORT.

    THREE MOVES, AND THEY ARE NOT ALIKE, which is the whole point:

      at 4   `v20 = mov v3`   v3 is DEAD after this -- last use is here
      at 7   `v21 = mov v5`   v5 is DEAD after this
      at 13  `v22 = mov v10`  v10 is USED AGAIN at 14, so it is NOT dead

    The third one is the trap's VICTIM.  A half-open range ends one
    instruction early, so a source whose last use is instruction 14 reads as
    last used at 13 -- the same instruction as the move -- and the
    half-open coalescer merges it.  §KEEP§ THE TWO HALF-OPEN BUGS IN THIS
    COURSE FAIL IN OPPOSITE DIRECTIONS: the interference graph loses edges
    and the coalescer gains a merge it should not make.
    """
    return [
        Ins('mov', ['7'], 'v0'),
        Ins('mov', ['11'], 'v1'),
        Ins('mul', ['v0', 'v1'], 'v2'),
        Ins('add', ['v2', 'v0'], 'v3'),
        Ins('mov', ['v3'], 'v20'),
        Ins('shl', ['v20', 'v1'], 'v4'),
        Ins('and', ['v4', 'v0'], 'v5'),
        Ins('mov', ['v5'], 'v21'),
        Ins('xor', ['v21', 'v2'], 'v6'),
        Ins('or', ['v6', 'v0'], 'v7'),
        Ins('shr', ['v7', 'v0'], 'v8'),
        Ins('sub', ['v8', 'v1'], 'v9'),
        Ins('add', ['v9', 'v0'], 'v10'),
        Ins('mov', ['v10'], 'v22'),
        Ins('mul', ['v22', 'v4'], 'v11'),
        Ins('add', ['v11', 'v10'], 'v12'),
    ]


def kernel_d():
    """FOUR INDEPENDENT CHAINS, WHICH IS WHAT A SCHEDULER IS FOR.

    §KEEP§ EVERY OTHER KERNEL IN THIS FILE IS A DEPENDENCY CHAIN: §KEEP§ EVERY
    §KEEP§ INSTRUCTION WAITS FOR THE ONE BEFORE IT, §KEEP§ THE CRITICAL PATH
    §KEEP§ EQUALS THE INSTRUCTION COUNT, AND THE ILP IS 1.0 FOR ALL OF THEM.
    §KEEP§ THE FIRST VERSION OF THE SCHEDULING SECTION MEASURED ON kernel_a
    §KEEP§ AND PRINTED THREE IDENTICAL SCHEDULES AND CALLED THEM THREE
    §KEEP§ SCHEDULES, §KEEP§ BECAUSE A LIST SCHEDULER GIVEN NO CHOICE
    §KEEP§ RETURNS THE INPUT ORDER THREE TIMES.

    §KEEP§ THE FOUR CHAINS HERE TOUCH DISJOINT REGISTERS AND NOTHING ELSE,
    §KEEP§ SO THE SCHEDULER HAS SOMETHING TO DECIDE AND THE THREE PRIORITIES
    §KEEP§ CAN DISAGREE. §KEEP§ IT IS ALSO THE SHAPE OF THE LOOP BODY IN
    §KEEP§ cbbench.c's SECTION 3, §KEEP§ WHICH IS WHY THE TWO AGREE.
    """
    return [
        # four chains, four registers, nothing shared
        Ins('mov', ['7'], 'v0'),
        Ins('mov', ['11'], 'v1'),
        Ins('mov', ['13'], 'v2'),
        Ins('mov', ['17'], 'v3'),
        Ins('mul', ['v0', 'v1'], 'v4'),
        Ins('mul', ['v2', 'v3'], 'v5'),
        Ins('shl', ['v4', 'v0'], 'v6'),
        Ins('shl', ['v5', 'v2'], 'v7'),
        Ins('xor', ['v6', 'v7'], 'v8'),
        Ins('add', ['v6', 'v5'], 'v9'),
        Ins('or', ['v7', 'v4'], 'v10'),
        Ins('sub', ['v9', 'v8'], 'v11'),
        Ins('add', ['v10', 'v8'], 'v12'),
        Ins('and', ['v11', 'v12'], 'v13'),
        Ins('xor', ['v13', 'v0'], 'v14'),
        Ins('or', ['v14', 'v1'], 'v15'),
    ]


KERNELS = (('kernel_a', kernel_a), ('kernel_b', kernel_b),
           ('kernel_c', kernel_c), ('kernel_d', kernel_d))


def step(ins, e):
    """Execute ONE instruction IN PLACE.

    §KEEP§`simulate` COPIES its environment (`e = dict(env)`) and `trace` does
    too, which is right for both of them -- they are whole-program functions
    and a copy is what makes them pure. §KEEP§ IT IS EXACTLY WRONG FOR THE
    ALLOCATOR, WHICH NEEDS TO READ THE STATE *AFTER* THE LAST USE OF EACH
    VALUE, AND THE FIRST VERSION OF `cbreg.base_values` CALLED `simulate` ON
    ONE INSTRUCTION AT A TIME AND GOT ELEVEN ZEROS. §KEEP§ ELEVEN ZEROS IS
    ALSO WHAT A CORRECT PROGRAM WITH AN ALL-BITS-SET ENVIRONMENT LOOKS LIKE,
    SO THE FIRST VERSION OF THIS CHECK REPORTED SUCCESS ON A COMPLETELY
    BROKEN ALLOCATION.

    So `step` is the in-place primitive, and it is the ONLY function here that
    mutates its argument.
    """
    if ins.op == 'mov':
        e[ins.dest] = _load(ins.args[0], e)
    elif ins.op == 'add':
        if opclass(ins.args[0]) == 'i':
            e[ins.dest] = _imm(ins.args[1], e) + _imm(ins.args[0], e)
        else:
            e[ins.dest] = _imm(ins.args[0], e) + _imm(ins.args[1], e)
    elif ins.op == 'sub':
        e[ins.dest] = _imm(ins.args[0], e) - _imm(ins.args[1], e)
    elif ins.op == 'mul':
        e[ins.dest] = _imm(ins.args[0], e) * _imm(ins.args[1], e)
    elif ins.op == 'and':
        e[ins.dest] = _imm(ins.args[0], e) & _imm(ins.args[1], e)
    elif ins.op == 'or':
        e[ins.dest] = _imm(ins.args[0], e) | _imm(ins.args[1], e)
    elif ins.op == 'xor':
        e[ins.dest] = _imm(ins.args[0], e) ^ _imm(ins.args[1], e)
    elif ins.op == 'shl':
        e[ins.dest] = _imm(ins.args[0], e) << (_imm(ins.args[1], e) & 63)
    elif ins.op == 'shr':
        e[ins.dest] = _imm(ins.args[0], e) >> (_imm(ins.args[1], e) & 63)
    elif ins.op == 'ld':
        base, off = _mem(ins.args[0], e)
        e[ins.dest] = e.get('M', {}).get(base + off, 0)
    elif ins.op == 'st':
        base, off = _mem(ins.args[0], e)
        e.setdefault('M', {})[base + off] = _imm(ins.args[1], e)
    return e


def _load(a, e):
    """Read an operand that may be a register, an immediate, or a memory
    reference.  `mov` needs this and nothing else does, because `mov` is the
    only operation that copies without computing."""
    if a.startswith('['):
        base, off = _mem(a, e)
        return e.get('M', {}).get(base + off, 0)
    return _imm(a, e)


def simulate(insns, env):
    """An interpreter for the IR, and the CHECKSUM the report compares.

    The rule this collection's timing harnesses follow is that every arm has
    to prove it did the work, because an arm that computes the wrong thing
    looks exactly like one that computes the right thing in a timing table.
    Here the proof is arithmetic rather than a checksum: this function
    EVALUATES the IR, and the report runs it on the allocator's output as
    well as on the input, so a misallocation is caught by a number rather
    than by a reader noticing.

    `mov` IS RIGHT-TO-LEFT here -- `mov src, dst` -- so that the IR reads the
    way an assembly listing reads and so that a register-to-register move and
    an immediate-to-register move are the same operation with a different
    first operand.  The IR kernels take NO arguments, which is what makes the
    checksum renaming-invariant: every value in the environment was defined by
    the program itself, so an allocated program and an unallocated one fold
    over the same sequence of definitions.
    """
    e = dict(env)
    for ins in insns:
        v = e.get
        if ins.op == 'mov':
            e[ins.dest] = _load(ins.args[0], e)
        elif ins.op == 'add':
            e[ins.dest] = _imm(ins.args[1], e) + _imm(ins.args[0], e) \
                if opclass(ins.args[1]) == 'i' \
                else _imm(ins.args[0], e) + _imm(ins.args[1], e)
        elif ins.op == 'sub':
            e[ins.dest] = _imm(ins.args[0], e) - _imm(ins.args[1], e)
        elif ins.op == 'mul':
            e[ins.dest] = _imm(ins.args[0], e) * _imm(ins.args[1], e)
        elif ins.op == 'and':
            e[ins.dest] = _imm(ins.args[0], e) & _imm(ins.args[1], e)
        elif ins.op == 'or':
            e[ins.dest] = _imm(ins.args[0], e) | _imm(ins.args[1], e)
        elif ins.op == 'xor':
            e[ins.dest] = _imm(ins.args[0], e) ^ _imm(ins.args[1], e)
        elif ins.op == 'shl':
            e[ins.dest] = _imm(ins.args[0], e) << (_imm(ins.args[1], e) & 63)
        elif ins.op == 'shr':
            e[ins.dest] = _imm(ins.args[0], e) >> (_imm(ins.args[1], e) & 63)
        elif ins.op == 'ld':
            base, off = _mem(ins.args[0], e)
            e[ins.dest] = e.get('M', {}).get(base + off, 0)
        elif ins.op == 'st':
            base, off = _mem(ins.args[0], e)
            e.setdefault('M', {})[base + off] = _imm(ins.args[1], e)
    del v
    return e


def _imm(a, e):
    if opclass(a) == 'i':
        return int(a, 0)
    return e.get(a, 0)


def _mem(a, e):
    m = re.match(r'\[([^\]+]+)([+-]\d+)?\]', a)
    base = m.group(1) if m else a
    off = int(m.group(2), 0) if m and m.group(2) else 0
    return _imm(base, e), off


def trace(insns, env):
    """The VALUE WRITTEN at each definition, in program order.

    This is the list a checksum has to fold, and the choice of this list over
    "the final contents of every register" is the third attempt at getting the
    checksum right, and the reason the first two failed is worth recording.

    Folding the FINAL environment fails because an allocation RENAMES and
    REUSES: twelve virtual registers become seven physical ones, so the two
    programs have different NUMBERS of live bindings at the end, and a fold
    over bindings compares two different-length lists and reports a
    difference where there is none.  A checksum that fails on a correct
    allocation is worse than no checksum, because it teaches its reader to
    ignore it.

    The value written at each DEFINITION is invariant under every legal
    renaming, because the program defines the same logical values in the same
    program order either way.  And it is not commutative-in-effect: a
    clobbered register changes the value written at a later definition, so the
    fold moves.
    """
    e = dict(env)
    seq = []
    for ins in insns:
        v = e.get
        if ins.op == 'mov':
            e[ins.dest] = _load(ins.args[0], e)
            seq.append(e[ins.dest])
            continue
        if ins.op == 'add':
            if opclass(ins.args[0]) == 'i':
                e[ins.dest] = _imm(ins.args[1], e) + _imm(ins.args[0], e)
            else:
                e[ins.dest] = _imm(ins.args[0], e) + _imm(ins.args[1], e)
        elif ins.op == 'sub':
            e[ins.dest] = _imm(ins.args[0], e) - _imm(ins.args[1], e)
        elif ins.op == 'mul':
            e[ins.dest] = _imm(ins.args[0], e) * _imm(ins.args[1], e)
        elif ins.op == 'and':
            e[ins.dest] = _imm(ins.args[0], e) & _imm(ins.args[1], e)
        elif ins.op == 'or':
            e[ins.dest] = _imm(ins.args[0], e) | _imm(ins.args[1], e)
        elif ins.op == 'xor':
            e[ins.dest] = _imm(ins.args[0], e) ^ _imm(ins.args[1], e)
        elif ins.op == 'shl':
            e[ins.dest] = _imm(ins.args[0], e) << (_imm(ins.args[1], e) & 63)
        elif ins.op == 'shr':
            e[ins.dest] = _imm(ins.args[0], e) >> (_imm(ins.args[1], e) & 63)
        elif ins.op == 'ld':
            base, off = _mem(ins.args[0], e)
            e[ins.dest] = e.get('M', {}).get(base + off, 0)
        elif ins.op == 'st':
            base, off = _mem(ins.args[0], e)
            e.setdefault('M', {})[base + off] = _imm(ins.args[1], e)
            continue                       # a store defines NOTHING
        elif ins.op == 'call':
            continue
        else:
            continue
        seq.append(e[ins.dest])
    del v
    return seq


def checksum(insns, env=None):
    """One number for a whole program, so a misallocation cannot hide."""
    seq = trace(insns, dict(env or {}))
    acc = 0
    for v in seq:
        acc = (acc * 31 + (v & 0xffffffffffffffff)) & 0xffffffffffffffff
    return acc, len(seq)