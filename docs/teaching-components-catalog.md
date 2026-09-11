# Teaching Components Catalog

## Purpose

Every type of content, interaction, and assessment we need to support. These are the building blocks that courses are made of. Each component is reusable, self-contained, and AI-developable.

## Component Families

### 1. Content Components (Information Delivery)

| Component | Purpose | Data | When to Use |
|---|---|---|---|
| `Paragraph` | Prose text | `markdown: string` | Default text block |
| `Heading` | Section header | `level: 1-6, text: string` | Structure |
| `Callout` | Highlighted info/warning | `type: note|tip|warning|danger, title?, content` | Important points |
| `Definition` | Term + meaning | `term: string, definition: string, related?: string[]` | New terminology |
| `KeyTakeaway` | Summary points | `points: string[]` | End of section |
| `Quote` | Quoted material | `text: string, attribution?: string` | Authoritative sources |
| `Comparison` | Side-by-side | `left: Component, right: Component, ratio?: number` | Before/after, this/that |
| `Table` | Structured data | `headers: Column[], rows: Row[]` | Reference data |
| `Image` | Visual | `src: string, alt: string, caption?: string` | Diagrams, screenshots |
| `Video` | Embedded media | `src: string, transcript?: string` | Demonstrations |
| `Timeline` | Chronological | `events: Event[]` | History, sequences |

### 2. Code Components (Technical Content)

| Component | Purpose | Data | When to Use |
|---|---|---|---|
| `CodeBlock` | Static code display | `language: string, code: string, title?, highlightLines?: number[]` | Code examples |
| `CodeCallout` | Line annotation | `line: number, label: string, explanation: string` | Explaining code |
| `CodeDiff` | Before/after | `before: string, after: string, language: string` | Changes, fixes |
| `CodeExecution` | Runnable code | `language: string, code: string, expectedOutput?: string` | Live demos |
| `CodeCompletion` | Fill-in-blank | `template: string, blanks: Blank[]` | Practice |
| `HexDump` | Binary data | `data: byte[], highlights?: Highlight[], baseAddress?: number` | ELF, file formats |
| `MemoryLayout` | Stack/heap | `stack: Frame[], heap: Object[], pointers: Relation[]` | Pointers, structs |
| `Terminal` | Shell interaction | `commands: Command[]` | CLI tools |
| `FileTree` | Directory structure | `entries: Entry[]` | Project structure |

### 3. Interactive Components (Learner Engagement)

| Component | Purpose | Data | When to Use |
|---|---|---|---|
| `Quiz` | Multiple choice | `question: string, options: Option[], multiSelect?: boolean` | Quick checks |
| `FillInBlank` | Text/code blanks | `text: string, blanks: Blank[]` | Recall |
| `DragDrop` | Reorder/match | `items: Item[], targets: Target[], correct: Mapping` | Sequencing |
| `Ordering` | Put in order | `items: Item[], correctOrder: number[]` | Processes |
| `Matching` | Connect pairs | `left: Item[], right: Item[], correctPairs: Pair[]` | Relationships |
| `Hotspot` | Click area | `image: string, zones: Zone[]` | Identify parts |
| `Slider` | Explore range | `min: number, max: number, step: number, onChange: expr` | Parameters |
| `Console` | REPL | `language: string, setup?: string` | experimentation |
| `Flashcard` | Flip card | `front: string, back: string, hints?: string[]` | Memorization |
| `Simulation` | System model | `type: string, config: object` | Dynamics |

### 4. Assessment Components (Evaluation)

| Component | Purpose | Data | When to Use |
|---|---|---|---|
| `MultipleChoice` | Single/multi answer | `stem: string, options: Option[], rubric?: string` | Knowledge check |
| `FreeResponse` | Open answer | `prompt: string, minLength?: number, maxLength?: number` | Understanding |
| `DebuggingExercise` | Find/fix bugs | `buggyCode: string, bugs: Bug[], solution: string` | Problem solving |
| `CodeChallenge` | Write code | `files: File[], tests: TestCase[]` | Application |
| `PeerReview` | Review code | `submission: string, rubric: Rubric[]` | Collaboration |
| `SelfAssessment` | Self-grade | `questions: Question[]` | Reflection |

