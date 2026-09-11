# Underlayer | Learn Things Deeply

## 0. Purpose of This Document

This document defines the product philosophy, learning philosophy, quality requirements, content requirements, and long-term design principles for **Underlayer**.

It is given to an AI agent **before implementation begins**.

The AI must use this document to:

1. Understand what Underlayer is.
2. Design the platform around its actual purpose.
3. Create the project's `AGENTS.md`.
4. Create the project's development and content-generation skills.
5. Produce an implementation plan.
6. Build the first MVP.
7. Generate and continuously improve the first course: **ELF — Executable and Linkable Format**.

This document intentionally does **not** prescribe implementation technologies, file structures, APIs, frameworks, component architectures, databases, or other engineering decisions.

Those decisions belong to the implementation-planning phase.

The AI must not interpret the absence of implementation details as permission to ignore the requirements here.

---

# 1. What Underlayer Is

**Underlayer is a learning platform for subjects that are difficult, deep, poorly taught, highly technical, or usually require digging through specifications, source code, academic papers, books, RFCs, and fragmented documentation.**

Its tagline is:

> **Underlayer | Learn Things Deeply**

The central idea is:

> **Take things that normally require enormous amounts of scattered research and turn them into structured, interactive, deeply understood knowledge.**

Underlayer is not primarily:

- a video course platform
- a collection of articles
- an AI-generated tutorial website
- a programming bootcamp
- a course marketplace
- a documentation viewer
- a generic educational platform

Those things may exist inside Underlayer, but they are not the product's identity.

The identity is:

> **Learn things deeply, especially the things nobody has properly taught.**

---

# 2. The Problem We Are Solving

There are countless important technical subjects where the available educational material is inadequate.

Examples include:

- ELF
- PE
- Mach-O
- JVM bytecode
- PDF internals
- MP4 / ISO Base Media File Format
- TLS implementation
- executable loaders
- linkers
- relocations
- ABI design
- calling conventions
- DWARF
- filesystems
- memory allocators
- CPU caches
- virtual memory
- page tables
- network protocols
- compression formats
- binary formats
- graphics internals
- operating-system internals
- compiler internals
- debugging formats
- cryptographic protocols

For many of these subjects, the learner encounters some combination of:

- a specification that is hundreds of pages long
- outdated tutorials
- scattered blog posts
- university lectures
- incomplete documentation
- source code without explanation
- superficial tutorials
- long videos with little interaction
- examples without conceptual explanations
- explanations without practical exercises

Underlayer exists to bridge this gap.

---

# 3. The Core Product Principle

The single most important principle is:

> **Underlayer does not optimize for course completion. It optimizes for understanding and retention.**

A learner watching 100% of a course and remembering 10% has not succeeded.

A learner who can explain, predict, apply, inspect, debug, and build something using the subject has succeeded.

Therefore:

**Progress is not mastery.**

**Exposure is not understanding.**

**Recognition is not recall.**

**Completion is not learning.**

The platform must be designed accordingly.

---

# 4. The Course Is the Primary Artifact

Underlayer should be designed around courses first.

The platform is infrastructure around the courses.

The first course is:

> **ELF — Executable and Linkable Format**

The platform MVP exists primarily to deliver this course.

The course should not be treated as temporary demonstration content.

It should be treated as the **first permanent Underlayer course**.

Future courses should follow the same philosophy.

---

# 5. Courses Are Long-Lived Knowledge Artifacts

A fundamental assumption of Underlayer is:

> **A course is generated once, then improved continuously for years.**

We are not building a system where an AI generates a course today and nobody looks at it again.

We expect courses to evolve.

A course may be:

- corrected
- expanded
- reorganized
- clarified
- given better examples
- given better visualizations
- given new exercises
- updated when specifications change
- updated when standards change
- updated when implementations change
- improved based on learner mistakes
- improved when a better explanation is discovered
- expanded as new knowledge becomes relevant

Therefore the architecture and content model must not make courses disposable.

The system must preserve the ability to improve them indefinitely.

---

# 6. The AI Must Never Treat Its First Generation as Authoritative

AI-generated content is presumed to contain errors until verified.

This applies even when the AI is highly confident.

The generation process must therefore be iterative.

The conceptual process should be:

> Research → Generate → Verify → Test → Critique → Improve → Re-verify → Repeat

Not:

> Prompt → Generate → Publish

The AI should assume that its own output requires examination.

---

# 7. Source-of-Truth Hierarchy

For technical courses, sources must be treated according to their authority.

The AI should distinguish between:

### Primary sources

Examples:

