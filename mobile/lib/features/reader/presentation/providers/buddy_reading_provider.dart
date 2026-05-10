import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

/// Fetches the current page and progress for friends who have the same book
/// in their library. Returns an empty list when there are no friends reading
/// the same book or the request fails.
///
/// Use [family] so each book gets its own cached provider slot.
final buddyProgressProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bookId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/user-books/$bookId/friends-progress');
  return (response.data as List).cast<Map<String, dynamic>>();
});
