# Compiler Backend: From IR to Machine Code — research notes

Working notes for the course whose id is `compback` and whose title is
**Compiler Backend: From IR to Machine Code**. Roadmap items *Compiler
Architecture*, *Instruction Selection*, *Register Allocation*, *Instruction
Scheduling*, *Compiler ABIs* and *Compiler Debug Information* — six of the
`compiler` roadmap's 67 items, and the first course in this collection to
stand between the three architecture sections rather than beside one of them.

Everything here that is a number is also in `assets/samples/compback.out`, and
the harness `assets/samples/crosscheck.py` re-asks every one of them in **171
checks**. `assets/samples/corrupt.py` corrupts the recorded report **27 ways,
and all 27 are caught**, because a harness whose checks have never been seen
to fail is a rubric.

> **A count in this file that disagrees with the artifact.** Section 18 of
> `compback.out` says the corruption suite "corrupts the recorded report
> **twenty-two** ways", and the suite **actually applies 27**. The artifact's
> own sentence is stale — the same defect its R16 retraction warns about, one
> section earlier than expected. The live number comes from `corrupt.py`'s own
> output and the artifact is **not** edited, for the reason in section 6 below.

---

## 1. The position in the chain, and why this course exists

`docs/course-mission.md` defines the spine:

```
lexing → parsing → IR → codegen → object files → linking → loading
```

Both ends are taught here in depth. The ELF course and the object-format
courses take the files apart field by field; `reloc`, `link`, `dyn` and `img`
cover what happens to a pair once the backend has handed one over; three whole
architecture sections take the targets apart instruction by instruction.

**The middle was taught nowhere.** Not thinly — nowhere. There was no course
that took an intermediate representation and asked the three questions a
backend asks about it: which machine form, which register, which order. And
none that showed how to read a backend's decisions back out of the bytes,
which is the only way to check your own work without trusting the compiler.

The mission's own test for the chain is that a learner finishing it should be
able to emit machine code for x86-64, AArch64 and RISC-V **without depending
on LLVM or any other backend**. That is why the artifact prints, by file
name, what replaces each piece of LLVM:

| LLVM's job | the file here |
|---|---|
| textual IR (parse and print) | `cbir.py` (`read_llvm_ir`) |
| the IR itself | `cbir.py` (`Ins`, `is_reg`, `simulate`) |
| instruction selection | `cbir.py` (`isel_tree`, `PATTERNS`) |
| register allocation, linear scan | `cbreg.py` (`alloc_linear_scan`) |
| register allocation, colouring | `cbreg.py` (`alloc_colour`) |
| liveness and interference | `cbreg.py` (`build_interference`) |
| spill slots and reloads | `cbreg.py` (`pack_spill_slots`) |
| coalescing | `cbreg.py` (`coalesce`) |
| instruction scheduling | `cbsched.py` (`build_dag`, `list_schedule`) |
| **the encoder** | `cbenc.py` (`enc_a64_madd`, `enc_x86`) |
| **the machine we measure on** | `cbbench.c` |

LLVM is the **oracle** and never a dependency. clang is *read* — what does the
best available compiler do with this function at this level — and compared
against an allocator and a scheduler written here.

### What is still missing, printed rather than implied

No SSA construction and no PHI placement. No CFG, no basic blocks, no
dominators, no loop structure. No peepholes, no compressed encodings, no
exception frames, no debug information.

**The IR is straight-line**, and the reason is in `cbir.py`'s own docstring:
selection, allocation and scheduling are three questions about a *sequence* of
operations, and a branch would put a fourth question in the middle of them.

This is the course's largest deliberate limitation and it is why the `compiler`
roadmap is only six items lighter rather than finished. SSA, CFGs, dominators,
data-flow analysis and constant folding are all still open.

---

## 2. The host's four absences, printed before the first number

A claim about a decoder needs a toolchain, so `build_samples.sh` checks and
prints the toolchain before it compiles anything, and section 1 of the artifact
repeats it.

