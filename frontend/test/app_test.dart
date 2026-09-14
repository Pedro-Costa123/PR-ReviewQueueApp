import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_review_queue/app.dart';
import 'package:pr_review_queue/shared/theme_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

final class UnavailablePreferences extends InMemorySharedPreferencesAsync {
  UnavailablePreferences() : super.empty();
  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async => throw StateError('Storage denied');
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => throw StateError('Storage denied');
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test(
    'first visit is dark; a new controller restores both saved preferences',
    () async {
      final first = ThemeController();
      await first.load();
      expect(first.mode, ThemeMode.dark);
      await first.toggle();
      final second = ThemeController();
      await second.load();
      expect(second.mode, ThemeMode.light);
      await second.toggle();
      final third = ThemeController();
      await third.load();
      expect(third.mode, ThemeMode.dark);
    },
  );
  test(
    'unavailable storage does not prevent startup or changing theme',
    () async {
      SharedPreferencesAsyncPlatform.instance = UnavailablePreferences();
      final theme = ThemeController();
      await theme.load();
      expect(theme.mode, ThemeMode.dark);
      expect(theme.warning, isNotNull);
      await theme.toggle();
      expect(theme.mode, ThemeMode.light);
      expect(theme.saving, isFalse);
      expect(theme.warning, contains('could not be saved'));
    },
  );
  testWidgets('demo navigation, profile, archive and empty team work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ReviewQueueApp(theme: ThemeController(), initialLocation: '/'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Explore the demo queue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Keep draft changes when a session expires'),
      findsOneWidget,
    );
    await tester.tap(find.text('Maya Chen').first);
    await tester.pumpAndSettle();
    expect(find.text('@maya.demo'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('History starts here'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orbit').last);
    await tester.pumpAndSettle();
    expect(find.text('A little breathing room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final route in [
    '/',
    '/teams/atlas',
    '/teams/atlas/archive',
    '/teams/atlas/profiles/maya',
    '/teams/missing',
    '/missing',
  ]) {
    testWidgets('narrow layout and direct route: $route', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ReviewQueueApp(theme: ThemeController(), initialLocation: route),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Demo team'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
