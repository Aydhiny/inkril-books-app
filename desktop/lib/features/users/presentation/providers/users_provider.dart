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
