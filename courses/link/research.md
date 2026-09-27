# Static Linking and Linker Scripts — research record

Every finding was **measured on this machine**. The command is given so a reader
can re-run it and, more usefully, disprove it.

Two claims in this record were **retracted after being measured the first
time**. Both retractions are kept, with the reason, because the way they went
wrong is the most useful thing in the file.

## Environment

    ld / ld.bfd        GNU ld (GNU Binutils for Ubuntu) 2.46
    clang              Ubuntu clang 21.1.8
    readelf, objdump, objcopy   binutils 2.46
    python3            3.x (no third-party modules)
    x86-64 Linux, glibc 2.43

`ld --verbose` is the only introspection this course needs, and it works on
every GNU ld. No Mach-O linker or lld is used, and no claim here depends on one.

## Scope boundary — what the neighbouring courses already taught

`obj-archives` covers the `ar` container and archive semantics. `sym-order`
covers command-line ordering of files and archives. `sym-algorithm` traces
GNU ld's demand-driven resolution pass, the fixed-point archive iteration and
the map file. `sym-linker-defined` covers `__start_SECTION` / `__stop_SECTION`
and the other invented symbols. `elf-segment-types` and `elf-memory-mapping`
cover what a `PT_LOAD` is. `reloc-*` covers the relocation vocabulary, PIE and
the cost of position independence.

**Nothing in those courses mentions a linker script.** The script is the thing
that has been driving every link the reader has ever run, and it is the one
layer of the toolchain that ships as *source* — `ld --verbose` prints it. That
is the gap this course fills, plus the two areas a script uniquely controls and
nothing else does: where things are placed, and what survives.

## Finding 1 — the script is 276 lines and ld will show it to you

    $ ld --verbose 2>/dev/null | sed -n '/^====/,$p' | sed '1d;$d' > default.ld
    $ wc -l default.ld
    276 default.ld

Its top-level commands are `OUTPUT_FORMAT`, `OUTPUT_ARCH`, `ENTRY(_start)`,
thirteen `SEARCH_DIR` calls, and one `SECTIONS` block. That is the entire
program that placed the reader's last binary.

### RETRACTION 1 — "the round trip is identical" was wrong

The first version of this experiment compared **sizes**, found them equal, and
concluded the saved script reproduces ld's output. Comparing **files** shows
otherwise:

    flags                  ld's own default    with -T default.ld
    ---------------------  ------------------  ------------------
    (none)                 DYN                 EXEC     differ
    -fPIE -pie             DYN                 EXEC     differ
    -fno-pie -no-pie       EXEC                EXEC     BYTE IDENTICAL

The two binaries are the same *size* and differ at **byte 16**, which is
`e_type`. On this PIE-by-default toolchain ld emits `ET_DYN` with no script,
and the saved script emits `ET_EXEC`, because supplying a script selects a
fixed code model (Finding 9).

The honest claim is therefore narrower and more useful: **the script round-trips
byte-for-byte exactly when the command-line flags and the script agree about
the code model.** The script decides placement; the flags decide the model;
`-T` overrides the model towards `EXEC`. The lesson is not "the script is
everything" — it is "the script is one of two inputs, and they have to agree".

## Finding 2 — `SEGMENT_START` returns its second argument, on this target

The default script's first two lines of `SECTIONS` are:

    PROVIDE (__executable_start = SEGMENT_START("text-segment", 0x400000));
    . = SEGMENT_START("text-segment", 0x400000) + SIZEOF_HEADERS;

The name strongly suggests a query to the target emulation, with the literal as
a fallback. Measured, by putting a sentinel in the fallback and reading the
answer back out of the binary:

    build flags          SEGMENT_START("text-segment", ..)
    --------------------  ---------------------------------------
    -fno-pie -no-pie     0xdeadbeef      (the fallback, verbatim)
    -fPIE -pie           0xdeadbeef
    -fno-pie -static     0xdeadbeef

`CONSTANT(MAXPAGESIZE)` in the same probe returned `0x1000`, the real page
size — so the probe mechanism works and the emulation *does* answer questions
it has opinions about. It simply has no opinion about `"text-segment"` on
x86-64 Linux. The name is a hook for targets that genuinely have named
segments; for us the second argument is the answer.

Reading `0x400000` as "the address the text segment starts at" is therefore a
coincidence of the fallback, not a fact about the format.

## Finding 3 — one number moves the whole binary, and the CPU obeys

