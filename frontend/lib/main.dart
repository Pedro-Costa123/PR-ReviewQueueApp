import 'package:flutter/material.dart';

import 'app.dart';
import 'shared/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/browser_session.dart';
import 'features/auth/local_auth_config.dart';

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
  if (allowsLocalAuth(api: api, key: key, page: Uri.base)) {
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
      SupabaseAuthRepository(Supabase.instance.client, localAuthCallback),
      callback: pending,
    );
  }
  runApp(ReviewQueueApp(theme: theme, auth: auth));
}
