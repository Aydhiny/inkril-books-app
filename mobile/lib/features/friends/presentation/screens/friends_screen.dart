import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_empty_state.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final friendsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/friends');
  return response.data as List<dynamic>;
});

// ── Screen ─────────────────────────────────────────────────────────────────

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _searching = false;
  // Track which user IDs have a pending sent request (optimistic UI)
  final Set<String> _sentRequests = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/users/search',
          queryParameters: {'q': q.trim()});
      setState(() {
        _searchResults = res.data as List<dynamic>;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(String receiverId) async {
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/friends/requests', data: {'receiverId': receiverId});
      setState(() => _sentRequests.add(receiverId));
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final pendingAsync = ref.watch(pendingFriendRequestsProvider);

    // Show search results when the user has typed something, otherwise friends list
    final showSearch = _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(children: [
                // Back arrow — goes back if a route can be popped, else library
                GestureDetector(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/library');
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: context.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.borderPurpleMid, width: 1.5),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        color: context.textPrimary, size: 20),
                  ),
                ),
                Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                // Pending requests badge
                pendingAsync.maybeWhen(
                  data: (p) => p.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showPendingSheet(context, p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B), width: 1.5),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_add_rounded,
                                      size: 16, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${p.length} pending',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ]),
                          ),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Search field ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: context.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderGray),
                ),
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search_rounded,
                        color: context.textHint, size: 22),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _search,
                      decoration: InputDecoration(
                        hintText: 'Search by username…',
                        hintStyle: TextStyle(
                          color: context.textHint,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                          fontSize: 15, color: context.textPrimary),
                    ),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary),
                      ),
                    ),
                  if (!_searching && _searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Body: search results or friends list ───────────────────
            Expanded(
              child: showSearch
                  ? _SearchResults(
                      results: _searchResults,
                      sentRequests: _sentRequests,
                      onSendRequest: _sendRequest,
                    )
                  : _FriendsList(friendsAsync: friendsAsync),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending requests bottom sheet ──────────────────────────────────────────

  void _showPendingSheet(BuildContext context, List<dynamic> requests) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _PendingSheet(
        requests: requests,
        onRespond: (id, accept) async {
          try {
            final dio = ref.read(dioProvider);
            await dio.put('/api/friends/requests/$id/respond',
                data: {'accept': accept});
            ref.invalidate(friendsProvider);
            ref.invalidate(pendingFriendRequestsProvider);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          } catch (_) {}
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search results list
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final List<dynamic> results;
  final Set<String> sentRequests;
  final Future<void> Function(String) onSendRequest;

  const _SearchResults({
    required this.results,
    required this.sentRequests,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return AnimatedEmptyState(
        emoji: '🔍',
        title: 'No users found',
        subtitle: 'Try a different username',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = results[i] as Map;
        final id = u['id'] as String? ?? '';
        final username = u['userName'] as String? ?? '';
        final displayName =
            u['displayName'] as String? ?? u['fullName'] as String? ?? username;
        final totalMinutes = (u['totalReadingMinutes'] as num?)?.toInt() ?? 0;
        final avatarUrl = u['avatarUrl'] as String?;
        final isSent = sentRequests.contains(id);

        return _UserCard(
          id: id,
          username: username,
          displayName: displayName,
          readingMinutes: totalMinutes,
          avatarUrl: avatarUrl,
          isSent: isSent,
          onAddFriend: isSent ? null : () => onSendRequest(id),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends list
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsList extends ConsumerWidget {
  final AsyncValue<List<dynamic>> friendsAsync;
  const _FriendsList({required this.friendsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return friendsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () => ref.invalidate(friendsProvider),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return AnimatedEmptyState(
            emoji: '👥',
            title: 'No friends yet',
            subtitle: 'Search for readers above\nand send a friend request',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: friends.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final f = friends[i] as Map;
            final friendId = f['friendId'] as String? ?? '';
            final username = f['userName'] as String? ?? '';
            final displayName = f['displayName'] as String?
                ?? f['fullName'] as String?
                ?? username;
            final totalMinutes =
                (f['totalReadingMinutes'] as num?)?.toInt() ?? 0;
            final avatarUrl = f['avatarUrl'] as String?;

            return _UserCard(
              id: friendId,
              username: username,
              displayName: displayName,
              readingMinutes: totalMinutes,
              avatarUrl: avatarUrl,
              isSent: false,
              onAddFriend: null, // already friends — tap to view profile
              onTap: () => context.push('/profile/$friendId'),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared user card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final String id;
  final String username;
  final String displayName;
  final int readingMinutes;
  final String? avatarUrl;
  final bool isSent;
  final VoidCallback? onAddFriend;
  final VoidCallback? onTap;

  const _UserCard({
    required this.id,
    required this.username,
    required this.displayName,
    required this.readingMinutes,
    required this.avatarUrl,
    required this.isSent,
    required this.onAddFriend,
    this.onTap,
  });

  String _fmtMinutes(int m) {
    if (m < 60) return '${m}m read';
    final h = m ~/ 60;
    return '${h}h read';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderGray, width: 1.5),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 104,
                    errorWidget: (_, __, ___) => _AvatarFallback(username),
                    placeholder: (_, __) => _AvatarFallback(username),
                  )
                : _AvatarFallback(username),
          ),
          const SizedBox(width: 12),
          // Name + username + reading time
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.isNotEmpty ? displayName : username,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: context.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      _fmtMinutes(readingMinutes),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ]),
                ]),
          ),
          // Action button (only shown in search mode)
          if (onAddFriend != null || isSent) ...[
            const SizedBox(width: 8),
            isSent
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.subtleBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Request Sent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onAddFriend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Add Friend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ],
        ]),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String username;
  const _AvatarFallback(this.username);

  @override
  Widget build(BuildContext context) {
    final letter =
        username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending requests bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PendingSheet extends StatelessWidget {
  final List<dynamic> requests;
  final Future<void> Function(String id, bool accept) onRespond;

  const _PendingSheet({required this.requests, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderPurpleMid, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A6B21A8),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.borderPurpleMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Friend Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = requests[i] as Map;
                final id = r['id'] as String? ?? '';
                final senderName = r['senderName'] as String?
                    ?? r['senderId'] as String?
                    ?? 'Someone';

                return Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF22C55E)),
                    tooltip: 'Accept',
                    onPressed: () => onRespond(id, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded,
                        color: Color(0xFFEF4444)),
                    tooltip: 'Decline',
                    onPressed: () => onRespond(id, false),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
