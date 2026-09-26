# P05 hosted authentication trial

P05 is complete for the controlled developer trial, ready for owner review.
P06 is the next ready item; do not start it automatically. Inbox placement remains
a documented release follow-up. This runbook separates local and live evidence.
The local-only runbook remains [AUTH](AUTH.md).

## Provider state observed 2026-09-18 through 2026-09-20

- The owner-selected existing Supabase project is on Free in Frankfurt. It was
  initially empty. Applied only the three migrations, with zero users, teams or
  trial admissions at that point. This local checkout remains unlinked.
- MCP assigned hosted migration versions rather than local filenames:

  | Migration | Local version | Hosted version |
  | --- | --- | --- |
  | authorization_foundation | 20260916000100 | 20260918202253 |
  | email_guard | 20260917000100 | 20260918202342 |
  | hosted_trial_admission | 20260918201219 | 20260918202401 |

  Reconcile this mapping in an isolated operator checkout before using CLI push;
  do not replay these already-applied migrations or link the local test checkout.
- Hosted public signup is disabled; anonymous/manual linking are off and email
  confirmation is on. Email expiry was shortened to 900 seconds. Site URL is
  `http://127.0.0.1:4173/` with no additional redirects.
- `auth.pedro-costa.dev` is verified in Resend, including all four supplied DNS
  records added by the owner at Namecheap. Sending is enabled; receiving and
  click/open tracking are disabled. Requested enforced TLS.
- Owner created the managed `PR Review Queue developer trial` Turnstile widget
  with one loopback hostname and no pre-clearance, then saved its secret directly
  in Supabase. Dashboard confirms Turnstile protection enabled and saved.
- Direct hosted `/otp` and `/resend` probes with missing and invalid CAPTCHA,
  using a nonexistent fictional recipient, each returned HTTP 400 `captcha_failed`.
  These four denials do not prove valid/reused-token behavior or real delivery.
- Owner saved the domain-restricted sending key as `RESEND_API_KEY` and the hook
  signing secret directly in provider storage. All six trial variables are stored.
  Deployed `send-auth-email` version 1 on 2026-09-19; unsigned POST returned 401
  in 614 ms. The owner authorized hook activation, verified enabled on 2026-09-20.
  No credentials appear here; public keys are in ignored frontend configuration.
- Resend dashboard on 2026-09-19 confirms Free: 0/100 daily, 0/3,000 monthly
  transactional emails, one of three domains, and pay-as-you-go off.
- The dashboard requires a password for user creation and made no identity.
  The owner logged the CLI in through its credential store. The operator helper
  then created one unconfirmed identity through the Auth admin API without
  supplying a password; SQL verified the email and zero memberships, then issued
  slot 1 admission on 2026-09-20 (expires 2026-09-21 00:19 UTC).
- Hosted RLS/grants and the intentional advisor findings are documented in
  [SECURITY](SECURITY.md). On 2026-09-20, narrowed exposed schemas to only
  `public` and saved Max rows = 200; automatic table exposure remains off.
  Refresh-token replay protection is enabled with a 10-second reuse interval;
  access-token expiry is 3,600 seconds.
- The Free organization usage dashboard on 2026-09-20 showed 25.87 MB database,
  one MAU, two Edge invocations, displayed 0.00 GB egress and zero Storage/Realtime
  use, with no quota exceeded. Counters are delayed/rounded; see COSTS.
- After the three-message sending trial, the operator revoked slot 1 and signed
  out the trial session. Final SQL checks found zero active admissions, sessions
  and memberships, with three reservations. No further mail is eligible until an
  operator explicitly admits the identity again; do not assume the old expiry
  means admission is still active.

## Live observations on 2026-09-20

- The owner completed real CAPTCHA and requested the first login email. One
  message arrived in **Junk**. Resend reported one sent and delivered, zero failed
  or bounced; the database recorded one reservation with outcome `sent`.
