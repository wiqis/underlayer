# JVM Class File Format — Phase A research record

Written before any course content, and updated as findings landed. Every claim
here was produced by running a tool, not by reading the specification and
reasoning about it. Where something could not be established, it says so.

## Toolchain

The strongest position of any course in this collection, and the only one with
**three** independent readers plus a boolean oracle.

| Tool | Version | Role |
|---|---|---|
| `javac` | 26.0.1 | producer — every sample is real compiler output |
| `javap` | 26.0.1 | reader 2 — the JDK's own disassembler |
| `java.lang.classfile` | JDK 26 | reader 3 — the JDK's own standard parsing API |
| `java` | 26.0.1 | the oracle — the JVM verifier accepts or rejects |
| `python3` | 3.14 | this course's spec-derived decoder |
| `gradle` | present | not needed; the JDK is self-contained |

No decompiler is available (`procyon`, `cfr`, `fernflower`, `jadx` all absent) and
none is needed: the format is fully readable with a hex dump, which is the point
of the course.

### Why `java.lang.classfile` matters

Added in Java 22, it is the JDK parsing class files through a **supported public
interface** rather than through a disassembler. That makes it independent of
`javap` in a way a third-party tool would not be: a bug in one implementation
cannot hide in both. It also turned out to be *stricter* than either other
reader about one thing, which became a finding — see finding 3.

Three API names cost time and are recorded so they are not lost:

- The pool type is `java.lang.classfile.constantpool.ConstantPool`, **not**
  `java.lang.classfile.ConstantPool`.
- It is `Iterable`, so it is iterated directly; there is no `entries()` method.
- Members are read with `fieldName()`/`fieldType()` and
  `methodName()`/`methodType()`, **not** `descriptorString()`. A class entry's
  name is `asInternalName()`, not `displayName()`.

## Readers

`assets/samples/class_decode.py` — written from the JVM Specification, and
deliberately **not a validator**. It reads structure and prints what it finds. The
docstring explains why that distinction is itself a teaching point: the class
file format is the rare binary format where a decoder can be completely correct
about the bytes and still be handed a file no JVM will load.

`assets/samples/Cf.java` — reader 3, using the JDK's own API.

`assets/samples/crosscheck.py` — requires all three to agree.

## Findings

### 1. Everything is big-endian, including the famous magic

`cafe babe` at offset 0. A little-endian reader sees `0xBEBAFECA`. Every
multi-byte field in the format is big-endian, which is the opposite of ELF, PE
and x86, and is the first thing that surprises anyone arriving from those.

Verified: `javap -v` reports `major version: 70` for a file this course
compiled, and this course's decoder reads the same 70 from the same bytes.

### 2. Two offset conventions coexist inside one attribute

This is the sharpest thing found in the whole course, and it is a genuine trap
because both conventions are in the same method of the same sample.

**Instruction branch offsets are relative to the address of the branch
instruction itself.** In `Shapes.tableswitch`, the opcode `0xAA` sits at offset
1 and the five encoded targets read `0x23 0x25 0x27 0x29 0x2B` = 35, 37, 39, 41,
43. Those are *not* the destinations. Adding the opcode's own address of 1 gives
36, 38, 40, 42, 44 — which is what `javap` prints, and those offsets land
exactly on the `iconst_1`/`ireturn` pairs that `case 0:` through `case 4:`
return. The default encodes as 45 and means 46.

**Exception table offsets are absolute code offsets.** The same method's
`trycatch` has `from 0 to 5 target 10` and `javap` prints exactly those numbers,
with offset 10 being the `astore_2` that begins the `ArithmeticException`
handler. No adjustment.

Both verified by diffing this course's decoder's output against `javap -c`. A
disassembler that reported raw switch offsets would be wrong by a different
amount at every switch, because the error is the instruction's own position.

### 3. The JDK's own API throws on a Long/Double hole

`CONSTANT_Long` and `CONSTANT_Double` occupy **two** constant pool indices and
the second is permanently unusable. Confirmed three ways on `Consts.class`:

- this course's decoder: `constant_pool_count 52 -> 47 usable`, holes at
  **24, 31, 40, 43**
