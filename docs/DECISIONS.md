# Decisions

Updated: 2026-09-14. **Confirmed** means specified/answered by the owner. **Proposed** means a researched design choice for staged validation. **Deferred** means deliberately outside current work.

| ID | Status | Decision and reasoning |
| --- | --- | --- |
| D01 | Confirmed | Flutter Web only. The owner wants to learn Flutter; native platforms are unnecessary. |
| D02 | Confirmed | Plan/research first, then one backlog item at a time. Persistent repository docs carry context between planning and implementation. |
| D03 | Confirmed | GitHub Enterprise and Jira Enterprise links only. Users maintain status and archive manually; no integrations, credentials, crawlers, or URL fetches. |
| D04 | Confirmed | Invite exact work emails and use magic links. Username remains profile data. |
| D05 | Confirmed | Aim for €0/month; keep `pedro-costa.dev/PR-Review-App-Queue/`, Namecheap DNS, and GitHub Pages. Namecheap supersedes the earlier corrected Cloudflare answer. |
| D06 | Confirmed | Sprint first, then priority; admins reorder within groups. Users may belong to multiple teams. |
| D07 | Confirmed | External hosting of the stated company data is permitted by the owner. Retention and any special regional constraints remain unspecified. |
| D08 | Proposed | Supabase Free for Auth/Postgres/RLS/Edge Functions plus Resend Free for mail. Fits magic links with a plausible zero-cost workload; see dated limits in COSTS. |
| D09 | Proposed | Use a signed Send Email Hook with invitation checks and atomic budgets. Direct Auth calls must not bypass mail controls. Tokens remain provider-managed. |
| D10 | Proposed | Publish the app folder inside the existing domain's complete Pages artifact. The source repo name differs from the required path, so inspect the publishing workflow first. Do not replace the full portfolio artifact with an app-only build. |
| D11 | Proposed | Use hash routing with the required Flutter base href. It avoids relying on unsupported Pages rewrites; callback compatibility is an early test. |
| D12 | Proposed | Enforce permissions in RLS and transactional functions. Privileged Edge Functions are narrowly scoped to invitation/provisioning and mail. No second general-purpose backend server. |
| D13 | Proposed | Short title + High/Normal/Low priorities; owner/admin entry edits and archiving; no self-review. These fill unspecified product details and may be adjusted at the relevant step. |
| D14 | Proposed | Active/archive are queue lifecycle states, not provider-verified PR states. Review signals are local indicators, not GitHub approvals. |
| D15 | Proposed | Operator bootstraps teams/initial admins; team admins manage invitations and roles. Prevent last-admin removal and cross-team admin authority. |
| D16 | Proposed | Review theme/layout locally first, then validate invitation/security design before building the full queue. |
| D17 | Proposed | Use revision checks and bounded refresh, not continuous full-list polling or Realtime. This reduces bandwidth and implementation scope. |
| D18 | Proposed | Keep theme locally, minimize session persistence, and review sibling apps. A path shares an origin; document the residual risk rather than promise subdomain-level isolation. |
| D19 | Deferred | Paid subscriptions, automatic provider integration, notifications, attachments, AI review, and self-service organization creation. |
| D20 | Implemented in P02, 2026-09-14 | Use `go_router` 18.0.1 and `shared_preferences` 2.5.5 with a pinned lockfile; no extra state-management package. Theme uses the async preferences API. The shell has public fictional presentation fixtures and no fake identity or login bypass. This realizes the local shell without granting or simulating server access. |

## Alternatives evaluated

P02 package references: [go_router](https://pub.dev/packages/go_router), [shared_preferences](https://pub.dev/packages/shared_preferences), checked 2026-09-14. Resolved versions were verified against the installed Flutter 3.47.4 / Dart 3.13.3 SDK. Provider, pricing, and product proposals have not been promoted to confirmed requirements by implementing the shell.

Cloudflare Access/Workers/D1 could offer an inexpensive code-login design, but it no longer matches the owner's confirmed magic-link and existing-hosting choices. No Cloudflare DNS changes are planned. Turnstile can still be used independently for CAPTCHA.

Supabase's built-in testing email service does not satisfy ordinary team delivery. Resend via the hook is the proposed production sender, with free quotas and explicit abuse controls. A $25/month Supabase upgrade is a separate future decision, not automatic.

Do not rename this repository to fix a Pages URL without an explicit decision. If adding a directory to the existing site's build is unsuitable, prepare the exact alternative publishing arrangement and explain its effects first.

## Maintaining this log

When a decision changes, record the date, reason, affected requirements, and superseded decision. Update Product/Architecture/Costs/Next as appropriate. Do not mark a proposal confirmed simply because implementation work has started.
