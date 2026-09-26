# Ordered implementation backlog

Updated: 2026-09-26. **Execute one selected item, verify it, update the docs, and stop.** Do not turn this file into a single full-app implementation prompt.

The owner selected only P11 after completed local P10. P11 refresh, filtering,
pagination and accessibility are complete locally with automated and browser
verification. Hosted P06-P11 rollout is unperformed. Stop at P11 review; do not execute
P12 or publish automatically. P05 hosted admission remains revoked.

`Complete` means the item's actual deliverable exists. `Ready` means the next item can start when requested. Later items remain planned, not authorized as a batch. Smaller UI/product defaults can be settled at the item that needs them.

| ID | Item | State | Depends on |
| --- | --- | --- | --- |
| P00 | Repository inspection, research, persistent project plan | Complete | — |
| P01 | Resolve core product, authentication, budget, and hosting questions | Complete | P00 |
| P02 | Local Flutter app shell | Complete; ready for owner review | P01 |
| P03 | Local Supabase schema and team authorization | Complete; ready for owner review | P02 |
| P04 | Magic-link flow and guarded email delivery locally | Complete locally; ready for owner review | P03 |
| P04A | Local root-path and callback migration | Complete locally; ready for owner review | P04 |
| P05 | Small hosted authentication/cost validation | Complete for controlled trial; ready for owner review | P04A |
| P06 | Admin invitations, teams, and profiles | Complete locally; ready for owner review | P05 |
| P07 | Create/read/edit queue entries and protected deletion | Complete locally; ready for owner review | P06 |
| P08 | Sprint/priority ordering and admin reordering | Complete locally; ready for owner review | P07 |
| P09 | Comments and per-user review signals | Complete locally; ready for owner review | P08 |
| P10 | Archive, restore, and data lifecycle | Complete locally; ready for owner review | P09 |
| P11 | Refresh, filtering, responsive UI, and accessibility | Complete locally; ready for owner review | P10 |
| P12 | Release checks and subdomain publishing preparation | Ready; not started | P11 |
| P13 | Deploy the prepared release and run a small pilot | Planned | P12 |

## P02 — Local Flutter app shell

**Deliver:** Scaffold only Flutter Web under `frontend/`, retaining the license and docs. Create a sign-in placeholder, team/queue shell, fake entries, navigation, dark default, and a persistent light-mode toggle. Use fictional data and the originally specified base path/hash-routing strategy (the path is subsequently revised in P04A).

**Acceptance:** Runs locally; relevant Flutter analysis and release web build pass; inspect desktop/narrow layouts, keyboard navigation, and theme persistence in a browser. The screen clearly uses demo data; there is no fake claim of working authentication. Document verified run/build commands and SDK version.

**Boundary:** No Supabase project, real login, backend schema, provider signup, production deployment, or full feature implementation. Review the shell before P03.

**Completed 2026-09-14:** Web-only shell, read-only fictional Atlas/Orbit queues, sign-in/profile/archive placeholders, hash navigation, dark default and persisted light preference. Nine Flutter tests, analysis, release build, and browser/keyboard checks passed. Details and verified commands are in [STATUS](STATUS.md) and the [frontend README](../frontend/README.md). P03 was subsequently selected by the owner on 2026-09-16.

## P03 — Local Supabase schema and team authorization

**Deliver:** Set up project-local Supabase tooling and Docker development. Add migrations for identity profiles, teams, memberships, invitations, entries, comments, reviews, and private operational tables. Establish grants/RLS and fictional fixtures for two disjoint teams plus a multi-team user. Add an explicit operator bootstrap procedure.

**Acceptance:** A clean local reset reproduces the schema; direct Data API/SQL role tests deny anonymous and cross-team access, forged ownership, and role escalation. Revoked members lose access with a still-valid token. Last-admin and child-team invariants hold. No public privileged functions or mutable membership tables bypass the rules.