- `javap`: silently skips those four indices, so the gaps are visible in its
  numbering but it never mentions them
- `java.lang.classfile`: `cpSize 52`, `cpUsable 47`, `cpHoles 4`,
  `cpHoleIdx 24 31 40 43` — and `entryByIndex(24)` **throws
  `ConstantPoolException`**

The third is the interesting one. The API does not return null and does not
return a wrong entry; it treats an unusable index as a hard error. That is a
stronger statement than "there is a gap you had better notice", and it is the
JDK's own position on the question.

A second consequence, also verified: the API's `ConstantPool.size()` is the raw
`constant_pool_count` (52), while iterating it yields only the 47 usable
entries. **The iteration length and `size()` disagree, and that disagreement is
the two-slot rule seen from outside.**

### 4. `CONSTANT_Utf8` is not UTF-8

Two deviations from real UTF-8, both confirmed against `javac` output for
`Str.class`:

**NUL is two bytes.** Java source `"a\0b"` appears as `61 c0 80 62`. The whole
point is that no string in a class file can contain a zero byte and be
truncated by anything that stops at NUL. Note that `"\u0000"` cannot be used to
write this in Java source: the unicode pre-processor runs *before* parsing and
would inject a raw NUL into the token stream. `"\0"`, an octal escape, is the
only way — and that difference is itself worth teaching.

**A supplementary character costs six bytes, not four.** The emoji U+1F389
appears as `ed a0 bc ed be 89`: its UTF-16 surrogate pair with each surrogate
encoded separately as three bytes. This is CESU-8. A standard UTF-8 decoder
rejects those bytes outright, which this course's own decoder did until it was
fixed — a useful demonstration that the deviation is real rather than
theoretical.

Also verified: a Java `char` cannot hold a supplementary character at all,
because `char` is one UTF-16 code unit. `char c = '\uD83C\uDF89';` is a compile
error.

### 5. The harness did not catch a silent wrong answer, and the reason was duplicated logic

Worth recording because the bug was in the harness, not the decoder.

`class_decode.py` computed "which pool indices are unusable" in `dump()`, and
`crosscheck.py` computed it again in its own reader. The harness exercised only
its own copy. A fault injected into `dump()`'s copy — making it report zero
holes while parsing perfectly correctly — **passed the crosscheck completely.**

Fixed by making it one function, `pool_holes()`, in `class_decode.py`, called by
both. The same fault is now caught with a message naming all three readers:

```
cp_holes differs: mine=() javap=(24, 31, 40, 43) api=(24, 31, 40, 43)
```

The general lesson, and it is the same one the WebAssembly harness taught: a
harness whose limits are undocumented will eventually be trusted past them, and
a check that re-implements the thing it is checking tests the re-implementation.

### 6. A fault that produces a *different legal file* is not a harness failure

Injecting a rename of the field `arr` to `arx` passed the crosscheck. That is
correct behaviour, not a gap: all three readers read the same patched file and
all three correctly report `arx`. A decoder is allowed to be right about a file
that differs from the original in one byte.

The distinction matters when designing fault injection. Three of the five faults
injected here create a genuine **disagreement** between readers and are
detected; one creates a different-but-valid file and is correctly not detected;
and only a fault that makes **one reader wrong while the bytes stay valid** tests
the comparison logic itself. That last category is the one worth spending
effort on, and it is the hardest to construct.

## Fault injection results

| Fault | Level | Detected |
|---|---|---|
| last magic byte `babe` -> `babf` | structure | yes |
| `constant_pool_count` + 1 | framing | yes |
| field `arr` -> `arx` | content | no — correct, it is a different legal file |
| decoder ignores the two-slot rule | slots | yes, but crudely: the decoder crashed |
| decoder reports zero holes | slots, silently | **no at first** — see finding 5; yes after the fix |

The fourth fault deserves a note: the harness noticed, but as an exception
rather than as a comparison. A sabotage that produces a *wrong answer* rather
than a *crash* is the only kind worth trusting as a test, and that is what
finding 5's fault was for.

## Samples

21 class files, all produced by `javac` on this machine, all read by all three
readers with no disagreements.

