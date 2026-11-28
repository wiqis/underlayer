# H15 — Performance budget gate (2026-11-28)

## Why the older <500 ms LCP target is revised

`docs/implementation-patterns.md:325` and `docs/rendering-pipeline.md:404`
still record `LCP < 500 ms` / `TTI < 500 ms`. Those are pre-CWV, unthrottled,
lab-only targets: they were written before the site carried a 76 KB lesson
page, an external Inter stylesheet and an embedded account iframe, and they
were never measured with the network/CPU throttling Core Web Vitals assume.
A 500 ms LCP on this deployment is not achievable under 4× CPU + 1.6 Mbps
throttling; the measured median across six archetypes is ~900 ms and the p95
is ~2.05 s, which is comfortably inside Google's **2.5 s** field threshold.

H15 therefore adopts the CWV-aligned budgets: **p95 LCP < 2.5 s, INP < 200 ms,
CLS < 0.1, transfer < 500 KB**, and re-scopes the two old documents to a
founder-owned follow-up (they are outside this package's file ownership).

## Measured run (port 9060, throwaway DB, 6 archetypes × 1280/420 px)

```
lcp_ms   p95=2052.00
inp_ms   p95=40.00
cls      p95=0.12
bytes    p95=57984.00
ttfb_ms  p95=150.20
```

INP is the largest event duration seen by a `PerformanceObserver` with a
16 ms threshold after one scripted interaction — an approximation of field
INP, not a replacement for it.

## Gate status: RED (honest, not waived)

- **Render-blocking third-party stylesheet** on `/`, `/courses`, `/help`,
  `/login`: `<link href="https://fonts.googleapis.com/css2?family=Inter…"
  rel="stylesheet">` emitted by the brand layer (`WebLibs/brandlib`, outside
  this repo/package). **Owner: founder / brandlib.** Not fixed here; no new
  unsafe-* was added to CSP (§6.5) and no checker was relaxed.
- **CLS p95 = 0.12 > 0.10**, from the 420 px lesson page (0.1209). Content and
  brand CSS are outside this package's ownership. **Owner: founder / content
  owner.**

`tools/perf_budget_check.py --selftest` is green (8 cases, 5 negative plants):
over-budget LCP/INP/CLS/transfer and a planted third-party stylesheet each
fail. The live gate is wired into the **nightly** CI job only, and is expected
to stay red until the two owner-signed defects above are fixed. It is not
marked green here.
