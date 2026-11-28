# Specimen sources — `front` (compiler front end)

**Verification date:** 2026-11-28.
**Toolchain contract:** python-cpython312 (declared in `front-specimen.json`;
no gcc/clang/readelf was used to produce this bundle).
**Toolchain:** CPython 3.12.2 (tags/v3.12.2:6abddd9, Feb 6 2024, 21:26:36)
[MSC v.1937 64 bit (AMD64)], Windows. The two authorities are the standard
library modules `tokenize` and `ast` shipped with that interpreter; no third
party package was used.

## Files

| File | What it is | How it was produced |
|---|---|---|
| `specimen.src` | The real source text `a + 2 * (b - 3) / 4` followed by one newline | Written by hand as the course specimen; it is a valid Python expression, so a real interpreter can check it |
| `specimen.tokens.json` | The verified token stream, 11 `[kind, text]` pairs | `tokenize.generate_tokens` on `specimen.src`, filtered to `NAME`/`NUMBER`/`OP`; compared to `runner/frontier.py::lex` — 11/11 agree |
| `specimen.ast.json` | The verified AST, 9 nodes | `ast.parse(src.strip(), mode='eval').body` converted to the course's node encoding; compared to `runner/frontier.py::parse` — structurally equal |

## Claim ledger (each number is traceable to the file on disk)

| Claim | Value | Authority |
|---|---|---|
| Token count | 11 | `tokenize` output; also the length of `specimen.tokens.json` |
| Token kinds and order | NAME a, OP +, NUMBER 2, OP *, OP (, NAME b, OP -, NUMBER 3, OP ), OP /, NUMBER 4 | `tokenize` output |
| AST node count | 9 | `ast.parse` converted, counted by `frontier.node_count` |
| AST root | `Add(Name('a'), Div(Mult(2, Sub(Name('b'), 3)), 4))` | `ast.dump` of the parsed specimen |
| Precedence and associativity | unary `-` tighter than `*`/`/` tighter than `+`/`-`; binary forms left-associative | `ast.parse` tree shape for this specimen; Python Language Reference §6.5, https://docs.python.org/3/reference/expressions.html#operator-precedence (read 2026-11-28) |

## What was NOT checked

- Floating-point literals, exponentiation (`**`), string literals, comparison
  operators, attribute access, function calls, assignment and statements. The
  course's language is the documented subset only.
- Runtime **values**: the specimen is parsed, never evaluated. No claim is made
  about what `a` or `b` would be bound to.
- Other Python versions, other implementations (PyPy, Jython), and the full
  Python grammar. The oracle is specifically CPython 3.12.2.
- Bytecode, machine code, object files, linking and loading. This specimen is
  the first link of the chain only; those are taught by `compback` and the
  format courses, and are not re-taught here.
