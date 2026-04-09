import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notifications_none, size: 64),
                SizedBox(height: 16),
                Text('No notifications yet'),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = notifications[i] as Map;
                final isRead = n['isRead'] as bool? ?? false;
                return Dismissible(
                  key: Key(n['id'] as String),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Dismiss notification'),
                        content: const Text('Remove this notification?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => _dismiss(context, ref, n['id'] as String),
                  child: ListTile(
                    tileColor: isRead
                        ? null
                        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    leading: CircleAvatar(child: Icon(_iconForType(n['type'] as String? ?? ''))),
                    title: Text(
                      n['title'] as String? ?? '',
                      style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                    ),
                    subtitle: Text(
                      n['message'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _markRead(context, ref, n['id'] as String),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _markRead(BuildContext context, WidgetRef ref, String notificationId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/notifications/$notificationId/read');
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref, String notificationId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/notifications/$notificationId');
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'NewBook' => Icons.library_add,
      'FriendRequest' => Icons.person_add,
      'FriendRequestAccepted' => Icons.people,
      'FriendReadingMilestone' => Icons.emoji_events,
      _ => Icons.notifications,
    };
  }
}
