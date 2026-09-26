# P10 archive, recovery and retention

Updated: 2026-09-26. Local implementation only. No hosted migration or publication.
P09 is the completed dependency. See `STATUS.md` (local operator notes) for verification evidence.

## Confirmed policy

The owner confirmed on 2026-09-26:

- Active submitters or team admins can archive and restore an entry.
- Only active team admins can list and recover deleted entries.
- Retain archives, deleted records and minimal audit metadata with no automatic
  expiry or permanent purge. This supersedes the proposed 30-day recovery and
  90-day audit defaults. There is no recovery deadline in P10.

Archive is manually maintained history, separate from deletion. Reasons are
Merged, Closed, No longer needed, or Other; these are user reports, never a claim
that GitHub verified the state. Reason, actor and timestamp appear in the archive.
No integration, external posting or provider status fetch occurs.

Archive preserves comments and current local signals. Entry content and activity
are read-only while archived. Authorized users can restore or soft-delete the
entry. Soft deletion hides the parent and children through existing RLS, including
from admins' normal table reads. The separate admin recovery list returns entry
metadata only; activity becomes readable again after recovery.

Recovery returns to the previous active or archived state. It preserves archive
reason/actor/time for archived entries and never revives individually deleted
comments. Recovering an active entry or restoring an archive appends it to the
end of its existing sprint/priority group. Retained signals may be outdated;
P09's no-self-review and PR-link reset rules remain unchanged.

## Database contract

OPS01 adds an explicitly invoked [operator workspace reset](../backend/operator/reset-project.sql) as an
exception to retained application data: it removes all teams/history and other
Auth accounts, then creates one team/admin. Ordinary lifecycle RPCs and retention
remain unchanged; there is no client purge or scheduled cleanup.

The eighth migration exposes four new authenticated RPCs and extends the existing
`delete_entry` wrapper to archived entries. No direct table write grants change.

| RPC | Contract |
| --- | --- |
| `lifecycle_snapshot(p_team_id,p_deleted=false,p_before_time=null,p_before_id=null)` | Live members read archives; live admins alone read deleted records. Returns up to 25 entries, `has_more` and `next_cursor` |
| `archive_entry(p_team_id,p_entry_id,p_expected_version,p_reason)` | Active submitter/admin, active non-deleted entry, enumerated reason |
| `restore_entry(p_team_id,p_entry_id,p_expected_version)` | Active submitter/admin, archived non-deleted entry, append to active group |
| `recover_entry(p_team_id,p_entry_id,p_expected_version)` | Active team admin, deleted entry, preserve prior state |
| `delete_entry(p_team_id,p_entry_id,p_expected_version)` | Active submitter/admin, active or archived entry, soft deletion only |

`private.entry_lifecycle` derives the actor from `auth.uid()`, reserves the shared
30/minute mutation budget, locks the team then entry, and rechecks live membership
and authority after waiting. It verifies the expected version after authorization.
Successful changes advance entry version and data revision. Only active queue
membership changes advance queue revision; deleted archive recovery stays outside
the active queue. History, revisions and budget reservation commit atomically.

Restore/active recovery revalidate both stored links against current private host
configuration and reject an active duplicate (HTTP 409, `23505`). They never
overwrite, merge or delete the conflicting entry. Stale lifecycle versions return
`PT409`; quota denial returns `PT429`. A new submission or PR-link replacement
matching a retained archive returns HTTP 422, `PT422`, directing the user to
Archive and an authorized restorer. Deleted entries do not block resubmission.

Archive/deleted pages sort newest first by lifecycle timestamp then UUID, using
matching indexes and a two-field exclusive cursor. A 26th row detects the next
page; the UI keeps only the current 25 rows, with Previous/Next and explicit
Refresh returning to page one. Timestamp ties do not skip entries. Concurrent
lifecycle changes can move rows between views; this is not a frozen multi-request
snapshot. Refresh restarts browsing. P11 now uses revision-checked filtered
25-entry pages for every view and visible-tab refresh; see [REFRESH](REFRESH.md).
The original lifecycle cursor RPC remains compatible.

Private audit events retain team, actor, action, target, time and minimal metadata
(version, previous/result state, archive reason), without title, URL or comment
copies. Archive metadata clears from the entry on restore, but its audit event
remains. Audit access stays operator-only; P10 adds no audit browser or export.
No API role can execute the private mutation/trigger helpers.

## Recovery and future purge boundary

Use Deleted entries as an active team admin, inspect the previous state and
confirm Recover entry. If an active duplicate exists, inspect that current entry
first; recovery remains blocked until the conflict is deliberately resolved.
If allowed hosts changed, ask the operator to review private configuration.
Do not broaden hosts merely to bypass validation. Network ambiguity requires
refresh and inspection before a deliberate retry; there is no automatic retry.

Soft-delete recovery is not backup recovery: it cannot repair database loss or
operator hard deletion. Restricted backups/exports, Auth/config/secret recovery
and a tested disaster restore remain P12 before pilot. No exports belong in this
repository. Monitor storage using existing `COSTS.md` (local operator notes) thresholds; retention
does not authorize a paid upgrade. A future purge needs a separately selected
item, explicit retention/cutoff and recovery policy, audit treatment, restricted
backup/restore evidence, a reviewable dry run, and explicit destructive approval.
P10 contains no purge SQL/RPC/job and changes no email-control retention or budgets.

## Local verification and preview

From `backend/`, with the local Docker engine available:

```powershell
npm start
npm run reset
npm test
npm run test:queue
npm run test:ordering
npm run test:activity
npm run test:lifecycle
npm run lint
node node_modules/supabase/dist/supabase.js db advisors --local --type security --level info --fail-on warn
```

Reset destroys only this checkout's local fictional database and applies nine
migrations without fixtures/hosts. Test runners refuse linked/remote targets.
Start `npm run functions` separately, then prepare the local provider preview:

```powershell
node tool/prepare-onboarding-preview.cjs
node tool/prepare-queue-preview.cjs
```

Build/serve from `frontend/`:

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.local.json
node tool/prepare-release.cjs local
node tool/serve.cjs
```

Use the existing [AUTH](AUTH.md) flow at `http://127.0.0.1:4173/` with fictional
`p06-preview@example.test`, local captured mail, a fresh callback document and
explicit Continue. Complete the fictional profile. Then from `backend/`:

```powershell
node tool/prepare-lifecycle-preview.cjs
```

This local-only helper adds one active entry with plain-text history/signal,
27 archived entries and an old deleted entry dated 2020 to demonstrate retention.
The provider identity remains real local Auth; no fake login enters the app.
Refresh Atlas, archive/restore the active example, browse two archive pages,
recover the deleted example, and check Orbit's member-only controls. Inspect
desktop and the 390 × 844 preview frame in both themes, keyboard confirmation and
Escape cancellation. After QA sign out, rebuild without environment defines,
stop preview/functions and run `npm run stop` to preserve local fictional data.

## Sources and review boundary

Official references checked 2026-09-26:
[database functions](https://supabase.com/docs/guides/database/functions),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[changelog](https://supabase.com/changelog), and
[Postgres minor-release changes](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes).
The reported extension/custom-operator changes require no P10 application SQL
change; P10 introduces none of those features. Dependencies/tooling remain pinned.
Provider pricing, deployment, email and billing assumptions are unchanged.

Stop for P10 review. P11 is next only when selected. Hosted P06–P10 rollout,
real company hosts, Inbox placement, final HTTPS callback and publishing remain
outstanding. P05 admission remains revoked; no hosted service was touched.
