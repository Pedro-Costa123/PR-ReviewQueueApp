# Frontend

Flutter Web provides fictional public demo queues and an invitation-only connected
workspace. The current deployment is a pilot; see the [project README](../README.md)
for its status and limitations. Only the web platform is scaffolded.

Features include team switching, profiles and invitations, queue editing and
ordering, comments/review signals, archive/recovery, filters and paginated refresh.
Dark mode is the default; the theme preference is saved locally.

## Run a disconnected release preview

Use Flutter 3.47.4 / Dart 3.13.3 and Node.js 26.5.0. From `frontend/`:

```powershell
flutter pub get --enforce-lockfile
flutter build web --release --base-href / --no-web-resources-cdn --no-pub
node tool/prepare-release.cjs disconnected
node tool/serve.cjs
```

Open http://127.0.0.1:4173/; stop with Ctrl+C. The preview binds to loopback and
serves only `build/web`. Hash routes such as `/#/teams/atlas` support direct entry
and reload. Rendering resources are bundled locally. Use the browser's responsive
viewport for narrow layouts: the app's security headers deliberately reject framing.

This demo has no fake signed-in identity or backend access. For local Supabase
login and persisted data, follow [AUTH](../docs/AUTH.md) and the
[backend guide](../backend/README.md). Local mail is captured rather than sent.

## Checks

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
node --test test/auth_callback.test.cjs test/turnstile.test.cjs test/release-policy.test.cjs
```

With the preview running, `node --test test/preview.test.cjs` checks HTTP behavior.
For isolated widget QA, `node tool/turnstile-preview.cjs` serves port 4175; its
dummy widgets never enable application authentication.

## Production builds

The [public configuration template](.env.production.json.example) contains only
placeholders; its populated counterpart remains ignored. Production accepts only
the fixed app origin and requires real public Supabase/Turnstile configuration.
Preview aliases and loopback cannot initialize production authentication.

[RELEASE](../docs/RELEASE.md) describes pinned two-clean-build comparisons, manifests,
exact-API CSP, no-store headers and a bootstrap without a service worker.
`tool/build-release.ps1` creates local review packages, never an upload.
The configured origin and sender remain deployment-specific.

## Structure and boundaries

- `lib/app.dart`: Material themes and hash routing.
- `lib/features/`: auth, teams, queue, archive and profiles.
- `lib/features/queue/queue_repository.dart`: fictional presentation data.
- `lib/shared/`: shared UI and theme persistence.
- `test/`: behavior and layout checks with fictional identities/data.

The demo stores its theme preference. Authenticated builds use sessionStorage
with memory fallback; the SDK can synchronize open same-origin tabs. See
[AUTH](../docs/AUTH.md) for those limits. Backend authorization remains mandatory.
Generic Flutter icons and the known fallback-font issues remain. UI01 removes the
preview badge, clarifies the demo sign-in requirement, aligns entry controls,
adds breathing room to mobile activity panels and fixes repeated team refreshes
locally; deployment is separate.
