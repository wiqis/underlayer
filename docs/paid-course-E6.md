# E6 — the paid course (first module)

**Course id:** `binread` — *Read a Binary by Hand*
**Entitlement product:** `underlayer.binread`
**Price:** displayed at `account.wiqis.com/purchase` from `COURSE_PASS_PRICE_USD` (default 39 USD).
**Provider:** Paddle as merchant of record (resolved 2026-11-14). No live merchant account exists on this machine.

## Scope — an honest first module, not a full course

The §6.3 ruling named a marketable paid course but a full multi-module course
could not be authored and verified safely in this batch. This is therefore a
**first module**: four concepts, one architecture (x86-64), one file class
(ELF64 little-endian). It is a real, graded, served course — not filler — and
its limitations are written into `courses/binread/manifest.json`.

| Concept | What the learner can do |
|---|---|
| `bin-magic` | Identify class, byte order, version and ABI from `e_ident` |
| `bin-header` | Turn `e_phoff`/`e_shoff`, entry sizes and counts into byte ranges |
| `bin-segments` | Read `PT_PHDR`, `PT_INTERP` and the four `PT_LOAD` entries of a real PIE |
| `bin-symbols` | Separate the 7-entry `.dynsym` from the 43-entry `.symtab` |

## Verification standard

- Every numeric claim is read from `courses/binread/assets/samples/readelf_*.txt`,
  captured with GNU readelf 2.39 from specimens copied byte-for-byte from the
  already-verified ELF corpus. Producer versions are inherited from
  `courses/elf/assets/samples/SOURCES.md`, not invented here.
- `tools/generate_paid_course_bank.py` uses the existing
  `generate_graded_banks.py` readers to derive one graded item per concept from
  that concept's own in-page quiz, with `source_ref`/`source_quote` citations.
- `tools/verify_binread.py` checks specimen SHA-256 values, every numeric
  claim against the captured evidence, the I7 manifest fields, the paid flag,
  the answer keys and a poison case. Result: **60/60** (61 with the deliberate
  poison, which fails as required).

## Gating

`paid: true` and `product: "underlayer.binread"` live in the manifest.
`GET /api/courses` exposes an additive `paid` boolean; course metadata and the
landing page remain public (they are the store front and the crawler's input).
Lesson content is gated server-side by a literal route for `binread`, which
asks `account.wiqis.com/api/entitlements/check` with a service token and never
keeps a local boolean. Without a pass a lesson returns **402** with a message
that says progress is saved. With a pass it returns the same journey-patched
HTML as any other lesson.

## Test-mode boundary — NOT a real purchase

No real Paddle account or credentials are configured. `POST
/api/entitlements/test-event` on the local account service signs a caller-
supplied event with the configured test secret and runs it through the *same*
webhook processing path as a real Paddle event. It is refused unless
`PADDLE_MODE=test` and a configured service token is supplied. **It does not
contact Paddle and does not represent money changing hands.** A real launch
requires founder configuration: Paddle account, webhook secret, checkout URL,
payout profile, and the live `/api/paddle/webhook` endpoint pointing at it.
