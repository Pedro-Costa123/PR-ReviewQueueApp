# P07 queue entries

Updated: 2026-09-21. Local implementation only; no hosted migration or publication.
P06 is the completed local dependency. See [STATUS](STATUS.md) for final evidence.

## Confirmed scope

The owner confirmed a required title of 1–160 characters and submitter/team-admin
editing. The owner's later priority correction supersedes High/Normal/Low:
**Low, Medium, High, Critical**, with Medium replacing Normal as the default.
Deletion hides the entry with actor/time/version and a minimal audit event.
Recovery, retention and purge remain P10. Real enterprise hostnames will be
configured privately; local tests use fictional exact hosts.

The signed-in root workspace now lists, adds, edits and deletes real database
entries for the selected team. Demo routes retain public fictional content.
Submitter names open the existing teammate profile dialog. Explicit refresh and
successful mutations reload the list. Failed refresh clears the old rows;
switching teams or signing out discards the displayed queue. The first 100 active
entries are shown in stable creation/ID order. P08 owns sprint/priority sorting
and admin reorder controls; P11 owns pagination/background refresh.

## Database contract

The fifth migration adds four authenticated RPCs. No direct client table writes
are granted, including to owners/admins. `private.mutate_entry` is not callable
by any API role. Every public mutation delegates to this guarded transaction.

| RPC | Contract |
| --- | --- |
| `queue_link_hosts(p_team_id)` | Return this team's PR/Jira exact-host lists only to its active members |
| `create_entry(p_team_id,p_title,p_pr_url,p_jira_url,p_sprint_goal,p_priority)` | Derive submitter from `auth.uid()`, validate and return saved row |
| `update_entry(p_team_id,p_entry_id,p_expected_version, …same fields…)` | Require active submitter or team admin; preserve resource identity |
| `delete_entry(p_team_id,p_entry_id,p_expected_version)` | Same ownership/version checks; hide active entry and preserve history |

Mutations acquire the per-user budget, then the team lock, then the entry lock.
Membership/role checks run again after locking. Entry/team IDs must match even
for a user belonging to both teams. Only active, non-deleted entries can change.
Versions advance on edits/deletion. Stale saves/deletions return HTTP 409/code
`PT409`, with `current_version` only after authorization. The UI retains a stale
draft, disables blind resubmission and asks the user to refresh/review the latest
entry. There is no automatic overwrite or network retry.

Canonical PR duplicates use the existing partial unique index: one non-deleted
active URL per team. HTTP 409/code `23505` is a duplicate; another team may submit
the same URL. Deleted entries release the active duplicate key. Existing RLS
hides deleted parents and their comments/reviews. Audit events contain action,
actor, target and version, not title/URL copies.

All successful mutations advance data revision. Creation, deletion and group
changes also advance queue revision; creation/group changes append a position
under the team lock. This preserves schema consistency for P08, without exposing
a reorder API or implementing its UI. The migration maps old `normal` values to
`medium` and advances affected versions/team revisions so open stale edits fail.

The private queue limiter permits 30 successful mutations per identity per
one-minute fixed window across teams. Reservations and writes commit together;
failed transactions roll back the reservation. Concurrent requests cannot exceed
the cap. HTTP 429/code `PT429` tells the user to wait. This is a mutation budget,
not a claim of network-level DoS protection or a rolling-window read limit.

## Enterprise link policy

`private.enterprise_hosts(team_id,kind,hostname)` is operator-only, RLS-enabled,
and has no API table grants. Migrations seed **no hosts**. An unconfigured team
fails closed; the UI explains the missing operator configuration. Active members
learn only their team's allowlist through the guarded RPC.

Validation runs in Dart and Postgres using the same narrow resource grammar:

- HTTPS, exact lowercase DNS host match; optional default `:443` is normalized.
  Reject userinfo, other ports, backslashes, whitespace/control characters,
  encoded controls/backslashes, trailing-dot or suffix-lookalike hosts,
  unconfigured hosts, and percent-encoded or unrelated resource paths.
