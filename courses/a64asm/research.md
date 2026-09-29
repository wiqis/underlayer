# AArch64: Encoding From The Ground Up — research log

Every number in the course was measured before it was written, on this
machine, with these tools. Claims that did not survive measurement were
**retracted rather than softened**, and all seventeen retractions are printed
by the artifact in section 14 and asserted as text by `crosscheck.py` group N so
that they can be neither quietly dropped nor deleted.

## The machine — and what is missing from it

| | |
|---|---|
| Host CPU | x86-64. **No AArch64 silicon.** Nothing in this course was executed. |
| Assembler | `Ubuntu clang version 21.1.8` with `--target=aarch64-linux-gnu` |
| Disassembler | `Ubuntu LLVM version 21.1.8` (`llvm-objdump-21 --triple=aarch64`) |
| AArch64 linker | **`aarch64-linux-gnu-ld` is NOT INSTALLED** |
| AArch64 emulator | **`qemu-aarch64` is NOT PRESENT** |
| Python | 3.x, standard library only |
| Determinism | two runs of `a64dec.py --run` are **byte-identical** |

Two absences decide what this course may claim at all, and they are printed by
the artifact in **section 1, before any measurement**, rather than in a limits
block at the end:

1. **No AArch64 machine and no emulator.** Not one instruction in this course
   has been run. Every number is a **bit pattern**, a **count of bit patterns**,
   an **arithmetic identity**, or a **refusal from a real assembler**. There is
   no claim about speed, latency, throughput or portability anywhere in the
   artifact or the five concept pages.
2. **No second AArch64 assembler.** `clang` assembled the corpus and
   `llvm-objdump-21` disassembled it, so both readers come from one LLVM tree.
   GNU binutils has no AArch64 target installed. The cross-check establishes
   that this decoder and one other piece of software agree on what the bytes
   mean — **not** that either agrees with the silicon.

And one tool difference, which cost a whole afternoon and is retraction R10:
**this `llvm-objdump` has no `-b binary` option.** `--triple=aarch64 -D -b
binary f` prints `error: unknown argument '-b'`. The ISA course's harness uses
GNU objdump, which has it, so the technique worked there and does not work here.
Every single-word probe in the artifact is therefore assembled into a real
object file and asked about in a section the disassembler already knows how to
read.

### Why those four absences are a feature, not a limitation

The four kinds of claim this course makes do not need a machine to verify, do
not go stale when a compiler changes, and can be checked by a reader with a hex
editor. That is the design, and it is the same reason the chain starts here: a
byte that means something is the first step of
`lexing → parsing → IR → codegen → object files → linking → executable`, and
it is the only step in that chain that is fully checkable without silicon. The
parts that need hardware — whether a `csel` is cheaper than a branch, whether a
load hits, whether a bitfield move is one instruction or two — are somebody
else's course, and section 15 names them.

## Scope: what the collection had not said

The rule that shaped this course is in `docs/aarch64-section-plan.md`, and the
sibling rule in `docs/x86-64-section-plan.md`:

> *"The comparison lives in the neutral courses; the depth lives in the
> per-arch ones."*

A scan over the concept files of the shipped courses, taken before this one was
written:

| Term | Files | Note |
|---|---|---|
| `bits[28:25]`, class field | **0** | the ISA course's decoder is x86-only |
| logical immediate, `N:immr:imms` | **0** | nowhere in the collection |
| `CSEL` `CSET` `CSINC` | **0** | only as a passing mention in RISC-V comparisons |
| `MOVZ` `MOVK` `MOVN` | **0** | |
| `ADRP` `:lo12:` | **0** | |
| `LDP` `STP` | **0** | |
| `TBZ` `CBZ` | **0** | |
| AArch64 *anything* | 0 | **the architecture was entirely absent** |

The debt this course pays is the whole of one architecture's encoding. What it
does **not** owe is anything the neutral courses already taught: the ELF
course's section-header table is where the artifact's own reader comes from
(`e_shoff` at `0x28`, the section array at `0x3a`, `struct.unpack_from`, no
library), and the ISA course's `isa-length` is where the variable-length
property is derived that this course's first concept is the negation of.

