# Backend

Supabase Postgres/Auth, guarded SQL functions and two TypeScript Edge Functions
provide the connected workspace. Ten versioned migrations cover authorization,
onboarding, entries, ordering, comments/reviews, lifecycle and paginated refresh.
The trial mail-admission route is retired and its operator scripts fail closed.

The existing deployment is in pilot evaluation; see the [project README](../README.md).
This guide describes local development, not authorization to modify hosted data.
Cloudflare Pages serves the frontend; Supabase enforces team membership and ownership.

Use [AUTH](../docs/AUTH.md) for local login and captured mail,
[ONBOARDING](../docs/ONBOARDING.md) for invitations/profiles, and
[QUEUE](../docs/QUEUE.md), [ACTIVITY](../docs/ACTIVITY.md),
[LIFECYCLE](../docs/LIFECYCLE.md) and [REFRESH](../docs/REFRESH.md) for feature contracts.
The [production checklist](.env.production.example) contains no credentials;
[RELEASE](../docs/RELEASE.md) describes release/recovery tooling.

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
host firewall restrictions; never expose it publicly. Stop it with `npm run stop` when finished.
Tests connect only to loopback and use fictional data. See the
[official local network guidance](https://supabase.com/docs/guides/local-development).

`npm run reset` **recreates only this project's local database**, applying the
migrations to an empty schema. It intentionally loads no identities or seed data.
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
- `private`: audit and email-budget/idempotency storage, with no client
  table grants or Data API exposure. Only membership/profile predicate helpers
  are executable by authenticated users; they always derive identity from JWT.
- `set_member_access(p_team_id, p_user_id, p_role, p_active)`: P03's membership
  mutation, now wrapped with P06's budget. An active team admin can change an **existing** membership. It locks
  the team, rechecks live authority, advances data revision, audits the change,
  and revokes matching pending invitations when removing access. It cannot
  create a membership. The last active admin cannot be removed or demoted.
- Direct table writes are denied even to team admins and submitters. Immutable
  keys and composite foreign keys add protection beneath guarded writes.
  Read policies hide soft-deleted entries and their children. Guarded RPCs implement
  owner/admin deletion, archive/restore and admin-only recovery/reorder. There is no purge.

The `private` schema is not exposed by PostgREST. All elevated functions have a
fixed empty search path. Explicit grants and global/schema default revocations
prevent newly added functions inheriting PUBLIC execution. Future migrations
must continue to declare permissions explicitly and extend the denial tests.

Entry permissions, review identity, ordering and lifecycle rules are enforced in
SQL functions. Service-role-only mail RPCs reserve atomic budgets and record
idempotent outcomes; clients cannot access operational tables.

## Explicit operator bootstrap

For the owner-approved first admin created through the Supabase website, follow
`docs/ADMIN_SETUP.md` (local operator notes) and use
[`operator/create-team-admin.sql`](operator/create-team-admin.sql). It calls the
existing bootstrap function; no migration is needed. The first-admin manual
email-confirmation exception is described in that guide.

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
without an admin. Normally, the Auth identity must be verified through the
supported onboarding flow. The owner-approved first-admin exception above lets
the operator vouch for that email using the dashboard's Auto confirm option.
Other users still require the normal invitation/verification flow. Do not run
the fictional demonstration against a hosted database. Missing/unverified
identities and API attempts are covered by tests.

## Production workspace reset

`operator/reset-project.sql` starts over with one existing verified admin and a
new team. The operator instructions are kept locally in `docs/RESET.md`.
It previews by default. Explicit apply deletes all old workspace data and all
other Auth accounts in one transaction while preserving email sending controls
and the deployed schema/configuration. This is separate from the local
`npm run reset` development command. Rehearse with `npm run test:reset`; no production
reset is performed by that test.

## Verification coverage and next step

SQL-role and HTTP tests cover positive reads, anonymous/outsider/cross-team
denials, forged ownership/direct writes, private schema and function grants,
revocation with an unchanged valid token, invitation revocation, parent/child
invariants, duplicate records, operator bootstrap, and concurrent admin changes.
Those P03 tests do not claim real Auth login or delivery. P04's separate test:auth
suite checks actual local Auth and captured delivery; neither suite claims deployed security.

The local callback is `http://127.0.0.1:4173/`. Production remains fixed to the
selected Pages origin and sender domain. Historical trial provisioning is retired.
Do not link this test checkout to a hosted project or copy fixtures into production.
See [NEXT](../docs/NEXT.md), [ARCHITECTURE](../docs/ARCHITECTURE.md) and
[SECURITY](../docs/SECURITY.md).

Tooling/security references checked 2026-09-16: [Supabase CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[database functions and grants](https://supabase.com/docs/guides/database/functions).