- official specifications
- standards
- RFCs
- formal documentation
- official technical documentation
- authoritative standards organizations
- source code of authoritative implementations
- academic papers where appropriate

### Secondary sources

Examples:

- reputable books
- high-quality technical articles
- respected educational material
- implementation documentation
- engineering write-ups

### Tertiary sources

Examples:

- forum posts
- random blogs
- social-media discussions
- AI-generated material
- unsourced explanations

Tertiary material may provide useful leads, but should not be treated as authoritative when stronger sources exist.

For a standards-based course, the course should be checked against the actual specification.

---

# 8. Verification Is a Permanent Course Activity

The AI should repeatedly ask:

- Is this technically correct?
- Is this still correct?
- Does the relevant specification say this?
- Does the relevant RFC say this?
- Is this implementation-specific?
- Is this architecture-specific?
- Is this version-specific?
- Is this simplified explanation hiding an important exception?
- Are there edge cases?
- Is the terminology correct?
- Does the example actually work?
- Does the binary example correspond to the explanation?
- Does the visualization represent reality?
- Are offsets, sizes, flags, and byte layouts correct?
- Does the exercise have an unambiguous answer?

The AI should not merely proofread prose.

It must verify **the underlying knowledge**.

---

# 9. Separate Facts, Models, Simplifications, and Implementation Details

Courses must clearly distinguish between:

### Specification facts

What the standard actually requires.

### Conceptual models

A simplified mental model that helps humans understand the system.

### Implementation details

How a particular implementation behaves.

### Historical context

Why a feature exists or how the system evolved.

### Simplifications

Things intentionally omitted temporarily to make learning easier.

The course must not accidentally teach:

> "Linux does X, therefore ELF requires X."

when the ELF specification actually allows something broader.

Likewise, it must not teach an implementation detail as though it were a universal rule.

---

# 10. Learning Must Be Interactive

Passive reading should never be the default learning mechanism.

Important concepts should be followed by opportunities to actively use them.

Interactions can include:

- quizzes
- recall questions
- multiple choice
- multiple answer
- ordering
- matching
- labeling
- prediction
- classification
- fill-in-the-blank
- code completion
- byte/hex inspection
- diagram interaction
- state-machine interaction
- debugging
- identifying mistakes
- comparing alternatives
- constructing an answer
- explaining a concept
- applying a rule
- manipulating a representation
- interpreting real artifacts

The exact interaction type should depend on the subject.

---

# 11. Understanding Must Be Tested at Multiple Levels

A concept should not be considered learned simply because the learner selected its definition.

Whenever appropriate, learning should progress through levels such as:

1. Recognition
2. Recall
3. Explanation
4. Interpretation
5. Prediction
6. Application
7. Debugging
8. Construction
9. Transfer to a new situation

For example, learning ELF should eventually progress from:

> "What is an ELF header?"

to:

> "Identify the ELF header."

to:

> "Explain what the ELF header provides."

to:

> "Interpret these fields."

to:

> "Predict what the loader/toolchain will do."

to:

> "Diagnose a malformed ELF."

to:

> "Write an ELF parser."

The course should strive toward **usable understanding**, not trivia retention.

---

# 12. Retrieval Must Be Built Into the Course

Humans forget.

Underlayer must be designed around this fact.

The course must deliberately bring concepts back after the learner has moved on.

A concept should not disappear forever after its lesson.

Examples:

> Learn ELF header.

Later:

> Question about program headers.

Later still:

> Recall what information the ELF header provides.

Later:

> Diagnose an issue involving the ELF header.

Later:

> Use the ELF header while implementing a parser.

This creates repeated encounters with the same idea in different contexts.

---

# 13. Repetition Must Not Become Boring

Repetition should not simply mean asking the same question five times.

Instead, repeat the **concept**, not necessarily the exact activity.

For example:

### First exposure

"What is `e_entry`?"

### Second exposure

"Find `e_entry` in this hex dump."

### Third exposure

"What would happen if this value changed?"

### Fourth exposure

"Your parser reports the wrong entry point. Find the bug."

### Fifth exposure

"Use the entry point while explaining how execution begins."

Same concept.

Different cognitive activity.

---

# 14. The Platform Should Eventually Understand Weakness

The long-term system should be capable of determining that a learner is weak in particular concepts.

For example:

```text
ELF Header        Strong
Program Headers  Strong
Sections          Medium
Symbols           Weak
Relocations       Weak
Dynamic Linking   Not Learned
```

A learner who repeatedly fails questions about relocation should encounter relocation concepts again.

The system should eventually be able to say:

> "Before continuing, let's repair this missing foundation."

This should be a core direction of the platform, even if the first MVP implements only a small portion of it.

