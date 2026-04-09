import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load leaderboard: $e')),
        data: (data) {
          final entries = data['entries'] as List? ?? [];
          final me = data['currentUserEntry'] as Map?;

          return Column(
            children: [
              if (me != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    CircleAvatar(child: Text('#${me['rank']}')),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Your Position', style: Theme.of(context).textTheme.labelMedium),
                      Text('${me['totalMinutesRead']} min read · ${me['currentStreak']}🔥 streak',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                  ]),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final entry = entries[i] as Map;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: i < 3
                            ? [Colors.amber, Colors.grey, Colors.brown][i]
                            : Theme.of(context).colorScheme.surfaceVariant,
                        child: Text('${entry['rank']}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(entry['userName'] as String),
                      subtitle: Text(
                        '📖 ${entry['totalMinutesRead']} min  🔥 ${entry['currentStreak']} days  📚 ${entry['booksCompleted']} books',
                      ),
                      onTap: () => context.push('/profile/${entry['userId']}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
