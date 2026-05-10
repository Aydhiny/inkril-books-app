import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// Animated amber banner that slides in from the top whenever the device
/// goes offline. Slides back out automatically when connectivity is restored.
///
/// Usage — add it as the first child of your root [Stack]:
/// ```dart
/// Stack(children: [
///   YourPageContent(),
///   const OfflineBanner(),
/// ])
/// ```
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: isOnline ? Curves.easeIn : Curves.easeOutCubic,
      offset: isOnline ? const Offset(0, -1) : Offset.zero,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          color: const Color(0xFFF59E0B), // amber-500
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.wifi_off_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'You\'re offline — cached books still open. Progress syncs when you reconnect.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
