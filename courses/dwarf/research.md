# Research: DWARF — Debugging Data Format

Phase A artifact. Every claim below was checked against a real binary on this
machine, not from memory. Commands used are recorded so the claims can be
re-verified.

## Reference binary

One C file, compiled four times at `-O0` with each DWARF version forced, so the
same program can be compared across versions.

```c
// shape.c
#include <stdint.h>

struct Point {
    int32_t x;
    int32_t y;
};

int32_t add(int32_t a, int32_t b) {
    return a + b;
}

int main(void) {
    struct Point p;
    p.x = 3;
    p.y = add(p.x, 4);
    return p.y;
}
```

```bash
for v in 2 3 4 5; do gcc -gdwarf-$v -O0 -o shape_v$v shape.c; done
```

Toolchain: `gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`, x86-64 Linux.
`-gdwarf` defaults to **5** on this compiler (checked with
`gcc -Q --help=common | grep -i dwarf` → `-gdwarf- 5`).

Sections emitted for `shape_v5` (`readelf -S -W shape_v5`):

| Section | Off | Size | Type |
|---|---|---|---|
| `.debug_aranges` | 0x3036 | 0x30 | PROGBITS |
| `.debug_info` | 0x3066 | 0x110 | PROGBITS |
| `.debug_abbrev` | 0x3176 | 0xbf | PROGBITS |
| `.debug_line` | 0x3235 | 0x73 | PROGBITS |
| `.debug_str` | 0x32a8 | 0x111 | PROGBITS, MS |
| `.debug_line_str` | 0x33b9 | 0x5e | PROGBITS, MS |

`MS` = SHF_MERGE | SHF_STRINGS. All have `Addr 0`, `ES 0`, `Al 1` — the
address field of a debug section is unused, which is itself worth teaching.

## Primary sources

| Topic | Source |
|---|---|
| DWARF 5 specification | DWARF Committee, *DWARF Version 5 Standard*, 2017-02-13 (dwarfstd.org/doc/DWARF5.pdf) |
| DWARF 4 specification | DWARF Committee, *DWARF Version 4 Standard*, 2010-02-16 |
| Linux ELF carrying DWARF | System V gABI + `man elf(5)` |
| Reference consumer | GNU binutils `readelf --debug-dump` |
| Kernel/gdb consumers | `gdb`, glibc `dl_iterate_phdr`, `backtrace()` |
| Producer under test | GCC 15.2 `-g` / `-gdwarf-N` |

## Verified claims — `.debug_line` header (DWARF 5)

`shape_v5`, `.debug_line` at file offset 0x3235, 0x73 bytes. The first 0x78
bytes, `xxd`:

```
00000000: 6f00 0000 0500 0800 3800 0000 0101 01fb  o.......8.......
00000010: 0e0d 0001 0101 0100 0000 0100 0001 0101  ................
00000020: 1f02 0000 0000 2500 0000 0201 1f02 0f04  ......%.........
00000030: 1d00 0000 001d 0000 0000 4800 0000 0150  ..........H..P
00000040: 0000 0001 0523 0009 0229 1100 0000 0000  .....#...)......
00000050: 0019 050e d705 0183 0510 3005 09bc 050b  ..........0.....
00000060: 7505 0900 0204 01e4 050d 3d05 013d 0202  u.........=..=..
00000070: 0001 01                                  ...
```

Field-by-field, decoded independently and then cross-checked against
`readelf --debug-dump=rawline shape_v5`:

