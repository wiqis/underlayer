# Executable Security and Hardening — research log

Every claim about a hardening feature was measured before it was written, on
this machine, with these tools. Claims that did not survive measurement were
retracted rather than softened, and the retractions are recorded below.

## Toolchain, and why it is the whole story here

| Tool | Version | Why it matters |
|---|---|---|
| gcc | 15.2.0 (Ubuntu 15.2.0-16ubuntu1) | Enables `_FORTIFY_SOURCE=3` and a stack protector **by default**, and passes `-z relro -z now` to `ld` |
| clang | 21.1.8 (Ubuntu 1:6ubuntu1) | Enables **neither** by default, and passes no `-z` flags |
| GNU ld | 2.46 (bfd) | Reads the flags, emits the tags |
| glibc | 2.43 | Provides `__strcpy_chk`, `__read_chk`, `__vprintf_chk` |
| binutils | 2.46 | The oracle for every field |

**The two compilers disagree, and that is the course.** On this machine, with
one source file, `-O1`, and no flags of any kind:

| | stack canary | RELRO | `.got.plt` tail |
|---|---|---|---|
| `gcc -O1 prog.c` | present | **full** | covered |
| `clang -O1 prog.c` | **absent** | partial | **writable** |

Two binaries from one source and one command line, differing in two
independent hardening properties. Everything in module 1 is a consequence.

## Scope: what the prior courses left open

`grep -rl` over all ~37 concept files written before this one:

| Term | Files |
|---|---|
| `stack-protector`, `stack canary`, `canary` | **0** |
| `FORTIFY`, `_FORTIFY_SOURCE` | **0** |
| `full RELRO`, `partial RELRO` | **0** (RELRO is *mentioned* 8 times; the two tiers never are) |
| `CET`, `IBT`, `SHSTK`, `safe-linking` | **0** (`endbr64` appears 3 times, only in DWARF address-range context) |
| `TEXTREL`, `RWX` | **0** |
| `DT_BIND_NOW`, `DF_BIND_NOW`, `DF_1_NOW` | **0** |
| `abort_on_error`, `stack clash` | **0** |

There **are** two hardening concepts already: `macho-hardening` (NULL-page, ASLR,
PIE) and `pe-security-flags` (`DllCharacteristics`: ASLR, NX, CFG). Both are at
the **flag level on a non-ELF platform**. Neither shows what a flag *does to the
file*, and neither covers the stack canary, FORTIFY, the RELRO tiers, or CET at
all. So the course is not a duplicate: it is the same subject moved to x86-64
ELF and moved down from flag names to bytes.

## The findings

### F1 — clang and gcc disagree on three independent defaults

Measured with `gcc -O1 -### ... ` and `clang -O1 -### ... `, and confirmed in
the output files:

- **Codegen.** clang emits **0** `%fs:0x28` references by default; gcc emits
  **2**. Same source, same `-O1`, same machine.
- **Linker flags via the driver.** gcc passes `-z relro -z now`; clang passes
  **nothing**. So the gcc binary gets full RELRO and the clang binary gets
  partial — and under clang the `.got.plt` tail is left writable.
- **FORTIFY.** gcc defines `_FORTIFY_SOURCE=3` by itself at `-O1`; clang does
  not.

The three are independent: a build system can pin the compiler and still
inherit a different linker policy from the driver.

### F2 — The canary sees the frame and nothing else

The mechanism, in the gcc default build: `mov %fs:0x28,%rax`, `mov %rax,0x18(%rsp)`,
then on exit `sub %fs:0x28,%rax` and `jne` to `__stack_chk_fail`.

Three overflows, 200 bytes each, in two builds:

| case | overflows | default gcc (canary + FORTIFY) | canary only |
|---|---|---|---|
| a | a **global** | `buffer overflow` | **no diagnostic** |
| b | its **own local** | `buffer overflow` | `stack smashing` |
| c | a global, no local array | `buffer overflow` | **no diagnostic** |

**FORTIFY caught all three; the canary caught one.** And the two mechanisms are
trivially confused because both abort — the *message* is what distinguishes
them (`*** stack smashing detected ***` vs `*** buffer overflow detected ***`).
A canary is a per-frame tripwire, so a write that never touches the frame is
invisible to it by construction.

### F3 — RELRO's two tiers are about how far the range reaches

Built `-no-pie` so file vaddrs *are* runtime addresses:

| mode | RELRO | ends on a page | `.got.plt` |
|---|---|---|---|
| no flag | `0x403df8..0x404000`, memsz `0x208` | yes | `0x403fe8..0x404008` — **crosses the end** |
| `-z relro` | identical, memsz `0x208` | yes | identical — **crosses the end** |
| `-z relro -z now` | `0x403dd0..0x404000`, memsz `0x230` | yes | **absent**, absorbed into `.got` |

Three things fall out:

1. **`-z relro` is a no-op on this toolchain.** The linker already emits a
   `GNU_RELRO` segment with no flag at all, at the same size. The tiers are not
   about the segment existing.
2. **The RELRO end is a page boundary in all three**, so `-z now` extends the
   range *backwards*, not forwards.
3. **The partial case leaves 8 bytes of `.got.plt` writable** — and that is
   precisely where lazy binding writes the resolved address. So `-z now` is not
   a free upgrade: it is the thing that makes sealing the GOT *possible at
   all*, because under lazy binding the loader still needs to write there.

### F4 — FORTIFY's trace is in the imports

| level | libc entry points called |
|---|---|
| 0 | `printf read strcpy strlen` |
| 1 | `printf __read_chk __strcpy_chk strlen` |
| 2 | `__read_chk __strcpy_chk strlen __vprintf_chk` |
| 3 | same as 2 for this specimen |

