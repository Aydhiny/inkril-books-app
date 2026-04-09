import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final friendsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/friends');
  return response.data as List<dynamic>;
});

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final pendingAsync = ref.watch(pendingFriendRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Find friends',
              onPressed: () => _showSearchDialog(context, ref),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'My Friends'),
              Tab(
                child: pendingAsync.maybeWhen(
                  data: (p) => p.isEmpty
                      ? const Text('Requests')
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Requests'),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Theme.of(context).colorScheme.error,
                            child: Text('${p.length}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                        ]),
                  orElse: () => const Text('Requests'),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FriendsList(friendsAsync: friendsAsync),
            _PendingRequests(pendingAsync: pendingAsync, ref: ref),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    List<dynamic> results = [];
    bool searching = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Find Friends'),
          content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Search by username',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: searching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    onPressed: () async {
                      if (controller.text.trim().isEmpty) return;
                      setState(() { searching = true; results = []; });
                      try {
                        final dio = ref.read(dioProvider);
                        final response = await dio.get('/api/users/search', queryParameters: {'q': controller.text.trim()});
                        setState(() { results = response.data as List<dynamic>; searching = false; });
                      } catch (_) {
                        setState(() => searching = false);
                      }
                    },
                  ),
                ),
                onSubmitted: (_) {},
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final u = results[i] as Map;
                      return ListTile(
                        dense: true,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(u['userName'] as String? ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_add_outlined),
                          onPressed: () async {
                            try {
                              final dio = ref.read(dioProvider);
                              await dio.post('/api/friends/requests', data: {'receiverId': u['id']});
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Request sent!')),
                                );
                              }
                            } catch (_) {}
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  final AsyncValue<List<dynamic>> friendsAsync;
  const _FriendsList({required this.friendsAsync});

  @override
  Widget build(BuildContext context) {
    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.group_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('No friends yet'),
            ]),
          );
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, i) {
            final f = friends[i] as Map;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(f['userName'] as String? ?? f['friendId'] as String? ?? ''),
              onTap: () => context.push('/profile/${f['friendId']}'),
            );
          },
        );
      },
    );
  }
}

class _PendingRequests extends StatelessWidget {
  final AsyncValue<List<dynamic>> pendingAsync;
  final WidgetRef ref;
  const _PendingRequests({required this.pendingAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, i) {
            final r = requests[i] as Map;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_add)),
              title: Text('Request from ${r['senderId']}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Accept',
                  onPressed: () => _respond(context, r['id'] as String, accept: true),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: 'Decline',
                  onPressed: () => _respond(context, r['id'] as String, accept: false),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _respond(BuildContext context, String requestId, {required bool accept}) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/friends/requests/$requestId/respond', data: {'accept': accept});
      ref.invalidate(friendsProvider);
      ref.invalidate(pendingFriendRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
