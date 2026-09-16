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
project docs, especially STATUS.md and NEXT.md. P03 is complete; review
its local backend foundation before proceeding. Implement only P04:
local magic-link integration, guarded email hook with invitation checks,
atomic budgets/idempotency, mocked delivery, and callback/session validation.
Follow P04's acceptance criteria and preserve P03's authorization tests.
Update STATUS.md and NEXT.md with what actually works and the checks run.
Stop after P04 for review. Do not start real email or cloud setup yet.
```

## Prompt for any later item

```text
Read AGENTS.md and the project docs. Implement only backlog item <ID>.
Check its dependencies and identify any material unanswered question.
Complete that item's deliverables and relevant verification, update the
durable docs, and stop at its review boundary. Preserve the confirmed
requirements: Flutter Web, invited-email magic links, manual enterprise
links, Namecheap DNS, GitHub Pages, and the exact URL path. Do not execute
the rest of the backlog automatically.
```

## End-of-item record

Update STATUS with the completed feature, evidence, and limitations; mark only the finished item complete in NEXT and identify the next ready item. If the design changed, update PRODUCT/ARCHITECTURE/DECISIONS and COSTS where relevant.

The final reply should name the completed item, give the useful result/link, summarize checks actually run, state any remaining blocker, and identify the next item. Do not claim a deployed service, successful email, passing test, or user-reviewed pilot without evidence.

## Current handoff

P00-P03 are complete locally. P03 passed clean local resets, 19 SQL-role/Data API/concurrency tests, and SQL lint. The local stack is stopped; startup instructions and the Windows port-binding limitation are in the backend README. The frontend remains the P02 demo, whose earlier Flutter/build/browser checks are recorded in STATUS. P04 is next after P03 review and has not started. No working magic-link delivery, hosted setup, or deployment exists. P02/planning are tracked in `39e9d5d`; P03 changes are uncommitted and were not pushed. Review product defaults at the relevant future step instead of re-asking the already answered core questions.
