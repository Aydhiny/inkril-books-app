import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/profile_provider.dart';
import '../providers/reading_heatmap_provider.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => _ProfileShimmer(),
          error: (e, _) => AppErrorWidget(
            error: e,
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: (profile) => RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(profile: profile, ref: ref),
                  const SizedBox(height: 20),
                  _IdentityBlock(profile: profile),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: context.borderPurple),
                  const SizedBox(height: 16),
                  _AddFriendsButton(),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: context.borderPurple),
                  const SizedBox(height: 24),
                  _StatisticsSection(profile: profile),
                  const SizedBox(height: 24),
                  _TrophyShelf(profile: profile),
                  const SizedBox(height: 24),
                  _YearlyGoalSection(profile: profile),
                  const SizedBox(height: 24),
                  _WeeklyProgressSection(profile: profile),
                  const SizedBox(height: 24),
                  _ReadingHeatmap(year: DateTime.now().year),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar — back arrow (left) + avatar circle (right)
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Map<String, dynamic> profile;
  final WidgetRef ref;
  const _TopBar({required this.profile, required this.ref});

  @override
  Widget build(BuildContext context) {
    final firstName = profile['firstName'] as String? ?? '';
    final lastName  = profile['lastName']  as String? ?? '';
    final userName  = profile['userName']  as String? ?? '';
    final initials  = _initials(firstName, lastName, userName);
    final photoUrl  = profile['profilePhotoUrl'] as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ← back / close
        GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library');
            }
          },
          child: const Icon(Icons.chevron_left_rounded,
              size: 30, color: AppTheme.primary),
        ),
        const Spacer(),
        // Avatar
        Stack(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFD8B4FE), width: 2.5),
                color: const Color(0xFFEDE9FE),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 144,
                      errorWidget: (_, __, ___) =>
                          _AvatarInitials(initials: initials, large: true),
                      placeholder: (_, __) =>
                          _AvatarInitials(initials: initials, large: true),
                    )
                  : _AvatarInitials(initials: initials, large: true),
            ),
            // Gear + logout overlay buttons — small, bottom-right of avatar
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _MiniIconBtn(
                    icon: Icons.manage_accounts_outlined,
                    onTap: () => context.push('/account-settings')),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 4),
        // Logout
        _MiniIconBtn(
          icon: Icons.logout_rounded,
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  String _initials(String first, String last, String user) {
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    return user.isNotEmpty ? user[0].toUpperCase() : '?';
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _LogoutSheet(),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: context.primarySurface,
          shape: BoxShape.circle,
          border: Border.all(color: context.borderPurpleMid, width: 1.5),
        ),
        child: Icon(icon, size: 16, color: AppTheme.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Identity block — title, name · username, joined line, friends count
// ─────────────────────────────────────────────────────────────────────────────

class _IdentityBlock extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _IdentityBlock({required this.profile});

  @override
  Widget build(BuildContext context) {
    final firstName   = profile['firstName']   as String? ?? '';
    final lastName    = profile['lastName']    as String? ?? '';
    final userName    = profile['userName']    as String? ?? '';
    final booksRead   = (profile['booksRead']   as num?)?.toInt() ?? 0;
    final friendCount = (profile['friendCount'] as num?)?.toInt() ?? 0;
    final fullName    = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final joinedYear  = _joinedYear(profile);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // "User Profile" title
      Text(
        'User Profile',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 6),

      // Name · username
      if (fullName.isNotEmpty || userName.isNotEmpty)
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 15, height: 1.4, color: context.textBody),
            children: [
              if (fullName.isNotEmpty)
                TextSpan(
                  text: fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              if (fullName.isNotEmpty && userName.isNotEmpty)
                TextSpan(
                  text: ' · ',
                  style: TextStyle(color: context.textSecondary),
                ),
              if (userName.isNotEmpty)
                TextSpan(
                  text: userName,
                  style: TextStyle(color: context.textSecondary),
                ),
            ],
          ),
        ),

      const SizedBox(height: 4),

      Text(
        joinedYear != null
            ? 'Joined $joinedYear, $booksRead Books read.'
            : '$booksRead Books read.',
        style: TextStyle(fontSize: 13, color: context.textSecondary),
      ),

      const SizedBox(height: 6),

      // Friends count — purple, tappable
      GestureDetector(
        onTap: () => context.push('/friends'),
        child: Text(
          '$friendCount ${friendCount == 1 ? 'Friend' : 'Friends'}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
      ),
    ]);
  }

  String? _joinedYear(Map<String, dynamic> profile) {
    final raw = profile['createdAt'] as String? ?? profile['joinedAt'] as String?;
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw);
    return dt != null ? '${dt.year}' : null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Friends button — full width
