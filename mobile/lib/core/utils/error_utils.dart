import 'package:dio/dio.dart';

/// Extracts a clean, human-readable error message from any exception type.
///
/// Priority:
///   DioException  → message set by [ErrorInterceptor] (already parsed from API body)
///   Exception     → strips the "Exception: " prefix Flutter adds
///   Anything else → toString() as a fallback
String parseError(dynamic error) {
  if (error is DioException) {
    return error.message?.isNotEmpty == true
        ? error.message!
        : _statusFallback(error.response?.statusCode);
  }
  final s = error.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  return s;
}

String _statusFallback(int? status) => switch (status) {
      400 => 'Invalid request.',
      401 => 'Invalid credentials.',
      403 => 'Access denied.',
      404 => 'Not found.',
      409 => 'Conflict — this already exists.',
      422 => 'Validation failed.',
      429 => 'Too many requests. Please slow down.',
      500 || 502 || 503 => 'Server error. Please try again later.',
      _   => 'Something went wrong.',
    };
