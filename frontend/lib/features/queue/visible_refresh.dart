import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool readAccessError(Object error) =>
    error is AuthException ||
    error is PostgrestException &&
        ['42501', 'PGRST301', 'PGRST302', 'PGRST303'].contains(error.code);
bool readQuotaError(Object error) =>
    error is PostgrestException && ['PT429', '429'].contains(error.code);
String readError(Object error) {
  if (error is AuthException ||
      error is PostgrestException &&
          ['PGRST301', 'PGRST302', 'PGRST303'].contains(error.code)) {
    return 'Your session expired. Sign out and sign in again. Automatic refresh is paused.';
  }
  if (readAccessError(error)) {
    return 'Your access changed or this entry is unavailable. Refresh your teams. Automatic refresh is paused.';
  }
  if (readQuotaError(error)) {
    return 'Request limit reached. Wait a minute, then refresh. Automatic refresh is paused.';
  }
  if (error is PostgrestException && error.code == 'PT409') {
    return 'This list changed. Refresh to restart from page one.';
  }
  return 'Could not refresh. You may be offline. Check your connection; automatic checks slow down to at most once every five minutes.';
}

/// One request at a time; no queued ticks, hidden-tab polling or mutation retries.
class VisibleRefresh with WidgetsBindingObserver {
  VisibleRefresh(this.check) {
    WidgetsBinding.instance.addObserver(this);
    _visible = _isVisible(WidgetsBinding.instance.lifecycleState);
    _schedule();
  }
  final Future<void> Function() check;
  Timer? _timer;
  bool _visible = true, _running = false, _disposed = false, _paused = false;
  int _failures = 0;
  DateTime? _lastAttempt;
  bool _isVisible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;
  void _schedule() {
    _timer?.cancel();
    if (_disposed || !_visible || _paused || _running) return;
    final seconds = _failures == 0
        ? 60
        : _failures == 1
        ? 120
        : _failures == 2
        ? 240
        : 300;
    _timer = Timer(Duration(seconds: seconds), _run);
  }

  Future<void> _run() async {
    if (_disposed || !_visible || _paused || _running) return;
    _running = true;
    _lastAttempt = DateTime.now();
    try {
      await check();
      _failures = 0;
    } catch (error) {
      _failures++;
      _paused = readAccessError(error) || readQuotaError(error);
    } finally {
      _running = false;
      _schedule();
    }
  }

  void reset() {
    _paused = false;
    _failures = 0;
    _schedule();
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _visible;
    _visible = _isVisible(state);
    if (!_visible) {
      _timer?.cancel();
      return;
    }
    if (!wasVisible &&
        !_paused &&
        !_running &&
        (_lastAttempt == null ||
            DateTime.now().difference(_lastAttempt!).inSeconds >= 60)) {
      _run();
    } else if (!wasVisible) {
      _schedule();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
