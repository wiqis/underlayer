# Correctness Verification System

This document defines how Underlayer verifies that course content is technically correct before publication.

---

## The Problem

When teaching low-level subjects (ELF, TLS, linkers), a single incorrect byte offset, wrong field name, or misleading explanation can teach wrong knowledge. Students will complain. Issues will pile up on GitHub. Trust will be lost.

**We must verify everything against authoritative sources.**

---

## Verification Layers

```
Layer 1: Source Grounding (during generation)
  ↓
Layer 2: Automated Verification (CI pipeline)
  ↓
Layer 3: Conformance Testing (against reference implementations)
  ↓
Layer 4: Human Review (mandatory gate)
  ↓
Layer 5: Community Verification (post-publication)
```

---

## Layer 1: Source Grounding (During Generation)

Every factual claim must trace to a source before it enters the course.

### Source Registry

```json
{
  "sources": {
    "gabi": {
      "title": "System V Application Binary Interface",
      "url": "https://refspecs.linuxfoundation.org/elf/elf.pdf",
      "type": "specification",
      "version": "1.1"
    },
    "rfc8446": {
      "title": "The Transport Layer Security (TLS) Protocol Version 1.3",
      "url": "https://www.rfc-editor.org/rfc/rfc8446",
      "type": "rfc",
      "version": "August 2018"
    },
    "linux_kernel": {
      "title": "Linux Kernel Source",
      "url": "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git",
      "type": "reference_implementation",
      "version": "6.x"
    }
  }
}
```

### Claim Format

Every factual claim in course content must have:

```json
{
  "claim": "The ELF header is 64 bytes in ELF64",
  "source": "gabi",
  "section": "ELF Header",
  "page": "4-5",
  "verified": true,
  "scope": "portable",
  "confidence": "high"
}
```

### Unverified Claims

Claims without a source are marked `[UNVERIFIED]` and MUST NOT be published until verified.

---

## Layer 2: Automated Verification (CI Pipeline)

### What Gets Verified

| Content Type | Verification Method | Tool |
|---|---|---|
| Code examples | Compilation test | gcc, rustc, cpython |
| Hex dumps | Binary comparison | xxd + diff |
| ELF structures | Structure validation | readelf + validator |
| Byte offsets | Specification check | Automated offset validator |
| Output claims | Golden file test | pytest + fixtures |
| API usage | Deprecation check | semgrep, pylint |

### CI Pipeline

```yaml
name: Verify Course Content

on: [push, pull_request]

jobs:
  extract-and-verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Extract code examples
        run: |
          python scripts/extract_code_blocks.py \
            --input courses/ \
            --output examples/
      
      - name: Verify code compiles
        run: |
          for f in examples/c/*.c; do
            gcc -Wall -Werror -c "$f" -o /dev/null || exit 1
          done
      
      - name: Verify hex dumps
        run: |
          python scripts/verify_hex_dumps.py --dir courses/
      
      - name: Verify ELF structures
        run: |
          for f in examples/elf/*.o; do
            readelf -h "$f" > /dev/null || exit 1
            python scripts/verify_elf.py "$f"
          done
      
      - name: Verify byte offsets
        run: |
          python scripts/verify_offsets.py \
            --spec specs/ \
            --examples examples/
```

### Code Example Extraction

```python
def extract_code_blocks(course_dir: Path) -> list[CodeBlock]:
    """Extract all code blocks from course content."""
    blocks = []
    for ch_file in course_dir.rglob("*.ch"):
        content = ch_file.read_text()
        # Extract between ``` markers
        for match in re.finditer(r'```(\w+)\n(.*?)```', content, re.DOTALL):
            blocks.append(CodeBlock(
                language=match.group(1),
                code=match.group(2),
                source_file=str(ch_file),
                line_number=content[:match.start()].count('\n') + 1
            ))
    return blocks
