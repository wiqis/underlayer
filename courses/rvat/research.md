# RISC-V Atomics and the Vector Extension — research notes

Working notes for the course whose id is `rvat` and whose title is **RISC-V
Atomics and the Vector Extension**. Roadmap items 8 (Atomics) and 9 (Vector
Extension) — the fourth of the four `docs/riscv-section-plan.md` splits.

These are the sources, the decisions, and the things that were measured
before a page was written. Everything here that is a number is also in
`assets/samples/rvat.out`, the harness `assets/samples/crosscheck.py`
re-asks every one of them in **370 checks**, and `assets/samples/corrupt.py`
proves the harness can fail by corrupting the recorded report **34 ways and
requiring all 34 to be caught**.

---

## 1. The premise, and what this course can and cannot do

`qemu-riscv64`, `spike` and `riscv64-linux-gnu-{gcc,as,ld}` are all **ABSENT**
on this host. That is checked and printed by `build_samples.sh` before it
compiles anything, and again in section 1 of the artifact.

This is the same absence the three RISC-V courses before it inherited, and it
has the same single consequence, stated once and never weakened:

* `THERE ARE NO TIMINGS IN THIS COURSE AND THERE IS NO WAY TO MAKE ONE`
* no RISC-V machine, so **no atomic operation is ever performed**, no
  reservation is ever held, no fence is ever executed and no vector
  instruction is ever run
* the x86-64 section's measured ratios and the AArch64 section's measured
  ordering latencies **have no counterpart here and are not invented to fill
  the gap**

What this course adds that its three siblings did not: **a subject where the
comparison with x86-64 and AArch64 is the concept, and where the two other
architectures' numbers ARE the honest contrast — provided what is compared is
a COUNT and not a TIME.** The `simd` and `smp` courses taught vectors and
ordering neutrally and measured them on real hardware; the trap is that their
numbers feel borrowable here. They are not borrowed and they are not
re-derived. What is measured is that zero instructions in this corpus take a
lock prefix, **against** a count of the operations that are atomic with no
prefix at all — so the zero has a denominator.

---

## 2. Sources

| Short name | Document | Used for |
|---|---|---|
| `rv32-unpriv` | *RISC-V Unprivileged ISA*, Volume I | the A extension — `lr`/`sc`, the eleven funct5 values, `aq`/`rl`, the reservation set size and the failure condition (§8.2); the base ordering model being **RVWMO** (§2.7) and the reason a single hart's behaviour is unchanged; the `fence` encoding and its four fields (§2.7), the predecessor/successor sets and `FENCE` consistency rules (§2.7); `FENCE.TSO` (§2.7) and the fact that `fence.tso` orders all memory operations **except** stores followed by stores; the V extension — `vsetvli`/`vsetivli`/`vsetvl` and their four fields plus the AVL absence (§31.3.6), `vle64`/`vse64` and the `vm` bit (§31.3), the `v0` mask-register restriction and the mask-agnostic encodings (§31.3), the tail-undisturbed/agnostic/masked policies (§31.2), `vlenb` (§31.3.6), the VL/SEW/LMUL interaction and why LMUL is an **alignment constraint** (§31.2) |
| `riscv-cc` | *RISC-V ABIs Specification* v1.0 | the `a` extension as an ABI-visible letter — that `-march=rv64ima` vs `-march=rv64im` changes which instructions the compiler may emit at all |
| `intel-sdm` | *Intel 64 and IA-32 Architectures Software Developer's Manual* | the LOCK-prefix list, quoted and then **disclaimed**: the SDM enumerates eighteen locked instructions, the assembler this host actually uses accepts **twenty-two** spellings, and the trap is `lock bt` — a form no vendor documents and every assembler accepts |

Every QUOTED row in the 58-row provenance table names one of these three with
a section. There is no fourth source and no uncited quote.

---

## 3. The concept ids, and the collision that was decided against

The section plan proposes five ids: `rv-amo`, `rv-fence`, `rv-vector`,
`rv-vector-mask` and `rv-dataflow`.

A concept id is resolved **globally** by `render_concept()` in
`web/src/helpers.ch` with **no course in the key**, so a collision does not
404 — it silently serves another course's page under this course's URL. That
has now happened three times in this section. So all five were grepped
against `helpers.ch` before a page was written.

