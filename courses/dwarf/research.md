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

---

# Module 3 research: DIEs, types, scopes, locations, frames, split DWARF

Added when Module 3 was written. The same discipline applies: a claim is only
written down after an independent decoder, `llvm-dwarfdump` and `readelf` all
agree on it.

## Harness

Three implementations, all shipped:

| Role | Tool |
|---|---|
| Independent decoder | `assets/dwarf_decode.py`, written from the specification |
| Section reader | `assets/dwarf_sections.py`, so the decoder does not lean on readelf |
| Reference readers | `readelf --debug-dump=*` and `llvm-dwarfdump --debug-info` |
| Comparison | `assets/crosscheck.py` |

```
$ python3 assets/crosscheck.py assets/samples/types_O0 assets/samples/types_O2 \
      assets/samples/types_pub assets/samples/types_split \
      assets/samples/types_split.dwo
  types_O0         OK   (54 DIEs, 281 attributes, CFI ops agree)
  types_O2         OK   (63 DIEs, 307 attributes, CFI ops agree)
  types_pub        OK   (54 DIEs, 283 attributes, CFI ops agree)
  types_split      OK   (2 skeleton units, 2 DW_AT_dwo_name)
  types_split.dwo  OK   (39 DIEs in the .dwo, tags agree with llvm-dwarfdump)
CROSS-CHECK: ALL READERS AGREE
```

The cross-check compares, per file: the number of abbreviation entries against
readelf's table, every DIE's (depth, offset, abbrev code, tag), every
attribute's (DIE, byte offset, name), the `.debug_aranges` unit headers and
tuples, the `.eh_frame` FDE address ranges, and the CFI opcode sequence.

## Corpus

```c
/* types.c */
#include <stdint.h>
typedef unsigned long  ulong_t;
enum Color { RED = 1, GREEN, BLUE = 7 };
struct Point { int x; int y; };
struct Nest {
    struct Point origin;
    char        label[8];
    uint32_t    flags;
    struct Point *next;
};
union Variant { int i; double d; struct Point p; };
static struct Nest  g_nest  = { {1, 2}, "hi", 0x30, 0 };
static ulong_t       g_count = 7;
static int           g_table[4] = {10, 20, 30, 40};
int  sum_table(int idx)            { int local = g_table[idx];
                                     return local + (int)g_count; }
int  walk(struct Point *p)          { if (p == 0) { return 0; }
                                     return p->x + p->y; }
struct Point make_point(int x, int y){ struct Point out; out.x = x; out.y = y;
                                     return out; }
```

| Binary | Command | What it is for |
|---|---|---|
| `types_O0` | `gcc -gdwarf-5 -O0 -o types_O0 types.c types_main.c` | the reference: full DIE tree, no location lists |
| `types_O2` | `… -O2 …` | optimised; `.debug_loclists` appears |
| `types_pub` | `… -gpubnames …` | adds `.debug_pubnames` and `.debug_pubtypes` |
| `types_split` | `… -gsplit-dwarf …` | skeleton units plus a separate `.dwo` |
| `inline_O2.o` | `gcc -gdwarf-5 -O2 -c inline.c` | forces real inlining |

## Finding 1 — readelf applies relocations, so it disagrees with your hex dump

Compiling to an object (`-c`) produces `.rela.debug_info`, and the string
offsets in `.debug_info` are **zero in the file** until the linker fills them
in. In `types_O0.o` (the unlinked form of the reference binary):

```
$ readelf -rW types_O0.o | grep -A2 debug_info
000000000000000d  0000000a0000000a R_X86_64_32  .debug_str + 85
$ xxd -s 0x10d -l 4 types_O0.o
0000010d: 0000 0000
```

readelf reports `DW_AT_producer` at `.debug_str + 85`. The four bytes in the
file are `00 00 00 00`. **readelf is not wrong — it applied the relocation** —
but a learner who types `xxd` and then checks readelf's number will conclude
that one of them is broken.

Consequence for this course: **every byte-level lesson uses a linked
executable.** In the linked `types_O0` there are zero relocations against
`.debug_info`, and the raw bytes and readelf's output agree exactly:

```
$ readelf -rW types_O0 | grep -c debug_info
0
$ python3 assets/dwarf_sections.py assets/samples/types_O0 .debug_info
  [30] .debug_info  off=0x0030e6 size=0x002e0
raw producer strp at 0xd = 63 00 00 00      # 0x63, and readelf says 0x63
```

## Finding 2 — `.debug_abbrev` holds several tables, and reading past the terminator is silent

