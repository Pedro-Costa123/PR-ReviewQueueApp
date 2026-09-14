# Product

Last updated: 2026-09-14. Owner: Pedro Costa. Stage: local shell implemented for review; core questions answered, smaller defaults recorded for later steps. Demo content illustrates proposals without confirming them.

## Problem and outcome

Teams currently share PRs in a Teams chat. Entries get buried, sprint-goal work loses priority, and people cannot easily tell which work still needs review or is already closed.

Build a small private web app for approximately 5-20 users, organized by team. It provides a durable review queue, direct PR/Jira links, clear priorities, review signals, and an archive. Git hosting remains the place where code review actually happens.

## Confirmed requirements

- Flutter frontend, web only.
- Dark mode by default, with a light-mode option.
- Basic profiles with name, email, and username; clicking a user's name opens their profile.
- Team-separated queues and administrator-managed invitations.
- Users add an entry with a PR link, Jira link, sprint-goal flag, and priority.
- Users can open both links in the relevant external service.
- Admins can reorganize the queue.
- Only an entry's submitter and that team's admins can delete it.
- Users can add comments to queue entries.
- Users can mark an entry with a check for "reviewed, looks good" or an X for "comments left on the PR".
- An archived queue is required.
- Keep hosting/backend cost as low as practical, with protection against unauthorized access and abuse that could increase costs.
- Keep frontend and backend in separate repository folders, with persistent documentation and incremental implementation.

The owner additionally confirmed:

- Work email invitations with **magic links**.
- Aim for **€0/month** and keep `https://pedro-costa.dev/PR-Review-App-Queue/`.
- DNS is on Namecheap; the portfolio and PassGen are hosted on GitHub Pages. The owner explicitly chose to keep this setup (correcting an earlier Cloudflare answer).
- PRs are on GitHub Enterprise and tasks on Jira Enterprise. The app must not fetch their contents or status; users update entries and archive them manually.
- Sprint-goal entries first, then priority; admins reorder within those groups. Multiple teams per user are allowed.
- External hosting of the specified company data is allowed. Exact retention/region requirements have not been specified.

## Proposed version 1 behavior

Confirmed rules above take precedence. Additional details below are proposed defaults, to resolve only when they materially affect the selected implementation item.

### Identity, invitations, and teams

- An admin invites an exact work email to a team. The email recipient proves ownership through the sign-in provider. A chosen username is display/profile data, never proof of invitation ownership.
- First sign-in claims unexpired invitations for that verified email and asks for name and username. A user with one team opens its queue; a user with multiple teams gets a team selector.
- Allow membership in multiple teams. Admin rights are team-specific. Being an admin in Team A grants no rights in Team B.
- A deployment operator bootstraps the initial team and admin explicitly. The first person to visit the site never becomes admin automatically.
- Invites expire after 7 days and can be revoked. Removing a member revokes their access to that team on their next API request.
- Teammates may view one another's profiles. Do not expose a global directory or another team's membership. Proposed public-to-teammates fields: name and username; email is visible to the user and their team admins.
- A deployment operator creates additional teams for the initial release. Self-service creation of unrelated organizations is deferred.

### Queue entries and ordering

- Also request a short title (1-160 characters) so the queue is understandable without fetching a private PR. This is an added proposed field, not an integration requirement.
- Require HTTPS PR and Jira links, an explicit sprint-goal boolean, and priority: High, Normal, or Low. Normal is the proposed default.
- Proposed sort: sprint-goal entries first; within each group, High before Normal before Low; within each priority group, admin-defined order, then stable creation order.
- Admin drag/drop and keyboard move controls operate within a group. Changing the sprint-goal flag or priority moves the entry to the end of its new group. If admins need an emergency override across groups, choose that different rule in P01.
- Only submitters and team admins edit an entry. Other members can comment and set their own review signal.
- An active entry with the same normalized PR URL in the same team is rejected as a duplicate. The same PR in another team is permitted. Re-adding an archived PR prompts restoration by an authorized user.
- Suggested queue columns: order, title, sprint-goal badge, priority, submitter, review counts, age, and link/actions menu.
- Include text search and filters for sprint goal, priority, and submitter. Keep paginated archive views separate from the active queue.

### Comments and review signals