---

# 15. Courses Must Have Explicit Knowledge Dependencies

Complex technical subjects have dependency graphs.

For example:

```text
Bytes
  ↓
Binary representation
  ↓
File layout
  ↓
ELF header
  ↓
Program headers
  ↓
Sections
  ↓
Symbols
  ↓
Relocations
  ↓
Dynamic linking
  ↓
Loading
```

The course should explicitly understand these dependencies.

A learner should not be required to understand something that the course has never adequately established.

The AI must identify prerequisites before teaching advanced concepts.

---

# 16. Avoid the "Prerequisite Avalanche"

Deep courses can become impossible if every concept requires ten previous concepts.

The course should introduce prerequisites **just in time**.

If the learner needs to understand an unfamiliar concept, provide the minimum necessary foundation and then return to the primary subject.

The goal is deep learning, not infinite prerequisite chains.

---

# 17. Every Important Concept Needs a Reason to Exist

Do not merely define technical structures.

Explain:

> **Why does this exist?**

For example:

Instead of only explaining:

> "A program header contains..."

also explain:

> "Why does the loader need this?"

Then:

> "What problem would exist without it?"

Then:

> "How does this interact with the other structures?"

This should be a recurring pattern throughout courses.

---

# 18. Teach Relationships, Not Isolated Facts

A deep course should answer:

- What is this?
- Why does it exist?
- What does it contain?
- Who consumes it?
- Who produces it?
- What does it depend on?
- What depends on it?
- How does it interact with neighboring concepts?
- What happens if it is invalid?
- What happens if it is missing?
- What happens in unusual cases?
- How is it represented physically?
- How is it represented conceptually?
- How would we implement it?

The learner should leave with a **mental model of the system**.

---

# 19. Concrete Reality Is Extremely Important

For low-level subjects, the course should frequently connect abstractions to real artifacts.

Whenever appropriate, show:

- actual bytes
- actual files
- actual headers
- actual machine code
- actual assembly
- actual memory layouts
- actual network packets
- actual structures
- actual compiler output
- actual error cases
- actual implementation behavior

The learner should repeatedly experience:

> **Concept → representation → real artifact**

rather than only reading abstract descriptions.

---

# 20. Interactive Visualizations Are First-Class Learning Material

When visualization can materially improve understanding, use it.

Examples:

### ELF

- file layout
- headers
- sections
- segments
- offsets
- virtual addresses
- mappings

### JVM

- bytecode
- operand stack
- local variables
- stack frames
- constant pool

### TLS

- handshake states
- messages
- cryptographic operations
- keys
- transcript
- encryption boundaries

### PDF

- objects
- xref
- trailer
- streams
- offsets
- page relationships

Visualization should explain the actual system, not merely decorate the page.

---

# 21. Interactivity Must Have Pedagogical Purpose

Do not create interactive widgets merely because they look impressive.

Every interaction must answer:

> **What does this help the learner understand or remember?**

Bad:

> An animated ELF file because animation looks cool.

Good:

> An interactive ELF layout where selecting a section highlights its file offset, size, and relationship to the section table.

The platform should prefer **useful interactivity over decorative interactivity**.

---

# 22. Learners Must Be Allowed to Make Mistakes

The system should treat mistakes as learning opportunities.

A wrong answer should ideally provide useful feedback.

Not:

> ❌ Wrong.

Instead:

> You selected X because it describes a section. The question is asking about a segment, which describes a runtime mapping.

Feedback should help correct the underlying mental model.

---

# 23. Misconceptions Should Be Explicitly Modeled

For important subjects, the course generator should identify likely misconceptions.

For example:

> "Sections and segments are the same thing."

The course should actively address this.

This is especially important for low-level material where similar terminology causes confusion.

The AI should ask:

> "What would an intelligent beginner probably misunderstand here?"

and design material to prevent it.

---

# 24. Examples Must Be Verified

Every technical example must be treated as executable knowledge.

Examples should be checked whenever practical.

This includes:

- code
- byte sequences
- binary layouts
- offsets
- sizes
- calculations
- diagrams
- protocol messages
- command output
- assembly
- compiler output
- file structures

Never invent plausible-looking technical data merely to make an explanation convenient.

---

# 25. Exercises Must Also Be Verified

A technically incorrect exercise can teach incorrect knowledge.

Every exercise should be checked for:

- correctness
- ambiguity
- solvability
- expected answer
- misleading wording
- edge cases
- consistency with the lesson
- consistency with the specification

The answer must actually follow from the provided information.

---

# 26. Deep Does Not Mean Needlessly Long