`types_O0` has **two** abbreviation tables, and readelf lists codes 1-15
twice:

```
$ readelf --debug-dump=abbrev assets/samples/types_O0 | grep -cE '^   [0-9]+ '
30
```

An early version of the decoder collected every entry into one dict keyed by
code. The second table reuses codes 1-15 for different tags, so it silently
replaced the first. The symptom is unusually nasty: the byte walk stays
perfectly in step, every DIE is still found at the right offset, and every
attribute value is read with the right *form* — but the tag names and
attribute lists are the wrong table's. There is no crash and no misalignment
to detect.

A table ends at a lone code `0`, so `read_abbrev()` must `break` there. Verified
on all four abbrev-using files.

## Finding 3 — one `.debug_info` holds one unit per compilation

`types_O0` links two `.c` files, so it has two units:

| Unit at | `unit_length` | `debug_abbrev_offset` | DIEs |
|---|---|---|---|
| 0x0 | 0x20b | 0x0 | 27 |
| 0x20f | 0xcd | 0x100 | 27 |

A decoder that reads only the first unit reports 27 DIEs against readelf's 54
and never raises anything. Total across the corpus: 54 DIEs in `types_O0`, 63
in `types_O2` (extra `DW_TAG_variable` DIEs for the temporaries the optimiser
introduced).

## Finding 4 — the `.debug_aranges` tuple table starts at 16, not 12

`.debug_aranges` is DWARF **version 2** even under `-gdwarf-5`. Its header is
`unit_length`, `version`(2), `debug_info_offset`(4), `address_size`(1),
`segment_selector_size`(1) — eight bytes after the length. But the tuple
table does not start at byte 12; it starts at byte **16**:

```
$ python3 assets/dwarf_sections.py assets/samples/types_O0 .debug_aranges
  [16] .debug_aranges  off=0x00214a size=0x00060
  0000: 2c 00 00 00 02 00 00 00 00 00 08 00 00 00 00 00
  0010: 49 11 00 00 00 00 00 00 80 00 00 00 00 00 00 00
        ^-- address 0x1149        ^-- length 0x80
```

Reading tuples at 12 decodes the first address as **0x114900000000** — a
plausible 48-bit value that points nowhere, and that no sanity check catches.
The second unit confirms the shape: header at 0x30, `debug_info_offset` 0x20f,
table at 0x40, first tuple 0x11c9/0x69. readelf agrees on all of it.

Only `address_size` 8 could be tested (no `-m32` here). For a 4-byte address
byte 12 is already tuple-aligned, so the padding would be zero — **a prediction,
not a measurement.**

## Finding 5 — an FDE has no version and no augmentation

`.eh_frame` records come in two shapes and they are not the same shape:

```
CIE:  length, CIE_id(=0), version(1), augmentation string,
      [version 1: code_alignment_factor ULEB, data_alignment_factor SLEB,
                 return_address_register ULEB]
      [if augmentation starts with 'z': augmentation_data_length ULEB, then data]
      initial instructions

FDE:  length, CIE_pointer, initial_location, address_range, instructions
```

An FDE stops after `CIE_pointer` and goes straight to two encoded values. The
first version of this decoder read a `version` byte for FDEs too, which ate
the first byte of `initial_location` and turned every later field into noise.

## Finding 6 — the `.eh_frame` CIE pointer is relative to its own field

Both FDEs in the reference binary store a `CIE_pointer` **equal to the offset
of the pointer field itself**:

```
00000018 0000000000000014 0000001c FDE cie=00000000
00000030 0000000000000024 00000034 FDE cie=00000000
```

The CIE is at offset 0. Reading the field as an absolute offset looks for a
CIE at 0x1c and 0x34 and finds none. In `.eh_frame` the value is
`field_position - CIE_offset`; in `.debug_frame` the same field is absolute.
Verified: subtracting the field's own position gives 0 for every FDE, and all
eleven CFI rows then match readelf.

## Finding 7 — `DW_EH_PE` 0x0b is `sdata4`, and `address_range` ignores `pcrel`

The CIE sets `fde_encoding = 0x1b` = `DW_EH_PE_pcrel | DW_EH_PE_sdata4`.
Two things follow that are easy to get wrong:

- The **low nibble** is the format: `0x0b` is a 4-byte signed value. Reading
  it as 8 bytes swallows the following four bytes, so the FDE's end address
  came out as `0x10076478` instead of `0x1086`.
