import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final myProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/users/me/profile');
  return response.data as Map<String, dynamic>;
});

final userProfileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/users/$userId/profile');
  return response.data as Map<String, dynamic>;
});

final pendingFriendRequestsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/friends/requests/pending');
  return response.data as List<dynamic>;
});
