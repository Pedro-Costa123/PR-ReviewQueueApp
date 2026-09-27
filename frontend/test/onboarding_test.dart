import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/teams/onboarding_page.dart';
import 'package:pr_review_queue/features/teams/onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entry_test.dart' show TestEntries;

class TestOnboarding implements OnboardingRepository {
  @override
  String get userId => 'self';
  bool complete = true, admin = true, offline = false, duplicate = false;
  int claims = 0, saves = 0, sends = 0;
  String? viewed, changedTeam;
  @override
  Future<void> claimInvites() async {
    claims++;
    if (offline) throw StateError('offline');
  }

  @override
  Future<List<RecordData>> teams() async => [
    {'id': 'atlas', 'name': 'Atlas', 'role': admin ? 'admin' : 'member'},
    {'id': 'orbit', 'name': 'Orbit', 'role': 'member'},
  ];
  @override
  Future<RecordData> profile(String id) async {
    viewed = id;
    return {
      'user_id': id,
      'email': '$id@example.test',
      'name': complete || id != 'self'
          ? (id == 'self' ? 'My profile' : 'Teammate')
          : null,
      'username': complete ? 'member' : null,
    };
  }

  @override
  Future<void> saveProfile(String name, String username) async {
    if (duplicate) {
      throw const PostgrestException(message: 'unique', code: '23505');
    }
    saves++;
    complete = true;
  }

  @override
  Future<List<RecordData>> members(String teamId) async {
    changedTeam = teamId;
    return [
      {
        'user_id': 'teammate',
        'name': '$teamId person',
        'email': 'teammate@example.test',
        'active': true,
        'role': 'member',
      },
    ];
  }

  @override
  Future<List<RecordData>> invites(String teamId) async => [];
  @override
  Future<void> invite(String teamId, String email, String role) async {
    sends++;
  }

  @override
  Future<void> revoke(String invitationId) async {}
  @override
  Future<void> setAccess(
    String teamId,
    String userId,
    String role,
    bool active,
  ) async {}
}

Future<void> show(
  WidgetTester tester,
  TestOnboarding repo, {
  TestEntries? entries,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OnboardingPage(
            repository: repo,
            signOut: () async {},
            entries: entries,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('repeated refresh keeps one team selector and connected queue', (
    tester,
  ) async {
    final repo = TestOnboarding();
    await show(tester, repo, entries: TestEntries());
    for (var i = 0; i < 3; i++) {
      expect(tester.takeException(), isNull);
      expect(find.text('Your team'), findsOneWidget);
      expect(find.text('Review queue'), findsOneWidget);
      expect(find.text('Durable PR'), findsOneWidget);
      await tester.tap(find.text('Refresh teams'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Your team'), findsOneWidget);
    expect(find.text('Durable PR'), findsOneWidget);
    await tester.tap(find.text('Atlas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orbit').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your team'), findsOneWidget);
    expect(find.text('Durable PR'), findsNothing);
    expect(find.text('No entries in this view.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'first login claims once and requires profile completion before team controls',
    (tester) async {
      final repo = TestOnboarding()..complete = false;
      await show(tester, repo);
      expect(repo.claims, 1);
      expect(find.text('Invite teammate'), findsNothing);
      await tester.tap(find.text('Complete profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'New Member',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'new-member',
      );
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(find.text('Profile saved.'), findsOneWidget);
      expect(find.text('Invite teammate'), findsOneWidget);
      expect(repo.claims, 1);
    },
  );
  testWidgets(
    'team switch replaces roster and removes admin controls; teammate profile opens',
    (tester) async {
      final repo = TestOnboarding();
      await show(tester, repo);
      expect(find.text('atlas person'), findsOneWidget);
      await tester.tap(find.text('Atlas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orbit').last);
      await tester.pumpAndSettle();
      expect(repo.changedTeam, 'orbit');
      expect(find.text('atlas person'), findsNothing);
      expect(find.text('Invite teammate'), findsNothing);
      expect(find.text('Make admin'), findsNothing);
      await tester.tap(find.text('orbit person'));
      await tester.pumpAndSettle();
      expect(find.text('teammate@example.test'), findsOneWidget);
    },
  );
  testWidgets('failed claim clears team content and manual refresh recovers', (
    tester,
  ) async {
    final repo = TestOnboarding()..offline = true;
    await show(tester, repo);
    expect(find.textContaining('Could not load your teams'), findsOneWidget);
    expect(find.text('Invite teammate'), findsNothing);
    repo.offline = false;
    await tester.tap(find.text('Refresh teams'));
    await tester.pumpAndSettle();
    expect(repo.claims, 2);
    expect(find.text('atlas person'), findsOneWidget);
  });
  testWidgets('duplicate username is reported without claiming a save', (
    tester,
  ) async {
    final repo = TestOnboarding()..duplicate = true;
    await show(tester, repo);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.textContaining('username is unavailable'), findsOneWidget);
    expect(find.text('Profile saved.'), findsNothing);
  });
  testWidgets(
    'invite cancel does not send and invalid email stays in the dialog',
    (tester) async {
      final repo = TestOnboarding();
      await show(tester, repo);
      await tester.tap(find.text('Invite teammate'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Work email'),
        'not-email',
      );
      await tester.tap(find.text('Invite & send link'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid work email.'), findsOneWidget);
      expect(repo.sends, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.sends, 0);
    },
  );
}