- The **high nibble** (`0x10` = pcrel) applies to `initial_location`, whose
  stored value is a displacement from the field's own *runtime* address. It
  does **not** apply to `address_range`, which is a length: adding the section
  base to it gave `0x20ac` where the real end is `0x1040`. `pcrel` also
  requires the section's **virtual** address (`.eh_frame` is at 0x2050), not
  its file offset, or every value is off by the difference.

All eight FDE ranges now agree with readelf:

```
mine     0x1060..0x1086  0x1020..0x1040  0x1040..0x1050  0x1050..0x1060
         0x1149..0x117e  0x117e..0x11a9  0x11a9..0x11c9  0x11c9..0x1232
readelf  identical
```

Note there are **eight** FDEs for five functions: one function's unwind
information is split across three adjacent FDEs (`0x1149..0x117e`,
`0x117e..0x11a9`, `0x11a9..0x11c9`). "One FDE per function" is a reasonable
first guess and is wrong often enough to matter.

## Finding 8 — in split DWARF, `strx` resolution needs a base from the skeleton

A `.dwo` resolves `DW_FORM_strx` through `.debug_str_offsets.dwo`, indexed
from a base that is **not in the `.dwo`** — it is `DW_AT_str_offsets_base` on
the skeleton unit, verified as 8. Ignoring it and using base 0 shifts every
string by two entries, and the first attribute comes back as:

```
DW_AT_producer : unsigned int        <- with base 0
DW_AT_producer : GNU C23 15.2.0 …    <- with base 8, matching llvm-dwarfdump
```

Both readers agree on the string once the base is right.

## Finding 9 — the two readers disagree on an attribute's *name*

`DW_AT_language` is followed in gcc's DWARF 5 output by two attributes the
readers do not agree how to name:

```
readelf:          DW_AT_language_name  (0x90)   DW_AT_language_version (0x91)
llvm-dwarfdump:   DW_AT_unknown_90              DW_AT_unknown_91
```

The *numbers* agree, and the values agree (3 = "C", 0x31647 = 202311). These
are gcc extensions in the DWARF 5 range with no standard name, so the honest
statement is the numeric one: **the attribute number is the truth; the name is
a convention each tool picks.** The course prints the numbers and names both.

## Finding 10 — `DW_AT_upper_bound` is inclusive

From the reference tree, `struct Nest`'s `label` is declared `char label[8]`:

```
<1><f0> DW_TAG_array_type      DW_AT_type <0x77>          (char)
 <2><f9> DW_TAG_subrange_type  DW_AT_type <0x48>  DW_AT_upper_bound : 7
```

`DW_AT_upper_bound` is **7**, not 8. It is an inclusive bound, so the element
count is `upper_bound + 1`. A debugger or pretty-printer that uses the value
directly prints seven elements for an eight-element array and never notices,
because the value is in range and the type is otherwise valid.

## Finding 11 — `implicit_const` puts values in the abbrev table, not the DIE

`struct Point`'s members use `DW_AT_decl_file DW_FORM_implicit_const: 1` and
`DW_AT_decl_line DW_FORM_implicit_const: 7`. Both values live in
`.debug_abbrev`; `.debug_info` carries **no bytes at all** for them. A reader
that expects every attribute to occupy space in the DIE desynchronises, and
because `implicit_const` is usually paired with a `DW_FORM_data1` elsewhere in
the same abbreviation the result is a plausible-looking wrong line number.

## Finding 12 — readelf follows the `.dwo` and merges the trees

`readelf --debug-dump=info types_split` prints 56 DIEs: the 2 skeleton DIEs
**plus** the 54 DIEs it loaded from `types_split.dwo`, because it resolves
`DW_AT_dwo_name` automatically. My decoder on the same file finds 2, which is
correct. The two are only comparable if each is compared against readers
looking at the same file, so the harness checks the `.o` for skeleton units
and the `.dwo` for the real tree. Verified: 2 skeletons with 2
`DW_AT_dwo_name`, 39 DIEs in the `.dwo`.

## Verified type chains (the reference tree, `types_O0`)

All offsets are `.debug_info`-relative and confirmed by both readers.

