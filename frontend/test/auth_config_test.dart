import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/auth/auth_config.dart';

void main() {
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
