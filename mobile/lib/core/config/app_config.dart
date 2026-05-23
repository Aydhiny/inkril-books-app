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

  /// Stripe publishable key (pk_test_… for test, pk_live_… for production).
  /// Obtain from https://dashboard.stripe.com/apikeys
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_YOUR_STRIPE_PUBLISHABLE_KEY_HERE',
  );

  static const String appName = 'Inkril';
  static const String appVersion = '1.0.0';
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;
}
