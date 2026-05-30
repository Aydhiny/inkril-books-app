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

  // Set the publishable key synchronously — this is just a field assignment.
  // applySettings() (the MethodChannel call that hits the Android main thread)
  // is deferred to the first post-frame callback so it never blocks startup
  // rendering and avoids the "Skipped N frames" ANR on cold launch.
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('[Stripe] init failed: $e');
    }
  });

  // Use the default FlutterSecureStorage options (no encryptedSharedPreferences
  // override) so this reads from the same Android backend as every other place
  // in the app that constructs FlutterSecureStorage().
  // Mixing AndroidOptions across instances splits the data into two separate
  // backing stores and causes KeyStoreException / AEADBadTagException on read.
  const storage = FlutterSecureStorage();

  String? userId;
  bool hasSeenWelcome = false;
  String? savedThemeRaw;

  try {
    userId          = await storage.read(key: 'user_id');
    hasSeenWelcome  = await storage.read(key: 'has_seen_welcome') == 'true';
    savedThemeRaw   = await storage.read(key: 'app_theme_mode');
  } catch (e) {
    // Corrupted keystore entry — wipe and treat user as logged-out.
    // They will need to log in again; that write regenerates clean entries.
    debugPrint('[Storage] SecureStorage read failed, clearing corrupt data: $e');
    try { await storage.deleteAll(); } catch (_) {}
    userId          = null;
    hasSeenWelcome  = false;
    savedThemeRaw   = null;
  }

  final prefs = await SharedPreferences.getInstance();

  // Parse the saved theme before runApp so the first frame renders with the
  // correct ThemeMode — avoids the system→saved flash on every cold start.
  final initialTheme = ThemeNotifier.themeFromString(savedThemeRaw);

  runApp(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWith((ref) => userId != null),
      // Eagerly provide the welcome flag so the router redirect can use it
      // synchronously on the first frame without waiting for an async load.
      hasSeenWelcomeProvider.overrideWith((ref) async => hasSeenWelcome),
      // Inject the pre-loaded theme so ThemeNotifier skips its async _load()
      // and returns the correct mode on the very first build.
      themeProvider.overrideWith(() => ThemeNotifier(initialTheme)),
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
