# P09 comments and review signals

Updated: 2026-09-26. Local implementation; no hosted migration or publication.
P08 is complete and supplies P09's dependency. The owner confirmed **no self-review**:
submitters, including admins, cannot set either signal on their own entries.
They may still comment. No material P09 product question remains unanswered.

## Behavior

Expand **Comments and reviews** on an entry to load its activity. Comments are
plain text, 1–2,000 Unicode code points after trimming; line breaks and tabs are
allowed. HTML-like input is displayed literally by Flutter Text widgets. There
is no HTML/Markdown parser, link preview, backend URL fetch or external posting.
Authors can edit/delete their own comments; team admins can remove another
author's comment but cannot rewrite it. Entry ownership alone grants no moderation.
Deletion hides the comment with actor/time/version; permanent retention, recovery
and purge policy are confirmed in P10: retain records without purge. Audit events contain identifiers/actions, no text copies.

Each member has one current signal per entry: **Reviewed, looks good** (check),
**Comments left on PR** (X), or unset. Setting replaces the person's current signal;
clearing removes it. Counts, reviewer names and local timestamps appear in the
expanded activity. A former teammate's historical activity remains, labeled
“Former teammate”; profile access continues to use P06's active-teammate rules.
These are local signals, not GitHub approvals, verified PR status or merged state.
They can become outdated when code changes. Changing the canonical PR link clears
all signals atomically; title/Jira/group edits preserve them. Comments are kept.

Activity loads on demand, after a successful mutation and on explicit refresh.
P11 adds 25-comment and 25-reviewer pages, complete counts and revision-based
refresh of open panels; see [REFRESH](REFRESH.md). The legacy 100-row RPC remains
compatible. Comments appear newest first with stable ID ties. Private activity
and drafts are not persisted in browser storage. Automatic queue replacement
waits for comment drafts/saves; access denial clears private rows. Team switches
and sign-out discard the mounted panel. Drafts survive save conflicts.

## Server contract

The seventh migration adds comment versions/deletion actor, five authenticated
RPCs, one private mutation helper and a PR-link-reset trigger. Existing RLS,
immutable authors/composite team keys and denied direct writes remain in force.

| RPC | Contract |
| --- | --- |
| `entry_activity(p_team_id,p_entry_id)` | Stable authorized snapshot: entry version/submitter/state, bounded comments/reviewers, complete counts and caller's signal |
| `add_comment(p_team_id,p_entry_id,p_body)` | Derive author from session; validate plain-text length/control characters |
| `edit_comment(p_team_id,p_entry_id,p_comment_id,p_expected_version,p_body)` | Live author only; require current comment version |
| `delete_comment(p_team_id,p_entry_id,p_comment_id,p_expected_version)` | Live author or team admin; require current comment version; soft delete |
| `set_review(p_team_id,p_entry_id,p_expected_version,p_signal)` | Derive reviewer; validate entry version and no-self-review; null clears own signal |

Every mutation reserves P07's shared 30-successful-mutations/minute identity budget,
locks team then entry, and rechecks live membership/role after waiting. It rejects
foreign/mismatched IDs, missing/deleted/archived parents, impersonation parameters
and unauthorized edits. Entry content versions prevent a stale review from being
attached to a replacement PR. Concurrent same-user signal updates serialize into
one row; the last committed explicit action is current. Concurrent stale comment
edits/deletes conflict instead of silently overwriting. Mutations advance data
revision without invalidating queue revision or entry content versions.

`PT409` reports conflict; `PT429` reports budget exhaustion; `42501` reports lost
authority/unavailable entry. The UI does not automatically retry or optimistically
claim a save. A stale edit retains its draft and blocks resubmission until the user
refreshes/cancels and starts a deliberate new edit. Ambiguous network outcomes ask
the user to refresh/check before retrying. Reads of archived activity are possible
under the existing foundation, but P09 adds no archive/restore workflow.

## Local verification

Use the [queue runbook](QUEUE.md) to start/reset the local stack, load fictional
authorization fixtures and prepare the existing two-team captured-mail preview.
Reset now applies seven migrations. From `backend/`:

```powershell
npm test
npm run test:queue
npm run test:ordering
npm run test:activity
npm run lint
node node_modules/supabase/dist/supabase.js db advisors --local --type security --level info --fail-on warn
```

`npm test` requires the clean reset; the other suites use isolated fictional
identities/teams. The activity suite covers author/admin restrictions, direct API
denials, revoked valid tokens, post-lock revocation/demotion, stale edits, signal
switch/clear/concurrency, body safety/bounds, PR reset, read bounds, parent state
and atomic shared quotas. No real email or enterprise host is involved.

From `frontend/` run analysis, the Flutter tests and the configured root release
build as in QUEUE. Browser QA uses real captured provider login, then comments,
check/X/clear, keyboard interaction, reload and light/dark narrow layouts.
Actual outcomes and tool limitations are recorded in `STATUS.md` (local operator notes).

After the preview identity signs in and claims its teams, run this additional
fictional-data helper from `backend/`, then refresh the Atlas queue:

```powershell
node tool/prepare-activity-preview.cjs
```

It adds an entry owned by that real local preview identity and a fixture teammate's
comment for no-self-review and admin-moderation QA. It refuses linked/remote targets
and requires the existing claimed membership; it never creates an app login bypass.

## Boundary and references

Stop for P09 review. P10 archive/lifecycle is next only when selected, with archive
authority, retention/recovery/audit policy still to settle before permanent purge.
Hosted P06–P09 rollout, real enterprise hosts, Inbox placement and final HTTPS
callback remain release work. No provider, authentication, dependency, hosting,
billing, Namecheap DNS or GitHub Pages assumption changed. Confirmed destination:
`https://reviews.pedro-costa.dev/` at the time of P09. The later D35 hosting
decision supersedes that web destination; see `HOSTING.md` (local operator notes).

Official references checked 2026-09-23:
[database functions](https://supabase.com/docs/guides/database/functions),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), and
[Supabase changelog](https://supabase.com/changelog).
Recent breaking changes concern unrelated management logs, extension version
pinning, self-hosted gateway and Realtime. Existing CLI/client versions remain pinned.
