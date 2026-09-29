# x86-64 Assembly and Encoding — research log

Every number in the course was measured before it was written, on this machine,
with these tools. Claims that did not survive measurement were **retracted
rather than softened**, and all fourteen retractions are printed by the
artifact in section 6 and asserted as text by `crosscheck.py` group H so that
they can be neither quietly dropped nor deleted.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U, family 0x19 model 0x50 (Zen 3) |
| Topology | 1 socket, 6 cores, 2 threads/core = 12 logical CPUs |
| L1d / L1i / L2 / L3 | 32 KiB / 32 KiB / 512 KiB / 16 MiB |
| **AVX-512** | **absent.** `avx512f` is not in `/proc/cpuinfo`; a hand-built EVEX instruction raises #UD (signal 4) on this part |
| TSC | 2.2957 GHz busy, 2.2957 GHz across a 300 ms sleep — **invariant to 0.0004 %** |
| PMU | **absent.** `perf_event_paranoid = 4`, and a forked child that executed `RDPMC` was killed with SIGSEGV |
| Kernel | 5.15.0-*, gcc 15.2.0, binutils 2.46, Python 3.14 |
| Noise floor | measured per run and printed **before any claim**, on two bodies: a pointer chase (7.67 ticks/op) and an arithmetic loop (0.70 ticks/op) |

Three facts about the machine decide what this course may claim at all:

1. **No hardware performance counters.** Nothing here counts instructions,
   cycles, branch predictions or mispredictions. Every number in sections 2 to
   4 is a **duration**, and a duration bounds a count without measuring it.
2. **No AVX-512.** So the EVEX rows are a *decoder* result and a *fault*
   result, never a timing result, and the concept says which is which.
3. **The machine is a loaded guest and it is very noisy.** Three runs of the
   same two-instruction comparison produced single-pair ratios of 2.00×, 0.55×
   and 2.77×. The artifact therefore measures that one ratio **seven times,
   alternating**, and reports the distribution rather than a pair.

## Scope: what the seven neutral courses left open

The rule that shaped this course is in `docs/x86-64-section-plan.md`:

> *"The comparison lives in the neutral courses; the depth lives in the
> per-arch ones."*

A word-boundary scan over the concept files of all 21 shipped courses, taken
before this one was written:

| Term | Files | Note |
|---|---|---|
| `SUB` `CMP` `MOVZX` `LEAQ` `SHR` `ROL` `SETcc` `CMOVcc` | **0** | the integer set is untaught as a set |
| `red zone` `callee-saved` `caller-saved` `GPR` | **0** | owed to course B (`x86abi`), not here |
| `AT&T` `Intel syntax` `disassembl` | **0** | this course's first concept |
| `addps` `addpd` `movaps` `pxor` | **0** | the ISA course covers **14** `0F xx` opcodes total |
| `EFLAGS` | 2 | both in the execution course, both as a *role*, never as a bit layout |
| `VEX` `EVEX` | several | **all as prefix bytes** in the `0x62`-is-`BOUND` collision. The ISA course taught what byte introduces an AVX-512 instruction and never said what the instruction does |

So the debt this course pays is narrow and specific. `<a href="/courses/isa/lessons/isa-modrm">The ISA course</a>`
taught the ModRM byte. `<a href="/courses/isa/lessons/isa-rex">REX</a>`. `<a href="/courses/isa/lessons/isa-sib">SIB</a>`. `<a href="/courses/isa/lessons/isa-length">The length arithmetic</a>`, and a
1042-line decoder in `<a href="/courses/isa/lessons/isa-decode">isa-decode</a>`. **What is owed in return is the
exhaustive x86-64 reference**: the whole integer instruction set as a set, the
complete flag list, and the VEX/EVEX encodings as *what they encode* rather
than as two more bytes to recognise.

## What was measured, and what it changed

