import 'package:supabase_flutter/supabase_flutter.dart';

import 'challenge.dart';

abstract interface class AuthRepository {
  String? get email;
  Stream<void> get changes;
  Future<void> requestLink(String email, {String? captchaToken});
  Future<void> confirmLink(String tokenHash);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, this.callback, {this.requestChallenge});
  final SupabaseClient client;
  final String callback;
  // P05 supplies a new Turnstile challenge for EACH provider request. A token
  // consumed by /otp must never be reused by the first-login /resend fallback.
  final Future<String?> Function()? requestChallenge;
  int _generation = 0;
  void cancelRequest() => _generation++;
  Future<String?> _challenge(String? supplied) async {
    if (requestChallenge == null) return supplied;
    final token = await requestChallenge!();
    if (token == null || token.isEmpty || token.length > 2048) {
      throw const ChallengeException();
    }
    return token;
  }

  @override
  String? get email => client.auth.currentUser?.email;
  @override
  Stream<void> get changes => client.auth.onAuthStateChange.map((_) {});
  @override
  Future<void> requestLink(String email, {String? captchaToken}) async {
    final generation = _generation;
    Future<String?> challenge(String? supplied) async {
      if (generation != _generation) throw const ChallengeException();
      final token = await _challenge(supplied);
      if (generation != _generation) throw const ChallengeException();
      return token;
    }

    try {
      await client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        shouldCreateUser: false,
        emailRedirectTo: callback,
        captchaToken: await challenge(captchaToken),
      );
    } on AuthException catch (error) {
      if (error.code != 'signup_disabled') rethrow;
      // Provider-generated confirmation link for an existing unconfirmed user.
      // Does not create an account; every send still passes the signed hook.
      if (captchaToken != null && requestChallenge == null) {
        throw const AuthException(
          'A fresh verification challenge is required.',
        );
      }
      await client.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        emailRedirectTo: callback,
        captchaToken: await challenge(null),
      );
    }
  }

  @override
  Future<void> confirmLink(String tokenHash) async {
    final result = await client.auth.verifyOTP(
      tokenHash: tokenHash,
      type: OtpType.email,
    );
    if (result.session == null) {
      throw const AuthException('Session unavailable');
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}
