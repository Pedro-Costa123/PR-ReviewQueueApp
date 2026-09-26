# P12 release preparation and recovery

Updated: 2026-09-26. P13 is selected and in progress; actual evidence is in STATUS. Follow
[HOSTING](HOSTING.md) for exact destination/provider settings and
[STATUS](STATUS.md) and [PILOT](PILOT.md) for actual results. Source remains private.

## Release inputs and reproducibility

Use Flutter **3.47.4 / 9584c6713b**, Dart **3.13.3**, Node **26.5.0**, npm
**11.17.0**, and the locked Supabase CLI **2.117.0**. Keep both application
lockfiles. A newer CLI is available; upgrading it is not part of this item.
`npm ci --offline` was tested with the existing cache, both in an isolated
directory and in `backend/` after stopping the running CLI. Missing cached
dependencies require an ordinary reviewed `npm ci`, never an unpinned update.

From `frontend/`:

```powershell
powershell.exe -NoProfile -File tool/build-release.ps1 -Mode production-check
powershell.exe -NoProfile -File tool/build-release.ps1 -Mode local
powershell.exe -NoProfile -File tool/build-release.ps1 -Mode disconnected
node tool/release-manifest.cjs verify disconnected
node tool/serve.cjs
```

Each build command enforces the SDK/Node versions and lockfile, cleans generated
output, builds twice with root base href and bundled renderers, prepares headers,
checks assets, and compares file hashes and release inputs. It retains packages
under ignored `releases/<mode>/web` plus two pass manifests and `manifest.json`.
Manifests include base Git revision/dirty state, source-input hash, public-config
hash, lockfiles, all migration hashes and each asset's SHA-256/size. The input hash
covers frontend source/web/release tools and backend functions/migrations/package
files; docs/test/operator changes are reviewed separately in the Git diff.
Do not edit release inputs during the two passes. Timestamps are not compared.

`production-check` uses fixed fictional public values and remains disconnected on
loopback. `local` uses existing ignored `.env.local.json` and Mailpit. Neither
package can pass `verify` for upload. `disconnected` contains no connection config
and is the first-release fallback. The build has no fake authenticated identity;
the existing public demo routes contain only fictional presentation data.

For P13, prepare ignored `.env.production.json` privately
from the [public example](../frontend/.env.production.json.example), using the
existing project's public key and the new production widget's public site key.
Only then run `build-release.ps1 -Mode production` and
`node tool/release-manifest.cjs verify production`. The public-config validator
rejects secret fields, admin JWTs, trial mode, wrong APIs and dummy site keys.
No real production config/widget was created in P12. Repeat browser acceptance
with the actual artifact in P13. Preserve the reviewed revision and manifest;
record any dirty state explicitly and commit the reviewed inputs before launch.

Upload **only the verified `frontend/build/web` folder**, using manual dashboard
Direct Upload. `verify` compares that folder with the retained package and current
release inputs/config. Never upload `releases/` (which contains manifests and
multiple modes), the repository, backend, env files, fixtures or backups.

## Static origin security

The custom bootstrap registers no service worker. Preparation removes the
generated worker, and preflight rejects its presence. CanvasKit is bundled;
the only third-party script allowed is the lazy Turnstile loader. No analytics,
external fonts, integrations or private-data offline cache is added. A top-level
`404.html` prevents Pages' implicit SPA fallback; hash routes still use `/`.

Generated `_headers` applies to all static responses: `no-store`, `no-referrer`,
`nosniff`, `X-Frame-Options: DENY`, restricted permissions and a CSP that denies
objects, forms and framing. `connect-src` names only self, Turnstile and the
configured exact Supabase origin. No wildcard backend, preview-host permission,
inline script or JavaScript `unsafe-eval` is allowed. Flutter requires inline
styles and WebAssembly compilation; those are explicit CSP allowances. Blob
workers/images are allowed for the renderer. Local preview applies the same
headers. Use a real narrow viewport: the old narrow iframe cannot frame the app.
Stock Flutter app icons remain cosmetic placeholders, not private content.

P13 must inspect actual Pages response headers, renderer and live Turnstile
behavior before invitations. Local CSP tests cannot prove live CAPTCHA, HTTPS or
provider delivery. A first deployment has no legacy worker to migrate. For any
future worker migration, explicitly test removal/update behavior rather than
assuming `no-store` removes previously registered workers.

