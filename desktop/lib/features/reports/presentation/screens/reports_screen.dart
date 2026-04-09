import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('$e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(dashboardStatsProvider),
              child: const Text('Retry'),
            ),
          ]),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardStatsProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _StatsRow(stats: stats),
                const SizedBox(height: 32),
                Text('Reading Activity (Last 7 Days)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: _ReadingActivityChart(data: stats['dailyReadingActivity'] as List? ?? []),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Card(
                        title: 'Top Books',
                        child: _TopBooksList(books: stats['topBooks'] as List? ?? []),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _Card(
                        title: 'Genre Distribution',
                        child: SizedBox(
                          height: 200,
                          child: _GenrePieChart(genres: stats['genreDistribution'] as List? ?? []),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _Card(
                  title: 'Top Readers',
                  child: _TopReadersList(readers: stats['topReaders'] as List? ?? []),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatTile(label: 'Total Users', value: '${stats['totalUsers'] ?? 0}', icon: Icons.people),
      const SizedBox(width: 16),
      _StatTile(label: 'Total Books', value: '${stats['totalBooks'] ?? 0}', icon: Icons.library_books),
      const SizedBox(width: 16),
      _StatTile(
          label: 'Reading Sessions',
          value: '${stats['totalReadingSessions'] ?? 0}',
          icon: Icons.menu_book),
      const SizedBox(width: 16),
      _StatTile(
        label: 'Avg. Session (min)',
        value: '${(stats['averageSessionMinutes'] as num?)?.toStringAsFixed(1) ?? '0'}',
        icon: Icons.timer_outlined,
      ),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ReadingActivityChart extends StatelessWidget {
  final List data;
  const _ReadingActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No activity data yet.'));
    return BarChart(BarChartData(
      barGroups: List.generate(data.length, (i) {
        final d = data[i] as Map;
        return BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(
            toY: (d['totalMinutes'] as num? ?? 0).toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 22,
            borderRadius: BorderRadius.circular(4),
          )],
        );
      }),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= data.length) return const SizedBox.shrink();
            final date = (data[i] as Map)['date'] as String? ?? '';
            return Text(
              date.length >= 10 ? date.substring(5, 10) : date,
              style: const TextStyle(fontSize: 10),
            );
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, _) =>
              Text('${v.toInt()}m', style: const TextStyle(fontSize: 10)),
        )),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
    ));
  }
}

class _TopBooksList extends StatelessWidget {
  final List books;
  const _TopBooksList({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('No data yet.'));
    }
    return Column(
      children: books.take(5).map((b) {
        final book = b as Map;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.book_outlined),
          title: Text(book['title'] as String? ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people, size: 14),
            const SizedBox(width: 4),
            Text('${book['readerCount'] ?? 0}'),
          ]),
        );
      }).toList(),
    );
  }
}

class _GenrePieChart extends StatelessWidget {
  final List genres;
  const _GenrePieChart({required this.genres});

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const Center(child: Text('No data yet.'));
    const colors = [
      Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFF44336),
      Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFF00BCD4),
      Color(0xFFFFEB3B), Color(0xFF795548),
    ];
    return PieChart(PieChartData(
      sections: List.generate(genres.length.clamp(0, 8), (i) {
        final g = genres[i] as Map;
        return PieChartSectionData(
          value: (g['count'] as num? ?? 0).toDouble(),
          title: g['name'] as String? ?? '',
          color: colors[i % colors.length],
          radius: 80,
          titleStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        );
      }),
      sectionsSpace: 2,
    ));
  }
}

class _TopReadersList extends StatelessWidget {
  final List readers;
  const _TopReadersList({required this.readers});

  @override
  Widget build(BuildContext context) {
    if (readers.isEmpty) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('No data yet.'));
    }
    return Column(
      children: List.generate(readers.length.clamp(0, 10), (i) {
        final reader = readers[i] as Map;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: i < 3
                ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][i]
                : Theme.of(context).colorScheme.secondaryContainer,
            child: Text('${i + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          title: Text(reader['userName'] as String? ?? ''),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.timer_outlined, size: 14),
            const SizedBox(width: 4),
            Text('${reader['totalMinutes'] ?? 0} min'),
          ]),
        );
      }),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
