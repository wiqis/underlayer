# Review Quality Skill

Load this skill when reviewing, verifying, or critiquing generated course content.

> **Also load `engineering_patterns`** for content validation patterns (source verification, exercise verification, manifest validation). This skill covers *how to review*; `engineering_patterns` covers *what to validate*.

> **Also load `course_writing`** for common mistakes and patterns. This skill covers *how to critique*; `course_writing` covers *what to look for*.

## Quick Start: Reviewing a Single Concept

For a quick review of one concept file, run through this abbreviated checklist:

```
1. Every hex byte verified? (run readelf/xxd)
2. Every if has an else?
3. WHY unit comes first?
4. Every exercise has exactly one correct answer?
5. Feedback explains WHY for each option?
```

For the full 5-type review process, continue below.

## Review Types

### 1. Technical Review

**Focus:** Is the content technically correct?

**Checklist:**
- [ ] Every technical claim traces to an authoritative source
- [ ] Byte layouts, offsets, and sizes are correct
- [ ] Examples actually work (compiled, tested, verified)
- [ ] Edge cases are not hidden without noting the simplification
- [ ] Terminology matches the specification
- [ ] Version-specific behavior is noted
- [ ] Architecture-specific behavior is noted
- [ ] Implementation-specific behavior is noted

**Review prompt:**
```
You are a technical reviewer for course content.

CONTENT: [content to review]
SPECIFICATION: [relevant spec]

Focus:
- Find technical errors
- Find unverifiable claims
- Find incorrect byte layouts, offsets, sizes
- Find examples that don't work
- Find hidden edge cases

Output:
- List of issues (critical / major / minor)
- For each: what's wrong, where, and how to fix it
```

### 2. Pedagogical Review

**Focus:** Does the content actually teach effectively?

**Checklist:**
- [ ] Every concept explains WHY before WHAT
- [ ] Mental models precede technical details
- [ ] Simplifications are explicitly marked
- [ ] Active recall is included in every lesson
- [ ] Exercises test understanding, not just recognition
- [ ] Feedback explains WHY, not just "wrong"
- [ ] Difficulty progression is appropriate
- [ ] Pacing is anxiety-friendly

**Review prompt:**
```
You are a pedagogical reviewer for course content.

CONTENT: [content to review]
TARGET LEARNER: [description of target audience]

Focus:
- Does this teach effectively?
- Is the pacing appropriate?
- Are there passive reading sections that should be active?
- Are exercises testing understanding or memorization?
- Is feedback helpful or just corrective?

Output:
- List of pedagogical issues
- For each: what's wrong, why it matters, how to fix it
```

### 3. Consistency Review

**Focus:** Is the course internally consistent?

**Checklist:**
- [ ] No contradictions between sections
- [ ] Terminology is used consistently
- [ ] Prerequisites are established before concepts that need them
- [ ] Simplified models are explicitly marked and later replaced
- [ ] No concept is introduced without its prerequisites
- [ ] Exercise difficulty matches concept difficulty
- [ ] Review items match lesson content

**Review prompt:**
```
You are a consistency reviewer for an entire course.

COURSE CONTENT: [all content]

Focus:
- Find contradictions between sections
- Find inconsistent terminology
- Find prerequisites taught after they're needed
- Find simplifications not marked as simplified
- Find concepts introduced without prerequisites

Output:
- List of inconsistencies
- For each: where the contradiction is, which version is correct
```

### 4. Adversarial Review

**Focus:** Actively try to prove the course is wrong.

**Checklist:**
- [ ] What did we misunderstand?
- [ ] What did we omit?
- [ ] Which claims need verification?
- [ ] Which examples are suspicious?
- [ ] Which diagrams oversimplify?
- [ ] Where could an expert object?
- [ ] Where could a beginner become confused?
- [ ] Which concepts are introduced too early?
- [ ] Which concepts are never revisited?
- [ ] Which exercises test memorization rather than understanding?

**Review prompt (expert perspective):**
```
You are a domain expert reviewing course content on [topic].

CONTENT: [content to review]

Focus:
- What would an expert find wrong?
- What important details are omitted?
- What simplifications are dangerous?
- What examples are misleading?

Output:
- List of expert-level concerns
- For each: what's wrong, why it matters, how to fix it
```

**Review prompt (beginner perspective):**
```
You are a beginner learning [topic] for the first time.

CONTENT: [content to review]

Focus:
- What is confusing?
- What assumed knowledge is missing?
- What terminology is unclear?
- Where would I get stuck?

Output:
- List of confusion points
- For each: what's unclear, why, how to clarify
```

### 5. Exercise Review

**Focus:** Are exercises well-designed and correct?

**Checklist for each exercise:**
- [ ] The correct answer is actually correct
- [ ] The question is unambiguous
- [ ] It is solvable with the information provided
- [ ] The explanation accurately describes why the answer is correct
- [ ] It targets a specific misconception
- [ ] Wrong answers are plausible enough to be educational
- [ ] The difficulty level is appropriate
- [ ] The time limit (if any) is fair

**Review prompt:**
```
You are an exercise reviewer.

EXERCISE: [exercise to review]
LESSON CONTEXT: [what the learner has been taught]

Focus:
- Is the correct answer correct?
- Is the question ambiguous?
- Is it solvable with the provided information?
- Does the explanation accurately describe why?
- Does it target a specific misconception?
- Are wrong answers plausible?

Output:
- List of exercise issues
- For each: what's wrong, how to fix it
```

