import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeKey = 'app_theme_mode';

/// Persists the user's theme preference (light / dark / system).
class ThemeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();

  @override
  ThemeMode build() {
    // Start with system; load from storage asynchronously.
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _kThemeKey);
    final mode = _fromString(saved);
    if (mode != state) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _kThemeKey, value: _toString(mode));
  }

  static ThemeMode _fromString(String? s) => switch (s) {
        'light'  => ThemeMode.light,
        'dark'   => ThemeMode.dark,
        _        => ThemeMode.system,
      };

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.light  => 'light',
        ThemeMode.dark   => 'dark',
        _                => 'system',
      };
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
