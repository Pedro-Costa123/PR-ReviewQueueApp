# Current status

Updated: 2026-09-21.

## Current implementation

P00-P04A are complete locally. P05 is complete for the controlled hosted trial.
**P07 is complete locally, ready for owner review.** The signed-in Flutter queue
now persists entries with guarded edits/deletion; separate demo routes remain
fictional and read-only. The selected Supabase Free project still has the
three versioned migrations and one operator-provisioned trial identity, without
fixtures or memberships. No production app is
deployed. See [HOSTED_AUTH](HOSTED_AUTH.md) for the trial and [AUTH](AUTH.md) for
local development. [ONBOARDING](ONBOARDING.md) covers P06; [QUEUE](QUEUE.md) covers P07.

- P02 shell: desktop/narrow navigation, Atlas/Orbit fixtures, profile/archive
  placeholders, dark default and saved theme preference.
- P03 database: profiles, teams, memberships, invitations, entries, comments,
  reviews, private operational tables, explicit grants/RLS, guarded existing-member
  access changes, immutable ownership/child-team rules and operator bootstrap.
- P04 frontend: pinned supabase_flutter 2.17.2, small auth repository/controller,
  generic link request, explicit Continue sign-in/cancel, session display/sign-out,
  early callback URL cleanup and sessionStorage with memory fallback.
- P04 backend: signed local Edge Function, exact identity/email/invitation checks,
  service-only quota reservation/completion RPCs, atomic recipient/global rolling
  budgets, digest-bound event idempotency and conservative unknown outcomes.
- Default/local mail goes only to Mailpit and fictional @example.test recipients.
  Explicit hosted-trial configuration enables Resend and Turnstile at the exact
  loopback root, with one to three allowed recipients. Production mode is rejected.
  Test provisioning remains outside migrations/application builds.
- P04A: root-base preview/frame and build, exact root callbacks in frontend/Auth/
  sender, secret-preserving local environment migration, expanded callback and
  preview denial tests, and verified replacement runbook commands.

Not complete: reliable Inbox placement and production-hostname acceptance,
hosted P06/P07 deployment, queue sorting/reorder/comments/reviews/archive,
CI, independent Pages release or deployment. Authentication alone grants no team;
the guarded P06 claim transaction creates invited memberships.

## P07 implementation and evidence on 2026-09-21

- Added the fifth migration, guarded create/update/delete/host-list RPCs,
  private team hostname configuration and atomic queue mutation budgets.
  Ownership is session-derived; direct writes stay denied. Deleted parents and
  their children disappear through existing RLS, with minimal audit metadata.
- Connected entry list/forms/actions to P06's selected-team workspace; added
  safe browser link opening, retained drafts on save errors and explicit
  conflict/duplicate/quota feedback. Signed-in navigation no longer labels the
  real workspace as a demo. Separate demo routes are still read-only.
- Owner confirmed title (1–160), owner/team-admin edits, soft deletion now and
  recovery/purge in P10, and fictional exact hosts locally with real hosts private
  before live use. Later correction: **Low, Medium, High, Critical**; Medium is
  the default. Migration replaces existing Normal values and invalidates stale
  versions. No material unanswered question blocks local P07.
- Clean reset applied all five migrations with no seeded hosts or identities.
  Final `npm test`: **19 passed**; `npm run test:queue`: **11 passed**;
  `npm run lint`: passed, no schema errors. Direct denial and concurrency coverage
  includes non-owner/foreign-team deletion, forged ownership/team, stale edits,
  queued revocation, duplicate active URLs and atomic mutation limits.
- Existing auth/hook regression: **28 passed**; onboarding/handler regression:
  **14 passed**. `flutter analyze`: no issues; **32 Flutter tests passed**,
  including validation/defaults, Critical edits/version forwarding, conflict
  draft retention, ownership UI, delete confirmation, refresh clearing and
  narrow Escape cancellation. JavaScript callback/Turnstile/preview: **15 passed**.
- Configured and default root release builds and Wasm dry runs passed; the
  pre-existing unused Cupertino font warning remains. No dependency/lockfile change.
