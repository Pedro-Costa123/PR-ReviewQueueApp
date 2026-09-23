# Decisions

Updated: 2026-09-23. **Confirmed** means specified/answered by the owner. **Proposed** means a researched design choice for staged validation. **Deferred** means deliberately outside current work. **Superseded** records an earlier choice replaced by a later decision.

| ID | Status | Decision and reasoning |
| --- | --- | --- |
| D01 | Confirmed | Flutter Web only. The owner wants to learn Flutter; native platforms are unnecessary. |
| D02 | Confirmed | Plan/research first, then one backlog item at a time. Persistent repository docs carry context between planning and implementation. |
| D03 | Confirmed | GitHub Enterprise and Jira Enterprise links only. Users maintain status and archive manually; no integrations, credentials, crawlers, or URL fetches. |
| D04 | Confirmed | Invite exact work emails and use magic links. Username remains profile data. |
| D05 | Confirmed; address revised by D27 | Aim for €0/month with Namecheap DNS and GitHub Pages. The original `pedro-costa.dev/PR-Review-App-Queue/` address was replaced by `reviews.pedro-costa.dev/` on 2026-09-18. |
| D06 | Confirmed | Sprint first, then priority; admins reorder within groups. Users may belong to multiple teams. |
| D07 | Confirmed | External hosting of the stated company data is permitted by the owner. Retention and any special regional constraints remain unspecified. |
| D08 | Proposed | Supabase Free for Auth/Postgres/RLS/Edge Functions plus Resend Free for mail. Fits magic links with a plausible zero-cost workload; see dated limits in COSTS. |
| D09 | Proposed | Use a signed Send Email Hook with invitation checks and atomic budgets. Direct Auth calls must not bypass mail controls. Tokens remain provider-managed. |
| D10 | Superseded by D27 | The proposed combined portfolio/app Pages artifact is no longer needed. Deploy this repository's app independently with its own custom subdomain. |
| D11 | Proposed | Use hash routing with the required Flutter base href. It avoids relying on unsupported Pages rewrites; callback compatibility is an early test. |
| D12 | Proposed | Enforce permissions in RLS and transactional functions. Privileged Edge Functions are narrowly scoped to invitation/provisioning and mail. No second general-purpose backend server. |
| D13 | Partly superseded by D30/D32 | P07 confirms title and owner/admin entry edits and replaces the proposed priorities. P09 confirms no self-review. Archive authority remains proposed for P10. |
| D14 | Proposed | Active/archive are queue lifecycle states, not provider-verified PR states. Review signals are local indicators, not GitHub approvals. |
| D15 | Proposed | Operator bootstraps teams/initial admins; team admins manage invitations and roles. Prevent last-admin removal and cross-team admin authority. |
| D16 | Proposed | Review theme/layout locally first, then validate invitation/security design before building the full queue. |
| D17 | Proposed | Use revision checks and bounded refresh, not continuous full-list polling or Realtime. This reduces bandwidth and implementation scope. |
| D18 | Updated by D27 | Keep theme locally and minimize session persistence. The selected subdomain separates app storage/service-worker origin from the portfolio; preserve backend access checks and avoid parent-domain auth cookies or shared scripts that undo this boundary. |
| D19 | Deferred | Paid subscriptions, automatic provider integration, notifications, attachments, AI review, and self-service organization creation. |
| D20 | Implemented in P02, 2026-09-14 | Use `go_router` 18.0.1 and `shared_preferences` 2.5.5 with a pinned lockfile; no extra state-management package. Theme uses the async preferences API. The shell has public fictional presentation fixtures and no fake identity or login bypass. This realizes the local shell without granting or simulating server access. |
| D21 | Implemented in P03, 2026-09-16 | Pin project-local Supabase CLI 2.117.0; run the minimal Docker stack on a dedicated bridge requesting loopback binding. Actual all-interface bindings on this Docker Desktop are reported, not treated as isolation; stop the stack after verification. Reset applies migrations without fixtures. Node built-in tests and Docker `psql` verify SQL roles, the Data API, and concurrency; test identities/JWTs are isolated from migrations, deployment seeds, and Flutter. |
| D22 | Implemented in P03, 2026-09-16 | Expose authenticated reads under live-membership RLS and only the guarded `set_member_access` RPC. Deny direct writes, including owner/admin queue writes until their backlog items. Keep private operational tables and operator bootstrap out of the API. Global and schema function defaults are explicitly revoked. Team-row serialization, post-lock authorization checks, and database triggers protect last-admin changes. This implements the local authorization foundation, not hosted authentication or approval of remaining product defaults. |

