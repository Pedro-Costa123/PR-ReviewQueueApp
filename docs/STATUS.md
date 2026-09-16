# Current status

Updated: 2026-09-16.

## What exists

- Original Git repository and MIT license preserved.
- Root README, `.gitignore`, and `AGENTS.md` for incremental implementation and documentation updates.
- Web-only Flutter application under `frontend/`, organized into auth, teams, queue, archive, profiles, and shared code. The frontend remains the P02 demo and is not connected to the backend.
- P03 backend under `backend/`: pinned project-local Supabase tooling, Docker startup/config, migration for profiles/teams/memberships/invitations/entries/comments/reviews and private audit/email tables, explicit grants/RLS, immutable ownership/child-team constraints, guarded membership access changes, and operator bootstrap.
- Nineteen local backend tests cover SQL roles, direct Data API requests, fictional disjoint/multi-team fixtures, JWT/ownership/role forgery, live revocation, private/default grants, initial/last-admin protection, and concurrent membership changes. Fixtures are outside migrations and configured seeds.
- P02 read-only fictional queue for Atlas, empty Orbit team, sign-in/profile/archive placeholders, desktop sidebar and narrow drawer navigation, dark default and saved light preference.
- Frontend dependency/lock files, nine tests, and a loopback-only Node release preview at the required base path. Theme preference is the frontend's only persisted value.
- Product, architecture, decisions, current status, ordered backlog, costs, security, and handoff documents.
- Official-source research on Flutter/static hosting, GitHub Pages, magic-link delivery, backend quotas, and abuse controls.
- Owner's answers recorded: GitHub Enterprise/Jira Enterprise links only; manual updates/archiving; invited work email magic links; €0 target; Namecheap DNS and GitHub Pages at the exact path; sprint/priority group ordering; multiple teams; external hosting allowed.

## What does not exist yet

No frontend login/backend integration, real queue CRUD/reordering/comments/reviews/archive operations, invitation provisioning/claiming UI, guarded email hook/budgets, hosted project, external mail configuration, CI workflow, combined-site release, or production app. The only exposed mutation is the P03 existing-member access RPC. Local Auth and mail capture run as tooling, not as a validated magic-link flow. No cloud accounts/subscriptions, DNS, existing website, or real email delivery changes were made.

P02 and the planning files are tracked in commit `39e9d5d` (`P02 | Local Flutter app shell`). P03 began with a clean worktree; local `main` and the cached `origin/main` reference pointed at that commit. P03 changes are currently uncommitted; this task did not fetch, commit, push, or deploy. Another checkout needs the resulting changes to use this context.

## Repository observations

- Workspace: `C:\Users\pedro\Projects\PR-ReviewQueueApp`.
- Branch inspected: `main`, tracking `origin/main`; initial worktree clean.
- Remote: `git@github.com:Pedro-Costa123/PR-ReviewQueueApp.git`.
- Initial planning commit was `7fa6224` (`Add MIT License to the project`); P03 baseline is `39e9d5d`.
- The repository name differs from the desired Pages path. Publishing through the existing site needs inspection; do not assume a new project Pages toggle gives the exact URL.
- The existing portfolio's source/deployment workflow and repository visibility have not been inspected.

## Local environment observed

| Tool | Observation |
| --- | --- |
| Flutter | `flutter --version` verified 3.47.4 stable at `C:\Users\pedro\flutter`; framework revision `9584c6713b` |
| Dart | `flutter --version` verified 3.13.3 |
| Node.js / npm | Version commands returned v26.5.0 / 11.17.0 |
| Git | Available on PATH |
| Docker | Desktop 4.91.0 / Linux engine 29.8.0 verified in P03; local stack starts, resets, tests, and stops |
| Java | Owner provided JDK 21 path; not needed by the proposed web/backend stack, not tested |
| Supabase CLI | Project-local 2.117.0, pinned in `backend/package.json` and lockfile; Postgres image 17.6.1.167 |

P02 verified the web environment using `flutter doctor -v`, analysis, tests, and release builds. Doctor's only failed category was missing Visual Studio for native Windows development, outside this web-only project. Flutter commands required SDK-cache access outside the workspace. P03 verified the installed Node version against the CLI's documented Node 20+ requirement. CLI cache access, dependency downloads, and Docker operations required sandbox permission; no global Supabase installation or manual system-tool upgrade was performed.

## Decisions still proposed

Supabase/Resend implementation details, title and priority labels, profile email visibility, self-review restriction, edit/archive privileges beyond deletion, operator-created teams, session persistence, and retention defaults. The final hosting choice is confirmed; its exact Pages publishing integration is not yet verified.

Need exact enterprise hostnames before live link validation, and the existing Pages source/workflow before publishing. These do not block P04's local auth work. Existing proposed title/priority/lifecycle schema fields and the operator bootstrap implementation do not promote unrelated product defaults to confirmed requirements.

## Verification

P03 verification on 2026-09-16:

