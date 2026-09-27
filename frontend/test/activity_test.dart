import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/queue/entry_activity.dart';
import 'package:pr_review_queue/features/queue/entry_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entry_test.dart' show TestEntries;

class ActivityEntries extends TestEntries {
  EntryData data = {
    'entry_version': 4,
    'submitter_id': 'peer',
    'state': 'active',
    'comments': <EntryData>[],
    'reviews': <EntryData>[],
    'comments_count': 0,
    'looks_good_count': 0,
    'comments_left_count': 0,
    'my_signal': null,
  };
  int writes = 0, reads = 0, deleted = 0;
  int? reviewVersion;
  Completer<EntryData>? pending;
  @override
  Future<EntryData> activity(String teamId, String entryId) async {
    reads++;
    if (offline) throw StateError('offline');
    if (pending != null) return pending!.future;
    return Map.of(data);
  }

  @override
  Future<void> comment(
    String teamId,
    String entryId,
    String body, {
    EntryData? original,
  }) async {
    writes++;
    if (error != null) {
      throw PostgrestException(message: 'failure', code: error);
    }
    this.original = original;
    data['comments'] = <EntryData>[
      {
        'id': 'note',
        'author_id': 'self',
        'body': body,
        'version': (original?['version'] as int? ?? 0) + 1,
        'updated_at': '2026-09-23T09:00:00Z',
      },
    ];
    data['comments_count'] = 1;
  }

  @override
  Future<void> review(
    String teamId,
    String entryId,
    int version,
    String? signal,
  ) async {
    writes++;
    reviewVersion = version;
    if (error != null) {
      throw PostgrestException(message: 'failure', code: error);
    }
    data['my_signal'] = signal;
    data['looks_good_count'] = signal == 'looks_good' ? 1 : 0;
    data['comments_left_count'] = signal == 'comments_left' ? 1 : 0;
  }

  @override
  Future<void> deleteComment(
    String teamId,
    String entryId,
    EntryData comment,
  ) async {
    deleted++;
    original = comment;
    data['comments'] = <EntryData>[];
    data['comments_count'] = 0;
  }
}

