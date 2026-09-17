# Frontend

P02 is implemented: a Flutter Web shell with read-only fictional data, a sign-in placeholder, two demo teams, profile/archive placeholders, responsive navigation, and a saved theme preference. P04 adds optional local Supabase authentication; queue writes remain unavailable. Follow [the P04 runbook](../docs/AUTH.md) to build the authentication preview.

Verified SDK: **Flutter 3.47.4 stable / Dart 3.13.3** on Windows. Only the web platform is scaffolded. Application dependencies and the lockfile are pinned; no global backend tooling is required.

## Run the verified release preview

From `frontend/` in PowerShell:

```powershell
flutter pub get
flutter build web --release --base-href /PR-Review-App-Queue/ --no-web-resources-cdn
node tool/serve.cjs
```

Open `http://127.0.0.1:4173/PR-Review-App-Queue/`. Stop the server with Ctrl+C. Node uses only built-in modules. It binds to loopback and serves only `build/web` beneath the required path, plus a local QA frame at `http://127.0.0.1:4173/__preview/narrow` (390 × 844). It is not a production server or a combined portfolio artifact.

The build flag bundles Flutter rendering resources locally. Hash URLs such as `/PR-Review-App-Queue/#/teams/atlas` require no server route rewrites. Both direct entry and refresh work. The real hosted authentication callback and Pages integration remain later work.

## Checks

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
node --check tool/serve.cjs
node --test test/auth_callback.test.cjs
```

Fifteen Flutter tests and three JavaScript callback tests cover authentication and the existing shell. The original nine tests cover theme default/restoration/storage failure, demo navigation, and narrow/direct/unknown routes. Browser checks covered desktop and narrow layouts, both themes, reload persistence, keyboard activation and team selection, drawer navigation, and browser Back. See [Status](../docs/STATUS.md) for results and limitations.

## Structure and boundaries

- `lib/app.dart`: Material themes and `go_router` hash routes.
- `lib/features/`: auth, teams, queue, archive, and profiles.
- `lib/features/queue/queue_repository.dart`: widget-independent presentation models and a read-only demo repository.
- `lib/shared/`: reusable UI and theme persistence using `SharedPreferencesAsync`.
- `test/`: shell behavior and layout tests; no real identities or mail.

The default demo stores only `pr_review_queue.theme`. The configured P04 preview also persists auth in sessionStorage with memory fallback; SDK cross-tab behavior is documented in AUTH. Theme-storage failures show a warning; unavailable auth storage falls back to memory. There is no fake login, role switch, or backend authorization bypass in any build; demo profiles are public fictional display data. The release artifact is still a demo and is not authorized for publishing.

The generated Flutter favicon/app icons remain temporary. The SDK emits a missing Cupertino font-family warning during icon tree shaking; this shell uses Material icons, which render correctly in the inspected browser. No native-platform tooling is needed.

Product behavior is in [Product](../docs/PRODUCT.md) and architecture in [Architecture](../docs/ARCHITECTURE.md). P04 connects only local authentication; the demo queue is unchanged. The next item is **P05**, after P04 review.
