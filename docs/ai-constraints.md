# AI Constraint System

This document defines how AI agents are constrained when generating, reviewing, or modifying course content. The goal is to ensure AI-generated courses are reliable, accurate, and pedagogically sound — not just plausible-sounding text.

## Why Constraints Exist

AI language models produce confident, well-written text that may be:
- Technically incorrect
- Based on hallucinated sources
- Oversimplified in dangerous ways
- Pedagogically ineffective
- Repetitive and generic

Without constraints, AI will generate a course that looks good but teaches wrong knowledge. The constraint system prevents this.

## Constraint Layers

### Layer 1: Generation Constraints

These constraints control HOW the AI generates content.

#### 1.1 No One-Pass Generation

The AI must never generate a course in a single pass. The required cycle:

```
Phase A: Research
  ↓
Phase B: Knowledge Extraction
  ↓
Phase C: Curriculum Design
  ↓
Phase D: Learning Design
  ↓
Phase E: Content Generation
  ↓
Phase F: Technical Verification
  ↓
Phase G: Pedagogical Critique
  ↓
Phase H: Interaction Review
  ↓
Phase I: Consistency Review
  ↓
Phase J: Final Review
  ↓
Phase K: Revision
```

Each phase produces artifacts that the next phase consumes. The AI cannot skip phases.

#### 1.2 Source Attribution

Every technical claim must trace to an authoritative source. The AI must:

1. Consult the actual specification before writing about it
2. Record which specification section supports each claim
3. Mark unverified claims explicitly: `[UNVERIFIED]`
4. Never write "According to the ELF specification..." unless the specification was actually consulted

#### 1.3 Distinction Requirements

The AI must always distinguish between:

| Category | Definition | Example |
|---|---|---|
| Specification fact | What the standard requires | "ELF headers start with bytes 0x7f 0x45 0x4c 0x46" |
| Conceptual model | Simplified mental model | "Think of a segment as a memory region" |
| Implementation detail | How a specific implementation behaves | "Linux's loader uses mmap for loadable segments" |
| Historical context | Why something exists | "ELF replaced a.out because..." |
| Simplification | Intentionally omitted for clarity | "For now, ignore relocation types" |

The AI must not accidentally teach:
> "Linux does X, therefore ELF requires X."

#### 1.4 No Hallucinated Authority

The AI must never:
- Invent a specification section number
- Invent a byte sequence that looks plausible
- Invent an offset, size, or field name
- Claim a source says something it doesn't
- Generate "real-looking" hex dumps without verification

When uncertain, the AI must:
1. Research further
2. Qualify the statement ("The specification likely...")
3. Or omit it

#### 1.5 Misconception Identification

For every important concept, the AI must:

1. Ask: "What would an intelligent beginner probably misunderstand here?"
2. Identify the most likely misconceptions
3. Design material to prevent them
4. Create exercises that specifically target them

### Layer 2: Verification Constraints

These constraints control how content is VERIFIED after generation.

#### 2.1 Technical Verification

Every technical claim must be checked against:

- [ ] The relevant specification (which version?)
- [ ] The relevant RFC (if applicable)
- [ ] Authoritative source code (if applicable)
- [ ] Is this architecture-specific?
- [ ] Is this version-specific?
- [ ] Are byte layouts, offsets, and sizes correct?
- [ ] Do the examples actually work?

#### 2.2 Pedagogical Verification

Every lesson must be checked for:

- [ ] Does it explain WHY, not just WHAT?
- [ ] Does it build a mental model before demanding memorization?
- [ ] Does it connect to other concepts?
- [ ] Is the complexity broken into digestible pieces?
- [ ] Does it include active recall, not just passive reading?
- [ ] Are the exercises testing understanding, not just recognition?

#### 2.3 Exercise Verification

Every exercise must be checked for:

- [ ] Is the correct answer actually correct?
- [ ] Is the question unambiguous?
- [ ] Is it solvable with the information provided?
- [ ] Does the explanation accurately describe why the answer is correct?
- [ ] Does it target a specific misconception?
- [ ] Are wrong answers plausible enough to be educational?

#### 2.4 Consistency Verification

The course must be checked for:

