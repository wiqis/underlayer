# Secrets inventory (H8, 2026-11-27)

Scope: this repository's build/deploy path and the identifiers it consumes.
Nothing in this file is a secret value. **No secret literal is tracked in this
repository** — the search on 2026-11-27 found only the *name* `GITHUB_TOKEN`,
first in the Dockerfile's former build `ARG` and now in the BuildKit recipe
below. The Android signing key and `google-services.json` live in the separate
`Android/Apps/underlayer-kmp` repo and are that repo's owner's responsibility
(D6); they are inventoried here only so the fleet has one list.

## Table

| Secret / identifier | Purpose | Dev source | Staging source | Prod source | Owner | Rotation interval | Last rotation |
|---|---|---|---|---|---|---|---|
| GitHub build token (`github_token`) | Read access to private `github.com/wiqis/brandlib` during the Cloud Build / Docker image build. **Never needed at runtime.** | Optional; local checkout uses `../../WebLibs/brandlib`, so no token | Founder-controlled CI/Cloud Build secret, mounted only for the compile step | Same BuildKit secret mount; injected with `--secret id=github_token,env=GITHUB_TOKEN` | **TBD — founder to name** (placeholder; not an operational control until named) | 90 days, and immediately on any suspected exposure | Not yet rotated — first inventory, no rotation performed |
| Account OAuth client id (Underlayer web) | Public identifier for embedded `account.wiqis.com` sign-in; not a credential | Local `ACCOUNT_URL`/config defaults; public value | Deployed account service config | `account.wiqis.com` service config | **TBD — founder to name** | On provider key rotation only; public identifier, no secret value | Not applicable / not recorded |
| reCAPTCHA site key (Underlayer web) | Public site key for the embedded sign-in flow | Local config defaults | Deployed account service config | `account.wiqis.com` service config | **TBD — founder to name** | On provider key rotation only; public identifier | Not applicable / not recorded |
| Paddle webhook secret | Verify Paddle course-pass webhooks (F2, **planned — not implemented**) | None yet | Founder-controlled secret store when F2 ships | Founder-controlled secret store when F2 ships | **TBD — founder to name** | 180 days once live | Not yet created |
| Android release signing key + store passwords | Sign the frozen `com.wakaztahir.learnpythonapp` release (D6, **planned; old committed key treated as compromised**) | Not used in dev (debug keystore) | Founder-controlled secret storage; env/Gradle properties, not the repo | Same; `signingConfig` reads path/alias/passwords from env/Gradle properties | **TBD — founder to name** (D6 owner) | On every release-key change; immediate for the compromised historical key | Not yet rotated — D6 owns the new key |
| `UL_BUILD_*` provenance values | Build identity in `/api/health` (H5) — **not secrets** | `unknown` locally | Set by the deploy step | Set by the deploy step | Deploy owner (H5) | Per deploy (values are the commit/compiler/time) | Per deploy; see `docs/deployment.md` §4 |

OAuth client ids, reCAPTCHA **site** keys and `google-services.json` are public
identifiers, not secrets. The secret halves (client secrets, reCAPTCHA **server**
keys, Paddle webhook secret, signing passwords) must never appear in this repo.

## Build-token handling in this repository

`Dockerfile` no longer has `ARG GITHUB_TOKEN`. The compile step uses a BuildKit
secret mount:

```dockerfile
RUN --mount=type=secret,id=github_token,target=/run/secrets/github_token \
    mkdir -p /workspace/build && set -eu; \
    cfg=/tmp/underlayer-gitconfig; \
    ...
    export GIT_CONFIG_GLOBAL="$cfg"; \
    chemical chemical.mod -o /workspace/build/underlayer.exe --mode release --no-cache; \
    rm -f "$cfg"
```

Why the temp gitconfig: `git config --global url."https://x-access-token:$TOKEN@…"`
would write the token into `/root/.gitconfig`, which **is** committed into the
layer by that `RUN`. Redirecting git's config to a temp file, exporting
`GIT_CONFIG_GLOBAL` for that shell only and deleting it in the same `RUN` keeps
the token out of both the layer and image metadata. The token is never an
`ENV`, never a build arg, and is absent entirely when no private module needs
fetching.

Build invocation: `docker build --secret id=github_token,env=GITHUB_TOKEN …`.
`GITHUB_TOKEN` here is the *name* of an environment variable, not a value.

**Verification limit:** Docker is installed on this machine but the daemon is
not running (`docker info` fails to connect to the Linux engine pipe). So
`docker history <image>` and an image-layer scan were **not** run; no claim of a
clean built image is made. The founder/owner must run, after the first secret-
mounted build:

```bash
docker history --no-trunc <image> | grep -i 'x-access-token\|github_token'  # expect no match
docker run --rm <image> sh -c 'cat /root/.gitconfig 2>/dev/null || true'     # expect no token
```

The command's *lines* contain no token — only the shell reads the mounted file.

## Environment separation and rotation (founder-owned)

- **Staging** must use a separate SQLite file/volume and a separate account
  configuration from production. Today that is a **founder console action**;
  no staging service is declared in this repo.
- Rotate one staging token end-to-end (create new secret → update the build
  input → rebuild → verify the private clone works → revoke the old token) before
  claiming H8 green. No rotation was performed by this work package.
- Owners are placeholders until the founder names humans. A placeholder is not
  an operational control and must not be recorded as "owned" in EC2/EC15.
