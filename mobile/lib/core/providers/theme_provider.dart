import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeKey = 'app_theme_mode';

/// Persists the user's theme preference (light / dark / system).
///
/// Accepts an optional [initial] value injected from main() so the very first
/// frame renders with the correct ThemeMode — no async _load() flash.
class ThemeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();

  final ThemeMode? _initial;
  ThemeNotifier([this._initial]);

  @override
  ThemeMode build() {
    // If main() pre-loaded the theme, use it directly and skip the async read.
    // If not (e.g., the provider is used in a test or hot-reload context without
    // the override), fall back to the async load path.
    if (_initial == null) _load();
    return _initial ?? ThemeMode.system;
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _kThemeKey);
    final mode = themeFromString(saved);
    if (mode != state) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _kThemeKey, value: _themeToString(mode));
  }

  /// Public so main() can parse the eagerly-read storage value.
  static ThemeMode themeFromString(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark'  => ThemeMode.dark,
        _       => ThemeMode.system,
      };

  static String _themeToString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark  => 'dark',
        _               => 'system',
      };
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
