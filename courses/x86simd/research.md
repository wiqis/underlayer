# The x86-64 Data Path: Atomics, Ordering and Vectors — research log

Every number in this course was measured on this machine, with these tools,
**before** it was written. Claims that did not survive measurement were
**retracted rather than softened**, and all twenty-four retractions are printed
by the artifact in section 7 and asserted as text by `crosscheck.py` group J,
so that they can be neither quietly dropped nor edited into being right.

**Two of the twenty-four are about the artifact itself, and they are the best
material in the course.** R23 is a cross-check that reported *28 disagreements
out of 30* and was **believed** — the encoder was perfect and the reader of the
disassembly was aimed one row off. R24 is a ping-pong instrument that took
**three attempts** to fix, and two of the three produced numbers that looked
entirely reasonable. Neither is a mistake about how a computer works, and that
is the argument for the whole collection: the interesting failures here were not
in the architecture, they were in what a number means.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U with Radeon Graphics (Zen 3), family 0x19 model 0x50 |
| Topology | 1 socket, 6 cores, 2 threads/core = 12 logical CPUs; **one NUMA node** |
| TSC | 2.2957 GHz busy, 2.2957 GHz across a 300 ms sleep — **invariant to 0.0005 %** |
| **AVX** | `CPUID.1:ECX` AVX = 1, FMA = 1; `CPUID.7.0:EBX` AVX2 = 1, F16C = 1 |
| **AVX-512** | `CPUID.7.0:EBX` F, DQ, CD, BW, VL = **five zeros** |
| **XCR0** | `0x0000000000000207` — bits 0, 1, 2, 9. The AVX-512 state bits **5, 6, 7 are clear**, so they are not merely unsupported, they are not enabled |
| `CR4.OSXSAVE` | **a direct `mov %cr4, %rax` faults in this environment** (signal 11). The bit is *inferred* instead: `XGETBV` is `#UD` without it and `XGETBV` returns |
| PMU | **present in the metal, absent to the process.** `perf_event_paranoid` = 4 |
| Kernel | 7.0.0-34-generic, gcc 15.2.0, binutils 2.46, Python 3.14.4 |
| Noise floor | measured per run and printed **before any claim**, on two bodies: a pointer chase (6.636 ticks/op in the recorded run) and an arithmetic increment loop (1.011), which are **6.56x** apart, and the arithmetic one is printed as *the clock*, not as noise |
| Placement | two threads pinned to two CPUs, and the CPU that answered is read back from inside the process and printed |

Three facts about the machine decide what this course may claim at all.

1. **There are no readable event counters.** Nothing here counts instructions,
   cycles, uops, cache lines or coherence transactions. Every number in the
   artifact is either a **fault**, a **bit pattern**, an **exact byte** or a
   **duration** — and a duration bounds a count without measuring it, so every
   mechanism named anywhere in this course is marked `INFERRED` unless it is a
   fault, a bit pattern or a byte.
2. **This machine cannot execute one instruction in the AVX-512 concept.** The
   third concept is therefore *reference plus a bytes-only decoder*, and every
   claim on it says which it is. That is a deliberate outcome rather than a
   gap, and the general form is worth more than the feature: *a reference for
   something you cannot run is still worth writing, provided every sentence in
   it says whether it was measured.*
3. **The alignment requirement is a FAULT requirement, not a speed one.** The
   SIMD course measured an unaligned 32-byte load as free on this machine; the
   `+8` probes here return `SIGSEGV` instead. Both are true and they are
   different claims, which is why the ten probes in section 2 are forked
   children rather than a timing table.

## Scope: what the twenty-four courses before it left open

The rule that shaped this course is in `docs/x86-64-section-plan.md`:
*"the comparison lives in the neutral courses; the depth lives in the
per-arch ones."* Two neutral courses own the principles and are **linked, not
repeated**:

| Neutral concept | What it owns | What this course therefore does NOT do |
|---|---|---|
| `simd-width` | the width experiment (3.89x at 2 KiB, 1.14x at 24 MiB) | **does not re-measure the width.** This course measures alignment, the three-operand form and `vzeroupper` instead |
| `simd-reduce` | the tail, measured at 1.02x | quotes that number as the AVX-512 concept's motivation, and does not restate it as a result |
| `simd-boundaries` | where a vector loop stops being safe | links, and adds the *fault* half that the neutral course does not have |
| `smp-atomic` | what a lost update costs, and the store buffer | quotes both; the x86-64 reference is the instruction list |
| `smp-ordering` | TSO as a model | the x86-64 half: three opcodes, six bytes of encoding, one documented rule |
| `x86asm/vex` | the VEX encoding, and the 1.00x for the removed copy | **inherits the number and re-measures it** on the body where the destination IS also a source |

