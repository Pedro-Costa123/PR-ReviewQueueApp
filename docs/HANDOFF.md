# Planning and implementation handoff

The repository documents are the shared source of context. A planning conversation handles requirements/research/design; an implementation task inspects the code, makes the selected changes, and verifies them. Both update these files.

## Which file owns which information?

| Information | File |
| --- | --- |
| What users need and how the product behaves | PRODUCT.md |
| Technical structure and security boundaries | ARCHITECTURE.md, SECURITY.md |
| Important choices and reasons | DECISIONS.md |
| Price facts, estimates, and budget assumptions | COSTS.md |
| What actually exists and what has passed | STATUS.md |
| Work order, acceptance criteria, and where to stop | NEXT.md |

`AGENTS.md` instructs Codex to read this context and work incrementally. It does not synchronize repositories. Other checkouts need the corresponding files/commit/branch, and any conversation without repository access must be given the relevant document contents. [Official AGENTS.md guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

## Prompt for the next item when selected

```text
Work in the existing PR-ReviewQueueApp repository. Read AGENTS.md and the
project docs, especially STATUS.md, NEXT.md, RELEASE.md, HOSTING.md, COSTS.md
and SECURITY.md. After reviewing P12, implement only P13: deployment and the
small pilot, following the release gates. Recheck the unreserved
pr-review-queue.pages.dev name; stop if allocation differs. Keep manual dashboard
Direct Upload, magic links and the verified auth.pedro-costa.dev sender.
Complete the private backup/config recovery checkpoint before real-data admission.
Apply only reviewed missing migrations including P12 trial-route retirement.
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
P11A/P12 are prepared locally; stop for P12 review. P13 is next only when explicitly selected.
Exact planned host: `pr-review-queue.pages.dev`, available at the dashboard check,
unreserved. Local exact-origin production guards/config examples and dashboard
upload preflight are in place; no project, upload or hosted setting changed.
See [REFRESH](REFRESH.md) for polling, filters, pages, accessibility and limitations.
See [QUEUE](QUEUE.md) for entry/ordering contracts, private hosts, preview and limitations.
See [ACTIVITY](ACTIVITY.md) for comments/reviews, contracts and review boundary.
See [LIFECYCLE](LIFECYCLE.md) for archive, admin recovery and confirmed no-purge retention.
See [ONBOARDING](ONBOARDING.md) for implementation, local evidence and limits, and
[HOSTED_AUTH](HOSTED_AUTH.md) for provider state, acceptance evidence and limits.
Three requested messages arrived in Junk; recipient SPF/DMARC passed on the third.
First and confirmed-user login, reload/sign-out, link expiry/replay, CAPTCHA reuse
denial, passive scanner rendering and failure recovery passed. The sending trial
is closed: admission revoked, zero sessions/memberships, further mail denied.
Inbox placement remains a release follow-up; do not send more mail merely to chase
placement or assume the admission is still active. The final artifact is the
disconnected demo; rebuild explicit trial configuration only when needed.

[AUTH](AUTH.md) retains the local runbook. Hosted/local builds share the exact
loopback root but use distinct explicit modes. The prepared production mode uses
only the exact Pages root; activation remains P13 after P12 checks and removal of
the temporary database trial route. The signed-in queue now persists
and orders entries locally, with comments/reviews and archive/recovery; demo routes remain fictional.
The owner confirmed no self-review, email visibility to active
teammates, title/owner-admin entry edits and Low/Medium/High/Critical priorities.

P12 began with a clean worktree at `e2e3761`. P12 changes are uncommitted.
No commit, push or app publication was performed during P12.
Inspect Git for earlier history rather than assuming another
checkout or conversation has synchronized it.
