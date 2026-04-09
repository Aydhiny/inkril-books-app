import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('$e'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => ref.invalidate(myProfileProvider), child: const Text('Retry')),
          ]),
        ),
        data: (profile) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myProfileProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: profile['profilePhotoUrl'] != null
                        ? NetworkImage(profile['profilePhotoUrl'] as String)
                        : null,
                    child: profile['profilePhotoUrl'] == null
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile['userName'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (profile['bio'] != null && (profile['bio'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(profile['bio'] as String, style: const TextStyle(color: Colors.grey)),
                  ],
                  const SizedBox(height: 8),
                  if ((profile['currentStreak'] as int? ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🔥', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(
                          '${profile['currentStreak']} day streak',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                        ),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [
                _StatCard(
                  label: 'Total Hours',
                  value: '${profile['totalReadingHours'] ?? 0}h',
                  icon: Icons.access_time,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Books Read',
                  value: '${profile['booksRead'] ?? 0}',
                  icon: Icons.menu_book,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Friends',
                  value: '${profile['friendCount'] ?? 0}',
                  icon: Icons.group,
                ),
              ]),
              const SizedBox(height: 24),
              Text(
                'Weekly Reading',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: _WeeklyChart(weeklyStats: profile['weeklyStats'] as List? ?? []),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'Friends',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.push('/friends'),
                  child: const Text('See all'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List weeklyStats;
  const _WeeklyChart({required this.weeklyStats});

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return BarChart(BarChartData(
      barGroups: List.generate(weeklyStats.length.clamp(0, 7), (i) {
        final stat = weeklyStats[i] as Map;
        return BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(
            toY: (stat['minutesRead'] as num? ?? 0).toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          )],
        );
      }),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(
            v.toInt() < days.length ? days[v.toInt()] : '',
            style: const TextStyle(fontSize: 12),
          ),
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
