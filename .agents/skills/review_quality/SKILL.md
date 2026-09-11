# Review Quality Skill

Load this skill when reviewing, verifying, or critiquing generated course content.

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
