# Local authentication (P04 / P04A)

Implemented in P04 and migrated/tested at `/` on 2026-09-18. This is a local feasibility implementation,
not a hosted authentication deployment. P05's implemented trial code and provider
setup are documented separately in [HOSTED_AUTH](HOSTED_AUTH.md). This runbook
continues to use fictional recipients and local Mailpit only.

## Hosting decision update (2026-09-18)

The confirmed production URL is now **`https://reviews.pedro-costa.dev/`**. This
document's commands now use the verified P04A local equivalent,
**`http://127.0.0.1:4173/`**. The callback scrubber, Dart local gate, preview/frame,
Supabase Site URL, sender guard, startup helper and tests use the root together.
Local-only authentication/mail, signup restrictions, explicit confirmation and
budgets remain enforced. P05 owns hosted origin/Turnstile settings; P13 verifies
the real production URL. The historical prefix results remain in STATUS.

## Run and verify

From `backend/`, with Docker Desktop's Linux engine running:

```powershell
npm ci
npm start
npm run reset
npm test
```

Start the hook in a second terminal, also in `backend/`:

```powershell
npm run functions
```

Then run, in the first terminal:

```powershell
npm run test:auth
npm run lint
node tool/prepare-auth-preview.cjs
```

The reset destroys this project's fictional local database. The P03 suite needs
an empty database and must run before the P04 suite. Reset before repeating the
complete sequence; repeated P04 runs deliberately consume the actual budgets.
The reset and function commands use the same dedicated network as startup.
Without that option, this CLI recreates the database on a different network and
the Data API cannot resolve it. Do not reset while sending mail or using the app.

Startup creates a random hook signing secret in ignored `backend/.env` when
absent. It also migrates the exact old loopback callback setting to `/`, preserving
the existing secret and other settings. An unrelated callback setting fails the
local-only startup check; it is not silently overwritten. Stop an existing stack
with `npm run stop` before this migration so Auth reloads the new Site URL, and
restart `npm run functions` with the updated environment. Never print/commit
the environment file. The preview operator script refuses remote
or linked stacks, provisions only `p04-preview@example.test` through local Auth,
and adds a fictional invitation using P03's fixture admin/team. It does not mark
that preview identity verified or grant it membership. It writes only the local
public API configuration to ignored `frontend/.env.local.json`.

From `frontend/`:

```powershell
flutter pub get
flutter analyze
flutter test
node --test test/auth_callback.test.cjs
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.local.json
node tool/serve.cjs
```

Open `http://127.0.0.1:4173/`, request a link for the preview
address, and open its message at `http://127.0.0.1:54324/`. Open the email link in
a new tab/document. Choose **Continue
sign-in** on the app. The queue remains public fictional presentation data.
Without the define file, the app remains the disconnected demo. The frontend
enables authentication only for the exact local API and loopback preview origin.

With the preview server running, run `node --test test/preview.test.cjs` in
another frontend terminal. This checks the root base, bundled resources, narrow
frame, old-path/missing-route 404s without redirects, and traversal rejection.
Use `/#/teams/atlas` for hash-route refresh checks. The obsolete prefix has no
redirect, and no login tokens are forwarded to another path or origin.

Stop the preview/function terminals with Ctrl+C, then `npm run stop` in
`backend/`. Docker's known all-interface published-port limitation remains;
use a trusted development machine/network with appropriate host firewall rules.
The inbox contains short-lived local login secrets; never publish it or export
its contents into the repository.

## Provider feasibility correction

The tested Auth image is GoTrue v2.196.0. `auth.enable_signup=false` disables
public creation, while `auth.email.enable_signup=true` is needed to enable the
email provider at all in CLI 2.117.0. Both `/signup` and unknown-user `/otp`
creation attempts are denied in direct endpoint tests.