**`rv-vector-mask` was NOT TAKEN.** The section plan gives it as a separate
page; this course ships **four** concepts in **two** modules, and the mask
material is a page's worth of content inside `rv-vector` and `rv-dataflow`
rather than a fifth route. The reason is the manifest's own numbers: the mask
is **one bit** at inst[25], proved by eleven pairs that all XOR to exactly
`0x02000000`, and the mask register is not in the encoding at all. That is
two results, and splitting it across a fifth page would have produced a page
whose central fact is that the thing it is named after is not in the encoding.
`rv-vector-mask` stays free for a future course that actually has masks to
measure.

Ids taken: `rv-amo`, `rv-fence`, `rv-vector`, `rv-dataflow`.
Ids **asserted ABSENT** — because a positive link list passes on any set of
ids that exist and says nothing about the ones that do not:
`rv-noflag`, `rv-noflags`, `rv-registers`, `rv-registers-abi`,
`rv-atomic`, `rv-atomics`, `rv-atomic-ext`, `rv-ordering`, `rv-fences`.

That last distinction is in the harness, not in a comment: `x86-atom` is a
**prefix** of `x86-atomics` and `rv-noflag` is a prefix of `rv-noflags`, so
the retired-id check matches on a **whole path segment**. The first version
matched on a plain substring and therefore passed on an id that 404s — the
check was weaker than the claim it was written for.

---

## 4. The central experiment, and why it needs no clock

The same C11 file, compiled twice, one letter apart:

```
-with     29 instructions, 2 lr, 2 sc, 5 amo*, 0 CALLS
-without 111 instructions, 0 lr, 0 sc, 0 amo*, 9 CALLS
```

`rv64ima` against `rv64im`. That is the whole atomics story in two numbers
and it is **not a timing**: with the `a` letter the compiler can inline
`amoswap.w` and the `lr`/`sc` pair; without it, every atomic becomes a call to
`__atomic_*_4`.

**The call count was wrong in the first version and the fix changed what the
page claims.** The original artifact counted instructions whose **mnemonic**
was `call`, and a relocatable RISC-V object has no `call` mnemonic at all —
in both builds the count was 0, and the artifact printed "0 CALLS" against
111 instructions without noticing that its own method could not have found a
call if there were one. It now counts `R_RISCV_CALL_PLT` **relocations**,
which is what a call is before there is a linker, and the nine calls appear.
The first reader here also attributed all nine to one function, because the
relocatable listing has no addresses; `func_insns()` now carries the
instruction address, so the calls are attributed per function.

`rvabi` retracted a claim for the same shape of reason in the same section —
a number that was right for the wrong reason is still wrong.

---

## 5. The claims that were retracted, and the ones that survived being tested

Eighteen retractions, `R1`–`R18`, each with a **source**, each asserted as
text so a taken-back claim can be neither quietly dropped nor edited into
being right. The three that matter most as method:

* **`amoswap.w` in place of a hand-rolled compare-exchange — RETRACTED.** The
  brief's headline claim. The compiler emits one instruction for the
  one-instruction operation and a **loop** for the loop-requiring one, and the
  base A extension has **no `cmpxchg`** to trade against. The page says so and
  links the manual rather than the brief.
* **`-O1` and `-Os` do not vectorise — RETRACTED, and in the opposite
  direction from expected.** `-Os` emits **21** vector instructions. The
  harness check was also wrong in the way that matters: it asserted the
  claim was false while the recorded run contradicted it, so the check was
  *unsatisfiable*, and it now splits into `-O1 == 0` plus a shape check and
  prints the size/vector-count distinction on its own `CODE SIZE:` line.
* **"Compression never changes the instruction count" — the pair of zeros
  and a `+6`.** Not this course's claim, this course's **predecessor's**
  retraction, and it is named here because the same experiment shape produced
  it.

---

## 6. What the measurement cannot show

Nineteen numbered limits, then two scope lists printed **side by side**:
**9 things a reader cannot conclude** and **11 they can**. The second list is
the longer one and that ordering is the finding — there is more that can be
read off bytes than there is that can be said about behaviour.

The two that a reader will most want to skip:

* **That the vectorised loops are CORRECT.** Nothing was executed. No output
  was compared against anything. A byte-level course can prove the compiler
  *emitted* the vector form and can say nothing about what it computes.
