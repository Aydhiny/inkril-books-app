import 'reader_theme.dart';

/// Immutable snapshot of all reader customisation preferences.
class ReaderSettings {
  final ReaderTheme theme;

  /// 0.0 = darkest overlay, 1.0 = no overlay (full screen brightness).
  /// Implemented as a black overlay whose opacity = (1 - brightness) * 0.65.
  final double brightness;

  /// Scale factor for HUD text (timer, page counter, title).
  final double hudFontScale;

  /// true = horizontal page swipe (book-style), false = vertical scroll.
  final bool horizontalScroll;

  const ReaderSettings({
    this.theme = ReaderTheme.white,
    this.brightness = 1.0,
    this.hudFontScale = 1.0,
    this.horizontalScroll = true,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    double? brightness,
    double? hudFontScale,
    bool? horizontalScroll,
  }) =>
      ReaderSettings(
        theme: theme ?? this.theme,
        brightness: brightness ?? this.brightness,
        hudFontScale: hudFontScale ?? this.hudFontScale,
        horizontalScroll: horizontalScroll ?? this.horizontalScroll,
      );
}