```

### Verification Script

```python
def verify_code_block(block: CodeBlock, work_dir: Path) -> VerificationResult:
    """Verify a code block compiles and runs correctly."""
    
    if block.language == 'c':
        source = work_dir / 'test.c'
        source.write_text(block.code)
        
        # Compile
        result = subprocess.run(
            ['gcc', '-Wall', '-Werror', '-o', str(work_dir / 'test'), str(source)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            return VerificationResult(
                status='FAILED',
                error=f"Compilation failed: {result.stderr}",
                block=block
            )
        
        # Run if expected output exists
        if block.expected_output:
            result = subprocess.run(
                [str(work_dir / 'test')],
                capture_output=True, text=True
            )
            if result.stdout.strip() != block.expected_output.strip():
                return VerificationResult(
                    status='FAILED',
                    error=f"Output mismatch: expected {block.expected_output}, got {result.stdout}",
                    block=block
                )
        
        return VerificationResult(status='PASSED', block=block)
```

---

## Layer 3: Conformance Testing

### ELF Conformance

```python
def verify_elf_example(elf_path: Path, spec: ELFSpec) -> list[Issue]:
    """Verify an ELF binary against the specification."""
    issues = []
    data = elf_path.read_bytes()
    
    # Verify magic bytes
    if data[0:4] != b'\x7fELF':
        issues.append(Issue('CRITICAL', 'Invalid ELF magic bytes'))
    
    # Verify header size
    elf_class = data[4]
    if elf_class == 2:  # ELF64
        expected_size = 64
    else:
        expected_size = 52
    
    e_ehsize = struct.unpack('<H', data[52:54])[0]
    if e_ehsize != expected_size:
        issues.append(Issue('CRITICAL', f'Header size wrong: {e_ehsize} != {expected_size}'))
    
    # Verify program headers
    if elf_class == 2:
        e_phoff = struct.unpack('<Q', data[32:40])[0]
        e_phnum = struct.unpack('<H', data[56:58])[0]
        e_phentsize = struct.unpack('<H', data[54:56])[0]
        
        if e_phoff > 0:
            expected_phentsize = 56  # ELF64 Phdr size
            if e_phentsize != expected_phentsize:
                issues.append(Issue('CRITICAL', f'Phdr size wrong: {e_phentsize}'))
            
            if e_phoff + (e_phnum * e_phentsize) > len(data):
                issues.append(Issue('CRITICAL', 'Program headers extend beyond file'))
    
    return issues
```

### TLS Conformance

```python
def verify_tls_handshake(handshake: TLSHandshake, rfc: RFCSpec) -> list[Issue]:
    """Verify TLS handshake against RFC 8446."""
    issues = []
    
    # Verify ClientHello format
    if handshake.type != 0x01:
        issues.append(Issue('CRITICAL', f'ClientHello type wrong: {handshake.type}'))
    
    # Verify supported versions
    if 0x0304 not in handshake.supported_versions:
        issues.append(Issue('MAJOR', 'TLS 1.3 not in supported_versions'))
    
    # Verify cipher suites
    if 0x1301 not in handshake.cipher_suites:
        issues.append(Issue('MAJOR', 'TLS_AES_128_GCM_SHA256 not offered'))
    
    # Verify key share
    if not handshake.has_key_share_for(0x0017):  # P-256
        issues.append(Issue('MAJOR', 'No key share for P-256'))
    
    return issues
```

### Reference Implementation Comparison

```python
def differential_test(test_input: bytes, implementations: dict) -> DifferentialResult:
    """Run same input through multiple implementations, compare outputs."""
    results = {}
    for name, impl in implementations.items():
        results[name] = impl(test_input)
    
    # Check for disagreements
    outputs = list(results.values())
    if len(set(str(o) for o in outputs)) > 1:
        return DifferentialResult(
            status='MISMATCH',
            results=results,
            description='Implementations disagree on output'
        )
    
    return DifferentialResult(status='AGREEMENT', results=results)
```

---

## Layer 4: Human Review

### Review Checklist

For every course module before publication:

**Technical Accuracy**
- [ ] Spot-check 5 technical claims against specification
- [ ] Verify 2 code examples compile and run
- [ ] Verify hex dumps match real binaries
- [ ] Check byte offsets against specification
- [ ] Verify field names and sizes are correct

**Pedagogical Quality**
- [ ] Read one lesson as a beginner — is it confusing?
- [ ] Check exercises for correctness
- [ ] Verify explanations are accurate
- [ ] Check for hidden assumptions

**Source Verification**
- [ ] Verify no hallucinated sources
- [ ] Check source citations are accurate
- [ ] Verify specification sections exist

### Review Tools

```bash
# Extract claims from course content
python scripts/extract_claims.py --input courses/elf/ --output claims.json

# Verify claims against specification
python scripts/verify_claims.py --claims claims.json --spec gabi.pdf

# Generate review report
python scripts/generate_review_report.py --claims claims.json --output review.md
```

---

## Layer 5: Community Verification

### Post-Publication

After a course is published:
1. Users can flag incorrect content via "Report Issue" button
2. Issues are tracked in GitHub
3. Maintainers verify and fix
4. Course version bumps on correction

### Report Issue UI

```
┌─────────────────────────────────────────┐
│  Report an Issue                        │
│  ─────────────────────                  │
│                                         │
│  What's wrong?                          │
│                                         │
│  [ ] Incorrect information              │
│  [ ] Outdated information               │
│  [ ] Code example doesn't work          │
│  [ ] Confusing explanation              │
│  [ ] Other                              │
│                                         │
│  Details:                               │
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Submit Report]                        │
│                                         │
└─────────────────────────────────────────┘
```

---

## The "i" Button Verification Display

Every factual claim can show verification status on hover.

### What It Shows

```
┌─────────────────────────────────────────┐
│  Source                                  │
│  gABI specification, ELF Identification  │
│  section, p. 4-5                        │
│                                         │
│  Verification Status                     │
│  ✓ Verified with readelf on Linux 6.1   │
│  ✓ Correct per ELF64 and ELF32          │
│  ✓ Byte offsets match specification     │
│                                         │
│  Scope                                   │
│  Portable — applies to all ELF systems  │
│                                         │
│  Last Verified                           │
│  2026-09-11                             │
│                                         │
│  [Open specification section]            │
│  [Report issue]                         │
└─────────────────────────────────────────┘
```

### Verification Badges

| Badge | Meaning |
|---|---|
| ✓ Verified | Checked against specification and reference implementation |
| ⚠ Partial | Some aspects verified, others need checking |
| ✗ Unverified | Not yet checked (should not appear on published content) |
| 🔒 Spec-only | Verified against specification only (not implementation-tested) |

---

## Verification Tracking

### Per-Claim Tracking

```json
{
  "claim_id": "elf-header-size-64",
  "claim": "The ELF header is 64 bytes in ELF64",
  "source": "gabi",
  "section": "ELF Header",
  "verification": {
    "spec_check": {
      "status": "passed",
      "spec_section": "ELF Header",
      "spec_page": "4-5"
    },
    "implementation_check": {
      "status": "passed",
      "tool": "readelf",
      "version": "2.41",
      "platform": "Linux 6.1",
      "date": "2026-09-11"
    },
    "property_check": {
      "status": "passed",
      "test": "header_size_matches_class"
    }
  },
  "last_verified": "2026-09-11",
  "verified_by": "automated_pipeline"
}
```

### Verification Report

```markdown
# Verification Report: ELF Course v1.0

## Summary
- Total claims: 156
- Verified: 152 (97.4%)
- Unverified: 4 (2.6%)
- Failed: 0

## By Category
| Category | Total | Verified | Failed |
|---|---|---|---|
| ELF Header | 32 | 32 | 0 |
| Program Headers | 28 | 28 | 0 |
| Sections | 25 | 25 | 0 |
| Symbols | 22 | 22 | 0 |
| Relocations | 18 | 18 | 0 |
| Dynamic Linking | 15 | 15 | 0 |
| Loading | 16 | 12 | 0 |

## Unverified Claims
1. "The loader uses mmap for all segments" — needs Linux kernel verification
2. "ET_DYN is used for PIE" — needs specification check
3. ...

## Code Examples
- Total: 24
- Compile: 24/24 (100%)
- Run correctly: 22/24 (91.7%)
- Failed: 2 (need fixing)
```

---

## Implementation Priority

### Phase 1 (MVP)
- Source grounding during generation
- Basic CI pipeline (compilation check)
- Human review checklist
- Verification badges on content

### Phase 2
- Automated hex dump verification
- ELF structure validation
- Property-based testing
- Verification tracking database

### Phase 3
- TLS conformance testing
- Differential testing against reference implementations
- Community reporting system
- Automated verification reports

### Phase 4
- Fuzzing for specification violations
- Model checking for protocol compliance
- Cross-platform verification matrix
- Real-time verification status dashboard