Underlayer courses should be deep, but individual learning units should remain digestible.

Do not turn depth into giant walls of text.

The course should be broken into small conceptual units.

A learner should regularly experience:

> Learn something → do something → get feedback → continue.

Rather than:

> Read 30 pages → take one quiz.

---

# 27. The Course Should Have Multiple Learning Loops

A useful conceptual pattern is:

```text
LOOP 1
Understand a concept
↓
Recall it
↓
Apply it

LOOP 2
Learn related concept
↓
Recall previous concept
↓
Connect concepts

LOOP 3
Solve a larger problem
↓
Expose weaknesses
↓
Repair weaknesses

LOOP 4
Review the entire system
↓
Apply knowledge to a real artifact

LOOP 5
Build something
↓
Debug it
↓
Explain why it works
```

The course should repeatedly move between local understanding and global understanding.

---

# 28. Courses Should End in Competence, Not a Final Quiz

The final stage of a deep technical course should ideally involve using the knowledge.

For example, the ELF course could culminate in tasks such as:

- inspecting real ELF files
- identifying their structures
- explaining their layout
- interpreting important fields
- diagnosing malformed data
- implementing an ELF parser
- perhaps progressively implementing more functionality

The exact project is subject-dependent.

The principle is:

> **The learner should demonstrate that they can use the knowledge.**

---

# 29. Course Quality Must Be Multi-Dimensional

A course should not be judged only by factual correctness.

It should be evaluated on at least:

### Correctness

Is the information technically accurate?

### Coverage

Did we teach the important concepts?

### Dependency correctness

Are prerequisites established in the right order?

### Depth

Does the learner actually understand the subject?

### Retention

Are concepts revisited?

### Interaction

Does the learner actively use knowledge?

### Clarity

Can the material be understood?

### Precision

Does it distinguish specification from implementation?

### Practicality

Can the learner apply the knowledge?

### Visualization

Are complex relationships made understandable?

### Misconception resistance

Does the course prevent common misunderstandings?

### Accessibility

Can a learner with limited attention consume the material?

### Maintainability

Can the course continue evolving for years?

---

# 30. AI Course Generation Must Be Iterative

The AI should not produce the final course in one pass.

A conceptual generation cycle should include:

### Phase A — Research

Study authoritative sources.

### Phase B — Knowledge extraction

Identify concepts, facts, dependencies, terminology, edge cases, examples, and misconceptions.

### Phase C — Curriculum design

Determine the order in which concepts should be taught.

### Phase D — Learning design

Determine how each concept will be learned, recalled, applied, and revisited.

### Phase E — Content generation

Generate the actual course material.

### Phase F — Technical verification

Check against authoritative sources.

### Phase G — Pedagogical critique

Ask whether the course actually teaches effectively.

### Phase H — Interaction review

Check whether interactive elements genuinely improve learning.

### Phase I — Consistency review

Look for contradictions across the course.

### Phase J — Final review

Attempt to find weaknesses in the entire course.

### Phase K — Revision

Fix identified problems.

This process should be repeatable indefinitely.

---

# 31. The AI Should Attack Its Own Work

An important rule:

> **The AI must actively attempt to prove that the course is wrong or weak.**

It should ask:

- What did we misunderstand?
- What did we omit?
- What assumptions did we make?
- Which claims need verification?
- Which examples are suspicious?
- Which diagrams oversimplify reality?
- Where could an expert object?
- Where could a beginner become confused?
- Which concepts are introduced too early?
- Which concepts are never revisited?
- Which exercises test memorization rather than understanding?
- Which explanations are technically correct but pedagogically poor?

A course should improve through adversarial review.

---

# 32. Expert Review Mindset

The AI should periodically assume the role of:

- domain expert
- specification reviewer
- compiler engineer
- systems programmer
- skeptical teacher
- beginner
- technical editor
- test author
- learner who forgot the previous lesson

Each perspective should reveal different problems.

---

# 33. Do Not Hallucinate Authority

Never write:

> "According to the ELF specification..."

unless the specification was actually consulted.

Never imply that a source says something it does not.

If a fact cannot be verified, the course should either:

- research it further,
- qualify it,
- or omit it.

Confidence is not evidence.

---

# 34. Course Sources Should Be Traceable

Important technical claims should have a path back to their authoritative source.

The long-term system should make it possible to determine:

> "Why does Underlayer teach this?"

and eventually:

> "Which specification/RFC/document supports this?"

This is important because courses are expected to live for many years.

When standards change, we need to know what needs re-evaluation.

---

# 35. Version Awareness

Technical standards evolve.

Courses must be conscious of versions.

For example:

