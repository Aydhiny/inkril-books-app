import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  final response = await dio.get('/api/reports/dashboard');
  return response.data as Map<String, dynamic>;
});