## What was measured, and what it changed

Every row below is reproducible with `build_samples.sh`, and every number in the
concept pages comes from the recorded run in `a64dec.out`.

| # | Experiment | Recorded result | What it changed |
|---|---|---|---|
| A1 | Walk every code section of five object files | 868 instructions, every section a multiple of 4, every walk ends EXACTLY, 4.0000 bytes/insn in all five rows | **The course's premise, established as a measurement rather than a definition.** It also fixes the declared subset: a subset of NAMES, not of LENGTHS. |
| A2 | Read bits[28:25] out of 868 words and ask the oracle | 11 of 16 values carry a real instruction; `ret` is 134 of the 868 in class 01011 | **R2: the class field is FOUR bits.** The two-bit rule put `ret` in the wrong class because bits[28:26] of `0xd65f03c0` is `0b110`, and it cannot see 01101 at all. |
| A3 | Assemble an instruction, change one operand, OR the XOR over a sweep | 58 field positions, 0 refusals, `Rt2` = bits[14:10] | The guards in part one are built from this table and it is written to `fields.txt`. A single pair would have given an 8-bit `imm16` for a 16-bit field — **R12.** |
| A4 | AND every word in each decoder group | ~15.5 of 32 bits dead per instruction, averaged over multi-member groups | "Wastes a lot of its width" is true and the number is ~48 %, not a slogan. The per-mnemonic and reserved-bit measurements give two *different* numbers, and the artifact says so rather than picking one. |
| A5 | Enumerate the logical-immediate encoding | **1,302** of 2³² 32-bit values; **5,334** of 2⁶⁴ | The smallest literal field in the architecture reaches more values than any other 12-bit field, including the add/sub immediate's 4,095. Derived, not quoted. |
| A6 | Ask the assembler for all 1,302 and read every word back | 1,302 agreed, **0 disagreed** | The only self-check here that could have failed for a reason the artifact does not control. The self-consistent round trip (5,334 values, 0 failures) is necessary and not sufficient. |
| A7 | Ask for `#0xffffffff` and `#0xffffffffffffffff` on all eight logical ops | **all sixteen refused**, same diagnostic | **R3 and R16.** The all-ones and all-zeros are not encodable at *either* width, which reverses the first draft's claim that 64-bit all-ones was fine. One bit short of all-ones IS accepted: the boundary is SHAPE, not WIDTH. |
| A8 | Assemble wide constants the obvious way | 1 / 2 / 4 instructions depending on the pattern, not the size | The cheapest 64-bit constant is the one with no variety in it: `movn x0, #0`. The largest signed 64-bit value costs the same four as an arbitrary literal. **The first draft predicted "big = expensive" and got all three wrong.** |
| A9 | The 4×4 table of conditional selects, built as WORDS | Four operations; four cells UNDEFINED in both readers | **R13.** The first draft called two reserved cells "the SET forms", and the first *table* assembled a line per cell and printed `csinv` eight times because there is no mnemonic for (invert, op2) = (1,0). |
| A10 | `cset w0, eq` against `csinc w0, wzr, wzr, NE` | `0x1a9f17e0` on both sides, and `csinc …, al` is `cset w0, ne` | **R6, the trap of the course.** The condition is INVERTED, the two are different 32 bits, and 23 of the 56 selects in the corpus are inverted forms whose output is 0 or 1 either way. |
| A11 | Count the family with `startswith` | printed 45; the nine names add to **56** | The `startswith` test misses `csinc`, `csinv` and `csneg` — the eleven it lost were three of the four operations, i.e. exactly the ones whose selection depends on the bit-30/`op2` pair. The count is now the sum of the nine numbers printed above it. |
| A12 | Two readers over the whole corpus | 859 named, **0 disagreements** | 100 %, which is also what a broken cross-check looks like. Hence A13. |
| A13 | **Poison** the largest model and re-run the same loop | 859 → 717, moved by exactly 142 | The control. The first version prepended a no-op model instead of removing one, the number did not move, and the line above it said POISONED. **R14.** |
| A14 | The 98.72 % run, with all eleven failures listed | 2 real decoder bugs + 9 silent normalisation failures | **R17, the most important line in the file.** One normalise rule was written as `^movn([\w,]*),#…` and `[\w,]*` does not match the space between mnemonic and operands, so it matched nothing and the cross-check printed its number anyway. The real bug: the logical-immediate model printed register 31 as `sp` where the encoding says zero. **R15.** |
| A15 | Same C, both targets, four -O levels | ratios 1.152 / 0.813 / 0.797 / 1.292 | **R1, retracted and REVERSED at half the levels.** AArch64 is larger at -O0 and -Os, smaller at -O1 and -O2. The defensible claim is that fixed width costs bytes in spill-heavy code and saves them otherwise. |
| A16 | Length distribution, same objects, two rules | x86-64 has 7 distinct lengths; AArch64 has 1 | The claim is not "4 bytes" but "a CONSTANT", and the only way to show a constant is to show what it is constant against. |
| A17 | Boundaries, by asking the assembler | 26 accepted edges, 29 refusals, 18 distinct diagnostics | A scaled field is **not** a contiguous range, in four places: the add/sub immediate, the pair offset (×8), the unscaled load offset, and the branch displacement (×4). **R4 and R5.** |
| A18 | Branch displacement boundaries, from memory vs by bisection | the assembler refused `b.eq .+0x1ffffc` and `b .-0x40000000` | **R5, retracted twice.** A 19-bit signed field reaches +0xffffc and −0x100000; a 26-bit one reaches +0x7fffffc and −0x8000000. The ends are not symmetric and a sign extension is not a magnitude. |
| A19 | `b T` in a three-word file | displacement −8, not +4 | The first boundary list labelled its own row "the far end" while measuring the nearest displacement. A **label is a name; the table is about numbers.** |
| A20 | ADR and ADRP, byte by byte | one bit apart (bit 31); the 21 bits are split with a 5-bit hole | Bit 31 is `sf` in most groups and something else in three. **R11.** And `:lo12:` is not a field in either instruction — it is arithmetic on the symbol that produces a relocation, which is the limit of a byte-level decoder. |
| A21 | `sbfx w0,w1,#29,#3` | accepted, as `asr w0, w1, #29` | A boundary table containing a row where the instruction changes identity would be a table of something else. The bitfield and shift encodings overlap. |

