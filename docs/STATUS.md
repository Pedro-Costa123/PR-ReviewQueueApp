# Current status

Updated: 2026-09-18.

## Current implementation

P00-P04A are complete locally. **Stop for P04A review; P05 is next.** The
Flutter queue remains fictional and read-only, while its sign-in screen can now
authenticate against the local Supabase stack. No hosted project or production
deployment exists. See [AUTH](AUTH.md) for the complete local runbook and decisions.

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
- Mail goes only to local Mailpit and fictional @example.test recipients. The
  frontend and sender have explicit local-only gates. Test provisioning is outside
  migrations/application builds; no fake application identity or token generator.
- P04A: root-base preview/frame and build, exact root callbacks in frontend/Auth/
  sender, secret-preserving local environment migration, expanded callback and
  preview denial tests, and verified replacement runbook commands.

Not implemented: hosted login/Resend/Turnstile widget, invitation admin/provisioning
UI or claiming, real queue CRUD/reorder/comments/reviews/archive,
CI, independent Pages release or deployment. P04 verifies identities
but creates no team membership.
P05 requires the owner to select the hosted trial and supply provider access/secrets
through secret storage; no cloud, billing, DNS or real-email changes were made.

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
P05 has not started. Hosted CAPTCHA/delivery and the real subdomain remain untested.

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
bd8e62c (the hosting-decision documentation commit). P04A changes are uncommitted.
No fetch, push, deployment or remote-state check was performed.

Tooling remains Flutter 3.47.4/Dart 3.13.3, Node 26.5.0/npm 11.17.0, Supabase CLI
2.117.0 and Postgres 17.6.1.167. P04 also exercised local Edge Runtime 1.74.3
(Deno 2.1.4), GoTrue 2.196.0 and Mailpit 1.30.2. Docker Desktop's Linux engine was
started for verification. No global tool upgrade or new hosted service was added.

Remaining product defaults are still proposed: title/priority labels, profile email
visibility, self-review, edit/archive privileges, operator-created teams and retention.
Exact enterprise hostnames are needed for P07; this app's Pages setup, domain
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

Review **P04A: local root-path and callback migration**. The next item is **P05:
hosted authentication/cost validation**, requiring owner selection and provider
access through secret storage. No P05 work is authorized or started by this handoff.