**Boundary:** Identity comes from local test fixtures; no real emails. Keep behavioral functions limited to what this authorization foundation needs.

**Completed 2026-09-16:** Pinned local Supabase CLI, Docker startup with binding diagnostics, schema migrations, explicit grants/RLS, guarded existing-member access changes, immutable identities, last-admin serialization, private operational tables, test-only fixtures, and operator bootstrap. Clean local reset, 19 SQL-role/Data API/concurrency tests, and SQL lint passed. Setup and test commands are in the [backend README](../backend/README.md); local network-binding limitations are recorded in [STATUS](STATUS.md). No frontend integration, real email, hosted setup, or queue behavior was added. P04 was subsequently selected on 2026-09-17.

## P04 — Magic-link flow and guarded email delivery locally

**Deliver:** Integrate the maintained Flutter auth client; disable public signup; prove server-provisioned unconfirmed users can obtain magic links. Implement the signed email hook, exact invitation checks, atomic quotas, idempotency, and a mocked sender/local inbox. Design the callback at the actual app entry document, not a server-rewritten route.

**Acceptance:** Allowed/uninvited/revoked/expired scenarios work through direct Auth endpoints. Replay/expiry, signature failure, concurrent quota reservations, and duplicate-hook tests pass without real mail. Select and document session persistence and token cleanup. Verify the CAPTCHA integration design and mail-scanner behavior; a failed feasibility test produces a small design correction before moving on.

**Boundary:** No invented auth tokens or test identity in hosted builds. No paid service or production signup/deployment.

**Completed 2026-09-17:** Maintained Flutter client, explicit token-hash confirmation at the entry document, sessionStorage adapter, signed local Edge hook, atomic service-only quotas, duplicate protection, fictional Mailpit delivery, and real Auth endpoint checks. Feasibility corrected first login to confirmation resend while retaining disabled public signup. CAPTCHA integration design requires a fresh challenge for the fallback. SDK cross-tab broadcasts are documented. See [AUTH](AUTH.md) and [STATUS](STATUS.md). No hosted configuration or real mail was added.

## P04A — Local root-path and callback migration

**Deliver:** Adapt the existing P04 implementation to the app-root path `/`, matching the selected subdomain. Update Flutter's base-href build instructions, local preview server/frame, early callback scrubber and Dart URL checks, Supabase local Site URL, sender callback validation, helper scripts, and relevant fixtures/tests together. Use `http://127.0.0.1:4173/` for the local equivalent. Keep exact-origin checks, explicit confirmation, token cleanup, and local-only authentication/mail gates intact.

**Acceptance:** Relevant Flutter and JavaScript callback tests, local Auth integration checks, and a root-base release build pass. Inspect root/hash-route refresh, link request, fragment cleanup, explicit confirmation, reload and sign-out in the browser. Reject the obsolete callback path and unexpected origins rather than forwarding tokens. Update AUTH/frontend/backend runbooks only after the replacement commands are verified. Record new evidence without rewriting historical P02-P04 test results.

**Boundary:** Local configuration/code only, with fictional data and captured mail. No cloud account, DNS, repository visibility/name, Pages, real email, or paid-service change. Stop for review before P05.

**Completed 2026-09-18:** Root preview/frame and release build, early callback cleanup,
exact local Dart/sender gates, Supabase Site URL, existing `.env` callback migration,
SDK callback fixtures and denial regressions. Local verification passed: 19 P03
tests, 20 auth/hook/environment tests, 16 Flutter tests, six callback-script tests,
three preview HTTP tests, analysis and SQL lint. Chrome verified captured-mail
confirmation, cancellation, reload, sign-out, root/hash routes and narrow preview.
In-page callback navigation found during QA is now scrubbed and rejected; normal
email confirmation uses a new document. Commands/evidence are in AUTH and STATUS.
P05 was subsequently selected by the owner; its current progress is below.

