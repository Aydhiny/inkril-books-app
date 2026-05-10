import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

/// One day's reading data as returned by GET /api/users/me/reading-stats/heatmap.
class HeatmapDay {
  final DateTime date;
  final int minutesRead;

  const HeatmapDay({required this.date, required this.minutesRead});

  factory HeatmapDay.fromJson(Map<String, dynamic> json) {
    // Server returns DateOnly in "yyyy-MM-dd" format.
    final raw = json['date'] as String;
    return HeatmapDay(
      date: DateTime.parse(raw),
      minutesRead: (json['minutesRead'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Fetch heatmap data for [year]. Use the current year by default.
/// Cached per year so switching back doesn't re-fetch.
final readingHeatmapProvider =
    FutureProvider.family<List<HeatmapDay>, int>((ref, year) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get(
    '/api/users/me/reading-stats/heatmap',
    queryParameters: {'year': year},
  );
  return (response.data as List)
      .cast<Map<String, dynamic>>()
      .map(HeatmapDay.fromJson)
      .toList();
});
