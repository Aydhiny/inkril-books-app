import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable error state widget with contextual messaging.
/// Detects network/timeout errors and shows them differently from server errors.
///
/// Usage:
///   AppErrorWidget(error: e, onRetry: () => ref.invalidate(myProvider))
class AppErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final info = _classify(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: info.color.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Center(
                child: Text(info.emoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              info.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A0A2E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              customMessage ?? info.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),

            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Try again',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ErrorInfo _classify(Object error) {
    final msg = error.toString().toLowerCase();

    // Network / connectivity issues
    if (error is SocketException ||
        msg.contains('socketexception') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('no address associated')) {
      return _ErrorInfo(
        emoji: '📡',
        title: 'No connection',
        message: "Looks like you're offline. Check your Wi-Fi or mobile data and try again.",
        color: const Color(0xFF3B82F6),
      );
    }

    // Timeout
    if (msg.contains('timeout') ||
        msg.contains('connection timed out') ||
        msg.contains('timed out')) {
      return _ErrorInfo(
        emoji: '⏳',
        title: 'Connection timed out',
        message: "The server took too long to respond. It might be busy — give it a moment.",
        color: const Color(0xFFF59E0B),
      );
    }

    // 401 / auth
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return _ErrorInfo(
        emoji: '🔒',
        title: 'Session expired',
        message: 'Your session has expired. Please sign in again.',
        color: const Color(0xFFEF4444),
      );
    }

    // 403 / forbidden
    if (msg.contains('403') || msg.contains('forbidden')) {
      return _ErrorInfo(
        emoji: '🚫',
        title: "Access denied",
        message: "You don't have permission to view this.",
        color: const Color(0xFFEF4444),
      );
    }

    // 404 / not found
    if (msg.contains('404') || msg.contains('not found')) {
      return _ErrorInfo(
        emoji: '🔍',
        title: 'Not found',
        message: "We couldn't find what you're looking for. It may have been removed.",
        color: const Color(0xFF6B7280),
      );
    }

    // 5xx / server error
    if (msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('server error') ||
        msg.contains('internal')) {
      return _ErrorInfo(
        emoji: '🛠️',
        title: 'Server hiccup',
        message: "Something went wrong on our end. We're on it — please try again shortly.",
        color: const Color(0xFFEF4444),
      );
    }

    // Generic fallback
    return _ErrorInfo(
      emoji: '😕',
      title: 'Something went wrong',
      message: "An unexpected error occurred. Try refreshing — it usually helps.",
      color: const Color(0xFF6B7280),
    );
  }
}

class _ErrorInfo {
  final String emoji;
  final String title;
  final String message;
  final Color color;
  const _ErrorInfo({
    required this.emoji,
    required this.title,
    required this.message,
    required this.color,
  });
}
