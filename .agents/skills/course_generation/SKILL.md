# Course Generation Skill

Load this skill when using AI to generate course content.

> **Also load `course_writing`** for the practical, in-the-trenches guide to writing .ch files: common mistakes, Chemical syntax patterns, exercise patterns, and verification checklists. This skill covers *the 11-phase process*; `course_writing` covers *how to actually write each file*.

> **Also load `technical_research`** for how to find and verify authoritative sources. This skill covers *the generation process*; `technical_research` covers *how to research each topic*.

> **Also load `engineering_patterns`** for content validation patterns (manifest validation, concept file validation, exercise verification). This skill covers *how to generate*; `engineering_patterns` covers *how to validate what you generated*.

## Quick Start: Generating a Single Concept

If you already have research and just need to generate one concept's content, use this abbreviated flow:

```
1. Load research.md for the concept
2. Load course_writing skill
3. Write the .ch file following the 8-unit structure
4. Verify hex bytes with readelf/xxd
5. Run through the verification checklist in course_writing
```

For the full 11-phase process (new course or major revision), continue below.

## The Iterative Generation Cycle

AI must never generate a course in one pass. The required cycle:

```
Phase A: Research
  Study authoritative sources
  ↓
Phase B: Knowledge Extraction
  Identify concepts, facts, dependencies, edge cases, misconceptions
  ↓
Phase C: Curriculum Design
  Determine order of concepts
  ↓
Phase D: Learning Design
  Determine how each concept is learned, recalled, applied
  ↓
Phase E: Content Generation
  Generate actual course material
  ↓
Phase F: Technical Verification
  Check against authoritative sources
  ↓
Phase G: Pedagogical Critique
  Does the course actually teach effectively?
  ↓
Phase H: Interaction Review
  Do interactive elements genuinely improve learning?
  ↓
Phase I: Consistency Review
  Look for contradictions across the course
  ↓
Phase J: Final Review
  Attempt to find weaknesses in the entire course
  ↓
Phase K: Revision
  Fix identified problems
```

Each phase produces artifacts. The next phase consumes them. No skipping.

### Time Estimates (per concept)

| Phase | Time | Can Skip? |
|-------|------|-----------|
| A: Research | 30-60 min | No — foundation for everything |
| B: Knowledge Extraction | 15-30 min | No — identifies misconceptions |
| C: Curriculum Design | 10-20 min | Only if concept order is already defined |
| D: Learning Design | 20-40 min | No — determines teaching approach |
| E: Content Generation | 60-120 min | No — the actual writing |
| F: Technical Verification | 30-60 min | No — prevents wrong knowledge |
| G: Pedagogical Critique | 15-30 min | No — prevents bad teaching |
| H: Interaction Review | 10-20 min | If no interactive elements |
| I: Consistency Review | 10-20 min | Only for single-concept additions |
| J: Final Review | 15-30 min | No — last quality gate |
| K: Revision | 30-60 min | Only if reviews found no issues |

### Common Failure Modes

| Failure | Symptom | Prevention |
|---------|---------|------------|
| Skipping research | Invented byte sequences, wrong offsets | Always read the spec first |
| Skipping verification | Content looks good but teaches wrong facts | Always run Phase F |
| One-pass generation | Technically correct but pedagogically flat | Follow all 11 phases |
| No misconception targeting | Learners hit the same wall repeatedly | Always do Phase B |
| Over-explaining | 500 words for a 100-word concept | Apply "Would I read this?" test |

## Phase A: Research

### Input
- Topic name (e.g., "ELF Header")
- Authoritative sources (from `technical_research` skill)

### Process
1. Read the relevant specification section
2. Read 2-3 authoritative secondary sources
3. Read relevant source code (if applicable)
4. Note all facts, definitions, and constraints
5. Note version-specific and architecture-specific behavior

### Output
- `research.md` — verified facts with sources

#### research.md Template