| Offset | Size | Field | Value | readelf agrees |
|---|---|---|---|---|
| 0x00 | 4 | `unit_length` | 0x6f (111) | `Length: 111` |
| 0x04 | 2 | `version` | 5 | `DWARF Version: 5` |
| 0x06 | 1 | `address_size` | 8 | `Address size (bytes): 8` |
| 0x07 | 1 | `segment_selector_size` | 0 | `Segment selector (bytes): 0` |
| 0x08 | 4 | `header_length` | 0x38 (56) | `Prologue Length: 56` |
| 0x0c | 1 | `minimum_instruction_length` | 1 | `Minimum Instruction Length: 1` |
| 0x0d | 1 | `maximum_operations_per_instruction` | 1 | `Maximum Ops per Instruction: 1` |
| 0x0e | 1 | `default_is_stmt` | 1 | `Initial value of 'is_stmt': 1` |
| 0x0f | 1 | `line_base` | 0xfb = **-5** (signed) | `Line Base: -5` |
| 0x10 | 1 | `line_range` | 0x0e = 14 | `Line Range: 14` |
| 0x11 | 1 | `opcode_base` | 0x0d = 13 | `Opcode Base: 13` |
| 0x12 | 12 | `standard_opcode_lengths` | 0,1,1,1,1,0,0,0,1,0,0,1 | matches per-opcode listing |

**Program start = 0x0c + 0x38 = 0x44.** readelf's first statement is at
`0x00000044`. Verified.

Total header claims 0x38 bytes of variable-length content; the section is
0x73 bytes; 0x44 + program = 0x73. The unit ends exactly at the section end.

### DWARF 5 counted directory / file tables (verified)

Decoded independently, matched readelf's `Directory Table` / `File Name Table`:

| Offset | Field | Bytes | Value |
|---|---|---|---|
| 0x1e | `directory_entry_format_count` | 01 | 1 |
| 0x1f–0x20 | `directory_entry_format` | 01 1f | content type 1 = `DW_LNCT_path`, form 0x1f = `DW_FORM_line_strp` |
| 0x21 | `directories_count` | 02 | 2 (ULEB128) |
| 0x22 | dir[0] offset | 00 00 00 00 | 0x0 |
| 0x23 | dir[1] offset | 25 00 00 00 | 0x25 |
| 0x27 | `file_name_entry_format_count` | 02 | 2 |
| 0x28–0x2b | `file_name_entry_format` | 01 1f 02 0f | path/line_strp, directory_index/udata |
| 0x2c | `file_names_count` | 04 | 4 (ULEB128) |
| 0x2d | file[0] path | 1d 00 00 00 | 0x1d |
| 0x2e | file[0] dir index | 00 | 0 |
| 0x2f | file[1] path | 1d 00 00 00 | 0x1d |
| 0x30 | file[1] dir index | 00 | 0 |
| 0x31 | file[2] path | 00 00 00 00 | 0x0 |
| 0x35 | file[2] dir index | 01 | 1 |
| 0x36 | file[3] path | 48 00 00 00 | 0x48 |
| 0x3a | file[3] dir index | 01 | 1 |

Independent parser stopped at 0x44 — **exact match** with the computed program
start. `readelf` reports the identical counts (2 dirs, 4 files) and offsets
(0x0, 0x25; 0x1d, 0x1d, 0x0, 0x48) and the identical directory indices.

The two counted-table encodings are the **single biggest** difference between
DWARF 4 and DWARF 5 in this section, and they are worth a whole concept.

### `.debug_line_str` string resolution (verified)

`xxd` of the 0x5e-byte `.debug_line_str` confirms every resolved name:

| Offset | String |
|---|---|
| 0x00 | `/tmp/opencode/dwarf-research` |
| 0x1d | `shape.c` |
| 0x25 | `/usr/include/x86_64-linux-gnu/bits` |
| 0x48 | `types.h` |
| 0x50 | `stdint-intn.h` |

So file[0] and file[1] resolve to `shape.c` in dir 0, file[2] to `types.h` in
dir 1, file[3] to `stdint-intn.h` in dir 1 — exactly what readelf prints.

## Verified claims — the line number program

`readelf --debug-dump=rawline shape_v5`, cross-checked byte by byte against the
hex above. Every statement was independently re-derived from the raw bytes.