| Target | State | Consequence |
|---|---|---|
| x86-64 | **runs natively** | the only course in the collection that can put a ratio on the cost of a spill and of a schedule |
| aarch64 | compiles, cannot run | `aarch64-linux-gnu-ld` **not installed**, `qemu-aarch64` and `spike` **absent** |
| riscv64 | compiles, cannot run | `riscv64-linux-gnu-ld` **not installed**, `qemu-riscv64` and `spike` **absent** |

Consequence, and it governs every label in the file:

* every claim about **x86-64 code** is `MEASURED`, because it ran
* every claim about an **AArch64 or RISC-V instruction** is
  `MEASURED-ON-BYTES`, because a word was emitted and read back and nothing
  more
* every claim about **what a machine would do** is `QUOTED`, with a document

**There is no fourth label and there is no fourth spelling.** A label rendered
two ways is not a label: the provenance summary in section 12 only adds up if
the three spellings are used consistently, and `tools/verify_compback.py`
counts them with word-boundary regexes for the same reason
`tools/verify_rvpriv.py` does.

Note the asymmetry this creates, and it is deliberate: **no relocation emitted
for AArch64 or RISC-V in this course has ever been resolved**, because there is
no linker for either. "The bytes are correct" and "the file is correct" are
different claims and only the first one is available here.

---

## 3. The three per-architecture sections, and what each page takes from them

Nothing is re-taught. Every outbound id was checked against a served route
before a page was written, and `tools/verify_compback.py` asserts the outbound
list **present** and the retired list **absent** — a positive list passes on
any set of ids that exist and says nothing about the ones that do not, which
is how `rvpriv` shipped four ids that 404'd while its own artifact claimed
every one had been verified.

| Subject | Owner | Id linked |
|---|---|---|
| x86-64 calling convention | `x86abi` | `/courses/x86abi/lessons/x86-calling` |
| AAPCS64 | `a64abi` | `/courses/a64abi/lessons/a64-aapcs` |
| RISC-V calling convention | `rvabi` | `/courses/rvabi/lessons/rv-calling` |
| relocations, symbols | `reloc`, `obj` | `reloc-apply`, `obj-relocations` |
| what a linker does | `link` | `link-write-script`, `link-order` |
| AArch64 encoding | `a64asm` | `a64-encoding` |
| RISC-V encoding | `rvasm` | `rv-encoding` |
| x86-64 encoding | `x86asm` | `x86-integers` |
| what the machine does with order | `exe`, `mem` | `exe-latency`, `exe-deps`, `exe-speculate`, `mem-latency` |
| the two decoders this course borrows | `rvasm`, `a64asm` | `rv-verify`, `a64-verify` |
| the model for a boundary page | `rvpriv` | `/courses/rvpriv/lessons/rv-boundary` |

**The decoders are borrowed, not forked.** `a64asm`'s `a64dec.py` and
`rvasm`'s `rvdec.py` are used as they are; no sibling is edited. That is the
same decision `rvpriv` made and it has a published price — a retraction whose
defect is admitted to be in the *sibling's* code — because a course that
quietly patches a neighbour to make its own numbers work is a course whose
numbers are not measurements any more.

### Concept ids

All six are `cb-` prefixed. `render_concept()` in `web/src/helpers.ch`
resolves ids **globally with no course in the key**, so a collision does not
404: it silently serves another course's page under this course's URL. All six
were grepped out of that file *and* out of every shipped manifest before a page
was written.

The names deviate from `docs/courses-todo.md` on purpose, and the deviation is
worth recording because it is the rule the whole file keeps re-learning:
`compiler-architecture` and `register-allocation` name **topics**, while every
other concept id in this collection names **what the reader is left holding**.
`cb-ir` names the finding (what an IR must *not* hide), `cb-verify` names the
thing the last page does rather than `cb-boundary`, because `rv-boundary` and
`x86-boundary` already exist and two courses cannot share one name.

---

## 4. What each of the six pages measures

### cb-ir — the ratio, read both ways

The argument for an IR is a ratio, and it must be read in **both** directions.
Above 1.0 the IR is bigger than the code (the backend deleted instructions);
below 1.0 the code is bigger (the backend inserted them). Measured over five
levels on x86-64:

