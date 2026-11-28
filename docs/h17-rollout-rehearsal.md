# H17 — Staged rollout rehearsal (2026-11-28)

Same binary `build/h9-h17-underlayer-v2.exe`, no rebuild between the two runs.

| Env | `UL_PAID_GATING_ENABLED` | `UL_LEARNER_SURFACE_V2` | `/api/health` | `/login` data attributes |
|---|---|---|---|---|
| Instance A (port 9060, throwaway DB) | unset | unset | `"paid_gating_enabled":"off","learner_surface_v2":"off"` | `data-paid-gating="off" data-surface-v2="off"` |
| Instance B (port 9064, throwaway DB) | `1` | `true` | `"paid_gating_enabled":"on","learner_surface_v2":"on"` | `data-paid-gating="on" data-surface-v2="on"` |

Both flags default OFF. They are read on demand in `core/src/config.ch`,
surfaced at the `/api/health` route entry (`app/main.ch`) and on the sign-in UI
entry point (`content/src/embedded_auth.ch`). Flipping them changes behaviour
on the next request without a rebuild; the rehearsal above is the evidence.

Honest scope note: because F3 (paid gating) and the G1–G4 v2 surface do not yet
exist as flag-gated code paths, today's ON state only changes the observable
flag state at these entry points. The full "bad F3/G1–G4 release can be killed
by config" property requires those features to consume the same two helpers
when they ship. That wiring is a follow-up, not a claim made here.

## Rollback target

From `tools/release_probe.py` / `docs/deployment.md` §4: the deploy rollback
target is the last recorded release build digest and compiler pin returned by
`/api/health` (`commit`, `compiler_version`, `build_mode`, `built_at`). Run

```
py -3 tools/release_probe.py https://underlayer.wiqis.com
```

before and after a flag flip or a binary swap; a payload without provenance
means "healthy but unverified", not "wrong service". The deployed service
still answers the two-field health payload, so no deployed rollback digest is
claimed — that remains a founder action.

## Android internal-track steps — DOCUMENTED, NOT EXECUTED

Per §6.1, the Play Console internal-track → production steps (upload the
signed 1.0.4/code-4 APK, internal track, 24 h crash-free/ANR gate, promotion)
apply **ONLY under §6.1(b)** (freeze lifted). Under (a)/(c) they are frozen:
no launch, no growth work. No Play Console action was taken by this agent; all
such steps are founder-owned. The freeze ruling itself is recorded in
`Docs/decisions.md` and is not re-decided here.
