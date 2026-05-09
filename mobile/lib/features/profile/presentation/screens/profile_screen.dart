import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 16),
              Text('$e', textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: const Text('Retry'),
              ),
            ]),
          ),
          data: (profile) => RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _ProfileHeader(profile: profile, ref: ref),
                  _StatsRow(profile: profile),
                  _WeeklySection(profile: profile),
                  _FriendsSection(profile: profile),
                  const SizedBox(height: 32),
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
// Header — avatar, name, username, add friends, settings
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final WidgetRef ref;
  const _ProfileHeader({required this.profile, required this.ref});

  @override
  Widget build(BuildContext context) {
    final firstName = profile['firstName'] as String? ?? '';
    final lastName = profile['lastName'] as String? ?? '';
    final userName = profile['userName'] as String? ?? '';
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final initials = _initials(firstName, lastName, userName);
    final streak = profile['currentStreak'] as int? ?? 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          // Top row: title + edit + settings + logout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                  onPressed: () => context.push('/profile/edit'),
                  tooltip: 'Edit profile',
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  onPressed: () => context.go('/settings'),
                  tooltip: 'Settings',
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                  onPressed: () => _confirmLogout(context, ref),
                  tooltip: 'Sign out',
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: profile['profilePhotoUrl'] != null
                    ? ClipOval(
                        child: Image.network(
                          profile['profilePhotoUrl'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarInitials(initials: initials),
                        ),
                      )
                    : _AvatarInitials(initials: initials),
              ),
              if (streak > 0)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.streakOrange,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🔥', style: TextStyle(fontSize: 10)),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (fullName.isNotEmpty)
            Text(
              fullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (userName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '@$userName',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          // Joined date
          if (profile['createdAt'] != null || profile['joinedAt'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'Joined ${_joinedDate(profile)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (profile['bio'] != null &&
              (profile['bio'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              profile['bio'] as String,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/friends'),
            icon: const Icon(Icons.person_add_outlined,
                size: 16, color: Colors.white),
            label: const Text('Add Friends',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 2),
              minimumSize: const Size(160, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String first, String last, String user) {
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    return user.isNotEmpty ? user[0].toUpperCase() : '?';
  }

  String _joinedDate(Map<String, dynamic> profile) {
    final raw = profile['createdAt'] as String?
        ?? profile['joinedAt'] as String?;
    if (raw == null) return 'recently';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return 'recently';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month]} ${dt.year}';
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // dialogContext is the dialog's own BuildContext — must use it for
    // Navigator.pop() so only the dialog closes, not the profile screen.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;
  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final booksRead = profile['booksRead'] as int? ?? 0;
    final totalHours = profile['totalReadingHours'] as int? ?? 0;
    final streak = profile['currentStreak'] as int? ?? 0;
    final friends = profile['friendCount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '$booksRead', label: 'Books\nRead', emoji: '📚'),
          _Divider(),
          _StatItem(value: '${totalHours}h', label: 'Reading\nTime', emoji: '⏱'),
          _Divider(),
          _StatItem(value: '$streak', label: 'Day\nStreak', emoji: '🔥'),
          _Divider(),
          _StatItem(value: '$friends', label: 'Friends', emoji: '👥'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  const _StatItem(
      {required this.value, required this.label, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppTheme.primary,
        ),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
      ),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 40, width: 1, color: const Color(0xFFE9D5FF));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly reading chart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklySection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _WeeklySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weeklyStats = profile['weeklyStats'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Reading',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A0A2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Minutes per day this week',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: _WeeklyChart(weeklyStats: weeklyStats),
          ),
        ],
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
    final maxY = weeklyStats.isEmpty
        ? 60.0
        : weeklyStats
            .map((s) => (s as Map)['minutesRead'] as num? ?? 0)
            .reduce((a, b) => a > b ? a : b)
            .toDouble()
            .clamp(1, double.infinity);

    return BarChart(BarChartData(
      maxY: maxY * 1.2,
      barGroups: List.generate(
        weeklyStats.length.clamp(0, 7),
        (i) {
          final stat = weeklyStats[i] as Map;
          final val = (stat['minutesRead'] as num? ?? 0).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY * 1.2,
                  color: const Color(0xFFF3E8FF),
                ),
              ),
            ],
          );
        },
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                v.toInt() < days.length ? days[v.toInt()] : '',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ),
        leftTitles:
            AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends section
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _FriendsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group_outlined,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Friends',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1A0A2E),
                ),
              ),
              Text(
                '${profile['friendCount'] ?? 0} reading buddies',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ]),
          ]),
          TextButton(
            onPressed: () => context.push('/friends'),
            child: const Text(
              'See all →',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