```markdown
# Research: [Concept Name]

## Specification Claims

| # | Claim | Spec Section | Version Notes | Verified |
|---|-------|-------------|---------------|----------|
| 1 | [claim] | [section] | [any version specifics] | [yes/no] |

## Secondary Sources

| Source | Type | Key Points | Reliability |
|--------|------|-----------|-------------|
| [title] | book/article/blog | [what it covers] | high/medium/low |

## Edge Cases

| Case | Behavior | Source |
|------|----------|--------|
| [case] | [what happens] | [reference] |

## Version-Specific Behavior

| Feature | Version | Behavior |
|---------|---------|----------|
| [feature] | [version] | [how it differs] |

## Unverified Claims

- [ ] [claim that needs verification]
```

## Phase B: Knowledge Extraction

### Input
- `research.md` from Phase A

### Process
1. List all concepts that need to be taught
2. For each concept, identify:
   - What it is (definition)
   - Why it exists (purpose)
   - Who produces it
   - Who consumes it
   - What depends on it
   - What happens if it's invalid
   - What happens if it's missing
   - Edge cases
3. Identify prerequisites for each concept
4. Identify likely misconceptions

### Output
- `concepts.json` — concept list with dependencies and misconceptions

#### concepts.json Template

```json
{
  "concepts": [
    {
      "id": "elf-header",
      "title": "The ELF Header",
      "definition": "The first structure in an ELF file, at byte 0",
      "purpose": "Tells the system how to process the entire file",
      "who_produces": "Compiler/linker",
      "who_consumes": "Loader, debugger, readelf",
      "depends_on": ["bytes", "binary-representation"],
      "if_invalid": "Loader rejects the file immediately",
      "if_missing": "File cannot be processed at all",
      "edge_cases": ["32-bit vs 64-bit size difference", "Big vs little endian"],
      "misconceptions": [
        {
          "wrong": "The ELF header is just metadata you can skip",
          "right": "It's parsed first and determines how to read everything else",
          "exercise_target": "Ask what happens if e_phoff is wrong"
        }
      ],
      "estimated_minutes": 15
    }
  ]
}
```

## Phase C: Curriculum Design

### Input
- `concepts.json` from Phase B

### Process
1. Topologically sort concepts by prerequisites
2. Group into modules (logical clusters)
3. Estimate time per concept
4. Identify the knowledge dependency graph
5. Check for prerequisite avalanches (too many prerequisites for one concept)

### Output
- `curriculum.json` — ordered concept list with modules

#### curriculum.json Template

```json
{
  "modules": [
    {
      "id": "fundamentals",
      "title": "Binary Fundamentals",
      "order": 1,
      "concepts": ["bytes", "binary-representation", "file-layout"],
      "estimated_minutes": 45,
      "prerequisite_modules": []
    },
    {
      "id": "elf-header",
      "title": "The ELF Header",
      "order": 2,
      "concepts": ["identification", "header-fields", "entry-point"],
      "estimated_minutes": 45,
      "prerequisite_modules": ["fundamentals"]
    }
  ],
  "dependency_graph": {
    "bytes": [],
    "binary-representation": ["bytes"],
    "elf-header": ["bytes", "binary-representation", "file-layout"]
  }
}
```

## Phase D: Learning Design

### Input
- `curriculum.json` from Phase C
- `concepts.json` from Phase B

### Process
For each concept, design:
1. The 8-unit lesson structure (WHY → MODEL → REALITY → EXAMPLE → INTERACT → RETRIEVE → APPLY → CONNECT)
2. Exercise types and difficulty progression
3. Review item generation patterns
4. Visualization concepts
5. Misconception-targeting exercises

### Output
- `learning-design.json` — per-concept learning plans

#### learning-design.json Template

