# H11 — Embedded sign-in proof (2026-11-28)

Verification package only. The shared account service was NOT changed.

## What ran

Local debug binary `build/h9-h17-underlayer-v2.exe`, disposable DB
`build/h9-h17-throwaway.db`, port **9060**, same-origin pages driven by Chrome
via Playwright with a **local stub account service** installed by request
routing at `https://account.wiqis.com/**`.

- `python tools/auth_shape_check.py --selftest` — 3 cases, 2 negative plants:
  a remote `href="https://account.` and a local opener missing
  `data-auth-open` each fail the checker.
- `python tools/auth_shape_check.py --base http://127.0.0.1:9060` — source:
  **zero** remote hrefs in `web/src`/`content/src`; local openers in
  `web/src/pages_auth_embedded.ch` and `content/src/lesson_nav.ch`. Served:
  **zero** remote hrefs, zero broken pages, 10 archetype pages checked, 6 with
  the local opener.
- `python tools/auth_shape_check.py --base … --drive` — **PASS**:
  local `/sign-in` opener opened the dialog, the stub account frame loaded,
  password → 6-digit MFA posted `login_success`, and the page called
  `POST /api/auth/from-account` (the local session bridge) with `{}`.
  Evidence: `build/h11-evidence/evidence.json`,
  `h11-password-mfa.png`, `h11-passkey-google-shapes.png`.

## Captured payload shapes (stub-authored, not authoritative)

The two `postMessage` events captured from the stub were:

```
{type:"passkey-shape", passkey:{
   publicKeyKeys:["challenge","rpId","userVerification","allowCredentials"],
   challenge_type:"string", rpId:"account.wiqis.com",
   userVerification:"preferred", source:"local-stub-only"}}
{type:"google-popup-shape", google:{
   popup_url:"https://accounts.google.com/o/oauth2/stub"}}
```

These are the shapes the LOCAL STUB emitted. They were captured, not invented
from static inspection of a fixture — but they are **not** a claim about the
real account service's ceremony.

## Dated exceptions — NOT verified, founder-owned

- **Real passkey ceremony (WebAuthn authenticator): NOT EXERCISED.**
  This machine has no authenticator and no real account credentials. A stub
  cannot prove `navigator.credentials.create/get` works against
  `account.wiqis.com`. **Owner: founder — run on a device with a real
  authenticator and record the ceremony transcript.** Date recorded:
  2026-11-28.
- **Real Google popup + MFA: NOT EXERCISED.** Only a stub popup at
  `https://accounts.google.com/o/oauth2/stub` and a local second factor were
  driven. **Owner: founder — run the real Google consent flow against a
  registered OAuth client and save screenshots/console.** Date recorded:
  2026-11-28.
- Safari human check: not run (no Safari on this machine). Owner: founder.

No exception here is treated as coverage. The link-shape half is a CI gate;
the ceremony half remains an owner-signed gap.
