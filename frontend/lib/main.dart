import 'package:flutter/material.dart';

import 'app.dart';
import 'shared/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/browser_session.dart';
import 'features/auth/auth_config.dart';
import 'features/auth/challenge.dart';
import 'features/teams/onboarding_repository.dart';
import 'features/queue/entry_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeController();
  await theme.load();
  AuthController? auth;
  OnboardingRepository? onboarding;
  EntryRepository? entries;
  const api = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const mode = String.fromEnvironment('AUTH_MODE', defaultValue: 'local');
  const siteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');
  final pending = takeAuthCallback();
  final config = AuthConfig.resolve(
    mode: mode,
    api: api,
    key: publicKey.isEmpty ? key : publicKey,
    siteKey: siteKey,
    page: Uri.base,
  );
  if (config != null) {
    await Supabase.initialize(
      url: api,
      publishableKey: config.key,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        detectSessionInUri: false,
        localStorage: createSessionStorage(),
      ),
    );
    final repository = SupabaseAuthRepository(
      Supabase.instance.client,
      config.callback,
      requestChallenge: config.hostedTrial
          ? () => requestChallenge(config.siteKey!, theme.mode.name)
          : null,
    );
    auth = AuthController(
      repository,
      callback: pending,
      hostedTrial: config.hostedTrial,
      cancelChallenge: config.hostedTrial
          ? () {
              repository.cancelRequest();
              cancelChallenge();
            }
          : null,
    );
    onboarding = SupabaseOnboardingRepository(
      Supabase.instance.client,
      repository,
    );
    entries = SupabaseEntryRepository(Supabase.instance.client);
  }
  runApp(
    ReviewQueueApp(
      theme: theme,
      auth: auth,
      onboarding: onboarding,
      entries: entries,
    ),
  );
}
