import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reader_settings.dart';
import '../models/reader_theme.dart';

// ── SharedPreferences injection ─────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not provided');
});

// ── Reader settings provider ────────────────────────────────────────────────

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier(ref.read(sharedPreferencesProvider));
});

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  final SharedPreferences _prefs;

  static const _kTheme = 'reader_theme';
  static const _kBrightness = 'reader_brightness';
  static const _kFontScale = 'reader_hud_font_scale';
  static const _kHorizontal = 'reader_horizontal_scroll';
  static const _kNightMode = 'reader_night_mode';
  static const _kAutoScrollWpm = 'reader_auto_scroll_wpm';

  ReaderSettingsNotifier(this._prefs) : super(_load(_prefs));

  static ReaderSettings _load(SharedPreferences p) => ReaderSettings(
        theme: ReaderTheme.values.firstWhere(
          (t) => t.name == p.getString(_kTheme),
          orElse: () => ReaderTheme.white,
        ),
        brightness: p.getDouble(_kBrightness) ?? 1.0,
        hudFontScale: p.getDouble(_kFontScale) ?? 1.0,
        horizontalScroll: p.getBool(_kHorizontal) ?? true,
        isNightMode: p.getBool(_kNightMode) ?? false,
        preferredAutoScrollWpm: p.getInt(_kAutoScrollWpm) ?? 250,
      );

  void setTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
    _prefs.setString(_kTheme, theme.name);
  }

  void setBrightness(double value) {
    state = state.copyWith(brightness: value.clamp(0.0, 1.0));
    _prefs.setDouble(_kBrightness, state.brightness);
  }

  void setHudFontScale(double scale) {
    state = state.copyWith(hudFontScale: scale);
    _prefs.setDouble(_kFontScale, scale);
  }

  void setHorizontalScroll(bool value) {
    state = state.copyWith(horizontalScroll: value);
    _prefs.setBool(_kHorizontal, value);
  }

  void setNightMode(bool value) {
    state = state.copyWith(isNightMode: value);
    _prefs.setBool(_kNightMode, value);
  }

  void setAutoScrollWpm(int wpm) {
    state = state.copyWith(preferredAutoScrollWpm: wpm.clamp(50, 600));
    _prefs.setInt(_kAutoScrollWpm, state.preferredAutoScrollWpm);
  }
}
