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

25 class files, all produced by `javac` on this machine, all read by all three
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
| `module-info.class` | 370 | the `Module` attribute, `CONSTANT_Module`/`Package`, `ACC_MODULE` |
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
- **Version history was initially not verified by building.** The `major` numbers
  for old class file versions were stated from the specification, not reproduced
  by compiling with `--release`. **This is now closed** (finding 22): one source
  file was compiled at `--release` 8, 11, 17 and 21 and the results compared
  against `javap`. It changed a number in the course -- the file is *larger* at
  release 11 than at release 8 -- which is the reason it was worth doing rather
  than assuming. Numbers for versions older than 8 are still from the
  specification; no toolchain here emits them.

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

---

## Modules 3-5: the attribute long tail, linking, and versioning

The attribute inventory below was measured across the sample set rather than
recalled, by collecting every attribute name `javap -v` prints and counting:

    class-level, 24 samples        code-level, all Code attributes
      SourceFile              24     LineNumberTable           75
      InnerClasses            14     Signature                 11
      NestHost                 8     ConstantValue             10
      BootstrapMethods         4     MethodParameters           9
      Signature / Record       3     StackMapTable              4
      NestMembers              3     AnnotationDefault          2
      RuntimeVisibleAnnot.     2     Deprecated                 1
      EnclosingMethod          2
      PermittedSubclasses      1

`LineNumberTable` is on all 75 `Code` attributes without exception, because
`javac` emits debug information by default. `SourceFile` is on all 24 classes,
and it is the only reference to the source filename, so removing it shrinks the
pool -- the class file does not need to know its own name.

### 13. `InnerClasses` uses the member flag table, not the class one

Decoded from the raw bytes of `Inner.class`, all six records, 50 bytes:

    [0] inner=#7   outer=#0   name=#0   flags=0x0000   Inner$1        anonymous
    [1] inner=#18  outer=#0   name=#36  flags=0x0000   Inner$1Local   method-local
    [2] inner=#27  outer=#13  name=#37  flags=0x4018   Inner$E         enum
    [3] inner=#29  outer=#13  name=#38  flags=0x0608   Inner$Iface     interface
    [4] inner=#31  outer=#13  name=#39  flags=0x0000   Inner$Member
    [5] inner=#33  outer=#13  name=#40  flags=0x0008   Inner$Nested    static

`0x0008` on records [2], [3] and [5] is `ACC_STATIC`, which is meaningless for a
top-level class. `inner_class_access_flags` describes a member of a class, so it
uses the field/method table. This is a live trap in this course's own decoder:
it reported `ACC_FINAL ACC_ENUM UNKNOWN(0x0008)` -- correct, and exactly the
wrong-table bug, since it was asked to render class flags.

`Inner$1Local` has a name but `outer_class_info_index = 0`, and `Inner$1` has
neither. That is why a nest-aware tool must use `NestHost`/`NestMembers` rather
than following `InnerClasses` outward: the attribute it would need to follow is
legitimately zero for exactly the two kinds of class that have no single
enclosing class.

### 14. There is no common attribute body shape, and two attributes are byte-identical

    SourceFile          4 + 2    ONE u2. No count.
    NestHost            4 + 2    ONE u2. No count.        raw: 00 10
    PermittedSubclasses 4 + 4    u2 count + that many u2  raw: 00 02 00 0a 00 08
    NestMembers         4 + 12   u2 count + that many u2  raw: 00 06 00 1b ...

`NestHost` and `SourceFile` are a bare index; a reader that assumes a counted
list reads the following attribute's name index as a count.
`PermittedSubclasses` and `NestMembers` are the same six bytes of structure and
mean unrelated things -- the name carries all the semantics.

### 15. `Signature` is a second grammar, and its wildcards cost one byte

A field declared `Map<String, List<? extends Number>>`:

    descriptor: Ljava/util/Map;
    Signature:  Ljava/util/Map<Ljava/lang/String;Ljava/util/List<+Ljava/lang/Number;>;>;

`+` is `? extends`, `-` is `? super`, `^` is unbounded, a bare type means exact.
Type arguments are **inline text, not pool indices**, so a repeated type
argument is written out twice rather than shared.

The class's own signature for `class Gen<T extends Comparable<T> & Cloneable, V>`:

    <T:Ljava/lang/Comparable<TT;>:Ljava/lang/Cloneable;TV;>Ljava/lang/Object;