## What the artifact deliberately does not do

* **It does not execute anything.** Section 1 prints the two absences before the
  first measurement; section 15 lists the consequences in its own words.
* **It does not use a tool to DECODE.** Part one imports `os`, `re`, `struct`
  and `sys` and nothing else, and reads the ELF64 section table by hand. A
  decoder that shells out to a disassembler is a disassembler with a hardcoded
  path in it.
* **It does not drop what it cannot model.** 9 of 868 words are Advanced SIMD
  and are *counted* and printed as `(op 0x…)`. **R8 and R9:** the subset is a
  subset of NAMES, and a cross-check that reported unmodelled words as
  failures would be reporting its own declared scope as a bug.
* **It does not print its retractions in a footnote.** Section 14 prints all
  seventeen in full, and `crosscheck.py` asserts their *presence* as text.
* **It does not trust its own cross-check.** The poison is the point.

## Reproducing everything

```bash
cd courses/a64asm/assets/samples
./build_samples.sh            # build the corpus, run the artifact, run the harness
python3 crosscheck.py         # against the SHIPPED a64dec.out -- no toolchain needed
```

`a64dec.out`, `fields.txt`, `run1.txt` and `run2.txt` are committed, and the
two runs are byte-identical. The object files are not: they are reproducible
from `corpus.c` and `a64.s` with one command, and a course whose numbers are
only checkable on the machine that produced them is a course whose numbers are
claims.