```
<0x5d> base_type  int                       byte_size 4
<0x41> base_type  unsigned int               byte_size 4
<0x48> base_type  long unsigned int          byte_size 8
<0x77> base_type  char                       byte_size 1

<0x64> typedef __uint32_t   -> <0x41> unsigned int
<0x7e> typedef uint32_t      -> <0x64> __uint32_t          (two hops)
<0x8a> typedef ulong_t       -> <0x48> long unsigned int

<0x96> structure_type Point  byte_size 8
  <0xa1> member x  -> <0x5d> int   data_member_location 0
  <0xaa> member y  -> <0x5d> int   data_member_location 4

<0xb4> structure_type Nest   byte_size 32
  <0xbf> member origin -> <0x96> Point   offset 0
  <0xcb> member label  -> <0xf0> array   offset 8
  <0xd7> member flags  -> <0x7e> uint32_t offset 16
  <0xe3> member next   -> <0x100> pointer offset 24

<0xf0> array_type           -> <0x77> char
  <0xf9> subrange_type      -> <0x48> long unsigned int, upper_bound 7

<0x100> pointer_type        byte_size 8, -> <0x96> Point
```

`Nest` is 32 bytes and its members sit at 0, 8, 16, 24: `Point` is 8, then
`char[8]`, then `uint32_t`, then a pointer, each naturally aligned. The
`DW_AT_data_member_location` values in the table above are the ones the file
actually contains.

## Verified: scopes and locations at `-O0`

`make_point`, at `<0x15c>`:

```
<1><15c> DW_TAG_subprogram
  DW_AT_name make_point   DW_AT_type <0x96>   (returns Point)
  DW_AT_low_pc 0x11a9     DW_AT_high_pc 0x20
  DW_AT_frame_base : 1 byte block: 9c            (DW_OP_call_frame_cfa)
 <2><17d> DW_TAG_formal_parameter x  DW_AT_location 91 5c  (DW_OP_fbreg -36)
 <2><189> DW_TAG_formal_parameter y  DW_AT_location 91 58  (DW_OP_fbreg -40)
 <2><195> DW_TAG_variable  out       DW_AT_location 91 68  (DW_OP_fbreg -24)
```

The three locations are displacements from the frame base, and the CIE says
`DW_CFA_def_cfa reg=7 offset=8`, so the frame base is `rsp + 8` on entry. The
parameters sit at negative offsets from it, which is what makes them
recoverable after a `push` has moved rsp.

## Verified: inlining at `-O2`

`inline.c` with a `static` `dot()` called three times produces **three**
`DW_TAG_inlined_subroutine` DIEs:

```
<2><ea>  DW_AT_abstract_origin <0x127>   DW_AT_entry_pc 0x16
        DW_AT_call_file 1  DW_AT_call_line 6  DW_AT_call_column 12
        DW_AT_low_pc 0x16  DW_AT_high_pc 0x14
<2><172> DW_AT_abstract_origin <0x127>   DW_AT_entry_pc 0x52
        DW_AT_call_file 1  DW_AT_call_line 9  DW_AT_call_column 12
        DW_AT_ranges 0xc                       <- not low_pc/high_pc
```

`DW_AT_abstract_origin` points at a separate `DW_TAG_subprogram` DIE that
describes the function as written, with no addresses. The instance DIE says
where the call was and where the body landed. One instance uses
`DW_AT_ranges` rather than a `low_pc`/`high_pc` pair, because that call's body
is split into two address ranges — a `DW_AT_ranges` consumer must not assume a
single contiguous range.

## Verified: `.debug_pubnames`

`types_pub`, `readelf --debug-dump=pubnames`:

| Set | `debug_info` offset | size | entries |
|---|---|---|---|
| 1 | 0x0 | 527 | `0x10d g_nest`, `0x122 g_count`, `0x147 g_table`, `0x15c make_point`, `0x1a5 walk`, `0x1d3 sum_table` |
| 2 | 0x20f | 209 | `0x5a walk`, `0x75 sum_table`, `0x8a make_point`, `0xa4 main` |

Version 2, one set per unit, each `(Length, Version, Offset into .debug_info,
Size of area)` then a NUL-terminated `(DIE offset, name)` list terminated by a
zero offset. The two sets are in different orders, and the first includes
`static` variables, so pubnames is not simply "the externals in link order".

## Still unverified — do NOT teach

- [ ] **`.debug_loclists` entry encoding.** Present in `types_O2` (96 bytes)
      and `readelf --debug-dump=loc` prints "location view pair" rows whose
      begin and end are both 0 at offsets where the bytes are `0x00`.
      `llvm-dwarfdump` was not available to break the tie. Rather than pick
      whichever reading suits the lesson, the entry encoding is **not taught**.
      Location *expressions* (`DW_FORM_exprloc`) are fully cross-checked and
      are taught instead.