## P05 — Small hosted authentication/cost validation

**Deliver:** Implement the reviewed Resend sender and Turnstile widget, replace P04's explicit local-only gates with validated hosted configuration, and prepare then configure a Free Supabase project, Resend Free sending domain, and Turnstile for a small developer trial when the owner selects this stage and supplies account access. After P04A, use the exact root-path loopback callback initially, with no real company content. Prepare the production Site URL/callback `https://reviews.pedro-costa.dev/` and specific Turnstile hostname for rollout, without wildcard or old portfolio redirects. Keep trial settings distinct from production and validate the live subdomain callback in P13. Confirm account quotas, sender-domain DNS additions at Namecheap, and no paid add-ons. The owner supplies secrets through secret storage, not docs/chat.

**Acceptance:** Controlled developer inboxes receive a single valid magic link; expired/replayed links and email scanners are handled; signup disabled still allows invited login; direct Auth calls enforce CAPTCHA and hook budgets. Capture actual sanitized provider usage/configuration and delivery observations. Generic user acknowledgement does not expose team membership. No load testing of real email.

**Boundary:** If provider setup needs user action, finish the local code/config/runbook first and identify the specific missing action. App-subdomain DNS and Pages publication remain P13; email-domain verification is separate. Do not change nameservers or proceed to queue implementation until this sign-in path works.

**Completed 2026-09-20 for the controlled trial:** Resend/Turnstile implementation,
bounded operator admissions, Free provider setup and usage, three single-message
deliveries, first/confirmed-user login, expiry/replay, reload/sign-out, passive
scanner rendering, live CAPTCHA reuse rejection and revoked-admission denial.
Local tests cover broader authorization, signatures, budgets and concurrency.
The sending trial is closed: zero active admissions/sessions/memberships; no extra
mail from denial tests. Evidence and limits are in [HOSTED_AUTH](HOSTED_AUTH.md)
and [STATUS](STATUS.md). All three emails reached Junk despite SPF/DMARC pass;
investigate classification and retest the final HTTPS callback before rollout.
P06 is ready when selected. No subsequent item is automatically authorized.

## P06 — Invitations, teams, and profiles

**Deliver:** Admin invite/revoke/resend UI; safe Auth provisioning/reconciliation; first-login invitation claiming; team selector; profile completion/view/edit; member role/removal controls. Use proposed operator-created teams and team-scoped admins unless the owner changes that default.

**Acceptance:** A real test invitation lands in the correct team; a user can belong to two teams without data leakage; repeated/failed provisioning is recoverable; usernames cannot claim invites; teammate profile permissions work; email disclosure follows the agreed rule; last-admin removal is prevented.

**Boundary:** No public team signup or global user directory. Review the onboarding workflow.

**Completed locally 2026-09-21:** Admin invite/revoke/resend and member controls,
recoverable unconfirmed Auth provisioning, verified identity-bound invitation
claiming, team selector, profile completion/edit/view and active-teammate email
disclosure (owner confirmed). Clean reset, 19 authorization tests, 28 auth tests,
14 onboarding tests, 25 Flutter tests, 15 JavaScript tests, analysis, SQL lint,
security advisor and root release build passed with documented advisory/font
limitations. Browser/keyboard checks exercised local provider links and the
connected workflow. See [ONBOARDING](ONBOARDING.md) and [STATUS](STATUS.md).
No hosted deployment or real-company invitations. Stop here; P07 is not executed.

## P07 — Queue entries and ownership

**Deliver:** Add/list/edit entry UI and guarded transactional functions, validation for title/HTTPS PR/Jira links/sprint flag/priority, duplicate detection, owner/admin deletion, and edit-version conflicts. Confirm the added title field, priority labels, and edit rules here if needed. Deletion can initially hide a record with audit metadata; permanent purge waits for P10.

