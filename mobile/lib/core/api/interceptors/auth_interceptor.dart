import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Attaches the JWT Bearer token to every outgoing request.
///
/// On a 401 response it attempts a silent token refresh via
/// POST /api/auth/refresh.  If the refresh succeeds the original
/// request is retried transparently.  If it fails (invalid / expired
/// refresh token) all stored credentials are wiped and [onForceLogout]
/// is called so the router redirects the user to the login screen.
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final void Function() onForceLogout;

  // Guard against infinite retry loops: if we're already refreshing,
  // don't attempt another refresh on the retry's 401.
  bool _isRefreshing = false;

  AuthInterceptor({
    required FlutterSecureStorage storage,
    required String baseUrl,
    required this.onForceLogout,
  })  : _storage = storage,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  // ── Attach token ──────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // ── Handle 401 ───────────────────────────────────────────────────────────

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      // No refresh token stored — force login
      await _clearAndLogout();
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      // Use a plain Dio (no interceptors) to avoid recursive 401 handling
      final refreshDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await refreshDio.post(
        '$_baseUrl/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken  = response.data['accessToken']  as String;
      final newRefreshToken = response.data['refreshToken'] as String;

      // Persist both tokens — not just the access token
      await _storage.write(key: 'access_token',  value: newAccessToken);
      await _storage.write(key: 'refresh_token', value: newRefreshToken);

      // Retry the original request with the fresh token
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await refreshDio.fetch(err.requestOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      // Refresh itself failed — clear everything and send the user to login
      await _clearAndLogout();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _clearAndLogout() async {
    await _storage.deleteAll();
    onForceLogout();
  }
}