- Browser: real captured local provider login/profile, Tab/Enter creation/save,
  concurrent RPC edit producing retained-draft conflict, reload persistence,
  canonical PR and Jira destinations in new tabs, Critical priority editing,
  Normal-to-Medium fixture migration, owner deletion, two-team isolation and
  team-specific controls. Light/dark 390 × 844 forms and desktop layout inspected;
  Escape restores focus and keyboard sign-out clears workspace data. Console clean.
  Fictional enterprise hosts do not resolve; actual enterprise access is untested.
- Initial checks found style lints and Escape blocked by a non-dismissible
  dialog barrier; corrected and rerun successfully. The Supabase CLI's telemetry
  and Node workers required sandbox escalation. The web tool could not parse the
  markdown changelog; curl retrieved it after PowerShell's reader failed.
- Updated product/architecture/security/decisions and the new QUEUE runbook,
  README/handoff pointers and P08's planned priority labels. No P08+ behavior,
  hosted migration, provider/DNS/Pages operation, real mail, commit or push.
- Documentation checks passed for **16 Markdown files and 94 relative links**,
  balanced fences and whitespace. Scanned **94 source/config files** for
  private-key/provider-secret patterns; only the existing explicit invalid
  key marker in the auth configuration test matched and was reviewed/excluded. No real
  secrets found. Helper/test syntax, unchanged lockfiles/license and
  `git diff --check` passed. Final Dart format check: 34 files, unchanged.
  An initial format invocation stalled inside the sandbox and was interrupted;
  the equivalent approved argument order passed.
- After browser QA, signed out and rebuilt without environment defines. The
  final browser showed disconnected sign-in, and the artifact contains no local
  fake identity. Preview/functions were stopped and `npm run stop` passed,
  preserving the final fictional test database. No deployment was performed.

Lists remain bounded to 100 with manual refresh and stable creation order.
P08 owns sprint/priority sorting and reorder; P07 only maintains necessary
append/revision metadata. Hosted rollout, private real-host configuration,
enterprise availability, Inbox placement and final HTTPS callback remain ahead.

## P06 implementation and evidence on 2026-09-21

- Added the fourth versioned migration, `invite-member` Edge Function, connected
  Flutter workspace/repository, five widget tests, 14 backend/handler tests and
  a local two-team preview helper. Preserved existing dependency lockfiles.
- Admin invitations/revoke/resend, exact-identity Auth provisioning/recovery,
  verified first-login claiming, real team selection, profile completion/edit/view,
  and member role/removal/restoration controls are implemented. Queue remains demo-only.
- Owner answered the material question: **all active teammates may see each
  other's email**. Enforced in a guarded profile RPC, without a global directory.
  Operator-created teams/team-scoped admins retain the selected P06 default.
- Clean local reset applied all four migrations. `npm test`: **19 passed**;
  `npm run test:auth`: **28 passed**; `npm run test:onboarding`: **14 passed**.
  SQL lint passed. New denial and concurrency coverage is detailed in ONBOARDING.
- Local security advisor: **five informational** private RLS/no-policy findings,
  **zero warnings/errors**. Reviewed as intentional API-denied operational tables.
- `flutter analyze`: no issues; **25 Flutter tests passed**. Callback/Turnstile/
  preview JavaScript checks: **15 passed**. Configured root release build and
  Wasm dry run passed; the existing unused Cupertino font warning remains.
- Browser: captured provider link, clean callback/Enter confirmation, first-login
  completion and profile save with Tab/Enter, both real teams, team-specific admin
  controls, invitation provisioning/mail request, teammate email view, Escape
  cancellation/focus restoration, and narrow light/dark forms. No console errors.
  Fixed clipped username help found during narrow QA.
- Final browser checks verified explicit resend/revoke, a role change, member
  removal hiding the profile, reload persistence and keyboard sign-out clearing
  workspace data. Owner-reported roster indentation is corrected and the current
  user's row says “(you)”; inspected the rebuilt release. Profile email now has
  an explicit accessibility label.
- A second owner alignment review removed the name-only button's extra vertical
  space: name/status share one accessible target and admin actions align with
  them. Analysis and the five onboarding widget tests passed again. Inspected
  the rebuilt desktop and 390-pixel release: matching text edges, balanced card
  padding and aligned admin actions. Enter opens the grouped profile target;
  Escape closes it, and keyboard sign-out clears the workspace. Console clean.