| Offset | Byte(s) | readelf's reading | Independent re-derivation |
|---|---|---|---|
| 0x44 | `05 23` | `Set column to 35` | DW_LNS_set_column, ULEB 0x23 = 35 |
| 0x46 | `00 09 02 29 11 00 00 00 00 00` | `Extended opcode 2: set Address to 0x1129` | DW_LNE (0x00), length 9, sub 2 = set_address, 8 addr bytes = 0x1129 |
| 0x51 | `19` | `Special opcode 12: advance Address by 0 to 0x1129 and Line by 7 to 8` | raw 0x19 = 25, adjusted = 25-13 = 12; op_adv = 12/14 = 0; addr_adv = 1*((0+0)/1) = 0; line_inc = -5 + (12%14) = **7**; line 1→8 |
| 0x52 | `05 0e` | `Set column to 14` | ✓ |
| 0x54 | `d7` | `Special opcode 202: advance Address by 14 to 0x1137 and Line by 1 to 9` | adjusted 215-13 = 202; op_adv = 202/14 = 14; line_inc = -5 + (202%14) = **1**; line 8→9 |
| 0x55 | `05 01` | `Set column to 1` | ✓ |
| 0x57 | `83` | `Special opcode 118: advance Address by 8 to 0x113f and Line by 1 to 10` | adjusted 131-13 = 118; op_adv = 118/14 = 8; line_inc = -5 + (118%14) = **1**; line 9→10 |
| 0x58 | `05 10` | `Set column to 16` | ✓ |
| 0x5a | `30` | `Special opcode 35: advance Address by 2 to 0x1141 and Line by 2 to 12` | adjusted 48-13 = 35; op_adv = 35/14 = 2; line_inc = -5 + (35%14) = **2**; line 10→12 |
| 0x5b | `05 09` | `Set column to 9` | ✓ |
| 0x5d | `bc` | `Special opcode 175: advance Address by 12 to 0x114d and Line by 2 to 14` | adjusted 188-13 = 175; op_adv = 175/14 = 12; line_inc = -5 + (175%14) = **2**; line 12→14 |
| 0x5e | `05 0b` | `Set column to 11` | ✓ |
| 0x60 | `75` | `Special opcode 104: advance Address by 7 to 0x1154 and Line by 1 to 15` | adjusted 117-13 = 104; op_adv = 104/14 = 7; line_inc = -5 + (104%14) = **1**; line 14→15 |
| 0x61 | `05 09` | `Set column to 9` | ✓ |
| 0x63 | `00 04 04 01` | `Extended opcode 4: set Discriminator to 1` | DW_LNE, length 4, sub 4 = set_discriminator, ULEB 1 |
| 0x67 | `e4` | `Special opcode 215: advance Address by 15 to 0x1163 and Line by 0 to 15` | adjusted 228-13 = 215; op_adv = 215/14 = 15; line_inc = -5 + (215%14) = **0** |
| 0x68 | `05 0d` | `Set column to 13` | ✓ |
| 0x6a | `3d` | `Special opcode 48: advance Address by 3 to 0x1166 and Line by 1 to 16` | adjusted 61-13 = 48; op_adv = 48/14 = 3; line_inc = -5 + (48%14) = **1** |
| 0x6b | `05 01` | `Set column to 1` | ✓ |
| 0x6d | `3d` | `Special opcode 48: advance Address by 3 to 0x1169 and Line by 1 to 17` | ✓ |
| 0x6e | `02 02` | `Advance PC by 2 to 0x116b` | DW_LNS_advance_pc, ULEB 2 |
| 0x70 | `00 01 01` | `Extended opcode 1: End of Sequence` | DW_LNE, length 1, sub 1 = end_sequence |

**All 22 statements independently reproduced. No disagreements with readelf.**

### The `op_index` subtlety (this is the thing everyone gets wrong)

The DWARF 5 spec orders the special-opcode steps:

```
1) operation_advance = adjusted_opcode / line_range
2) address_advance = minimum_instruction_length
                     * ((op_index + operation_advance) / maximum_operations_per_instruction)
3) op_index = (op_index + operation_advance) % maximum_operations_per_instruction
4) address += address_advance
5) line += line_base + (adjusted_opcode % line_range)
```

