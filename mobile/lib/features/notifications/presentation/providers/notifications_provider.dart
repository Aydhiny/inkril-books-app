import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

/// Fetches the first page of notifications (20 items, newest first).
/// The timer in NotificationsScreen invalidates this every 30 s for auto-refresh.
final notificationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/notifications',
      queryParameters: {'pageNumber': 1, 'pageSize': 20});
  final data = response.data;
  // Backend now returns a PagedList envelope: { items: [...], ... }
  if (data is Map && data['items'] is List) return data['items'] as List<dynamic>;
  // Fallback for plain list (older API versions during transition)
  if (data is List) return data;
  return [];
});

/// Synchronously derived count of unread notifications.
/// Returns 0 while [notificationsProvider] is still loading so callers
/// don't need to handle the async case — the badge just stays hidden.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? [];
  return items
      .whereType<Map>()
      .where((n) => !(n['isRead'] as bool? ?? false))
      .length;
});