A word-boundary grep over the 24 courses that shipped before it confirmed the
rest was genuinely new ground. In the **neutral** courses: `cmpxchg8b` 0,
`cmpxchg16b` 0, `vzeroupper` 0, `lock inc` 0, `LOCK#` 0, `k0` 0, `opmask` 0,
`zmm_hi256` 0, `dirty upper` 0. The `fence` hits in the `exe` and `mem`
courses are a **timing technique** and never ordering — the same seam the
previous course in this section found.

Two of the zeroes needed a second look, and the corrections are the point of
running the grep rather than remembering it:

- **`lock xadd` is not zero — it is in `smp-atomic`, six times**, with the
  uncontended cost (2.54x a plain store) and the contended one (21.20x the
  floor) measured there. This course therefore **quotes that number and links
  back** rather than re-measuring an uncontended lock, which is exactly the
  remembered-number mistake `x86asm` documented as R10.
- **`opmask` and `zmm_hi256` are not zero either — they are in
  `x86sys/x86-boundary`**, which read `XCR0` while establishing that ring 3 may
  read the register. So the words exist in the collection but **nowhere as a
  claim about what they select**: that file needed the bits to report an
  absence, and this course is the first to say what a set bit would *mean*.

## What was measured, and what it changed

| Draft said | Measured | Effect |
|---|---|---|
| "VEX removed the alignment requirement" | `vmovaps` and VEX `vmovdqa` fault on exactly the addresses their legacy twins do | **R15.** The commonest claim about AVX. The SDM's own sentence is quoted beside it |
| "INC and DEC are not atomic even with `LOCK`" | `lock inc` is **exact** — 120000 of 120000, every run | **R2.** Caused by reading the SDM's list of eighteen instructions that *accept* the prefix as a list that *guarantees* it |
| "The direction flag is EFLAGS bit 21" | it is **bit 10**; bit 21 is the **ID** flag | **R1.** Read out of `PUSHFQ`, every bit named rather than the one remembered |
| "`MFENCE` and `SFENCE` differ in one bit position" | **two** bit positions, and they *share* reg = 7 | **R22.** A decoder switching on `ModRM.reg` alone gets them right by accident |
| "A round trip proves the encoder is right" | it certified an encoder that was wrong on 28 of 28 rows | **R9.** Fixed by a second reader that was not written from the same table |
| "The three-operand form is faster" | 1.00x on three bodies, two widths | **R5**, inherited from `x86asm` and re-measured rather than re-argued |
| "The `vzeroupper` transition penalty will show up" | the bit pattern came out the **other way round** | **R6.** Legacy SSE *preserves* the upper half; VEX-128 *zeroes* it |

## The two bugs that are the course

### R23 — a cross-check that disagreed with almost everything

The first run of the `objdump` cross-check reported **28 disagreements out of
30**, and the artifact reported them as evidence that the encoder was broken.
The encoder was perfect. The **reader of the disassembly** counted `objdump`'s
section header line as row 0 — that line has no mnemonic in it — so every row
was compared against its **neighbour's** text, and the two rows that still
"agreed" did so only because both of them happen to be `vaddps`.

```
  vecmaps_dis.txt                    loaded, 30 rows  (1 header, 290 padding skipped)
```

The fix is not "check your index". The fix is that the **loader now prints how
many lines it skipped** and the harness asserts the counts, because a loader
that stops skipping reads exactly as many lines as one that has not.

> A cross-check that **disagrees** with almost everything is as suspicious as
> one that **agrees** with everything. The two failure modes a misaimed check
> can have look nothing like each other and are equally wrong, and the only
> reason this one was caught is that the number was compared against what a
> correct run looks like rather than against whether it felt right.

### R24 — a floor that measured above the thing it floored

The store-buffer ping-pong took **three attempts**, and the tell was visible the
whole time: **the store-only floor came out above the ping-pong, in every run**,
which is impossible for a floor. The file printed the ratio instead of objecting.