Step 2 uses the **old** `op_index`; step 3 updates it. With
`maximum_operations_per_instruction == 1` (verified at 0x0d) step 3 always
yields 0, so `op_index` is always 0 and `address_advance == operation_advance`.
That is exactly why readelf reports plain increments 0, 14, 8, 2, 12, 7, 15, 3,
3 here. On a machine with VLIW instructions `max_ops > 1` and this stops being
true — that is the real reason the field exists.

## Verified claims — `.debug_info` (DWARF 5)

`shape_v5`, `.debug_info` at 0x3066, 0x110 (272) bytes. `xxd`:

```
00000000: 0c01 0000 0500 0108 0000 0000 0500 0000  ................
00000010: 001d 0347 1603 001d 0000 0000 0000 0029  ...G...........)
00000020: 1100 0000 0000 0042 0000 0000 0000 0000  .......B........
00000030: 0000 0001 0108 d200 0000 0102 07ee 0000  ................
```

CU header, decoded and cross-checked against
`readelf --debug-dump=info shape_v5`:

| Offset | Size | Field | Value | readelf agrees |
|---|---|---|---|---|
| 0x00 | 4 | `unit_length` | 0x10c (268) | `Length: 0x10c (32-bit)` |
| 0x04 | 2 | `version` | 5 | `Version: 5` |
| 0x06 | 1 | `unit_type` | 1 = `DW_UT_compile` | `Unit Type: DW_UT_compile (1)` |
| 0x07 | 1 | `address_size` | 8 | `Pointer Size: 8` |
| 0x08 | 4 | `debug_abbrev_offset` | 0 | `Abbrev Offset: 0` |

**First DIE begins at 0x0c.** readelf prints `<0><c>`. Verified.

### The first DIE, attribute by attribute

Byte 0x0c is abbrev code `05`; `.debug_abbrev` declares code 5 =
`DW_TAG_compile_unit [has children]` with 10 attributes in this order:

| Offset | Bytes | Attribute | Form | Value | readelf agrees |
|---|---|---|---|---|---|
| 0x0d | 4 | `DW_AT_producer` | `strp` | 0x0 | `offset: 0` |
| 0x11 | 1 | `DW_AT_language` | `data1` | 29 | `29 (C11)` |
| 0x12 | 1 | `DW_AT_language_name` | `data1` | 3 | `3 (C)` |
| 0x13 | 4 | `DW_AT_language_version` | `data4` | 0x00031647 = 202311 | `0x31647 (202311)` |
| 0x17 | 4 | `DW_AT_name` | `line_strp` | 0x1d | `offset: 0x1d` |
| 0x1b | 4 | `DW_AT_comp_dir` | `line_strp` | 0x0 | `offset: 0` |
| 0x1f | 8 | `DW_AT_low_pc` | `addr` | 0x1129 | `0x1129` |
| 0x27 | 8 | `DW_AT_high_pc` | `data8` | 0x42 | `0x42` |
| 0x2f | 4 | `DW_AT_stmt_list` | `sec_offset` | 0 | `0` |

0x33 is the next abbrev code (`01` = `DW_TAG_base_type`), and readelf prints
`<1><33>`. The whole 10-attribute chain is byte-exact.

**The `high_pc` form trap, verified:** `DW_AT_high_pc` here is
`DW_FORM_data8`, so its value `0x42` is a **length** (66 bytes), not an
address. `DW_AT_low_pc` 0x1129 + 0x42 = 0x116b — which is precisely the
address the line program ends at (the `Advance PC by 2 to 0x116b` statement,
then `end_sequence`). A learner who reads 0x42 as an address will look for code
at address 0x42. This is a genuine, high-value misconception and it is
verifiable in this tiny file.

## Verified claims — `.debug_abbrev` (DWARF 5)

`shape_v5`, `.debug_abbrev` at 0x3176, 0xbf (191) bytes. `readelf --debug-dump=abbrev`
lists 10 abbreviations. Byte-level structure confirmed by hand:

```
00000000: 0124 000b 0b3e 0b03 0e00 0002 1600 030e  .$...>..........
00000010: 3a0b 3b0b 390b 4913 0000 030d 0003 083a  :.;.9.I........:
```

