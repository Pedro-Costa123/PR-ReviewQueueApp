import 'package:flutter/material.dart';

import 'app.dart';
import 'shared/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/browser_session.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeController();
  await theme.load();
  AuthController? auth;
  const api = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  final pending = takeAuthCallback();
  // P04 is local-only. No hosted login with CAPTCHA silently omitted.
  if (api == 'http://127.0.0.1:54321' &&
      key.isNotEmpty &&
      Uri.base.origin == 'http://127.0.0.1:4173') {
    await Supabase.initialize(
      url: api,
      publishableKey: key,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        detectSessionInUri: false,
        localStorage: createSessionStorage(),
      ),
    );
    auth = AuthController(
      SupabaseAuthRepository(
        Supabase.instance.client,
        'http://127.0.0.1:4173/PR-Review-App-Queue/',
      ),
      callback: pending,
    );
  }
  runApp(ReviewQueueApp(theme: theme, auth: auth));
}