**Acceptance:** Entry survives reload; both enterprise links open in the browser; no server fetch occurs. Direct non-owner deletion fails. Forged submitter/team values and duplicate active links fail. Conflicting edits cannot silently overwrite each other.

**Boundary:** No external GitHub/Jira credentials or inferred PR state.

**Completed locally 2026-09-21:** connected entry list/add/edit/delete, guarded
transactional RPCs, private per-team exact host configuration, canonical resource
links, duplicate protection, optimistic versions, mutation budgets and deletion
audit metadata. Owner confirmed title/owner-admin edits and later revised
priorities to **Low, Medium, High, Critical**; Medium replaces Normal, including
existing-row migration. Fictional hosts locally; real hosts remain private before
live use. Verification and limitations are in [QUEUE](QUEUE.md) and [STATUS](STATUS.md).
No P08 reorder controls or subsequent backlog behavior was implemented.

## P08 — Priority and reordering

**Deliver:** Sprint-goal groups, Critical/High/Medium/Low groups, admin drag/drop and keyboard moves within a group. Transactional queue revisions prevent competing admins losing changes. Moving groups appends to the destination. P07 already maintains revision/append metadata for create/edit/delete; reuse it and add the actual sorting/reorder contract here.

**Acceptance:** A representative mixed queue sorts correctly; a member cannot reorder via UI or API; cross-group drag is disallowed; simultaneous edits produce a clear conflict; order remains stable after reload.

**Boundary:** No unrequested override across sprint/priority groups.

**Completed locally 2026-09-22:** ordered snapshots with matching revisions,
admin-only transactional same-group moves, Material drag handles and keyboard
move buttons, conflict refresh and destination append behavior. P07 dependency
was complete; no material unanswered P08 question. Clean six-migration reset,
19 authorization tests, 11 entry tests, eight ordering tests, 37 Flutter tests,
analysis, SQL lint/security advisor and root release build passed. Browser
checks cover admin/member controls, drag, keyboard, conflict, persistence and
narrow themes. Details/limitations are in [QUEUE](QUEUE.md) and [STATUS](STATUS.md).
No later backlog behavior or hosted/DNS/Pages operation. Stop at P08 review.

## P09 — Comments and review signals

**Deliver:** Plain-text comments; author edit/delete and admin moderation; per-user check/X/clear actions and counts. Owner confirmed 2026-09-23: prohibit both review signals on one's own entry, including admins; comments remain allowed.

**Acceptance:** One current signal per user; changing/clearing updates counts correctly; members cannot impersonate a reviewer; cross-team entry IDs fail; HTML-like input is safe. The X has the explicit label "Comments left on PR". These actions do not post externally or mark a PR merged.

**Completed locally 2026-09-23:** seventh migration, guarded activity snapshot/comment/signal
RPCs, optimistic comment versions, PR-link signal reset, shared mutation budget
and connected Flutter panels. See [ACTIVITY](ACTIVITY.md) and [STATUS](STATUS.md)
for verification and limitations. Clean reset, 47 backend tests across authorization,
entries, ordering and activity, 44 Flutter tests, SQL lint/security advisor, analysis,
root release builds and browser/keyboard checks passed with documented limits.
No P10+ work or hosted/DNS/Pages operation. Stop for P09 review.

## P10 — Archive and lifecycle

**Deliver:** Manual archive with reason/updater/time; paginated read-only archive; authorized restore with duplicate conflict handling; distinguish deleted entries from archived ones. Confirm retention, recovery, and audit policy before implementing permanent purges.

**Acceptance:** Archive preserves history; restore applies current ordering rules; unauthorized actions fail; conflicting active duplicates are explained; all PR state is labeled manually maintained. Lifecycle changes can be demonstrated with fictional dates/data. No unapproved destructive purge.

