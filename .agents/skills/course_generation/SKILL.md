# Course Generation Skill

Load this skill when using AI to generate course content.

> **Also load `course_writing`** for the practical, in-the-trenches guide to writing .ch files: common mistakes, Chemical syntax patterns, exercise patterns, and verification checklists. This skill covers *the 11-phase process*; `course_writing` covers *how to actually write each file*.

> **Also load `engineering_patterns`** for content validation patterns (manifest validation, concept file validation, exercise verification). This skill covers *how to generate*; `engineering_patterns` covers *how to validate what you generated*.

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