| # | Experiment | Recorded result | What it changed |
|---|---|---|---|
| F1 | TSC rate, busy and across a 300 ms sleep | 2.2957 vs 2.2957 GHz, drift 0.0004 % | A tick is TIME. Every figure is a ratio. |
| F2 | Noise floor on two bodies | pointer chase 7.67, arithmetic 0.70 ticks/op | The arithmetic floor is the *clock*, not noise. The chase is the floor this course quotes. |
| F3 | PMU absence | `RDPMC` in a child → SIGSEGV; `perf_event_paranoid = 4` | No count of anything. Stated before any claim. |
| F4 | ADD/SUB/CMP/TEST, one chain of eight against eight independents | add 3.65×, sub 3.25×, **cmp 0.86×, test 0.78×** | **The course's central result.** ADD and SUB chain on a *data* dependency. CMP and TEST chain on the *flags register* and do not, because the flags are renamed. The ISA says they write the same REGISTER, which is a different sentence. |
| F5 | LEA of three inputs against `mov`+`add`+`shl` | mean of seven alternating ratios 1.15×, spread 230 % | **The "one instruction beats three" claim is retracted (R2).** There is no 3× win in either direction and a mean near 1.0 is not evidence of equality. |
| F6 | LEA shape sweep | base 1.207, base+index 0.661, +disp 1.206, +scale 1.207 | The AGU has a cost; the *instruction count* does not. INFERRED: no counter. |
| F7 | `lea (%rdi,%rsi,3)` | `as` **refuses**: `expecting scale factor of 1, 2, 4, or 8` | The encodable scales are the SIB byte's two bits, and a refusal is better evidence than a claim. |
| F8 | `shl $1` against `shl %cl` | 0.58×–0.95× depending on the run | The immediate form is not the cheap one. The count is **masked to six bits**: `cl=64` is identical to `cl=0`. |
| F9 | `shl %cl` with `cl=63` and no clear | measured cheaper, dearer and equal on three runs | **A timing table cannot tell a fast instruction from a deleted one** (R6). Only the bit pattern settles it. |
| F10 | `movzx`/`movsx`/`mov eax,eax` | 0.66 / 1.21 / 0.82 ticks/op; `movzx 0x88 → 0x88`, `movsx 0x88 → 0xffffff88` | The cost is unremarkable. The *correctness* is the story. |
| F11 | `mov ax,al` against `mov eax,al` on `0x1122334455667788` | `0x1122334455667788` against `0x0000000055667788` | A **16-bit write keeps the top 48 bits**; a 32-bit write clears them. Exact, and the second one costs somebody a day. |
| F12 | `shr $1` on `-1` | `shr $1,%eax → 0x000000007fffffff`, `shr $1,%rax → 0x7fffffffffffffff` | A 32-bit destination is *also an instruction to clear the top half*. |
| F13 | EFLAGS read with `pushfq` after six operations | `0x206` add, `0x293` sub, `0x212` shl, `0x216`/`0xa16` shr, `0xa12`/`0xa12` div | The two `shr` rows differ in **exactly one bit and it is bit 11, OF**; the two `div` rows are **byte-identical**, and a divide writes no flags at all. |
| F14 | Six reserved flag positions | bit 1 reads 1; bits 3, 5, 15, 22, 63 read **0** | A program that saves EFLAGS and compares it is comparing a value the architecture does not fully define. |
| F15 | `cmp`+`cmovl`, `cmp`+`xor`+`setl`+`movzx`+`add`, `cmp`+`jl` | 1.207 / 2.100 / 0.682 ticks/op | The branch wins in a loop the predictor can learn, and the setcc arm is **five** instructions because `setcc` writes a byte. The predictability question is **not measurable here** (R3, R5). |
| F16 | A `cmovl` whose condition is false, reading a `PROT_NONE` page | **SIGSEGV** | **The sharpest result in the course.** A failing cmov still reads its source. |
| F17 | A not-taken `jl` reading the same page | **no fault** | A failing branch touches nothing. Not a timing: a fault. |
| F18 | The same `jl` with its body taken | SIGSEGV | The control, so the page really was unreadable. |
| F19 | The four encodings, decoded by this file and by objdump 2.46 | 51 of 51 modelled entries agree; 0 disagreements | A two-reader cross-check with a declared subset. |
| F20 | `vaddps %ymm2,%ymm0,%ymm1` | `c5 fc 58 ca` — **two bytes** | **The most widely repeated false fact about VEX is retracted (R1).** The three-byte form is for four register numbers and a fourth operand. |
| F21 | Hand-built `62 f1 7c 48 58 ca` | objdump: `vaddps zmm1,zmm0,zmm2`; executed here: **signal 4** | A second reader names it correctly and the silicon refuses it. Three instruments, three answers, all correct. |
| F22 | The same six bytes with one bit of byte 4 changed | `vaddps zmm1{k2},...` and `...{ru-sae}` | One bit of an encoding field is the difference between a masked instruction and a rounding mode. |
| F23 | `blendvps` | `66 0f 38 14 d1` — a **fourth** operand that is hard-coded and not in the bytes | The thing the VEX `vvvv` field removed. |
| F24 | One-, two- and three-instruction vector add | within a factor of about 2, order moving | The copy the three-operand form removes was **free** (R13). The encoding is a source-level feature and no duration here can price it. |
| F25 | The three maps, probed 768 slots, read twice | `0F` 218 legacy / 101 VEX; `0F38` 28 / 125; `0F3A` **2 / 54** | **The course's second headline.** The newer maps are the *emptiest* part of the encoding in their legacy form and half full with one byte in front. The draft said the opposite (R12). |
| F26 | The corpus decoded twice through the same code path | 100 % agreement; **100 % again after poisoning the table** | Self-agreement is not evidence, demonstrated rather than asserted. |
| F27 | The whole artifact, run to completion | **hung** for 30 s of user time | **R14**, the best bug in the file: the loop counter was bound with `"c"` and decremented in `%rcx` without declaring it, so the second repetition of every body started at zero and looped 2^64 times. And it was **latent** — the same source with a changed surrounding loop bound ran in 1.7 s. |