```
  level   IR insns   machine insns   IR/machine
  O0           260             235        1.106
  O1            99             117        0.846
  O2           207             253        0.818
  O3           207             253        0.818
  Os            99             103        0.961
```

**The ratio is not monotonic.** `-O1` gives a *smaller* ratio than `-O0`
because `-O0` emits more machine instructions than IR and `-O1` emits fewer. A
number that only falls as the compiler gets better is a story.

The half nobody states: at `-Os` the three targets share **17 of 19 opcodes**
and the two that are target-specific are named — `insertelement` and
`shufflevector`, both on `riscv64`. At `-O2` **all three targets agree on every
opcode and the machine counts are still 253, 190 and 207**. So the finding is
neither "an IR is target-independent" nor "target-dependent": it is
target-independent in its *operations* and target-dependent in its *shapes*.

The vectoriser enters at `-O2` and not at `-O1` and not on `-Os` for two of
three targets, and `-Os` emits **more** IR for RISC-V than `-O2` does. A level
of `-O` is not a ranking; it is a set of objectives.

### cb-isel — the misroute, and why the count is not the receipt

The selector is a tree walk over operand **kinds**. Dispatching on kind alone
takes the first pattern with a matching kind, which in `cbir.py`'s table is
`add` for every two-operand arithmetic form:

```
  kernel   instructions   isel_tree   isel_kind   MISROUTED
  TOTAL               61          61          61          49
```

**49 of 61 routed to the wrong machine form, and the selector never fails
once.** The result is not a crash; it is a program that computes a different
number. Hence the checksum as the receipt rather than the count:

```
  the correct program folds to  193715795505516148
  one sub computed as an add    193715795509322676
```

Fusion is measured **on bytes**, built by hand rather than assembled because
an assembler hides the question: seven AArch64 words re-encoded from register
numbers with a mask table and no library, **7 of 7** agreeing with a real
assembler. That table caught all three encoder bugs the artifact shipped, none
of which raised. The sharpest read the three-source group selector out of the
wrong group and produced a `msub` for a `madd`.

Four five-bit register fields are twenty bits of thirty-two. The
three-operand form is not a compressed form; it is the same width with one
field reading 31, which is how the encoding says *no fourth operand*.

The x86-64 half is a **refusal**: `enc_x86` takes `(op, dst, src)` and cannot
express a three-operand multiply, because ModRM puts the source in bits 3–5
and the destination in the low three.

### cb-regalloc — three policies, two bugs, and the one real measurement

Three allocators on the same IR give three spill counts, and the ratio between
them is a fact about the **spill heuristic**, not about the algorithms:

```
  linear scan           58 spills across 36 allocations
  Chaitin colour       166 spills
  colour, iterate       45 spills
```

Every `yes` in the tables is a **checksum**, not a count: the program is
lowered with the spills, run, and each value read back at its **last use** —
because a spill slot may legitimately be reused, and reading at the end reports
an error in a correct allocation. That was a bug this artifact shipped.

The two deliberate off-by-ones fail in **opposite directions**. A half-open live
range loses 15 of 50 interference edges, so the graph is easier to colour and
a wrong allocator reports a **better** spill count — succeeding *is* the
failure. The coalescer with the same bug **gains** a merge instead. The sweep
goes down to pressure 1, the one pressure at which the bug is invisible,
because a sweep starting at 3 would have reported nine of nine and called it
detected.

**The one measurement no other course in this collection could take**, because
this is the first course whose machine runs the code:

```
  arm   spilled   vs arm A   checksum
  A            0   1.00-1.25   5925179420309322629
  B            1   1.00-1.25   5925179420309322629
  C            2   1.00-1.25   5925179420309322629
  D            4   1.25-1.56   5925179420309322629
```

**The cost of a spill is not linear, and no page may say otherwise.** The 1-
and 2-spill arms are **not distinguishable from each other**; only 4 separates.
Any unconditional "a spill costs X" claim is unsupported by the artifact.

The TSC was measured twice, busy and across a 400 ms sleep, agreeing to within
0.01 per cent, so a tick is time and not cycles. **No number in this course is
a cycle count and none is converted into one.**

