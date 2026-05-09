import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading stats: $e')),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI cards row
              Row(children: [
                _KpiCard(label: 'Total Users', value: '${stats['totalUsers']}', icon: Icons.people, color: Colors.blue),
                const SizedBox(width: 16),
                _KpiCard(label: 'Active (7d)', value: '${stats['activeUsersLast7Days']}', icon: Icons.trending_up, color: Colors.green),
                const SizedBox(width: 16),
                _KpiCard(label: 'Avg Reading', value: '${(stats['averageReadingHoursPerUser'] as num).toStringAsFixed(1)}h', icon: Icons.access_time, color: Colors.orange),
                const SizedBox(width: 16),
                _KpiCard(label: 'Total Books', value: '${stats['totalBooks']}', icon: Icons.library_books, color: Colors.purple),
              ]),
              const SizedBox(height: 32),

              // Activity chart
              Text('Reading Activity (last 14 days)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _buildSpots(stats['last14DaysActivity'] as List? ?? []),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots(List activity) {
    return activity.asMap().entries.map((e) {
      final item = e.value as Map;
      return FlSpot(e.key.toDouble(), (item['activeUsers'] as int).toDouble());
    }).toList();
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }
}
