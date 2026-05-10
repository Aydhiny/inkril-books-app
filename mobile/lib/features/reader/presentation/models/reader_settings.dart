import 'reader_theme.dart';

/// Immutable snapshot of all reader customisation preferences.
class ReaderSettings {
  final ReaderTheme theme;

  /// 0.0 = darkest overlay, 1.0 = no overlay (full screen brightness).
  final double brightness;

  /// Scale factor for HUD text (timer, page counter, title).
  final double hudFontScale;

  /// true = horizontal page swipe (book-style), false = vertical scroll.
  final bool horizontalScroll;

  /// When true: Twilight theme + 60 % brightness regardless of [theme]/[brightness].
  final bool isNightMode;

  /// Preferred auto-scroll speed in words-per-minute.
  /// Used to calculate seconds-per-page = (250 / wpm) * 60.
  /// Default 250 WPM ≈ 1 page/min for a standard trade paperback.
  final int preferredAutoScrollWpm;

  /// When true, the reader locks to portrait orientation regardless of device
  /// rotation. Useful when reading lying on your side.
  final bool lockPortrait;

  const ReaderSettings({
    this.theme = ReaderTheme.white,
    this.brightness = 1.0,
    this.hudFontScale = 1.0,
    this.horizontalScroll = true,
    this.isNightMode = false,
    this.preferredAutoScrollWpm = 250,
    this.lockPortrait = false,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    double? brightness,
    double? hudFontScale,
    bool? horizontalScroll,
    bool? isNightMode,
    int? preferredAutoScrollWpm,
    bool? lockPortrait,
  }) =>
      ReaderSettings(
        theme: theme ?? this.theme,
        brightness: brightness ?? this.brightness,
        hudFontScale: hudFontScale ?? this.hudFontScale,
        horizontalScroll: horizontalScroll ?? this.horizontalScroll,
        isNightMode: isNightMode ?? this.isNightMode,
        preferredAutoScrollWpm:
            preferredAutoScrollWpm ?? this.preferredAutoScrollWpm,
        lockPortrait: lockPortrait ?? this.lockPortrait,
      );
}
