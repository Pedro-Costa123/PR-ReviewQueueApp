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
project docs, especially STATUS.md, NEXT.md and HOSTED_AUTH.md. Implement only
P06: admin invitations, teams, and profiles. P05's trial admission is revoked;
preserve that state and implement real invitations instead of extending the trial.
Keep credentials in provider/secret storage, exact callbacks, explicit confirmation,
disabled signup, server-side membership and email budgets. Verify P06, update
the docs and stop for review. Do not start P07 or publish the app.
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

P00-P04A are complete locally; P05 is complete for the controlled hosted trial
and ready for review. P06 is the next ready item, not started. See
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
`https://reviews.pedro-costa.dev/` remains P12/P13. The queue is still fictional;
invitation claiming and all subsequent queue work remain later items.

P03 is committed as c2b44c8, P04 as 1ff6c13 and P04A as 99c68f3. P05 changes
are uncommitted. No push or app publication has been performed.
