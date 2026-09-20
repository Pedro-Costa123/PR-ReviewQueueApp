import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/auth/auth_controller.dart';
import 'package:pr_review_queue/features/auth/auth_repository.dart';
import 'package:pr_review_queue/features/auth/sign_in_page.dart';
import 'package:pr_review_queue/features/auth/challenge.dart';

class FakeAuth implements AuthRepository {
  @override
  String? email;
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => events.stream;
  int requests = 0, confirmations = 0;
  bool fail = false;
  bool challengeFails = false;
  @override
  Future<void> requestLink(String email, {String? captchaToken}) async {
    requests++;
    if (challengeFails) throw const ChallengeException();
    if (fail) throw StateError('private provider detail');
  }

  @override
  Future<void> confirmLink(String tokenHash) async {
    confirmations++;
    if (fail) throw StateError('expired');
    email = 'member@example.test';
    events.add(null);
  }

  @override
  Future<void> signOut() async {
    email = null;
    events.add(null);
  }
}

void main() {
  test(
    'verification failure has a recoverable message and allows another request',
    () async {
      final repository = FakeAuth()..challengeFails = true;
      final controller = AuthController(repository, hostedTrial: true);
      await controller.requestLink('member@example.test');
      expect(controller.message, contains('Verification did not complete'));
      expect(controller.busy, isFalse);
      repository.challengeFails = false;
      await controller.requestLink('member@example.test');
      expect(controller.message, AuthController.acknowledgement);
      controller.dispose();
      await repository.events.close();
    },
  );
  test(
    'link waits for user confirmation, is consumed once and can be cancelled',
    () async {
      final repository = FakeAuth();
      final controller = AuthController(repository, callback: 'provider-token');
      expect(repository.confirmations, 0);
      expect(controller.hasPendingLink, isTrue);
      await controller.confirmLink();
      await controller.confirmLink();
      expect(repository.confirmations, 1);
      expect(controller.email, 'member@example.test');
      await controller.signOut();
      expect(controller.email, isNull);
      controller.dispose();
      final cancelled = AuthController(repository, callback: 'provider-token');
      cancelled.cancelLink();
      await cancelled.confirmLink();
      expect(repository.confirmations, 1);
      cancelled.dispose();
      await repository.events.close();
    },
  );
  test(
    'request acknowledgement does not expose eligibility or provider errors',
    () async {
      final repository = FakeAuth();
      final controller = AuthController(repository);
      await controller.requestLink('allowed@example.test');
      final accepted = controller.message;
      repository.fail = true;
      await controller.requestLink('uninvited@example.test');
      expect(controller.message, accepted);
      controller.dispose();
      await repository.events.close();
    },
  );
  test('invalid and expired callbacks have recovery messages without token content', () async {
    final repository = FakeAuth()..fail = true;
    final invalid = AuthController(repository, callback: 'invalid');
    expect(invalid.hasPendingLink, isFalse);
    expect(invalid.message, contains('invalid'));
    invalid.dispose();
    final expired = AuthController(repository, callback: 'secret-token');
    await expired.confirmLink();
    expect(expired.message, contains('expired'));
    expect(expired.message, isNot(contains('secret-token')));
    expect(expired.hasPendingLink, isFalse);
    expired.dispose();
    await repository.events.close();
  });
  testWidgets('sign-in validates email and renders pending/signed-in states', (
    tester,
  ) async {
    final repository = FakeAuth();
    final controller = AuthController(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SignInPage(auth: controller)),
        ),
      ),
    );
    await tester.tap(find.text('Send sign-in link'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repository.requests, 0);
    await tester.enterText(find.byType(TextFormField), 'member@example.test');
    await tester.tap(find.text('Send sign-in link'));
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    expect(find.text(AuthController.acknowledgement), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    final pending = AuthController(repository, callback: 'provider-token');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SignInPage(auth: pending)),
        ),
      ),
    );
    expect(repository.confirmations, 0);
    await tester.tap(find.text('Continue sign-in'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as member@example.test'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.dispose();
    await repository.events.close();
  });
}
