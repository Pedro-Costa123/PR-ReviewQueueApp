import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:supabase_flutter/supabase_flutter.dart';

@JS('takeAuthCallback')
external JSString? _takeAuthCallback();
String? takeAuthCallback() => _takeAuthCallback()?.toDart;
LocalStorage createSessionStorage() => TabSessionStorage();

/// Persistence uses sessionStorage; the SDK still broadcasts to other open
/// same-origin app tabs. Failure falls back to memory, never localStorage.
class TabSessionStorage extends LocalStorage {
  static const key = 'pr_review_queue.auth';
  String? _memory;
  bool _available = true;
  @override
  Future<void> initialize() async {
    try {
      _memory = web.window.sessionStorage.getItem(key);
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<String?> accessToken() async => _memory;
  @override
  Future<bool> hasAccessToken() async => _memory != null;
  @override
  Future<void> persistSession(String persistSessionString) async {
    _memory = persistSessionString;
    if (_available) {
      try {
        web.window.sessionStorage.setItem(key, persistSessionString);
      } catch (_) {
        _available = false;
      }
    }
  }

  @override
  Future<void> removePersistedSession() async {
    _memory = null;
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (_) {
      /* memory only */
    }
  }
}
