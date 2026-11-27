# SEO / organic discovery status — I1 + I2 (2026-11-27)

This is the live ledger for the first discovery work packages of
`production-ready-plan.md` §3 workstream I. It records what is **shipped and
verified locally**, what is **pending a deployed host**, and what needs
**founder access**. No numbers in this file are invented.

## Search Console baseline

- **Property / access:** baseline pending founder access.
- **Owner:** `<founder / TBD — assign at wave kickoff>` (§0.2 rule 10 requires a
  named owner; none has been assigned for this work package).
- **Queries, impressions, clicks, average position:** not measured. Do not write
  placeholder numbers; the baseline is the first export taken after the site is
  verified in Search Console, and it belongs to the founder or the named owner.
- **Sitemap submission:** `https://underlayer.wiqis.com/sitemap.xml` is the URL
  to submit once access exists. Nothing has been submitted yet.

## What is shipped

### I1 — organic discovery infrastructure

- `GET /robots.txt` — 200, `User-agent: *`, `Allow: /`, `Disallow: /api/` and a
  `Sitemap:` line built from `PUBLIC_BASE_URL`.
- `GET /sitemap.xml` — 200. The URL set is generated from the repository's own
  course loader at request time:
  - `/` + `/courses` + `/search` + `/learning-path` (4)
  - six guide/legal pages: `/help`, `/shortcuts`, `/faq`, `/about`, `/terms`,
    `/privacy` (6)
  - 33 course landings `/courses/<id>` (33)
  - 329 lesson URLs `/courses/<id>/lessons/<conceptId>` (329)
  - **372 total**, with a `lastmod` on every entry.
- `GET /favicon.ico` — 200, a valid 16×16 32-bpp ICO generated in memory. The
  repo had no favicon asset; nothing was copied from `DesignAssets`.
- All three are explicit routes registered **before** the `web::App` catch-all
  and answered through `deliver_with_learner`, so they inherit H3's uniform
  security headers, request id, access line, ETag/304 and gzip. Verified: all
  three send `Content-Security-Policy`, `X-Frame-Options: DENY`, HSTS,
  `nosniff`, `Referrer-Policy` and `X-Request-Id`.
- Every served lesson, course landing, `/`, `/courses`, `/search`,
  `/learning-path` and guide page now has exactly one non-empty `<title>`, one
  140–158 character `<meta name="description">`, one `<link rel="canonical">`
  on the public host, `og:title`, `og:description` and `og:url`. Course and
  lesson pages additionally carry `Course` and `BreadcrumbList` in one
  `application/ld+json` `@graph`. **There is no `aggregateRating` and no
  `review`** (per `wiqis-seo-content` §1–§2).
- All head markup is emitted by `HtmlPage` (`PageHead` + `append_head_view`);
  every interpolated title/description/URL is escaped with `html_escape`, and
  every JSON-LD string with `json_escape` plus `<`/`>`/`&` → `\uXXXX`. No
  string-built markup and no `@never_destructed string` globals.
- `PUBLIC_BASE_URL` (default `https://underlayer.wiqis.com`) is the one source
  for canonicals, og:url, sitemap locs and robots' Sitemap line. Local runs set
  it to `http://localhost:<port>`; no production host is hardcoded in a way
  that breaks local testing.

### `<lastmod>` derivation

No course ships a `changelog.json` yet (G9 is not built), and the manifest has
a numeric `version` but no date. `<lastmod>` is therefore the verified content
snapshot date from `production-ready-plan.md` §1 (**2026-11-26**), advanced by
one day per course version bump. This is documented rather than invented: when
G9 lands a real changelog date it should replace the derivation. All 372
entries currently read `2026-11-26` because every manifest is version 1.

### I2 — shadowed hint route

`GET /api/exercises/hint` is registered **before** `GET /api/exercises/:conceptId`
in `app/main.ch`; the parameterised route had been capturing `hint` as a
concept id. `handle_exercise_hint` also falls back from an unauthored hint
level to `hint1`, because the seeded bank only carries `hint1`, so levels 1–3
all return a real lesson-sourced hint rather than an empty string.