- specification version
- RFC version/status
- platform version
- architecture version
- implementation version

The course must distinguish:

> "This is part of the standard."

from:

> "This changed in version X."

and:

> "Linux does this."

and:

> "This particular implementation does this."

---

# 36. Do Not Over-Simplify Low-Level Subjects

Simplification is useful.

False simplification is dangerous.

If a mental model is simplified, explicitly indicate that it is a model.

For example:

> "For now, think of a segment as..."

Later:

> "That model is useful, but incomplete. Here is what actually happens."

Underlayer should be willing to say:

> "The simple explanation you learned earlier is no longer sufficient."

That is not a failure.

That is deep learning.

---

# 37. Build From Simple Models Toward Reality

The learner should generally progress:

```text
simple mental model
        ↓
concrete example
        ↓
interaction
        ↓
more precise model
        ↓
edge cases
        ↓
real specification
        ↓
real implementation
```

This allows difficult subjects to remain approachable without sacrificing depth.

---

# 38. The Platform Should Be Calm and Learning-Focused

The UI should support concentration.

Avoid unnecessary:

- gamification
- flashing animations
- excessive notifications
- meaningless badges
- competitive leaderboards
- distracting social features
- unnecessary progress mechanics

The learner should feel:

> "I am sitting down and understanding something difficult."

not:

> "I am playing a mobile game about completing lessons."

---

# 39. Attention-Friendly Design

Underlayer is explicitly designed for learners who may struggle with:

- sustained attention
- working memory
- remembering previous material
- long passive lectures
- large blocks of text
- information overload

This does **not** mean the material should be dumbed down.

It means the material should be structured intelligently.

Use:

- short learning units
- frequent interactions
- clear visual hierarchy
- explicit objectives
- frequent retrieval
- contextual repetition
- small conceptual steps
- visible relationships
- progressive complexity
- immediate feedback
- optional deeper explanations
- clear "why this matters" explanations

A technically advanced subject can still be presented in digestible pieces.

---

# 40. Do Not Assume the Learner Remembers

At any point, the course should be able to reintroduce a concept.

Do not punish the learner for forgetting.

Forgetting is expected.

The correct response is:

> "Let's retrieve that again."

not:

> "You should already know this."

---

# 41. Deep Dive and Quick Path

Where appropriate, material should have layers.

For example:

### Essential

What must be understood to continue.

### Deeper

Why it works.

### Expert

Edge cases, historical details, specification nuances, implementation details.

This lets the learner maintain momentum without sacrificing depth.

---

# 42. Courses Should Expose the Underlying Structure

Underlayer should eventually allow learners to see:

- what concepts they have learned
- what concepts depend on them
- what concepts they are weak in
- what concepts they should review
- where they are in the overall knowledge graph

This should feel like exploring a subject, not merely progressing through numbered videos.

---

# 43. The Course Is a Knowledge Graph, Not Just a Sequence

A course may be presented sequentially, but internally the knowledge should be thought of as interconnected.

Example:

```text
ELF
├── Binary representation
├── File layout
├── ELF identification
├── ELF header
│   ├── Architecture
│   ├── Entry point
│   └── File offsets
├── Program headers
│   ├── Segments
│   └── Memory mapping
├── Sections
│   ├── Code
│   ├── Data
│   └── Metadata
├── Symbols
├── Relocations
├── Dynamic linking
└── Loading
```

This structure enables better:

- review
- remediation
- course navigation
- future updates
- prerequisite detection
- adaptive learning

---

# 44. Content and Presentation Should Be Separate Concepts

The underlying knowledge should not be trapped inside one presentation.

The same concept may eventually appear as:

- explanation
- quiz
- visualization
- exercise
- review question
- project
- diagnostic question

Therefore the conceptual content model should allow knowledge to be reused in multiple learning contexts.

---

# 45. Courses Must Be Portable

A course should be a self-contained artifact as much as reasonably possible.

The intended conceptual output is a complete course directory containing everything required to present the course, such as:

- pages
- styles
- scripts
- images
- interactive experiences
- course assets
- supporting resources

The course should be capable of being distributed independently of the main platform.

The platform may host and serve it, but the course should not conceptually belong to a database that makes independent distribution impossible.

A course should be able to exist as a **portable learning artifact**.

---

# 46. Underlayer Platform vs Course

The platform should provide reusable capabilities.

Courses provide subject-specific knowledge.

The platform may eventually provide things such as:

- course navigation
- learning state
- quizzes
- question rendering
- progress
- mastery
- review scheduling
- reusable interactive components
- search
- course metadata
- source references
- accessibility
- analytics
- course updates

