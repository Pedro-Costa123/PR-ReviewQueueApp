# Cost and hosting research

Checked: **2026-09-14** using official provider documentation. Prices below are provider-listed USD, before applicable tax or currency conversion. €0 means zero additional service charges on the selected free plans, not free domain renewal or a guarantee of permanent pricing.

## Cloudflare Pages hosting recheck (2026-09-26)

**Selected by the owner:** Cloudflare Pages Free at an available `pages.dev`
address for the frontend, retaining Supabase Free and existing Resend magic-link
email. P11A validated `pr-review-queue.pages.dev` as available in the authenticated
Direct Upload form; it is unreserved. The account project list was empty. Account
eligibility/remaining quotas must still be rechecked at release. No new project,
paid feature, subscription or deployment.
The personal website-domain requirement is superseded; sender DNS and its existing
domain renewal remain. This does not eliminate all personal-domain use.

Cloudflare lists static asset requests as free and unlimited when they do not
invoke Functions. Free Pages lists 500 builds/month, one concurrent build,
20,000 files and a 25 MiB per-file maximum. Direct Upload accepts prebuilt assets
at `<project>.pages.dev`; dashboard upload has a 1,000-file limit, while Wrangler
supports 20,000. Direct Upload cannot switch to Git integration in place. P11A
selected manual dashboard upload; no Functions or Wrangler dependency is needed.
[Static pricing](https://developers.cloudflare.com/pages/functions/pricing/),
[Pages limits](https://developers.cloudflare.com/pages/platform/limits/),
[Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

Rechecked those official hosting sources for P11A on **2026-09-26**. The local
configured JavaScript release contains **42 files**, **42,411,949 bytes** total;
largest is `canvaskit/canvaskit.wasm`, **7,284,602 bytes**, below 25 MiB
(26,214,400 bytes). `node tool/check-pages.cjs` measures the current artifact and
enforces the 1,000-file dashboard limit. Rebuilds change totals; rerun before any
upload. These are disk bytes, not billed transfer, deployed size or account quota.
No CI, subscription, automatic overage or paid service was added. Static rollback
and exact settings are in [HOSTING](HOSTING.md); backend/email budgets are unchanged.

GitHub Free Pages requires public publishing repositories and project sites
inherit the account site's custom domain when configured. An independent
organization was an alternative; the owner chose Cloudflare instead.
[GitHub domain behavior and eligibility](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/about-custom-domains-and-github-pages).

Moving the frontend does not replace email-sender verification. Resend's shared
test domain sends only to the account email; Supabase's default mail is limited
to project-team recipients and currently two messages/hour. The owner reaffirmed
the existing verified sender after considering those constraints. Read-only
Resend inspection confirmed `auth.pedro-costa.dev` and four verified records;
see [HOSTING](HOSTING.md) for the Namecheap keep/remove table.
[Resend test sender](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain),
[Supabase test mail](https://supabase.com/docs/guides/auth/auth-smtp).

Supabase pricing was also rechecked: Free retains 500 MB database, 5 GB egress,
50,000 MAU and 500,000 Edge invocations. Social OAuth is available on Free but is
not selected; there is no authentication migration in this plan.
[Supabase pricing](https://supabase.com/pricing).
Older dated research below is historical where it assumes a personal web domain
or GitHub Pages. Backend/email budgets and P11 payload estimates remain applicable.

## P11 payload check (2026-09-26)

Official [Supabase pricing](https://supabase.com/pricing) rechecked: Free still
lists 5 GB egress and 500 MB database. No plan/provider/deployment assumption or
account setting changed. This is local measurement, not hosted billed usage.

The P11 integration fixture measured uncompressed JSON bodies: scalar revision
**1 byte** at its small local revision (digit count grows), a 25-entry page
**14,256 bytes**, and 25 comments plus 25 reviewers **8,527-8,528 bytes**. Entry
links/titles and comment lengths change these sizes. HTTP headers, TLS, preflight,
authentication, people/host reads, compression and rendering assets are excluded.
No request bodies, JWTs or real company data were logged for measurements.

At 20 users x 22 days x 8 visible hours, 60-second checks mean **211,200 revision
requests/month**. Budgeting 1 KB per check including an illustrative overhead
allowance gives **211.2 MB/month**. At 60 changed snapshots/person/day, measured
queue bodies add **376.36 MB/month**; if each also loads one measured activity page,
add **225.14 MB**, totaling about **813 MB** before the other traffic above.
For comparison, a full measured queue body every minute would consume **3.01 GB**
before activity and overhead. More open panels/tabs and maximum-length comments
increase usage; hidden tabs stop polling and failures back off. A worst-case
25-comment page alone can carry 50,000 Unicode characters, far above this fixture.

These are extrapolations, not quotas or a zero-cost guarantee. Keep the existing
60%/80% monitoring thresholds, mutation/email budgets and no-upgrade policy.
Read traffic uses Data API RPCs, not new Edge calls or Realtime subscriptions.
Retained records/audit still consume database space; P11 adds no purge. Measure
actual provider egress/database growth during a separately authorized pilot.

## P06 recheck (2026-09-21)

Before invitation provisioning, official [Supabase pricing](https://supabase.com/pricing)
still lists 500,000 Free Edge invocations. [Resend pricing](https://resend.com/pricing)
still lists $0 for 3,000 emails/month, 100/day and three domains.
[Turnstile plans](https://developers.cloudflare.com/turnstile/plans/) still lists
20 free widgets, ten hostnames per widget and unlimited challenges. Provider,
DNS, Pages and zero-additional-service assumptions are unchanged.

P06 adds one authenticated provisioning Edge call per admin invite/retry and
reuses the existing budgeted Auth mail route. Creating an unconfirmed identity
does not itself send email. Onboarding mutations have a 30/minute per-identity
database budget; delivery retains the stricter P04 rolling budgets. Validation
used only local Auth/Mailpit, so no hosted delivery, deployment or new measured
provider usage is claimed. No paid add-on or upgrade was enabled.

## P05 recheck (2026-09-18)

Official pricing rechecked before hosted setup:
[Supabase Free](https://supabase.com/pricing) still lists 500 MB database,
50,000 MAU, 5 GB egress and 500,000 Edge invocations, with two active projects,
inactivity pausing and no automatic backups. The connected organization reports
Free and the selected existing project is in Frankfurt. Schema setup added no
fixtures/users. On 2026-09-20, the organization's Free usage dashboard showed
25.87 MB database size (summary 0.027/0.5 GB), 1/50,000 MAU,
2/500,000 Edge invocations, 0.00/5 GB displayed egress, and zero Storage/Realtime
usage. No quota exceeded or overage billing. These rounded/delayed metrics can
lag recent trial requests by an hour or more; they are not per-request accounting.

[Resend Free](https://resend.com/pricing) lists 3,000 emails/month, 100/day and
three domains; paid entry remains $20/month. The owner-approved sender domain is
verified. On 2026-09-19 the dashboard confirmed Free, 0/100 daily and 0/3,000
monthly transactional emails used, one of three domains, and pay-as-you-go off.
On 2026-09-20, the first controlled send produced one delivered message, zero
failures/bounces and one charged application reservation. The owner reported Junk
placement. This single observation does not establish reliable inbox placement.
The second controlled request also produced one message in Junk and brought the
application's sent-reservation total to two; its link successfully signed in.
The refreshed Resend dashboard confirmed 2/100 daily and 2/3,000 monthly usage,
one of three domains, pay-as-you-go off; metrics reported two delivered and zero
failed/bounced messages.
Final controlled totals on 2026-09-20: three sent/delivered, zero failed/bounced,
and three application reservations. All three landed in Junk. The temporary mail
admission was revoked after testing; no additional sends were made for placement.

[Turnstile Free](https://developers.cloudflare.com/turnstile/plans/) supports
20 widgets, ten hostnames per widget and unlimited challenges. The owner created
one managed loopback widget, without pre-clearance or a DNS-provider change.
No paid plan, add-on or automatic upgrade was enabled. The successful second-send
hook returned HTTP 200 in 1,119 ms according to hosted invocation details; this
single observation is not a latency distribution. Keep the conservative app budgets below.

## P04 recheck (2026-09-17)

Official pages rechecked before authentication implementation: [Supabase pricing](https://supabase.com/pricing),
[Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks), [Resend pricing](https://resend.com/pricing),
and [Turnstile plans](https://developers.cloudflare.com/turnstile/plans/). Send Email
Hooks remain available on Free; Supabase lists 500,000 free Edge invocations;
Resend Free lists 3,000 emails/month and 100/day. The proposed free-plan architecture
and zero-additional-service-cost target are unchanged. No account, subscription,
billing, DNS or real mail setup was performed. Account eligibility/consumption must
still be verified at P05.

P04 enforces conservative rolling windows of 24 hours and 31 days for the daily
and monthly application budgets below, including unknown failures. The tested
sender is local Mailpit only; no Resend API calls or hosted costs occurred.

## Historical hosting recheck (2026-09-18; superseded above)

The owner selected **`https://reviews.pedro-costa.dev/`**, hosted independently from this app's repository on GitHub Pages with Namecheap DNS. The €0 additional-service target is unchanged: this uses the existing domain and a subdomain record, not a new domain or paid Supabase custom domain. GitHub Free supports Pages from public repositories; check the actual account/repository eligibility before publishing. A visibility change is future work. [GitHub custom-domain eligibility](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/about-custom-domains-and-github-pages), [Namecheap subdomains](https://www.namecheap.com/support/knowledgebase/article.aspx/9776/2237/how-to-create-a-subdomain-for-my-domain/)

The combined portfolio artifact and repository-name/path workaround are superseded. The additional implementation work is a local root-path/callback migration (P04A), followed by the planned hosted setup and independent Pages release. This recheck covers hosting/domain assumptions only; backend/email quotas retain their dated research above. No subscription, DNS, repository visibility, or deployment setting changed.

## Original recommendation (2026-09-14; frontend hosting superseded above)

P03 local implementation note, 2026-09-16: project-local Supabase CLI 2.117.0 and a Docker development stack were added. No provider account, hosted project, subscription, DNS, billing, or email-delivery configuration changed. The estimates and provider assumptions below remain the 2026-09-14 research, to recheck at P05/P12. [Current local CLI requirements](https://supabase.com/docs/guides/local-development/cli/getting-started) were checked for tooling compatibility; this is not a fresh verification of hosted pricing.

**GitHub Pages + Supabase Free + Resend Free**, with Cloudflare Turnstile for CAPTCHA. Keep Namecheap DNS. No Cloudflare DNS migration, Cloudflare Access, Workers, D1, VPS, or production Docker service is required by this final proposal.

Supabase supplies Postgres, authentication, row-level security, and small Edge Functions. A guarded Send Email Hook delivers provider-generated magic links through Resend. This keeps email budgets enforceable even when someone calls the public Auth endpoint directly. The hook is available on Free. [Supabase Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks)

| Component | Expected starting cost | Relevant limitation |
| --- | --- | --- |
| App-specific GitHub Pages hosting | $0 additional, subject to the account/repository's eligibility | Static frontend at reviews.pedro-costa.dev; publish this app independently |
| Supabase Free | $0 | 500 MB database, 50,000 monthly active users, 5 GB egress, 500,000 Edge Function invocations; check actual project/organization usage |
| Resend Free | $0 | 3,000 emails/month and 100/day; use a dedicated sending domain and budget |
| Turnstile Free | $0 | Managed bot challenge; integration and provider-side enforcement still need testing |
| Namecheap domain/subdomain | Existing renewal | Use the existing domain's reviews CNAME; no additional domain purchase proposed; renewal is excluded |
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

Flutter builds static web files suitable for the selected Cloudflare Pages host. Keep the app at `/` independently of the repository name; follow [HOSTING](HOSTING.md) and [Architecture](ARCHITECTURE.md). [Flutter web deployment](https://docs.flutter.dev/deployment/web)

The former GitHub Pages plan also had commercial-use policy constraints. It is no longer the selected frontend host. Check Cloudflare's current eligibility/terms and actual account quotas before publication; the planning recheck is not an account approval.

Revisit the architecture if inactivity pauses are unacceptable, quotas are routinely tight, or automatic managed backups/support become required. The planned dedicated pages.dev origin preserves separation from the portfolio, subject to implementation and launch checks. Present a current priced alternative before changing subscriptions. Recheck free-plan eligibility, existing account consumption, email domain verification and pricing at release.
