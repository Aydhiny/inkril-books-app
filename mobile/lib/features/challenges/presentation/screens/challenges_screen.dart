import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../library/presentation/providers/library_provider.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(challengesProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(challengesProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('🎯', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            'Daily Challenges',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Resets at midnight',
                            style: TextStyle(fontSize: 13, color: context.textSecondary),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: challengesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: Text('Could not load challenges',
                            style: TextStyle(color: Color(0xFF9CA3AF)))),
                  ),
                  data: (challenges) {
                    if (challenges.isEmpty) {
                      return const _EmptyChallenges();
                    }
                    final completed = challenges
                        .where((c) => (c as Map)['completed'] == true)
                        .length;
                    final total = challenges.length;
                    final allDone = completed == total;

                    return Column(children: [
                      // ── Overall XP bar ─────────────────────────────
                      _XpSummaryBar(completed: completed, total: total),
                      const SizedBox(height: 8),
                      if (allDone) const _AllDoneBanner(),

                      // ── Challenge cards ────────────────────────────
                      ...challenges.map((c) {
                        final ch = c as Map;
                        return _ChallengeCard(
                          id:          ch['id'] as String,
                          title:       ch['title'] as String,
                          description: ch['description'] as String,
                          emoji:       ch['emoji'] as String,
                          progress:    (ch['progress'] as num).toDouble(),
                          current:     (ch['current'] as num).toInt(),
                          target:      (ch['target'] as num).toInt(),
                          unit:        ch['unit'] as String,
                          completed:   ch['completed'] as bool,
                          xp:          (ch['xpReward'] as num).toInt(),
                        );
                      }),

                      const SizedBox(height: 32),
                    ]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP summary bar at top
// ─────────────────────────────────────────────────────────────────────────────

class _XpSummaryBar extends StatelessWidget {
  final int completed;
  final int total;
  const _XpSummaryBar({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B21A8).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(children: [
          // Fire streak orb
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '$completed / $total completed today',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All-done celebration banner
// ─────────────────────────────────────────────────────────────────────────────

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
        ),
        child: const Row(children: [
          Text('🎉', style: TextStyle(fontSize: 22)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "All challenges complete! You're on fire today.",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF065F46),
                fontSize: 14,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual challenge card
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeCard extends StatelessWidget {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final double progress;
  final int current;
  final int target;
  final String unit;
  final bool completed;
  final int xp;

  const _ChallengeCard({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.progress,
    required this.current,
    required this.target,
    required this.unit,
    required this.completed,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = completed
        ? const Color(0xFF22C55E)
        : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: completed
                ? const Color(0xFF86EFAC)
                : context.borderPurpleMid,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: completed
                  ? const Color(0x1422C55E)
                  : const Color(0x0A6B21A8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ──────────────────────────────────────────────
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFFD1FAE5)
                    : context.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            // XP badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Text(
                '+$xp XP',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Progress bar ─────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: completed
                  ? const Color(0xFFBBF7D0)
                  : context.borderPurple,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),

          // ── Counter + status ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $target $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: completed
                      ? const Color(0xFF059669)
                      : context.textSecondary,
                ),
              ),
              if (completed)
                const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Done!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ])
              else
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎯', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(
          'No challenges yet',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start reading to unlock daily challenges!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.textSecondary),
        ),
      ]),
    );
  }
}
