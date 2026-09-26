# Cloudflare Pages hosting plan

Updated: 2026-09-26. Planning only; P11A implementation has not started.

## Confirmed direction

The owner selected **Cloudflare Pages Free**, using an available
`<project>.pages.dev` address instead of the planned personal-domain app URL.
The exact project name/address is still to be chosen and checked for availability.
`pr-review-queue.pages.dev` is only an example, not a reserved or deployed site.

The owner clarified: **keep emailed magic links and the existing sender; change
only the web host**. The verified sender is `auth.pedro-costa.dev`, reconfirmed
read-only in Resend on 2026-09-26. No sender rename or DNS change is planned.
Supabase, Resend, invitations, CAPTCHA and mail budgets retain their existing
roles. OAuth migration is not selected.

The owner requested a new item before P12 and explicitly limited this task to
planning. No application code, local configuration, DNS, provider settings,
repository visibility, deployment, email or billing changes were performed.

## Why this fits

Cloudflare supplies the web hostname, so the app needs no personal-domain DNS
record. A dedicated Pages project preserves a separate browser origin from the
portfolio and PassGen and fits the existing root build and hash routes.
Prebuilt upload allows Flutter to build locally without publishing the source
repository. This is static hosting only; Supabase remains the backend.

GitHub Pages was considered, but project sites inherit a user/organization site's
custom domain when configured. An independent organization would add setup;
Cloudflare Pages is the owner's selected alternative. Current official sources,
free limits and the distinction between website and sender are in
[COSTS](COSTS.md#cloudflare-pages-hosting-recheck-2026-09-26).

## P11A — Prepare the Cloudflare Pages hosting change

**Depends on:** completed local P11. **State:** ready when selected; not started.

**Scope:** prepare the local app/configuration and runbooks for a stable production
`pages.dev` origin while retaining base href `/`, hash routes and the existing
magic-link flow. Confirm the exact hostname before fixing release settings.
Keep local/trial and release configurations distinct; never allow `*.pages.dev`
or arbitrary preview URLs as authentication callbacks.

Inventory all affected settings together: frontend auth gate, early callback
cleanup, sender callback validation, Supabase Site URL/redirect allowlist,
invitation-function origin checks and Turnstile hostname. Prepare provider changes
as a reviewable checklist; apply them only at the separately selected deployment.
Update the planned build/upload workflow for `frontend/build/web` and document
rollback. No portfolio build, custom-domain CNAME or Namecheap web record is needed.

Prefer a prebuilt Direct Upload workflow; choose the exact manual/CI method in
this item. A Direct Upload project cannot switch to Git integration in place.
Check actual artifact file count and maximum asset size against the chosen upload
method. Keep deployment manual until P13 is selected. Do not add Pages Functions,
Workers services, paid plans or a DNS-provider migration.

**Acceptance:** root assets/hash routes work in the release preview; relevant
Flutter and callback/hook checks pass; browser/keyboard checks cover login,
callback cleanup, explicit confirmation and sign-out. Old personal-domain,
unexpected-origin and preview-host callbacks are denied. Record exact planned
provider settings and prove existing invitation/team/mail protections remain.
These local checks are not evidence of live HTTPS or hosted login success.

**Boundary:** stop for owner review. No cloud project creation, deployment,
hosted provider changes, DNS changes, real mail, public-source change or P12 work.

## Namecheap records: keep versus optional cleanup

Read-only Resend inspection on 2026-09-26 reports the sender verified, sending
enabled, receiving disabled and the following four records verified. Names below
are the **Host** field within Namecheap's `pedro-costa.dev` zone.

| Action | Type | Host | Value / reason |
| --- | --- | --- | --- |
| Keep | TXT | `resend._domainkey.auth` | Existing `p=...` public key; DKIM verification. Do not replace the value. |
| Keep | MX | `send.auth` | `feedback-smtp.eu-west-1.amazonses.com`, priority 10; sending return-path/bounce handling. |
| Keep | TXT | `send.auth` | `v=spf1 include:amazonses.com ~all`; sending authorization. |
| Keep | CNAME | `rsend.auth` | `send.forge.rmta.net`; Resend currently lists it as a verified SPF record. |
| Keep | TXT | `_dmarc.auth` | `v=DMARC1; p=none;`; sender DMARC, reconfirmed by DNS lookup on 2026-09-26. |
| May remove if present and used only for this abandoned app URL | CNAME | `reviews` | The old plan targeted `Pedro-Costa123.github.io`; unnecessary for pages.dev or email. |
| Keep | Existing website/mail/verification records | `@`, `www`, other hosts | Portfolio, PassGen, other mail and GitHub ownership verification are outside this change. |

Do not remove the `send.auth` MX merely because receiving is disabled: it belongs
to the sending configuration. The four-record list is from live Resend state;
DMARC was also checked with `Resolve-DnsName`. A lookup of
`reviews.pedro-costa.dev` returned NXDOMAIN (name does not exist), so no published
record there was found to remove. The full Namecheap zone has not been inspected;
other cleanup candidates are not asserted. Retain GitHub domain-verification TXT
records used by the portfolio.
No wildcard or blanket `auth` record deletion is proposed. See
[Resend's Namecheap guide](https://resend.com/docs/knowledge-base/namecheap) and
[DMARC guide](https://resend.com/docs/dashboard/domains/dmarc).

## Subsequent items

- **P12:** release/security checks, reproducible build and publishing preparation,
  backup/restore rehearsal, current quota checks and reviewed rollout/rollback.
- **P13:** explicitly selected deployment and small pilot. Create/verify the exact
  Pages address, apply the prepared callback/Turnstile settings, test live HTTPS,
  magic links, origin isolation and provider usage. Preserve the existing sender,
  portfolio and PassGen. Keep P05 trial admission revoked.

No implementation or live application validation is claimed by this planning update.
