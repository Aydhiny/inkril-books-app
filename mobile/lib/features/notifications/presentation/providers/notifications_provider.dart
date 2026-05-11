import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final notificationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/notifications');
  return response.data as List<dynamic>;
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