- Documentation checks passed for 15 Markdown files and 81 relative links,
  balanced fences and whitespace. Scanned 97 tracked/new files for private-key
  and provider-secret patterns: no matches. Preview helper syntax, unchanged
  lockfiles/license and `git diff --check` passed. The first file-list scan used
  PowerShell UTF-16 output; reran with explicit UTF-8. Node `--check` does not
  parse this TypeScript entry; the passing handler tests and local Edge Runtime
  execution provide its verification instead.
- Initial failures were an outdated RPC allowlist, an overlong test username,
  style lints and a spinner kept active behind a profile dialog. Corrected and
  rerun successfully. Node workers/CLI telemetry required sandbox escalation.
  A stalled `dart fix` attempt was stopped; explicit edits and formatting passed.
- Official Auth/pricing references were rechecked; no provider, hosted, DNS,
  repository visibility, Pages, real-mail or billing operation was performed.
  The migration draft was moved into `backend/supabase/migrations/` using the
  CLI-generated timestamp before reset; no stray backend-root migration remains.
- After final alignment QA, rebuilt the default root release without environment
  defines; build/Wasm dry run passed and the browser showed disconnected sign-in.
  Stopped the preview, function process and project Supabase stack, preserving
  the fictional local database. No deployment was performed.

No material P06 product question remains unanswered. P06 is locally verified;
hosted rollout is explicitly unperformed. Lists are bounded at 100 and refreshed
manually; background refresh/pagination remain P11. This was the P06 review
boundary; P07 was subsequently selected and its current evidence is above.

## P05 implementation and evidence on 2026-09-18 through 2026-09-20

- Added explicit trial client/sender configuration, a lazy themed Turnstile dialog
  with cancellation and fresh tokens per Auth attempt, and a fixed Resend adapter
  with signed-event idempotency, bounded timeouts and no automatic retries.
- Added operator-only, three-slot, 24-hour identity/email admissions for first
  trial login before a verified team admin exists. No API role can read/write
  admissions; revoked members cannot use them. No profile or membership is created.
- Clean local reset applied all three migrations. `npm test`: **19 passed**;
  `npm run test:auth`: **28 passed**; `npm run test:unit`: **14 passed** (a subset
  of the auth run). SQL lint passed. Tests cover authorization/concurrency,
  admission expiry/revocation/forged pairs, allowlists, sender failure, config
  rejection and duplicate delivery without real mail.
- `flutter analyze` passed; **20 Flutter tests passed**. Callback/Turnstile Node
  tests: **12 passed**; preview HTTP tests: **3 passed**. Default and configured
  trial root release builds and Wasm dry runs passed; the pre-existing Cupertino font warning
  remains. No dependency or lockfile change.
- Chrome's isolated widget harness exercised real Cloudflare public test widgets,
  success/failure, light/dark dialogs, cancellation with Enter/Escape and focus
  restoration. The harness has no Auth client and is excluded from the artifact.
  These checks do not prove server-side CAPTCHA enforcement.
- Final browser console review exposed an async-loader `turnstile.ready()` error
  hidden by subsequent attempts with the API already loaded. Replaced it with
  Cloudflare's documented load callback; added the first-load regression test and
  verified success on a fresh page with no new console errors. Narrow 390 by 844
  dark layout, keyboard cancellation and desktop light/dark rendering were checked.
- Supabase Free/EU project selected; all three migrations applied via MCP to an
  initially empty project. Hosted checks confirm all 11 tables have RLS, no
  admission grants to API roles and service-only mail reservation. Initially there
  were zero users, teams or admissions. Migration timestamp mapping is in HOSTED_AUTH.
- Disabled hosted public signup; anonymous sign-in and manual linking remain off,
  email confirmation remains on. Set email expiry to 900 seconds and Site URL to
  the exact loopback root; there are no additional redirects.
- Owner approved `auth.pedro-costa.dev`, added the displayed Namecheap DNS records,
  and Resend reports the domain and all four records verified. Receiving and
  tracking are disabled. No paid service enabled.
