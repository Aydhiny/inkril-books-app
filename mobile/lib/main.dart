import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/reader/presentation/providers/reader_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Stripe with the publishable key injected at build time.
  // The publishable key is NOT secret — it's safe in source code.
  // Override for production: --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_…
  try {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
  } catch (e) {
    // Stripe init failure must not crash the app — payments simply won't work
    // until a valid key is provided. All other screens remain functional.
    debugPrint('[Stripe] init failed: $e');
  }

  // Read storage once at startup so the router guard has the correct
  // initial state before the first frame renders.
  const storage = FlutterSecureStorage();
  final userId          = await storage.read(key: 'user_id');
  final hasSeenWelcome  = await storage.read(key: 'has_seen_welcome') == 'true';
  final prefs           = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWith((ref) => userId != null),
      // Eagerly provide the welcome flag so the router redirect can use it
      // synchronously on the first frame without waiting for an async load.
      hasSeenWelcomeProvider.overrideWith((ref) async => hasSeenWelcome),
      // Reader settings backed by SharedPreferences — injected once at startup
      // so the StateNotifier can read/write preferences synchronously.
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: InkrilApp(initialLocation: hasSeenWelcome ? '/library' : '/welcome'),
  ));
}

class InkrilApp extends ConsumerWidget {
  final String initialLocation;
  const InkrilApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider(initialLocation));
    final themeMode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Inkril',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
