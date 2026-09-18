import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/auth/local_auth_config.dart';

void main() {
  test(
    'local auth allows only the root loopback preview with local API config',
    () {
      bool allowed(
        String page, {
        String api = 'http://127.0.0.1:54321',
        String key = 'public-test-key',
      }) => allowsLocalAuth(api: api, key: key, page: Uri.parse(page));
      expect(allowed(localAuthCallback), isTrue);
      expect(allowed('$localAuthCallback#/teams/atlas'), isTrue);
      for (final page in [
        '${localAuthCallback}PR-Review-App-Queue/',
        '${localAuthCallback}index.html',
        '$localAuthCallback?code=bad',
        'http://localhost:4173/',
        'http://127.0.0.1:4174/',
        'https://127.0.0.1:4173/',
        'http://user@127.0.0.1:4173/',
        'https://reviews.pedro-costa.dev/',
      ]) {
        expect(allowed(page), isFalse, reason: page);
      }
      expect(allowed(localAuthCallback, key: ''), isFalse);
      expect(
        allowed(localAuthCallback, api: 'https://project.example.test'),
        isFalse,
      );
    },
  );
}
