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
project docs, especially STATUS.md, NEXT.md and QUEUE.md. Implement only
P08: sprint/priority ordering and admin reordering. P06/P07 are verified locally, not deployed. P05's
hosted trial admission remains revoked; preserve that state.
Keep credentials in provider/secret storage, exact callbacks, explicit confirmation,
disabled signup, server-side membership and email budgets. Preserve confirmed
Low/Medium/High/Critical priorities and private enterprise host configuration.
Verify P08, update the docs and stop for review. Do not start P09 or publish the app.
```

## Prompt for any later item

```text
Read AGENTS.md and the project docs. Implement only backlog item <ID>.
Check its dependencies and identify any material unanswered question.
Complete that item's deliverables and relevant verification, update the
durable docs, and stop at its review boundary. Preserve the confirmed
requirements: Flutter Web, invited-email magic links, manual enterprise
links, Namecheap DNS, GitHub Pages, and https://reviews.pedro-costa.dev/.
Do not execute the rest of the backlog automatically.
```

## End-of-item record

Update STATUS with the completed feature, evidence, and limitations; mark only the finished item complete in NEXT and identify the next ready item. If the design changed, update PRODUCT/ARCHITECTURE/DECISIONS and COSTS where relevant.

The final reply should name the completed item, give the useful result/link, summarize checks actually run, state any remaining blocker, and identify the next item. Do not claim a deployed service, successful email, passing test, or user-reviewed pilot without evidence.

## Current handoff

P00-P04A are complete locally; P05 is complete for the controlled hosted trial.
P07 is complete locally and ready for entry/ownership review; P08 is next when selected.
See [QUEUE](QUEUE.md) for the entry contract, private hosts, preview and limitations.
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
loopback root but use distinct explicit modes. Production publication at
`https://reviews.pedro-costa.dev/` remains P12/P13. The signed-in queue now persists
entries locally; demo routes remain fictional. Sorting/reorder, comments/reviews
and archive remain later items. The owner confirmed email visibility to active
teammates, title/owner-admin entry edits and Low/Medium/High/Critical priorities.

P07 changes are uncommitted. No commit, push or app publication was performed
during P07. Inspect Git for earlier history rather than assuming another
checkout or conversation has synchronized it.
