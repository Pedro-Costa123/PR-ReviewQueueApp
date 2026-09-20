import 'local_auth_config.dart';

class AuthConfig {
  const AuthConfig({required this.api, required this.key, this.siteKey});
  final String api;
  final String key;
  final String? siteKey;
  bool get hostedTrial => siteKey != null;
  String get callback => localAuthCallback;

  static AuthConfig? resolve({
    required String mode,
    required String api,
    required String key,
    required String siteKey,
    required Uri page,
  }) {
    if (mode == 'local' && allowsLocalAuth(api: api, key: key, page: page)) {
      return AuthConfig(api: api, key: key);
    }
    // P05 trial stays on the exact loopback root. Production rollout is P13.
    if (mode != 'hosted-trial' ||
        !allowsLocalAuth(api: 'http://127.0.0.1:54321', key: key, page: page) ||
        !RegExp(r'^https://[a-z0-9]{20}\.supabase\.co$').hasMatch(api) ||
        !RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key) ||
        !RegExp(r'^0x[A-Za-z0-9_-]{20,100}$').hasMatch(siteKey)) {
      return null;
    }
    // Cloudflare's public dummy site keys (1x/2x/3x) never enable app auth.
    return AuthConfig(api: api, key: key, siteKey: siteKey);
  }
}