But a course should contain the subject-specific material and experiences.

This separation is important.

---

# 47. The First MVP

The first MVP should intentionally be small.

It should contain:

## Platform

A deployed Underlayer website capable of serving a course.

The platform should provide only the reusable foundation required to present the first course well.

It does not need every future feature.

## Course

Exactly one flagship course:

> **ELF — Executable and Linkable Format**

The ELF course should demonstrate the core Underlayer philosophy.

It should be substantially better than a normal article or video course.

It should demonstrate:

- structured learning
- short conceptual units
- interactive learning
- quizzes
- repetition
- real technical artifacts
- visualizations where useful
- progressively deeper concepts
- practical exercises
- correctness verification
- authoritative references

The MVP should not attempt to solve every future problem.

But it must avoid architectural decisions that make the long-term vision impossible.

---

# 48. ELF Is the Proof of the Philosophy

The ELF course is not merely sample content.

It should answer the question:

> **Can Underlayer teach a genuinely difficult low-level subject better than the existing material?**

The course should aim to take a technically capable programmer from appropriate prerequisites toward genuine understanding of ELF.

The exact depth and curriculum must be determined through research and planning.

Do not arbitrarily restrict it to superficial material simply because it is an MVP.

---

# 49. The ELF Course Should Eventually Reach Implementation

Where appropriate, the course should progress from:

```text
What is ELF?
        ↓
Why does ELF exist?
        ↓
How is an ELF file structured?
        ↓
What does every major structure mean?
        ↓
How does the linker use it?
        ↓
How does the loader use it?
        ↓
How does dynamic linking work?
        ↓
How do relocations work?
        ↓
How do real binaries look?
        ↓
How can we inspect them?
        ↓
How can we implement an ELF parser?
```

The exact curriculum must be researched rather than assumed.

---

# 50. The AI Must Not Optimize for Speed of Generation

The goal is not:

> "Generate 20 courses this month."

The goal is:

> **"Create courses worth keeping for decades."**

A single excellent course is more valuable than 100 mediocre AI-generated courses.

The platform should therefore encourage:

> depth > volume

> correctness > speed

> learning quality > content quantity

> longevity > novelty

---

# 51. Future Course Selection

Future courses should favor subjects with characteristics such as:

- difficult to learn independently
- fragmented existing resources
- specifications that are hard to understand
- limited high-quality educational material
- valuable to technically curious people
- practical or intellectually important
- suitable for interactive exploration
- capable of benefiting from repetition and visualization

The question should not be:

> "What course will get the most generic traffic?"

The question should be:

> **"What important thing do people desperately want to understand but currently have to assemble from ten different sources?"**

That is an Underlayer course candidate.

---

# 52. Underlayer Should Become a Library of Deep Knowledge

The long-term vision is a collection of courses such as:

```text
Underlayer

├── ELF
├── PE
├── Mach-O
├── JVM Bytecode
├── PDF Internals
├── MP4 Internals
├── TLS
├── Linkers
├── Dynamic Linking
├── DWARF
├── Memory Allocators
├── Virtual Memory
├── CPU Caches
├── Filesystems
├── QUIC
├── WebAssembly
└── ...
```

Each course should be treated as a long-lived knowledge artifact.

---

# 53. The AI Is a Teacher, Researcher, Critic, and Maintainer

AI has several roles in Underlayer.

### Teacher

Design explanations and learning experiences.

### Researcher

Study specifications, standards, RFCs, implementations, papers, and authoritative sources.

### Curriculum designer

Determine what should be learned and in what order.

### Question designer

Create meaningful retrieval and application exercises.

### Reviewer

Find errors and weaknesses.

### Maintainer

Continuously improve the course.

### Adversary

Try to find things that are wrong.

No single generated output should be assumed to represent all of these roles correctly.

The workflow should explicitly use them.

---

# 54. AI Must Follow the Product Philosophy Even When the User Did Not Explicitly Ask

Any AI agent working on Underlayer should automatically ask:

> Does this make learning deeper?

> Does this improve retention?

> Does this make difficult knowledge easier to understand?

> Does this reduce unnecessary cognitive load?

> Does this improve correctness?

> Does this make future course maintenance easier?

> Does this support the idea that courses are long-lived artifacts?

If a proposed feature does not support Underlayer's educational purpose, it should be questioned rather than added merely because other educational platforms have it.

---

# 55. No Feature Should Exist Merely Because Other Platforms Have It

Do not blindly copy:

- certificates
- leaderboards
- streaks
- likes
- comments
- social feeds
- badges
- arbitrary gamification
- video-first course structures
- instructor profiles
- course marketplaces

