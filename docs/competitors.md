# Competitive Analysis

## Platform Comparison

### Brilliant.org

**What they do:** Interactive problem-solving in math, CS, data analysis. ~60+ courses. Every lesson is a problem to solve — no video lectures.

**Strengths:**
- 100% interactive format — no passive consumption
- "Explain why wrong" feedback on every incorrect answer
- Beautiful visual design
- Excellent mobile apps with offline caching

**Weaknesses:**
- No spaced repetition — forgetting curve is ignored
- No review of previously learned concepts
- Not deep enough for systems topics (no ELF, no reverse engineering, no kernel)
- $30/month is steep
- Course completion = "done" with no maintenance mode

**What we take:** Interactive format, immediate feedback on wrong answers, visual quality.

**What we improve:** Spaced repetition, systems-level depth, retention tracking, anxiety-friendly pacing.

### Exercism.org

**What they do:** 8660 exercises across 83 programming languages. Human mentoring. Web editor + CLI.

**Strengths:**
- 100% free (non-profit)
- Human mentoring is rare and valuable
- Language breadth is unmatched
- Open source

**Weaknesses:**
- No spaced repetition
- Mentoring quality varies wildly
- No structured curriculum for systems topics
- No progression tracking or retention metrics
- No mobile experience

**What we take:** Free/open model, mentorship concept, exercise-based learning.

**What we improve:** Spaced repetition, structured curriculum, mobile/offline, retention tracking.

### CodeCrafters.io

**What they do:** Build real systems from scratch (Redis, Git, SQLite, Shell). Stage-based progression. Multi-language support.

**Strengths:**
- "Build real things" is maximally motivating
- Stage-based progression gives micro-wins
- Git-based workflow is authentic
- Instant automated feedback

**Weaknesses:**
- No spaced repetition
- No conceptual explanation — tests only
- No mentorship
- No mobile experience
- Challenges are narrow (build X) not broad (understand Y)

**What we take:** Build-real-things philosophy, stage-based progression, instant feedback.

**What we improve:** Conceptual understanding (not just building), spaced repetition, mobile, breadth.

### roadmap.sh

**What they do:** Community-curated visual roadmaps for developer roles. Links to external resources. Progress tracking.

**Strengths:**
- Solves "what should I learn next?"
- Visual structure makes overwhelming topics approachable
- Free and open source

**Weaknesses:**
- No actual learning content — just links
- No exercises, no practice, no feedback
- No spaced repetition
- No retention mechanism

**What we take:** Visual knowledge graph, structured progression.

**What we improve:** Everything — actual content, exercises, feedback, retention.

### nand2tetris.org

**What they do:** Build a complete computer from NAND gates to Tetris. 12 projects. Hardware → software → OS → compiler.

**Strengths:**
- "From first principles" journey is unmatched
- Projects are deeply satisfying
- Free and open source
- Well-paced and genuinely educational

**Weaknesses:**
- No spaced repetition
- No adaptive difficulty
- Tools are dated (Java-based)
- One-shot completion — no review mechanism

**What we take:** First-principles approach, project-based learning, from-nothing-to-understanding arc.

**What we improve:** Spaced repetition, adaptive difficulty, modern tooling, review mechanism.

### OpenSecurityTraining2

**What they do:** 70+ free courses in cybersecurity. Video lectures + slides + hands-on labs.

**Strengths:**
- Deepest free cybersecurity training available
- Real-world CVE analysis
- Completely free and open source

**Weaknesses:**
- No interactive exercises on-platform
- No automated testing or feedback
- No spaced repetition
- Not beginner-friendly

**What we take:** Depth of technical content, real-world focus, free model.

**What we improve:** Interactivity, automated feedback, accessibility, retention.

### Coursera / edX

**What they do:** University-produced courses. Video lectures, quizzes, assignments, peer review.

**Strengths:**
- University credibility
- Production quality is high
- Structured with deadlines

**Weaknesses:**
- Expensive ($59/mo for Coursera Plus)
- Video-heavy format is passive
- Completion rates are low (~5-15%)
- Certificate ≠ competence
- No spaced repetition

**What we take:** Production quality, structured progression.

**What we improve:** Active learning, retention, pacing, cost (free), anxiety-friendly design.

## Gap Analysis

| Feature | Brilliant | Exercism | CodeCrafters | roadmap | nand2tetris | OST2 | Coursera | **Underlayer** |
|---|---|---|---|---|---|---|---|---|
| Spaced repetition (FSRS) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Interleaved practice | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Retrieval-first design | Partial | Partial | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Anxiety-friendly pacing | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Energy/fatigue management | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Systems-level depth | ❌ | ❌ | Partial | Partial | Partial | Partial | Partial | **✅** |
| Offline-first | ❌ | Partial | ✅ | ❌ | ✅ | ✅ | Partial | **✅** |
| Retention tracking | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Weakness detection | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Course portability | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | **✅** |
| Free + open source | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | **✅** |
| Misconception modeling | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Difficulty reframing | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |
| Source traceability | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **✅** |

## Underlayer's Unique Position

No existing platform combines:
1. **Spaced repetition** (FSRS) with
2. **Deep technical content** (ELF, PE, TLS, linkers) with
3. **Anxiety-friendly design** (pacing, energy management, struggle normalization) with
4. **Course portability** (download, offline, own your data) with
5. **AI-constrained generation** (verified against specs, no hallucination)

This is the gap Underlayer fills.