**Bands, not ticks, in `compback.out`.** The exact ticks live in `cbbench.out`,
which is committed and not compared, because a report containing a clock
reading and a file that is byte-identical between two runs cannot both be
true. The exception is written down rather than discovered by a failed `cmp`.

### cb-sched — the tie-break, and the fastest wrong answer

List scheduling over `kernel_d` (16 instructions, critical path 8, ILP 2.00) —
and **deliberately not `kernel_a`**, which is a dependency chain whose every
schedule is the input order. A scheduler given no choice prints three copies
of the input, and a reader who has not spotted it concludes scheduling works.

`height` reproduces the input order and `height_hi` does not, and they are the
same algorithm with a different **undocumented tie-break**. Every list
scheduler in every textbook breaks ties by some rule and none of them say
which.

The trap: `kernel` stores to `[1024+8]` and loads from `[1024+8]`. Without a
memory-dependency analysis the `height` schedule returns 6601062688 where the
correct answer is 6601140724. **The same schedule is correct on a kernel with
distinct addresses** — both verdicts are true and they say different things.
A scheduler that drops an unknown memory dependency is not wrong, it is a
scheduler without an alias analysis, and the failure it produces is **faster
and wrong**, which is the worst combination this course found.

### cb-abi — the obligation, not the convention

Three courses already taught the three conventions, so this page links and does
not re-teach. The subject is the **order**: register allocation assigns names
to values and the ABI assigns names to arguments, and if the allocator runs
first the prologue must save a register the backend did not plan for — on
x86-64, a stack frame where the function looked like it needed none.

Measured by name, 6 of 6 argument registers read on all three targets, and the
count is a **lower bound**: a destructive mnemonic can print an operand twice
and a memory operand names a register that is not an argument. The example has
six arguments and not seven because the seventh is the one that moves to the
stack, and how many arguments spill is a fact about the ABI and not about the
backend.

The second reader reads **words**, and 1 of 12 agree. Nine of the eleven
disagreements are printing conventions; two are the compressed forms the RISC-V
decoder implements and this artifact does not. The artifact also names its own
reader as the one that could be wrong in the same way as the others.

Item 5 of the six-item list is the one that bites: on x86-64 `al` is an
argument register that becomes the vector-count register, so **a varargs call
cannot be encoded by the same prologue as an ordinary one.**

### cb-verify — reading the decisions back out

Given a compiled function with no symbol table and no debug information,
recover four things. **The fourth is the only one that is an inference and is
labelled as one**, because the first three are counts and a count can be
checked while a reading cannot.

```
  target   level   instructions   headers   mem ops   distinct regs
  x86_64    O0              235        11       141               5
  x86_64    O2              253        11        37               6
  aarch64   O2              190        11        11              12
  riscv64   O2              207        12         6               8
```

The inference, for `leaf`: 9 instructions, 7 distinct registers, peaking at 3
at instruction 3, never touching the stack — so it was allocated **without
spilling**. The comparison with the `-O0` build of the same source (23
instructions, 15 touching `rsp` or `rbp`) is what turns the reading into an
inference, because the difference between the two is the allocator's work and
nothing else's.

**A prologue is visible because it is a frame, not because it saves
registers** (retraction R14). The registers it saves are the allocator's
business and the compiler may save more than it modified; what is recoverable
from a disassembly alone is the frame and the memory traffic inside it.

The boundary as a table with a count: **25 rows, 8 MEASURED, 9
MEASURED-ON-BYTES, 8 QUOTED**, and the comparison with the x86-64 section's
quoted fraction printed **both ways**. Then 15 numbered limits, **11 things a
reader cannot conclude beside 11 they can** (the second list being longer *is*
the finding), and 18 retractions each with a SOURCE.

The two-reader check over the AArch64 leaf: 9 words, 9 agree, 0 disagree, with
the **normaliser fire table pre-seeded at zero** so a rule that never fires is
a row rather than an absence, and two of the six rules **dead by design and
labelled in the table itself**.

