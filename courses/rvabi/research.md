# RISC-V ABI — research notes

Working notes for the course whose id is `rvabi` and whose title is **The
RISC-V ABI, and the Register That Isn't There**. Roadmap item 4, the second
of the four `docs/riscv-section-plan.md` splits.

These are the sources, the decisions, and the things that were measured
before a page was written. Everything here that is a number is also in
`assets/samples/rvabi.out`, and the harness `assets/samples/crosscheck.py`
re-asks every one of them.

---

## 1. The premise, and why it is not a caveat

`qemu-riscv64`, `spike` and `riscv64-linux-gnu-{gcc,as,ld}` are all **ABSENT**
on this host. That is checked and printed by `build_samples.sh` before it
compiles anything, and again in section 1 of the artifact.

The x86-64 ABI course in the first section of this collection measured a
**4.92x** and a **27.65x** on hardware it could run. This course has **no
counterpart for either number and does not invent one.** Every cross-target
table is an **INSTRUCTION COUNT** or a **BYTE COUNT**, and every one of them
carries IT IS NOT A TIMING AND NOT A SPEEDUP in its own caption. This is
retraction R10 and it is asserted as text.

The subject makes the temptation worse than anywhere else in the collection:
this course is *about* how a compiler's choices turn into machine code, and a
reader who has just read two ratios is looking for one.

What survives the absence is more than usual, because the two claims this
course makes are both static:

* a **contract** (the calling convention) can be quoted exactly and then
  checked against a compiler, and
* a **choice** (branch versus mask versus call) is a property of the emitted
  bytes.

Neither needs a CPU to be true. Both need a decoder to be believed, and that
is the real subject of section 9.

---

## 2. Sources

| Short name | Document | Used for |
|---|---|---|
| `riscv-cc` | *RISC-V Calling Conventions* (the psABI) | register table, argument rules, stack rules, frame-pointer rule, the `OTHERWISE, IT IS PASSED ACCORDING TO THE INTEGER CALLING CONVENTION` sentence |
| `rv32-unprivileged` | *RISC-V Unprivileged ISA* | the programmers' model for x0, and the branch-design note that admits the absence of conditional moves |

The second one is the course's spine in its own words:

> We considered but did not include conditional moves or predicated
> instructions, which can effectively replace unpredictable short forward
> branches.

and the sentence that makes the design a comparison rather than an accident:

> The conditional branches were designed to include arithmetic comparison
> operations between two registers ... rather than use condition codes (x86,
> ARM, SPARC, PowerPC).

Both are quoted with a section in the artifact's 25-row `PROVENANCE` table, and
the harness asserts that every QUOTED row names a document and a section
(`t.count("riscv-cc,") >= 4 and t.count("rv32-unprivileged") >= 3`).

`docs/course-mission.md` supplies the spine in the form the pages use it.

---

## 3. Decisions, and the reason for each

### 3.1 Four concepts, in the order a *reader* needs and not the order the *artifact* measures

The artifact quotes the specification (section 2) before it runs a compiler
(section 3), because an oracle has to be in front of the thing tested against
it. A reader needs the opposite: the absence, then its consequences. So the
pages are `rv-calling` → `rv-noflags` → `rv-registers` → `rv-compressed-cost`.

### 3.2 The concept ids, and the collision they had to avoid

`render_concept()` in `web/src/helpers.ch` resolves concept ids **GLOBALLY,
with no course in the key.** A collision does not 404 — it silently serves
another course's page under this course's URL. This is 2.2.108's finding and
it has now cost three courses a name.

`rvasm` already owns `rv-verify`, `rv-isa`, `rv-encoding`, `rv-compressed` and
`rv-immediate`. Everything here is `rv-` plus a word the encoding course does
not use:

| id | why that and not the obvious name |
|---|---|
| `rv-calling` | not `rv-abi` (a concept must not shadow its own course id), and not `rv-arguments` (the page is about *one* argument and where it lands) |
| `rv-noflags` | named for the **absence**, not the mechanism: the course title is "the Register That Isn't There" and `cmov` is the thing the absence removes |
| `rv-registers` | not `rv-regs`, which the encoding course would have wanted for the field map |
| `rv-compressed-cost` | the `-cost` suffix is what keeps this apart from `rv-compressed`; the encoding page measured reserved code points and this one measures a spill, a hot loop and a `jal`/`ret` pair |

`grep -n '"rv-' web/src/helpers.ch` was run before any id was chosen, and
`render_rvabi_concept` is called **after** `render_rvasm_concept` in
`render_concept` so the older course gets first refusal on anything both could
match.

### 3.3 The three-target table is a count and says so everywhere

