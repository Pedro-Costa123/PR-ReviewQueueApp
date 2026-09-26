# P13 deployment and pilot record

Updated: 2026-09-26. Deployment is live; P13 is at its review checkpoint with
the small pilot started and multi-day acceptance incomplete.
Only P13 is selected. Stop at its review boundary; no subsequent work or
background monitoring is authorized by this record.

## Deployment

- Destination: <https://pr-review-queue.pages.dev/>. Cloudflare allocated this
  exact name without a suffix after the fresh availability check.
- Method: manual dashboard Direct Upload of only `frontend/build/web`.
- Deployment: `af95cb9d-f008-4fc7-bc39-837c2045b46a`, successful on 2026-09-26
  at 21:51 Europe/Lisbon (20:51 UTC); operator: repository owner with agent assistance.
- Source inputs: committed `c24ff7a`; working tree contains P13 documentation
  updates, explicitly recorded as dirty in the manifest. No application input
  or dependency upgrade was included.
- Production manifest SHA-256:
  `e098af893ba8470a702b51042d591114028727324954a3cac7306864d6c154a3`.
  Two clean builds matched: 43 files, 42,411,856 bytes. Dashboard processes
  `_headers` separately and lists 42 uploaded assets. Ignored review package and
  disconnected fallback remain under `releases/`.
- Seven missing reviewed migrations applied in order; original three retained.
  Exact hosted mapping is in [HOSTED_AUTH](HOSTED_AUTH.md). Reviewed mail hook v4
  and invitation function v1 are active. No P05 admission was reopened.

## Recovery and pilot scope

Owner D37 explicitly accepts data loss and waived off-device backup for this
disposable pilot. The ACL-restricted local `backups/p13-config/recovery.md`
contains configuration/store references only. No hosted export, decrypt drill,
fresh-machine provider recovery, or off-device recovery is claimed. Before
durable company data, complete the original [RELEASE](RELEASE.md) recovery gate.

The owner chose the existing verified initial-admin identity and two pilot
recipients privately. The team is `Pilot`; fictional private allowlist hosts
are `git.example.test` and `jira.example.test`, as explicitly requested.
Actual enterprise host navigation cannot be validated with these placeholders.
Only fictional queue records should be used for this pilot. Contacts, tokens,
provider secrets and real company links must remain out of repository files.

## Evidence collected

- HTTPS root and five key assets return 200 with hashes matching the verified
  package and the expected security headers. HTTP redirects to the exact HTTPS
  root; missing routes, env-file and service-worker requests return 404.
- Chrome renders the app at the correct origin, secure context, zero service
  worker registrations and no controller. Portfolio-origin attempts to read
  the app window's DOM and storage both raise `SecurityError`. Temporary test
  window/reference removed. Portfolio and `/PassGen/` remain reachable.
- Unsigned hook, unauthenticated invitations, anonymous RPC/table access,
  missing-CAPTCHA Auth sends and preview/old-origin invitation requests deny.
  Fourteen public/private tables retain RLS and clients have no direct writes.
- Production managed Turnstile completed without an interactive challenge.
  Initial-admin mail delivered at 20:56 UTC; owner confirmed **Inbox** placement.
  Opening the link left the clean root URL at explicit confirmation; keyboard
  Continue then opened the private workspace. This is one recipient observation,
  not a claim that every provider will place pilot mail in Inbox.
- Profile completion, fictional entry creation and plain-text comment persisted.
  Low/Medium/High/Critical choices are present and owner self-review is disabled.
- Admin keyboard reorder, archive, restore, soft delete and deleted recovery
  passed. The original comment survives; audit retains create/archive/restore/
  delete/recover events. Two fictional active entries and one comment remain.
  Both themes render; reload preserves the signed-in workspace, light preference
  and saved ordering. Production sign-out returns to the public sign-in screen.
- Hosted SQL-role checks pass for positive member/peer-signal access and denials
  of self-review, direct ownership writes, nonmember/foreign-team access, member
  edits/archive/restore of another owner's entry, deleted-list access and recovery.
  Revocation denies RLS/RPC reads with the same member identity claims. All test
  mutations, including signal/deletion/revocation, were rolled back; this is
  server SQL-role evidence, not a member-browser stale-JWT test. Final checks
  confirm both actual members stay active and no synthetic review signal remains.
- The actual deployment-specific preview host renders disconnected demo mode,
  with sign-in disabled; it cannot initialize the production auth flow.
- Final Resend usage: 2/100 daily and 5/3,000 monthly. Application reservations:
  2 in 24 hours, 5 in 31 days, all sent; zero active trial admissions.
  Existing budgets remain 60 seconds / 5 per hour / 10 per day per recipient,
  80 per 24 hours and 2,500 per 31 days project-wide. No quota-exhaustion mail
  traffic was generated.
- Callback/Turnstile/release-policy tests: 15 passed. Production manifest and
  source/history checks passed. Earlier full local P12 suites remain separate
  historical evidence, not newly executed hosted tests.
- Final `check-release-source.cjs --history`: 142 files, 22 Markdown files,
  214 relative links, 411 history blobs and one exact local-secret comparison;
  no findings, original license hash retained. `release-manifest.cjs verify
  production` and `git diff --check` passed. Node's sandboxed Git subprocesses
  returned EPERM; approved read-only retries completed successfully.

## Remaining acceptance and findings

The initial admin and User1 are active. User1's invitation was delivered and
claimed; the owner reports profile completion and **Junk** placement. User1's
browser was outside the connected Chrome session, so member UI acceptance is
owner-observed; server permissions were separately exercised as above.

User2's seven-day Member invitation is saved/provisioned, but Auth `/resend`
returned **429 email rate limit exceeded** before the hook or Resend. No retry
loop, quota reset or cap increase was used. Retry the saved invitation after
the provider sending window resets; do not reprovision the identity. A subsequent
returning-user magic-link check also remains for that later session.

Actual usage and feedback from 2-3 users across multiple days remain pending;
one execution cannot satisfy that gate. Follow up with member-browser revocation,
peer review UI, narrow-screen use, real enterprise hosts (only when selected),
recipient delivery and operator quota observations during the pilot. No automatic
monitoring or subsequent implementation item was started.

Existing UI still labels the header `LOCAL PREVIEW` even when signed in to the
live backend. Flutter also attempts external fallback fonts for missing glyphs;
CSP blocks these and a few decorative link glyphs render as boxes. Record these
pilot findings without weakening CSP or claiming the console is warning-free.

No repository visibility, DNS, paid service, integration, git push or purge
change. Retention, private hosts, server membership/ownership, no self-review,
owner/admin archive and restore, and admin-only deleted recovery remain the
reviewed requirements. See [SECURITY](SECURITY.md) for hosted advisor findings.

## Human pilot observation record

For each actual session, record date, anonymized participant label, task,
result and issue without emails or company URLs. Exercise first/returning
sign-in, queue create/edit/reorder, peer signals, local comments, archive and
restore, owner/admin limits, both themes and narrow screens. Operator checks
delivery/usage and revocation; never clear quota history or purge records.
Review collected findings with the owner before declaring P13 complete.

| Date | Participant | Observed result |
| --- | --- | --- |
| 2026-09-26 | Initial admin | Inbox delivery, explicit confirmation, profile, queue/comment, lifecycle, ordering, themes and reload checks |
| 2026-09-26 | User1 | Invitation delivered to Junk; profile completed and membership claimed, reported by owner and corroborated by hosted membership |
| 2026-09-26 | User2 | Invitation saved; delivery blocked by Auth rate limit, no mail sent |
