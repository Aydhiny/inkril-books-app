import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // Duolingo-style pill tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.subtleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderPurple, width: 1.5),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: context.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                    tabs: const [
                      Tab(text: '🌍  Global'),
                      Tab(text: '👥  Friends'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _LeaderboardList(
                      asyncValue: ref.watch(leaderboardProvider),
                      onRetry: () => ref.invalidate(leaderboardProvider),
                      emptyMessage: 'Start reading to claim the top spot!',
                    ),
                    _LeaderboardList(
                      asyncValue: ref.watch(friendLeaderboardProvider),
                      onRetry: () => ref.invalidate(friendLeaderboardProvider),
                      emptyMessage: 'Add friends to compare your reading!',
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
}

// Extracted shared list widget — used by both Global and Friends tabs
class _LeaderboardList extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> asyncValue;
  final VoidCallback onRetry;
  final String emptyMessage;
  const _LeaderboardList({
    required this.asyncValue,
    required this.onRetry,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const ShimmerLeaderList(),
      error: (e, _) => AppErrorWidget(error: e, onRetry: onRetry),
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
                    child: Text('🏆', style: TextStyle(fontSize: 40)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No readers yet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final entry = entries[i] as Map;
            final isMe = me != null && entry['userId'] == me['userId'];
            return _LeaderRow(
              entry: entry,
              isCurrentUser: isMe,
              onTap: () {
                final uid = entry['userId'] as String?;
                if (uid != null && !isMe) context.push('/profile/$uid');
              },
            );
          },
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rank = entry['rank'] as int? ?? 0;
    final userName = entry['userName'] as String? ?? '';
    final minutes = entry['totalMinutesRead'] as int? ?? 0;
    final streak = entry['currentStreak'] as int? ?? 0;
    final hours = (minutes / 60).toStringAsFixed(1);
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    // Colors per rank — dark-mode aware
    Color bg, border, nameColor;
    double borderWidth;

    if (isCurrentUser) {
      bg = context.primarySurface;
      border = AppTheme.primary;
      nameColor = AppTheme.primary;
      borderWidth = 2;
    } else if (rank == 1) {
      bg = isDark ? const Color(0xFF1E1600) : const Color(0xFFFFFBEB);
      border = const Color(0xFFF59E0B);
      nameColor = const Color(0xFFB45309);
      borderWidth = 2.5;
    } else if (rank == 2) {
      bg = isDark ? const Color(0xFF141414) : const Color(0xFFF8F8F8);
      border = isDark ? const Color(0xFF546E7A) : const Color(0xFFB0BEC5);
      nameColor = isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A);
      borderWidth = 1.5;
    } else if (rank == 3) {
      bg = isDark ? const Color(0xFF1A1000) : const Color(0xFFFFF3E0);
      border = const Color(0xFFFF8F00);
      nameColor = const Color(0xFFE65100);
      borderWidth = 1.5;
    } else {
      bg = context.cardBg;
      border = context.borderPurple;
      nameColor = context.textPrimary;
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
                              : context.textSecondary,
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
                    : context.subtleBg,
              ),
              child: Center(
                child: Text(
                  isCurrentUser ? 'Y' : initials,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : context.textSecondary,
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