- PR: `/owner/repository/pull/123`, optionally `/files`, `/commits`, `/checks`
  and a trailing slash. Owner/repository case is normalized to lowercase.
- Jira: `/browse/PROJECT-123`, with optional context segments such as
  `/jira/browse/PROJECT-123`. Issue keys are uppercased; context case is preserved.
- Query/fragment suffixes are accepted only by the bounded safe-character
  grammar, then discarded. Store/open the canonical resource URL. The form
  explains this normalization; it does not preserve view-specific anchors.

No DNS lookup, metadata fetch, GitHub/Jira SDK, credential, tunnel or integration
is added. The browser opens links synchronously from a user gesture with
`target=_blank`, `rel=noopener noreferrer`, and `referrerPolicy=no-referrer`.
The existing page-wide no-referrer policy remains. Stored URLs are revalidated
against the loaded allowlist before enabling navigation.

Before real use, the operator configures actual hostnames in private SQL, never
in source, migrations, static build assets or committed fixtures. Use one
transaction, locking the selected `public.teams` row `FOR UPDATE` before changing
its allowlist, so configuration updates serialize with entry mutations. Supply
the existing team UUID and exact PR/Jira hosts as parameters to the SQL client;
insert rows with `kind='pr'` and `kind='jira'`. Do not expose a client host-setting
RPC. This item neither collects nor configures real company hosts.

## Local verification and preview

From `backend/`, with the local Docker engine running:

```powershell
npm start
npm run reset
npm test
npm run test:queue
npm run lint
```

Reset is destructive to this project's local test database. It applies all five
migrations without seeding hosts/users. `npm test` requires a clean database and
loads fictional fixtures. Queue tests create isolated identities/teams, refuse
linked/remote targets, and never send email. Run the security advisor with:

```powershell
node node_modules/supabase/dist/supabase.js db advisors --local --type security --level info --fail-on warn
```

For the real local Auth/browser preview, start `npm run functions` in a separate
backend terminal, then run:

```powershell
node tool/prepare-onboarding-preview.cjs
node tool/prepare-queue-preview.cjs
```

The first helper writes ignored `frontend/.env.local.json` and prepares the
existing fictional two-team invitation flow. The second configures only
`git.example.test` and `jira.example.test` for the two fixture teams. Neither is
an application import, migration or deployable seed. Old P03 fixture links can
remain disabled because they predate the stricter resource-path grammar; add a
new entry using the documented paths to verify P07 links.

From `frontend/`:

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.local.json
node tool/serve.cjs
```

Open `http://127.0.0.1:4173/`, request the preview identity's local link, and open
the captured Mailpit link in a **fresh document** before explicit confirmation.
Complete its fictional profile. Example input: title `Improve fictional search`,
PR `https://git.example.test/platform/search/pull/701`, Jira
`https://jira.example.test/browse/DEMO-701`. Both domains intentionally do not
resolve; QA verifies the new tab's exact destination, not enterprise availability.
The preview identity is Atlas admin and Orbit member. The 390 × 844 QA frame is
`http://127.0.0.1:4173/__preview/narrow`.

After QA sign out, rebuild without environment defines for the disconnected
artifact, stop the preview/functions processes and `npm run stop`. The existing
Docker all-interface binding limitation remains; see [AUTH](AUTH.md).

## Review boundary and sources

No P08 reorder controls, P09 comments/review mutations, P10 archive/recovery/purge,
P11 background refresh, hosted migration, DNS change, mail-provider change,
dependency, paid service, commit, push or publication is included. Hosted P06/P07
rollout, actual company hostname configuration, Inbox placement and the final
HTTPS callback remain outstanding before live use. No material unanswered
question blocks the agreed local P07 scope.

Official references rechecked 2026-09-21:
[database functions](https://supabase.com/docs/guides/database/functions),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), and
[Supabase changelog](https://supabase.com/changelog).
The changelog's recent breaking changes concern unrelated management logs,
extension version pinning, self-hosted gateway and Realtime configuration; P07
uses the already pinned CLI/client and adds no provider or billing assumption.
