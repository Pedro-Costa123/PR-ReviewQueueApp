# Security design and launch evidence

Last updated: 2026-09-26. P11 adds local bounded read/refresh endpoints. P10 adds local lifecycle controls. P09 comments/review signals, P08 ordering, P07 queue mutations and P06 onboarding are verified locally. P03/P04/P04A local controls are verified. P05 controlled
hosted login, mail, CAPTCHA replay denial and passive-scanner checks passed.
[AUTH](AUTH.md) and [HOSTED_AUTH](HOSTED_AUTH.md) distinguish implementation,
provider configuration and observed behavior. P10 lifecycle is local only; launch controls remain planned.

The signed-in workspace now reads/writes team entries through guarded P07 RPCs;
public demo routes still contain only fictional presentation fixtures. P04 adds
a real local Auth client and sessionStorage adapter, with SDK cross-tab synchronization.
There is no fake signed-in identity, role switch or company URL. Browser demo
navigation is not an authorization test. SQL-role/Data API denial tests run against
local Supabase. The release build remains a local preview, not a production auth path.

## P11 implemented evidence and limits

`team_revision`, `queue_page` and `activity_page` require live membership on every
request; deleted pages require live admin and deleted activity is denied. Revision
conflicts are disclosed only after authorization. Filtering and caller-controlled
UUIDs/offsets grant no authority. Seven integration tests cover anonymous/foreign/
revoked/forged denials, cross-team parents, pagination ties/bounds, combined filters,
revision drift, profile/host invalidation and lifecycle isolation. The exact RPC
allowlist and all 19 authorization tests pass. Private triggers/direct writes stay
closed. SQL lint passes; advisor: seven intentional info findings, zero warnings/errors.

Refresh keeps no private persistent cache, ignores late results after team changes,
stops hidden-tab polling and clears queue data on denied/expired reads. Paused
refresh never changes backend authorization. Auth callbacks, signup, credentials,
mail controls and hosted admission are unchanged. See [REFRESH](REFRESH.md).

## P10 implemented evidence and limits

P10 subsequently adds the [confirmed lifecycle policy](LIFECYCLE.md): live
submitter/admin archive, restore and soft deletion; admin-only deleted listing
and recovery. Nine lifecycle tests cover anonymous/foreign/non-owner/forged
denials, same-token revocation, post-lock revocation/demotion, stale/concurrent
transitions, retained history, pagination, duplicate/host checks and atomic quotas.
Private helpers and direct writes remain denied. Advisor results remain seven
intentional info findings and zero warnings/errors. No hosted/auth change.

## P09 implemented evidence and limits

The seventh migration derives comment/review identity from the session, verifies
team/parent IDs and live membership before and after team locking, and denies
self-review even for admins. Comment authors alone may edit; authors/team admins
may soft-delete with expected versions. Archived/deleted parents reject mutations.
The shared queue budget, fixed search paths, explicit RPC grants, denied private
helper/direct table access and original RLS/immutable keys remain in force.

Denial tests cover anonymous, foreign team, forged author/reviewer/team, revoked
valid tokens, queued revocation/demotion and direct-write bypasses. Concurrency
tests cover stale comment edits, one signal per user and shared atomic budgets.
Tests also cover PR replacement resets and stale review denial. Flutter Text
renders HTML-like content literally; no network fetch or external posting occurs.
See [ACTIVITY](ACTIVITY.md) for contracts and limits. SQL lint passes; the advisor
has seven intentional private RLS/no-policy info findings and zero warnings/errors.
P10 subsequently confirmed retained records without purge; no hosted change.

## P08 implemented evidence and limits

The sixth migration grants authenticated execution only for `queue_snapshot` and
`move_entry`; the private mutation implementation and direct writes remain denied.
Snapshots require live membership and use one stable statement snapshot for rows
and revision. Moves derive identity, require live team-admin status before and
after the team lock, reject foreign/deleted/archived and cross-group targets, and
require the observed queue revision. They share P07's atomic budget and lock order.

Direct tests cover anonymous/member/submitter/foreign-admin/revoked-token access,
forged team/owner arguments, private helper denial, concurrent admin conflicts,
post-lock demotion/revocation, destination append behavior and concurrent budgets.
The advisor still reports seven informational private RLS/no-policy findings,
zero warnings/errors; SQL lint passes. No auth/provider/hosted grants changed.
See [QUEUE](QUEUE.md) for limits and conflict recovery.

## P07 implemented evidence and limits

