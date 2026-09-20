import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pr_review_queue/features/auth/auth_repository.dart';
import 'package:pr_review_queue/features/auth/challenge.dart';

void main() {
  test(
    'leaving sign-in while OTP is pending prevents a later fallback challenge',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      var challenges = 0;
      final client = SupabaseClient(
        'https://example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final repository = SupabaseAuthRepository(
        client,
        'http://127.0.0.1:4173/',
        requestChallenge: () async => 'token-${++challenges}',
      );
      final pending = repository.requestLink('member@example.test');
      final rejected = expectLater(pending, throwsA(isA<ChallengeException>()));
      await started.future;
      repository.cancelRequest();
      response.complete(
        http.Response(
          '{"msg":"Signup disabled","error_code":"signup_disabled"}',
          422,
        ),
      );
      await rejected;
      expect(challenges, 1);
      await client.dispose();
    },
  );
  test(
    'failed or empty CAPTCHA prevents Auth calls and fallback sends',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      for (final challenge in <Future<String?> Function()>[
        () async => null,
        () async => '',
        () async => throw const ChallengeException(),
      ]) {
        final repository = SupabaseAuthRepository(
          client,
          'http://127.0.0.1:4173/',
          requestChallenge: challenge,
        );
        await expectLater(
          repository.requestLink('member@example.test'),
          throwsA(isA<ChallengeException>()),
        );
      }
      expect(calls, 0);
      await client.dispose();
    },
  );
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
        'http://127.0.0.1:4173/',
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
              r.url.queryParameters['redirect_to'] == 'http://127.0.0.1:4173/',
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
        'http://127.0.0.1:4173/',
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