| Sample | Bytes | What it is for |
|---|---|---|
| `Hello.class` | 409 | the minimum: header, pool, two methods, `Code` |
| `Consts.class` | 661 | every constant pool tag, four Long/Double holes |
| `Flags.class` | 792 | the spread of access flags, abstract/native/synchronized |
| `Shapes.class` | 842 | both switches, `wide`, a six-entry exception table |
| `Desc.class` | — | one field of every type: the whole descriptor grammar |
| `Slots.class` | — | ten methods whose `max_locals` predicted from the signature all match |
| `Wide.class` | 6175 | 300 live locals, `max_locals = 303`, 96 `wide` prefixes at index 256+ |
| `Str.class` | 532 | modified UTF-8: NUL, surrogate pair, BMP limits |
| `Gen.class` | 992 | `Signature` — generics as a descriptor grammar |
| `Lambda.class` | 3621 | `invokedynamic`, `BootstrapMethods`, `MethodHandle` |
| `Rec.class` | 1452 | the `Record` attribute |
| `Sealed*.class` | 228-1140 | `PermittedSubclasses`, sealed interfaces |
| `Anno.class`, `Marker.class` | 473 | `RuntimeVisibleAnnotations`, `AnnotationDefault` |
| `Inner*.class` | 6 files | `InnerClasses`, `NestHost`, `NestMembers`, `$1` numbering |
| `Shapes`, `Hello`, `Consts`, `Flags`, `Str`, `Gen` | — | single-class samples above |

`Inner$1Local.class` is worth its own line: javac numbered a class declared
inside a method `$1Local`, so the numbering scheme and the file name disagree in
a way that is worth a concept.

## Not established

- **Attribute bodies are not cross-checked.** The harness compares attribute
  *names*, and this course's decoder prints `max_stack`, `max_locals`, the code
  bytes and the exception table. The exception table was verified by hand
  against `javap -c` (finding 2) but is not in the automated pass/fail, because
  `javap` presents it as part of a disassembly rather than as fields. This is
  stated in the harness's own source rather than left for a reader to discover.
- **Constant pool values are not cross-checked** — tags and slots are, the
  integer a `CONSTANT_Integer` holds is not.
- **Access flag names are not cross-checked**, because all three readers could
  share a wrong table. They were instead verified by hand against `javap` on
  `Flags.class`, which uses a wide spread. This caught a real error: an early
  version of the table listed `0x0009` as `ACC_FINAL` when it is
  `ACC_PUBLIC|ACC_STATIC`, so every static public method was reported with two
  wrong names and one missing.
- **Version history is not verified by building.** The `major` numbers for old
  class file versions are stated from the specification, not reproduced by
  compiling with `--release`, which was not exercised.

## Tooling gaps

- No decompiler, and none needed. A reader that understands the format can
  reconstruct the semantics without one, which is the course's argument.
- No `asm` or `bytecode-viewer`; the JDK API covers the same ground and is
  better because it is the same code the JVM uses.
- `gradle` is present but unused. Everything needed is in the JDK.

### 7. TWO offset conventions coexist inside one attribute

The sharpest single finding in the course, and a trap precisely because nothing
in the bytes marks which convention is in force.

**Instruction branch offsets are relative to the address of the branch
instruction itself.** In `Shapes.tableswitch`, the opcode `0xAA` sits at offset 1
and the five stored targets are `0x23 0x25 0x27 0x29 0x2B` = 35, 37, 39, 41, 43,
with a stored default of 45. `javap -c` prints **36, 38, 40, 42, 44 and default
46** -- every stored value plus the opcode's own address of 1. Those offsets land
exactly on the `iconst_N; ireturn` pairs for `case 0:` through `case 4:` and on
the default's `iconst_0; ireturn`.

**Exception table offsets are absolute code offsets.** The same class's
`trycatch` has `from 0 to 5 target 10`, and `javap -c` prints exactly those
numbers, with offset 10 being the `astore_2` that begins the `ArithmeticException`
handler. `to` is exclusive, and rows are tried in order.

Both verified by diffing this course's decoder's output against `javap -c`. The
failure mode is nasty because the error is *the instruction's own position*, so
it is a different amount at every branch: applying the relative rule to the
exception table makes handler 1 report 20 instead of 10 and handler 3 report 54
instead of 27.

