# Technical Research Skill

Load this skill when researching authoritative sources for course topics or verifying technical claims.

> **Also load `engineering_patterns`** for content validation patterns (source verification, exercise verification, manifest validation). This skill covers *how to research*; `engineering_patterns` covers *how to validate what you found*.

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
