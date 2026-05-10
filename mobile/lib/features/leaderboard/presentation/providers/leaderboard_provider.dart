import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final leaderboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/leaderboard');
  return response.data as Map<String, dynamic>;
});

final friendLeaderboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/leaderboard/friends');
  return response.data as Map<String, dynamic>;
});
