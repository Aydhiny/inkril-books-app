import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/profile_provider.dart';
import 'profile_screen.dart' show AnimatedCount;

class FriendProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  bool _requestSent = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => _FriendProfileShimmer(),
          error: (e, _) => AppErrorWidget(
            error: e,
            onRetry: () => ref.invalidate(userProfileProvider(widget.userId)),
          ),
          data: (profile) => RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async =>
                ref.invalidate(userProfileProvider(widget.userId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(profile: profile),
                  const SizedBox(height: 20),
                  _IdentityBlock(profile: profile),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFE9D5FF)),
                  const SizedBox(height: 16),
                  _SendFriendRequestButton(
                    userId: widget.userId,
                    sent: _requestSent,
                    onSent: () => setState(() => _requestSent = true),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE9D5FF)),
                  const SizedBox(height: 24),
                  _StatisticsSection(profile: profile),
                  const SizedBox(height: 24),
                  _WeeklyProgressSection(profile: profile),
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
// Top bar — back arrow (left) + avatar (right)
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _TopBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile['profilePhotoUrl'] as String?;
    final firstName = profile['firstName'] as String? ?? '';
    final lastName  = profile['lastName']  as String? ?? '';
    final userName  = profile['userName']  as String? ?? '';
    final initials  = _initials(firstName, lastName, userName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.chevron_left_rounded,
              size: 30, color: AppTheme.primary),
        ),
        const Spacer(),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD8B4FE), width: 2.5),
            color: const Color(0xFFEDE9FE),
          ),
          clipBehavior: Clip.antiAlias,
          child: photoUrl != null && photoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 144,
                  errorWidget: (_, __, ___) => _AvatarFallback(initials),
                  placeholder: (_, __) => _AvatarFallback(initials),
                )
              : _AvatarFallback(initials),
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
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback(this.initials);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Identity block — "X's Profile", name · username, joined, friends
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
    final displayName = fullName.isNotEmpty ? fullName : userName;
    final joinedYear  = _joinedYear(profile);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // "Name's Profile"
      Text(
        "${displayName.isNotEmpty ? displayName : 'User'}'s Profile",
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A0A2E),
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 6),

      // Full name · username
      if (fullName.isNotEmpty || userName.isNotEmpty)
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, height: 1.4),
            children: [
              if (fullName.isNotEmpty)
                TextSpan(
                  text: fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A0A2E)),
                ),
              if (fullName.isNotEmpty && userName.isNotEmpty)
                const TextSpan(
                    text: ' · ', style: TextStyle(color: Color(0xFF9CA3AF))),
              if (userName.isNotEmpty)
                TextSpan(
                  text: userName,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
            ],
          ),
        ),

      const SizedBox(height: 4),

      Text(
        joinedYear != null
            ? 'Joined $joinedYear, $booksRead Books read.'
            : '$booksRead Books read.',
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),

      const SizedBox(height: 6),

      Text(
        '$friendCount ${friendCount == 1 ? 'Friend' : 'Friends'}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    ]);
  }

  String? _joinedYear(Map<String, dynamic> p) {
    final raw =
        p['createdAt'] as String? ?? p['joinedAt'] as String?;
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw);
    return dt != null ? '${dt.year}' : null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Send friend request button
// ─────────────────────────────────────────────────────────────────────────────

class _SendFriendRequestButton extends ConsumerWidget {
  final String userId;
  final bool sent;
  final VoidCallback onSent;
  const _SendFriendRequestButton(
      {required this.userId, required this.sent, required this.onSent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: sent
          ? OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Request Sent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF22C55E),
                backgroundColor: const Color(0xFFF0FDF4),
                side: const BorderSide(color: Color(0xFF22C55E), width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: () async {
                try {
                  final dio = ref.read(dioProvider);
                  await dio.post('/api/friends/requests',
                      data: {'receiverId': userId});
                  onSent();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Friend request sent!'),
                        backgroundColor: AppTheme.progressGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Could not send — already friends or pending.')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Send Friend Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                backgroundColor: AppTheme.primarySurface,
                side: const BorderSide(color: AppTheme.primary, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Statistics section
// ─────────────────────────────────────────────────────────────────────────────

class _StatisticsSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _StatisticsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final streak        = profile['currentStreak']    as int? ?? 0;
    final totalHoursRaw = (profile['totalReadingHours'] as num?)?.toDouble() ?? 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Statistics',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A0A2E),
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _StatCard(emoji: '🔥', rawValue: streak.toDouble(), suffix: '', label: 'Longest Streak')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(emoji: '⏰', rawValue: totalHoursRaw, suffix: 'h', label: 'Hours read')),
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final double rawValue;
  final String suffix;
  final String label;
  const _StatCard({required this.emoji, required this.rawValue, required this.suffix, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
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
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A0A2E)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly progress — line chart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyProgressSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _WeeklyProgressSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weeklyStats = profile['weeklyStats'] as List? ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Weekly progress',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A0A2E),
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
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

    return LineChart(LineChartData(
      minX: 0, maxX: 6, minY: 0, maxY: chartMax,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: AppTheme.primary,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
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
                child: Text(dayLabels[idx],
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF))),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: chartMax / 4,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9CA3AF))),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: chartMax / 4,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: Color(0xFFF3F4F6),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friend profile loading shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _FriendProfileShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ShimmerWrapper(child: ShimmerBox(width: 30, height: 30, radius: 8)),
          const Spacer(),
          ShimmerWrapper(child: ShimmerBox(width: 72, height: 72, radius: 36)),
        ]),
        const SizedBox(height: 20),
        ShimmerWrapper(child: ShimmerBox(width: 200, height: 22, radius: 8)),
        const SizedBox(height: 10),
        ShimmerWrapper(child: ShimmerBox(width: 240, height: 16, radius: 6)),
        const SizedBox(height: 8),
        ShimmerWrapper(child: ShimmerBox(width: 120, height: 14, radius: 5)),
        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFE9D5FF)),
        const SizedBox(height: 16),
        ShimmerWrapper(child: ShimmerBox(width: double.infinity, height: 52, radius: 14)),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE9D5FF)),
        const SizedBox(height: 24),
        ShimmerWrapper(child: ShimmerBox(width: 100, height: 20, radius: 6)),
        const SizedBox(height: 14),
        const ShimmerStatCards(),
      ]),
    );
  }
}