```json
{
  "concepts": [
    {
      "id": "elf-header",
      "lesson_structure": {
        "WHY": "How does readelf -h know where program headers are? The ELF header at byte 0 points to everything.",
        "MODEL": "The header says: this is ELF, this is 64-bit, here's where program headers start.",
        "REALITY": "64 bytes for ELF64, 52 for ELF32. Contains e_ident, e_type, e_machine, etc.",
        "EXAMPLE": "Real hex dump of /bin/ls first 64 bytes",
        "INTERACT": "Run xxd -l 64 /bin/ls, find offset 4",
        "RETRIEVE": "What field points to program headers?",
        "APPLY": "Corrupt e_phoff in a hex editor, run readelf",
        "CONNECT": "Next: Program Headers (what e_phoff points to)"
      },
      "exercises": [
        {
          "type": "recall",
          "question": "What is the ELF magic number?",
          "answer": "7f 45 4c 46",
          "misconception_targeted": null
        },
        {
          "type": "recognize",
          "question": "Which field indicates 32-bit vs 64-bit?",
          "answer": "e_ident[EI_CLASS] at offset 4",
          "misconception_targeted": "All ELF headers are the same size"
        },
        {
          "type": "apply",
          "question": "Given this hex dump, identify the class and endianness",
          "answer": "Class at offset 4, endianness at offset 5",
          "misconception_targeted": "ELF fields are in random positions"
        },
        {
          "type": "debug",
          "question": "readelf says 'invalid magic number' — what's wrong?",
          "answer": "First 4 bytes are not 7f 45 4c 46",
          "misconception_targeted": "Magic number is optional"
        }
      ],
      "review_items": 6,
      "visualization": "Interactive hex viewer highlighting ELF header fields"
    }
  ]
}
```

## Phase E: Content Generation

### Input
- `learning-design.json` from Phase D
- `research.md` from Phase A

### Process
Generate for each concept:
1. Lesson content (learning units)
2. Exercises (with verified answers)
3. Review items (with front/back)
4. Visualization descriptions

### Generation Prompt Template

```
You are generating content for the Underlayer learning platform.

SUBJECT: [concept name]
PREREQUISITES: [concepts the learner already knows]
SPECIFICATION: [relevant spec section]

CONSTRAINTS:
1. Explain WHY this concept exists before WHAT it is
2. Provide a simplified model, explicitly marked as simplified
3. Then provide the actual technical detail
4. Include a concrete, verifiable example
5. End with a retrieval question (no hints)
6. Include one exercise targeting a specific misconception
7. Cite the specification section for every technical claim
8. Never invent byte sequences, offsets, or field names

Generate:
- Lesson content (8 learning units)
- 1 visualization concept
- 4 exercises (1 recall, 1 recognize, 1 apply, 1 debug)
- 6 review items (2 recall, 2 recognize, 1 apply, 1 explain)
```

### Output
- `content/` directory with `.ch` files for each concept

## Phase F: Technical Verification

### Input
- `content/` from Phase E
- `research.md` from Phase A

### Process
For each concept:
1. Check every technical claim against the specification
2. Verify byte layouts, offsets, sizes
3. Test examples (compile, run, verify output)
4. Check exercises for correctness
5. Mark unverified claims as `[UNVERIFIED]`

### Verification Prompt Template

```
You are verifying course content for technical accuracy.

CONTENT: [the content to verify]
SPECIFICATION: [the relevant spec]

CHECK:
1. Is every technical claim supported by the specification?
2. Are byte layouts, offsets, and sizes correct?
3. Does the example actually work?
4. Are there edge cases hidden by simplification?
5. Is the terminology correct per the specification?

OUTPUT:
- List of verified claims (with spec section)
- List of unverified claims
- List of potential errors
- List of simplifications that need noting
```

### Output
- `verification.md` — list of verified/unverified/potential-error claims

#### verification.md Template