- `npm install`: pinned CLI/lockfile installed successfully; npm reported 0 vulnerabilities. Node 26.5.0/npm 11.17.0 and Docker Desktop/Linux engine were inspected.
- `npm start`: the minimal local stack starts. The wrapper validates the local Docker context and dedicated bridge, reports actual port bindings, and suppresses credential output. No cloud setup or real mail was used.
- `npm run reset`: repeatedly reproduced the complete schema from a clean local database, with no fixture identities seeded. The final tests ran after a clean reset and stack restart.
- `npm test`: **19 passed**, 0 failed/skipped. Tests exercise real PostgREST requests and SQL roles, positive permitted reads, anonymous/outsider/cross-team denials, forged ownership/JWT/metadata, direct-write/upsert denial, private/default function grants, same-token revocation with preserved other-team access, pending-invite revocation, child-team/immutable-key/duplicate constraints, bootstrap script, and last-admin protection.
- Three deterministic concurrent-connection tests passed: competing admin self-demotions, an admin revoked while waiting for the team lock, and direct operator changes at repeatable-read isolation. They verify final state and expected constraint/authorization/serialization errors.
- The first test run found PostgreSQL's global default PUBLIC function execution was not removed by schema-scoped revocation. The migration now revokes both; the regression probe passes. A write-test request was also corrected to include a filter so it exercises database authorization rather than an API WHERE-clause guard.
- `npm run lint`: passed on `public,private` with warnings treated as failures; no schema errors.
- `node --check` passed for the startup wrapper and both test files. Content/whitespace checks passed across 43 non-generated text files; all 41 relative Markdown links resolved and code fences were balanced. The lockfile's CLI pin matches the manifest. `git diff --check` passed, and tracked/new-file diffs were reviewed. The read-only checker required a sandbox retry to launch Git. No frontend code changed, so P02 Flutter/browser checks below were not rerun as P03 evidence.
- `npm run stop`: passed after verification, preserving local fictional data and stopping this project's containers.

Local tooling limitation: Docker Desktop 4.91.0/engine 29.8.0 still reports all-interface port bindings despite Supabase's documented loopback network option. The wrapper explicitly reports this; it does not claim network isolation. Use only a trusted development machine/network with appropriate host firewall restrictions. The local stack is stopped after verification, preserving its fictional database. No production setup was attempted.

P03 is an authorization foundation: all direct queue writes are denied, including owners/admins; queue mutations wait for P07+. Full URL validation, mutation limits, email quotas, invite claiming, and real authentication remain later checks. A revoked member can still read their own profile, but not revoked-team records. Profile email visibility rules and other product defaults remain distinguishable from confirmed requirements.

Planning verification remains recorded in COSTS and the prior documentation. P02 verification on 2026-09-14:

- `flutter --version` and `flutter doctor -v`: web tooling available; native Windows warning as described above.
- `flutter analyze`: passed, no issues.
- `flutter test`: **9 passed**. Coverage includes dark default, persisted light/dark preference across controller instances, unavailable storage, sign-in disabled/no email field, profile/archive/team navigation, six narrow direct/unknown route cases and drawer layout. Initial tests found sidebar/metric label overflow; flexible text fixed it and the full suite passed afterward.
- `flutter build web --release --base-href /PR-Review-App-Queue/ --no-web-resources-cdn`: passed, including the SDK's Wasm dry run. The final JavaScript release bundles rendering resources locally. The initial build without the CDN flag also passed.
- Chrome release preview at `http://127.0.0.1:4173/PR-Review-App-Queue/`: desktop (1920 × 855) and narrow iframe (390 × 844) inspected; light/dark visuals, wrapping, scroll, demo labels, disabled sign-in, profile/archive navigation, empty team, hash-route reload, and saved light theme verified. Keyboard Tab/Enter activation, arrow-key team selection, browser Back, and narrow drawer navigation verified.
- `node --check tool/serve.cjs`: passed. Preview run command is `node tool/serve.cjs` from `frontend/`; Ctrl+C stops it. Full run/build instructions are in [frontend README](../frontend/README.md).
- Local HTTP checks: app HTML, JavaScript, bundled CanvasKit Wasm, and narrow preview returned 200; the slashless base redirected to the trailing slash; unrelated/missing paths returned 404. Generated HTML contains the exact base href. These are local preview checks, not claims about GitHub Pages.
- `dart format --output=none --set-exit-if-changed lib test`: passed, 11 files unchanged. Content checks passed across 33 non-generated text files and 33 relative Markdown links, including balanced code fences and trailing whitespace. `git diff --check` passed for tracked content; new files were also inspected directly/as new-file diffs because the implementation and planning files were untracked at that time. P02 handoff documentation was checked for stale claims.

No backend tests were applicable during P02; P03 results are above. No production checks have been claimed. The SDK's release icon-tree-shaking step warns about an absent Cupertino font family; this app uses Material icons, which rendered correctly in Chrome. Generated Flutter favicon/app icons are still placeholders. Real auth callbacks, shared-origin review, provider quotas, and the combined Pages artifact remain future checks.

## Next

P00-P03 are complete locally. **P03 is ready for review. P04 is next: magic-link flow and guarded email delivery locally**, including mocked delivery and callback/session validation. P04 has not started. See [NEXT](NEXT.md) for its acceptance criteria and stop boundary, and the [backend README](../backend/README.md) for verified commands.
