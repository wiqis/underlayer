# WebAssembly Course — Research Record

The authority for what this course teaches and, more importantly, for what it
does not. Every claim in `content/src/wasm_*.ch` came from a file on disk that
three independent readers agreed about.

## The toolchain, and why this course has an unusually good position

Checked before any content was written, which turned out to matter more here
than in the previous two courses.

| Tool | Present | Role |
|---|---|---|
| `wat2wasm`, `wasm2wat` | yes, wabt 1.0.36 | text to binary and back |
| `wasm-objdump` | yes | the reference section and disassembly reader |
| `wasm-validate` | yes | a validator, which is a different kind of reader |
| `wasm2c` | yes | binary to C, useful for reading a module as source |
| `wast2json` | yes | spec-test harness driver |
| `llvm-objdump`, `llvm-readobj`, `llvm-nm` | yes, LLVM 21 | a second, independent implementation |
| `clang --target=wasm32` | yes | a producer: real modules from real C |

**Three independent readers**, the same standard the DWARF course meets, and a
fourth participant (`wasm-validate`) that answers a different question. No
COFF linker equivalent is needed, because the compiled output of one C file is
already a module.

The absence of `wasm-ld` and `lld` is noted, and it matters for Module 5:
`clang --target=wasm32 -c` produces a relocatable object with `linking`,
`reloc.*` and `target_features` custom sections, but there is no linker on this
machine to link it. The object format can be read; the linking behaviour cannot
be observed.

## The shipped harness

- `assets/samples/wasm_decode.py` — a decoder written from the specification.
  Deliberately not a validator, and the docstring says why that distinction is a
  teaching point rather than an omission.
- `assets/samples/crosscheck.py` — compares every section of every sample across
  the three readers and requires agreement.

```
$ python3 crosscheck.py
ok    externs.o                10 sections, three readers agree
ok    handwritten.wasm          9 sections, three readers agree
ok    long_custom.wasm         10 sections, three readers agree
ok    minimal.wasm              0 sections, three readers agree
ok    simple.o                  7 sections, three readers agree
CROSS-CHECK PASSED -- all three readers agree on every section
```

**The harness is itself tested.** Three injected faults, three detections: a
section size byte changed, two section ids swapped, one magic byte changed. A
green result from a checker that cannot fail is not evidence, and this one
demonstrably can fail.

Two bugs in the harness were found and fixed while writing it, both worth
recording because they are the errors a reader of this format makes first:

1. **Comparing the id offset against wabt's `start=`.** wabt prints the
   *payload* offset; the id and size bytes precede it. Comparing against the id
   byte is an off-by-two that looks like a tool disagreement on every section of
   every file. Fixed to compare the payload offset.
2. **Custom section names.** wabt prints them in double quotes after the size;
   llvm lower-cases them; my decoder reported the id name (`custom`). Fixed on
   all three sides.

## Findings

### 1. The two tools report different sizes for the same custom section

Verified on four custom sections across two files.

| custom section | declared | wabt | llvm | name bytes | payload after name |
|---|---|---|---|---|---|
| `linking` | 32 | `0x20` | `0x18` | 8 | 24 |
| `producers` | 56 | `0x38` | `0x2e` | 10 | 46 |
| `target_features` | 148 | `0x94` | `0x84` | 16 | 132 |
| `reloc.CODE` | 17 | `0x11` | — | 11 | 6 |

Neither is wrong. **wabt reports the declared size** (what is in the length
field, name included); **llvm reports the payload after the name** (what a
consumer of the contents wants). For standard sections the two definitions
coincide, because standard sections have no name — and on every standard section
the tools agree exactly.

The trap: the difference is `1 + name length`, which varies per section. A
reader using the wrong number stops that far early, inside the section, and the
bytes it finds there are the next section's identifier and length — small valid
numbers. The result is a plausible section that does not exist, and every row
after it is wrong. The error is constant within a section and different between
sections.

### 2. `wasm-objdump` prints `i32.const` and `i64.const` operands as unsigned

Four real immediates from `neg.wasm`:

| source | bytes | signed LEB128 | unsigned LEB128 | widened unsigned |
|---|---|---|---|---|
| `i32.const -1` | `7f` | **-1** | 127 | 4294967295 |
| `i32.const 1000000` | `c0 84 3d` | **1000000** | 1000000 | 1000000 |
| `i32.const -1000000` | `c0 fb 42` | **-1000000** | 1097152 | 4293967296 |
| `i64.const -1` | `7f` | **-1** | 127 | 18446744073709551615 |

