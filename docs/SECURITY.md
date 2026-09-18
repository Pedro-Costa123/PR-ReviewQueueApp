# Security design and launch evidence

Last updated: 2026-09-18. P03 database authorization and P04 local sign-in/email guards are implemented and tested. The production subdomain is confirmed; root-path migration, hosted CAPTCHA/mail, lifecycle and launch controls remain planned. [AUTH](AUTH.md) records implemented controls and limits.

The queue still contains only public fictional presentation fixtures. P04 adds a real local Auth client and sessionStorage adapter, with SDK cross-tab synchronization. There is no fake signed-in identity, role switch or company URL. Browser navigation between demo teams is not an authorization test. P03 SQL-role/Data API denial tests run separately against local Supabase. The release build remains a local preview, not a production authentication path.

## P03 implemented evidence and limits

- Explicit table/function grants and RLS protect profiles, teams, memberships, invitations, entries, comments, and reviews. Direct writes are denied to all client roles. Private audit/email tables are not exposed. Function defaults revoke global PUBLIC execution as well as schema-specific grants.
- Live membership controls every team read. Profile access allows self or shared active teammates; emails are absent from profiles. A user's own profile remains accessible after team revocation, without revealing their old team's data or other teams' memberships.
- Only a live team admin may call `set_member_access` for an existing membership. It rechecks authority after acquiring the team lock, audits changes, increments data revision, and revokes pending invitations on removal. Triggers protect immutable ownership and last-admin invariants even on operator SQL writes; composite keys prevent cross-team child rows.
- Operator bootstrap requires privileged SQL and an existing verified Auth identity. It creates a team/admin/audit transactionally. No API role can invoke it. Teams cannot commit without an initial admin.
- SQL-role and real Data API tests use fictional fixtures and short-lived synthetic JWTs signed with the local development key. The runner refuses linked projects, remote Docker targets, other checkouts' containers, and non-loopback API addresses. Fixtures are outside migrations and configured seeds; no fake login is shipped in Flutter.
- Startup requests loopback binding using a dedicated Docker network, but this Windows Docker Desktop still reports all-interface publishes. The wrapper reports that concrete limitation; use a trusted development network/host firewall and stop the stack after use. Signup is disabled and mail remains local capture only. P04 now validates local Auth login and email budgets. Invitation claiming, live CAPTCHA enforcement, enterprise URL validation, mutation rate limits and hosted configuration remain later items. P03 grants no usable queue mutation path and makes no production-security claim.

Commands and scope are in the [backend README](../backend/README.md); actual results are in [STATUS](STATUS.md).

## Boundaries

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
- Prevent role escalation, forged team IDs in nested resources, duplicate active entries, self-review if the proposed rule is retained, and removal of a team's last admin.
- Guarded mutation functions perform quotas and business changes transactionally. Revoke direct table writes that would bypass them. Elevated functions have fixed search paths and explicit caller checks.
- Bootstrap the first admin through an explicit operator action. Never use "first registered user wins". Require MFA on infrastructure/admin provider accounts.

## Browser and link safety

The owner replaced the shared-path design on 2026-09-18. The planned PR app origin is **`https://reviews.pedro-costa.dev`**, separate from the portfolio/PassGen origin `https://pedro-costa.dev`. The latter's scripts cannot directly read app-origin storage or DOM, and its service workers cannot control the app origin. Keep the subdomain dedicated to this app. This is a planned browser boundary, not evidence of a deployed or tested configuration. [Browser same-origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Same-origin_policy)

Separate origins under the same parent domain are not separate sites for every browser rule. Do not use `document.domain`, parent-domain auth cookies, broad credential sharing, or permissive message handlers to reconnect them. RLS, token verification and any future CSRF protection remain necessary. Review third-party scripts loaded by the app itself; code included in the app runs with its privileges.

P04 uses sessionStorage with memory fallback and SDK synchronization across open same-origin app tabs, as documented in AUTH. That synchronization will stay inside the new app origin; the tab-isolation limitation still applies among app tabs. GitHub Pages has limited custom response-header control; use a compatible CSP meta policy where effective and do not claim it supplies every header-based protection.

P04A must migrate callback validation and fragment cleanup to `/` without weakening the local-only gates. P05 must use exact trial/production callback settings and the specific Turnstile hostname; do not allow the old portfolio callback or wildcard redirects. P13 verifies the final hostname, HTTPS, origin separation, and login flow. Never copy or redirect login tokens from the old origin to the new one. Domain verification and removing stale DNS mappings on decommissioning belong in the deployment runbook.

Use plain-text comments/titles, validation on both client and server, and query parameters rather than concatenated SQL. Parse HTTPS links, reject credentials/embedded control characters, and enforce the agreed enterprise hostnames before real use. Do not fetch link metadata. Open links with `noopener`/`noreferrer` behavior and use a no-referrer policy for sensitive navigation.

No confidential data in static build assets, public fixtures, service-worker caches, browser error reports, CI logs, or repository exports. Test release assets and authentication callbacks together, including Flutter renderer/CAPTCHA compatibility with the chosen CSP.

## Data lifecycle and incident handling

Proposed defaults pending lifecycle confirmation: retain archived entries until deliberately removed; soft-delete recovery for 30 days; audit metadata retained for 90 days. Do not implement automatic purges before P10 settles these defaults. Email budgets need only the records necessary for their time windows and idempotency.

Create restricted backups/export instructions, retention, and a restore test before the pilot. Database restore is not necessarily full Supabase Auth/config/secret recovery; document those separately. Store no exports in the public repository. Select an available EU database region by default; do not equate this with a guarantee that all auth/email/log processing stays in the EU.

For an incident: revoke affected memberships/invites and sessions, disable mail sending if abused, rotate exposed provider keys, preserve minimal useful logs, and restore from a verified backup if needed. Prefer a temporary outage to disabling authorization. Free-plan limits and remaining availability risks are in [Costs](COSTS.md).

## Required evidence before pilot

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