## P04 validated corrections (2026-09-17)

- **D23:** Keep global signup disabled and enable the local email provider. Existing
  unconfirmed users require SDK confirmation resend after /otp returns signup_disabled;
  confirmed users use ordinary OTP. No pre-confirmation or public creation workaround.
- **D24:** Use provider token-hash verification after explicit user confirmation at the
  real entry document. Scrub the fragment before Flutter. Use sessionStorage with memory
  fallback and document SDK synchronization across open tabs; no tab-isolation claim.
- **D25:** Serialize rolling recipient/project mail reservations; bind idempotency to
  event ID plus digest. Count uncertain sends and do not redeliver ambiguous events.
  Local-only Mailpit adapter now; Resend adapter/provider idempotency is P05.
- **D26:** P05 supplies a fresh Turnstile token for every provider attempt, including
  confirmation fallback. Local frontend/sender gates prevent shipping this preview as
  hosted login without that work. No live CAPTCHA enforcement is claimed in P04.

Evidence, observed limitations and official references are in [AUTH](AUTH.md).

## D27 — Dedicated app subdomain (confirmed 2026-09-18)

The owner selected **`https://reviews.pedro-costa.dev/`** on GitHub Pages, retaining Namecheap DNS. This replaces D05's original shared URL path and D10's proposed combined-site deployment. It updates D18's security assumptions: the app and portfolio have separate browser origins, while app authentication and team authorization remain essential.

Deploy from this app's repository, with base href `/` and an explicit repository custom domain. No new organization, repository rename, DNS-provider migration, or new domain purchase is required. Making the repository public remains a later publication action, not part of this documentation change.

P04A is a bounded local path/callback migration before P05; P12 prepares the independent Pages release and P13 applies/validates the subdomain deployment. Preserve P02-P04's recorded commands and results as history until their replacements are tested. See [Architecture](ARCHITECTURE.md), [Security](SECURITY.md), and the 2026-09-18 hosting recheck in [Costs](COSTS.md).

P04A implemented D27's local preparation on 2026-09-18. The exact loopback root
replaces the legacy callback throughout preview/client/provider/hook configuration.
Browser QA also found same-document fragment navigation bypassed the original
load-time scrubber. History/hash callback events now scrub and reject that input;
opening the email link in a new document remains the supported confirmation flow.
No hosted gate was widened and no hosting/provider decision changed.

## D28 — Bounded hosted authentication trial (2026-09-18/19)

The owner selected P05, named the existing Supabase Free project, approved
`auth.pedro-costa.dev` as the dedicated sender, added its Namecheap verification
records, and created a managed Turnstile widget. This authorizes the developer
trial, not production Pages publication or a paid plan.

Use explicit `hosted-trial` mode at the exact loopback root. Keep local Mailpit
isolated and reject production mode until P12/P13. The reviewed sender uses Resend
event idempotency and one bounded attempt; Turnstile tokens are fresh per Auth call.

Implementation correction: the first hosted identity cannot receive a team invite
before a verified bootstrap admin exists. An operator-only, maximum-three-slot,
24-hour admission bound to an unconfirmed Auth identity/email permits guarded
trial mail without pre-confirming email or copying fixtures. It grants no team
access and cannot bypass existing membership revocation. Remove admissions before
production. P06 still owns real invitation/provisioning/claiming behavior.

The controlled trial completed on 2026-09-20 with real login, delivery, CAPTCHA
reuse denial, revoked-admission denial and passive-rendering checks. Three messages
reached Junk despite SPF/DMARC pass; retain this release follow-up. Admission is
revoked. See [HOSTED_AUTH](HOSTED_AUTH.md) for evidence and limits. P06 is next.

## D29 — P06 onboarding and profile disclosure (2026-09-21)

**Confirmed:** the owner selected P06 only and explicitly chose email visibility
to **all active teammates**, superseding the proposed admin-only email rule.
`profile_details` returns Auth email only to self/shared active teammates; there
is no global directory or profile-editable email field.

**Implemented locally:** retain operator-created teams and team-scoped admins,
seven-day invitations, idempotent preparation with unchanged pending role/expiry,
unconfirmed password-free Auth provisioning and exact-identity reconciliation.
Delivery reuses the existing provider OTP/confirmation resend and signed hook,
so admin resend does not create a CAPTCHA or budget bypass. First-login claiming
requires both bound identity and current verified email. Old invitations never
restore removed memberships; an admin must explicitly restore access.

