# Ordered implementation backlog

Updated: 2026-09-16. **Execute one selected item, verify it, update the docs, and stop.** Do not turn this file into a single full-app implementation prompt.

`Complete` means the item's actual deliverable exists. `Ready` means the next item can start when requested. Later items remain planned, not authorized as a batch. Smaller UI/product defaults can be settled at the item that needs them.

| ID | Item | State | Depends on |
| --- | --- | --- | --- |
| P00 | Repository inspection, research, persistent project plan | Complete | — |
| P01 | Resolve core product, authentication, budget, and hosting questions | Complete | P00 |
| P02 | Local Flutter app shell | Complete; ready for owner review | P01 |
| P03 | Local Supabase schema and team authorization | Complete; ready for owner review | P02 |
| **P04** | **Magic-link flow and guarded email delivery locally** | **Ready; next implementation item after P03 review** | P03 |
| P05 | Small hosted authentication/cost validation | Planned | P04 |
| P06 | Admin invitations, teams, and profiles | Planned | P05 |
| P07 | Create/read/edit queue entries and protected deletion | Planned | P06 |
| P08 | Sprint/priority ordering and admin reordering | Planned | P07 |
| P09 | Comments and per-user review signals | Planned | P08 |
| P10 | Archive, restore, and data lifecycle | Planned | P09 |
| P11 | Refresh, filtering, responsive UI, and accessibility | Planned | P10 |
| P12 | Release checks and exact-path publishing preparation | Planned | P11 |
| P13 | Deploy the prepared release and run a small pilot | Planned | P12 |

## P02 — Local Flutter app shell

**Deliver:** Scaffold only Flutter Web under `frontend/`, retaining the license and docs. Create a sign-in placeholder, team/queue shell, fake entries, navigation, dark default, and a persistent light-mode toggle. Use fictional data and the required base path/hash-routing strategy.

**Acceptance:** Runs locally; relevant Flutter analysis and release web build pass; inspect desktop/narrow layouts, keyboard navigation, and theme persistence in a browser. The screen clearly uses demo data; there is no fake claim of working authentication. Document verified run/build commands and SDK version.

**Boundary:** No Supabase project, real login, backend schema, provider signup, production deployment, or full feature implementation. Review the shell before P03.

**Completed 2026-09-14:** Web-only shell, read-only fictional Atlas/Orbit queues, sign-in/profile/archive placeholders, hash navigation, dark default and persisted light preference. Nine Flutter tests, analysis, release build, and browser/keyboard checks passed. Details and verified commands are in [STATUS](STATUS.md) and the [frontend README](../frontend/README.md). P03 was subsequently selected by the owner on 2026-09-16.

## P03 — Local Supabase schema and team authorization

**Deliver:** Set up project-local Supabase tooling and Docker development. Add migrations for identity profiles, teams, memberships, invitations, entries, comments, reviews, and private operational tables. Establish grants/RLS and fictional fixtures for two disjoint teams plus a multi-team user. Add an explicit operator bootstrap procedure.

**Acceptance:** A clean local reset reproduces the schema; direct Data API/SQL role tests deny anonymous and cross-team access, forged ownership, and role escalation. Revoked members lose access with a still-valid token. Last-admin and child-team invariants hold. No public privileged functions or mutable membership tables bypass the rules.

**Boundary:** Identity comes from local test fixtures; no real emails. Keep behavioral functions limited to what this authorization foundation needs.

**Completed 2026-09-16:** Pinned local Supabase CLI, Docker startup with binding diagnostics, schema migrations, explicit grants/RLS, guarded existing-member access changes, immutable identities, last-admin serialization, private operational tables, test-only fixtures, and operator bootstrap. Clean local reset, 19 SQL-role/Data API/concurrency tests, and SQL lint passed. Setup and test commands are in the [backend README](../backend/README.md); local network-binding limitations are recorded in [STATUS](STATUS.md). No frontend integration, real email, hosted setup, or queue behavior was added. P04 remains unstarted.

## P04 — Magic-link flow and guarded email delivery locally

**Deliver:** Integrate the maintained Flutter auth client; disable public signup; prove server-provisioned unconfirmed users can obtain magic links. Implement the signed email hook, exact invitation checks, atomic quotas, idempotency, and a mocked sender/local inbox. Design the callback at the actual app entry document, not a server-rewritten route.

**Acceptance:** Allowed/uninvited/revoked/expired scenarios work through direct Auth endpoints. Replay/expiry, signature failure, concurrent quota reservations, and duplicate-hook tests pass without real mail. Select and document session persistence and token cleanup. Verify the CAPTCHA integration design and mail-scanner behavior; a failed feasibility test produces a small design correction before moving on.

**Boundary:** No invented auth tokens or test identity in hosted builds. No paid service or production signup/deployment.

## P05 — Small hosted authentication/cost validation

**Deliver:** Prepare then configure a Free Supabase project, Resend Free sending domain, and Turnstile for a small developer trial when the owner selects this stage and supplies account access. Use an exact localhost callback initially, with no real company content. Confirm account quotas, sender-domain DNS additions at Namecheap, and no paid add-ons. The owner supplies secrets through secret storage, not docs/chat.

**Acceptance:** Controlled developer inboxes receive a single valid magic link; expired/replayed links and email scanners are handled; signup disabled still allows invited login; direct Auth calls enforce CAPTCHA and hook budgets. Capture actual sanitized provider usage/configuration and delivery observations. Generic user acknowledgement does not expose team membership. No load testing of real email.