### 5. Reference Components (Lookup)

| Component | Purpose | Data | When to Use |
|---|---|---|---|
| `Glossary` | Term definitions | `terms: Term[]` | Quick reference |
| `CheatSheet` | Quick reference | `sections: Section[]` | Summary |
| `APIReference` | Function docs | `name: string, signature: string, params: Param[]` | API reference |
| `ComparisonTable` | Feature compare | `features: string[], options: Option[]` | Decisions |
| `ResourceLink` | External ref | `url: string, title: string, type: string` | Further reading |
| `SpecReference` | Standard cite | `spec: string, section: string, quote?: string` | Authority |

### 6. Visualization Components (Visual Learning)

| Component | Purpose | Data | When to Use |
|---|---|---|---|
| `Flowchart` | Process flow | `nodes: Node[], edges: Edge[]` | Algorithms |
| `ArchitectureDiagram` | System structure | `components: Component[], connections: Connection[]` | Systems |
| `SequenceDiagram` | Message flow | `participants: Participant[], messages: Message[]` | Protocols |
| `StateDiagram` | State transitions | `states: State[], transitions: Transition[]` | State machines |
| `NetworkDiagram` | Connections | `nodes: Node[], links: Link[]` | Networking |
| `MemoryDiagram` | Memory layout | `stack: Frame[], heap: Object[]` | Pointers |
| `FileFormatDiagram` | Binary structure | `fields: Field[], byteOffsets: number[]` | File formats |
| `AnimatedDemo` | Step-by-step | `steps: Step[], autoPlay?: boolean` | Processes |

## Component Properties

Every component has:

| Property | Type | Purpose |
|---|---|---|
| `id` | string | Unique identifier |
| `type` | string | Component type name |
| `difficulty` | 1-5 | Cognitive load level |
| `timeEstimate` | number | Seconds to complete |
| `prerequisites` | string[] | Required knowledge |
| `learningObjective` | string | What this teaches |
| `verificationStatus` | enum | verified/unverified/disputed |
| `source` | string? | Authoritative reference |

## Composition Rules

1. **Components don't reference each other** — they're self-contained
2. **Components compose into lessons** — a lesson is a sequence of components
3. **Lessons compose into modules** — a module is a sequence of lessons
4. **Modules compose into courses** — a course is a sequence of modules
5. **Components can be reused across courses** — they're context-free

## AI-Developable Components

These components can be generated by AI given enough context:

| Component | AI Can Generate | Human Must Verify |
|---|---|---|
| `CodeBlock` | Yes (with correct syntax) | Accuracy of code |
| `Quiz` | Yes (with correct facts) | Correctness of options |
| `FillInBlank` | Yes | Appropriate blanks |
| `HexDump` | Yes (with correct data) | Byte accuracy |
| `MemoryLayout` | Yes (with correct data) | Address accuracy |
| `Flowchart` | Yes (with correct logic) | Logic accuracy |
| `ComparisonTable` | Yes (with correct facts) | Fact accuracy |
| `Glossary` | Yes (with correct definitions) | Definition accuracy |
| `DebuggingExercise` | Yes (with correct bugs) | Bug realism |
| `CodeChallenge` | Partially | Test correctness |
| `Simulation` | No | Requires engineering |
| `InteractiveDemo` | No | Requires engineering |

## Verification Requirements

| Component Type | Verification Method |
|---|---|
| Code | Compile + run, check output |
| HexDump | Compare to reference (readelf, xxd) |
| MemoryLayout | Compare to GDB output |
| Quiz options | Check each option against spec |
| Flowchart | Verify logic against spec |
| APIReference | Check against source code |
| SpecReference | Verify quote matches spec |
