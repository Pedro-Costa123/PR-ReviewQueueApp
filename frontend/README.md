# Frontend

The Flutter Web shell has read-only fictional queues and optional local Supabase
authentication. P05 adds an explicitly configured hosted trial with a lazy themed
Turnstile dialog. P07 connects queue writes in the signed-in workspace. Use [AUTH](../docs/AUTH.md) for
local login or [HOSTED_AUTH](../docs/HOSTED_AUTH.md) for the controlled trial.

P06 adds the connected signed-in root workspace: real team selector, profile
completion/edit/view, admin invitations and member controls. Use the
[onboarding runbook](../docs/ONBOARDING.md) for its two-team local preview.
The separate demo queue routes remain fictional. P07 adds real selected-team
entries, validated manual links, Low/Medium/High/Critical priorities, guarded
editing/deletion and retained drafts on conflicts. See [QUEUE](../docs/QUEUE.md)
for its preview and checks. Email is visible only to self/shared active teammates
through the server. P08 adds sprint/priority group headings, admin drag handles
and keyboard move controls with revision conflict recovery. The server orders
before paging; P11 replaces the original 100-entry display limit. No P06-P11 hosted
deployment has been performed. See QUEUE for ordering checks and preview fixtures.

P09 adds expandable comments/review panels: plain text, author edits/deletion,
admin removal, check/X/clear, complete counts and reviewer/time display. Self-review
is prohibited; comments stay allowed. Run `flutter test test/activity_test.dart`;
see [ACTIVITY](../docs/ACTIVITY.md) for the server contract and local QA.

P10 adds Active queue / Archive / admin-only Deleted entries views, explicit
lifecycle confirmation, manual reason/actor/time, read-only retained activity,
25-entry cursor pages and restore/recovery conflict handling. Run
`flutter test test/lifecycle_test.dart`; see [LIFECYCLE](../docs/LIFECYCLE.md).

P11 adds literal title/link search, sprint/priority/submitter filters, 25-entry and
activity pages, last-updated/checked status and a 60-second visible-tab scheduler.
Unchanged revisions avoid full downloads; drafts defer replacement; access/session/
quota failures pause refresh and network errors back off. Narrow layouts and
keyboard/semantic checks use both themes. Run `flutter test test/refresh_test.dart`;
see [REFRESH](../docs/REFRESH.md). No P12 or publication work is included.

Verified SDK: **Flutter 3.47.4 stable / Dart 3.13.3** on Windows. Only the web platform is scaffolded. Application dependencies and the lockfile are pinned; no global backend tooling is required.

## Run the verified release preview

The future production target is an available Cloudflare Pages `pages.dev`
hostname `pr-review-queue.pages.dev` (availability checked, unreserved), with
base href `/`. P11A prepares separate production mode and a read-only
`node tool/check-pages.cjs` dashboard upload preflight; see [HOSTING](../docs/HOSTING.md). P04A tested the local preview and
callback flow together. These commands build the disconnected local demo;
HOSTED_AUTH records the completed P05 trial and its separate configuration.

From `frontend/` in PowerShell:

```powershell
flutter pub get
flutter build web --release --base-href / --no-web-resources-cdn
node tool/serve.cjs
```

Open `http://127.0.0.1:4173/`. Stop the server with Ctrl+C. Node uses only built-in modules. It binds to loopback and serves only `build/web` at `/`, plus a local QA frame at `http://127.0.0.1:4173/__preview/narrow` (390 × 844). The old prefix returns 404 without forwarding tokens. It is not a production server. The final app will publish independently from this repository, without a combined portfolio artifact.

The build flag bundles Flutter rendering resources locally. Hash URLs such as `/#/teams/atlas` require no server route rewrites. Both direct entry and refresh work. The real hosted authentication callback and Pages integration remain later work.

## Checks

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
node --check tool/serve.cjs
node --test test/auth_callback.test.cjs test/turnstile.test.cjs
```

Thirty-two Flutter tests and twelve JavaScript callback/widget tests cover entries, auth,
configuration, cancellation and the existing shell. With the release preview
running, `node --test test/preview.test.cjs` adds three HTTP checks. For isolated
widget QA run `node tool/turnstile-preview.cjs` and open port 4175 (`/narrow` for
a 390 by 844 frame). Public dummy widgets never reach Auth or the release artifact.
See [Status](../docs/STATUS.md) for dated browser/keyboard evidence and limitations.

## Structure and boundaries

- `lib/app.dart`: Material themes and `go_router` hash routes.
- `lib/features/`: auth, teams, queue, archive, and profiles.
- `lib/features/queue/queue_repository.dart`: widget-independent presentation models and a read-only demo repository.
- `lib/shared/`: reusable UI and theme persistence using `SharedPreferencesAsync`.
- `test/`: shell behavior and layout tests; no real identities or mail.

The default demo stores only `pr_review_queue.theme`. The configured P04 preview also persists auth in sessionStorage with memory fallback; SDK cross-tab behavior is documented in AUTH. Theme-storage failures show a warning; unavailable auth storage falls back to memory. There is no fake login, role switch, or backend authorization bypass in any build; demo profiles are public fictional display data. The release artifact is still a demo and is not authorized for publishing.

The generated Flutter favicon/app icons remain temporary. The SDK emits a missing Cupertino font-family warning during icon tree shaking; this shell uses Material icons, which render correctly in the inspected browser. No native-platform tooling is needed.

Product behavior is in [Product](../docs/PRODUCT.md) and architecture in
[Architecture](../docs/ARCHITECTURE.md). P05 is complete for the controlled trial;
the demo queue remains fictional. P06-P11 and P11A are complete locally; review
P11A before selecting P12. No deployment is authorized.