## Severity Levels

| Level | Definition | Action |
|---|---|---|
| Critical | Technically wrong, teaches incorrect knowledge | Must fix before publishing |
| Major | Pedagogically weak, likely to confuse learners | Should fix before publishing |
| Minor | Stylistic, could be improved | Note for future revision |

### Severity Calibration Guide

**Critical** — The content actively teaches wrong knowledge:
- Incorrect hex bytes, offsets, or struct layouts
- Wrong answer marked as correct in an exercise
- A claim that contradicts the specification
- Missing prerequisite that causes learner confusion

**Major** — The content works but teaches poorly:
- No WHY before WHAT (jumps to definition)
- Exercise that tests memorization, not understanding
- Feedback that says "wrong" without explaining why
- Over-explaining (500 words for a 100-word concept)
- Missing connection to prerequisite concepts

**Minor** — The content works but could be better:
- Inconsistent terminology (but still understandable)
- Slightly verbose explanations
- Missing optional visualizations
- CSS could be more polished

### Concrete Examples

**Critical:**
```
Content claims "ELF header is 52 bytes for ELF64"
Reality: ELF64 header is 64 bytes, ELF32 is 52 bytes
Fix: Change to "64 bytes for ELF64, 52 bytes for ELF32"
```

**Major:**
```
Content: "The ELF header is a structure that contains various fields..."
Problem: No WHY, jumps straight to WHAT
Fix: Add "When you run readelf -h, how does it know where program headers are?"
```

**Minor:**
```
Content uses "header struct" in one place and "ELF header" in another
Problem: Inconsistent terminology (but both are understandable)
Fix: Standardize to "ELF header" throughout
```

## Issue Tracking

Every issue found during review is tracked:

```json
{
  "id": "issue-001",
  "type": "technical|pedagogical|consistency|exercise",
  "severity": "critical|major|minor",
  "location": "concepts/elf-header/identification.ch:42",
  "description": "The claim about e_ident size is incorrect",
  "current": "e_ident is 16 bytes",
  "correct": "e_ident is 16 bytes in ELF32 and ELF64",
  "source": "gABI specification, ELF Identification section",
  "fix": "Add note that size is consistent across ELF32 and ELF64",
  "status": "open|fixed|deferred"
}
```

## Review Workflow

1. **Generate content** (Phase E of course generation)
2. **Technical review** — verify all claims
3. **Pedagogical review** — verify teaching effectiveness
4. **Exercise review** — verify all exercises
5. **Consistency review** — verify course-wide consistency
6. **Adversarial review** — try to break the course
7. **Fix critical issues** — must fix before publishing
8. **Fix major issues** — should fix before publishing
9. **Note minor issues** — track for future revision
10. **Re-verify fixes** — confirm fixes are correct
11. **Publish** — all gates pass

## Review Metrics

Track review quality:

| Metric | Target |
|---|---|
| Critical issues found per concept | 0 (after fix) |
| Major issues found per concept | 0 (after fix) |
| Technical accuracy | 100% verified claims |
| Exercise correctness | 100% correct answers |
| Pedagogical coverage | 100% concepts with WHY |
| Consistency | 0 contradictions |

## When to Stop Reviewing

Stop reviewing when ALL of these are true:

1. **No critical issues remain** — every technically wrong claim is fixed
2. **No major issues remain** — every pedagogically weak section is improved
3. **All exercises verified** — every answer is correct, every question is unambiguous
4. **All hex bytes verified** — every byte sequence matches a real file or the spec
5. **Two review passes completed** — first pass finds issues, second pass confirms fixes

**Do NOT stop reviewing when:**
- "It looks good enough" — subjective feeling is not a quality gate
- "I'm tired" — take a break, then come back
- "Minor issues can wait" — only if they're actually minor

### Review Iteration Pattern

```
Round 1: Full review (all 5 types)
  ↓
Fix critical + major issues
  ↓
Round 2: Re-verify fixes + check for new issues introduced
  ↓
If Round 2 found new critical/major → Round 3
If Round 2 clean → Done
```

**Maximum iterations:** 3. If Round 3 still finds critical issues, the content needs to be rewritten, not reviewed.

## Integration with Other Skills

### Review Type → Skill Mapping

| Review Type | Primary Skill | Supporting Skills |
|-------------|--------------|-------------------|
| Technical | `technical_research` | `implementation_gaps` |
| Pedagogical | `learning_design` | `course_generation` |
| Consistency | `course_architecture` | `course_generation` |
| Adversarial | `review_quality` (this skill) | All of the above |
| Exercise | `course_writing` | `learning_design` |

### What to Do After Review

| Review Result | Action |
|---------------|--------|
| Critical issues found | Fix immediately, re-review |
| Major issues found | Fix before publishing, re-review |
| Minor issues found | Log in revision-log.md, fix later |
| No issues found | Publish |
| Unsure about a claim | Mark `[NEEDS VERIFICATION]`, research later |

### Common Review Anti-Patterns

**Anti-pattern: "Looks correct to me"**
- Problem: No actual verification against sources
- Fix: Run readelf/xxd, check the spec, test the exercise

**Anti-pattern: "I'll just check the first few"**
- Problem: Later content may have worse issues
- Fix: Review ALL content, use the checklist for every concept

**Anti-pattern: "The exercise seems fine"**
- Problem: "Seems fine" is not "is correct"
- Fix: Actually solve every exercise yourself, verify the answer