Replacing the literal in both `SEGMENT_START` calls, nothing else:

    base          first PT_LOAD vaddr   the program
    -------------  --------------------  -----------
    0x400000      0x0000000000400000     ran, exit 0
    0x10000000    0x0000000010000000     ran, exit 0
    0x800000      0x0000000000800000     ran, exit 0

The third is the interesting one: 0x800000 is an unremarkable address that
nothing reserves, and the binary ran there and returned the right answer. So
the number in the script is not documentation the loader may reinterpret — it
is where the CPU jumps on entry.

## Finding 4 — rule order decides placement, and the `.text` order is deliberate

The default script's `.text` rule is, in order:

    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.text.exit .text.exit.*)
    *(.text.startup .text.startup.*)
    *(.text.hot .text.hot.*)
    *(SORT(.text.sorted.*))
    *(.text .stub .text.* .gnu.linkonce.t.*)

With `-ffunction-sections` on a two-function program, the input sections in
object order are `.text`, `.text.cold`, `.text.hot`, `.text.main`, and the
linked function order is **`hot`, `cold`, `main`**. `hot` is pulled to the
front by rule 4, not by anything the compiler did; `cold` and `main` both fall
into the last wildcard and keep **object** order.

So: rule order dominates, and within one wildcard the object's own order
survives. Two different orderings, and the script decides which one applies.

## Finding 5 — first-match-wins, in all four cells

### RETRACTION 2 — "/DISCARD/ beats rule order" was wrong

The first version of this experiment concluded that `/DISCARD/` overrides an
earlier rule regardless of position. It does not. **The experiment was broken,
not the model:** the two Python `.replace()` calls were chained, and in the
file that produced the wrong answer the first one had not applied — so the
"keep rule comes first" variant contained no keep rule at all. A `.replace()`
that matches nothing returns the text unchanged and reports success, so the
bug was invisible.

The corrected version builds all four cells and verifies that each script
really contains the rule it is supposed to:

    cell                                     .mynote kept
    ---------------------------------------  -----------
    A  keep rule only                        1
    B  /DISCARD/ only                        0
    C  keep rule FIRST, then /DISCARD/       1
    D  /DISCARD/ FIRST, then keep rule       0

Plain first-match-wins, with no exception. `/DISCARD/` is not special: in cell
C it is simply the last rule, and in cell D simply the first.

## Finding 6 — `.note.GNU-stack` is consumed before script matching

The default script names it twice: a rule at line 101, and an entry in
`/DISCARD/` at line 273. By Finding 5 the earlier rule should win and the
section should be emitted. It is not:

    .note.GNU-stack as an output SECTION: 0
    PT_GNU_STACK in the output:            1

Removing the `/DISCARD/` entry so the earlier rule cannot possibly be beaten
changes nothing. **The first-match rule is not reached at all**: ld consumes
this section while reading the input, to decide the executable-stack header.

**And the causation is not claimed.** Stripping the section from the input
object with `objcopy --remove-section` still produces `PT_GNU_STACK`:

    input .note.GNU-stack after stripping: 0
    output PT_GNU_STACK anyway:              1

So the section is not the only thing that produces the header. The honest
claim is: consumed, never emitted, and its absence does not remove the header.

## Finding 7 — `MEMORY` is a budget, and overflow is an error

    MEMORY { rom (rx) : ORIGIN = 0x08000000, LENGTH = 1M
             ram (rw) : ORIGIN = 0x20000000, LENGTH = 8M }

With `> rom` / `> ram` on the output sections, `.text` lands at 0x08000000 and
the entry point is the start of `.text`. Non-allocated sections (`.strtab`,
`.symtab`) stay at address 0, because they are in no region.