- [ ] No contradictions between sections
- [ ] Terminology is consistent throughout
- [ ] Prerequisites are established in the right order
- [ ] Simplified models are explicitly marked and later replaced
- [ ] No concept is introduced without its prerequisites

### Layer 3: Adversarial Constraints

These constraints force the AI to ATTACK its own work.

#### 3.1 Self-Critique

The AI must periodically ask:

- What did I misunderstand?
- What did I omit?
- Which claims need verification?
- Which examples are suspicious?
- Which diagrams oversimplify?
- Where could an expert object?
- Where could a beginner become confused?
- Which concepts are introduced too early?
- Which concepts are never revisited?
- Which exercises test memorization rather than understanding?

#### 3.2 Expert Review Simulation

The AI must assume these roles and review from each perspective:

| Role | Focus |
|---|---|
| Domain expert | Technical correctness |
| Specification reviewer | Compliance with standards |
| Skeptical teacher | Pedagogical effectiveness |
| Beginner | Confusion points, pacing |
| Technical editor | Clarity, precision, grammar |
| Test author | Exercise quality, unambiguity |

#### 3.3 Adversarial Attack

The AI must actively try to prove the course is wrong:

- Find the weakest explanation
- Find the most confusing exercise
- Find the most likely misconception
- Find the least verifiable claim
- Find the poorest example

Then fix these before the course is considered ready.

### Layer 4: Quality Gates

These are mandatory checkpoints before content is published.

#### Gate 1: Technical Accuracy
- All claims verified against authoritative sources
- No hallucinated citations
- Byte layouts and offsets verified
- Examples tested

#### Gate 2: Pedagogical Effectiveness
- Every concept explains WHY
- Mental models precede details
- Active recall in every lesson
- Exercises test understanding

#### Gate 3: Consistency
- No contradictions
- Consistent terminology
- Prerequisites in correct order
- Simplifications explicitly marked

#### Gate 4: Completeness
- Every concept has exercises
- Every concept has review items
- Every exercise has an explanation
- Every exercise targets a misconception

#### Gate 5: Adversarial Review
- Self-critique completed
- Expert review simulated
- Weakest points identified and fixed

## AI Generation Prompts

### Content Generation Prompt Template

```
You are generating content for the Underlayer learning platform.

SUBJECT: [concept name]
PREREQUISITES: [concepts the learner already knows]
SPECIFICATION: [relevant spec section]

CONSTRAINTS:
1. Explain WHY this concept exists before explaining WHAT it is
2. Provide a simplified model, explicitly marked as simplified
3. Then provide the actual technical detail
4. Include a concrete, verifiable example
5. End with a retrieval question (no hints)
6. Include one exercise targeting a specific misconception
7. Cite the specification section for every technical claim
8. Never invent byte sequences, offsets, or field names

Generate:
- Lesson content (3 learning units)
- 1 visualization concept
- 2 exercises (1 recall, 1 application)
- 4 review items (2 recall, 1 recognize, 1 apply)
```

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
6. Could an expert find errors here?

OUTPUT:
- List of verified claims (with spec section)
- List of unverified claims
- List of potential errors
- List of simplifications that need noting
```

### Adversarial Review Prompt Template

```
You are reviewing course content from the perspective of [role].

ROLE: [domain expert / specification reviewer / skeptical teacher / beginner / technical editor / test author]
CONTENT: [the content to review]

FOCUS:
- What is wrong or weak in this content?
- What would confuse a beginner?
- What would an expert object to?
- What is missing?
- What is pedagogically poor?

OUTPUT:
- List of problems found
- Severity (critical / major / minor)
- Suggested fixes
```

## Chemical Language Constraints

Since Underlayer is built in Chemical, the AI must also follow Chemical-specific constraints:

1. **No `+` on strings** — use `.append_view` / `.append_string`
2. **`vector<T>` has no `[]`** — use `.get(i)` / `.get_ptr(i)`
3. **`.size()` not `.length()`**
4. **Uninitialized `var x : T` needs `unsafe` marker**
5. **No raw `HtmlPage.append_*`** — use `#html` blocks
6. **Universal components have known bugs** — use carefully

These constraints are documented in the project's `AGENTS.md` and enforced during code review.
