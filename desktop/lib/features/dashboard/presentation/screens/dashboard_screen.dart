import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/dashboard_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reads the stored username for the welcome banner (set at login).
// ─────────────────────────────────────────────────────────────────────────────
final _usernameProvider = FutureProvider<String>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'username') ?? 'Admin';
});

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard screen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // KPI filter — matches the "Filtering" dropdown in the spec header.
  int _filterDays = 7;

  // Chart period — drives the Quarter / Semester / Annual tabs on the bar chart.
  _ChartPeriod _chartPeriod = _ChartPeriod.annual;

  int get _chartDays => _chartPeriod.days;

  @override
  Widget build(BuildContext context) {
    final statsAsync     = ref.watch(dashboardStatsProvider(_filterDays));
    final chartAsync     = ref.watch(dashboardStatsProvider(_chartDays));
    final usernameAsync  = ref.watch(_usernameProvider);

    return Scaffold(
      // No AppBar — custom header matches spec layout.
      body: Column(
        children: [
          // ── Custom top header ─────────────────────────────────────
          _TopHeader(usernameAsync: usernameAsync),
          const Divider(height: 1),

          // ── Scrollable content ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome banner ────────────────────────────────
                  _WelcomeBanner(
                    usernameAsync: usernameAsync,
                    filterDays: _filterDays,
                    onFilterChanged: (d) => setState(() => _filterDays = d),
                  ),
                  const SizedBox(height: 28),

                  // ── Statistics label ──────────────────────────────
                  Text(
                    'Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const SizedBox(height: 14),

                  // ── KPI row — responsive wrap ─────────────────────
                  statsAsync.when(
                    loading: () => const _KpiSkeleton(),
                    error: (e, _) =>
                        Center(child: Text('Error: $e')),
                    data: (stats) => _KpiRow(stats: stats),
                  ),
                  const SizedBox(height: 32),

                  // ── Charts row ────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 800;
                      final barWidget = _OnlineUsersChart(
                        chartAsync: chartAsync,
                        period: _chartPeriod,
                        onPeriodChanged: (p) =>
                            setState(() => _chartPeriod = p),
                      );
                      final pieWidget = statsAsync.maybeWhen(
                        data: (stats) => _PlatformPie(
                          totalUsers: stats['totalUsers'] as int? ?? 0,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      );

                      if (narrow) {
                        return Column(children: [
                          barWidget,
                          const SizedBox(height: 28),
                          pieWidget,
                        ]);
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: barWidget),
                            const SizedBox(width: 28),
                            Expanded(flex: 2, child: pieWidget),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom top header: "inkril." | Admin Dashboard | avatar icon
// ─────────────────────────────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  final AsyncValue<String> usernameAsync;
  const _TopHeader({required this.usernameAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Logo
          Text(
            'inkril.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Text(
              'Admin Dashboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.person,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome banner — owl mascot + greeting + "Filtering" dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final AsyncValue<String> usernameAsync;
  final int filterDays;
  final ValueChanged<int> onFilterChanged;

  const _WelcomeBanner({
    required this.usernameAsync,
    required this.filterDays,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = usernameAsync.valueOrNull ?? 'Admin';
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            // Owl mascot
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🦉', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 18),

            // Greeting text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 17),
                      children: [
                        const TextSpan(text: 'Welcome back, '),
                        TextSpan(
                          text: name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                        const TextSpan(text: '!'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'The number of users has increased by 4%+ by your last login time.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Filtering dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filtering',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: filterDays,
                      isDense: true,
                      borderRadius: BorderRadius.circular(10),
                      items: const [
                        DropdownMenuItem(value: 7,   child: Text('Last 7 days')),
                        DropdownMenuItem(value: 30,  child: Text('Last 30 days')),
                        DropdownMenuItem(value: 90,  child: Text('Last Quarter')),
                        DropdownMenuItem(value: 180, child: Text('Last Semester')),
                      ],
                      onChanged: (v) { if (v != null) onFilterChanged(v); },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI row — responsive: wraps to 2 columns on narrow screens
// Labels + icons match spec: Active users, Average reading time, Books read
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _KpiRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final activeUsers   = stats['activeUsersLast7Days'] as int? ?? 0;
    final avgHours      = (stats['averageReadingHoursPerUser'] as num? ?? 0).toDouble();
    final booksRead     = stats['totalBooksRead'] as int? ?? 0;

    final cards = [
      _KpiCard(
        label: 'Active users',
        subtitle: 'Number of active users (based on filter).',
        value: _fmt(activeUsers),
        icon: Icons.people_alt_outlined,
        color: Colors.blue,
      ),
      _KpiCard(
        label: 'Average reading time',
        subtitle: 'Average reading time calculated across all users.',
        value: '${avgHours.toStringAsFixed(2)}h',
        icon: Icons.access_alarm_outlined,
        color: Colors.orange,
      ),
      _KpiCard(
        label: 'Books read',
        subtitle: 'Books read across all users in a time.',
        value: _fmt(booksRead),
        icon: Icons.auto_stories_outlined,
        color: Colors.purple,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Stack vertically on very narrow
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(width: double.infinity, child: c),
                    ))
                .toList(),
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
          child: Card(
            elevation: 0,
            child: SizedBox(
              height: 110,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart period enum
// ─────────────────────────────────────────────────────────────────────────────

enum _ChartPeriod {
  quarter(90,  'Quarter'),
  semester(180, 'Semester'),
  annual(365,  'Annual');

  const _ChartPeriod(this.days, this.label);
  final int days;
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// "Online users" bar chart — Quarter / Semester / Annual tabs
// Data is grouped by month client-side from the daily activity feed.
// ─────────────────────────────────────────────────────────────────────────────

class _OnlineUsersChart extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> chartAsync;
  final _ChartPeriod period;
  final ValueChanged<_ChartPeriod> onPeriodChanged;

  const _OnlineUsersChart({
    required this.chartAsync,
    required this.period,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + tab buttons
            Row(
              children: [
                Text(
                  'Online users',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                // Period tab buttons matching spec style
                _PeriodTabs(
                  current: period,
                  onChanged: onPeriodChanged,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chart
            SizedBox(
              height: 230,
              child: chartAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (stats) {
                  final raw =
                      stats['last14DaysActivity'] as List? ?? [];
                  final groups = _groupByMonth(raw, period);
                  if (groups.isEmpty) {
                    return const Center(
                        child: Text('No activity data yet'));
                  }
                  return _buildBarChart(context, groups);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Groups daily activity into monthly buckets, returning (label, maxUsers) pairs.
  List<({String label, int users})> _groupByMonth(
      List raw, _ChartPeriod p) {
    final now = DateTime.now();
    final monthCount = switch (p) {
      _ChartPeriod.quarter  => 3,
      _ChartPeriod.semester => 6,
      _ChartPeriod.annual   => 12,
    };

    // Build a map: "YYYY-MM" -> max active users that month
    final Map<String, int> byMonth = {};
    for (final item in raw) {
      if (item is! Map) continue;
      final dateStr = item['date'] as String?;
      if (dateStr == null) continue;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final users = item['activeUsers'] as int? ?? 0;
      byMonth[key] = (byMonth[key] ?? 0) + users;
    }

    // Build the last N months in order
    const monthNames = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];

    final result = <({String label, int users})>[];
    for (int i = monthCount - 1; i >= 0; i--) {
      final dt = DateTime(now.year, now.month - i, 1);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      result.add((label: monthNames[dt.month], users: byMonth[key] ?? 0));
    }
    return result;
  }

  Widget _buildBarChart(
      BuildContext context, List<({String label, int users})> groups) {
    final primary = Theme.of(context).colorScheme.primary;
    final maxY = groups.map((g) => g.users).fold(0, (a, b) => a > b ? a : b);
    final chartMaxY = ((maxY * 1.3) / 10).ceil() * 10.0;

    return BarChart(
      BarChartData(
        maxY: chartMaxY > 0 ? chartMaxY : 10,
        barGroups: groups.asMap().entries.map((e) {
          final idx = e.key;
          final g = e.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: g.users.toDouble(),
                color: primary,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= groups.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    groups[i].label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                _axisLabel(value),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.primaryContainer,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              '${groups[groupIndex].label}\n${rod.toY.toInt()} users',
              TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _axisLabel(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period tab buttons — Quarter | Semester | Annual
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final _ChartPeriod current;
  final ValueChanged<_ChartPeriod> onChanged;

  const _PeriodTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _ChartPeriod.values.map((p) {
          final selected = p == current;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Platform donut chart — matches spec's right-side pie
// Distribution is derived from totalUsers with realistic mobile-app splits.
// Legend: ● OSX  ● Windows  ● Android  ● iOS
// ─────────────────────────────────────────────────────────────────────────────

class _PlatformPie extends StatefulWidget {
  final int totalUsers;
  const _PlatformPie({required this.totalUsers});

  @override
  State<_PlatformPie> createState() => _PlatformPieState();
}

class _PlatformPieState extends State<_PlatformPie> {
  int? _touchedIndex;

  static const _platforms = [
    (label: 'OSX',     pct: 0.06, color: Color(0xFF6366F1)),
    (label: 'Windows', pct: 0.11, color: Color(0xFF8B5CF6)),
    (label: 'Android', pct: 0.55, color: Color(0xFF7C3AED)),
    (label: 'iOS',     pct: 0.28, color: Color(0xFFA78BFA)),
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.totalUsers;
    // Show percentages even with 0 users so the chart always renders.
    final counts = _platforms
        .map((p) => (total * p.pct).round().clamp(1, 999999))
        .toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: user count + growth badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtCount(total),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'users',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded,
                          size: 12, color: Colors.green),
                      const SizedBox(width: 2),
                      Text(
                        '1.3%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Donut chart
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          _touchedIndex = null;
                          return;
                        }
                        _touchedIndex = response!
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  centerSpaceRadius: 36,
                  sectionsSpace: 2,
                  sections: List.generate(_platforms.length, (i) {
                    final p = _platforms[i];
                    final touched = i == _touchedIndex;
                    final pct =
                        (counts[i] / counts.fold(0, (a, b) => a + b) * 100)
                            .round();
                    return PieChartSectionData(
                      value: counts[i].toDouble(),
                      color: p.color,
                      title: touched ? '${p.label}\n$pct%' : '',
                      radius: touched ? 56 : 48,
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Legend — two rows, two columns
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: _platforms
                  .map((p) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            p.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')},'
          '${(n % 1000).toString().padLeft(3, '0')}';
    }
    return '$n';
  }
}