## Verification gate

From `backend/`, start the local stack and function server, then reset and run
the suites sequentially (the foundation suite loads fictional fixtures):

```powershell
npm start
npm run functions
# In another terminal, after the runtime is ready:
npm run reset
npm test
npm run test:auth
npm run test:onboarding
npm run test:queue
npm run test:ordering
npm run test:activity
npm run test:lifecycle
npm run test:refresh
npm run lint
node node_modules/supabase/dist/supabase.js db advisors --local --type security --level info --fail-on warn
node tool/rehearse-restore.cjs
node tool/check-release-source.cjs --history
```

Also run Flutter analysis/tests, the callback/Turnstile/release-policy Node tests,
and `test/preview.test.cjs` while preview serves a prepared artifact. Inspect
desktop/narrow light/dark UI, Tab/Enter, callback cleanup before explicit
confirmation, reload/sign-out, missing paths, framing denial and absent workers.
No real mail belongs in these checks. The source audit scans non-ignored files
and reachable Git-history blobs for credential patterns, verifies Markdown links/
fences/whitespace, and compares private local secret values against built bytes
without printing values. This is a heuristic audit, not proof of all possible
secret absence; inspect the diff and artifact inventory too. Preserve LICENSE.

## Restricted backup and restore

The executable rehearsal refuses linked projects, remote Docker engines,
non-loopback APIs, containers from other checkouts and non-fictional Auth emails.
It exports `public`, `private`, `auth`, `extensions` and `supabase_migrations` from
one consistent `pg_dump` snapshot, including owners/ACLs. No rows are printed.
The archive exists as plaintext only in process/pipe memory; the on-disk copy is
Windows DPAPI CurrentUser encrypted in ignored `backups/p12_restore_<random>/`.
The directory's inherited ACL is replaced with current-operator and SYSTEM
access before writing. A checksum/evidence file is restricted with the archive.

It decrypts and restores transactionally to a fresh randomly named database in
the **same local cluster**, with no API/Auth service pointed at it. The local
internal admin preserves managed Auth owners/default grants; the normal hosted
`postgres` user cannot restore those wholesale. No new role grant is made.
It compares every included table's count/content hash, effective RLS/policies/
function grants/search paths, and runs anonymous/foreign/revoked/forged ownership
denials. Only its scratch database is dropped afterward; the source and encrypted
evidence remain. Owner-only ACLs are normalized using PostgreSQL's defaults when
comparing equivalent explicit versus implicit grants.

This verifies a **local logical restore**, not a hosted disaster recovery or a
fresh machine. DPAPI is bound to this Windows user/machine: copying this file off
the machine alone is insufficient. It is not a production backup destination.
There is no backup/purge scheduler and no record/audit expiry.

For durable-data use, the operator must record a restricted, encrypted
off-device backup location, separate recovery-key custody and a successful
decrypt test. Keep the pre-migration checkpoint and latest verified checkpoint;
do not automatically delete older checkpoints in this non-purging item. Proposed
pilot cadence: before every migration/release and after each day with changes;
maximum expected loss is the interval since the last verified backup, and restore
time is not yet measured for hosted data. Monitor storage with the same 60%/80%
thresholds; a retention/storage change requires a later decision.

**P13 owner exception (D37):** the owner has no off-device setup and explicitly
accepts data loss for now. The data-backup/decrypt gate is waived only for the
disposable pilot; do not claim hosted recovery or silently restore this as a
completed checkpoint. A restricted local references-only configuration inventory
exists; provider credentials remain in their stores. Keep the full procedure above
for later durable-data admission. No purge or budget reset is authorized.

