param([ValidateSet('disconnected','local','production','production-check')][string]$Mode = 'disconnected')
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
function Check-Exit { if ($LASTEXITCODE -ne 0) { throw 'Release command failed; no upload approved.' } }
$sdk = flutter --version --machine | ConvertFrom-Json
Check-Exit
if (-not $sdk.frameworkRevision.StartsWith('9584c6713b')) { throw 'Use the reviewed Flutter 3.47.4 revision 9584c6713b.' }
if ($sdk.frameworkVersion -ne '3.47.4' -or $sdk.dartSdkVersion -notlike '3.13.3*') { throw 'Use Flutter 3.47.4 / Dart 3.13.3.' }
node tool/release-manifest.cjs validate $Mode
Check-Exit
flutter pub get --enforce-lockfile
Check-Exit
for ($pass = 1; $pass -le 2; $pass++) {
  flutter clean
  Check-Exit
  flutter pub get --enforce-lockfile
  Check-Exit
  $buildArgs = @('build','web','--release','--base-href','/','--no-web-resources-cdn','--no-pub','--pwa-strategy=none')
  if ($Mode -eq 'production-check') {
    $buildArgs += @('--dart-define=AUTH_MODE=production','--dart-define=SUPABASE_URL=https://abcdefghijklmnopqrst.supabase.co','--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_fictional','--dart-define=TURNSTILE_SITE_KEY=0xFictionalProductionKey12345')
  } elseif ($Mode -ne 'disconnected') { $buildArgs += "--dart-define-from-file=.env.$Mode.json" }
  flutter @buildArgs
  Check-Exit
  node tool/prepare-release.cjs $Mode
  Check-Exit
  node tool/check-pages.cjs
  Check-Exit
  node tool/release-manifest.cjs record $Mode $pass
  Check-Exit
}
node tool/release-manifest.cjs compare $Mode
Check-Exit
