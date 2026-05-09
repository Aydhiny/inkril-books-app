import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Leaderboard',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A0A2E),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: leaderboardAsync.when(
                loading: () => const ShimmerLeaderList(),
                error: (e, _) => AppErrorWidget(
                  error: e,
                  onRetry: () => ref.invalidate(leaderboardProvider),
                ),
                data: (data) {
                  final entries = data['entries'] as List? ?? [];
                  final me = data['currentUserEntry'] as Map?;

                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: Text('🏆',
                                  style: TextStyle(fontSize: 40)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No readers yet',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A0A2E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start reading to claim the top spot!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Flat ranked list — no podium
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final entry = entries[i] as Map;
                      final isMe = me != null &&
                          entry['userId'] == me['userId'];
                      return _LeaderRow(
                        entry: entry,
                        isCurrentUser: isMe,
                        onTap: () {
                          final uid = entry['userId'] as String?;
                          if (uid != null && !isMe) {
                            context.push('/profile/$uid');
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single leaderboard row
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  final Map entry;
  final bool isCurrentUser;
  final VoidCallback onTap;
  const _LeaderRow(
      {required this.entry,
      required this.isCurrentUser,
      required this.onTap});

  static const _goldBg     = Color(0xFFFFFBEB);
  static const _goldBorder = Color(0xFFF59E0B);
  static const _silverBg   = Color(0xFFF8F8F8);
  static const _silverBorder = Color(0xFFB0BEC5);
  static const _bronzeBg   = Color(0xFFFFF3E0);
  static const _bronzeBorder = Color(0xFFFF8F00);

  @override
  Widget build(BuildContext context) {
    final rank      = entry['rank']            as int? ?? 0;
    final userName  = entry['userName']        as String? ?? '';
    final minutes   = entry['totalMinutesRead'] as int? ?? 0;
    final streak    = entry['currentStreak']   as int? ?? 0;
    final hours     = (minutes / 60).toStringAsFixed(1);
    final initials  = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    // Styling per rank
    Color bg, border;
    Color nameColor;
    double borderWidth;

    if (isCurrentUser) {
      bg = const Color(0xFFF3EEFF);
      border = AppTheme.primary;
      nameColor = AppTheme.primary;
      borderWidth = 2;
    } else if (rank == 1) {
      bg = _goldBg;
      border = _goldBorder;
      nameColor = const Color(0xFFB45309);
      borderWidth = 2.5;
    } else if (rank == 2) {
      bg = _silverBg;
      border = _silverBorder;
      nameColor = const Color(0xFF546E7A);
      borderWidth = 1.5;
    } else if (rank == 3) {
      bg = _bronzeBg;
      border = _bronzeBorder;
      nameColor = const Color(0xFFE65100);
      borderWidth = 1.5;
    } else {
      bg = Colors.white;
      border = const Color(0xFFE9D5FF);
      nameColor = const Color(0xFF1A0A2E);
      borderWidth = 1.5;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: borderWidth),
        ),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 36,
              child: rank <= 3
                  ? Text(
                      rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center,
                    )
                  : Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isCurrentUser
                              ? AppTheme.primary
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? AppTheme.primary
                    : const Color(0xFFE5E7EB),
              ),
              child: Center(
                child: Text(
                  isCurrentUser ? 'Y' : initials,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(
                isCurrentUser ? '(You)' : userName,
                style: TextStyle(
                  fontWeight: rank <= 3 || isCurrentUser
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontSize: 15,
                  color: nameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Streak
            const SizedBox(width: 8),
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 3),
            Text(
              '$streak',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: nameColor,
              ),
            ),
            const SizedBox(width: 12),
            // Hours with clock icon
            const Text('⏰', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 3),
            Text(
              '${hours}h',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: nameColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