- Hosted security advisor reports four informational private-table/no-policy
  findings and one warning for the intentional guarded membership RPC; reviewed
  in SECURITY. Do not mistake these for a clean zero-warning report.
- Owner created the real managed Turnstile widget and entered its secret in Auth.
  Direct missing/invalid CAPTCHA probes on both `/otp` and `/resend` each returned
  HTTP 400 `captcha_failed`. The owner's valid challenges led to one delivered
  first-login message; final reused-token evidence is recorded below.
- Owner stored Resend and hook-signing secrets directly in Supabase; all six
  trial settings are stored. Deployed `send-auth-email` version 1; unsigned POST
  returned 401 in 614 ms. Owner-authorized hook activation is verified enabled.
- Resend Free usage before delivery: 0/100 daily and 0/3,000 monthly emails,
  one of three domains, pay-as-you-go off. No real message sent at this point.
- Dashboard creation required a password and created no identity. After owner CLI
  login, the new operator helper provisioned one unconfirmed identity via the Auth
  admin API without supplying a password. Admission slot 1 expires 2026-09-21
  00:19 UTC; zero memberships. Provider-generated internal password hashing is
  expected; no operator password was chosen or stored. See HOSTED_AUTH.
- The owner reported exactly one email, delivered to Junk. Resend reported one
  delivered and no bounce/failure; the hook recorded one sent reservation.
  Opening the link showed explicit confirmation at a clean URL without sign-in.
  Confirmation over eight hours after sending correctly failed past the
  15-minute expiry. The second message also arrived in Junk; its fresh link
  successfully confirmed the identity and signed in. Reload preserved the session,
  and Sign out succeeded. SQL confirms zero memberships and two sent reservations.
  The owner reopened the used link and it was rejected. SQL then confirmed zero
  remaining sessions, zero memberships and the same two reservations.
  No DMARC record was initially found. The owner added sender-only
  `v=DMARC1; p=none;`; both authoritative nameservers and Google's resolver
  returned it. A negative cache persisted at Cloudflare's resolver at that check.
  Recipient authentication and deliverability investigation remain open.
- Third email: SPF and DMARC passed according to receiver results; DKIM
  signatures were supplied without an explicit verification verdict. It still
  reached Junk. The already-confirmed identity successfully signed in, verified
  by browser and SQL. Totals: two confirmation sends and one magic-link send;
  Resend reports three delivered, zero failed/bounced. Raw headers are not stored.
- Closed the sending trial by signing out and revoking admission slot 1. SQL
  confirms zero active admissions, sessions and memberships. A service-role mail
  reservation then failed with `email not eligible`, leaving three reservations.
  No further delivery is eligible through the revoked admission.
- Successful second-send hook: HTTP 200, 1,119 ms execution time in hosted
  invocation details. Custom SMTP is disabled; the active hook replaces templates.
- Saved hosted Data API exposure to only `public`, maximum 200 rows; automatic
  table exposure remains off. Refresh-token replay protection is enabled with
  10-second reuse interval and 3,600-second access-token expiry.
- Recorded actual Free organization usage in COSTS: 25.87 MB database, one MAU,
  two reported Edge invocations, rounded 0.00 GB egress, no exceeded quota.
  Dashboard counters may lag recent requests. Documentation links/fences/whitespace
  passed (14 Markdown files, 69 relative links); operator helper syntax and
  `git diff --check` passed after the live-evidence updates.

- Final live negative check: fresh owner-completed CAPTCHA reached `/otp`, which
  returned HTTP 500 for the hook's expected 403 revoked-admission denial. The app
  kept its generic acknowledgement. Reuse on `/otp` and `/resend` returned HTTP
  400 `timeout-or-duplicate`. SQL still shows three reservations/hook events,
  zero active admissions, zero sessions and zero memberships.
- Passive browser scanner simulation rendered a synthetic token callback without
  confirmation: clean root, confirmation screen, zero Auth calls among 13 page
  requests. Reload discarded the pending callback; zero Auth calls across 28
  total page requests. No provider token was created or redeemed in this probe.
- Browser outage simulation blocked only the Turnstile loader: retry message,
  Send button restored, zero Auth calls. Removed the temporary network block and
  reloaded. Natural hosted token expiry was not separately timed; unit coverage
  handles expiry/timeout/cancellation and Cloudflare enforces single-use tokens.
