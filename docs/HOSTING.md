# Cloudflare Pages hosting plan

Updated: 2026-09-26. P13 deployed at the exact Pages address; pilot in progress.

P12's build, security, restricted backup/restore and activation/rollback runbook
is [RELEASE](RELEASE.md). Use its two-clean-build commands and final integrity
verification for publishing preparation. Current results are in STATUS. P13
rechecked availability and allocated exactly `pr-review-queue.pages.dev` through
the manual dashboard. The historical P11A/P12 boundaries below describe those
earlier items; the current owner instruction authorizes P13 deployment.
The production deployment is live; see [PILOT](PILOT.md) for the deployment ID,
artifact and observed browser gates. The availability-only statements below
are historical P11A/P12 evidence, not the current allocation state.

## Confirmed direction and original pre-allocation check

The owner selected **Cloudflare Pages Free**, using an available
`<project>.pages.dev` address instead of the planned personal-domain app URL.
**Exact planned address: `https://pr-review-queue.pages.dev/`.** On 2026-09-26,
Cloudflare's authenticated Pages Direct Upload form validated `pr-review-queue`
with a checkmark and displayed “Your project will be deployed to
pr-review-queue.pages.dev.” The account project list was empty. Neither **Create
project** nor **Deploy site** was clicked, and no files were uploaded.
This confirms availability at that check, not reservation or ownership. Recheck
at P13: if Cloudflare assigns a suffix or the name is taken, stop and revise all
exact-origin settings/tests together before applying provider settings.

The owner clarified: **keep emailed magic links and the existing sender; change
only the web host**. The verified sender is `auth.pedro-costa.dev`, reconfirmed
read-only in Resend on 2026-09-26. No sender rename or DNS change is planned.
Supabase, Resend, invitations, CAPTCHA and mail budgets retain their existing
roles. OAuth migration is not selected.

The owner subsequently selected P11A for local implementation only. No DNS,
hosted provider setting, repository visibility, deployment, real email or billing
change is authorized. The existing P05 trial admission remains revoked.

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

**Depends on:** completed local P11. **State:** implemented locally; see
[STATUS](STATUS.md) for checks and review boundary. P12 subsequently completed
local release preparation; P13 has now deployed the result (see PILOT).

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

## Prepared configuration and activation checklist

These are the **P13 activation settings** prepared in P11A/P12. P13 applied them
after release review; [PILOT](PILOT.md) records the actual deployment and limits.
The hosted project still has only P03-P05 migrations and the trial hook. P06-P11
remain local. No production public-key file or production widget was created.

| Surface | Prepared target / retained control |
| --- | --- |
| Pages | Free, Direct Upload, project `pr-review-queue`; production root `https://pr-review-queue.pages.dev/`; no custom domain, Functions, Worker, Git integration or analytics |
| Flutter | `AUTH_MODE=production`; existing hosted `SUPABASE_URL` and public `SUPABASE_PUBLISHABLE_KEY`; new production public `TURNSTILE_SITE_KEY`; base `/`, hash routes |
| Frontend gate | Only the exact HTTPS origin and `/` without query/userinfo; production rejects loopback and preview aliases; local/trial reject Pages |
| Early callback | Only loopback root or exact production root can hand off a token hash; Dart separately enforces build mode; clean URL before Flutter, one-time in-memory handoff, explicit Continue; no token forwarding |
| Supabase Auth Site URL | `https://pr-review-queue.pages.dev/` |
| Additional redirect allowlist | Empty; Site URL supplies the exact default. Never add `*.pages.dev`, branch/hash preview aliases, loopback, old personal domain or portfolio paths to production |
| Auth protections | Keep signup/anonymous/manual linking disabled, email confirmation enabled, 900-second token validity, existing rate limits and refresh replay protection |
| Send Email Hook | Existing signed hook, `AUTH_EMAIL_MODE=production`, `APP_CALLBACK_URL=https://pr-review-queue.pages.dev/`; exact `redirect_to` equality before reservation; preserve hook secret, Resend key and existing mailbox at `auth.pedro-costa.dev` in provider storage |
| Trial configuration | Keep admissions revoked. P12 supplies the retirement migration; P13 must apply it and remove `TRIAL_RECIPIENTS` from production environment. Never re-admit the old trial identity as a hosting convenience |
| `invite-member` | Same email configuration supplies exact CORS origin `https://pr-review-queue.pages.dev`; bearer identity and guarded admin/invitation RPCs remain authoritative, including requests with no Origin |
| Turnstile | Separate managed production widget with hostname `pr-review-queue.pages.dev`, no pre-clearance; public site key in frontend, secret entered directly in Supabase Auth; retain the separate loopback trial widget |
| Sender/DNS | Existing verified sender and Namecheap records below unchanged; tracking stays off; no website DNS record required |

