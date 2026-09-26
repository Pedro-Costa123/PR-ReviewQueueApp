import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/queue/entry_queue.dart';
import 'package:pr_review_queue/features/queue/entry_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const hosts = LinkHosts(pr: ['git.example.test'], jira: ['jira.example.test']);
EntryData row({String owner = 'self'}) => {
  'id': 'entry',
  'team_id': 'atlas',
  'submitter_id': owner,
  'title': 'Durable PR',
  'pr_url': 'https://git.example.test/team/repo/pull/1',
  'jira_url': 'https://jira.example.test/browse/DEMO-1',
  'sprint_goal': false,
  'priority': 'medium',
  'version': 1,
};

class TestEntries implements EntryRepository {
  @override
  Future<EntryData> lifecyclePage(
    String teamId, {
    bool deleted = false,
    EntryData? cursor,
  }) async => {
    'entries': <EntryData>[],
    'has_more': false,
    'next_cursor': null,
  };
  @override
  Future<void> lifecycle(
    String teamId,
    EntryData entry,
    String action, {
    String? reason,
  }) async {}
  @override
  Future<EntryData> activity(String teamId, String entryId) async => {
    'entry_version': 1,
    'submitter_id': 'self',
    'state': 'active',
    'comments': <EntryData>[],
    'reviews': <EntryData>[],
    'comments_count': 0,
    'looks_good_count': 0,
    'comments_left_count': 0,
    'my_signal': null,
  };
  @override
  Future<void> comment(
    String teamId,
    String entryId,
    String body, {
    EntryData? original,
  }) async {}
  @override
  Future<void> deleteComment(
    String teamId,
    String entryId,
    EntryData comment,
  ) async {}
  @override
  Future<void> review(
    String teamId,
    String entryId,
    int version,
    String? signal,
  ) async {}
  @override
  String get userId => 'self';
  List<EntryData> entries = [row()];
  EntryData? saved, original;
  String? error;
  bool offline = false;
  int deletions = 0;
  @override
  Future<LinkHosts> hosts(String teamId) async {
    if (offline) throw StateError('offline');
    return const LinkHosts(
      pr: ['git.example.test'],
      jira: ['jira.example.test'],
    );
  }

  @override
  Future<QueueSnapshot> list(String teamId) async =>
      QueueSnapshot(teamId == 'atlas' ? List.of(entries) : [], 7);
  @override
  Future<void> move(
    String teamId,
    String entryId,
    String targetId, {
    required bool after,
    required int revision,
  }) async {}
  @override
  Future<void> save(
    String teamId,
    EntryData fields, {
    EntryData? original,
  }) async {
    if (error != null) {
      throw PostgrestException(message: 'failure', code: error);
    }
    saved = fields;
    this.original = original;
    entries = [
      {...row(), ...fields},
    ];
  }

  @override
  Future<void> delete(String teamId, EntryData entry) async {
    deletions++;
    entries = [];
  }
}

Future<void> showQueue(
  WidgetTester tester,
  TestEntries repository, {
  bool admin = false,
  String team = 'atlas',
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1100));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EntryQueue(
            repository: repository,
            teamId: team,
            admin: admin,
            members: const [
              {'user_id': 'self', 'active': true, 'name': 'Owner'},
            ],
            viewProfile: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('enterprise URL grammar canonicalizes known resources and rejects hostile inputs', () {
    expect(
      normalizeEnterpriseLink(
        'HTTPS://GIT.EXAMPLE.TEST:443/Team/Repo/pull/42/files/?tab=files#diff',
        hosts.pr,
        'pr',
      ),
      'https://git.example.test/team/repo/pull/42',
    );
    expect(
      normalizeEnterpriseLink(
        'https://jira.example.test/jira/browse/demo-42/?x=1',
        hosts.jira,
        'jira',
      ),
      'https://jira.example.test/jira/browse/DEMO-42',
    );
    for (final url in [
      'http://git.example.test/a/b/pull/1',
      'https://me@git.example.test/a/b/pull/1',
      'https://git.example.test.evil.test/a/b/pull/1',
      'https://git.example.test:444/a/b/pull/1',
      'https://git.example.test./a/b/pull/1',
      'https://git.example.test/a/b/pull/1\n',
      'https://git.example.test/a/b/pull/1\\x',
      'https://git.example.test/a/%2e%2e/pull/1',
      'https://git.example.test/a/b/pull/0',
      'https://git.example.test/a/b/pull/1?x=%0a',
      'https://git.example.test/a/b/pull/1?x=%5c',
      'javascript:alert(1)',
    ]) {
      expect(normalizeEnterpriseLink(url, hosts.pr, 'pr'), isNull, reason: url);
    }
  });
  testWidgets('create validates fields and saves explicit defaults', (
    tester,
  ) async {
    final repo = TestEntries();
    await showQueue(tester, repo);
    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    expect(find.text('Enter a title of 1–160 characters.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'New PR',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'PR link'),
      'https://git.example.test/a/b/pull/2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jira link'),
      'https://jira.example.test/browse/DEMO-2',
    );
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(repo.saved?['priority'], 'medium');
    expect(repo.saved?['sprint_goal'], false);
    expect(find.text('New PR'), findsOneWidget);
    expect(find.text('Entry saved.'), findsOneWidget);
  });
  testWidgets('Critical priority saves with the original edit version', (
    tester,
  ) async {
    final repo = TestEntries();
    await showQueue(tester, repo);
    await tester.tap(find.text('Edit entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(repo.saved?['priority'], 'critical');
    expect(repo.original?['version'], 1);
    expect(find.text('CRITICAL'), findsOneWidget);
  });
  testWidgets(
    'conflict preserves draft and prevents blind retry; duplicate remains editable',
    (tester) async {
      final repo = TestEntries()..error = 'PT409';
      await showQueue(tester, repo);
      await tester.tap(find.text('Edit entry'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Unsaved draft',
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved draft'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save entry'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      repo.error = '23505';
      await tester.tap(find.text('Edit entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(
        find.text('This PR is already in this team’s active queue.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save entry'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'member actions reflect ownership; deletion requires confirmation',
    (tester) async {
      final repo = TestEntries()..entries = [row(owner: 'someone')];
      await showQueue(tester, repo);
      expect(find.text('Edit entry'), findsNothing);
      expect(find.text('Delete entry'), findsNothing);
      await showQueue(tester, repo, admin: true);
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.deletions, 0);
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete entry'));
      await tester.pumpAndSettle();
      expect(repo.deletions, 1);
      expect(find.text('Durable PR'), findsNothing);
    },
  );
  testWidgets(
    'refresh failure clears private rows and a team switch clears previous results',
    (tester) async {
      final repo = TestEntries();
      await showQueue(tester, repo);
      expect(find.text('Durable PR'), findsOneWidget);
      repo.offline = true;
      await tester.tap(find.text('Refresh queue'));
      await tester.pumpAndSettle();
      expect(find.text('Durable PR'), findsNothing);
      expect(find.textContaining('Could not load the queue'), findsOneWidget);
      repo.offline = false;
      await showQueue(tester, repo, team: 'orbit');
      expect(find.text('Durable PR'), findsNothing);
    },
  );
  testWidgets(
    'narrow editor scrolls and keyboard Escape cancels without saving',
    (tester) async {
      final repo = TestEntries();
      await showQueue(tester, repo);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Save entry'), findsNothing);
      expect(repo.saved, isNull);
    },
  );
}
