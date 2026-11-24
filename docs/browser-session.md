# Browser session cookie contract (2026-11-24)

This is the human-readable version of the constants in `web/src/session_cookie.ch`.

## Why

Before this change the only credential was a bearer token. `/api/auth/login`
returned `session_token`, the browser kept it in `localStorage`, and
`auth_get_learner_id` read only `Authorization: Bearer …`. A page navigation
sends no Authorization header, so the server-side gate on `/dashboard`,
`/review`, `/progress`, `/bookmarks`, `/notes`, `/study-plans`,
`/achievements`, `/streaks`, `/notifications` and `/certificates` always
redirected a genuinely signed-in reader to `/login?next=…`. The fix gives the
browser a credential it sends on navigation; it does **not** change what
"authorised" means.

## Cookie

| Property | Value |
|---|---|
| Name | `ul_session` |
| Value | the same 64-hex-character token returned as JSON `session_token` |
| Attributes | `HttpOnly; SameSite=Lax; Path=/; Max-Age=2592000` (30 days), plus `Secure` when the request is HTTPS |
| Domain | none (host-only) |
| Set by | `POST /api/auth/register`, `POST /api/auth/login` (on success) |
| Cleared by | `POST /api/auth/logout` — same attributes, `Max-Age=0` |

`Secure` is computed from the request: `https` wire protocol or the first token
of `X-Forwarded-Proto` (the container terminates TLS at a proxy, so production
requests arrive as plain HTTP with that header). Local `http://` development
therefore gets no `Secure` flag and can still store the cookie.

The 30-day `Max-Age` matches `create_session()`'s `expires_at = now + 2592000`.
A cookie that outlives its row is harmless — the lookup fails.

## Precedence and validation

`auth_get_learner_id` resolves a token once, in this order:

1. `Authorization: Bearer <token>` if present — **bearer keeps priority**.
2. If there is no Authorization header, the `ul_session` cookie.

An Authorization header that is present but malformed reads as signed out; it
does not fall back to the cookie. Whatever token is chosen is hashed with
SHA-256 and looked up in `auth_sessions` with `expires_at > now`. Missing,
unknown, revoked and expired tokens all read as signed out — the gate is not
weakened, and there is no `demo` fallback. `has_session`, `has_session_for` and
every API handler share this one resolution path.

## Why bearer remains

The JSON `session_token` response is unchanged. Mobile clients (the Android
app and its progress-sync endpoints) have no browser cookie jar and send
`Authorization: Bearer …` explicitly. Keeping both credentials means one
login response serves both clients, with the same token and the same database
lookup behind them.

## Delivery

Every route answers through `underlayer_web::deliver`. It copies the handler's
response rather than rebuilding it, so handler-set headers reach the wire; a
response carrying `Set-Cookie` is excluded from `If-None-Match` → 304
revalidation, because a conditional response cannot deliver a new credential.

## Client script

`web/src/session_js.ch` sends `credentials: 'same-origin'` on its fetches and
uses a non-sensitive `ul_signed_in` marker as its display signal. After a
browser login it does not attach the legacy localStorage token as a bearer —
that would outrank the valid cookie on the server. The localStorage token
remains only as a legacy mirror for offline/static pages and older sessions;
it is cleared on 401 and on sign-out. On sign-out the server deletes the
session row and expires the cookie, so the next navigation lands signed out.
