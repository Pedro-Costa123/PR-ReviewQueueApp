# Current status

Updated: 2026-09-14.

## What exists

- Original Git repository and MIT license preserved.
- Root README, `.gitignore`, and `AGENTS.md` for incremental implementation and documentation updates.
- Web-only Flutter application under `frontend/`, organized into auth, teams, queue, archive, profiles, and shared code. `backend/` remains a planning README only.
- P02 read-only fictional queue for Atlas, empty Orbit team, sign-in/profile/archive placeholders, desktop sidebar and narrow drawer navigation, dark default and saved light preference.
- Pinned dependency/lock files, nine tests, and a loopback-only Node release preview at the required base path. The theme preference is the only persisted app value.
- Product, architecture, decisions, current status, ordered backlog, costs, security, and handoff documents.
- Official-source research on Flutter/static hosting, GitHub Pages, magic-link delivery, backend quotas, and abuse controls.
- Owner's answers recorded: GitHub Enterprise/Jira Enterprise links only; manual updates/archiving; invited work email magic links; €0 target; Namecheap DNS and GitHub Pages at the exact path; sprint/priority group ordering; multiple teams; external hosting allowed.

## What does not exist yet

No API functions, database migrations, login integration, real queue CRUD/reordering/comments/reviews/archive behavior, hosted project, mail configuration, CI workflow, combined-site release, or production app. The generated local release artifact contains only the demo. No cloud accounts or subscriptions were created. No DNS, existing website, or email delivery changes were made.

The documentation and implementation changes are local and uncommitted/unpushed. Only LICENSE is tracked in the starting commit; the existing planning files and new implementation are untracked. Another checkout needs the resulting commit/branch or files to use this context.

## Repository observations

- Workspace: `C:\Users\pedro\Projects\PR-ReviewQueueApp`.
- Branch inspected: `main`, tracking `origin/main`; initial worktree clean.
- Remote: `git@github.com:Pedro-Costa123/PR-ReviewQueueApp.git`.
- Initial commit inspected: `7fa6224` (`Add MIT License to the project`).
- The repository name differs from the desired Pages path. Publishing through the existing site needs inspection; do not assume a new project Pages toggle gives the exact URL.
- The existing portfolio's source/deployment workflow and repository visibility have not been inspected.

## Local environment observed

| Tool | Observation |
| --- | --- |
| Flutter | `flutter --version` verified 3.47.4 stable at `C:\Users\pedro\flutter`; framework revision `9584c6713b` |
| Dart | `flutter --version` verified 3.13.3 |
| Node.js / npm | Version commands returned v26.5.0 / 11.17.0 |
| Git | Available on PATH |
| Docker | Executable available; engine/local Supabase readiness not tested |
| Java | Owner provided JDK 21 path; not needed by the proposed web/backend stack, not tested |
| Supabase CLI | Not installed or verified by this task; select a project-local version in P03 |

P02 verified the web environment using `flutter doctor -v`, analysis, tests, and release builds. Doctor's only failed category was missing Visual Studio for native Windows development, outside this web-only project. Flutter commands required SDK-cache access outside the workspace, approved during this task. Check backend tooling support for the installed Node version during P03 rather than silently changing system tools.

## Decisions still proposed

Supabase/Resend implementation details, title and priority labels, profile email visibility, self-review restriction, edit/archive privileges beyond deletion, operator-created teams, session persistence, and retention defaults. The final hosting choice is confirmed; its exact Pages publishing integration is not yet verified.

Need exact enterprise hostnames before live link validation, and the existing Pages source/workflow before publishing. These do not block the fictional local shell.

## Verification

Planning verification remains recorded in COSTS and the prior documentation. P02 verification on 2026-09-14:

- `flutter --version` and `flutter doctor -v`: web tooling available; native Windows warning as described above.
- `flutter analyze`: passed, no issues.
- `flutter test`: **9 passed**. Coverage includes dark default, persisted light/dark preference across controller instances, unavailable storage, sign-in disabled/no email field, profile/archive/team navigation, six narrow direct/unknown route cases and drawer layout. Initial tests found sidebar/metric label overflow; flexible text fixed it and the full suite passed afterward.
- `flutter build web --release --base-href /PR-Review-App-Queue/ --no-web-resources-cdn`: passed, including the SDK's Wasm dry run. The final JavaScript release bundles rendering resources locally. The initial build without the CDN flag also passed.
- Chrome release preview at `http://127.0.0.1:4173/PR-Review-App-Queue/`: desktop (1920 × 855) and narrow iframe (390 × 844) inspected; light/dark visuals, wrapping, scroll, demo labels, disabled sign-in, profile/archive navigation, empty team, hash-route reload, and saved light theme verified. Keyboard Tab/Enter activation, arrow-key team selection, browser Back, and narrow drawer navigation verified.
- `node --check tool/serve.cjs`: passed. Preview run command is `node tool/serve.cjs` from `frontend/`; Ctrl+C stops it. Full run/build instructions are in [frontend README](../frontend/README.md).
- Local HTTP checks: app HTML, JavaScript, bundled CanvasKit Wasm, and narrow preview returned 200; the slashless base redirected to the trailing slash; unrelated/missing paths returned 404. Generated HTML contains the exact base href. These are local preview checks, not claims about GitHub Pages.
- `dart format --output=none --set-exit-if-changed lib test`: passed, 11 files unchanged. Content checks passed across 33 non-generated text files and 33 relative Markdown links, including balanced code fences and trailing whitespace. `git diff --check` passed for tracked content; new files were also inspected directly/as new-file diffs because this repository's implementation and planning files are untracked. No stale planning-only/P02-next handoff claims remain.

No backend tests or production checks were applicable or claimed. The SDK's release icon-tree-shaking step warns about an absent Cupertino font family; this app uses Material icons, which rendered correctly in Chrome. Generated Flutter favicon/app icons are still placeholders. Real auth callbacks, shared-origin review, provider quotas, and the combined Pages artifact remain future checks.

## Next

P00, P01, and **P02 are complete**. Review the local shell. **P03 is next: local Supabase schema and team authorization**, with no hosted setup or real mail. P03 has not started. See [NEXT](NEXT.md) for its acceptance criteria and stop boundary.
