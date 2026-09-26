# PR Review Queue

A private team queue that keeps pull requests visible, makes sprint priorities clear, and records review feedback and archived work.

**Current stage: P11A Cloudflare Pages hosting preparation complete locally.**
P05's controlled hosted trial is complete. Inbox placement remains a release
follow-up; stop for P11A review. P12 is next only when selected.
P06-P11 have not been deployed to the hosted
project. The signed-in queue persists entries locally; demo routes remain fictional. No
production app is published. Work proceeds one backlog item at a time.

## Project documentation

| Document | Purpose |
| --- | --- |
| [Product](docs/PRODUCT.md) | Users, requirements, proposed behavior, and unanswered questions |
| [Architecture](docs/ARCHITECTURE.md) | Proposed system, data model, and technical boundaries |
| [Decisions](docs/DECISIONS.md) | Accepted constraints and proposed decisions with reasons |
| [Status](docs/STATUS.md) | What actually exists and what has been verified |
| [Next](docs/NEXT.md) | Ordered, individually reviewable implementation steps |
| [Costs](docs/COSTS.md) | Hosting/authentication comparison, quotas, estimates, and sources |
| [Hosting plan](docs/HOSTING.md) | Cloudflare Pages preparation before P12 and Namecheap records to retain |
| [Security](docs/SECURITY.md) | Access rules, abuse controls, and launch checks |
| [Local authentication](docs/AUTH.md) | P04 runbook, provider corrections, sessions, email guards and CAPTCHA design |
| [Hosted authentication trial](docs/HOSTED_AUTH.md) | P05 configuration, provider state, evidence and limitations |
| [Onboarding](docs/ONBOARDING.md) | P06 invitation/profile workflow, local verification and recovery |
| [Queue entries](docs/QUEUE.md) | P07/P08 entry/ordering contracts, private enterprise hosts and local verification |
| [Comments and review signals](docs/ACTIVITY.md) | P09 permissions, counts, PR-link resets and verification |
| [Archive and lifecycle](docs/LIFECYCLE.md) | P10 archive/restore, admin recovery, retention policy and verification |
| [Refresh and usability](docs/REFRESH.md) | P11 revision checks, filters, pages, error recovery and accessibility |
| [Handoff](docs/HANDOFF.md) | How to continue the project across planning and implementation tasks |

## Proposed stack

- Frontend: Flutter Web, with dark mode as the default and an optional light theme.
- Backend: Supabase Postgres, row-level security, transactional database functions, and small TypeScript Edge Functions.
- Authentication: Supabase magic links, restricted to exact work email invitations.
- Email: Resend Free, with server-enforced sending budgets.
- Hosting: Cloudflare Pages Free, selected 2026-09-26; P11A preparation is local, pending review before P12.
- Future production address: `https://pr-review-queue.pages.dev/`; availability checked, unreserved and not deployed.

Flutter Web, magic links, Cloudflare Pages, manual updates, sprint-first ordering and multiple team membership are confirmed. The owner selected a free provider web address while retaining the verified `auth.pedro-costa.dev` email sender and its Namecheap DNS. Supabase + Resend remains the backend recommendation. Estimated additional service cost is **€0/month within free-plan limits**; existing sender-domain renewal remains separate. Read [Hosting](docs/HOSTING.md), [Costs](docs/COSTS.md) and [Security](docs/SECURITY.md). P11A changes local configuration/code and runbooks only.

P04A verified local root callbacks. P05 adds a separately gated hosted trial at
the same loopback root; the owner verified the dedicated email-sending domain at
Namecheap. Pages, the production app hostname and repository visibility remain unchanged.

## Repository layout

```text
frontend/          Flutter Web shell, fictional fixtures, tests, local preview
backend/           Local Supabase schema, authorization tests, operator bootstrap
docs/              Persistent product and implementation context
AGENTS.md          Instructions for agents working in this repository
.gitignore         Generated files and local secrets
LICENSE            Existing MIT license
```

## Start the next step

Read [Status](docs/STATUS.md), then [Next](docs/NEXT.md). Review the completed local
**P11A hosting preparation** using [its runbook](docs/HOSTING.md).
P12 release preparation is next only when separately selected.
The [local authentication runbook](docs/AUTH.md) and
[frontend demo commands](frontend/README.md) remain available.

Do not run the entire backlog in one task. Complete the selected item, verify its acceptance criteria, update the docs, and stop at its review boundary.

## Local tools

On the initial machine, Flutter is at `C:\Users\pedro\flutter` and is on PowerShell's PATH. Git, Node.js, npm, and Docker are available. Exact observed versions are in [Status](docs/STATUS.md).

The proposed stack needs no Java server or Docker container in production. P03 uses Docker for local Supabase development with CLI 2.117.0 pinned under `backend/`. Setup, tests, and the observed Windows port-binding limitation are in [backend/README.md](backend/README.md). Verified local app build/preview commands are in [frontend/README.md](frontend/README.md).

## License

[MIT](LICENSE), copyright 2026 Pedro Costa.