`wasm-objdump -d` prints exactly the last column, all four. The encoding *is*
signed LEB128 — the signed column recovers the source constants exactly — so this
is a presentation choice, not a decoding error. But a reader who takes the
disassembler's number as the constant is wrong on precisely the values real code
uses most.

### 3. The ordering rule, and three behaviours on a violation

Duplicating the Type section and appending the copy:

```
$ wasm-validate dup.wasm
  0000063: error: multiple Type sections
$ llvm-objdump -h dup.wasm
llvm-objdump: error: 'dup.wasm': out of order section type: 1
$ wasm-objdump -h dup.wasm
  ...prints a section table, no complaint...
```

A validator naming the rule, a reader expressing it as a consequence, and a
printer doing its job. Taught as the difference between "is this usable", "can I
make sense of this" and "what is in this".

### 4. Custom section contents are not validated

A hand-built custom section with a raw name and no length prefix — malformed by
the convention the `linking` and `name` sections use — passes
`wasm-validate`, and `wasm-objdump` prints a name that has lost its first
character because it consumed the first name byte as a length.

Found by accident while building a multi-byte-LEB test and written up because it
is a clean demonstration: the format promises not to interpret custom section
contents, so there is nothing for a validator to check. The corrected file, with
a proper name length, validates and prints correctly.

### 5. The version field is a number, not a pattern

`01 00 00 00` is the number 1 in four-byte little-endian, not the byte sequence.
The distinction is invisible today and decisive later: a future version 256
encodes as `00 01 00 00`, which no pattern-matching reader has ever seen and any
numeric reader can compare against a supported set. Not independently tested
here — no second version exists to test against — so it is taught from the
specification with that limit stated.

## Findings, Modules 2 to 5

Recorded as observed. Each was produced by running a tool, not by reading the
specification and reasoning about it.

6. **Imports are counted first, in five independent index spaces.** A module
   importing one function, one table and one global and defining two functions,
   one table, one memory and two globals has `func[0]` and `table[0]` and
   `global[0]` as the imports, and the definitions at 1 and 2. Memories had no
   imports, so `memory[0]` is a definition. Verified against
   `wasm-objdump -x`, which prints the same global numbering the decoder had to
   be taught to produce.
7. **The limits flag byte is a length, not a tag.** `0x00` means one count
   follows; `0x01` means two. Reading a maximum unconditionally consumes the
   *next* section's first byte and desynchronises silently. Bit 1 is `shared`,
   bit 2 is `memory64`, and both were added to a byte that originally had one
   meaning.
8. **Adjacent local declarations of the same type are merged into one
   run-length group.** `(local i32) (local i32) (local i64) (local f32)
   (local i32 i32 i32)` is four groups and seven locals, not six groups. The
   groups are *not* reordered to compress better, because group order is local
   numbering. Verified by decoding `body.wasm` and counting.
9. **`call_indirect` has two immediates.** Type index then table index. The
   table index was appended by the reference-types proposal, so a reader written
   against the 2017 specification reads one LEB and decodes the table index as
   the next opcode. `memory.size` and `memory.grow` likewise carry a memory
   index that is always zero today.
10. **The `align` immediate on a load is a base-2 logarithm.** `i32.load` with
    `align 2` means four bytes. Confirmed on four real load instructions.
11. **A block type is overloaded and disambiguated by a one-byte peek.** `0x40`
    is the empty type; a single valtype byte is a single result; anything else
    is a signed LEB128 type index. Reading `0x40` as a LEB gives 64, which is a
    type index a small module does not have.
12. **The element section has eight segment forms, and wabt's writer only
    emits four of them.** Forms 0 to 3 (the function-index family) are produced
    by `wat2wasm`; forms 4 to 7 (the expression family) are not — writing
    `(elem (i32.const 0) (ref.func $f0))` produces `flags=0`, not `flags=4`. All
    eight were therefore verified by hand-assembling the bytes and confirming
    `wasm-validate` accepts them and `wasm-objdump -x` reads them back with the
    expected `flags=` value.
13. **The elemkind byte's only legal value is `0x00`, and it is not a
    valtype.** In forms 1, 2 and 3 an elemkind byte precedes the element count;
    `0x00` abbreviates `funcref`, whose valtype encoding is `0x70`, used in
    forms 5 to 7. A reader expecting `0x70` reads the count from the wrong byte.
    The type byte appears only where the table section cannot supply the
    information, which is exactly the passive and declarative modes.
14. **The data section has three forms and no expression form**, and its payload
    is a counted blob of raw bytes rather than a sequence of records. All three
    verified by hand-assembly, after the validator rejected a first attempt for
    placing the code section after the data section.
