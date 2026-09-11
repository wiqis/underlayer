# Course Development Handbook

Step-by-step guide for AI to develop high-quality courses. Every course must follow this process exactly. No steps may be skipped.

> **Also load the `course_generation` skill** for the 11-phase generation cycle with artifact templates. This handbook covers *the overall development process*; the skill covers *the generation details*.

## Quick Decision Tree

Use this to determine which phases to run:

```
New course from scratch?
  → Run ALL phases (0-7)

Adding a single concept to existing course?
  → Skip Phase 0 (scoping)
  → Run Phases 1-7 for the new concept only

Fixing a bug in existing content?
  → Skip Phases 0-3
  → Run Phase 4 (generation) for the fix
  → Run Phase 5 (verification) for the fix
  → Run Phase 6 (adversarial) only if fix is major

Reviewing existing content?
  → Skip Phases 0-4
  → Run Phase 5 (verification) fully
  → Run Phase 6 (adversarial) fully
```

## Phase Overview with Time Estimates

| Phase | Name | Time (full course) | Time (single concept) | Can Skip? |
|-------|------|-------------------|----------------------|-----------|
| 0 | Topic Scoping | 1-2 hours | No | Only if adding to existing course |
| 1 | Knowledge Extraction | 2-4 hours | 30-60 min | No |
| 2 | Curriculum Design | 2-3 hours | 10-20 min | Only if concept order is fixed |
| 3 | Learning Design | 2-3 hours/concept | 20-40 min | No |
| 4 | Content Generation | 4-8 hours/module | 60-120 min | No |
| 5 | Verification | 4-6 hours/module | 30-60 min | No |
| 6 | Adversarial Review | 2-4 hours/module | 15-30 min | No |
| 7 | Publication | 1-2 hours | 15-30 min | No |

**Total for a 10-concept course:** ~40-80 hours
**Total for a single concept:** ~3-6 hours

---

## Phase 0: Topic Scoping (1-2 hours)

### Step 0.1: Define the Subject

Answer these questions:
1. What is the subject? (e.g., "ELF — Executable and Linkable Format")
2. Why does it exist? (What problem does this knowledge solve?)
3. Who is the target learner? (Programmer wanting to understand binaries? Security researcher? Compiler engineer?)
4. What are the prerequisites? (What must the learner already know?)
5. What will the learner be able to DO after completing this course?
6. How long should the course take? (Estimated hours)

### Step 0.2: Research the Subject

1. Find the authoritative specification (gABI for ELF, RFC for TLS, etc.)
2. Find 2-3 reputable secondary sources (books, articles)
3. Find authoritative source code (Linux kernel, LLVM, etc.)
4. Create a `research/` directory with source material

### Step 0.3: Create the Course Manifest

```json
{
  "id": "elf",
  "title": "ELF — Executable and Linkable Format",
  "version": 1,
  "description": "Understand the ELF binary format from first principles",
  "prerequisites": [],
  "estimated_hours": 20,
  "target_learner": "Programmer who wants to understand how binaries work",
  "learning_outcomes": [
    "Read and interpret ELF headers",
    "Understand program headers and segments",
    "Understand section headers and sections",
    "Explain how linking and loading work",
    "Write a basic ELF parser"
  ],
  "research_sources": [
    {
      "type": "specification",
      "title": "System V Application Binary Interface",
      "url": "https://refspecs.linuxfoundation.org/elf/elf.pdf",
      "sections": ["1-8"]
    }
  ]
}
```

---

## Phase 1: Knowledge Extraction (2-4 hours)

### Step 1.1: Read the Specification

Read the relevant sections of the specification. For each section, extract:
- All definitions (what things ARE)
- All requirements (what things MUST be)
- All constraints (what things CANNOT be)
- All optional features (what things MAY be)
- Version-specific behavior
- Architecture-specific behavior

### Step 1.2: Identify All Concepts

List every concept the learner must understand. For each concept:

```json
{
  "id": "elf-header",
  "title": "ELF Header",
  "definition": "The ELF header is the first structure in an ELF file...",
  "purpose": "The ELF header tells the system how to process the file",
  "who_produces": "The compiler/linker",
  "who_consumes": "The loader, static linker, debugger",
  "depends_on": ["bytes", "binary-representation", "file-layout"],
  "depends_on_by": ["program-headers", "sections", "symbols"],
  "if_invalid": "The loader rejects the file",
  "if_missing": "The file cannot be processed at all",
  "edge_cases": ["32-bit vs 64-bit", "big-endian vs little-endian", "ET_DYN vs ET_EXEC"],
  "misconceptions": [
    "The ELF header is at offset 0 (TRUE, but the e_phoff field is what matters for program headers)",
    "The entry point is always the start of main() (FALSE — it's _start, which calls __libc_start_main)"
  ],
  "specification_section": "ELF Identification, ELF Header",
  "specification_page": "4-5"
}
```

### Step 1.3: Build the Knowledge Graph

Map all concepts and their dependencies. Check for:
- Circular dependencies (FORBIDDEN)
- Prerequisite avalanches (too many prerequisites for one concept)
- Concepts that depend on concepts not yet taught

### Step 1.4: Identify Misconceptions

For each concept, ask:
1. "What would an intelligent beginner probably misunderstand here?"
2. "What is the most common confusion with similar terminology?"
3. "What implementation detail might someone mistake for a specification requirement?"
4. "What simplified model might someone take too literally?"

Document each misconception with:
- The misconception itself
- Why it's wrong
- How to prevent it
- How to detect it (exercise targeting it)

---

## Phase 2: Curriculum Design (2-3 hours)

### Step 2.1: Order Concepts

Topologically sort concepts by prerequisites. The result is a linear order where every concept appears after all its prerequisites.

### Step 2.2: Group into Modules

Group related concepts into modules (3-6 concepts per module). Each module should:
1. Have a clear theme
2. Build on the previous module
3. Contain concepts that are learned close together

### Step 2.3: Estimate Time

For each concept, estimate:
- Lesson time: 15-25 minutes
- Exercise time: 5-10 minutes
- Review time: 2-5 minutes (first time)

### Step 2.4: Create the Curriculum Document

```json
{
  "modules": [
    {
      "id": "fundamentals",
      "title": "Fundamentals",
      "order": 1,
      "concepts": ["bytes", "binary-representation", "file-layout"],
      "estimated_minutes": 45
    },
    {
      "id": "elf-header",
      "title": "ELF Header",
      "order": 2,
      "concepts": ["identification", "header-fields", "entry-point"],
      "estimated_minutes": 45
    }
  ]
}
```

---

## Phase 3: Learning Design (2-3 hours per concept)

### Step 3.1: Design the 8-Unit Lesson

For each concept, design 8 learning units following the pattern:

#### Unit 1: WHY (1-2 minutes)
- State the problem this concept solves
- Explain what would go wrong without it
- Connect to something the learner already knows

**Template:**
> Before [concept], consider what happens when [problem]. Without [concept], [bad thing]. [Concept] exists because [reason].

#### Unit 2: MODEL (2-3 minutes)
- Provide a simplified mental model
- Explicitly mark it as simplified
- Give it a name the learner can reference

**Template:**
> For now, think of [concept] as [simple model]. This is useful because [reason]. But this model is incomplete — [what it misses]. We'll fix that next.

#### Unit 3: REALITY (3-5 minutes)
- Provide the actual technical detail
- Reference the specification directly
- Use precise terminology

**Template:**
> The specification says [exact quote or paraphrase with section reference]. In detail: [technical explanation]. The key fields are: [list with sizes and offsets].

#### Unit 4: EXAMPLE (2-3 minutes)
- Show a concrete, verifiable example
- Use real bytes, real hex dumps, real structures
- Walk through the example step by step

**Template:**
> Here is an actual [example]. Let's walk through it: [step-by-step walkthrough]. Notice [key detail]. This corresponds to [specification reference].

#### Unit 5: INTERACT (2-5 minutes)
- Launch an interactive exercise or visualization
- Let the learner manipulate the concept
- Provide immediate feedback

**Template:**
> [Interactive element]. Try it yourself. [Instructions]. What do you notice? [Observation prompt].

#### Unit 6: RETRIEVE (1-2 minutes)
- Ask a free-recall question (NO hints)
- Wait for the learner's answer
- Then show the correct answer