For an authorized hosted backup/recovery, use the provider's
[CLI backup/restore procedure](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
with its managed-schema filtering, not the local superuser command. Obtain the
connection privately from the existing credential store, with no password on a
command line, in shell history, chat or committed file. Prepare the restricted
encrypted destination first; stop application writes/invitations/mail before
the checkpoint so separate schema/data exports describe one maintenance window.
Export roles, application schema/data **including private operational tables**,
Auth data, and migration history; inspect the archive table inventory before
accepting it. Do not assume the default CLI schema dump includes managed Auth
schema customizations. Preserve UUIDs/verified-email state; never pre-confirm
users or replay invitations as a restore substitute.

Recover into an isolated compatible target only after explicit authorization
for that target. Apply the reviewed schema/migration history and managed Auth
procedure; restore data and validate constraints, counts, retained deleted/archive
activity, minimal audit, grants/RLS and the denial matrix before pointing clients
at it. Keep sending disabled. Never reset email budgets/idempotency because an
older restore lacks recent sends: reconcile recent reservations or leave mail
closed through the 31-day budget window. Reapply revocations newer than the
checkpoint and invalidate old sessions before reopening. Do not roll back the
P12 admission retirement or authorization to regain availability.

A database dump does **not** restore Edge deployments, provider settings, secret
stores, signing/encryption keys, CAPTCHA secrets, DNS, Pages deployments or any
Storage object bytes. This app stores no objects. Maintain a separate private
configuration inventory with recovery locations (not secret values): Auth
signup/expiry/rates/CAPTCHA/Site URL, hook/signing/Resend credentials, sender and
tracking, Edge runtime/config, Turnstile widgets, exact private enterprise hosts,
provider MFA/recovery access and production public config. Recover/rotate secrets
through provider stores; preserve `auth.pedro-costa.dev` and its DNS records.
Different projects/keys can invalidate Auth sessions and encrypted provider data;
verify those separately. Keep sign-in unavailable until this is resolved.

## P13 rollout and rollback checklist (execution recorded in STATUS)

1. Review P12 diff/evidence; select P13 explicitly. Recheck Free plans/quotas,
   eligibility and the **unreserved** `pr-review-queue` name. If allocation differs,
   stop and update all exact-origin guards/config/tests together. No DNS change.
2. Take the restricted pre-migration backup/config checkpoint above, subject to
   the explicit disposable-pilot D37 exception. Confirm zero
   active trial admissions and keep mail/invitations closed during transition.
3. Review and apply only missing migrations, in order, through
   `20260926174044_retire_trial_admission.sql`. At P12 hosted had P03-P05 only;
   P13 has now applied the seven missing migrations (see HOSTED_AUTH mapping).
   Verify the mail function no longer references admissions and all historical
   admission rows remain revoked.
4. Deploy the reviewed Edge functions; apply the exact [HOSTING](HOSTING.md)
   checklist privately. Remove `TRIAL_RECIPIENTS` from production configuration;
   preserve keys/sender, disabled signup, hook verification, CAPTCHA and budgets.
   Bootstrap only an explicitly chosen existing verified identity/team using the
   operator runbook; never reopen the retired admission or use first-user-wins.
   Configure enterprise hosts privately, never in static config or fixtures.
   D37 explicitly selects fictional hosts for the current disposable pilot.
5. Build/verify the real production package, retain the disconnected fallback,
   allocate the exact Pages hostname and manually upload the verified folder.
   Record revision, manifest hash, destination, deployment ID/time and operator.
6. Gate invitations on HTTPS/root/hash routes, actual headers/no worker, exact
   callback/preview denials, fresh CAPTCHA for each attempt, first/returning magic
   links, explicit confirmation, reload/sign-out, server membership/revocation,
   enterprise links and quota headroom. Inspect portfolio/PassGen separately;
   prove their origin cannot read app storage/DOM or control its worker scope.
   Do not move tokens between origins. Inspect Inbox/Junk placement with the
   authorized small pilot; all three P05 messages reached Junk. P13 initial-admin
   mail reached Inbox; other recipients need their own observations.

For a frontend-only failure, roll back to a previous compatible **production**
Pages deployment. For a failed first release, upload the verified disconnected
artifact. These are P13 actions. Stop invitations and configure the hook to fail
closed/disable provider sending through the operator interface if mail is at
risk; merely hiding the frontend does not stop direct Auth/API requests. Do not
disable the hook and fall through to a default sender. Do not enable signup,
weaken RLS, clear budgets or restore trial admission. If the backend is unsafe,
keep it unavailable using provider maintenance/access controls until reviewed.

Static rollback never reverses migrations, Auth, secrets or CAPTCHA settings.
Prefer a forward repair. A database restore can lose newer work/revocations and
needs an explicitly approved checkpoint/target after preserving the current
state. Re-run restore/security gates before reopening. See
[Pages rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/).
