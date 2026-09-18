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

## Prompt for the next implementation task

```text
Work in the existing PR-ReviewQueueApp repository. Read AGENTS.md and the
project docs, especially STATUS.md and NEXT.md. P04 is complete locally;
read docs/AUTH.md and review its verified flow. Implement only P04A:
migrate the local preview/build and all auth callback checks from the old
path prefix to /, preparing for https://reviews.pedro-costa.dev/.
Preserve local-only gates, early URL cleanup, explicit confirmation,
signup restrictions and hook budgets. Verify the root-path flow with
fictional identities and local captured mail; update the runbook only
after testing the replacement commands.
Update STATUS.md and NEXT.md with what actually works and the checks run.
Stop after P04A for review. Do not begin P05, configure hosted services,
change DNS/Pages/repository visibility, send real email or deploy the app.
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

P00-P04 are complete locally. See [STATUS](STATUS.md) for
verification and [AUTH](AUTH.md) for local setup, the first-login resend correction,
sessionStorage/cross-tab behavior, budget/idempotency rules and CAPTCHA design.
The owner selected `https://reviews.pedro-costa.dev/` on 2026-09-18. P04A is next:
a local root-path/callback migration before P05's hosted trial. The current
runbook still uses the implemented legacy local prefix; the subdomain change
is documentation only. No real mail, cloud configuration, DNS/Pages settings,
repository visibility/name changes or deployment occurred.

P03 is committed as c2b44c8 and P04 as 1ff6c13. This documentation update began
with a clean worktree and is uncommitted; no fresh remote check was made.
P05 requires owner-selected hosted setup/provider access. Queue behavior and
invitation claiming remain later work.