Two things: the `&` became a second colon (intersection is implicit in the
repetition), and the self-referential bound lost its `T` -- erasure reaches into
the bounds, not just the type arguments. A member's signature only *uses* the
names: field `T t` has signature `TT;`, one character.

### 16. Annotation tags are characters, and every value is a pool index

The class-level annotation is eleven bytes and contains no value:

    00 01  00 0e  00 01  00 0f  73  00 16
    |     |      |     |     |    +---- #22 = Utf8 "hello"
    |     |      |     |     +--------- 0x73 = 's' = String
    |     |      |     +--------------- #15 = "value"
    |     |      +--------------------- 1 pair
    |     +---------------------------- #14 = "LMarker;"
    +---------------------------------- 1 annotation

`0x73` is the ASCII code for `s`. The ten tags are `B C D F I J S Z` uppercase,
`s` **lowercase** for String, `e`, `c`, and `@`.

**This course's own first analysis was wrong here, and the way it was caught is
the useful part.** It assumed an `int` value was a 4-byte inline payload and
read `00 12 00 13` as 1179667. The parse did not *balance*: 11 + 10 bytes have
to total exactly 20, and a 4-byte payload left two bytes over, which would have
to be the next annotation's `type_index` of 0 -- and index 0 is the reserved
entry. **A parse that does not balance is a parse that is wrong, and the
imbalance is louder evidence than a surprising number.** The real encoding is a
uniform `u2` pool index for every constant type, confirmed against `javap -v`,
which prints `0: #14(#15=s#16,#17=I#18)`.

Two of the eight value kinds are *not* pool references: arrays reuse the pair
list with an empty final name, and `@` embeds a whole nested annotation inline.
So `element_value` is not fixed-size.

### 17. `Record` is a declaration, not a description

`record Rec(int x, String name, long[] data)` produces nine members from three
source declarations. The accessors are **not** `ACC_SYNTHETIC` (`0x0001`), which
is correct because source calls them by name. The class flags are `0x0031` --
`ACC_PUBLIC|ACC_FINAL|ACC_SUPER` and **no `ACC_RECORD` exists**; the attribute
is the marker. The superclass is `java.lang.Record` and the JVM enforces that,
because its only constructor is `protected`. Deleting the `Record` attribute by
hand leaves a class that loads, runs, and has all nine methods -- and is not a
record, so pattern-matching `switch` will not compile against it.

The component list is 20 bytes: `u2` count then six bytes per component. A
generic component is where the component's own attribute list earns its
existence, carrying a `Signature`.

### 18. An empty `PermittedSubclasses` is a statement, not an absence

`Sealed$A.class` has the attribute with a **zero-length body**. The attribute's
*presence* is what says "sealed"; the list may be empty, meaning the hierarchy is
closed over itself. A reader that tests for a non-empty list to decide sealedness
gets it exactly backwards. A permitted subclass must also be `ACC_FINAL` in its
own `InnerClasses` record, and that is the load-time failure if it is not -- a
rule coupled across two files, which is invisible to a per-file reader.

### 19. `values()` and `valueOf()` are not synthetic; `$VALUES` and `$values()` are

From `Inner$E.class`, eight members for `enum E { A, B }`:

    class            0x4030  ACC_FINAL, ACC_SUPER, ACC_ENUM
    A, B             0x4019  ACC_PUBLIC, ACC_STATIC, ACC_FINAL, ACC_ENUM
    $VALUES          0x101a  ACC_PRIVATE, ACC_STATIC, ACC_FINAL, ACC_SYNTHETIC
    values()         0x0009  ACC_PUBLIC, ACC_STATIC             <- no SYNTHETIC
    valueOf(String)  0x0009  ACC_PUBLIC, ACC_STATIC             <- no SYNTHETIC
    Inner$E()        0x0002  ACC_PRIVATE
    $values()        0x100a  ACC_PRIVATE, ACC_STATIC, ACC_SYNTHETIC
    static init      0x0008  ACC_STATIC

The natural expectation is that compiler-generated members are synthetic. The
two public ones are not, because they are real methods the language calls by
name; only the cached array and its bridge are. `ACC_ENUM` is `0x4000` in both
the class table and the field table, and means the same thing in each -- unlike
`InnerClasses`' `0x0008`, which means different things in different tables.

There is no enum attribute and no constant count. `java.lang.Enum` recovers the
list by scanning the subclass's declared fields for `ACC_ENUM`, so the flag is a
*selector* rather than a checked declaration -- the opposite of
`PermittedSubclasses`, which the verifier enforces.

