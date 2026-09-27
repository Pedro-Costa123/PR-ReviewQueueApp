# PR Review Queue

A team review queue built with Flutter Web. Keep pull requests visible, prioritize
sprint work, and record review feedback without connecting to GitHub or Jira APIs.

**Status: deployed pilot; evaluation is still in progress.**
The [live app](https://pr-review-queue.pages.dev/) offers fictional demo queues.
The signed-in workspace is invitation-only; viewing or cloning this repository
does not grant access to its team data. This is an experimental project, not a
production-readiness guarantee.

## Features

- Separate team workspaces, member profiles, admin invitations and role controls.
- Entries with a title, PR/Jira links, sprint-goal flag and Low/Medium/High/Critical priority.
- Sprint-first ordering and admin drag or keyboard reordering within priority groups.
- Plain-text comments and per-user review signals; submitters cannot review their own entries.
- Owner/admin editing, archive and restore; admin-only recovery of deleted entries.
- Search, filters, paginated lists and visible-tab refresh.
- Responsive Flutter UI, dark default and a saved light-mode preference.

PR status is maintained manually. Review signals do not post to external services
or replace approvals on the PR. Archives and deleted records are retained; there
is no automatic purge.

## Stack

| Layer | Implementation |
| --- | --- |
| Frontend | Flutter Web / Dart |
| Database and authorization | Supabase Postgres, row-level security and guarded SQL functions |
| Authentication | Invited-email magic links and Cloudflare Turnstile |
| Email | Resend through a signed hook with server-enforced sending budgets |
| Hosting | Static Cloudflare Pages deployment via manual Direct Upload |

## Run the fictional demo locally

The release tooling pins Flutter **3.47.4**, Dart **3.13.3** and Node.js **26.5.0**.
Install those tools on your PATH. From the repository root:

```powershell
cd frontend
flutter pub get --enforce-lockfile
flutter build web --release --base-href / --no-web-resources-cdn --no-pub
node tool/prepare-release.cjs disconnected
node tool/serve.cjs
```

Open http://127.0.0.1:4173/ and stop the preview with Ctrl+C. This disconnected
demo needs no provider account, backend, email or credentials. It contains only
fictional data and cannot sign in.

For local authentication and persisted team data, use the
[backend setup](backend/README.md) and [local authentication guide](docs/AUTH.md).
They use Docker-backed Supabase and captured local mail. Database reset commands
erase the local database; use them only for disposable development data.

## Configuration and deployment

The [frontend production template](frontend/.env.production.json.example) contains
placeholders for public browser configuration. Copy it to the ignored
`frontend/.env.production.json` and supply your selected project's public values.
The [backend production checklist](backend/.env.production.example) documents
server settings; provider keys and signing secrets belong in secret stores.
Never place service-role or email-provider secrets in frontend configuration.

Production origin and sender-domain checks are intentionally fixed to this
deployment. This repository is a showcase, not a configurable self-hosting
template: another deployment needs coordinated source/configuration changes and
validation. Keep exact-origin checks, CAPTCHA and server permissions intact.
See [release tooling](docs/RELEASE.md) for builds, integrity checks and recovery.
To add a first team and admin through the Supabase website, follow
the [SQL Editor script](backend/operator/create-team-admin.sql); no migration is required.
For an intentional fresh start with one admin and team, see the
[operator reset script](backend/operator/reset-project.sql). It previews first and requires an
explicit destructive apply; ordinary app deletion remains recoverable.

## Checks and documentation

- [Frontend](frontend/README.md): preview, analysis and tests.
- [Backend](backend/README.md): local database setup and authorization tests.
- [Product](docs/PRODUCT.md) and [architecture](docs/ARCHITECTURE.md): behavior and design.
- [Security](docs/SECURITY.md): access controls, abuse limits and known boundaries.
- [Onboarding](docs/ONBOARDING.md), [queue](docs/QUEUE.md), [activity](docs/ACTIVITY.md),
  [lifecycle](docs/LIFECYCLE.md) and [refresh](docs/REFRESH.md): feature contracts.
- [Backlog](docs/NEXT.md): implementation checkpoints and remaining pilot work.

Deployment receipts, provider/account observations and the publication review are
local operator records excluded from future Git snapshots. Public guides remain
in `docs/`; historical checkpoints describe the evidence collected at that time.

## Known limitations

The multi-day pilot is incomplete. Email delivery can reach Junk or hit provider
rate limits. The current pilot uses fictional enterprise hosts and disposable
data; hosted disaster recovery and real enterprise navigation are not established.
The live UI still has some fallback-font issues. The preview-label and wording
corrections are implemented locally and await a separate deployment.
Free-tier service limits may affect availability.

## License

[MIT](LICENSE), copyright 2026 Pedro Costa.
