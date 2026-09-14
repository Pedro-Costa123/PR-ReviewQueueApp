# PR Review Queue

A private team queue that keeps pull requests visible, makes sprint priorities clear, and records review feedback and archived work.

**Current stage: P02 local Flutter shell complete, ready for review.** A runnable demo exists with fictional data and theme/navigation support. There is no backend, working authentication, or deployment. Work proceeds one backlog item at a time.

## Project documentation

| Document | Purpose |
| --- | --- |
| [Product](docs/PRODUCT.md) | Users, requirements, proposed behavior, and unanswered questions |
| [Architecture](docs/ARCHITECTURE.md) | Proposed system, data model, and technical boundaries |
| [Decisions](docs/DECISIONS.md) | Accepted constraints and proposed decisions with reasons |
| [Status](docs/STATUS.md) | What actually exists and what has been verified |
| [Next](docs/NEXT.md) | Ordered, individually reviewable implementation steps |
| [Costs](docs/COSTS.md) | Hosting/authentication comparison, quotas, estimates, and sources |
| [Security](docs/SECURITY.md) | Access rules, abuse controls, and launch checks |
| [Handoff](docs/HANDOFF.md) | How to continue the project across planning and implementation tasks |

## Proposed stack

- Frontend: Flutter Web, with dark mode as the default and an optional light theme.
- Backend: Supabase Postgres, row-level security, transactional database functions, and small TypeScript Edge Functions.
- Authentication: Supabase magic links, restricted to exact work email invitations.
- Email: Resend Free, with server-enforced sending budgets.
- Hosting: GitHub Pages, retaining Namecheap DNS and publishing the app under the existing site's required path.
- Required address: `https://pedro-costa.dev/PR-Review-App-Queue/`.

Flutter Web, magic links, the URL path, Namecheap DNS, GitHub Pages, manual updates, sprint-first ordering, and multiple team membership are confirmed. Supabase + Resend is the researched backend recommendation, ready for staged validation. The estimated additional service cost is **€0/month within free-plan limits**; existing domain renewal is separate. Read [Costs](docs/COSTS.md) for limits and [Security](docs/SECURITY.md) for the shared-origin tradeoff.

## Repository layout

```text
frontend/          Flutter Web shell, fictional fixtures, tests, local preview
backend/           API and database migrations (currently a planning README)
docs/              Persistent product and implementation context
AGENTS.md          Instructions for agents working in this repository
.gitignore         Generated files and local secrets
LICENSE            Existing MIT license
```

## Start the next step

Read [Status](docs/STATUS.md), then [Next](docs/NEXT.md). Review the local shell using the [verified frontend commands](frontend/README.md). The next implementation item is **P03: local Supabase schema and team authorization**. The [handoff instructions](docs/HANDOFF.md) include a prompt for continuing in Codex.

Do not run the entire backlog in one task. Complete the selected item, verify its acceptance criteria, update the docs, and stop at its review boundary.

## Local tools

On the initial machine, Flutter is at `C:\Users\pedro\flutter` and is on PowerShell's PATH. Git, Node.js, npm, and Docker are available. Exact observed versions are in [Status](docs/STATUS.md).

The proposed stack needs no Java server or Docker container in production. Docker will be useful for local Supabase development. Project-local backend tools will be selected during P03. Verified local app build/preview commands are in [frontend/README.md](frontend/README.md).

## License

[MIT](LICENSE), copyright 2026 Pedro Costa.
