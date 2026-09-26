import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/queue/entry_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entry_test.dart' show TestEntries, row, showQueue;

class LifecycleEntries extends TestEntries {
  List<EntryData> archived = [], deletedRows = [];
  final List<EntryData> calls = [];
  final List<EntryData?> cursors = [];
  bool more = false;
  String? lifecycleError;
  @override
  Future<EntryData> lifecyclePage(
    String teamId, {
    bool deleted = false,
    EntryData? cursor,
  }) async {
    cursors.add(cursor);
    if (offline) throw StateError('offline');
    return {
      'entries': teamId != 'atlas'
          ? <EntryData>[]
          : cursor != null
          ? [
              {...history(), 'id': 'page2', 'title': 'Second page'},
            ]
          : deleted
          ? List.of(deletedRows)
          : List.of(archived),
      'has_more': more && cursor == null,
      'next_cursor': {'time': '2020-01-01T00:00:00Z', 'id': 'entry'},
    };
  }

  @override
  Future<void> lifecycle(
    String teamId,
    EntryData entry,
    String action, {
    String? reason,
  }) async {
    calls.add({
      'team': teamId,
      'entry': entry,
      'action': action,
      'reason': reason,
    });
    if (lifecycleError != null) {
      throw PostgrestException(message: 'failure', code: lifecycleError);
    }
    if (action == 'archive') {
      archived = [history()];
      entries = [];
    }
    if (action == 'restore') {
      entries = [row()];
      archived = [];
    }
    if (action == 'recover') {
      entries = [row()];
      deletedRows = [];
    }
  }
}

EntryData history({String owner = 'self'}) => {
  ...row(owner: owner),
  'state': 'archived',
  'version': 7,
  'archived_at': '2020-01-01T00:00:00Z',
  'archived_by': 'self',
  'archive_reason': 'merged',
  'deleted_at': '2020-02-01T00:00:00Z',
  'deleted_by': 'self',
};

Future<void> tap(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'archive requires reason and explicit confirmation; Escape cancels; version is forwarded',
    (tester) async {
      final repo = LifecycleEntries();
      await showQueue(tester, repo);
      await tap(tester, 'Archive entry');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Archive entry'),
            )
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tap(tester, 'Archive entry');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tap(tester, 'Merged');
      await tap(tester, 'Archive entry');
      expect(repo.calls.single['reason'], 'merged');
      expect(repo.calls.single['entry']['version'], 1);
      expect(find.text('Entry archived.'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.context?.widget, isNotNull);
      await tap(tester, 'Archive');
      expect(find.text('Manually archived: Merged'), findsOneWidget);
      expect(find.text('Edit entry'), findsNothing);
      await tap(tester, 'Comments and reviews');
      // Even a stale activity response reporting active cannot enable archive edits.
      expect(find.text('This entry is read-only.'), findsOneWidget);
      expect(find.text('Add a comment'), findsNothing);
      expect(
        find.text('You can comment, but cannot review your own entry.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'member authority: others read history without restore/delete; deleted view is admin only',
    (tester) async {
      final repo = LifecycleEntries()
        ..entries = [row(owner: 'someone')]
        ..archived = [history(owner: 'someone')];
      await showQueue(tester, repo);
      expect(find.text('Archive entry'), findsNothing);
      expect(find.text('Deleted entries'), findsNothing);
      await tap(tester, 'Archive');
      expect(find.text('Restore entry'), findsNothing);
      expect(find.text('Delete entry'), findsNothing);
      expect(find.text('Comments and reviews'), findsOneWidget);
    },
  );

  testWidgets(
    'restore conflict is explicit and not retried; stale/permission/quota/ambiguous errors refresh',
    (tester) async {
      for (final code in ['23505', 'PT409', '42501', 'PT429', 'unknown']) {
        final repo = LifecycleEntries()
          ..archived = [history()]
          ..lifecycleError = code;
        await showQueue(tester, repo);
        await tap(tester, 'Archive');
        await tap(tester, 'Restore entry');
        await tap(tester, 'Restore entry');
        expect(repo.calls.length, 1);
        expect(repo.calls.single['entry']['version'], 7);
        expect(
          find.textContaining(switch (code) {
            '23505' => 'already has an active entry',
            'PT409' => 'action was not applied',
            '42501' => 'Your access changed',
            'PT429' => 'Too many changes',
            _ => 'Could not confirm',
          }),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'admin recovery has confirmation, original-state explanation and separate deleted list',
    (tester) async {
      final repo = LifecycleEntries()
        ..deletedRows = [history(owner: 'someone')];
      await showQueue(tester, repo, admin: true);
      await tap(tester, 'Deleted entries');
      expect(find.text('Restore entry'), findsNothing);
      expect(find.text('Comments and reviews'), findsNothing);
      await tap(tester, 'Recover entry');
      expect(find.textContaining('previous archived state'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tap(tester, 'Recover entry');
      expect(repo.calls.single['action'], 'recover');
      expect(find.text('Entry recovered.'), findsOneWidget);
    },
  );

  testWidgets(
    'cursor next/previous/reset and team switch do not retain private rows',
    (tester) async {
      final repo = LifecycleEntries()
        ..archived = [history()]
        ..more = true;
      await showQueue(tester, repo);
      await tap(tester, 'Archive');
      await tap(tester, 'Next page');
      expect(repo.cursors.last?['id'], 'entry');
      expect(find.text('Second page'), findsOneWidget);
      expect(find.text('Durable PR'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Previous page'),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tap(tester, 'Previous page');
      expect(repo.cursors.last, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Next page'),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tap(tester, 'Refresh list');
      expect(repo.cursors.last, isNull);
      await showQueue(tester, repo, team: 'orbit');
      expect(find.text('Durable PR'), findsNothing);
      expect(find.text('Second page'), findsNothing);
    },
  );

  testWidgets(
    'narrow archive wraps, keyboard restore works, and failed read clears private rows',
    (tester) async {
      final repo = LifecycleEntries()..archived = [history()];
      await showQueue(tester, repo);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      await tap(tester, 'Archive');
      await tap(tester, 'Restore entry');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Restore entry'),
      );
      expect(button.onPressed, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      repo.offline = true;
      await tap(tester, 'Refresh list');
      expect(find.text('Durable PR'), findsNothing);
      expect(find.textContaining('Could not refresh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
