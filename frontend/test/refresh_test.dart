import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/features/queue/entry_repository.dart';
import 'package:pr_review_queue/features/queue/entry_queue.dart';
import 'package:pr_review_queue/features/queue/visible_refresh.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entry_test.dart' show TestEntries, row, showQueue;

class RefreshEntries extends TestEntries {
  int revision = 1, checks = 0, reads = 0;
  Object? failure;
  Completer<int>? pending;
  final List<EntryData> requests = [];
  @override
  Future<int> dataRevision(String teamId) async {
    checks++;
    if (failure != null) throw failure!;
    return pending == null ? revision : pending!.future;
  }

  @override
  Future<EntryData> page(
    String teamId, {
    String view = 'active',
    String search = '',
    String? priority,
    bool? sprint,
    String? submitter,
    int offset = 0,
    int? revision,
  }) async {
    reads++;
    requests.add({
      'team': teamId,
      'view': view,
      'search': search,
      'priority': priority,
      'sprint': sprint,
      'submitter': submitter,
      'offset': offset,
      'revision': revision,
    });
    if (failure != null) throw failure!;
    if (revision != null && revision != this.revision) {
      throw const PostgrestException(message: 'changed', code: 'PT409');
    }
    return {
      'entries': [
        ...entries.map(
          (e) => {
            ...e,
            'title': search.isEmpty
                ? (offset == 0 ? e['title'] : 'Page two')
                : 'Search result',
          },
        ),
      ],
      'has_more': offset == 0,
      'revision': 7,
      'data_revision': this.revision,
    };
  }
}

Future<void> tap(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label).last);
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'visible checks avoid full reads, update changed rows, and preserve keyboard focus',
    (t) async {
      final repo = RefreshEntries();
      await showQueue(t, repo);
      await tap(t, 'Search and filters');
      await t.tap(find.byType(TextField).first);
      await t.pump();
      final focus = FocusManager.instance.primaryFocus;
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(repo.checks, 1);
      expect(repo.reads, 1);
      repo.revision++;
      repo.entries = [
        {...row(), 'title': 'Remote saved title'},
      ];
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(repo.reads, 2);
      expect(find.text('Remote saved title'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, focus);
      expect(find.textContaining('Last updated:'), findsOneWidget);
    },
  );
  testWidgets(
    'hidden tabs stop requests; return checks and slow requests never overlap',
    (t) async {
      final repo = RefreshEntries();
      await showQueue(t, repo);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump(const Duration(minutes: 10));
      expect(repo.checks, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(repo.checks, 1);
      repo.pending = Completer<int>();
      await t.pump(const Duration(seconds: 60));
      expect(repo.checks, 2);
      await t.pump(const Duration(seconds: 10));
      expect(repo.checks, 2);
      repo.pending!.complete(1);
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'network failures back off; access/session/quota failures pause and clear denied data',
    (t) async {
      final repo = RefreshEntries();
      await showQueue(t, repo);
      repo.failure = StateError('offline');
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(find.textContaining('may be offline'), findsOneWidget);
      expect(find.text('Durable PR'), findsOneWidget);
      await t.pump(const Duration(seconds: 60));
      expect(repo.checks, 1);
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(repo.checks, 2);
      repo.failure = const PostgrestException(message: 'denied', code: '42501');
      await t.pump(const Duration(seconds: 240));
      await t.pumpAndSettle();
      expect(find.text('Durable PR'), findsNothing);
      final count = repo.checks;
      await t.pump(const Duration(minutes: 20));
      expect(repo.checks, count);
      repo.failure = null;
      await tap(t, 'Refresh queue');
      repo.failure = const PostgrestException(message: 'quota', code: 'PT429');
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(find.textContaining('Request limit reached'), findsOneWidget);
      final quotaCount = repo.checks;
      await t.pump(const Duration(minutes: 20));
      expect(repo.checks, quotaCount);
      expect(
        readError(
          const PostgrestException(message: 'expired', code: 'PGRST301'),
        ),
        contains('session expired'),
      );
    },
  );
  testWidgets(
    'server search, pagination and stale-page recovery work by keyboard',
    (t) async {
      final repo = RefreshEntries();
      await showQueue(t, repo, admin: true);
      await tap(t, 'Search and filters');
      await t.enterText(find.byType(TextField).first, '%_ literal');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(repo.requests.last['search'], '%_ literal');
      expect(find.text('Move up'), findsNothing);
      await tap(t, 'Next page');
      expect(repo.requests.last['offset'], 25);
      expect(repo.requests.last['revision'], 1);
      repo.revision++;
      await tap(t, 'Previous page');
      expect(find.textContaining('list changed'), findsOneWidget);
      await tap(t, 'Refresh queue');
      expect(repo.requests.last['offset'], 0);
      expect(repo.requests.last['revision'], isNull);
      await tap(t, 'Clear filters');
      expect(repo.requests.last['search'], '');
      expect(find.text('Move up'), findsOneWidget);
    },
  );
  testWidgets(
    'background refresh defers comment drafts and confirmation dialogs',
    (t) async {
      final repo = RefreshEntries();
      await showQueue(t, repo);
      await tap(t, 'Comments and reviews');
      await t.enterText(
        find.widgetWithText(TextField, 'Add a comment'),
        'Keep this draft',
      );
      repo.revision++;
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(repo.reads, 1);
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(find.textContaining('Updates available'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Next page'),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(find.widgetWithText(TextField, 'Add a comment'), '');
      await tap(t, 'Archive entry');
      final checks = repo.checks;
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(repo.checks, checks);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 60));
      await t.pumpAndSettle();
      expect(repo.reads, 2);
    },
  );
  testWidgets(
    'filters wrap at 320px with large text in both themes and have semantic labels',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final semantics = t.ensureSemantics();
      try {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await t.pumpWidget(
            MaterialApp(
              key: ValueKey(brightness),
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: EntryQueue(
                      repository: RefreshEntries(),
                      teamId: 'atlas',
                      admin: false,
                      members: const [],
                      viewProfile: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await tap(t, 'Search and filters');
          expect(find.bySemanticsLabel('Search title or links'), findsWidgets);
          expect(
            find.bySemanticsLabel(RegExp('Filter priority')),
            findsWidgets,
          );
          expect(t.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