The fifth migration adds a private, empty-by-default per-team enterprise host
allowlist and atomic queue mutation budget. Server-side resource URL validation,
session-derived submitter, immutable team/owner, post-lock live membership/role
checks, expected versions, unique active PR/team, soft-deletion metadata and
minimal audit events are enforced through narrow RPCs. Direct writes/private
helper execution remain denied to API roles. Only active team members may read
their allowlist; the client revalidates stored links before opening a protected
new tab. No server fetch or external integration is present.

The P07 tests cover anonymous, cross-team, non-owner, forged-team/submitter,
revoked-token and queued-after-revocation denials; hostile URLs; concurrent
duplicates, edits and quota reservations; stale deletion; parent/child hiding;
all four priorities; and private configuration/function grants. SQL lint passes.
Local security advisors report seven informational private RLS/no-policy findings
and zero warnings/errors; these tables deliberately have no API access policies.
The shared audit uses no URL/title copies. See [QUEUE](QUEUE.md) for exact
grammar, budget semantics, operator configuration, runbook and limitations.

P07 adds no real company hosts or production access. Actual company navigation,
hosted P06/P07 deployment remains future work; P10 now supplies local recovery. Rate budgets
cap successful writes, not read traffic or all failed request attempts.

## P03 implemented evidence and limits

- Explicit table/function grants and RLS protect profiles, teams, memberships, invitations, entries, comments, and reviews. Direct writes are denied to all client roles. Private audit/email tables are not exposed. Function defaults revoke global PUBLIC execution as well as schema-specific grants.
- Live membership controls every team read. Profile access allows self or shared active teammates; emails are absent from profiles. A user's own profile remains accessible after team revocation, without revealing their old team's data or other teams' memberships.
- Only a live team admin may call `set_member_access` for an existing membership. It rechecks authority after acquiring the team lock, audits changes, increments data revision, and revokes pending invitations on removal. Triggers protect immutable ownership and last-admin invariants even on operator SQL writes; composite keys prevent cross-team child rows.
- Operator bootstrap requires privileged SQL and an existing verified Auth identity. It creates a team/admin/audit transactionally. No API role can invoke it. Teams cannot commit without an initial admin.
- SQL-role and real Data API tests use fictional fixtures and short-lived synthetic JWTs signed with the local development key. The runner refuses linked projects, remote Docker targets, other checkouts' containers, and non-loopback API addresses. Fixtures are outside migrations and configured seeds; no fake login is shipped in Flutter.
- Startup requests loopback binding using a dedicated Docker network, but this Windows Docker Desktop still reports all-interface publishes. The wrapper reports that concrete limitation; use a trusted development network/host firewall and stop the stack after use. Signup is disabled and mail remains local capture only. P04 now validates local Auth login and email budgets. Invitation claiming, live CAPTCHA enforcement, enterprise URL validation, mutation rate limits and hosted configuration remain later items. P03 grants no usable queue mutation path and makes no production-security claim.

Commands and scope are in the [backend README](../backend/README.md); actual results are in [STATUS](STATUS.md).

## Boundaries

P06's [onboarding evidence](ONBOARDING.md) extends the P03 boundary with guarded
invitation lifecycle/identity binding, self-only profile edits and owner-confirmed
email visibility to shared **active** teammates. Username and metadata cannot
claim invitations. Exact Auth user ID/current verified email, live admin checks,
post-lock revocation checks and explicit grants protect the new RPCs. Provisioning
can leave an unconfirmed orphan after a revoke race, but cannot grant membership.
Retry reconciles the same identity rather than deleting or pre-confirming it.

The new private limiter caps successful onboarding operations at 30 per identity
per one-minute window. The P03 membership implementation is now private behind
the budgeted public wrapper. Direct client writes and private helper execution
remain denied. Existing rolling mail budgets and CAPTCHA are unchanged.
Local security advisors reported five informational RLS/no-policy private tables,
zero warnings/errors on 2026-09-21. Those tables intentionally have no API grants
or policies; the prior hosted advisory result remains historical evidence.

Protect work identities, team membership, PR/Jira URLs, comments, and review activity. Treat company URLs as private metadata even when their destinations already require company access.

Anyone can download the Flutter frontend and view the sign-in page. Only authorized team members may retrieve team data. The source's public Supabase URL/publishable key and Turnstile site key are expected to be inspectable; they are not admin credentials.

