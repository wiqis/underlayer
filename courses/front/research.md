# Research and verification record — `front` (compiler front end)

**Course id:** `front`. **Place in the chain:** the FIRST link — lexing →
recursive-descent parsing → AST. The next link (`front` AST → IR → machine code)
is taught by `compback`; this course neither re-teaches it nor claims it.
**Researched and verified:** 2026-11-28.
**Named, dated toolchain:** CPython **3.12.2** (tags/v3.12.2:6abddd9, Feb 6 2024,
21:26:36) [MSC v.1937 64 bit (AMD64)], Windows; standard-library `tokenize`
and `ast` only. Chemical build validated with the pinned
`D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe`.

## Phase 0 — scope

- **Subject:** a real lexer and recursive-descent parser for a documented small
  language: Python integer arithmetic expressions restricted to NAME, NUMBER,
  `+`, `-`, `*`, `/` and parentheses.
- **Why:** `docs/course-mission.md` defines the path from parsing to an
  executable; the collection taught both ends (formats, backends) but
  `docs/courses-todo.md:878-887` had every front-end item unchecked. This
  course is the first link, deliberately complete rather than a survey.
- **Target learner:** someone who can read a little Python and wants to build a
  compiler front end without delegating it to a library.
- **Prerequisites:** basic Python syntax; no prior compiler course.
- **Outcome:** write a lexer, write a recursive-descent parser, produce an AST,
  and check both against an independent authority.

## Phase 1 — authoritative sources (each read, not assumed)

| Source | What it settled | Where |
|---|---|---|
| Python Language Reference, *Operator precedence* (§6.17 in the docs read 2026-11-28), https://docs.python.org/3/reference/expressions.html#operator-precedence | Unary `+x`/`-x` binds tighter than `*, @, /, //, %`, which bind tighter than `+, -`; "Operators in the same box group left to right" | quoted in the course's precedence unit |
| Same reference, *Literals* (§6.2.3) | "negative and complex numbers, like `-3` ... are syntactically not literals, but unary or binary arithmetic operations involving the `-` or `+` operator" — so the AST must contain `UnaryOp(USub, Constant(3))`, not `Constant(-3)` | implemented in `unary()` and checked by the fixture |
| CPython `tokenize` module, https://docs.python.org/3/library/tokenize.html | `generate_tokens(...).tok_name` values `NAME`, `NUMBER`, `OP` for the specimen | `assets/samples/specimen.tokens.json` |
| CPython `ast` module, https://docs.python.org/3/library/ast.html | `ast.parse(src, mode='eval')` and `ast.dump` give the authoritative tree | `assets/samples/specimen.ast.json` |
| Real specimen on disk | `a + 2 * (b - 3) / 4` → **11** tokens, **9** AST nodes; root `Add(a, Div(Mult(2, Sub(b, 3)), 4))` | `assets/samples/specimen.src`, `SOURCES.md` |
| `docs/course-mission.md`, `docs/course-development-handbook.md` | The 7-phase standard, the chain position, and the "no invented byte/offset/spec claim" rule | governing docs |

## Phase 2 — curriculum

Three finishable concepts, one module:

| concept id | roadmap item | minutes |
|---|---|---:|
| `fe-lexer` | Learn Lexers | 22 |
| `fe-recursive-descent` | Learn Recursive-Descent Parsing | 26 |
| `fe-ast` | Learn Abstract Syntax Trees | 24 |

Ids are prefixed `fe-` because `web/src/helpers.ch` resolves concept ids
**globally** with no course key; the verifier asserts the three roadmap names
are ABSENT as whole segments so the rename cannot be undone by accident.

## Phases 3–4 — learning design and content

Each concept has the handbook's eight units (WHY, MODEL, REALITY, EXAMPLE,
INTERACT, RETRIEVE, APPLY, CONNECT), one in-page graded quiz, and one statement
whose numeric claim is checked by `tools/verify_front.py`. The `fe-ast` unit
contains the interactive runner: the learner types a source expression, the
course's lexer/parser path produces a token stream and AST, and an independent
Pratt parser in the same page is the oracle; the two are compared **by value**
(`JSON.stringify`), not by display text. A wrong program produces a calm,
specific error naming the offending token or missing operand.

## Phase 5 — verification

Run `python tools/verify_front.py`. It re-derives the token stream from
`tokenize` and the tree from `ast.parse`, compares both to the shipped fixtures
and to `runner/frontier.py`, counts the verified claim sentences present in the
lesson sources, and checks every graded item's `source_ref`/`source_quote`.
`--poison` plants a mutation in each reported count in an isolated temp tree
and requires that count to move.

## Phase 6 — adversarial review

- **Expert:** precedence is not a list of facts here; the leaf shape `2 * (b-3) / 4`
  is `(2 * (b-3)) / 4` because `*`/`/` are left-associative, and the fixture is
  the proof. `-3` is a unary operation, not a literal; the citation above is
  quoted rather than paraphrased into a false claim.
- **Beginner:** the grammar is printed in full before any code is shown; the
  runner's errors name the token they rejected; no term is used before its unit.
- **Test author:** the runner compares by value, so a differently-spaced but
  structurally identical tree is accepted — the learner is being tested on the
  AST, not on our printer. Distractors in graded items are terms from the same
  lesson, so a learner cannot answer by elimination from foreign vocabulary.

## Phase 7 — publication and explicit deferral

`manifest.json` carries the full I7 metadata contract (`author`, `license`,
semver `version`, `toolchain`, `spec_source`, `last_verified`, `limitations`).

**This first module does NOT cover:** semantic analysis, name resolution, type
checking or inference, IR construction, SSA/CFG/dominators, optimisation,
instruction selection, register allocation, scheduling, code generation,
assembly, object files, relocation, linking, loading, or runtime support. It
also excludes floating-point literals, `**`, strings, calls, statements and
error recovery beyond a clear first-error message. The next link is `compback`;
the type-system and IR items stay open in `docs/courses-todo.md` and are linked
there. No claim is made that this course alone completes the mission chain.
