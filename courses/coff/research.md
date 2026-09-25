# Research: COFF — Common Object File Format

Phase A artifact. Every claim below was checked against object files produced
on this machine, decoded by a parser written from the specification
(`coff_parse.py`, shipped alongside these notes) and then required to agree
with `llvm-readobj` field by field (`crosscheck.py`, also shipped).

**Two independently written parsers agreeing is the evidence. Agreeing with
one tool by eye is not.** `crosscheck.py` currently reports
`TWO INDEPENDENT PARSERS AGREE ON EVERY FIELD` across all five shipped samples.

## Toolchain

| Role | Tool | Notes |
|---|---|---|
| Producer | `clang` 21.1.8 | full LLVM toolchain sits beside it on this machine |
| Reference reader | `llvm-readobj` | headers, sections, relocations, symbols |
| Reference reader | `llvm-objdump` | section table, disassembly, `-r` |
| Reference reader | `llvm-objdump`/`obj2yaml` | round-trip inspection |
| Third opinion | `file` (1) | magic-level identification |
| Independent parser | `coff_parse.py` | written from the PE/COFF spec, not from a tool |

```bash
export PATH="$(dirname "$(readlink -f "$(command -v clang)"):$PATH"
```

## Sample corpus

One C file, compiled three ways, plus a C++ file for COMDAT:

```c
/* sample.c */
int add(int a, int b) { return a + b; }

int g_data = 42;
int g_bss;
static int s_data = 7;
const char g_str[] = "coff";
const char *g_ptr = "ptr";
int *g_addr = &g_data;

int table[4] = {1, 2, 3, 4};

int call_through(int (*fn)(int, int), int v) { return fn(v, v); }
int use(void) { return call_through(add, g_data); }
```

```bash
clang --target=x86_64-pc-windows-msvc  -c sample.c -o sample_msvc.obj
clang --target=x86_64-w64-windows-gnu -c sample.c -o sample_gnu.obj
clang --target=i686-pc-windows-msvc     -c sample.c -o sample_m32.obj
clang++ --target=x86_64-pc-windows-msvc -c comdat.cpp -o comdat.obj
```

`file` identifies all four as COFF objects, which is the first independent
confirmation that the target triple produces what we want:

```
sample_msvc.obj: x86-64 COFF object file, not stripped, 9 sections,
                 symbol offset=0x348, 31 symbols, ..., 1st section name ".text"
sample_gnu.obj:  x86-64 COFF object file, not stripped, 8 sections,
                 symbol offset=0x320, 28 symbols
sample_m32.obj:  Intel i386 COFF object file, not stripped, 7 sections,
                 symbol offset=0x254, 27 symbols
comdat.obj:      x86-64 COFF object file, not stripped, 13 sections
```

## Verified: the file header

`sample_msvc.obj`, first 64 bytes:

```
00000000: 6486 0900 2aa5 b66a 4803 0000 1f00 0000  d...*..jH.......
00000010: 0000 0000 2e74 6578 7400 0000 0000 0000  .....text.......
00000020: 0000 0000 6c00 0000 7c01 0000 e801 0000  ....l...|.......
00000030: 0000 0000 0300 0000 2000 5060 2e64 6174  ........ .P`.dat
```

| Offset | Size | Field | Bytes | Value | `llvm-readobj` |
|---|---|---|---|---|---|
| 0x00 | 2 | `Machine` | `64 86` | 0x8664 | `IMAGE_FILE_MACHINE_AMD64 (0x8664)` |
| 0x02 | 2 | `NumberOfSections` | `09 00` | 9 | `SectionCount: 9` |
| 0x04 | 4 | `TimeDateStamp` | `2a a5 b6 6a` | 0x6AB6A52A | matches |
| 0x08 | 4 | `PointerToSymbolTable` | `48 03 00 00` | 0x348 | `PointerToSymbolTable: 0x348` |
| 0x0c | 4 | `NumberOfSymbols` | `1f 00 00 00` | 31 | `SymbolCount: 31` |
| 0x10 | 2 | `SizeOfOptionalHeader` | `00 00` | **0** | `OptionalHeaderSize: 0` |
| 0x12 | 2 | `Characteristics` | `00 00` | 0 | `Characteristics [ (0x0) ]` |

**The 20-byte header ends at 0x14 and the section table begins there** — byte
0x14 is `2e`, the `.` of `.text`, which is the first byte of the first section
header. Confirmed by the `file` output's "1st section name .text".

### The one fact that defines the format

`SizeOfOptionalHeader == 0`. In a PE **image** this field holds 224 (PE32+) or
240 (PE32). In an object it is zero, and that single value is the whole
difference between "a thing the OS can run" and "a thing the linker consumes".

## Verified: section headers

`.text`, at file offset 0x14, 40 bytes:

| Offset | Size | Field | Bytes | Value | `llvm-readobj` |
|---|---|---|---|---|---|
| +0 | 8 | `Name` | `2e 74 65 78 74 00 00 00` | `.text` | `.text (2E 74 65 78 74 00 00 00)` |
| +8 | 4 | `VirtualSize` | `00 00 00 00` | **0** | `VirtualSize: 0x0` |
| +12 | 4 | `VirtualAddress` | `00 00 00 00` | **0** | `VirtualAddress: 0x0` |
| +16 | 4 | `SizeOfRawData` | `6c 00 00 00` | 108 | `RawDataSize: 108` |
| +20 | 4 | `PointerToRawData` | `7c 01 00 00` | 0x17C | `PointerToRawData: 0x17C` |
| +24 | 4 | `PointerToRelocations` | `e8 01 00 00` | 0x1E8 | `PointerToRelocations: 0x1E8` |
| +28 | 4 | `PointerToLinenumbers` | `00 00 00 00` | 0 | `PointerToLinenumbers: 0x0` |
| +32 | 2 | `NumberOfRelocations` | `03 00` | 3 | `RelocationCount: 3` |
| +34 | 2 | `NumberOfLinenumbers` | `00 00` | 0 | `LineNumberCount: 0` |
| +36 | 4 | `Characteristics` | `20 00 50 60` | 0x60500020 | matches |

`VirtualSize` and `VirtualAddress` are **both zero in every section of every
object** checked (9 sections in `sample_msvc.obj`, 13 in `comdat.obj`). Nothing
in a relocatable object has an address, which is the whole point.

### `.bss` has no file bytes at all

| Section | `SizeOfRawData` | `PointerToRawData` |
|---|---|---|
| `.bss` | 4 | **0x0** |

`.bss` reserves four zero bytes that do not exist in the file. The linker
allocates them. This is the cleanest possible demonstration that
`SizeOfRawData` and `VirtualSize` are different questions — and that in an
object, the "how big in memory" answer lives in the symbol table's aux record
instead (see below).

## Verified: section characteristics and the alignment trap

`.text` = 0x60500020. Decomposed:

| Bits | Mask | Meaning |
|---|---|---|
| 0x00000020 | | `IMAGE_SCN_CNT_CODE` |
| 0x00500000 | | alignment field = 5 = `IMAGE_SCN_ALIGN_16BYTES` |
| 0x20000000 | | `IMAGE_SCN_MEM_EXECUTE` |
| 0x40000000 | | `IMAGE_SCN_MEM_READ` |

`llvm-readobj` prints exactly these four names and nothing else.

**The alignment is a 4-bit field in bits 20-23, not a set of independent
flags.** This was found the hard way: a first pass that tested
`0x60500020 & 0x00100000`, `& 0x00200000`, `& 0x00300000` … reported
`ALIGN_1BYTES ALIGN_2BYTES ALIGN_4BYTES ALIGN_8BYTES ALIGN_16BYTES
ALIGN_32BYTES ALIGN_64BYTES` simultaneously, because a value of 5 in a 4-bit
field has bit 0 and bit 2 set. The correct decode is
`ALIGN = (Characteristics >> 20) & 0xF`. A parser that decodes it as flags
reports seven alignments where the file has one. Full table verified across
all sections of all samples:

| Section | `Characteristics` | align | `llvm-readobj` names |
|---|---|---|---|
| `.text` | 0x60500020 | 5 | CNT_CODE, ALIGN_16BYTES, MEM_EXECUTE, MEM_READ |
| `.data` | 0xC0500040 | 5 | CNT_INITIALIZED_DATA, ALIGN_16BYTES, MEM_READ, MEM_WRITE |
| `.bss` | 0xC0300080 | 3 | CNT_UNINITIALIZED_DATA, ALIGN_4BYTES, MEM_READ, MEM_WRITE |
| `.xdata` | 0x40300040 | 3 | CNT_INITIALIZED_DATA, ALIGN_4BYTES, MEM_READ |
| `.rdata` | 0x40100040 | 1 | CNT_INITIALIZED_DATA, ALIGN_1BYTES, MEM_READ |
| `.rdata` (COMDAT) | 0x40101040 | 1 | CNT_INITIALIZED_DATA, **LNK_COMDAT**, ALIGN_1BYTES, MEM_READ |
| `.debug$S` | 0x42300040 | 3 | CNT_INITIALIZED_DATA, ALIGN_4BYTES, **MEM_DISCARDABLE**, MEM_READ |
| `.pdata` | 0x40300040 | 3 | CNT_INITIALIZED_DATA, ALIGN_4BYTES, MEM_READ |
| `.llvm_addrsig` | 0x00100800 | 1 | **LNK_REMOVE**, ALIGN_1BYTES |

## Verified: symbols

18 bytes per entry, `NumberOfSymbols` entries, **aux records count toward that
total** — a symbol with `NumberOfAuxSymbols = 1` occupies 36 bytes.

| Offset | Size | Field |
|---|---|---|
| +0 | 8 | `Name` (inline, or 0 + string-table offset) |
| +8 | 4 | `Value` |
| +12 | 2 | `SectionNumber` (1-based; 0 = undefined; 0xFFFE = absolute) |
| +14 | 2 | `Type` |
| +16 | 1 | `StorageClass` |
| +17 | 1 | `NumberOfAuxSymbols` |

Verified symbol indices, matching `llvm-readobj` exactly:

| Index | Name | Value | Section | StorageClass | Aux |
|---|---|---|---|---|---|
| 0 | `.text` | 0 | 1 | 3 STATIC | 1 |
| 2 | `.data` | 0 | 2 | 3 STATIC | 1 |
| 4 | `.bss` | 0 | 3 | 3 STATIC | 1 |
| 6 | `.xdata` | 0 | 4 | 3 STATIC | 1 |
| 8 | `.rdata` | 0 | 5 | 3 STATIC | 1 |
| 10 | `.rdata` | 0 | 6 | 3 STATIC | 1 |
| 12 | `??_C@_03PLHFFLIH@ptr?$AA@` | 0 | 6 | 2 EXTERNAL | 0 |
| 13 | `.debug$S` | 0 | 7 | 3 STATIC | 1 |
| 15 | `.pdata` | 0 | 8 | 3 STATIC | 1 |

Non-section symbols: `add` (Value 0, section 1, Type 0x0002 = function,
EXTERNAL), `use` (Value 80, section 1), `g_data` (section 2), `table`
(Value 32, section 2), `g_str` (section 5), `g_ptr` (section 6), `g_addr`.

`??_C@_03PLHFFLIH@ptr?$AA@` is the MSVC-mangled name of the `"ptr"` string
literal. It is stored in the string table, not inline, because it does not fit
in eight bytes.

### The aux record field order is not what the specification says

The section-definition aux record, raw bytes for `.text`:

```
6c 00 00 00 | 03 00 00 00 | bc bb d6 09 | 01 00 | 00 | 00 | 00 00
```

Read as the specification orders it — Length, NumberOfRelocations,
NumberOfLinenumbers, CheckSum, Number, Selection — that gives
NumberOfLinenumbers = 0x09D6BBBC = 165,067,708, which is absurd.

Read the way clang actually emits it, and required to match `llvm-readobj`:

| Offset | Size | Field | `.text` value | `llvm-readobj` |
|---|---|---|---|---|
| 0x00 | 4 | `Length` | 108 | `Length: 108` |
| 0x04 | 4 | `NumberOfRelocations` | 3 | `RelocationCount: 3` |
| 0x08 | 4 | `CheckSum` | 0x09D6BBBC | `Checksum: 0x9D6BBBC` |
| 0x0c | 2 | `Number` | 1 | `Number: 1` |
| 0x0e | 1 | `Selection` | 0 | `Selection: 0x0` |
| 0x0f | 1 | reserved | 0 | — |
| 0x10 | 2 | `NumberOfLinenumbers` | 0 | `LineNumberCount: 0` |

**Independent proof of this ordering, not just agreement with a tool:** the
`Number` field at 0x0c must equal the 1-based section index of the symbol that
owns the aux record. It does, for all 58 aux records across the five samples.
`.text` is section 1 and its `Number` is 1; `.data` is section 2 and its
`Number` is 2; `.bss` is 3 and its `Number` is 3. A layout that put
`NumberOfLinenumbers` at 0x08 could not produce that coincidence.

Note what the aux record carries that the section header does not: for `.bss`
the section header says `SizeOfRawData = 4` but `VirtualSize = 0`, while the
aux record says `Length = 4`. **In an object, the aux record's `Length` is
where the section's eventual size in memory is recorded.**

## Verified: relocations

10 bytes per record. The three `.text` records, raw:

```
000001e8: 5600 0000 1700 0000 0400   -> addr 0x56, sym 23, type 4
000001f2: 5d00 0000 1400 0000 0400   -> addr 0x5d, sym 20, type 4
000001fc: 6200 0000 1500 0000 0400   -> addr 0x62, sym 21, type 4
```

| Offset | Size | Field |
|---|---|---|
| 0x00 | 4 | `VirtualAddress` (offset within the section) |
| 0x04 | 4 | `SymbolTableIndex` (low 16 bits used) |
| 0x08 | 2 | `Type` |

`llvm-objdump -r` agrees: `0x56 IMAGE_REL_AMD64_REL32 g_data (23)`,
`0x5d … add (20)`, `0x62 … call_through (21)`. Symbol 23 is `g_data`,
20 is `add`, 21 is `call_through` — cross-referenced against the symbol table
dumped above.

All 14 relocations in `sample_msvc.obj`, cross-checked:

| Section | addr | sym | type | meaning |
|---|---|---|---|---|
| `.text` | 0x56 | 23 | 4 | `IMAGE_REL_AMD64_REL32` → `g_data` |
| `.text` | 0x5d | 20 | 4 | `IMAGE_REL_AMD64_REL32` → `add` |
| `.text` | 0x62 | 21 | 4 | `IMAGE_REL_AMD64_REL32` → `call_through` |
| `.data` | 0x08 | 12 | 1 | `IMAGE_REL_AMD64_ADDR64` → the string literal |
| `.data` | 0x10 | 23 | 1 | `IMAGE_REL_AMD64_ADDR64` → `g_data` |
| `.pdata` ×9 | 0x00…0x20 | 0 / 6 | 3 | `IMAGE_REL_AMD64_ADDR32NB` → `.text` / `.xdata` |

### A second specification-versus-reality discrepancy

The PE/COFF specification documents an **overlapping** x64 relocation layout:
the offset occupies the low 12 bits of the first dword, the type occupies bits
12-15 of that same dword, and the symbol index occupies bits 16-31 of the
second. Under that reading, `56 00 00 00` would be offset 0x56 with type 0.

clang does not emit that. Every object produced here uses the plain
`DWORD / DWORD / WORD` layout, and `llvm-objdump` reads the plain layout. This
was verified by decoding both ways and requiring the type to be non-zero and
to match `llvm-objdump` — the overlapped reading yields `IMAGE_REL_AMD64_ABSOLUTE`
(0) for all fourteen records, which is obviously wrong, while the plain reading
yields 4, 1 and 3 exactly as `llvm-readobj` reports.

**Do not teach the overlapped layout as if it were what compilers emit.** This
is recorded as a discrepancy, not resolved as a claim that the spec is wrong —
some documentation and some linkers do describe the packed form.

## Verified: COMDAT and the C++ case

`comdat.cpp`:

```cpp
struct S { int a, b; };
inline S make(int v) { S s; s.a = v; s.b = v * 2; return s; }
int f() { S s = make(3); return s.a + s.b; }
template<class T> T twice(T v) { return v + v; }
int g() { return twice(21); }
```

Result: **13 sections, with `.text` appearing three times, `.xdata` three
times and `.pdata` three times.** Duplicate section names are legal in COFF,
and are how COMDAT works.

| Section | Name | Characteristics | COMDAT? |
|---|---|---|---|
| 1 | `.text` | 0x60500020 | no |
| 2 | `.data` | 0xC0300040 | no |
| 3 | `.bss` | 0xC0300080 | no |
| 4 | `.xdata` | 0x40300040 | no |
| 5 | `.text` | 0x60501020 | **LNK_COMDAT** |
| 6 | `.text` | 0x60501020 | **LNK_COMDAT** |
| 7 | `.debug$S` | 0x42300040 | no |
| 8 | `.pdata` | 0x40300040 | no |
| 9 | `.llvm_addrsig` | 0x00100800 | no |
| 10 | `.xdata` | 0x40301040 | **LNK_COMDAT** |
| 11 | `.xdata` | 0x40301040 | **LNK_COMDAT** |
| 12 | `.pdata` | 0x40301040 | **LNK_COMDAT** |
| 13 | `.pdata` | 0x40301040 | **LNK_COMDAT** |

The `Selection` byte in the aux record is the linker instruction, and both
values occur naturally:

| Section | `Selection` | `llvm-readobj` name |
|---|---|---|
| `.text` #5 | 2 | `IMAGE_COMDAT_SELECT_ANY` |
| `.text` #6 | 2 | `IMAGE_COMDAT_SELECT_ANY` |
| `.xdata` (paired) | 5 | `IMAGE_COMDAT_SELECT_ASSOCIATIVE` |
| `.pdata` (paired) | 5 | `IMAGE_COMDAT_SELECT_ASSOCIATIVE` |

`ASSOCIATIVE` is how a compiler keeps a `.pdata` entry and its `.xdata` entry
together: they are meaningless apart, so both are discarded if any sibling
disappears. The `CheckSum` field (0xEEE27D3D, 0x63791761, …) is how the linker
decides whether two same-named sections are genuinely the same thing: equal
checksum means identical contents, so one copy is kept.

## Verified: MSVC versus GNU dialect, and i386

Same `sample.c`, three targets. The dialects differ in ways that are easy to
mistake for format differences:

| | `sample_msvc.obj` | `sample_gnu.obj` | `sample_m32.obj` |
|---|---|---|---|
| `Machine` | 0x8664 AMD64 | 0x8664 AMD64 | **0x14C I386** |
| `AddressSize` | 64bit | 64bit | **32bit** |
| Sections | 9 | **8** | 7 |
| `.rdata` count | **2** (one COMDAT) | **1** | 1 |
| Symbol for `g_data` | `g_data` | `g_data` | **`_g_data`** |
| Symbol for `add` | `add` | `add` | **`_add`** |
| Relocation names | `IMAGE_REL_AMD64_REL32` | same | **`IMAGE_REL_I386_DIR32`, `IMAGE_REL_I386_REL32`** |

The leading underscore on i386 is the cdecl symbol decoration, which x64
dropped. The extra COMDAT `.rdata` in the MSVC build is string-literal merging,
which the GNU target did not perform for this file. **The COFF container is
identical in all three; only the dialect content differs.** A reader must key
off `Machine` and the relocation `Type` numbering, not off the dialect.

## bigobj: documented, not reproducible here

`bigobj` replaces the classic 20-byte header when a file would exceed 65,535
sections or 65,535 symbols. Its header is **not** the classic one with wider
fields — the fields **move**:

```
Signature = 0xFFFF        (occupies the classic Machine slot)
Version   = 2             (occupies the classic NumberOfSections slot)
Machine   = 2 bytes       (NEW, at offset 4)
TimeDateStamp = 4
ClassID  = 4   GUID
SizeOfData = 4   Flags = 4   MetaDataSize = 4   MetaDataOffset = 4
NumberOfSections = 4      (32-bit, was 16-bit)
PointerToSymbolTable = 4
NumberOfSymbols = 4
```

**Observed, verified:** patching a real object by setting the first word to
0xFFFF and the second to 2 — which is what the "signature" and "version"
description naively suggests — produces a file that **both `llvm-readobj` and
`file` reject**. That is direct evidence that the rest of the header is
relocated, because a file with a correct signature and version but a
classic-layout remainder is not a valid bigobj.

**Not verified here:** a complete, valid bigobj, because producing one needs
more than 65,535 sections or symbols, which is not practical to generate for
these lessons. The field list above is from the specification and is marked
accordingly. Do not present example bigobj bytes as observed.

## Line numbers: fields verified, contents not produced

COFF has native line-number support: `PointerToLinenumbers` and
`NumberOfLinenumbers` in the section header, and a table of 6-byte records
(4-byte symbol index, 2-byte line number) terminated by a zero entry.

**clang emits none of it.** `LineNumberCount: 0` in every section of every
object produced here; clang emits CodeView data in a `.debug$S` section
instead. MSVC's `cl.exe` populates the native table.

The two fields were verified by construction: a line-number table was appended
to `sample_msvc.obj`, the section-1 header patched to point at it
(`PointerToLinenumbers = 0x5AF`, `NumberOfLinenumbers = 5`), and
`llvm-readobj` read both values back exactly. That is `lineno.obj`, and it is
shipped. It proves the field layout and the offset arithmetic, not the
semantics of the line values.

**Do not teach the meaning of COFF line numbers as source line numbers.** In a
standalone object they are indices whose referent is the linked image's line
table, and that referent does not exist until the link has happened. The
`llvm-objdump -l` output for `lineno.obj` demonstrates the confusion concretely
— it labels the disassembly with invented function names, because the values
have nothing to resolve against. The DWARF course is the reference for
address-to-source mapping.

## What is verified, and what is not

### Verified on this machine

- The 20-byte file header, every field, for 3 machine types
- The 40-byte section header, every field, for every section of every sample
- The characteristics bit decomposition, including the alignment bit-field trap
- The 18-byte symbol record, storage classes, and the aux-record count
- The aux record layout, proven by the `Number == section index` invariant
- The 10-byte relocation record and the AMD64/I386 type numbering
- COMDAT selection values, checksums, and duplicate section names
- Long section names via the `/N` string-table reference (`.llvm_addrsig`)
- The string table location and size, and name resolution from it
- MSVC vs GNU dialect differences and the i386 underscore convention

### Not verified here — do not present as observed

- A complete valid `bigobj` file (field list is from the spec; the naive patch
  is verified to be rejected)
- The semantics of COFF native line numbers (clang emits none)
- The `.lib` archive container format
- The linker map file format
- The short-export format and the full import/export directory of an *image*
  (the PE course already covers those, as image-side content)
- Behaviour of MSVC's `cl.exe` and `link.exe` directly (no MSVC toolchain on
  this machine)

## Verification method

1. Compile one C file at three targets to get three dialects.
2. Compile a C++ file to get COMDAT, duplicate section names, and associative
   selections.
3. Read the file with `llvm-readobj`, `llvm-objdump` and `file` — three
   independent implementations.
4. Decode the same bytes with `coff_parse.py`, written from the specification.
5. Run `crosscheck.py`, which compares the five header fields, every
   relocation's (offset, symbol index), and every aux record's (length,
   relocation count, checksum, section number) between the two parsers.
   **Agreement was required before any claim above was written down.**
6. Where the two disagreed, decode the bytes by hand, identify which reading is
   self-consistent, and record the result as a discrepancy rather than
   silently choosing one.
7. Construct `lineno.obj` to verify the line-number field offsets, and
   construct a bigobj patch to demonstrate that it is rejected.