// ─────────────────────────────────────────────────────────────────────────────

class _AddFriendsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.push('/friends'),
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: const Text(
          'Add Friends',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          backgroundColor: AppTheme.primarySurface,
          side: const BorderSide(color: AppTheme.primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Statistics — two side-by-side cards
// ─────────────────────────────────────────────────────────────────────────────

class _StatisticsSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _StatisticsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final streak        = profile['currentStreak']     as int? ?? 0;
    final totalHoursRaw = (profile['totalReadingHours'] as num?)?.toDouble() ?? 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Statistics',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/reading-stats'),
            child: _StatCard(
              emoji: '🔥',
              rawValue: streak.toDouble(),
              suffix: '',
              label: 'Longest Streak',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/reading-stats'),
            child: _StatCard(
              emoji: '⏰',
              rawValue: totalHoursRaw,
              suffix: 'h',
              label: 'Hours read',
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final double rawValue;
  final String suffix;
  final String label;
  const _StatCard({
    required this.emoji,
    required this.rawValue,
    required this.suffix,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          AnimatedCount(
            target: rawValue,
            suffix: suffix,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
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
// Yearly goal — Goodreads-style ring + progress bar
// Hidden when yearlyBookGoal == 0 (no goal set).
// ─────────────────────────────────────────────────────────────────────────────

class _YearlyGoalSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _YearlyGoalSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final goal = (profile['yearlyBookGoal'] as num?)?.toInt() ?? 0;
    if (goal == 0) return const SizedBox.shrink();

    final read   = (profile['yearlyBooksRead'] as num?)?.toInt() ?? 0;
    final year   = DateTime.now().year;
    final progress = (goal > 0 ? (read / goal).clamp(0.0, 1.0) : 0.0);
    final done   = read >= goal;
    final pct    = (progress * 100).round();

    // Ring colours
    const ringBg    = Color(0xFFEDE9FE);
    const ringFg    = AppTheme.primary;
    const goldColor = Color(0xFFF59E0B);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        '$year Reading Goal',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderPurple, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Ring
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 96,
                height: 96,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => CustomPaint(
                    painter: _RingPainter(
                      progress: value,
                      bgColor: ringBg,
                      fgColor: done ? goldColor : ringFg,
                      strokeWidth: 10,
                    ),
                  ),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                if (done)
                  const Text('🏆', style: TextStyle(fontSize: 26))
                else ...[
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ]),
            ]),
          ),

          const SizedBox(width: 20),

          // Right side
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // "X of Y books" headline
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15, color: context.textBody),
                  children: [
                    TextSpan(
                      text: '$read ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: done ? goldColor : context.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'of $goal books',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: ringBg,
                    valueColor: AlwaysStoppedAnimation(
                        done ? goldColor : ringFg),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Motivational caption
              Text(
                done
                    ? '🎉 Goal crushed! Set a new one in Settings.'
                    : _caption(read, goal),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  String _caption(int read, int goal) {
    final left = goal - read;
    if (left == 0) return '🎉 Done!';
    if (left == 1) return 'Just 1 book to go!';
    return '$left books to go — you got this!';
  }
}

// Arc painter — draws a background circle + a foreground arc from 12 o'clock
class _RingPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final double strokeWidth;
  const _RingPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -1.5707963267948966; // -π/2 (12 o'clock)
    const fullSweep  = 6.283185307179586;   // 2π

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fullSweep * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fgColor != fgColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly progress — LINE chart matching the screenshot
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyProgressSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _WeeklyProgressSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weeklyStats = profile['weeklyStats'] as List? ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Weekly progress',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderPurple, width: 1.5),
        ),
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.22).clamp(160.0, 220.0),
          child: _LineChart(weeklyStats: weeklyStats),
        ),
      ),
    ]);
  }
}

