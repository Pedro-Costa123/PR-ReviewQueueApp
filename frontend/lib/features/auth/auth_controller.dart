import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'challenge.dart';

class AuthController extends ChangeNotifier {
  AuthController(
    this.repository, {
    String? callback,
    this.hostedTrial = false,
    this.production = false,
    this.cancelChallenge,
  }) : _pending = callback {
    _subscription = repository.changes.listen(
      (_) => notifyListeners(),
      onError: (Object error) {
        message = 'Your session needs attention. Please sign in again.';
        notifyListeners();
      },
    );
    if (callback == 'invalid') {
      _pending = null;
      message = 'This sign-in link is invalid. Request a new one.';
    }
  }
  final AuthRepository repository;
  final bool hostedTrial;
  final bool production;
  final void Function()? cancelChallenge;
  late final StreamSubscription<void> _subscription;
  String? _pending;
  String? message;
  bool busy = false;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool get hasPendingLink => _pending != null;
  String? get email => repository.email;
  static const acknowledgement =
      'If this address is eligible, a sign-in link will arrive. If it does not, wait a minute and try again or contact your team admin.';

  Future<void> requestLink(String email, {String? captchaToken}) async {
    if (busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await repository.requestLink(email, captchaToken: captchaToken);
      message = acknowledgement;
    } on ChallengeException {
      message = 'Verification did not complete. Choose Send sign-in link to try again.';
    } catch (_) {
      message = acknowledgement;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> confirmLink() async {
    if (busy || _pending == null) return;
    final token = _pending!;
    _pending = null;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await repository.confirmLink(token);
    } catch (_) {
      message = 'This link has expired, was already used, or could not be verified. Request a new link.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void cancelLink() {
    _pending = null;
    message = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await repository.signOut();
      message = 'Signed out.';
    } catch (_) {
      message = 'Sign-out could not complete. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancelChallenge?.call();
    _subscription.cancel();
    super.dispose();
  }
}
