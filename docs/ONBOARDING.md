# P06 invitations, teams and profiles

Updated: 2026-09-21. Implemented and verified locally; no P06 hosted deployment.
P05 is the completed dependency. Queue behavior remains P07 and later.

## Decisions and flow

The owner confirmed **email visibility to all active teammates**, as well as the
user themselves. `profile_details` checks shared live membership on every call.
It reveals no unrelated memberships and provides no global directory. Profiles
store name/normalized unique username; email comes from Auth and cannot be edited
through the profile form. Names are 1–100 characters; usernames are 3–40 lowercase
letters/numbers/dots/underscores/hyphens, starting with a letter or number.

Operator-created teams and team-scoped admins remain the P06-authorized defaults.
Use [the existing bootstrap procedure](../backend/README.md#explicit-operator-bootstrap)
with an already verified Auth identity. Public team/account signup stays disabled.

1. An active admin chooses an exact email and member/admin role. `prepare_invite`
   derives the inviter from the JWT, locks the team and rechecks live authority.
   Invitations last seven days. A repeated pending invitation retains its ID,
   role and expiry; revoke it first to change the role. An expired invitation is
   revoked and replaced when explicitly retried.
2. `invite-member` validates the bearer through Auth `/user`, uses the caller's
   JWT for preparation, then service-only reconciliation for that invitation.
   Auth creation sets `email_confirm: false` and supplies no password. It sends
   no mail and grants no membership. The backend looks up only the exact invited
   email, never exposes a global Auth list, and never accepts an actor from JSON.
3. Lost/failed creation responses are reconciled against Auth. The pending/failed
   invitation remains retryable. A concurrent revoke/admin removal prevents
   completion. A user created during that race may remain as an unconfirmed,
   unentitled Auth record; never delete a possibly shared identity as compensation.
4. After provisioning, the browser requests a provider sign-in link through the
   existing OTP/confirmation-resend flow. Every hosted attempt retains a fresh
   Turnstile challenge, the signed hook and atomic mail budgets. Provisioning and
   sending are distinct outcomes: if sending fails, retry the saved invitation
   after a minute. There are no background retries or alternate mail routes.
5. After explicit link confirmation, the workspace calls `claim_invites`.
   It checks the current verified Auth email **and** bound provisioned user ID;
   username, user metadata and client-supplied email confer no authority.
   It locks teams in UUID order and rechecks invitation expiry/revocation after
   locking. Concurrent claims create one membership. Existing memberships are
   never replaced or silently reactivated by claims.
6. Complete the profile, select a real team, open teammate profiles and, as an
   admin, manage invitations/roles/removal/restoration. Removing someone revokes
   pending invitations for that team/email and preserves their other teams.
   The locked P03 implementation still protects the last admin. Inactive roster
   rows show their stable user ID without disclosing a removed person's profile.

The signed-in workspace is at `/`. Existing `/teams/atlas` and `/teams/orbit`
routes are explicitly fictional demo queues, not database-backed queue pages.
The real team workspace has an empty queue placeholder until P07. Default builds
without authentication defines stay disconnected. No local fake identity is
compiled into the application.

## Server boundary

- Migration: [20260921132850_onboarding.sql](../backend/supabase/migrations/20260921132850_onboarding.sql).
- Client RPCs: `prepare_invite`, `revoke_invite`, `claim_invites`, `save_profile`,
  `profile_details` and the budgeted `set_member_access` wrapper.
- `reconcile_invite` is service-only; the underlying membership function and
  mutation limiter live in `private` without API execution grants.
- Direct table writes remain denied. Private rate-limit rows have RLS and no
  API grants. Successful onboarding mutations/claims share an atomic allowance
  of 30 per identity per fixed one-minute window. Mail has its stricter independent
  rolling limits. Failed transactions roll back their counter changes.
- The Edge handler bounds body size, validates fields, uses bounded network
  attempts and exact local/trial configuration, and returns sanitized errors.
  Hosted provisioning is restricted to the existing trial recipient allowlist.
  Production mode remains rejected until release work.
- Invite/member transitions are audited. Profile edits are self-only and use
  last-save-wins semantics; profile conflict UX is not claimed.

## Reproduce local verification

From `backend/`, with Docker running, use fictional data only:

```powershell
npm start
npm run reset
npm test
npm run lint
```

In another backend terminal, keep both Edge Functions running:

```powershell
npm run functions
```

Then from the first backend terminal:

```powershell
npm run test:auth
npm run test:onboarding
node tool/prepare-onboarding-preview.cjs
```

The helper refuses remote/linked projects, creates an unconfirmed fictional
`p06-preview@example.test` identity and two invitations (Atlas admin, Orbit
member), and writes ignored **public** frontend config. It does not sign in,
pre-confirm that user, send mail or create their memberships. Fixtures/tests and
this helper are outside migrations and application imports.

From `frontend/`:

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.local.json
node tool/serve.cjs
```

Open `http://127.0.0.1:4173/`, request the preview address's link and open the
captured message from `http://127.0.0.1:54324/` in a new document. Confirm, complete
the profile, switch teams and invite another fictional `@example.test` address.
The actual Auth provider verifies these local links; these are not mocked logins.

Stop both foreground servers with Ctrl+C and run `npm run stop` from backend
after verification. The documented Docker all-interface binding limitation
still applies. Rebuild without the define-file flag for the disconnected demo.

## Evidence and limits

- Clean reset applied all four migrations. Existing authorization suite: 19 passed.
  Auth/hook suite: 28 passed. New onboarding/handler suite: 14 passed.
- New tests exercise a real local Edge → Auth → signed hook → Mailpit → verify →
  claim path, one delivered message, exact team/role, idempotent retries, lost
  creation response, failed recovery, two teams, email disclosure, profile
  ownership, unverified/expired/revoked/forged identity denial, direct writes,
  mutation budget, concurrent claims and claim/revoke serialization.
- Flutter analysis passed; 25 tests passed, including first-login completion,
  team switching/admin control visibility, denied/offline load recovery,
  duplicate username and cancelled/invalid invitations. JavaScript callback,
  Turnstile bridge and preview suites: 15 passed.
- Local SQL lint found no schema errors. Security advisor returned five
  informational private-table/RLS-without-policy findings, no warnings/errors.
  These tables deliberately have no client access. Hosted advisor output may
  differ; do not claim this was a hosted security review.
- Browser checks used the configured root release, genuine captured mail,
  first-login claiming, profile completion, team selection, admin invitations,
  teammate email view, keyboard Tab/Enter/Escape and 390 × 844 light/dark layout.
  Browser QA found clipped username helper text; it now wraps to two lines.
  Owner review also identified the default button padding offsetting roster
  names from role/status text. Names now share the same left edge and the current
  user's roster entry is labeled “(you)”.
  A second owner alignment review found excess vertical space from the separate
  name button. Name/status now form one accessible clickable block with a
  four-pixel gap and a minimum 48-pixel target; admin action labels use the same
  left edge. Analysis and all five onboarding widget tests passed after this fix.
  The rebuilt desktop and 390-pixel browser preview confirmed balanced vertical
  padding, matching text edges and aligned admin actions. Enter opens the grouped
  profile target and Escape closes it; keyboard sign-out clears the workspace.
  Resend/revoke, member role/removal, reload persistence and sign-out were also
  exercised in the browser. The last console review returned no warnings/errors.
- Final generated build is the default disconnected root release, rebuilt and
  browser-checked after alignment QA. Preview/functions and the local Supabase
  stack were stopped, preserving fictional data. Use the commands above to
  rebuild and restart the configured onboarding preview for review.

P06 changes have **not** been applied to the hosted project. The P05 admission
remains revoked and its Junk-placement limitation remains open. Before any later
hosted onboarding trial, apply the reviewed migration and deploy `invite-member`
within an explicitly selected deployment task; use a controlled recipient in the
existing allowlist. No real-company invitation, DNS change, Pages publication,
new service or billing change was performed here.

Lists are bounded at 100 records with an explicit limit notice; full pagination,
tab-return/background refresh and queue behavior remain later backlog items.
Membership removal is enforced on the next server request; already rendered
content is not remotely erased. No material P06 product question remains open.
Review this onboarding workflow before selecting P07.
