import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inkril_mobile/main.dart';
import 'package:inkril_mobile/core/providers/auth_provider.dart';
import 'package:inkril_mobile/core/router/app_router.dart';
import 'package:inkril_mobile/features/reader/presentation/providers/reader_settings_provider.dart';

void main() {
  group('InkrilApp smoke tests', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('renders without crashing — unauthenticated welcome flow',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAuthenticatedProvider.overrideWith((ref) => false),
            hasSeenWelcomeProvider.overrideWith((ref) async => false),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const InkrilApp(initialLocation: '/welcome'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('renders without crashing — authenticated library view',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAuthenticatedProvider.overrideWith((ref) => true),
            hasSeenWelcomeProvider.overrideWith((ref) async => true),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const InkrilApp(initialLocation: '/library'),
        ),
      );

      // Pump a bounded number of frames — the library screen fires live API
      // requests that never resolve in tests, so pumpAndSettle would hang.
      // We only assert that the widget tree initialises without crashing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
