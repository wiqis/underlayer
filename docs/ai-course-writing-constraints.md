# AI Course-Writing Constraints

This document defines the specific methods and constraints for AI to generate high-quality educational content. These are not suggestions — they are requirements.

---

## The Problem

AI language models produce confident, well-written text that may be:
- Technically incorrect
- Based on hallucinated sources
- Oversimplified in dangerous ways
- Pedagogically ineffective
- Repetitive and generic

Without constraints, AI will generate a course that looks good but teaches wrong knowledge.

---

## Constraint Pipeline

Every piece of course content must pass through this pipeline. No steps may be skipped.

```
1. Source Grounding (RAG)
   ↓
2. Structured Generation (SCoT)
   ↓
3. Chain-of-Verification (CoVe)
   ↓
4. Rubric Evaluation
   ↓
5. Self-Consistency Check
   ↓
6. Confidence Gating
   ↓
7. Adversarial Review
   ↓
8. Human Gate
```

---

## Method 1: Source Grounding (RAG)

### What

Force the AI to generate content ONLY from retrieved authoritative sources, with explicit citations.

### How

1. Build a verified knowledge base per topic
2. Index specification sections, authoritative articles, source code
3. Before generation, retrieve relevant passages
4. Prompt includes retrieved passages as context
5. AI must cite `[source_id]` after every factual claim
6. Post-process: flag any uncited claims

### Prompt Template

```
You are generating educational content about [TOPIC].

SOURCE MATERIAL:
[SPEC_EXCERPT_1]
[SPEC_EXCERPT_2]
[AUTHORITATIVE_ARTICLE]

CONSTRAINTS:
- Using ONLY the above source material
- Cite [source_id] after every factual claim
- If the source material doesn't cover a point, say "Not covered in available sources"
- Never invent information not in the source material
- Every byte sequence, offset, or size must come from the source

Generate: [LESSON CONTENT]
```

### Verification

- Parse output for citation markers
- Flag any factual claim without a citation
- Reject output with > 2 uncited claims

---

## Method 2: Structured Chain-of-Thought (SCoT)

### What

A state-machine approach where the AI must pass through dedicated states: read → extract → verify → generate.

### States

| State | Input | Output |
|---|---|---|
| 1. Read | Source material | Annotated notes |
| 2. Extract | Annotated notes | Key claims list |
| 3. Verify | Key claims + source | Verified claims |
| 4. Generate | Verified claims | Educational content |

### Prompt Template for Each State

**State 1: Read**
```
Read the following source material about [TOPIC].
For each paragraph, note:
- Key facts (with section references)
- Definitions
- Constraints or requirements
- Edge cases

Source: [SOURCE_MATERIAL]
```

**State 2: Extract**
```
From the annotated notes below, extract the key claims that should appear in a lesson about [CONCEPT].

Rules:
- Only extract claims that are directly supported by the notes
- Include the section reference for each claim
- Mark any claims that are uncertain

Notes: [ANNOTATED_NOTES]
```

**State 3: Verify**
```
For each claim below, verify it against the source material.
For each claim, state:
- VERIFIED: claim is directly supported by the source
- UNSUPPORTED: claim is not in the source (REMOVE IT)
- CONFLICTING: claim contradicts the source (FIX IT)

Claims: [KEY_CLAIMS]
Source: [SOURCE_MATERIAL]
```

**State 4: Generate**
```
Using ONLY the verified claims below, generate educational content about [CONCEPT].

Follow this structure:
1. WHY: Why this concept exists
2. MODEL: Simplified mental model (marked as simplified)
3. REALITY: Actual technical detail
4. EXAMPLE: Concrete, verifiable example
5. RETRIEVAL: Active recall question
6. APPLY: Exercise
7. CONNECT: How this relates to other concepts

Verified Claims: [VERIFIED_CLAIMS]
```

### Verification

- Ensure each state's output feeds correctly into the next
- Reject if State 3 finds unsupported claims (must regenerate)
- Verify final output only contains verified claims

---

## Method 3: Chain-of-Verification (CoVe)

### What

A 4-step self-verification protocol: generate → plan verification → answer independently → revise.

### Steps

1. Generate baseline content
2. Plan 3-5 verification questions targeting factual claims
3. Answer each question INDEPENDENTLY (not conditioned on the draft)
4. Revise the content based on verification results

### Prompt Template

**Step 1: Generate**
```
Generate a lesson about [CONCEPT].
[LESSON_REQUIREMENTS]
```

