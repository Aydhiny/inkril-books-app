/// All environment configuration is injected at build time via --dart-define.
/// Usage:
///   flutter run \
///     --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
///     --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_…
///
/// Never hardcode URLs or secrets in source code.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator localhost
  );

  /// Stripe publishable key — NOT secret, safe to commit.
  /// Must be supplied at build time via --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_…
  /// (or pk_live_… for production). There is intentionally no fallback value here
  /// to prevent a hardcoded test key from slipping into a release build.
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );

  static const String appName = 'Inkril';
  static const String appVersion = '1.0.0';
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;
}