Use Supabase RLS and server-side role/ownership checks. The app's public API addresses remain reachable independently of GitHub Pages. CORS, hidden UI controls, unguessable IDs, and secret-looking frontend configuration do not provide authorization. [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security)

## Sign-in and email abuse

- Disable public signup in provider settings. Server-provision accounts only for admin-created invitations; do not auto-grant a team because an Auth user exists.
- Match verified work email, not username or a client-supplied email. Normalize consistently without stripping plus tags or treating dots as interchangeable.
- Let Supabase generate and verify single-use magic links. Use an exact callback allowlist, a short configured validity (proposed 15 minutes), and provider CAPTCHA/rate controls.
- Use a provider-supported callback flow with no tokens in routine logs, analytics, referrers, or the URL after processing. Validate expired/replayed links, email-scanner visits, and opening in a different browser. If PKCE requires the originating browser, explain the recovery flow clearly.
- Requesting a link should show a generic acknowledgement; record and assess any unavoidable provider-level account-enumeration differences rather than claiming complete concealment.
- Verify the Send Email Hook's raw-body signature and timestamp before any send. Validate its payload and supported action type, then apply invitation and atomic email-budget checks. Refuse unsigned/replayed requests; valid retries are idempotent.
- Use a dedicated Resend sending key/domain, verify DNS records at Namecheap, and leave click/open tracking off for login mail. Sender verification is separate from hosting DNS.
- Keep provider admin keys and hook/Resend secrets in backend secret stores. No real mail in automated tests. A fake local login is excluded from hosted builds.

