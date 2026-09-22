import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entry_test.dart' show TestEntries, row, showQueue;

class OrderedEntries extends TestEntries {
  OrderedEntries() {
    entries = [
      {...row(), 'id': 'a', 'title': 'Alpha'},
      {...row(), 'id': 'b', 'title': 'Beta'},
      {
        ...row(),
        'id': 'c',
        'title': 'Critical',
        'priority': 'critical',
        'sprint_goal': true,
      },
    ];
  }
  int moves = 0;
  int? sentRevision;
  String? sentSource, sentTarget;
  bool? sentAfter;
  @override
  Future<void> move(
    String teamId,
    String entryId,
    String targetId, {
    required bool after,
    required int revision,
  }) async {
    moves++;
    sentRevision = revision;
    sentSource = entryId;
    sentTarget = targetId;
    sentAfter = after;
    if (error != null) {
      entries[0] = {...entries[0], 'title': 'Changed elsewhere'};
      throw PostgrestException(message: 'changed', code: error);
    }
    final entry = entries.firstWhere((e) => e['id'] == entryId);
    entries.remove(entry);
    final target = entries.indexWhere((e) => e['id'] == targetId);
    entries.insert(target + (after ? 1 : 0), entry);
  }
}

Finder drop(String id) => find.byKey(ValueKey('drop-$id'));
Finder button(String id, String text) => find.descendant(
  of: drop(id),
  matching: find.widgetWithText(TextButton, text),
);

void main() {
  testWidgets(
    'groups sort sprint before priority and members have no reorder controls',
    (tester) async {
      final repo = OrderedEntries();
      await showQueue(tester, repo);
      expect(
        tester.getTopLeft(find.text('Critical')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy),
      );
      expect(find.text('Sprint goal · Critical'), findsOneWidget);
      expect(find.text('Other work · Medium'), findsOneWidget);
      expect(find.text('Move up'), findsNothing);
      expect(find.byType(Draggable<String>), findsNothing);
    },
  );

  testWidgets(
    'keyboard move sends snapshot revision and restores usable focus after reload',
    (tester) async {
      final repo = OrderedEntries()..entries.removeLast();
      await showQueue(tester, repo, admin: true);
      expect(
        tester.widget<TextButton>(button('a', 'Move up')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(button('b', 'Move down')).onPressed,
        isNull,
      );
      final down = tester.widget<TextButton>(button('a', 'Move down'));
      down.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.moves, 1);
      expect(repo.sentRevision, 7);
      expect(repo.sentSource, 'a');
      expect(repo.sentTarget, 'b');
      expect(repo.sentAfter, true);
      expect(
        tester.getTopLeft(find.text('Beta')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy),
      );
      expect(
        tester.widget<TextButton>(button('a', 'Move up')).focusNode!.hasFocus,
        true,
      );
      expect(find.text('Order saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'drag moves within a group and cross-group drops do not call repository',
    (tester) async {
      final repo = OrderedEntries();
      await showQueue(tester, repo, admin: true);
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      await tester.pumpAndSettle();
      Finder handle(String id) => find.descendant(
        of: drop(id),
        matching: find.byType(Draggable<String>),
      );
      await tester.dragFrom(
        tester.getCenter(handle('a')),
        tester.getCenter(drop('c')) - tester.getCenter(handle('a')),
      );
      await tester.pumpAndSettle();
      expect(repo.moves, 0);
      await tester.dragFrom(
        tester.getCenter(handle('b')),
        tester.getCenter(drop('a')) - tester.getCenter(handle('b')),
      );
      await tester.pumpAndSettle();
      expect(repo.moves, 1);
      expect(repo.sentSource, 'b');
      expect(repo.sentTarget, 'a');
      expect(repo.sentAfter, false);
    },
  );

  testWidgets(
    'conflict refreshes changed rows, reports rejection and never retries automatically',
    (tester) async {
      final repo = OrderedEntries()
        ..entries.removeLast()
        ..error = 'PT409';
      await showQueue(tester, repo, admin: true);
      await tester.tap(button('a', 'Move down'));
      await tester.pumpAndSettle();
      expect(repo.moves, 1);
      expect(find.textContaining('Your move was not applied'), findsOneWidget);
      expect(find.text('Changed elsewhere'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow move controls fit and team switching clears ordering state',
    (tester) async {
      final repo = OrderedEntries()..entries.removeLast();
      await showQueue(tester, repo, admin: true);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(button('a', 'Move down'));
      await tester.pumpAndSettle();
      expect(repo.moves, 1);
      await showQueue(tester, repo, admin: false, team: 'orbit');
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Move up'), findsNothing);
    },
  );
}
