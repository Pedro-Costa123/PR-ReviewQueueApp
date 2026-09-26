# P11 refresh, filters and accessibility

Updated: 2026-09-26. Local implementation only. P10 is the completed dependency.
P05 hosted trial admission remains revoked. No hosted migration or publication.

## Behavior

The signed-in queue has an expandable Search and filters section. Search is a
case-insensitive literal substring of title, PR URL or Jira URL (up to 160
characters). Combine it with sprint-goal, Low/Medium/High/Critical priority and
submitter filters. Apply filters or Enter starts at page one; Clear filters
removes them. Filtering runs on the server across the selected active/archive/
deleted view, not just the downloaded page. Deleted entries remain admin-only.
Search strings and team data are not persisted in browser storage or URLs.

Each queue page contains at most 25 entries. Activity separately pages comments
and reviewers, 25 each, with complete counts and newest-first deterministic ties.
Previous/Next controls restore keyboard focus. Refresh, view/filter changes and
successful mutations restart queue browsing at page one. Active ordering remains
sprint first, then Critical/High/Medium/Low and saved within-group order. Reorder
controls operate within the displayed unfiltered page; clear filters to reorder.
There is no automatic cross-page drag scrolling or move-across-group override.

Visible tabs check the small team data revision every 60 seconds. Returning after
at least 60 seconds since the previous automatic attempt checks immediately.
Hidden tabs cancel the timer; an already-issued request may finish. No overlapping
automatic checks or queued timer ticks occur. Unchanged revisions download no
queue, host, member or activity snapshot. A changed revision reloads page one,
host configuration and people/roles, then open activity panels. Healthy visible,
idle sessions normally see a saved change within 60 seconds plus request latency.

Last updated is the most recent successful queue snapshot; Last checked includes
successful unchanged revision checks. Times are local. Background refresh keeps
the existing widgets/focus while replacing rows. A comment draft or activity save
defers replacement and shows Updates available; finish/clear the draft, then
refresh. Open confirmation/editor/profile dialogs defer the check. These user
interactions intentionally extend the normal refresh window. Team switching and
sign-out dispose the old queue and timer; late results are ignored.

Connection failures keep existing rows visibly stale and use 120, 240, then
300-second automatic delays, with a 15-second timeout on queue/activity reads.
Session/access errors clear the queue's private rows and pause automatic refresh;
quota errors also pause it. Manual refresh resumes checks, but every request still
requires live server authority. There are no automatic mutation retries. Session
expiry asks for sign-out/sign-in; permission changes ask for Refresh teams.

Existing Material controls now wrap the filter and page controls on narrow
screens. Filters have explicit labels, named groups are headings, status/errors
use live regions, and review signals keep their full text labels. Search submits
with Enter; dialogs retain Escape/explicit confirmation; focus returns to useful
page/move controls. Automated semantic/layout checks include 320px and 200% text
in light/dark themes. Browser checks and practical limits are in [STATUS](STATUS.md).
Queue and comment action rows have 12px separation from the text above. Comment
author, body and action labels align, retaining 48px minimum button targets.
Expanded filters have 16px bottom padding above the divider/status area.
This is not a claim of a complete assistive-technology certification.

## Read contract and consistency

The ninth migration adds authenticated-only stable RPCs with fixed search paths:

| RPC | Contract |
| --- | --- |
| `team_revision(p_team_id)` | Scalar data revision after live membership verification |
| `queue_page(p_team_id,p_view,p_search,p_priority,p_sprint,p_submitter,p_offset,p_revision)` | Up to 25 matching rows, queue/data revisions and `has_more`; deleted view requires live admin |
| `activity_page(p_team_id,p_entry_id,p_comments_offset,p_reviews_offset,p_revision)` | Up to 25 comments/reviewers each, totals, caller's signal and entry/data versions; deleted/foreign parents denied |

All reads authorize before returning revisions or page conflicts. Rows and
revisions share one statement snapshot. Offsets must be multiples of 25 from
0 through 100,000; nonzero offsets require the observed data revision. Any changed
revision returns `PT409` before page data, prompting a restart rather than silent
skips/duplicates during concurrent edits. This deliberately conservative check
also restarts browsing after an unrelated team change. It is not a frozen
multi-request snapshot. Offset cost increases with page depth; this small-team
implementation bounds offsets and responses, not total database work. Revisit
keyset search at larger scale instead of raising limits without measurement.

Existing mutation paths advance data revision, independently of ordering version.
New private triggers cover profile name/username and private host changes too.
Direct table writes and private helper execution remain denied. Old bounded
`queue_snapshot`, `entry_activity` and cursor `lifecycle_snapshot` RPCs remain
compatible for existing clients/tests; the current Flutter queue uses the new
page endpoints. No auth, invitation, email budget, ownership or lifecycle grant
is broadened. P09 plain text/no-self-review and P10 retained history/no-purge hold.

## Local verification

From `backend/`, with Docker running:

```powershell
npm start
npm run reset
npm test
npm run test:queue
npm run test:ordering
npm run test:activity
npm run test:lifecycle
npm run test:refresh
npm run lint
node node_modules/supabase/dist/supabase.js db advisors --local --type security --level info --fail-on warn
```

Reset destroys this checkout's fictional local database only. Helpers/tests refuse
linked/remote targets. Start `npm run functions`, prepare onboarding and queue
fixtures using the commands in [QUEUE](QUEUE.md), and build/serve from `frontend/`:

```powershell
flutter analyze
flutter test
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.local.json
node tool/serve.cjs
```

Sign in at the exact loopback root with the captured local provider email and
explicit Continue. After claiming the fictional invitations, run from `backend/`:

```powershell
node tool/prepare-refresh-preview.cjs
node tool/prepare-lifecycle-preview.cjs
```

P11's helper supplies 30 active entries and 27 comments; the P10 helper supplies
archives/deleted history. Neither is imported into the application or migrations.
Check filters, page navigation, draft retention and two-session changes; inspect
hidden-tab network silence, unchanged revision-only reads, both themes and
keyboard controls. Sign out, rebuild without environment defines, stop preview/
functions and `npm run stop`. Payload measurements and estimates are in [COSTS](COSTS.md).

## Sources and boundary

Official references checked 2026-09-26: [database functions](https://supabase.com/docs/guides/database/functions),
[Supabase changelog](https://supabase.com/changelog),
[Postgres minor release](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes),
[Flutter lifecycle](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html),
and [Supabase pricing](https://supabase.com/pricing). P11 introduces none of the
extensions/custom operators affected by the recent database notice. Dependencies
remain pinned; provider, auth, DNS, billing and publication settings are unchanged.

Stop for P11 review. P12 release preparation remains unstarted. Hosted P06–P11,
real enterprise hosts, reliable Inbox placement, final HTTPS callback and publishing
remain outstanding. Credentials stay in provider/secret storage.