- Final source review scanned 87 tracked/new files for the trial address and
  secret-key patterns: no matches. The initial Node child-process scan hit sandbox
  EPERM; the approved read-only retry passed. No credentials or raw mail headers
  were added to source. Final default root release build and Wasm dry run passed;
  the generated artifact is again the disconnected demo, with the existing
  unused Cupertino font warning. Rebuild with the trial define file only when needed.
- Browser inspection verified the final default artifact has no connected email
  form. Stopped the preview, widget harness and local function server;
  `npm run stop` passed and backed up/preserved the local Supabase data. Hosted
  services remain on Free with the deployed guarded hook and revoked admission.

P05's acceptance/evidence matrix and limitations are in HOSTED_AUTH. All three
emails reached Junk despite SPF/DMARC pass; Inbox reliability is a release follow-up,
not a claimed success. Passive scanners are covered; arbitrary automated form
submission is not. The dashboard did not expose the provider send interval; the
hook independently enforces the tested 60-second minimum. Sending remains closed.
At the P05 boundary, P06 was next and not started. No commit, push or app
publication was performed during that trial. Current P06 evidence is above.

## P04A verification on 2026-09-18

- Migrated the release preview/frame, JavaScript scrubber, Dart callback/local gate,
  Supabase Site URL, sender callback guard and startup `.env` helper to `/`.
  Existing hook secrets survive the exact legacy-setting migration; unrelated
  callback settings fail closed. No dependency, schema, budget or signup change.
- `npm start`, `npm run reset`, `npm test`: clean local schema reset and **19 P03
  authorization/Data API/concurrency tests passed**. The dedicated Docker network
  remains required. Startup migrated the existing ignored `.env` without printing
  its secret. Docker still reports the documented all-interface port limitation.
- `npm run functions`, `npm run test:auth`: local hook serving and **20 tests
  passed**, including provider signup/OTP/resend, old-path denial with no mail or
  quota use, external-redirect destination checks, replay/expiry, revoked/uninvited
  access, signatures, service grants, forged identity, concurrent budgets and
  idempotency, plus environment migration. `npm run lint` passed without warnings.
- `node tool/prepare-auth-preview.cjs` provisioned the fictional preview identity
  and local public config. `flutter pub get` passed without lockfile changes.
  `flutter analyze` and **16 Flutter tests passed**, including exact root local
  gates and the SDK's root redirect with fresh CAPTCHA tokens on fallback.
- `node --test test/auth_callback.test.cjs`: **6 passed**. Coverage includes
  immediate cleanup, one-time handoff, invalid/mixed/query callbacks, obsolete
  paths, unexpected origins, normal hash routing and in-page callback rejection.
- Root release builds with `--base-href / --no-web-resources-cdn` were checked
  with and without `--dart-define-from-file=.env.local.json`. Wasm dry runs passed;
  the existing unused Cupertino font warning remains.
- `node tool/serve.cjs` and `node --test test/preview.test.cjs`: **3 HTTP tests
  passed** for root/base/early-script ordering, bundled JS/CanvasKit, narrow frame,
  old prefix and missing-route 404s without redirects, and traversal rejection.
- Chrome: fictional request with Tab/Enter, local Mailpit link in a separate tab,
  clean root before confirmation, refresh dropping an unconfirmed link, keyboard
  Cancel and Continue, successful sign-in, reload persistence and keyboard sign-out.
  Reopening the used link failed safely after explicit confirmation. The default
  build without the define file showed no email form or connected login.
  Root hash-route navigation/refresh and the 390 x 844 root frame were inspected;
  desktop light and narrow light/dark layouts rendered correctly.
- Browser QA found same-document callback fragments bypassed the original startup
  scrubber. Added early popstate/hashchange rejection; rebuilt and verified a clean
  URL with the request screen unchanged. Normal hash routes still work. Open email
  links in a new document for confirmation, as documented in AUTH.
