import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart' show AnimatedCount;

class ReadingStatsScreen extends ConsumerWidget {
  const ReadingStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (e, _) => Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('⚠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Could not load stats',
                  style: TextStyle(
                      color: context.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: const Text('Retry'),
              ),
            ]),
          ),
          data: (profile) => _StatsBody(profile: profile),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBody extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _StatsBody({required this.profile});

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = (widget.profile['currentStreak'] as num?)?.toInt() ?? 0;
    final totalHoursRaw =
        (widget.profile['totalReadingHours'] as num?)?.toDouble() ?? 0.0;
    final weeklyStats = widget.profile['weeklyStats'] as List? ?? [];

    // Today's minutes = last entry in weekly stats
    final todayMinutes = weeklyStats.isNotEmpty
        ? ((weeklyStats.last as Map)['minutesRead'] as num?)?.toInt() ?? 0
        : 0;

    // Total minutes this week
    final weekMinutes = weeklyStats.fold<int>(
      0,
      (sum, s) => sum + ((s as Map)['minutesRead'] as num? ?? 0).toInt(),
    );

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/library');
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: context.borderPurpleMid, width: 1.5),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: AppTheme.primary, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Reading Stats',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ]),
          ),
        ),

        // ── Streak hero card ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B21A8), Color(0xFF9333EA),
                      Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pulsing fire
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: const Text('🔥',
                        style: TextStyle(fontSize: 56)),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedCount(
                        target: streak.toDouble(),
                        suffix: '',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'day streak',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Today + Total ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Expanded(
                child: _StatTile(
                  emoji: '⏱',
                  label: "Today's reading",
                  value: todayMinutes >= 60
                      ? '${(todayMinutes / 60).toStringAsFixed(1)}h'
                      : '${todayMinutes}m',
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  emoji: '📚',
                  label: 'This week',
                  value: weekMinutes >= 60
                      ? '${(weekMinutes / 60).toStringAsFixed(1)}h'
                      : '${weekMinutes}m',
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ]),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              Expanded(
                child: _StatTile(
                  emoji: '⏰',
                  label: 'Total hours',
                  value: totalHoursRaw % 1 == 0
                      ? '${totalHoursRaw.toInt()}h'
                      : '${totalHoursRaw.toStringAsFixed(1)}h',
                  color: AppTheme.goldMedal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  emoji: '🗓',
                  label: 'Active days',
                  value: _activeDays(weeklyStats).toString(),
                  color: AppTheme.progressGreen,
                ),
              ),
            ]),
          ),
        ),

        // ── Weekly chart ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text(
              'Weekly progress',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: context.borderPurple, width: 1.5),
              ),
              child: SizedBox(
                height: 200,
                child: _WeeklyChart(weeklyStats: weeklyStats),
              ),
            ),
          ),
        ),

        // ── Motivational section ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _MotivationalCard(streak: streak, todayMinutes: todayMinutes),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  int _activeDays(List weeklyStats) {
    return weeklyStats
        .where((s) =>
            ((s as Map)['minutesRead'] as num? ?? 0).toInt() > 0)
        .length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat tile
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderPurple, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly chart — reuses same LineChart logic as profile
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List weeklyStats;
  const _WeeklyChart({required this.weeklyStats});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'Tu', 'W', 'Th', 'Fr', 'Sa', 'Su'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      double val = 0;
      if (i < weeklyStats.length) {
        val = ((weeklyStats[i] as Map)['minutesRead'] as num? ?? 0)
            .toDouble();
      }
      spots.add(FlSpot(i.toDouble(), val));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final chartMax = maxY < 10 ? 60.0 : (maxY * 1.25).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: chartMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.primaryLight,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: AppTheme.primaryLight,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.25),
                  AppTheme.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dayLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dayLabels[idx],
                      style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}m',
                style: TextStyle(
                    fontSize: 10, color: context.textSecondary),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark
                ? const Color(0xFF2D2440)
                : const Color(0xFFE9D5FF),
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Motivational card
// ─────────────────────────────────────────────────────────────────────────────

class _MotivationalCard extends StatelessWidget {
  final int streak;
  final int todayMinutes;
  const _MotivationalCard(
      {required this.streak, required this.todayMinutes});

  String get _message {
    if (streak >= 30) return 'Incredible! 30+ day streak. You\'re unstoppable! 🏆';
    if (streak >= 14) return 'Two weeks strong! Keep the momentum going! ⚡';
    if (streak >= 7) return 'One week streak! You\'re building a real habit! 🌟';
    if (streak >= 3) return 'Nice streak going! Three days and counting! 💪';
    if (todayMinutes >= 30) return 'Great session today! Keep reading! 📖';
    if (todayMinutes > 0) return 'Every minute counts. You\'re making progress! ✨';
    return 'Start reading today to build your streak! 🔥';
  }

  String get _tip {
    if (todayMinutes < 15) return 'Tip: Even 15 minutes a day builds lasting habits';
    if (todayMinutes < 30) return 'Tip: Try to reach your daily reading goal!';
    return 'Tip: Great readers make great thinkers';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderPurpleMid, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _message,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tip,
          style: TextStyle(
            fontSize: 13,
            color: context.textSecondary,
            height: 1.4,
          ),
        ),
      ]),
    );
  }
}