```markdown
# Technical Verification: [Concept Name]

## Verified Claims

| # | Claim | Spec Section | How Verified |
|---|-------|-------------|--------------|
| 1 | ELF magic is 7f 45 4c 46 | gABI §1-2 | Read spec + readelf output |

## Unverified Claims

| # | Claim | Why Unverified | Action Needed |
|---|-------|---------------|---------------|
| 1 | [claim] | [reason] | [what to do] |

## Potential Errors

| # | Issue | Location | Severity | Fix |
|---|-------|----------|----------|-----|
| 1 | [issue] | [file:line] | critical/major/minor | [how to fix] |

## Simplifications Noted

| # | Simplification | Where | Replacement Model |
|---|----------------|-------|-------------------|
| 1 | [what's simplified] | [location] | [accurate version] |
```

## Phase G: Pedagogical Critique

### Input
- `content/` from Phase E
- `verification.md` from Phase F

### Process
1. Does every concept explain WHY?
2. Does it build a mental model before demanding memorization?
3. Does it connect to other concepts?
4. Is complexity broken into digestible pieces?
5. Does it include active recall?
6. Are exercises testing understanding, not just recognition?
7. Is the pacing appropriate for anxiety-friendly learning?

### Output
- `pedagogy-review.md` — list of pedagogical issues and fixes

#### pedagogy-review.md Template

```markdown
# Pedagogical Review: [Concept Name]

## Issues Found

| # | Issue | Location | Severity | Fix |
|---|-------|----------|----------|-----|
| 1 | No WHY before WHAT | Unit 1 | critical | Add problem statement before definition |
| 2 | Passive reading section | Unit 3 | major | Convert to exercise |

## Checklist Results

- [x] Every concept explains WHY
- [ ] Mental models precede technical details
- [x] Simplifications are explicitly marked
- [x] Active recall included
- [ ] Exercises test understanding
- [x] Feedback explains WHY
```

## Phase H: Interaction Review

### Input
- `content/` from Phase E
- `pedagogy-review.md` from Phase G

### Process
For each interactive element:
1. Does this help the learner understand something?
2. Is it better than a non-interactive alternative?
3. Does it provide useful feedback?
4. Is it accessible?

### Output
- `interaction-review.md` — list of interaction quality issues

#### interaction-review.md Template

```markdown
# Interaction Review: [Concept Name]

## Interactive Elements

| # | Element | Type | Purpose | Verdict |
|---|---------|------|---------|---------|
| 1 | Hex byte click | exercise | Test offset knowledge | Good — tests understanding |
| 2 | Toggle hex dump | decoration | None | Remove — no learning value |

## Questions

| # | Element | Question | Answer |
|---|---------|----------|--------|
| 1 | [element] | Does this help understand something? | [yes/no + what] |
| 2 | [element] | Is it better than non-interactive? | [yes/no + why] |
```

## Phase I: Consistency Review

### Input
- All previous outputs

### Process
1. No contradictions between sections
2. Terminology is consistent
3. Prerequisites are established in order
4. Simplifications are explicitly marked
5. No concept introduced without prerequisites

### Output
- `consistency-review.md` — list of inconsistencies

#### consistency-review.md Template

```markdown
# Consistency Review

## Contradictions

| # | Section A | Section B | Issue | Correct Version |
|---|-----------|-----------|-------|-----------------|
| 1 | bytes.ch:15 | elf-header.ch:23 | Different byte counts | [which is right] |

## Inconsistent Terminology

| # | Term Used | Where | Consistent Term |
|---|-----------|-------|-----------------|
| 1 | "header struct" | elf-header.ch:10 | "ELF header" |

## Prerequisite Violations

| # | Concept | Prerequisite Used | Where | Fix |
|---|---------|-------------------|-------|-----|
| 1 | [concept] | [prerequisite] | [location] | Move or add prerequisite section |
```

## Phase J: Final Review

### Input
- All previous outputs

### Process
Assume the role of:
1. Domain expert — find technical errors
2. Skeptical teacher — find pedagogical weaknesses
3. Beginner — find confusion points
4. Test author — find ambiguous exercises

### Output
- `final-review.md` — list of remaining issues

