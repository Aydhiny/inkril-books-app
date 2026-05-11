import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

/// Returns the personalised recommendation list from
/// GET /api/recommendations — hybrid content-based + collaborative.
final recommendationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/recommendations', queryParameters: {'count': 10});
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  return [];
});
