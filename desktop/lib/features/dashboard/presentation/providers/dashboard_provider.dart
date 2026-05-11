import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Parameterised by [days] (7 / 14 / 30) so the dashboard time-range
/// filter can switch without re-fetching unrelated data.
final dashboardStatsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  final response = await dio.get(
    '/api/reports/dashboard',
    queryParameters: {'days': days},
  );
  return response.data as Map<String, dynamic>;
});
