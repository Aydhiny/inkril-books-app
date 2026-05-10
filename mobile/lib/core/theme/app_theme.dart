import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Inkril brand palette
  static const Color primary = Color(0xFF6B21A8);     // purple-800
  static const Color primaryLight = Color(0xFFA855F7); // purple-500
  static const Color primarySurface = Color(0xFFF3E8FF); // purple-100
  static const Color streakOrange = Color(0xFFF97316);
  static const Color progressGreen = Color(0xFF22C55E);
  static const Color goldMedal = Color(0xFFF59E0B);
  static const Color silverMedal = Color(0xFF94A3B8);
  static const Color bronzeMedal = Color(0xFFB45309);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: primaryLight,
          primaryContainer: primarySurface,
          onPrimaryContainer: primary,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F5FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F5FF),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF3D1A78),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: Color(0xFF6B21A8)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE9D5FF), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: primary, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: primary, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: primarySurface,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primary, size: 26);
            }
            return const IconThemeData(color: Color(0xFF9CA3AF), size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: primary, fontSize: 11, fontWeight: FontWeight.w700);
            }
            return const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11);
          }),
          elevation: 8,
          shadowColor: Color(0x1A6B21A8),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3D1A78)),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3D1A78)),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3D1A78)),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF3D1A78)),
          bodyLarge: TextStyle(color: Color(0xFF374151)),
          bodyMedium: TextStyle(color: Color(0xFF4B5563)),
          bodySmall: TextStyle(color: Color(0xFF6B7280)),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0A1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primaryLight,
          onPrimary: Colors.white,
          secondary: primary,
          primaryContainer: const Color(0xFF2A1850),
          onPrimaryContainer: const Color(0xFFE9D5FF),
          surface: const Color(0xFF18122A),
          onSurface: const Color(0xFFF0EAFF),
          surfaceContainerHighest: const Color(0xFF201836),
          outline: const Color(0xFF3D2460),
          outlineVariant: const Color(0xFF2D2440),
          error: const Color(0xFFFF6B6B),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF18122A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFF3D2460), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1230),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF3D2460)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF3D2460)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: primaryLight, width: 2),
          ),
          labelStyle: TextStyle(color: Color(0xFF9B8EC4)),
          hintStyle: TextStyle(color: Color(0xFF6B5F8A)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF0EAFF)),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFF0EAFF)),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF0EAFF)),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF0EAFF)),
          bodyLarge: TextStyle(color: Color(0xFFD4CAED)),
          bodyMedium: TextStyle(color: Color(0xFFB8A9D4)),
          bodySmall: TextStyle(color: Color(0xFF9B8EC4)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF130E22),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFF0EAFF),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: Color(0xFFA855F7)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryLight,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: primaryLight, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF18122A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF18122A),
          modalBackgroundColor: Color(0xFF18122A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D2060),
          contentTextStyle: const TextStyle(color: Color(0xFFF0EAFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