Future<void> showActivity(
  WidgetTester tester,
  ActivityEntries repo, {
  bool admin = false,
  String team = 'atlas',
  bool narrow = false,
}) async {
  await tester.binding.setSurfaceSize(Size(narrow ? 390 : 850, 1100));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EntryActivity(
              repository: repo,
              teamId: team,
              entryId: 'entry',
              admin: admin,
              members: const [
                {'user_id': 'self', 'name': 'Avery', 'active': true},
                {'user_id': 'peer', 'name': 'Taylor', 'active': true},
              ],
              viewProfile: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'activity loads on demand and check/X/clear updates server-confirmed counts',
    (tester) async {
      final repo = ActivityEntries();
      await showActivity(tester, repo);
      expect(repo.reads, 0);
      await click(tester, 'Comments and reviews');
      await click(tester, 'Reviewed, looks good');
      expect(repo.reviewVersion, 4);
      expect(find.text('Reviewed, looks good: 1'), findsOneWidget);
      expect(find.text('Comments left on PR: 0'), findsOneWidget);
      await click(tester, 'Comments left on PR');
      expect(find.text('Reviewed, looks good: 0'), findsOneWidget);
      expect(find.text('Comments left on PR: 1'), findsOneWidget);
      await click(tester, 'Clear my signal');
      expect(repo.data['my_signal'], isNull);
      expect(repo.writes, 3);
    },
  );

  testWidgets(
    'own entry forbids both signals even for admins but permits plain-text comments and edits',
    (tester) async {
      final repo = ActivityEntries()..data['submitter_id'] = 'self';
      await showActivity(tester, repo, admin: true);
      await click(tester, 'Comments and reviews');
      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((chip) => chip.onSelected == null),
        isTrue,
      );
      await tester.enterText(
        find.byType(TextField),
        '<img src=x onerror=alert(1)>\nLocal only',
      );
      await click(tester, 'Post comment');
      expect(
        find.text('<img src=x onerror=alert(1)>\nLocal only'),
        findsOneWidget,
      );
      await click(tester, 'Edit comment');
      await tester.enterText(find.byType(TextField), 'Corrected local note');
      await click(tester, 'Save comment');
      expect(repo.original?['version'], 1);
      expect(find.text('Corrected local note'), findsOneWidget);
    },
  );

  testWidgets(
    'moderation requires confirmation and never offers editing another author',
    (tester) async {
      final repo = ActivityEntries();
      repo.data['comments'] = <EntryData>[
        {
          'id': 'note',
          'author_id': 'peer',
          'body': 'Peer note',
          'version': 3,
          'updated_at': '2026-09-23T09:00:00Z',
        },
      ];
      repo.data['comments_count'] = 1;
      await showActivity(tester, repo, admin: true);
      await click(tester, 'Comments and reviews');
      expect(find.text('Edit comment'), findsNothing);
      await click(tester, 'Remove comment (admin)');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.deleted, 0);
      await click(tester, 'Remove comment (admin)');
      await click(tester, 'Delete comment');
      expect(repo.deleted, 1);
      expect(repo.original?['version'], 3);
      expect(find.text('Peer note'), findsNothing);
    },
  );

  testWidgets(
    'stale comment retains draft, prevents blind retry, refreshes, and requires a new edit',
    (tester) async {
      final repo = ActivityEntries();
      await repo.comment('atlas', 'entry', 'Original');
      await showActivity(tester, repo);
      await click(tester, 'Comments and reviews');
      await click(tester, 'Edit comment');
      repo.error = 'PT409';
      await tester.enterText(find.byType(TextField), 'Unsaved draft');
      await click(tester, 'Save comment');
      expect(find.text('Unsaved draft'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save comment'),
            )
            .onPressed,
        isNull,
      );
      await click(tester, 'Refresh activity');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save comment'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.writes, 2);
      await click(tester, 'Cancel editing');
      expect(find.text('Unsaved draft'), findsNothing);
    },
  );

  testWidgets(
    'permission failures and failed refresh clear activity; team switch discards drafts',
    (tester) async {
      final repo = ActivityEntries();
      await repo.comment('atlas', 'entry', 'Private note');
      await showActivity(tester, repo);
      await click(tester, 'Comments and reviews');
      repo.error = '42501';
      await click(tester, 'Reviewed, looks good');
      expect(find.text('Private note'), findsNothing);
      repo.error = null;
      await click(tester, 'Refresh activity');
      repo.offline = true;
      await click(tester, 'Refresh activity');
      expect(find.text('Private note'), findsNothing);
      repo.offline = false;
      await click(tester, 'Refresh activity');
      await tester.enterText(find.byType(TextField), 'Old team draft');
      repo.data['comments'] = <EntryData>[];
      await showActivity(tester, repo, team: 'orbit');
      expect(find.text('Private note'), findsNothing);
      expect(find.text('Old team draft'), findsNothing);
    },
  );

  testWidgets(
    'narrow layout, keyboard posting, empty validation and read-only state',
    (tester) async {
      final repo = ActivityEntries();
      await showActivity(tester, repo, narrow: true);
      await click(tester, 'Comments and reviews');
      await click(tester, 'Post comment');
      expect(repo.writes, 0);
      expect(find.text('Enter 1–2,000 plain-text characters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Keyboard note');
      final post = find.widgetWithText(FilledButton, 'Post comment');
      await tester.ensureVisible(post);
      Focus.of(tester.element(find.text('Post comment'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      repo.data['state'] = 'archived';
      await click(tester, 'Refresh activity');
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((chip) => chip.onSelected == null),
        isTrue,
      );
    },
  );

  testWidgets('late response from a previous team is ignored', (tester) async {
    final repo = ActivityEntries()..pending = Completer<EntryData>();
    await showActivity(tester, repo);
    await tester.tap(find.text('Comments and reviews'));
    await tester.pump();
    final old = repo.pending!;
    repo.pending = null;
    await showActivity(tester, repo, team: 'orbit');
    old.complete({...repo.data, 'comments_count': 987});
    await tester.pumpAndSettle();
    expect(find.text('Comments (987)'), findsNothing);
    expect(find.text('Comments (0)'), findsOneWidget);
  });
}