An existing **unconfirmed** user cannot use `/otp` with global signup disabled:
GoTrue internally routes that case through signup and returns `signup_disabled`.
The Flutter repository catches only that specific error and calls the maintained
SDK's `resend(type: signup)`. This sends a provider-generated confirmation link
for the already-provisioned identity without public account creation. Confirmed
users use ordinary `signInWithOtp(shouldCreateUser: false)`. Both actions pass
the same signed email hook. No user is pre-confirmed to work around the restriction.
This correction follows the actual [magic-link handler](https://github.com/supabase/auth/blob/v2.196.0/internal/api/magic_link.go)
and [resend handler](https://github.com/supabase/auth/blob/v2.196.0/internal/api/resend.go).

Auth identity verification does not grant membership. A link issued before
invitation revocation can still prove email ownership, but that identity gets no
team rows and cannot receive another link without another eligible invitation or
active membership. P06 must recheck invitation eligibility when claiming it.

## Signed hook and budgets

The Edge Function verifies Standard Webhooks v1 HMAC over the raw body, event ID
and timestamp, with a five-minute skew window and a 32 KiB body bound. Only
`signup` and `magiclink` actions and the exact configured callback are supported.
Unsupported email changes, recovery, invite email actions, invalid signatures,
and malformed payloads fail closed. No hook request or token body is logged.

`reserve_auth_email` and `finish_auth_email` are service-role-only functions.
Clients receive no table or function grants. The reservation checks the live
Auth identity/email pair and either an active membership or a provisioned,
unclaimed, unexpired, unrevoked exact-email invitation. Email normalization trims
and lowercases; it preserves plus tags and dots.

A project advisory transaction lock serializes all recipient/global budgets:
one send/60 seconds, five/hour, ten/24 hours per recipient, 80/project/24 hours,
and 2,500/project/31 days. Rolling windows are deliberately conservative relative
to provider calendar resets. Reserved, sent, failed and unknown outcomes count.
Event IDs are bound to a SHA-256 payload digest; altered reuse fails. A completed
duplicate returns success without another delivery. In-flight/unknown/failed
duplicates cannot send again. A crash can lose delivery, but never releases quota
or automatically retries an ambiguous external send. There is no purge job.
The reservation rejects isolation levels other than read committed, so a future
configuration change cannot count a stale transaction snapshot after the lock.

P04's entrypoint only runs in the local runtime, posts to the fixed Mailpit
capture API, and accepts fictional `@example.test` recipients. It has no Resend
credential or external sender in local mode. P05 adds a separately gated
Resend sender, using the same event ID as provider idempotency key and
keeping ambiguous failures conservative. Mailpit itself is not claimed to
implement provider idempotency; the database prevents repeated calls.

## Callback, sessions and scanners

The P04A local email points to the `/` entry document with the
provider's token hash in its fragment. `auth_callback.js` removes callback
material with `history.replaceState` before Flutter/router initialization and
holds it in memory for one read. Query-token and implicit access/refresh-token
callbacks are scrubbed and rejected. No clean-path server rewrite is assumed.
Only the exact loopback root accepts a token hash; old paths, other origins,
duplicate/mixed parameters and query callbacks fail closed. The production
hostname is deliberately still disabled. Callback-like in-page history/hash
navigation is scrubbed and rejected before the router handles it; it cannot
initiate sign-in. Open email links in a new document for the supported handoff.

The signed hook rejects any nonexact `redirect_to` before quota reservation.
Direct Auth tests prove the obsolete same-origin prefix is denied without mail
or quota use. GoTrue may substitute Site URL for a disallowed external redirect
before the hook runs; the integration check allows either rejection or delivery
only to the exact root callback. No callback to that external origin is accepted.

Automatic SDK URL session detection is disabled. Explicit confirmation calls
`verifyOTP(tokenHash: ..., type: email)`; the provider creates and verifies the
one-use material. The request client uses the non-PKCE option for this explicit
token-hash exchange, so a link can open in a different browser/tab without a
stored verifier. A plain GET/HEAD or page-rendering scanner cannot consume it;
a scanner that actually activates the confirmation control can still consume it.
P05 verified passive rendering; arbitrary scanner interaction is not guaranteed.
Reload before confirming intentionally drops the pending token: reopen
the email or request a fresh link. No auth material goes into analytics or team
data caches.

The custom storage adapter uses `sessionStorage`, falling back to memory when
storage is unavailable, and clears its value on sign-out. The maintained SDK
also broadcasts auth events to already-open same-origin app tabs: browser
testing observed those tabs become signed in and signed out together. This is
tab-lifetime **storage**, not isolated sessions per tab. Browser tab duplication
or session restoration can also preserve sessionStorage. There is no indefinite
auth localStorage value. The selected production subdomain separates the app's
origin from the portfolio/PassGen; P12/P13 must verify the deployment preserves
that boundary. SDK synchronization among tabs on the app's own origin remains.

## CAPTCHA integration design and P05 gate

P04's exact-loopback local mode uses no live CAPTCHA service. P05 adds a separate
hosted-trial mode, enables Turnstile in **Supabase Auth itself**, mounts the
widget, passes its response through `requestChallenge`, and obtains a fresh
single-use challenge for every provider request. Production mode remains disabled.
In particular the failed
unconfirmed `/otp` attempt may consume its challenge: `/resend` must obtain a
new one. SDK request-contract tests prove distinct challenge tokens reach both
endpoints and rate errors do not start fallback retries.

P05 verified missing/invalid/reused challenge denials through direct `/otp` and
`/resend`, live failure recovery, exact callbacks and passive scanner rendering.
Expiry/timeout recovery is unit-tested; natural hosted CAPTCHA expiry was not
separately timed. See HOSTED_AUTH for the actual evidence. The SDK exposes `captchaToken` on both
methods. See [Supabase CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha)
and [Turnstile validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/).

The UI always gives the same link-request acknowledgement. Direct Auth endpoints
still distinguish missing identities, unconfirmed users and denied hooks through
different status/error codes. This is an observed enumeration limitation; the
generic UI is not a claim that the provider API hides identity existence.
