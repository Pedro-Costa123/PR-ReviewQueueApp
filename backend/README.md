# Backend

P03 implements the **local database and authorization foundation**. P04 adds local
magic-link authentication, a signed Edge hook, guarded quotas and Mailpit delivery.
The Flutter sign-in screen and signed-in queue can connect locally.
P05 adds a gated Resend sender, bounded operator trial admissions and mock sender
tests and a CLI-backed operator provisioning helper. The existing Free hosted
project has the three migrations and the signed hook deployed/enabled. Controlled
delivery/login and live denial checks passed; the trial admission is now revoked.
Inbox placement remains a release follow-up.

P06 adds a fourth **local** migration, `invite-member`, guarded invitation
claiming and profile RPCs, and the budgeted membership wrapper. Its 14 dedicated
tests run with `npm run test:onboarding` while `npm run functions` is serving.
See [ONBOARDING](../docs/ONBOARDING.md) for setup, recovery, grants and evidence.
The hosted project still has three migrations; no P06 deployment was performed.

P07 adds the fifth local migration, guarded create/edit/delete functions,
private exact enterprise host configuration and queue mutation limits. Priorities
are Low/Medium/High/Critical. `npm run test:queue` runs its direct API, denial and
concurrency checks. See [QUEUE](../docs/QUEUE.md) for the local preview, operator
host configuration, URL grammar and verification. No P07 hosted deployment.

P08 adds the sixth local migration: ordered `queue_snapshot` with its matching
revision and admin-only `move_entry`, sharing P07's budget/team serialization.
Run `npm run test:ordering` for ordering, denial and concurrent-mutation coverage.
The QUEUE runbook includes mixed-group browser fixtures. No hosted migration.

P09 adds the seventh local migration: plain-text comments with author versions,
author/admin deletion and per-user check/X/clear signals with no self-review.
Run `npm run test:activity` for direct API denials, concurrency and count/reset
checks. See [ACTIVITY](../docs/ACTIVITY.md). No hosted migration or external posting.

Follow [AUTH](../docs/AUTH.md) for the complete P04 setup/test/preview sequence.
Use [HOSTED_AUTH](../docs/HOSTED_AUTH.md) for P05; never run local fixtures/tests
against the hosted project or link this local test checkout to it.

The researched proposal is Supabase Postgres/Auth with row-level security, SQL functions, and TypeScript Edge Functions. Resend delivers magic links through a guarded Send Email Hook. GitHub Pages serves the public frontend; it does not replace database authorization.

## Local setup and checks

Run from `backend/`, with Docker Desktop's Linux engine running:

```powershell
npm ci
npm start
npm run reset
npm test
npm run lint
```

The CLI is pinned to **2.117.0** in the application lockfile. P04's TypeScript
hook tests use Node's built-in type stripping and require Node 22.18+; the CLI
itself requires Node 20+. This project was checked with Node 26.5.0/npm 11.17.0 on Windows.
The first start downloads Docker images. The CLI also uses a user cache outside
the repository; an agent sandbox may need permission to access that cache and
the Docker engine. No global CLI installation is required.

`npm start` creates/validates the dedicated `pr-review-queue-local` Docker bridge,
requests loopback binding, runs Postgres 17, Auth, the Data API/gateway, and a
local mail capture service, and reports actual bindings. It suppresses CLI
credential output. Unused Storage, Realtime, Studio, analytics, and pooler
services are disabled. Public/anonymous signup is disabled. P04 enables Edge Runtime and routes Auth mail through the signed local hook. No external SMTP
provider is configured. This config is for local development, not deployment.

