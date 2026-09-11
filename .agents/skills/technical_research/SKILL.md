# Technical Research Skill

Load this skill when researching authoritative sources for course topics or verifying technical claims.

> **Also load `engineering_patterns`** for content validation patterns (source verification, exercise verification, manifest validation). This skill covers *how to research*; `engineering_patterns` covers *how to validate what you found*.

## Quick Start: Verifying One Claim

If you just need to verify a single technical claim:

```
1. Is it in the spec? → Check the relevant section
2. Can you test it? → Run readelf/xxd/objdump on a real file
3. Still unsure? → Check authoritative source code (Linux kernel, binutils)
4. Mark result: VERIFIED / UNVERIFIED / CONFLICTING
```

For the full research process, continue below.

## Source Hierarchy

### Primary Sources (Highest Authority)

| Type | Examples | When to Use |
|---|---|---|
| Official specifications | ELF gABI, RFC 8446 (TLS), ISO standards | Any technical claim about a standard |
| Standards organizations | IEEE, ISO, IETF, W3C | When the spec is the authority |
| Authoritative source code | Linux kernel, GNU binutils, LLVM | When the spec is ambiguous |
| Academic papers | Original algorithm descriptions | For theoretical foundations |
| Formal documentation | Man pages, official docs | For implementation-specific behavior |

### Secondary Sources

| Type | Examples | When to Use |
|---|---|---|
| Reputable books | "Linkers and Loaders" (Levine) | For conceptual explanations |
| High-quality articles | Eli Bendersky's blog, OSDev wiki | For implementation guidance |
| Engineering write-ups | Google security blog, Mozilla dev docs | For real-world context |

### Tertiary Sources (Leads Only, Not Authority)

| Type | Examples | Caution |
|---|---|---|
| Forum posts | Stack Overflow, Reddit | May be outdated or wrong |
| Random blogs | Personal technical blogs | Verify against primary sources |
| AI-generated material | ChatGPT output, AI tutorials | Presumed incorrect until verified |
| Wikipedia | Any article | May be inaccurate for technical details |

## Research Process

### Time-Boxing Guide

| Research Task | Time Limit | What to Do If Time Runs Out |
|---------------|------------|---------------------------|
| Find the specification | 15 min | Use secondary source, mark `[NEEDS SPEC]` |
| Read one spec section | 20 min | Read enough to verify current claims, mark rest `[UNVERIFIED]` |
| Verify one claim | 10 min | Mark `[UNVERIFIED]`, move on |
| Verify hex bytes | 5 min | Run readelf/xxd, copy real output |
| Check conflicting sources | 15 min | Use spec as authority, note conflict |

**Rule:** Never spend more than 30 minutes researching one concept. If you can't verify something in 30 minutes, mark it `[UNVERIFIED]` and move on.

### Step 1: Identify the Specification

For any technical topic, find the authoritative specification:

| Topic | Primary Source |
|---|---|
| ELF | gABI specification (elf.pdf) |
| PE | Microsoft PE/COFF specification |
| Mach-O | Apple Mach-O ABI reference |
| TLS | RFC 8446 (TLS 1.3), RFC 5246 (TLS 1.2) |
| PDF | ISO 32000-2 (PDF 2.0) |
| MP4 | ISO 14496-12 (ISOBMFF) |
| HTTP | RFC 9110 (HTTP semantics) |
| DNS | RFC 1035 (DNS) |
| TCP | RFC 793 (TCP), RFC 9293 (updated) |

### Step 2: Read the Relevant Section

Don't just cite the specification — READ the relevant section. Note:
- Exact section number
- Exact wording of relevant definitions
- Any version-specific behavior
- Any architecture-specific behavior
- Any implementation-specific behavior

### Step 3: Verify Against Implementation

Check how authoritative implementations handle this:
- Linux kernel source (for ELF loading)
- GNU binutils (for ELF manipulation)
- LLVM/Clang (for compiler output)
- System V ABI (for calling conventions)

### Step 4: Document the Source

For every technical claim, record:

```json
{
  "claim": "The ELF header starts with bytes 0x7f 0x45 0x4c 0x46",
  "source": {
    "type": "specification",
    "title": "System V Application Binary Interface",
    "section": "ELF Identification",
    "version": "1.1",
    "url": "https://refspecs.linuxfoundation.org/elf/elf.pdf",
    "page": "4-5",
    "accessed": "2026-09-11"
  },
  "verified": true,
  "version_specific": false,
  "architecture_specific": false,
  "implementation_specific": false
}
```

## Verification Checklist

For every technical claim in course content:

- [ ] Is this in the specification? Which section?
- [ ] Is this version-specific? Which version?
- [ ] Is this architecture-specific? Which architecture?
- [ ] Is this implementation-specific? Which implementation?
- [ ] Are byte layouts, offsets, and sizes correct?
- [ ] Does the example actually work?
- [ ] Are there edge cases I'm hiding?
- [ ] Is the terminology correct per the specification?
- [ ] Could an expert find errors here?

## Common Research Pitfalls

### 1. "Linux does X, therefore the specification requires X"

Linux's behavior is often a subset of what the specification allows. Teach the specification, note Linux's behavior as implementation detail.

### 2. "The specification says X" (without reading it)

Don't cite the specification unless you've actually read the relevant section. Specifications are often more nuanced than people assume.

### 3. "This is how it works" (version unspecified)

Many standards have evolved. Always note which version you're teaching.

### 4. "Everyone knows X"

If you can't find a primary source for a claim, it may be wrong or outdated. Verify.

### 5. Inventing plausible-looking data

Never invent byte sequences, offsets, or field names. Every example must be verifiable.