- `dart format lib test --output=none --set-exit-if-changed`: 20 files unchanged.
  Node syntax checks passed for the scrubber, preview server, startup and callback
  migration helper. `git diff --check` passed. Markdown checks covered 13 files
  and 53 relative links, balanced fences and no trailing whitespace. Tracked/new
  source and stale-prefix references were reviewed; remaining code references to
  the prefix are migration input or rejection fixtures. Local env files are ignored.
- Preview/function processes and temporary browser tabs were closed.
  `npm run stop` passed and preserved the fictional local database. The final
  generated artifact is the disconnected root demo; use AUTH's define-file build
  command to rebuild the authentication preview. No commit or push was made.

Node workers and Docker helper access required sandbox escalation; those retries
passed. An initial combined formatting command stalled in the sandbox and was
stopped; standalone formatting worked. Analysis initially found two interpolation
style issues in the new test; they were fixed before the passing run. No provider
account, DNS, Pages, visibility, real mail or deployment operation was performed.
At the end of P04A, P05 had not started. Current P05 hosted trial evidence is
above; the production subdomain remains untested.

## Historical hosting decision update on 2026-09-18

The owner selected **`https://reviews.pedro-costa.dev/`**, using this app's own
GitHub Pages deployment and Namecheap DNS. The app will have a separate browser
origin from the portfolio and PassGen. The former shared-path and combined
portfolio artifact plans are superseded; see decision D27 and ARCHITECTURE.

That earlier change updated documentation only, while the implementation still
used `/PR-Review-App-Queue/`. Its P02-P04 test results described that prefix and
did not prove root-path or live-subdomain behavior. P04A's replacement evidence is
recorded above. No code, DNS, Pages settings, repository name/visibility, provider
configuration or deployment changed during that earlier documentation update.

The root/backend/frontend READMEs and PRODUCT, ARCHITECTURE, DECISIONS, SECURITY,
COSTS, AUTH, NEXT, STATUS and HANDOFF now reflect this decision. Hosting/domain
research was rechecked against official documentation; backend/email pricing
retains its earlier research dates in COSTS.

Verification for this documentation update: reviewed the 12 changed Markdown
files and searched for stale hosting/next-step claims. A read-only PowerShell
check covered all 13 repository Markdown files: all 54 relative links resolved,
code fences were balanced, and no trailing whitespace was found.
`git diff --check` passed; `git diff --name-only` confirmed only documentation
changed. No application tests, builds or browser checks were rerun because
application code/configuration did not change. P04A and the live subdomain checks
were outstanding at that point; only the local P04A work is now complete.

## Verified P04 behavior and corrections

- Global signup remains disabled. The local CLI's email provider flag must be
  enabled. GoTrue v2.196.0 rejects /otp for unconfirmed identities when signup is
  disabled; the SDK falls back only on signup_disabled to confirmation resend for
  the existing identity. After verification, ordinary OTP requests succeed.
- Provider-issued links are single-use, expire after 15 minutes, and point at the
  actual entry document with a token-hash fragment. Opening/rendering the page
  does not consume the link; explicit confirmation does. The URL is cleaned before
  Flutter starts. Refresh before confirmation drops the pending in-memory value.
- Session persistence uses sessionStorage, never auth localStorage. Browser testing
  found SDK auth broadcasts synchronize already-open app tabs. This reduces durable
  persistence but does not isolate tabs or protect against compromised sibling apps.
- Direct Auth responses can reveal identity state despite generic UI acknowledgement.
  A previously-issued link may verify after invite revocation, but gains no team
  access. P06 must recheck eligibility when claiming invitations.
- CAPTCHA design uses provider enforcement and fresh single-use challenges for
  both /otp and the possible /resend fallback; SDK contract tests verify this.
  Actual Turnstile enforcement, delivery and advanced scanners remain P05 checks.
- Database reset/function serving must use the startup Docker network. The initial
  regression run exposed a DNS failure without that flag; corrected commands pass.
  The previously documented all-interface Docker port binding remains a local limit.

## Verification on 2026-09-17

- Clean local reset applies both migrations without fixtures.
- npm test: **19 P03 authorization/Data API/concurrency tests passed**.
- npm run test:auth: **15 tests passed**, covering real unconfirmed/confirmed Auth,
  disabled signup, denied uninvited/revoked/expired requests, verification replay and
  expiry, refresh, no automatic team access, signed duplicate delivery, signature
  failures, service grants, forged identity/email pairs, stale-snapshot rejection,
  recipient/global concurrent caps and failure accounting.