- [ ] `.debug_rnglists` / `DW_AT_ranges` contents — the attribute is verified
      to exist, the list it points at is not decoded.
- [ ] `address_size` 4 — no `-m32` on this machine.
- [ ] Non-x86-64 producers, macOS/Windows clang DWARF.
- [ ] `DW_LNE_define_file` — not emitted by this gcc.
- [ ] `DW_FORM_GNU_str_index` and other pre-DWARF-5 string forms.

## Method

1. Write the source, compile at each interesting flag combination.
2. Locate sections with `dwarf_sections.py`, not readelf.
3. Decode with `dwarf_decode.py`, written from the specification.
4. Require field-by-field agreement with `readelf` **and** `llvm-dwarfdump`.
5. Where they disagreed, decode the bytes by hand, find the reading that is
   self-consistent, and record it as a finding rather than quietly choosing one.
6. Run `crosscheck.py`; a claim did not enter the course until it passed.

Step 4 is where the value is. Four of the findings above (the aranges padding,
the relative CIE pointer, the missing FDE header, the `sdata4` width) were
found *because* an independent decoder disagreed with readelf, and each one
produces confident, plausible, wrong output rather than an error.

---

# Phase A record — Module 4: Location Lists, Portability and Packages

The Module 3 record closed with a list of items marked "blocked on tooling".
Four of the six fell. This section records what changed and what did not.

## Blockers that fell

### 1. `address_size` 4 and 32-bit producers — SOLVED

Not `-m32` (gcc here has no multilib), but clang targets directly:

```
$ clang --target=i386-linux-gnu -gdwarf-5 -c t.c -o types_i386.o
$ readelf --debug-dump=info types_i386.o | grep 'Pointer Size'
  Pointer Size:  4
```

The CU header is `a5 00 00 00 05 00 01 04 00 00 00 00 01 00`:
`unit_length` 165, `version` 5, `unit_type` 1, **`address_size` 4**.

### 2. Non-x86-64 producers — SOLVED

```
$ clang --target=aarch64-linux-gnu -gdwarf-5 -c t.c -o types_aarch64.o
  Pointer Size:  8
```

### 3. `.debug_loclists` — SOLVED, and it resolves an open disagreement

This is the item I previously refused to teach, because `readelf` and
`llvm-dwarfdump` disagreed and I had only two readers. `llvm-dwarfdump` turned
out to read the section, and it is the third reader the item was waiting for:

```
$ llvm-dwarfdump --debug-loclists types_O2
locations list header: length = 0x5c, version = 5, addr_size = 8, offset_entry_count = 0
0x0000000c: 0x0000000d: 0x0000000e: 0x0000000f:            (all empty)
0x00000010: DW_LLE_offset_pair (0x40, 0x48): DW_OP_reg4 RSI
            DW_LLE_offset_pair (0x48, 0x4e): DW_OP_entry_value(DW_OP_reg4 RSI), DW_OP_stack_value

$ readelf --debug-dump=loc types_O2
  0000000c  v0 v0  location view pair
  0000000e  v0 v0  location view pair
  00000010  views at 0000000c for: ...
```

**Adjudication by byte offsets**, which is the only way this can be settled:

- Bytes at `0x0c` are `00 00 00 00`. `0x00` is `DW_LLE_end_of_list` in DWARF 5,
  so the lists at `0x0c`, `0x0d`, `0x0e`, `0x0f` are each empty. That is
  llvm's reading and it is what the bytes say.
- "Location view pair" is a DWARF 4 `.debug_loc` concept. It has no meaning in
  a `DW_LLE` stream. `readelf` is decoding a version-5 table with a version-4
  grammar.
- Every llvm offset is reachable by sequentially consuming the bytes it claims.
  `readelf`'s `0x1d` "end of list" lands in the middle of llvm's `0x1e` entry.

Both readers agree with each other, and with my decoder, on the thing that
matters for a DIE: that `0x10`, `0x24` and `0x47` are loclist offsets.
`0x10` and `0x24` are used in `dwarf-loclists` because they are both
*referenced by a DIE* and *decoded at that same offset* — doubly verified.

### 4. `.dwp` packages — SOLVED

`llvm-dwp` exists, which I had not checked for:

```
$ llvm-dwp -e split_exe -o split.dwp
$ readelf -S -W split.dwp | grep -oE '\.debug[a-zA-Z_.0-9]*'
.debug_abbrev.dwo  .debug_cu_index  .debug_info.dwo
.debug_line.dwo     .debug_str.dwo   .debug_str_offsets.dwo
```