## Local verification (2026-11-27, port 9034, throwaway DB)

| Check | Command | Result |
|---|---|---|
| Build | `TCCCompiler chemical.mod -o build/underlayer-i1i2.exe -bm-modules --no-cache` | green |
| Hint route | `GET /api/exercises/hint?exercise_id=elf_bytes_0&level=1..3` | `200`, non-empty hint, `level` echoed |
| Unknown id | `GET /api/exercises/hint?exercise_id=hint&level=1` | `404 {"error":"exercise not found"}` — never `{"concept_id":"hint"}` |
| Discovery routes | `GET /robots.txt`, `/sitemap.xml`, `/favicon.ico` | `200`, `200` (372 locs), `200` (1118 bytes), all with the full header contract |
| SEO surface | `python tools/seo_surface_check.py http://localhost:9034` | 372 URLs from `/api/courses` + course details, 372 sitemap locs, all consistent |
| SEO negative plant | `python tools/seo_surface_check.py http://localhost:9034 --limit 8 --plant` | planted short description detected, exit 0 when it is the only finding |
| SEO selftest | `python tools/seo_surface_check.py --selftest` | OK |
| Shadow route | `python tools/literal_route_shadow_check.py` | OK — 190 routes parsed, 0 shadows |
| Shadow negative plant | `python tools/literal_route_shadow_check.py --selftest` and `--plant` | both OK — planted shadow detected |
| Journey | `python tools/journey_quality_check.py http://localhost:9034 --all --workers 8` | 364/364 |
| Theme | `python tools/theme_check.py http://localhost:9034` | 56/56 (1 optional browser check skipped) |
| Pager | `python tools/lesson_pager_check.py http://localhost:9034` | 35/35 |
| Helpful dedupe | `python tools/helpful_dedupe_check.py http://localhost:9034` | 12/12 |
| Bridge | `python tools/bridge_probe.py http://localhost:9034` | 3/3 (one informational SKIP: bad token → 502 because no account backend is reachable locally) |
| Security headers | `python tools/security_header_coverage.py http://localhost:9034` | 11/11 paths, identical contract |
| Security/rate limits | `python tools/security_check.py --port 9034 --db build/verify-i1i2.db` | 72/72 |
| Chemical suite | `build/tests-i1i2.exe` | 138/138 on a clean repeat run; two earlier runs reported 136–137/138 with `RUNTIME ERROR: invalid memory access` in upstream `http::Server::release_connection` (`std::Arc::get`). The failing test name varied between runs; the fault is in the upstream HTTP connection-release path, not in any file changed for I1/I2. Reported, not hidden. |

The `--workers 8` flag on the journey checker is required locally: the served
artifacts are correct, but a sequential crawl of 329 lessons exceeds a 10-minute
command timeout on this machine.

## CI wiring

The two new checkers are **not** wired into `.github/workflows/` by this work
package — that is the coordinator's step (H4). The exact commands to add to the
served-artifact checker stage are:

```
python3 tools/literal_route_shadow_check.py
python3 tools/seo_surface_check.py "$BASE_URL"
python3 tools/seo_surface_check.py --selftest
python3 tools/literal_route_shadow_check.py --selftest
```

## Not verified / still open

- **No deployed-host proof.** All probes above are against a freshly built
  local binary on `localhost:9034`. The production host, TLS, CDN/cache
  behaviour and real Googlebot fetching are untested.
- **Search Console:** baseline pending founder access; nothing submitted, no
  coverage or query data.
- **G4/C2 browser drives:** the hint route is proven by HTTP probes, not by a
  browser retry-ladder drive. No CDP/browser session was run in this pass.
- **Static `file://` course output:** the head metadata is applied by the
  server handlers, so a lesson opened straight from `courses/*/output/` does
  not get the new head. Same limitation already documented for the lesson
  header (EC8); not a target of I1.
- **Owner:** no named owner is recorded for I1/I2; assign one at the next wave
  kickoff per §0.2 rule 10.
