import 'package:flutter/material.dart';
import 'app_theme.dart';

/// BuildContext extension that maps semantic names to the correct color for
/// the current brightness (light / dark).  Every hardcoded color that was
/// previously sprinkled across screens should be sourced from here.
///
/// Usage:
///   color: context.textPrimary
///   color: context.cardBg
extension AppColorsX on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  // ── Scaffold / page backgrounds ───────────────────────────────────────────
  /// Main page background (replaces Colors.white or Color(0xFFF8F5FF))
  Color get scaffoldBg => _dark ? const Color(0xFF0D0A1A) : Colors.white;

  /// Surface for cards / containers (replaces Colors.white inside widgets)
  Color get cardBg => _dark ? const Color(0xFF18122A) : Colors.white;

  /// Subtle tinted background (replaces Color(0xFFF3F4F6) / Color(0xFFF9FAFB))
  Color get subtleBg => _dark ? const Color(0xFF201836) : const Color(0xFFF3F4F6);

  /// Input field fill (replaces Color(0xFFF9FAFB) in text fields)
  Color get inputBg => _dark ? const Color(0xFF1A1230) : const Color(0xFFF9FAFB);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Headings / strong primary text — dark purple in light mode so it reads
  /// as purple, not black. Deep indigo (#1A0A2E) was indistinguishable from black.
  Color get textPrimary => _dark ? const Color(0xFFF0EAFF) : const Color(0xFF3D1A78);

  /// Body text (replaces Color(0xFF374151))
  Color get textBody => _dark ? const Color(0xFFD4CAED) : const Color(0xFF374151);

  /// Secondary / meta text (replaces Color(0xFF4B5563) / Color(0xFF6B7280))
  Color get textSecondary => _dark ? const Color(0xFF9B8EC4) : const Color(0xFF6B7280);

  /// Hint / placeholder text (replaces Color(0xFF9CA3AF) / Color(0xFFD1D5DB))
  Color get textHint => _dark ? const Color(0xFF6B5F8A) : const Color(0xFF9CA3AF);

  // ── Borders ───────────────────────────────────────────────────────────────
  /// Purple brand border (replaces Color(0xFFE9D5FF))
  Color get borderPurple => _dark ? const Color(0xFF3D2460) : const Color(0xFFE9D5FF);

  /// Mid-weight purple border (replaces Color(0xFFD8B4FE))
  Color get borderPurpleMid => _dark ? const Color(0xFF5B3490) : const Color(0xFFD8B4FE);

  /// Neutral gray border (replaces Color(0xFFE5E7EB))
  Color get borderGray => _dark ? const Color(0xFF2D2440) : const Color(0xFFE5E7EB);

  /// Very subtle divider line
  Color get divider => _dark ? const Color(0xFF231A3A) : const Color(0xFFF3F4F6);

  // ── Brand surfaces ────────────────────────────────────────────────────────
  /// Purple tint surface (replaces AppTheme.primarySurface / Color(0xFFF3EEFF))
  Color get primarySurface =>
      _dark ? const Color(0xFF2A1850) : AppTheme.primarySurface;

  /// Slightly deeper purple surface (replaces Color(0xFFEDE9FE))
  Color get primarySurfaceMid =>
      _dark ? const Color(0xFF341D60) : const Color(0xFFEDE9FE);

  // ── Semantic states ───────────────────────────────────────────────────────
  Color get successSurface =>
      _dark ? const Color(0xFF0D2818) : const Color(0xFFF0FDF4);
  Color get warningSurface =>
      _dark ? const Color(0xFF1E1400) : const Color(0xFFFFFBEB);
  Color get errorSurface =>
      _dark ? const Color(0xFF1E0808) : const Color(0xFFFEF2F2);

  // ── Shell / nav ───────────────────────────────────────────────────────────
  Color get navBg => _dark ? const Color(0xFF130E22) : Colors.white;
  Color get navBorder => _dark ? const Color(0xFF2D2060) : const Color(0xFFE9D5FF);
  Color get shellGradientTop =>
      _dark ? const Color(0xFF0D0A1A) : Colors.white;
  Color get shellGradientBottom =>
      _dark ? const Color(0xFF150E28) : const Color(0xFFF3EEFF);
}