P06 adds no provider, dependency, public signup, queue behavior or deployment.
See [ONBOARDING](ONBOARDING.md) for recovery, verification and local-only limits.

## D30 — P07 entries and enterprise hosts (2026-09-21)

**Confirmed:** the owner selected P07 only, accepted required title (1–160),
submitter/team-admin editing and soft deletion with audit metadata, and chose
operator-configured exact hostname allowlists with fictional hosts locally.
Real company hosts will be supplied privately before live use. A later instruction
in the same item replaced the earlier labels with **Low, Medium, High, Critical**.
Medium replaces Normal as the default; the migration converts existing values and
advances versions/revisions to invalidate stale edits.

**Implemented locally:** empty-by-default private team host allowlist; strict
GitHub PR/Jira issue resource grammar; canonical resource URLs without
query/fragments; server-derived submitter; owner/admin guarded edits/deletion;
version conflicts; unique active PR/team; 30 successful mutations per identity
per minute; minimal private audit metadata. See [QUEUE](QUEUE.md).

Existing Material patterns are reused. No design-generation service, dependency,
external integration, hosted migration, DNS, Pages or billing change is included.
P08 sorting/reorder, P09 review/comments and P10 archive/recovery/purge remain
unimplemented. Host availability and real enterprise access are not claimed by
the fictional local link checks.

## D31 — P08 ordering and concurrency (2026-09-22)

The owner selected P08 only; confirmed D06 ordering and P07 priority labels fully
determine its local product behavior. No material question blocks this item.
P09 self-review and P10 lifecycle questions remain for their selected items.

Implemented one stable snapshot RPC for ordered rows and queue revision, with
server sorting before the existing 100-row bound. Admin moves name a same-group
target and before/after placement, serialize under the existing team lock, recheck
authority and revision, and shift the affected position interval. Reorder advances
queue/data revisions but preserves content versions; P07 group edits still append.
UI controls use existing Material patterns, drag handles and keyboard move buttons,
with explicit conflict refresh and no automatic retry. No additional dependency,
provider, authentication, pricing, DNS or publishing decision is introduced.
See [QUEUE](QUEUE.md) and [STATUS](STATUS.md) for contracts, evidence and limits.

## D32 — P09 comments and review signals (2026-09-23)

**Confirmed:** the owner selected only P09 and explicitly chose to prevent both
review signals on one's own entry, including admins. Submitters may still comment.
P08 is complete locally; no material P09 question remains unanswered.

**Implemented locally:** retain the proposed 2,000-character plain-text comments,
author edit/delete, admin removal without rewriting, and one current signal per
identity. The X is labeled “Comments left on PR”. The guarded transaction reuses
queue budgets/locks, derives authors, rechecks live membership/role after waits,
and advances only data revision. Comment versions prevent stale overwrite; entry
versions reject reviews of stale PR links. PR replacement atomically resets signals.
Soft-deleted comment metadata/audit mirrors P07; retention/purge is still P10.
Bounded on-demand activity panels use existing Material components, with complete
counts and explicit manual refresh. See [ACTIVITY](ACTIVITY.md) for contracts.

No new dependency, provider, authentication, pricing, hosting, external posting,
DNS or publishing decision. Flutter Web, invited-email magic links, manual links,
Namecheap DNS, GitHub Pages and `https://reviews.pedro-costa.dev/` are preserved.

## Alternatives evaluated

P02 package references: [go_router](https://pub.dev/packages/go_router), [shared_preferences](https://pub.dev/packages/shared_preferences), checked 2026-09-14. Resolved versions were verified against the installed Flutter 3.47.4 / Dart 3.13.3 SDK. Provider, pricing, and product proposals have not been promoted to confirmed requirements by implementing the shell.

Cloudflare Access/Workers/D1 could offer an inexpensive code-login design, but it no longer matches the owner's confirmed magic-link and existing-hosting choices. No Cloudflare DNS changes are planned. Turnstile can still be used independently for CAPTCHA.

Supabase's built-in testing email service does not satisfy ordinary team delivery. Resend via the hook is the proposed production sender, with free quotas and explicit abuse controls. A $25/month Supabase upgrade is a separate future decision, not automatic.

The former shared path and a dedicated GitHub organization were considered; the owner chose an app-specific subdomain on the existing domain instead. A repository rename is optional naming work, not a requirement for the chosen URL.

## Maintaining this log

When a decision changes, record the date, reason, affected requirements, and superseded decision. Update Product/Architecture/Costs/Next as appropriate. Do not mark a proposal confirmed simply because implementation work has started.
