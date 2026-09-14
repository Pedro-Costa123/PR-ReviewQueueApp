# Architecture

Last researched: 2026-09-14. Status: P02 local frontend shell implemented; backend and deployment design remains proposed. No components deployed.

## Design

Use Flutter Web with Supabase for authentication, relational data, and server-side authorization. Deliver magic links through Resend. Keep Namecheap DNS and GitHub Pages as requested; publish the app's static files under the exact path on the existing site.

```mermaid
flowchart TD
    U[Team member's browser] -->|Namecheap DNS| GH[GitHub Pages: pedro-costa.dev]
    GH --> APP[/PR-Review-App-Queue/: Flutter static files]
    GH --> OTHER[Existing portfolio and PassGen]
    U -->|Magic-link sign-in + CAPTCHA| AU[Supabase Auth]
    AU --> EH[Signed Send Email Hook]
    EH -->|Allowlist + atomic send budget| RE[Resend]
    RE --> EM[Invited work email inbox]
    U -->|User JWT: reads and guarded mutations| DB[Supabase Postgres + RLS + SQL functions]
    U -->|Admin-only operations| EF[Supabase Edge Functions]
    EF --> AU
    EF --> DB
    U -->|Open links directly| CO[GitHub Enterprise / Jira Enterprise]
```

The browser never receives database admin credentials or Resend credentials. No backend request goes to GitHub Enterprise or Jira. The public HTML/Flutter bundle is not confidential; team data requires authorization.

## Hosting at the requested path