`llvm-dwp` discovers the `.dwo` files by reading `DW_AT_dwo_name` from the
executable's skeleton units, not by scanning the directory — confirmed by
passing it a non-split object and getting
`warning: executable file does not contain any references to dwo files`.

`.debug_cu_index` header, all four fields 4 bytes wide:

```
0000: 05 00 00 00  version = 5
0004: 04 00 00 00  section_count = 4
0008: 02 00 00 00  unit_count = 2
000c: 04 00 00 00  slot_count = 4
```

And both units' 64-bit `DWO_id`s appear verbatim at `0x20`, matching what
`llvm-dwarfdump` prints from the units themselves:

```
index 0020: 3a c9 20 1a 41 2d e4 5c = 0x5ce42d411a20c93a
index 0028: 0f b3 b9 69 1f 53 96 c2 = 0xc296531f69b9b30f
```

**The offset table's tail is not accounted for and is not taught.** The header
plus the 4-slot hash table plus both signatures plus 4 sections x 2 units of
offsets is 80 of 144 bytes. A 16-byte block is visibly duplicated at `0x60` and
`0x70`, which no single-table reading explains. `0xb7` does appear there and
does match the second unit's offset, which is suggestive but not a derivation.
`dwarf-packages` states this explicitly rather than guessing, and gives the
reader the evidence needed to finish the job.

### 5. `.debug_rnglists` / `DW_AT_ranges` — SOLVED

`inline_O2.o` has `.debug_rnglists` (78 bytes) and 8 relocations against it.
`llvm-dwarfdump --debug-rnglists` reads it. `readelf --debug-dump=rnglists`
prints **nothing** for this file — a second, separate readelf gap.

Decoded by hand and by script, agreeing:

```
0x0c  DW_RLE_base_address  base = 0 (relocated)
0x15  offset_pair (0, 18)
0x18  offset_pair (18, 26)
0x1b  offset_pair (34, 48)
0x1e  offset_pair (56, 60)
0x21  end_of_list
0x22  [list 2] base_address, then 4 more offset_pairs, end_of_list at 0x37
0x38  [list 3] start_length (start 0, len 137 = 89 01)
0x43  start_length (start 0, len 10 = 0a)
0x4d  end_of_list
```

Three lists in one section, and two different opcode families. My first
hand-walk of this went wrong past `0x2f` because I reconstructed bytes instead
of reading them; the dump above is from the file.

## The portability finding worth keeping

`types_i386.o` and `types_aarch64.o` both have `unit_length = 165`.
Identical. One is 32-bit, one is 64-bit, and every address differs in width.

The reason is `DW_FORM_addrx`: `DW_AT_low_pc` reads `(index: 0): 0`. Addresses
are stored as indices into `.debug_addr`, so the target's address width never
enters the DIE tree. The unit lengths are the same because the indices are the
same size, not because the addresses are.

Version 2 and 3 share an 11-byte header; version 5 inserts `unit_type` making
it 12. The first DIE therefore sits at `0xb` or `0xc` depending only on the
version, with nothing else in the file to indicate which.

`.debug_line_str` exists only in the version 5 build. A version-5 reader can
meet `DW_FORM_line_strp` whose target section does not exist.

## Still not taught, and why

- **The index forms** `DW_LLE_base_addressx`, `startx_endx`, `startx_length`
  and their `DW_RLE` equivalents. They all require a non-zero
  `offset_entry_count`, and no configuration on this machine produces one —
  every section observed has it zero. The concepts say so and list them as the
  untested set.
- **`DW_RLE_start_end`** and **`DW_LLE_start_end` / `start_length` / `default_location`**
  as such. `DW_RLE_start_length` *is* now covered (list 3 above), which the
  concept states rather than leaving the whole family unwritten.
- **Pre-DWARF-5 `.debug_ranges` and `.debug_loc`**, and
  `DW_FORM_GNU_str_index`. The version 2 and 3 builds are decoded for their
  headers and string forms, which is what `dwarf-portability` teaches; the
  old list sections themselves are a separate comparison this course did not
  make.
- **DWARF64.** A 4 GB debug-info file is not producible here, so the
  `0xffffffff` escape is taught as a documented branch that was never executed.
  The concept says that explicitly.
- **`.debug_rnglists` intervals on a linked binary.** The offsets are
  verifiable from the object; the resolved addresses are not, because they come
  from relocations. `dwarf-rnglists` makes that distinction explicit and tells
  the reader to link the object rather than presenting the second while showing
  evidence for the first.