**Completed locally 2026-09-26:** eighth migration, manual owner/admin archive and
restore, admin-only deleted recovery, 25-row cursor pages, read-only history,
duplicate/host/version conflicts, shared budgets, minimal retained audit and
keyboard confirmation/focus. Owner confirmed no expiry or permanent purge.
See [LIFECYCLE](LIFECYCLE.md) and [STATUS](STATUS.md) for verification and limits.
No P11, hosted migration, real mail, provider change or publication. Stop for review.

## P11 — Usability and efficient refresh

**Deliver:** Search/filters, bounded pagination, small revision checks, visible-tab refresh, last-updated display, offline/session/quota errors, mobile layout, and accessibility improvements. Changes to relevant rows advance the data revision.

**Acceptance:** Two sessions see saved changes within the stated refresh window; hidden tabs stop polling; unchanged queues do not download full snapshots; no retry storms; keyboard/screen-reader labels and both themes are usable. Measure payloads and extrapolate usage against COSTS.

**Completed 2026-09-26:** Revision-only visible checks, server filters, 25-row queue
and activity pages, draft/focus preservation, bounded retries and responsive,
labelled controls. User-reported comment alignment and action spacing are fixed.
Verification and measured costs are recorded in [STATUS](STATUS.md),
[REFRESH](REFRESH.md) and [COSTS](COSTS.md). P12 remains unstarted; stop for review.

## P12 — Release checks and subdomain publishing preparation

**Deliver:** Prepare this repository's independent GitHub Pages workflow and Flutter artifact with base href `/`. Document the app-specific custom domain, domain verification, exact Namecheap record, HTTPS setup, callback/Turnstile configuration, and rollback/decommissioning sequence from ARCHITECTURE. Inspect the actual repo/account's Pages eligibility; if a public repository is required, prepare for that visibility change without performing it here. Add reproducible build checks, secret handling, backup/export and restore procedure, and versioned release instructions. Review scripts/service workers on the app origin and current hosting terms/quotas.

**Acceptance:** Preview of the standalone app artifact serves `/` and hash routes; callback URLs match the confirmed subdomain. Relevant security matrix checks pass; release assets and any history to be published contain no secrets/private fixtures; restore is tested; provider configuration/usage is documented. The deployment targets this app's repository, not the portfolio. DNS changes are limited to the dedicated hostname and necessary verification records. Document how P13 will verify origin separation and preserve the existing sites. Resolve concrete release blockers before launch.

**Boundary:** Prepare a reviewable release and publishing diff; P13 owns applying it. No DNS provider change, automatic billing upgrade, or repository rename is needed. No access to the portfolio's source repository is required for combining builds, because the combined-site plan is superseded.

## P13 — Deploy and pilot

**Deliver:** When the owner selects this deployment step, publish the prepared release from this app's repository, apply the verified app-specific Pages/Namecheap settings, and enforce HTTPS at `https://reviews.pedro-costa.dev/`. Apply any needed repository visibility change only within the selected publication scope. Validate the live callback and Turnstile hostname, and remove development-only/obsolete callbacks from production configuration. Roll back the app-specific change if rollout fails. Pilot with 2-3 invited users before adding the rest of the team.

**Acceptance:** HTTPS, sign-in, team boundaries, links, queue/reorder/comments/reviews/archive, and both themes work at the production subdomain root. The app does not redirect to the portfolio; portfolio-origin DOM/storage access fails and its service worker cannot control the app. Portfolio and PassGen remain reachable. Confirm actual costs/quotas, restore instructions, and revocation. Record the deployed revision, deployment destination, operator, and known limitations.

**Boundary:** The pilot needs human feedback across real use. Do not claim a multi-day pilot passed in one run or create background monitoring unless requested. Subsequent work follows actual pilot findings.

## Later ideas (unordered; not part of this implementation)

Email-free company SSO, optional stale-review resets after manual code-update marking, notification preferences, and richer analytics. The dedicated subdomain is now confirmed, not a later idea. GitHub/Jira synchronization remains excluded unless the owner changes the manual-only requirement.