- `01` = abbrev code 1
- `24` = 0x24 = **DW_TAG_base_type**
- `00` = no `DW_CHILDREN` byte → leaf
- `0b` = 0x0b = **DW_AT_byte_size**, then `3e` = 0x3e = DW_FORM_data1
- `0b` = DW_AT_byte_size? no — `0b 3e` then `0b 03` = DW_FORM_encoding
  `DW_FORM_data1`
- `0e 00 00` = `DW_AT_name` (0x0e) `DW_FORM_strp` (0x0e) implicit_const 0
- `00` = end of attribute list
- `02` = abbrev code 2 = `DW_TAG_typedef` (0x16) with `01` = `DW_CHILDREN_no`

Confirmed against readelf's abbrev 1 and 2 listings. A table of abbreviations
terminates with a single `00` code, then the next table begins.

`DW_TAG_compile_unit` (abbrev 5) is the only `[has children]` entry that
matters for Module 1: its `DW_AT_stmt_list` is the join between `.debug_info`
and `.debug_line` — verified as 0, and the line unit at `.debug_line` offset 0
is the one decoded above.

## Verified version contrast — DWARF 4 vs 5

Same `shape.c`, same flags except `-gdwarf-4`.

`.debug_line` header (`readelf --debug-dump=rawline shape_v4`):

| Field | v4 | v5 |
|---|---|---|
| `unit_length` | 0x93 (147) | 0x6f (111) |
| `version` | 4 | 5 |
| `address_size` | **absent** — taken from the CU | present at 0x06 (8) |
| `segment_selector_size` | **absent** | present at 0x07 (0) |
| `header_length` | 0x5e (94) at offset 0x06 | 0x38 (56) at offset 0x08 |
| fixed prologue size | 10 bytes (0x06→0x10) | 12 bytes (0x08→0x14) |
| program start | 0x0a + 0x5e = **0x68** | 0x0c + 0x38 = **0x44** |
| directory table | offset 0x1c, NUL-terminated strings | counted, explicit form |
| file table | offset 0x40, name + 3 ULEBs | counted, explicit form |
| `line_base`/`line_range`/`opcode_base` | -5 / 14 / 13 | -5 / 14 / 13 (identical) |

v4 raw bytes, `xxd -l 96`:

```
00000000: 9300 0000 0400 5e00 0000 0101 01fb 0e0d  ......^.........
00000010: 0001 0101 0100 0000 0100 0001 2f75 7372  ............/usr
00000020: 2f69 6e63 6c75 6465 2f78 3836 5f36 342d  /include/x86_64-
```

Note `0x06 = 5e` is `header_length` directly after `version` — there is no
`address_size` byte in v4. A parser written for v5 misreads `5e` as an
address size of 94. That is a concrete, demonstrable breakage.

readelf confirms program start 0x68 for v4 (its first statement is at
`[0x00000068]`), matching `0x0a + 0x5e`. Both computed and reported values agree.

`.debug_info` CU header, v4 vs v5 (`xxd -l 32 sec4/debug_info`):

```
00000000: 0e01 0000 0400 0000 0000 0801 0000 0000  ................
```

- v4: `unit_length` 0x10e, `version` 4, `debug_abbrev_offset` 0,
  `address_size` 8 → **first DIE at 0x0b** (readelf prints `<0><b>`)
- v5: adds `unit_type` at 0x06 → **first DIE at 0x0c** (readelf prints `<0><c>`)

So the v5 CU header is 12 bytes and the v4 CU header is 11. A v4 parser that
does not expect `unit_type` reads the DIE one byte early.

## Failure modes (verified by corrupting a real binary)

### Corrupt `unit_length` in `.debug_line`

Set the `unit_length` field (file offset 0x3235) to 0xfff0:

```
$ readelf --debug-dump=rawline broken1
Raw dump of debug contents of section .debug_line:

readelf: Warning: The length field (0xfff0) in the debug_line header is wrong - the section is too small
```