class _LineChart extends StatelessWidget {
  final List weeklyStats;
  const _LineChart({required this.weeklyStats});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'Tu', 'W', 'Th', 'Fr', 'Sa', 'Su'];

    // Build data points; if no data show flat line at 0
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      double val = 0;
      if (i < weeklyStats.length) {
        val = ((weeklyStats[i] as Map)['minutesRead'] as num? ?? 0).toDouble();
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
            color: AppTheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: AppTheme.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
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
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= dayLabels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dayLabels[idx],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: chartMax / 4,
              getTitlesWidget: (v, _) {
                return Text(
                  v.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: context.textSecondary),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.divider,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar initials fallback
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final String initials;
  final bool large;
  const _AvatarInitials({required this.initials, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: large ? 24 : 18,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile loading shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top bar skeleton
        Row(children: [
          ShimmerWrapper(child: ShimmerBox(width: 30, height: 30, radius: 8)),
          const Spacer(),
          ShimmerWrapper(child: ShimmerBox(width: 72, height: 72, radius: 36)),
        ]),
        const SizedBox(height: 20),
        // Identity skeleton
        ShimmerWrapper(child: ShimmerBox(width: 180, height: 22, radius: 8)),
        const SizedBox(height: 10),
        ShimmerWrapper(child: ShimmerBox(width: 240, height: 16, radius: 6)),
        const SizedBox(height: 8),
        ShimmerWrapper(child: ShimmerBox(width: 140, height: 14, radius: 5)),
        const SizedBox(height: 20),
        Divider(height: 1, color: context.borderPurple),
        const SizedBox(height: 16),
        ShimmerWrapper(child: ShimmerBox(width: double.infinity, height: 52, radius: 14)),
        const SizedBox(height: 16),
        Divider(height: 1, color: context.borderPurple),
        const SizedBox(height: 24),
        ShimmerWrapper(child: ShimmerBox(width: 100, height: 20, radius: 6)),
        const SizedBox(height: 14),
        const ShimmerStatCards(),
        const SizedBox(height: 24),
        ShimmerWrapper(child: ShimmerBox(width: 140, height: 20, radius: 6)),
        const SizedBox(height: 14),
        ShimmerWrapper(
          child: Container(
            height: (MediaQuery.sizeOf(context).height * 0.22).clamp(160.0, 220.0),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderPurple, width: 1.5),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duolingo-style logout confirmation bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.borderPurpleMid, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: context.borderPurpleMid,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('👋', style: TextStyle(fontSize: 32))),
        ),
        const SizedBox(height: 16),
        Text(
          'Sign Out?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You\'ll need to sign back in to access your reading progress.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                side: BorderSide(color: context.borderGray, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(0, 52),
              ),
              child: const Text('Stay', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count-up animated number — animates from 0 → target over 800 ms on first build
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedCount extends StatelessWidget {
  final num target;
  final String suffix;
  final TextStyle style;
  const AnimatedCount({
    super.key,
    required this.target,
    this.suffix = '',
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) {
        final display = target is int
            ? '${value.round()}$suffix'
            : '${value.toStringAsFixed(1)}$suffix';
        return Text(display, style: style);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trophy shelf — computed from profile data; locked badges tease what's next
// ─────────────────────────────────────────────────────────────────────────────

class _TrophyShelf extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _TrophyShelf({required this.profile});

  List<_BadgeData> _badges() {
    final booksRead     = (profile['booksRead']          as num?)?.toInt()    ?? 0;
    final longestStreak = (profile['longestStreak']      as num?)?.toInt()    ?? 0;
    final totalHours    = (profile['totalReadingHours']  as num?)?.toDouble() ?? 0.0;
    final friendCount   = (profile['friendCount']        as num?)?.toInt()    ?? 0;

    return [
      _BadgeData(emoji: '📖', label: 'First Book',    hint: 'Read 1 book',        unlocked: booksRead >= 1),
      _BadgeData(emoji: '📚', label: 'Bookworm',       hint: 'Read 5 books',        unlocked: booksRead >= 5),
      _BadgeData(emoji: '🦁', label: 'Literary Lion',  hint: 'Read 10 books',       unlocked: booksRead >= 10),
      _BadgeData(emoji: '🔥', label: 'Streak Starter', hint: '3-day streak',        unlocked: longestStreak >= 3),
      _BadgeData(emoji: '🌋', label: 'On Fire',        hint: '7-day streak',        unlocked: longestStreak >= 7),
      _BadgeData(emoji: '💎', label: 'Unbreakable',    hint: '30-day streak',       unlocked: longestStreak >= 30),
      _BadgeData(emoji: '⏰', label: 'Dedicated',      hint: '10 hours read',       unlocked: totalHours >= 10),
      _BadgeData(emoji: '🏆', label: 'Century Club',   hint: '100 hours read',      unlocked: totalHours >= 100),
      _BadgeData(emoji: '👥', label: 'Social Reader',  hint: '5 friends',           unlocked: friendCount >= 5),
      _BadgeData(emoji: '🦉', label: 'Night Owl',      hint: 'Read past midnight',  unlocked: false, comingSoon: true),
      _BadgeData(emoji: '⚡', label: 'Speed Reader',   hint: '400+ WPM session',    unlocked: false, comingSoon: true),
      _BadgeData(emoji: '🌍', label: 'Globe Trotter',  hint: '5 different genres',  unlocked: false, comingSoon: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badges();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Trophy Shelf',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: badges.length,
        itemBuilder: (_, i) => _TrophyTile(badge: badges[i]),
      ),
    ]);
  }
}

class _BadgeData {
  final String emoji;
  final String label;
  final String hint;
  final bool unlocked;
  final bool comingSoon;
  const _BadgeData({
    required this.emoji,
    required this.label,
    required this.hint,
    required this.unlocked,
    this.comingSoon = false,
  });
}

class _TrophyTile extends StatelessWidget {
  final _BadgeData badge;
  const _TrophyTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final locked = !badge.unlocked;
    return Tooltip(
      message: badge.hint,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: locked
              ? context.cardBg
              : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: locked
                ? context.borderPurple
                : const Color(0xFFD8B4FE),
            width: badge.unlocked ? 2 : 1,
          ),
          boxShadow: badge.unlocked
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: locked
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.dst),
              child: Opacity(
                opacity: locked ? 0.4 : 1.0,
                child: Text(
                  badge.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                badge.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: locked
                      ? context.textSecondary
                      : AppTheme.primary,
                ),
              ),
            ),
            if (badge.comingSoon)
              Text(
                'soon',
                style: TextStyle(
                  fontSize: 8,
                  color: context.textSecondary.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reading heatmap — GitHub-style calendar grid of daily reading minutes
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingHeatmap extends ConsumerWidget {
  final int year;
  const _ReadingHeatmap({required this.year});

  // Intensity buckets: 0 = nothing, 1-4 = light → max
  static int _bucket(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 15) return 1;
    if (minutes < 30) return 2;
    if (minutes < 60) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(readingHeatmapProvider(year));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        '$year Reading Activity',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderPurple, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: heatmapAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
          error: (_, __) => const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Could not load activity',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ),
          ),
          data: (days) => _HeatmapGrid(year: year, days: days),
        ),
      ),
    ]);
  }
}

