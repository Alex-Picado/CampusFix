import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the appearance for this installation or browser.
class AppearanceController extends ChangeNotifier {
  static const _key = 'campusfix.themeMode';
  final _preferences = _openPreferences();
  Future<void> _pendingWrite = Future<void>.value();
  ThemeMode? _selectedMode;
  bool _disposed = false;

  AppearanceController() {
    _restore();
  }

  ThemeMode get mode => _selectedMode ?? ThemeMode.system;

  static Future<SharedPreferences?> _openPreferences() async {
    try {
      return await SharedPreferences.getInstance();
    } on Exception {
      return null;
    }
  }

  Future<void> _restore() async {
    final stored = (await _preferences)?.get(_key);
    if (_disposed || _selectedMode != null) return;
    _selectedMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  void select(ThemeMode mode) {
    _selectedMode = mode;
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await (await _preferences)?.setString(_key, mode.name);
      } on Exception {
        // Keep the selected theme for the current session if storage fails.
      }
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
