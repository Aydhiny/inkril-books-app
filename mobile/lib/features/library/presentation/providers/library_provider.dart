import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final publicBooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/books');
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['items'] as List);
});

final bookDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/books/$bookId');
  return response.data as Map<String, dynamic>;
});

final bookReviewsProvider = FutureProvider.family<List<dynamic>, String>((ref, bookId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/books/$bookId/reviews');
  final data = response.data as Map<String, dynamic>;
  return data['items'] as List? ?? [];
});

final userLibraryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/user-books');
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
});

final genresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/genres');
  return List<Map<String, dynamic>>.from(response.data as List? ?? []);
});

final searchBooksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/books', queryParameters: {
    'searchTerm': query.trim(),
    'pageSize': 30,
  });
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
});

final challengesProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/challenges');
  return res.data as List<dynamic>;
});

final activityFeedProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/activity-feed');
  return res.data as List<dynamic>;
});