- Opening the email in a new document showed Continue sign-in at the clean root
  URL. SQL confirmed the identity remained unconfirmed, had never signed in and
  had zero memberships. Rendering alone did not exchange the token. This does
  not establish how every automated mail scanner behaves.
- The first message was sent at 00:23 UTC; confirmation was attempted after
  08:54 UTC, beyond the configured 15-minute expiry. It failed safely with the
  recovery message, no sign-in and no second email. A fresh-link success check
  subsequently succeeded; this expired-link result is not evidence of a login defect.
- The second requested message also arrived in Junk. The owner immediately
  confirmed its link and signed in; browser inspection and SQL confirmed success,
  with zero memberships and two sent reservations in total. Reload preserved the
  session and Sign out returned the signed-out request screen. The owner reopened
  the second, used link shortly afterwards and explicitly confirmed again: it
  was rejected with the safe recovery message. SQL then confirmed zero sessions,
  zero memberships and the same two reservations.
- Resend then reported two sent/delivered and zero failed/bounced messages;
  its refreshed Free dashboard showed 2/100 daily and 2/3,000 monthly usage,
  one of three domains, with pay-as-you-go still off.
- The successful second-send invocation returned HTTP 200 with 1,119 ms
  execution time in Supabase's invocation details. This is one signed-hook
  observation, not a latency distribution or an inbox-delivery measurement.
  Custom SMTP remains disabled; Auth confirms the active hook replaces templates.