### 20. A bootstrap method reference is ONE u2, not two

`BootstrapMethods` is `u2 num`, then per entry `u2 bootstrap_method_ref`,
`u2 num_bootstrap_arguments`, then the arguments. The reference is a single
index because it names a `CONSTANT_MethodHandle`, which is already a complete
reference -- unlike a `CONSTANT_Methodref`, which needs a class index and a
name-and-type index.

All 84 bytes of `Lambda.class` decoded, agreeing with `javap` on all nine
entries and consuming exactly 84 bytes:

    [0] #174  3 args   LambdaMetafactory       (erased type, impl handle, type)
    ...
    [6] #181  1 args   StringConcatFactory     (just the recipe)
    [8] #181  1 args   StringConcatFactory

**This course's own decoder read two `u2`s and reported 134 arguments in an
84-byte attribute.** Reading it as one field is the fix, and the reason the bug
was caught is the same as finding 16: the attribute length is the only
arithmetic that can tell you, so a length-delimited structure must assert it
consumed exactly the declared bytes.

Entry 3 points `REF_invokeStatic Lambda.hello:()V` at an *existing* method
rather than a generated `lambda$new$N`, so a method reference to a compatible
existing method generates no code at all. The generated names are
`lambda$<enclosingMethod>$<counter>` and, for a constructor, `lambda$new$N`.

### 21. `javap` prints `Unknown` for two of the twenty pool tags

`module-info.class`, 370 bytes, compiled on this machine:

    #6  = Unknown  #7    // "com.example.demo"      <- tag 19, CONSTANT_Module
    #8  = Unknown  #9    // "java.base"             <- tag 19
    #13 = Unknown  #14   // com/example/api         <- tag 20, CONSTANT_Package

`javap` in JDK 26 **resolves the Utf8 correctly and prints the tag as
`Unknown`.** It reads the structure and lacks a label. This course's decoder
reads both correctly, and `java.lang.classfile` models them as distinct entry
types, so all three readers agree on the file.

The tags exist because a module name (`com.example.demo`, dotted) and a package
name (`com/example/api`, slashed) are **read and compared but never resolved to
a class** -- unlike a `CONSTANT_Class`, whose internal name the loader does
resolve. Encoding a module as a `Class` would break the promise the tag makes.
Over a third of this 24-entry pool exists only to name modules and packages.

### 22. Version history, measured by building rather than recalled

One source file -- a lambda, a method reference, a functional interface and a
string concatenation -- compiled at four release levels:

    release  major  bytes  indy  boots  StringBuilder  NestMembers
        8      52    1608    2      2            10        no
       11      55    1806    4      4             0       yes
       17      61    1806    4      4             0       yes
       21      65    1806    4      4             0       yes

**Java 11 made the file 198 bytes larger.** Not the nest attributes -- a
six-entry `NestMembers` is 14 bytes. It is string concatenation: the Java 8
`StringBuilder` chain was ten instructions and seven pool entries, replaced by
two extra `invokedynamic` instructions, their bootstrap entries and a recipe
`Utf8`. The `StringBuilder` pattern was never a run-time cost -- the JIT had
eliminated it for years -- so the change bought uniformity and cost bytes. This
is the first entry in this record where a number corrected a reasonable
assumption rather than confirming it.

The synthetic methods are **identical in all four releases** --
`lambda$main$0` and `lambda$main$1` -- so the lambda's implementation never got
cheaper; what changed is that it became a bootstrap argument rather than a call
target. `minor_version` was not exercised here and is covered in Module 1.

The one major feature that used **neither** extension mechanism is the
`Module` attribute: it is positional, with five sections in fixed order and no
section ids, so a sixth kind of directive would need a new major version. That
is the honest exception to "the format never needed a new layout", and it is in
the course rather than hidden.

## Harness state after Modules 3-5

    25 class files, 3 readers each, 0 disagreements

`module-info.class` was compiled on this machine from a nine-line
`module-info.java` and added to the set. It is the file that makes finding 21
checkable, and it passes the harness even though `javap` cannot name two of its
pool tags -- which is a useful demonstration that the harness compares structure
and not labels.

The `BootstrapMethods` decoder used for finding 20 is new and was verified
against `javap` on all nine entries of `Lambda.class` and on the attribute
length, which is the check that matters.
