import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onMarkAll: () => _markAllRead(context, ref)),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const _NotificationsShimmer(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📡', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load notifications',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(notificationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: context.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('🔔', style: TextStyle(fontSize: 36)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "You're all caught up!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No new notifications',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async => ref.invalidate(notificationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = notifications[i] as Map;
                        return _NotificationCard(
                          notification: n,
                          onMarkRead: () => _markRead(context, ref, n['id'] as String),
                          onDismiss: () => _dismiss(context, ref, n['id'] as String),
                          onRespond: (accept) => _respondToFriendRequest(
                            context, ref,
                            n['referenceId'] as String,
                            n['id'] as String,
                            accept,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markRead(BuildContext context, WidgetRef ref, String id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/notifications/$id/read');
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/notifications/read-all');
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref, String id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/notifications/$id');
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  Future<void> _respondToFriendRequest(
    BuildContext context,
    WidgetRef ref,
    String friendRequestId,
    String notificationId,
    bool accept,
  ) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '/api/friends/requests/$friendRequestId/respond',
        data: {'accept': accept},
      );
      // Mark the notification as read so the action buttons disappear
      await dio.put('/api/notifications/$notificationId/read');
      ref.invalidate(notificationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Friend request accepted! 🎉' : 'Friend request declined.'),
            backgroundColor: accept ? AppTheme.progressGreen : null,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onMarkAll;
  const _Header({required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          TextButton(
            onPressed: onMarkAll,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Mark all read'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final Map notification;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;
  final void Function(bool accept) onRespond;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDismiss,
    required this.onRespond,
  });

  bool get _isFriendRequest =>
      (notification['type'] as String?) == 'FriendRequest';

  bool get _isRead => notification['isRead'] as bool? ?? false;

  bool get _canRespond =>
      _isFriendRequest &&
      !_isRead &&
      notification['referenceId'] != null;

  @override
  Widget build(BuildContext context) {
    final type    = notification['type'] as String? ?? '';
    final title   = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final config  = _typeConfig(type);

    return Dismissible(
      key: Key(notification['id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Remove notification',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
            content: Text('Remove this notification?',
                style: TextStyle(color: context.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: context.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: _isRead ? null : onMarkRead,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isRead ? context.cardBg : context.primarySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isRead
                  ? context.borderPurpleMid
                  : AppTheme.primary.withValues(alpha: 0.5),
              width: _isRead ? 1.5 : 2,
            ),
            boxShadow: _isRead
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon bubble
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(config.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                                  _isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        if (!_isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ── Inline Accept / Ignore for friend requests ──
                    if (_canRespond) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onRespond(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Accept',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onRespond(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.textSecondary,
                              side: BorderSide(
                                  color: context.borderGray, width: 1.5),
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Ignore',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NotifConfig _typeConfig(String type) => switch (type) {
        'FriendRequest'         => _NotifConfig('👋', const Color(0xFF8B5CF6)),
        'FriendRequestAccepted' => _NotifConfig('🤝', const Color(0xFF10B981)),
        'NewBook'               => _NotifConfig('📚', const Color(0xFF3B82F6)),
        'FriendReadingMilestone'=> _NotifConfig('🏆', const Color(0xFFF59E0B)),
        'WeeklyReadingSummary'  => _NotifConfig('📊', const Color(0xFF6366F1)),
        _                       => _NotifConfig('🔔', const Color(0xFF9CA3AF)),
      };
}

class _NotifConfig {
  final String emoji;
  final Color color;
  const _NotifConfig(this.emoji, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsShimmer extends StatelessWidget {
  const _NotificationsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => ShimmerBox(
        width: double.infinity,
        height: 80,
        radius: 18,
      ),
    );
  }
}