#### final-review.md Template

```markdown
# Final Review: [Concept Name]

## As Domain Expert

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | [issue] | critical/major/minor | [fix] |

## As Skeptical Teacher

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | [issue] | critical/major/minor | [fix] |

## As Beginner

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | [issue] | critical/major/minor | [fix] |

## As Test Author

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | [issue] | critical/major/minor | [fix] |

## Summary

- Critical: [N] (must fix)
- Major: [N] (should fix)
- Minor: [N] (note for future)
```

## Phase K: Revision

### Input
- All review outputs

### Process
1. Fix all critical issues
2. Fix all major issues
3. Note minor issues for future improvement
4. Re-verify fixed content

### Output
- Revised `content/` directory
- `revision-log.md` — what was changed and why

#### revision-log.md Template

```markdown
# Revision Log: [Concept Name]

## Changes Made

| # | Issue Fixed | File | Line | Change | Verified |
|---|-------------|------|------|--------|----------|
| 1 | [issue from review] | [file] | [line] | [what changed] | [yes/no] |

## Re-verification Results

| # | Previous Issue | Status | Evidence |
|---|---------------|--------|----------|
| 1 | [issue] | Fixed / Still broken / New issue | [proof] |

## Remaining Issues

- [ ] [minor issue deferred to future revision]
```

## Quality Gates

Before content is published, ALL gates must pass:

| Gate | Check |
|---|---|
| Technical Accuracy | All claims verified against authoritative sources |
| Pedagogical Effectiveness | Every concept explains WHY, includes active recall |
| Consistency | No contradictions, consistent terminology |
| Completeness | Every concept has exercises and review items |
| Adversarial Review | Self-critique completed, weakest points fixed |

## AI Role Constraints

The AI must perform these roles during generation:

| Role | Focus |
|---|---|
| Teacher | Design explanations and learning experiences |
| Researcher | Study specifications, standards, implementations |
| Curriculum designer | Determine what and in what order to teach |
| Question designer | Create meaningful retrieval and application exercises |
| Reviewer | Find errors and weaknesses |
| Adversary | Try to find things that are wrong |

No single pass covers all roles. The iterative cycle ensures all roles are performed.

## Integration with Other Skills

### Skill Loading Order

For a new course, load skills in this order:

```
1. product_architecture  → understand the system
2. course_architecture   → understand file structure
3. technical_research    → how to find sources
4. course_generation     → THIS SKILL (the process)
5. course_writing        → how to write .ch files
6. learning_design       → pedagogical methodology
7. implementation_gaps   → Chemical syntax pitfalls
8. review_quality        → how to review output
```

### Phase-to-Skill Mapping

| Phase | Primary Skill | Supporting Skills |
|-------|--------------|-------------------|
| A: Research | `technical_research` | — |
| B: Knowledge Extraction | `course_generation` | `learning_design` |
| C: Curriculum Design | `course_architecture` | `course_generation` |
| D: Learning Design | `learning_design` | `course_generation` |
| E: Content Generation | `course_writing` | `implementation_gaps`, `libs_reference` |
| F: Technical Verification | `technical_research` | `engineering_patterns` |
| G: Pedagogical Critique | `learning_design` | `review_quality` |
| H: Interaction Review | `micro_interactions` | `review_quality` |
| I: Consistency Review | `course_generation` | `course_architecture` |
| J: Final Review | `review_quality` | All of the above |
| K: Revision | `course_writing` | `implementation_gaps` |

### What to Do When Stuck

| Situation | Action |
|-----------|--------|
| Can't find authoritative source | Load `technical_research`, check source hierarchy |
| Chemical code won't compile | Load `implementation_gaps` for syntax pitfalls |
| Not sure if exercise is good | Load `review_quality`, run exercise review prompt |
| Content feels flat/boring | Load `learning_design`, check for active recall |
| Too much content | Apply "one concept per lesson" rule from `course_writing` |