Every feature must justify itself against Underlayer's central purpose.

---

# 56. Accessibility Is Part of Learning Quality

The course should be usable by people with different learning needs.

Important information should not depend exclusively on:

- color
- audio
- animation
- hover states
- tiny text
- timing-sensitive interactions

Interactive elements should have understandable alternatives where appropriate.

The goal is not merely compliance.

The goal is making difficult knowledge easier to absorb.

---

# 57. Visual Quality Matters

Underlayer should feel like a serious technical learning environment.

The UI should be:

- clean
- calm
- modern
- readable
- technically sophisticated
- responsive
- consistent
- visually hierarchical
- optimized for learning

Technical subjects often look ugly when presented as documentation.

Underlayer should demonstrate that deep technical education can also have excellent design.

But visual design must never overwhelm the learning experience.

---

# 58. Avoid AI Slop

Underlayer must not feel like a collection of AI-generated pages.

Warning signs include:

- repetitive wording
- generic introductions
- unnecessary summaries
- fake enthusiasm
- excessive headings
- bloated explanations
- shallow analogies
- incorrect technical claims
- repetitive quiz questions
- meaningless interactivity
- decorative diagrams
- obvious template reuse

The AI should write as a technically competent educator, not as a language model trying to fill space.

---

# 59. Analogies Must Be Used Carefully

Analogies can help establish intuition.

But analogies must not become the actual technical model.

A course should eventually transition:

> analogy → conceptual model → technical reality

The learner should know where the analogy stops being accurate.

---

# 60. Every Course Should Have a Clear Contract With the Learner

At the beginning, explain:

- what the course teaches
- what prerequisites are expected
- what the learner will eventually be able to do
- approximately how the learning experience is structured
- how repetition works
- how exercises work
- how deep the material goes

The learner should understand what they are undertaking.

---

# 61. The Course Should Not Hide Complexity

Underlayer exists specifically to teach difficult things.

Do not artificially remove complexity simply to make a course look easy.

Instead:

> **Break complexity into understandable pieces.**

The goal is:

> difficult but understandable

not:

> difficult and overwhelming

and not:

> easy because important details were removed.

---

# 62. The Course Should Build a Mental Model Before Demanding Memorization

If a learner understands relationships, many facts become naturally recoverable.

Therefore prioritize:

```text
Why
↓
Relationship
↓
Mental model
↓
Concrete representation
↓
Recall
```

rather than:

```text
Memorize terminology
↓
Memorize fields
↓
Memorize definitions
```

---

# 63. The System Should Eventually Learn From Learners

Long-term, learner interaction should help improve courses.

If many learners consistently:

- misunderstand a concept
- fail a particular question
- abandon at a particular section
- answer a question correctly for the wrong reason
- require the same prerequisite

that is evidence that the course itself may need improvement.

The platform should eventually support a feedback loop:

```text
Course
 ↓
Learners
 ↓
Observed difficulties
 ↓
Course analysis
 ↓
Course improvement
 ↓
Better learners
```

Learner failure should not always be interpreted as learner weakness.

Sometimes the lesson is bad.

---

# 64. Never Let Analytics Become the Goal

Metrics are useful only insofar as they improve learning.

Do not optimize for:

- time on page
- number of clicks
- session duration
- number of lessons completed

unless those measurements genuinely correlate with learning.

A learner who understands a concept in five minutes is better than a learner who spends twenty minutes clicking around.

---

# 65. Long-Term Evolution

The system should be designed with the expectation that Underlayer may eventually contain:

- many courses
- adaptive review
- knowledge graphs
- course versioning
- source tracking
- continuous verification
- course diffing
- automated regression tests for educational content
- reusable interactive learning components
- learner-specific review
- cross-course concepts
- shared prerequisites
- course recommendations based on knowledge
- offline/downloadable courses
- independently distributable courses
- community feedback
- expert review
- AI-assisted maintenance

These are directions, not requirements that must all exist in the MVP.

The MVP should establish the foundations without prematurely implementing everything.

---

# 66. The Course Is More Important Than the Platform

This principle must survive future growth.

If there is ever a choice between:

> improving a course

and

> adding a shiny platform feature

the course should generally win.

Underlayer's competitive advantage is not its login system.

It is not its dashboard.

It is not its subscription page.

It is:

> **The quality of the understanding it creates.**

---

# 67. The First Question for Every Major Decision

When designing Underlayer, ask:

> **"Does this help someone understand something deeply that they otherwise would struggle to learn?"**

If yes, investigate it.

If no, question why it exists.

---

# 68. Requirements for the Initial AI Planning Phase