The mechanism: `mov $0x20,%edx` immediately before `call __strcpy_chk@plt`.
`0x20` is 32, the `sizeof` of the destination local — a compile-time fact
turned into a runtime argument so libc can compare it against the actual
length.

### F5 — W^X: the stack bit, and why TEXTREL is nearly extinct

`PT_GNU_STACK` is `RW` by default, `RWE` under `-z execstack`. `-z execstack`
is the flag to look for in a Makefile.

TEXTREL **could not be forced**, with `-z text` not refusing the link. The
reason is the finding: a table of `const char *const` went to `.data.rel.ro`
(`0x3e20..0x3e38`), which is inside the RELRO range (`0x3e10..0x4000`) and is
writable *during* load. The loader had somewhere legal to write, so it never
needed a writable text segment. `.data.rel.ro` is why TEXTREL is nearly
extinct, and it is the same sealing mechanism as full RELRO doing a second job.

### F6 — CET: the instructions and the request are different things

| build | property note | properties claimed | `endbr64` total | in `main`/`helper` |
|---|---|---|---|---|
| `-fcf-protection=none` | `0x10` | `x86 ISA needed` only | 5 | **0** |
| `-fcf-protection=branch` | `0x20` | `IBT` | 7 | 1 |
| `-fcf-protection=full` | `0x20` | `IBT, SHSTK` | 7 | 1 |

**With protection explicitly off, the binary still contains 5 `endbr64`** —
they come from `crt1.o` and `crti.o`, which the distribution built with
protection on (2 each, measured). So a hardening report that counts
instructions and calls the binary protected is wrong; **enforcement comes from
the property note**, which the kernel reads, and the note says nothing.

## Retractions, recorded

**R1 — "A known-size destination gives you `__memcpy_chk`."** It does not, on
clang 21. `char b[4096]; memcpy(b, s, 2048);` emits plain `memcpy` at
`_FORTIFY_SOURCE=3`. `strcpy` becomes `__strcpy_chk` reliably; `memcpy` did
not, and the rule was not determined from source and is not claimed. What *is*
claimed: FORTIFY is a compile-time technique whose visible effect is in the
binary's imports, so you verify it by reading the file.

**R2 — The first H2 claim was "a global overflow is not caught."** Wrong in the
default build: **FORTIFY caught it.** The canary did not. The concept now leads
with the two-mechanism distinction, which is both true and more useful.

**R3 — "The binary has 5 `endbr64` therefore it is CET-enabled."** Wrong.
Those 5 are the C runtime's, and the note does not request enforcement. Both
the claim and the counting method were retracted.

## Errors in the tooling, kept because they are the lesson

**E1 — `harden.py` hung on the first real binary.** The GNU property note loop
computed its step from `psize`, and a `psize` of 0 advances the cursor by
nothing, so the loop never terminated. The symptom was a hang with no output,
which is the worst possible failure for a security report. Fixed with a
guaranteed positive step, and asserted in the crosscheck.

**E2 — The crosscheck's section reader was one column out.** `readelf -SW`
prints `Nr Name Type Address Off Size`, and the helper returned the *file
offset*. Four separate checks then reported hardening claims as false when the
claims were fine. A check that fails for the wrong reason is worse than no
check, because it teaches you to ignore it. The column is now named
(`'addr'`/`'off'`/`'size'`) rather than numbered.

**E3 — Two checks searched for driver flags in the wrong stream.** `gcc -###`
prints the command line on **stderr**. The helper returned stdout only, so the
checks found nothing and — this is the dangerous part — **a security check that
finds nothing is indistinguishable from a security check that never ran.** Both
now read both streams.

**E4 — The `-O1` optimiser deleted the evidence, twice.** The first H2
specimen's local array was folded away at `-O1`, so gcc declined to instrument
the function and the canary count was 0 — the source had a local array and the
binary had no canary. The second was `read()` whose result was unused: the call
vanished and `read@plt` went 2 → 0, which looked exactly like FORTIFY level 3
"removing" the call. Both were the same lesson as the TLS retraction in the
relocations course: **when two things measure as identical, the first
hypothesis is that the optimiser deleted the difference.**

**E5 — All the `sp_*` specimens had the same name.** The build loop took the
empty string before the colon, so four builds overwrote one file and three
ladder rungs silently measured the last one. Found by the crosscheck, which is
the argument for having one.

## What is deliberately not claimed

- **The ASLR entropy in bits.** Not measured. The course says the canary and
  RELRO facts and does not reopen ASLR, which the relocations course covered.
- **Stack-clash protection, safe-linking, `_FORTIFY_SOURCE=3`'s compile-time
  diagnostics.** Not exercised; the specimens do not trigger them. Named as
  existing, not measured.
- **AArch64.** No second architecture available. The DWARF concepts cover
  AArch64 frame records; nothing here claims a second-architecture result.
- **Why gcc and clang chose these defaults.** Observed and characterised, not
  explained from source. Each toolchain documents its own defaults; this course
  did not read those documents and does not attribute intent.
- **Whether the `endbr64` in `crt1.o` was deliberate.** Measured present;
  provenance not established.

## Reproducing

```bash
cd courses/sec/assets/samples
./build_samples.sh     # 8 finding groups, from an empty directory
python3 crosscheck.py  # 60 checks
python3 harden.py <binary> ...   # the artifact
```

Tracked: `build_samples.sh`, `crosscheck.py`, `harden.py`, `.gitignore`.
Everything else — every `.c` file, every binary — is a build product, and
`build_samples.sh` writes the `.c` files itself.
