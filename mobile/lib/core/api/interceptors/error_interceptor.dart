import 'package:dio/dio.dart';

/// Transforms every [DioException] into a human-readable message by reading
/// the `detail` field from the API's RFC 7807 ProblemDetails response body.
///
/// Without this, the raw exception message ("DioException [bad response]: …")
/// reaches the UI and looks terrible in a SnackBar or error Text widget.
///
/// Priority order for the error message:
///   1. `detail` field in the JSON body  (e.g. "Invalid credentials.")
///   2. `title` field in the JSON body   (e.g. "Authentication failed.")
///   3. `errors` map joined             (FluentValidation 422 responses)
///   4. Generic fallback per status code
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = _extractMessage(err);
    handler.next(
      err.copyWith(
        message: message,
        error: message,
      ),
    );
  }

  String _extractMessage(DioException err) {
    // Network / timeout — no response from server
    if (err.response == null) {
      return switch (err.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout    ||
        DioExceptionType.sendTimeout       => 'Request timed out. Check your connection.',
        DioExceptionType.connectionError   => 'Cannot reach the server. Check your connection.',
        _                                  => 'A network error occurred.',
      };
    }

    final status = err.response!.statusCode ?? 0;
    final data   = err.response!.data;

    // Try to parse the RFC 7807 ProblemDetails body
    if (data is Map<String, dynamic>) {
      // 422 Validation — FluentValidation returns { errors: { field: ["msg"] } }
      if (data['errors'] is Map) {
        final errors = data['errors'] as Map;
        final messages = errors.values
            .expand((v) => v is List ? v : [v])
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.first;
      }

      final detail = data['detail'] as String?;
      if (detail != null && detail.isNotEmpty) return detail;

      final title = data['title'] as String?;
      if (title != null && title.isNotEmpty) return title;
    }

    // Generic fallback
    return switch (status) {
      400 => 'Invalid request. Please check your input.',
      401 => 'Invalid credentials.',
      403 => 'You don\'t have permission to do this.',
      404 => 'Not found.',
      409 => 'This already exists.',
      422 => 'Validation failed. Please check your input.',
      429 => 'Too many requests. Please slow down.',
      500 || 502 || 503 => 'Server error. Please try again later.',
      _   => 'Something went wrong (${status}).',
    };
  }
}