Before writing substantial implementation code, the AI must:

1. Study this document completely.
2. Identify all implied product requirements.
3. Identify ambiguities that genuinely require decisions.
4. Identify long-term architectural risks without prematurely selecting implementation technologies.
5. Define the conceptual model of:
   - courses
   - concepts
   - lessons
   - learning objectives
   - questions
   - exercises
   - reviews
   - interactions
   - sources
   - verification
   - course versions
   - learner state
6. Determine what belongs to the platform and what belongs to courses.
7. Design the content-generation and content-review lifecycle.
8. Design the quality gates that generated courses must pass.
9. Create appropriate AI skills.
10. Create `AGENTS.md`.
11. Produce a detailed implementation plan.
12. Only then begin implementation.

Do not skip directly from this document to coding.

---

# 69. Requirements for AI Skills

The project should have dedicated AI skills/processes for at least the following conceptual responsibilities:

- product architecture
- learning design
- course architecture
- technical research
- source verification
- specification analysis
- curriculum design
- lesson design
- quiz design
- interactive learning design
- misconception analysis
- course correctness review
- pedagogical review
- accessibility review
- UI/UX review
- course consistency review
- course maintenance
- adversarial course review

The implementation agent should use these capabilities rather than attempting to perform every role through one generic prompt.

The exact skill structure is an implementation decision.

---

# 70. Requirements for AGENTS.md

`AGENTS.md` should encode the important rules in this document in a form that development agents can follow.

It must make clear that:

1. Underlayer is learning-first.
2. Courses are long-lived artifacts.
3. AI-generated content must be verified.
4. Specifications and authoritative sources matter.
5. Interactivity must have pedagogical purpose.
6. Retrieval and repetition are fundamental.
7. The platform exists to serve courses.
8. The ELF course is the first permanent flagship course.
9. The AI must not optimize for content quantity.
10. The AI must not silently weaken educational requirements for convenience.

`AGENTS.md` should not merely repeat this entire document.

It should translate the principles into actionable agent rules.

---

# 71. Requirements for the Development Plan

The implementation plan must be written before significant implementation.

It should identify:

- what must exist for the MVP
- what can wait
- what foundations must be established now
- what should remain deliberately simple
- what decisions are difficult to change later
- what should be tested
- how the ELF course will be generated
- how course assets will be represented
- how course quality will be evaluated
- how the course can be continuously updated

The plan should avoid implementing speculative future features merely because they are mentioned in this document.

---

# 72. The MVP Definition of Done

The MVP is successful when:

### Platform

A deployed Underlayer platform can reliably present the course.

### Course

The ELF course is genuinely useful and technically deep.

### Learning

The course demonstrates:

- active learning
- retrieval
- repetition
- progressive difficulty
- meaningful interaction
- technical accuracy
- practical application

### Quality

The course has been subjected to:

- source verification
- technical review
- pedagogical review
- consistency review
- interaction review
- adversarial review

### Architecture

The system allows future courses to be added without rebuilding Underlayer from scratch.

### Portability

The course can exist as an independently distributable artifact.

---

# 73. What Success Looks Like

A learner should be able to say:

> "I wanted to understand ELF, but everything I found was either a specification, a scattered collection of articles, or an extremely long lecture. Underlayer actually walked me through it."

And more importantly:

> "I don't just remember the definitions. I understand why ELF is structured this way."

And eventually:

> "I can open an ELF file and understand what I'm looking at."

That is the standard Underlayer should aim for.

---

# 74. The Ultimate Vision

Underlayer should become a place where someone can search for an obscure technical subject and discover:

> **Someone actually taught this properly.**

Not merely documented it.

Not merely summarized it.

Not merely generated an AI explanation.

**Taught it.**

With:

- structure
- repetition
- interaction
- visualization
- real examples
- specifications
- exercises
- feedback
- progressively deeper understanding
- continuous maintenance

The ultimate promise of Underlayer is:

> **You don't have to spend six months assembling knowledge from scattered sources just to understand how something works.**

Underlayer does the work of turning that complexity into a learning experience.

---

# 75. Final Principle

Everything in Underlayer should ultimately serve one sentence:

# **Learn Things Deeply.**

If a feature makes that easier, pursue it.

If a course element makes that more likely, keep it.

If a process improves correctness or retention, invest in it.

If a technical decision makes long-term course maintenance easier, consider it carefully.

If something exists only because other platforms do it, question it.

If the AI has to spend ten times longer verifying a course instead of generating ten more courses, **verify the course.**

Underlayer is not trying to generate the most educational content.

It is trying to create **the best way to deeply understand things that are difficult to learn.**