Required production base path: `/PR-Review-App-Queue/`, preserving case and a trailing slash. Flutter supports a non-root base path. Use hash routing initially, such as `/PR-Review-App-Queue/#/teams/<id>`, so refreshing an app screen does not need server rewrites. [Flutter URL configuration](https://docs.flutter.dev/ui/navigation/url-strategies)

The source repository is `Pedro-Costa123/PR-ReviewQueueApp`. Its name does **not** match the requested path. Enabling project Pages on this repo does not automatically publish at `/PR-Review-App-Queue/`. GitHub Pages project paths normally follow repository names; DNS cannot route by URL path. [GitHub Pages overview](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)

- Preferred publishing arrangement: include the Flutter build as the `PR-Review-App-Queue/` directory in the **complete artifact of the existing domain's Pages site**. Inspect that site's repository and publishing workflow in P12 before making changes. This project remains the source of the app; the existing site is only its publishing destination.
- Never upload an app-only artifact as the root site's entire deployment: that could remove the portfolio. Preserve the full current site artifact, CNAME, existing files and project-site routing.
- Build Flutter with the matching base href. Include `.nojekyll` where the chosen Pages publishing mode needs it.
- Put the magic-link callback at the existing app entry document, using the provider-supported query/fragment format validated in P04. Do not configure a nonexistent clean `/auth/callback` path and assume GitHub rewrites it.
- Test slashless/trailing-slash URLs, hash routes, query callbacks, browser refresh, assets, root portfolio, and `/PassGen/` on the actual Pages arrangement.
- Keep all hosted callback origins explicitly allowlisted. Do not enable arbitrary preview callbacks.

If the current site workflow cannot include the directory safely, present a concrete publishing alternative before changes: for example, a Pages publishing repository named exactly `PR-Review-App-Queue`. Do not rename this repository or create another one silently. A CNAME or Flutter base href alone cannot fix the repository/path mismatch.

GitHub Pages serves static files and does not run Supabase/backend code. It has restrictions on commercial SaaS and sensitive transactions. This plan is for the requested internal utility, not a commercial SaaS launch; revisit hosting if the use changes. See [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).

Paths share an origin with the portfolio and PassGen. They are not separate browser security boundaries. Session storage, root-scoped service workers, and scripts on sibling apps require review; details in [Security](SECURITY.md). The path is retained as requested. A subdomain would be a future option only if the owner changes this constraint.

## Frontend

P02 implementation: feature folders under `frontend/lib/`, a small read-only `QueueRepository` with fictional display models, Material themes, `go_router` 18.0.1 using its default hash strategy, and `shared_preferences` 2.5.5 through `SharedPreferencesAsync`. The lockfile is pinned. Theme preference is loaded before first rendering, defaults to dark independently of OS theme, and reports unavailable storage without blocking the app. No state-management or auth client package is installed yet.

Routes are `/`, `/teams/:teamId`, `/teams/:teamId/archive`, and `/teams/:teamId/profiles/:profileId`; unknown routes/IDs show a recovery screen. There is no signed-in demo identity or authentication bypass. The fictional profiles and entries are public static presentation data, not protected team records. All server permissions remain P03+ work. The local release preview serves the required base path without rewrites; this does not verify the actual Pages publishing arrangement.

- Flutter Web only; Material components, responsive queue, dark default and saved light preference.
- Start with feature folders: `auth`, `teams`, `queue`, `archive`, `profiles`, and small shared UI/services.
- Use the pinned routing package for deep links; verify real auth callback compatibility in P04. Keep state management minimal until multiple screens justify a package.
- Use the maintained Supabase Flutter client behind a small repository interface; fake repositories support the local shell. Domain models should not import widget code.
- Auth session storage decision is part of P04: prefer tab-scoped persistence, avoiding indefinite shared localStorage sessions. Verify SDK support and refresh/callback behavior; do not silently accept the SDK's persistence defaults.
- No tokens in URLs after callback processing, no auth data in analytics, and no offline caching of team data.
- No Realtime subscription in version 1. Refresh after successful writes, on tab return, manually, and at most once per 60 seconds while visible.

## Backend organization

Planned directories, to be created only by their backlog items:

```text
backend/
  supabase/
    config.toml
    migrations/           schema, constraints, RLS, transactional functions
    functions/            invite-member and guarded send-auth-email
    tests/                authorization and database behavior
  tests/                  Edge Function behavior and email-provider stubs
  README.md
frontend/
  lib/                    Dart app/features
  test/
  integration_test/
  web/                    entry page, app base path, callback-compatible shell
```

Use Supabase's generated Data API for narrowly granted reads and transactional SQL functions for mutations with business invariants. Do not create a parallel CRUD server without a concrete need. Edge Functions are for operations requiring provider secrets, particularly user provisioning and email delivery.

SQL functions normally execute with caller privileges. Any necessary elevated function must have explicit identity/team checks, a fixed safe search path, minimal grants, and dedicated denial tests. Revoke broad table writes and function execution that would bypass these checks. Row-level security applies to exposed tables; views must preserve it, and storage/internal schemas are not exposed. [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)

## Data model

IDs are generated UUIDs. Store UTC timestamps, display local time, and use database constraints in addition to UI validation.

| Entity | Key data and invariants |
| --- | --- |
| `auth.users` | Supabase-managed identity; server-provisioned after invitation, no public signup |
| `profiles` | `user_id`, name, normalized unique username, timestamps; identity email comes from Auth, not editable profile data |
| `teams` | ID, name, queue revision, data revision; initial creation through operator bootstrap |
| `team_memberships` | Team/user unique pair, role `member` or `admin`, active/revoked state; prevent removal of last admin |
| `team_invites` | Team, exact normalized email, role, inviter, expiry, provisioning state, claimed identity; unique pending invite per team/email |
| `queue_entries` | Team, immutable submitter, title, PR/Jira URLs, normalized PR URL, sprint flag, priority, group position, active/archived state, version, timestamps, archive reason/actor, optional deletion fields |
| `entry_comments` | Entry/team, immutable author, plain-text body, timestamps, optional deletion metadata |
| `entry_reviews` | Entry/team/user unique tuple, `looks_good` or `comments_left`, timestamp; clear means remove current signal |
| `audit_events` | Team, actor, action, target ID, timestamp, minimal change metadata; no auth tokens or full comment copies |
| private email-control tables | Per-recipient/project quota reservations and webhook idempotency IDs; readable only by the sending hook/operator |

Use composite foreign keys or equivalent database constraints so child rows cannot claim a different team than their parent. Index membership lookups, active entries by team/group/position, archive pagination, comments by entry, and review uniqueness. Use a partial unique index to prevent duplicate non-deleted active PR URLs per team.

Avoid a globally readable email column in profiles. If team admins need a roster email, expose it through a specifically authorized server function. A shared profile does not disclose the person's other teams.

## Authentication and onboarding

1. An authenticated team admin requests an invite for an exact email and role. The server rechecks live admin membership; it never trusts a role in the request body or user-editable metadata.
2. Persist a pending invitation before provisioning Auth. Provision an unconfirmed email identity if absent, without creating a password or granting membership. Use server-only Auth admin capabilities. Repeated requests reconcile the same identity/invite instead of duplicating them.
3. An invited user requests a magic link with a valid CAPTCHA. Disable public signup in Supabase settings and pass `shouldCreateUser: false`. These are separate protections: client options alone are insufficient. [Auth settings](https://supabase.com/docs/guides/auth/general-configuration), [passwordless sign-in](https://supabase.com/docs/guides/auth/auth-email-passwordless)
4. Supabase creates the login material and calls a signed Send Email Hook. The hook verifies signature/timestamp, checks active membership or a valid invite, atomically reserves email budget, and sends through Resend. Do not build a custom token generator.
5. The callback verifies the provider-issued material through the supported flow and claims pending team invitations for the authenticated, verified email in a transaction. Auth record existence alone never grants team access. Profile completion follows.
6. Removing membership is effective for every database request even while a JWT remains valid. Revoke pending invitations too; another team's membership must remain intact.

The hook is important because direct calls to the public Auth API can bypass this Flutter UI. Budget and invitation checks must still run for every supported email action. Unsupported email actions fail closed. The hook is available on Supabase Free. [Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks), [Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook)

P04-P05 must prove that server-provisioned identities can receive magic links with signup disabled, including expired/revoked invitations and email-scanner behavior. If a provider flow needs adjustment, record a small decision change before queue implementation. Initial app-invite expiry and short-lived sign-in-token expiry are different clocks.

## Mutations and consistency

- Read identity from the verified session, derive ownership server-side, and recheck current membership in the database transaction.
- Use transactional functions such as `create_entry`, `update_entry`, `move_entry`, `archive_entry`, `restore_entry`, `set_review`, and `claim_invites`. Names are proposed contracts, not existing functions.
- Entry edits carry an expected version; stale writes return a conflict and the latest version. Do not silently overwrite another user's change.
- A reorder locks the team's queue revision, checks the expected revision, validates admin/group membership, and updates positions atomically. A bounded group can be reindexed in one transaction; avoid fractional-rank infrastructure at this scale.
- Changing sprint flag/priority appends to the destination group and advances the queue revision. Restore behaves similarly. Database uniqueness detects an active duplicate during restore.
- All user-visible mutations also advance a team data revision. Background refresh checks this small value and reloads queue details only after a change, keeping transfer usage low. Comments/reviews do not unnecessarily invalidate a reorder's queue revision.
- Mutation rate limits live in the same guarded server path as mutations, so raw Data API writes cannot bypass them. Pagination and bounded response fields constrain read size.

## Environments and operations

Use Docker-backed local Supabase and a local email inbox/stub initially. Never send real mail in automated tests. Check the Supabase CLI and Edge Function tooling requirements during P03; Node is present but its installed version is not assumed supported by every tool.

Use one hosted Free project for the developer trial/pilot if eligible; local development avoids an extra hosted staging bill. Choose an available EU region as the default, without claiming that every vendor's logs/auth/email remain in the EU. Avoid a paid Supabase custom domain: the required frontend address does not require one.

Build verification can later run in GitHub Actions with the account's available allowance. Production deployment starts manually, from a known revision, with rollback instructions. Version schema and config; keep secrets in vendor/CI secret stores. Free Supabase has no included automatic backups, so design a restricted export and restore procedure before pilot. See [Costs](COSTS.md) and [Next](NEXT.md).
