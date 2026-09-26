# Planning and implementation handoff

The public guides and any available local operator records provide project context.
A planning conversation handles requirements/research/design; an implementation
task inspects the code, makes selected changes and verifies them. Deployment,
account and publication-review records are intentionally ignored and absent from
fresh clones. Preserve them locally when present; use the public README, backlog,
product, architecture and security guides when they are unavailable.

## Which file owns which information?

| Information | File |
| --- | --- |
| What users need and how the product behaves | PRODUCT.md |
| Technical structure and security boundaries | ARCHITECTURE.md, SECURITY.md |
| Operator choices and reasons | DECISIONS.md (local-only) |
| Provider observations and cost research | COSTS.md (local-only) |
| Detailed verification receipts | STATUS.md (local-only) |
| Work order, acceptance criteria, and where to stop | NEXT.md |

`AGENTS.md` instructs Codex to read this context and work incrementally. It does not synchronize repositories. Other checkouts need the corresponding files/commit/branch, and any conversation without repository access must be given the relevant document contents. [Official AGENTS.md guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

## Operator prompt for continuing P13 (requires local records)

```text
Work in the existing PR-ReviewQueueApp repository. Read AGENTS.md and the
project docs, especially STATUS.md, NEXT.md, RELEASE.md, HOSTING.md, COSTS.md
and SECURITY.md. After reviewing P12, implement only P13: deployment and the
small pilot, following the release gates and current PILOT.md evidence. The exact
pr-review-queue.pages.dev name is allocated and deployed. Keep manual dashboard
Direct Upload, magic links and the verified auth.pedro-costa.dev sender.
Respect D37's explicit disposable-pilot data-loss waiver and fictional hosts;
complete the private backup/config recovery checkpoint before durable company data.
Reviewed migrations through P12 are already applied; do not replay them.
Keep P05 admission revoked, provider secrets private, exact callbacks, explicit
confirmation, disabled signup, server membership and email budgets.
Preserve private enterprise hosts, Low/Medium/High/Critical priorities, no
self-review, plain-text local comments/signals, owner/admin archive/restore,
admin-only deleted recovery, and retained records/audit without purge.
Do not make the repository public, change DNS, add paid services or integrations.
Obtain the private enterprise-host and operator/team inputs when needed.
Verify live HTTPS, origin isolation, CAPTCHA/login, quotas and delivery; do not
claim a multi-day pilot in one run. Update docs and stop at P13 review.
```

## Prompt for any later item

```text
Read AGENTS.md and the project docs. Implement only backlog item <ID>.
Check its dependencies and identify any material unanswered question.
Complete that item's deliverables and relevant verification, update the
durable docs, and stop at its review boundary. Preserve the confirmed
requirements: Flutter Web, invited-email magic links, manual enterprise
links, the existing verified email sender/Namecheap email DNS, and Cloudflare
Pages Free at an available pages.dev address. See HOSTING.md and D35.
Do not execute the rest of the backlog automatically.
```

## End-of-item record

Update STATUS with the completed feature, evidence, and limitations; mark only the finished item complete in NEXT and identify the next ready item. If the design changed, update PRODUCT/ARCHITECTURE/DECISIONS and COSTS where relevant.

The final reply should name the completed item, give the useful result/link, summarize checks actually run, state any remaining blocker, and identify the next item. Do not claim a deployed service, successful email, passing test, or user-reviewed pilot without evidence.

## Current handoff

P00-P04A are complete locally; P05 is complete for the controlled hosted trial.
P11 is implemented locally with automated and browser checks; see STATUS for evidence.
P11A/P12 were reviewed and P13 is selected. The exact `pr-review-queue.pages.dev`
host is live. `PILOT.md` (local operator notes) records deployment/artifact, current provider state,
observed gates, quota-blocked delivery and remaining real-use feedback. Stop at
P13 review; do not mark the multi-day pilot complete from deployment checks.
See [REFRESH](REFRESH.md) for polling, filters, pages, accessibility and limitations.
See [QUEUE](QUEUE.md) for entry/ordering contracts, private hosts, preview and limitations.
See [ACTIVITY](ACTIVITY.md) for comments/reviews, contracts and review boundary.
See [LIFECYCLE](LIFECYCLE.md) for archive, admin recovery and confirmed no-purge retention.
See [ONBOARDING](ONBOARDING.md) for implementation, local evidence and limits, and
`HOSTED_AUTH.md` (local operator notes) for provider state, acceptance evidence and limits.
Historically, three P05 messages arrived in Junk; recipient SPF/DMARC passed on the third.
First and confirmed-user login, reload/sign-out, link expiry/replay, CAPTCHA reuse
denial, passive scanner rendering and failure recovery passed in P05. That trial
closed with admission revoked and its then-current sessions/memberships removed.
P13 subsequently bootstrapped the verified initial admin and admitted User1
through an invitation; this does not reopen P05. Production is now the deployed
artifact; the disconnected build is a fallback. Do not rebuild or reopen the
retired trial route. Admin Inbox and User1 Junk placement are separate P13
observations; do not send mail merely to chase placement.

[AUTH](AUTH.md) retains the local runbook. Hosted/local builds share the exact
loopback root but use distinct explicit modes. The prepared production mode uses
only the exact Pages root and is active after P12 checks and retirement of the
temporary database trial route. The signed-in hosted queue now persists
and orders entries, with comments/reviews and archive/recovery; demo routes remain fictional.
The owner confirmed no self-review, email visibility to active
teammates, title/owner-admin entry edits and Low/Medium/High/Critical priorities.

P12 began at `e2e3761`; P13 began with clean committed release inputs at `c24ff7a`.
P13 documentation updates remain in the working tree for review. No push occurred.
Inspect Git for earlier history rather than assuming another
checkout or conversation has synchronized it.
