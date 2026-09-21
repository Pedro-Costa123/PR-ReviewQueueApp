import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/archive/archive_page.dart';
import 'features/auth/sign_in_page.dart';
import 'features/auth/auth_controller.dart';
import 'features/profiles/profile_page.dart';
import 'features/queue/queue_page.dart';
import 'features/queue/queue_repository.dart';
import 'features/queue/entry_repository.dart';
import 'features/teams/workspace_shell.dart';
import 'features/teams/onboarding_page.dart';
import 'features/teams/onboarding_repository.dart';
import 'shared/theme_controller.dart';

class ReviewQueueApp extends StatefulWidget {
  const ReviewQueueApp({
    super.key,
    required this.theme,
    this.repository = const DemoQueueRepository(),
    this.initialLocation,
    this.auth,
    this.onboarding,
    this.entries,
  });
  final ThemeController theme;
  final QueueRepository repository;
  final String? initialLocation;
  final AuthController? auth;
  final OnboardingRepository? onboarding;
  final EntryRepository? entries;
  @override
  State<ReviewQueueApp> createState() => _ReviewQueueAppState();
}

class _ReviewQueueAppState extends State<ReviewQueueApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ListenableBuilder(
          listenable: widget.auth ?? widget.theme,
          builder: (context, _) => WorkspaceShell(
            theme: widget.theme,
            repository: widget.repository,
            path: state.uri.path,
            teamId: state.pathParameters['teamId'],
            connected:
                state.uri.path == '/' &&
                widget.auth?.email != null &&
                widget.auth?.hasPendingLink == false,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                widget.auth == null || widget.onboarding == null
                ? SignInPage(auth: widget.auth)
                : ListenableBuilder(
                    listenable: widget.auth!,
                    builder: (context, _) =>
                        widget.auth!.email != null &&
                            !widget.auth!.hasPendingLink
                        ? OnboardingPage(
                            key: ValueKey(widget.auth!.email),
                            repository: widget.onboarding!,
                            signOut: widget.auth!.signOut,
                            entries: widget.entries,
                          )
                        : SignInPage(auth: widget.auth),
                  ),
          ),
          GoRoute(
            path: '/teams/:teamId',
            builder: (context, state) {
              final team = widget.repository.team(
                state.pathParameters['teamId']!,
              );
              return team == null
                  ? const MissingPage()
                  : QueuePage(repository: widget.repository, team: team);
            },
            routes: [
              GoRoute(
                path: 'archive',
                builder: (context, state) {
                  final team = widget.repository.team(
                    state.pathParameters['teamId']!,
                  );
                  return team == null
                      ? const MissingPage()
                      : ArchivePage(teamName: team.name);
                },
              ),
              GoRoute(
                path: 'profiles/:profileId',
                builder: (context, state) {
                  final team = widget.repository.team(
                    state.pathParameters['teamId']!,
                  );
                  final profile = widget.repository.profile(
                    state.pathParameters['profileId']!,
                  );
                  return team == null || profile == null
                      ? const MissingPage()
                      : ProfilePage(profile: profile, teamId: team.id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => WorkspaceShell(
      theme: widget.theme,
      repository: widget.repository,
      path: state.uri.path,
      child: const MissingPage(),
    ),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF76D7BB),
          brightness: brightness,
        ).copyWith(
          surface: dark ? const Color(0xFF111718) : const Color(0xFFF6F8F7),
          surfaceContainerLow: dark ? const Color(0xFF192123) : Colors.white,
          outlineVariant: dark
              ? const Color(0xFF303B3D)
              : const Color(0xFFDCE5E1),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.theme,
    builder: (context, child) => MaterialApp.router(
      title: 'PR Review Queue · Demo',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: widget.theme.mode,
      routerConfig: _router,
    ),
  );
}

class MissingPage extends StatelessWidget {
  const MissingPage({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'This demo page does not exist',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      const Text('Choose a demo team or return to the preview introduction.'),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => context.go('/'),
        child: const Text('Return to introduction'),
      ),
    ],
  );
}
