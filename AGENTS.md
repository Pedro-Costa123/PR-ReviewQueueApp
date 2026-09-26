# Working in this repository

## Read before changing code

Read `README.md`, `docs/NEXT.md`, `docs/PRODUCT.md`, and `docs/ARCHITECTURE.md`. Read `docs/SECURITY.md` for access/data changes. When present, also read the local operator records `docs/STATUS.md` and `docs/DECISIONS.md`, plus `docs/COSTS.md` for service or deployment changes.

Operator records and the publication review are intentionally ignored and absent from fresh clones. Preserve them when present; do not force-add them. Public documentation must not link to these missing local files. A fresh clone uses the public guides and the actual source as its baseline.

These files are the shared project memory. Inspect the actual repository too: planned features are not implemented features. A conversation does not automatically update repository files or synchronize another checkout.

## Work in small steps

The owner explicitly requested research and a plan first, followed by incremental implementation.

1. Identify the requested backlog ID and its dependencies. If the owner says only "continue", use the next ready item in `docs/NEXT.md`.
2. Briefly state the selected item's scope and acceptance criteria.
3. Complete that item and the work necessary to verify it. Do not execute subsequent items automatically.
4. Ask only for missing information that materially changes the item. Continue independent work when possible. Do not treat unanswered questions as approval of proposed decisions.
5. Update the local `docs/STATUS.md` (create it if absent) and public `docs/NEXT.md`; update other docs when behavior or a decision changes. Keep deployment/account receipts in ignored local records.
6. Report the result, verification, remaining limitations, and the next item. Stop at the selected item's review boundary.

An explicit later instruction from the owner can change this workflow. Do not repeatedly request permission for already authorized work. Do not create subagents unless the owner asks for them.

## Implementation boundaries

- Flutter Web belongs in `frontend/`. Backend code and database migrations belong in `backend/`.
- Keep scope aligned with `PRODUCT.md`. Proposed defaults must remain distinguishable from confirmed requirements.
- Keep dependencies small; pin application lockfiles. Avoid scaffolding unused platforms or services.
- Enforce identity, team membership, and ownership on the server. Hiding buttons is not authorization.
- Never commit credentials, tokens, real company links, personal data, database exports, or private fixtures. Use fictional examples.
- A local fake identity must be impossible to enable in a production build/deployment.
- Do not add paid services, automatic plan upgrades, public signups, integrations, or AI API calls as incidental conveniences.
- Research current official pricing and relevant limits before changing providers, authentication, deployment, or billing assumptions. Record the date and source in local `docs/COSTS.md` (create it if absent); put any necessary public setup assumptions in the relevant public guide.
- Preserve unrelated work and the existing license. Do not push or deploy unless the current task authorizes it.

## Verification and handoff

Use checks appropriate to the selected item. Access-control changes require meaningful denial tests for unauthenticated requests, other teams, revoked members, and forged ownership. Ordering changes require concurrency checks. UI changes require browser inspection and keyboard checks in addition to relevant Flutter checks.

Until the app is scaffolded, do not claim builds or tests passed. Documentation-only changes need consistency, relative-link, and whitespace checks, not invented application tests.

At the end of each item, record files/features completed, commands/checks actually run and their results, unresolved questions, and the next ready item. Keep durable facts in repository docs instead of only in the final chat reply.
