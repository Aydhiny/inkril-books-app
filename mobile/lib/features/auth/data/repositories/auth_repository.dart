import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository(this._dio, this._storage);

  Future<AuthResponse> login(String userNameOrEmail, String password) async {
    final response = await _dio.post('/api/auth/login', data: {
      'userNameOrEmail': userNameOrEmail,
      'password': password,
    });
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistTokens(auth);
    return auth;
  }

  Future<AuthResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String userName,
    required String password,
  }) async {
    final response = await _dio.post('/api/auth/register', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'userName': userName,
      'password': password,
    });
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistTokens(auth);
    return auth;
  }

  Future<AuthResponse> verifyEmail({
    required String email,
    required String otp,
  }) async {
    // Backend returns a full AuthResponse on success — store tokens so the
    // user is immediately logged in after verifying their email.
    final response = await _dio.post(
      '/api/auth/verify-email',
      data: {'email': email, 'otp': otp},
    );
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistTokens(auth);
    return auth;
  }

  Future<void> resendVerification(String email) async {
    await _dio.post('/api/auth/resend-verification', data: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/api/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post('/api/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<void> logout() async {
    // Revoke the refresh token on the server before clearing local storage.
    // This is the §5 requirement: logout must invalidate the token server-side,
    // not just delete it locally. We swallow errors so a network failure never
    // gets the user stuck on the logged-in screen.
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _dio.post('/api/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {
      // Silent — local clear-out proceeds regardless
    }
    await _storage.deleteAll();
  }

  Future<void> _persistTokens(AuthResponse auth) async {
    await _storage.write(key: 'access_token',  value: auth.accessToken);
    await _storage.write(key: 'refresh_token', value: auth.refreshToken);
    await _storage.write(key: 'user_id',       value: auth.userId);
    await _storage.write(key: 'user_name',     value: auth.userName);
    await _storage.write(key: 'user_role',     value: auth.role);
  }
}
