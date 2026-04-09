import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: AppConfig.connectTimeoutSeconds),
    receiveTimeout: const Duration(seconds: AppConfig.receiveTimeoutSeconds),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.addAll([
    ref.read(authInterceptorProvider),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => print('[DIO] $o'),
    ),
  ]);

  return dio;
});