## Retractions, all fourteen

R1 the three-byte VEX is for 256-bit · R2 LEA beats three instructions ·
R3 LEA is a multiplier · R4 the setcc arm is three instructions · R5 prefer
the cmov · R6 the variable shift count is a win · R7 CMP and TEST form a chain ·
R8 subtract the nop control · R9 the map counts are the instruction count ·
R10 restate the vector course's alignment number · R11 the EFLAGS table was a
table of claims · R12 the newer maps are nearly full · R13 the three-operand
form bought a speed-up · R14 the artifact is correct because it terminates.

## Limits, printed rather than footnoted

* **No cycle counts.** No PMU. Every number is a duration.
* **No branch mispredictation rate, and therefore no predictability claim in
  either direction.** An arm that mixed a predictable and an unpredictable
  branch was written, measured and **deleted**: it measures a blend it cannot
  decompose.
* **No observation of flag renaming.** Consistent with renaming and with not
  renaming; the AMD manual is the only source that says which.
* **No AVX-512 execution.** Nothing about a ZMM or a `k0`-`k7` mask register is
  timed. What *is* measured is that the encodings decode, by a second reader,
  and that this machine cannot run them.
* **The other two architectures are quoted, not measured.** There is no such
  machine in the room.

## Reproducing

```sh
cd courses/x86asm/assets/samples
./build_samples.sh          # assemble, probe, build, run, cross-check
python3 crosscheck.py       # 155 checks against the recorded run
```

`x86dec.out`, `run1.txt` and `run2.txt` ship, so the claims are checkable on a
machine that never ran the benchmark. All three are **155/155** as recorded.
