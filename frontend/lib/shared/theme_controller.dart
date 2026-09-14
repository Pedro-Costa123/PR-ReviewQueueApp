import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists display preference only; no identity or team data is stored.
class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const storageKey = 'pr_review_queue.theme';
  final SharedPreferencesAsync _preferences;
  ThemeMode mode = ThemeMode.dark;
  bool saving = false;
  String? warning;

  Future<void> load() async {
    try {
      mode = await _preferences.getString(storageKey) == 'light'
          ? ThemeMode.light
          : ThemeMode.dark;
    } catch (_) {
      warning = 'Theme storage is unavailable. Your preference may not survive a reload.';
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (saving) return;
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    saving = true;
    notifyListeners();
    try {
      await _preferences.setString(storageKey, mode.name);
      warning = null;
    } catch (_) {
      warning = 'Theme changed for this visit, but could not be saved.';
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