- Initial TXT lookups found no DMARC record at the sending subdomain or parent domain.
  Junk placement remains unresolved; missing DMARC alone does not establish its
  cause. Inspect recipient authentication results without sharing links/tokens.
  The owner then added the initial Namecheap TXT record with Host `_dmarc.auth`,
  Value `v=DMARC1; p=none;`, scoped only to the sender subdomain. Both authoritative
  Namecheap nameservers and Google's public resolver returned the exact record
  on 2026-09-20 (TTL 1,799 seconds). Cloudflare's resolver initially retained a
  negative cached response, so propagation was not yet consistent everywhere.
  Verify SPF/DKIM alignment and DMARC passing before tightening policy;
  no reporting mailbox or external report destination has been configured.
  See [Resend DMARC setup](https://resend.com/docs/dashboard/domains/dmarc).
- The third requested email still arrived in Junk. The owner supplied receiver
  results showing SPF pass and DMARC pass (`action=none`). DKIM signatures were
  present, but an explicit DKIM verification result was not supplied; a signature
  alone does not prove verification. Raw headers/signatures are not stored here.
  Cloudflare's public resolver subsequently returned the correct DMARC record.
- The third link successfully signed in the already-confirmed identity. SQL
  recorded one `magiclink` send after two `signup` confirmation sends and a new
  sign-in immediately after the third send. Browser inspection confirmed the
  signed-in screen. The prepared network observer did not capture that tab's
  request, so no direct `/otp` HTTP trace or latency is claimed for this attempt.
- Final Resend metrics: three sent, three delivered, zero failed/bounced. All
  three messages reached Junk in the same controlled inbox. This establishes
  delivery and working links, not reliable Inbox placement across recipients.
  Microsoft considers signals beyond authentication; the exact filtering cause
  has not been established. See
  [Microsoft email authentication](https://learn.microsoft.com/en-us/defender-office-365/email-authentication-about).
- After revoking the admission, an actual `service_role` reservation call for the
  trial identity failed with `42501: email not eligible`. Reservation count stayed
  at three; this was a database denial check with no email-provider call.
- Final live denial check: the owner completed a fresh real CAPTCHA for the
  revoked identity. Browser observation captured `POST /auth/v1/otp`; Auth returned
  HTTP 500 explaining that the hook returned 403. The application kept its generic
  acknowledgement. Replaying the consumed token on both `/otp` and `/resend`
  returned HTTP 400, `timeout-or-duplicate`. Tokens stayed in temporary browser
  debugging memory and were not written to files or printed.
- After those three denied requests, SQL still showed three reservations and
  three hook events, with zero active admissions, sessions or memberships. No
  fourth email was eligible. This verifies the live CAPTCHA and hook boundary;
  the local suite supplies the broader concurrency/forged-identity/expiry matrix.
- Passive scanner simulation against the configured release: a synthetic,
  structurally valid token fragment loaded the confirmation page and was removed
  from the URL. Network observation captured 13 page requests and zero Auth
  requests. Reload dropped the pending callback and returned the request screen;
  28 page requests across both loads still included zero Auth requests. Combined
  with the real-link opening check above, rendering does not redeem a link.
- Browser outage simulation temporarily blocked the Turnstile loader. The app
  displayed its retry message, restored the Send button and made zero Auth calls.
  The network block was removed and the page reloaded. Unit tests cover expiry,
  timeout, cancellation and fresh-widget retry; natural five-minute token expiry
  was not separately timed against the hosted provider.

## Implemented trial boundary

- `AUTH_MODE=hosted-trial` explicitly enables the Flutter client only at
  `http://127.0.0.1:4173/`, with an exact HTTPS Supabase project URL, a public
  `sb_publishable_` key and a real Turnstile site key. Dummy keys cannot enable
  application authentication. Default/local builds retain P04's local gate.
- Callback cleanup still runs before Flutter and before the CAPTCHA bridge.
  Continue sign-in is still required; no automatic token exchange occurs.
- The verification dialog loads Cloudflare only when requesting a link, follows
  the app theme, traps keyboard focus, supports Escape/cancel, and restores focus.
  Each provider attempt creates a fresh widget. Errors/expiry/timeouts stop the
  request, with manual retry. Leaving sign-in cancels a pending challenge and
  prevents a delayed OTP response from starting a fallback challenge.
- The deployed sender requires `AUTH_EMAIL_MODE=hosted-trial`, an exact project
  URL, the loopback callback, a sender and one to three explicit recipients. That
  additional recipient list does not replace database eligibility or budgets.
  Local Mailpit cannot run deployed, and the Resend path cannot run locally.
- Resend receives a plain-text email with one provider-generated token-hash link,
  no team details, and the signed event ID as `Idempotency-Key`. No automatic
  retries or provider fallback; ambiguous outcomes remain charged to quota.
  HTTP redirects fail closed. RPC timeouts are 750 ms each and the sender timeout
  is 2.5 seconds, leaving headroom within the provider's five-second HTTP hook
  deadline. Cold starts and actual delivery latency still require measurement.

## First hosted identity

The original team invitation flow needs an existing verified initial admin.
Copying local fixture admins or manually confirming real email would defeat
that boundary. P05 therefore adds `private.auth_trial_admissions`: at most three
slots, bound to Auth user ID plus exact normalized email, expiring within 24
hours and individually revocable. Only the SQL operator can write/read it;
API roles, including service role, have no table grants.

Provision the controlled identity through the Auth admin API with
`email_confirm: false` and no supplied password. Supabase internally generates a
random inaccessible password hash when the password is omitted; do not require an
empty `encrypted_password` column or modify Auth internals. See
[the provider implementation](https://github.com/supabase/auth/blob/master/internal/api/admin.go).
Add its admission using
[admit-trial.sql](../backend/operator/admit-trial.sql), supplying operator
variables privately. Also include that email in the hook's `TRIAL_RECIPIENTS`.
An admission permits mail only if the live Auth identity/email matches and the
user has no membership rows. It never creates a profile, team, or membership;
it cannot bypass revocation of an existing member. Team invitations and their
claiming workflow remain P06. Revoke admissions after trial checks; remove this
temporary admission route before production.

[provision-trial.cjs](../backend/operator/provision-trial.cjs) uses the pinned CLI's
existing login and keeps the project service key only in process memory. Set
`TRIAL_PROJECT_REF` and `TRIAL_EMAIL` privately, with the selected project matching
the ignored frontend trial config, then run `node operator/provision-trial.cjs`
from backend. It does not send mail, admit the user or create memberships. It
refuses missing/mismatched configuration and never retries ambiguous provisioning;
inspect Auth before retrying. The real API run passed on 2026-09-20.

For CLI login, the owner runs this in their own terminal and completes browser/code
entry there:

```powershell
npx supabase login --name pr-review-queue-trial --agent no --output-format text
```

Do not paste the verification code or access token into chat. Do not
use the dashboard's password-required or auto-confirm flow for this trial.

## Provider setup order

1. Confirm the selected project is on Supabase Free and an available EU region;
   inspect current account consumption. Apply only the versioned migrations,
   never fixtures. Keep `private` outside exposed schemas and expose only
   `public`; keep API response rows bounded to 200.
2. In Auth, disable public signup, anonymous sign-in and manual linking; keep
   Email enabled and email confirmation required. Set email token expiry to 900
   seconds and the send interval to 60 seconds. Keep refresh-token rotation.
3. Set Site URL to exactly `http://127.0.0.1:4173/`; no wildcard or portfolio
   redirects. No additional callback is required for this trial.
4. Verify the dedicated Resend sending domain at Namecheap, with receiving,
   click tracking and open tracking disabled, and enforced TLS. Use the exact
   records Resend provides; retain existing website and mail records. Confirm
   Resend Free and remaining shared-account quotas before real delivery.
5. Create a separate Free managed Turnstile trial widget allowing the exact
   loopback hostname, with pre-clearance disabled. If the provider UI refuses
   it, resolve provider-supported loopback configuration before sending mail;
   do not use dummy secrets, disable CAPTCHA, or widen callbacks as a workaround.
6. Put the Turnstile secret directly in Supabase Auth's CAPTCHA/Attack Protection
   settings and enable Turnstile enforcement. Only its public site key belongs
   in the frontend define file. Secret entry belongs in provider/secret storage,
   never chat, docs, code, or screenshots.
7. Create a Resend sending-only API key restricted to the verified sender domain.
   Put it in this project's Edge Function secrets as `RESEND_API_KEY`. Configure
   the other names from [the example](../backend/.env.hosted-trial.example).
   Generate a Send Email Hook signing secret in Supabase, store the same value
   as `SEND_EMAIL_HOOK_SECRET`, and use an HTTPS hook pointing to
   `https://<project-ref>.supabase.co/functions/v1/send-auth-email`.
8. Deploy `send-auth-email` with JWT verification disabled because the handler
   authenticates the raw request using the provider signature. Check unsigned
   requests fail before enabling the hook. Do not configure an SMTP fallback.
9. Provision/admit only controlled trial identities as above. No real company
   content is needed. Record delivery/scanner outcomes without addresses/tokens.

The pinned CLI's help was inspected for the following operator commands. They
require an authenticated CLI and explicitly selected project; they are not proof
that hosted secrets/deployment have been applied:

```powershell
# From backend; use a project reference selected through operator configuration.
npx supabase secrets set --project-ref <project-ref> --env-file .env.hosted-trial
npx supabase functions deploy send-auth-email --project-ref <project-ref> --no-verify-jwt
```

Do not link the local test checkout to a hosted project; the local test runner
deliberately refuses linked projects. Use MCP migrations or an isolated operator
checkout for hosted migration history. A hosted project/schema reset is not a
trial test command.

## Frontend and local verification

Copy [the public-config example](../frontend/.env.hosted-trial.json.example) to
ignored `frontend/.env.hosted-trial.json` and fill only public configuration.
From frontend:

```powershell
flutter analyze
flutter test
node --test test/auth_callback.test.cjs test/turnstile.test.cjs
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.hosted-trial.json
node tool/serve.cjs
```

The last build is for the controlled trial, not publication. From backend,
`npm run test:unit` tests configuration/senders without network delivery. The
full AUTH reset/test sequence covers the admission migration and live local
Auth. Never run the fictional fixtures or test suite against hosted services.

For widget-only browser QA, `node tool/turnstile-preview.cjs` serves
`http://127.0.0.1:4175/` (`/narrow` adds a 390 by 844 iframe). This separate test fixture uses Cloudflare's documented
public dummy keys, discards tokens and has no Auth client or email sender. It
is outside the Flutter artifact. Test light/dark rendering, success/failure,
Tab/Enter/Escape, focus return and a narrow viewport. Passing this harness is
not evidence of provider-side CAPTCHA enforcement.

## Acceptance and remaining limits

| P05 criterion | Evidence |
| --- | --- |
| One valid message per permitted event | Three requested messages, three deliveries/reservations; first and confirmed-user sign-in succeeded |
| Expiry, replay and passive scanners | Expired and used real links rejected; rendering waited for explicit confirmation; scanner simulation made no Auth requests |
| Disabled signup with controlled login | Hosted signup remains off; first-login confirmation fallback and subsequent magic link succeeded; local direct-endpoint denial tests cover unknown users |
| Server CAPTCHA and mail eligibility | Missing, invalid and consumed tokens denied on both endpoints; valid CAPTCHA reached the revoked-admission hook and was denied without quota/mail |
| Budgets and authorization | Local real-Auth/SQL tests cover eligibility, forged pairs, revoked members, expiry, concurrency, signatures and idempotency; hosted grants/RLS and revoked-admission denial checked |
| Costs and safe recovery | Free plans/usage recorded; no paid fallback; live loader failure recovered without Auth; sender/hook timeout tests passed |

All three messages reached Junk despite receiver SPF/DMARC passing. This is an
unresolved rollout deliverability issue, not proof of reliable Inbox placement.
Do not repeat sends or change DNS without evidence. Before P13, inspect sanitized
receiver DKIM/composite-authentication/spam classifications and retest the final
HTTPS callback. No guarantee is made for scanners that actively submit forms or
for every commercial scanner product; passive GET/render behavior is covered.

The provider send interval was not exposed in the inspected dashboard. The hook's
independently tested 60-second minimum remains enforced. Actual hosted challenge
expiry was not timed separately; Cloudflare documents five-minute, single-use
tokens, while expiry/error recovery is covered by tests and live failure recovery.
See [Turnstile validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/).
Provider responses can reveal identity state despite the app's generic message.

Trial admission is revoked and sessions are signed out. Preserve this closed
state; P06 implements actual invitations and membership. Production still requires
the separate release gates below. No new test identity or fixture was added to
the hosted database for the final negative checks.

Final local handoff: the default root release artifact was rebuilt and browser
checked with no connected email form. Preview/widget/function processes were
stopped; `npm run stop` preserved the local database. Use the explicit trial build
command above only for a deliberately reopened trial; the old admission is revoked.

## Production handoff (P12/P13)

The owner selected Cloudflare Pages Free on 2026-09-26, retaining magic links and
the verified `auth.pedro-costa.dev` sender. P11A, before P12, will prepare the exact
available pages.dev Site URL/callback and specific Turnstile hostname. See
[HOSTING](HOSTING.md) for scope and the Namecheap records to retain. Remove trial
admissions and loopback/obsolete redirects for production. Current code accepts
only local and hosted-trial modes; production gates need implementation/tests.
Do not deploy the current trial as the final app. Publication and live-hostname
verification remain P13; no hosted settings changed in the planning update.

## Sources checked 2026-09-18

[Supabase CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha),
[HTTP hook deadline](https://supabase.com/docs/guides/auth/auth-hooks),
[Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook),
[Turnstile widget configuration](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/widget-configurations/),
[Turnstile dummy keys](https://developers.cloudflare.com/turnstile/troubleshooting/testing/),
[Resend API](https://resend.com/docs/api-reference/emails/send-email),
[Resend idempotency](https://resend.com/docs/dashboard/emails/idempotency-keys).

Resend retains idempotency keys for 24 hours. The database retains event/digest
records and independently refuses ambiguous redelivery beyond that period.
