import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _days = 14;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider(_days));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // ── Time-range filter ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7,  label: Text('7d')),
                ButtonSegment(value: 14, label: Text('14d')),
                ButtonSegment(value: 30, label: Text('30d')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading stats: $e')),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── KPI cards ─────────────────────────────────────────
              Row(children: [
                _KpiCard(
                    label: 'Total Users',
                    value: '${stats['totalUsers']}',
                    icon: Icons.people,
                    color: Colors.blue),
                const SizedBox(width: 16),
                _KpiCard(
                    label: 'Active (7d)',
                    value: '${stats['activeUsersLast7Days']}',
                    icon: Icons.trending_up,
                    color: Colors.green),
                const SizedBox(width: 16),
                _KpiCard(
                    label: 'Avg Reading',
                    value:
                        '${(stats['averageReadingHoursPerUser'] as num).toStringAsFixed(1)}h',
                    icon: Icons.access_time,
                    color: Colors.orange),
                const SizedBox(width: 16),
                _KpiCard(
                    label: 'Total Books',
                    value: '${stats['totalBooks']}',
                    icon: Icons.library_books,
                    color: Colors.purple),
              ]),
              const SizedBox(height: 32),

              // ── Activity chart + pie side by side ─────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: line chart
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reading Activity (last $_days days)',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: LineChart(LineChartData(
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _buildSpots(
                                      stats['last14DaysActivity'] as List? ?? []),
                                  isCurved: true,
                                  color: Theme.of(context).colorScheme.primary,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true, reservedSize: 30)),
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true, reservedSize: 40)),
                                topTitles: AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: false),
                            )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right: reading status pie chart
                    Expanded(
                      flex: 2,
                      child: _ReadingStatusPie(
                        completed: stats['completedBooksCount'] as int? ?? 0,
                        inProgress: stats['inProgressBooksCount'] as int? ?? 0,
                      ),
                    ),
                  ],
                ),
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
      return FlSpot(
          e.key.toDouble(), (item['activeUsers'] as int).toDouble());
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI card
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color)),
            const SizedBox(width: 16),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reading status pie chart
// Completed (100%) vs In-progress (0–99%) books across all users.
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingStatusPie extends StatefulWidget {
  final int completed;
  final int inProgress;
  const _ReadingStatusPie({required this.completed, required this.inProgress});

  @override
  State<_ReadingStatusPie> createState() => _ReadingStatusPieState();
}

class _ReadingStatusPieState extends State<_ReadingStatusPie> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final total = widget.completed + widget.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reading Status',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (total == 0)
          const SizedBox(
            height: 220,
            child: Center(child: Text('No data yet')),
          )
        else
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = null;
                        return;
                      }
                      _touchedIndex =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: [
                  PieChartSectionData(
                    value: widget.completed.toDouble(),
                    color: Colors.green,
                    title: _touchedIndex == 0
                        ? '${widget.completed}\nCompleted'
                        : '${(widget.completed / total * 100).round()}%',
                    radius: _touchedIndex == 0 ? 80 : 70,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: widget.inProgress.toDouble(),
                    color: Colors.orange,
                    title: _touchedIndex == 1
                        ? '${widget.inProgress}\nIn Progress'
                        : '${(widget.inProgress / total * 100).round()}%',
                    radius: _touchedIndex == 1 ? 80 : 70,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 3,
              ),
            ),
          ),
        // Legend
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _LegendDot(color: Colors.green, label: 'Completed (${widget.completed})'),
          const SizedBox(width: 20),
          _LegendDot(color: Colors.orange, label: 'In Progress (${widget.inProgress})'),
        ]),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