**Step 2: Plan Verification**
```
From the generated lesson above, identify 3-5 factual claims that could be wrong.
For each claim, write a verification question that would confirm or deny it.

Example:
Claim: "The ELF header is 52 bytes in ELF32 and 64 bytes in ELF64"
Verification question: "What is the size of e_ident in ELF32 vs ELF64 per the gABI specification?"
```

**Step 3: Answer Independently**
```
Answer each verification question using ONLY your knowledge of the specification.
Do NOT reference the generated lesson. Answer as if you're starting fresh.

Questions: [VERIFICATION_QUESTIONS]
```

**Step 4: Revise**
```
Compare your verification answers with the original lesson.
For any discrepancy:
- If the verification answer differs from the lesson, CORRECT the lesson
- If the lesson was correct, keep it
- If uncertain, mark as [NEEDS VERIFICATION]

Original Lesson: [LESSON]
Verification Answers: [ANSWERS]
```

### Critical Rule

Step 3 MUST be independent from Step 1. If the AI answers verification questions while looking at its own draft, it will confirm its own hallucinations.

---

## Method 4: Rubric Evaluation

### What

Define atomic, verifiable rubric criteria and score generated content against them.

### Rubric

| Criterion | Description | Score (0-5) |
|---|---|---|
| Factual accuracy | Every claim is verifiable against sources | |
| No hallucinated examples | All code/data examples are syntactically valid | |
| Citation completeness | Every factual claim has a source citation | |
| Pedagogical scaffolding | Concepts introduced before being used | |
| WHY before WHAT | Every concept explains purpose before definition | |
| Uncertainty marking | Active debates marked as such | |
| Misconception coverage | Known misconceptions addressed | |
| Exercise correctness | All exercises have verifiable correct answers | |
| Feedback quality | Explanations explain WHY, not just right/wrong | |
| Accessibility | No jargon without definition | |

### Evaluation Prompt

```
You are evaluating educational content against a rubric.

CONTENT: [GENERATED_CONTENT]
RUBRIC: [RUBRIC_TABLE]

For each criterion:
1. Score 0-5 (0=fails completely, 5=exceeds standards)
2. Provide specific evidence (quote from content)
3. If score < 3, explain what's wrong and how to fix it

Output: JSON with scores, evidence, and fixes.
```

### Auto-Reject Rules

Reject content if ANY criterion scores < 3.

---

## Method 5: Self-Consistency Check

### What

Generate multiple versions and keep only claims that appear in most versions.

### Process

1. Generate 3 versions of the same content (temperature > 0)
2. Extract factual claims from each version
3. Keep claims present in ≥ 2/3 versions
4. Flag inconsistent claims for review

### Example

Version 1: "The ELF header starts with bytes 0x7f 0x45 0x4c 0x46"
Version 2: "The ELF magic number is 0x7f followed by 'ELF'"
Version 3: "ELF files begin with the four-byte sequence 7f 45 4c 46"

Consistent claim: ELF files start with 0x7f 0x45 0x4c 0x46

Version 1: "The ELF header is 52 bytes in ELF32"
Version 2: "The ELF32 header is 52 bytes"
Version 3: "ELF32 headers are 40 bytes"

Inconsistent claim: ELF32 header size (flag for verification)

### Implementation

- Use temperature 0.7 for generation
- Use NLP or structured extraction for claim identification
- Set consistency threshold: ≥ 2/3

---

## Method 6: Confidence Gating

### What

Force the AI to rate its confidence in each factual claim, triggering external verification for low-confidence claims.

### Prompt Template

```
After each section, create a table:

| Claim | Type | Confidence | Source |
|-------|------|------------|--------|
| [claim] | Fact/Inference/Opinion | High/Medium/Low | [source] |

Rules:
- FACT: Directly stated in the specification
- INFERENCE: Logical conclusion from facts
- OPINION: Interpretation or judgment
- HIGH: Directly quoted or paraphrased from source
- MEDIUM: Reasonable but not directly quoted
- LOW: Uncertain or extrapolated
```

### Verification Rules

| Confidence | Action |
|---|---|
| HIGH + Fact | Accept |
| MEDIUM + Fact | Verify against source |
| LOW + Fact | Reject or mark [UNVERIFIED] |
| Inference | Mark as inference, verify logic |
| Opinion | Mark as opinion, remove from factual content |

---

## Method 7: Adversarial Review

### What

Use a separate AI call to attack the generated content from multiple perspectives.

### Perspectives

