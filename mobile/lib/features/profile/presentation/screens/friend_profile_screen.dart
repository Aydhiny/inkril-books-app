import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../providers/profile_provider.dart';

class FriendProfileScreen extends ConsumerWidget {
  final String userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: profile['profilePhotoUrl'] != null
                      ? NetworkImage(profile['profilePhotoUrl'] as String)
                      : null,
                  child: profile['profilePhotoUrl'] == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  profile['userName'] as String? ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (profile['bio'] != null && (profile['bio'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(profile['bio'] as String, style: const TextStyle(color: Colors.grey)),
                ],
                if ((profile['currentStreak'] as int? ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🔥', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        '${profile['currentStreak']} day streak',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              _StatCard(
                label: 'Total Hours',
                value: '${profile['totalReadingHours'] ?? 0}h',
                icon: Icons.access_time,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Books Read',
                value: '${profile['booksRead'] ?? 0}',
                icon: Icons.menu_book,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Friends',
                value: '${profile['friendCount'] ?? 0}',
                icon: Icons.group,
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Send Friend Request'),
                onPressed: () => _sendFriendRequest(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendFriendRequest(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/friends/requests', data: {'receiverId': userId});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send request. Already friends or pending.')),
        );
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