**Observed Windows limitation:** Docker Desktop 4.91.0/engine 29.8.0 with CLI
2.117.0 reported all-interface published ports despite Supabase's documented
loopback network option. The wrapper reports this instead of claiming isolation.
Use the stack only on a trusted development machine/network with appropriate
host firewall restrictions; never expose it publicly. It is stopped at handoff.
Tests connect only to loopback and use fictional data. See the
[official local network guidance](https://supabase.com/docs/guides/local-development).

`npm run reset` **recreates only this project's local database**, applying the
migration to an empty schema. It intentionally loads no identities or seed data.
Do not use it to preserve local work. `npm test` requires that empty database and
loads fictional fixtures; run reset before each full test run. Tests leave those
fixtures behind for local inspection. `npm run lint` checks both application
schemas. Stop the stack with `npm run stop`; the default stop preserves data.

The tests use Node's built-in runner and Docker's bundled `psql`, without another
database driver or testing package. They reject linked Supabase projects, remote
Docker contexts/host overrides, unexpected project containers, and non-loopback
API URLs. Short-lived test JWTs are generated in memory from the local stack's
signing material. They are not a login implementation; no test identity code is
imported into Flutter, stored in migrations, or configured as a deployable seed.
Do not copy test fixtures into a hosted database. Raw CLI status/start output
includes local development keys; do not paste it into committed logs or documents.

## Implemented boundary

- `supabase/migrations/`: profiles, teams, memberships, invitations, entries,
  comments, reviews, and private audit/email-control tables.
- `public`: authenticated reads through RLS. Own profile or shared active-team
  profiles are readable; no email lives in profiles. Membership rows reveal only
  accessible teams; inactive rows and invitation emails are visible only to that
  team's admins.
- `private`: audit and future email-budget/idempotency storage, with no client
  table grants or Data API exposure. Only membership/profile predicate helpers
  are executable by authenticated users; they always derive identity from JWT.
- `set_member_access(p_team_id, p_user_id, p_role, p_active)`: P03's membership
  mutation, now wrapped with P06's budget. An active team admin can change an **existing** membership. It locks
  the team, rechecks live authority, advances data revision, audits the change,
  and revokes matching pending invitations when removing access. It cannot
  create a membership. The last active admin cannot be removed or demoted.
- Direct table writes are denied even to team admins and submitters. Immutable
  keys and composite foreign keys add protection beneath future guarded writes.
  Read policies hide soft-deleted entries and their children. P07 adds guarded
  owner/admin soft deletion; restoration, reorder and purge remain unimplemented.

The `private` schema is not exposed by PostgREST. All elevated functions have a
fixed empty search path. Explicit grants and global/schema default revocations
prevent newly added functions inheriting PUBLIC execution. Future migrations
must continue to declare permissions explicitly and extend the denial tests.

P07 confirms title/entry permissions and Low/Medium/High/Critical priorities,
implements enterprise URL validation and the queue mutation budget. Self-review
behavior remains P09, and retention/purging P10. P04 adds service-role-only reserve_auth_email/finish_auth_email functions and
atomic budgets; clients still cannot access operational tables. P06 adds admin
UI/provisioning, profile/claim RPCs and onboarding mutation limits. This remains a
locally verified implementation, not a release.

## Explicit operator bootstrap

`operator/bootstrap.sql` creates a team and its first admin in one transaction,
with an audit event. It requires a privileged SQL operator and an **existing,
verified Auth user ID**. No visitor, client, service-role API, username, or email
claim can invoke it. There is no automatic first-user promotion.

For a local demonstration **after the tests have loaded fictional identities**:

```powershell
Get-Content -Raw operator/bootstrap.sql | docker exec -i supabase_db_pr-review-queue psql -X -U postgres -d postgres -v team_name="Fictional bootstrap demo" -v admin_user_id="10000000-0000-4000-8000-000000000007"
```

The command deliberately creates a new team each time; record its returned ID.
The first-admin constraint is deferred until commit, so a team cannot be left
without an admin. An Auth identity must be verified through the future supported
onboarding flow before bootstrapping real use. Never manually mark a real email
verified just to satisfy this check. There is no production bootstrap to run in
P03. Missing/unverified identities and API attempts are covered by tests.

## Verification coverage and next step

SQL-role and HTTP tests cover positive reads, anonymous/outsider/cross-team
denials, forged ownership/direct writes, private schema and function grants,
revocation with an unchanged valid token, invitation revocation, parent/child
invariants, duplicate records, operator bootstrap, and concurrent admin changes.
Those P03 tests do not claim real Auth login or delivery. P04's separate test:auth
suite checks actual local Auth and captured delivery; neither suite claims deployed security.

P04A is complete locally: Auth Site URL and the sender's exact callback use
`http://127.0.0.1:4173/`, preparing for `https://reviews.pedro-costa.dev/`.
`npm start` migrates the known old `.env` callback without rotating the secret;
stop an already-running stack first and restart the function terminal afterward.
The full replacement sequence and browser checks are in AUTH/STATUS.
Continue **P05** hosted authentication/cost validation from HOSTED_AUTH;
provider setup and controlled live acceptance remain the current boundary.
The frontend subdomain does not require a paid Supabase custom domain.
See [NEXT](../docs/NEXT.md), [STATUS](../docs/STATUS.md),
[ARCHITECTURE](../docs/ARCHITECTURE.md), and [SECURITY](../docs/SECURITY.md).

Tooling/security references checked 2026-09-16: [Supabase CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[database functions and grants](https://supabase.com/docs/guides/database/functions).