class _HeatmapGrid extends StatelessWidget {
  final int year;
  final List<HeatmapDay> days;

  const _HeatmapGrid({required this.year, required this.days});

  static const _cellSize = 11.0;
  static const _cellGap  = 2.0;
  static const _stride   = _cellSize + _cellGap;
  // Show label for Mon, Wed, Fri only to avoid crowding
  static const _dayLabels = ['', 'M', '', 'W', '', 'F', ''];

  // 5 intensity colours — index 0 = inactive day, 1-4 = active
  static const _colors = [
    Color(0xFFEDE9FE), // 0 — empty (very light purple-grey)
    Color(0xFFC4B5FD), // 1 — <15 min
    Color(0xFF8B5CF6), // 2 — 15–29 min
    Color(0xFF7C3AED), // 3 — 30–59 min
    Color(0xFF4C1D95), // 4 — 60+ min
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    // Fast lookup: "yyyy-MM-dd" → minutes
    final minuteMap = <String, int>{
      for (final d in days) _key(d.date): d.minutesRead,
    };

    // Align grid to Monday. weekday: 1=Mon … 7=Sun.
    final jan1 = DateTime(year, 1, 1);
    final startOffset = (jan1.weekday - 1) % 7;
    final gridStart = jan1.subtract(Duration(days: startOffset));

    final dec31     = DateTime(year, 12, 31);
    final totalDays = dec31.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    final activeDays   = days.length;
    final totalMinutes = days.fold(0, (s, d) => s + d.minutesRead);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Month labels ──────────────────────────────────────────────────
      Row(children: [
        const SizedBox(width: 16),
        SizedBox(
          height: 14,
          width: totalWeeks * _stride,
          child: CustomPaint(
            painter: _MonthLabelPainter(
              year: year,
              gridStart: gridStart,
              totalWeeks: totalWeeks,
              stride: _stride,
              color: labelColor,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 4),

      // ── Scrollable grid ───────────────────────────────────────────────
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Day-of-week column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _dayLabels.map((label) => SizedBox(
              width: 14,
              height: _stride,
              child: Text(
                label,
                style: TextStyle(fontSize: 8, color: labelColor),
                textAlign: TextAlign.right,
              ),
            )).toList(),
          ),
          const SizedBox(width: 2),

          // Week columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(totalWeeks, (w) {
              return Column(
                children: List.generate(7, (d) {
                  final date = gridStart.add(Duration(days: w * 7 + d));
                  final inYear = date.year == year;
                  final mins   = minuteMap[_key(date)] ?? 0;
                  final bucket = inYear ? _ReadingHeatmap._bucket(mins) : -1;

                  return Tooltip(
                    message: inYear && mins > 0
                        ? '${_fmtDate(date)}: $mins min'
                        : inYear
                            ? _fmtDate(date)
                            : '',
                    preferBelow: false,
                    child: Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.all(_cellGap / 2),
                      decoration: BoxDecoration(
                        color: bucket < 0
                            ? Colors.transparent
                            : _colors[bucket],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ]),
      ),

      const SizedBox(height: 10),

      // ── Legend + summary line ─────────────────────────────────────────
      Row(children: [
        Expanded(
          child: Text(
            activeDays == 0
                ? 'No reading sessions yet this year.'
                : '$activeDays day${activeDays == 1 ? '' : 's'} · '
                    '${(totalMinutes / 60).toStringAsFixed(1)} h total',
            style: TextStyle(fontSize: 11, color: labelColor),
          ),
        ),
        Text('Less', style: TextStyle(fontSize: 9, color: labelColor)),
        const SizedBox(width: 4),
        ..._colors.map((c) => Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
        const SizedBox(width: 4),
        Text('More', style: TextStyle(fontSize: 9, color: labelColor)),
      ]),
    ]);
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// Paints month abbreviations above the correct week column.
class _MonthLabelPainter extends CustomPainter {
  final int year;
  final DateTime gridStart;
  final int totalWeeks;
  final double stride;
  final Color color;

  const _MonthLabelPainter({
    required this.year,
    required this.gridStart,
    required this.totalWeeks,
    required this.stride,
    required this.color,
  });

  static const _abbrevs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    int? lastMonth;

    for (int w = 0; w < totalWeeks; w++) {
      final monday = gridStart.add(Duration(days: w * 7));
      if (monday.year != year) continue; // skip lead-in weeks before Jan 1

      final m = monday.month;
      if (m == lastMonth) continue;
      lastMonth = m;

      tp.text = TextSpan(
        text: _abbrevs[m - 1],
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(w * stride, 0));
    }
  }

  @override
  bool shouldRepaint(_MonthLabelPainter old) =>
      old.year != year || old.gridStart != gridStart || old.color != color;
}