RISC-V 74 instructions, AArch64 63, x86-64 83 over twelve functions at `-O2`.
The differences (−11 and +9) **do not have the same sign**, and the file says
so and refuses to explain it as a property of the architectures. A count
does not know whether the instruction is fast; that sentence is the whole of
what replaces the ratios.

### 3.4 The compiler is the test subject, the specification is the oracle

Every disagreement between them is a retraction in section 11, printed in full
and asserted **as text** by the harness, so one cannot be quietly deleted.
Twelve of them; **none is a mistake about how a computer works**, which is
twelve courses in a row.

### 3.5 The three labels are defined, used and counted

`MEASURED` (about the compiler or the bytes, by experiment),
`MEASURED-ON-BYTES` (a property of emitted bytes, cross-checked against
`llvm-objdump-21`), `QUOTED` (a manual claim, with a document and a section).
The shipped run has **33 / 15 / 19**. A label rendered two ways is not a
label — that was 2.2.108's finding, applied to a second section.

### 3.6 `run1.txt` and `run2.txt` are byte-identical

Cheap to run, expensive to omit, and it is the only evidence the artifact has
no machine in it.

---

## 4. What was measured before a page existed

Numbers below are MEASURED unless marked otherwise. All are in `rvabi.out`.

**The contract.** 44 of 44 register-resident integer argument placements agree
with `riscv-cc` at `-O2` (MEASURED-ON-BYTES: read out of the relocation each
store carries). The denominator is arithmetic: 1+2+…+8 = 36 from `i1`…`i8`,
plus 8 more from `i9`. The spill count is the compiler's and it moves with
`-O`: 0 in a register / 36 on the stack at `-O0`, 36 / 0 at the other three.

**The first stacked argument is at offset zero** at every level, and at `-O0`
it is read through `s0` — through the frame pointer, which *is* the CFA — so
the offset is still zero. A row that is empty at one level and full at every
other is almost always a base-register assumption, not a measurement.

**Two counters, not one.** `f9` (nine doubles) puts the ninth in **`a0`, an
integer register**, and reads **no** stack argument at any level: with fa0-fa7
exhausted the value is passed "according to the integer calling convention"
and the integer convention is a0-a7 first. `m18` (nine ints then nine
doubles) reads **exactly offsets 0 and 8**, with the ninth integer in `t0` and
the ninth double in `ft0` — both through a **temporary**, and the load that
filled it is the only evidence the value came from the stack at all.

**The three idioms are disjoint.** 17 branches, 16 csel/cneg, 16 cmov.
Union 13 = sum of the three sets 13. The intersections are **computed and
printed** rather than asserted in prose; the first version wrote the word
"disjoint" and never computed one.

**The constructive half.** `sign` is **one instruction** — `srliw a0, a0, 0x1f`,
4 bytes — where x86-64 needs a `SETL` that does not exist.

**`csel` is decoded, not named.** `a64dec.py` from the sibling AArch64
course decodes the words; the condition is a **four-bit field at bits[15:12]**,
on `0x1a81b000` (`csel w0, w0, w1, lt`, cond 0xb) and `0x5a805400`
(`cneg w0, w0, mi`, cond 0x5). Three register fields plus a 7-bit immediate
in a 32-bit word leaves **no room** for a 4-bit condition, so `csel` is a
different *encoding* and not an instruction with an extra field. That is the
out-of-encodings argument, and it is arithmetic rather than preference.

**The register census, and the audit that makes it trustworthy.** 5,973
instructions checked against the inherited decoder's printed operands, 5,973
agree. `gp` and `tp` are written **0** times across the whole corpus. x0 is
read 110 times and written 75, and **not one of those writes takes effect**.

**The three spellings of a zero are one instruction.** `mv t0, zero`,
`addi t0, zero, 0` and `li t0, 0` all assemble to 2 bytes at `-march=rv64gc`
and 4 at `-march=rv64i`. There is no `c.mv` with a zero source — the cell is
`c.li`. `li zero, 42` **assembles** to four real bytes.

**Compression, clean pair.** `rv64imafd` → `rv64imafdc`: `cpc.c` **+6**,
`regs.c` **+0**, `abi.c` **+0** instructions. Confounded pair `rv64i` →
`rv64gc`: **−38** for `regs.c`, every bit of it the soft-float library.
`spilln`: 43 instructions / 172 bytes → **49 / 124**.

**The length rule.** 6,048 instructions found by the two-bit rule against
5,012 with the length supplied. **The two counts are not equal**, which is
what proves the rule is load-bearing.

**The two readers.** 6,048 instructions compared, 5,973 named, **0**
disagreements, 0 length disagreements, **75 unmodelled** (counted, never
dropped). 38 of 51 normalisation rules fired; the 13 that did not each carry
a one-line reason and a rule with no reason prints as `INVESTIGATE`.

---

