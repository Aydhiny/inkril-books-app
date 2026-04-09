/// Desktop app configuration — API URL is injected via --dart-define.
/// flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String appName = 'Inkril Admin';
}
