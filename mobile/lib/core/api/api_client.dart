import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: AppConfig.connectTimeoutSeconds),
    receiveTimeout: const Duration(seconds: AppConfig.receiveTimeoutSeconds),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.addAll([
    ErrorInterceptor(),
    AuthInterceptor(
      storage: const FlutterSecureStorage(),
      baseUrl: AppConfig.apiBaseUrl,
      onForceLogout: () =>
          ref.read(isAuthenticatedProvider.notifier).state = false,
    ),
  ]);

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => debugPrint('[DIO] $o'),
    ));
  }

  return dio;
});