| Perspective | Focus |
|---|---|
| Domain expert | Technical correctness |
| Specification reviewer | Compliance with standards |
| Skeptical teacher | Pedagogical effectiveness |
| Beginner | Confusion points |
| Technical editor | Clarity and precision |

### Adversarial Prompt

```
You are a [PERSPECTIVE] reviewing this educational content.

CONTENT: [GENERATED_CONTENT]

Your job is to find problems. Be aggressive. Find:
- Technical errors
- Misleading simplifications
- Confusing explanations
- Missing prerequisites
- Ambiguous exercises
- Incorrect examples

For each problem:
1. What's wrong
2. Where it is (quote)
3. Why it matters
4. How to fix it
```

### Verification

- Run all 5 perspectives
- Collect all problems
- Fix critical and major issues
- Re-run adversarial review on fixes

---

## Method 8: Human Gate

### What

Mandatory human review at specific pipeline stages.

### Gates

| Gate | What Human Reviews | Can Be Automated? |
|---|---|---|
| Gate 1: Source material | Is the source authoritative and complete? | No |
| Gate 2: Curriculum design | Is the concept order correct? | Partially |
| Gate 3: Generated content | Is it technically accurate? | No |
| Gate 4: Exercises | Are they correct and well-designed? | No |
| Gate 5: Final course | Is it ready to publish? | No |

### Human Review Checklist

For Gate 3 (most critical):
- [ ] Spot-check 5 technical claims against specification
- [ ] Verify 2 examples by compiling/running them
- [ ] Check 3 exercises for correctness
- [ ] Read one lesson as a beginner — is it confusing?
- [ ] Verify no hallucinated sources

---

## Negative Constraints

What the AI must NEVER do:

1. **Never fabricate statistics or percentages** — "studies show 80%..." is forbidden unless the study is cited
2. **Never invent case studies or examples** — all examples must be real or marked as hypothetical
3. **Never use "studies show" without naming the study** — every claim needs a source
4. **Never present contested claims as settled science** — mark debates as debates
5. **Never generate code that hasn't been tested** — all code examples must compile and run
6. **Never use hedging language for established facts** — "The ELF magic bytes ARE 0x7f..." not "The ELF magic bytes might be..."
7. **Never present opinions as facts** — mark interpretations as interpretations
8. **Never invent byte sequences** — all hex data must come from real files or the specification
9. **Never skip the verification step** — no exceptions
10. **Never accept first-pass content as final** — always iterate

---

## Prompt Framework: PARTS/CLEAR

Every generation prompt must include these components:

### PARTS

| Component | Description | Example |
|---|---|---|
| **P**ersona | Who the AI is | "You are a systems programmer teaching ELF to intermediate developers" |
| **A**im | What to create | "Create a lesson about ELF program headers" |
| **R**ecipients | Who the learner is | "Programmers who understand C and binary but haven't read the ELF spec" |
| **T**heme | Focus area | "Focus on practical understanding, not just definitions" |
| **S**tructure | Format | "Use the 8-unit lesson structure" |

### CLEAR

| Component | Description | Example |
|---|---|---|
| **C**oncise | Length constraint | "Under 500 words per concept" |
| **L**ogical | Order constraint | "Prerequisites before advanced topics" |
| **E**xplicit | Format constraint | "Use numbered steps, not prose paragraphs" |
| **A**daptive | Audience constraint | "If the reader is advanced, include edge cases" |
| **R**estrictive | Vocabulary constraint | "Don't use jargon not defined in the text" |

---

## Implementation Checklist

For each piece of generated content:

- [ ] Source material retrieved and included in prompt
- [ ] SCoT states completed (read → extract → verify → generate)
- [ ] CoVe verification questions planned
- [ ] CoVe answers generated independently
- [ ] Content revised based on verification
- [ ] Rubric evaluated (all criteria ≥ 3)
- [ ] Self-consistency check (3 versions, keep consistent claims)
- [ ] Confidence gating (all LOW claims removed or marked)
- [ ] Adversarial review completed (5 perspectives)
- [ ] All critical and major issues fixed
- [ ] Human gate passed

---

## Quality Metrics

| Metric | Target | Measurement |
|---|---|---|
| Factual accuracy | 100% | All claims verified against sources |
| Citation completeness | 100% | Every factual claim has a citation |
| Hallucination rate | 0% | No invented facts, examples, or sources |
| Rubric score | ≥ 4/5 average | Automated evaluation |
| Self-consistency | ≥ 80% | Claims consistent across 3 versions |
| Adversarial issues | 0 critical, 0 major | After fixes |
| Human approval | 100% | All gates passed |