1. The body took a thread id and never used it — both threads addressed
   `mine[0]` and `peer[0]`, so "my line" and "the peer's" were the same two words
   and the arm was the one-cache-line case wearing the wrong name.
2. Indexing by id was not enough. `aligned(64)` on a two-element array aligns
   the **array**, not each **element**, so the two words were still eight bytes
   apart in one cache line. *A layout is a claim, and a comment is not a
   measurement.*
3. The fix is a **stride**: a line is 64 bytes and a `uint64_t` is 8, so each
   thread gets a row of eight.

The layout is now printed above the table and asserted by the harness.

> A number that **cannot have come out** is the friendliest thing an experiment
> ever does, and the only way to deserve it is to hold a claim that says the
> number should have been **smaller**. A test that says *faster* passes when the
> instrument is broken; a test that says *slower* fails and hands you the
> instrument.

## Retractions, all twenty-four

Printed by the artifact in section 7 and asserted as **text** by
`crosscheck.py` group J, in numeric order. Not one is a mistake about how a
computer works: **six** are about what a *number* is (R2, R4, R18, R19, R20,
R22), **seven** about what an *instrument* is (R3, R8, R11, R16, R21, R23,
R24), **three** about what an *encoding* is (R9, R10, R15), and the rest about
what a *binary* contains or what a *specification* says.

The full text of each is in `docs/features-complete.md` under **P1 2.2.99**, and
each is reproduced in the artifact itself so that a reader who has only the
`.out` file can still read the correction next to the claim.

## Limits, printed rather than footnoted

A limit that is a footnote is a limit that gets forgotten. The artifact's section
7B names the instrument that would settle each of its nine entries, and four of
them are properties of the **instrument** rather than of the subject:

- **No event counter of any kind.** `perf_event_paranoid` is 4, `RDPMC` is a
  fault, `perf_event_open` is `EACCES`, `/dev/cpu/0/msr` is root-only. Settled
  by `perf_event_open` with `paranoid` below 4 and a PMU passthrough.
- **No AVX-512.** Settled by a Skylake-SP or a Zen 4.
- **Only one misalignment was measured**, at 8 bytes. That is the case that
  matters and the case that ran.
- **Whether any locked instruction asserted `LOCK#` on the bus.** On every
  processor since the P6 a locked instruction whose line is already cached
  does not drive the pin at all. Settled by a logic analyser.
- **The cost of a locked instruction, and the store-buffer depth.** The `smp`
  course measured an uncontended lock against a plain store, and that is the
  number to quote.
- **Why the downward string direction is slower.** Measured, four sizes, a
  shape. **Not explained** — there is no counter that can count the micro-ops a
  `REP MOVSB` expands to, and the vendor manual gives no number either.
- **A second run's ratios.** The exact figures move; the *shapes* do not, and
  every figure in the harness is asserted as an ordering or a shape for that
  reason.
- **AArch64, RISC-V, and every other architecture.** Quoted, not run. `LDXR`/
  `STXR` and `DMB` are a different instruction set with a different failure
  mode — an LL/SC pair can **always** fail and there is no way to make it not.

## Reproducing

```sh
cd courses/x86simd/assets/samples
./build_samples.sh              # build, run 3x, cross-check a FRESH 4th run
./build_samples.sh --quick      # fewer iterations in the timing sections

python3 crosscheck.py           # defaults to the RECORDED vecdump.out
python3 crosscheck.py run1.txt  # any other run
```

`vecdump.out`, `run1.txt`, `run2.txt`, `vecdump_dis.txt` and `vecmaps_dis.txt`
all **ship with the course**, so the harness is runnable on a machine that has
never run the benchmark and has no AVX-512. That is the property the section
plan asked for: *a course whose claims can only be checked by first rebuilding
its own artifact is a course whose claims are only verifiable on the machine
that wrote them.*

The build script also captures the disassembly of the probe bodies into
`vecdump_dis.txt`, which is how retraction 11 stays retracted: the first
alignment probe reported `returned` for eight instructions, four of which were
not in the binary, and the harness now asserts the mnemonics are present.

**Positive control, from the manifest's completion criteria:** delete the
header-skip in `load_dis()` in `vecmaps.c` so `objdump`'s section header is
counted as row 0 again, and watch group I report 28 disagreements out of 30 for
an encoder that is entirely correct.