- npm run lint: public/private schemas passed, no errors or warnings.
- The final backend sequence passed after a clean reset. An intervening P03
  rerun correctly refused the already-populated test database; reset is required
  before repeating that suite, as documented in AUTH.
- flutter analyze: passed; flutter test: **15 passed**, including SDK request
  contracts with fresh CAPTCHA tokens, controller states and sign-in widgets.
- node --test test/auth_callback.test.cjs: **3 passed** for immediate cleanup,
  one-time handoff, rejected query/access-token callbacks and unchanged hash routes.
- Release web build at /PR-Review-App-Queue/ with local bundled rendering resources
  passed, including Wasm dry run. The existing unused Cupertino-font warning remains.
- Chrome local release: email request via Tab/Enter, captured link in a new tab,
  clean callback URL before confirmation, keyboard confirmation, signed-in screen,
  reload persistence, cross-tab SDK synchronization and sign-out inspected.
  Desktop 1920 × 855 and narrow 390 × 844 layouts, both themes and narrow keyboard
  validation were inspected. The demo banner was corrected to describe only queue data.
- Final tracked/new-source review and git diff --check passed. Content checks
  covered 57 text files and 51 relative Markdown links; lockfile pins/engines match.
  Local environment files remain ignored. The fictional preview recipient was
  restored after the final reset. The preview/function processes and this project's
  Supabase stack were stopped, preserving its fictional database.

## Repository and environment

Workspace: C:\Users\pedro\Projects\PR-ReviewQueueApp. Branch: main. P03 is
committed as c2b44c8 and P04 as 1ff6c13. P04A began from a clean worktree at
bd8e62c (the hosting-decision documentation commit) and was committed as 99c68f3.
P05 is committed as 5ad5235 and P06 as 4c96d27. P07 began from that clean
worktree and remains uncommitted. No fetch, push or app publication was performed.

Tooling remains Flutter 3.47.4/Dart 3.13.3, Node 26.5.0/npm 11.17.0, Supabase CLI
2.117.0 and Postgres 17.6.1.167. P04 also exercised local Edge Runtime 1.74.3
(Deno 2.1.4), GoTrue 2.196.0 and Mailpit 1.30.2. Docker Desktop's Linux engine was
started for verification. P05 selected the existing hosted project and configured
the sender domain; no global tool upgrade or paid subscription was added.

Remaining product defaults include self-review, archive privileges,
operator-created teams and retention. P06 confirmed profile email visibility;
P07 confirmed title, entry edit privileges, soft deletion and the revised priorities.
Exact enterprise hostnames will be supplied privately before live use; P07 uses
fictional local configuration as confirmed. This app's Pages setup, domain
ownership, DNS and separate browser origin must be checked before publishing.
No unresolved product question blocks completed local P04A verification.

## Historical verification

P03 verification on 2026-09-16:

- `npm install`: pinned CLI/lockfile installed successfully; npm reported 0 vulnerabilities. Node 26.5.0/npm 11.17.0 and Docker Desktop/Linux engine were inspected.
- `npm start`: the minimal local stack starts. The wrapper validates the local Docker context and dedicated bridge, reports actual port bindings, and suppresses credential output. No cloud setup or real mail was used.
- `npm run reset`: repeatedly reproduced the complete schema from a clean local database, with no fixture identities seeded. The final tests ran after a clean reset and stack restart.
- `npm test`: **19 passed**, 0 failed/skipped. Tests exercise real PostgREST requests and SQL roles, positive permitted reads, anonymous/outsider/cross-team denials, forged ownership/JWT/metadata, direct-write/upsert denial, private/default function grants, same-token revocation with preserved other-team access, pending-invite revocation, child-team/immutable-key/duplicate constraints, bootstrap script, and last-admin protection.
- Three deterministic concurrent-connection tests passed: competing admin self-demotions, an admin revoked while waiting for the team lock, and direct operator changes at repeatable-read isolation. They verify final state and expected constraint/authorization/serialization errors.
- The first test run found PostgreSQL's global default PUBLIC function execution was not removed by schema-scoped revocation. The migration now revokes both; the regression probe passes. A write-test request was also corrected to include a filter so it exercises database authorization rather than an API WHERE-clause guard.
- `npm run lint`: passed on `public,private` with warnings treated as failures; no schema errors.
- `node --check` passed for the startup wrapper and both test files. Content/whitespace checks passed across 43 non-generated text files; all 41 relative Markdown links resolved and code fences were balanced. The lockfile's CLI pin matches the manifest. `git diff --check` passed, and tracked/new-file diffs were reviewed. The read-only checker required a sandbox retry to launch Git. No frontend code changed, so P02 Flutter/browser checks below were not rerun as P03 evidence.
- `npm run stop`: passed after verification, preserving local fictional data and stopping this project's containers.