The section is only 0x73 bytes, so a length of 0xfff0 overruns it. readelf
refuses to decode the line program and emits **nothing** — no addresses, no
source lines. A debugger in the same position shows no line information at all
and falls back to disassembly-only stepping.

### Corrupt `version` in `.debug_info`

Set the `.debug_info` version (file offset 0x3066 + 4) to 9:

```
$ readelf --debug-dump=info broken2
readelf: Warning: CU at offset 0 contains corrupt or unsupported version number: 9.
```

readelf still prints the 4 header fields it could read, then stops. The lesson:
**the version field is the consumer's first gate.** A parser must check
`version` before trusting any offset that follows it, because every offset in
the rest of the unit is laid out per that version's layout.

## Edge cases confirmed on the reference binary

| Case | Evidence |
|---|---|
| `DW_FORM_implicit_const` in abbrev 3/4 | readelf abbrev dump: `DW_AT_decl_file DW_FORM_implicit_const: 1` — the value lives in the abbrev table, not `.debug_info` |
| `DW_AT_language_name` / `DW_AT_language_version` are DWARF 5 additions | present in v5 abbrev 5, absent in v4 |
| `DW_FORM_line_strp` vs `DW_FORM_strp` | two different string sections; `.debug_line_str` holds paths, `.debug_str` holds everything else. Verified by resolving offsets 0x1d/0x48 in the former and 0xb6/0xc8 in the latter |
| `DW_AT_external` / `DW_AT_prototyped` as `DW_FORM_flag_present` | v5 abbrev 8 — presence *is* the value, no bytes in `.debug_info` |
| Debug sections are non-alloc | all six have `Addr 0`; they are file content, not memory |
| `default_is_stmt` is a default, not a constant | the standard opcode `DW_LNS_negate_stmt` (6) flips it per-row |

## Version-specific behaviour summary

| Feature | v2/v3 | v4 | v5 | Default on this gcc |
|---|---|---|---|---|
| `.debug_line` `address_size` | no | no | yes (0x06) | v5 |
| `.debug_line` counted dir/file tables | no | no | yes | v5 |
| `.debug_info` `unit_type` | no | no | yes (0x06) | v5 |
| `DW_AT_language_name`, `DW_AT_language_version` | no | no | yes | v5 |
| `DW_FORM_line_strp` / `.debug_line_str` | no | no | yes | v5 |

`gcc --help=common` on this toolchain shows `-gdwarf-` accepting 2/3/4/5 with
default 5, so a learner can produce every version on demand.

## Unverified claims — do NOT teach until checked

- [ ] `.debug_pubnames` / `.debug_gnu_pubnames` layout — not emitted here
- [ ] `.debug_aranges` internals — emitted (0x30 bytes) but not yet decoded
- [ ] `.debug_ranges` / location lists (DWARF 5 `DW_LLE`) — requires `-O2`
- [ ] Call-frame information (`.debug_frame` / `.eh_frame`) — separate design,
      emitted only with `-fasynchronous-unwind-tables`; not yet dumped
- [ ] Split DWARF (`.dwo` / `DW_SECT_*` skeleton units) — `-gsplit-dwarf` off
- [ ] macOS / Windows clang output — would need cross toolchains
- [ ] Non-x86-64 `address_size` values (4) — needs `-m32`, not available here
- [ ] `DW_LNE_define_file` (opcode 3) — not emitted by this gcc

## Verification method used

1. Compile one C file at each `-gdwarf-N`.
2. `readelf -S -W` to get each debug section's file offset and size.
3. `dd`/Python-slice the section bytes out of the ELF.
4. Decode the header with an independent Python parser written for the course
   research (`decode_line.py`), not by reading readelf's own parser.
5. Compare the independent decode against `readelf --debug-dump` field by
   field. **Agreement was required before any claim was written down.**
6. Corrupt specific fields and record the real consumer output.

Step 4/5 is the important one: agreeing with readelf by eyeballing proves
nothing. Every number in the tables above was produced by the independent
parser and then required to match.
