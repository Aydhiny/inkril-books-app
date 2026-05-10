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
    await _storage.deleteAll();
  }

  Future<void> _persistTokens(AuthResponse auth) async {
    await _storage.write(key: 'access_token', value: auth.accessToken);
    await _storage.write(key: 'refresh_token', value: auth.refreshToken);
    await _storage.write(key: 'user_id', value: auth.userId);
    await _storage.write(key: 'user_name', value: auth.userName);
  }
}
