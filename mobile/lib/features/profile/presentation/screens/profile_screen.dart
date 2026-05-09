import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_empty_state.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/profile_provider.dart';
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
                  _WeeklyProgressSection(profile: profile),
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
                  ? Image.network(photoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _AvatarInitials(initials: initials, large: true))
                  : _AvatarInitials(initials: initials, large: true),
            ),
            // Gear + logout overlay buttons — small, bottom-right of avatar
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _MiniIconBtn(
                    icon: Icons.settings_outlined,
                    onTap: () => context.go('/settings')),
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
    final totalHoursStr = totalHoursRaw % 1 == 0
        ? '${totalHoursRaw.toInt()}'
        : totalHoursRaw.toStringAsFixed(1);

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
          height: 200,
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
            height: 200,
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