15. **Every section size in a real LLVM object is a five-byte LEB128.**
    `85 80 80 80 00` is the value 5. Confirmed across all eight sections of
    `externs.o`, and again at the inner level for a `linking` subsection size.
    A decoder assuming minimal encodings — which is what every hand-built
    sample in this course is — misaligns on the first section of every real
    object. This is the single most practically important finding in the course.
16. **A `linking` symbol record's field order for a data symbol was not
    reconciled.** The section framing, the five-byte padding at both levels, the
    version, the subsection `(id, size, payload)` structure, subsection id 8 as
    the symbol table, the first symbol's complete layout and the relocation
    record are all verified. The second symbol leaves two bytes unaccounted for,
    and the observable symptom is that the subsection walk then reports ids
    2, 4 and 3 where the bytes plainly say 5. Recorded as
    encountered-not-decoded; the concept shows the symptom rather than guessing.

## Samples, and what each is for

19 files, all read by the three-reader harness.

| File | Bytes | Produced by | Teaches |
|---|---|---|---|
| `minimal.wat` / `.wasm` | 8 | `printf '(module)'` + `wat2wasm` | the header alone |
| `handwritten.wat` / `.wasm` | 97 | `wat2wasm`, nine sections | the framing with every standard section kind present |
| `long_custom.wasm` | 344 | hand-built | a two-byte LEB128 size and a 43-character custom name |
| `neg.wat` / `.wasm` | 96 | `wat2wasm` | signed LEB128 operands, and finding 2 |
| `decls.wat` / `.wasm` | 132 | `wat2wasm` | three imports of three kinds, limits with a max, a mutable global |
| `globs.wat` / `.wasm` | 70 | `wat2wasm` | eight globals spanning the full signed range of `i32` and `i64` |
| `body.wat` / `.wasm` | 114 | `wat2wasm` | local declaration grouping, two data forms, two element forms |
| `ops.wat` / `.wasm` | 156 | `wat2wasm` | 40 instructions with their byte encodings, block types, `memarg` |
| `elems.wat` / `.wasm` | 84 | `wat2wasm` | five of the eight element forms in one section |
| `form4.wasm` … `form7.wasm` | 43-50 | hand-built | the four expression element forms no tool will emit |
| `data0.wasm` … `data2.wasm` | 38-42 | hand-built | the three data forms |
| `simple.c` / `.o` | 79 / 342 | `clang --target=wasm32 -O2 -c` | a real object: `linking`, `producers`, `target_features` |
| `sym.c` / `.o` | 24 / 452 | `clang --target=wasm32 -O0 -c` | a symbol table with an undefined global and a defined data symbol |
| `externs.c` / `.o` | 126 / 393 | `clang --target=wasm32 -O2 -c` | the same plus a `reloc.CODE` section |

`wasm_decode.py` is the specification-derived decoder and `crosscheck.py` is
the three-reader harness. Both are shipped with the course and both are
exercised by the exercises in the concepts.

## The harness, and what it does and does not check

The harness compares three independent readers on every sample. It was extended
during this work from a framing-only comparison to three levels, and each level
was confirmed to fail when it should:

- **Structure** — section count, ids, declared sizes and payload offsets.
- **Counts** — the number of entries of each kind in each section.
- **Values** — decoded global initialisers against wabt.

Two findings came from testing the harness rather than trusting it:

- **A count-only check does not catch a wrong value.** Established by
  deliberately breaking the decoder's `i32.const` path to read unsigned; the
  sabotage went undetected because no sample then had a *negative* `i32`
  initialiser, so signed and unsigned agreed. `globs.wasm` was added to close
  the gap, and the sabotage is now caught.
- **The value check initially got the index base wrong** — wabt numbers globals
  in the global index space, so a module with one imported global has its first
  defined global at index 1. The checker tripped over the same rule the
  `wasm-imports` concept teaches, which is the clearest available evidence that
  the rule is real and easy to get wrong.

## Not written, and why

- **The object linking format's output side.** `linking` and `reloc.*` decode
  and `clang --target=wasm32` produces them, but there is no `wasm-ld` or
  `lld` on this machine, so what a linker *does* with them cannot be observed.
  Module 5 teaches the sections and states the limit explicitly, with an
  exercise that closes the gap for anyone who has a linker.
- **The data symbol record layout in the `linking` section.** See finding 16.
  Attempted from one sample and cross-checked against a second; the field order
  could not be made to account for all fifteen bytes.
- **The text format.** A separate course per the roadmap, not started.
- **SIMD, threads, and the 64-bit memory flag.** Present in the encoding and
  usable with `wat2wasm` for SIMD, but no sample in this course uses one, so
  nothing about them is claimed beyond the flag bit and the value type byte.
