# Decisions

Updated: 2026-09-18. **Confirmed** means specified/answered by the owner. **Proposed** means a researched design choice for staged validation. **Deferred** means deliberately outside current work. **Superseded** records an earlier choice replaced by a later decision.

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
| D13 | Proposed | Short title + High/Normal/Low priorities; owner/admin entry edits and archiving; no self-review. These fill unspecified product details and may be adjusted at the relevant step. |
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

## Alternatives evaluated

P02 package references: [go_router](https://pub.dev/packages/go_router), [shared_preferences](https://pub.dev/packages/shared_preferences), checked 2026-09-14. Resolved versions were verified against the installed Flutter 3.47.4 / Dart 3.13.3 SDK. Provider, pricing, and product proposals have not been promoted to confirmed requirements by implementing the shell.

Cloudflare Access/Workers/D1 could offer an inexpensive code-login design, but it no longer matches the owner's confirmed magic-link and existing-hosting choices. No Cloudflare DNS changes are planned. Turnstile can still be used independently for CAPTCHA.

Supabase's built-in testing email service does not satisfy ordinary team delivery. Resend via the hook is the proposed production sender, with free quotas and explicit abuse controls. A $25/month Supabase upgrade is a separate future decision, not automatic.

The former shared path and a dedicated GitHub organization were considered; the owner chose an app-specific subdomain on the existing domain instead. A repository rename is optional naming work, not a requirement for the chosen URL.

## Maintaining this log

When a decision changes, record the date, reason, affected requirements, and superseded decision. Update Product/Architecture/Costs/Next as appropriate. Do not mark a proposal confirmed simply because implementation work has started.