Turnstile hostname entries also cover subdomains, so widget configuration alone
does **not** exclude Pages preview aliases. Exact app/callback/hook/origin checks
provide that boundary. Never use `pages.dev` as the widget hostname.
[Turnstile hostname behavior](https://developers.cloudflare.com/turnstile/additional-configuration/hostname-management/),
[Supabase redirects](https://supabase.com/docs/guides/auth/redirect-urls).

Tracked examples contain placeholders/instructions only:
[frontend public config](../frontend/.env.production.json.example) and
[backend checklist](../backend/.env.production.example). Copy the frontend example
to ignored `.env.production.json` only for a separately reviewed release. Never
put service-role, hook, Resend or Turnstile secrets in a Dart define or Pages asset.
Never bulk-upload the backend example over existing provider secrets.

## Build, local preview and manual upload

**Selected method:** manual dashboard Direct Upload of the `frontend/build/web`
folder. It fits the measured artifact without installing Wrangler or exposing
the repository. No CI/deploy workflow is added. Direct Upload cannot be switched
to Git integration in place. Re-run the preflight after every final rebuild.

From `frontend/`, disconnected root preview:

```powershell
flutter build web --release --base-href / --no-web-resources-cdn
node tool/prepare-release.cjs disconnected
node tool/check-pages.cjs
node tool/serve.cjs
```

For local real-provider/captured-mail verification, use the existing
[AUTH](AUTH.md) setup, add `--dart-define-from-file=.env.local.json` to the build,
and use `node tool/prepare-release.cjs local` in place of `disconnected` so the
CSP allows the exact local API.
Open `http://127.0.0.1:4173/`; hash-route reload stays at the root. Only local
Mailpit receives fictional `@example.test` mail. The production mode deliberately
does not connect on loopback; do not weaken its gate for a local browser test.

Future release build, **after P12 review and production public config preparation**:

```powershell
flutter build web --release --base-href / --no-web-resources-cdn --dart-define-from-file=.env.production.json
node tool/prepare-release.cjs production
node tool/check-pages.cjs
```

The read-only checker counts actual files and largest bytes, enforces dashboard
limits (1,000 files, 25 MiB per file), checks root/early-script ordering and stale
callback assets, and rejects symlinks, env files, CNAME, Functions and `_worker.js`.
It performs no network call/upload and is not a secret audit or release approval.
P12 adds the strict checks and reproducible packaging in RELEASE; the commands
above are a single-build preview only. Publish only after its two-pass comparison
and final verifier. Metadata is prepared; generic icons remain cosmetic.
No artifact is upload-authorized by P12.

In explicitly selected P13, use **Workers & Pages > Create application > Continue
to Pages > Drag and drop** (not the Worker static-upload flow). Recheck the name,
create the Pages project, verify the exact assigned hostname, and upload only the
reviewed `frontend/build/web` folder as a production deployment. Do not upload
the repository root, `.env` files, backend, local mail or database fixtures.
If the assigned hostname differs, do not apply callbacks or deploy a connected
artifact until guards/config/tests are updated and reviewed. No CNAME, Namecheap
website record, portfolio artifact or public-source change is needed.

## Rollback and remaining release boundary

Before P13, retain the reviewed revision and artifact plus a disconnected build.
For a frontend regression after a successful production release, select its
previous compatible **production** deployment in Pages > Deployments > actions >
Rollback to this deployment. Preview deployments are not rollback targets.
For a failed first release with no prior target, use the prepared disconnected
artifact and stop mail/invitation activity through the reviewed operator plan.
Do not redirect tokens to the old domain or turn signup on to recover access.
[Cloudflare rollback](https://developers.cloudflare.com/pages/configuration/rollbacks/).

Static rollback does not roll back Supabase migrations, Auth settings, secrets or
Turnstile. Keep revoked admission and authorization intact; restore only reviewed
compatible settings, otherwise leave sign-in unavailable. P12's restricted
database/Auth/config restore plan is in RELEASE; satisfy its hosted gates before rollout.

P13 must verify actual assigned hostname/HTTPS, exact redirects and preview-host
denials, CAPTCHA/fresh tokens, first and returning-user links with explicit
confirmation, reload/sign-out, server membership, real private enterprise links,
portfolio/PassGen origin separation, sender delivery/Inbox placement and quotas.
Local tests below do not prove those live properties. Do not send mail to chase
Inbox placement during P11A. The existing three Junk deliveries remain unresolved.

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

No live application validation is claimed by the local preparation.