Local tooling limitation: Docker Desktop 4.91.0/engine 29.8.0 still reports all-interface port bindings despite Supabase's documented loopback network option. The wrapper explicitly reports this; it does not claim network isolation. Use only a trusted development machine/network with appropriate host firewall restrictions. The local stack is stopped after verification, preserving its fictional database. No production setup was attempted.

P03 is an authorization foundation: all direct queue writes are denied, including owners/admins; queue mutations wait for P07+. Full URL validation, mutation limits, email quotas, invite claiming, and real authentication remain later checks. A revoked member can still read their own profile, but not revoked-team records. Profile email visibility rules and other product defaults remain distinguishable from confirmed requirements.

Planning verification remains recorded in COSTS and the prior documentation. P02 verification on 2026-09-14:

- `flutter --version` and `flutter doctor -v`: web tooling available; native Windows warning as described above.
- `flutter analyze`: passed, no issues.
- `flutter test`: **9 passed**. Coverage includes dark default, persisted light/dark preference across controller instances, unavailable storage, sign-in disabled/no email field, profile/archive/team navigation, six narrow direct/unknown route cases and drawer layout. Initial tests found sidebar/metric label overflow; flexible text fixed it and the full suite passed afterward.
- `flutter build web --release --base-href /PR-Review-App-Queue/ --no-web-resources-cdn`: passed, including the SDK's Wasm dry run. The final JavaScript release bundles rendering resources locally. The initial build without the CDN flag also passed.
- Chrome release preview at `http://127.0.0.1:4173/PR-Review-App-Queue/`: desktop (1920 × 855) and narrow iframe (390 × 844) inspected; light/dark visuals, wrapping, scroll, demo labels, disabled sign-in, profile/archive navigation, empty team, hash-route reload, and saved light theme verified. Keyboard Tab/Enter activation, arrow-key team selection, browser Back, and narrow drawer navigation verified.
- `node --check tool/serve.cjs`: passed. Preview run command is `node tool/serve.cjs` from `frontend/`; Ctrl+C stops it. Full run/build instructions are in [frontend README](../frontend/README.md).
- Local HTTP checks: app HTML, JavaScript, bundled CanvasKit Wasm, and narrow preview returned 200; the slashless base redirected to the trailing slash; unrelated/missing paths returned 404. Generated HTML contains the exact base href. These are local preview checks, not claims about GitHub Pages.
- `dart format --output=none --set-exit-if-changed lib test`: passed, 11 files unchanged. Content checks passed across 33 non-generated text files and 33 relative Markdown links, including balanced code fences and trailing whitespace. `git diff --check` passed for tracked content; new files were also inspected directly/as new-file diffs because the implementation and planning files were untracked at that time. P02 handoff documentation was checked for stale claims.

No backend tests were applicable during P02; P03 results are above. No production checks have been claimed. The SDK's release icon-tree-shaking step warns about an absent Cupertino font family; this app uses Material icons, which rendered correctly in Chrome. Generated Flutter favicon/app icons are still placeholders. These historical frontend checks used the legacy local prefix; root-path verification is now recorded under P04A above. Hosted auth callbacks, provider quotas, and the independent Pages/subdomain release remain future checks.

## Next

Review **P07: queue entries and ownership**. The next ready item is
**P08: sprint/priority ordering and admin reordering**. Keep trial admission revoked;
carry the documented delivery and production callback checks into P12/P13.
