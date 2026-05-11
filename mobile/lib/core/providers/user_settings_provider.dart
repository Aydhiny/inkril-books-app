import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

/// Fetches the current user's settings from GET /api/user-settings.
/// Cached for the session lifetime — invalidate on settings save.
final userSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/user-settings');
  return response.data as Map<String, dynamic>;
});
