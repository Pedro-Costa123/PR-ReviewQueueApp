import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/auth/auth_config.dart';

void main() {
  test('production requires its exact root, explicit mode and public hosted credentials', () {
    AuthConfig? resolve({
      String mode = 'production',
      String api = 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
      String key = 'sb_publishable_fictional',
      String siteKey = '0x12345678901234567890',
      String page = productionAuthCallback,
    }) => AuthConfig.resolve(
      mode: mode,
      api: api,
      key: key,
      siteKey: siteKey,
      page: Uri.parse(page),
    );
    final config = resolve()!;
    expect(config.production, isTrue);
    expect(config.requiresChallenge, isTrue);
    expect(config.hostedTrial, isFalse);
    expect(config.callback, productionAuthCallback);
    for (final mode in ['local', 'hosted-trial', '', 'preview']) {
      expect(resolve(mode: mode), isNull);
    }
    for (final page in [
      'http://127.0.0.1:4173/',
      'https://reviews.pedro-costa.dev/',
      'https://preview.pr-review-queue.pages.dev/',
      'https://abcdef12.pr-review-queue.pages.dev/',
      'https://other.pages.dev/',
      'https://pr-review-queue.pages.dev.evil.test/',
      'http://pr-review-queue.pages.dev/',
      'https://pr-review-queue.pages.dev:8443/',
      '${productionAuthCallback}index.html',
      '$productionAuthCallback?code=x',
      'https://user@pr-review-queue.pages.dev/',
    ]) {
      expect(resolve(page: page), isNull, reason: page);
    }
    expect(resolve(page: '$productionAuthCallback#/teams/atlas'), isNotNull);
    expect(resolve(api: 'http://127.0.0.1:54321'), isNull);
    expect(resolve(key: 'sb_secret_forbidden'), isNull);
    expect(resolve(siteKey: '1x00000000000000000000AA'), isNull);
    expect(resolve(siteKey: ''), isNull);
  });
  test('hosted trial needs explicit mode, public key, real site key and exact loopback root', () {
    AuthConfig? resolve({
      String mode = 'hosted-trial',
      String? api,
      String key = 'sb_publishable_fictional',
      String siteKey = '0x12345678901234567890',
      String page = 'http://127.0.0.1:4173/',
    }) => AuthConfig.resolve(
      mode: mode,
      api: api ?? 'https://${'a' * 20}.supabase.co',
      key: key,
      siteKey: siteKey,
      page: Uri.parse(page),
    );
    expect(resolve()!.hostedTrial, isTrue);
    expect(resolve(mode: 'local'), isNull);
    expect(resolve(mode: 'production'), isNull);
    expect(resolve(api: 'https://evil.example.test'), isNull);
    expect(resolve(api: 'http://127.0.0.1:54321'), isNull);
    expect(resolve(key: 'sb_secret_forbidden'), isNull);
    expect(resolve(siteKey: ''), isNull);
    expect(resolve(siteKey: '1x00000000000000000000AA'), isNull);
    for (final page in [
      'https://reviews.pedro-costa.dev/',
      'http://localhost:4173/',
      'http://127.0.0.1:4173/old/',
      'http://127.0.0.1:4173/?code=x',
      'http://user@127.0.0.1:4173/',
    ]) {
      expect(resolve(page: page), isNull, reason: page);
    }
  });
}