Four poisons, all FIRED: misroutes −1 and the checksum changed; edges −15 and
the checksum WRONG; dependency edges −1 and the schedule gave a **different
answer**; and **5 of 9 planted disagreements HIDDEN** by a normaliser that
deletes an operand — the class of bug that reads as success.

**None of the eighteen retractions is a mistake about how a computer works.**
They are all mistakes about how a compiler behaves, which is a different
subject and a harder one — nineteen courses in a row.

### R16: what the *Compiler Debug Information* item actually gets ticked

This course emits no DWARF. `dwarf` owns the format. What this course adds is
the question that comes *before* the format: **what can you know about a
compiler when you have no debug information at all?** The roadmap item is
ticked by its **second** half, and the artifact says so rather than letting
the tick imply the first.

---

## 5. Two claims this course refuses to make

Both are load-bearing, both were verified against the artifact before the pages
were written, and both are the kind of sentence a course is tempted to soften.

1. **The spill cost is not linear.** 1 and 2 spills are indistinguishable on
   this machine under this load; only 4 separates. Any unconditional
   "a spill costs X" is unsupported. The verdict is a ratio against the
   **1-SPILL arm**, not against the floor, and the floor is printed anyway
   because it is the honest statement of how much two independent estimates of
   one arm disagree. On this machine under load the floor and the 4-spill
   difference **overlap**, so "difference > floor" is not a question this
   machine answers the same way twice.

2. **The schedule measurement is below the comparison floor.** Hand-interleaving
   four independent chains came out *below* the floor, with checksums agreeing.
   This is not a disappointment — it is the finding, and it is the reason the
   second schedule-comparison floor exists beside the estimator floor.

---

## 6. Two defects found while writing the last page, published not repaired

Both were found by writing `cb_verify.ch` against the artifact rather than
from memory, and both are the collection's own recurring shape turned on this
course.

### 6a. Section 12 says three, and the table marks two

The header reads `AND THE THREE ROWS THAT ARE QUOTED *AND* NOT MEASURED ARE
MARKED` and the block beneath it prints **two** lines reading `NOT MEASURED
HERE`. Confirmed by `grep -c "NOT MEASURED HERE" compback.out` → 6, of which
two are in this table and two are in the complexity rows' own source lines.

**A count that does not add up, in the one section whose subject is counts that
add up.** Every other number in this course was checked; this one was not, and
it shipped.

### 6b. Section 18 says twenty-two corruptions, and there are 27

`crosscheck.py` and `corrupt.py` disagree with the artifact about the size of
the suite. The artifact's sentence is a **hand-written count in prose**, which
is precisely the failure its own retraction list is about — and it is not the
first time: `rvpriv` shipped a section header reading "Sixteen of them" beside a
list of seventeen, and the fix there was to take the word from a `NUMWORDS`
table. **This course's equivalent count was left in prose and went stale when
five corruptions were added.**

Both are the same defect and both are found the same way: a count written in a
sentence rather than computed from the list it summarises.

It is **not repaired**, deliberately: `compback.out`, `run1.txt` and `run2.txt`
must stay byte-identical, and a page that silently corrected a recorded figure
would be worse than one that quoted it — because the correction would be
invisible and the artifact would go on being wrong. `cb-verify` quotes the
block verbatim and names the discrepancy.

The lesson generalises past this course: *a label rendered two ways is not a
label; a count that does not add up is not a count; and a summary sentence that
disagrees with the table it summarises is the same defect one level up.*

---

## 7. Reproducing everything here

```bash
cd courses/compback/assets/samples
./build_samples.sh              # rebuilds the corpus, runs the report 3x, cmp's
python3 crosscheck.py           # 171 checks against the SHIPPED compback.out
python3 corrupt.py              # 22 corruptions, all must be CAUGHT
```

The harness takes no assembler, no decoder and no toolchain, and that is the
point: a harness that can re-measure can disagree with the artifact for reasons
unrelated to whether its sentences are still true, and then it teaches its
reader to ignore it.

`cb_verify.ch`'s "Try it" invites a reader to reproduce the non-linearity on
their own machine, and the artifact explicitly permits that conclusion to come
out differently — the measurement is about *their* machine, which is worth
reporting rather than quietly accepting.
