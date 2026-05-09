import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Leaderboard',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A0A2E),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Top readers this week',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
            Expanded(
              child: leaderboardAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Color(0xFF9CA3AF)),
                      const SizedBox(height: 12),
                      Text('$e',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(leaderboardProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (data) {
                  final entries = data['entries'] as List? ?? [];
                  final me = data['currentUserEntry'] as Map?;
                  final top3 = entries.take(3).toList();
                  final rest = entries.skip(3).toList();

                  return Column(
                    children: [
                      // Podium top-3
                      if (top3.isNotEmpty)
                        _PodiumSection(entries: top3),
                      // Remaining ranks
                      Expanded(
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: rest.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final entry = rest[i] as Map;
                            final isMe = me != null &&
                                entry['rank'] == me['rank'];
                            return _RankCard(
                                entry: entry, isCurrentUser: isMe);
                          },
                        ),
                      ),
                      // Current user sticky footer (if not visible)
                      if (me != null && (me['rank'] as int? ?? 99) > entries.length)
                        _CurrentUserFooter(entry: me),
                    ],
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
// Podium (top 3)
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumSection extends StatelessWidget {
  final List entries;
  const _PodiumSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd (left), 1st (center, taller), 3rd (right)
    final first = entries.isNotEmpty ? entries[0] as Map : null;
    final second = entries.length > 1 ? entries[1] as Map : null;
    final third = entries.length > 2 ? entries[2] as Map : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) _PodiumSlot(entry: second, rank: 2, height: 80),
          if (first != null) _PodiumSlot(entry: first, rank: 1, height: 100),
          if (third != null) _PodiumSlot(entry: third, rank: 3, height: 65),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final Map entry;
  final int rank;
  final double height;
  const _PodiumSlot(
      {required this.entry, required this.rank, required this.height});

  Color get _medalColor {
    if (rank == 1) return AppTheme.goldMedal;
    if (rank == 2) return AppTheme.silverMedal;
    return AppTheme.bronzeMedal;
  }

  String get _medal {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    return '🥉';
  }

  @override
  Widget build(BuildContext context) {
    final userName = entry['userName'] as String? ?? '';
    final initials =
        userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final minutes = entry['totalMinutesRead'] as int? ?? 0;
    final streak = entry['currentStreak'] as int? ?? 0;

    return GestureDetector(
      onTap: () {
        final userId = entry['userId'] as String?;
        if (userId != null) context.push('/profile/$userId');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_medal, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: rank == 1 ? 28 : 22,
            backgroundColor:
                Colors.white.withValues(alpha: 0.25),
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: rank == 1 ? 20 : 16,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            userName.length > 8
                ? '${userName.substring(0, 8)}…'
                : userName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔥', style: TextStyle(fontSize: 10)),
            Text(
              '$streak',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _medalColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_formatMinutes(minutes)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int min) {
    if (min >= 60) return '${(min / 60).toStringAsFixed(1)}h';
    return '${min}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rank card (4th place onward)
// ─────────────────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  final Map entry;
  final bool isCurrentUser;
  const _RankCard({required this.entry, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] as int? ?? 0;
    final userName = entry['userName'] as String? ?? '';
    final minutes = entry['totalMinutesRead'] as int? ?? 0;
    final streak = entry['currentStreak'] as int? ?? 0;
    final books = entry['booksCompleted'] as int? ?? 0;
    final initials =
        userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () {
        final userId = entry['userId'] as String?;
        if (userId != null) context.push('/profile/$userId');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentUser ? AppTheme.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentUser
                ? AppTheme.primary
                : const Color(0xFFE9D5FF),
            width: isCurrentUser ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isCurrentUser
                      ? AppTheme.primary
                      : const Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: isCurrentUser
                  ? AppTheme.primary
                  : const Color(0xFFE9D5FF),
              child: Text(
                initials,
                style: TextStyle(
                  color: isCurrentUser
                      ? Colors.white
                      : AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isCurrentUser
                          ? AppTheme.primary
                          : const Color(0xFF1A0A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    _MiniStat(icon: '📚', value: '$books'),
                    const SizedBox(width: 10),
                    _MiniStat(icon: '🔥', value: '$streak'),
                  ]),
                ],
              ),
            ),
            // Reading time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.access_time_rounded,
                    size: 12, color: AppTheme.primary),
                const SizedBox(width: 3),
                Text(
                  _formatMinutes(minutes),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int min) {
    if (min >= 60) return '${(min / 60).toStringAsFixed(1)}h';
    return '${min}m';
  }
}

class _MiniStat extends StatelessWidget {
  final String icon;
  final String value;
  const _MiniStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 2),
      Text(value,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky current-user footer (shown when user is outside visible entries)
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentUserFooter extends StatelessWidget {
  final Map entry;
  const _CurrentUserFooter({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _RankCard(entry: entry, isCurrentUser: true),
    );
  }
}
