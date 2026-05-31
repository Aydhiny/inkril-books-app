import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final publicBooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/books');
  final data = response.data as Map<String, dynamic>;
  // 'items' can be null if the page is empty — treat it as an empty list
  // rather than throwing, which would crash the library screen build.
  return List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
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

/// Returns the user's own random highlight (daily rotation) for Quote of the Day.
/// Returns null when the user has no highlights yet (falls back to static quotes in the UI).
final qotdProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/bookmarks/random-highlight');
  if (res.data == null) return null;
  return res.data as Map<String, dynamic>;
});

/// Bookmarks for a specific book — used by the book detail screen and reader panel.
/// The API returns a PagedList envelope {items:[...], ...} not a bare List.
final bookBookmarksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bookId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/bookmarks', queryParameters: {'bookId': bookId, 'pageSize': 100});
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map) {
    final items = (data as Map<String, dynamic>)['items'] as List? ?? [];
    return items.cast<Map<String, dynamic>>();
  }
  return [];
});