Supabase supports magic links and PKCE and provides CAPTCHA and rate controls. The implementation must test the selected combination rather than assume defaults are sufficient. [Magic links](https://supabase.com/docs/guides/auth/auth-email-passwordless), [PKCE](https://supabase.com/docs/guides/auth/sessions/pkce-flow), [Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook)

## Team isolation and mutations

- Every read and write checks active membership in the owning team. Profiles require a shared active team; never reveal a person's unrelated memberships.
- A removed member loses team data access on the next database request, even if their JWT has not expired. Prevent deleted memberships or old invitations from silently recreating access.
- Enforce immutable submitter/comment author/review author. Only submitter/team admin can delete entries; only team admins reorder or invite.
- Prevent role escalation, forged team IDs in nested resources, duplicate active entries, self-review (confirmed in P09), and removal of a team's last admin.
- Guarded mutation functions perform quotas and business changes transactionally. Revoke direct table writes that would bypass them. Elevated functions have fixed search paths and explicit caller checks.
- Bootstrap the first admin through an explicit operator action. Never use "first registered user wins". Require MFA on infrastructure/admin provider accounts.

## Browser and link safety

The owner replaced the shared-path design on 2026-09-18. The planned PR app origin is **`https://reviews.pedro-costa.dev`**, separate from the portfolio/PassGen origin `https://pedro-costa.dev`. The latter's scripts cannot directly read app-origin storage or DOM, and its service workers cannot control the app origin. Keep the subdomain dedicated to this app. This is a planned browser boundary, not evidence of a deployed or tested configuration. [Browser same-origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Same-origin_policy)

Separate origins under the same parent domain are not separate sites for every browser rule. Do not use `document.domain`, parent-domain auth cookies, broad credential sharing, or permissive message handlers to reconnect them. RLS, token verification and any future CSRF protection remain necessary. Review third-party scripts loaded by the app itself; code included in the app runs with its privileges.

P04 uses sessionStorage with memory fallback and SDK synchronization across open same-origin app tabs, as documented in AUTH. That synchronization will stay inside the new app origin; the tab-isolation limitation still applies among app tabs. GitHub Pages has limited custom response-header control; use a compatible CSP meta policy where effective and do not claim it supplies every header-based protection.

P04A migrated callback validation and fragment cleanup to `/` with local-only gates intact. Its tests reject old paths, unexpected origins and mixed callback parameters. In-page callback navigation is scrubbed and rejected, while a new-document email link still requires explicit confirmation. P05 must use exact trial/production callback settings and the specific Turnstile hostname; do not allow the old portfolio callback or wildcard redirects. P13 verifies the final hostname, HTTPS, origin separation, and login flow. Never copy or redirect login tokens from the old origin to the new one. Domain verification and removing stale DNS mappings on decommissioning belong in the deployment runbook.

Use plain-text comments/titles, validation on both client and server, and query parameters rather than concatenated SQL. Parse HTTPS links, reject credentials/embedded control characters, and enforce the agreed enterprise hostnames before real use. Do not fetch link metadata. Open links with `noopener`/`noreferrer` behavior and use a no-referrer policy for sensitive navigation.

No confidential data in static build assets, public fixtures, service-worker caches, browser error reports, CI logs, or repository exports. Test release assets and authentication callbacks together, including Flutter renderer/CAPTCHA compatibility with the chosen CSP.

## Data lifecycle and incident handling

Confirmed in P10 on 2026-09-26: retain archives, deleted records and minimal audit
metadata without automatic expiry or permanent purge; only active team admins
recover deleted entries. This supersedes proposed 30-day recovery and 90-day audit
retention. Recovery preserves previous state and does not revive individually
deleted comments. There is no purge SQL/API/job. A later destructive item must
settle cutoff, recovery, audit and restricted backup/restore policy before explicit
purge approval. Email-control records/budgets remain unchanged.

Create restricted backups/export instructions, retention, and a restore test before the pilot. Database restore is not necessarily full Supabase Auth/config/secret recovery; document those separately. Store no exports in the public repository. Select an available EU database region by default; do not equate this with a guarantee that all auth/email/log processing stays in the EU.

For an incident: revoke affected memberships/invites and sessions, disable mail sending if abused, rotate exposed provider keys, preserve minimal useful logs, and restore from a verified backup if needed. Prefer a temporary outage to disabling authorization. Free-plan limits and remaining availability risks are in [Costs](COSTS.md).

## Required evidence before pilot

### P05 trial controls and hosted advisor review

The operator-only admission table permits guarded first-user mail for at most
three identity/email pairs for up to 24 hours, never membership. The live Auth
email/ban/deletion checks still apply, and any existing membership prevents use of
this bootstrap exception. Tests deny unauthenticated/authenticated/service table
reads/writes, revoked/expired admissions and forged email pairs. Revoke admissions
after testing and remove the route before production.

Frontend and hook both require explicit hosted-trial configuration. Only the exact
loopback callback is accepted; dummy Turnstile keys cannot enable app auth. Secrets
remain in provider stores. The browser only holds public project/site keys.
Resend redirects fail closed, sends are bounded and uncertain results stay charged;
there is no retry or alternate provider. Live CAPTCHA must be enforced by Auth.

The final hosted check used a valid human-completed CAPTCHA after admission
revocation: the hook denied mail before reserving quota. Reuse of that token on
both Auth endpoints returned `timeout-or-duplicate`. Final counts remained three
reservations, zero active admissions, zero sessions and zero memberships. Passive
scanner rendering made no Auth calls; automated submission of the confirmation
control is outside that guarantee. Turnstile outage recovery made no Auth call.

Hosted advisor review on 2026-09-18 returned four informational
[RLS-without-policy findings](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
for private operator/hook tables. These intentionally deny API table access and
are not exposed. It also warned about
[authenticated SECURITY DEFINER execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
for `set_member_access`. This is the intended admin RPC: it derives identity,
checks live admin authority before and after locking, and has local denial and
concurrency coverage. No broad privilege was added to silence either finding.

### Launch matrix

| Test | Required result |
| --- | --- |
| Unauthenticated API access | No team rows, comments, review signals, profiles, or invitations exposed |
| Team A token used on Team B IDs | Read/write denied for all resource types and functions |
| Non-owner deletion or forged submitter | Denied by backend/database, independent of UI |
| Revoked member with a still-valid token | Denied immediately on next team request |
| Direct signup / direct email API calls | No uninvited account access or bypass of CAPTCHA/email budget |
| Concurrent sends / duplicated hook events | Atomic cap respected, no duplicate deliveries |
| Expired/reused/revoked invite or login link | No team access; useful recovery without leaking tokens |
| Concurrent admin reorder / last-admin removal | Conflict handled; invariants preserved |
| Malicious links and HTML-like comments | Rejected or displayed safely; no backend fetch |
| Quota/provider outage | Clear failure, no unbounded retry, no paid fallback |
| Static build / subdomain boundary | No embedded secrets; app remains on reviews.pedro-costa.dev with HTTPS; portfolio-origin DOM/storage access is denied and its service worker does not control the app |
| Callback / hostname configuration | Only intended app/trial callbacks accepted; fragment cleanup and explicit confirmation work at `/`; no parent-domain session sharing or redirect through the portfolio |

Run synthetic abuse tests locally with mocked mail first. Hosted checks use a small controlled set of developer accounts, not load tests against real inboxes.
