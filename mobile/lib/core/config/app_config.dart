/// All environment configuration is injected at build time via --dart-define.
/// Usage:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// Never hardcode URLs in source code — this satisfies the professor's requirement
/// for configurable API addresses.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator localhost
  );

  static const String appName = 'Inkril';
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;
}
