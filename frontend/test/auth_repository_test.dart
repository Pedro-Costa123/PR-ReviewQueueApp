import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pr_review_queue/features/auth/auth_repository.dart';

void main() {
  test(
    'unconfirmed fallback uses maintained SDK and a fresh CAPTCHA per call',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/otp')) {
            return http.Response(
              jsonEncode({
                'code': 422,
                'error_code': 'signup_disabled',
                'msg': 'Signups not allowed',
              }),
              422,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      var challenges = 0;
      final repository = SupabaseAuthRepository(
        client,
        'http://localhost/app/',
        requestChallenge: () async => 'challenge-${++challenges}',
      );
      await repository.requestLink(' Member@Example.Test ');
      expect(requests.map((r) => r.url.path), [
        '/auth/v1/otp',
        '/auth/v1/resend',
      ]);
      final first = jsonDecode(requests[0].body) as Map;
      final second = jsonDecode(requests[1].body) as Map;
      expect(first['create_user'], isFalse);
      expect(first['email'], 'member@example.test');
      expect(first['gotrue_meta_security']['captcha_token'], 'challenge-1');
      expect(second['type'], 'signup');
      expect(second['gotrue_meta_security']['captcha_token'], 'challenge-2');
      expect(
        requests.every(
          (r) =>
              r.url.queryParameters['redirect_to'] == 'http://localhost/app/',
        ),
        isTrue,
      );
      await client.dispose();
    },
  );
  test(
    'network and rate failures do not trigger confirmation retries',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'http://localhost:54321',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(
            '{"msg":"Too many requests","error_code":"over_email_send_rate_limit"}',
            429,
          );
        }),
      );
      final repository = SupabaseAuthRepository(
        client,
        'http://localhost/app/',
      );
      await expectLater(
        repository.requestLink('member@example.test'),
        throwsA(isA<AuthException>()),
      );
      expect(calls, 1);
      await client.dispose();
    },
  );
}
