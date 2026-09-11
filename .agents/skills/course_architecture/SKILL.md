# Course Architecture Skill

Load this skill when structuring course content, concept dependencies, or lesson formats.

## Course File Structure

```
courses/
  elf/
    chemical.mod                    (module declaration)
    manifest.json                   (metadata, version, concept list)
    concepts/
      fundamentals/
        bytes.ch                    (concept: Bytes and Binary)
        binary-representation.ch
        file-layout.ch
      elf-header/
        identification.ch
        header-fields.ch
        entry-point.ch
      program-headers/
        header-table.ch
        segment-types.ch
        memory-mapping.ch
      sections/
        section-header.ch
        common-sections.ch
        section-vs-segment.ch
      symbols/
        symbol-table.ch
        binding.ch
        visibility.ch
      relocations/
        relocation-types.ch
        dynamic-section.ch
      dynamic-linking/
        dynamic-section.ch
        libraries.ch
        ld-so.ch
      loading/
        loader.ch
        memory-layout.ch
        execution.ch
    exercises/
      identify-header.ch
      parse-hex.ch
      diagnose-malformed.ch
      ...
    visualizations/
      file-layout.ch
      hex-viewer.ch
      segment-mapping.ch
      ...
    assets/
      samples/
        hello.elf
        libcrypto.so
        malformed.elf
      images/
        elf-layout.svg
        ...
    reviews/
      (generated — not manually created)
```

## Manifest Format

```json
{
  "id": "elf",
  "title": "ELF — Executable and Linkable Format",
  "version": 1,
  "description": "Understand the ELF binary format from first principles",
  "prerequisites": [],
  "estimated_hours": 20,
  "modules": [
    {
      "id": "fundamentals",
      "title": "Fundamentals",
      "order": 1,
      "concepts": ["bytes", "binary-representation", "file-layout"]
    },
    {
      "id": "elf-header",
      "title": "ELF Header",
      "order": 2,
      "concepts": ["identification", "header-fields", "entry-point"]
    }
  ],
  "concepts": [
    {
      "id": "bytes",
      "title": "Bytes and Binary",
      "module": "fundamentals",
      "prerequisites": [],
      "estimated_minutes": 15,
      "importance": "core"
    }
  ],
  "assets": [
    "assets/samples/hello.elf",
    "assets/samples/libcrypto.so"
  ]
}
```

## Concept Dependency Graph (ELF)

```
Bytes
  ↓
Binary Representation
  ↓
File Layout
  ↓
ELF Identification
  ↓
ELF Header Fields
  ↓
Entry Point
  ↓
Program Header Table ──→ Segment Types ──→ Memory Mapping
  ↓
Section Header ──→ Common Sections ──→ Section vs Segment
  ↓
Symbol Table ──→ Binding ──→ Visibility
  ↓
Relocation Types
  ↓
Dynamic Section ──→ Libraries ──→ ld.so
  ↓
Loader ──→ Memory Layout ──→ Execution
```

## Concept File Format

Each concept is a Chemical source file:

```chemical
// concepts/elf-header/identification.ch

package elf_header

// Concept: ELF Identification (Magic Bytes)
// Module: ELF Header
// Prerequisites: bytes, binary-representation, file-layout
// Estimated minutes: 15
// Importance: core

// Sources:
// - gABI specification, "ELF Identification" section
// - https://refspecs.linuxfoundation.org/elf/elf.pdf, p. 4-5

public struct LessonContent {
    var units : vector<LearningUnit>
    var sources : vector<Source>
    var exercises : vector<Exercise>
    var review_items : vector<ReviewItem>

    @make
    public func make() : LessonContent {
        // ... content defined here
    }
}
```

## Learning Unit Format

```chemical
public struct LearningUnit {
    var type : UnitType        // explain, example, show, ask, do, visualize
    var content : string       // The teaching content
    var purpose : string       // Why this unit exists (for AI review)
}

public enum UnitType {
    Explain
    Example
    Show
    Ask
    Do
    Visualize
}
```

## Exercise Format

```chemical
public struct Exercise {
    var id : string
    var type : ExerciseType    // multiple_choice, hex_inspect, debug, etc.
    var difficulty : Difficulty // easy, medium, hard
    var question : string
    var options : vector<Option>   // for multiple choice
    var answer : string
    var explanation : string
    var misconception : string     // what wrong answer this targets
    var time_limit_seconds : int   // 0 = no limit
}

public enum ExerciseType {
    MultipleChoice
    MultipleAnswer
    FillBlank
    HexInspect
    Ordering
    Matching
    Labeling
    Predict
    Debug
    Classify
    Construct
    Explain
}

public struct Option {
    var id : string
    var text : string
    var correct : bool
    var feedback : string      // shown when this option is selected
}
```

## Review Item Format

```chemical
public struct ReviewItem {
    var id : string
    var concept_id : string
    var type : ReviewType      // recall, recognize, apply, explain
    var front : string         // the question or prompt
    var back : string          // the answer
    var difficulty : float     // FSRS difficulty (1-10)
    var stability : float      // FSRS stability (days)
    var retrievability : float // current recall probability (0-1)
    var next_review : date     // when this item is due
}

public enum ReviewType {
    Recall       // "What is X?" (free recall)
    Recognize    // "Which of these is X?" (multiple choice)
    Apply        // "Use X to solve this"
    Explain      // "Explain why X exists"
}
```

## Lesson Structure (8-Unit Pattern)

Every concept follows this structure:

```
1. WHY       (1-2 min)  — Why does this exist?
2. MODEL     (2-3 min)  — Simplified mental model
3. REALITY   (3-5 min)  — Actual technical detail
4. EXAMPLE   (2-3 min)  — Concrete, verifiable example
5. INTERACT  (2-5 min)  — Interactive exercise or visualization
6. RETRIEVE  (1-2 min)  — Active recall question
7. APPLY     (2-5 min)  — Exercise using the knowledge
8. CONNECT   (1 min)    — How this relates to other concepts
```

## Visualization Types

| Type | Use Case | Data |
|---|---|---|
| `diagram` | File layout, memory map | Structured data (offsets, sizes) |
| `hex_viewer` | Byte-level inspection | Raw bytes + field annotations |
| `state_machine` | TLS handshake, linker states | States + transitions |
| `timeline` | Loading process | Ordered events |
| `tree` | Symbol table hierarchy | Nodes + children |
| `code_viewer` | Source + assembly correspondence | Code lines + mappings |

## Course Versioning

| Change Type | Version Bump | Example |
|---|---|---|
| Typo fix | Patch (1.0.x) | Fixed spelling |
| Content correction | Minor (1.x.0) | Fixed incorrect offset |
| New exercise | Minor (1.x.0) | Added debug exercise |
| New concept | Major (x.0.0) | Added DWARF module |
| Restructured prerequisites | Major (x.0.0) | Moved "symbols" before "sections" |

## Portability Rules

1. No platform-specific dependencies in course files
2. No database queries in course files
3. All assets are relative paths
4. Course can be opened by any compatible player
5. Course directory can be zipped and shared