## Handling Conflicting Sources

When sources disagree, use this resolution process:

### Conflict Resolution Priority

| Priority | Source Type | Example |
|----------|------------|---------|
| 1 (highest) | Official specification | gABI spec, RFC |
| 2 | Authoritative source code | Linux kernel, GNU binutils |
| 3 | Reputable books | "Linkers and Loaders" |
| 4 | High-quality articles | Eli Bendersky's blog |
| 5 (lowest) | Forum posts, random blogs | Stack Overflow |

### Resolution Process

```
1. Identify the conflict
   Source A says X, Source B says Y

2. Check source priority
   Is Source A higher priority than Source B?
   → If yes, trust Source A, note the conflict

3. Both same priority?
   → Check if one is more specific/recent
   → Check if they're actually talking about the same thing

4. Still unresolved?
   → Mark as [CONFLICTING — NEEDS RESOLUTION]
   → Note both positions in research.md
   → Do NOT teach either version as fact

5. Check implementation
   → Run readelf/xxd to see what actually happens
   → Implementation may resolve the spec ambiguity
```

### Example: Conflicting ELF Header Size

```
Conflict:
- Some sources say "ELF header is 52 bytes"
- Others say "ELF header is 64 bytes"

Resolution:
- gABI spec: ELF32 header = 52 bytes, ELF64 header = 64 bytes
- Both are correct — they're different ELF classes
- Course content: "The ELF header is 52 bytes for ELF32, 64 bytes for ELF64"
```

### Example: Conflicting Entry Point

```
Conflict:
- Some sources say "entry point is main()"
- Others say "entry point is _start"

Resolution:
- gABI spec: e_entry is the virtual address of the entry point
- Linux: e_entry points to _start (in crt1.o), which calls __libc_start_main, which calls main
- Both are correct at different levels of abstraction
- Course content: "The entry point is _start (not main). _start calls __libc_start_main, which calls your main()."
```

## Verification Workflow Examples

### Example 1: Verifying ELF Magic Bytes

```
Claim: "The ELF magic number is 7f 45 4c 46"

Step 1: Check the specification
  gABI spec §1-2: "e_ident[EI_MAG0] through e_ident[EI_MAG3]"
  → "0x7f 'E' 'L' 'F'"
  → VERIFIED

Step 2: Check implementation
  $ readelf -h /bin/ls | grep Magic
  → "Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00"
  → CONFIRMED

Step 3: Record
  Claim: VERIFIED
  Sources: gABI §1-2, readelf output
```

### Example 2: Verifying ELF Header Size

```
Claim: "The ELF header is 64 bytes"

Step 1: Check the specification
  gABI spec: "The ELF header is 52 bytes for ELF32, 64 bytes for ELF64"
  → PARTIALLY VERIFIED (needs class distinction)

Step 2: Check implementation
  $ readelf -h /bin/ls
  → Class: ELF64
  $ xxd -l 64 /bin/ls | tail -1
  → Confirms 64 bytes visible

Step 3: Revise claim
  Original: "The ELF header is 64 bytes"
  Revised: "The ELF header is 64 bytes for ELF64 (52 bytes for ELF32)"
  → VERIFIED with correction
```

### Example 3: Verifying a Questionable Claim

```
Claim: "The entry point is always at the beginning of the .text section"

Step 1: Check the specification
  gABI spec: e_entry is the "virtual address of the entry point"
  → Doesn't say it's in .text

Step 2: Check implementation
  $ readelf -l /bin/ls | grep -A1 LOAD
  → Entry point may be in a different segment

Step 3: Check source code
  Linux fs/binfmt_elf.c: starts at e_entry
  → e_entry can be anywhere, not necessarily .text start

Step 4: Record
  Claim: REFUTED
  Correct: "The entry point (e_entry) can be anywhere in the executable"
  → Mark as [NEEDS VERIFICATION] for specific examples
```

## ELF Research Guide

### Primary Source

The ELF specification is the "System V Application Binary Interface" (gABI), maintained by SCO Group (now part of other entities). The most accessible version is:

- PDF: https://refspecs.linuxfoundation.org/elf/elf.pdf
- HTML: https://man7.org/linux/man-pages/man5/elf.5.html (man page, not full spec)

### Key Sections

| Section | Topic |
|---|---|
| 1-2 | Object files, ELF header |
| 3 | Program header table (segments) |
| 4 | Section header table (sections) |
| 5 | Symbol table, relocations |
| 6 | Dynamic linking |
| 7-8 | Special sections, relocation types |

### Version History

- ELF was originally specified in the System V ABI (1988)
- Extended by Linux, BSD, and others
- The gABI is the "generic" ABI, Linux follows it closely
- There's no single "version number" — it evolves through addenda

### Verification Sources

- Linux kernel: `fs/binfmt_elf.c` (loader), `include/uapi/linux/elf.h` (definitions)
- GNU binutils: `binutils/readelf.c` (parser), `binutils/objcopy.c` (manipulator)
- LLVM: `llvm/Object/ELF.h` (type definitions), `llvm/CodeGen/ELF.h` (code generation)

## Documentation Template

For each concept in the course, create a research document:

```markdown
# [Concept Name]

## Claims to Verify

1. [claim]
   - Source: [specification section]
   - Verified: [yes/no]
   - Notes: [any caveats]

## Examples to Verify

1. [example]
   - How to verify: [command/tool]
   - Expected result: [what should happen]

## Edge Cases

1. [edge case]
   - Source: [where this is documented]
   - Behavior: [what happens]

## Common Misconceptions

1. [misconception]
   - Reality: [what's actually true]
   - Source: [specification reference]
```
