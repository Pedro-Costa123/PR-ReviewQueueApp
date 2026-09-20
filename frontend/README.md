# Frontend

The Flutter Web shell has read-only fictional queues and optional local Supabase
authentication. P05 adds an explicitly configured hosted trial with a lazy themed
Turnstile dialog. Queue writes remain unavailable. Use [AUTH](../docs/AUTH.md) for
local login or [HOSTED_AUTH](../docs/HOSTED_AUTH.md) for the controlled trial.

Verified SDK: **Flutter 3.47.4 stable / Dart 3.13.3** on Windows. Only the web platform is scaffolded. Application dependencies and the lockfile are pinned; no global backend tooling is required.

## Run the verified release preview

The production target is now `https://reviews.pedro-costa.dev/` (confirmed
2026-09-18), with base href `/`. P04A migrated and tested the local preview and
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

Twenty Flutter tests and twelve JavaScript callback/widget tests cover auth,
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
the demo queue is unchanged. P06 is next when selected after review.