**Boundary:** If provider setup needs user action, finish the local code/config/runbook first and identify the specific missing action. Do not change nameservers, publish the app to the portfolio, or proceed to queue implementation until this sign-in path works.

## P06 — Invitations, teams, and profiles

**Deliver:** Admin invite/revoke/resend UI; safe Auth provisioning/reconciliation; first-login invitation claiming; team selector; profile completion/view/edit; member role/removal controls. Use proposed operator-created teams and team-scoped admins unless the owner changes that default.

**Acceptance:** A real test invitation lands in the correct team; a user can belong to two teams without data leakage; repeated/failed provisioning is recoverable; usernames cannot claim invites; teammate profile permissions work; email disclosure follows the agreed rule; last-admin removal is prevented.

**Boundary:** No public team signup or global user directory. Review the onboarding workflow.

## P07 — Queue entries and ownership

**Deliver:** Add/list/edit entry UI and guarded transactional functions, validation for title/HTTPS PR/Jira links/sprint flag/priority, duplicate detection, owner/admin deletion, and edit-version conflicts. Confirm the added title field, priority labels, and edit rules here if needed. Deletion can initially hide a record with audit metadata; permanent purge waits for P10.

**Acceptance:** Entry survives reload; both enterprise links open in the browser; no server fetch occurs. Direct non-owner deletion fails. Forged submitter/team values and duplicate active links fail. Conflicting edits cannot silently overwrite each other.

**Boundary:** No external GitHub/Jira credentials or inferred PR state.

## P08 — Priority and reordering

**Deliver:** Sprint-goal groups, High/Normal/Low groups, admin drag/drop and keyboard moves within a group. Transactional queue revisions prevent competing admins losing changes. Moving groups appends to the destination.

**Acceptance:** A representative mixed queue sorts correctly; a member cannot reorder via UI or API; cross-group drag is disallowed; simultaneous edits produce a clear conflict; order remains stable after reload.

**Boundary:** No unrequested override across sprint/priority groups.

## P09 — Comments and review signals

**Deliver:** Plain-text comments; author edit/delete and admin moderation; per-user check/X/clear actions and counts. Confirm the proposed self-review restriction here.

**Acceptance:** One current signal per user; changing/clearing updates counts correctly; members cannot impersonate a reviewer; cross-team entry IDs fail; HTML-like input is safe. The X has the explicit label "Comments left on PR". These actions do not post externally or mark a PR merged.

## P10 — Archive and lifecycle

**Deliver:** Manual archive with reason/updater/time; paginated read-only archive; authorized restore with duplicate conflict handling; distinguish deleted entries from archived ones. Confirm retention, recovery, and audit policy before implementing permanent purges.

**Acceptance:** Archive preserves history; restore applies current ordering rules; unauthorized actions fail; conflicting active duplicates are explained; all PR state is labeled manually maintained. Lifecycle changes can be demonstrated with fictional dates/data. No unapproved destructive purge.

## P11 — Usability and efficient refresh

**Deliver:** Search/filters, bounded pagination, small revision checks, visible-tab refresh, last-updated display, offline/session/quota errors, mobile layout, and accessibility improvements. Changes to relevant rows advance the data revision.

**Acceptance:** Two sessions see saved changes within the stated refresh window; hidden tabs stop polling; unchanged queues do not download full snapshots; no retry storms; keyboard/screen-reader labels and both themes are usable. Measure payloads and extrapolate usage against COSTS.

## P12 — Release checks and exact-path publishing preparation

**Deliver:** Inspect the existing portfolio Pages repository/workflow and exact custom-domain arrangement. Prepare a complete combined-site artifact or a concrete reviewed alternative; never replace the portfolio artifact with just this app. Add reproducible build checks, explicit callback configuration, secret handling, backup/export and restore procedure, versioned release instructions, and rollback steps. Review shared-origin scripts/service workers and current hosting terms/quotas.

**Acceptance:** Local preview of the full artifact serves the exact base path and hash routes; callback URLs match; root portfolio and PassGen routing are accounted for. Relevant security matrix checks pass; release assets contain no secrets; restore is tested; provider configuration/usage is documented. Resolve any concrete hosting-policy or shared-origin blocker before launch. Existing site deployment details are currently unknown and must be verified here.

**Boundary:** Prepare a reviewable release and publishing diff. No DNS provider change, automatic billing upgrade, or silent repository rename. If access to the existing site is missing, identify the exact repository/workflow required after completing independent preparation.

## P13 — Deploy and pilot

**Deliver:** When the owner selects this deployment step, deploy the prepared release to the existing Pages publishing arrangement and validate the real domain/callback. Roll back if existing site routes fail. Pilot with 2-3 invited users before adding the rest of the team.

**Acceptance:** HTTPS, sign-in, team boundaries, links, queue/reorder/comments/reviews/archive, and both themes work on the production path. Portfolio and PassGen remain reachable. Confirm actual costs/quotas, restore instructions, and revocation. Record the deployed revision, deployment destination, operator, and known limitations.

**Boundary:** The pilot needs human feedback across real use. Do not claim a multi-day pilot passed in one run or create background monitoring unless requested. Subsequent work follows actual pilot findings.

## Later ideas (unordered; not part of this implementation)

Email-free company SSO, optional stale-review resets after manual code-update marking, notification preferences, richer analytics, and a dedicated subdomain if the owner later wants browser isolation. GitHub/Jira synchronization remains excluded unless the owner changes the manual-only requirement.
