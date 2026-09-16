# Cost and hosting research

Checked: **2026-09-14** using official provider documentation. Prices below are provider-listed USD, before applicable tax or currency conversion. €0 means zero additional service charges on the selected free plans, not free domain renewal or a guarantee of permanent pricing.

## Recommendation for the confirmed requirements

P03 local implementation note, 2026-09-16: project-local Supabase CLI 2.117.0 and a Docker development stack were added. No provider account, hosted project, subscription, DNS, billing, or email-delivery configuration changed. The estimates and provider assumptions below remain the 2026-09-14 research, to recheck at P05/P12. [Current local CLI requirements](https://supabase.com/docs/guides/local-development/cli/getting-started) were checked for tooling compatibility; this is not a fresh verification of hosted pricing.

**GitHub Pages + Supabase Free + Resend Free**, with Cloudflare Turnstile for CAPTCHA. Keep Namecheap DNS. No Cloudflare DNS migration, Cloudflare Access, Workers, D1, VPS, or production Docker service is required by this final proposal.

Supabase supplies Postgres, authentication, row-level security, and small Edge Functions. A guarded Send Email Hook delivers provider-generated magic links through Resend. This keeps email budgets enforceable even when someone calls the public Auth endpoint directly. The hook is available on Free. [Supabase Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks)

| Component | Expected starting cost | Relevant limitation |
| --- | --- | --- |
| Existing GitHub Pages hosting | $0 additional, subject to the account/site's eligibility | Static frontend only; exact path requires integration with the current Pages publishing setup |
| Supabase Free | $0 | 500 MB database, 50,000 monthly active users, 5 GB egress, 500,000 Edge Function invocations; check actual project/organization usage |
| Resend Free | $0 | 3,000 emails/month and 100/day; use a dedicated sending domain and budget |
| Turnstile Free | $0 | Managed bot challenge; integration and provider-side enforcement still need testing |
| Namecheap domain | Existing renewal | No new domain required; renewal cost is not included in this estimate |
| Builds and backups | No new paid service proposed | Local builds/exports initially; CI must stay within the existing account allowance |

Supabase Free can pause after one week of inactivity and does not include automatic backups. These are real operational compromises for a team app. Its paid entry tier starts at $25/month; it is not an incidental €5 upgrade. [Supabase pricing](https://supabase.com/pricing)

Resend's paid entry tier is $20/month. Stay on Free; paid plans can permit additional email charges. [Resend pricing](https://resend.com/pricing)

Turnstile does not require moving DNS to Cloudflare. Confirm the free widget's domain configuration during setup. [Turnstile plans](https://developers.cloudflare.com/turnstile/plans/)

## Why not the other routes?

| Option | Cost position | Decision for this project |
| --- | --- | --- |
| Cloudflare Access + Workers + D1 | Can start at $0; Access Free supports 50 users | Good candidate for emailed codes, but the owner selected magic links, Namecheap DNS, and GitHub Pages. Not selected. |
| Supabase's built-in test email sender | Included but highly limited | Not suitable for inviting normal team users: it only sends to project-team addresses and is limited to 2 messages/hour. Use a configured sender/hook. |
| Supabase Pro + Resend Free | Starts at $25/month | Possible future choice for the inactivity/backup limitations; outside the current €0 target. |
| Paid VM with a database/auth server | Nonzero hosting plus maintenance | No need for patching, backups, TLS, and mail delivery operations when the selected managed free stack fits. No provider-specific VM quote is relied on. |
| Custom magic-link authentication | Hosting might be inexpensive | Rejected: implement application permissions and email budgets, but let a managed provider create and verify login tokens. |

Sources: [Cloudflare plans](https://www.cloudflare.com/plans/), [Access email codes](https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/one-time-pin/), [Supabase email limitations](https://supabase.com/docs/guides/auth/auth-smtp).

## Usage model (estimates, not measurements)

Assume 20 people, 22 working days/month, no files/images stored, no GitHub/Jira API calls, no analytics service, and no Realtime subscription.

- **Email:** two sign-ins/person/workday = `20 × 2 × 22 = 880` emails/month, normally 40/day. Allow room for invitations/retries. The 100/day limit is more likely to matter than 3,000/month.
- **Normal data use:** 60 full queue reads/person/day at an assumed 20 KB each = approximately `20 × 60 × 22 × 20 KB = 528 MB/month`, before authentication, comments, and other traffic.
- **Bad polling design:** downloading that 20 KB queue every minute for 8 hours/person/day would use about **4.22 GB/month** before other traffic, too close to the 5 GB allowance.
- **Planned refresh:** check a small team data revision every minute only while visible, and fetch details when it changes. A 1 KB revision response under that same heavy scenario is about **211 MB/month**, plus changed snapshots. Measure actual payloads and usage during the pilot.
- **Storage example:** 20 new entries/day over 22 days/month for a year = 5,280 entries. At an assumed 10 KB per entry including associated notes/signals, payload is about 53 MB before indexes, Auth, audit data, and database overhead. This is a planning estimate, not a storage guarantee.

Provider dashboards, actual database size, and measured egress decide whether the plan fits. Review at 60% of database/egress allowance, take action at 80%, and review email use above 60 sends/day. Do not add fake activity solely to avoid free-plan pausing.

## Cost-abuse controls

Use free subscriptions without paid add-ons or automatic overages. Supabase says Free users are not charged; excessive use can lead to restrictions. Its Pro Spend Cap only covers specified usage categories and is not a universal euro-denominated ceiling. [Supabase cost control](https://supabase.com/docs/guides/platform/cost-control), [billing FAQ](https://supabase.com/docs/guides/platform/billing-faq)

Proposed application email limits, validated in P04-P05:

- 1 send per recipient per 60 seconds; 5 per hour and 10 per day per recipient.
- 80 sends/project/day and 2,500/project/month, counting invitations, retries, and all allowed email actions. These leave margin under Resend Free. A separate Resend account quota shared with other apps would reduce that margin.
- Reserve quota atomically before the external email call; count ambiguous failures conservatively. Use hook-event and provider idempotency so retries do not send duplicates.
- A signed provider hook must enforce budgets and exact invitations; a browser-only cooldown does not count as a control. Never expose a public arbitrary-recipient email function.
- On limit/provider failure, stop sending, show a retry-later result, and expose a sanitized operator diagnostic. Do not switch to a paid mail route or loop retries.

Enable CAPTCHA in Supabase Auth itself and pass the frontend challenge token. Keep provider verification/rate limits active, limit mutation frequency server-side, paginate reads, and limit text lengths. [Supabase CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha), [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)

This protects the budget but cannot guarantee uninterrupted service under attack. An attacker can still consume request/verification quotas or repeatedly target a known invited address. At €0, quota exhaustion can cause temporary unavailability rather than an unexpected paid upgrade.

## Hosting constraints and upgrade triggers

Flutter builds static web files suitable for static hosting. GitHub Pages is compatible with that output; it cannot run a backend. The exact requested path is not the current source repository name: follow the publishing design in [Architecture](ARCHITECTURE.md). [Flutter web deployment](https://docs.flutter.dev/deployment/web), [GitHub Pages overview](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)

GitHub Pages is not permitted as free hosting for commercial SaaS and cautions against sensitive transactions. The planned use is an internal team utility with authentication handled by Supabase; that is an architectural interpretation, not a guarantee of policy eligibility. If the use becomes commercial or the site's policy fit is uncertain at deployment, resolve it before launch. [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)

Revisit the architecture if inactivity pauses are unacceptable, quotas are routinely tight, automatic managed backups/support become required, or the common browser origin is unsuitable. Present a current priced alternative before changing subscriptions. Recheck all free-plan eligibility, existing account consumption, email domain verification, and pricing at P05 and P12.