* **That `llvm-objdump-21` agrees with the silicon.** Section 11 establishes
  that this file's decoder and one other program from the same LLVM tree
  agree on what the bytes mean. That is a fact about **two programs**, not
  about a processor.

And the boundary of the atomics half, stated once: the **reservation** rules
are QUOTED and are not measured, because no reservation is ever held on this
host. There is no hart here to hold one.

---

## 7. The harness, and how it was shown to be able to fail

`crosscheck.py` asks **370** questions of the shipped `rvat.out`.

Ten of those questions were **unsatisfiable as written** and were repaired
**in the harness**, each with the reason recorded at the call site, following
the precedent `rvabi` set with one. The classes are all of them the same
shape — a harness that encodes the author's habit rather than the artifact's
contract:

1. a `source_limits()` helper that counted source **lines** (96) instead of
   the **length** of the list it was handed
2. an operator-precedence bug: `m2 + m3*100//m1` instead of
   `(m2+m3)*100//m1`
3. a needle written with an over-escaped `\\(` that carried a **literal
   backslash** into the search
4. an allowance for a "speed claim" keyed on the **description** string
   rather than the **pattern**, so it allowed zero and rejected the pinned
   cannot-claim
5. a `-march` sweep pattern `rv64i\w*` that cannot match `rv64gc`
6. two patterns requiring `\n` run against the **flattened** text, where
   newlines have already been collapsed
7. a poison check that asserted `disagreements == '+0'` one line after
   asserting it was `> 0` — the same check contradicting itself, which is
   why the poison now asserts the **real pairing** (named −47 / unmodelled
   +47, a HOLE)
8. the `-O1`/`-Os` claim, contradicted by the recorded run (see §5)
9. retired-id negatives matched by plain substring, so `x86-atom` passed on
   `x86-atomics`
10. a `TypeError` in the ISA-string check — a `if False else` chain indexing
   a dict of ints

Beyond those, the harness grew structures it did not have: `retraction_blocks()`
so needles match **per retraction** rather than anywhere in 2,409 lines; a
**per-id SIBLING** check for R1/R2/R3 so a retraction that must name the
course it corrects actually does; a config-table check that decodes
`inst[31:30]` from the word rather than trusting the printed column; and
twelve section-side **"is not de-negated"** checks, which are the harness's
answer to 2.2.114's finding that a scope claim can be softened without any
check failing.

`corrupt.py` is the other half: **34 corruptions, 34 caught, 0 missed, 0
errored**, including a 0-byte file (which fails 652 checks). It found four
real harness gaps on its first run, all since fixed. A harness whose checks
have never been seen to fail is a rubric.

---

## 8. Determinism, and why the build asserts it

`build_samples.sh` writes `rvat.out` and asserts it is non-empty — with a
**20,000-byte floor**, because `rvat.out` was 0 bytes once and every
downstream check passed on an empty file that contained none of the
assertions. It then runs the artifact a second and third time and `cmp`s all
three, and a mismatch fails the build. `run1.txt` and `run2.txt` ship
byte-identical to `rvat.out` (2,409 lines / 167,339 bytes), so the 370 checks
run on a machine that never ran the cross-compiler.

---

## 9. What the section owes its siblings, and does not re-teach

Eleven outbound ids, **verified present by a live route check** and asserted
both ways in `crosscheck.py`:

* what a race is, what "atomic" has to mean for it — `smp-atomic`,
  `smp-ordering` (neutral, hardware-measured)
* what a vector lane is, what a reduction is — `simd-width`, `simd-reduce`
* why a vectorised loop needs a remainder — `simd-boundaries`
* what the vectoriser does and does not do — `simd-compiler`
* the **same subject on x86-64**, where it *is* measurable on hardware —
  `x86-atomics`, `x86-order`
* the **same subject on AArch64**, where acquire and release are **access
  modes** rather than two bits — `a64-atomic`, `a64-order`
* the section's spine, why there are no condition codes — `rv-noflags`

The RISC-V half of the section's own spine (`rv-verify`, `rv-isa`,
`rv-encoding`, `rv-compressed`, `rv-immediate`, `rv-calling`, `rv-noflags`,
`rv-registers`, `rv-compressed-cost`, `rv-modes`, `rv-paging`, `rv-traps`,
`rv-boundary`) is inherited rather than repeated.