## 5. The four bugs that cost the most

### 5.1 Asking a decoder for a field it never read

The inherited `rvdec.py` emits one `field()` line per field it *reads*, and
for `c.sdsp ra, 24(sp)` the CSS format's `rs2` exists only to be printed, so
it is explained in prose. The lookup returned `None`, and the store audit
reported the eighth integer argument of `m18` as arriving in `t0` when it
arrived in `a7`.

**A decoder's field report is not an API.**

### 5.2 Answering "which register file" once per instruction

`fsd fa0, -24(s0)` has `rs2` = 10 (`fa0`) and `rs1` = 8 (`s0`). The first
reader asked *per instruction* and got the base wrong, which made the census
report **18 writes to `gp` and 8 to `tp`** over a corpus with none — because a
real `a2` read in the wrong file comes out as `fs2`, and `fs2` read as an
integer is `x18` = `s2`.

**A register number is not a register until you know which file it is in, and
the answer is per FIELD.** The fix is the audit: a second rendering of the same
bits, compared instruction by instruction, 5,973 of 5,973.

### 5.3 A count with no denominator

The zero-spelling census asked for a field named `imm`; the decoder writes that
line under `immediate`. All four counts printed **0** — which reads exactly
like "the corpus contains no zero-spelling", and is a claim a reader would
have believed. The census now reads the immediate from the bits and prints the
**260-instruction denominator** beside the 18.

**A count of zero out of 260 is a measurement; a count of zero out of zero is
a bug wearing the costume of a result.**

### 5.4 A check that no output could satisfy

In `crosscheck.py`, the m18 row's third group was `(\S+)` and the assertion
compared it against `"0, 8"` — a string containing a space. **Unsatisfiable.**
It failed against a measurement that was right.

The group was widened to `(\S.*?)`; the equality test was not touched. Recorded
at the call site: *a harness bug repaired by loosening what it asserts is a
different thing from this, and this is not that.*

---

## 6. What this course does not teach, and links instead

A course that re-teaches a principle makes a reader learn it twice. Every link
was verified present before it was written.

* why a contract exists, and why a callee saves registers — `x86abi/lessons/x86-calling`, `x86abi/lessons/x86-saved`
* what a frame is for, and what a frame pointer is for — `x86abi/lessons/x86-frame`, `a64abi/lessons/a64-frame`
* the same contract for AArch64, and the two counters as AArch64 states them — `a64abi/lessons/a64-aapcs`
* the register file as a partitioned namespace elsewhere — `a64abi/lessons/a64-registers`
* the **encoding** side of the C extension — `rvasm/lessons/rv-compressed`, `rvasm/lessons/rv-encoding`
* what an object file *is* — `exe/lessons/exe-frontend`

`rvasm/lessons/rv-compressed` is the one that most obviously overlaps and is
the reason for the `-cost` suffix: it measured reserved code points, the seven
displacement permutations and the four assembler refusals. **This course
measures the consequence** — a spill, a hot loop, a call/return pair, and the
two-bit rule — and repeats none of it.

---

## 7. Verification

```
python3 courses/rvabi/assets/samples/build_samples.sh     # corpus + artifact + harness
python3 tools/verify_rvabi.py                              # routes, chain, minutes, artifact
python3 tools/bracecheck.py    content/src/rv*.ch
python3 tools/html_balance.py  content/src/rv*.ch
python3 tools/nesting_check.py
python3 tools/check_quotes.py  rvabi
```

`check_quotes.py` is registered in `PREFIXES`, `OUTPUTS` and
`ARTIFACT_CMDS`, and it now prints how many files and how many quoted blocks
it examined — a course absent from those tables prints "0 tokens, 0 not in
…" and reads exactly like a clean one.

Build notes that cost time, recorded so the next course does not pay them
again:

* A `chemical.mod` that does not declare `html_cbi` / `css_cbi` / `js_cbi`
  never triggers a CBI build, and the failure reads
  `couldn't find macro parser for '#html'`, which looks like a toolchain
  fault and is a manifest fault. `courses/rvasm/chemical.mod` is the worked
  example.
* A course exe writes `./output` **relative to its working directory.** Run it
  from inside `courses/rvabi/`, never from the repo root.
* The compiler is at `/home/wakaztahir/work/Chemical/chemical/cmake-build-debug/TCCCompiler`
  and the application module is the **root** `chemical.mod`. The
  `lang/compiled/underlayer/` and `cmake-build-debug/` paths in `AGENTS.md` do
  not exist on this checkout — that is 2.2.109's finding (7), recorded rather
  than worked around.
* Read `tools/nesting_check.py` before writing a page: a unit div at any depth
  other than one below `.lesson` swallows its siblings, and a page shipped
  with exactly that bug read as balanced to the linter.
