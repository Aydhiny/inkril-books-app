import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primaryColor = Color(0xFF4F46E5);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor),
        dataTableTheme: DataTableThemeData(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor, brightness: Brightness.dark),
      );
}