### 8. One number confirming two findings at once

The `tableswitch` method's `StackMapTable` is eight bytes: `00 06 24 01 01 01 01
01`, six `same_frame`s. Frame offsets are absolute, and frame N's offset is
`previous + frame_type + 1` after the first, which gives **36, 38, 40, 42, 44,
46**. The switch's six destinations, after adding the opcode address, are also
**36, 38, 40, 42, 44, 46**. Two independent derivations agreeing to the byte, and
the agreement is the proof: a relative branch misread as absolute would put the
frames at 35, 37, 39, 41, 43, 45 -- odd numbers landing mid-instruction.

This is the most efficient verification in the course and it came from the sample
by accident: the switch's only branches *are* its six destinations, so every frame
has a branch and every branch has a frame.

### 9. A hypothesis formed, tested, and discarded

Seeing the `trycatch` frame types 74, 71 and 72 as bytes gives `0x4A`, `0x47`,
`0x48` -- the `astore`, `astore_0` and `astore_1` opcodes. The specification does
say a `same_locals_1_stack_item` frame always follows an astore-family
instruction, and the frame's single stack item is what that store produced, so
the frame type plausibly *is* the instruction.

**It is wrong, and the bytes say so.** The instructions at offsets 10, 18 and 27
are `astore_2`, `astore_2` and `astore 4` -- `0x4D`, `0x4D` and `0x3A`. The frame
type is 64 plus an offset delta and nothing else. The astore family merely
occupies the same numeric range, 64 to 127, because the specification allocated
that range to this frame type. Recorded because a plausible story that survives a
glance is exactly what this course keeps warning about.

### 10. max_locals: the third two-slot rule

`Slots.class` has ten methods whose `max_locals` were predicted from the
signature before being checked, and all ten match:

    d(J)V      1 + 2           = 3     long is TWO slots
    e(JJ)V     1 + 2 + 2       = 5
    f(D)V      1 + 2           = 3     double is TWO slots
    g(IJD)V    1 + 1 + 2 + 2   = 6
    s(IJD)V    0 + 1 + 2 + 2   = 5     static: no `this`
    h(String, int[], Object)  1 + 3    = 4   arrays are ONE slot

So the course has now found the same 64-bit rule in **three** places: two pool
indices, two local slots, two stack slots, plus a `TOP` verification type for the
unusable half. A verification script written for this course initially got
`h` wrong by treating `[I` as two tokens -- the array's `[` is part of the type,
not a separate thing.

`max_locals` is also **not** the number of locals. `Shapes.wide` has twelve live
locals and `max_locals` is 2, because the field is sized from the signature and
the body's locals live above that mark. A generated class with 300 live locals has
`max_locals = 303`, so the field is neither a tight bound nor a constant.

### 11. The wide prefix appears at exactly 256

A local variable index is one byte, so 256 is the first value that does not fit,
and the `0xC4` prefix widens the index that follows to a `u2`. Verified on the
generated 300-local class: `max_locals = 303`, 96 real wide prefixes, and the
first is `c4 36 01 00` = `wide istore 256` at code offset 1139, immediately after
an unprefixed `istore 255`.

A caution about finding this by scanning: a naive `c4` byte search finds false
positives inside operands, because `c4` also occurs as a pool index. The real
ones were located by looking for `c4` followed by one of the twelve opcodes it may
prefix, and cross-checked against `javap`.

### 12. The complete descriptor grammar, three-reader verified

From `Desc.class`, one field of every type, with all three readers agreeing on
every name and descriptor:

    Z B C S I J F D            the eight primitives
    V                          void, return position only
    Ljava/lang/String;         a reference, internal name with slashes
    LDesc$Nested;              a nested class, $ separated
    [I   [[I   [Ljava/lang/String;    one [ per dimension, PREFIX order
    ()V   (I)Z   (IJLjava/lang/String;[ILjava/lang/Object;)V

Generics are **absent**: a `List<String>` field has descriptor
`Ljava/util/List;`, with the type arguments in a separate `Signature` attribute.
That absence is deliberate -- the erased type is all the verifier needs.