**Template:**
> Without looking back: [question]. (Pause for recall.) The answer is: [answer]. If you got it wrong, that's okay — the act of trying to recall strengthens your memory.

#### Unit 7: APPLY (2-5 minutes)
- Present an exercise that uses the knowledge
- Require the learner to apply, not just recognize
- Provide detailed feedback

**Template:**
> [Exercise prompt]. Think about what you learned. [Hints if needed]. [Feedback on answer].

#### Unit 8: CONNECT (1 minute)
- Explain how this concept relates to others
- Preview what's coming next
- Show the concept's position in the knowledge graph

**Template:**
> This connects to [related concept] because [reason]. Next, we'll learn [next concept], which builds on [what we just learned].

### Step 3.2: Design Exercises

For each concept, create 4-6 exercises:

| Type | Count | Purpose |
|---|---|---|
| `recall` | 1-2 | Free recall ("What is X?") |
| `recognize` | 1-2 | Multiple choice ("Which of these is X?") |
| `apply` | 1-2 | Use the knowledge ("Given this, find X") |
| `debug` | 1 | Find errors ("This is wrong. Why?") |

For each exercise, specify:
1. The question (clear, unambiguous)
2. The correct answer (verified against specification)
3. 3-4 wrong answers (plausible, targeting specific misconceptions)
4. The explanation for each answer (WHY it's right or wrong)
5. The misconception it targets

### Step 3.3: Generate Review Items

From the concept, generate 5-8 review items:

| Type | Front | Back |
|---|---|---|
| `recall` | "What is X?" | Definition |
| `recognize` | "Which of these is X?" | Correct option |
| `apply` | "Given this hex dump, find X" | Solution with explanation |
| `explain` | "Why does X exist?" | Explanation of purpose |

### Step 3.4: Design Visualizations

For each concept that benefits from visualization:
1. State the learning objective
2. Describe the visualization type
3. Specify the interaction model
4. Define the data source

---

## Phase 4: Content Generation (4-8 hours per module)

### Step 4.1: Generate Lesson Content

For each concept, write the 8 learning units in Chemical source format.

**Constraints during generation:**
1. Every factual claim must cite a source or be marked `[UNVERIFIED]`
2. Every byte sequence, offset, or size must be verified against the specification
3. Every example must be testable (compile, run, verify)
4. Never invent plausible-looking technical data
5. Always distinguish specification facts from implementation details
6. Mark simplified models explicitly

### Step 4.2: Generate Exercises

For each exercise:
1. Write the question
2. Write the correct answer
3. Write 3-4 wrong answers with specific feedback
4. Verify the correct answer against the specification
5. Verify the wrong answers are plausible enough to be educational

### Step 4.3: Generate Review Items

For each review item:
1. Write the front (question)
2. Write the back (answer)
3. Verify the answer is correct
4. Ensure the question is answerable from the lesson content

### Step 4.4: Generate Visualization Code

For each visualization:
1. Write the Chemical code
2. Test it renders correctly
3. Verify the data matches the specification
4. Ensure interactions work

---

## Phase 5: Verification (4-6 hours per module)

### Step 5.1: Technical Verification

For every technical claim in the course:

- [ ] Is this in the specification? Which section?
- [ ] Is this version-specific? Which version?
- [ ] Is this architecture-specific? Which architecture?
- [ ] Are byte layouts, offsets, and sizes correct?
- [ ] Does the example actually work?
- [ ] Are there edge cases I'm hiding?

**Verification command:**
```bash
# For ELF examples
readelf -h sample.elf  # Compare with course explanation
xxd sample.elf | head  # Verify byte sequences
```

### Step 5.2: Pedagogical Verification

For every concept:

- [ ] Does it explain WHY before WHAT?
- [ ] Does it build a mental model before demanding memorization?
- [ ] Does it connect to other concepts?
- [ ] Is complexity broken into digestible pieces?
- [ ] Does it include active recall?
- [ ] Are exercises testing understanding, not just recognition?

### Step 5.3: Exercise Verification

For every exercise:

- [ ] Is the correct answer actually correct?
- [ ] Is the question unambiguous?
- [ ] Is it solvable with the information provided?
- [ ] Does the explanation accurately describe why?
- [ ] Does it target a specific misconception?
- [ ] Are wrong answers plausible?

### Step 5.4: Consistency Verification

For the entire course:

- [ ] No contradictions between sections
- [ ] Terminology is consistent
- [ ] Prerequisites are established in order
- [ ] Simplifications are explicitly marked
- [ ] No concept introduced without prerequisites

---

## Phase 6: Adversarial Review (2-4 hours per module)

### Step 6.1: Expert Perspective

Review from the perspective of a domain expert:
- What important details are omitted?
- What simplifications are dangerous?
- What examples are misleading?
- Where would an expert object?

### Step 6.2: Beginner Perspective

Review from the perspective of a beginner:
- What is confusing?
- What assumed knowledge is missing?
- What terminology is unclear?
- Where would I get stuck?

### Step 6.3: Test Author Perspective

Review from the perspective of a test author:
- Which exercises test memorization rather than understanding?
- Which questions are ambiguous?
- Which explanations are technically correct but pedagogically poor?

### Step 6.4: Fix and Re-verify

Fix all critical and major issues found during adversarial review. Re-verify fixes are correct.

---

## Phase 7: Publication

### Step 7.1: Final Checklist

- [ ] All phases completed
- [ ] All critical issues fixed
- [ ] All major issues fixed
- [ ] All technical claims verified
- [ ] All exercises tested
- [ ] All review items verified
- [ ] Course manifest complete
- [ ] All files in correct directory structure

### Step 7.2: Version the Course

Set the version number:
- 1.0.0 — First publication
- 1.0.x — Typo fixes, minor corrections
- 1.x.0 — New exercises, content corrections
- x.0.0 — New concepts, major restructuring

### Step 7.3: Publish

```bash
# Verify course structure
ls courses/elf/
# manifest.json  concepts/  exercises/  visualizations/  assets/  reviews/

# Build and test
cmake-build-debug/TCCCompiler courses/elf/chemical.mod -o build/elf-course.exe --mode debug_quick
./build/elf-course.exe  # Verify it renders correctly
```

---

## Quality Metrics

Track these metrics for each course:

| Metric | Target |
|---|---|
| Technical accuracy | 100% verified claims |
| Exercise correctness | 100% correct answers |
| Concept coverage | 100% of identified concepts taught |
| Prerequisite correctness | 100% of prerequisites taught before use |
| Misconception coverage | 100% of identified misconceptions addressed |
| Review item count | 5-8 per concept |
| Exercise count | 4-6 per concept |
| Lesson time | 15-25 minutes per concept |
| Adversarial issues | 0 critical, 0 major after review |

---

## Template Index

All templates are in the `course_generation` skill. Here's a quick reference:

| Template | Location | When to Use |
|----------|----------|-------------|
| `research.md` | `course_generation/SKILL.md` Phase A | Research phase output |
| `concepts.json` | `course_generation/SKILL.md` Phase B | Knowledge extraction output |
| `curriculum.json` | `course_generation/SKILL.md` Phase C | Curriculum design output |
| `learning-design.json` | `course_generation/SKILL.md` Phase D | Learning design output |
| `verification.md` | `course_generation/SKILL.md` Phase F | Technical verification output |
| `pedagogy-review.md` | `course_generation/SKILL.md` Phase G | Pedagogical critique output |
| `interaction-review.md` | `course_generation/SKILL.md` Phase H | Interaction review output |
| `consistency-review.md` | `course_generation/SKILL.md` Phase I | Consistency review output |
| `final-review.md` | `course_generation/SKILL.md` Phase J | Final review output |
| `revision-log.md` | `course_generation/SKILL.md` Phase K | Revision log output |
| `.ch file template` | `course_writing/SKILL.md` | Writing concept pages |
| `manifest.json` | `course_architecture/SKILL.md` | Course manifest |

### Template Usage Rules

1. **Copy the template** — don't try to memorize the structure
2. **Fill in all sections** — empty sections are incomplete work
3. **Mark unknowns** — use `[UNVERIFIED]` or `[NEEDS RESEARCH]`
4. **Version your artifacts** — track what changed between iterations
