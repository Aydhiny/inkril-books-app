import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';

final usersProvider = FutureProvider.family<Map<String, dynamic>, ({String searchTerm, bool? isBlocked})>(
  (ref, params) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));
    final queryParams = <String, dynamic>{
      if (params.searchTerm.isNotEmpty) 'searchTerm': params.searchTerm,
      if (params.isBlocked != null) 'isBlocked': params.isBlocked,
    };
    final response = await dio.get('/api/users', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  },
);

Future<void> blockUser(String userId, bool block) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  await dio.put('/api/users/$userId/status', data: {
    'userId': userId,
    'isBlocked': block,
    'reason': null,
  });
}

Future<void> deleteUser(String userId) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  await dio.delete('/api/users/$userId');
}

Future<void> updateUserRoles(String userId, List<String> roles) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  await dio.put('/api/users/$userId/roles', data: {
    'userId': userId,
    'roles': roles,
  });
}
