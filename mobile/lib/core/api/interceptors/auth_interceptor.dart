import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(const FlutterSecureStorage());
});

/// Attaches the JWT Bearer token to every request.
/// On 401, attempts a token refresh before retrying once.
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  AuthInterceptor(this._storage);

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

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          // Attempt token refresh
          final refreshDio = Dio();
          final response = await refreshDio.post(
            '${err.requestOptions.baseUrl}/api/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newToken = response.data['accessToken'] as String;
          await _storage.write(key: 'access_token', value: newToken);

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await refreshDio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
          return;
        } catch (_) {
          // Refresh failed — clear tokens, user must re-login
          await _storage.deleteAll();
        }
      }
    }
    handler.next(err);
  }
}