Shrinking `LENGTH` to 64:

    ld.bfd: tm.out section `.eh_frame' will not fit in region `rom'
    ld.bfd: region `rom' overflowed by 24 bytes

and with `LENGTH = 4M` the same object links. That is the entire value of
`MEMORY`: it turns "these two things overlap" into "this did not link", with a
byte count. Nothing in a plain link would have noticed.

## Finding 8 — `PHDRS` writes the program headers

    PHDRS { code PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
    SECTIONS {
      .text 0x08000000 : { *(.text .text.*) } :code
      .data 0x20000000 : { *(.data .data.*) } :data
    }

produces exactly the two `PT_LOAD`s asked for, at the addresses asked for,
with `R E` and `R W`. `FLAGS(5)` and `FLAGS(6)` are the literal `p_flags` bit
values: `PF_X = 1`, `PF_W = 2`.

## Finding 9 — `-T` suppresses PIE

    flags                      e_type   first LOAD
    -------------------------  -------  --------------------
    -fPIE -pie                 DYN      0x0000000000000000
    -fPIE -pie -T default.ld   EXEC     0x0000000000400000
    -fPIE -T default.ld -pie   EXEC     0x0000000000400000

Command-line order is irrelevant. This is the most surprising property of
`-T` found in this course, and it is the direct cause of Retraction 1: on a
toolchain where PIE is the default, adding `-T` silently changes the output
type. A script that wants a PIE must say so in the script.

## Finding 10 — `--gc-sections` is reachability, rooted at `ENTRY` and `KEEP`

The same source at two optimisation levels, with `--gc-sections` off and on:

    level  flag   .text     surviving lab_* functions
    -----  -----  --------  --------------------------------
    -O1    off    0x138     lab_used lab_dead lab_also_dead
    -O1    on     0x108     (none)
    -O0    off    0x161     lab_used lab_dead lab_also_dead
    -O0    on     0x131     lab_used

At `-O1` the collector removed `lab_used`; at `-O0` it kept it. The only
difference is inlining, and the disassembly shows it directly: `main` at `-O1`
carries `mov $0x2a,%esi` — `lab_used(41)` folded to the constant 42 — so the
out-of-line copy has **no caller**. It is unreachable, not unused.

This is the finding worth the concept: **reachability is a property of the
graph, and the optimiser edits the graph.** A section can be perfectly live and
still be collected, and a section nobody calls can survive.

The root is `ENTRY` from the script (`ENTRY(_start)` at line 8). Moving it:

    -Wl,-e,lab_used   ->   lab_used survives, main is GONE

`KEEP` makes a section a root regardless of reachability. A constructor in
`.init_array` is called by nobody; it survives `--gc-sections` because the
script says `KEEP (*(.init_array EXCLUDE_FILE (...) .ctors))`.

## Finding 11 — the default script orphans five sections, and says nothing

A section the script never mentions is an *orphan*, and GNU ld places it with a
heuristic. By default there is no warning at all — the link succeeds silently.
With `--orphan-handling=warn`, on a trivial `int main(void){return 0;}` plus
one custom section:

    orphan section `.rela.fini_array' from `/lib/x86_64-linux-gnu/Scrt1.o' ...
    orphan section `.rela.init_array' from `/lib/x86_64-linux-gnu/Scrt1.o' ...
    orphan section `.tm_clone_table' from `.../crtbeginS.o' ...
    orphan section `.my_odd_section' from `orph.o' ...
    orphan section `.tm_clone_table' from `.../crtendS.o' ...

**Four of the five come from the C runtime, not from the reader's code.** The
"default" script is not complete; it leans on a fallback algorithm for input it
did not anticipate, and it will not tell you unless asked.

## Finding 12 — `-static`, measured

    binary     size     e_type  PT_INTERP  PT_LOADs  sections
    ---------  -------  ------  ---------  --------  --------
    dynamic    15880    DYN     1          4         30
    static     825160   EXEC    0          4         29

52x, and the extra size is almost entirely `.text` (0x8497d) and `.rodata`
(0x1c57c) — libc, linked in — plus 0x966c of `.eh_frame` that the dynamic
build does not have. The dynamic binary's `.eh_frame` is under 4 KB.

The first `PT_LOAD` is at 0 in the dynamic build and at 0x400000 in the static
one. **That is the script's number from Finding 3**, unchanged: `-static`
changed the `e_type`, and the script followed. Both still have four `PT_LOAD`s,
because `-z separate-code` is on by default and the script's first line says so:
`/* Script for -z combreloc -z separate-code */`.

## Deliberately not claimed

- **A Mach-O or lld equivalent.** `ld --verbose` is a GNU ld feature. lld and
  gold have different scripts and this course does not describe them.
- **Bare-metal or RTOS linker scripts as *written by people*.** The `MEMORY`
  and `PHDRS` experiments here run on a hosted Linux target with a real
  dynamic loader, so they prove the mechanism, not a bootable board. The
  addresses used (`0x08000000`) are realistic and the programs are not run.
- **What `-z noseparate-code` changes.** The script's own first line names
  `-z separate-code`, and the four `PT_LOAD`s follow from it, but the
  comparison against the flag was not run.
- **Any claim about relocation ordering or garbage collection in a PIE.** The
  gc experiments are all `ET_EXEC`; reachability is the same algorithm but the
  root set differs and it was not compared.
