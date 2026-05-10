import 'package:flutter/material.dart';

/// Every reading theme the user can pick.
/// Each theme is a [ColorFilter.matrix] applied over the PDF view so we never
/// touch the PDF bytes — the transformation is purely visual and zero-cost.
enum ReaderTheme {
  white,
  hazel,
  papyrus,
  sepia,
  dark,
  midnight,
  vampire,
  forest,
  twilight;

  String get label => switch (this) {
        ReaderTheme.white => 'White',
        ReaderTheme.hazel => 'Hazel',
        ReaderTheme.papyrus => 'Papyrus',
        ReaderTheme.sepia => 'Sepia',
        ReaderTheme.dark => 'Dark',
        ReaderTheme.midnight => 'Midnight',
        ReaderTheme.vampire => 'Vampire',
        ReaderTheme.forest => 'Forest',
        ReaderTheme.twilight => 'Twilight',
      };

  String get emoji => switch (this) {
        ReaderTheme.white => '☀️',
        ReaderTheme.hazel => '🌅',
        ReaderTheme.papyrus => '📜',
        ReaderTheme.sepia => '🍂',
        ReaderTheme.dark => '🌙',
        ReaderTheme.midnight => '🌌',
        ReaderTheme.vampire => '🩸',
        ReaderTheme.forest => '🌿',
        ReaderTheme.twilight => '🔥',
      };

  /// Background colour of the Scaffold (area outside the PDF canvas).
  Color get scaffoldColor => switch (this) {
        ReaderTheme.white => const Color(0xFFFFFFFF),
        ReaderTheme.hazel => const Color(0xFFFFF5E4),
        ReaderTheme.papyrus => const Color(0xFFF5ECD7),
        ReaderTheme.sepia => const Color(0xFFEEDDC0),
        ReaderTheme.dark => const Color(0xFF1A1A1A),
        ReaderTheme.midnight => const Color(0xFF0D1B2A),
        ReaderTheme.vampire => const Color(0xFF1A0606),
        ReaderTheme.forest => const Color(0xFFF0F5EC),
        ReaderTheme.twilight => const Color(0xFFFFF8E8),
      };

  /// Small preview tile colours shown in the picker.
  Color get previewBg => scaffoldColor;

  Color get previewText => switch (this) {
        ReaderTheme.white => const Color(0xFF1F2937),
        ReaderTheme.hazel => const Color(0xFF4A3728),
        ReaderTheme.papyrus => const Color(0xFF3D2B1F),
        ReaderTheme.sepia => const Color(0xFF5C3D2E),
        ReaderTheme.dark => const Color(0xFFE8E8E8),
        ReaderTheme.midnight => const Color(0xFFB8C5D6),
        ReaderTheme.vampire => const Color(0xFFD4A0A0),
        ReaderTheme.forest => const Color(0xFF2D4A2D),
        ReaderTheme.twilight => const Color(0xFF6B4A00),
      };

  /// Accent / border colour used in the picker tile.
  Color get accentColor => switch (this) {
        ReaderTheme.white => const Color(0xFFE5E7EB),
        ReaderTheme.hazel => const Color(0xFFD4A853),
        ReaderTheme.papyrus => const Color(0xFFC4A46B),
        ReaderTheme.sepia => const Color(0xFF9B7653),
        ReaderTheme.dark => const Color(0xFF6B21A8),
        ReaderTheme.midnight => const Color(0xFF3B82F6),
        ReaderTheme.vampire => const Color(0xFFDC2626),
        ReaderTheme.forest => const Color(0xFF16A34A),
        ReaderTheme.twilight => const Color(0xFFF59E0B),
      };

  bool get isDark =>
      this == ReaderTheme.dark ||
      this == ReaderTheme.midnight ||
      this == ReaderTheme.vampire;

  /// The color-filter matrix applied to the [PDFView] widget.
  ///
  /// Matrix layout (20 values, row-major):
  ///   [R_r, R_g, R_b, R_a, R_off,
  ///    G_r, G_g, G_b, G_a, G_off,
  ///    B_r, B_g, B_b, B_a, B_off,
  ///    A_r, A_g, A_b, A_a, A_off]
  /// Channel offsets are in 0-255 range.
  ColorFilter get colorFilter => ColorFilter.matrix(_matrix);

  List<double> get _matrix => switch (this) {
        // ── Light themes ─────────────────────────────────────────────────

        // Identity — no transformation.
        ReaderTheme.white => [
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 1, 0,
          ],

        // Hazel: gentle warmth (Kindle-style warm light).
        // Bumps red slightly, clips blue — white pages become a soft cream.
        ReaderTheme.hazel => [
            1.00, 0, 0, 0, 12,
            0, 0.98, 0, 0, 8,
            0, 0, 0.78, 0, -8,
            0, 0, 0, 1, 0,
          ],

        // Papyrus: aged-paper yellowing, more pronounced than Hazel.
        ReaderTheme.papyrus => [
            1.00, 0, 0, 0, 22,
            0, 0.95, 0, 0, 12,
            0, 0, 0.70, 0, -15,
            0, 0, 0, 1, 0,
          ],

        // Sepia: classic channel-mix sepia (grayscale + warm tint).
        ReaderTheme.sepia => [
            0.393, 0.769, 0.189, 0, 0,
            0.349, 0.686, 0.168, 0, 0,
            0.272, 0.534, 0.131, 0, 0,
            0, 0, 0, 1, 0,
          ],

        // Forest: natural green tint — easy on the eyes for long sessions.
        ReaderTheme.forest => [
            0.92, 0, 0, 0, 0,
            0, 1.00, 0, 0, 8,
            0, 0, 0.85, 0, -5,
            0, 0, 0, 1, 0,
          ],

        // Twilight: strong amber/orange warmth for late-night reading.
        ReaderTheme.twilight => [
            1.00, 0, 0, 0, 18,
            0, 0.88, 0, 0, 0,
            0, 0, 0.55, 0, -20,
            0, 0, 0, 1, 0,
          ],

        // ── Dark themes (invert + tint) ───────────────────────────────────

        // Dark: pure invert — white pages become near-black, black text becomes white.
        ReaderTheme.dark => [
            -1, 0, 0, 0, 255,
            0, -1, 0, 0, 255,
            0, 0, -1, 0, 255,
            0, 0, 0, 1, 0,
          ],

        // Midnight: invert + blue shift. Background → dark navy, text → cool blue-white.
        // White(255,255,255) → R:-0.85*255+200≈0, G:0, B:-0.75*255+255≈64 → (0,0,64) dark navy ✓
        // Black(0,0,0)       → R:200, G:210, B:255 → light periwinkle ✓
        ReaderTheme.midnight => [
            -0.85, 0, 0, 0, 200,
            0, -0.85, 0, 0, 210,
            0, 0, -0.75, 0, 255,
            0, 0, 0, 1, 0,
          ],

        // Vampire: invert + crimson shift. Background → deep blood-red, text → rose-pink.
        // White(255,255,255) → R:-0.85*255+230≈13, G:0, B:0 → very dark red ✓
        // Black(0,0,0)       → R:230, G:170, B:160 → pinkish-red ✓
        ReaderTheme.vampire => [
            -0.85, 0, 0, 0, 230,
            0, -0.90, 0, 0, 170,
            0, 0, -0.90, 0, 160,
            0, 0, 0, 1, 0,
          ],
      };
}