- Queue comments are local notes; they are not automatically posted to the PR or Jira.
- Use plain text, up to 2,000 characters. A comment's author can edit/delete it; team admins can remove it for moderation.
- Each member has one current signal per entry: `looks_good`, `comments_left`, or unset. They can change or clear their own signal. Show who set it and when.
- The X means feedback was left on the PR; it is not a build failure. Pair icons with text/tooltips and accessible labels.
- Proposed: the submitter cannot mark their own entry as reviewed. No automatic completion based on a count of checks.
- These signals do not replace required approvals in GitHub/GitLab/Azure DevOps/Bitbucket and can become outdated when code changes. Reset signals when the PR link changes; automated detection of new commits belongs with the future integration.

### Archive, deletion, and PR closure

- An authorized submitter or team admin can archive and restore an entry. Archiving records who did it, when, and a reason: merged, closed, no longer needed, or other.
- Archived entries keep comments and signals and become read-only until restored. Archive is not deletion.
- Delete removes an erroneous entry from normal views; proposed implementation is soft deletion with 30-day recovery for the submitter/team admin, followed by a controlled purge. Confirm retention in P01; do not implement an unapproved automatic purge.
- Archive manually, as confirmed by the owner. Show that state is manually maintained, with the last updater and timestamp. An archived entry must not be represented as provider-verified merged/closed just because someone archived it.
- Do not add GitHub/Jira integrations, link previews, server-side URL fetches, webhooks, credentials, or network tunnels. The user's browser opens the enterprise links directly.

### Refresh and usability

- Responsive layout for desktop and mobile browsers, with desktop as the primary workflow.
- Store theme preference locally; do not follow the OS light theme on the first visit.
- Refresh after mutations and when returning to the tab. Proposed background refresh: at most once per 60 seconds while visible; stop on hidden tabs, authentication errors, or rate limits. Provide a manual refresh button and last-updated time.
- Show explicit loading, empty, permission-denied, expired-session, offline, and save-conflict states. Do not claim a change saved before the API confirms it.
- Links open with protections against opener/referrer leakage. Existing company sign-in/VPN requirements still apply when following them.

## Roles and permissions (proposed details)

All permissions below require active membership of the entry's team.

| Action | Member | Submitter / author | Team admin |
| --- | --- | --- | --- |
| Read queue/archive and teammate profiles | Yes | Yes | Yes |
| Add entry or comment | Yes | Yes | Yes |
| Edit/archive/restore/delete entry | No | Own entry | Any entry in own team |
| Set/change/clear review signal | Own signal | Own signal, except own PR | Own signal, except own PR |
| Edit comment | Own comment | Own comment | Own comment |
| Delete comment | Own comment | Own comment | Any comment in own team |
| Reorder queue | No | No | Yes |
| Invite/remove members and manage team roles | No | No | Yes; cannot remove last admin |

## Out of scope unless requested

Native mobile/desktop apps, payments, attachments/avatar uploads, Teams messages, automated reminders, AI code review, Jira data synchronization, repository crawling, public signup, and a general-purpose organization billing system.

## Confirmed answers and remaining questions

| ID | Question | Proposed default / consequence |
| --- | --- | --- |
| Q01 answered | PR/task source and synchronization? | GitHub Enterprise and Jira Enterprise; links only, entirely manual updates. Exact allowed hostnames are needed before live use, not for the fictional prototype. |
| Q02 answered | Invitation identity and sign-in? | Exact work email + magic link. |
| Q03 answered | Budget and hosting address? | Aim for €0; retain the path, Namecheap DNS, and GitHub Pages. Inspect the existing Pages publishing arrangement before rollout. |
| Q04 answered | Ordering and teams? | Sprint first, then priority, admin reorder within groups; multiple teams allowed. |
| Q05 answered | External hosting permission? | Owner says allowed. Region/retention remain unspecified; select an available EU project region unless a different requirement emerges. |
| Q06 | Who creates teams and appoints initial admins? | Deployment operator bootstraps them. Team admins manage their own members. |
| Q07 | Who may archive/edit, should emails be visible to teammates, and can submitters review their own PR? | Defaults above. |
| Q08 | Are the title field, priority labels, deletion recovery, and retention acceptable? | Title + High/Normal/Low; confirm archive/audit retention and deletion policy before data lifecycle work. |

## Pilot success criteria

Every submitted PR can be found in the active queue or archive; sprint ordering is understandable; team boundaries and ownership rules hold through direct API calls; two users can see each other's confirmed changes; theme and links work; measured service usage stays comfortably within the chosen budget. Pilot with 2-3 users before expanding to 5-20.
